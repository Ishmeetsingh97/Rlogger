param(
    [string]$Package = 'rlogger_0.1.0.tar.gz',
    [string]$LogPath = 'C:\ProgramData\rlogger'
)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run as administrator.'
}

$RHome    = (Get-ItemProperty 'HKLM:\SOFTWARE\R-core\R').InstallPath
$RLib     = (& "$RHome\bin\Rscript.exe" -e 'cat(.libPaths()[1])' | Out-String).Trim()
$Rprofile = "$RHome\etc\Rprofile.site"

& "$RHome\bin\R.exe" CMD INSTALL $Package --library=$RLib
if ($LASTEXITCODE -ne 0) { throw 'R CMD INSTALL failed.' }

[Environment]::SetEnvironmentVariable('RLOGGER_PATH', $LogPath, 'Machine')

if (Test-Path $Rprofile) { Copy-Item $Rprofile "$Rprofile.backup" -Force }
if (-not (Select-String -Path $Rprofile -Pattern 'rlogger' -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content $Rprofile 'if (nzchar(system.file(package = "rlogger"))) options(defaultPackages = unique(c(getOption("defaultPackages"), "rlogger")))'
}

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
icacls $LogPath /grant "*S-1-5-32-545:(OI)(CI)M" /Q

Write-Host 'Done. Users must sign out and back in.'
