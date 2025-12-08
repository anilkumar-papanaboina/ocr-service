# OCR Service Setup Instructions

## Prerequisites

1. **.NET 9.0 SDK**
   ```bash
   # Check if installed
   dotnet --version
   ```

2. **Homebrew** (macOS only)
   ```bash
   # Install if needed
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

## Installation Steps

### macOS (Apple Silicon or Intel)

1. **Install Tesseract OCR**
   ```bash
   brew install tesseract
   ```

2. **Clone/Copy the project** to your machine

3. **Update paths in Program.cs** (if Homebrew installed Tesseract in a different location)
   
   Check where Tesseract is installed:
   ```bash
   brew --prefix tesseract
   ```
   
   Update line 17 in `Program.cs` with the correct path:
   ```csharp
   var tessdataPath = "<YOUR_HOMEBREW_PREFIX>/share/tessdata";
   ```

4. **Build the project**
   ```bash
   cd OcrService
   dotnet build
   ```
   
   The build process will automatically copy native libraries to the output directory.

5. **Run the application**
   ```bash
   dotnet run
   ```

6. **Access Swagger UI**
   ```
   http://localhost:5196/swagger
   ```

### Linux

1. **Install Tesseract**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install tesseract-ocr libtesseract-dev
   
   # Check installation
   tesseract --version
   ```

2. **Update Program.cs**
   - Remove or comment out line 4 (DYLD_LIBRARY_PATH)
   - Update line 17 to point to Linux tessdata path:
   ```csharp
   var tessdataPath = "/usr/share/tesseract-ocr/5/tessdata";  // or check with: dpkg -L tesseract-ocr-eng
   ```

3. **Remove macOS-specific build target from OcrService.csproj**
   - Delete the entire `<Target Name="CopyNativeLibraries"...` section

4. **Build and run**
   ```bash
   dotnet build
   dotnet run
   ```

### Windows

1. **Install Tesseract**
   - Download from: https://github.com/UB-Mannheim/tesseract/wiki
   - Or use Chocolatey: `choco install tesseract`

2. **Update Program.cs**
   - Remove or comment out line 4 (DYLD_LIBRARY_PATH)
   - Update line 17:
   ```csharp
   var tessdataPath = @"C:\Program Files\Tesseract-OCR\tessdata";  // Adjust to your installation path
   ```

3. **Remove macOS-specific build target from OcrService.csproj**
   - Delete the entire `<Target Name="CopyNativeLibraries"...` section

4. **Build and run**
   ```bash
   dotnet build
   dotnet run
   ```

## API Usage

### Endpoint
`POST /extract-text-from-image`

### Request
- Content-Type: `multipart/form-data`
- Body: `image` (file)

### Response
```json
{
  "text": "Extracted text from the image",
  "confidence": 0.95
}
```

### Example using curl
```bash
curl -X POST "http://localhost:5196/extract-text-from-image" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "image=@/path/to/your/image.png"
```

## Configuration

### Adjust Concurrent Request Handling

In `Program.cs` line 18, change the pool size:
```csharp
builder.Services.AddSingleton<TesseractEnginePool>(sp => new TesseractEnginePool(tessdataPath, poolSize: 10));
```

- Default: 4 concurrent requests
- Recommended: Match your expected concurrent load
- Higher values use more memory but handle more parallel requests

## Troubleshooting

### Library not found errors (macOS)
If you get "Failed to find library" errors:
1. Check Homebrew installation: `brew list tesseract leptonica`
2. Verify paths: `brew --prefix tesseract` and `brew --prefix leptonica`
3. Update the build script in `OcrService.csproj` with correct paths

### tessdata not found
1. Find tessdata location: 
   - macOS: `find /opt/homebrew -name tessdata -type d`
   - Linux: `dpkg -L tesseract-ocr-eng | grep tessdata`
   - Windows: Check Tesseract installation directory
2. Update the path in `Program.cs` line 17

### Poor OCR quality
- Ensure images are clear and high resolution
- Consider preprocessing images (deskew, denoise, etc.)
- Check confidence score in response - low confidence indicates poor quality input

## Additional Language Support

To add support for other languages:

1. **macOS**: `brew install tesseract-lang`
2. **Linux**: `sudo apt-get install tesseract-ocr-[lang]` (e.g., `tesseract-ocr-fra` for French)
3. **Windows**: Download language files from GitHub and place in tessdata folder

Update engine initialization in `TesseractEnginePool` to use different language:
```csharp
var engine = new TesseractEngine(tessdataPath, "fra", EngineMode.Default);  // for French
```
