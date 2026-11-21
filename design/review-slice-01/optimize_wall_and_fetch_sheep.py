import os
import re
import requests
import trimesh

MODELS = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"

# 1. Merge CC0_DryStoneWall_Innerscene.glb (46 meshes -> 4 meshes)
wall_path = os.path.join(MODELS, "CC0_DryStoneWall_Innerscene.glb")
sc = trimesh.load(wall_path)
if isinstance(sc, trimesh.Scene):
    groups = {}
    for node_name in sc.graph.nodes_geometry:
        xf, geom_name = sc.graph[node_name]
        g = sc.geometry[geom_name].copy()
        g.apply_transform(xf)
        mat = getattr(g.visual, "material", None)
        mat_key = getattr(mat, "name", None) or str(id(mat))
        groups.setdefault(mat_key, []).append(g)
    merged = trimesh.Scene()
    for k, meshes in groups.items():
        merged.add_geometry(trimesh.util.concatenate(meshes), node_name=f"wall_{k}")
    out_wall = os.path.join(MODELS, "CC0_DryStoneWall_Optimized.glb")
    merged.export(out_wall)
    print(f"Exported {out_wall} ({os.path.getsize(out_wall)/1024:.1f} KB, {len(merged.geometry)} geoms)")

# 2. Fetch uncompressed CC0 sheep GLB from grab3d.com
HEADERS = {"User-Agent": "Mozilla/5.0"}
found_sheep = False
for slug in ["sheep", "farm-sheep", "wool-sheep", "white-sheep", "lamb", "grazing-sheep", "fluffy-sheep"]:
    url = f"https://grab3d.com/dl/{slug}/{slug}.glb"
    try:
        r = requests.get(url, headers=HEADERS, timeout=12)
        if r.status_code == 200 and r.content[:4] == b"glTF":
            out_s = os.path.join(MODELS, "CC0_Sheep_Grab3D.glb")
            with open(out_s, "wb") as f:
                f.write(r.content)
            print(f"OK SAVED {out_s} ({len(r.content)/1024:.1f} KB) from {url}")
            found_sheep = True
            break
    except Exception:
        pass

if not found_sheep:
    # Search grab3d.com animals category page
    try:
        r = requests.get("https://grab3d.com/models/animals/", headers=HEADERS, timeout=15)
        slugs = list(dict.fromkeys(re.findall(r'/models/[a-z0-9\-]+/([a-z0-9\-]+)/', r.text)))
        print("Grab3D animals slugs:", slugs[:30])
        for s in slugs:
            if "sheep" in s or "lamb" in s or "ram" in s or "goat" in s:
                u = f"https://grab3d.com/dl/{s}/{s}.glb"
                rr = requests.get(u, headers=HEADERS, timeout=15)
                if rr.status_code == 200 and rr.content[:4] == b"glTF":
                    out_s = os.path.join(MODELS, "CC0_Sheep_Grab3D.glb")
                    with open(out_s, "wb") as f:
                        f.write(rr.content)
                    print(f"OK SAVED {out_s} ({len(rr.content)/1024:.1f} KB) from {u}")
                    found_sheep = True
                    break
    except Exception as e:
        print("Grab3D animals search err:", e)
