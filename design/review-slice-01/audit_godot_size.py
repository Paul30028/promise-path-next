import os

ASSETS_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets"
files = []
for root, _, fnames in os.walk(ASSETS_DIR):
    for fn in fnames:
        if fn.endswith(".import"):
            continue
        p = os.path.join(root, fn)
        files.append((os.path.getsize(p), os.path.relpath(p, ASSETS_DIR)))

files.sort(reverse=True)
total_mb = sum(sz for sz, _ in files) / (1024 * 1024)
print(f"=== GodotSize Asset Footprint Audit | Total: {total_mb:.2f} MB ({len(files)} files) ===")
for sz, rel in files[:12]:
    print(f"  {sz / (1024 * 1024):6.2f} MB  {rel}")
