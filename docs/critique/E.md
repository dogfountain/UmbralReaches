# Critique E: visuals and performance (r29)

Agent E. Lens: shadows (the "weird shadow lines"), lighting, materials, terrain and flora shaders,
the grade, sky and fog, anti-aliasing, VFX quality, LOD and culling, frame pacing, hitches, memory,
the loading screen. Severity: S1 breaks or looks broken, S2 clearly hurts, S3 polish.
Status: FIXED (by E), REG (in register.md for its owner), OPEN (noted, not acted on), LEAD (for the lead / Luke).

All runs used an isolated HOME (scratchpad/critE/home), Travel._busy held, every tool quits itself.
Luke's own settings.cfg was read (never written) to reproduce what he plays with.

## Tools written for this pass

- `zz/perf_lines` (new): the real player camera at Luke's output (1920x1080 window, 3D capped at 960
  rows, Cinematic, fov 90): stills, a moving-camera filmstrip of a crop (`--strip=N --move=m/frame
  --turn=rad/frame --crop=`) with a flicker number (mean |dL| between frames, share of pixels jumping
  > 10/255), `--debug=2` lighting only (shadow artefacts with no texture to hide them), `--debug=14`
  PSSM splits, `--moon= --rs=atlas:N,filter:N,fogvol:WxD --env= --grade= --set=` overrides,
  `--scaling=bilinear|fsr|full --fsr_sharp=`, `--shader=res://a=/abs/b` (A/B any shader edit in
  memory), `--flame=r,g,b`. Files: shots/critE_lines_<view>_<tag>.png (+ _strip).
- `zz/perf_tour`: `--moon=k:v --rs=atlas:N,filter:N` overrides once the Realm is built; attrib gained
  `--reps=N` with the median pair (the machine is shared by six agents: a 2-pair mean swung from
  +0.05 to +6 ms for the same feature) and the features "moon r29 setup (vs r28)", "moon atlas",
  "moon filter", "upscale fsr (vs bilinear)", "native rows". Fixed: `--luke` resized the window to
  1920x1080 and then straight back to 1600x1000 on the next line, so every "--luke" number since r25
  was taken at 1600x1000.
- A 9-phase gradient meter (scratchpad gd/period.gd): mean |dI/dx| by x mod 9 and |dI/dy| by y mod 9,
  which is how the upscale grid below was found.

## Findings, worst first

