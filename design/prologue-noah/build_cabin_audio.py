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

    # 4. Authentic Ram's Horn Shofar Tekiah (1.75s: Bb3 -> F4 fifth leap with warm brass harmonics)
    n4 = int(SR * 1.75)
    s4 = [0.0] * n4
    phase4 = 0.0
    for i in range(n4):
        t = i / SR
        glide = 1.0 / (1.0 + math.exp(-(t - 0.34) * 22.0))
        freq = (233.08 * (1.0 - glide) + 349.23 * glide) * (1.0 + 0.008 * math.sin(tau * 5.2 * t))
        phase4 += tau * freq / SR
        atk = min(1.0, t / 0.08) * min(1.0, (1.75 - t) / 0.22)
        horn = (0.48 * math.sin(phase4) + 0.31 * math.sin(2.0 * phase4) + 0.19 * math.sin(3.0 * phase4) + 0.10 * math.sin(4.0 * phase4))
        breath = rng.gauss(0.0, 0.025) * math.exp(-t * 2.5)
        s4[i] = (horn * 0.52 + breath) * atk
    write_wav("sfx_shofar_horn.wav", s4)

    # 5. Perfect Rhythmic Assist Strike (0.65s: deep timber mortise thud + bronze harmonic ring)
    n5 = int(SR * 0.65)
    s5 = [0.0] * n5
    for i in range(n5):
        t = i / SR
        thud = 0.62 * math.sin(tau * (128.0 * math.exp(-t * 14.0) + 52.0) * t) * math.exp(-t * 16.0)
        chime = (0.28 * math.sin(tau * 587.33 * t) + 0.18 * math.sin(tau * 880.0 * t) + 0.10 * math.sin(tau * 1174.66 * t)) * math.exp(-t * 5.8)
        crack = rng.gauss(0.0, 0.24) * math.exp(-t * 48.0)
        s5[i] = thud + chime + crack
    write_wav("sfx_perfect_strike.wav", s5)

    # 6. Flood Hull Seam Water Leak Spray (2.2s spatial loop)
    n6 = int(SR * 2.2)
    s6 = [0.0] * n6
    hp = 0.0
    for i in range(n6):
        t = i / SR
        raw = rng.gauss(0.0, 1.0)
        hp += 0.28 * (raw - hp)
        surge = 0.68 + 0.32 * math.sin(tau * t / 1.1)
        bub = 0.08 * math.sin(tau * (320.0 + 90.0 * math.sin(tau * 7.0 * t)) * t)
        s6[i] = ((raw - hp) * 0.22 + bub) * surge
    write_wav("sfx_hull_leak.wav", s6)

    # 7. Canaanite Highland Night Wolf Howl Warning (1.45s)
    n7 = int(SR * 1.45)
    s7 = [0.0] * n7
    ph7 = 0.0
    for i in range(n7):
        t = i / SR
        rise = 1.0 / (1.0 + math.exp(-(t - 0.28) * 14.0))
        fall = 0.22 * max(0.0, t - 0.85)
        wf = (290.0 + 165.0 * rise - 140.0 * fall) * (1.0 + 0.012 * math.sin(tau * 6.0 * t))
        ph7 += tau * wf / SR
        env7 = min(1.0, t / 0.14) * min(1.0, (1.45 - t) / 0.28)
        s7[i] = (0.42 * math.sin(ph7) + 0.16 * math.sin(2.0 * ph7)) * env7
    write_wav("sfx_wolf_howl.wav", s7)

    # 8. Ancient Levant 10-String Kinnor Lyre & Drone Loop (12.0s seamless D-Dorian pastoral)
    n8 = int(SR * 12.0)
    s8 = [0.0] * n8
    notes = [
        (0.0, 293.66), (0.75, 440.00), (1.5, 349.23), (2.25, 392.00),
        (3.0, 440.00), (3.75, 523.25), (4.5, 440.00), (5.25, 392.00),
        (6.0, 349.23), (6.75, 293.66), (7.5, 329.63), (8.25, 349.23),
        (9.0, 392.00), (9.75, 349.23), (10.5, 329.63), (11.25, 293.66),
    ]
    for i in range(n8):
        t = i / SR
        drone = (0.075 * math.sin(tau * 146.83 * t) + 0.045 * math.sin(tau * 220.0 * t)) * (0.85 + 0.15 * math.sin(tau * t / 6.0))
        lyre = 0.0
        for nt, nf in notes:
            dt = t - nt
            if 0.0 <= dt < 2.2:
                e = math.exp(-dt * 2.35) * min(1.0, dt / 0.012)
                lyre += e * (0.14 * math.sin(tau * nf * dt) + 0.06 * math.sin(2.0 * tau * nf * dt) + 0.025 * math.sin(3.0 * tau * nf * dt))
        s8[i] = drone + lyre
    write_wav("bgm_levant_lyre_loop.wav", s8)


if __name__ == "__main__":
    main()
