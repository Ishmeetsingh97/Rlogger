# rlogger - Quick Reference Card

## 🚀 Installation (One-Time Setup)

```bash
# Automated installation with auto-loading
cd /path/to/Rlogger
sudo ./setup_autoload.sh
```

**That's it!** Every user who starts R will automatically have logging enabled.

---

## 📋 What Gets Logged

Each R session creates a log file:

**Filename format:**
```
{COMPUTER}_{USER}_{TIMESTAMP}_{SESSION-ID}.jsonl
```

**Example:**
```
mac-finance01_jsmith_20260327_143052_a1b2c3d4.jsonl
```

**Log entry format (JSON):**
```json
{
  "timestamp": "2026-03-27T14:30:52.123",
  "session_id": "a1b2c3d4-e5f6-...",
  "user": "jsmith",
  "computer": "mac-finance01",
  "command": "x <- 1 + 1",
  "command_number": 1,
  "success": true
}
```

---

## 🎯 User Experience

### Users see this when starting R:

```
R version 4.2.0 (2022-04-22)
...

rlogger: Command logging active
  Log file: /network/share/r_logs/mac-finance01_jsmith_20260327_143052_a1b2c3d4.jsonl
  Session ID: a1b2c3d4...
  Mode: Immediate flush (every command logged instantly)
  Use get_log_file() to see log path, disable_logging() to stop

>
```

### Users don't need to:
- ❌ Install anything
- ❌ Call `library(rlogger)`
- ❌ Configure anything
- ❌ Remember any commands

### Everything just works automatically!

---

## 🔧 Functions (Optional - For Advanced Users)

```r
get_log_file()      # See current session's log file path
get_session_id()    # Get current session UUID
disable_logging()   # Stop logging (admin override)
flush_logs()        # No-op (already immediate flush)
```

---

## 📁 File Locations

### Package Installation
```
/usr/local/lib/R/site-library/rlogger/
```

### Configuration Files
```
/usr/lib/R/etc/Rprofile.site          # Auto-load config
/etc/environment                       # RLOGGER_PATH variable
```

### Log Files
```
/network/share/r_logs/                 # Or path specified in RLOGGER_PATH
  ├── computer1_user1_20260327_091523_a1b2c3d4.jsonl
  ├── computer2_user2_20260327_093045_e5f6g7h8.jsonl
  └── ...
```

---

## 🔍 Viewing Logs

### From Command Line

```bash
# List today's logs
ls -lh /network/share/r_logs/*$(date +%Y%m%d)*.jsonl

# View a log file
cat /network/share/r_logs/computer_user_20260327_143052_a1b2c3d4.jsonl

# Count entries
wc -l /network/share/r_logs/computer_user_20260327_143052_a1b2c3d4.jsonl

# Search for specific command
grep "library(" /network/share/r_logs/*.jsonl
```

### From R

```r
# Get current session's log
log_file <- get_log_file()

# Read raw JSONL
readLines(log_file)

# Parse as JSON
logs <- jsonlite::stream_in(file(log_file), verbose=FALSE)

# View in data frame
View(logs)

# Filter by command
logs[grepl("library", logs$command), ]

# Get specific fields
logs$command
logs$timestamp
```

---

## 🔒 Security

### Log Directory Permissions

**Admin-only read:**
```bash
sudo chmod 733 /network/share/r_logs
# Users can write but not read (prevents tampering)
```

**Users can read own logs:**
```bash
sudo chmod 1777 /network/share/r_logs
# Sticky bit prevents deleting others' files
```

### What's Logged
- ✅ All R commands (including sensitive ones)
- ✅ Username and computer
- ✅ Timestamps
- ❌ Command output/results (not logged)
- ❌ Variable values (unless in command)

---

## 📊 Common Queries

### Find all logs from a specific user
```bash
ls /network/share/r_logs/*_jsmith_*.jsonl
```

### Find all logs from a specific computer
```bash
ls /network/share/r_logs/mac-finance01_*.jsonl
```

### Count commands in a session
```bash
wc -l /network/share/r_logs/computer_user_20260327_143052_a1b2c3d4.jsonl
```

### Extract all commands from a log
```bash
jq -r '.command' < log_file.jsonl
```

### Find sessions that used a specific package
```bash
grep -l '"library(dplyr)"' /network/share/r_logs/*.jsonl
```

---

## 🛠️ Troubleshooting

| Problem | Solution |
|---------|----------|
| No startup message | Check `/usr/lib/R/etc/Rprofile.site` contains `.First()` |
| Logs not created | Check `RLOGGER_PATH` is set: `echo $RLOGGER_PATH` |
| Permission denied | Check directory permissions: `ls -ld /network/share/r_logs` |
| Package not found | Verify installation: `R -e "library(rlogger)"` |

### Quick Debug

```r
# Check if logging is active
"rlogger" %in% loadedNamespaces()

# Check callback is registered
"rlogger" %in% getTaskCallbackNames()

# Get log file path
get_log_file()

# Check directory exists
dir.exists(dirname(get_log_file()))
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| **README.md** | User guide and features |
| **DEPLOYMENT.md** | Enterprise deployment instructions |
| **TECHNICAL.md** | Complete technical documentation |
| **QUICKSTART.md** | Quick testing guide |
| **QUICK_REFERENCE.md** | This file - one-page reference |
| **setup_autoload.sh** | Automated installation script |

---

## 🎯 For Admins

### Monitoring

```bash
# Count active sessions today
ls /network/share/r_logs/*$(date +%Y%m%d)*.jsonl | wc -l

# See which users logged today
ls /network/share/r_logs/*$(date +%Y%m%d)*.jsonl | \
  xargs -n1 basename | cut -d_ -f2 | sort -u

# Find large log files (possible runaway scripts)
find /network/share/r_logs -size +100M -name "*.jsonl"
```

### Log Rotation

```bash
# Archive logs older than 90 days
find /network/share/r_logs -name "*.jsonl" -mtime +90 -exec gzip {} \;

# Move archives to separate location
mkdir -p /network/share/r_logs/archive
find /network/share/r_logs -name "*.jsonl.gz" -exec mv {} archive/ \;
```

### Deployment to Multiple Computers

**Option 1: Manual**
- Copy `rlogger_0.1.0.tar.gz` to each computer
- Run `setup_autoload.sh` on each

**Option 2: Automated (Recommended)**
- Use Ansible, Puppet, or similar
- Deploy to all 40-50 computers at once

---

## ⚡ Quick Command Cheatsheet

```bash
# Installation
sudo ./setup_autoload.sh

# Check if working
R -e "library(rlogger); get_log_file()"

# View logs
ls -lh /network/share/r_logs/

# Count today's sessions
ls /network/share/r_logs/*$(date +%Y%m%d)*.jsonl | wc -l

# Tail a log in real-time
tail -f /network/share/r_logs/computer_user_*.jsonl

# Parse JSON
cat log.jsonl | jq '.'

# Extract commands only
cat log.jsonl | jq -r '.command'

# Filter by success
cat log.jsonl | jq 'select(.success == true)'
```

---

**Version:** 1.0
**Package:** rlogger 0.1.0
**Updated:** 2026-03-27
