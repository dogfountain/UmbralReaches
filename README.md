# Umbral Reaches — v0.1 atmosphere prototype

A single playable zone, **Stair of Ascension**, built to prove the look: permanent night, saturated blue world, violet vortex sky, warm light only where there is gameplay.

## Play

| You have | Do this |
| --- | --- |
| Windows | Run `build/windows/UmbralReaches.exe` (unsigned prototype, so SmartScreen may ask: More info → Run anyway) |
| Linux / Steam Deck desktop mode | `chmod +x UmbralReaches.x86_64 && ./UmbralReaches.x86_64` |
| Godot 4.7.x editor | Import `project.godot`, press F5 |

Needs a GPU with Vulkan or Direct3D 12 (Forward+ renderer).

**Controls:** WASD move · mouse look (click to capture) · Shift sprint · Space jump · E kindle · F1 grade on/off · F2 settings · F3 stats · F4 render scale · F8 benchmark · F9 demo walk · F11 fullscreen · Esc free the mouse. Gamepad: left stick move, right stick look, A jump, X kindle, L3 sprint, View stats.

**The loop:** away from light, Gloom rises (faster near the rift). At 100 a shade takes shape and hunts you. Reach a lit brazier and it unmakes the shade; let it touch you and you are Hollowed back to your last kindled brazier. Kindle all four braziers on the way to the summit. The chasm floor is lava — falling in Hollows you outright.

**Picking this up as a developer or an agent?** Read `AGENTS.md` for how the project is structured, then `AGENT_HANDOVER.md` for the bake/export traps.

## Project layout

```
autoload/      Events, LightGrid, InputSetup, Settings, Travel
core/player/   Player (controller) + CharacterRig (skin) + loadout
core/items/    EquipmentPiece wearables (staff, lantern)
core/util/     Groups, Layers, ProcMesh
core/world/    Zone shell, Interactable, braziers, mirrors
core/enemy/    shade.gd
ui/            hud.gd, settings_menu.gd, fonts/Cinzel (OFL)
world/         main.tscn (Stair of Ascension; Vale removed)
art/           textures, materials, models
tools/         bake_*.gd — do not headless-rebake shipped scenes
assets/        provenance.csv
```

## Rebuild from source

```sh
python3 tools/gen_textures.py                      # tileable painted-style textures
godot --headless --path . --import                 # import them
xvfb-run godot --path . --rendering-driver vulkan -s tools/bake_main.gd   # bake world/main.tscn; needs a real renderer (headless drops MultiMesh data)
godot --headless --path . --export-release "Windows" build/windows/UmbralReaches.exe
godot --headless --path . --export-release "Linux" build/linux/UmbralReaches.x86_64
```

The zone is assembled by `tools/bake_main.gd` and saved as a normal scene, so everything is visible and editable in the editor. Re-running the bake overwrites `main.tscn`. Once you start hand-placing things, stop re-baking or move hand edits to a separate scene.

## Tests and capture (user args go after `--`)

```sh
godot --path . -- --demo --quit-after-demo --shots-dir=/tmp/shots   # autopilot walks the zone, kindles every brazier, saves screenshots
godot --path . -- --test-shade                                      # forces full Gloom in the dark: expects spawn, Hollowed, respawn
godot --path . --write-movie demo.avi --fixed-fps 30 -- --demo --quit-after-demo   # deterministic video capture
```

Smoke lines print as `SMOKE ...`. v0.1 results: all 4 braziers lit, Gloom 0 at the summit; shade spawned, Hollowed, respawned at the sanctuary with Gloom 0.

## Measured look (palette check on the demo screenshots)

| Shot | Coloured pixels in 200–290° | Median brightness | Near-black |
| --- | --- | --- | --- |
| Sanctuary | 99.9% | 0.180 | 42% |
| Stair foot, brazier lit | 94.4% | 0.180 | 45% |
| Mid-stair (between lights) | 99.9% | 0.118 | 61% |
| Landing, brazier lit | 91.1% | 0.114 | 61% |
| Summit, brazier lit | 94.6% | 0.227 | 29% |
| Gazing into the rift | 98.0% | 0.247 | 32% |

The mid-stair runs darker than the 0.18 target on purpose (that is where Gloom presses in), so it is the first thing to retune if it reads as too dark on a real monitor.

## Known limits of v0.1

- Characters are primitive-built placeholders (hooded wanderer, shade); no skeletal animation yet.
- No audio yet.
- One zone, one mechanic; no combat, classes, loot or saves.
- Performance is unprofiled on real hardware (verified on a software renderer only). Press F3 in game for fps and draw calls.
