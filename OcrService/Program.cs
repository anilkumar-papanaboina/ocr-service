using Tesseract;

// Set library path for native libraries
Environment.SetEnvironmentVariable("DYLD_LIBRARY_PATH", "/opt/homebrew/lib:/opt/homebrew/opt/tesseract/lib:/opt/homebrew/opt/leptonica/lib");

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

// Add Swagger services
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Register TesseractEngine pool for parallel processing
string tessdataPath = Path.Combine(
    AppContext.BaseDirectory,
    "ocrtessdata"
);
//var tessdataPath = "/Users/i41073/HelperProjects/OCR/OcrService/ocrtessdata";
builder.Services.AddSingleton<TesseractEnginePool>(sp => new TesseractEnginePool(tessdataPath, poolSize: 4));

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapOpenApi();
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "OCR Service API v1");
});

app.UseHttpsRedirection();

app.MapPost("/extract-text-from-image", async (IFormFile image, TesseractEnginePool enginePool) =>
{
    if (image == null || image.Length == 0)
    {
        return Results.BadRequest("No image provided");
    }

    try
    {
        using var memoryStream = new MemoryStream();
        await image.CopyToAsync(memoryStream);
        var imageBytes = memoryStream.ToArray();
        
        // Get an engine from the pool and process
        var result = await enginePool.ProcessAsync(imageBytes);
        
        return Results.Ok(new { text = result.Text, confidence = result.Confidence });
    }
    catch (Exception ex)
    {
        var innerMessage = ex.InnerException?.Message ?? ex.Message;
        return Results.Problem($"OCR processing failed: {innerMessage}");
    }
})
.WithName("ExtractText")
.Accepts<IFormFile>("multipart/form-data")
.Produces<object>(200)
.Produces(400)
.Produces(500)
.DisableAntiforgery();

app.Run();

// Tesseract Engine Pool for handling concurrent requests
public class TesseractEnginePool : IDisposable
{
    private readonly SemaphoreSlim _semaphore;
    private readonly List<TesseractEngine> _engines;
    private readonly object _lock = new();
    private readonly Queue<TesseractEngine> _availableEngines;

    public TesseractEnginePool(string tessdataPath, int poolSize)
    {
        _semaphore = new SemaphoreSlim(poolSize, poolSize);
        _engines = new List<TesseractEngine>();
        _availableEngines = new Queue<TesseractEngine>();

        for (int i = 0; i < poolSize; i++)
        {
            var engine = new TesseractEngine(tessdataPath, "eng", EngineMode.Default);
            _engines.Add(engine);
            _availableEngines.Enqueue(engine);
        }
    }

    public async Task<OcrResult> ProcessAsync(byte[] imageBytes)
    {
        await _semaphore.WaitAsync();
        TesseractEngine engine;
        
        lock (_lock)
        {
            engine = _availableEngines.Dequeue();
        }

        try
        {
            return await Task.Run(() =>
            {
                using var pix = Pix.LoadFromMemory(imageBytes);
                using var page = engine.Process(pix);
                return new OcrResult
                {
                    Text = page.GetText(),
                    Confidence = page.GetMeanConfidence()
                };
            });
        }
        finally
        {
            lock (_lock)
            {
                _availableEngines.Enqueue(engine);
            }
            _semaphore.Release();
        }
    }

    public void Dispose()
    {
        foreach (var engine in _engines)
        {
            engine.Dispose();
        }
        _semaphore.Dispose();
    }
}

public record OcrResult
{
    public string Text { get; init; } = string.Empty;
    public float Confidence { get; init; }
}
