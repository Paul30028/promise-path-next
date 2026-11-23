import os
import sys
import time
import types
import numpy as np
import torch
import trimesh
from PIL import Image
from skimage.measure import marching_cubes as sk_marching_cubes

# Inject torchmcubes shim before importing tsr
_mc_mod = types.ModuleType("torchmcubes")


def _marching_cubes_shim(volume: torch.Tensor, threshold: float = 0.0):
    vol_np = volume.detach().cpu().float().numpy()
    verts, faces, _, _ = sk_marching_cubes(vol_np, level=float(threshold))
    verts_zyx = np.ascontiguousarray(verts[:, [2, 1, 0]], dtype=np.float32)
    faces_i64 = np.ascontiguousarray(faces[:, [0, 2, 1]], dtype=np.int64)
    return torch.from_numpy(verts_zyx), torch.from_numpy(faces_i64)


_mc_mod.marching_cubes = _marching_cubes_shim
sys.modules["torchmcubes"] = _mc_mod
sys.modules["rembg"] = types.ModuleType("rembg")

sys.path.insert(0, r"C:\AI\TripoSR")
sys.path.insert(0, r"c:\AI\gemini\promise-path-next\design\review-slice-01")
from scipy.ndimage import label
from tsr.system import TSR
from tsr.utils import resize_foreground
from rig_characters_glb import rig_glb

SHEET_PATH = r"c:\AI\gemini\promise-path-next\design\prologue-noah\CHR_Noah_sheet.png"
CROP_PATH = r"c:\AI\gemini\promise-path-next\design\prologue-noah\CHR_Noah_front.png"
OUT_RAW = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models\CHR_Noah.glb"
OUT_RIG = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models\CHR_Noah_rigged.glb"


def remove_studio_bg(pil_img: Image.Image, tol: float = 24.0) -> Image.Image:
    rgb = np.array(pil_img.convert("RGB"), dtype=np.float32)
    h, w, _ = rgb.shape
    corners = np.concatenate([
        rgb[:16, :16].reshape(-1, 3),
        rgb[:16, -16:].reshape(-1, 3),
        rgb[-16:, :16].reshape(-1, 3),
        rgb[-16:, -16:].reshape(-1, 3),
    ], axis=0)
    bg_col = np.median(corners, axis=0)
    dist = np.linalg.norm(rgb - bg_col[None, None, :], axis=2)
    labeled, _ = label(dist < tol)
    border_labels = set(np.unique(np.concatenate([
        labeled[0, :], labeled[-1, :], labeled[:, 0], labeled[:, -1]
    ])))
    border_labels.discard(0)
    bg_mask = np.isin(labeled, list(border_labels))
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb.astype(np.uint8)
    rgba[:, :, 3] = ((~bg_mask).astype(np.float32) * 255.0).astype(np.uint8)
    return Image.fromarray(rgba, mode="RGBA")


def main():
    t0 = time.time()
    sheet = Image.open(SHEET_PATH).convert("RGB")
    w, h = sheet.size
    front = sheet.crop((0, 0, int(w * 0.355), h))
    front.save(CROP_PATH)
    print(f"Cropped front A-Pose: {front.size} -> {CROP_PATH}", flush=True)

    device = "cuda:0" if torch.cuda.is_available() else "cpu"
    print(f"Loading TripoSR on {device}...", flush=True)
    model = TSR.from_pretrained("stabilityai/TripoSR", config_name="config.yaml", weight_name="model.ckpt")
    model.renderer.set_chunk_size(8192)
    model.to(device)

    fg = remove_studio_bg(front, tol=24.0)
    fg = resize_foreground(fg, 0.85)
    arr = np.array(fg).astype(np.float32) / 255.0
    arr = arr[:, :, :3] * arr[:, :, 3:4] + (1.0 - arr[:, :, 3:4]) * 0.5
    img_proc = Image.fromarray((arr * 255.0).astype(np.uint8))

    with torch.no_grad():
        scene_codes = model([img_proc], device=device)

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
    rot_x = trimesh.transformations.rotation_matrix(-np.pi / 2.0, [1, 0, 0])
    tmesh = trimesh.Trimesh(
        vertices=verts,
        faces=faces,
        visual=trimesh.visual.TextureVisuals(uv=uvs, image=tex_img),
        process=False,
    )
    tmesh.apply_transform(rot_x)
    tmesh.export(OUT_RAW)
    print(f"Exported UV-baked {OUT_RAW} ({os.path.getsize(OUT_RAW):,} bytes, {time.time() - t0:.1f}s)", flush=True)

    torch.cuda.empty_cache()

    print("Rigging 14-bone Skeleton3D + Idle/Walk/Pray...", flush=True)
    rig_glb(OUT_RAW, OUT_RIG, is_sarai=False)
    print(f"DONE: {OUT_RIG} ({os.path.getsize(OUT_RIG):,} bytes, total {time.time() - t0:.1f}s)", flush=True)


if __name__ == "__main__":
    main()
