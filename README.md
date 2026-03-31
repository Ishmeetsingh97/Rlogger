# rlogger - R Command Logger

An R package that automatically logs all executed R commands for audit and compliance purposes.

## ✨ Key Feature: Users Don't Need to Do Anything!

Once deployed:
- ✅ **No manual loading required** - logging starts automatically when R starts
- ✅ **No commands to remember** - completely transparent to users
- ✅ **No configuration needed** - works out of the box
- ✅ **Zero user intervention** - perfect for enterprise deployment

See [Auto-Loading Setup](#auto-loading-setup) below for how to configure this.

## Features

- Captures all R commands in real-time using task callbacks
- **Separate log file for each R session** - no mixing of sessions
- **Computer and username in filename** - easy auditing (who ran what where)
- **Immediate flush** - every command logged instantly (no buffering)
- **Auto-loads on R startup** - users don't need to call `library(rlogger)`
- Stores logs in JSONL (JSON Lines) format for easy parsing
- Works in RStudio and base R

## Installation

### Quick Install (For Testing)

```bash
# Set log path
export RLOGGER_PATH="~/r_logs_test"

# Install from R
R -e "install.packages('rlogger_0.1.0.tar.gz', repos=NULL, type='source')"

# Test it
R -e "library(rlogger); x <- 1+1; get_log_file()"
```

Dependencies (jsonlite, uuid) are installed automatically.

### Production Install (Auto-Loading for All Users)

🚀 **Use the automated setup script:**

```bash
# Navigate to package directory
cd /path/to/Rlogger

# Run setup script (installs + configures auto-load)
sudo ./setup_autoload.sh
```

This script will:
1. ✅ Install package system-wide
2. ✅ Set RLOGGER_PATH environment variable
3. ✅ Configure Rprofile.site for auto-loading
4. ✅ Create log directory with proper permissions

**Result:** Users start R → rlogger loads automatically! No `library(rlogger)` needed!

See [DEPLOYMENT.md](DEPLOYMENT.md) for manual installation instructions.

## Auto-Loading Setup

### How It Works

rlogger can be configured to load **automatically** when any user starts R:

1. **Package installed system-wide** → Available to all users
2. **Environment variable set** → Defines where logs are stored
3. **Rprofile.site configured** → Loads rlogger on R startup

**Result:** Users type `R` → rlogger starts logging automatically!

### Quick Setup

**Use the automated script:**
```bash
sudo ./setup_autoload.sh
```

**Or manually configure Rprofile.site:**

Edit `/usr/lib/R/etc/Rprofile.site` (or equivalent on your system):

```r
# Add this to Rprofile.site
.First <- function() {
  suppressPackageStartupMessages({
    if (requireNamespace("rlogger", quietly = TRUE)) {
      library(rlogger)
    }
  })
}
```

Set environment variable `/etc/environment`:
```bash
RLOGGER_PATH="/network/share/r_logs"
```

📖 **See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions**

### Manual Configuration (For Testing)

For testing without auto-load:

```bash
# Set log path
export RLOGGER_PATH="~/r_logs_test"

# Start R and manually load
R
```

```r
library(rlogger)  # Only needed if not auto-loading
```

## Usage

### Basic Usage

```r
# Load the package (logging starts automatically)
library(rlogger)

# Execute R commands normally
x <- 1 + 1
y <- 2 + 2
print("hello")

# Manually flush logs if needed
flush_logs()

# Disable logging
disable_logging()
```

### Auto-load on R Startup

To automatically load rlogger every time R starts, add this to your `~/.Rprofile`:

```r
if (interactive() && requireNamespace("rlogger", quietly = TRUE)) {
  library(rlogger)
}
```

### Viewing Logs

Each R session creates its own log file with format: `session_{ID}_{timestamp}.jsonl`

```r
# Get current session's log file
log_file <- get_log_file()
cat("Current log file:", log_file, "\n")

# View raw JSONL
readLines(log_file)

# Parse as JSON
logs <- jsonlite::stream_in(file(log_file), verbose = FALSE)
View(logs)

# List all session logs
list.files("~/r_logs_test", pattern = "session_.*\\.jsonl", full.names = TRUE)
```

### Log Format

Each log entry contains:

```json
{
  "timestamp": "2026-03-27T10:30:45.123",
  "session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "user": "username",
  "computer": "hostname",
  "command": "x <- 1 + 1",
  "command_number": 42,
  "success": true
}
```

## Testing

To test the package locally:

```bash
# Set a test log path
export RLOGGER_PATH="~/r_logs_test"

# Start R
R

# Load the package
library(rlogger)

# Execute some test commands
x <- 1 + 1
y <- mean(c(1, 2, 3))
print("test")
plot(1:10)
# ... execute ~10 commands to trigger auto-flush

# Or manually flush
flush_logs()

# Check the log file
readLines("~/r_logs_test/commands_20260327.jsonl")
```

## Functions

- `get_log_file()` - Get the path to the current session's log file
- `get_session_id()` - Get the current session ID
- `flush_logs()` - No-op (logs are already flushed immediately)
- `disable_logging()` - Disable logging and deregister the callback

## How It Works

1. When loaded, rlogger registers a task callback with R
2. A unique session ID is generated and a session-specific log file is created
3. After each top-level command, the callback captures the expression
4. Metadata is collected (timestamp, user, computer, etc.)
5. **The entry is immediately written to the session's log file** (no buffering)
6. Each command is flushed to disk instantly for maximum reliability

## Production Deployment

For enterprise deployment across multiple computers:

1. **Install system-wide**:
   ```bash
   sudo R CMD INSTALL rlogger_0.1.0.tar.gz --library=/usr/local/lib/R/site-library
   ```

2. **Configure system-wide Rprofile** (`/usr/lib/R/etc/Rprofile.site`):
   ```r
   .First <- function() {
     suppressPackageStartupMessages(library(rlogger))
   }
   ```

3. **Set system environment variable**:
   ```bash
   export RLOGGER_PATH="/network/share/r_logs"
   ```

4. **Test with a few users first** before rolling out to all computers

## Architecture Details

### Session-Specific Log Files

Each R session gets its own log file with naming format:
```
{COMPUTER}_{USER}_{YYYYMMDD_HHMMSS}_{SESSION-ID}.jsonl
```

Example: `mac-finance01_jsmith_20260327_143052_a1b2c3d4.jsonl`

**Filename breakdown:**
- `mac-finance01` = Computer hostname (for auditing which machine)
- `jsmith` = Username (for auditing who ran commands)
- `20260327_143052` = Session start timestamp
- `a1b2c3d4` = Session ID (first 8 chars)

This design:
- ✅ **Easy auditing** - see who ran what from filename alone
- ✅ Eliminates concurrent write conflicts between sessions
- ✅ Makes it easy to trace all commands from a specific user/computer
- ✅ Allows parallel analysis of logs from different sessions
- ✅ Simplifies debugging (one file = one session)

### Immediate Flush vs Buffering

Commands are written immediately after execution (no buffering):
- ✅ **Maximum reliability** - no data loss if R crashes
- ✅ **Real-time audit trail** - logs available instantly
- ✅ **Simpler implementation** - no buffer management
- ⚠️ **Slight I/O overhead** - one write per command (negligible for interactive use)

## Current Limitations (MVP)

This is a minimal viable prototype. The following features are planned for future versions:

- File locking (not needed with per-session files, but useful if extending to shared files)
- Local cache fallback when network is unavailable
- Extended metadata (RStudio detection, execution time, working directory)
- Comprehensive error handling and logging
- Unit tests

## License

MIT License - see LICENSE file for details

## Support

For issues or questions, contact your IT administrator.
