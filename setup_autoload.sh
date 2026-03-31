#!/bin/bash
#
# Auto-Install Setup Script for rlogger
#
# This script sets up rlogger to automatically load on EVERY R session
# Users will NEVER need to call library(rlogger) manually
#
# Usage:
#   sudo ./setup_autoload.sh
#

set -e  # Exit on error

echo "========================================="
echo "rlogger Auto-Load Setup Script"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root (sudo)"
  echo "Usage: sudo ./setup_autoload.sh"
  exit 1
fi

# Configuration
PACKAGE_FILE="rlogger_0.1.0.tar.gz"
NETWORK_PATH="${RLOGGER_PATH:-/network/share/r_logs}"

echo "Configuration:"
echo "  Package: $PACKAGE_FILE"
echo "  Log path: $NETWORK_PATH"
echo ""

# Step 1: Find R installation
echo "[1/5] Checking R installation..."
if ! command -v R &> /dev/null; then
  echo "ERROR: R is not installed or not in PATH"
  exit 1
fi

R_VERSION=$(R --version | head -n1)
echo "  Found: $R_VERSION"

# Find R home directory
R_HOME=$(R RHOME)
R_ETC="$R_HOME/etc"
R_LIBRARY=$(R -e "cat(.libPaths()[1])" -q --no-save 2>/dev/null | tail -n1)

echo "  R_HOME: $R_HOME"
echo "  R_ETC: $R_ETC"
echo "  R_LIBRARY: $R_LIBRARY"
echo ""

# Step 2: Install package system-wide
echo "[2/5] Installing rlogger package system-wide..."
if [ ! -f "$PACKAGE_FILE" ]; then
  echo "ERROR: Package file not found: $PACKAGE_FILE"
  exit 1
fi

R CMD INSTALL "$PACKAGE_FILE" --library="$R_LIBRARY"
echo "  ✓ Package installed to $R_LIBRARY"
echo ""

# Step 3: Set environment variable
echo "[3/5] Setting RLOGGER_PATH environment variable..."

# For Linux systems
if [ -f /etc/environment ]; then
  if grep -q "RLOGGER_PATH" /etc/environment; then
    echo "  RLOGGER_PATH already set in /etc/environment"
  else
    echo "RLOGGER_PATH=\"$NETWORK_PATH\"" >> /etc/environment
    echo "  ✓ Added to /etc/environment"
  fi
fi

# Also add to profile.d for login shells
mkdir -p /etc/profile.d
cat > /etc/profile.d/rlogger.sh << EOF
# rlogger configuration
export RLOGGER_PATH="$NETWORK_PATH"
EOF
chmod +x /etc/profile.d/rlogger.sh
echo "  ✓ Created /etc/profile.d/rlogger.sh"
echo ""

# Step 4: Configure auto-load in Rprofile.site
echo "[4/5] Configuring auto-load in Rprofile.site..."

RPROFILE_SITE="$R_ETC/Rprofile.site"

# Backup existing Rprofile.site if it exists
if [ -f "$RPROFILE_SITE" ]; then
  cp "$RPROFILE_SITE" "$RPROFILE_SITE.backup.$(date +%Y%m%d_%H%M%S)"
  echo "  ✓ Backed up existing Rprofile.site"
fi

# Check if rlogger is already configured
if grep -q "library(rlogger)" "$RPROFILE_SITE" 2>/dev/null; then
  echo "  rlogger already configured in Rprofile.site"
else
  # Add auto-load configuration
  cat >> "$RPROFILE_SITE" << 'EOF'

# ========================================
# rlogger - Automatic Command Logging
# ========================================
# This automatically loads rlogger on every R session
# Users do not need to call library(rlogger) manually
#
.First <- function() {
  suppressPackageStartupMessages({
    if (requireNamespace("rlogger", quietly = TRUE)) {
      library(rlogger)
    } else {
      warning("rlogger package not found - command logging disabled")
    }
  })
}
EOF
  echo "  ✓ Added auto-load configuration to Rprofile.site"
fi
echo ""

# Step 5: Create log directory
echo "[5/5] Creating log directory..."

if [ ! -d "$NETWORK_PATH" ]; then
  mkdir -p "$NETWORK_PATH"
  echo "  ✓ Created directory: $NETWORK_PATH"
else
  echo "  Directory already exists: $NETWORK_PATH"
fi

# Set permissions (world-writable with sticky bit)
chmod 1777 "$NETWORK_PATH"
echo "  ✓ Set permissions (1777 - sticky bit)"
echo ""

# Summary
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  ✓ Package installed system-wide"
echo "  ✓ Environment variable configured"
echo "  ✓ Auto-load enabled in Rprofile.site"
echo "  ✓ Log directory created and configured"
echo ""
echo "Next steps:"
echo "  1. Users should log out and back in (for env vars)"
echo "  2. Start R - rlogger will load automatically"
echo "  3. No need to call library(rlogger)!"
echo ""
echo "Test it:"
echo "  R"
echo "  # You should see: 'rlogger: Command logging active'"
echo "  # Execute: x <- 1 + 1"
echo "  # Check: get_log_file()"
echo ""
echo "Log files will be created at:"
echo "  $NETWORK_PATH/{COMPUTER}_{USER}_{TIMESTAMP}_{SESSION-ID}.jsonl"
echo ""
