"""Layered creature, impact and combat sounds for Umbral Reaches (numpy only, deterministic, all in-house).

    BLENDER_PY=/Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13   # any python with numpy
    $BLENDER_PY tools/gen_enemy_sfx.py                    # everything -> art/audio/{enemy,kit,player}/ + core/vfx/enemy_bank.gd
    $BLENDER_PY tools/gen_enemy_sfx.py --only hollow      # one voice set (or: steps, kit, player)
    $BLENDER_PY tools/gen_enemy_sfx.py --reel /path/reel.wav [--no-write]   # a listening reel, every family back to back

Nothing is sampled: each sound is built in layers from noise, glottal pulse trains with jitter and
subharmonics run through moving formant filters (vocal tracts), FM blips, damped resonators and swept noise.
  body   a low sub / chest layer for weight
  voice  the mid layer: formant-filtered vocal tract or breath, with the family's texture on top
         (wet throat clicks, bone rattles, chitin ticks, airy hiss, metal rings, ember crackle, wood creak)
  attack a transient (click, swipe, slam, spit, pounce)
  tail   a short synthetic-room reverb (bosses: long)
Rendered at 44.1 kHz mono 16-bit, RMS-matched per act, soft-limited under -1 dBFS, short fades, no DC.
core/vfx/enemy_bank.gd (generated) lists how many takes of every sound exist; core/vfx/enemy_audio.gd plays them.
"""
import os, sys, wave, zlib
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
AUDIO = os.path.join(ROOT, "art", "audio")
CEIL = 0.89            # -1 dBFS


def R(*key):
    return np.random.default_rng(zlib.crc32("|".join(str(k) for k in key).encode()))


# ---------------------------------------------------------------------------------------------------
# DSP basics
# ---------------------------------------------------------------------------------------------------

def N(sec):
    return max(int(round(sec * SR)), 1)


def tt(n):
    return np.arange(n) / SR


