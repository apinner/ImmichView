<#
.SYNOPSIS
    Sends a deep link to the dev channel and prints the debug console for a few seconds.
    Without -Running it (re)launches the channel with the link (ECP /launch, like Roku Search);
    with -Running it sends it to the running channel (ECP /input, delivered as roInput).
.EXAMPLE
    .\tools\deeplink.ps1 -ContentId 5c949428-2cb9-475b-9262-e906fdb64510 -MediaType movie
    .\tools\deeplink.ps1 -ContentId <video asset id> -MediaType shortFormVideo -Running
#>
param(
    [Parameter(Mandatory)][string]$ContentId,
    [string]$MediaType = 'movie',
    [switch]$Running,
    [int]$Seconds = 8,
    [string]$RokuHost
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$targetHost = $RokuHost
if (-not $targetHost) {
    foreach ($line in Get-Content (Join-Path $root '.env')) {
        if ($line -match '^\s*ROKU_HOST\s*=\s*(.*?)\s*$') { $targetHost = $Matches[1] }
    }
}
$query = 'contentId=' + [uri]::EscapeDataString($ContentId) + '&mediaType=' + [uri]::EscapeDataString($MediaType)
if ($Running) { $url = "http://${targetHost}:8060/input?$query" } else { $url = "http://${targetHost}:8060/launch/dev?$query" }

$client = New-Object Net.Sockets.TcpClient
$client.Connect($targetHost, 8085)
$stream = $client.GetStream()
$stream.ReadTimeout = 500
try {
    & curl.exe -s -m 10 -X POST $url | Out-Null
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
