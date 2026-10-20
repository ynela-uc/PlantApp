# Draws the brand mark (a tilted price tag with a leaf and a coral hole) and writes every icon the apps need.
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File tools\make_brand.ps1
Add-Type -AssemblyName System.Drawing

$teal  = [System.Drawing.Color]::FromArgb(255, 14, 111, 115)
$white = [System.Drawing.Color]::White
$coral = [System.Drawing.Color]::FromArgb(255, 242, 107, 91)
$tilt = 35

function New-Canvas([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    return @{ Bitmap = $bmp; Graphics = $g }
}

function P([double]$k, [double]$x, [double]$y) {
    return New-Object System.Drawing.PointF([single]($k * $x), [single]($k * $y))
}

# The tag outline on a 96-unit grid: pointed end up, rounded bottom corners.
function Tag-Path([double]$k) {
    $tag = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tag.AddLine((P $k 48 12), (P $k 68 32))
    $tag.AddLine((P $k 68 32), (P $k 68 78))
    $tag.AddBezier((P $k 68 78), (P $k 68 82), (P $k 66 84), (P $k 62 84))
    $tag.AddLine((P $k 62 84), (P $k 34 84))
    $tag.AddBezier((P $k 34 84), (P $k 30 84), (P $k 28 82), (P $k 28 78))
    $tag.AddLine((P $k 28 78), (P $k 28 32))
    $tag.CloseFigure()
    return $tag
}

# Draws the mark centred on (cx, cy), scaled so its tilted bounding box is $target pixels on the longer side.
function Draw-Glyph($g, [double]$cx, [double]$cy, [double]$target) {
    $whiteBrush = New-Object System.Drawing.SolidBrush($white)
    $tealBrush = New-Object System.Drawing.SolidBrush($teal)
    $coralBrush = New-Object System.Drawing.SolidBrush($coral)

    # Size of the tilted tag at scale 1 (pivot at the grid point 48,48).
    $probe = Tag-Path 1
    $rot = New-Object System.Drawing.Drawing2D.Matrix
    $rot.RotateAt($tilt, (New-Object System.Drawing.PointF(48, 48)))
    $probe.Transform($rot)
    $b = $probe.GetBounds()
    $k = $target / [Math]::Max($b.Width, $b.Height)
    $bcx = $b.X + $b.Width / 2
    $bcy = $b.Y + $b.Height / 2

    $state = $g.Save()
    $g.TranslateTransform([single]($cx - $k * $bcx), [single]($cy - $k * $bcy))
    $g.TranslateTransform([single]($k * 48), [single]($k * 48))
    $g.RotateTransform([single]$tilt)
    $g.TranslateTransform([single](-$k * 48), [single](-$k * 48))

    $g.FillPath($whiteBrush, (Tag-Path $k))
    $g.FillEllipse($coralBrush, [single]($k * (48 - 5.5)), [single]($k * (28 - 5.5)), [single](11 * $k), [single](11 * $k))

    $leaf = New-Object System.Drawing.Drawing2D.GraphicsPath
    $leaf.AddBezier((P $k 38 76), (P $k 38 62), (P $k 45 53), (P $k 58 53))
    $leaf.AddBezier((P $k 58 53), (P $k 58 66), (P $k 51 76), (P $k 38 76))
    $leaf.CloseFigure()
    $g.FillPath($tealBrush, $leaf)

    $vein = New-Object System.Drawing.Pen($white, [single](2.4 * $k))
    $vein.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $vein.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($vein, (P $k 41 73), (P $k 54 58))

    $g.Restore($state)
}

function Save-Png($canvas, [string]$path) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $canvas.Graphics.Dispose()
    $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Bitmap.Dispose()
    Write-Host "wrote $path"
}

# iPhone app icon: full-bleed teal square, the system rounds the corners.
$c = New-Canvas 1024
$c.Graphics.Clear($teal)
Draw-Glyph $c.Graphics 512 512 600
Save-Png $c "ios\PlantApp\Assets.xcassets\AppIcon.appiconset\icon-1024.png"

# In-app logo: rounded teal square with the mark.
function Make-Logo([int]$size, [string]$path) {
    $canvas = New-Canvas $size
    $g = $canvas.Graphics
    $radius = $size * 22 / 96
    $round = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $round.AddArc(0, 0, $d, $d, 180, 90)
    $round.AddArc($size - $d, 0, $d, $d, 270, 90)
    $round.AddArc($size - $d, $size - $d, $d, $d, 0, 90)
    $round.AddArc(0, $size - $d, $d, $d, 90, 90)
    $round.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush($teal)), $round)
    Draw-Glyph $g ($size / 2) ($size / 2) ($size * 0.62)
    Save-Png $canvas $path
}
Make-Logo 512 "ios\PlantApp\Assets.xcassets\Logo.imageset\logo.png"
Make-Logo 512 "android\app\src\main\res\drawable-nodpi\logo.png"

# Android adaptive icon foreground: only the mark, inside the 66 dp safe zone of the 108 dp canvas.
$f = New-Canvas 432
Draw-Glyph $f.Graphics 216 216 232
Save-Png $f "android\app\src\main\res\drawable-nodpi\ic_launcher_foreground.png"