def smooth(x, win):
    win = int(win)
    if win < 2:
        return x
    pad = np.pad(x, (win // 2, win - win // 2 - 1), mode="edge")
    return np.convolve(pad, np.ones(win) / win, mode="valid")


def curve(pts, n, sm=0.02):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    c = np.interp(np.linspace(0, 1, n), xs, ys)
    return smooth(c, max(sm * n, 3))


def snoise(r, n, hz):
    m = int(n / SR * hz) + 4
    return np.interp(np.arange(n) / SR * hz, np.arange(m), r.normal(size=m))


def rms(x):
    return float(np.sqrt(np.mean(x * x))) + 1e-12


def lv(x, g=1.0):
    """Scale to unit RMS over its loud part, times g."""
    a = np.abs(x)
    m = a > a.max() * 0.05 if a.max() > 0 else np.ones_like(a, bool)
    return x / (rms(x[m]) if m.any() else 1.0) * g


def _spec(x):
    n = 1
    while n < len(x):
        n *= 2
    return np.fft.rfft(x, n), np.fft.rfftfreq(n, 1 / SR), n


def lp(x, fc, order=2):
    if np.ndim(fc) > 0:
        return svf(x, fc, 0.7, "lp")
    X, f, n = _spec(x)
    X *= 1 / np.sqrt(1 + (f / fc) ** (2 * order))
    return np.fft.irfft(X, n)[: len(x)]


def hp(x, fc, order=2):
    X, f, n = _spec(x)
    X *= 1 / np.sqrt(1 + (fc / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(X, n)[: len(x)]


def bp(x, lo, hi, order=2):
    return hp(lp(x, hi, order), lo, order)


def svf(x, fc, q=3.0, mode="bp"):
    """Time-varying state-variable filter (TPT form). bp is unity peak gain."""
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, float), (n,))
    q = np.broadcast_to(np.asarray(q, float), (n,))
    g = np.tan(np.pi * np.clip(fc, 20.0, SR * 0.45) / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1 = ic2 = 0.0
    b = [0.0] * n
    l = [0.0] * n
    for i, (xi, c1, c2, c3) in enumerate(zip(x.tolist(), a1.tolist(), a2.tolist(), a3.tolist())):
        v3 = xi - ic2
        v1 = c1 * ic1 + c2 * v3
        v2 = ic2 + c2 * ic1 + c3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        b[i] = v1
        l[i] = v2
    b = np.array(b)
    l = np.array(l)
    if mode == "bp":
        return b * k
    if mode == "lp":
        return l
    return x - k * b - l


def expo(n, tau, a=0.002):
    t = tt(n)
    return np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t / tau)


def add(out, ev, at, g=1.0):
    i = int(at * SR)
    if i < 0 or i >= len(out):
        return
    j = min(len(out), i + len(ev))
    out[i:j] += ev[: j - i] * g


def delay(x, sec):
    return np.concatenate([np.zeros(N(sec)), x])


def fit(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


_irs = {}


def reverb(x, rt60, wet, damp=0.5, pre=0.012):
    key = (rt60, damp)
    if key not in _irs:
        r = np.random.default_rng(int(rt60 * 1000 + damp * 100))
        n = int(rt60 * SR * 1.05)
        t = tt(n)
        h = r.normal(size=n) * np.exp(-6.9 * t / rt60)
        h = lp(h, 9000.0 * (1.0 - damp) + 1800.0)
        h[: int(0.003 * SR)] *= np.linspace(0, 1, int(0.003 * SR))
        _irs[key] = h / np.sqrt(np.sum(h * h))
    h = _irs[key]
    total = len(x) + len(h) + N(pre)
    n = 1
    while n < total:
        n *= 2
    tail = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(h, n), n)[:total]
    out = np.zeros(total)
    out[: len(x)] += x
    out[N(pre): N(pre) + len(tail) - N(pre)] += tail[: len(tail) - N(pre)] * wet * 0.55
    return out


def softclip(x, ceil=CEIL, knee=0.6):
    a = np.abs(x)
    over = a > knee
    y = x.copy()
    y[over] = np.sign(x[over]) * (knee + (ceil - knee) * np.tanh((a[over] - knee) / (ceil - knee)))
    return y


def finish(x, db, fade=0.025, trim=True, fade_in=0.002):
    """DC/sub removal, trim the dead tail, short fades, RMS match, soft limit under -1 dBFS."""
    x = hp(x, 24.0)
    if trim:
        a = np.abs(x)
        idx = np.nonzero(a > a.max() * 0.015)[0]
        if len(idx):
            x = x[: min(len(x), idx[-1] + N(0.03))]
    gain = 10 ** (db / 20.0) / rms(x[np.abs(x) > np.abs(x).max() * 0.04])
    x = softclip(x * gain)
    f = min(len(x) // 2, N(fade))
    x[-f:] *= np.cos(np.linspace(0, np.pi / 2, f)) ** 2
    fi = min(len(x) // 4, N(fade_in))
    x[:fi] *= np.linspace(0, 1, fi)
    pk = np.abs(x).max()
    if pk > CEIL:
        x *= CEIL / pk
    return x


# ---------------------------------------------------------------------------------------------------
# Events: small building blocks placed on a timeline
# ---------------------------------------------------------------------------------------------------

def thump(f0, f1, tau, dur=None, g=1.0):
    n = N(dur or tau * 5)
    f = np.geomspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * expo(n, tau, 0.003) * g


def ring(freqs, decays, dur, amps=None, r=None):
    n = N(dur)
    t = tt(n)
    out = np.zeros(n)
    for i, (f, d) in enumerate(zip(freqs, decays)):
        out += np.sin(2 * np.pi * f * t + (r.uniform(0, 6.28) if r is not None else 0)) * np.exp(-t * d) * (amps[i] if amps else 1.0)
    return out


def bone_clack(r, f=None, g=1.0):
    f = f or r.uniform(900, 2600)
    n = N(0.05)
    t = tt(n)
    body = np.sin(2 * np.pi * f * t) * np.exp(-t * r.uniform(90, 180)) + 0.6 * np.sin(2 * np.pi * f * r.uniform(1.9, 2.8) * t) * np.exp(-t * r.uniform(140, 260))
    click = bp(r.normal(size=n), 1800, 7000) * np.exp(-t * 700) * 1.2
    return (body * 0.8 + click) * g


def chit_tick(r, g=1.0):
    n = N(0.014)
    t = tt(n)
    f = r.uniform(3200, 6800)
    return (np.sin(2 * np.pi * f * t) * np.exp(-t * r.uniform(600, 1100)) + 0.5 * r.normal(size=n) * np.exp(-t * 1500)) * g


def wet_click(r, g=1.0):
    n = N(0.035)
    t = tt(n)
    f = np.geomspace(r.uniform(900, 1700), r.uniform(180, 320), n)
    blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * r.uniform(160, 260))
    sq = lp(r.normal(size=n), 1600) * np.exp(-t * 110) * 0.7
    return (blip + sq) * g


def grit(r, n, dens=900, f=(1500, 5500)):
    """Sparse tiny clicks: bone dust, shale, dry throat."""
    m = (r.random(n) < dens / SR).astype(float) * r.uniform(-1, 1, n)
    return bp(m, f[0], f[1]) * 3.0


def whoosh(dur, f0, f1, r, q=1.6, g=1.0, peak=0.5):
    n = N(dur)
    sweep = np.geomspace(f0, f1, n)
    x = svf(r.normal(size=n), sweep, q, "bp")
    t = np.linspace(0, 1, n)
    e = np.where(t < peak, (t / peak) ** 1.6, ((1 - t) / (1 - peak)) ** 1.4)
    return x * e * g


def breath(r, dur, kind="out", f=(350, 3000), g=1.0):
    n = N(dur)
    t = np.linspace(0, 1, n)
    nz = r.normal(size=n)
    mid = svf(nz, curve([(0, f[0] * 1.5), (1, f[0] * 2.6)], n), 1.4, "bp") + 0.6 * svf(nz, f[1] * 0.5, 1.2, "bp")
    e = np.sin(np.pi * t) ** (1.2 if kind == "out" else 2.0)
    if kind == "in":
        e = t ** 1.5 * (1 - t) ** 0.6 * 2.0
    return mid * e * g * (1 + 0.25 * snoise(r, n, 14))


def crackle(r, n, rate, fc=(900, 6000), g=1.0, tau=0.004):
    out = np.zeros(n)
    for at in np.sort(r.random(int(rate * n / SR)) * n / SR):
        m = N(tau * 6)
        e = bp(r.normal(size=m), fc[0], fc[1]) * np.exp(-tt(m) / tau) * r.uniform(0.3, 1.0)
        add(out, e, at)
    return out * g


def am(x, hz, depth, r=None):
    t = tt(len(x))
    ph = (r.uniform(0, 6.28) if r is not None else 0.0)
    return x * (1 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * hz * t + ph)))


# ---------------------------------------------------------------------------------------------------
# The throat: glottal pulse train (jitter, shimmer, subharmonic, breaks) through moving formants
# ---------------------------------------------------------------------------------------------------

VOW = {  # F1, F2, F3 of the vowel
    "ah": (730, 1090, 2440), "aw": (590, 880, 2540), "oh": (500, 800, 2400), "oo": (300, 870, 2240),
    "ee": (270, 2290, 3010), "eh": (530, 1840, 2480), "ih": (390, 1990, 2550), "uh": (640, 1190, 2390),
}


def source(f0, r, jitter=0.012, shimmer=0.08, tilt=1.2, sub=0.0, detune=(0.0,), rough=0.0, rough_hz=45):
    n = len(f0)
    out = np.zeros(n)
    jit = snoise(r, n, 60) * jitter + snoise(r, n, 7) * jitter * 1.5
    hmax = int(min(110, 0.42 * SR / max(f0.min(), 30.0)))
    for d in detune:
        f = f0 * (1 + jit) * (2 ** (d / 1200.0))
        ph = np.cumsum(f) / SR + r.uniform()
        for h in range(1, hmax + 1):
            m = (h * f < 0.45 * SR)
            out += np.sin(2 * np.pi * h * ph) * m * h ** -tilt
        if sub > 0:
            for h in range(1, 40, 2):
                out += sub * np.sin(2 * np.pi * h * ph / 2.0) * (h * f / 2 < 0.45 * SR) * h ** -tilt * 1.2
    out /= len(detune)
    out *= 1 + shimmer * snoise(r, n, 35)
    if rough > 0:
        out *= 1 - rough + rough * (0.5 + 0.5 * np.sin(2 * np.pi * rough_hz * tt(n) * (1 + 0.1 * snoise(r, n, 5))))
    return out


def vocal(dur, f0pts, vowA, vowB, vpts, r, *, noise=0.3, jitter=0.012, shimmer=0.08, tilt=1.2, sub=0.0, detune=(0.0,),
          rough=0.0, rough_hz=45, q=4.5, size=1.0, vib=0.0, vib_hz=5.5, cracks=0, f0=100.0, nasal=0.0):
    n = N(dur)
    f = curve(f0pts, n) * f0
    if vib:
        f = f * (1 + vib * np.sin(2 * np.pi * vib_hz * tt(n) + r.uniform(0, 6)))
    for _ in range(cracks):                       # a broken voice: a pitch step and back
        a = r.integers(0, max(n - N(0.12), 2))
        ln = N(r.uniform(0.03, 0.09))
        f[a: a + ln] *= 2 ** (r.choice([-1, 1]) * r.uniform(3, 8) / 12.0)
    src = source(f, r, jitter, shimmer, tilt, sub, detune, rough, rough_hz)
    src = src / (rms(src))
    nz = r.normal(size=n)
    exc = src * (1.0 - noise * 0.55) + nz * noise * 0.9
    vt = curve(vpts, n)
    y = np.zeros(n)
    for k, (gain, qk) in enumerate(((1.0, q), (0.65, q * 1.2), (0.35, q * 1.5))):
        fa = VOW[vowA][k] * (1 - vt) + VOW[vowB][k] * vt
        y += svf(exc, fa / size, qk, "bp") * gain
    if nasal:
        y += svf(exc, 260 / size, 6.0, "bp") * nasal
    return y


# ---------------------------------------------------------------------------------------------------
# Voice sets. One personality each; the act builders below read these numbers.
#   f0 pitch, size (vocal tract, bigger = lower formants), noise breathiness, rough AM roughness, sub subharmonic,
#   wet / bone / chit / air / metal / crackle / creak / grit : texture layers, body: sub weight at body_hz,
#   choir: detuned voices, tail (rt60, wet), atk: attack kind, mat: hit material, vow: (closed, open) vowels
# ---------------------------------------------------------------------------------------------------

SETS = {
    # the hollowed: wet breath, broken human voices
    "hollow":   dict(f0=140, size=1.0, noise=.50, rough=.30, sub=.22, wet=.9, bone=0, chit=0, air=.10, metal=0, body=.45, body_hz=72, tail=(.45, .10), atk="swipe", vow=("aw", "ah"), cracks=2, jitter=.035, q=4.2),
    "gaunt":    dict(f0=250, size=0.9, noise=.45, rough=.10, sub=.06, wet=.3, bone=0, chit=0, air=.35, metal=0, body=.20, body_hz=90, tail=(.6, .14), atk="swipe", vow=("ee", "eh"), cracks=1, vib=.03, jitter=.03, q=5.0),
    "husk":     dict(f0=66, size=1.3, noise=.35, rough=.50, sub=.50, wet=.45, bone=0, chit=0, air=.05, metal=0, body=.95, body_hz=46, tail=(.7, .14), atk="slam", vow=("aw", "oh"), jitter=.03, q=3.6),
    "bulwark":  dict(f0=82, size=1.2, noise=.30, rough=.35, sub=.30, wet=.1, bone=0, chit=0, air=0, metal=.75, body=.85, body_hz=54, tail=(.55, .14), atk="slam", vow=("oh", "oo"), jitter=.02, q=3.4),
    "gurgle":   dict(f0=175, size=1.0, noise=.50, rough=.15, sub=.10, wet=1.4, bone=0, chit=0, air=.20, metal=0, body=.30, body_hz=80, tail=(.4, .10), atk="spit", vow=("ah", "eh"), jitter=.03, q=4.0, gurgle=14),
    "leaper":   dict(f0=430, size=0.85, noise=.40, rough=.45, sub=.12, wet=.2, bone=0, chit=0, air=.20, metal=0, body=.40, body_hz=84, tail=(.5, .12), atk="pounce", vow=("ee", "ah"), jitter=.04, q=5.0),
    "chanter":  dict(f0=150, size=1.0, noise=.78, rough=.05, sub=.05, wet=.1, bone=0, chit=0, air=.55, metal=.1, body=.15, body_hz=75, tail=(1.0, .22), atk="cast", vow=("oo", "ah"), choir=3, jitter=.012, q=6.0),
    "tollman":  dict(f0=92, size=1.2, noise=.40, rough=.15, sub=.20, wet=.1, bone=0, chit=0, air=.15, metal=.9, body=.70, body_hz=58, tail=(1.4, .22), atk="slam", vow=("oh", "oo"), jitter=.012, q=5.0, bell=1),
    "quiller":  dict(f0=310, size=0.9, noise=.50, rough=.20, sub=0, wet=0, bone=.9, chit=.25, air=.15, metal=0, body=.20, body_hz=95, tail=(.4, .10), atk="flick", vow=("eh", "ee"), jitter=.03, q=5.0),
    "ossuant":  dict(f0=108, size=1.1, noise=.55, rough=.40, sub=.15, wet=0, bone=1.0, chit=0, air=.05, metal=0, body=.60, body_hz=64, tail=(.5, .12), atk="swipe", vow=("aw", "oh"), jitter=.03, q=4.0, grit=1),
    "crawler":  dict(f0=520, size=0.7, noise=.50, rough=.35, sub=0, wet=.2, bone=0, chit=1.0, air=.15, metal=0, body=.20, body_hz=110, tail=(.3, .08), atk="lunge", vow=("ee", "ih"), jitter=.05, q=5.5, chitter=38),
    "burrower": dict(f0=72, size=1.25, noise=.60, rough=.60, sub=.20, wet=.15, bone=0, chit=.6, air=0, metal=0, body=.85, body_hz=44, tail=(.5, .10), atk="lunge", vow=("aw", "uh"), jitter=.04, q=3.6, grit=1, earth=1),
    "shade":    dict(f0=310, size=1.0, noise=1.0, rough=0, sub=0, wet=0, bone=0, chit=0, air=1.0, metal=0, body=0, body_hz=70, tail=(1.7, .38), atk="swirl", vow=("oo", "ee"), jitter=.02, q=7.0, reverse=1),
    "cinder":   dict(f0=190, size=1.0, noise=.55, rough=.50, sub=.15, wet=0, bone=0, chit=0, air=.25, metal=0, body=.35, body_hz=70, tail=(.55, .12), atk="cast", vow=("ah", "oh"), jitter=.035, q=4.0, crackle=1),
    # the great ones
    "thorn":    dict(f0=54, size=1.55, noise=.50, rough=.60, sub=.60, wet=0, bone=0, chit=0, air=.05, metal=0, body=1.0, body_hz=38, tail=(1.9, .28), atk="slam", vow=("aw", "oh"), jitter=.03, q=3.4, creak=1, boss=1),
    "abbot":    dict(f0=80, size=1.35, noise=.45, rough=.20, sub=.25, wet=0, bone=.75, chit=0, air=.2, metal=.1, body=.80, body_hz=45, tail=(2.3, .32), atk="slam", vow=("oo", "aw"), choir=4, jitter=.015, q=5.0, boss=1),
    "warden":   dict(f0=64, size=1.5, noise=.40, rough=.30, sub=.35, wet=0, bone=0, chit=0, air=.2, metal=1.0, body=.90, body_hz=40, tail=(2.5, .33), atk="slam", vow=("aw", "ah"), choir=3, jitter=.015, q=4.6, boss=1),
    "brood":    dict(f0=96, size=1.4, noise=.55, rough=.70, sub=.50, wet=1.1, bone=0, chit=.9, air=0, metal=0, body=.90, body_hz=42, tail=(1.5, .26), atk="spit", vow=("ah", "eh"), jitter=.05, q=3.8, boss=1, gurgle=9),
    "reliquary": dict(f0=112, size=1.25, noise=.70, rough=.20, sub=.15, wet=0, bone=1.0, chit=0, air=.35, metal=.45, body=.70, body_hz=52, tail=(1.9, .30), atk="swipe", vow=("eh", "oh"), choir=2, jitter=.03, q=5.0, boss=1, grit=1),
    "anchoress": dict(f0=320, size=1.2, noise=.50, rough=.10, sub=.15, wet=0, bone=0, chit=0, air=.35, metal=.85, body=.55, body_hz=60, tail=(2.1, .34), atk="swipe", vow=("ah", "ee"), vib=.035, jitter=.02, q=5.5, boss=1, chain=1),
    "hierarch": dict(f0=42, size=1.8, noise=.45, rough=.55, sub=.80, wet=0, bone=0, chit=0, air=.1, metal=.2, body=1.0, body_hz=30, tail=(2.7, .36), atk="slam", vow=("oh", "aw"), jitter=.02, q=3.2, boss=1, stone=1),
}

# act -> duration, pitch contour (x f0), vowel openness contour, amplitude contour, effort 0..1
ACT = {
    "idle":    dict(dur=.95, f0=[(0, .78), (.35, .9), (.7, .8), (1, .68)], vt=[(0, 0), (.4, .35), (1, .1)], amp=[(0, 0), (.22, .7), (.55, 1), (1, 0)], eff=.15, n=3, db=-27),
    "alert":   dict(dur=.85, f0=[(0, .85), (.1, 1.5), (.5, 1.3), (1, .75)], vt=[(0, .3), (.15, 1), (1, .4)], amp=[(0, 0), (.04, 1), (.6, .85), (1, 0)], eff=.9, n=3, db=-18),
    "windup":  dict(dur=.42, f0=[(0, .7), (.7, 1.25), (1, 1.5)], vt=[(0, 0), (1, .9)], amp=[(0, 0), (.3, .45), (.9, 1), (.985, .9), (1, 0)], eff=.7, n=3, db=-19),
    "attack":  dict(dur=.46, f0=[(0, 1.55), (.14, 1.3), (1, .6)], vt=[(0, 1), (1, .5)], amp=[(0, 0), (.03, 1), (.3, .8), (1, 0)], eff=1.0, n=3, db=-17),
    "hurt":    dict(dur=.32, f0=[(0, 1.05), (.12, 1.65), (1, .85)], vt=[(0, .8), (1, .3)], amp=[(0, 0), (.05, 1), (1, 0)], eff=.8, n=3, db=-19),
    "stagger": dict(dur=.62, f0=[(0, 1.3), (.2, 1.0), (1, .5)], vt=[(0, .9), (1, .1)], amp=[(0, 0), (.06, 1), (.5, .7), (1, 0)], eff=.8, n=3, db=-18),
    "die":     dict(dur=1.05, f0=[(0, 1.2), (.15, 1.45), (1, .38)], vt=[(0, .9), (1, 0)], amp=[(0, 0), (.04, 1), (.5, .7), (1, 0)], eff=.85, n=3, db=-18),
    "flee":    dict(dur=.36, f0=[(0, 1.2), (.3, 1.85), (1, 1.3)], vt=[(0, .5), (1, .8)], amp=[(0, 0), (.1, 1), (1, 0)], eff=.6, n=2, db=-22),
    "phase":   dict(dur=2.3, f0=[(0, .6), (.12, 1.25), (.55, 1.05), (1, .45)], vt=[(0, .4), (.15, 1), (1, .3)], amp=[(0, 0), (.05, 1), (.7, .9), (1, 0)], eff=1.0, n=2, db=-14, boss_only=1),
}
# bosses lean longer on the big acts; takes per act for bosses
BOSS_N = {"idle": 3, "alert": 2, "windup": 3, "attack": 3, "hurt": 3, "stagger": 2, "die": 2, "flee": 0, "phase": 2}
BOSS_DUR = {"idle": 1.0, "alert": 1.4, "windup": .8, "attack": .7, "hurt": .5, "stagger": .9, "die": 2.2, "phase": 2.3}
ONLY = None


def textures(p, act, n, dur, r, eff, amp):
    """The family's grit and wetness on top of the voice, scaled to the act."""
    o = np.zeros(n)
    busy = {"idle": .35, "alert": 1.0, "windup": .9, "attack": .6, "hurt": .8, "stagger": 1.0, "die": 1.0, "flee": .7, "phase": 1.2}[act]
    sec = n / SR
    if p.get("wet"):
        rate = (3.0 + 9.0 * busy) * p["wet"]
        for at in np.sort(r.random(int(rate * sec)) * sec):
            add(o, wet_click(r), at, r.uniform(0.25, 0.7) * (0.5 + eff))
    if p.get("gurgle"):
        bub = np.zeros(n)
        for at in np.sort(r.random(int((6 + 14 * busy) * sec)) * sec):
            m = N(0.06)
            f = np.geomspace(r.uniform(250, 500), r.uniform(700, 1400), m)
            add(bub, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt(m) * r.uniform(45, 80)), at, r.uniform(.3, 1))
        o += lv(bub, 0.35) * amp
    if p.get("bone"):
        for at in np.sort(r.random(int((1.5 + 6.0 * busy) * p["bone"] * sec)) * sec):
            k = int(r.integers(2, 6))
            t0 = at
            for _ in range(k):
                add(o, bone_clack(r), t0, r.uniform(.2, .6) * (0.4 + eff))
                t0 += r.uniform(.011, .034)
    if p.get("chit"):
        for at in np.sort(r.random(int((6 + 22 * busy) * p["chit"] * sec)) * sec):
            for j in range(int(r.integers(2, 5))):
                add(o, chit_tick(r), at + j * r.uniform(.006, .014), r.uniform(.4, .95) * (0.4 + eff))
    if p.get("chitter"):
        o += lp(hp(r.normal(size=n), 2200), 7000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * p["chitter"] * tt(n) + 1.0))) ** 3 * amp * 0.12 * (0.4 + eff)
    if p.get("air"):
        a = bp(r.normal(size=n), 1800, 9000)
        o += a * amp * p["air"] * (0.22 + 0.55 * (p["air"] >= 0.9)) * (0.4 + eff)
        if p.get("reverse"):                            # a swell that builds and is cut: a reversed breath
            sw = (np.linspace(0, 1, n) ** 2.6) * (np.linspace(1, 0, n) ** 0.1)
            o += bp(r.normal(size=n), 700, 6500) * sw * 0.8 * (0.3 + 0.7 * eff)
    if p.get("metal"):
        t = tt(n)
        base = {"tollman": 196.0, "warden": 233.0, "anchoress": 520.0, "bulwark": 410.0}.get(p.get("name", ""), 330.0)
        if p.get("bell") or act in ("alert", "die", "stagger", "phase", "attack") or p.get("chain"):
            fr = [base, base * 2.4, base * 3.9, base * 5.6] if not p.get("chain") else [base * 3.3, base * 5.1, base * 7.7]
            d = [1.4, 2.0, 3.1, 4.4] if act in ("idle", "hurt") else [1.0, 1.6, 2.4, 3.6]
            at = 0.0 if p.get("bell") or act not in ("die",) else 0.0
            add(o, ring([f * (1 + .004 * r.normal()) for f in fr[:len(d)]], d[:len(fr)], min(sec, 1.8), [1, .6, .35, .2][:len(fr)], r), at, p["metal"] * 0.24 * (0.5 + eff))
        if p.get("chain"):
            for at in np.sort(r.random(int((3 + 9 * busy) * sec)) * sec):
                add(o, ring([r.uniform(2200, 4800), r.uniform(5200, 8000)], [r.uniform(60, 120), r.uniform(140, 260)], .09, [1, .5], r), at, r.uniform(.1, .35))
        if not p.get("bell") and not p.get("chain") and act in ("attack", "hurt", "windup"):
            add(o, ring([base * 3.1, base * 4.7], [30, 55], .2, [1, .5], r), 0.0, p["metal"] * 0.18)
    if p.get("crackle"):
        o += crackle(r, n, 18 + 40 * busy, (1200, 7000), 0.55 * (0.4 + eff)) * (0.4 + 0.6 * amp)
    if p.get("grit"):
        o += grit(r, n, 500 + 1500 * busy) * amp * 0.35 * (0.4 + eff)
    if p.get("creak"):
        # stick-slip wood: a low saw bowed by a slow stutter, resonant at wood frequencies
        ph = np.cumsum(np.full(n, 1.0) * (38 + 22 * snoise(r, n, 3) + 12 * snoise(r, n, 11))) / SR
        saw = ((ph % 1.0) - 0.5) * (np.sign(np.sin(2 * np.pi * (7 + 4 * busy) * tt(n))) * .5 + .5 + .3)
        o += svf(saw + 0.3 * r.normal(size=n), curve([(0, 260), (.5, 420), (1, 210)], n), 7.0, "bp") * amp * 1.2 * (0.3 + eff * 0.7)
        o += crackle(r, n, 5 + 14 * busy, (500, 3500), 0.55 * (0.4 + eff), 0.007)
    if p.get("earth"):
        o += lp(r.normal(size=n), 220 + 80 * snoise(r, n, 4).clip(-1, 1)) * amp * 1.3 * (0.3 + 0.7 * eff)
    if p.get("stone"):
        o += svf(r.normal(size=n), 150 + 60 * snoise(r, n, 3), 4.0, "bp") * amp * 1.4 * (0.3 + 0.7 * eff)
    return o


