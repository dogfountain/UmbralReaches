#!/usr/bin/env python3
"""Render core/vfx/foley.gd's sounds to WAV (through zz/foley_test.tscn) and analyse them with ffmpeg:
a spectrogram per kind and per-kind loudness (EBU R128 integrated / true peak, and RMS / peak from volumedetect).
Standard library + ffmpeg only.

    python3 tools/analyze_foley.py <out_dir> [--no-render] [--only hoof_,horse_]

Writes <out_dir>/wav/*.wav, <out_dir>/spec/<kind>.png (one frame per kind, take 0), <out_dir>/sheet_<group>.png
(contact sheets of the spectrograms) and <out_dir>/levels.tsv.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = os.path.abspath(args[0] if args else "foley_out")
    wav = os.path.join(out, "wav")
    spec = os.path.join(out, "spec")
    os.makedirs(spec, exist_ok=True)
    only = None
    for i, a in enumerate(sys.argv):
        if a == "--only" and i + 1 < len(sys.argv):
            only = sys.argv[i + 1].split(",")
    if "--no-render" not in sys.argv:
        r = run(["godot", "--headless", "--path", ROOT, "res://zz/foley_test.tscn", "--", "--out=" + wav])
        print("\n".join(l for l in r.stdout.splitlines() if l.startswith(("FOLEY", "FAIL"))))
    rows = []
    groups = {}
    for f in sorted(os.listdir(wav)):
        if not f.endswith("_0.wav"):
            continue
        kind = f[:-6]
        if only and not any(kind.startswith(o) for o in only):
            continue
        path = os.path.join(wav, f)
        png = os.path.join(spec, kind + ".png")
        # log-frequency would be nicer, but showspectrumpic is linear: limit to 12 kHz so the thumps and the clicks both show
        run(["ffmpeg", "-y", "-i", path, "-lavfi", "showspectrumpic=s=480x240:legend=0:fscale=log:color=intensity:scale=log:drange=70:limit=0", png])
        e = run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"]).stderr
        integ = re.findall(r"I:\s+(-?[\d.]+) LUFS", e)
        tp = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", e)
        v = run(["ffmpeg", "-nostats", "-i", path, "-af", "volumedetect", "-f", "null", "-"]).stderr
        mean = re.findall(r"mean_volume: (-?[\d.]+) dB", v)
        mx = re.findall(r"max_volume: (-?[\d.]+) dB", v)
        rows.append((kind, integ[-1] if integ else "", tp[-1] if tp else "", mean[-1] if mean else "", mx[-1] if mx else ""))
        groups.setdefault(kind.split("_")[0], []).append(png)
    with open(os.path.join(out, "levels.tsv"), "w") as fh:
        fh.write("kind\tLUFS\ttruepeak_dBFS\tmean_dB\tmax_dB\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    for g, pngs in groups.items():
        n = len(pngs)
        if n < 2:
            continue
        cols = 3 if n > 4 else 2
        rws = (n + cols - 1) // cols
        cmd = ["ffmpeg", "-y"]
        for p in pngs:
            cmd += ["-i", p]
        lay = "|".join("%d_%d" % ((i % cols) * 480, (i // cols) * 240) for i in range(n))
        fc = "".join("[%d:v]" % i for i in range(n)) + "xstack=inputs=%d:layout=%s[v]" % (n, lay)
        cmd += ["-filter_complex", fc, "-map", "[v]", os.path.join(out, "sheet_%s.png" % g)]
        run(cmd)
    for r in rows:
        print("%-16s I=%7s LUFS  TP=%6s dBFS  mean=%7s  max=%7s" % r)


if __name__ == "__main__":
    main()
