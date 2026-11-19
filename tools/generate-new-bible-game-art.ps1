Add-Type -AssemblyName System.Drawing

$artifactDir = "C:\Users\holyx\.gemini\antigravity\brain\6e568a4c-bd1a-4b4b-8be5-415b1cddfb8e"
$proposalDir = "c:\AI\gemini\promise-path-next\design\producer-proposal-v2"
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
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-Poly([System.Drawing.Graphics]$g, [System.Drawing.Brush]$brush, [System.Drawing.Pen]$pen, [float[]]$coords) {
    $pts = New-Object System.Drawing.PointF[] ($coords.Length / 2)
    for ($i = 0; $i -lt $pts.Length; $i++) {
        $pts[$i] = New-Object System.Drawing.PointF($coords[$i*2], $coords[$i*2+1])
    }
    if ($null -ne $brush) { $g.FillPolygon($brush, $pts) }
    if ($null -ne $pen) { $g.DrawPolygon($pen, $pts) }
}

function Draw-ClosedCurve([System.Drawing.Graphics]$g, [System.Drawing.Brush]$brush, [System.Drawing.Pen]$pen, [float[]]$coords, [float]$tension = 0.4) {
    $pts = New-Object System.Drawing.PointF[] ($coords.Length / 2)
    for ($i = 0; $i -lt $pts.Length; $i++) {
        $pts[$i] = New-Object System.Drawing.PointF($coords[$i*2], $coords[$i*2+1])
    }
    if ($null -ne $brush) { $g.FillClosedCurve($brush, $pts, [System.Drawing.Drawing2D.FillMode]::Winding, $tension) }
    if ($null -ne $pen) { $g.DrawClosedCurve($pen, $pts) }
}

function New-Grad([float]$x1, [float]$y1, [float]$x2, [float]$y2, [string]$c1, [string]$c2) {
    return New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF($x1, $y1)),
        (New-Object System.Drawing.PointF($x2, $y2)),
        (ColorFromHex $c1),
        (ColorFromHex $c2)
    )
}

