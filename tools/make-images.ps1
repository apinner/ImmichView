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

# Logo mark for the in-app title: the flower from the supplied splash artwork, cropped to a
# square (centred on the emblem) with rounded corners, 128x128 (shown at 64x64).
$splash = [Drawing.Image]::FromFile((Join-Path $images 'splash-screen_fhd.jpg'))
$bmp = New-Object Drawing.Bitmap 128, 128
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([Drawing.Color]::Transparent)
$radius = 28
$path = New-Object Drawing.Drawing2D.GraphicsPath
$path.AddArc(0, 0, $radius * 2, $radius * 2, 180, 90)
$path.AddArc(128 - $radius * 2, 0, $radius * 2, $radius * 2, 270, 90)
$path.AddArc(128 - $radius * 2, 128 - $radius * 2, $radius * 2, $radius * 2, 0, 90)
$path.AddArc(0, 128 - $radius * 2, $radius * 2, $radius * 2, 90, 90)
$path.CloseFigure()
$g.SetClip($path)
$g.DrawImage($splash, (New-Object Drawing.Rectangle 0, 0, 128, 128), (New-Object Drawing.Rectangle 717, 225, 480, 480), [Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$splash.Dispose()
$bmp.Save((Join-Path $images 'logo-mark.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# Small white icons for the top bar pills (tinted at runtime with blendColor), 48x48.
function New-IconCanvas { $b = New-Object Drawing.Bitmap 48, 48; $gr = [Drawing.Graphics]::FromImage($b); $gr.SmoothingMode = 'AntiAlias'; $gr.Clear([Drawing.Color]::Transparent); return @($b, $gr) }

# Gear: 8 teeth around a ring, with a hole in the middle.
$bmp, $g = New-IconCanvas
$points = New-Object Collections.Generic.List[Drawing.PointF]
$teeth = 8
for ($t = 0; $t -lt $teeth; $t++) {
    $base = $t * 2 * [math]::PI / $teeth
    foreach ($step in @(@(-0.30, 16.5), @(-0.17, 22.5), @(0.17, 22.5), @(0.30, 16.5))) {
        $angle = $base + $step[0]
        $points.Add((New-Object Drawing.PointF (24 + $step[1] * [math]::Cos($angle)), (24 + $step[1] * [math]::Sin($angle))))
    }
}
$g.FillPolygon([Drawing.Brushes]::White, $points.ToArray())
$g.CompositingMode = 'SourceCopy'
$g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::Transparent)), 16.5, 16.5, 15, 15)
$g.Dispose()
$bmp.Save((Join-Path $images 'icon-gear.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# Person: head and shoulders.
$bmp, $g = New-IconCanvas
$g.FillEllipse([Drawing.Brushes]::White, 14, 4, 20, 20)
$g.FillPie([Drawing.Brushes]::White, 5, 27, 38, 38, 180, 180)
$g.Dispose()
$bmp.Save((Join-Path $images 'icon-person.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# Dropdown arrow: downward chevron.
$bmp, $g = New-IconCanvas
$pen = New-Object Drawing.Pen ([Drawing.Color]::White), 6
$pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
$g.DrawLines($pen, [Drawing.PointF[]]@((New-Object Drawing.PointF 10, 17), (New-Object Drawing.PointF 24, 31), (New-Object Drawing.PointF 38, 17)))
$g.Dispose()
$bmp.Save((Join-Path $images 'icon-chevron.png'), [Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Wrote play.png, focus.9.png, circle-mask.png, focus-ring.png, pill.9.png, logo-mark.png and icons to $images"
