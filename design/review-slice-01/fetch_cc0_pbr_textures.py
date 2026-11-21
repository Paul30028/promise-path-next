import os
import json
import urllib.request
from PIL import Image, ImageEnhance

OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\textures"
os.makedirs(OUT_DIR, exist_ok=True)


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "PromisePathGameStudio/1.0"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.loads(r.read().decode("utf-8"))


def download_file(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": "PromisePathGameStudio/1.0"})
    with urllib.request.urlopen(req, timeout=45) as r:
        with open(dest, "wb") as f:
            f.write(r.read())


print("Querying Poly Haven CC0 textures catalog...", flush=True)
catalog = fetch_json("https://api.polyhaven.com/assets?t=textures")

# Preferred curated CC0 photographic PBR textures (with automatic keyword fallback)
TARGETS = [
    ("rock_boulder", ["limestone", "rock_wall", "sandstone", "cliff_side", "rock"], (1.0, 0.96, 0.88)),
    ("terrain_dirt", ["dry_ground", "gravel_ground", "dirt", "soil", "mud_cracked"], (1.08, 0.96, 0.80)),
    ("terrain_grass", ["dry_grass", "meadow", "grass_path", "forest_ground", "grass"], (0.90, 0.98, 0.76)),
    ("wood_timber", ["bark_brown", "weathered_planks", "rough_wood", "oak_bark", "wood"], (0.95, 0.85, 0.72)),
    ("linen_canopy", ["linen", "fabric_pattern", "burlap", "canvas", "cloth"], (1.02, 0.98, 0.90)),
]

keys = list(catalog.keys())
downloaded_log = {}

for out_stem, keywords, tint in TARGETS:
    chosen = None
    for kw in keywords:
        matches = [k for k in keys if kw in k.lower()]
        if matches:
            # Prefer shortest/cleanest match
            matches.sort(key=lambda x: len(x))
            chosen = matches[0]
            break
    if not chosen:
        print(f"  WARN: No match for {out_stem}", flush=True)
        continue

    print(f"\n=== [{out_stem}] -> Poly Haven CC0 '{chosen}' ===", flush=True)
    files_meta = fetch_json(f"https://api.polyhaven.com/files/{chosen}")

    # Pick Diffuse / Albedo (1k png or jpg)
    diff_node = files_meta.get("Diffuse") or files_meta.get("col") or files_meta.get("albedo")
    norm_node = files_meta.get("nor_gl") or files_meta.get("Normal") or files_meta.get("nor_dx")

    for kind, node, suffix in [("albedo", diff_node, "albedo"), ("normal", norm_node, "normal")]:
        if not node:
            print(f"  missing {kind} for {chosen}", flush=True)
            continue
        res_node = node.get("1k") or node.get("2k")
        if not res_node:
            continue
        fmt_node = res_node.get("jpg") or res_node.get("png")
        if not fmt_node or "url" not in fmt_node:
            continue
        url = fmt_node["url"]
        tmp = os.path.join(OUT_DIR, f"_tmp_{out_stem}_{suffix}.img")
        download_file(url, tmp)
        im = Image.open(tmp).convert("RGB").resize((1024, 1024), Image.LANCZOS)
        if kind == "albedo" and tint != (1.0, 1.0, 1.0):
            # Subtle warm Mediterranean harmonization
            r, g, b = im.split()
            r = r.point(lambda v: min(255, int(v * tint[0])))
            g = g.point(lambda v: min(255, int(v * tint[1])))
            b = b.point(lambda v: min(255, int(v * tint[2])))
            im = Image.merge("RGB", (r, g, b))
        final_p = os.path.join(OUT_DIR, f"{out_stem}_{suffix}.png")
        im.save(final_p, optimize=True)
        os.remove(tmp)
        print(f"  SAVED {final_p} ({os.path.getsize(final_p):,} bytes)", flush=True)

    downloaded_log[out_stem] = chosen

# Also derive dark woven goat-hair canopy from real photographic linen weave + subtle beige warp stripes!
linen_alb = os.path.join(OUT_DIR, "linen_canopy_albedo.png")
linen_nrm = os.path.join(OUT_DIR, "linen_canopy_normal.png")
if os.path.exists(linen_alb):
    im = Image.open(linen_alb).convert("RGB")
    # Darken to rich woven dark-brown goat-hair while preserving authentic photographic weave fibers!
    r, g, b = im.split()
    r = r.point(lambda v: min(255, int(v * 0.36)))
    g = g.point(lambda v: min(255, int(v * 0.27)))
    b = b.point(lambda v: min(255, int(v * 0.19)))
    goat = Image.merge("RGB", (r, g, b))
    # Subtle woven warm beige stripe bands
    px = goat.load()
    for y in range(1024):
        band = (y % 256)
        if (24 <= band <= 34) or (42 <= band <= 48) or (180 <= band <= 192):
            for x in range(1024):
                cr, cg, cb = px[x, y]
                px[x, y] = (min(255, cr + 92), min(255, cg + 74), min(255, cb + 48))
    goat.save(os.path.join(OUT_DIR, "tent_goathair_albedo.png"), optimize=True)
    if os.path.exists(linen_nrm):
        Image.open(linen_nrm).save(os.path.join(OUT_DIR, "tent_goathair_normal.png"), optimize=True)
    print("\n=== Derived photographic woven tent_goathair_albedo/normal from CC0 linen weave ===", flush=True)

# Also sync terrain_rock to our new CC0 limestone
if os.path.exists(os.path.join(OUT_DIR, "rock_boulder_albedo.png")):
    Image.open(os.path.join(OUT_DIR, "rock_boulder_albedo.png")).save(os.path.join(OUT_DIR, "terrain_rock_albedo.png"), optimize=True)
    Image.open(os.path.join(OUT_DIR, "rock_boulder_normal.png")).save(os.path.join(OUT_DIR, "terrain_rock_normal.png"), optimize=True)

print("\nCC0_DOWNLOAD_SUMMARY:", json.dumps(downloaded_log))
