# Umbral Reaches — Game Audit (3 Nov 2026)

## Method

The audit used the real project in Godot 4.7.2 (Forward+, Jolt), checked six ways:

- A full type-checked compile of every script.
- The headless autopilot demo route.
- Scripted walk tests: the Ossuary route, the summit approach, the lift lane, the bridge gap.
- A floor-ray grid over the summit.
- Spawn placement against light radii.
- A save round-trip across two launches, plus in-game renders.

**Look and feel you have signed off are deliberately left alone:** the hub stair and spawn-area stone, and the player robe.

## Findings and status

| # | Area | Finding | Severity | Status |
|---|------|---------|----------|--------|
| 1 | Progress | No save game: kindles, relics, checkpoints and the hollow count were lost on quit | P0 | **Fixed**: `Travel` saves to `user://savegame.cfg` 0.6 s after any change, loads at boot, and continues at your last brazier. "Erase Saved Progress" is in Settings (two-step); `-- --fresh` ignores the save. |
| 2 | World | `seat_props.gd` snapped every brazier to the terrain, so the Landing and Threshold braziers sat on the chasm floor and two checkpoints were missing from the climb | P0 | **Fixed** (session 1c): only props within 2 m of the terrain are snapped. |
| 3 | Audio | One bus for everything; no volume controls | P1 | **Fixed**: SFX and Ambience buses are created at runtime, every player is routed, and Master, Effects and Ambience sliders sit in Settings (saved). |
| 4 | Audio | No ambience: silence between sounds | P1 | **Fixed**: two seamless 18 s beds (`amb_night` wind and drone; `amb_ossuary` crypt drone, drips and bone ticks), equal-power crossfaded by area. |
| 5 | Combat loop | Kills gave nothing back; Gloom only punished | P1 | **Fixed**: −6 Gloom per kill within 28 m, with a violet wisp to the player. |
| 6 | Enemies | Hub camps all sat inside the StairFoot light and piled up at its edge; enemies re-aggroed the tick after giving up | P1 | **Fixed** (1c): five spread camps, a 3.5 s calm-down, and strict stair probing. |
| 7 | Streaming | A forced load (continue or respawn into an area) was time-sliced, so the player could fall before the floor existed | P1 | **Fixed**: `Area.instant` builds in one go on forced loads; verified the player continues onto solid floor. |
| 8 | Assets | The Ossuant was a recoloured husk | P2 | **Fixed**: bone armour (crowned skull mask, spurred pauldrons, outer ribcage, spinal ridge, bone fauld) on the flesh material, so flash and dissolve still work. |
| 9 | Perf | The hotbar resolved key labels through InputMap and DisplayServer for 5 slots every frame | P2 | **Fixed** (1c): cached, refreshed every 0.5 s. |
| 10 | Perf | The Ossuary build (0.3–0.8 s) ran in one frame at boot | P2 | **Fixed** (1c): time-sliced into 5 frames, or instant on forced loads. |
| 11 | Tools | `tools/bake_caps.gd` points at the removed Vale zone | P3 | Noted; not runtime. |
| 12 | Content | Only the Ossuary exists beyond the hub; the summit portal and Ember Rift are planned | — | Roadmap: `docs/ZONE_PLAN.md` P2–P5. |

## Verified after the fixes

- **Compile:** 0 failures.
- **Walks:** the Ossuary route, summit approach and lift lane walk clean, and the Rift Step clears the bridge gap.
- **Save:** a save written on launch 1 restores on launch 2 (spawn at the Ossuary gate on solid floor, fire lit, relic kept).
- **Kill reward:** Gloom 50 → 44 after a kill.
- **Skills and spawns:** Nova variants, the Shade, and spawn placement all pass.
