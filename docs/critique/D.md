# Critique D: life and sound (r29)

Lens: wildlife, weather, night phenomena, the regional ambience and music, and the mix of every sound
in the game. Severity: S1 breaks or sounds broken, S2 clearly hurts, S3 polish.

## How this was measured

- **Level table of every sound** (`zz/critD_levels.tscn`, headless, ~1 s): builds or loads every
  stream (art/audio files from their 16-bit sources, Synth kinds and creature voices, the staff, the
  village's work sounds, NPC syllables, LifeSynth, ScapeSynth beds/spots/music voices), measures peak
  and loudest-100 ms RMS, then adds the level the game plays it at (volume_db, its usual distance with
  Godot's inverse-distance attenuation and the max_db 3 cap, its bus at default settings): the level
  at the listener. `shots/critD_levels_before.tsv` / `_after.tsv` (173 sources).
- **Real mixes of game moments** (`zz/critD_mix.tscn` under Godot's Movie Maker, `--write-movie`,
  fixed 60 fps): the engine's own mix through every bus, reverb, low-pass and the 3D panner. Nine
  moments: village, rest by the spawn fire, heath, wood, fen, a storm (a near crack + a far roll),
  drizzle in the wood, a fight (two wretches, a husk, bolts, a Nova, a Lance), the Keg. Loudness with
  ffmpeg (EBU R128 LUFS, LRA, true peak), peaks per 50 ms, spectrograms. `--sfx-trace` (new in Sfx)
  logs every one-shot with its name, level and distance.
- **Wildlife script time** (`zz/critD_lifeprof.tscn`): at the fen, each kind's tick and buffer write
  timed alone, then the live director after everything near takes fright (the busy case);
  `--no-glide` for A/B. life_test's own perf line as before.
- **Renders from the player camera**: zz/world_shots (storm, rain, meteors, surge, mist, wisp, hart,
  owl, fox, lapwings, tracks) -> `shots/critD_world_*.png`, before/after pairs for what changed.

## Findings in D's area

| # | Sev | Where | Issue | Evidence | Status |
|---|---|---|---|---|---|
| D1 | S1 | Master bus | **Fights clipped.** No limiter anywhere: a hit, the wanderer's hurt, a creature call and a spell landing together summed to 0.0 dBFS (true peak +0.1) twice in the render, -0.8 in the staged fight. On speakers that is a crackle. | mix before: 47.10 s and 97.65 s peak 0.0 dBFS; fight -0.8 | **Fixed**: AudioEffectHardLimiter (ceiling -0.5 dB) last on Master; the same stream re-fired within 40 ms and 4 m is turned down 4 dB per repeat. After: no 50 ms window over -2.5 dBFS in any moment (fight -2.5). `shots/critD_fight_before/after.wav` |
| D2 | S2 | scape_music.gd | **The music was inaudible.** Pads at -47/-50 dBFS, lyre -42, bell -43 at the ear, under beds at -25..-33. Resting by a fire sounded like no music at all. | levels table; `shots/critD_music_rest_before/after.png` (the lyre's notes and harmonics now stand out of the bed); `critD_rest_before/after.wav` | **Fixed**: the layer +12 dB (now pads -35/-38, lyre -30, heartbeat -28.5), on its own Music bus (F's slider; follows the Ambience slider if Settings had none). |
| D3 | S2 | weather.gd | **Rain was under the beds.** A full storm measured 1.6 LU over a clear night: rain at -41 dBFS under the night bed's -31. Crickets sang on through a storm. | mix: heath -30.0 LUFS vs storm -28.1 | **Fixed**: rain beds +7..10.5 dB, crickets -85% and meadow -50% in rain. After: storm -25.2 LUFS (4.5 LU over the clear heath), drizzle in the wood 4 LU over the dry wood. `critD_storm_before/after.wav` |
| D4 | S2 | weather.gd + new storm_veil.gdshader | **A storm did not look like one.** The vortex sky stayed bright and clear through drizzle and storm; only thin streaks and a bolt said "weather". | `shots/critD_storm_before.png`, `critD_rain_before.png` | **Fixed** (deepened): rain clouds roll over the sky in the sky layer (a sphere round the camera, dark slate masses thickening with rain and thunder, drifting with the wind, lit from within by the flashes); a temporary effect, hidden when clear, shown in the loading warm-up. `critD_storm_after.png`, `critD_rain_after.png` |
| D5 | S2 | weather.gd | **Mist banks missed the fen.** A probe found 3 of the fen's 4 banks against its west edge and none over the pools: banks only drifted with the wind and wrapped at the region's edges. Banks were also thin. | `zz/critD_mist_probe` before/after; `shots/critD_mist_before/after.png` | **Fixed**: each bank keeps a home hollow (the lowest of 14 spots, 22 m from the others) with a soft pull back to it; density x1.55. The view across the fen now has haze in depth (subtle; volumetric fog only reaches 40 m). |
| D6 | S2 | life_pond / life_birds | Frog chorus at 15 m 9 dB under the fen bed (never heard as a chorus); crows 11 dB under owls. | levels: frogs -41, fen bed -32.6; crow -38 vs owl -26.5 at 20 m | **Fixed**: chorus -15 -> -10 dB, crow -13 -> -8, heron -11 -> -8. |
| D7 | S3 | weather.gd | The wind bed at full gust (-35 dBFS) was under the night bed: a gusts front did not sound windy. | levels | **Fixed** +4 dB. |
| D8 | S2 | life_* groups, weather | **Script time over budget in the worst case** (lead's isolated suite: world_react_test 545 us, life_test 447; owls 99, crows 80). Causes found with zz/critD_lifeprof (`--thunder` reproduces life_test's end state) and a per-section probe: dictionary-heavy logic ticking every frame near the camera; every MultiMesh buffer rebuilt from dictionaries each tick and re-sent unchanged; an Array per animal per tick for the threat; terrain lookups per walking bird per tick; frog throats driven from script; the field mice simulated out of sight; a 40-group scan every frame; weather easing banks, beds and Environment offsets every frame with dictionaries built per frame. | lifeprof, react/life per-kind lines | **Fixed** (see "Wildlife script time" below): life_test 447 -> 300/311/317 us, world_react_test 545 -> 311/278/295 us on three consecutive runs. |
| D9 | S2 | life_director | **Stepping on a fast screen.** Busy groups past 16 m ticked at 30 Hz (15 Hz past 45 m) with nothing in between: on a 144 Hz screen a crow at 30 m jumped ~6 px every 4-5 frames; near groups' heads and pecks were tied to the tick. | 7 m/s at 30 m = 0.23 m per 33 ms tick | **Fixed**: logic and drawing are split. Between ticks a group in view *glides*: redrawn every frame from packed copies the tick made (velocity, head/pitch turning toward their goals, strides, a mouse's run, a frog's leap, a splash ring), touching only the rows that move; still groups skip it. |
| D10 | S3 | life_director | Groups within 16 m ticked every rendered frame (2.4x the 60 Hz cost at 144 Hz). | code | **Fixed** with the glide: logic 10-15 Hz near (herds 30, a pool 10 unless you are on its bank), drawing every frame. |
| D11 | S3 | sfx.gd | A third of all one-shots in the render (95 of 285: the village's anvil and spade 50-70 m away) were played past the 34 m cut-off: silent, but each took a pool voice a fight could need. Voice stealing took the round-robin slot even if it started this frame; freed voices were only noticed via voice 0. | `--sfx-trace` of the render | **Fixed**: sounds beyond 36 m from the camera are not played; the longest-started voice is stolen; any freed voice rebuilds the pool; non-finite positions ignored; `--sfx-trace`. |
| D12 | S3 | phenomena.gd + ghost.gdshader | The white hart could appear in the village (start_hart took any open "meadow" ground 40 m ahead) and, near-white and diffuse-lit, a lantern or window painted it orange: a placeholder look (E's register entry). | `shots/critE_lines_cart_base.png` | **Fixed**: never within 50 m of Hearthward; mostly its own cold light, more translucent. `critD_hart_before/after.png` |
| D13 | S3 | art/audio/amb_night.wav | The night bed is an 18 s loop with two swells (6.5 s, 12.5 s): a regular breathing every 18 s while you stand still. | spectrogram | **Fixed**: a detuned twin (pitch 0.94, half a loop on, each -3 dB) so the swells drift apart. |
| D14 | S3 | weather.gd | Rain "on a roof" was heard deep in the Ossuary (the ray up hits rock, so "roof"). | code | **Fixed**: surface "under" in the Ossuary's room: no rain bed. |
| D15 | S3 | ambience / caches | AudioStreamWAVs held in static caches past engine shutdown ("leaked at exit"; F's entry). | quit_probe --verbose | **Fixed for D's files** (Ambience._exit_tree stops its players and clears ScapeSynth/LifeSynth/Sfx). |
| D16 | S3 | scape_music.gd | The danger music came on for a camp asleep behind a hill (any enemy within 20 m, awake or not). | code | **Fixed**: only enemies that are processing (awake) count. |
| D17 | S3 | ambience.gd, life_director.gd | Weather looked up without validity checks; `_on_kill` tested `is Node3D` before `is_instance_valid`. | code | **Fixed**. |
| D18 | S3 | life_synth / scape_synth | Everything synthesised for the world is 22.05 kHz: nothing above 11 kHz, so rain, leaves, crickets and wind lack air next to the 32 kHz staff and 44.1 kHz files. | levels table `rate` column | Open (a 32 kHz resynthesis changes every GenCache entry and memory: its own pass). |
| D19 | S3 | life_flock placement | Lapwings feed where the tallgrass is taller than they are: from a low camera the feeding flock is hidden (it reads well once up). | `shots/critD_world_lapwings_feed.png` | Open: needs a grass-height query from the flora (E). |
| D20 | S3 | zz/world_shots | The wisp and owl views are framed into a trunk / at grass height. | `critD_world_wisp.png`, `_owl.png` | Open (harness framing only). |
| D21 | S3 | weather | Rain streaks are thin and faint at 1080p; rain mostly reads through the sound and splashes now. | `critD_rain_after.png` | Open (polish). |

## Outside D's files (registered in register.md)

| Sev | Owner | Issue | Evidence |
|---|---|---|---|
| S2 | A | Creature tells (the audible warning of an attack) reach the ear at -28..-32 dBFS from 9 m, 13-17 dB under the wanderer's own bolt (-15) and Nova (-11.6): in a fight your casting masks them. | levels table, `creature` vs `staff` |
| S3 | A | Boosts over +3 dB (boss roar +4, deeper bell +6, arena chime +4) do nothing up close: AudioStreamPlayer3D caps volume+attenuation at max_db 3; Sfx voices stop at 34 m. | Godot attenuation code, sfx.gd |
| S3 | B | One set of footsteps for every surface (B has since started surface-coloured steps; a compile slip in it, `Sfx.has_method`, broke every scene for a minute and was fixed). | character_rig `_footstep` |
| S3 | F | No UI sounds anywhere (hover, confirm, back, tabs, sliders); only the Kindling chime. | grep |
| S3 | A, C | Static audio caches (synth, staff_sfx; npc_voice, village_audio) still hold streams at exit. | F's quit_probe entry |

## Before / after

| Measure | Before | After |
|---|---|---|
| Worst peak in any moment (real mix) | 0.0 dBFS (true peak +0.1), twice | -2.5 dBFS |
| Music at the ear (pads / lyre) | -50 / -42 dBFS | -38 / -30 dBFS |
| Storm over a clear heath | +1.6 LU | +4.5 LU (-25.2 LUFS) |
| Rain (open) at the ear | -40.9 dBFS | -30.4 dBFS |
| Frog chorus at 15 m | -41.1 | -36.1 |
| Crow at 20 m | -38.0 | -33.0 |
| One-shots spent on silence (>34 m) | 95 of 285 | 0 (not played) |
| life_test script time, worst state (3 runs) | 447 us (lead's suite) | 300 / 311 / 317 us |
| world_react_test script time, worst state (3 runs) | 545 us (lead's suite) | 311 / 278 / 295 us |
| Busy groups past 16 m | 30/15 Hz steps | drawn every frame (glide), logic 7.5/5 Hz |

Mix moments (LUFS), before -> after: village -29.7 -> -27.9, rest -29.3 -> -27.2, heath -30.0 -> -29.7,
fen -29.0 -> -29.2, storm -28.1 -> -25.2, fight -22.3 -> -22.4 (peak -0.8 -> -2.5), tavern -27.4 -> -23.5
(a Keg scene was singing in the later render). The wood and drizzle "before" moments were a fight
(a camp killed the wanderer mid-render; the harness now clears camps every frame).

## Wildlife script time (lead follow-up)

Targets: world_react_test's final measurement <= 380 us, life_test <= 350 us, three consecutive runs
each, no visible loss on a 144 Hz screen. Per kind (us/frame), lead's run -> a run after:

| | owl | crow | deer | plover | pond | heron | elk | weather | total |
|---|---|---|---|---|---|---|---|---|---|
| life_test | 99 -> 60 | 80 -> 56 | 38 -> 35 | 27 -> 20 | 37 -> 19 | 9 -> 12 | 10 -> 9 | 60 -> 27 | 447 -> 311 |
| world_react_test | | | | | | | | 73 -> 28 | 545 -> 278..311 |

What changed (core/life/wildlife):
- **Logic and drawing split** (director): in view within 16 m, logic at 10 Hz idle / 15 Hz on the move
  (herds 30, pools 10 unless someone is on the bank); further out 7.5/5 Hz on the move, idle birds and
  flocks 5 Hz, herds 20/10 Hz; out of the camera's view 5 Hz and no drawing (ticked the frame it comes
  back). Between ticks the glide draws every frame, from packed copies, only the moving rows.
- **Writes skipped** when a group was still and stays still; the glide sends its buffer directly (the
  tick pads the box for how far a glide can carry anything), no compare/duplicate per frame.
- **Frog throats on the GPU** (creature_rig `throat_auto`): a calling pool carries only the chorus gate;
  its frog loop runs only when someone is near or a frog is in the air; chorus volume set on change.
- **Owls' mice** simulated within 26 m (they are 2 px past that) at 7.5 Hz, carried by the glide,
  clamped to their spot. Heads snap to their goal once within 0.0005 rad (they never quite converged,
  so a perched owl was never "still").
- **No terrain lookups per tick** for feeding lapwings and stalking herons (height set when a spot is
  chosen, eased while walking).
- **Director**: the 40-group reach scan 5 times a second (or after a camera jump) instead of every
  frame; per-kind accounting in packed arrays; `kind_glide_us` and `perf_p50/p90/max` for diagnosis.
- **Weather**: steps at ~40 Hz (every frame only during a flash, a pending thunderclap or a splash grid
  being laid); banks at 10 Hz, beds at 15 Hz; Environment offsets sent once they have moved enough
  (exact at 0); no dictionaries built per frame; particle direction and veil uniforms written on change.
- **Tests**: world_react_test and life_test print the glide share and the director's median/p90;
  world_react_test prints the herd's state if "heads go back down" fails (it failed once in 12 runs;
  cause not reproduced). zz/critD_lifeprof `--thunder` reproduces life_test's end state.

Note on measurement: the same frame's script time measured inside a tight loop is 2-4x lower than in
live frames (cold caches, other processes); the live per-kind numbers swing +-20% run to run, so the
targets were met with margin rather than to the microsecond.

## Tests

All pass at the end: zz/life_test, world_sound_test, world_weather_test, world_react_test,
staff_sfx_test (bad=0), voice_test (bad=0), quit_probe (exit 0), and the new zz/critD_sound_test
(16 checks: Music bus and its level, the limiter, Sfx stacking / pool / freed voice / non-finite /
out-of-earshot / release, rain hushing the crickets, the night twin, no rain bed in the Ossuary, a
lifted flock redrawn every frame). Tools: zz/critD_levels, critD_mix, critD_lifeprof, critD_mist_probe.
