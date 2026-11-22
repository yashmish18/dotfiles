#!/usr/bin/env python3
"""the shell's sounds, synthesised from scratch (no samples, no licences to worry about).

    python3 make.py        writes the .wav files next to this script

small and soft on purpose: 22 khz mono, a few dozen kb each, peaking around -10 dbfs.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
HERE = Path(__file__).resolve().parent


def write(name: str, samples: list[float], gain: float = 0.32) -> None:
    peak = max(1e-9, max(abs(x) for x in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, x / peak * gain)) * 32767)) for x in samples)
    with wave.open(str(HERE / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def silence(sec: float) -> list[float]:
    return [0.0] * int(sec * RATE)


def bell(freq: float, sec: float, decay: float, partials=((1, 1.0), (2, 0.28), (3.01, 0.08)), drop: float = 0.0) -> list[float]:
    """a soft struck tone: a few partials, a quick attack, an exponential tail."""
    n = int(sec * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        f = freq * (1 - drop * min(1.0, t / sec))
        env = min(1.0, t / 0.004) * math.exp(-t / decay)
        out.append(env * sum(a * math.sin(2 * math.pi * f * k * t) for k, a in partials))
    return out


def mix(*tracks) -> list[float]:
    """(offset seconds, samples) pairs, summed."""
    end = max(int(o * RATE) + len(s) for o, s in tracks)
    out = [0.0] * end
    for o, s in tracks:
        start = int(o * RATE)
        for i, x in enumerate(s):
            out[start + i] += x
    return out


def noise(sec: float, shape, seed: int = 7, smooth: float = 0.0) -> list[float]:
    """filtered noise: `shape(t)` is the loudness over time, `smooth` a one-pole low-pass."""
    rnd = random.Random(seed)
    n = int(sec * RATE)
    out, y = [], 0.0
    for i in range(n):
        x = rnd.uniform(-1, 1)
        y = y + (x - y) * (1 - smooth)
        out.append(y * shape(i / RATE))
    return out


# volume: a tiny wooden tick
write("tick.wav", bell(1480, 0.06, 0.012, ((1, 1.0), (2.4, 0.2)), drop=0.08), gain=0.22)
# notification: two notes up, like a soft glass
write("notify.wav", mix((0, bell(784, 0.5, 0.16)), (0.09, bell(1175, 0.6, 0.2))), gain=0.3)
# lock: two notes down; unlock: three up
write("lock.wav", mix((0, bell(1046, 0.4, 0.12)), (0.08, bell(698, 0.5, 0.16))), gain=0.28)
write("unlock.wav", mix((0, bell(698, 0.35, 0.1)), (0.07, bell(880, 0.35, 0.1)), (0.14, bell(1175, 0.55, 0.18))), gain=0.3)
# wrong password: a low, short double thud
write("error.wav", mix((0, bell(220, 0.22, 0.06, ((1, 1.0), (2, 0.4)))), (0.12, bell(196, 0.26, 0.07, ((1, 1.0), (2, 0.4))))), gain=0.32)
# charger in: a little rising blip
write("plug.wav", mix((0, bell(523, 0.25, 0.07)), (0.06, bell(784, 0.35, 0.1))), gain=0.26)
# screenshot: a dry click and a breath of noise
write("shutter.wav", mix((0, noise(0.05, lambda t: math.exp(-t / 0.008), smooth=0.2)),
                         (0.05, noise(0.07, lambda t: math.exp(-t / 0.015), seed=3, smooth=0.35))), gain=0.3)
# wallpaper: ink spreading, a soft rising-then-falling hush
write("swoosh.wav", noise(0.9, lambda t: math.sin(math.pi * min(1, t / 0.9)) ** 2, seed=11, smooth=0.93), gain=0.2)
print("sounds written to", HERE)
