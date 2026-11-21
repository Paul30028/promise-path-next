import os
import sys
import shutil
import time
from gradio_client import Client, handle_file

IN_DIR = r"c:\AI\gemini\promise-path-next\design\review-slice-01\inputs"
OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"
os.makedirs(OUT_DIR, exist_ok=True)


def _extract_path(val):
    if isinstance(val, dict):
        return val.get("value") or val.get("path")
    return val


def generate_one(name, img_path, target_faces=18000, seed=42):
    print(f"\n=== [TripoSG MIT] Generating {name}.glb from {os.path.basename(img_path)} ===", flush=True)
    hf_tok = os.environ.get("HF_TOKEN") or None
    client = Client("VAST-AI/TripoSG", token=hf_tok, verbose=False)
    try:
        client.predict(api_name="/start_session")
    except Exception:
        pass

    t0 = time.time()
    print("  1/3 /run_segmentation ...", flush=True)
    seg_res = client.predict(image=handle_file(img_path), api_name="/run_segmentation")
    seg_path = _extract_path(seg_res) or img_path

    print(f"  2/3 /image_to_3d (faces={target_faces}) ...", flush=True)
    mesh_res = client.predict(
        image=handle_file(seg_path),
        seed=seed,
        num_inference_steps=32,
        guidance_scale=7.0,
        simplify=True,
        target_face_num=target_faces,
        api_name="/image_to_3d",
    )
    mesh_path = _extract_path(mesh_res)
    print(f"  mesh ready ({time.time() - t0:.1f}s): {mesh_path}", flush=True)

    print("  3/3 /run_texture (PBR texturing) ...", flush=True)
    tex_res = client.predict(
        image=handle_file(seg_path),
        mesh_path=handle_file(mesh_path),
        seed=seed,
        api_name="/run_texture",
    )
    tex_path = _extract_path(tex_res) or mesh_path
    out_path = os.path.join(OUT_DIR, f"{name}.glb")
    shutil.copy2(tex_path, out_path)
    print(f"  SUCCESS in {time.time() - t0:.1f}s -> {out_path} ({os.path.getsize(out_path):,} bytes)", flush=True)
    return out_path


if __name__ == "__main__":
    MAP = {
        "CHR_Abram": ("abram_front.png", 16000, 1234),
        "BLD_MainTent": ("BLD_MainTent.png", 24000, 2026),
        "BLD_StoneWell": ("BLD_StoneWell.png", 16000, 2027),
        "CHR_Sheep": ("CHR_Sheep.png", 10000, 2028),
    }
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["CHR_Abram", "BLD_MainTent", "BLD_StoneWell", "CHR_Sheep"]
    for t in targets:
        if t in MAP:
            fn, faces, sd = MAP[t]
            try:
                generate_one(t, os.path.join(IN_DIR, fn), target_faces=faces, seed=sd)
            except Exception as e:
                print(f"  FAILED {t}: {e}", flush=True)
