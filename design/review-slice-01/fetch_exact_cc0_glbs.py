import os
import re
import urllib.request
from urllib.parse import urljoin

OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    "Accept": "*/*",
}

# Remove mis-targeted wheat file saved as CC0_DryStoneWall.glb
bad_wall = os.path.join(OUT_DIR, "CC0_DryStoneWall.glb")
if os.path.exists(bad_wall) and os.path.getsize(bad_wall) > 1_800_000:
    os.remove(bad_wall)
    print("Removed mis-targeted wheat-crop-stages file.")

def get_bytes(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.geturl(), r.read()

def save_glb(url, out_name):
    print(f"  Downloading {url} -> {out_name}...")
    _, data = get_bytes(url)
    if data[:4] == b"glTF":
        p = os.path.join(OUT_DIR, out_name)
        with open(p, "wb") as f:
            f.write(data)
        print(f"  OK SAVED {out_name} ({len(data)/1024:.1f} KB)")
        return True
    print(f"  NOT GLB (header={data[:20]!r}, len={len(data)})")
    return False

# 1. Innerscene CC0 parts (Dry Stone Wall Section + Mature Olive Tree)
for out_name, page_url in [
    ("CC0_DryStoneWall_Innerscene.glb", "https://www.innerscene.com/tools/library/3d-parts/dry-stone-wall-section-f63adad9"),
    ("CC0_OliveTree_Mature.glb", "https://www.innerscene.com/tools/library/3d-parts/mature-olive-tree-bc261a43"),
]:
    print(f"\n=== Innerscene: {out_name} ===")
    try:
        final_url, body = get_bytes(page_url)
        html = body.decode("utf-8", errors="ignore")
        # Look for href near "Download"
        m = re.findall(r'href="([^"]+)"[^>]*>[^<]*Download', html, re.I)
        print("  Download hrefs:", m[:5])
        if m:
            dl_url = urljoin(final_url, m[0].replace("&amp;", "&"))
            save_glb(dl_url, out_name)
    except Exception as e:
        print("  ERR:", e)

# 2. Grab3D Cozy Ancient Ruins Kit (Amphora!) & Cozy Farm Countryside Kit (Dry Stone Wall!)
for kit_url, keywords in [
    ("https://grab3d.com/kits/cozy-ancient-ruins/", [("amphora", "CC0_Amphora.glb"), ("jar", "CC0_Jar.glb"), ("pot", "CC0_Pot.glb"), ("wall", "CC0_RuinWall.glb")]),
    ("https://grab3d.com/kits/cozy-farm-countryside/", [("dry-stone-wall", "CC0_DryStoneWall.glb"), ("stone-wall", "CC0_DryStoneWall.glb"), ("olive", "CC0_OliveTree_Grab3D.glb")]),
]:
    print(f"\n=== Grab3D Kit: {kit_url} ===")
    try:
        _, body = get_bytes(kit_url)
        html = body.decode("utf-8", errors="ignore")
        slugs = list(dict.fromkeys(re.findall(r'/models/[a-z0-9\-]+/([a-z0-9\-]+)/', html)))
        print(f"  Found {len(slugs)} model slugs: {slugs[:25]}")
        for kw, out_name in keywords:
            matches = [s for s in slugs if kw in s]
            if matches and not os.path.exists(os.path.join(OUT_DIR, out_name)):
                slug = matches[0]
                dl_url = f"https://grab3d.com/dl/{slug}/{slug}.glb"
                save_glb(dl_url, out_name)
    except Exception as e:
        print("  ERR:", e)
