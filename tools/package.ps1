<#
.SYNOPSIS
    Builds the signed store package: installs a release build on the test Roku, has the Roku's
    packager sign it with the key from genkey, and downloads out\packages\ImmichView-<version>.pkg.
    Then reinstalls the dev build (unless -KeepRelease).
.DESCRIPTION
    Needs ROKU_HOST, ROKU_DEV_PASSWORD and ROKU_SIGN_PASSWORD in .env. The Roku must hold the
    signing key (genkey, or rekey from an earlier package). Keep every published package: a
    package plus ROKU_SIGN_PASSWORD is the only way to restore the key onto a Roku.
#>
param([switch]$KeepRelease)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$config = @{}
foreach ($line in Get-Content (Join-Path $root '.env')) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $config[$Matches[1]] = $Matches[2] }
}
$targetHost = $config['ROKU_HOST']
$user = "rokudev:$($config['ROKU_DEV_PASSWORD'])"
$signPassword = $config['ROKU_SIGN_PASSWORD']
if (-not $signPassword) { throw 'Set ROKU_SIGN_PASSWORD in .env (from genkey).' }

$manifest = Get-Content (Join-Path $root 'manifest')
function ManifestValue([string]$key) {
    $line = $manifest | Where-Object { $_ -match "^$key=" } | Select-Object -First 1
    return ($line -replace '^[^=]*=', '').Trim()
}
$version = '{0}.{1}.{2}' -f (ManifestValue 'major_version'), (ManifestValue 'minor_version'), [int](ManifestValue 'build_version')
if ((ManifestValue 'bs_const') -ne 'DEV=false') { throw 'manifest must have bs_const=DEV=false for store builds.' }

Write-Host "Installing release build $version on $targetHost ..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'deploy.ps1') -Release
if ($LASTEXITCODE -ne 0) { throw 'Release install failed.' }

Write-Host 'Signing ...'
$pkgTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$response = & curl.exe --silent --show-error --max-time 180 --digest --user $user `
    -F 'mysubmit=Package' -F "app_name=ImmichView/$version" -F "passwd=$signPassword" -F "pkg_time=$pkgTime" `
    "http://$targetHost/plugin_package"
if ($LASTEXITCODE -ne 0) { throw "Packaging request failed (curl exit code $LASTEXITCODE)." }
$text = $response -join "`n"
$match = [regex]::Match($text, 'pkgs/+([^"''<>\s]+\.pkg)')
if (-not $match.Success) {
    $messages = [regex]::Matches($text, '"text"\s*:\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value }
    if ($messages) { $messages | ForEach-Object { Write-Host $_ } }
    throw 'The Roku did not produce a package (wrong signing password, or no key on this Roku?).'
}

$outDir = Join-Path $root 'out\packages'
New-Item -ItemType Directory -Force $outDir | Out-Null
$pkgPath = Join-Path $outDir "ImmichView-$version.pkg"
& curl.exe --silent --show-error --max-time 120 --digest --user $user -o $pkgPath "http://$targetHost/pkgs/$($match.Groups[1].Value)"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $pkgPath) -or (Get-Item $pkgPath).Length -lt 1024) { throw 'Package download failed.' }
Write-Host "Signed package: $pkgPath ($([math]::Round((Get-Item $pkgPath).Length / 1KB)) KB)"
Write-Host 'Keep a copy of this package with ROKU_SIGN_PASSWORD: together they restore the signing key.'

if (-not $KeepRelease) {
    Write-Host 'Reinstalling the dev build ...'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'deploy.ps1') | Out-Null
}