# Richly Detailed Painterly Near-Eastern Figure Renderer (Expressive Face, Draped Folds, Authentic Props)
function Draw-DetailedBiblicalFigure([System.Drawing.Graphics]$g, [float]$cx, [float]$bottomY, [float]$scale, [string]$type, [bool]$selected = $false) {
    $state = $g.Save()
    $g.TranslateTransform($cx, $bottomY)
    $g.ScaleTransform($scale, $scale)

    $inkPen = New-Object System.Drawing.Pen((ColorFromHex "#1C130E" 230), 2.0)
    $foldPen = New-Object System.Drawing.Pen((ColorFromHex "#1C130E" 90), 1.4)
    $goldPen = New-Object System.Drawing.Pen((ColorFromHex "#E5B85B"), 2.2)

    $skinGrad = New-Grad -20 -185 20 -145 "#DFA77E" "#B57850"
    $skinDark = New-Object System.Drawing.SolidBrush(ColorFromHex "#9E6440")
    $hairDark = New-Grad -20 -190 20 -135 "#2B201A" "#140E0B"
    $hairWhite = New-Grad -20 -190 20 -120 "#F5EFE6" "#B8AEA0"
    $linenGrad = New-Grad -25 -150 25 -15 "#F3E9D2" "#C8B696"

    # 1. Ground Shadow & Selection Ring
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#0E0906" 155)), -42, -11, 84, 22)
    if ($selected) {
        $g.DrawEllipse((New-Object System.Drawing.Pen((ColorFromHex "#F5C451" 95), 8)), -54, -17, 108, 34)
        $g.DrawEllipse((New-Object System.Drawing.Pen((ColorFromHex "#FDE047"), 3.2)), -48, -14, 96, 28)
    }

    # Helper to draw expressive Semitic head with eyes, brows, nose, mouth, beard/hair
    function Draw-Head([string]$beardStyle, [string]$headwear, [string]$headColor1, [string]$headColor2, [string]$bandColor) {
        # Back of headscarf / hair
        if ($headwear -eq "keffiyeh" -or $headwear -eq "veil") {
            $hwBack = New-Grad -30 -192 25 -115 $headColor1 $headColor2
            Draw-ClosedCurve $g $hwBack $inkPen @(-18,-186, -34,-148, -26,-116, 12,-125, 20,-165) 0.4
        } else {
            Draw-ClosedCurve $g $hairDark $inkPen @(-18,-184, -22,-155, -14,-142, 14,-144, 18,-178) 0.4
        }

        # Neck
        $g.FillRectangle($skinDark, -7, -152, 14, 14)

        # Face Oval (3/4 view facing slightly right)
        $g.FillEllipse($skinGrad, -14, -184, 29, 34)
        $g.DrawEllipse($inkPen, -14, -184, 29, 34)

        # Warm cheek blush
        $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#C85A42" 55)), -8, -166, 9, 6)

        # Eyes (3/4 perspective: left eye at x=-2, right eye at x=+8)
        $g.FillEllipse([System.Drawing.Brushes]::White, -5, -171, 6.5, 5.0)
        $g.FillEllipse([System.Drawing.Brushes]::White, 5.5, -171, 6.0, 5.0)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#241811")), -3, -170.5, 4.0, 4.2)
        $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#241811")), 7.2, -170.5, 4.0, 4.2)
        # Eye catchlights
        $g.FillEllipse([System.Drawing.Brushes]::White, -2.2, -170, 1.6, 1.6)
        $g.FillEllipse([System.Drawing.Brushes]::White, 8.0, -170, 1.6, 1.6)

        # Expressive Eyebrows
        $browCol = if ($beardStyle -eq "white") { ColorFromHex "#D6CFC2" } else { ColorFromHex "#231914" }
        $browPen = New-Object System.Drawing.Pen($browCol, 2.4)
        $g.DrawLine($browPen, -6.5, -173.5, 1.0, -174.5)
        $g.DrawLine($browPen, 5.0, -174.5, 11.5, -173.0)

        # Nose bridge & tip
        $nosePen = New-Object System.Drawing.Pen((ColorFromHex "#8C5434"), 1.8)
        $g.DrawLines($nosePen, [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF(3.5, -171)),
            (New-Object System.Drawing.PointF(6.5, -162)),
            (New-Object System.Drawing.PointF(2.5, -161))
        ))

        # Beard or Mouth
        if ($beardStyle -eq "full" -or $beardStyle -eq "white" -or $beardStyle -eq "trimmed") {
            $bBrush = if ($beardStyle -eq "white") { $hairWhite } else { $hairDark }
            $bLen = if ($beardStyle -eq "white") { -126 } elseif ($beardStyle -eq "full") { -136 } else { -144 }
            Draw-ClosedCurve $g $bBrush $inkPen @(-13,-164, -14,-150, -3,$bLen, 11,-148, 14,-162, 4,-158, -5,-158) 0.35
            # Moustache
            Draw-ClosedCurve $g $bBrush $null @(-6,-159, 3,-161, 12,-158, 4,-155) 0.3
            # Gentle mouth line
            $g.DrawLine((New-Object System.Drawing.Pen(ColorFromHex "#D99B72" 180)), 0, -156, 6, -156)
        } else {
            # Female / Clean-shaven warm smile & earring
            $g.DrawArc((New-Object System.Drawing.Pen((ColorFromHex "#8C3B2B"), 1.8)), 0, -159, 7, 4, 15, 150)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#E5B85B")), -13, -161, 4.5, 5.5)
        }

        # Top Headscarf / Crown / Fillet
        $hwTop = New-Grad -22 -194 20 -160 $headColor1 $headColor2
        if ($headwear -eq "keffiyeh" -or $headwear -eq "veil") {
            Draw-ClosedCurve $g $hwTop $inkPen @(-17,-176, -12,-191, 8,-191, 15,-177, 4,-181, -10,-178) 0.4
            # Side drape over left shoulder
            Draw-ClosedCurve $g $hwTop $inkPen @(-17,-176, -25,-150, -19,-118, -11,-128, -12,-162) 0.35
            # Cord / Fillet band
            $bandPen = New-Object System.Drawing.Pen((ColorFromHex $bandColor), 3.5)
            $g.DrawCurve($bandPen, [System.Drawing.PointF[]]@(
                (New-Object System.Drawing.PointF(-17, -179)),
                (New-Object System.Drawing.PointF(-1, -184)),
                (New-Object System.Drawing.PointF(14, -179))
            ))
        } else {
            # Curls & Woven Headband
            Draw-ClosedCurve $g $hairDark $inkPen @(-16,-177, -10,-190, 9,-190, 15,-177, 3,-180) 0.4
            $bandPen = New-Object System.Drawing.Pen((ColorFromHex $bandColor), 3.8)
            $g.DrawCurve($bandPen, [System.Drawing.PointF[]]@(
                (New-Object System.Drawing.PointF(-16, -178)),
                (New-Object System.Drawing.PointF(0, -182)),
                (New-Object System.Drawing.PointF(14, -177))
            ))
        }
    }

    # Helper to draw Detailed Legs & Strapped Canaanite Sandals
    function Draw-Sandals([float]$lx = -14, [float]$rx = 7, [float]$topY = -26) {
        foreach ($fx in @($lx, $rx)) {
            $g.FillRectangle($skinDark, $fx, $topY, 9, (-4 - $topY))
            $g.DrawRectangle($inkPen, $fx, $topY, 9, (-4 - $topY))
            # Leather sandal sole & straps
            $g.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#4A2E1B")), ($fx - 2), -6, 14, 5)
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#5C3A21"), 2)), $fx, -12, ($fx + 9), -6)
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#5C3A21"), 2)), $fx, -15, ($fx + 9), -15)
        }
    }

    switch ($type) {
        "abraham" {
            Draw-Sandals -15 7 -26
            # Back Crimson Cloak
            $cloakGrad = New-Grad -40 -148 30 -20 "#8C3325" "#4F1A12"
            Draw-ClosedCurve $g $cloakGrad $inkPen @(-24,-144, -40,-65, -32,-22, 22,-22, 24,-140) 0.25

            # Inner Cream Linen Tunic with Fringe
            Draw-Poly $g $linenGrad $inkPen @(-19,-146, -24,-20, 24,-20, 18,-146)
            $g.DrawLine($foldPen, -6, -135, -10, -22)
            $g.DrawLine($foldPen, 6, -135, 8, -22)

            # Lapis Blue Over-Robe (Beni Hasan Semitic Chieftain Style)
            $lapisGrad = New-Grad -25 -148 20 -30 "#264B78" "#142945"
            Draw-Poly $g $lapisGrad $inkPen @(-22,-148, -28,-30, -2,-30, 6,-146)
            Draw-Poly $g $lapisGrad $inkPen @(8,-146, 12,-34, 24,-34, 20,-144)

            # Ornate Diagonal Woven Amorite Sash with Fringe
            $sashGrad = New-Grad -18 -144 22 -55 "#E0B25B" "#9E6B24"
            Draw-Poly $g $sashGrad $inkPen @(-16,-145, 20,-76, 22,-54, -19,-122)
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#8C3325"), 2.5)), -15, -136, 20, -68)
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#1E3A5F"), 2.0)), -17, -129, 21, -61)

            # Left & Right Arms + Hands
            Draw-ClosedCurve $g $lapisGrad $inkPen @(-22,-142, -32,-106, -22,-96, -14,-128) 0.3
            $g.FillEllipse($skinGrad, -28, -100, 11, 11)
            $g.DrawEllipse($inkPen, -28, -100, 11, 11)

            Draw-ClosedCurve $g $linenGrad $inkPen @(14,-140, 32,-116, 28,-102, 12,-124) 0.3
            $g.FillEllipse($skinGrad, 24, -118, 12, 12)
            $g.DrawEllipse($inkPen, 24, -118, 12, 12)

            Draw-Head "full" "keffiyeh" "#F3E9D2" "#C8B696" "#264B78"

            # Gnarled Shepherd's Crook with Bronze Covenant Ring
            $staffPen = New-Object System.Drawing.Pen((ColorFromHex "#5C3A21"), 5.0)
            $g.DrawLine($staffPen, 31, -2, 31, -190)
            $g.DrawArc($staffPen, 19, -212, 26, 28, 165, 235)
            $g.DrawLine($goldPen, 28, -135, 34, -135)
        }
        "sarah" {
            Draw-Sandals -13 5 -20
            # Terracotta Royal Matriarch Dress
            $dressGrad = New-Grad -26 -144 26 -16 "#B04638" "#6E241B"
            Draw-Poly $g $dressGrad $inkPen @(-17,-144, -27,-16, 27,-16, 17,-144)
            # Center Embroidered Panel
            Draw-Poly $g $linenGrad $inkPen @(-7,-142, -10,-16, 10,-16, 7,-142)
            $g.DrawLine($goldPen, -25, -26, 25, -26)

            # Draped Shawl over Shoulders
            $shawlGrad = New-Grad -24 -146 24 -75 "#C85A48" "#8C3325"
            Draw-ClosedCurve $g $shawlGrad $inkPen @(-21,-144, -28,-85, -8,-92, 0,-138) 0.3
            Draw-ClosedCurve $g $shawlGrad $inkPen @(6,-142, 24,-96, 12,-85, -2,-125) 0.3

            Draw-Head "none" "veil" "#F5EFE6" "#D6C7AE" "#D4AF37"

            # Hands Clasped & Glowing Terracotta Covenant Lamp
            $g.FillEllipse($skinGrad, 8, -114, 12, 10)
            $g.DrawEllipse($inkPen, 8, -114, 12, 10)
            # Warm Lamp Halo
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F59E0B" 85)), 4, -138, 42, 42)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047" 135)), 12, -130, 26, 26)
            # Clay Oil Lamp Body & Flame
            Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#B45309")) $inkPen @(14,-112, 24,-106, 35,-112, 26,-116) 0.4
            Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A")) $null @(26,-113, 22,-126, 28,-134, 32,-124) 0.3
        }
        "lot" {
            Draw-Sandals -15 7 -24
            # Tunic & Purple-Brown Jordan Merchant Mantle
            $tunicGrad = New-Grad -22 -146 22 -22 "#855B3C" "#543622"
            Draw-Poly $g $tunicGrad $inkPen @(-18,-146, -24,-22, 24,-22, 18,-146)

            $mantleGrad = New-Grad -24 -146 26 -48 "#6E3850" "#3D1B2B"
            Draw-Poly $g $mantleGrad $inkPen @(-21,-146, 19,-130, 26,-48, -23,-72)
            $g.DrawLine($goldPen, -21, -72, 25, -48)

            # Braided Hemp Shepherd Rope Coils over Right Shoulder
            $ropePen = New-Object System.Drawing.Pen((ColorFromHex "#DFC286"), 4.8)
            $g.DrawEllipse($ropePen, -24, -144, 24, 42)
            $g.DrawEllipse($inkPen, -24, -144, 24, 42)

            # Arms & Hands
            $g.FillEllipse($skinGrad, -12, -112, 11, 11)
            $g.FillEllipse($skinGrad, 18, -118, 11, 11)

            Draw-Head "trimmed" "headband" "#2B201A" "#140E0B" "#A44235"

            # Bronze Balance Scales of the City Gate
            $g.DrawLine($goldPen, 26, -126, 26, -92)
            $g.DrawLine($goldPen, 12, -108, 40, -108)
            $g.DrawLine((New-Object System.Drawing.Pen(ColorFromHex "#C8A96E")), 14, -108, 14, -94)
            $g.DrawLine((New-Object System.Drawing.Pen(ColorFromHex "#C8A96E")), 38, -108, 38, -94)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#E5B85B")), 9, -95, 11, 5)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#E5B85B")), 33, -95, 11, 5)
        }
        "eliezer" {
            Draw-Sandals -15 7 -26
            # Syrian Recurve Composite Bow on Back
            $bowPen = New-Object System.Drawing.Pen((ColorFromHex "#7A4824"), 4.2)
            $g.DrawArc($bowPen, -36, -172, 32, 102, 105, 165)

            # Olive Scout Tunic & Scale-Stitched Leather Cuirass
            $scoutGrad = New-Grad -22 -148 22 -26 "#466349" "#283B2A"
            Draw-Poly $g $scoutGrad $inkPen @(-17,-146, -23,-26, 23,-26, 17,-146)

            $cuirassGrad = New-Grad -20 -146 20 -86 "#8C5834" "#54321B"
            Draw-Poly $g $cuirassGrad $inkPen @(-19,-146, 19,-146, 15,-86, -15,-86)
            $g.DrawLine($goldPen, -16, -144, 14, -88)
            $g.DrawLine($goldPen, -15, -88, 15, -88)

            # Raised Right Arm Holding Blazing Night-Raid Torch
            Draw-ClosedCurve $g $scoutGrad $inkPen @(14,-140, 32,-158, 36,-142, 16,-122) 0.3
            $g.FillEllipse($skinGrad, 28, -162, 11, 11)

            Draw-Head "trimmed" "headband" "#2B201A" "#140E0B" "#8C5834"

            # Blazing Torch (Gen 14:15 Night Raid at Dan)
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#4A2E1B"), 4.5)), 31, -115, 35, -182)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F97316" 95)), 12, -224, 48, 48)
            Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#EF4444")) $null @(28,-180, 22,-202, 36,-218, 45,-196, 39,-180) 0.35
            Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A")) $null @(31,-181, 28,-196, 35,-206, 40,-192) 0.35
        }
        "hagar" {
            Draw-Sandals -13 5 -20
            # Pleated Egyptian Linen Skirt & Turquoise Wells-of-Beersheba Robe
            Draw-Poly $g $linenGrad $inkPen @(-16,-142, -24,-18, 24,-18, 16,-142)
            for ($pl = -18; $pl -le 18; $pl += 6) {
                $g.DrawLine($foldPen, ($pl * 0.7), -95, $pl, -18)
            }
            $tealGrad = New-Grad -20 -144 20 -58 "#2E7378" "#194447"
            Draw-Poly $g $tealGrad $inkPen @(-18,-144, 18,-144, 14,-58, -16,-78)
            $g.DrawLine($goldPen, -16, -78, 14, -58)

            Draw-Head "none" "keffiyeh" "#EAE0C8" "#C2B295" "#2E7378"

            # Holding Middle Bronze Age Painted Canaanite Amphora (Water Jar)
            $jarGrad = New-Grad 6 -138 38 -96 "#C86D44" "#7D3C1F"
            $g.FillEllipse($jarGrad, 8, -134, 28, 36)
            $g.DrawEllipse($inkPen, 8, -134, 28, 36)
            $g.FillRectangle($jarGrad, 15, -142, 14, 9)
            $g.DrawRectangle($inkPen, 15, -142, 14, 9)
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#3B1E10"), 2)), 10, -116, 34, -116)
            # Hand cradling jar
            $g.FillEllipse($skinGrad, 6, -116, 11, 10)
            $g.DrawEllipse($inkPen, 6, -116, 11, 10)
        }
        "ur" {
            Draw-Sandals -16 7 -26
            # Linen Kilt & Heavy Artisan Leather Apron
            Draw-Poly $g $linenGrad $inkPen @(-18,-110, -24,-24, 24,-24, 18,-110)
            $apronGrad = New-Grad -22 -146 22 -48 "#965833" "#593119"
            Draw-Poly $g $apronGrad $inkPen @(-20,-146, 20,-146, 22,-48, -22,-48)
            $g.DrawRectangle($inkPen, -18, -96, 16, 18)

            # Muscular Arms
            $g.FillEllipse($skinGrad, -28, -136, 12, 28)
            $g.DrawEllipse($inkPen, -28, -136, 12, 28)
            $g.FillEllipse($skinGrad, 16, -140, 13, 28)
            $g.DrawEllipse($inkPen, 16, -140, 13, 28)

            Draw-Head "full" "headband" "#2B201A" "#140E0B" "#B04638"

            # Bronze Duckbill Adze / Heavy Builder's Mallet over Right Shoulder
            $g.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#4A2E1B"), 4.8)), 22, -108, 36, -176)
            $bronzeGrad = New-Grad 18 -186 48 -164 "#E5B85B" "#9E6B24"
            Draw-Poly $g $bronzeGrad $inkPen @(20,-184, 48,-172, 44,-158, 16,-170)
        }
        "melchizedek" {
            Draw-Sandals -14 6 -18
            # Royal Violet-Indigo Scribe-Elder Robe & Gold Ephod Stole
            $elderGrad = New-Grad -26 -146 26 -16 "#4E3B63" "#291E36"
            Draw-Poly $g $elderGrad $inkPen @(-20,-146, -28,-16, 28,-16, 20,-146)
            $stoleGrad = New-Grad -10 -146 10 -16 "#E5B85B" "#9E7329"
            Draw-Poly $g $stoleGrad $inkPen @(-8,-146, 8,-146, 11,-16, -11,-16)

            Draw-Head "white" "keffiyeh" "#F5EFE6" "#C8BFA8" "#D4AF37"

            # Holding Inscribed Cuneiform Clay Tablet & Stylus
            $tabGrad = New-Grad 8 -134 38 -96 "#D48C5E" "#965B36"
            Draw-Poly $g $tabGrad $inkPen @(10,-132, 36,-126, 33,-94, 8,-100)
            # Cuneiform script lines on tablet
            $g.DrawLine($foldPen, 14, -122, 31, -118)
            $g.DrawLine($foldPen, 13, -114, 30, -110)
            $g.DrawLine($foldPen, 12, -106, 28, -102)
            $g.FillEllipse($skinGrad, 6, -116, 10, 10)
        }
    }

    $g.Restore($state)
}

