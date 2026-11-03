"""Sound refinement pass for Umbral Reaches.

    python3 tools/refine_sfx.py        # needs numpy + scipy

1. Synthesises 8 layered stone footsteps (art/audio/step_0..7.wav): heel thump, toe scuff a
   few ms later, sparse grit, and a short stone-room tail. The old steps were ~45 % energy above
   6 kHz (pure hiss, no body) at 22 kHz.
2. Masters every other sound from the untouched sources kept in tools/sfx_raw/ (copied there on
   the first run; .gdignore keeps Godot from importing them), so re-running is idempotent:
     - 44.1 kHz, DC removed (25 Hz high-pass)
     - de-clicked attacks (several files started at full amplitude -> a click on every play)
     - per-sound high cut to tame hiss (spit, slide, jump, die were 12-34 % above 6 kHz)
     - loudness matched per category (they spread ~10 dB), soft limiter at -1 dBFS
     - a shared short dark reverb so everything sits in the same night air
     - brazier_loop rebuilt as a seamless loop (it ended at 0.13 amplitude -> a click per loop)
"""
import os, shutil, wave
import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AUDIO = os.path.join(ROOT, "art", "audio")
RAW = os.path.join(ROOT, "tools", "sfx_raw")
rng = np.random.default_rng(2026)

# name: (target RMS dBFS, high cut Hz or None, reverb wet 0..1, attack ms)
SPEC = {
    "bolt_cast":     (-17.0, 9000, 0.10, 2.0),
    "bolt_impact":   (-16.0, 10000, 0.16, 1.0),
    "enemy_die":     (-18.0, 7000, 0.20, 3.0),
    "hurt":          (-16.0, 8000, 0.12, 2.0),
    "jump_air":      (-20.0, 7000, 0.08, 3.0),
    "lance_charge":  (-19.0, 9000, 0.12, 4.0),
    "lance_fire":    (-14.0, 9500, 0.16, 1.5),
    "lance_impact":  (-14.5, 9000, 0.24, 1.0),
    "mark_tick":     (-21.0, 9000, 0.14, 1.0),
    "nova_boom":     (-14.0, 9000, 0.26, 1.5),
    "pounce_shriek": (-17.0, 8000, 0.18, 3.0),
    "shade_whisper": (-19.0, 6000, 0.30, 20.0),
    "slide_scrape":  (-21.0, 5500, 0.05, 15.0),
    "spit":          (-19.0, 6000, 0.12, 2.0),
    "step_blink":    (-17.0, 8500, 0.20, 2.0),
    "ward_chime":    (-17.0, 11000, 0.30, 1.5),
}


# --- io ---------------------------------------------------------------------------------------

