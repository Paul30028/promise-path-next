Add-Type -AssemblyName System.Drawing
$artDir = "C:\Users\holyx\.gemini\antigravity\brain\6e568a4c-bd1a-4b4b-8be5-415b1cddfb8e"
$clayDir = "c:\AI\gemini\promise-path-next\public\clay"
$bg = [System.Drawing.Bitmap]::FromFile("$clayDir\level1-bethel-ground.png")
$bmp = New-Object System.Drawing.Bitmap($bg.Width, $bg.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($bg, 0, 0, $bg.Width, $bg.Height)

$placements = @(
  @{ id="eli";   x=0.45; y=0.44; h=215; sel=$false },
  @{ id="asa";   x=0.69; y=0.46; h=220; sel=$false },
  @{ id="sarai"; x=0.33; y=0.47; h=220; sel=$false },
  @{ id="nura";  x=0.22; y=0.62; h=225; sel=$false },
  @{ id="abram"; x=0.48; y=0.70; h=250; sel=$true  },
  @{ id="lot";   x=0.67; y=0.75; h=245; sel=$false }
)

foreach ($p in $placements) {
  $cImg = [System.Drawing.Image]::FromFile("$clayDir\character_$($p.id).png")
  $ch = [float]$p.h
  $cw = $ch * ($cImg.Width / [double]$cImg.Height)
  $fx = $bg.Width * $p.x
  $fy = $bg.Height * $p.y
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(115, 45, 28, 12))), [float]($fx - $cw*0.38), [float]($fy - 16), [float]($cw*0.76), 28.0)
  if ($p.sel) {
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(245, 255, 224, 102), 5.5)
    $g.DrawEllipse($pen, [float]($fx - $cw*0.48), [float]($fy - 20), [float]($cw*0.96), 36.0)
  }
  $g.DrawImage($cImg, [float]($fx - $cw/2.0), [float]($fy - $ch), [float]$cw, [float]$ch)
  $cImg.Dispose()
}

$bmp.Save("$artDir\level1-assembled-preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save("c:\AI\gemini\promise-path-next\design\codex-level1\level1-assembled-preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $bg.Dispose()
Write-Host "Saved level1-assembled-preview.png"
