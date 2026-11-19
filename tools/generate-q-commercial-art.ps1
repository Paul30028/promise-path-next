Add-Type -AssemblyName System.Drawing

$artifactDir = "C:\Users\holyx\.gemini\antigravity\brain\6e568a4c-bd1a-4b4b-8be5-415b1cddfb8e"
$proposalDir = "c:\AI\gemini\promise-path-next\design\producer-proposal-v3-q"
New-Item -ItemType Directory -Force -Path $proposalDir | Out-Null

function ColorFromHex([string]$hex, [int]$alpha = 255) {
    $h = $hex.TrimStart('#')
    $r = [Convert]::ToInt32($h.Substring(0,2), 16)
    $g = [Convert]::ToInt32($h.Substring(2,2), 16)
    $b = [Convert]::ToInt32($h.Substring(4,2), 16)
    return [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b)
}

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    if ($d -gt $w) { $d = $w }
    if ($d -gt $h) { $d = $h }
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-Grad([float]$x1, [float]$y1, [float]$x2, [float]$y2, [string]$c1, [string]$c2) {
    return New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF($x1, $y1)),
        (New-Object System.Drawing.PointF($x2, $y2)),
        (ColorFromHex $c1),
        (ColorFromHex $c2)
    )
}

function Draw-Poly([System.Drawing.Graphics]$g, [System.Drawing.Brush]$brush, [System.Drawing.Pen]$pen, [float[]]$coords) {
    $pts = New-Object System.Drawing.PointF[] ($coords.Length / 2)
    for ($i = 0; $i -lt $pts.Length; $i++) {
        $pts[$i] = New-Object System.Drawing.PointF($coords[$i*2], $coords[$i*2+1])
    }
    if ($null -ne $brush) { $g.FillPolygon($brush, $pts) }
    if ($null -ne $pen) { $g.DrawPolygon($pen, $pts) }
}

function Draw-ClosedCurve([System.Drawing.Graphics]$g, [System.Drawing.Brush]$brush, [System.Drawing.Pen]$pen, [float[]]$coords, [float]$tension = 0.45) {
    $pts = New-Object System.Drawing.PointF[] ($coords.Length / 2)
    for ($i = 0; $i -lt $pts.Length; $i++) {
        $pts[$i] = New-Object System.Drawing.PointF($coords[$i*2], $coords[$i*2+1])
    }
    if ($null -ne $brush) { $g.FillClosedCurve($brush, $pts, [System.Drawing.Drawing2D.FillMode]::Winding, $tension) }
    if ($null -ne $pen) { $g.DrawClosedCurve($pen, $pts) }
}

