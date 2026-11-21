import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\textures"
os.makedirs(OUT, exist_ok=True)


def height_to_normal(height_img: Image.Image, strength: float = 2.6) -> Image.Image:
    w, h = height_img.size
    px = height_img.load()
    out = Image.new("RGB", (w, h))
    opx = out.load()
    for y in range(h):
        ym = (y - 1) % h
        yp = (y + 1) % h
        for x in range(w):
            xm = (x - 1) % w
            xp = (x + 1) % w
            tl = px[xm, ym] / 255.0
            t = px[x, ym] / 255.0
            tr = px[xp, ym] / 255.0
            l = px[xm, y] / 255.0
            r = px[xp, y] / 255.0
            bl = px[xm, yp] / 255.0
            b = px[x, yp] / 255.0
            br = px[xp, yp] / 255.0
            dx = (tr + 2.0 * r + br - (tl + 2.0 * l + bl)) * strength
            dy = (bl + 2.0 * b + br - (tl + 2.0 * t + tr)) * strength
            dz = 1.0
            inv = 1.0 / math.sqrt(dx * dx + dy * dy + dz * dz)
            nx = int((-dx * inv * 0.5 + 0.5) * 255)
            ny = int((-dy * inv * 0.5 + 0.5) * 255)
            nz = int((dz * inv * 0.5 + 0.5) * 255)
            opx[x, y] = (nx, ny, nz)
    return out


def make_grass():
    rng = random.Random(101)
    size = 512
    alb = Image.new("RGB", (size, size), (104, 114, 52))
    hgt = Image.new("L", (size, size), 120)
    ad = ImageDraw.Draw(alb)
    hd = ImageDraw.Draw(hgt)
    # Soft earthy grass patches
    for _ in range(380):
        x, y = rng.randrange(size), rng.randrange(size)
        r = rng.randint(10, 34)
        c = (rng.randint(82, 128), rng.randint(92, 134), rng.randint(38, 62))
        ad.ellipse((x - r, y - r, x + r, y + r), fill=c)
        hd.ellipse((x - r, y - r, x + r, y + r), fill=rng.randint(105, 165))
    # Grass blades & tiny wildflowers
    for _ in range(1800):
        x, y = rng.randrange(size), rng.randrange(size)
        l = rng.randint(4, 11)
        c = (rng.randint(120, 155), rng.randint(128, 156), rng.randint(52, 74))
        ad.line((x, y, x + rng.randint(-3, 3), y - l), fill=c, width=1)
        hd.line((x, y, x + rng.randint(-2, 2), y - l), fill=rng.randint(170, 235), width=1)
    for _ in range(95):
        x, y = rng.randrange(size), rng.randrange(size)
        ad.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(224, 198, 76))
    alb = alb.filter(ImageFilter.GaussianBlur(0.5))
    hgt = hgt.filter(ImageFilter.GaussianBlur(1.2))
    alb.save(os.path.join(OUT, "terrain_grass_albedo.png"))
    height_to_normal(hgt, 2.2).save(os.path.join(OUT, "terrain_grass_normal.png"))


def make_dirt():
    rng = random.Random(202)
    size = 512
    alb = Image.new("RGB", (size, size), (168, 129, 83))
    hgt = Image.new("L", (size, size), 128)
    ad = ImageDraw.Draw(alb)
    hd = ImageDraw.Draw(hgt)
    for _ in range(420):
        x, y = rng.randrange(size), rng.randrange(size)
        r = rng.randint(8, 30)
        v = rng.randint(-18, 18)
        ad.ellipse((x - r, y - r, x + r, y + r), fill=(168 + v, 129 + v, 83 + int(v * 0.7)))
        hd.ellipse((x - r, y - r, x + r, y + r), fill=128 + v * 2)
    # Small limestone pebbles in dirt
    for _ in range(900):
        x, y = rng.randrange(size), rng.randrange(size)
        r = rng.randint(2, 5)
        shade = rng.randint(155, 210)
        ad.ellipse((x - r, y - r, x + r, y + r), fill=(shade, shade - 16, shade - 36))
        hd.ellipse((x - r, y - r, x + r, y + r), fill=rng.randint(185, 240))
    hgt = hgt.filter(ImageFilter.GaussianBlur(1.0))
    alb.save(os.path.join(OUT, "terrain_dirt_albedo.png"))
    height_to_normal(hgt, 2.5).save(os.path.join(OUT, "terrain_dirt_normal.png"))


