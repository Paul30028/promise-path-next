import os
import sys
import shutil
import time
from gradio_client import Client, handle_file

BASE = r"c:\AI\gemini\promise-path-next\design\review-slice-01"
IN_DIR = os.path.join(BASE, "inputs")
OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\models"
os.makedirs(OUT_DIR, exist_ok=True)


def _extract_path(val):
    if isinstance(val, dict):
        return val.get("value") or val.get("path")
    return val


def generate_trellis_glb(name, primary_img, multi_imgs=None, seed=42, mesh_simplify=0.92, texture_size=1024):
    print(f"\n=== [TRELLIS MIT] Generating {name}.glb ===", flush=True)
    hf_tok = os.environ.get("HF_TOKEN") or None
    client = Client("trellis-community/TRELLIS", token=hf_tok, verbose=False)
    try:
        client.predict(api_name="/start_session")
    except Exception as e:
        print(f"  start_session note: {e}", flush=True)

    # Preprocess primary image (removes background cleanly)
    print(f"  Preprocessing primary: {os.path.basename(primary_img)}", flush=True)
    proc_primary = client.predict(
        image=handle_file(primary_img),
        api_name="/preprocess_image",
    )
    proc_path = _extract_path(proc_primary)

    gallery_input = []
    if multi_imgs:
        for mimg in multi_imgs:
            gallery_input.append({"image": handle_file(mimg), "caption": None})
        print(f"  Preprocessing {len(multi_imgs)} multi-view images...", flush=True)
        proc_gallery = client.predict(
            images=gallery_input,
            api_name="/preprocess_images",
        )
        # Re-wrap processed gallery paths if returned
        gallery_input = []
        if isinstance(proc_gallery, list):
            for item in proc_gallery:
                p = _extract_path(item.get("image") if isinstance(item, dict) else item)
                if p:
                    gallery_input.append({"image": handle_file(p), "caption": None})

    print(f"  Running /generate_and_extract_glb (simplify={mesh_simplify}, tex={texture_size})...", flush=True)
    t0 = time.time()
    vid, glb_preview, glb_download = client.predict(
        image=handle_file(proc_path),
        multiimages=gallery_input,
        seed=seed,
        ss_guidance_strength=7.5,
        ss_sampling_steps=12,
        slat_guidance_strength=3.0,
        slat_sampling_steps=12,
        multiimage_algo="stochastic",
        mesh_simplify=mesh_simplify,
        texture_size=texture_size,
        api_name="/generate_and_extract_glb",
    )
    elapsed = time.time() - t0
    src = _extract_path(glb_download) or _extract_path(glb_preview)
    if not src or not os.path.exists(src):
        raise RuntimeError(f"TRELLIS did not return a valid GLB file: {glb_preview}, {glb_download}")

    out_path = os.path.join(OUT_DIR, f"{name}.glb")
    shutil.copy2(src, out_path)
    print(f"  SUCCESS in {elapsed:.1f}s -> {out_path} ({os.path.getsize(out_path):,} bytes)", flush=True)
    return out_path


if __name__ == "__main__":
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["CHR_Abram"]
    for t in targets:
        if t == "CHR_Abram":
            generate_trellis_glb(
                "CHR_Abram",
                primary_img=os.path.join(IN_DIR, "abram_front.png"),
                multi_imgs=[
                    os.path.join(IN_DIR, "abram_front.png"),
                    os.path.join(IN_DIR, "abram_back.png"),
                    os.path.join(IN_DIR, "abram_left.png"),
                    os.path.join(IN_DIR, "abram_right_flipped.png"),
                ],
                seed=1234,
                mesh_simplify=0.92,
                texture_size=1024,
            )
        elif os.path.exists(os.path.join(IN_DIR, f"{t}.png")):
            generate_trellis_glb(
                t,
                primary_img=os.path.join(IN_DIR, f"{t}.png"),
                seed=2026,
                mesh_simplify=0.92,
                texture_size=1024,
            )
        else:
            print(f"Unknown target or missing input PNG: {t}", flush=True)