# ==============================================================================
# COMMERCIAL Q-VERSION (2.3-HEAD-TALL CHIBI) CHARACTER RENDERER
# Big expressive sparkling eyes, chubby cheeks, rounded toy-box proportions,
# crisp dark-brown comic outlines, and iconic Old Testament props!
# ==============================================================================
function Draw-ChibiHero([System.Drawing.Graphics]$g, [float]$cx, [float]$bottomY, [float]$scale, [string]$id, [bool]$selected = $false) {
    $st = $g.Save()
    $g.TranslateTransform($cx, $bottomY)
    $g.ScaleTransform($scale, $scale)

    $outPen = New-Object System.Drawing.Pen((ColorFromHex "#2B1B12"), 3.2)
    $outPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $thinPen = New-Object System.Drawing.Pen((ColorFromHex "#2B1B12"), 2.0)
    $goldPen = New-Object System.Drawing.Pen((ColorFromHex "#F59E0B"), 2.8)

    $skinGrad = New-Grad -35 -135 35 -65 "#FFE0C2" "#F2B88B"
    $blushBrush = New-Object System.Drawing.SolidBrush(ColorFromHex "#F472B6" 95)
    $eyeDark = New-Object System.Drawing.SolidBrush(ColorFromHex "#23150E")
    $hairDark = New-Grad -35 -145 35 -70 "#3B261A" "#1F130C"
    $hairSilver = New-Grad -35 -145 35 -60 "#FAF6F0" "#C7BEB2"

    # 1. Ground Shadow & Glow Ring
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#24170B" 110)), -44, -14, 88, 26)
    if ($selected) {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047" 65)), -58, -20, 116, 38)
        $g.DrawEllipse((New-Object System.Drawing.Pen((ColorFromHex "#FACC15"), 4.0)), -50, -16, 100, 30)
    }

    # Chubby Chibi Feet / Sandals (y: -18 to 0)
    foreach ($fx in @(-20, 6)) {
        $footPath = New-RoundedRectPath $fx -18 16 15 7
        $g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#78472A")), $footPath)
        $g.DrawPath($outPen, $footPath)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F2B88B")), ($fx + 3), -14, 10, 8)
    }

    # Helper for Chibi Big-Head (y: -136 to -66, width: 76, height: 68)
    function Draw-ChibiHead([string]$beard, [string]$scarfCol1, [string]$scarfCol2, [string]$bandCol, [bool]$isFemale = $false) {
        # Back headscarf / hair puff
        if ($scarfCol1 -ne "") {
            $scBack = New-Grad -44 -142 44 -55 $scarfCol1 $scarfCol2
            $backPath = New-RoundedRectPath -42 -136 84 82 34
            $g.FillPath($scBack, $backPath)
            $g.DrawPath($outPen, $backPath)
        } else {
            $hPath = New-RoundedRectPath -40 -138 80 72 34
            $g.FillPath($hairDark, $hPath)
            $g.DrawPath($outPen, $hPath)
        }

        # Cute Chubby Ears
        $g.FillEllipse($skinGrad, -42, -106, 14, 16)
        $g.DrawEllipse($outPen, -42, -106, 14, 16)
        $g.FillEllipse($skinGrad, 28, -106, 14, 16)
        $g.DrawEllipse($outPen, 28, -106, 14, 16)
        if ($isFemale) {
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FBBF24")), -39, -93, 8, 8)
            $g.DrawEllipse($thinPen, -39, -93, 8, 8)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FBBF24")), 31, -93, 8, 8)
            $g.DrawEllipse($thinPen, 31, -93, 8, 8)
        }

        # Chibi RoundedSquishy Face (Width 68, Height 60)
        $facePath = New-RoundedRectPath -34 -130 68 60 28
        $g.FillPath($skinGrad, $facePath)
        $g.DrawPath($outPen, $facePath)

        # Rosy Chubby Cheeks
        $g.FillEllipse($blushBrush, -28, -94, 15, 10)
        $g.FillEllipse($blushBrush, 13, -94, 15, 10)

        # Big Sparkling Chibi Eyes!
        foreach ($ex in @(-19, 6)) {
            $g.FillEllipse([System.Drawing.Brushes]::White, ($ex - 2), -110, 17, 19)
            $g.DrawEllipse($thinPen, ($ex - 2), -110, 17, 19)
            $g.FillEllipse($eyeDark, ($ex + 1), -108, 12, 15)
            # Big primary star catchlight + secondary dot
            $g.FillEllipse([System.Drawing.Brushes]::White, ($ex + 2), -106, 5.5, 5.5)
            $g.FillEllipse([System.Drawing.Brushes]::White, ($ex + 8), -98, 3.0, 3.0)
        }

        # Cute Button Nose
        $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#E09A6C")), -3, -96, 7, 5)

        # Eyebrows
        $bCol = if ($beard -eq "silver") { ColorFromHex "#A8A29E" } else { ColorFromHex "#2B1B12" }
        $bPen = New-Object System.Drawing.Pen($bCol, 3.2)
        $g.DrawArc($bPen, -20, -117, 15, 8, 200, 140)
        $g.DrawArc($bPen, 6, -117, 15, 8, 200, 140)

        # Mouth or Fluffy Chibi Beard
        if ($beard -eq "full" -or $beard -eq "silver") {
            $bGrad = if ($beard -eq "silver") { $hairSilver } else { $hairDark }
            # Fluffy cloud-like chibi beard
            Draw-ClosedCurve $g $bGrad $outPen @(-30,-92, -32,-70, -16,-56, 0,-52, 16,-56, 32,-70, 30,-92, 14,-86, 0,-88, -14,-86) 0.45
            # Cute smile peeking through moustache
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F2B88B")), -6, -85, 12, 7)
        } elseif ($beard -eq "short") {
            Draw-ClosedCurve $g $hairDark $outPen @(-28,-88, -24,-66, 0,-60, 24,-66, 28,-88, 12,-82, 0,-84, -12,-82) 0.4
            $g.DrawArc($thinPen, -5, -86, 10, 6, 10, 160)
        } else {
            # Happy Chibi Smile
            $g.DrawArc($thinPen, -6, -88, 12, 8, 10, 160)
        }

        # Front Hair Bangs & Headcloth Crown
        if ($scarfCol1 -ne "") {
            $scTop = New-Grad -38 -146 38 -110 $scarfCol1 $scarfCol2
            Draw-ClosedCurve $g $scTop $outPen @(-38,-116, -32,-142, 0,-146, 32,-142, 38,-116, 18,-126, 0,-128, -18,-126) 0.4
            if ($bandCol -ne "") {
                $bandPath = New-RoundedRectPath -36 -134 72 11 5
                $g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex $bandCol)), $bandPath)
                $g.DrawPath($outPen, $bandPath)
            }
        } else {
            Draw-ClosedCurve $g $hairDark $outPen @(-36,-114, -30,-142, 0,-145, 30,-142, 36,-114, 15,-124, 0,-120, -15,-124) 0.4
            if ($bandCol -ne "") {
                $bandPath = New-RoundedRectPath -35 -130 70 10 5
                $g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex $bandCol)), $bandPath)
                $g.DrawPath($outPen, $bandPath)
            }
        }
    }

    switch ($id) {
        "abraham" {
            # Chubby Rounded Tunic & Royal Blue Patriarch Cloak (y: -74 to -12)
            $robePath = New-RoundedRectPath -32 -76 64 62 22
            $g.FillPath((New-Grad -32 -76 32 -14 "#F7EBD2" "#D8C39E"), $robePath)
            $g.DrawPath($outPen, $robePath)

            # Blue Mantle sides
            $blueGrad = New-Grad -36 -76 36 -14 "#2563EB" "#1E3A8A"
            Draw-ClosedCurve $g $blueGrad $outPen @(-30,-74, -40,-22, -14,-16, -10,-70) 0.3
            Draw-ClosedCurve $g $blueGrad $outPen @(10,-70, 14,-16, 40,-22, 30,-74) 0.3

            # Beni-Hasan Striped Scarf
            Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#F59E0B")) $outPen @(-14,-72, 16,-24, 26,-24, -4,-72)

            # Chubby Hands
            $g.FillEllipse($skinGrad, -40, -52, 16, 16)
            $g.DrawEllipse($outPen, -40, -52, 16, 16)
            $g.FillEllipse($skinGrad, 26, -56, 16, 16)
            $g.DrawEllipse($outPen, 26, -56, 16, 16)

            Draw-ChibiHead "full" "#FAF5EB" "#DFD3BC" "#2563EB" $false

            # Chunky Toy-Box Shepherd Staff with Glowing Star Gem!
            $staffPen = New-Object System.Drawing.Pen((ColorFromHex "#78350F"), 8.0)
            $staffPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $staffPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawLine($staffPen, 38, -4, 38, -125)
            $g.DrawArc($staffPen, 20, -155, 34, 34, 170, 230)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047")), 31, -142, 12, 12)
        }
        "sarah" {
            $dressPath = New-RoundedRectPath -30 -74 60 60 22
            $g.FillPath((New-Grad -30 -74 30 -14 "#E11D48" "#9F1239"), $dressPath)
            $g.DrawPath($outPen, $dressPath)

            $apronPath = New-RoundedRectPath -14 -70 28 56 10
            $g.FillPath((New-Grad -14 -70 14 -14 "#FEF3C7" "#FDE68A"), $apronPath)
            $g.DrawPath($outPen, $apronPath)

            Draw-ChibiHead "none" "#FFFBEB" "#FDE68A" "#F59E0B" $true

            # Holding Cute Glowing Golden Oil Lamp in Front
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F59E0B" 95)), -22, -74, 44, 44)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#D97706")), -12, -52, 24, 14)
            $g.DrawEllipse($outPen, -12, -52, 24, 14)
            Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A")) $thinPen @(-5,-52, 0,-68, 5,-52) 0.3
            $g.FillEllipse($skinGrad, -18, -50, 13, 13)
            $g.DrawEllipse($outPen, -18, -50, 13, 13)
            $g.FillEllipse($skinGrad, 5, -50, 13, 13)
            $g.DrawEllipse($outPen, 5, -50, 13, 13)
        }
        "lot" {
            $tunicPath = New-RoundedRectPath -32 -76 64 62 22
            $g.FillPath((New-Grad -32 -76 32 -14 "#9333EA" "#581C87"), $tunicPath)
            $g.DrawPath($outPen, $tunicPath)

            # Chunky Rope Coils across chest
            $ropePen = New-Object System.Drawing.Pen((ColorFromHex "#FCD34D"), 6.5)
            $g.DrawArc($ropePen, -28, -72, 52, 44, 10, 170)

            Draw-ChibiHead "short" "" "" "#DC2626" $false

            # Holding Golden Trade Pouch & Balance Scale
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FBBF24")), 22, -54, 22, 24)
            $g.DrawEllipse($outPen, 22, -54, 22, 24)
            $g.FillEllipse($skinGrad, -38, -52, 15, 15)
            $g.DrawEllipse($outPen, -38, -52, 15, 15)
        }
        "eliezer" {
            $armorPath = New-RoundedRectPath -31 -76 62 62 20
            $g.FillPath((New-Grad -31 -76 31 -14 "#16A34A" "#14532D"), $armorPath)
            $g.DrawPath($outPen, $armorPath)

            # Leather Chest Belt
            Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#92400E")) $outPen @(-24,-72, 20,-22, 28,-28, -16,-76)

            Draw-ChibiHead "short" "" "" "#92400E" $false

            # Holding Big Blazing Chibi Torch!
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#78350F"), 7)), 34, -22, 42, -110)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F97316" 110)), 16, -156, 54, 54)
            Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#EF4444")) $outPen @(30,-110, 24,-134, 42,-152, 56,-130, 48,-110) 0.4
            Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A")) $null @(35,-112, 33,-128, 42,-138, 48,-126) 0.4
            $g.FillEllipse($skinGrad, 26, -58, 16, 16)
            $g.DrawEllipse($outPen, 26, -58, 16, 16)
        }
        "hagar" {
            $dressPath = New-RoundedRectPath -30 -74 60 60 22
            $g.FillPath((New-Grad -30 -74 30 -14 "#0D9488" "#115E59"), $dressPath)
            $g.DrawPath($outPen, $dressPath)

            Draw-ChibiHead "none" "#CCFBF1" "#99F6E4" "#0D9488" $true

            # Hugging Big Cute Round Water Jar with Water Splash!
            $jarGrad = New-Grad 4 -68 42 -24 "#EA580C" "#9A3412"
            $g.FillEllipse($jarGrad, 6, -64, 34, 38)
            $g.DrawEllipse($outPen, 6, -64, 34, 38)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#38BDF8")), 13, -68, 20, 9)
            $g.DrawEllipse($outPen, 13, -68, 20, 9)
            $g.FillEllipse($skinGrad, 2, -48, 14, 14)
            $g.DrawEllipse($outPen, 2, -48, 14, 14)
        }
        "ur" {
            $apronPath = New-RoundedRectPath -32 -76 64 62 22
            $g.FillPath((New-Grad -32 -76 32 -14 "#D97706" "#78350F"), $apronPath)
            $g.DrawPath($outPen, $apronPath)

            Draw-ChibiHead "full" "" "" "#EA580C" $false

            # Holding Giant Cute Toy-Box Wooden Mallet / Bronze Hammer!
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#78350F"), 7)), 28, -35, 42, -115)
            $hamPath = New-RoundedRectPath 18 -142 46 28 10
            $g.FillPath((New-Grad 18 -142 64 -114 "#FBBF24" "#B45309"), $hamPath)
            $g.DrawPath($outPen, $hamPath)
            $g.FillEllipse($skinGrad, 24, -56, 16, 16)
            $g.DrawEllipse($outPen, 24, -56, 16, 16)
        }
        "melchizedek" {
            $robePath = New-RoundedRectPath -32 -76 64 62 22
            $g.FillPath((New-Grad -32 -76 32 -14 "#6366F1" "#312E81"), $robePath)
            $g.DrawPath($outPen, $robePath)
            $stolePath = New-RoundedRectPath -10 -74 20 60 8
            $g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#FACC15")), $stolePath)
            $g.DrawPath($outPen, $stolePath)

            Draw-ChibiHead "silver" "#F3F4F6" "#D1D5DB" "#FACC15" $false

            # Holding Glowing Golden Cuneiform Tablet!
            $tabPath = New-RoundedRectPath 12 -64 28 34 7
            $g.FillPath((New-Grad 12 -64 40 -30 "#FDE047" "#CA8A04"), $tabPath)
            $g.DrawPath($outPen, $tabPath)
            $g.FillEllipse($skinGrad, 8, -48, 14, 14)
            $g.DrawEllipse($outPen, 8, -48, 14, 14)
        }
    }

    $g.Restore($st)
}