def body_layer(p, act, n, r, eff):
    """The low weight under the voice: chest resonance and, on the hard acts, a thump."""
    o = np.zeros(n)
    if not p.get("body"):
        return o
    bh = p["body_hz"]
    sec = n / SR
    chest = np.sin(2 * np.pi * np.cumsum(np.full(n, bh) * (1 + .05 * snoise(r, n, 3))) / SR)
    e = {"idle": .12, "alert": .55, "windup": .5, "attack": .45, "hurt": .3, "stagger": .5, "die": .6, "flee": .15, "phase": .7}[act]
    o += chest * curve([(0, 0), (.08, 1), (.6, .7), (1, 0)], n) * e * p["body"]
    if act in ("alert", "attack", "stagger", "phase"):
        add(o, thump(bh * 2.4, bh * .9, .09 if not p.get("boss") else .16), 0.0 if act != "attack" else 0.09, 1.4 * p["body"] * (0.6 + 0.4 * eff))
    if act == "hurt":
        add(o, thump(bh * 2.6, bh * 1.2, .05), 0.0, 0.8 * p["body"])
    return o


def fall_layer(p, r, sec, body_hint=None):
    """The collapse: weight hits the ground, then things settle. Material by family."""
    n = N(sec)
    o = np.zeros(n)
    bh = p["body_hz"]
    big = p.get("boss", 0)
    add(o, thump(bh * 2.2, bh * .75, .14 + .1 * big), 0.0, 1.6 * max(p["body"], .35))
    add(o, lp(r.normal(size=N(.25)), 900) * expo(N(.25), .05), 0.0, .8)
    if p.get("bone"):
        for j in range(int(r.integers(5, 10 + 6 * big))):
            add(o, bone_clack(r), .03 + j * r.uniform(.03, .07) + r.uniform(0, .03), r.uniform(.2, .8) * (1 - j * .07))
    elif p.get("chit"):
        for j in range(int(r.integers(5, 10))):
            add(o, chit_tick(r), .02 + j * r.uniform(.02, .05), r.uniform(.2, .6) * (1 - j * .06))
        add(o, thump(240, 120, .03), .01, .6)
    elif p.get("metal"):
        add(o, ring([r.uniform(420, 760), r.uniform(1200, 1900), r.uniform(2600, 4100)], [14, 30, 60], .6, [1, .5, .3], r), 0.0, .5 * p["metal"])
        add(o, ring([r.uniform(420, 760) * 1.3, r.uniform(1200, 1900) * 1.2], [20, 44], .4, [1, .5], r), .13, .3)
    else:
        add(o, bp(r.normal(size=N(.3)), 120, 800) * expo(N(.3), .08), .02, .9)
        for j in range(int(r.integers(2, 5))):
            add(o, thump(120, 60, .03), .1 + j * r.uniform(.06, .15), .5 / (j + 1))
    if p.get("stone") or p["atk"] == "slam" and big:
        o += lp(r.normal(size=n), 700) * expo(n, .35) * .5
        for j in range(int(r.integers(6, 14))):
            add(o, ring([r.uniform(800, 3000)], [r.uniform(70, 160)], .08) , .08 + r.uniform(0, sec * .5), r.uniform(.1, .4))
    return o


