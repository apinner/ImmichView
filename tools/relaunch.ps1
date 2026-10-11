<#
.SYNOPSIS
    Relaunches the dev channel and prints the debug console (port 8085) for a few seconds.
    Useful for catching compile errors after .\deploy.ps1. Uses ROKU_HOST from .env.
    If IMMICH_URL and IMMICH_API_KEY are set in .env they are passed as launch
    parameters, so the channel is signed in even though sideloading wiped its registry.
    With the ImmichView Screensaver app sideloaded (deploy.ps1 -Screensaver), launching it shows
    the screensaver straight away (dev builds only); -Screensaver is accepted for clarity.
    -RokuHost targets another Roku than ROKU_HOST.
#>
param([int]$Seconds = 10, [switch]$Screensaver, [string]$RokuHost)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$config = @{}
foreach ($line in Get-Content (Join-Path $root '.env')) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') { $config[$Matches[1]] = $Matches[2] }
}
$targetHost = $config['ROKU_HOST']
if ($RokuHost) { $targetHost = $RokuHost }
$launchUrl = "http://${targetHost}:8060/launch/dev"
if ($config['IMMICH_URL'] -and $config['IMMICH_API_KEY']) {
    $launchUrl += '?serverUrl=' + [uri]::EscapeDataString($config['IMMICH_URL']) +
        '&apiKey=' + [uri]::EscapeDataString($config['IMMICH_API_KEY'])
}

$client = New-Object Net.Sockets.TcpClient
$client.Connect($targetHost, 8085)
$stream = $client.GetStream()
$stream.ReadTimeout = 500
try {
    & curl.exe -s -m 10 -X POST "http://${targetHost}:8060/keypress/Home" | Out-Null
    Start-Sleep 2
    & curl.exe -s -m 10 -X POST $launchUrl | Out-Null

    $buffer = New-Object byte[] 65536
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $n = $stream.Read($buffer, 0, $buffer.Length)
            if ($n -gt 0) { Write-Host -NoNewline ([Text.Encoding]::UTF8.GetString($buffer, 0, $n)) }
        } catch [System.IO.IOException] { }
    }
} finally {
    $client.Close()
}
