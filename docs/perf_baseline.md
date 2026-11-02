# Perf baseline — 2 Nov 2026

Recorded on the owner Mac after 2.9 (real GPU/CPU overlay) and 1.7 (F8 vsync off).
Re-measure every Phase 2 item against this file.

## Machine

- MacBook Pro (Mac16,8), Apple M4 Pro, 12 CPU / 16 GPU cores, 24 GB
- Built-in Retina 3024×1964
- Godot 4.7.2 Forward+, `--rendering-driver vulkan` (MoltenVK)
- In-memory for the run only: fullscreen, vsync off. Owner `settings.cfg` not written.
- Live settings: preset 2 (Cinematic), shadows 2, fog/ssao/glow/grade on, `render_scale=1.00`, height cap 960
- Internal buffer: **1529×960 @ 100%** (window reported 3600×2260)

Command:

```
godot --path . --rendering-driver vulkan -- --perf-baseline
```

Stands on `Demo/WP01_Sanctuary`, `WP05_Climb`, `WP11_Gaze` (raycast-snapped, 10 s each).

## Boot

| Stamp | ms | Notes |
| --- | ---: | --- |
| `BOOT setup_ms` (end of `finish_zone_setup`) | 156.4 | GDScript dress + spawners |
| `BOOT first_frame_ms` (first `process_frame` after that) | 1458.0 | Warm process. Cold run earlier the same session: **2232.4** |

First-frame includes the realtime sky radiance cubemap and `UPDATE_ONCE` reflection probes. `boot_diag` (16 GLB loads) is on a 0.45 s timer, so it is **not** inside `first_frame_ms`.

## Standing points (vsync off, 10 s)

| Point | pos (end) | avg fps | 1% low | GPU ms | render CPU ms | worst ms | draws | prims |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sanctuary | (0.70, −0.16, 20.76) | 185.8 | 113.1 | 5.20 | 0.45 | 12.5 | 769 | 987k |
| mid-stair | (0.00, 6.33, −15.40) | 225.1 | 111.5 | 4.25 | 0.35 | 15.9 | 520 | 827k |
| summit facing rift | (3.10, 26.55, −76.11) | 192.8 | 167.3 | 5.02 | 0.31 | 11.7 | 526 | 2748k |

Avg already clears 120 fps at the 960-tall buffer. The gap to a stable 120 is **1% low ~112** at sanctuary and mid-stair (worst frame 12–16 ms), and the 769 draw calls at the sanctuary. Summit is GPU-comfortable but throws ~2.7 M primitives (rift / far terrain).

## What this does *not* capture

- HUD sharpness / canvas stretch (1.6). Overlay still upscales with the 3D buffer.
- Metal driver (2.12). This baseline is Vulkan/MoltenVK only. Godot 4.7's macOS default is native Metal; the packed app uses that. Re-run `--perf-baseline` with `--rendering-driver metal` vs `vulkan` and keep the faster.
- Player motion. Velocity was zeroed for the sample; walking will add CPU.

## Phase 2 remeasures

All later rows use exclusive fullscreen, same 1529×960 buffer, vsync off, `--perf-baseline`.

### 2.1 Sky `PROCESS_MODE_QUALITY` (TIME removed from `vortex.gdshader`)

QUALITY + `TIME` in the shader GGX-filters the cubemap every frame and **regressed** GPU ~2.7 ms. Spin is now `sky_time` (global uniform); cubemap pass is still TIME-less so radiance bakes once.

| Point | avg fps | 1% low | GPU ms | Δ GPU vs 0.2 |
| --- | ---: | ---: | ---: | ---: |
| sanctuary | 196.6 | 117.5 | 4.90 | −0.30 |
| mid-stair | 229.2 | 67.9 | 3.88 | −0.37 |
| summit | 205.7 | 108.5 | 4.58 | −0.44 |

### 1.6 + 2.2 canvas_items HUD, grade `filter_nearest`

3D stays 1529×960 @ 42%. Grade now runs on the 2D canvas (~1920×1205), not the 960 3D buffer, so GPU ms rose vs 2.1. Grain is an integer hash; screen texture no longer builds mips.

| Point | avg fps | 1% low | GPU ms | 3D |
| --- | ---: | ---: | ---: | --- |
| sanctuary | 140.2 | 85.7 | 6.74 | 1529×960 @ 42% |
| mid-stair | 157.4 | 102.3 | 5.94 | 1529×960 @ 42% |
| summit | 140.8 | 85.8 | 6.65 | 1529×960 @ 42% |
