<#
.SYNOPSIS
    Zips the channel and sideloads it to the Roku dev installer.
.DESCRIPTION
    Reads ROKU_HOST and ROKU_DEV_PASSWORD from .env (git-ignored; copy .env.example).
    Uses the curl.exe that ships with Windows, so Node isn't needed.
.EXAMPLE
    .\deploy.ps1            # build and install
    .\deploy.ps1 -ZipOnly   # just build out\immich-roku.zip
#>
param([switch]$ZipOnly)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$include = @('manifest', 'source', 'components', 'images')

function Read-DotEnv([string]$path) {
    $values = @{}
    if (Test-Path $path) {
        foreach ($line in Get-Content $path) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $values[$Matches[1]] = $Matches[2] }
        }
    }
    return $values
}

function New-ChannelZip([string]$zipPath) {
    # Built by hand so entry names use forward slashes (Compress-Archive on PS 5.1 writes backslashes).
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try {
        foreach ($item in $include) {
            $path = Join-Path $root $item
            if (-not (Test-Path $path)) { continue }
            foreach ($file in Get-ChildItem $path -Recurse -File) {
                $entry = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
                [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry, 'Optimal')
            }
        }
    } finally {
        $zip.Dispose()
    }
}

$outDir = Join-Path $root 'out'
New-Item -ItemType Directory -Force $outDir | Out-Null
$zipPath = Join-Path $outDir 'immich-roku.zip'
New-ChannelZip $zipPath
Write-Host "Built $zipPath"
if ($ZipOnly) { return }

$config = Read-DotEnv (Join-Path $root '.env')
$rokuHost = $config['ROKU_HOST']
$password = $config['ROKU_DEV_PASSWORD']
if (-not $rokuHost -or -not $password) { throw 'Set ROKU_HOST and ROKU_DEV_PASSWORD in .env (copy .env.example).' }

Write-Host "Uploading to $rokuHost ..."
$result = & curl.exe --silent --show-error --max-time 120 --digest --user "rokudev:$password" `
    -F 'mysubmit=Install' -F "archive=@$zipPath" "http://$rokuHost/plugin_install"
if ($LASTEXITCODE -ne 0) { throw "Upload failed (curl exit code $LASTEXITCODE). Is the Roku on and in developer mode?" }

$text = $result -join "`n"
if ($text -match 'Identical to previous version') {
    Write-Host 'Roku already has this exact build; nothing changed.'
} elseif ($text -match 'Install Success|Application Received') {
    Write-Host "Installed. Debug console: telnet $rokuHost 8085"
} elseif ($text -match '401|Unauthorized') {
    throw 'The Roku rejected the dev password. Check ROKU_DEV_PASSWORD in .env.'
} else {
    $messages = [regex]::Matches($text, '"text"\s*:\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value }
    if ($messages) { $messages | ForEach-Object { Write-Host $_ } } else { Write-Host $text }
    throw 'Install did not report success.'
}
