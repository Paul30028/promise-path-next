Add-Type -AssemblyName System.Drawing

$artifactDir = "C:\Users\holyx\.gemini\antigravity\brain\6e568a4c-bd1a-4b4b-8be5-415b1cddfb8e"
$clayDir = "c:\AI\gemini\promise-path-next\public\clay"
$proposalDir = "c:\AI\gemini\promise-path-next\design\producer-proposal-v1"
New-Item -ItemType Directory -Force -Path $proposalDir | Out-Null

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

function ColorFromHex([string]$hex, [int]$alpha = 255) {
    $h = $hex.TrimStart('#')
    $r = [Convert]::ToInt32($h.Substring(0,2), 16)
    $g = [Convert]::ToInt32($h.Substring(2,2), 16)
    $b = [Convert]::ToInt32($h.Substring(4,2), 16)
    return [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b)
}

# ==============================================================================
# BOARD 1: CHARACTER DESIGN & ARCHAEOLOGICAL SPECIFICATION SHEET (1920 x 1160)
# ==============================================================================
$W1 = 1920
$H1 = 1160
$bmp1 = New-Object System.Drawing.Bitmap($W1, $H1)
$g1 = [System.Drawing.Graphics]::FromImage($bmp1)
$g1.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g1.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g1.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

$bgBrush1 = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0, 0)),
    (New-Object System.Drawing.Point(0, $H1)),
    (ColorFromHex "#F4EBDC"),
    (ColorFromHex "#E2D2B5")
)
$g1.FillRectangle($bgBrush1, 0, 0, $W1, $H1)

$headerBrush = New-Object System.Drawing.SolidBrush(ColorFromHex "#231C15")
$g1.FillRectangle($headerBrush, 0, 0, $W1, 112)
$goldPen = New-Object System.Drawing.Pen((ColorFromHex "#C89D54"), 3)
$g1.DrawLine($goldPen, 0, 112, $W1, 112)

$fTitle = New-Object System.Drawing.Font("Microsoft YaHei UI", 25, [System.Drawing.FontStyle]::Bold)
$fSub = New-Object System.Drawing.Font("Microsoft YaHei UI", 12, [System.Drawing.FontStyle]::Regular)
$fBadge = New-Object System.Drawing.Font("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold)
$fHex = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)

$g1.DrawString("《尘沙与星辰：应许之路》 · 七名核心角色设定与中青铜时代（MB IIA）考据总表", $fTitle, (New-Object System.Drawing.SolidBrush(ColorFromHex "#F7EBD2")), 42, 22)
$g1.DrawString("CHARACTER DESIGN & ARCHAEOLOGICAL BIBLE v1.0  |  比例规格：2.7 头身手工黏土微缩  |  视角适配：35°-40° 俯视高辨识轮廓  |  经文核心(3) + 历史随行同伴(4)", $fSub, (New-Object System.Drawing.SolidBrush(ColorFromHex "#C8B696")), 44, 72)

