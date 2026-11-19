Add-Type -AssemblyName System.Drawing
$art = "C:\Users\holyx\.gemini\antigravity\brain\6e568a4c-bd1a-4b4b-8be5-415b1cddfb8e"
$src = [System.Drawing.Bitmap]::FromFile("$art\level1-assembled-preview.png")

function Save-Mock($w, $h, $name, $hudTop, $hudBottom) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.Clear([System.Drawing.Color]::FromArgb(30,30,30))
  $playH = $h - $hudTop - $hudBottom
  # cover-fit the scene into play area
  $scale = [Math]::Max($w / $src.Width, $playH / $src.Height)
  $dw = $src.Width * $scale; $dh = $src.Height * $scale
  $g.DrawImage($src, [float](($w - $dw)/2), [float]($hudTop + ($playH - $dh)/2), [float]$dw, [float]$dh)
  $hud = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(225, 35, 27, 19))
  if ($hudTop -gt 0) { $g.FillRectangle($hud, 0, 0, $w, $hudTop) }
  if ($hudBottom -gt 0) { $g.FillRectangle($hud, 0, $h - $hudBottom, $w, $hudBottom) }
  $f = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
  $g.DrawString("HUD 区（资源/目标）", $f, [System.Drawing.Brushes]::Wheat, 10, 8)
  $g.DrawString("HUD 区（手牌/指令/执行）", $f, [System.Drawing.Brushes]::Wheat, 10, $h - $hudBottom + 8)
  $bmp.Save("$art\$name", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
Save-Mock 844 390 "mobile-landscape-mock.png" 44 96
Save-Mock 390 844 "mobile-portrait-mock.png" 56 260
$src.Dispose()
Write-Host done