def attack_layer(p, n, r, eff):
    """The blow itself: the part you dodge."""
    o = np.zeros(n)
    k = p["atk"]
    big = p.get("boss", 0)
    bh = p["body_hz"]
    if k == "swipe":
        add(o, whoosh(.22, 3200, 650, r, 1.4, 1.0, .35), 0.0)
        add(o, bone_clack(r, 1500, .6) if p.get("bone") else lp(r.normal(size=N(.04)), 2500) * expo(N(.04), .01) * .8, .13, 1.0)
        add(o, thump(bh * 2.5, bh, .05), .13, p["body"] * 1.1)
    elif k == "slam":
        add(o, whoosh(.34 + .12 * big, 1400, 220, r, 1.2, 1.0, .55), 0.0, 1.1)
        t0 = .30 + .12 * big
        add(o, thump(bh * 2.8, bh * .7, .16 + .1 * big), t0, 2.0 * p["body"])
        add(o, lp(r.normal(size=N(.5)), 1100) * expo(N(.5), .09 + .05 * big), t0, 1.0)
        for j in range(int(r.integers(4, 9))):
            add(o, ring([r.uniform(700, 3200)], [r.uniform(60, 180)], .08), t0 + .03 + r.uniform(0, .25), r.uniform(.05, .3))
        add(o, thump(bh * 1.4, bh * .6, .35 + .2 * big), t0, 1.3 * p["body"])
    elif k == "spit":
        add(o, lp(r.normal(size=N(.1)), 1500) * expo(N(.1), .04), 0.0, .5)             # the cheeks gather
        m = N(.28)
        f = np.geomspace(1500, 260, m)
        add(o, np.sin(2 * np.pi * np.cumsum(f) / SR) * expo(m, .06) * .6, .06)           # the pop
        add(o, bp(r.normal(size=N(.25)), 1800, 6500) * expo(N(.25), .05) * .9, .06)       # the spray
        for j in range(5):
            add(o, wet_click(r), .08 + j * r.uniform(.02, .05), r.uniform(.3, .7))
        add(o, thump(bh * 3, bh, .04), .06, p["body"] * .8)
    elif k == "pounce":
        add(o, thump(bh * 3.5, bh * 1.1, .05), 0.0, p["body"] * 1.2)                    # the push-off
        add(o, whoosh(.38, 700, 2800, r, 1.0, 1.1, .35), .02)
        add(o, thump(bh * 2.2, bh * .8, .08), .36, p["body"] * 1.3)
    elif k == "lunge":
        add(o, thump(bh * 3, bh * 1.2, .04), 0.0, p["body"] * 1.1)
        add(o, whoosh(.2, 2600, 900, r, 1.2, .9, .3), .01)
        if p.get("chit"):
            for j in range(6):
                add(o, chit_tick(r), .01 + j * .012, .6)
    elif k == "cast":
        add(o, bp(r.normal(size=N(.3)), 500, 6000) * np.linspace(0, 1, N(.3)) ** 2 * .8, 0.0)
        add(o, ring([r.uniform(700, 900), r.uniform(1900, 2400), r.uniform(3100, 3900)], [9, 14, 20], .45, [1, .5, .3], r), .28, .45)
        add(o, thump(bh * 2, bh, .06), .28, p["body"] * .8)
    elif k == "swirl":
        sw = bp(r.normal(size=N(.5)), 600, 7000) * (np.linspace(0, 1, N(.5)) ** 3) * (np.linspace(1, 0, N(.5)) ** .1)
        add(o, sw, 0.0, 1.0)
        add(o, bp(r.normal(size=N(.3)), 2000, 9000) * expo(N(.3), .08), .45, .6)
    elif k == "flick":
        add(o, whoosh(.1, 5000, 2000, r, 1.6, .8, .3), 0.0)
        for j in range(3):
            add(o, bone_clack(r, r.uniform(2400, 3800), .7), .06 + j * .018, .8)
    return o