$chars = @(
    @{
        id = "abram"; name = "亚伯兰 Abram"; tag = "经文核心 · 创 13:1-18"; role = "族长 / 立约领路人"
        c1 = "#304D70"; c2 = "#DFCFAC"; c3 = "#74553A"
        costume = "靛蓝灰粗羊毛外披、素麻长衣、条纹流苏肩带、黎凡特弯头牧羊杖"
        trait = "【族长之言】调停牧人争执降低草场摩擦；率队警戒野兽零羊群损失"
        card = "专属手牌：《兄长的礼让》— 主动让出上泉或牧道，大幅提升两家和睦"
    },
    @{
        id = "sarai"; name = "撒莱 Sarai"; tag = "经文核心 · 创 13:1"; role = "主母 / 营地家宰"
        c1 = "#B76962"; c2 = "#EEE0BF"; c3 = "#8C584C"
        costume = "赭红茜草染披巾、多层素麻内裙、双手交叠姿态、耳坠与编织发带"
        trait = "【主母统筹】搭帐棚或营地休整时统筹配给，额外恢复全队 +10 体力"
        card = "专属手牌：《主帐配给》— 平衡饮水与木料消耗，稳定全队疲劳阈值"
    },
    @{
        id = "lot"; name = "罗得 Lot"; tag = "经文核心 · 创 13:5-12"; role = "侄儿 / 分群牧长"
        c1 = "#856340"; c2 = "#C5A879"; c3 = "#A45E56"
        costume = "土棕皮革背心、红褐束发带、右肩盘绕粗麻牧绳、左手持木制水杯"
        trait = "【双群并牧】管理庞大羊群，但随时间自动推高伯特利草场的空间拥挤度"
        card = "叙事节点：《举目望约旦》— 经文定数：最终选择滋润的约旦河平原东迁"
    },
    @{
        id = "eli"; name = "以利 Eli"; tag = "原创随行 · 历史语境角色"; role = "迦南山地斥候"
        c1 = "#7B8B5C"; c2 = "#BDA67B"; c3 = "#76543C"
        costume = "橄榄绿短袖束腰外衣、皮质行军背囊与卷毯、抬手遮阳远眺姿态"
        trait = "【高地视野】勘察山脊提前发现夜兽与牧道风险，警戒驱离时保全羊群"
        card = "专属手牌：《山脊火把界》— 消耗 1 捆荆棘木料，在夜袭或野兽前立起防线"
    },
    @{
        id = "asa"; name = "亚撒 Asa"; tag = "原创随行 · 历史语境角色"; role = "帐棚与木作工匠"
        c1 = "#A66B42"; c2 = "#74553A"; c3 = "#DFCFAC"
        costume = "铜棕粗革工匠围裙、腰间工具皮袋、右肩扛硬木大槌、左握木杯"
        trait = "【巧匠营造】林缘收木每次 +3（常人+2）；搭建黑山羊毛帐棚稳固营地"
        card = "专属手牌：《加固帐橛》— 缩短帐棚施工耗时，提升夜间歇息体力恢复率"
    },
    @{
        id = "nura"; name = "努拉 Nura"; tag = "原创随行 · 历史语境角色"; role = "泉眼汲水者"
        c1 = "#568484"; c2 = "#AE7152"; c3 = "#76543C"
        costume = "靛青绿粗麻长裙、斜挎皮质随身袋、双手怀抱中青铜时代双耳圆腹陶罐"
        trait = "【深泉汲引】每次泉眼取水 +3（常人+2），且长途背水移动体力消耗减半"
        card = "专属手牌：《双耳陶罐储水》— 为迁徙或转移羊群提供额外应急饮水缓冲"
    },
    @{
        id = "mara"; name = "玛拉 Mara"; tag = "原创随行 · 历史语境角色"; role = "随行族中长者"
        c1 = "#775F86"; c2 = "#DAD1B8"; c3 = "#74553A"
        costume = "深紫灰厚重织花披肩、银白须发、双掌握持矮木杖、温和谦卑站姿"
        trait = "【古道劝解】在主帐歇息或参与罗得议事时安抚人心，额外提升和睦 +1"
        card = "专属手牌：《帐前夜话》— 降低两家牧人争执张力，保存家族记忆泥板"
    }
)

$cardW = 248
$cardH = 965
$gap = 18
$startX = 36
$startY = 142

$fName = New-Object System.Drawing.Font("Microsoft YaHei UI", 15, [System.Drawing.FontStyle]::Bold)
$fRole = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$fSec = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Bold)
$fBody = New-Object System.Drawing.Font("Microsoft YaHei UI", 9.5, [System.Drawing.FontStyle]::Regular)

