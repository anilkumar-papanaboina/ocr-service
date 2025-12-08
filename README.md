# OCR Service

A production-ready .NET 9.0 Web API service for extracting text from images using Tesseract OCR. Supports concurrent processing and can run as a 24/7 system daemon on macOS.

## Features

- 🚀 Fast OCR processing with Tesseract 5.5.1
- 🔄 Thread-safe concurrent processing (configurable pool size)
- 📝 RESTful API with Swagger documentation
- 🖥️ System daemon support for 24/7 operation
- 🍎 macOS and Windows setup automation
- 📊 Confidence scores for extracted text
- 🔧 Easy deployment and configuration

## Quick Start

### Prerequisites

- .NET 9.0 SDK
- macOS (Intel or Apple Silicon) or Windows
- Homebrew (macOS)

### macOS Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/OCR.git
cd OCR/OcrService

# Make scripts executable
chmod +x *.sh

# Run automated setup
./setup-macos.sh

# Test the service
dotnet run
# Visit http://localhost:5196/swagger
```

### Install as System Daemon (macOS)

```bash
sudo ./install-service.sh
```

The service will start automatically at boot and restart on failure.

### Windows Installation

```powershell
# Run PowerShell as Administrator
cd OCR\OcrService
.\setup-windows.ps1
```

## API Endpoint

### Extract Text from Image

**POST** `/extract-text-from-image`

**Request:**
- Content-Type: `multipart/form-data`
- Body: `image` (file)

**Response:**
```json
{
  "text": "Extracted text content",
  "confidence": 0.95
}
```

**Example:**
```bash
curl -X POST "http://localhost:5196/extract-text-from-image" \
  -H "Content-Type: multipart/form-data" \
  -F "image=@document.png"
```

## Configuration

### Adjust Pool Size

Edit `Program.cs` to change concurrent processing capacity:

```csharp
builder.Services.AddSingleton(sp => 
    new TesseractEnginePool(poolSize: 4, tessdataPath));
```

### Change Port

Edit `appsettings.json` or use environment variable:

```bash
export ASPNETCORE_URLS="http://0.0.0.0:8080"
```

## Service Management (macOS Daemon)

```bash
# Check status
sudo launchctl list | grep ocrservice

# Stop service
sudo launchctl unload /Library/LaunchDaemons/com.ocrservice.daemon.plist

# Start service
sudo launchctl load /Library/LaunchDaemons/com.ocrservice.daemon.plist

# View logs
sudo tail -f /var/log/ocrservice/output.log
sudo tail -f /var/log/ocrservice/error.log

# Uninstall service
sudo ./uninstall-service.sh
```

## Documentation

- [Daemon Setup Guide](DAEMON-SETUP-GUIDE.md) - Complete guide for system service setup
- [Setup Guide](SETUP.md) - General setup instructions
- [Verification Report](VERIFICATION-REPORT.md) - System verification checklist

## Supported Languages

By default, English (`eng`) is installed. To add more languages:

```bash
# macOS
cd /opt/homebrew/Cellar/tesseract/*/share/tessdata/
brew install tesseract-lang  # Installs all languages

# Or download specific language:
# https://github.com/tesseract-ocr/tessdata
```

Update `Program.cs` to use different language:

```csharp
using var engine = new TesseractEngine(tessdataPath, "fra", EngineMode.Default);
```

## Performance

- **Engine Pool:** 4 concurrent requests (configurable)
- **Memory:** ~400-600 MB total
- **Startup:** ~2-3 seconds
- **OCR Time:** 200-500ms per image (varies by size/complexity)

## Troubleshooting

### Native Library Errors

```bash
# Verify Tesseract installation
brew list tesseract
tesseract --version

# Check native libraries
ls bin/Debug/net9.0/x64/*.dylib
```

### Service Won't Start

```bash
# Check logs
sudo tail -30 /var/log/ocrservice/error.log

# Verify daemon is loaded
sudo launchctl list | grep ocrservice

# Test manually
cd bin/Release/net9.0
dotnet OcrService.dll
```

### Build Errors

```bash
# Clean and rebuild
dotnet clean
dotnet restore
dotnet build
```

## Architecture

- **TesseractEnginePool:** Connection pool pattern for thread-safe concurrent processing
- **Native Libraries:** Auto-copied to x64/ directory during build
- **Dependency Injection:** ASP.NET Core DI container manages engine pool lifecycle

## License

MIT License - Feel free to use in your projects!

## Contributing

Contributions welcome! Please open an issue or submit a pull request.

## Author

Your Name - [GitHub Profile](https://github.com/YOUR_USERNAME)

## Acknowledgments

- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)
- [Tesseract .NET Wrapper](https://github.com/charlesw/tesseract)