def build(sn, act, i):
    p = dict(SETS[sn])
    p["name"] = sn
    r = R(sn, act, i)
    A = ACT[act]
    boss = p.get("boss", 0)
    dur = (BOSS_DUR[act] if boss else A["dur"]) * [1.0, 1.1, .92, 1.18, .88][i % 5] * r.uniform(.96, 1.05)
    eff = A["eff"]
    pv = [1.0, .92, 1.08, .85, 1.14][i % 5] * r.uniform(.985, 1.015)
    n = N(dur)
    amp = curve(A["amp"], n, .03)
    vowA, vowB = p["vow"]
    tilt = 1.7 - 0.9 * eff
    detune = {1: (0.0,), 2: (-14.0, 11.0), 3: (-22.0, 0.0, 17.0), 4: (-28.0, -9.0, 10.0, 31.0)}[p.get("choir", 1)]
    f0 = p["f0"] * pv
    v = vocal(dur, A["f0"], vowA, vowB, A["vt"], r, noise=min(p["noise"] * (0.55 + 0.6 * eff), 0.97), jitter=p.get("jitter", .02),
              shimmer=.06 + .1 * eff, tilt=tilt, sub=p["sub"] * (0.5 + eff), detune=detune, rough=p["rough"] * (0.4 + 0.6 * eff),
              rough_hz=r.uniform(32, 58), q=p["q"], size=p["size"], vib=p.get("vib", 0.0), cracks=p.get("cracks", 0) if act not in ("idle",) else 0,
              f0=f0, nasal=.3 if p["name"] in ("hollow", "gurgle") else 0.0)
    v = lp(v, 2000.0 + 5200.0 * p["noise"] ** 2 + 900.0 * eff)           # a dark throat: the hiss above is the family's own layers
    if p.get("gurgle"):
        v = am(v, p["gurgle"] * r.uniform(.9, 1.1), .55, r)
    if p.get("chitter") and act != "idle":
        v = am(v, p["chitter"] * r.uniform(.9, 1.15), .8, r)
    v = lv(v * amp, 1.0)
    # idle is quiet, sparse breathing under a murmur; the rest carry the voice at the front
    pad = {"attack": .5, "die": .45, "stagger": .35, "alert": .3, "phase": .7, "hurt": .2, "idle": .1, "windup": .0, "flee": .1}[act] * (1.6 if boss else 1.0)
    M = n + N(pad)
    mix = np.zeros(M)
    if act == "idle":
        mix[:n] += v * .75
        bf = (380.0 / p["size"], 2600.0 / p["size"])
        add(mix, lv(lp(breath(r, dur * .36, "in", f=bf), 1500 + 3500 * p["noise"]), .45), dur * .05)
        add(mix, lv(lp(breath(r, dur * .5, "out", f=bf), 1500 + 3500 * p["noise"]), .55), dur * .45)
    else:
        mix[:n] += v
    tx = textures(p, act, n, dur, r, eff, amp)
    mix[:n] += tx * (0.9 if act != "idle" else 0.5)
    mix[:n] += body_layer(p, act, n, r, eff) * (1.0 if act != "idle" else .6)
    # windups: a tension sweep rising to the cut. Built so the player hears it is about to land.
    if act == "windup":
        sweep = svf(r.normal(size=n), curve([(0, 400), (1, 3600)], n), 1.8, "bp") * (np.linspace(0, 1, n) ** 2.2) * .8
        mix[:n] += sweep * (0.4 + 0.4 * (1 if p["atk"] in ("slam", "pounce") else 0))
        mix[:n] += np.sin(2 * np.pi * np.cumsum(curve([(0, p["body_hz"] * 1.5), (1, p["body_hz"] * 3.3)], n)) / SR) * (np.linspace(0, 1, n) ** 2) * p["body"] * .5
    if act == "attack":
        mix += attack_layer(p, M, r, eff) * 1.15
    if act in ("die",):
        fl = fall_layer(p, r, min(dur * .7, 1.3 + boss), None)
        add(mix, fl, dur * (.42 if not boss else .38), 1.15)
        # a long last breath leaving
        add(mix, lv(breath(r, dur * .3, "out"), .4), dur * .55)
    if act == "phase":
        add(mix, thump(p["body_hz"] * 3, p["body_hz"] * .7, .4), 0.0, 3.0 * p["body"])
        add(mix, lp(r.normal(size=N(.6)), 1400) * expo(N(.6), .12), 0.0, 1.0)
        add(mix, whoosh(1.2, 300, 5000, r, .9, .6, .85), .3)
    if act == "stagger":
        add(mix, thump(p["body_hz"] * 2.2, p["body_hz"] * .8, .1), dur * .35, 1.0 * p["body"])
        add(mix, lp(r.normal(size=N(.18)), 800) * expo(N(.18), .04), dur * .35, .7)
    if act == "flee":
        mix *= 0.9
    # the room: short for the small, long for the great
    rt, wt = p["tail"]
    if act in ("idle", "flee"):
        wt *= .6
    mix = reverb(mix, rt, wt, .55 if not boss else .4, .008 + .014 * boss)
    return finish(mix, A["db"] + (3 if boss and act != "idle" else 0), fade=.03 + .04 * boss, fade_in=.003)


