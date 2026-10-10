<#
.SYNOPSIS
    Renders the channel icons and splash screens in images/ from art/immichview.svg,
    using headless Microsoft Edge (Windows has no built-in SVG rasteriser).
    Icons are on white (the wordmark is dark); splash screens are on the app's
    background with the "Immich" half of the wordmark switched to white.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$images = Join-Path $root 'images'
$work = Join-Path $root 'out\icons'
New-Item -ItemType Directory -Force $work | Out-Null

$edge = @('C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', 'C:\Program Files\Microsoft\Edge\Application\msedge.exe') |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge not found.' }

$svg = Get-Content (Join-Path $root 'art\immichview.svg') -Raw
# Crop the 1024x1024 canvas to the artwork so it fills more of each image.
$svg = $svg -replace 'width="1024" height="1024" viewBox="0 0 1024 1024"', 'width="100%" height="100%" viewBox="150 50 724 880"'
$svgOnDark = $svg -replace '<tspan fill="#35105E">', '<tspan fill="#FFFFFF">'

function Render([string]$name, [int]$width, [int]$height, [int]$artHeight, [string]$background, [string]$art) {
    $html = Join-Path $work "$name.html"
    $png = Join-Path $images "$name.png"
    @"
<!doctype html><html><head><style>
html,body{margin:0;width:${width}px;height:${height}px;background:$background;overflow:hidden}
.art{position:absolute;left:50%;top:50%;height:${artHeight}px;width:${artHeight}px;transform:translate(-50%,-50%)}
</style></head><body><div class="art">$art</div></body></html>
"@ | Set-Content -Path $html -Encoding utf8
    if (Test-Path $png) { Remove-Item $png }
    # Start-Process: Edge reports progress on stderr, which PowerShell 5.1 would treat as an error.
    $arguments = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
        "--user-data-dir=`"$work\edge-profile`"", "--window-size=$width,$height", "--screenshot=`"$png`"",
        "file:///$($html.Replace('\','/'))")
    Start-Process -FilePath $edge -ArgumentList $arguments -Wait -WindowStyle Hidden
    if (-not (Test-Path $png)) { throw "Edge did not write $png" }
    Write-Host "Wrote $png"
}

Render 'icon_focus_fhd' 540 405 380 '#FFFFFF' $svg
Render 'icon_focus_hd' 290 218 204 '#FFFFFF' $svg
Render 'splash_fhd' 1920 1080 620 '#24232F' $svgOnDark
Render 'splash_hd' 1280 720 414 '#24232F' $svgOnDark