function Draw-DetailedOliveTree([System.Drawing.Graphics]$g, [float]$tx, [float]$ty, [float]$sc) {
    $st = $g.Save()
    $g.TranslateTransform($tx, $ty)
    $g.ScaleTransform($sc, $sc)
    $inkPen = New-Object System.Drawing.Pen((ColorFromHex "#1C130E" 200), 2.0)
    $trunkGrad = New-Grad -25 -120 25 0 "#6E4B30" "#3D2717"

    # Gnarled roots & trunk
    Draw-ClosedCurve $g $trunkGrad $inkPen @(-28,0, -16,-35, -14,-85, -36,-125, -24,-132, -4,-95, 16,-130, 28,-122, 10,-82, 14,-32, 26,0) 0.35

    # Layered Olive Foliage Clusters
    $clusters = @(
        @(-45,-145, 72, 48, "#4A6141"),
        @(10,-152, 68, 46, "#4A6141"),
        @(-22,-175, 84, 54, "#5E7851"),
        @(-52,-132, 56, 38, "#6E8A5E"),
        @(18,-136, 58, 38, "#6E8A5E"),
        @(-14,-162, 66, 42, "#849E6F")
    )
    foreach ($cl in $clusters) {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex $cl[4])), $cl[0], $cl[1], $cl[2], $cl[3])
        $g.DrawEllipse($inkPen, $cl[0], $cl[1], $cl[2], $cl[3])
    }
    $g.Restore($st)
}

