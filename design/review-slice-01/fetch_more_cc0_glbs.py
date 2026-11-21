import os
import requests

OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

TARGETS = [
    ("CC0_OliveTree_Mature.glb", "https://www.innerscene.com/api/library/mature-olive-tree-bc261a43/download"),
    ("CC0_DryStoneWall.glb", "https://grab3d.com/dl/dry-stone-wall/dry-stone-wall.glb"),
    ("CC0_StoneStairs.glb", "https://grab3d.com/dl/ruin-stairs/ruin-stairs.glb"),
]

for name, url in TARGETS:
    print(f"Downloading {name} from {url}...")
    try:
        r = requests.get(url, headers=HEADERS, timeout=60, stream=True)
        data = r.content
        if r.status_code == 200 and data[:4] == b"glTF":
            p = os.path.join(OUT_DIR, name)
            with open(p, "wb") as f:
                f.write(data)
            print(f"  OK SAVED {name} ({len(data)/1024:.1f} KB)")
        else:
            print(f"  FAIL status={r.status_code} header={data[:16]!r} len={len(data)}")
    except Exception as e:
        print(f"  ERR: {e}")

print("\nAll CC0/MIT models in godot-pilot/assets/models:")
for fn in sorted(os.listdir(OUT_DIR)):
    if fn.endswith(".glb"):
        sz = os.path.getsize(os.path.join(OUT_DIR, fn)) / 1024.0
        print(f"  {fn:36s} {sz:8.1f} KB")
