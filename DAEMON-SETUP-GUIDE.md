# OCR Service - Complete Setup Guide for Mac Mini (24/7 Daemon Service)

This guide will walk you through setting up the OCR Service as a system daemon that runs 24/7 on your Mac Mini, starting automatically at boot without requiring a user login.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Quick Start (Automated Setup)](#quick-start-automated-setup)
3. [Manual Setup (Step by Step)](#manual-setup-step-by-step)
4. [Installing as System Daemon](#installing-as-system-daemon)
5. [Managing the Service](#managing-the-service)
6. [Troubleshooting](#troubleshooting)
7. [Uninstalling](#uninstalling)

---

## Prerequisites

- **Mac Mini** running macOS (Intel or Apple Silicon)
- **Administrator access** (required for system daemon installation)
- **Internet connection** (for downloading dependencies)

---

## Quick Start (Automated Setup)

### Option 1: Complete Automated Setup (Recommended)

If this is your first time setting up the service, follow these steps:

1. **Copy the project** to your Mac Mini (e.g., to `~/HelperProjects/OCR/OcrService`)

2. **Open Terminal** and navigate to the project directory:
   ```bash
   cd ~/HelperProjects/OCR/OcrService
   ```

3. **Run the automated setup script**:
   ```bash
   chmod +x setup-macos.sh
   ./setup-macos.sh
   ```

   This script will:
   - Install Homebrew (if not present)
   - Install .NET 9 SDK
   - Install Tesseract OCR with dependencies
   - Configure all paths automatically
   - Build the project

4. **Install as system daemon**:
   ```bash
   chmod +x install-service.sh
   sudo ./install-service.sh
   ```

   This will:
   - Build a production release
   - Install the service as a LaunchDaemon
   - Start the service automatically
   - Configure it to run at boot

5. **Verify the service is running**:
   ```bash
   sudo launchctl list | grep ocrservice
   ```

   You should see something like:
   ```
   12345	0	com.ocrservice.daemon
   ```

6. **Test the service**:
   - Open a browser and go to: `http://localhost:5196/swagger`
   - You should see the Swagger UI with the API documentation

---

## Manual Setup (Step by Step)

If you prefer to install components manually or the automated script doesn't work:

### Step 1: Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

For Apple Silicon Macs, add Homebrew to your PATH:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Step 2: Install .NET 9 SDK

```bash
brew install --cask dotnet-sdk
```

Verify installation:
```bash
dotnet --version
```

### Step 3: Install Tesseract OCR

```bash
brew install tesseract
```

Verify installation:
```bash
tesseract --version
```

### Step 4: Update Configuration Files

Find your Homebrew prefix:
```bash
brew --prefix tesseract
```

Edit `Program.cs` and update line 17 with your tessdata path:
```csharp
var tessdataPath = "/opt/homebrew/share/tessdata";  // or your actual path
```

### Step 5: Build the Project

```bash
cd ~/HelperProjects/OCR/OcrService
dotnet restore
dotnet build
```

---

## Installing as System Daemon

### What is a System Daemon?

A system daemon is a background service that:
- ✅ Starts automatically at **boot time**
- ✅ Runs **without any user logged in**
- ✅ Continues running 24/7
- ✅ Restarts automatically if it crashes
- ✅ Accessible from **other machines** on the network

### Installation Steps

1. **Navigate to the project directory**:
   ```bash
   cd ~/HelperProjects/OCR/OcrService
   ```

2. **Make installation scripts executable**:
   ```bash
   chmod +x install-service.sh uninstall-service.sh
   ```

3. **Install the daemon** (requires administrator password):
   ```bash
   sudo ./install-service.sh
   ```

4. **Wait for installation** (typically 30-60 seconds)

   The script will:
   - Build a Release version of the application
   - Create log directories at `/var/log/ocrservice`
   - Install the daemon configuration to `/Library/LaunchDaemons`
   - Start the service
   - Verify it's running

5. **Confirm installation**:
   ```bash
   sudo launchctl list | grep ocrservice
   ```

   Expected output:
   ```
   PID    Status  Label
   12345  0       com.ocrservice.daemon
   ```

### First Time Access

After installation, the service will be accessible at:

- **Swagger UI**: `http://localhost:5196/swagger`
- **API Endpoint**: `http://localhost:5196/extract-text-from-image`
- **From other machines**: `http://<MAC_MINI_IP>:5196/swagger`

To find your Mac Mini's IP address:
```bash
ipconfig getifaddr en0  # WiFi
# or
ipconfig getifaddr en1  # Ethernet
```

---

## Managing the Service

### Viewing Service Status

```bash
sudo launchctl list | grep ocrservice
```

The output shows:
- **PID**: Process ID (if running, otherwise "-")
- **Status**: Exit code (0 = healthy)
- **Label**: Service identifier

### Viewing Logs

**Real-time log monitoring**:
```bash
# View application output
sudo tail -f /var/log/ocrservice/output.log

# View errors only
sudo tail -f /var/log/ocrservice/error.log
```

**View last 50 lines**:
```bash
sudo tail -n 50 /var/log/ocrservice/output.log
```

**Search logs**:
```bash
sudo grep "error" /var/log/ocrservice/error.log
```

### Stopping the Service

```bash
sudo launchctl unload /Library/LaunchDaemons/com.ocrservice.daemon.plist
```

### Starting the Service

```bash
sudo launchctl load -w /Library/LaunchDaemons/com.ocrservice.daemon.plist
```

### Restarting the Service

```bash
sudo launchctl unload /Library/LaunchDaemons/com.ocrservice.daemon.plist && \
sudo launchctl load -w /Library/LaunchDaemons/com.ocrservice.daemon.plist
```

### Updating the Service

If you make code changes:

1. Stop the service:
   ```bash
   sudo launchctl unload /Library/LaunchDaemons/com.ocrservice.daemon.plist
   ```

2. Build new version:
   ```bash
   dotnet publish -c Release -o bin/Release/net9.0/publish
   ```

3. Start the service:
   ```bash
   sudo launchctl load -w /Library/LaunchDaemons/com.ocrservice.daemon.plist
   ```

---

## Testing the Service

### Using Swagger UI

1. Open browser: `http://localhost:5196/swagger`
2. Click on **POST /extract-text-from-image**
3. Click **Try it out**
4. Click **Choose File** and select an image with text
5. Click **Execute**
6. View the extracted text in the response

### Using cURL

```bash
curl -X POST "http://localhost:5196/extract-text-from-image" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "image=@/path/to/your/image.png"
```

Example response:
```json
{
  "text": "This is the extracted text from your image\n",
  "confidence": 0.95
}
```

### Using Python

```python
import requests

url = "http://localhost:5196/extract-text-from-image"
files = {"image": open("image.png", "rb")}
response = requests.post(url, files=files)
print(response.json())
```

---

## Troubleshooting

### Service Won't Start

**Check if daemon is loaded**:
```bash
sudo launchctl list | grep ocrservice
```

**Check error logs**:
```bash
sudo tail -f /var/log/ocrservice/error.log
```

**Common issues**:

1. **Port already in use**:
   ```bash
   sudo lsof -i :5196
   ```
   Kill the process using the port or change the port in the daemon plist.

2. **Missing native libraries**:
   ```bash
   ls -la bin/Release/net9.0/x64/*.dylib
   ```
   Rebuild the project if libraries are missing.

3. **Permission errors**:
   Ensure log directory has correct permissions:
   ```bash
   sudo chown -R $(whoami):staff /var/log/ocrservice
   ```

### Service Crashes Frequently

Check the crash logs:
```bash
sudo grep -A 20 "exception" /var/log/ocrservice/error.log
```

If memory issues, reduce pool size in `Program.cs`:
```csharp
builder.Services.AddSingleton<TesseractEnginePool>(sp => 
    new TesseractEnginePool(tessdataPath, poolSize: 2)); // Reduce from 4
```

### Cannot Access from Other Machines

1. **Check firewall**:
   - System Settings → Network → Firewall
   - Allow incoming connections on port 5196

2. **Verify binding**:
   Ensure daemon plist has `--urls http://0.0.0.0:5196`

3. **Test network connectivity**:
   ```bash
   # From another machine
   telnet <MAC_MINI_IP> 5196
   ```

### Poor OCR Quality

- Use high-resolution, clear images
- Check confidence score (should be > 0.8 for good results)
- Preprocess images (convert to grayscale, increase contrast)
- Install additional language data if needed

---

## Uninstalling

### Complete Removal

```bash
cd ~/HelperProjects/OCR/OcrService
sudo ./uninstall-service.sh
```

This will:
1. Stop the daemon
2. Remove the daemon configuration
3. Optionally delete log files

### Manual Removal

If the uninstall script fails:

```bash
# Stop the daemon
sudo launchctl unload /Library/LaunchDaemons/com.ocrservice.daemon.plist

# Remove daemon plist
sudo rm /Library/LaunchDaemons/com.ocrservice.daemon.plist

# Remove logs
sudo rm -rf /var/log/ocrservice
```

---

## Advanced Configuration

### Changing the Port

Edit `/Library/LaunchDaemons/com.ocrservice.daemon.plist`:

```xml
<string>--urls</string>
<string>http://0.0.0.0:8080</string>  <!-- Change port here -->
```

Reload the daemon:
```bash
sudo launchctl unload /Library/LaunchDaemons/com.ocrservice.daemon.plist
sudo launchctl load -w /Library/LaunchDaemons/com.ocrservice.daemon.plist
```

### Adjusting Concurrent Requests

Edit `Program.cs` line 18:
```csharp
builder.Services.AddSingleton<TesseractEnginePool>(sp => 
    new TesseractEnginePool(tessdataPath, poolSize: 10)); // Increase for more concurrency
```

Rebuild and restart the service.

### Adding Language Support

1. Install language files:
   ```bash
   brew install tesseract-lang
   ```

2. Update engine initialization in `Program.cs`:
   ```csharp
   var engine = new TesseractEngine(tessdataPath, "fra+eng", EngineMode.Default);
   ```

---

## Monitoring & Maintenance

### Daily Health Check

Create a simple monitoring script:

```bash
#!/bin/bash
if curl -s http://localhost:5196/swagger > /dev/null; then
    echo "✓ Service is healthy"
else
    echo "✗ Service is down - restarting..."
    sudo launchctl unload /Library/LaunchDaemons/com.ocrservice.daemon.plist
    sudo launchctl load -w /Library/LaunchDaemons/com.ocrservice.daemon.plist
fi
```

### Log Rotation

Logs can grow large over time. Set up log rotation:

```bash
# Create log rotation config
sudo tee /etc/newsyslog.d/ocrservice.conf << EOF
/var/log/ocrservice/*.log  644  7  *  \$D0  J
EOF
```

This rotates logs daily, keeping 7 days of history.

---

## Support & Resources

- **Project Setup**: `SETUP.md`
- **Windows Setup**: `setup-windows.ps1`
- **Logs Location**: `/var/log/ocrservice/`
- **Configuration**: `/Library/LaunchDaemons/com.ocrservice.daemon.plist`

For issues, check the error logs first:
```bash
sudo tail -f /var/log/ocrservice/error.log
```

---

## Summary Checklist

- [ ] Run `./setup-macos.sh` to install dependencies
- [ ] Run `sudo ./install-service.sh` to install daemon
- [ ] Verify service is running: `sudo launchctl list | grep ocrservice`
- [ ] Test Swagger UI: `http://localhost:5196/swagger`
- [ ] Upload a test image and verify OCR works
- [ ] Configure firewall if accessing from other machines
- [ ] Set up log monitoring for production use

**Your OCR service is now running 24/7!** 🎉