function Draw-ChibiSheep([System.Drawing.Graphics]$g, [float]$sx, [float]$sy) {
    $outPen = New-Object System.Drawing.Pen((ColorFromHex "#2B1B12"), 2.5)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#24170B" 90)), $sx-22, $sy+8, 44, 14)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#451A03")), $sx-12, $sy+2, 6, 12)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#451A03")), $sx+6, $sy+2, 6, 12)
    # Fluffy wool cloud body
    $g.FillEllipse((New-Grad ($sx-22) ($sy-18) ($sx+22) ($sy+10) "#FFFFFF" "#E5E0D8"), $sx-22, $sy-16, 44, 28)
    $g.DrawEllipse($outPen, $sx-22, $sy-16, 44, 28)
    # Cute dark face
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#451A03")), $sx+8, $sy-14, 18, 16)
    $g.DrawEllipse($outPen, $sx+8, $sy-14, 18, 16)
    $g.FillEllipse([System.Drawing.Brushes]::White, $sx+16, $sy-10, 4, 4)
}

# ==============================================================================
# BOARD 1: Q-VERSION COMMERCIAL CONCEPT MOCKUP (1920 x 1080)
# Inspired by Whiteout Survival ($3B+) + Cult of the Lamb ($67M+) + Thronefall
# ==============================================================================
$W = 1920
$H = 1080
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

