#!/bin/bash

# OCR Service Setup Script for macOS
# This script automates the installation and configuration

set -e  # Exit on error

echo "========================================"
echo "OCR Service Setup for macOS"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Step 1: Check if Homebrew is installed
echo -e "${YELLOW}Step 1: Checking Homebrew installation...${NC}"
if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    print_success "Homebrew installed successfully!"
else
    print_success "Homebrew is already installed."
fi

# Step 2: Check if .NET 9 SDK is installed
echo ""
echo -e "${YELLOW}Step 2: Checking .NET 9 SDK installation...${NC}"
if ! command -v dotnet &> /dev/null; then
    print_warning ".NET SDK not found. Installing .NET 9 SDK..."
    brew install --cask dotnet-sdk
    print_success ".NET 9 SDK installed successfully!"
else
    DOTNET_VERSION=$(dotnet --version)
    if [[ $DOTNET_VERSION == 9.* ]]; then
        print_success ".NET 9 SDK is already installed (version: $DOTNET_VERSION)."
    else
        print_warning "Current .NET version: $DOTNET_VERSION"
        read -p "Do you want to install .NET 9 SDK? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install --cask dotnet-sdk
            print_success ".NET 9 SDK installed!"
        fi
    fi
fi

# Step 3: Install Tesseract OCR
echo ""
echo -e "${YELLOW}Step 3: Installing Tesseract OCR...${NC}"
if ! command -v tesseract &> /dev/null; then
    print_info "Installing Tesseract OCR..."
    brew install tesseract
    print_success "Tesseract OCR installed successfully!"
else
    TESSERACT_VERSION=$(tesseract --version 2>&1 | head -n 1)
    print_success "Tesseract is already installed ($TESSERACT_VERSION)."
    
    # Upgrade if needed
    if brew outdated tesseract &> /dev/null; then
        print_warning "A newer version of Tesseract is available."
        read -p "Do you want to upgrade? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew upgrade tesseract
            print_success "Tesseract upgraded!"
        fi
    fi
fi

# Step 4: Locate Homebrew prefix and Tesseract paths
echo ""
echo -e "${YELLOW}Step 4: Locating installation paths...${NC}"
HOMEBREW_PREFIX=$(brew --prefix)
TESSERACT_PREFIX=$(brew --prefix tesseract)
LEPTONICA_PREFIX=$(brew --prefix leptonica)
TESSDATA_PATH="$TESSERACT_PREFIX/share/tessdata"

print_info "Homebrew prefix: $HOMEBREW_PREFIX"
print_info "Tesseract prefix: $TESSERACT_PREFIX"
print_info "Leptonica prefix: $LEPTONICA_PREFIX"
print_info "Tessdata path: $TESSDATA_PATH"

# Verify tessdata exists
if [ -d "$TESSDATA_PATH" ]; then
    print_success "Tessdata directory found."
    print_info "Available languages: $(ls $TESSDATA_PATH/*.traineddata 2>/dev/null | xargs -n 1 basename | sed 's/.traineddata//' | tr '\n' ', ' | sed 's/,$//')"
else
    print_error "Tessdata directory not found at $TESSDATA_PATH"
    exit 1
fi

# Step 5: Update Program.cs with correct paths
echo ""
echo -e "${YELLOW}Step 5: Updating Program.cs...${NC}"
PROGRAM_CS="Program.cs"

if [ -f "$PROGRAM_CS" ]; then
    # Update DYLD_LIBRARY_PATH
    sed -i '' "s|Environment.SetEnvironmentVariable(\"DYLD_LIBRARY_PATH\", \".*\");|Environment.SetEnvironmentVariable(\"DYLD_LIBRARY_PATH\", \"$HOMEBREW_PREFIX/lib:$TESSERACT_PREFIX/lib:$LEPTONICA_PREFIX/lib\");|g" "$PROGRAM_CS"
    
    # Update tessdata path
    sed -i '' "s|var tessdataPath = .*\";|var tessdataPath = \"$TESSDATA_PATH\";|g" "$PROGRAM_CS"
    
    print_success "Program.cs updated with correct paths!"
else
    print_error "Program.cs not found in current directory!"
    print_warning "Please make sure you're running this script from the OcrService directory."
    exit 1
fi

# Step 6: Update OcrService.csproj with correct paths
echo ""
echo -e "${YELLOW}Step 6: Updating OcrService.csproj...${NC}"
CSPROJ="OcrService.csproj"

if [ -f "$CSPROJ" ]; then
    # Update library paths in build target
    sed -i '' "s|/opt/homebrew/opt/tesseract/lib|$TESSERACT_PREFIX/lib|g" "$CSPROJ"
    sed -i '' "s|/opt/homebrew/opt/leptonica/lib|$LEPTONICA_PREFIX/lib|g" "$CSPROJ"
    
    print_success "OcrService.csproj updated with correct paths!"
else
    print_error "OcrService.csproj not found in current directory!"
    exit 1
fi

# Step 7: Restore NuGet packages
echo ""
echo -e "${YELLOW}Step 7: Restoring NuGet packages...${NC}"
dotnet restore
print_success "NuGet packages restored!"

# Step 8: Build the project
echo ""
echo -e "${YELLOW}Step 8: Building the project...${NC}"
if dotnet build; then
    print_success "Project built successfully!"
else
    print_error "Build failed. Please check the errors above."
    exit 1
fi

# Step 9: Verify native libraries
echo ""
echo -e "${YELLOW}Step 9: Verifying native libraries...${NC}"
BUILD_OUTPUT="bin/Debug/net9.0/x64"

if [ -f "$BUILD_OUTPUT/libtesseract50.dylib" ] && [ -f "$BUILD_OUTPUT/libleptonica-1.82.0.dylib" ]; then
    print_success "Native libraries copied successfully!"
    ls -lh "$BUILD_OUTPUT"/*.dylib | head -5
else
    print_error "Native libraries not found in build output!"
    print_warning "Attempting to copy manually..."
    
    mkdir -p "$BUILD_OUTPUT"
    cp -f "$TESSERACT_PREFIX/lib/libtesseract.5.dylib" "$BUILD_OUTPUT/libtesseract50.dylib"
    cp -f "$LEPTONICA_PREFIX/lib/libleptonica.6.dylib" "$BUILD_OUTPUT/libleptonica-1.82.0.dylib"
    
    if [ -f "$BUILD_OUTPUT/libtesseract50.dylib" ]; then
        print_success "Native libraries copied manually!"
    else
        print_error "Failed to copy native libraries!"
        exit 1
    fi
fi

# Step 10: Summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Setup Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Homebrew Prefix:  $HOMEBREW_PREFIX"
echo "  Tesseract Path:   $TESSERACT_PREFIX"
echo "  Tessdata Path:    $TESSDATA_PATH"
echo ""
echo -e "${YELLOW}To run the application:${NC}"
echo "  cd $(pwd)"
echo "  dotnet run"
echo ""
echo -e "${YELLOW}To access Swagger UI:${NC}"
echo "  http://localhost:5196/swagger"
echo ""
echo -e "${YELLOW}API Endpoint:${NC}"
echo "  POST http://localhost:5196/extract-text-from-image"
echo ""
print_success "You're all set! Run 'dotnet run' to start the service."
