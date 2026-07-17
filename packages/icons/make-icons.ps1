Add-Type -AssemblyName System.Drawing

$outDir = $PSScriptRoot
$brandBlue = [System.Drawing.Color]::FromArgb(255, 47, 129, 247)
$brandBlueDark = [System.Drawing.Color]::FromArgb(255, 26, 86, 179)
$white = [System.Drawing.Color]::White

function New-RoundedPath([int]$size, [single]$radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $inset = 1.0
    $w = $size - 1 - $inset
    $h = $size - 1 - $inset
    $path.AddArc($inset, $inset, $d, $d, 180, 90)
    $path.AddArc($w - $d, $inset, $d, $d, 270, 90)
    $path.AddArc($w - $d, $h - $d, $d, $d, 0, 90)
    $path.AddArc($inset, $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-Glyph([int]$size, [string]$file) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

    # Magenta background is the classic .dcr transparency key.
    $g.Clear([System.Drawing.Color]::FromArgb(255, 255, 0, 255))

    $radius = [single]($size * 0.22)
    $path = New-RoundedPath $size $radius

    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point(0, 0)),
        (New-Object System.Drawing.Point($size, $size)),
        $brandBlue, $brandBlueDark)
    $g.FillPath($brush, $path)

    $penBorder = New-Object System.Drawing.Pen($brandBlueDark, 1.0)
    $g.DrawPath($penBorder, $path)

    # "M" letter
    $fontSize = [single]($size * 0.5)
    $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
    $textRect = New-Object System.Drawing.RectangleF(0, [single](-$size * 0.06), $size, $size)
    $textBrush = New-Object System.Drawing.SolidBrush($white)
    $g.DrawString("M", $font, $textBrush, $textRect, $fmt)

    # Down arrow underneath the M
    $pen = New-Object System.Drawing.Pen($white, [single]([Math]::Max(1.0, $size * 0.08)))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $cx = [single]($size * 0.5)
    $top = [single]($size * 0.60)
    $bottom = [single]($size * 0.82)
    $g.DrawLine($pen, $cx, $top, $cx, $bottom)
    $wing = [single]($size * 0.16)
    $g.DrawLine($pen, $cx, $bottom, [single]($cx - $wing), [single]($bottom - $wing))
    $g.DrawLine($pen, $cx, $bottom, [single]($cx + $wing), [single]($bottom - $wing))

    $g.Dispose()

    $target = Join-Path $outDir $file
    # Save as 24-bit BMP (System.Drawing writes 32-bit by default for Bitmap; force 24bpp).
    $bmp24 = $bmp.Clone((New-Object System.Drawing.Rectangle(0, 0, $size, $size)), [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $bmp24.Save($target, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $bmp24.Dispose()
    $bmp.Dispose()
    Write-Host "wrote $target"
}

New-Item -ItemType Directory -Force -Path (Join-Path $outDir "24") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outDir "32") | Out-Null

New-Glyph 24 "24\TMARKDOWNVIEWER.bmp"
New-Glyph 24 "24\TMARKDOWNEDITOR.bmp"
New-Glyph 32 "32\TMARKDOWNVIEWER.bmp"
New-Glyph 32 "32\TMARKDOWNEDITOR.bmp"
