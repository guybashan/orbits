#!/usr/bin/env python3
"""
Synthesise the Orbits audio set.

Everything is generated: plucks are Karplus-Strong, pads are detuned stacks,
and a small FFT convolution reverb glues the whole set into one space so the
effects sound like they belong in the same room as the music.
"""
import math
import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path("/Users/columbo/dev/godot-orbits/sounds")

# ---------------------------------------------------------------- helpers --


def t(dur, sr=SR):
    return np.arange(int(sr * dur)) / sr


def env_ad(n, attack, decay, sr=SR):
    a = max(1, int(attack * sr))
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a)
    e[a:] = np.exp(-np.arange(n - a) / sr / decay)
    return e


def env_adsr(n, attack, decay, sustain, release, sr=SR):
    a, d, r = int(attack * sr), int(decay * sr), int(release * sr)
    a, d, r = max(a, 1), max(d, 1), max(r, 1)
    s = max(n - a - d - r, 0)
    return np.concatenate([
        np.linspace(0.0, 1.0, a),
        np.linspace(1.0, sustain, d),
        np.full(s, sustain),
        np.linspace(sustain, 0.0, r),
    ])[:n]


def soft_clip(x, amount=1.3):
    return np.tanh(x * amount) / math.tanh(amount)


def add_at(track, sample, start):
    """Mix `sample` into `track` at sample offset `start`, clipping to length."""
    if start >= len(track):
        return
    end = min(start + len(sample), len(track))
    track[start:end] += sample[: end - start]


def lowpass(x, cutoff, sr=SR):
    """One-pole lowpass, applied as a stable IIR via cumulative decay."""
    alpha = math.exp(-2.0 * math.pi * cutoff / sr)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = v * (1.0 - alpha) + acc * alpha
        out[i] = acc
    return out


# ------------------------------------------------------------------ reverb --


def reverb_ir(dur=1.4, decay=4.5, sr=SR, seed=99):
    """Exponentially decaying noise: a cheap but convincing plate."""
    rng = np.random.default_rng(seed)
    n = int(sr * dur)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / sr * decay)
    # Roll off the top so it reads as air rather than hiss.
    ir = np.convolve(ir, np.hanning(48) / np.hanning(48).sum(), mode="same")
    ir[0] += 1.0  # keep the dry transient intact
    return ir / np.abs(ir).max()


_IR = None


def reverb(x, mix=0.25, dur=1.4, decay=4.5):
    global _IR
    if _IR is None or len(_IR) != int(SR * dur):
        _IR = reverb_ir(dur, decay)
    n = len(x) + len(_IR) - 1
    size = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(_IR, size), size)[: len(x)]
    peak = np.abs(wet).max()
    if peak > 0:
        wet = wet / peak * np.abs(x).max()
    return x * (1.0 - mix) + wet * mix


# ------------------------------------------------------------------ voices --


def pluck(freq, dur, damping=0.9955, seed=0, brightness=0.5, sr=SR):
    """Karplus-Strong string. Gives the arpeggio a real body sines can't."""
    n = int(sr * dur)
    period = max(int(sr / freq), 2)
    rng = np.random.default_rng(seed)
    buf = rng.uniform(-1.0, 1.0, period)
    # Pre-darken the excitation for a rounder, less zingy attack.
    buf = buf * brightness + np.roll(buf, 1) * (1.0 - brightness)

    out = np.empty(n)
    idx = 0
    for i in range(n):
        current = buf[idx]
        nxt = buf[(idx + 1) % period]
        out[i] = current
        buf[idx] = damping * 0.5 * (current + nxt)
        idx = (idx + 1) % period
    return out * env_ad(n, 0.001, dur * 0.6)


def pad(freqs, dur, detune=0.004, sr=SR):
    """Warm sustained stack — two slightly detuned sines per note."""
    n = int(sr * dur)
    tt = t(dur, sr)
    out = np.zeros(n)
    for i, f in enumerate(freqs):
        out += np.sin(2 * math.pi * f * tt)
        out += np.sin(2 * math.pi * f * (1.0 + detune) * tt) * 0.8
        # A touch of the octave keeps it from muddying in the low mids.
        out += np.sin(2 * math.pi * f * 2 * tt) * 0.12
    out /= max(len(freqs), 1) * 2.0
    # Gentle swell, long plateau, tail that runs past the bar so the next
    # chord crossfades in rather than the loop breathing once per bar.
    return out * env_adsr(n, dur * 0.16, dur * 0.10, 0.86, dur * 0.30)


def sub(freq, dur, sr=SR):
    n = int(sr * dur)
    tt = t(dur, sr)
    tone = np.sin(2 * math.pi * freq * tt) + 0.22 * np.sin(2 * math.pi * freq * 2 * tt)
    return tone * env_adsr(n, 0.015, 0.08, 0.90, dur * 0.22)


