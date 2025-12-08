# OCR Service Setup Script for Windows
# Run this script in PowerShell with Administrator privileges

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OCR Service Setup for Windows" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Function to check if a command exists
function Test-CommandExists {
    param($command)
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Step 1: Install Chocolatey if not present
Write-Host "Step 1: Checking Chocolatey installation..." -ForegroundColor Yellow
if (-not (Test-CommandExists choco)) {
    Write-Host "Installing Chocolatey package manager..." -ForegroundColor Green
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "Chocolatey installed successfully!" -ForegroundColor Green
} else {
    Write-Host "Chocolatey is already installed." -ForegroundColor Green
}

# Step 2: Install .NET 9 SDK if not present
Write-Host ""
Write-Host "Step 2: Checking .NET 9 SDK installation..." -ForegroundColor Yellow
if (-not (Test-CommandExists dotnet)) {
    Write-Host "Installing .NET 9 SDK..." -ForegroundColor Green
    choco install dotnet-9.0-sdk -y
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host ".NET 9 SDK installed successfully!" -ForegroundColor Green
} else {
    $dotnetVersion = dotnet --version
    Write-Host ".NET SDK is already installed (version: $dotnetVersion)." -ForegroundColor Green
    
    if ($dotnetVersion -notmatch "^9\.") {
        Write-Host "WARNING: .NET 9 is required. Current version: $dotnetVersion" -ForegroundColor Yellow
        $response = Read-Host "Do you want to install .NET 9 SDK? (y/n)"
        if ($response -eq 'y') {
            choco install dotnet-9.0-sdk -y
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
    }
}

# Step 3: Install Tesseract OCR
Write-Host ""
Write-Host "Step 3: Installing Tesseract OCR..." -ForegroundColor Yellow
choco install tesseract -y

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "Tesseract OCR installed successfully!" -ForegroundColor Green

# Step 4: Find Tesseract installation path
Write-Host ""
Write-Host "Step 4: Locating Tesseract installation..." -ForegroundColor Yellow

$tesseractPath = $null
$possiblePaths = @(
    "C:\Program Files\Tesseract-OCR",
    "C:\Program Files (x86)\Tesseract-OCR",
    "${env:ProgramFiles}\Tesseract-OCR",
    "${env:ProgramFiles(x86)}\Tesseract-OCR"
)

foreach ($path in $possiblePaths) {
    if (Test-Path "$path\tesseract.exe") {
        $tesseractPath = $path
        break
    }
}

if ($null -eq $tesseractPath) {
    # Try to find it via registry or environment
    $tesseractExe = Get-Command tesseract -ErrorAction SilentlyContinue
    if ($tesseractExe) {
        $tesseractPath = Split-Path $tesseractExe.Source
    }
}

if ($null -eq $tesseractPath) {
    Write-Host "ERROR: Could not find Tesseract installation path!" -ForegroundColor Red
    Write-Host "Please check your installation and update Program.cs manually." -ForegroundColor Yellow
    $tesseractPath = "C:\Program Files\Tesseract-OCR"
} else {
    Write-Host "Tesseract found at: $tesseractPath" -ForegroundColor Green
}

$tessdataPath = "$tesseractPath\tessdata"
Write-Host "Tessdata path: $tessdataPath" -ForegroundColor Green

# Step 5: Update Program.cs with correct paths
Write-Host ""
Write-Host "Step 5: Updating Program.cs with Windows paths..." -ForegroundColor Yellow

$projectPath = Get-Location
$programCsPath = Join-Path $projectPath "Program.cs"

if (Test-Path $programCsPath) {
    $content = Get-Content $programCsPath -Raw
    
    # Remove or comment out DYLD_LIBRARY_PATH line (macOS specific)
    $content = $content -replace '(Environment\.SetEnvironmentVariable\("DYLD_LIBRARY_PATH".*?\);)', '// $1 // macOS only'
    
    # Update tessdata path
    $escapedPath = $tessdataPath -replace '\\', '\\'
    $content = $content -replace 'var tessdataPath = .*?;', "var tessdataPath = @`"$tessdataPath`";"
    
    Set-Content $programCsPath -Value $content
    Write-Host "Program.cs updated successfully!" -ForegroundColor Green
} else {
    Write-Host "WARNING: Program.cs not found at $programCsPath" -ForegroundColor Yellow
    Write-Host "Please update the tessdata path manually." -ForegroundColor Yellow
}

# Step 6: Update OcrService.csproj to remove macOS-specific build tasks
Write-Host ""
Write-Host "Step 6: Updating OcrService.csproj..." -ForegroundColor Yellow

$csprojPath = Join-Path $projectPath "OcrService.csproj"

if (Test-Path $csprojPath) {
    [xml]$csproj = Get-Content $csprojPath
    
    # Remove macOS-specific Target
    $targetNode = $csproj.Project.Target | Where-Object { $_.Name -eq "CopyNativeLibraries" }
    if ($targetNode) {
        $csproj.Project.RemoveChild($targetNode) | Out-Null
        $csproj.Save($csprojPath)
        Write-Host "OcrService.csproj updated (removed macOS-specific build tasks)!" -ForegroundColor Green
    } else {
        Write-Host "No macOS-specific build tasks found in OcrService.csproj." -ForegroundColor Green
    }
} else {
    Write-Host "WARNING: OcrService.csproj not found at $csprojPath" -ForegroundColor Yellow
}

# Step 7: Restore NuGet packages
Write-Host ""
Write-Host "Step 7: Restoring NuGet packages..." -ForegroundColor Yellow
dotnet restore
Write-Host "NuGet packages restored!" -ForegroundColor Green

# Step 8: Build the project
Write-Host ""
Write-Host "Step 8: Building the project..." -ForegroundColor Yellow
$buildResult = dotnet build
if ($LASTEXITCODE -eq 0) {
    Write-Host "Project built successfully!" -ForegroundColor Green
} else {
    Write-Host "Build failed. Please check the errors above." -ForegroundColor Red
}

# Step 9: Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Tesseract Path: $tesseractPath" -ForegroundColor White
Write-Host "  Tessdata Path:  $tessdataPath" -ForegroundColor White
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Yellow
Write-Host "  dotnet run" -ForegroundColor White
Write-Host ""
Write-Host "To access Swagger UI:" -ForegroundColor Yellow
Write-Host "  http://localhost:5196/swagger" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
