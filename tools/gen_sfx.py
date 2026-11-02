"""Procedural combat SFX for Umbral Reaches (numpy only, deterministic).

    python3 tools/gen_sfx.py            # writes art/audio/*.wav (16-bit mono 44.1 kHz)

Every sound is synthesised from noise, filtered sweeps and FM so there is no licensing to track.
Dark-fantasy palette: low thumps, breathy whooshes, glassy rift tones, wet organic bursts.
"""
import os, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "audio")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, d=None, curve=4.0):
    x = np.linspace(0, 1, n)
    attack = np.clip(x / max(a * SR / n, 1e-6), 0, 1)
    decay = (1 - x) ** curve if d is None else np.exp(-x * d)
    return attack * decay


def lp(x, cutoff):
    """One-pole low-pass; cutoff may be an array (sweeps)."""
    cutoff = np.broadcast_to(cutoff, x.shape)
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def hp(x, cutoff):
    return x - lp(x, cutoff)


def noise(n):
    return rng.uniform(-1, 1, n)


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def save(name, x):
    x = np.clip(norm(x), -1, 1)
    fade = min(len(x), 256)
    x[-fade:] *= np.linspace(1, 0, fade)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", path, f"{len(x) / SR:.2f}s")


def whoosh(sec, f0, f1, curve=2.0):
    n = int(SR * sec)
    sweep = np.geomspace(f0, f1, n)
    body = lp(noise(n), sweep) * np.sin(np.linspace(0, np.pi, n)) ** curve
    return body


def main():
    os.makedirs(OUT, exist_ok=True)
    # Shadowstep: inhale-whoosh up, airy tail, low sub drop on arrival
    n = int(SR * 0.42)
    x = whoosh(0.42, 400, 5200, 1.5) * 1.2
    x += np.sin(2 * np.pi * np.geomspace(90, 45, n) * t(0.42)) * env(n, 0.05, 6) * 0.5
    save("step_blink", x)
    # Double jump: soft rift pulse (FM chirp) + air puff
    n = int(SR * 0.32)
    tt = t(0.32)
    car = np.sin(2 * np.pi * np.geomspace(320, 640, n) * tt + 2.5 * np.sin(2 * np.pi * 90 * tt))
    x = car * env(n, 0.004, 9) * 0.6 + whoosh(0.32, 900, 3000, 3.0) * 0.6
    save("jump_air", x)
    # Slide: gritty scrape loop (band noise, slow amplitude grain)
    n = int(SR * 1.2)
    grit = hp(lp(noise(n), 2600), 300)
    grain = 0.75 + 0.25 * np.sin(2 * np.pi * 7.3 * t(1.2)) * np.sin(2 * np.pi * 3.1 * t(1.2))
    x = grit * grain
    x[: 2000] *= np.linspace(0, 1, 2000)
    save("slide_scrape", x)
    # Nova: deep boom + glassy shimmer + reverse-ish swell
    n = int(SR * 1.3)
    tt = t(1.3)
    boom = np.sin(2 * np.pi * np.geomspace(110, 32, n) * tt) * env(n, 0.002, 4.5)
    crack = lp(noise(n), np.geomspace(9000, 400, n)) * env(n, 0.001, 18) * 0.9
    shimmer = sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) for f in (880, 1310, 1975, 2637)) * env(n, 0.01, 5) * 0.12
    save("nova_boom", boom * 1.2 + crack + shimmer)
    # Lance charge: rising ember crackle + tone (loopable-ish, 1.0 s)
    n = int(SR * 1.0)
    tt = t(1.0)
    tone = np.sin(2 * np.pi * np.geomspace(140, 420, n) * tt) * 0.35 * np.linspace(0.3, 1, n)
    crack = (rng.random(n) > 0.9965).astype(float) * rng.uniform(-1, 1, n)
    crack = lp(crack, 3000) * 3.0
    roar = lp(noise(n), np.geomspace(300, 1400, n)) * 0.5 * np.linspace(0.2, 1, n)
    save("lance_charge", tone + crack + roar)
    # Lance fire: fiery whoosh + thump
    n = int(SR * 0.6)
    x = whoosh(0.6, 2500, 350, 0.8) * 1.3 + np.sin(2 * np.pi * np.geomspace(160, 50, n) * t(0.6)) * env(n, 0.002, 9) * 0.8
    save("lance_fire", x)
    # Lance impact: explosion
    n = int(SR * 1.1)
    x = lp(noise(n), np.geomspace(6000, 180, n)) * env(n, 0.001, 5) * 1.2
    x += np.sin(2 * np.pi * np.geomspace(80, 28, n) * t(1.1)) * env(n, 0.002, 4) * 0.9
    save("lance_impact", x)
    # Ward plant: bell-like chime (inharmonic partials) + warm flare
    n = int(SR * 2.2)
    tt = t(2.2)
    bell = sum(a * np.sin(2 * np.pi * f * tt) * np.exp(-tt * d) for f, a, d in ((392, 1, 1.4), (588, 0.6, 2.0), (1002, 0.35, 2.8), (1569, 0.2, 3.6)))
    save("ward_chime", bell * 0.7 + whoosh(2.2, 600, 200, 4.0) * 0.2)
    # Spit: wet glop + hiss
    n = int(SR * 0.4)
    tt = t(0.4)
    glop = np.sin(2 * np.pi * np.geomspace(380, 120, n) * tt) * env(n, 0.003, 14)
    hiss = hp(noise(n), 2500) * env(n, 0.01, 8) * 0.4
    save("spit", glop + hiss)
    # Enemy death: dry rattle + exhale
    n = int(SR * 0.9)
    tt = t(0.9)
    rattle = lp(noise(n) * (np.sin(2 * np.pi * 31 * tt) > 0.6), 1800) * env(n, 0.005, 4)
    exhale = lp(noise(n), np.geomspace(1800, 300, n)) * env(n, 0.08, 3) * 0.7
    save("enemy_die", rattle + exhale)
    # Pounce screech: harsh FM shriek, short
    n = int(SR * 0.45)
    tt = t(0.45)
    shriek = np.sin(2 * np.pi * np.geomspace(700, 1300, n) * tt + 6.0 * np.sin(2 * np.pi * 173 * tt)) * env(n, 0.01, 6)
    save("pounce_shriek", hp(shriek, 300) + hp(noise(n), 3000) * env(n, 0.01, 10) * 0.3)
    # Mark applied: tiny glass tick
    n = int(SR * 0.18)
    tt = t(0.18)
    save("mark_tick", np.sin(2 * np.pi * 2350 * tt) * np.exp(-tt * 40) + np.sin(2 * np.pi * 3510 * tt) * np.exp(-tt * 55) * 0.5)
    # Player hurt: muffled thump + dark breath
    n = int(SR * 0.5)
    tt = t(0.5)
    save("hurt", np.sin(2 * np.pi * np.geomspace(120, 55, n) * tt) * env(n, 0.002, 10) + lp(noise(n), 700) * env(n, 0.02, 7) * 0.6)


if __name__ == "__main__":
    main()