# ==============================================================================
# BOARD 1: BRAND-NEW RUNTIME CONCEPT ART (1920 x 1080)
# ==============================================================================
$W = 1920
$H = 1080
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

# 1. Sky Gradient
$skyBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0, 0)),
    (New-Object System.Drawing.Point($W, 520)),
    (ColorFromHex "#0D182E"),
    (ColorFromHex "#C87A42")
)
$blend = New-Object System.Drawing.Drawing2D.ColorBlend(4)
$blend.Colors = @( (ColorFromHex "#0B1528"), (ColorFromHex "#1B3254"), (ColorFromHex "#7A3E38"), (ColorFromHex "#C87A42") )
$blend.Positions = @(0.0, 0.45, 0.78, 1.0)
$skyBrush.InterpolationColors = $blend
$g.FillRectangle($skyBrush, 0, 0, $W, 540)

# 2. Stars & Constellation
$rng = New-Object System.Random(1318)
for ($s = 0; $s -lt 180; $s++) {
    $sx = $rng.Next(40, 1880)
    $sy = $rng.Next(98, 350)
    $alpha = [int]([Math]::Max(35, 240 - ($sy * 0.52)))
    $sz = if ($s % 9 -eq 0) { 4.2 } elseif ($s % 3 -eq 0) { 2.6 } else { 1.5 }
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FFF6D6" $alpha)), $sx, $sy, $sz, $sz)
}
$constPen = New-Object System.Drawing.Pen((ColorFromHex "#FDE68A" 95), 1.3)
$constPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dot
$cPts = @( @(280,145), @(390,118), @(520,136), @(670,108), @(830,142), @(980,115), @(1140,148) )
for ($i = 0; $i -lt ($cPts.Count - 1); $i++) {
    $g.DrawLine($constPen, $cPts[$i][0], $cPts[$i][1], $cPts[$i+1][0], $cPts[$i+1][1])
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047" 220)), ($cPts[$i][0]-4), ($cPts[$i][1]-4), 8, 8)
}

$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F59E0B" 48)), 1380, 160, 320, 320)
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047" 90)), 1460, 230, 160, 160)

