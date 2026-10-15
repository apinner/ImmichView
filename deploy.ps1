<#
.SYNOPSIS
    Zips the channel and sideloads it to the Roku dev installer.
.DESCRIPTION
    Reads ROKU_HOST and ROKU_DEV_PASSWORD from .env (git-ignored; copy .env.example).
    For another Roku pass -RokuHost; its password comes from ROKU_DEV_PASSWORD_<ip with
    dots as underscores> in .env if set (e.g. ROKU_DEV_PASSWORD_10_10_10_164), else ROKU_DEV_PASSWORD.
    Uses the curl.exe that ships with Windows, so Node isn't needed.
    Builds a dev build (bs_const DEV=true: debug logging and dev launch parameters) unless
    -Release is given, which keeps the manifest's DEV=false as in store builds.
    Two apps come from this repo: ImmichView (default) and, with -Screensaver, the separate
    ImmichView Screensaver app (manifest.screensaver; Roku only allows standalone screensavers).
    A Roku holds one sideloaded app at a time, so installing one replaces the other.
.EXAMPLE
    .\deploy.ps1                          # build and install on ROKU_HOST
    .\deploy.ps1 -Screensaver             # build and install the screensaver app instead
    .\deploy.ps1 -RokuHost 10.10.10.164   # install on another Roku
    .\deploy.ps1 -Release                 # install a release build (as published)
    .\deploy.ps1 -ZipOnly                 # just build out\immich-roku.zip
#>
param([switch]$ZipOnly, [string]$RokuHost, [switch]$Release, [switch]$Screensaver)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
# Files and folders in each app; the manifest is written into the zip separately.
if ($Screensaver) {
    $manifestFile = 'manifest.screensaver'
    $include = @('source\screensaver.brs', 'source\common', 'components\screensaver', 'components\tasks',
        'components\widgets\ProgressRing.xml', 'components\widgets\ProgressRing.brs',
        'images\channel-poster-screensaver_fhd.png', 'images\channel-poster-screensaver_hd.png', 'images\ring-half.png', 'images\ring-track.png',
        'images\splash-screen_fhd.jpg', 'images\splash-screen_hd.jpg', 'images\splash-screen_sd.jpg')
    # The dev-only Main; release builds leave it out (Roku doesn't allow Main in a screensaver).
    if (-not $Release) { $include += 'source\screensaver-dev.brs' }
    $zipName = 'immich-roku-screensaver.zip'
} else {
    $manifestFile = 'manifest'
    $include = @('source\main.brs', 'source\common', 'components', 'images')
    $exclude = @('components\screensaver')
    $zipName = 'immich-roku.zip'
}

function Read-DotEnv([string]$path) {
    $values = @{}
    if (Test-Path $path) {
        foreach ($line in Get-Content $path) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $values[$Matches[1]] = $Matches[2] }
        }
    }
    return $values
}

function New-ChannelZip([string]$zipPath, [bool]$devBuild) {
    # Built by hand so entry names use forward slashes (Compress-Archive on PS 5.1 writes backslashes).
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    if (Test-Path $zipPath) { Remove-Item $zipPath }
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try {
        $text = Get-Content (Join-Path $root $manifestFile) -Raw
        if ($devBuild) {
            $text = $text -replace '(?m)^bs_const=DEV=false', 'bs_const=DEV=true'
            # Tells the sideloaded screensaver apart from an installed one in Settings > Theme > Screensavers.
            $text = $text -replace '(?m)^screensaver_title=ImmichView\s*$', 'screensaver_title=ImmichView (dev)'
        }
        $writer = New-Object IO.StreamWriter ($zip.CreateEntry('manifest').Open())
        $writer.Write($text)
        $writer.Dispose()
        foreach ($item in $include) {
            $path = Join-Path $root $item
            if (-not (Test-Path $path)) { throw "Missing $item" }
            foreach ($file in Get-ChildItem $path -Recurse -File) {
                $relative = $file.FullName.Substring($root.Length + 1)
                if ($exclude | Where-Object { $relative.StartsWith($_ + '\') }) { continue }
                [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relative.Replace('\', '/'), 'Optimal')
            }
        }
    } finally {
        $zip.Dispose()
    }
}

$outDir = Join-Path $root 'out'
New-Item -ItemType Directory -Force $outDir | Out-Null
$zipPath = Join-Path $outDir $zipName
New-ChannelZip $zipPath (-not $Release)
if ($Release) { Write-Host "Built $zipPath (release)" } else { Write-Host "Built $zipPath (dev)" }
if ($ZipOnly) { return }

$config = Read-DotEnv (Join-Path $root '.env')
$targetHost = $config['ROKU_HOST']
if ($RokuHost) { $targetHost = $RokuHost }
$password = $config['ROKU_DEV_PASSWORD']
$hostPassword = $config['ROKU_DEV_PASSWORD_' + ($targetHost -replace '\.', '_')]
if ($hostPassword) { $password = $hostPassword }
if (-not $targetHost -or -not $password) { throw 'Set ROKU_HOST and ROKU_DEV_PASSWORD in .env (copy .env.example).' }

Write-Host "Uploading to $targetHost ..."
$result = & curl.exe --silent --show-error --max-time 120 --digest --user "rokudev:$password" `
    -F 'mysubmit=Install' -F "archive=@$zipPath" "http://$targetHost/plugin_install"
if ($LASTEXITCODE -ne 0) { throw "Upload failed (curl exit code $LASTEXITCODE). Is the Roku on and in developer mode?" }

$text = $result -join "`n"
if ($text -match 'Identical to previous version') {
    Write-Host 'Roku already has this exact build; nothing changed.'
} elseif ($text -match 'Install Success|Application Received') {
    Write-Host "Installed. Debug console: telnet $targetHost 8085"
} elseif ($text -match '401|Unauthorized') {
    throw "$targetHost rejected the dev password. Check ROKU_DEV_PASSWORD (or ROKU_DEV_PASSWORD_$($targetHost -replace '\.', '_')) in .env."
} else {
    $messages = [regex]::Matches($text, '"text"\s*:\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value }
    if ($messages) { $messages | ForEach-Object { Write-Host $_ } } else { Write-Host $text }
    throw 'Install did not report success.'
}