def bell(freq, dur, sr=SR):
    """Inharmonic partials — the shimmer that makes a chime read as magic."""
    n = int(sr * dur)
    tt = t(dur, sr)
    out = np.zeros(n)
    for mult, amp, dec in ((1.0, 1.00, 0.55), (2.76, 0.45, 0.28),
                           (5.40, 0.22, 0.16), (8.93, 0.10, 0.09)):
        out += amp * np.sin(2 * math.pi * freq * mult * tt) * env_ad(n, 0.001, dec * dur)
    return out / 1.8


def kick(dur=0.34, sr=SR):
    n = int(sr * dur)
    tt = t(dur, sr)
    sweep = 110.0 * np.exp(-tt * 26.0) + 44.0
    phase = 2 * math.pi * np.cumsum(sweep) / sr
    return np.sin(phase) * env_ad(n, 0.001, 0.085)


def shaker(dur=0.09, seed=0, sr=SR):
    n = int(sr * dur)
    rng = np.random.default_rng(seed)
    noise = rng.normal(0, 1, n)
    # Bandpass-ish: subtract a smoothed copy to keep only the top end.
    smooth = np.convolve(noise, np.hanning(12) / np.hanning(12).sum(), mode="same")
    # Darker than a raw noise burst: keeps the mix from going hissy.
    return (noise - smooth * 0.72) * env_ad(n, 0.001, 0.014) * 0.55


# -------------------------------------------------------------------- sfx --


def make_move():
    """Fires on every move: short, pitched, and completely un-fatiguing."""
    body = pluck(660.0, 0.13, damping=0.986, seed=3, brightness=0.35)
    click = np.zeros(len(body))
    click[:40] = np.linspace(1.0, 0.0, 40) * 0.35
    out = body * 0.75 + click
    return soft_clip(reverb(out, mix=0.14) * 0.85)


def make_bounce():
    """Blocked move: muted and low, discouraging without being harsh."""
    n = int(SR * 0.18)
    tt = t(0.18)
    sweep = 190.0 * np.exp(-tt * 30.0) + 96.0
    phase = 2 * math.pi * np.cumsum(sweep) / SR
    body = np.sin(phase) * env_ad(n, 0.002, 0.032)
    return soft_clip((body * 0.85 + shaker(0.18, seed=5) * 0.10) * 0.8)


def glass(freq, dur, sr=SR):
    """
    A soft glass/vibraphone tone: near-harmonic partials, gentle attack.

    Deliberately *not* the inharmonic `bell` used for stars and wins — those
    ratios (2.76, 5.40, 8.93) read as metallic, which is fine once at the end
    of a level but fatiguing on a sound that fires twenty times a board.
    """
    n = int(sr * dur)
    tt = t(dur, sr)
    out = np.zeros(n)
    for mult, amp, dec in ((1.00, 1.00, 0.40), (2.00, 0.32, 0.16),
                           (3.00, 0.11, 0.09), (4.01, 0.05, 0.05)):
        # 6ms attack rather than 1ms: takes the "tick" off the front.
        out += amp * np.sin(2 * math.pi * freq * mult * tt) * env_ad(n, 0.006, dec * dur)
    # A quiet sub-octave gives it body so it does not sound thin on a phone.
    out += 0.18 * np.sin(2 * math.pi * freq * 0.5 * tt) * env_ad(n, 0.008, 0.18 * dur)
    return out / 1.55


def make_lock():
    """
    A ball reaching its socket — the most-heard sound in the game.

    Warm rather than bright: A5 fundamental instead of the old E6 bell, which
    was piercing after a few placements. Playback pitches this up a pentatonic
    ladder for consecutive placements (see Audio.play_lock), so a run of
    correct moves turns into a phrase.
    """
    out = np.zeros(int(SR * 0.55))
    add_at(out, glass(880.00, 0.55) * 0.85, 0)                     # A5
    add_at(out, glass(1318.51, 0.34) * 0.22, int(0.012 * SR))      # E6, a touch late
    return soft_clip(reverb(out, mix=0.26) * 0.82)


def make_ui():
    out = pluck(880.0, 0.09, damping=0.982, seed=7, brightness=0.3) * 0.8
    return soft_clip(reverb(out, mix=0.12))


def make_star():
    """One per star. Pitch-shifted per star at playback for a rising run."""
    n = int(SR * 0.6)
    out = np.zeros(n)
    add_at(out, bell(1567.98, 0.6) * 0.7, 0)
    tt = t(0.6)
    sparkle = np.sin(2 * math.pi * (2600 + 1500 * tt / tt[-1]) * tt)
    add_at(out, sparkle * env_ad(len(tt), 0.004, 0.10) * 0.22, 0)
    return soft_clip(reverb(out, mix=0.36) * 0.9)


