# Deployment Guide - Auto-Loading rlogger

This guide shows how to set up rlogger so it **automatically loads** for all users without them needing to do anything.

## Goal

Once deployed:
- ✅ Users start R → rlogger loads automatically
- ✅ All commands are logged immediately
- ✅ Users don't need to install or load anything
- ✅ Works for RStudio and base R

## Deployment Steps

### Step 1: Install Package System-Wide

Install the package in a system library where all users can access it:

#### On Linux/Mac:

```bash
# As root/sudo
sudo R CMD INSTALL rlogger_0.1.0.tar.gz --library=/usr/local/lib/R/site-library

# Verify installation
sudo R -e "library(rlogger)"
```

#### On Windows:

```powershell
# As Administrator
R CMD INSTALL rlogger_0.1.0.tar.gz --library="C:\Program Files\R\R-4.x.x\library"

# Verify installation
R -e "library(rlogger)"
```

### Step 2: Set System-Wide Environment Variable

Configure the log path that all users will use:

#### On Linux/Mac:

```bash
# Option A: System-wide environment variable (/etc/environment)
sudo sh -c 'echo "RLOGGER_PATH=/network/share/r_logs" >> /etc/environment'

# Option B: Profile script (/etc/profile.d/rlogger.sh)
sudo tee /etc/profile.d/rlogger.sh << 'EOF'
export RLOGGER_PATH="/network/share/r_logs"
EOF

# Users need to log out and back in for this to take effect
```

#### On Windows:

```powershell
# As Administrator - Set system environment variable
[System.Environment]::SetEnvironmentVariable(
    "RLOGGER_PATH",
    "\\network\share\r_logs",
    [System.EnvironmentVariableTarget]::Machine
)

# Users need to restart their R sessions
```

### Step 3: Configure Auto-Load via Rprofile.site

Edit the system-wide R profile to automatically load rlogger:

#### On Linux/Mac:

```bash
# Find Rprofile.site location
R -e "R.home('etc')"
# Typically: /usr/lib/R/etc or /Library/Frameworks/R.framework/Resources/etc

# Edit Rprofile.site
sudo nano /usr/lib/R/etc/Rprofile.site

# Add the following at the end:
```

```r
# Auto-load rlogger for audit logging
.First <- function() {
  if (interactive() || !interactive()) {  # Load in all modes
    suppressPackageStartupMessages({
      if (requireNamespace("rlogger", quietly = TRUE)) {
        library(rlogger)
      } else {
        warning("rlogger package not found - command logging disabled")
      }
    })
  }
}
```

#### On Windows:

```powershell
# Find Rprofile.site location
R -e "R.home('etc')"
# Typically: C:\Program Files\R\R-4.x.x\etc

# Edit the file (as Administrator)
notepad "C:\Program Files\R\R-4.x.x\etc\Rprofile.site"

# Add the same .First function shown above
```

### Step 4: Create Log Directory

Ensure the log directory exists and has correct permissions:

```bash
# Create directory
sudo mkdir -p /network/share/r_logs

# Set permissions (all users can write, only admins can read)
sudo chmod 733 /network/share/r_logs

# Or if users should be able to read their own logs:
sudo chmod 777 /network/share/r_logs
```

### Step 5: Test on One Computer First

Before deploying to all 40-50 computers:

```bash
# Start R as a test user
R
```

You should see:
```
rlogger: Command logging active
  Log file: /network/share/r_logs/hostname_username_20260327_143052_a1b2c3d4.jsonl
  Session ID: a1b2c3d4...
  Mode: Immediate flush (every command logged instantly)
```

Execute some commands and verify the log file is created:
```r
x <- 1 + 1
get_log_file()
readLines(get_log_file())
```

### Step 6: Deploy to All Computers

Once verified working:

1. **Install package** on all computers (Steps 1)
2. **Set environment variable** on all computers (Step 2)
3. **Update Rprofile.site** on all computers (Step 3)
4. **Notify users** to restart R sessions

## Log File Naming Convention

Each session creates a log file with format:

```
{COMPUTER}_{USER}_{TIMESTAMP}_{SESSION-ID}.jsonl
```

**Example:**
```
mac-finance01_jsmith_20260327_143052_a1b2c3d4.jsonl
win-analytics03_mjones_20260327_150234_e5f6g7h8.jsonl
linux-dev02_bwilson_20260327_163045_i9j0k1l2.jsonl
```

**Breakdown:**
- `mac-finance01` = Computer hostname
- `jsmith` = Username
- `20260327_143052` = Start time (2026-03-27 14:30:52)
- `a1b2c3d4` = Session ID (first 8 chars)

