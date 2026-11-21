import os
import sys
import json
import urllib.request

BASE_OUT = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\cc0_models"
os.makedirs(BASE_OUT, exist_ok=True)


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "PromisePathStudio/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def download(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return
    req = urllib.request.Request(url, headers={"User-Agent": "PromisePathStudio/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        with open(dest, "wb") as f:
            f.write(r.read())


def fetch_model(asset_id, res="1k"):
    print(f"\n=== Fetching Poly Haven CC0 3D Model: {asset_id} ({res}) ===", flush=True)
    meta = fetch_json(f"https://api.polyhaven.com/files/{asset_id}")
    gltf_root = meta.get("gltf")
    if not gltf_root:
        print(f"  WARN: no gltf for {asset_id}", flush=True)
        return False
    res_node = gltf_root.get(res) or gltf_root.get("1k") or gltf_root.get("2k")
    if not res_node or "gltf" not in res_node:
        print(f"  WARN: no {res} gltf entry for {asset_id}", flush=True)
        return False

    entry = res_node["gltf"]
    model_dir = os.path.join(BASE_OUT, asset_id)
    os.makedirs(model_dir, exist_ok=True)

    main_url = entry["url"]
    main_name = os.path.basename(main_url.split("?")[0])
    main_dest = os.path.join(model_dir, main_name)
    download(main_url, main_dest)

    includes = entry.get("include", {})
    for rel_path, inc_info in includes.items():
        inc_dest = os.path.join(model_dir, rel_path.replace("/", os.sep))
        download(inc_info["url"], inc_dest)

    print(f"  READY: {main_dest} (+{len(includes)} includes)", flush=True)
    return True


if __name__ == "__main__":
    DEFAULT_MODELS = [
        # Real Photoscanned Geological Cliffs & Boulders (CC0!)
        "coastal_cliff_01",
        "coastal_cliff_02",
        "boulder_01",
        "coast_rocks_01",
        "coast_rocks_02",
        "coast_rocks_05",
        # Real Branched Airy Mediterranean Trees & Shrubs (CC0!)
        "island_tree_01",
        "island_tree_02",
        "grass_medium_01",
        "flower_gazania",
        # Real Handcrafted Camp Props (CC0!)
        "dry_branches_medium_01",
        "antique_ceramic_vase_01",
        "WoodenTable_02",
    ]
    targets = sys.argv[1:] if len(sys.argv) > 1 else DEFAULT_MODELS
    ok = 0
    for m in targets:
        try:
            if fetch_model(m, res="1k"):
                ok += 1
        except Exception as e:
            print(f"  ERR {m}: {e}", flush=True)
    print(f"\nDONE: {ok}/{len(targets)} CC0 3D models ready in {BASE_OUT}", flush=True)