# 3. Layered Judean Hills & Jordan River Valley
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#282136")) $null @(
    0,410, 220,340, 480,375, 760,310, 1050,355, 1340,295, 1620,330, 1920,275, 1920,560, 0,560
)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#453134")) $null @(
    0,460, 180,395, 420,430, 690,370, 980,425, 1290,385, 1590,415, 1920,365, 1920,620, 0,620
)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#36594E")) $null @(
    1220,465, 1480,435, 1920,410, 1920,650, 1180,650
)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#64A8AB" 195)) $null @(
    1460,440, 1520,440, 1640,510, 1890,545, 1920,585, 1680,565, 1540,505
)

# 4. Main Isometric Playable Terraced Plateau
$groundBrush = New-Grad 0 460 0 $H "#C99E6B" "#6E4B2E"
Draw-Poly $g $groundBrush $null @( 0,485, 580,445, 1280,490, 1920,565, 1920,1080, 0,1080 )

# Isometric Grid Overlay
$gridPen = New-Object System.Drawing.Pen((ColorFromHex "#F5E6C8" 38), 1.4)
for ($gx = -200; $gx -lt 2100; $gx += 135) {
    $g.DrawLine($gridPen, $gx, 490, ($gx - 380), 1080)
    $g.DrawLine($gridPen, $gx, 490, ($gx + 480), 1080)
}

# Ancient Olive Trees flanking the ridge
Draw-DetailedOliveTree $g 95 565 1.15
Draw-DetailedOliveTree $g 960 495 0.85
Draw-DetailedOliveTree $g 1795 605 1.08

# 5. Landmark 1: Black Goat-Hair Patriarchal Tent & Stone Altar of Bethel
$tentPen = New-Object System.Drawing.Pen((ColorFromHex "#120E0B"), 2.5)
Draw-Poly $g (New-Grad 120 510 510 675 "#2E2520" "#17120F") $tentPen @(125,635, 255,510, 430,530, 520,642, 350,672, 165,662)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#853B2B")) $null @(165,605, 255,518, 425,536, 475,612, 335,628)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#D9B882")) $null @(248,510, 264,510, 360,670, 344,670)
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#F97316" 195)) $null @(285,666, 348,576, 418,656)

# Stone Altar of Bethel (Gen 13:4)
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F59E0B" 85)), 520, 490, 130, 130)
$stones = @( @(540,582,28,18), @(566,582,30,18), @(594,582,26,18), @(548,565,28,17), @(576,565,28,17), @(560,549,30,16) )
foreach ($st in $stones) {
    $g.FillRectangle((New-Grad $st[0] $st[1] ($st[0]+28) ($st[1]+18) "#B5A895" "#786D5E"), $st[0], $st[1], $st[2], $st[3])
    $g.DrawRectangle($tentPen, $st[0], $st[1], $st[2], $st[3])
}
Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#EF4444" 225)) $null @(560,548, 575,510, 592,548) 0.3
Draw-ClosedCurve $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF08A" 245)) $null @(566,548, 575,524, 585,548) 0.3
Draw-Poly $g (New-Object System.Drawing.SolidBrush(ColorFromHex "#E5E7EB" 48)) $null @(568,515, 545,320, 588,160, 632,160, 595,330, 582,515)

# 6. Landmark 2: Stone-Rimmed Deep Well of Bethel
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#5C5245")), 122, 755, 226, 92)
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#184752")), 138, 765, 194, 72)
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#3694A3")), 152, 773, 166, 54)
$g.DrawEllipse((New-Object System.Drawing.Pen((ColorFromHex "#BAE6FD" 175), 2.2)), 176, 784, 118, 32)

# 7. Landmark 3: Disputed Pasture Zone & Detailed Canaanite Sheep
$conflictPen = New-Object System.Drawing.Pen((ColorFromHex "#EF4444" 215), 3.5)
$conflictPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#DC2626" 45)), 940, 625, 510, 175)
$g.DrawEllipse($conflictPen, 940, 625, 510, 175)

$sheepCoords = @( @(1025,685), @(1075,712), @(1125,678), @(1295,698), @(1350,672), @(1392,712) )
foreach ($sc in $sheepCoords) {
    $sx = $sc[0]; $sy = $sc[1]
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#2B1D12" 120)), $sx-18, $sy+8, 36, 10)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#3D2B1F")), $sx-10, $sy, 4, 12)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#3D2B1F")), $sx+6, $sy, 4, 12)
    $g.FillEllipse((New-Grad ($sx-16) ($sy-12) ($sx+16) ($sy+8) "#FAF5EB" "#C8BCA8"), $sx-16, $sy-10, 32, 19)
    $g.DrawEllipse($tentPen, $sx-16, $sy-10, 32, 19)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#3D2B1F")), $sx+10, $sy-12, 12, 11)
}

# 8. Planned Trajectory Arc & All 7 Detailed Biblical Figures
$arcPen = New-Object System.Drawing.Pen((ColorFromHex "#FDE047" 235), 4.5)
$arcPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawBezier($arcPen, 790, 795, 890, 720, 990, 700, 1110, 715)

Draw-DetailedBiblicalFigure $g 675 595 0.78 "melchizedek" $false
Draw-DetailedBiblicalFigure $g 455 685 0.86 "ur" $false
Draw-DetailedBiblicalFigure $g 295 795 0.94 "hagar" $false
Draw-DetailedBiblicalFigure $g 575 805 0.96 "sarah" $false
Draw-DetailedBiblicalFigure $g 790 795 1.06 "abraham" $true
Draw-DetailedBiblicalFigure $g 1205 725 0.98 "lot" $false
Draw-DetailedBiblicalFigure $g 1545 665 0.90 "eliezer" $false

