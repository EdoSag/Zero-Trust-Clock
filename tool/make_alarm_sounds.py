#!/usr/bin/env python3
"""Makes the app's extra built-in alarm sounds (android/app/src/main/res/raw).

Every sound is synthesized here, so nothing is licensed from anyone. Each
one loops: it starts and ends in silence.

Needs numpy and ffmpeg (with libvorbis):
    python3 tool/make_alarm_sounds.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(
    os.path.dirname(__file__), "..", "android", "app", "src", "main", "res", "raw"
)


def silence(seconds):
    return np.zeros(int(RATE * seconds))


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def fade(x, seconds=0.005):
    n = min(int(RATE * seconds), len(x) // 2)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def place(total, at, x):
    start = int(RATE * at)
    end = min(len(total), start + len(x))
    total[start:end] += x[: end - start]


def bell(freq, seconds):
    """A struck bell: partials that are not whole multiples, each fading."""
    x = t(seconds)
    out = np.zeros(len(x))
    for ratio, level, decay in [
        (1.0, 1.0, 2.2),
        (2.0, 0.6, 3.0),
        (3.0, 0.35, 4.5),
        (4.2, 0.25, 6.0),
        (5.4, 0.15, 8.0),
    ]:
        out += level * np.sin(2 * np.pi * freq * ratio * x) * np.exp(-decay * x)
    return fade(out, 0.003)


def bells():
    total = silence(3.4)
    for i, freq in enumerate([659.25, 830.61, 987.77, 1318.51]):
        place(total, 0.02 + i * 0.34, bell(freq, 2.0))
    return total


def beep(freq, seconds):
    x = t(seconds)
    out = sum(
        np.sin(2 * np.pi * freq * k * x) / k for k in (1, 3, 5)
    )
    return fade(out, 0.004)


def beeps():
    total = silence(1.9)
    for i in range(4):
        place(total, 0.02 + i * 0.18, beep(1976.0, 0.09))
    return total


def marimba(freq, seconds):
    x = t(seconds)
    out = np.sin(2 * np.pi * freq * x) * np.exp(-5.0 * x)
    out += 0.3 * np.sin(2 * np.pi * freq * 4 * x) * np.exp(-14.0 * x)
    return fade(out, 0.004)


def sunrise():
    total = silence(5.0)
    notes = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
    for i, freq in enumerate(notes):
        place(total, 0.05 + i * 0.42, (0.55 + 0.09 * i) * marimba(freq, 1.6))
    return total


def buzz(freq, seconds):
    x = t(seconds)
    out = sum(np.sin(2 * np.pi * freq * k * x) / k for k in range(1, 9))
    return fade(out, 0.004)


def buzzer():
    total = silence(2.4)
    for i in range(8):
        place(total, 0.02 + i * 0.2, buzz(880.0 if i % 2 == 0 else 698.46, 0.19))
    return total


def write(name, samples):
    samples = samples / np.max(np.abs(samples)) * 0.89
    pcm = (samples * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error", "-i", path,
                "-c:a", "libvorbis", "-q:a", "3", "-map_metadata", "-1",
                "-fflags", "+bitexact", "-flags:a", "+bitexact",
                os.path.join(OUT, name + ".ogg"),
            ],
            check=True,
        )


if __name__ == "__main__":
    write("alarm_bells", bells())
    write("alarm_beeps", beeps())
    write("alarm_sunrise", sunrise())
    write("alarm_buzzer", buzzer())