This makes it easy to:
- ✅ See who ran what
- ✅ See which computer it was on
- ✅ See when the session started
- ✅ Track multiple sessions from same user

## Verification Checklist

After deployment, verify on each computer:

- [ ] R starts without errors
- [ ] rlogger loads automatically (check startup message)
- [ ] Commands are being logged
- [ ] Log files appear in network share
- [ ] Filenames include computer and username
- [ ] Users don't need to do anything manually

## Troubleshooting

### Users don't see rlogger startup message

**Check:**
1. Is package installed? `R -e "library(rlogger)"`
2. Is Rprofile.site configured? `cat /usr/lib/R/etc/Rprofile.site`
3. Is environment variable set? `echo $RLOGGER_PATH`

### Log files not being created

**Check:**
1. Does log directory exist? `ls -la /network/share/r_logs`
2. Do users have write permissions? `ls -ld /network/share/r_logs`
3. Is network share accessible? `touch /network/share/r_logs/test.txt`

### Multiple users have permission issues

**Solution:**
```bash
# Make directory world-writable
sudo chmod 1777 /network/share/r_logs

# The sticky bit (1) prevents users from deleting others' files
```

### Package loads but doesn't log

**Check:**
1. Is callback registered? In R: `getTaskCallbackNames()` should show "rlogger"
2. Get log file path: `rlogger::get_log_file()`
3. Check for errors: Look for error messages during package load

## Alternative: Per-User Installation

If you can't install system-wide, you can deploy per-user:

### Create a setup script that each user runs once:

```bash
#!/bin/bash
# File: setup_rlogger.sh

# Install package to user library
R -e "install.packages('rlogger_0.1.0.tar.gz', repos=NULL, type='source')"

# Add to user's .Rprofile
cat >> ~/.Rprofile << 'EOF'
if (requireNamespace("rlogger", quietly = TRUE)) {
  suppressPackageStartupMessages(library(rlogger))
}
EOF

# Set environment variable in user's profile
echo 'export RLOGGER_PATH="/network/share/r_logs"' >> ~/.bashrc

echo "rlogger installed! Please restart R."
```

Make executable and distribute:
```bash
chmod +x setup_rlogger.sh
./setup_rlogger.sh
```

## Security Considerations

### Log File Permissions

**Option 1: Admin-only read** (most secure)
```bash
# Users can write but not read
sudo chmod 733 /network/share/r_logs
```

**Option 2: Users can read own logs**
```bash
# World-writable with sticky bit
sudo chmod 1777 /network/share/r_logs
```

### Preventing Users from Disabling

Users could potentially disable logging by:
- Calling `disable_logging()`
- Removing callback
- Modifying their .Rprofile

**Mitigation:**
- Set Rprofile.site (system-level, requires admin to modify)
- Monitor for missing log files
- Educate users that logging is company policy
- Make logs write-only (users can't check if it's working)

## Monitoring and Maintenance

### Daily Checks

```bash
# Count log files created today
find /network/share/r_logs -name "*$(date +%Y%m%d)*.jsonl" | wc -l

# List users who logged today
find /network/share/r_logs -name "*$(date +%Y%m%d)*.jsonl" -exec basename {} \; | cut -d_ -f2 | sort -u

# Check for large log files (possible issues)
find /network/share/r_logs -size +100M -name "*.jsonl"
```

### Log Rotation

Archive old logs to prevent directory bloat:

```bash
#!/bin/bash
# File: rotate_logs.sh

# Archive logs older than 90 days
find /network/share/r_logs -name "*.jsonl" -mtime +90 -exec gzip {} \;

# Move archived logs to archive directory
mkdir -p /network/share/r_logs/archive
find /network/share/r_logs -name "*.jsonl.gz" -exec mv {} /network/share/r_logs/archive/ \;
```

## Uninstalling / Disabling

If you need to disable logging:

```bash
# Remove from Rprofile.site
sudo nano /usr/lib/R/etc/Rprofile.site
# Comment out or remove the .First function

# Or uninstall package entirely
sudo R CMD REMOVE rlogger --library=/usr/local/lib/R/site-library
```

## Summary

**For 40-50 computers, recommended approach:**

1. ✅ System-wide installation (`/usr/local/lib/R/site-library`)
2. ✅ System environment variable (`/etc/environment` or `/etc/profile.d/`)
3. ✅ Auto-load via `Rprofile.site` (`.First` function)
4. ✅ Shared network drive with proper permissions
5. ✅ Test on 1-2 computers first
6. ✅ Deploy to all via automation (Ansible, GPO, etc.)

**Users don't need to:**
- ❌ Install anything
- ❌ Load any library
- ❌ Configure anything
- ❌ Know logging is happening (transparent)

Everything happens automatically when they start R!