# ---------------------------------------------------------------------------------------------------
# Footsteps: by body type, on the surfaces the game knows
# ---------------------------------------------------------------------------------------------------

BODIES = ["bare", "bony", "chitin", "heavy", "shuffling", "skittering"]
SURFACES = ["grass", "stone", "wood", "water"]
STEP_TAKES = 3


def step(body, surf, i):
    r = R("step", body, surf, i)
    n = N(.3)
    o = np.zeros(n)
    pv = [1.0, .93, 1.08][i % 3]
    if body == "bare":      # a soft flat foot, the toes after
        add(o, thump(150 * pv, 70, .025), 0.0, 1.0)
        add(o, lp(r.normal(size=N(.06)), 1200) * expo(N(.06), .018), 0.0, .8)
        add(o, bp(r.normal(size=N(.08)), 900, 4200) * expo(N(.08), .02), .05 * r.uniform(.6, 1.4), .3)
    elif body == "bony":    # heel bone tapping, a double click
        add(o, bone_clack(r, 1100 * pv, 1.0), 0.0)
        add(o, bone_clack(r, 1600 * pv, .55), r.uniform(.02, .04))
        add(o, thump(190 * pv, 110, .02), 0.0, .6)
    elif body == "chitin":  # hooked legs: three or four hard ticks
        for j in range(int(r.integers(3, 5))):
            add(o, chit_tick(r), j * r.uniform(.016, .03), .9 - j * .1)
        add(o, thump(210 * pv, 130, .02), 0.0, .45)
    elif body == "heavy":   # a ton lands: sub thump, a slump of noise, a creak of harness
        add(o, thump(84 * pv, 36, .1, .5), 0.0, 1.6)
        add(o, lp(r.normal(size=N(.18)), 600) * expo(N(.18), .05), 0.0, .9)
        add(o, svf(r.normal(size=N(.2)), curve([(0, 600), (1, 300)], N(.2)), 5, "bp") * expo(N(.2), .08), .03, .25)
        add(o, thump(60 * pv, 28, .2, .3), .02, .9)
    elif body == "shuffling":  # a dragged foot: sandpaper in, a soft knock out
        ln = N(.2) + int(r.integers(0, N(.05)))
        e = np.sin(np.linspace(0, np.pi, ln)) ** 1.6
        add(o, bp(r.normal(size=ln), 500, 4200) * e * .9, 0.0)
        add(o, thump(120 * pv, 66, .025), ln / SR * .75, .8)
    elif body == "skittering":  # a fast cluster of tiny ticks
        for j in range(int(r.integers(5, 8))):
            add(o, chit_tick(r), j * r.uniform(.009, .017), .55 * (1 - j * .06))
    if surf == "grass":
        o = lp(o, 2800 * pv) * .85
        add(o, bp(r.normal(size=N(.14)), 1800, 6000) * np.sin(np.linspace(0, np.pi, N(.14))) ** 2 * .12, .01)
    elif surf == "stone":
        add(o, hp(r.normal(size=N(.012)), 2500) * np.exp(-tt(N(.012)) * 500) * .6, 0.0)
        o = reverb(o, .28, .14, .3, .004)[:n]
    elif surf == "wood":
        add(o, ring([r.uniform(170, 230), r.uniform(330, 410), r.uniform(560, 700)], [26, 40, 55], .22, [1, .5, .25], r), 0.0, .7)
        add(o, thump(140, 90, .025), 0.0, .35)
    elif surf == "water":
        o = lp(o, 1800) * .5
        add(o, bp(r.normal(size=N(.18)), 350, 3200) * expo(N(.18), .045) * np.linspace(.5, 1, N(.18)), 0.0, .7)
        for j in range(int(r.integers(2, 5))):
            add(o, wet_click(r), .02 + j * r.uniform(.015, .04), r.uniform(.2, .6))
    base = {"bare": -24, "bony": -26, "chitin": -29, "heavy": -19, "shuffling": -26, "skittering": -30}[body]
    return finish(o, base, fade=.03, fade_in=.0015)


# ---------------------------------------------------------------------------------------------------
# Kit: shared combat sounds (hit materials, shields, eruptions) -- layered, several takes each
# ---------------------------------------------------------------------------------------------------

def hit_mat(mat, heavy, i):
    r = R("hit", mat, heavy, i)
    pv = [1.0, .9, 1.1, .82][i % 4]
    n = N(.5 if heavy else .3)
    o = np.zeros(n)
    w = 1.7 if heavy else 1.0
    if mat == "flesh":
        add(o, thump(120 * pv, 48, .05 + .03 * heavy), 0.0, 1.4 * w)
        add(o, lp(r.normal(size=N(.14)), 1400) * expo(N(.14), .03), 0.0, 1.0)
        add(o, svf(r.normal(size=N(.16)), curve([(0, 1800), (1, 500)], N(.16)), 2.0, "bp") * expo(N(.16), .035), .004, 1.2)   # wet slap
        for j in range(int(r.integers(2, 4 + 2 * heavy))):
            add(o, wet_click(r), .02 + j * r.uniform(.015, .04), r.uniform(.2, .6))
    elif mat == "bone":
        add(o, bone_clack(r, 1000 * pv, 1.1), 0.0)
        add(o, bone_clack(r, 1700 * pv, .7), .007)
        add(o, thump(170 * pv, 80, .035), 0.0, 1.0 * w)
        for j in range(int(r.integers(2, 6 + 3 * heavy))):
            add(o, bone_clack(r), .03 + j * r.uniform(.015, .04), r.uniform(.15, .45))
    elif mat == "chitin":
        add(o, thump(200 * pv, 90, .03), 0.0, 1.0 * w)
        add(o, ring([r.uniform(2800, 4200), r.uniform(5000, 7200)], [170, 320], .12, [1, .5], r), 0.0, .9)
        add(o, lp(r.normal(size=N(.08)), 2500) * expo(N(.08), .015), 0.0, .8)     # crunch
        for j in range(int(r.integers(3, 7 + 3 * heavy))):
            add(o, chit_tick(r), .015 + j * r.uniform(.008, .02), r.uniform(.3, .7))
        add(o, wet_click(r), .03, .5)
    elif mat == "stone":
        add(o, thump(100 * pv, 42, .07 + .04 * heavy), 0.0, 1.5 * w)
        add(o, ring([r.uniform(500, 900), r.uniform(1300, 2100), r.uniform(2800, 4400)], [22, 46, 90], .3, [1, .55, .3], r), 0.0, .7)
        add(o, hp(r.normal(size=N(.03)), 1800) * expo(N(.03), .006), 0.0, 1.0)
        for j in range(int(r.integers(2, 6 + 3 * heavy))):
            add(o, ring([r.uniform(900, 3600)], [r.uniform(90, 200)], .06), .04 + r.uniform(0, .15), r.uniform(.1, .3))
    elif mat == "wood":
        add(o, thump(140 * pv, 70, .05), 0.0, 1.2 * w)
        add(o, ring([r.uniform(200, 280), r.uniform(420, 560), r.uniform(900, 1300)], [30, 55, 90], .3, [1, .6, .3], r), 0.0, .8)
        add(o, bp(r.normal(size=N(.03)), 1200, 5000) * expo(N(.03), .008), 0.0, 1.0)
        for j in range(int(r.integers(1, 4))):
            add(o, crackle(r, N(.05), 100, (700, 4000), 1.0, .005), .03 + j * .03, .5)
    elif mat == "ether":
        add(o, bp(r.normal(size=N(.3)), 700, 7000) * expo(N(.3), .08), 0.0, .9)
        add(o, ring([r.uniform(1200, 1700), r.uniform(2400, 3200)], [14, 22], .4, [1, .5], r), 0.0, .35)
        add(o, thump(110 * pv, 55, .05), 0.0, .6)
        add(o, bp(r.normal(size=N(.45)), 500, 5000) * (np.linspace(0, 1, N(.45)) ** 2) * np.linspace(1, .2, N(.45)), .03, .35)
    o = reverb(o, .35, .08, .6, .004)
    return finish(o, -17 if not heavy else -13, fade=.035)


