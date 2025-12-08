#!/bin/bash

# Script to install and manage OcrService as a 24/7 system daemon on macOS
# This uses launchd (LaunchDaemon) to keep the service running system-wide

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

echo "========================================"
echo "OCR Service - System Daemon Setup"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get the user who invoked sudo
REAL_USER="${SUDO_USER:-$(whoami)}"
REAL_HOME=$(eval echo ~$REAL_USER)
CURRENT_DIR=$(pwd)
PLIST_NAME="com.ocrservice.daemon.plist"
PLIST_SOURCE="$CURRENT_DIR/$PLIST_NAME"
LAUNCH_DAEMONS_DIR="/Library/LaunchDaemons"
PLIST_DEST="$LAUNCH_DAEMONS_DIR/$PLIST_NAME"
LOG_DIR="/var/log/ocrservice"

# Find dotnet path
DOTNET_PATH=$(which dotnet)
if [ -z "$DOTNET_PATH" ]; then
    # Try common locations
    if [ -f "/usr/local/share/dotnet/dotnet" ]; then
        DOTNET_PATH="/usr/local/share/dotnet/dotnet"
    elif [ -f "/opt/homebrew/bin/dotnet" ]; then
        DOTNET_PATH="/opt/homebrew/bin/dotnet"
    else
        print_error "dotnet not found!"
        exit 1
    fi
fi

print_info "Real user: $REAL_USER"
print_info "User home: $REAL_HOME"
print_info "Project directory: $CURRENT_DIR"
print_info "Dotnet path: $DOTNET_PATH"

# Step 1: Build Release version
echo ""
echo -e "${YELLOW}Step 1: Building Release version...${NC}"
cd "$CURRENT_DIR"
sudo -u "$REAL_USER" dotnet publish -c Release -o bin/Release/net9.0/publish
print_success "Release build completed."

# Step 2: Create log directory
echo ""
echo -e "${YELLOW}Step 2: Creating log directory...${NC}"
mkdir -p "$LOG_DIR"
chown "$REAL_USER:staff" "$LOG_DIR"
print_success "Log directory created: $LOG_DIR"

# Step 3: Update plist file with correct paths
echo ""
echo -e "${YELLOW}Step 3: Configuring system daemon...${NC}"

if [ ! -f "$PLIST_SOURCE" ]; then
    print_error "Service configuration file not found: $PLIST_SOURCE"
    print_info "Please ensure com.ocrservice.daemon.plist is in the current directory."
    exit 1
fi

# Create a temporary plist with updated paths
TEMP_PLIST=$(mktemp)
sed "s|YOUR_USERNAME|$REAL_USER|g" "$PLIST_SOURCE" | \
sed "s|/usr/local/share/dotnet/dotnet|$DOTNET_PATH|g" | \
sed "s|/Users/YOUR_USERNAME/HelperProjects/OCR/OcrService|$CURRENT_DIR|g" > "$TEMP_PLIST"

print_success "Service configuration updated."

# Step 4: Install LaunchDaemon
echo ""
echo -e "${YELLOW}Step 4: Installing system daemon...${NC}"

# Stop existing service if running
if launchctl list | grep -q "com.ocrservice.daemon"; then
    print_warning "Stopping existing service..."
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# Copy plist to LaunchDaemons
cp "$TEMP_PLIST" "$PLIST_DEST"
rm "$TEMP_PLIST"
chmod 644 "$PLIST_DEST"
chown root:wheel "$PLIST_DEST"

print_success "System daemon installed: $PLIST_DEST"

# Step 5: Load the service
echo ""
echo -e "${YELLOW}Step 5: Starting service...${NC}"
launchctl load -w "$PLIST_DEST"

# Wait a moment for service to start
sleep 3

# Check if service is running
if launchctl list | grep -q "com.ocrservice.daemon"; then
    print_success "Service is running!"
else
    print_error "Service failed to start. Check logs for details."
    print_info "View logs: sudo tail -f $LOG_DIR/error.log"
    exit 1
fi

# Step 6: Verify service is responding
echo ""
echo -e "${YELLOW}Step 6: Verifying service...${NC}"
sleep 3

# Try to connect to the service
if curl -s http://localhost:5196/swagger/index.html > /dev/null; then
    print_success "Service is responding! Swagger UI is accessible."
else
    print_warning "Service may still be starting up. Give it a few more seconds."
    print_info "Check logs: sudo tail -f $LOG_DIR/output.log"
fi

# Step 7: Summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}System Daemon Installed Successfully!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${YELLOW}Service Information:${NC}"
echo "  Name:     com.ocrservice.daemon"
echo "  Type:     System Daemon (runs at boot)"
echo "  Status:   Running"
echo "  Logs:     $LOG_DIR"
echo "  Swagger:  http://localhost:5196/swagger"
echo "  Endpoint: http://localhost:5196/extract-text-from-image"
echo ""
echo -e "${YELLOW}Service Management Commands (require sudo):${NC}"
echo "  View status:      sudo launchctl list | grep ocrservice"
echo "  Stop service:     sudo launchctl unload $PLIST_DEST"
echo "  Start service:    sudo launchctl load -w $PLIST_DEST"
echo "  Restart service:  sudo launchctl unload $PLIST_DEST && sudo launchctl load -w $PLIST_DEST"
echo "  View logs:        sudo tail -f $LOG_DIR/output.log"
echo "  View errors:      sudo tail -f $LOG_DIR/error.log"
echo "  Uninstall:        sudo ./uninstall-service.sh"
echo ""
echo -e "${YELLOW}The service will:${NC}"
echo "  • Start automatically at system boot"
echo "  • Run without any user logged in"
echo "  • Restart automatically if it crashes"
echo "  • Keep running 24/7 as a system service"
echo "  • Listen on all network interfaces (0.0.0.0:5196)"
echo ""
print_success "Setup complete! Your OCR service is now running as a system daemon."