### E1 S1 FIXED: the "weird shadow lines" are moon shadow acne on open ground
Where: every open stretch of terrain and path under the moon at High shadows: the village green, the
hill road west of spawn, the fen, the cart. What: curved parallel bands along the ground, one per
shadow-map texel row, that crawl as the camera moves. In the lighting-only view they are plain
(shots/critE_shadowlines_before.png, _spawn_before.png, crop critE_shadowlines_crop_before_after.png);
in the graded frame they read as faint stripes that move (filmstrip critE_shadow_filmstrip_before.png).
Why: r25 raised normal bias 0.9 -> 1.8, which cleared the one cart view, but the bias was still too
small for the soft-shadow blocker search (angular 2.5 deg) on the 1024 atlas: two splits over 30 m at
fov 90 put far texels at ~10 cm, and the sloped ground read as its own blocker along each texel row.
Isolation (lighting-only, spawn): fog off, SSAO off: lines stay; shadows off: gone; atlas 4096 alone:
lines finer but still there; filter Medium: still there; bias 0.1 or normal bias 3: gone.
Fix (core/world/light_policy.gd `_moon`, one place now): bias 0.035 -> 0.06, normal bias 1.8 -> 2.5,
and on High the near split 0.1 -> 0.25 x 30 m = 7.5 m (the old 3 m boundary ran right under the
wanderer's feet with its blend band), fade from 0.8. Atlas stays 1024, filter Very Low. Atmosphere._moon
no longer sets the shadow (the two copies had drifted: fade 0.82 there, 0.78 here). The atlas size and
filter are now set from LightPolicy too (MOON_ATLAS / MOON_FILTER per shadow quality), so a crisper
setup is one constant away.
Proof: shots/critE_shadowlines_before|after.png and _spawn_before|after.png (lighting only: no bands
at spawn, hill road, thornwood, henge, fen, cart), crop pairs critE_shadowlines_crop_before_after.png,
moving filmstrips critE_shadow_filmstrip_before|after.png (spawn, lighting only, 4 cm/frame: mean
frame-to-frame dL 1.20 -> 0.50; hill 0.78 -> 0.54). No peter-panning: fence, villager and staff
shadows still meet their feet.
What it costs and what was left out (perf_tour --attrib --reps=6, Cinematic, 4x pixels, median pair;
hub A/B in alternation): the bias and split change cost nothing measurable. A 2048 atlas gives
visibly crisper contact shadows for +0.22-0.31 ms (hub -1.5..2 % fps, two A/B rounds): over the
"no worse than r28" budget, so left out (`MOON_ATLAS[2] = 2048` turns it on). 4096: +1.1-2.3 ms more.
Soft filter Low: +1.0-2.6 ms (it does remove the fine grain in penumbras, E4). Four splits: +355 shadow
draws, +560k primitives (over the 900-draw / 1.5 M budget). A 34 m reach: +34 shadow draws.

### E2 S2 FIXED: a 9-pixel grid over the whole frame (bilinear 8/9 upscale)
Where: everything, at Luke's output: the 3D renders 960 rows (Settings.render_height_cap) and was
stretched to 1080 bilinearly. What: every 9th row and column is sharp and the ones between are soft;
the gradient energy of the frame swings 1.54x (x) and 1.86x (y) with a 9-px period (spawn, grass).
The grade's unsharp mask then draws that grid out, and as the camera moves the texture slides under a
fixed grid: fine crawling lines. This is there with shadows OFF, i.e. at Luke's saved settings.
Fix (core/world/zone.gd `_apply_render_scale`, a 4-line edit in F's file, noted in the register):
below 1:1 the upscale is FSR 1 with its least RCAS sharpening (fsr_sharpness 2.0). Measured: period
swing 1.33x / 1.54x, and the frame is much closer to native 1080 (scratchpad v/g_up2.png: bilinear |
FSR | native). Native rows (no upscale) would remove it entirely but costs ~27 % more pixels.
Cost: not measurable here (at 1x the Mac paces at 120 Hz; under --stress the scale is > 1 and FSR is
off); FSR 1 is two full-screen passes at 1080p, expected ~0.1-0.3 ms on the M4 Pro. OPEN for the lead
to confirm on the AOC: if Luke's frame is GPU-bound there, this is where it would show.

### E3 S1 FIXED: every lit brazier's flame was a soft white sheet
Where: all 7 braziers (Sanctuary at spawn, Stair Foot, Landing ...), from any distance.
What: a glowing white-blue rectangle above the bowl (shots/critE_brazier_flame_before.png; it is
white with the grade off too, so not the grade). Why: world/brazier_flame.gdshader is unshaded +
additive and wrote only EMISSION; in unshaded mode the colour is ALBEDO, which defaulted to white, so
each crossed card added a white sheet scaled by its alpha. Fix: the card writes ALBEDO, with a hot pale
core low and central, an orange body, deep-red tips that fade before they get dim enough for the
grade to pull them blue, and a tongue that narrows as it rises (critE_brazier_flame_after.png,
critE_spawn_before|after.png). The particle Flame was tested at a third of its energy: no change, it
was never the culprit. (The file sits in world/, nearest owner F; registered as done.)

### E4 S3 OPEN: fine grain in soft-shadow penumbras
The Very Low soft filter shows its sample pattern as a fine screen-fixed grain in penumbras (lighting
view crops). Filter Low clears it but costs 1.0-2.6 ms at 4x pixels. Left at Very Low; TAA (now an
option) animates it away for those who use TAA.

### E5 S2 FIXED (register, from A): the grade turned every strong red blue
world/post/grade.gdshader pulls every hue outside 205-236 deg into the band at full strength and
protected warm only from 8 to 66 deg: health bars, red telegraphs, blood and hit sparks went
blue-violet. Fix: saturated, lit reds (-20..12 deg, S > 0.5-0.65, V > 0.28-0.45) keep their hue;
dull or dark red-browns (stone, timber, earth) still go blue under the moon, so the r21 night is
unchanged. Also: bright near-white pixels that lean warm (r > b, not green) keep their colour (a
clipped fire core lost its warmth to the azure split tone).

### E6 S2 FIXED (register, from B): leaves fill the frame when the camera backs into a crown
core/world/realm/flora/realm_foliage.gdshader: cards dither away (IGN screen-door, no alpha pass)
inside `near_fade` 1.6 m of the camera (fully gone under 0.56 m). The directional shadow pass sees a
far-off "camera", so shadows are unchanged. Also seen in my own thornwood view (dE sheets).

### E7 S3 FIXED (register, from C): orphan names at exit from realm_ground.gdshader
The global const arrays SCALE / LAYER_CS are local consts in fragment() now.

### E8 S2 LEAD: Luke's saved settings have shadows OFF
~/Library/Application Support/UmbralReaches/settings.cfg (read only): quality_preset=2 but
shadow_quality=0, ssr on, motion_blur 0, fov 90, fps_limit 120, vsync off (13:02 today). Either Luke
turned shadows off to get rid of the lines, or something wrote it. With shadows off the remaining
"lines" he could still see are E2 (the upscale grid), which is now fixed too. Worth asking him to
turn High shadows back on and look again.

### E9 S2 OPEN: Luke's spike log shows a sustained drop at the cart
user://perf_spikes.log (his, 13:29): "frame 16.0 ms (median 8.4) ... draws 620 prims 599k | particles
188 omni 88 spot 3 enemies 37 ... at (15.3, 1.0, 13.6)": more than 0.5 s at 60 fps by the cart with
shadows off. 37 enemies awake and 188 particle systems is the outlier against the hub numbers.
Not reproduced in the time left (needs his save's state: enemies alive near the village).

### E10 S3 FIXED: perf_tour --luke never ran at Luke's window (see Tools).

### E11 S3 REG (to F): far casters drawn into the moon shadow
At spawn_west (census, exact counts): Area_ossuary draws 0 visible but 21 shadow draws / 48.6k
primitives, HollowLantern 15 / 40k, RealmRift 26 / 74.5k of the 441k shadow primitives.

### E12 S3 REG (to D): the white hart reads as an untextured placeholder
By the long house at the cart: flat-shaded, low-poly, near-white with orange rim light
(scratchpad v/elk.png, from shots/critE_lines_cart_base.png).

### E13 S3 REG (to C): the Keg's ceiling is a black void
From inside the tavern the ceiling takes no light and shows only a faint grid
(shots/critE_lines_tavern_gafter.png). The windows now show the night outside (fixed by someone this
pass: they were flat orange panels in the first shot, critE_lines_tavern_base.png).

### E14 S3 OPEN: the grade's sharpen is not AA-aware
The unsharp mask (sharpen 1.85, 1-px kernel, output resolution) re-crunches what FXAA/SMAA/TAA
smooth: with FXAA the texture detail goes soft and the sharpen puts the jaggies' contrast back
(shots/look_aa_aa*.png). Suggest scaling sharpen with the AA mode (Off/MSAA 1.0, SMAA 0.6, FXAA 0.45,
TAA 0.5) in Zone._apply_aa; left for the lead because the crunch is Luke's chosen look.

### E15 S3 OPEN: motion blur is IGN-jittered without temporal change
The smear's per-pixel jitter (IGN) is fixed to the screen, so a long smear shows a faint diagonal
pattern. Animating the jitter needs TAA to resolve it; left.

## Measurements

Hub, Cinematic --stress=2, A/B alternated (A = r28 shadows + pre-r29 grade and foliage shaders loaded
in memory, B = r29); machine shared with five agents, A2 disturbed:
| point | A1 | A2 | B1 | B2 | r28 handoff |
|---|---|---|---|---|---|
| spawn_west | 83.7 | 81.4* | 82.6 | 82.7 | 84 |
| meadow | 81.2 | 60.1* | 80.3 | 80.4 | 82 |
| spawn_north | 80.3 | 75.5* | 80.1 | 80.2 | 80 |
| tavern_in | 73.5 | 73.1 | 72.2 | 73.2 | 74 |
B is within run-to-run noise (A1 vs an earlier A run of the same build differed by 3 %); shadow draws
+10 at spawn_west (the 7.5 m near split holds a few more casters), primitives +5k.

Luke's pacing (perf_tour --preset=2 --luke, 1920x1080 now for real, vsync, 144 cap, shadows High):
all 17 Realm points hold 120 fps, worst frame 8.3 ms, except one 16.7 ms frame (a missed vsync) at
spawn_west and at barrows. The path WITHOUT the loading warm-up: one 134 ms frame at the fen descent
toward the Ossuary gate (46, 1.8, -61) (a first-sight shader compile). With the real loading screen
(--loading): whole path 119.9 fps, 1 % low 114.3, worst 16.7 ms, no frame over 33 ms: the warm-up
covers it, including the r29 shader changes. The r28 "38 ms in the tavern" did not recur.

zz/check: CHECK DONE bad=0. zz/quit_probe: exit 0 (windowed and --verbose); realm_ground's orphan
names are gone; the remaining leak lines are F's register entry (a particles shader).

## Register entries answered

- to:E S3 realm_ground.gdshader orphan StringNames: fixed (E7).
- to:E S2 grade pulls reds blue (from A): fixed (E5).
- to:E S2 flora vs camera (from B): fixed (E6).