def load(path):
    with wave.open(path) as w:
        sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0 if sw == 2 else (np.frombuffer(raw, dtype=np.uint8) - 128.0) / 128.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)
    if sr != SR:
        g = np.gcd(sr, SR)
        x = signal.resample_poly(x, SR // g, sr // g)
    return x


def save(name, x):
    x = np.clip(x, -1.0, 1.0)
    with wave.open(os.path.join(AUDIO, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    print(f"  {name:16s} {len(x) / SR:5.2f}s  rms {rms:6.1f} dB  peak {np.abs(x).max():.2f}")


# --- dsp ----------------------------------------------------------------------------------------

def hp(x, f, order=2):
    return signal.sosfiltfilt(signal.butter(order, f, "highpass", fs=SR, output="sos"), x)


def lp(x, f, order=2):
    return signal.sosfiltfilt(signal.butter(order, f, "lowpass", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=2):
    return signal.sosfiltfilt(signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos"), x)


def fade_in(x, ms):
    n = min(len(x), max(1, int(SR * ms / 1000)))
    x = x.copy()
    x[:n] *= np.sin(np.linspace(0, np.pi / 2, n)) ** 2
    return x


def fade_out(x, ms):
    n = min(len(x), max(1, int(SR * ms / 1000)))
    x = x.copy()
    x[-n:] *= np.cos(np.linspace(0, np.pi / 2, n)) ** 2
    return x


def limit(x, ceiling=0.89):
    """Soft knee: transparent below ~-3 dB, tanh-rounded above, never past the ceiling."""
    k = 0.7
    y = np.where(np.abs(x) < k, x, np.sign(x) * (k + (1 - k) * np.tanh((np.abs(x) - k) / (1 - k))))
    return y * ceiling


def to_rms(x, db):
    r = np.sqrt(np.mean(x ** 2)) + 1e-12
    return x * (10 ** (db / 20) / r)


_ir = None


def reverb(x, wet, tail=0.9):
    """Short dark stone-room tail: convolution with decaying, low-passed noise (cached IR)."""
    global _ir
    if _ir is None:
        n = int(SR * tail)
        tt = np.arange(n) / SR
        ir = rng.standard_normal(n) * np.exp(-tt * 6.5)
        ir = lp(ir, 3800) + lp(ir, 900) * 0.6
        ir[: int(SR * 0.012)] = 0.0                    # pre-delay
        _ir = ir / np.sqrt(np.sum(ir ** 2))
    if wet <= 0:
        return x
    y = signal.fftconvolve(np.concatenate([x, np.zeros(len(_ir))]), _ir)[: len(x) + len(_ir)]
    dry = np.concatenate([x, np.zeros(len(_ir))])
    out = dry * (1 - wet * 0.5) + y * wet * 0.55
    # trim the silent end of the tail
    env = np.abs(out)
    keep = np.nonzero(env > 10 ** (-60 / 20) * env.max())[0]
    end = keep[-1] + 1 if len(keep) else len(out)
    return fade_out(out[: max(end, len(x))], 30)


# --- footsteps ----------------------------------------------------------------------------------

def footstep(seed):
    """Boot on worn stone: heel (thump + body), toe a few ms later, grit, short room."""
    r = np.random.default_rng(seed)
    n = int(SR * 0.26)
    tt = np.arange(n) / SR
    out = np.zeros(n)
    # heel: a damped low thump with a little pitch drop, and a mid "body" knock
    f0 = r.uniform(78, 104)
    thump = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.35 * np.exp(-tt * 60))) / SR) * np.exp(-tt * r.uniform(38, 50))
    knock = bp(r.standard_normal(n), r.uniform(320, 420), r.uniform(1100, 1500)) * np.exp(-tt * r.uniform(70, 95))
    out += thump * 0.9 + knock * 0.55
    # toe: offset, softer, a touch brighter (leather on stone)
    off = int(SR * r.uniform(0.028, 0.048))
    toe_n = n - off
    tt2 = np.arange(toe_n) / SR
    toe = bp(r.standard_normal(toe_n), r.uniform(600, 800), r.uniform(2400, 3200)) * np.exp(-tt2 * r.uniform(90, 120))
    out[off:] += toe * r.uniform(0.28, 0.4)
    # grit: sparse crackles under the sole, band-limited so they never hiss
    grit = np.zeros(n)
    for _ in range(r.integers(6, 12)):
        i = r.integers(int(SR * 0.004), int(SR * 0.09))
        grit[i] += r.uniform(-1, 1)
    grit = bp(grit, 1500, 4500) * np.exp(-tt * 30)
    out += grit * r.uniform(0.6, 1.0)
    out = hp(out, 45)
    out = fade_in(out, 1.0)
    out = reverb(out, 0.12, tail=0.45)
    out = to_rms(out[: int(SR * 0.4)], -21.0)
    return fade_out(limit(out), 25)


# --- brazier loop -------------------------------------------------------------------------------

def seamless_loop(x, xfade_s=0.18):
    """Equal-power crossfade of the tail into the head so sample end == sample start."""
    n = int(SR * xfade_s)
    head, tail = x[:n], x[-n:]
    a = np.linspace(0, np.pi / 2, n)
    blended = tail * np.cos(a) + head * np.sin(a)
    return np.concatenate([x[n:-n], blended])


# --- ambience beds (seamless 20 s loops) ------------------------------------------------------

def amb_night(sec=20.0):
    """Open-air night on the ridge: wind with slow gusts, a faint low drone under it."""
    n = int(SR * sec)
    tt = np.arange(n) / SR
    r = np.random.default_rng(31)
    gust = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * tt / sec * 3 + 1.0)) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / sec * 7 + 2.0))
    wind = bp(r.standard_normal(n), 140, 900) * gust + bp(r.standard_normal(n), 900, 2600) * gust ** 3 * 0.25
    drone = sum(np.sin(2 * np.pi * f * tt + ph) * a for f, ph, a in [(41.0, 0.0, 0.5), (61.5, 1.3, 0.3), (82.2, 2.1, 0.15)])
    drone *= 0.6 + 0.4 * np.sin(2 * np.pi * tt / sec * 2)
    x = wind + drone * 0.06
    x = seamless_loop(hp(x, 30), 2.0)
    return limit(to_rms(x, -24.0))