# Floating Name & Action Badges Placed cleanly BELOW feet so zero heads/props are covered!
$fTag = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)
$charLabels = @(
    @{ x = 675; y = 602; text = "亚希兰 · 铭刻盟约"; hi = $false },
    @{ x = 455; y = 692; text = "乌珥 · 筑坛与帐橛"; hi = $false },
    @{ x = 295; y = 802; text = "夏甲 · 古井汲水+3"; hi = $false },
    @{ x = 575; y = 812; text = "撒拉 · 主帐油灯配给"; hi = $false },
    @{ x = 790; y = 806; text = "★ 亚伯拉罕 · 族长调停"; hi = $true  },
    @{ x = 1205; y = 734; text = "罗得 · 望向约旦平原"; hi = $false },
    @{ x = 1545; y = 674; text = "以利以谢 · 东坡夜警"; hi = $false }
)
foreach ($cl in $charLabels) {
    $lw = 148
    $lp = New-RoundedRectPath ($cl.x - $lw/2) $cl.y $lw 24 7
    $bgC = if ($cl.hi) { ColorFromHex "#2B1D10" 245 } else { ColorFromHex "#16120E" 215 }
    $g.FillPath((New-Object System.Drawing.SolidBrush($bgC)), $lp)
    $penC = if ($cl.hi) { ColorFromHex "#F5C451" } else { ColorFromHex "#8C734B" }
    $g.DrawPath((New-Object System.Drawing.Pen($penC, 1.5)), $lp)
    $g.DrawString($cl.text, $fTag, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE68A")), ($cl.x - $lw/2 + 10), ($cl.y + 3))
}

# 9. HUD Layer
$fHudTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$fHudSub = New-Object System.Drawing.Font("Microsoft YaHei UI", 10.5, [System.Drawing.FontStyle]::Bold)
$fHudBody = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Regular)

$topBar = New-RoundedRectPath 24 18 1872 78 14
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#14110F" 238)), $topBar)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#C89D54"), 2)), $topBar)

