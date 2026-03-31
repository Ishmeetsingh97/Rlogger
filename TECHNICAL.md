# rlogger - Comprehensive Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [Package Structure](#package-structure)
3. [Dependencies](#dependencies)
4. [Core Architecture](#core-architecture)
5. [Implementation Details](#implementation-details)
6. [File-by-File Breakdown](#file-by-file-breakdown)
7. [How R Packages Work](#how-r-packages-work)
8. [Auto-Loading Mechanism](#auto-loading-mechanism)
9. [Logging Flow](#logging-flow)
10. [Performance Considerations](#performance-considerations)
11. [Security Considerations](#security-considerations)
12. [Troubleshooting](#troubleshooting)
13. [Extending the Package](#extending-the-package)

---

## Overview

**rlogger** is an R package that captures all R commands executed by users and logs them to disk for audit and compliance purposes. It is designed for enterprise deployment across 40-50 computers where users should not need to manually install or load anything.

### Key Design Principles

1. **Transparency**: Users don't know logging is happening (works silently)
2. **Reliability**: Every command is logged immediately (no data loss)
3. **Isolation**: Per-session log files eliminate concurrent write conflicts
4. **Auditability**: Filenames include computer, user, and timestamp
5. **Simplicity**: Minimal dependencies and straightforward architecture

---

## Package Structure

### Directory Layout

```
Rlogger/
├── DESCRIPTION           # Package metadata and dependencies
├── NAMESPACE            # Exported functions
├── LICENSE              # MIT license
├── README.md            # User documentation
├── DEPLOYMENT.md        # Enterprise deployment guide
├── QUICKSTART.md        # Quick start guide
├── TECHNICAL.md         # This file - technical documentation
├── SUMMARY.md           # Feature summary
├── CHANGES.md           # Changelog
├── setup_autoload.sh    # Automated setup script
├── test_rlogger.R       # Test script
└── R/                   # R source code
    ├── rlogger.R        # Core logging implementation
    └── zzz.R            # Package lifecycle hooks

Built package:
rlogger_0.1.0.tar.gz     # Installable package archive
```

### File Purposes

| File | Purpose |
|------|---------|
| `DESCRIPTION` | Defines package name, version, dependencies, author, license |
| `NAMESPACE` | Declares which functions are exported (public API) |
| `R/rlogger.R` | Core logging logic: callback, file writing, metadata collection |
| `R/zzz.R` | Package initialization and cleanup hooks |
| `LICENSE` | MIT license text |
| `*.md` | Documentation files |

---

## Dependencies

### Required Packages

The package depends on only 2 external packages (minimal footprint):

#### 1. **jsonlite** (>= 1.7.0)

- **Purpose**: JSON serialization/deserialization
- **Why needed**: Converts R data structures to JSON format for log files
- **Functions used**:
  - `jsonlite::toJSON()` - Convert log entries to JSON strings
  - `auto_unbox = TRUE` - Prevents wrapping scalar values in arrays
- **Stability**: Very stable, widely used (~10M downloads/month)
- **Maintainer**: Jeroen Ooms (very active)

#### 2. **uuid** (>= 0.1-4)

- **Purpose**: Generate universally unique identifiers
- **Why needed**: Create unique session IDs for tracking
- **Functions used**:
  - `uuid::UUIDgenerate()` - Generate random UUID v4
- **Stability**: Stable, lightweight package
- **Alternative**: Could use `digest::digest()` or custom implementation

### R Version Requirement

- **Minimum**: R >= 3.5.0
- **Why**: Uses `addTaskCallback()` which has been stable since R 3.5
- **Tested on**: R 4.2.0, R 4.3.1

### System Dependencies

None. Package is pure R with no C/C++ compilation needed.

---

## Core Architecture

### Three-Layer Design

```
┌─────────────────────────────────────────┐
│         User's R Session                │
│                                         │
│  User executes command: x <- 1 + 1     │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  LAYER 1: Capture (Task Callback)       │
│                                         │
│  - addTaskCallback() hook               │
│  - Captures expression after execution  │
│  - Collects metadata                    │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  LAYER 2: Processing                    │
│                                         │
│  - Deparse expression to string         │
│  - Build metadata object                │
│  - Convert to JSON                      │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  LAYER 3: Storage                       │
│                                         │
│  - Write to session-specific file       │
│  - Flush to disk immediately            │
└─────────────────────────────────────────┘
```

### Key Components

#### 1. Package Environment (`.pkg`)

A private environment that persists across function calls:

```r
.pkg <- new.env(parent = emptyenv())
```

**Stores:**
- `session_id` - Unique UUID for this R session
- `log_path` - Directory where logs are stored
- `log_file` - Full path to this session's log file
- `command_count` - Counter for commands in this session
- `callback_id` - Reference to registered callback

**Why environment?**
- Persists across function calls
- Private (not in global namespace)
- Fast access (no copying)

#### 2. Task Callback Mechanism

R's `addTaskCallback()` allows registering a function that runs after every top-level command.

**Callback signature:**
```r
function(expr, value, ok, visible)
```

**Parameters:**
- `expr` - The unevaluated expression (as language object)
- `value` - The result of evaluating the expression
- `ok` - Boolean indicating if evaluation succeeded
- `visible` - Boolean indicating if result should be printed

**Return value:**
- `TRUE` - Keep callback registered
- `FALSE` - Deregister callback

#### 3. File Writing Strategy

**Per-session files:**
- Each R session gets its own log file
- No concurrent writes from multiple sessions
- No need for file locking
- Simpler and more reliable

**Filename format:**
```
{COMPUTER}_{USER}_{TIMESTAMP}_{SESSION-ID}.jsonl
```

Example: `mac-finance01_jsmith_20260327_143052_a1b2c3d4.jsonl`

**File format: JSONL (JSON Lines)**
- One JSON object per line
- No commas between objects
- Easy to append (no need to parse entire file)
- Easy to stream and process line-by-line

---

## Implementation Details

### Initialization Flow

When `library(rlogger)` is called:

1. **`.onAttach()` hook executes** (in `zzz.R`)
2. **`init_logger()` is called**:
   - Generate session UUID
   - Read `RLOGGER_PATH` environment variable
   - Create log directory if needed
   - Build session-specific log filename
3. **`register_callback()` is called**:
   - Registers `logger_callback()` with R
4. **Startup message displayed** to user
5. **Ready to log** - all subsequent commands will be captured

### Command Logging Flow

When user executes a command (e.g., `x <- 1 + 1`):

1. **R evaluates the command**
2. **R calls all registered task callbacks**
3. **`logger_callback()` executes**:
   ```
   a. Increment command counter
   b. Deparse expression to string
   c. Collect metadata (user, computer, timestamp, etc.)
   d. Call write_log_entry()
   e. Return TRUE (keep callback active)
   ```
4. **`write_log_entry()` executes**:
   ```
   a. Convert metadata to JSON
   b. Open log file in append mode
   c. Write JSON line
   d. Flush to disk
   e. Close file
   ```
5. **Control returns to user**

**Total time:** ~1-5ms (negligible for interactive use)

### Cleanup Flow

When R session ends or user calls `detach("package:rlogger")`:

1. **`.onUnload()` hook executes**
2. **`deregister_callback()` is called**:
   - Removes task callback
3. **Package detached**

Note: No buffer to flush since we use immediate writes.

---

## File-by-File Breakdown

### DESCRIPTION

**Purpose:** Package metadata file (required by R)

**Format:** Debian Control File (DCF) format

**Key fields:**

```
Package: rlogger               # Package name (must match directory name)
Type: Package                  # Package type
Title: R Command Logger        # Short title
Version: 0.1.0                # Semantic versioning
Authors@R: person(...)        # Author information
Description: ...              # Longer description
License: MIT + file LICENSE   # License
Encoding: UTF-8              # File encoding
Depends: R (>= 3.5.0)        # Minimum R version
Imports: jsonlite, uuid      # Required packages
```

**Why these fields matter:**
- `Package` - Used for installation and loading
- `Version` - For tracking updates
- `Depends` - R will check version before installing
- `Imports` - R will install these packages automatically

### NAMESPACE

**Purpose:** Declares package's public API

**Format:** R code (executed when package loads)

**Content:**
```r
export(flush_logs)
export(disable_logging)
export(get_session_id)
export(get_log_file)
```

**What `export()` does:**
- Makes function available when users call `library(rlogger)`
- Without export, functions are internal-only

**Non-exported functions:**
- `init_logger()`
- `register_callback()`
- `logger_callback()`
- `write_log_entry()`

Users cannot call these directly (good - they're internal implementation).

### R/rlogger.R

**Purpose:** Core logging implementation

**Line-by-line explanation:**

```r
# Line 1-2: Package environment
.pkg <- new.env(parent = emptyenv())
```
Creates isolated environment for package state.

```r
# Lines 5-29: init_logger()
init_logger <- function() {
  .pkg$session_id <- uuid::UUIDgenerate()
  # ... create session-specific log filename
}
```
**What it does:**
1. Generate unique session ID (UUID v4, e.g., `a1b2c3d4-e5f6-...`)
2. Read `RLOGGER_PATH` environment variable (default: `~/r_logs`)
3. Expand path (`~/` → `/Users/username/`)
4. Create directory if doesn't exist
5. Get computer hostname and username
6. Build filename: `{computer}_{user}_{timestamp}_{sessionid}.jsonl`
7. Store in `.pkg$log_file`

```r
# Lines 32-37: register_callback()
register_callback <- function() {
  if (is.null(.pkg$callback_id)) {
    .pkg$callback_id <- addTaskCallback(logger_callback, name = "rlogger")
  }
}
```
**What it does:**
- Registers `logger_callback()` with R's task callback system
- Only registers if not already registered (idempotent)
- Stores callback ID for later removal

```r
# Lines 40-46: deregister_callback()
deregister_callback <- function() {
  if (!is.null(.pkg$callback_id)) {
    removeTaskCallback("rlogger")
    .pkg$callback_id <- NULL
  }
}
```
**What it does:**
- Removes callback by name
- Clears stored callback ID

```r
# Lines 49-78: logger_callback()
logger_callback <- function(expr, value, ok, visible) {
  tryCatch({
    # ... logging logic
    return(TRUE)
  }, error = function(e) {
    # Silent failure
    return(TRUE)
  })
}
```
**What it does:**

1. **Wrapped in `tryCatch()`** - Never break user's session
2. **Increment counter** - Track command number
3. **Deparse expression**:
   ```r
   cmd_text <- paste(deparse(expr, width.cutoff = 500L), collapse = "\n")
   ```
   - `deparse()` converts expression to string
   - `width.cutoff = 500` prevents excessive line wrapping
   - `paste(..., collapse = "\n")` joins multi-line expressions
4. **Build metadata object**:
   ```r
   metadata <- list(
     timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3", tz = "UTC"),
     session_id = .pkg$session_id,
     user = as.character(Sys.info()["user"]),
     computer = as.character(Sys.info()["nodename"]),
     command = cmd_text,
     command_number = .pkg$command_count,
     success = ok
   )
   ```
   - Timestamp in ISO 8601 format (e.g., `2026-03-27T14:30:52.123`)
   - User from `Sys.info()` (system username)
   - Computer from `Sys.info()` (hostname)
5. **Write immediately** - Call `write_log_entry(metadata)`
6. **Return TRUE** - Keep callback registered

```r
# Lines 81-99: write_log_entry()
write_log_entry <- function(metadata) {
  tryCatch({
    jsonl_line <- jsonlite::toJSON(metadata, auto_unbox = TRUE)
    conn <- file(.pkg$log_file, open = "a")
    on.exit(close(conn), add = TRUE)
    writeLines(jsonl_line, conn)
    flush(conn)
  }, error = function(e) {
    # Silent failure
  })
}
```
**What it does:**

1. **Convert to JSON**:
   ```r
   jsonlite::toJSON(metadata, auto_unbox = TRUE)
   ```
   - `auto_unbox = TRUE` - Scalars remain scalars (not arrays)
   - Produces: `{"timestamp":"2026-03-27...","user":"jsmith",...}`

2. **Open file in append mode**:
   ```r
   conn <- file(.pkg$log_file, open = "a")
   ```
   - `"a"` mode - append (don't overwrite)
   - Creates file if doesn't exist

3. **Ensure file closes**:
   ```r
   on.exit(close(conn), add = TRUE)
   ```
   - Guarantees file closes even if error occurs
   - `add = TRUE` - Don't overwrite other on.exit handlers

4. **Write line**:
   ```r
   writeLines(jsonl_line, conn)
   ```
   - Writes JSON line with newline

5. **Force flush**:
   ```r
   flush(conn)
   ```
   - Forces OS to write to disk immediately
   - Ensures data is persisted (not just in buffer)

```r
# Lines 102-125: Public API functions
flush_logs()        # No-op (already immediate flush)
disable_logging()   # Deregister callback
get_session_id()    # Return session UUID
get_log_file()      # Return log file path
```

### R/zzz.R

**Purpose:** Package lifecycle hooks

**Special filename:** `.R` files starting with `z` are loaded last (convention)

**Functions:**

#### `.onAttach()`

Called when package is attached (via `library()` or auto-load):

```r
.onAttach <- function(libname, pkgname) {
  init_logger()
  register_callback()
  packageStartupMessage(...)
}
```

**Why `.onAttach()` not `.onLoad()`?**
- `.onLoad()` - Called when namespace is loaded (earlier)
- `.onAttach()` - Called when package is attached to search path
- We want startup message only when user explicitly loads, not just when imported

#### `.onUnload()`

Called when package namespace is unloaded:

```r
.onUnload <- function(libpath) {
  deregister_callback()
}
```

Ensures callback is removed when package is detached.

---

## How R Packages Work

### Package Installation

When you run:
```bash
R CMD INSTALL rlogger_0.1.0.tar.gz
```

R does the following:

1. **Extract tarball** to temporary directory
2. **Check DESCRIPTION** file for dependencies
3. **Check if dependencies installed** (install if not)
4. **Check R version** requirement
5. **Compile code** (if C/C++ present - not applicable here)
6. **Copy files** to library directory (e.g., `/usr/lib/R/library/`)
7. **Build namespace** from NAMESPACE file
8. **Create documentation** (if present)
9. **Add to installed packages** database

**Result:** Package is available for loading via `library(rlogger)`

### Package Loading

When you run:
```r
library(rlogger)
```

R does the following:

1. **Check if already loaded** (skip if yes)
2. **Find package** in library paths
3. **Load dependencies** (jsonlite, uuid)
4. **Load namespace** from NAMESPACE file
5. **Execute `.onLoad()` hook** (if present)
6. **Attach to search path** (makes exported functions available)
7. **Execute `.onAttach()` hook** (if present)

**Result:** Package is loaded and ready to use

### Search Path

When package is loaded, it's added to the search path:

```r
> search()
[1] ".GlobalEnv"        "package:rlogger"   "package:stats"
[4] "package:graphics"  "package:grDevices" "package:utils"
```

Functions from `package:rlogger` can now be called directly:
```r
get_log_file()  # No need for rlogger::get_log_file()
```

---

## Auto-Loading Mechanism

### The Problem

Users need to call `library(rlogger)` in every R session.

### The Solution

Use R's system-wide startup file: **Rprofile.site**

### How It Works

**Location of Rprofile.site:**
```bash
# Linux/Mac
/usr/lib/R/etc/Rprofile.site

# Windows
C:\Program Files\R\R-4.x.x\etc\Rprofile.site
```

**R's startup sequence:**

1. R starts
2. R reads `R_HOME/etc/Renviron.site` (environment variables)
3. R reads `R_HOME/etc/Rprofile.site` (system-wide profile)
4. R reads `~/.Renviron` (user environment)
5. R reads `~/.Rprofile` (user profile)
6. R executes `.First()` function if defined
7. Ready for user input

**Our configuration in Rprofile.site:**

```r
.First <- function() {
  suppressPackageStartupMessages({
    if (requireNamespace("rlogger", quietly = TRUE)) {
      library(rlogger)
    } else {
      warning("rlogger package not found - command logging disabled")
    }
  })
}
```

**What this does:**

1. **`.First()`** - Special function executed on startup
2. **`suppressPackageStartupMessages()`** - Hides normal startup messages
3. **`requireNamespace()`** - Check if package exists (don't error if missing)
4. **`library(rlogger)`** - Load package if found
5. **`warning()`** - Alert if package not installed

**Result:** Every R session automatically loads rlogger without user intervention!

### Environment Variables

**Setting RLOGGER_PATH:**

Option 1: `/etc/environment` (Linux)
```bash
RLOGGER_PATH="/network/share/r_logs"
```

Option 2: `/etc/profile.d/rlogger.sh` (Linux)
```bash
export RLOGGER_PATH="/network/share/r_logs"
```

Option 3: System Environment Variables (Windows)
```
RLOGGER_PATH=\\network\share\r_logs
```

**Why environment variable?**
- Allows configuration without modifying code
- Different environments (dev/prod) can use different paths
- Easy to override per-user if needed

---

## Logging Flow

### Complete Flow Diagram

```
┌──────────────────────────────────────────────────────────┐
│ SYSTEM STARTUP                                           │
├──────────────────────────────────────────────────────────┤
│ 1. R starts                                              │
│ 2. R reads Rprofile.site                                 │
│ 3. .First() executes                                     │
│ 4. library(rlogger) called                               │
│ 5. .onAttach() executes                                  │
│    ├─ init_logger()                                      │
│    │  ├─ Generate UUID                                   │
│    │  ├─ Read RLOGGER_PATH env var                       │
│    │  ├─ Get computer and user                           │
│    │  └─ Create log filename                             │
│    └─ register_callback()                                │
│       └─ addTaskCallback(logger_callback)                │
│ 6. Startup message displayed                             │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ USER EXECUTES COMMAND: x <- 1 + 1                       │
├──────────────────────────────────────────────────────────┤
│ 1. R parses command                                      │
│ 2. R evaluates command                                   │
│ 3. R calls registered task callbacks                     │
│ 4. logger_callback() executes                            │
│    ├─ Increment command_count                            │
│    ├─ deparse(expr) → "x <- 1 + 1"                      │
│    ├─ Collect metadata                                   │
│    │  ├─ Sys.time() → timestamp                          │
│    │  ├─ session_id                                      │
│    │  ├─ Sys.info()["user"] → username                   │
│    │  ├─ Sys.info()["nodename"] → computer               │
│    │  ├─ command text                                    │
│    │  ├─ command_number                                  │
│    │  └─ success (ok parameter)                          │
│    └─ write_log_entry(metadata)                          │
│       ├─ toJSON(metadata) → JSON string                  │
│       ├─ file(..., "a") → open for append                │
│       ├─ writeLines() → write JSON                       │
│       ├─ flush() → force to disk                         │
│       └─ close() → close file                            │
│ 5. Return TRUE (keep callback active)                    │
│ 6. R continues (user sees result)                        │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
                   (repeat for each command)
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ SESSION END                                              │
├──────────────────────────────────────────────────────────┤
│ 1. User quits R or detaches package                      │
│ 2. .onUnload() executes                                  │
│ 3. deregister_callback()                                 │
│    └─ removeTaskCallback("rlogger")                      │
│ 4. Package unloaded                                      │
└──────────────────────────────────────────────────────────┘
```

### Timing Analysis

**Per-command overhead:**

| Operation | Time |
|-----------|------|
| Callback invocation | ~0.1 ms |
| deparse() | ~0.5 ms |
| Metadata collection | ~0.2 ms |
| toJSON() | ~0.5 ms |
| File open/write/close | ~2-5 ms |
| **Total** | **~3-6 ms** |

**Impact:**
- For interactive use: negligible (users type slowly)
- For batch scripts: ~3-6 seconds per 1000 commands
- Acceptable trade-off for audit requirements

---

## Performance Considerations

### I/O Optimization

**Why immediate flush instead of buffering?**

| Approach | Pros | Cons |
|----------|------|------|
| **Buffering** | Fewer file operations, faster | Data loss on crash |
| **Immediate flush** | No data loss, real-time logs | More I/O operations |

We chose immediate flush because:
- Audit requirements prioritize reliability over speed
- Performance impact is minimal for interactive use
- No buffer management complexity

**File I/O details:**

1. **Append mode (`"a"`)** - Fast, no need to read existing content
2. **Unbuffered writes** - `flush(conn)` forces to disk
3. **Per-session files** - No lock contention between sessions

### Memory Usage

**Package memory footprint:**

- **`.pkg` environment:** ~1 KB
  - session_id (UUID): 36 bytes
  - log_path (string): ~50-200 bytes
  - log_file (string): ~50-200 bytes
  - command_count (integer): 8 bytes
  - callback_id (pointer): 8 bytes

- **Callback function:** ~1-2 KB (code)
- **Per-command overhead:** ~0 (no buffering)

**Total:** ~2-3 KB (negligible)

### CPU Usage

**Per-command CPU operations:**

1. String operations: `deparse()`, `paste()`, `format()`
2. JSON serialization: `toJSON()`
3. File I/O: `writeLines()`

All operations are O(n) where n = command length. For typical commands (<100 chars), this is fast.

---

## Security Considerations

### Data Sensitivity

**What gets logged:**
- ✅ All R commands (including sensitive ones)
- ✅ Passwords typed in code
- ✅ API keys in code
- ✅ Personal data manipulations

**Mitigations:**

1. **Secure log directory:**
   ```bash
   # Admin-only read
   chmod 733 /network/share/r_logs

   # Or users can read own logs
   chmod 1777 /network/share/r_logs
   ```

2. **Network security:**
   - Use VPN or private network for log share
   - Encrypt logs in transit (SMB encryption, SSH, etc.)

3. **Retention policy:**
   - Rotate logs after 90 days
   - Archive to secure storage
   - Delete after retention period

### User Privacy

**What's captured:**
- Username (system user)
- Computer hostname
- Commands executed
- Session timing

**Not captured:**
- Command results/output
- Variables values (unless in command)
- File contents (unless read in command)

### Preventing Circumvention

**Users could disable logging by:**

1. **Calling `disable_logging()`**
   - Mitigation: Don't document this function
   - Or remove from exports

2. **Removing callback manually:**
   ```r
   removeTaskCallback("rlogger")
   ```
   - Mitigation: Monitor for missing log files
   - Educate users on policy

3. **Modifying Rprofile.site:**
   - Mitigation: Requires admin access
   - Set proper file permissions

4. **Using own .Rprofile:**
   ```r
   # ~/.Rprofile
   removeTaskCallback("rlogger")
   ```
   - Mitigation: `.First()` in user profile runs after system
   - Re-register callback in periodic timer (advanced)

**Best approach:** Combine technical controls with policy and training.

---

## Troubleshooting

### Common Issues

#### 1. Package doesn't auto-load

**Symptoms:** R starts but no rlogger message

**Debug:**
```r
# Check if package is installed
library(rlogger)

# Check Rprofile.site
cat(readLines("/usr/lib/R/etc/Rprofile.site"), sep="\n")

# Check if .First is defined
exists(".First")
```

**Solutions:**
- Verify Rprofile.site contains `.First()` function
- Check package is installed system-wide
- Ensure no syntax errors in Rprofile.site

#### 2. Logs not being created

**Symptoms:** Package loads but no log files

**Debug:**
```r
# Check log file path
get_log_file()

# Check if directory exists
dir.exists(dirname(get_log_file()))

# Check if callback is registered
"rlogger" %in% getTaskCallbackNames()

# Try writing manually
cat("test", file=get_log_file())
```

**Solutions:**
- Verify `RLOGGER_PATH` environment variable is set
- Check directory permissions
- Verify network share is mounted

#### 3. Permission denied errors

**Symptoms:** Errors about can't write to log file

**Debug:**
```bash
# Check directory permissions
ls -ld /network/share/r_logs

# Try creating file manually
touch /network/share/r_logs/test.txt

# Check if user can write
ls -l /network/share/r_logs/test.txt
```

**Solutions:**
- Set directory to world-writable: `chmod 1777`
- Check network mount permissions
- Verify no quota limits

#### 4. Callback not capturing commands

**Symptoms:** Log file created but empty

**Debug:**
```r
# Check if callback is registered
getTaskCallbackNames()

# Check command count
rlogger:::.pkg$command_count

# Test logging manually
rlogger:::write_log_entry(list(test="hello"))
```

**Solutions:**
- Deregister and re-register callback
- Check for errors in callback function
- Verify no other packages interfering

---

## Extending the Package

### Adding More Metadata

To capture additional metadata (e.g., RStudio detection, working directory):

**Edit `R/rlogger.R`, in `logger_callback()`:**

```r
# Collect metadata
metadata <- list(
  timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3", tz = "UTC"),
  session_id = .pkg$session_id,
  user = as.character(Sys.info()["user"]),
  computer = as.character(Sys.info()["nodename"]),
  command = cmd_text,
  command_number = .pkg$command_count,
  success = ok,

  # NEW FIELDS
  working_dir = getwd(),
  r_version = paste(R.version$major, R.version$minor, sep="."),
  platform = R.version$platform,
  rstudio = if (requireNamespace("rstudioapi", quietly=TRUE)) {
    rstudioapi::isAvailable()
  } else {
    FALSE
  }
)
```

**Don't forget to update:**
- DESCRIPTION (add rstudioapi to Suggests)
- Documentation

### Adding File Locking

If you decide to use shared log files instead of per-session files:

**Add locking mechanism:**

```r
acquire_lock <- function(lock_file, timeout = 3) {
  start <- Sys.time()
  while (difftime(Sys.time(), start, units="secs") < timeout) {
    if (!file.exists(lock_file)) {
      writeLines(as.character(Sys.getpid()), lock_file)
      Sys.sleep(0.01)
      if (file.exists(lock_file)) return(TRUE)
    }
    Sys.sleep(0.05)
  }
  return(FALSE)
}

release_lock <- function(lock_file) {
  unlink(lock_file)
}

# Use in write_log_entry():
lock_file <- paste0(.pkg$log_file, ".lock")
if (acquire_lock(lock_file)) {
  # ... write logic ...
  release_lock(lock_file)
}
```

### Adding Local Cache

For network reliability, add local caching:

```r
write_log_entry <- function(metadata) {
  # Try network first
  success <- try_write_to_network(metadata)

  if (!success) {
    # Fall back to local cache
    write_to_cache(metadata)
  }
}

write_to_cache <- function(metadata) {
  cache_dir <- "~/.rlogger/cache"
  dir.create(cache_dir, recursive=TRUE, showWarnings=FALSE)
  cache_file <- file.path(cache_dir, paste0(.pkg$session_id, ".jsonl"))
  # ... write to cache ...
}

# Periodically try to sync cache
sync_cache <- function() {
  # Read cache files
  # Try writing to network
  # Delete cache on success
}
```

### Adding Filtering

To redact sensitive patterns:

```r
redact_command <- function(cmd) {
  # Redact password patterns
  cmd <- gsub("password\\s*=\\s*['\"].*?['\"]",
              "password='***REDACTED***'", cmd, ignore.case=TRUE)

  # Redact API keys
  cmd <- gsub("api_key\\s*=\\s*['\"].*?['\"]",
              "api_key='***REDACTED***'", cmd, ignore.case=TRUE)

  return(cmd)
}

# Use in logger_callback:
cmd_text <- redact_command(cmd_text)
```

### Adding Analytics Functions

Add functions to analyze logs:

```r
#' Read all log files for a date range
#' @export
read_logs <- function(start_date, end_date, user=NULL, computer=NULL) {
  # ... implementation ...
}

#' Get command statistics
#' @export
get_stats <- function(log_files) {
  # ... implementation ...
}
```

---

## Building and Distributing

### Building the Package

```bash
# From directory containing Rlogger/
cd /Users/ishmeet

# Build package
R CMD build Rlogger

# Output: rlogger_0.1.0.tar.gz
```

### Checking the Package

```bash
# Run checks
R CMD check rlogger_0.1.0.tar.gz

# Run without manual (if no documentation)
R CMD check --no-manual rlogger_0.1.0.tar.gz
```

### Installing

```bash
# System-wide (requires sudo)
sudo R CMD INSTALL rlogger_0.1.0.tar.gz --library=/usr/local/lib/R/site-library

# User-level
R CMD INSTALL rlogger_0.1.0.tar.gz
```

### Distributing

**Option 1: Network share**
```bash
# Place package on network share
cp rlogger_0.1.0.tar.gz /network/share/packages/

# Install from share on each computer
sudo R CMD INSTALL /network/share/packages/rlogger_0.1.0.tar.gz
```

**Option 2: Internal CRAN**
```bash
# Set up internal CRAN repository
# See: https://rstudio.github.io/packrat/custom-repos.html
```

**Option 3: Automation (Recommended)**
```bash
# Use Ansible, Puppet, or similar
# Deploy to all 40-50 computers automatically
```

---

## Summary

### Key Technical Points

1. **Language**: Pure R (no C/C++)
2. **Dependencies**: jsonlite + uuid only
3. **Mechanism**: R task callbacks (`addTaskCallback`)
4. **Storage**: JSONL (JSON Lines) format
5. **Architecture**: Per-session files (no locking needed)
6. **Auto-load**: Via Rprofile.site + .First()
7. **Performance**: ~3-6ms overhead per command
8. **Memory**: ~2-3 KB total footprint

### Package Components

| Component | Purpose | Location |
|-----------|---------|----------|
| DESCRIPTION | Metadata | Root |
| NAMESPACE | Public API | Root |
| R/rlogger.R | Core logic | R/ |
| R/zzz.R | Lifecycle hooks | R/ |
| *.md files | Documentation | Root |

### Installation Components

| Component | Purpose | Location |
|-----------|---------|----------|
| Package | Code + metadata | R library dir |
| Rprofile.site | Auto-load config | R_HOME/etc/ |
| Environment var | Log path | /etc/environment |
| Log directory | Storage | Network share |

### Data Flow

```
User command → Task callback → Deparse → Metadata → JSON → File → Disk
```

**Time:** ~3-6ms total

### Files Created

```
{COMPUTER}_{USER}_{TIMESTAMP}_{SESSION-ID}.jsonl
```

**Example:** `mac-finance01_jsmith_20260327_143052_a1b2c3d4.jsonl`

**Content:** One JSON object per line (JSONL format)

---

## Additional Resources

### R Package Development
- Writing R Extensions: https://cran.r-project.org/doc/manuals/r-release/R-exts.html
- R Packages book: https://r-pkgs.org/
- Task callbacks: `?addTaskCallback`

### JSON Lines Format
- Specification: https://jsonlines.org/
- jsonlite package: https://cran.r-project.org/package=jsonlite

### UUID
- UUID RFC: https://tools.ietf.org/html/rfc4122
- uuid package: https://cran.r-project.org/package=uuid

### Enterprise R Deployment
- R Admin Manual: https://cran.r-project.org/doc/manuals/r-release/R-admin.html
- RStudio Server: https://www.rstudio.com/products/rstudio/download-server/

---

**Document version:** 1.0
**Last updated:** 2026-03-27
**Package version:** 0.1.0
