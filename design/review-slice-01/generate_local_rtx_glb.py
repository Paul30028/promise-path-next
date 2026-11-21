import os
import sys
import time
import types
import numpy as np
import torch
import trimesh
from PIL import Image
from skimage.measure import marching_cubes as sk_marching_cubes

# 1. Inject pure-wheel torchmcubes shim BEFORE importing tsr (zero C++ build needed on Windows!)
_mc_mod = types.ModuleType("torchmcubes")


def _marching_cubes_shim(volume: torch.Tensor, threshold: float = 0.0):
    vol_np = volume.detach().cpu().float().numpy()
    verts, faces, _, _ = sk_marching_cubes(vol_np, level=float(threshold))
    # torchmcubes returns (z, y, x) and TripoSR flips [..., [2, 1, 0]] back to (x, y, z)
    # skimage already returns (x, y, z), so flip to (z, y, x) so TripoSR's flip restores (x, y, z)
    verts_zyx = np.ascontiguousarray(verts[:, [2, 1, 0]], dtype=np.float32)
    # Flip triangle winding so outward normals catch sunlight properly in Godot!
    faces_i64 = np.ascontiguousarray(faces[:, [0, 2, 1]], dtype=np.int64)
    return torch.from_numpy(verts_zyx), torch.from_numpy(faces_i64)


_mc_mod.marching_cubes = _marching_cubes_shim
sys.modules["torchmcubes"] = _mc_mod
sys.modules["rembg"] = types.ModuleType("rembg")

sys.path.insert(0, r"C:\AI\TripoSR")
from scipy.ndimage import binary_dilation, label
from tsr.system import TSR
from tsr.utils import resize_foreground

IN_DIR = r"c:\AI\gemini\promise-path-next\design\review-slice-01\inputs"
OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"
os.makedirs(OUT_DIR, exist_ok=True)


def remove_studio_bg(pil_img: Image.Image, tol: float = 24.0) -> Image.Image:
    """Clean border flood-fill studio background removal (zero onnxruntime needed)."""
    rgb = np.array(pil_img.convert("RGB"), dtype=np.float32)
    h, w, _ = rgb.shape
    # Sample corner patches to estimate exact studio gray color
    corners = np.concatenate([
        rgb[:16, :16].reshape(-1, 3),
        rgb[:16, -16:].reshape(-1, 3),
        rgb[-16:, :16].reshape(-1, 3),
        rgb[-16:, -16:].reshape(-1, 3),
    ], axis=0)
    bg_col = np.median(corners, axis=0)
    dist = np.linalg.norm(rgb - bg_col[None, None, :], axis=2)
    is_bg_cand = dist < tol
    # Keep only background components connected to the image border
    labeled, _ = label(is_bg_cand)
    border_labels = set(np.unique(np.concatenate([
        labeled[0, :], labeled[-1, :], labeled[:, 0], labeled[:, -1]
    ])))
    border_labels.discard(0)
    bg_mask = np.isin(labeled, list(border_labels))
    # Soft feather 1px edge
    alpha = (~bg_mask).astype(np.float32)
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb.astype(np.uint8)
    rgba[:, :, 3] = (alpha * 255.0).astype(np.uint8)
    return Image.fromarray(rgba, mode="RGBA")


def run_batch(targets):
    device = "cuda:0" if torch.cuda.is_available() else "cpu"
    print(f"=== Local RTX 3D Factory | device={device} | torch={torch.__version__} ===", flush=True)
    if torch.cuda.is_available():
        print(f"    GPU: {torch.cuda.get_device_name(0)}", flush=True)

    t0 = time.time()
    print("Loading TripoSR (MIT) model...", flush=True)
    model = TSR.from_pretrained(
        "stabilityai/TripoSR",
        config_name="config.yaml",
        weight_name="model.ckpt",
    )
    model.renderer.set_chunk_size(8192)
    model.to(device)
    print(f"Model ready in {time.time() - t0:.1f}s", flush=True)

    MAP = {
        "CHR_Abram": "abram_front.png",
        "BLD_MainTent": "BLD_MainTent.png",
        "BLD_StoneWell": "BLD_StoneWell.png",
        "CHR_Sheep": "CHR_Sheep.png",
    }

    for name in targets:
        if name not in MAP:
            continue
        img_path = os.path.join(IN_DIR, MAP[name])
        if not os.path.exists(img_path):
            print(f"Missing input: {img_path}", flush=True)
            continue

        ts = time.time()
        print(f"\n--- Generating {name}.glb from {MAP[name]} ---", flush=True)
        raw = Image.open(img_path)
        fg = remove_studio_bg(raw, tol=28.0)
        fg = resize_foreground(fg, 0.85)
        arr = np.array(fg).astype(np.float32) / 255.0
        arr = arr[:, :, :3] * arr[:, :, 3:4] + (1.0 - arr[:, :, 3:4]) * 0.5
        img_proc = Image.fromarray((arr * 255.0).astype(np.uint8))

        with torch.no_grad():
            scene_codes = model([img_proc], device=device)

        # Try UV texture baking first; fall back cleanly to high-res vertex colors if moderngl fails
        out_glb = os.path.join(OUT_DIR, f"{name}.glb")
        baked_ok = False
        try:
            from tsr.bake_texture import bake_texture

            meshes = model.extract_mesh(scene_codes, has_vertex_color=False, resolution=256)
            mesh = meshes[0]
            bake_out = bake_texture(mesh, model, scene_codes[0], texture_resolution=1024)
            tex_img = Image.fromarray((bake_out["colors"] * 255.0).astype(np.uint8)).transpose(
                Image.FLIP_TOP_BOTTOM
            )
            verts = mesh.vertices[bake_out["vmapping"]].copy()
            faces = bake_out["indices"]
            uvs = bake_out["uvs"]
            # TripoSR is Z-up; rotate -90 deg around X to Godot Y-up
            rot_x = trimesh.transformations.rotation_matrix(-np.pi / 2.0, [1, 0, 0])
            tmesh = trimesh.Trimesh(
                vertices=verts,
                faces=faces,
                visual=trimesh.visual.TextureVisuals(uv=uvs, image=tex_img),
                process=False,
            )
            tmesh.apply_transform(rot_x)
            tmesh.export(out_glb)
            baked_ok = True
            print(f"  [UV 1024px Baked] {out_glb} ({os.path.getsize(out_glb):,} bytes, {time.time() - ts:.1f}s)", flush=True)
        except Exception as e:
            print(f"  UV bake fallback ({e}), exporting high-res vertex-color GLB...", flush=True)

        if not baked_ok:
            meshes = model.extract_mesh(scene_codes, has_vertex_color=True, resolution=256)
            mesh = meshes[0]
            rot_x = trimesh.transformations.rotation_matrix(-np.pi / 2.0, [1, 0, 0])
            mesh.apply_transform(rot_x)
            mesh.export(out_glb)
            print(f"  [VertexColor GLB] {out_glb} ({os.path.getsize(out_glb):,} bytes, {time.time() - ts:.1f}s)", flush=True)

        torch.cuda.empty_cache()


if __name__ == "__main__":
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["CHR_Abram", "BLD_MainTent", "BLD_StoneWell", "CHR_Sheep"]
    run_batch(targets)
