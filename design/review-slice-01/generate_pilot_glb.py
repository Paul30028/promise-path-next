import os
import shutil
import time
from gradio_client import Client, handle_file

BASE = r"c:\AI\gemini\promise-path-next\design\review-slice-01"
IN_DIR = os.path.join(BASE, "inputs")
OUT_DIR = os.path.join(BASE, "pilot-glb")
os.makedirs(OUT_DIR, exist_ok=True)

client = Client("tencent/Hunyuan3D-2.1", verbose=False)


def _extract_path(val):
    if isinstance(val, dict):
        return val.get("value") or val.get("path")
    return val


def gen_shape(name, img, front=None, back=None, left=None, right=None, seed=1234):
    print(f"=== Generating {name} shape via Hunyuan3D-2.1 (/shape_generation) ===")
    for attempt in range(2):
        try:
            white_file, _, stats, out_seed = client.predict(
                image=handle_file(img),
                mv_image_front=handle_file(front) if front else None,
                mv_image_back=handle_file(back) if back else None,
                mv_image_left=handle_file(left) if left else None,
                mv_image_right=handle_file(right) if right else None,
                steps=15,
                guidance_scale=5.5,
                seed=seed,
                octree_resolution=256,
                check_box_rembg=True,
                num_chunks=8000,
                randomize_seed=False,
                api_name="/shape_generation",
            )
            src_path = _extract_path(white_file)
            out_path = os.path.join(OUT_DIR, f"{name}_pilot.glb")
            shutil.copy2(src_path, out_path)
            print("SAVED:", out_path, os.path.getsize(out_path), stats)
            return out_path
        except Exception as e:
            print(f"Attempt {attempt + 1} failed: {e}")
            time.sleep(2)
    return None


gen_shape(
    "CHR_Abram",
    img=os.path.join(IN_DIR, "abram_front.png"),
    front=os.path.join(IN_DIR, "abram_front.png"),
    back=os.path.join(IN_DIR, "abram_back.png"),
    left=os.path.join(IN_DIR, "abram_left.png"),
    right=os.path.join(IN_DIR, "abram_right_flipped.png"),
    seed=1234,
)

gen_shape(
    "PRP_Amphora",
    img=os.path.join(IN_DIR, "prop_amphora_ref.png"),
    seed=2026,
)

print("PILOT_GLB_FILES:", sorted(os.listdir(OUT_DIR)))
