import os
import subprocess

roots = [
    r"C:\Users\holyx",
    r"C:\Program Files",
    r"C:\Program Files (x86)",
    r"C:\AI",
    "D:\\",
    "C:\\",
]

godot_exe = None
for root in roots:
    if not os.path.exists(root):
        continue
    max_depth = 1 if root == "C:\\" else 4
    for r, ds, fs in os.walk(root):
        depth = r.rstrip("\\").count("\\") - root.rstrip("\\").count("\\")
        if depth >= max_depth:
            ds[:] = []
        # Skip noisy folders
        ds[:] = [d for d in ds if d.lower() not in {"node_modules", ".git", "windows", "winsxs", "$recycle.bin"}]
        for f in fs:
            fl = f.lower()
            if "godot" in fl and fl.endswith(".exe") and "console" not in fl:
                godot_exe = os.path.join(r, f)
                break
        if godot_exe:
            break
    if godot_exe:
        break

print("GODOT_EXE:", godot_exe)
if not godot_exe:
    raise SystemExit(1)

pilot = r"c:\AI\gemini\promise-path-next\godot-pilot"
shots_dir = os.path.join(pilot, "shots")
os.makedirs(shots_dir, exist_ok=True)

v = subprocess.run([godot_exe, "--version"], capture_output=True, text=True)
print("VERSION:", v.stdout.strip() or v.stderr.strip())

check_script = r"C:\AI\gemini\.agent\skills\godot-3d-essentials\assets\check_3d_scene.gd"
chk = subprocess.run(
    [godot_exe, "--headless", "--path", pilot, "--script", check_script, "--", "res://scenes/camp_pilot.tscn"],
    capture_output=True,
    text=True,
    timeout=45,
)
print("CHECK_RC:", chk.returncode)
print("CHECK_OUT:", chk.stdout[-1500:])
if chk.stderr:
    print("CHECK_ERR:", chk.stderr[-800:])

shot_path = os.path.join(shots_dir, "pilot.png")
ren = subprocess.run(
    [godot_exe, "--path", pilot, "--rendering-driver", "vulkan", "--write-movie", shot_path, "--quit-after", "6", "res://scenes/camp_pilot.tscn"],
    capture_output=True,
    text=True,
    timeout=60,
)
print("RENDER_RC:", ren.returncode)
print("SHOTS:", sorted(os.listdir(shots_dir)))
