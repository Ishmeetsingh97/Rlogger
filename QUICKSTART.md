# Quick Start Guide

## 1. Build the Package

The package has already been built! You should see `rlogger_0.1.0.tar.gz` in the parent directory.

## 2. Run the Test Script

```bash
cd /Users/ishmeet
Rscript Rlogger/test_rlogger.R
```

This will:
- Install the package
- Load it
- Execute test commands
- Verify logs are created
- Display the results

## 3. Manual Testing

```bash
# Set the log path
export RLOGGER_PATH="~/r_logs_test"

# Start R
R
```

Then in R:

```r
# Install the package
install.packages("rlogger_0.1.0.tar.gz", repos = NULL, type = "source")

# Load it
library(rlogger)

# Execute some commands
x <- 1 + 1
y <- 2 + 2
mean(c(1,2,3,4,5))
print("hello")

# Get the current session's log file
log_file <- get_log_file()
cat("Log file:", log_file, "\n")

# Read the log (commands are logged immediately)
readLines(log_file)

# Parse the JSON
logs <- jsonlite::stream_in(file(log_file), verbose = FALSE)
View(logs)

# Get session ID
get_session_id()

# Disable logging when done
disable_logging()
```

## 4. Point to Shared Network Drive

Once you've verified it works locally, point it to your shared drive:

```bash
export RLOGGER_PATH="/path/to/your/shared/drive/r_logs"
```

Then repeat the testing steps.

## 5. Deploy to Other Computers

See README.md section "Production Deployment" for system-wide installation instructions.

## Expected Output

**Log File Name Format:**
```
{COMPUTER}_{USER}_{TIMESTAMP}_{SESSION-ID}.jsonl
```

**Example:**
```
mac-finance01_jsmith_20260327_143052_a1b2c3d4.jsonl
```

This shows:
- Computer: `mac-finance01`
- User: `jsmith`
- Started: `2026-03-27 14:30:52`
- Session ID: `a1b2c3d4...`

Each R session creates its own log file. The log file will contain JSONL entries like:

```json
{"timestamp":"2026-03-27T10:30:45.123","session_id":"a1b2c3d4-...","user":"yourname","computer":"hostname","command":"x <- 1 + 1","command_number":1,"success":true}
{"timestamp":"2026-03-27T10:30:46.456","session_id":"a1b2c3d4-...","user":"yourname","computer":"hostname","command":"y <- 2 + 2","command_number":2,"success":true}
```

**Key Features:**
- Each R session gets its own log file (no mixing)
- Filename includes computer, user, timestamp for easy auditing
- Commands are logged immediately (no buffering)
- Perfect for compliance and audit tracking

## Troubleshooting

**Problem**: Package won't load
- Solution: Make sure jsonlite and uuid are installed: `install.packages(c("jsonlite", "uuid"))`

**Problem**: Log file not created
- Solution: Check that RLOGGER_PATH is set and the directory exists/is writable

**Problem**: Commands not being logged
- Solution: Check that the callback is registered by looking for the startup message when you load the package

**Problem**: Can't find my log file
- Solution: Use `get_log_file()` to see the exact path for your current session