def amb_ossuary(sec=20.0):
    """Crypt: a dark beating drone, breath-like air, sparse drips and bone ticks, long reverb."""
    n = int(SR * sec)
    tt = np.arange(n) / SR
    r = np.random.default_rng(57)
    drone = np.zeros(n)
    for f, a in [(55.0, 0.5), (55.4, 0.5), (82.4, 0.3), (110.3, 0.18), (164.8, 0.07)]:
        drone += np.sin(2 * np.pi * f * tt + r.uniform(0, 6)) * a
    drone *= 0.75 + 0.25 * np.sin(2 * np.pi * tt / sec * 4)
    breath = bp(r.standard_normal(n), 200, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * tt / sec * 5)) ** 2
    events = np.zeros(n)
    for _ in range(14):
        i = r.integers(int(SR * 0.5), n - int(SR * 0.5))
        k = np.arange(int(SR * 0.08)) / SR
        if r.random() < 0.5:     # water drip: short falling ping
            ping = np.sin(2 * np.pi * np.cumsum(np.geomspace(1900, 900, len(k))) / SR) * np.exp(-k * 60)
        else:                    # bone tick: dry click
            ping = bp(r.standard_normal(len(k)), 1200, 3500) * np.exp(-k * 120)
        events[i:i + len(k)] += ping * r.uniform(0.15, 0.4)
    x = drone * 0.35 + breath * 0.5 + events
    x = reverb(hp(x, 28), 0.5, tail=1.2)[:n]
    x = seamless_loop(x, 2.0)
    return limit(to_rms(x, -23.0))


# --- main ---------------------------------------------------------------------------------------

def main():
    os.makedirs(RAW, exist_ok=True)
    open(os.path.join(RAW, ".gdignore"), "w").close()
    for f in os.listdir(AUDIO):
        generated = f.startswith("step_") and f[5:-4].isdigit()      # the footsteps are synthesised here
        if f.endswith(".wav") and not os.path.exists(os.path.join(RAW, f)) and not generated:
            shutil.copy2(os.path.join(AUDIO, f), os.path.join(RAW, f))
    print("footsteps")
    for i in range(8):
        save(f"step_{i}", footstep(100 + i * 17))
    print("mastered")
    for name, (db, cut, wet, atk) in SPEC.items():
        src = os.path.join(RAW, name + ".wav")
        if not os.path.exists(src):
            print("  missing", name)
            continue
        x = load(src)
        x = x - np.mean(x)
        x = hp(x, 25)
        if cut:
            x = lp(x, cut)
        x = fade_in(x, atk)
        x = reverb(x, wet)
        x = to_rms(x, db)
        save(name, fade_out(limit(x), 20))
    print("ambience")
    save("amb_night", amb_night())
    save("amb_ossuary", amb_ossuary())
    # brazier crackle loop: clean, darker, seamless
    src = os.path.join(RAW, "brazier_loop.wav")
    if os.path.exists(src):
        x = load(src)
        x = hp(x - np.mean(x), 40)
        x = lp(x, 5500)
        x = seamless_loop(x)
        x = to_rms(x, -22.0)
        x = limit(x)
        save("brazier_loop", x)
        print(f"  loop seam |end-start| = {abs(x[-1] - x[0]):.4f}")


if __name__ == "__main__":
    main()
