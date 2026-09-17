#!/bin/bash
set -e

[ "$EUID" -ne 0 ] && { echo "Run as root: sudo $0"; exit 1; }

PACKAGE="rlogger_0.1.0.tar.gz"
LOG_PATH="${RLOGGER_PATH:-/network/share/r_logs}"
R_HOME=$(R RHOME)
R_LIB=$(R -e "cat(.libPaths()[1])" -q --no-save 2>/dev/null | tail -n1)
RPROFILE="$R_HOME/etc/Rprofile.site"

echo "Installing rlogger..."
R CMD INSTALL "$PACKAGE" --library="$R_LIB"

echo "export RLOGGER_PATH=\"$LOG_PATH\"" > /etc/profile.d/rlogger.sh

[ -f "$RPROFILE" ] && cp "$RPROFILE" "$RPROFILE.backup"
grep -q "library(rlogger)" "$RPROFILE" 2>/dev/null || cat >> "$RPROFILE" << 'EOF'

.First <- function() {
  suppressPackageStartupMessages(library(rlogger, quietly = TRUE))
}
EOF

mkdir -p "$LOG_PATH"
chmod 1777 "$LOG_PATH"

echo "Done! Users must re-login for changes to take effect."