def kit(kind, i):
    r = R("kit", kind, i)
    pv = [1.0, .92, 1.08, .86][i % 4]
    o = np.zeros(N(1.6))
    if kind == "flesh":
        return hit_mat("flesh", 0, i)
    if kind == "bone":
        return hit_mat("bone", 0, i)
    if kind == "roar":      # a generic great roar for elites and shaken foes
        dur = 1.5 * [1.0, 1.15, .9][i % 3]
        v = lv(vocal(dur, [(0, .7), (.12, 1.3), (.6, 1.0), (1, .5)], "aw", "ah", [(0, .3), (.2, 1), (1, .3)], r, noise=.45, tilt=.9, sub=.6, rough=.55, rough_hz=r.uniform(28, 44), f0=70 * pv, size=1.4, q=3.5), 1.0)
        v = v * curve([(0, 0), (.05, 1), (.75, .85), (1, 0)], len(v))
        o = fit(o, len(v)) + v
        add(o, thump(150, 38, .2), 0.0, 1.6)
        add(o, whoosh(.7, 500, 3200, r, 1.0, .35, .5), .1)
        o = reverb(o, 1.3, .24, .5, .02)
        return finish(o, -15, fade=.05)
    if kind == "stagger":   # a heavy lurch: ground, breath, armour
        add(o, thump(130 * pv, 34, .22, .6), 0.0, 2.0)
        add(o, lp(r.normal(size=N(.4)), 700) * expo(N(.4), .1), 0.0, 1.0)
        add(o, breath(r, .4, "out", g=.7), .08)
        add(o, thump(90 * pv, 40, .12), .22, 1.0)
        for j in range(int(r.integers(4, 8))):
            add(o, ring([r.uniform(1000, 3400)], [r.uniform(60, 160)], .08), .02 + r.uniform(0, .3), r.uniform(.05, .25))
        o = reverb(o, .6, .14, .5, .01)
        return finish(o, -15, fade=.04)
    if kind == "spike":     # bone or thorn bursting from the ground
        add(o, thump(260 * pv, 60, .08), 0.0, 1.4)
        add(o, bp(r.normal(size=N(.12)), 1500, 8000) * expo(N(.12), .02), 0.0, 1.0)
        add(o, whoosh(.25, 600, 4500, r, 1.2, .8, .3), 0.0)
        for j in range(int(r.integers(5, 10))):
            add(o, bone_clack(r), .02 + j * r.uniform(.01, .035), r.uniform(.2, .6))
        add(o, lp(r.normal(size=N(.5)), 1000) * expo(N(.5), .1), .05, .6)
        o = reverb(o, .5, .12, .5, .006)
        return finish(o, -15, fade=.04)
    if kind == "block":     # a blow turned on a shield / plate
        fs = [r.uniform(420, 620) * pv, r.uniform(1100, 1500), r.uniform(2300, 3200), r.uniform(4500, 6200)]
        add(o, ring(fs, [9, 17, 30, 60], .9, [1, .7, .45, .25], r), 0.0, 1.0)
        add(o, thump(150 * pv, 60, .04), 0.0, 1.3)
        add(o, hp(r.normal(size=N(.02)), 2500) * expo(N(.02), .004), 0.0, 1.2)
        o = reverb(o, .7, .16, .4, .008)
        return finish(o, -16, fade=.06)
    if kind == "burrow":    # earth heaves and is spat out
        n = N(1.0)
        o = np.zeros(n)
        o += lp(r.normal(size=n), curve([(0, 160), (.5, 320), (1, 140)], n)) * curve([(0, 0), (.3, 1), (.7, .8), (1, 0)], n) * 1.4
        add(o, thump(80 * pv, 30, .2, .6), 0.0, 1.4)
        for j in range(int(r.integers(8, 16))):
            add(o, ring([r.uniform(600, 2600)], [r.uniform(70, 170)], .08), r.uniform(0, .7), r.uniform(.05, .3))
        add(o, grit(r, n, 1400) * 0.4, 0.0)
        o = reverb(o, .4, .1, .6, .006)
        return finish(o, -16, fade=.06)
    if kind == "spit":      # a gob of something thrown: cheeks gather, the pop, spray, wet impacts after
        add(o, lp(r.normal(size=N(.1)), 1500) * expo(N(.1), .04), 0.0, .5)
        m = N(.28)
        f = np.geomspace(1500 * pv, 260, m)
        add(o, np.sin(2 * np.pi * np.cumsum(f) / SR) * expo(m, .06) * .7, .06)
        add(o, bp(r.normal(size=N(.3)), 1600, 6500) * expo(N(.3), .06) * .9, .06)
        for j in range(int(r.integers(5, 9))):
            add(o, wet_click(r), .08 + j * r.uniform(.02, .05), r.uniform(.3, .8))
        add(o, thump(190 * pv, 80, .05), .06, .9)
        add(o, whoosh(.22, 3000, 900, r, 1.2, .4, .3), .1)
        o = reverb(o, .35, .08, .6, .004)
        return finish(o, -17, fade=.05)
    if kind == "bell":      # a great bronze bell: strike, hum, a long ring (tollman)
        n = N(2.2)
        t = tt(n)
        o = np.zeros(n)
        base = 98.0 * pv
        parts = [(0.5, 1.0, 1.1), (1.0, .8, 1.5), (1.19, .45, 1.8), (1.5, .4, 2.2), (2.0, .55, 2.6), (2.5, .3, 3.2), (3.0, .22, 4.0), (4.1, .16, 5.2)]
        for ratio, amp_, dec in parts:
            o_ = np.sin(2 * np.pi * base * ratio * (1 + .0007 * r.normal()) * t + r.uniform(0, 6.28)) * np.exp(-t * dec) * amp_
            o += o_
        add(o, hp(r.normal(size=N(.03)), 1500) * expo(N(.03), .006), 0.0, .9)
        add(o, thump(120 * pv, 60, .08), 0.0, .7)
        o = reverb(o, 1.6, .22, .45, .015)
        return finish(o, -17, fade=.12)
    if kind == "chant":     # a caster's rising drone (choir of three)
        n = N(1.2)
        v = vocal(1.2, [(0, .9), (1, 1.25)], "oo", "ah", [(0, 0), (1, 1)], r, noise=.15, jitter=.006, tilt=1.3, detune=(-18, 0, 15), f0=120 * pv, size=1.1, q=7)
        v = v * curve([(0, 0), (.4, .8), (.9, 1), (1, 0)], n)
        o = v + bp(r.normal(size=n), 800, 5000) * curve([(0, 0), (1, .25)], n)
        o = reverb(o, 1.2, .3, .5, .015)
        return finish(o, -19, fade=.08)
    raise ValueError(kind)


KIT_KINDS = {"flesh": 4, "bone": 4, "roar": 3, "stagger": 3, "spike": 3, "block": 3, "burrow": 3, "chant": 2, "spit": 3, "bell": 2}
HIT_MATS = {"flesh": 3, "bone": 3, "chitin": 4, "stone": 4, "wood": 3, "ether": 3}      # light takes; heavy 2 each (ether 1)


# ---------------------------------------------------------------------------------------------------
# The wanderer's own combat: hurt, dodge, parry, block, staff thwack
# ---------------------------------------------------------------------------------------------------