$g.DrawString("《泥板与星辰：旧约纪》", $fHudTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#F5D076")), 44, 28)
$g.DrawString("TABLETS & STARS: CHRONICLES OF THE COVENANT", $fTag, (New-Object System.Drawing.SolidBrush(ColorFromHex "#A89676")), 46, 62)

$epochs = @(
    @{ name = "卷一 · 列祖迁徙 (MB IIA)"; sub = "吾珥 → 哈兰 → 伯特利"; active = $true },
    @{ name = "卷二 · 埃及与旷野 (LB)"; sub = "逾越 → 西乃立约"; active = $false },
    @{ name = "卷三 · 士师与支派 (IA I)"; sub = "示剑 → 基甸夜袭"; active = $false },
    @{ name = "卷四 · 王国与先知 (IA II)"; sub = "锡安 → 列王兴衰"; active = $false },
    @{ name = "卷五 · 巴比伦与归回"; sub = "河畔泥板 → 重建圣城"; active = $false }
)
for ($ep = 0; $ep -lt $epochs.Count; $ep++) {
    $ex = 435 + $ep * 192
    $ey = 28
    $eNode = New-RoundedRectPath $ex $ey 180 56 9
    $eBg = if ($epochs[$ep].active) { ColorFromHex "#6E3B26" 240 } else { ColorFromHex "#241E1A" 205 }
    $g.FillPath((New-Object System.Drawing.SolidBrush($eBg)), $eNode)
    $eBorder = if ($epochs[$ep].active) { ColorFromHex "#F5C451" } else { ColorFromHex "#574B3D" }
    $g.DrawPath((New-Object System.Drawing.Pen($eBorder, 1.8)), $eNode)
    $g.DrawString($epochs[$ep].name, $fTag, (New-Object System.Drawing.SolidBrush(ColorFromHex "#F7EBD2")), ($ex + 10), ($ey + 8))
    $g.DrawString($epochs[$ep].sub, $fHudBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#C2B295")), ($ex + 10), ($ey + 30))
}

$g.DrawString("● 泉水 14   ■ 牧草/木 8   ▲ 黑毛帐棚 3   ◆ 牛羊群 120   ✦ 盟约见证 5", $fHudSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE68A")), 1415, 32)
$g.DrawString("⚡ 伯特利水草承载极限：82%（创13:6 那地容不下他们 — 需在入夜前与罗得分群）", $fHudBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FCA5A5")), 1415, 60)

$leftPanel = New-RoundedRectPath 24 845 560 212 16
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#18130F" 240)), $leftPanel)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#B8893E"), 2.2)), $leftPanel)
$g.DrawString("■ 历史节点抉择 · 创世记 13:7-12（公元前 19 世纪 · 迦南中央山地）", $fTag, (New-Object System.Drawing.SolidBrush(ColorFromHex "#D9A752")), 44, 862)
$g.DrawString("「当时，迦南人与比利洗人在那地居住。」", $fHudTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#F7EBD2")), 44, 888)
$rectLore = New-Object System.Drawing.RectangleF(44, 924, 520, 75)
$g.DrawString("亚伯兰与罗得的牧人因山地古井争执，四周迦南城邦正在窥伺。若家族内讧，必遭外族吞并；若主动礼让肥沃的约旦河谷，亚伯兰一族将留在荒凉山地。", $fHudBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#D8C8B0")), $rectLore)

$btnExec = New-RoundedRectPath 44 1002 245 42 10
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#B45309")), $btnExec)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#FDE68A"), 2)), $btnExec)
$g.DrawString("▶ 结束定格 · 推演本旬历史", $fHudSub, [System.Drawing.Brushes]::White, 64, 1012)

$btnChron = New-RoundedRectPath 305 1002 255 42 10
$g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#2B231C")), $btnChron)
$g.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#8C734B"), 1.5)), $btnChron)
$g.DrawString("✦ 展开《家族楔形泥板纪事》", $fHudSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#E7D8B5")), 328, 1012)

$tablets = @(
    @{ type = "【盟约话语泥板 · 创 13:8-9】"; title = "《你向左，我就向右》"; cost = "让出约旦河平原 · 家族和睦 +3"; desc = "亚伯拉罕向罗得让出平原优先选择权，平息牧人内争，将家族迁往希伯仑幔利橡树。" },
    @{ type = "【家宰军略泥板 · 创 14:14】"; title = "《以利以谢：三百一十八家丁夜警》"; cost = "木料 -2 · 防备迦南与四王劫掠"; desc = "由大马士革家宰以利以谢在东侧山脊布设火把警戒网，为下一幕【但地夜袭】储备精锐。" },
    @{ type = "【旷野生存泥板 · 创 16:14】"; title = "《夏甲：掘开庇耳拉海莱暗泉》"; cost = "体力 -15 · 永久泉水产出 +4/旬"; desc = "派埃及侍女夏甲与铜匠乌珥凿深山地石灰岩蓄水池，解决山地驻扎的干渴危机。" },
    @{ type = "【祭坛立约泥板 · 创 13:18】"; title = "《筑坛求告：数算尘沙与星辰》"; cost = "石料 -2 · 铭刻第一块时代记忆泥板"; desc = "在伯特利高地重修石坛，将本卷的同伴命运与盟约誓词永久刻入家族传承档案。" }
)

for ($tb = 0; $tb -lt 4; $tb++) {
    $tItem = $tablets[$tb]
    $tx = 612 + $tb * 322
    $ty = 845
    $tw = 308
    $th = 212
    $tPath = New-RoundedRectPath $tx $ty $tw $th 14
    $tBrush = New-Grad $tx $ty $tx ($ty + $th) "#DEC9A4" "#B59464"
    $g.FillPath($tBrush, $tPath)
    $tPen = if ($tb -eq 0) { New-Object System.Drawing.Pen((ColorFromHex "#F5C451"), 3.5) } else { New-Object System.Drawing.Pen((ColorFromHex "#6E5233"), 2.2) }
    $g.DrawPath($tPen, $tPath)

    $g.DrawString($tItem.type, $fTag, (New-Object System.Drawing.SolidBrush(ColorFromHex "#5E3418")), ($tx + 14), ($ty + 14))
    $g.DrawString($tItem.title, $fHudSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#1F140B")), ($tx + 14), ($ty + 40))

    $costBox = New-RoundedRectPath ($tx + 14) ($ty + 68) ($tw - 28) 26 6
    $g.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#3B2614" 215)), $costBox)
    $g.DrawString($tItem.cost, $fTag, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE68A")), ($tx + 22), ($ty + 72))

    $rectT = New-Object System.Drawing.RectangleF(($tx + 14), ($ty + 104), ($tw - 28), 96)
    $g.DrawString($tItem.desc, $fHudBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#2B1E12")), $rectT)
}

$outConcept = Join-Path $artifactDir "new-ot-game-concept-v1.png"
$bmp.Save($outConcept, [System.Drawing.Imaging.ImageFormat]::Png)
Copy-Item $outConcept (Join-Path $proposalDir "new-ot-game-concept-v1.png") -Force
$g.Dispose()
$bmp.Dispose()

# ==============================================================================
# BOARD 2: BRAND-NEW CHARACTER DESIGN SHEET (1920 x 1160)
# ==============================================================================
$CW = 1920
$CH = 1160
$cbmp = New-Object System.Drawing.Bitmap($CW, $CH)
$cg = [System.Drawing.Graphics]::FromImage($cbmp)
$cg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$cg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$cBg = New-Grad 0 0 0 $CH "#181512" "#2B231B"
$cg.FillRectangle($cBg, 0, 0, $CW, $CH)

$cg.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#100D0B")), 0, 0, $CW, 110)
$cg.DrawLine((New-Object System.Drawing.Pen((ColorFromHex "#C89D54"), 3)), 0, 110, $CW, 110)

$fMainTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", 24, [System.Drawing.FontStyle]::Bold)
$fSub = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Regular)
$fName = New-Object System.Drawing.Font("Microsoft YaHei UI", 14.5, [System.Drawing.FontStyle]::Bold)
$fSec = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)
$fBody = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.2, [System.Drawing.FontStyle]::Regular)
$fHex = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$cardW = 248
$gap = 18
$startX = 36

$cg.DrawString("《泥板与星辰：旧约纪》 · 全新原创人物设计总表（近东壁画浮雕 × 6.5头身史诗剪影风）", $fMainTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#F5D076")), 40, 20)
$cg.DrawString("ORIGINAL CHARACTER BIBLE v2.0  |  告别幼态Q版玩偶，采用公元前 1890 年埃及贝尼哈桑（Beni Hasan）闪米特游牧壁画考据与《旗帜的传说》修长戏剧比例", $fSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#C8B696")), 42, 70)

$newChars = @(
    @{
        type = "abraham"; name = "亚伯拉罕 Abraham"; sub = "渡河者 · 希伯来族长 (创 12-22)"
        c1 = "#1E3A5F"; c2 = "#8C3B2B"; c3 = "#D9A752"
        arch = "参考公元前19世纪贝尼哈桑墓壁画中闪米特族长「Abisha」服饰：红蓝斜纹几何羊毛长袍、流苏披肩、弯头牧杖。"
        sys = "【立约之首】主持筑坛与外邦盟约；在部族分裂危机中可执行「兄长礼让」，将领地让步转化为跨章盟约威望。"
        arc = "历史脉络：从吾珥城邦青年 → 伯特利牧长 → 但地夜袭统帅 → 摩利亚山献祭的苍老慈父（随章节年龄演进）。"
    },
    @{
        type = "sarah"; name = "撒拉 Sarah"; sub = "帐棚之母 · 盟约守望者 (创 12-23)"
        c1 = "#9E3E32"; c2 = "#F0E5CF"; c3 = "#D4AF37"
        arch = "乌尔（Ur）王朝银叶发箍、茜草红织纹长裙与素麻长头纱，双手捧迦南单嘴陶油灯（象征宗族延续之火）。"
        sys = "【主帐之光】掌管车队粮水配给与家族内务；夜间驻扎时点亮主帐油灯，大幅降低全族在旷野中的恐慌与疲惫。"
        arc = "历史脉络：历经饥荒入埃及、多年不育的苦楚与欢笑，最终安葬于希伯仑麦比拉洞（家族第一块永久产业）。"
    },
    @{
        type = "lot"; name = "罗得 Lot"; sub = "约旦牧长 · 城门审断者 (创 13-19)"
        c1 = "#5B3246"; c2 = "#6E4B32"; c3 = "#C8A96E"
        arch = "紫褐贸易披风配游牧皮衣，右肩盘绕粗麻牧绳，左手持青铜天平砝码（隐喻他从游牧走向所多玛城门的转变）。"
        sys = "【平原商路】与亚伯拉罕同行时提供高额牛羊产出，但会持续挤压山地水草容量；分群后可与其建立远途贸易。"
        arc = "历史脉络：在伯特利选择滋润的约旦河平原 → 渐挪帐棚直到所多玛 → 四王之战被掳 → 倾覆之夜的逃亡。"
    },
    @{
        type = "eliezer"; name = "以利以谢 Eliezer"; sub = "大马士革家宰 · 夜袭统领 (创 14-24)"
        c1 = "#3E5641"; c2 = "#7A4E2D"; c3 = "#EF4444"
        arch = "经文真实人物（创15:2）：叙利亚式皮革护胸、背负中青铜时代反曲复合弓、高举松脂火把。"
        sys = "【三百一十八精锐】统领家生精壮仆人；在夜袭战（如创14章但地奇袭）中可开启「分队号角与火把疑兵」战术。"
        arc = "历史脉络：前半生为亚伯拉罕仗剑守夜、奇袭四王；晚年受托远赴哈兰井旁，为以撒迎娶利百加（创24章）。"
    },
    @{
        type = "hagar"; name = "夏甲 Hagar"; sub = "埃及侍女 · 旷野寻泉者 (创 16-21)"
        c1 = "#2E6F73"; c2 = "#D8CDB8"; c3 = "#B85D3B"
        arch = "埃及中王国时期百褶素麻长裙配绿松石色披带，怀抱迦南双耳圆腹储水陶罐（Amphora）。"
        sys = "【庇耳拉海莱之眼】在干旱荒漠地图中拥有勘探隐藏地下水脉的唯一能力，汲水效率翻倍。"
        arc = "历史脉络：从埃及赐予的使女 → 书珥旷野水泉旁听见使者呼唤 → 在别是巴旷野抚养弓箭手以实玛利。"
    },
    @{
        type = "ur"; name = "乌珥 Ur"; sub = "青铜与石坛匠师 (历史语境角色)"
        c1 = "#8C5230"; c2 = "#C8B89A"; c3 = "#D99B52"
        arch = "中青铜时代（MB IIA）工匠装束：粗革胸围、亚麻短裙、肩扛鸭嘴形青铜锛斧（Duckbill Axe）与石工锤。"
        sys = "【掘井与筑坛】负责在各地凿石掘井、支搭黑毛大帐、修筑山脊防御石墙，并打造青铜武器护卫车队。"
        arc = "历史脉络：其家族匠艺世代相传，从列祖时代的粗糙石坛，延续至出埃及记中会幕铜祭坛的铸造者。"
    },
    @{
        type = "melchizedek"; name = "亚希兰 Ahiram"; sub = "泥板书记官 · 族中长老 (历史语境角色)"
        c1 = "#4A3B5C"; c2 = "#D4AF37"; c3 = "#C27D54"
        arch = "深紫长袍配金线祭司肩带，银白长髯，手持湿润的阿卡德/早期闪米特泥板与芦苇刻刀。"
        sys = "【泥板立约】将口传神谕与部族盟约刻入泥板；在牧人争执或外邦谈判时提供「古道劝诫」，平息哗变。"
        arc = "历史脉络：见证亚伯拉罕与撒冷王麦基洗德献饼和酒（创14:18）、亚比米勒别是巴七母羊盟约（创21:28）。"
    }
)

for ($i = 0; $i -lt $newChars.Count; $i++) {
    $nc = $newChars[$i]
    $cx = $startX + $i * ($cardW + $gap)
    $cy = 136

    $cCard = New-RoundedRectPath $cx $cy $cardW 985 16
    $cg.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#231D18")), $cCard)
    $bCol = if ($i -lt 5) { ColorFromHex "#C89D54" } else { ColorFromHex "#786854" }
    $cg.DrawPath((New-Object System.Drawing.Pen($bCol, 2.2)), $cCard)

    $archPath = New-RoundedRectPath ($cx + 14) ($cy + 16) ($cardW - 28) 330 22
    $archBrush = New-Grad $cx ($cy + 16) $cx ($cy + 346) "#162438" "#3D2B1F"
    $cg.FillPath($archBrush, $archPath)
    $cg.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#8C6F3E"), 1.5)), $archPath)

    $cg.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#F5C451" 38)), ($cx + 68), ($cy + 44), 112, 112)

    Draw-DetailedBiblicalFigure $cg ($cx + $cardW / 2.0) ($cy + 324) 1.32 $nc.type ($i -eq 0)

    $cg.DrawString($nc.name, $fName, (New-Object System.Drawing.SolidBrush(ColorFromHex "#F7EBD2")), ($cx + 14), ($cy + 360))
    $cg.DrawString($nc.sub, $fTag, (New-Object System.Drawing.SolidBrush(ColorFromHex "#D9A752")), ($cx + 14), ($cy + 392))

    $sws = @($nc.c1, $nc.c2, $nc.c3)
    for ($s = 0; $s -lt 3; $s++) {
        $sx = $cx + 14 + $s * 73
        $sy = $cy + 422
        $cg.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex $sws[$s])), $sx, $sy, 18, 18)
        $cg.DrawRectangle((New-Object System.Drawing.Pen(ColorFromHex "#A89676")), $sx, $sy, 18, 18)
        $cg.DrawString($sws[$s], $fHex, (New-Object System.Drawing.SolidBrush(ColorFromHex "#C8B696")), ($sx + 20), ($sy + 2))
    }

    $cg.DrawLine((New-Object System.Drawing.Pen(ColorFromHex "#4A3D31")), ($cx + 14), ($cy + 454), ($cx + $cardW - 14), ($cy + 454))

    $cg.DrawString("■ 历史壁画与文物考据", $fSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#E5B85B")), ($cx + 14), ($cy + 468))
    $r1 = New-Object System.Drawing.RectangleF(($cx + 14), ($cy + 492), ($cardW - 28), 145)
    $cg.DrawString($nc.arch, $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#DFD3C3")), $r1)

    $cg.DrawString("■ 游戏系统定位与特长", $fSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#6EE7B7")), ($cx + 14), ($cy + 645))
    $r2 = New-Object System.Drawing.RectangleF(($cx + 14), ($cy + 669), ($cardW - 28), 145)
    $cg.DrawString($nc.sys, $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#D1FAE5")), $r2)

    $arcBox = New-RoundedRectPath ($cx + 12) ($cy + 818) ($cardW - 24) 152 10
    $cg.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#16120E")), $arcBox)
    $cg.DrawPath((New-Object System.Drawing.Pen(ColorFromHex "#6E5233")), $arcBox)
    $cg.DrawString("✦ 旧约历史脉络弧线", $fSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FCD34D")), ($cx + 20), ($cy + 828))
    $r3 = New-Object System.Drawing.RectangleF(($cx + 20), ($cy + 852), ($cardW - 40), 110)
    $cg.DrawString($nc.arc, $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#E7D8B5")), $r3)
}

$outChars = Join-Path $artifactDir "new-ot-character-designs-v1.png"
$cbmp.Save($outChars, [System.Drawing.Imaging.ImageFormat]::Png)
Copy-Item $outChars (Join-Path $proposalDir "new-ot-character-designs-v1.png") -Force
$cg.Dispose()
$cbmp.Dispose()
Write-Host "Successfully rendered high-detail OT Concept and Character Sheets."