# 1. Warm Vibrant Toy-Box Oasis & Canaan Hillside Background
$bgGrad = New-Grad 0 0 0 $H "#7DD3FC" "#FDE68A"
$g.FillRectangle($bgGrad, 0, 0, $W, 320)

# Distant Rolling Cozy Hills
Draw-ClosedCurve $g (New-Grad 0 180 0 420 "#86EFAC" "#4ADE80") $null @(-100,340, 250,210, 680,265, 1180,195, 1620,250, 2020,190, 2020,450, -100,450) 0.4
# Main Sunny Sandy-Grass Diorama Meadow
$meadowGrad = New-Grad 0 280 0 $H "#FDE68A" "#D9A05B"
$g.FillRectangle($meadowGrad, 0, 280, $W, ($H - 280))

# Lush Green Oasis Grass Patches around Spring & Jordan East
$g.FillEllipse((New-Grad 40 420 520 820 "#86EFAC" "#22C55E"), 30, 440, 490, 340)
$g.FillEllipse((New-Grad 1260 360 1880 780 "#BBF7D0" "#4ADE80"), 1260, 380, 620, 360)

# Cute Toy-Box Olive Trees & Boulders on the Hills
$outPen = New-Object System.Drawing.Pen((ColorFromHex "#2B1B12"), 3.2)
foreach ($tr in @( @(140,340,1.0), @(820,250,0.82), @(1760,310,1.05) )) {
    $tx = $tr[0]; $ty = $tr[1]; $sc = $tr[2]
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#24170B" 75)), ($tx-45*$sc), ($ty-8), (90*$sc), (22*$sc))
    $trunkP = New-RoundedRectPath ($tx-16*$sc) ($ty-85*$sc) (32*$sc) (85*$sc) 10
    $g.FillPath((New-Grad ($tx-16) ($ty-85) ($tx+16) $ty "#92400E" "#5C2808"), $trunkP)
    $g.DrawPath($outPen, $trunkP)
    $g.FillEllipse((New-Grad ($tx-60) ($ty-150) ($tx+60) ($ty-70) "#4ADE80" "#15803D"), ($tx-58*$sc), ($ty-142*$sc), (116*$sc), (76*$sc))
    $g.DrawEllipse($outPen, ($tx-58*$sc), ($ty-142*$sc), (116*$sc), (76*$sc))
    $g.FillEllipse((New-Grad ($tx-42) ($ty-172) ($tx+42) ($ty-105) "#86EFAC" "#22C55E"), ($tx-42*$sc), ($ty-168*$sc), (84*$sc), (58*$sc))
    $g.DrawEllipse($outPen, ($tx-42*$sc), ($ty-168*$sc), (84*$sc), (58*$sc))
}