def make_rock():
    rng = random.Random(303)
    size = 512
    alb = Image.new("RGB", (size, size), (176, 158, 128))
    hgt = Image.new("L", (size, size), 130)
    ad = ImageDraw.Draw(alb)
    hd = ImageDraw.Draw(hgt)
    # Layered Canaanite limestone strata
    for row in range(0, size, 32):
        for col in range(0, size, 64):
            ox = (row // 32 % 2) * 28
            x0 = (col + ox) % size
            w = rng.randint(46, 62)
            h = rng.randint(22, 30)
            s = rng.randint(158, 206)
            ad.rounded_rectangle((x0, row + 2, x0 + w, row + h), radius=5, fill=(s, s - 14, s - 32), outline=(102, 88, 68), width=2)
            hd.rounded_rectangle((x0, row + 2, x0 + w, row + h), radius=5, fill=rng.randint(165, 225), outline=45, width=3)
    hgt = hgt.filter(ImageFilter.GaussianBlur(1.4))
    alb.save(os.path.join(OUT, "terrain_rock_albedo.png"))
    height_to_normal(hgt, 3.2).save(os.path.join(OUT, "terrain_rock_normal.png"))


def make_goathair_tent():
    rng = random.Random(404)
    size = 512
    alb = Image.new("RGB", (size, size), (58, 42, 30))
    hgt = Image.new("L", (size, size), 120)
    ad = ImageDraw.Draw(alb)
    hd = ImageDraw.Draw(hgt)
    # Woven horizontal goat-hair strips + pale beige woven seams (matching camp-scene-mobile.png!)
    for y in range(0, size, 6):
        is_seam = (y % 128) < 12
        if is_seam:
            c = (182, 154, 114)
            hv = 185
        else:
            v = rng.randint(-12, 12)
            c = (56 + v, 40 + v, 28 + int(v * 0.8))
            hv = 120 + v * 2
        ad.rectangle((0, y, size, y + 5), fill=c)
        hd.rectangle((0, y, size, y + 5), fill=hv)
    for x in range(0, size, 8):
        ad.line((x, 0, x, size), fill=(72, 54, 38), width=1)
        hd.line((x, 0, x, size), fill=145, width=1)
    hgt = hgt.filter(ImageFilter.GaussianBlur(0.8))
    alb.save(os.path.join(OUT, "tent_goathair_albedo.png"))
    height_to_normal(hgt, 2.0).save(os.path.join(OUT, "tent_goathair_normal.png"))


def make_tekhelet_tapestry():
    size = 256
    alb = Image.new("RGB", (size, size), (42, 74, 126)) # Tekhelet blue
    ad = ImageDraw.Draw(alb)
    # Pomegranate-red border & geometric diamond motif (matching camp-scene-mobile.png!)
    ad.rectangle((10, 10, size - 10, size - 36), outline=(186, 86, 68), width=8)
    ad.rectangle((24, 24, size - 24, size - 50), outline=(222, 186, 118), width=4)
    for cy in (74, 146):
        pts = [(size // 2, cy - 30), (size // 2 + 42, cy), (size // 2, cy + 30), (size // 2 - 42, cy)]
        ad.polygon(pts, fill=(186, 86, 68), outline=(228, 194, 122))
        pts2 = [(size // 2, cy - 14), (size // 2 + 18, cy), (size // 2, cy + 14), (size // 2 - 18, cy)]
        ad.polygon(pts2, fill=(42, 74, 126))
    # Bottom golden tassels
    ad.rectangle((0, size - 32, size, size), fill=(198, 162, 92))
    for x in range(6, size, 12):
        ad.line((x, size - 32, x, size), fill=(112, 82, 42), width=3)
    alb.save(os.path.join(OUT, "tapestry_tekhelet_albedo.png"))


make_grass()
make_dirt()
make_rock()
make_goathair_tent()
make_tekhelet_tapestry()
print("PBR_TEXTURES_OK:", sorted(os.listdir(OUT)))