for ($i = 0; $i -lt $chars.Count; $i++) {
    $c = $chars[$i]
    $cx = $startX + $i * ($cardW + $gap)
    $cy = $startY

    $cardPath = New-RoundedRectPath $cx $cy $cardW $cardH 16
    $g1.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#FBF6EC")), $cardPath)
    $borderCol = if ($i -lt 3) { ColorFromHex "#B8893E" } else { ColorFromHex "#9E927B" }
    $g1.DrawPath((New-Object System.Drawing.Pen($borderCol, 2.5)), $cardPath)

    $tagBg = if ($i -lt 3) { ColorFromHex "#8C5A2B" } else { ColorFromHex "#4A5D4E" }
    $tagPath = New-RoundedRectPath ($cx + 12) ($cy + 12) ($cardW - 24) 26 8
    $g1.FillPath((New-Object System.Drawing.SolidBrush($tagBg)), $tagPath)
    $g1.DrawString($c.tag, $fBadge, [System.Drawing.Brushes]::White, ($cx + 22), ($cy + 16))

    $pedPath = New-RoundedRectPath ($cx + 14) ($cy + 48) ($cardW - 28) 320 12
    $g1.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#EFE4CE")), $pedPath)
    $g1.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#C9B693" 160)), ($cx + 48), ($cy + 332), ($cardW - 96), 24)

    $imgFile = Join-Path $clayDir ("character_" + $c.id + ".png")
    if (Test-Path $imgFile) {
        $cImg = [System.Drawing.Image]::FromFile($imgFile)
        $targetH = 285.0
        $targetW = $targetH * ($cImg.Width / [double]$cImg.Height)
        if ($targetW -gt ($cardW - 36)) {
            $targetW = $cardW - 36
            $targetH = $targetW * ($cImg.Height / [double]$cImg.Width)
        }
        $ix = $cx + ($cardW - $targetW) / 2.0
        $iy = $cy + 350 - $targetH
        $g1.DrawImage($cImg, [float]$ix, [float]$iy, [float]$targetW, [float]$targetH)
        $cImg.Dispose()
    }

    $g1.DrawString($c.name, $fName, (New-Object System.Drawing.SolidBrush(ColorFromHex "#231B12")), ($cx + 14), ($cy + 380))
    $g1.DrawString($c.role, $fRole, (New-Object System.Drawing.SolidBrush(ColorFromHex "#6E5233")), ($cx + 14), ($cy + 412))

    $swatches = @($c.c1, $c.c2, $c.c3)
    for ($s = 0; $s -lt 3; $s++) {
        $sx = $cx + 14 + $s * 73
        $sy = $cy + 444
        $swBrush = New-Object System.Drawing.SolidBrush(ColorFromHex $swatches[$s])
        $g1.FillRectangle($swBrush, $sx, $sy, 18, 18)
        $g1.DrawRectangle((New-Object System.Drawing.Pen(ColorFromHex "#5C4D3C")), $sx, $sy, 18, 18)
        $g1.DrawString($swatches[$s], $fHex, (New-Object System.Drawing.SolidBrush(ColorFromHex "#4D4132")), ($sx + 20), ($sy + 2))
    }

    $g1.DrawLine((New-Object System.Drawing.Pen(ColorFromHex "#D8CBB3")), ($cx + 14), ($cy + 478), ($cx + $cardW - 14), ($cy + 478))

    $g1.DrawString("■ 服饰与器物考据（MB IIA）", $fSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#5E4325")), ($cx + 14), ($cy + 492))
    $rectCostume = New-Object System.Drawing.RectangleF(($cx + 14), ($cy + 516), ($cardW - 28), 115)
    $g1.DrawString($c.costume, $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#3A3024")), $rectCostume)

    $g1.DrawString("■ 角色职责与系统特长", $fSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#2F5941")), ($cx + 14), ($cy + 640))
    $rectTrait = New-Object System.Drawing.RectangleF(($cx + 14), ($cy + 664), ($cardW - 28), 125)
    $g1.DrawString($c.trait, $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#2B3A2E")), $rectTrait)

    $cardBox = New-RoundedRectPath ($cx + 12) ($cy + 795) ($cardW - 24) 152 10
    $g1.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#F3E5C8")), $cardBox)
    $g1.DrawPath((New-Object System.Drawing.Pen(ColorFromHex "#C5A875")), $cardBox)
    $g1.DrawString("✦ 绑定情境手牌 / 叙事节点", $fSec, (New-Object System.Drawing.SolidBrush(ColorFromHex "#7A5221")), ($cx + 20), ($cy + 806))
    $rectCard = New-Object System.Drawing.RectangleF(($cx + 20), ($cy + 832), ($cardW - 40), 108)
    $g1.DrawString($c.card, $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#3B2A16")), $rectCard)
}

$outSheet1 = Join-Path $artifactDir "dust-and-stars-character-sheet-v1.png"
$bmp1.Save($outSheet1, [System.Drawing.Imaging.ImageFormat]::Png)
Copy-Item $outSheet1 (Join-Path $proposalDir "dust-and-stars-character-sheet-v1.png") -Force
$g1.Dispose()
$bmp1.Dispose()

# ==============================================================================
# BOARD 2: ORIGINAL RUNTIME CONCEPT & TACTILE HUD TARGET (1920 x 1080)
# ==============================================================================
$W2 = 1920
$H2 = 1080
$bmp2 = New-Object System.Drawing.Bitmap($W2, $H2)
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

# 1. Draw Clean Camp Scene Background Plate (Full-Bleed 1920x1080 using actual image dimensions)
$bgFile = Join-Path $clayDir "camp-scene-clean-bg.jpg"
$bgImg = [System.Drawing.Image]::FromFile($bgFile)
$cropW = $bgImg.Width
$cropH = [int]([Math]::Min($bgImg.Height, [Math]::Round($cropW * 9.0 / 16.0)))
$cropY = [int]([Math]::Max(0, [Math]::Round(($bgImg.Height - $cropH) * 0.25)))
$srcRect = New-Object System.Drawing.Rectangle(0, $cropY, $cropW, $cropH)
$dstRect = New-Object System.Drawing.Rectangle(0, 0, $W2, $H2)
$g2.DrawImage($bgImg, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$bgImg.Dispose()

# 2. Draw Spatial Crowding Tension Zone on the Central Pasture (Gen 13:6-7)
$zonePen = New-Object System.Drawing.Pen((ColorFromHex "#EF4444" 215), 4)
$zonePen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g2.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#DC2626" 48)), 1085, 520, 440, 185)
$g2.DrawEllipse($zonePen, 1085, 520, 440, 185)

$zoneTagPath = New-RoundedRectPath 1085 678 335 30 8
$g2.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#3B1212" 235)), $zoneTagPath)
$g2.DrawPath((New-Object System.Drawing.Pen(ColorFromHex "#F87171")), $zoneTagPath)
$g2.DrawString("▲ 牧场空间挤压区：两家牧人争草 (摩擦 72%)", $fBadge, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FECACA")), 1099, 684)

# 3. Draw Tactile Rope/Chalk Planned Trajectories on the Ground
$ropePen = New-Object System.Drawing.Pen((ColorFromHex "#FDE047" 235), 5)
$ropePen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g2.DrawBezier($ropePen, 1018, 865, 1080, 740, 1170, 680, 1265, 645)

$ropePen2 = New-Object System.Drawing.Pen((ColorFromHex "#7DD3FC" 225), 4)
$ropePen2.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dot
$g2.DrawBezier($ropePen2, 410, 680, 340, 640, 260, 635, 210, 645)

$g2.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE047" 200)), 1251, 633, 28, 16)

# 4. Draw All 7 Clay Characters in Formation
$sceneActors = @(
    @{ id = "asa";   name = "亚撒 · 搭棚备料"; x = 0.588; y = 0.492; sc = 0.255; sel = $false },
    @{ id = "eli";   name = "以利 · 山脊警戒"; x = 0.418; y = 0.580; sc = 0.245; sel = $false },
    @{ id = "nura";  name = "努拉 · 汲水+3";   x = 0.214; y = 0.642; sc = 0.265; sel = $false },
    @{ id = "lot";   name = "罗得 · 分群牧长"; x = 0.704; y = 0.715; sc = 0.275; sel = $false },
    @{ id = "abram"; name = "亚伯兰 · 族长调停"; x = 0.530; y = 0.818; sc = 0.305; sel = $true  },
    @{ id = "sarai"; name = "撒莱 · 主母统筹"; x = 0.312; y = 0.848; sc = 0.285; sel = $false },
    @{ id = "mara";  name = "玛拉 · 长者劝解"; x = 0.818; y = 0.905; sc = 0.285; sel = $false }
)

foreach ($sa in $sceneActors) {
    $pFile = Join-Path $clayDir ("character_" + $sa.id + ".png")
    if (Test-Path $pFile) {
        $pImg = [System.Drawing.Image]::FromFile($pFile)
        $ch = $H2 * $sa.sc
        $cw = $ch * ($pImg.Width / [double]$pImg.Height)
        $fx = $W2 * $sa.x
        $fy = $H2 * $sa.y

        $g2.FillEllipse((New-Object System.Drawing.SolidBrush(ColorFromHex "#3D2612" 125)), [float]($fx - $cw * 0.36), [float]($fy - 18), [float]($cw * 0.82), 34.0)

        if ($sa.sel) {
            $ringPen = New-Object System.Drawing.Pen((ColorFromHex "#FDE047"), 6)
            $g2.DrawEllipse($ringPen, [float]($fx - $cw * 0.48), [float]($fy - 22), [float]($cw * 0.96), 44.0)
        }

        $g2.DrawImage($pImg, [float]($fx - $cw / 2.0), [float]($fy - $ch), [float]$cw, [float]$ch)

        $pillW = 148
        $pillPath = New-RoundedRectPath ($fx - $pillW / 2) ($fy - $ch - 32) $pillW 26 8
        $pillBg = if ($sa.sel) { ColorFromHex "#2B1E10" 235 } else { ColorFromHex "#1F1812" 195 }
        $g2.FillPath((New-Object System.Drawing.SolidBrush($pillBg)), $pillPath)
        if ($sa.sel) {
            $g2.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#FACC15"), 2)), $pillPath)
        }
        $g2.DrawString($sa.name, $fBadge, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF3C7")), ($fx - $pillW / 2 + 12), ($fy - $ch - 27))
        $pImg.Dispose()
    }
}

# 5. TOP-LEFT HUD: Clay Tablet Chapter & Sundial Bar
$tlPath = New-RoundedRectPath 28 24 545 82 14
$g2.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#231B13" 232)), $tlPath)
$g2.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#B89358"), 2)), $tlPath)
$g2.DrawString("《尘沙与星辰》 · 第一章：伯特利与艾城之间（创 13:1-18）", $fRole, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FDE68A")), 46, 36)
$g2.DrawString("☀ 黄昏将至（剩余 2 轮入夜）  |  当前目标：平息两家牧人草场争执，预备分群", $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#E7D8B5")), 46, 68)

# 6. TOP-RIGHT HUD: Pasture Capacity / Friction Gauge & Physical Supplies
$trPath = New-RoundedRectPath 1120 24 772 82 14
$g2.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#231B13" 232)), $trPath)
$g2.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#B89358"), 2)), $trPath)
$g2.DrawString("⚡ 伯特利牧场拥挤摩擦：72% (争执临界 — 创13:6「那地容不下他们」)", $fBadge, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FCA5A5")), 1142, 34)
$g2.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#44403C")), 1142, 62, 310, 14)
$g2.FillRectangle((New-Object System.Drawing.SolidBrush(ColorFromHex "#EA580C")), 1142, 62, 224, 14)
$g2.DrawString("● 饮水 4    ■ 木料 2    ▲ 帐棚 1    ◆ 羊群 6    ✦ 和睦 3", $fRole, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF3C7")), 1475, 54)

# 7. BOTTOM-LEFT HUD: Stop-Motion Showdown Pause / Execute Hourglass
$blPath = New-RoundedRectPath 28 962 295 90 16
$g2.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#B45309" 242)), $blPath)
$g2.DrawPath((New-Object System.Drawing.Pen((ColorFromHex "#FDE68A"), 2.5)), $blPath)
$g2.DrawString("▶ 定格沙盘 · 点击推演", $fName, [System.Drawing.Brushes]::White, 50, 978)
$g2.DrawString("已排入 3 条同伴路线 · 随时可暂停重排", $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#FEF3C7")), 50, 1016)

# 8. BOTTOM-RIGHT HUD: Tactile Parchment Word & Artifact Hand Cards
$handCards = @(
    @{ tag = "话语牌 · 亚伯兰专属 (创13:8)"; title = "《兄长的礼让：先共饮上泉》"; cost = "● 饮水 -2   ✦ 和睦 +2   消除红圈摩擦"; desc = "「你我不可相争，因为我们是骨肉。」主动让出泉眼缓解争执。" },
    @{ tag = "器物牌 · 以利 / 亚伯兰"; title = "《山脊荆棘火把夜界》"; cost = "■ 木料 -1   ◆ 羊群保全   ✦ 和睦 +1"; desc = "在东侧山脊点燃荆棘火光，驱离窥伺羊群的野兽。" },
    @{ tag = "职责牌 · 撒莱与亚撒"; title = "《加固分道行装与帐橛》"; cost = "■ 木料 -2   ✦ 和睦 +3   解锁罗得东迁"; desc = "清点两家账目与水袋，邀请罗得登高举目先选约旦河平原。" }
)

for ($hc = 0; $hc -lt 3; $hc++) {
    $hCard = $handCards[$hc]
    $hx = 945 + $hc * 315
    $hy = 895
    $hw = 300
    $hh = 160
    $cPath = New-RoundedRectPath $hx $hy $hw $hh 14
    $g2.FillPath((New-Object System.Drawing.SolidBrush(ColorFromHex "#F6EBD4" 248)), $cPath)
    $penCol = if ($hc -eq 0) { ColorFromHex "#EAB308" } else { ColorFromHex "#8C734B" }
    $g2.DrawPath((New-Object System.Drawing.Pen($penCol, 3)), $cPath)

    $g2.DrawString($hCard.tag, $fBadge, (New-Object System.Drawing.SolidBrush(ColorFromHex "#7C5826")), ($hx + 16), ($hy + 14))
    $g2.DrawString($hCard.title, $fRole, (New-Object System.Drawing.SolidBrush(ColorFromHex "#23190F")), ($hx + 16), ($hy + 38))
    $g2.DrawString($hCard.cost, $fBadge, (New-Object System.Drawing.SolidBrush(ColorFromHex "#9A3412")), ($hx + 16), ($hy + 68))
    $rectDesc = New-Object System.Drawing.RectangleF(($hx + 16), ($hy + 94), ($hw - 32), 56)
    $g2.DrawString($hCard.desc, $fBody, (New-Object System.Drawing.SolidBrush(ColorFromHex "#443524")), $rectDesc)
}

$outSheet2 = Join-Path $artifactDir "dust-and-stars-runtime-concept-v1.png"
$bmp2.Save($outSheet2, [System.Drawing.Imaging.ImageFormat]::Png)
Copy-Item $outSheet2 (Join-Path $proposalDir "dust-and-stars-runtime-concept-v1.png") -Force
$g2.Dispose()
$bmp2.Dispose()
Write-Host "Successfully regenerated both design boards."