def make_win():
    """Fanfare: rising bell arpeggio over a swelling major chord."""
    dur = 2.6
    n = int(SR * dur)
    out = np.zeros(n)

    # C major triumph: C4 E4 G4 C5 E5, each entering a beat apart.
    arp = [(523.25, 0.00), (659.25, 0.11), (783.99, 0.22),
           (1046.50, 0.33), (1318.51, 0.44)]
    for freq, start in arp:
        add_at(out, bell(freq, dur - start) * 0.42, int(start * SR))

    add_at(out, pad([261.63, 329.63, 392.00, 523.25], 2.3) * 0.55, int(0.05 * SR))
    add_at(out, sub(130.81, 2.2) * 0.5, 0)
    add_at(out, bell(2093.00, 1.2) * 0.18, int(0.55 * SR))

    return soft_clip(reverb(out, mix=0.32) * 0.72)


# ------------------------------------------------------------------ music --

BPM = 84.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
BARS = 8

# i - VI - III - VII in A minor: warm, resolved, and happy to loop forever.
PROGRESSION = [
    {"sub": 110.00, "pad": [220.00, 261.63, 329.63, 493.88], "arp": [220.00, 261.63, 329.63, 493.88]},  # Am9
    {"sub": 87.31,  "pad": [174.61, 220.00, 261.63, 392.00], "arp": [174.61, 220.00, 261.63, 392.00]},  # Fmaj9
    {"sub": 130.81, "pad": [196.00, 261.63, 329.63, 392.00], "arp": [196.00, 261.63, 329.63, 392.00]},  # Cmaj
    {"sub": 98.00,  "pad": [196.00, 246.94, 293.66, 392.00], "arp": [196.00, 246.94, 293.66, 392.00]},  # G
]


def make_music():
    total = BAR * BARS
    n = int(SR * total)
    track = np.zeros(n + SR)  # headroom for tails, trimmed at the end

    seed = 0
    for bar in range(BARS):
        chord = PROGRESSION[(bar // 2) % len(PROGRESSION)]
        bar_start = int(bar * BAR * SR)

        add_at(track, sub(chord["sub"], BAR * 1.30) * 0.30, bar_start)
        add_at(track, pad(chord["pad"], BAR * 1.90) * 0.15, bar_start)

        # Eighth-note arpeggio, up then down, one octave up from the pad.
        shape = [0, 1, 2, 3, 2, 1, 2, 3]
        for step, degree in enumerate(shape):
            seed += 1
            freq = chord["arp"][degree] * 2.0
            when = bar_start + int(step * (BEAT / 2) * SR)
            accent = 0.115 if step % 2 == 0 else 0.075
            add_at(track, pluck(freq, 0.85, damping=0.9945, seed=seed) * accent, when)

        # A single high bell every other bar, for movement over the loop.
        if bar % 2 == 1:
            note = chord["arp"][3] * 2.0
            add_at(track, bell(note, 1.8) * 0.055, bar_start + int(BEAT * 2.5 * SR))

        # Soft pulse: kick on 1 and 3, shaker on the off-beats.
        for beat in (0, 2):
            add_at(track, kick() * 0.30, bar_start + int(beat * BEAT * SR))
        for eighth in range(8):
            if eighth % 2 == 1:
                seed += 1
                add_at(track, shaker(seed=seed) * 0.018,
                       bar_start + int(eighth * (BEAT / 2) * SR))

    track = reverb(track, mix=0.22, dur=1.8, decay=3.2)
    track = soft_clip(track * 1.05, 1.15)

    # Wrap the tail that spilled past the loop point back over the head, so the
    # reverb and ringing plucks carry across the seam instead of cutting dead.
    tail = track[n:]
    track = track[:n]
    track[: len(tail)] += tail
    return track * 0.9


# ------------------------------------------------------------------- write --


def write_wav(name, samples, sr=SR):
    peak = np.abs(samples).max()
    if peak > 0.999:
        samples = samples / peak * 0.999
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2")
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    print(f"  {name:<12} {len(samples)/sr:6.2f}s  {path.stat().st_size/1024:7.1f} KB")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    print("sfx:")
    write_wav("move.wav", make_move())
    write_wav("bounce.wav", make_bounce())
    write_wav("lock.wav", make_lock())
    write_wav("ui.wav", make_ui())
    write_wav("star.wav", make_star())
    write_wav("win.wav", make_win())
    print("music:")
    write_wav("music.wav", make_music())
