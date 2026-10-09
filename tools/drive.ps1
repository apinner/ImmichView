<#
.SYNOPSIS
    Sends a sequence of remote keys over ECP and screenshots after each step, then builds
    a contact sheet (out\drive.png). Needs "Control by mobile apps" set to Permissive.
.EXAMPLE
    .\tools\drive.ps1 -Steps 'Up','Right','Down','Info'
    Each step is a key name (Up, Down, Left, Right, Select, Back, Home, Info, Rev, Fwd, Play)
    or several separated by '+', e.g. 'Down+Down+Down'.
#>
param([string[]]$Steps, [int]$DelayMs = 1500)

$ErrorActionPreference = 'Stop'
# powershell -File passes 'A','B' as one string; accept comma-separated steps too.
$Steps = @($Steps | ForEach-Object { $_.Split(',') } | Where-Object { $_ })
$root = Split-Path $PSScriptRoot -Parent
$rokuHost = $null
foreach ($line in Get-Content (Join-Path $root '.env')) {
    if ($line -match '^\s*ROKU_HOST\s*=\s*(.*?)\s*$') { $rokuHost = $Matches[1] }
}

$shots = @()
$i = 0
foreach ($step in $Steps) {
    foreach ($key in $step.Split('+')) {
        & curl.exe -s -m 5 -X POST "http://${rokuHost}:8060/keypress/$key" | Out-Null
        Start-Sleep -Milliseconds 250
    }
    Start-Sleep -Milliseconds $DelayMs
    $file = Join-Path $root "out\drive-$i.jpg"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'screenshot.ps1') -OutFile $file | Out-Null
    $shots += @{ file = $file; label = "$i. $step" }
    $i++
}

# Contact sheet: 2 columns of 960x540 thumbnails with step labels.
Add-Type -AssemblyName System.Drawing
$cols = 2
$w = 960; $h = 540
$rows = [math]::Ceiling($shots.Count / $cols)
$sheet = New-Object Drawing.Bitmap ($cols * $w), ($rows * ($h + 40))
$g = [Drawing.Graphics]::FromImage($sheet)
$g.Clear([Drawing.Color]::Black)
$font = New-Object Drawing.Font 'Segoe UI', 18
for ($n = 0; $n -lt $shots.Count; $n++) {
    $x = ($n % $cols) * $w
    $y = [math]::Floor($n / $cols) * ($h + 40)
    $img = [Drawing.Image]::FromFile($shots[$n].file)
    $g.DrawImage($img, $x, $y + 40, $w, $h)
    $img.Dispose()
    $g.DrawString($shots[$n].label, $font, [Drawing.Brushes]::Yellow, $x + 8, $y + 6)
}
$g.Dispose()
$out = Join-Path $root 'out\drive.png'
$sheet.Save($out)
$sheet.Dispose()
Write-Host "Saved $out"
