import math
import os
import struct
import wave
import numpy as np

OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\audio"
os.makedirs(OUT_DIR, exist_ok=True)
SR = 22050


def write_wav(name: str, samples: np.ndarray):
    s = np.clip(samples, -1.0, 1.0)
    pcm = (s * 32767.0).astype(np.int16)
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    print(f"OK SFX {name} ({os.path.getsize(path):,} bytes)")


def main():
    rng = np.random.default_rng(42)

    # 1. sfx_ui_click.wav (crisp warm wooden click for UI buttons)
    t = np.linspace(0, 0.08, int(SR * 0.08), endpoint=False)
    sig = np.sin(2 * np.pi * (620 - 240 * t / 0.08) * t) * np.exp(-t * 48.0) * 0.55
    write_wav("sfx_ui_click.wav", sig)

    # 2. sfx_assign.wav (pleasant 2-note upward chime for worker assignment)
    t = np.linspace(0, 0.16, int(SR * 0.16), endpoint=False)
    f = np.where(t < 0.075, 523.25, 659.25)
    sig = np.sin(2 * np.pi * f * t) * np.exp(-np.mod(t, 0.075) * 24.0) * 0.45
    write_wav("sfx_assign.wav", sig)

    # 3. sfx_hammer.wav (realistic wooden mallet knock on hollow gopher-wood timber!)
    t = np.linspace(0, 0.24, int(SR * 0.24), endpoint=False)
    thump = np.sin(2 * np.pi * (165 * np.exp(-t * 10.0) + 75) * t) * np.exp(-t * 22.0)
    wood_res = np.sin(2 * np.pi * 410 * t) * np.exp(-t * 36.0) * 0.35
    crack = rng.normal(0, 1, len(t)) * np.exp(-t * 85.0) * 0.45
    write_wav("sfx_hammer.wav", (thump * 0.8 + wood_res + crack) * 0.75)

    # 4. sfx_alert.wav (tense low bronze horn/warning pulse for raider theft / low timber)
    t = np.linspace(0, 0.38, int(SR * 0.38), endpoint=False)
    sig = (np.sin(2 * np.pi * 220 * t) + 0.5 * np.sin(2 * np.pi * 330 * t)) * np.exp(-t * 6.5) * 0.45
    write_wav("sfx_alert.wav", sig)

    # 5. sfx_covenant_chime.wav (warm sacred harp/bell chord for Divine Revelation & Rainbow Covenant)
    t = np.linspace(0, 2.4, int(SR * 2.4), endpoint=False)
    chord = (
        0.35 * np.sin(2 * np.pi * 261.63 * t)
        + 0.30 * np.sin(2 * np.pi * 329.63 * t)
        + 0.25 * np.sin(2 * np.pi * 392.00 * t)
        + 0.20 * np.sin(2 * np.pi * 523.25 * t)
    )
    env = (1.0 - np.exp(-t * 14.0)) * np.exp(-t * 1.45)
    write_wav("sfx_covenant_chime.wav", chord * env * 0.65)

    # 6. sfx_rain_loop.wav (3.0s smooth seamless pink-filtered rain ambience loop)
    n = int(SR * 3.0)
    white = rng.normal(0, 1, n)
    # Simple moving-average lowpass for warm heavy rain texture
    kernel = np.ones(9) / 9.0
    rain = np.convolve(white, kernel, mode="same") * 0.28
    # Crossfade edges for seamless looping
    fade = int(SR * 0.15)
    w = np.linspace(0, 1, fade)
    rain[:fade] = rain[:fade] * w + rain[-fade:] * (1.0 - w)
    write_wav("sfx_rain_loop.wav", rain)

    # 7. sfx_thunder.wav (deep rolling distant storm thunder)
    t = np.linspace(0, 2.2, int(SR * 2.2), endpoint=False)
    noise = rng.normal(0, 1, len(t))
    k2 = np.ones(45) / 45.0
    rumble = np.convolve(noise, k2, mode="same") * 3.2
    env = (1.0 - np.exp(-t * 9.0)) * np.exp(-t * 1.6) * (0.75 + 0.25 * np.sin(2 * np.pi * 3.2 * t))
    write_wav("sfx_thunder.wav", rumble * env * 0.85)


if __name__ == "__main__":
    main()
