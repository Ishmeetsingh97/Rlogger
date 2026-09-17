#Requires -Version 5.1
<#
.SYNOPSIS
    Installs rlogger machine-wide and configures it to load in every R session.

.DESCRIPTION
    Run from an elevated PowerShell session. This script:
      1. Locates the R installation (registry, else Rscript.exe on PATH).
      2. Installs the rlogger package into the system-wide R library.
      3. Sets RLOGGER_PATH as a machine-level environment variable.
      4. Appends an auto-load hook to Rprofile.site so every R session loads rlogger.
      5. Creates the log directory with append-only style ACLs.

    Safe to re-run: the Rprofile.site hook is added only once.

.PARAMETER Package
    Path to the built package tarball. Defaults to rlogger_0.1.0.tar.gz in the
    current directory. Build it first with: R CMD build .

.PARAMETER LogPath
    Directory that will receive the JSONL logs.

.PARAMETER RHome
    Override R's install root. Auto-detected when omitted.

.EXAMPLE
    .\setup_autoload.ps1

.EXAMPLE
    .\setup_autoload.ps1 -LogPath 'D:\audit\r_logs' -Package .\rlogger_0.1.0.tar.gz
#>
[CmdletBinding()]
param(
    [string]$Package = 'rlogger_0.1.0.tar.gz',
    [string]$LogPath = 'C:\ProgramData\rlogger',
    [string]$RHome
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $ErrorActionPreference does not apply to native executables, so check exit codes by hand.
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments, [string]$What)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$What failed (exit code $LASTEXITCODE): $Exe $($Arguments -join ' ')"
    }
}

function Get-RHomePath {
    # The registry is the authoritative source; 32-bit R registers under WOW6432Node.
    foreach ($key in 'HKLM:\SOFTWARE\R-core\R', 'HKLM:\SOFTWARE\WOW6432Node\R-core\R') {
        if (Test-Path $key) {
            # Guard the property access explicitly: Set-StrictMode throws on a
            # missing property or a property read off $null.
            $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            if ($props -and ($props.PSObject.Properties.Name -contains 'InstallPath')) {
                $installPath = $props.InstallPath
                if ($installPath -and (Test-Path $installPath)) { return $installPath }
            }
        }
    }
    # Fall back to asking R itself, which handles bin\x64 vs bin\i386 layouts for us.
    $rscript = Get-Command 'Rscript.exe' -ErrorAction SilentlyContinue
    if ($rscript) {
        $detected = (& $rscript.Source -e 'cat(R.home())' | Out-String).Trim()
        if ($detected -and (Test-Path $detected)) { return $detected }
    }
    return $null
}

# --- 1. Require elevation -----------------------------------------------------
$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This script must be run as Administrator. Right-click PowerShell and choose "Run as administrator".'
}

# --- 2. Locate R --------------------------------------------------------------
if (-not $RHome) { $RHome = Get-RHomePath }
if (-not $RHome) {
    throw 'Could not find an R installation. Install R, or pass -RHome "C:\Program Files\R\R-4.4.1".'
}

$RExe       = Join-Path $RHome 'bin\R.exe'
$RscriptExe = Join-Path $RHome 'bin\Rscript.exe'
foreach ($exe in $RExe, $RscriptExe) {
    if (-not (Test-Path $exe)) { throw "Expected R executable not found: $exe" }
}

# Use Rscript, not `R -e`: `R -e` echoes the expression and a trailing prompt,
# which corrupts the captured value.
$RLib = (& $RscriptExe -e 'cat(.libPaths()[1])' | Out-String).Trim()
if (-not $RLib) { throw 'Could not determine the R library path.' }

Write-Host "R home:    $RHome"
Write-Host "R library: $RLib"
Write-Host "Log path:  $LogPath"

# --- 3. Install the package ---------------------------------------------------
if (-not (Test-Path $Package)) {
    throw "Package not found: $Package`nBuild it first with: R CMD build ."
}
$PackageFull = (Resolve-Path $Package).Path

Write-Host 'Installing rlogger...'
Invoke-Native -Exe $RExe -Arguments @('CMD', 'INSTALL', $PackageFull, "--library=$RLib") -What 'R CMD INSTALL'

# --- 4. Machine-wide RLOGGER_PATH --------------------------------------------
Write-Host 'Setting RLOGGER_PATH (machine scope)...'
[Environment]::SetEnvironmentVariable('RLOGGER_PATH', $LogPath, 'Machine')
$env:RLOGGER_PATH = $LogPath   # so this session can smoke-test without restarting

# --- 5. Auto-load hook in Rprofile.site --------------------------------------
$Rprofile = Join-Path $RHome 'etc\Rprofile.site'
$existing = if (Test-Path $Rprofile) { Get-Content -Path $Rprofile -Raw } else { '' }

if ($existing -match 'rlogger') {
    Write-Host 'Rprofile.site already references rlogger; leaving it unchanged.'
} else {
    if (Test-Path $Rprofile) {
        Copy-Item -Path $Rprofile -Destination "$Rprofile.backup" -Force
        Write-Host "Backed up existing Rprofile.site to $Rprofile.backup"
    }
    # defaultPackages rather than .First: a user's own ~/.Rprofile can define
    # .First and silently clobber a site-level one, which would defeat auditing.
    $hook = @'

# rlogger: load automatically in every R session (added by setup_autoload.ps1)
local({
  if (nzchar(system.file(package = "rlogger"))) {
    options(defaultPackages = unique(c(getOption("defaultPackages"), "rlogger")))
  }
})
'@
    Add-Content -Path $Rprofile -Value $hook -Encoding ASCII
    Write-Host "Added auto-load hook to $Rprofile"
}

# --- 6. Log directory and ACLs -----------------------------------------------
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null

# Windows analogue of POSIX mode 1777 (sticky bit): any user may create their own
# log file and append to it, but has no rights over log files owned by others.
# Well-known SIDs are used because group names are localized on non-English Windows.
Write-Host 'Applying ACLs...'
Invoke-Native -Exe 'icacls.exe' -Arguments @($LogPath, '/inheritance:r', '/Q') -What 'icacls /inheritance:r'
$aces = @(
    '*S-1-5-32-544:(OI)(CI)F',          # BUILTIN\Administrators - full control
    '*S-1-5-18:(OI)(CI)F',              # NT AUTHORITY\SYSTEM     - full control
    '*S-1-5-32-545:(CI)(WD,AD,X,RA,REA)', # BUILTIN\Users - create files in this folder only
    '*S-1-3-0:(OI)(IO)(W,RA,REA)'       # CREATOR OWNER - write to the file you created
)
foreach ($ace in $aces) {
    Invoke-Native -Exe 'icacls.exe' -Arguments @($LogPath, '/grant:r', $ace, '/Q') -What "icacls /grant:r $ace"
}

Write-Host ''
Write-Host 'Done. Users must sign out and back in (or reboot) to pick up RLOGGER_PATH.'
Write-Host "Verify with: Rscript -e `"library(rlogger); x <- 1+1; cat(get_log_file())`""