def player(kind, i):
    r = R("player", kind, i)
    pv = [1.0, .93, 1.07, .86][i % 4]
    o = np.zeros(N(1.0))
    if kind == "hurt":      # a blow lands on cloth and flesh: thud, a caught breath, a bright sting
        add(o, thump(115 * pv, 44, .06, .3), 0.0, 1.5)
        add(o, lp(r.normal(size=N(.12)), 900) * expo(N(.12), .03), 0.0, 1.0)
        add(o, hp(r.normal(size=N(.02)), 2400) * expo(N(.02), .004), 0.0, .8)
        add(o, breath(r, .32, "in", f=(450, 2600), g=.9), .05)
        add(o, ring([r.uniform(700, 900) * pv, r.uniform(1500, 2000)], [26, 44], .3, [1, .4], r), 0.0, .12)
        add(o, thump(60, 34, .25, .5), .02, 1.0)
        o = reverb(o, .4, .1, .6, .006)
        return finish(o, -15, fade=.05)
    if kind == "dodge":     # cloth and air, a push off the ground
        add(o, whoosh(.32, 900 * pv, 4200, r, 1.2, 1.0, .4), 0.0)
        add(o, bp(r.normal(size=N(.25)), 200, 1800) * np.sin(np.linspace(0, np.pi, N(.25))) ** 2 * 0.5, 0.0)
        add(o, thump(140 * pv, 70, .03), 0.0, .7)
        add(o, thump(130, 66, .04), .26, .5)
        o = reverb(o, .3, .06, .6, .004)
        return finish(o, -22, fade=.05)
    if kind in ("parry", "block"):
        hard = kind == "parry"
        f0 = r.uniform(900, 1250) * pv if hard else r.uniform(380, 520) * pv
        fs = [f0, f0 * 2.43, f0 * 4.1, f0 * 6.2]
        add(o, ring(fs, [7, 13, 24, 42] if hard else [18, 34, 60, 90], 1.0 if hard else .6, [1, .8, .5, .3], r), 0.0, 1.0)
        add(o, hp(r.normal(size=N(.012)), 2800) * expo(N(.012), .003), 0.0, 1.6)
        add(o, thump(150 * pv, 55, .05 if hard else .07), 0.0, 1.2 if hard else 1.7)
        if hard:
            add(o, ring([f0 * 1.5, f0 * 3.6], [5, 10], 1.2, [.4, .25], r), .01, .8)     # the shimmer after a clean parry
        o = reverb(o, 1.0 if hard else .45, .2 if hard else .1, .4, .008)
        return finish(o, -15, fade=.08)
    if kind == "thwack":    # the staff striking a body
        add(o, thump(180 * pv, 70, .04), 0.0, 1.2)
        add(o, ring([r.uniform(220, 300), r.uniform(560, 700)], [38, 60], .2, [1, .4], r), 0.0, .6)
        add(o, hp(r.normal(size=N(.015)), 2000) * expo(N(.015), .004), 0.0, 1.0)
        add(o, whoosh(.08, 3000, 1400, r, 1.4, .5, .5), 0.0)
        o = reverb(o, .3, .06, .6, .004)
        return finish(o, -19, fade=.04)
    raise ValueError(kind)


PLAYER_KINDS = {"hurt": 4, "dodge": 3, "parry": 3, "block": 3, "thwack": 3}


# ---------------------------------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------------------------------

def wav_write(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def takes(sn, act):
    if SETS[sn].get("boss"):
        return BOSS_N[act]
    if ACT[act].get("boss_only"):
        return 0
    return ACT[act]["n"]


def main():
    args = sys.argv[1:]
    only = args[args.index("--only") + 1] if "--only" in args else None
    reel = args[args.index("--reel") + 1] if "--reel" in args else None
    write = "--no-write" not in args
    bank = {"sets": {}, "steps": {}, "kit": {}, "hits": {}, "player": {}}
    rl = []
    gap = np.zeros(N(.45))

    def out(rel, x, family, label):
        if write:
            wav_write(os.path.join(AUDIO, rel), x)
        if reel and label.endswith(" 0") and (family != "steps" or " grass " in label or " stone " in label):
            rl.append((family, label, x))

    for sn in SETS:
        bank["sets"][sn] = {}
        for act in ACT:
            k = takes(sn, act)
            if k <= 0:
                continue
            bank["sets"][sn][act] = k
            if only and only not in (sn, "sets"):
                continue
            for i in range(k):
                out("enemy/%s/%s_%d.wav" % (sn, act, i), build(sn, act, i), sn, "%s %d" % (act, i))
        print("set", sn, bank["sets"][sn], flush=True)
    for body in BODIES:
        bank["steps"][body] = {s: STEP_TAKES for s in SURFACES}
        if only and only not in ("steps",):
            continue
        for s in SURFACES:
            for i in range(STEP_TAKES):
                out("enemy/step/%s_%s_%d.wav" % (body, s, i), step(body, s, i), "steps", "%s %s %d" % (body, s, i))
    for kind, k in KIT_KINDS.items():
        bank["kit"][kind] = k
        if only and only not in ("kit",):
            continue
        for i in range(k):
            out("kit/%s_%d.wav" % (kind, i), kit(kind, i), "kit", "%s %d" % (kind, i))
    for mat, k in HIT_MATS.items():
        heavy_n = 1 if mat == "ether" else 2
        bank["hits"][mat] = [k, heavy_n]
        if only and only not in ("kit",):
            continue
        for i in range(k):
            out("kit/hit_%s_%d.wav" % (mat, i), hit_mat(mat, 0, i), "hits", "%s %d" % (mat, i))
        for i in range(heavy_n):
            out("kit/hit_%s_heavy_%d.wav" % (mat, i), hit_mat(mat, 1, i), "hits", "%s heavy %d" % (mat, i))
    for kind, k in PLAYER_KINDS.items():
        bank["player"][kind] = k
        if only and only not in ("player",):
            continue
        for i in range(k):
            out("player/%s_%d.wav" % (kind, i), player(kind, i), "player", "%s %d" % (kind, i))
    if write and not only:
        write_bank(bank)
    if reel:
        pieces = []
        last = None
        t = 0.0
        index = []
        for fam, label, x in rl:
            if fam != last:
                pieces.append(np.zeros(N(.9)))
                t += .9
                last = fam
                index.append("%7.1fs  == %s ==" % (t, fam))
            index.append("%7.1fs     %s" % (t, label))
            pieces += [x, gap]
            t += len(x) / SR + len(gap) / SR
        wav_write(reel, np.concatenate(pieces))
        with open(os.path.splitext(reel)[0] + "_index.txt", "w") as f:
            f.write("\n".join(index) + "\n")
        print("reel", reel, "%.1fs" % t)


def write_bank(bank):
    L = ["extends RefCounted",
         "## GENERATED by tools/gen_enemy_sfx.py (re-run it, do not edit): how many takes of each sound exist under",
         "## art/audio/enemy, art/audio/kit and art/audio/player. EnemyAudio (enemy_audio.gd) plays them.", ""]
    def dump(name, d, doc):
        L.append("## " + doc)
        L.append("const %s := {" % name)
        for k, v in d.items():
            if isinstance(v, dict):
                L.append('\t"%s": {%s},' % (k, ", ".join('"%s": %s' % (a, b) for a, b in v.items())))
            else:
                L.append('\t"%s": %s,' % (k, v))
        L.append("}")
        L.append("")
    dump("SETS", bank["sets"], "voice set -> act -> takes (enemy/<set>/<act>_<n>.wav)")
    dump("STEPS", bank["steps"], "body type -> surface -> takes (enemy/step/<body>_<surface>_<n>.wav)")
    dump("KIT", bank["kit"], "shared combat kit: kind -> takes (kit/<kind>_<n>.wav)")
    dump("HITS", bank["hits"], "hit material -> [light takes, heavy takes] (kit/hit_<material>[_heavy]_<n>.wav)")
    dump("PLAYER", bank["player"], "the wanderer's own combat: kind -> takes (player/<kind>_<n>.wav)")
    with open(os.path.join(ROOT, "core", "vfx", "enemy_bank.gd"), "w") as f:
        f.write("\n".join(L))
    print("wrote core/vfx/enemy_bank.gd")


if __name__ == "__main__":
    main()
