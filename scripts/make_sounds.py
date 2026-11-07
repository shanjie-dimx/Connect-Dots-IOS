#!/usr/bin/env python3
"""Synthesizes the game's short sound effects into ColorLink/Sounds/*.wav.

Usage: python3 scripts/make_sounds.py
"""

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "ColorLink", "Sounds")
RATE = 44100


def note(freq, dur, volume=0.5, attack=0.005, decay=6.0, harmonics=(1.0, 0.35, 0.12), sweep=0.0):
    n = int(dur * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + sweep * t / dur)
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = sum(a * math.sin(phase * (k + 1)) for k, a in enumerate(harmonics))
        out.append(volume * env * s)
    return out


def noise(dur, volume=0.3, decay=30.0, seed=1):
    rng = random.Random(seed)
    return [volume * math.exp(-decay * i / RATE) * (rng.random() * 2 - 1) for i in range(int(dur * RATE))]


def mix(*tracks):
    """Each track is (start_seconds, samples)."""
    length = max(int(start * RATE) + len(s) for start, s in tracks)
    out = [0.0] * length
    for start, samples in tracks:
        offset = int(start * RATE)
        for i, v in enumerate(samples):
            out[offset + i] += v
    return out


def save(name, samples):
    peak = max(1e-9, max(abs(v) for v in samples))
    scale = min(1.0, 0.9 / peak)
    fade = int(0.01 * RATE)
    data = bytearray()
    for i, v in enumerate(samples):
        if i > len(samples) - fade:
            v *= (len(samples) - i) / fade
        data += struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


def main():
    os.makedirs(OUT, exist_ok=True)
    # Soft bubbly pop when a dot is picked up.
    save("pick", note(620, 0.09, decay=40, sweep=0.9, harmonics=(1.0, 0.2)))
    # Bright two-note chime when a pair connects.
    save("connect", mix((0, note(1046.5, 0.35, decay=9)), (0.07, note(1568, 0.4, decay=8, volume=0.45))))
    # Dull double thud when a line is blocked.
    save("blocked", mix((0, note(140, 0.12, decay=28, harmonics=(1.0, 0.6, 0.4, 0.3))), (0.09, note(110, 0.14, decay=26, harmonics=(1.0, 0.6, 0.4, 0.3)))))
    # Short click for buttons.
    save("tap", mix((0, note(1800, 0.04, decay=90, harmonics=(1.0,))), (0, noise(0.02, volume=0.15, decay=200))))
    # Little rewind blip for undo and reset.
    save("undo", note(900, 0.14, decay=18, sweep=-0.55, harmonics=(1.0, 0.25)))
    # Rising fanfare and sparkle for solving a level.
    melody = [(0.0, 523.25), (0.11, 659.25), (0.22, 783.99), (0.33, 1046.5)]
    tracks = [(t, note(f, 0.5, decay=5, volume=0.42)) for t, f in melody]
    tracks += [(0.44, note(1318.5, 0.9, decay=3.2, volume=0.38)), (0.44, note(1046.5, 0.9, decay=3.2, volume=0.3))]
    tracks += [(0.5 + k * 0.06, note(2093 * (1 + 0.12 * (k % 3)), 0.12, decay=30, volume=0.12, harmonics=(1.0,))) for k in range(8)]
    save("win", mix(*tracks))
    # Whoosh when the puzzle floats in.
    rng = random.Random(7)
    whoosh = []
    prev = 0.0
    n = int(0.35 * RATE)
    for i in range(n):
        t = i / n
        prev = prev * 0.92 + (rng.random() * 2 - 1) * 0.08
        whoosh.append(prev * math.sin(math.pi * t) * 1.6)
    save("whoosh", whoosh)
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