# Cozy Dirt Roads radiating from the Central Covenant Altar
$roadPen = New-Object System.Drawing.Pen((ColorFromHex "#EAB308" 115), 54)
$roadPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$roadPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawLine($roadPen, 960, 540, 290, 610)
$g.DrawLine($roadPen, 960, 540, 520, 380)
$g.DrawLine($roadPen, 960, 540, 1460, 560)
$g.DrawLine($roadPen, 960, 540, 1390, 360)

# 2. CENTERPIECE: "THE ALTAR OF COVENANT" (Like Whiteout Survival's Central Furnace + Cult of the Lamb's Shrine!)
# Warm Sacred Sanctuary Aura Circle
$auraPen = New-Object System.Drawing.Pen((ColorFromHex "#F59E0B" 190), 4)
$auraPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A" 55)), 660, 360, 600, 340)
$g.DrawEllipse($auraPen, 660, 360, 600, 340)

$outPen = New-Object System.Drawing.Pen((ColorFromHex "#2B1B12"), 3.2)
# Altar Stone Base
$altarBase = New-RoundedRectPath 875 465 170 95 24
$g.FillPath((New-Grad 875 465 1045 560 "#F5F5F4" "#A8A29E"), $altarBase)
$g.DrawPath($outPen, $altarBase)
$altarTop = New-RoundedRectPath 895 440 130 45 14
$g.FillPath((New-Grad 895 440 1025 485 "#E7E5E4" "#78716C"), $altarTop)
$g.DrawPath($outPen, $altarTop)
# Big Cozy Sacred Flame on Altar!
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F59E0B" 120)), 890, 345, 140, 140)
Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#EF4444")) $outPen @(930,445, 918,395, 960,350, 1002,395, 990,445) 0.4
Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047")) $null @(942,445, 936,410, 960,378, 984,410, 978,445) 0.4

# 3. BUILDING NODE 1 (Upper-Left): Lv.2 Patriarch's Cozy Tent (Rest & Population Hub)
$tentPath = New-RoundedRectPath 380 250 260 155 30
$g.FillPath((New-Grad 380 250 640 405 "#B45309" "#78350F"), $tentPath)
$g.DrawPath($outPen, $tentPath)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE68A")) $outPen @(420,250, 510,195, 600,250)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#451A03")) $outPen @(475,405, 510,315, 545,405)

# 4. BUILDING NODE 2 (Left Oasis): Lv.2 Sparkling Spring Well
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#D6D3D1")), 150, 545, 220, 110)
$g.DrawEllipse($outPen, 150, 545, 220, 110)
$g.FillEllipse((New-Grad 170 560 350 640 "#38BDF8" "#0284C7"), 170, 558, 180, 84)
$g.DrawEllipse($outPen, 170, 558, 180, 84)

# 5. BUILDING NODE 3 (Upper-Right): Buildable Slot [Upgrade Sheepfold / Watchtower] (Thronefall style slot!)
$slotPath = New-RoundedRectPath 1280 255 230 130 26
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF3C7" 190)), $slotPath)
$slotPen = New-Object System.Drawing.Pen((ColorFromHex "#D97706"), 3.5)
$slotPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawPath($slotPen, $slotPath)

# 6. Draw Cute Fluffy Chibi Sheep in East Pasture + Red Dispute Bubble
Draw-ChibiSheep $g 1380 565
Draw-ChibiSheep $g 1455 595
Draw-ChibiSheep $g 1520 555
Draw-ChibiSheep $g 1595 590

# 7. Draw All 7 Commercial Q-Version Chibi Heroes in Action!
Draw-ChibiHero $g 555 435 0.90 "sarah" $false
Draw-ChibiHero $g 760 445 0.88 "melchizedek" $false
Draw-ChibiHero $g 1220 395 0.92 "ur" $false
Draw-ChibiHero $g 345 645 0.96 "hagar" $false
Draw-ChibiHero $g 960 695 1.12 "abraham" $true
Draw-ChibiHero $g 1335 665 1.00 "lot" $false
Draw-ChibiHero $g 1690 505 0.94 "eliezer" $false

# 8. COMMERCIAL "1-TAP BUBBLES" OVER BUILDINGS & HEROES (Whiteout Survival / Cult of the Lamb UX!)
$fBubTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$fBubSub = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)

$bubbles = @(
    @{ x = 960; y = 320; w = 230; bg = "#1E293B"; border = "#FACC15"; text = "★ Lv.2 伯特利立约祭坛"; sub = "圣火庇护范围：全队体力恢复 +25%" },
    @{ x = 510; y = 175; w = 195; bg = "#1E293B"; border = "#FDE68A"; text = "▲ Lv.2 族长黑毛大帐"; sub = "撒拉驻守：夜间全员士气 +15" },
    @{ x = 1395; y = 225; w = 220; bg = "#FEF3C7"; border = "#EA580C"; text = "✚ 点击建造：山脊守望塔"; sub = "耗材：木料 2 · 防御夜兽奇袭"; darkText = $true },
    @{ x = 345; y = 465; w = 175; bg = "#0284C7"; border = "#BAE6FD"; text = "● 汲水完成！+3 陶罐"; sub = "点击气泡一键收取" },
    @{ x = 1335; y = 475; w = 235; bg = "#991B1B"; border = "#FCA5A5"; text = "⚡ 牧人争草事件！(创13:7)"; sub = "点击派亚伯拉罕前往调停" },
    @{ x = 1690; y = 325; w = 195; bg = "#14532D"; border = "#86EFAC"; text = "✦ 以利以谢：夜袭待命"; sub = "已集结 318 家丁精锐" }
)

