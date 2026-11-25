"""Pure stdlib 16-bit PCM spatial WAV generator for Ark & Tent interiors (zero external deps):
  1. sfx_ark_wood_creak.wav   — Deep cedar hull timber groaning & gentle wave heave
  2. sfx_oil_lamp_crackle.wav — Warm olive-oil clay lamp wick crackle
  3. sfx_animals_breath.wav   — Peaceful livestock breathing & soft hay rustle
"""
import array
import math
import os
import random
import wave

OUT_DIR = r"c:\AI\gemini\promise-path-next\godot-pilot\assets\audio"
SR = 22050


def write_wav(filename: str, samples: list[float]) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, filename)
    n = len(samples)
    fade = min(700, n // 8)
    pcm = array.array("h", [0] * n)
    for i, v in enumerate(samples):
        env = 1.0
        if i < fade:
            env = i / fade
        elif i >= n - fade:
            env = (n - 1 - i) / fade
        c = max(-1.0, min(1.0, v * env))
        pcm[i] = int(c * 32767.0)
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    print(f"OK {filename} ({os.path.getsize(path):,} bytes)")


def main() -> None:
    rng = random.Random(42)
    tau = 2.0 * math.pi

    # 1. Cedar hull creak & low wave resonance (3.5s)
    n1 = int(SR * 3.5)
    s1 = [0.0] * n1
    for i in range(n1):
        t = i / SR
        swell = 0.5 + 0.5 * math.sin(tau * t / 3.5)
        low_hull = 0.16 * math.sin(tau * 56.0 * t + 0.7 * math.sin(tau * 0.5 * t)) * swell
        c_env = math.exp(-((t - 1.15) / 0.28) ** 2) + 0.75 * math.exp(-((t - 2.55) / 0.24) ** 2)
        f_mod = 162.0 + 34.0 * math.sin(tau * 3.4 * t)
        creak = (math.sin(tau * f_mod * t) + 0.42 * math.sin(2.0 * tau * f_mod * t)) * 0.13 * c_env
        s1[i] = low_hull + creak
    write_wav("sfx_ark_wood_creak.wav", s1)

    # 2. Olive-oil lamp warm air & gentle wick crackle (2.5s)
    n2 = int(SR * 2.5)
    s2 = [0.0] * n2
    lp = 0.0
    pop = 0.0
    for i in range(n2):
        t = i / SR
        lp += 0.06 * (rng.gauss(0.0, 1.0) - lp)
        if rng.random() > 0.9986:
            pop = rng.uniform(0.10, 0.24)
        pop *= 0.92
        s2[i] = 0.16 * lp * (0.82 + 0.18 * math.sin(tau * t / 2.5)) + pop
    write_wav("sfx_oil_lamp_crackle.wav", s2)

    # 3. Peaceful livestock breathing & hay rustle (3.6s)
    n3 = int(SR * 3.6)
    s3 = [0.0] * n3
    bp = 0.0
    for i in range(n3):
        t = i / SR
        bp += 0.11 * (rng.gauss(0.0, 1.0) - bp)
        br = max(0.0, math.sin(tau * t / 1.8)) ** 1.8
        s3[i] = 0.14 * bp * br + 0.03 * math.sin(tau * 88.0 * t) * br
    write_wav("sfx_animals_breath.wav", s3)


if __name__ == "__main__":
    main()
