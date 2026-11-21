import json
import os
import struct
import trimesh

MODELS = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"

def peek_glb_json(path):
    with open(path, "rb") as f:
        magic, ver, length = struct.unpack("<4sII", f.read(12))
        chunk_len, chunk_type = struct.unpack("<II", f.read(8))
        return json.loads(f.read(chunk_len).decode("utf-8"))

for name in ["CC0_Sheep_Rigged.glb", "CC0_StoneStairs.glb", "CC0_DryStoneWall_Innerscene.glb", "CC0_OliveTree_Mature.glb"]:
    p = os.path.join(MODELS, name)
    j = peek_glb_json(p)
    print(f"=== {name}: meshes={len(j.get('meshes',[]))}, nodes={len(j.get('nodes',[]))}, skins={len(j.get('skins',[]))}, mats={len(j.get('materials',[]))}, exts={j.get('extensionsRequired',[])} ===")
    try:
        sc = trimesh.load(p)
        if isinstance(sc, trimesh.Scene):
            print(f"    trimesh: {len(sc.geometry)} geoms, extents={sc.extents.round(3).tolist()}")
        else:
            print(f"    trimesh: single mesh, extents={sc.extents.round(3).tolist()}")
    except Exception as e:
        print(f"    trimesh err: {e}")

# Optimize CC0_OliveTree_Mature.glb by merging meshes per material
olive_path = os.path.join(MODELS, "CC0_OliveTree_Mature.glb")
sc = trimesh.load(olive_path)
if isinstance(sc, trimesh.Scene):
    groups = {}
    for node_name in sc.graph.nodes_geometry:
        xf, geom_name = sc.graph[node_name]
        g = sc.geometry[geom_name].copy()
        g.apply_transform(xf)
        mat = getattr(g.visual, "material", None)
        mat_key = getattr(mat, "name", None) or str(id(mat))
        groups.setdefault(mat_key, []).append(g)
    print(f"Olive material groups: {list(groups.keys())} -> {[len(v) for v in groups.values()]}")
    merged = trimesh.Scene()
    for k, meshes in groups.items():
        merged.add_geometry(trimesh.util.concatenate(meshes), node_name=f"merged_{k}")
    out_olive = os.path.join(MODELS, "CC0_OliveTree_Optimized.glb")
    merged.export(out_olive)
    print(f"Exported {out_olive} ({os.path.getsize(out_olive)/1024:.1f} KB, {len(merged.geometry)} geoms)")