foreach ($b in $bubbles) {
    $bx = $b.x - $b.w / 2.0
    $by = $b.y
    $bPath = New-RoundedRectPath $bx $by $b.w 52 14
    $g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex $b.bg 240)), $bPath)
    $g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex $b.border), 2.5)), $bPath)
    $tCol = if ($b.darkText) { ColorFromHex "#7C2D12" } else { [System.Drawing.Color]::White }
    $sCol = if ($b.darkText) { ColorFromHex "#9A3412" } else { ColorFromHex "#FDE68A" }
    $g.DrawString($b.text, $fBubTitle, (New-Object System.Drawing.SolidBrush($tCol)), ($bx + 12), ($by + 6))
    $g.DrawString($b.sub, $fBubSub, (New-Object System.Drawing.SolidBrush($sCol)), ($bx + 12), ($by + 28))
}

# ==============================================================================
# 9. COMMERCIAL HUD LAYER (Top Resource & Day/Night Bar + Bottom Hero & Skill Dock)
# ==============================================================================
$fTopTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$fTopNum = New-Object System.Drawing.Font("Microsoft YaHei UI", 13, [System.Drawing.FontStyle]::Bold)

# Top-Left Chapter & Epoch Pill
$tlBox = New-RoundedRectPath 24 20 460 72 20
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#1E1B18" 235)), $tlBox)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#F59E0B"), 2.5)), $tlBox)
$g.DrawString("《应许之地：Q版旧约纪》 · 第一章", $fTopTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047")), 42, 28)
$g.DrawString("创世记 13 章：伯特利营地  |  营地繁荣度 Lv.3", $fBubSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#E7E5E4")), 44, 60)

# Top-Center Thronefall-Style Day/Night Phase Switcher!
$tcBox = New-RoundedRectPath 690 20 540 72 22
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#1E1B18" 235)), $tcBox)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#38BDF8"), 2.5)), $tcBox)
$g.DrawString("☀ 白昼建设阶段 (剩余 45 秒)   ➔   ☾ 今夜预告：山脊野兽袭羊", $fBubTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A")), 715, 30)
$g.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#334155")), 715, 62, 490, 14)
$g.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#F59E0B")), 715, 62, 340, 14)

# Top-Right Currency & Camp Supplies Pills
$trBox = New-RoundedRectPath 1290 20 606 72 20
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#1E1B18" 235)), $trBox)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#F59E0B"), 2.5)), $trBox)
$g.DrawString("● 泉水 24/30    ■ 木料 18    ◆ 羊群 16    ✦ 盟约信仰 120", $fTopNum, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF3C7")), 1318, 40)

# Bottom Commercial Dock: Left Quest Card + Center 3 Tactile Skill Cards + Right "Start Night / Auto-Work" Button
$questBox = New-RoundedRectPath 24 895 490 160 22
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#1E1B18" 242)), $questBox)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#22C55E"), 3)), $questBox)
$g.DrawString("★ 主线任务（阶段 2/3）：平息牧人争执", $fTopNum, (New-Object System.Drawing.SolidBrush(ColorFromHex "#86EFAC")), 46, 912)
$g.DrawString("「亚伯兰的牧人和罗得的牧人相争。」（创 13:7）", $fBubTitle, [System.Drawing.Brushes]::White, 46, 945)
$g.DrawString("目标：扩建 1 座守望塔，并打出【兄长的礼让】与罗得和平分群", $fBubSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#D6D3D1")), 46, 976)
$rewBox = New-RoundedRectPath 44 1006 446 34 10
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#14532D")), $rewBox)
$g.DrawString("✦ 通关奖励：免费领 SSR【以利以谢】+ 开启第二章【但地夜袭】", $fBubSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A")), 54, 1014)

$qCards = @(
    @{ tag = "SSR 亚伯拉罕 · 盟约技"; title = "《兄长的礼让》"; cost = "● 泉水 -4  |  ✦ 信仰 +30"; desc = "让罗得优先选择约旦河平原，立即平息争执并升满营地和睦！"; col = "#FEF3C7"; border = "#F59E0B" },
    @{ tag = "SSR 以利以谢 · 夜战技"; title = "《三百一十八火把阵》"; cost = "■ 木料 -2  |  ☾ 夜晚防卫 +100%"; desc = "围绕营地立起松脂火把圈，夜间自动驱离野兽并保护羊群！"; col = "#ECFDF5"; border = "#10B981" },
    @{ tag = "SR 撒拉 & 夏甲 · 丰收技"; title = "《庇耳拉海莱涌泉》"; cost = "冷却 30秒  |  ● 泉水产量 x2"; desc = "主母统筹配给、夏甲勘探暗泉，全营地劳作速度提升 50%！"; col = "#F0F9FF"; border = "#0284C7" }
)

for ($c = 0; $c -lt 3; $c++) {
    $qc = $qCards[$c]
    $cx = 540 + $c * 340
    $cy = 895
    $cBox = New-RoundedRectPath $cx $cy 322 160 20
    $g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex $qc.col 248)), $cBox)
    $g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex $qc.border), 3.5)), $cBox)
    $g.DrawString($qc.tag, $fBubSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#78350F")), ($cx + 16), ($cy + 14))
    $g.DrawString($qc.title, $fTopNum, (New-Object System.Drawing.SolidBrush(ColorFromHex "#1C1917")), ($cx + 16), ($cy + 38))
    $g.DrawString($qc.cost, $fBubSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#B45309")), ($cx + 16), ($cy + 68))
    $rDesc = New-Object System.Drawing.RectangleF(($cx + 16), ($cy + 94), 290, 56)
    $g.DrawString($qc.desc, $fBubSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#44403C")), $rDesc)
}

# Right Action Button (Thronefall / Whiteout style big CTA button!)
$ctaBox = New-RoundedRectPath 1575 895 320 160 24
$g.FillPath((New-Grad 1575 895 1575 1055 "#F59E0B" "#D97706"), $ctaBox)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#FEF08A"), 3.5)), $ctaBox)
$g.DrawString("▶ 一键委派 / 迎战夜晚", $fTopTitle, [System.Drawing.Brushes]::White, 1605, 935)
$g.DrawString("白昼自动采集 · 夜晚率队迎敌", $fBubTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF3C7")), 1625, 980)

$outQConcept = Join-Path $artifactDir "q-version-commercial-concept-v3.png"
$bmp.Save($outQConcept, [System.Drawing.Imaging.ImageFormat]::Png)
Copy-Item $outQConcept (Join-Path $proposalDir "q-version-commercial-concept-v3.png") -Force
$g.Dispose()
$bmp.Dispose()

# ==============================================================================
# BOARD 2: Q-VERSION COMMERCIAL CHARACTER LINEUP & PROGRESSION SHEET (1920 x 1160)
# ==============================================================================
$CW = 1920
$CH = 1160
$cbmp = New-Object System.Drawing.Bitmap($CW, $CH)
$cg = [System.Drawing.Graphics]::FromImage($cbmp)
$cg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$cg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$cg.FillRectangle((New-Grad 0 0 0 $CH "#FFFBEB" "#FDE68A"), 0, 0, $CW, $CH)
$cg.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#1E1B18")), 0, 0, $CW, 112)
$cg.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#F59E0B"), 4)), 0, 112, $CW, 112)

$fSheetTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", 24, [System.Drawing.FontStyle]::Bold)
$fSheetSub = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Regular)
$cg.DrawString("《应许之地：Q版旧约纪》 · 商业化 Q 版角色设计与养成体系总表（2.3头身玩具沙盘风）", $fSheetTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047")), 40, 22)
$cg.DrawString("COMMERCIAL CHIBI CHARACTER BIBLE v3.0  |  对标《Cult of the Lamb》《无尽冬日》高亲和力商业化美术  |  兼顾圣经历史还原与英雄收集养成留存", $fSheetSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#E7E5E4")), 42, 72)

$qRoster = @(
    @{
        id = "abraham"; tier = "SSR · 传奇族长"; name = "亚伯拉罕"; role = "统帅 / 盟约核心"; col = "#2563EB"
        look = "2.3头身圆润比例、蓬松大胡子、闪米特蓝白头巾、条纹流苏披肩、星芒牧羊杖。"
        skill = "【被动：立约之父】营地圣火范围 +30%；【主动：兄长的礼让】平息部族争执并永久提升全族信仰产出。"
        comm = "商业化锚点：首章初始核心统帅，随旧约章节推进解锁「信心之父」觉醒外观。"
    },
    @{
        id = "sarah"; tier = "SSR · 传奇主母"; name = "撒拉"; role = "内政 / 士气辅助"; col = "#E11D48"
        look = "暖红披巾配金耳坠、灵动大眼、双手捧发光迦南单嘴陶油灯、温和微笑。"
        skill = "【被动：主帐金灯】所有帐棚体力恢复速度 +50%；【主动：欢笑之赐】立即恢复全队体力并产出额外口粮。"
        comm = "商业化锚点：营地内政第一人权卡，解决中后期高强度建设与远征的体力瓶颈。"
    },
    @{
        id = "lot"; tier = "SR · 平原牧长"; name = "罗得"; role = "资源 / 商路贸易"; col = "#9333EA"
        look = "紫袍配红头带、身上缠绕粗麻牧绳、手持沉甸甸的黄金贸易钱袋。"
        skill = "【被动：双群并牧】羊群繁殖速度 +40%（但增加草场拥挤度）；【分群后】解锁「约旦河平原商队」自动送来物资。"
        comm = "商业化锚点：第一章剧情冲突核心人物，第二章【但地夜袭】的核心营救目标。"
    },
    @{
        id = "eliezer"; tier = "SSR · 夜袭统领"; name = "以利以谢"; role = "战斗 / 夜间防卫"; col = "#16A34A"
        look = "绿甲皮护肩、坚毅神情、高举熊熊燃烧的松脂大火把（创15:2 大马士革家宰）。"
        skill = "【被动：三百一十八精锐】家丁护卫队攻击与移速 +35%；【主动：但地夜袭】召唤火把分队击溃夜间来袭敌军。"
        comm = "商业化锚点：完成第一章主线免费赠送的强力 SSR 战斗统领，完美衔接第二章夜战！"
    },
    @{
        id = "hagar"; tier = "SR · 旷野寻泉"; name = "夏甲"; role = "采集 / 荒漠探索"; col = "#0D9488"
        look = "绿松石色衣裙、埃及风头巾、怀抱装满清泉的大号双耳彩陶罐。"
        skill = "【被动：庇耳拉海莱之眼】水井产量翻倍，且能在干旱章节探测隐藏绿洲水脉。"
        comm = "商业化锚点：旷野迁徙章节（创16、创21、出埃及记）必备的水源保障核心角色。"
    },
    @{
        id = "ur"; tier = "SR · 首席巧匠"; name = "乌珥"; role = "建造 / 工事防御"; col = "#D97706"
        look = "橙棕工匠皮围裙、浓密络腮胡、肩扛超大号玩具感黄金木槌。"
        skill = "【被动：巨槌营造】建造与升级帐棚、石坛、守望塔耗时缩短 40%，木材消耗减少 1。"
        comm = "商业化锚点：对应《无尽冬日》建造加速队列与工匠养成线，极大提升基建爽感。"
    },
    @{
        id = "melchizedek"; tier = "SSR · 至高祭司"; name = "麦基洗德 / 亚希兰"; role = "祝祷 / 泥板科技"; col = "#6366F1"
        look = "深紫祭司长袍、黄金胸带、银白大胡子、手持发光的金色楔形文字泥板。"
        skill = "【被动：撒冷的饼和酒】战后全军零伤亡恢复；【主动：铭刻律法】解锁营地科技树与跨时代增益。"
        comm = "商业化锚点：创世记 14 章高光登场角色，统管全游戏的「泥板科技树与祝福系统」。"
    }
)

$cardW = 248
$gap = 18
$startX = 36
$fCardName = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$fCardSec = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)
$fCardBody = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.2, [System.Drawing.FontStyle]::Regular)

for ($i = 0; $i -lt $qRoster.Count; $i++) {
    $qr = $qRoster[$i]
    $cx = $startX + $i * ($cardW + $gap)
    $cy = 136

    $cPath = New-RoundedRectPath $cx $cy $cardW 985 22
    $cg.FillPath([System.Drawing.Brushes]::White, $cPath)
    $cg.DrawPath((New-Object System.Drawing.Pen((ColorFromHex $qr.col), 3.5)), $cPath)

    # Top Rarity Banner
    $topBanner = New-RoundedRectPath ($cx + 12) ($cy + 12) ($cardW - 24) 30 10
    $cg.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex $qr.col)), $topBanner)
    $cg.DrawString($qr.tier, $fBubTitle, [System.Drawing.Brushes]::White, ($cx + 24), ($cy + 16))

    # Toy-box Stage Pedestal
    $pedBox = New-RoundedRectPath ($cx + 14) ($cy + 52) ($cardW - 28) 290 18
    $cg.FillPath((New-Grad $cx ($cy+52) $cx ($cy+342) "#FEF3C7" "#FDE68A"), $pedBox)
    $cg.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#F59E0B"), 1.5)), $pedBox)

    # Draw Chibi Hero on Pedestal
    Draw-ChibiHero $cg ($cx + $cardW / 2.0) ($cy + 312) 1.38 $qr.id ($i -eq 0)

    $cg.DrawString($qr.name, $fCardName, (New-Object System.Drawing.SolidBrush(ColorFromHex "#1C1917")), ($cx + 16), ($cy + 354))
    $cg.DrawString($qr.role, $fBubTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex $qr.col)), ($cx + 16), ($cy + 388))

    $cg.DrawLine((New-Object System.Drawing.Pen(ColorFromHex "#E7E5E4" 2)), ($cx + 16), ($cy + 422), ($cx + $cardW - 16), ($cy + 422))

    $cg.DrawString("■ Q版造型与考据记忆点", $fCardSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#B45309")), ($cx + 16), ($cy + 436))
    $rLook = New-Object System.Drawing.RectangleF(($cx + 16), ($cy + 460), ($cardW - 32), 120)
    $cg.DrawString($qr.look, $fCardBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#44403C")), $rLook)

    $cg.DrawString("■ 核心技能与昼夜分工", $fCardSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#047857")), ($cx + 16), ($cy + 590))
    $rSkill = New-Object System.Drawing.RectangleF(($cx + 16), ($cy + 614), ($cardW - 32), 165)
    $cg.DrawString($qr.skill, $fCardBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#1C1917")), $rSkill)

    $commBox = New-RoundedRectPath ($cx + 12) ($cy + 795) ($cardW - 24) 172 14
    $cg.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#FFFBEB")), $commBox)
    $cg.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#F59E0B"), 1.5)), $commBox)
    $cg.DrawString("★ 商业化留存与投放价值", $fCardSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#D97706")), ($cx + 20), ($cy + 808))
    $rComm = New-Object System.Drawing.RectangleF(($cx + 20), ($cy + 834), ($cardW - 40), 125)
    $cg.DrawString($qr.comm, $fCardBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#44403C")), $rComm)
}

$outQChars = Join-Path $artifactDir "q-version-character-sheet-v3.png"
$cbmp.Save($outQChars, [System.Drawing.Imaging.ImageFormat]::Png)
Copy-Item $outQChars (Join-Path $proposalDir "q-version-character-sheet-v3.png") -Force
$cg.Dispose()
$cbmp.Dispose()
Write-Host "Successfully generated Commercial Q-Version Concept and Character Sheets."
