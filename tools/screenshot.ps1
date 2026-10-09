<#
.SYNOPSIS
    Saves a screenshot of the running dev channel to out\screenshot.jpg (or -OutFile).
    Uses ROKU_HOST and ROKU_DEV_PASSWORD from .env.
#>
param([string]$OutFile)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $OutFile) { $OutFile = Join-Path $root 'out\screenshot.jpg' }
New-Item -ItemType Directory -Force (Split-Path $OutFile -Parent) | Out-Null

$config = @{}
foreach ($line in Get-Content (Join-Path $root '.env')) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $config[$Matches[1]] = $Matches[2] }
}
$rokuHost = $config['ROKU_HOST']
$user = "rokudev:$($config['ROKU_DEV_PASSWORD'])"

& curl.exe --silent --show-error --max-time 30 --digest --user $user `
    -F 'mysubmit=Screenshot' -F 'passwd=' -F 'archive=' "http://$rokuHost/plugin_inspect" | Out-Null
& curl.exe --silent --show-error --max-time 30 --digest --user $user -o $OutFile "http://$rokuHost/pkgs/dev.jpg"
if ($LASTEXITCODE -ne 0) { throw "Screenshot download failed (curl exit code $LASTEXITCODE)." }
Write-Host "Saved $OutFile"
