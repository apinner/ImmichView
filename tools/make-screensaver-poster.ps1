<#
.SYNOPSIS
    Makes the ImmichView Screensaver posters (images/channel-poster-screensaver_fhd.png 540x405
    and _hd.png 290x218) from the supplied ImmichView poster: the artwork moves up 22px and a
    letter-spaced "SCREENSAVER" label goes under the wordmark.
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$images = Join-Path (Split-Path $PSScriptRoot -Parent) 'images'

$source = [Drawing.Bitmap]::FromFile((Join-Path $images 'channel-poster_fhd.png'))
$width = $source.Width; $height = $source.Height; $shift = 22
$poster = New-Object Drawing.Bitmap $width, $height
$g = [Drawing.Graphics]::FromImage($poster)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.DrawImage($source, 0, -$shift, $width, $height)
# Fill the rows freed at the bottom with the background colour there (it's flat at the bottom).
$bottom = $source.GetPixel([int]($width / 2), $height - 3)
$g.FillRectangle((New-Object Drawing.SolidBrush $bottom), 0, $height - $shift - 2, $width, $shift + 2)

$text = 'SCREENSAVER'
$font = New-Object Drawing.Font 'Segoe UI Semibold', 15, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 0xA2, 0x74, 0xD4))
$format = [Drawing.StringFormat]::GenericTypographic
$tracking = 5
$widths = foreach ($ch in $text.ToCharArray()) { $g.MeasureString([string]$ch, $font, 1000, $format).Width }
$total = ($widths | Measure-Object -Sum).Sum + $tracking * ($text.Length - 1)
$x = ($width - $total) / 2
$y = 358
for ($i = 0; $i -lt $text.Length; $i++) {
    $g.DrawString([string]$text[$i], $font, $brush, $x, $y, $format)
    $x += $widths[$i] + $tracking
}
$g.Dispose()
$source.Dispose()
$poster.Save((Join-Path $images 'channel-poster-screensaver_fhd.png'), [Drawing.Imaging.ImageFormat]::Png)

$hd = New-Object Drawing.Bitmap 290, 218
$g = [Drawing.Graphics]::FromImage($hd)
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.DrawImage($poster, 0, 0, 290, 218)
$g.Dispose()
$hd.Save((Join-Path $images 'channel-poster-screensaver_hd.png'), [Drawing.Imaging.ImageFormat]::Png)
$hd.Dispose()
$poster.Dispose()
Write-Host "Wrote channel-poster-screensaver_fhd.png and _hd.png to $images"
