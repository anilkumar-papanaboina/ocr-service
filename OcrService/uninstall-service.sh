#!/bin/bash

# Script to uninstall the OcrService system daemon

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

echo "========================================"
echo "OCR Service - Uninstall System Daemon"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

PLIST_NAME="com.ocrservice.daemon.plist"
PLIST_PATH="/Library/LaunchDaemons/$PLIST_NAME"

# Check if service is installed
if [ ! -f "$PLIST_PATH" ]; then
    print_error "Service is not installed."
    exit 1
fi

# Stop the service
echo -e "${YELLOW}Stopping service...${NC}"
if launchctl list | grep -q "com.ocrservice.daemon"; then
    launchctl unload "$PLIST_PATH"
    print_success "Service stopped."
else
    print_warning "Service was not running."
fi

# Remove the plist file
echo -e "${YELLOW}Removing service configuration...${NC}"
rm "$PLIST_PATH"
print_success "Service configuration removed."

# Ask about log files
echo ""
read -p "Do you want to remove log files? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    LOG_DIR="/var/log/ocrservice"
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"
        print_success "Log files removed."
    fi
fi

echo ""
print_success "OcrService system daemon has been uninstalled."
echo ""
echo "You can reinstall it anytime by running: sudo ./install-service.sh"
