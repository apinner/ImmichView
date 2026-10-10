<#
.SYNOPSIS
    Regenerates the simple UI images in images/ (play badge icon, focus frame 9-patch).
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$images = Join-Path (Split-Path $PSScriptRoot -Parent) 'images'
New-Item -ItemType Directory -Force $images | Out-Null

# Play icon: white triangle on transparent, 32x32 (drawn scaled down on the badge).
$bmp = New-Object Drawing.Bitmap 32, 32
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::Transparent)
$points = [Drawing.PointF[]]@((New-Object Drawing.PointF 6, 3), (New-Object Drawing.PointF 29, 16), (New-Object Drawing.PointF 6, 29))
$g.FillPolygon([Drawing.Brushes]::White, $points)
$g.Dispose()
$bmp.Save((Join-Path $images 'play.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# Focus frame 9-patch: 32x32 content with a 5px white border, plus the 1px
# black stretch markers on the top row and left column that Roku's .9.png format needs.
$size = 34
$border = 5
$bmp = New-Object Drawing.Bitmap $size, $size
for ($x = 0; $x -lt $size; $x++) { for ($y = 0; $y -lt $size; $y++) { $bmp.SetPixel($x, $y, [Drawing.Color]::Transparent) } }
for ($x = 1; $x -le 32; $x++) {
    for ($y = 1; $y -le 32; $y++) {
        $cx = $x - 1; $cy = $y - 1
        if ($cx -lt $border -or $cy -lt $border -or $cx -ge 32 - $border -or $cy -ge 32 - $border) {
            $bmp.SetPixel($x, $y, [Drawing.Color]::White)
        }
    }
}
$black = [Drawing.Color]::FromArgb(255, 0, 0, 0)
for ($i = 1 + $border + 2; $i -le 32 - $border - 2; $i++) {
    $bmp.SetPixel($i, 0, $black)
    $bmp.SetPixel(0, $i, $black)
}
$bmp.Save((Join-Path $images 'focus.9.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# Circle mask for face thumbnails (MaskGroup uses the alpha channel): 220x220.
$bmp = New-Object Drawing.Bitmap 220, 220
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::Transparent)
$g.FillEllipse([Drawing.Brushes]::White, 0, 0, 219, 219)
$g.Dispose()
$bmp.Save((Join-Path $images 'circle-mask.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# Focus ring for face thumbnails: 6px white ring, 232x232 (drawn 6px outside the face).
$bmp = New-Object Drawing.Bitmap 232, 232
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::Transparent)
$pen = New-Object Drawing.Pen ([Drawing.Color]::White), 6
$g.DrawEllipse($pen, 3, 3, 225, 225)
$g.Dispose()
$bmp.Save((Join-Path $images 'focus-ring.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# Pill 9-patch for tabs: 56px-tall white rounded rectangle (fully rounded ends), tinted at
# runtime with blendColor. Only the centre column/row stretch.
$bmp = New-Object Drawing.Bitmap 58, 58
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::Transparent)
$g.FillEllipse([Drawing.Brushes]::White, 1, 1, 56, 56)
$g.Dispose()
$bmp.SetPixel(29, 0, $black)
$bmp.SetPixel(0, 29, $black)
$bmp.Save((Join-Path $images 'pill.9.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Wrote play.png, focus.9.png, circle-mask.png, focus-ring.png and pill.9.png to $images"
