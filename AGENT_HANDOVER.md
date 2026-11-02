# Umbral Reaches — agent handover

Godot **4.7.2**, Forward+, GDScript, Jolt physics. One playable zone (*Stair of Ascension*) of a
dark-fantasy action RPG. Singleplayer first; small-scale MMO is a long-term aim, nothing in the
codebase assumes it yet.

Snapshot taken 31 Oct 2026. **Stale in places** (no Vale, no combat, 1080 cap, macOS zip export, unused cloth shader). Current playbook: `.cursor/skills/`.

---

## 1. Read this before touching the pipeline

These are all things that have already cost real debugging time.

1. **Bake with a GPU context, never `--headless`.** Under headless, baked `MultiMesh` instance data
   does not survive and the forest floor comes back empty. Use
   `xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/bake_main.gd -- --quit`,
   or just run it from the editor.

2. **A `MultiMesh` needs `custom_aabb` set explicitly.** A baked one reloads with an empty AABB and
   every instance is culled. `_ground_cover()` already does this — keep doing it for any new kind.

3. **Half of `world/zones/ascension/` is generated.** `environment.tres`, every `*_mesh.res` /
   `*_shape.res`, and `bake_info.gd` are written by `tools/bake_main.gd`. Hand-editing them is
   silently lost on the next bake. Change the generating function instead (fog lives in `_fog()`).

4. **Never modify a macOS binary after export.** Godot ad-hoc signs the bundle during export. Any
   later change to the Mach-O (`llvm-lipo -thin`, stripping, re-zipping the binary) invalidates the
   signature, and combined with Gatekeeper's quarantine flag the app dies with "can't be opened".
   Ship the universal binary untouched.

5. **A new `class_name` script is invisible to `-s` tool scripts until the project is rescanned.**
   Run `godot --headless --path . --editor --quit` once after adding one.

6. **`tools/capture.gd` is ~45 s per view under software rendering.** Pass
   `--only=forest_left,floor_close` to limit it. Fast on real hardware.

---

## 2. Pipeline

| Task | Command |
| --- | --- |
| Bake the world | `godot --path . --rendering-driver vulkan -s res://tools/bake_main.gd -- --quit` |
| Regenerate textures | `python3 tools/gen_textures.py` and `python3 tools/gen_foliage.py` |
| Export | `godot --headless --path . --export-release "macOS" build/out/UmbralReaches.zip` |
| Look-dev stills | `godot --path . --rendering-driver vulkan -s res://tools/capture.gd -- --out=/tmp/shots --only=floor_close` |
| Rig animation sheet | `godot --path . --rendering-driver vulkan -s res://tools/anim_sheet.gd -- --out=/tmp/anim` |

Export presets: `Windows`, `Linux`, `macOS` (universal, ad-hoc signed).

**When a rebake is required:** changes to `tools/bake_main.gd`, the `height()` terrain function,
foliage placement, materials built in `_materials()`, or the environment.
**Not required** for pure script edits (player, rig, UI, settings) — those are packed at export.

---

## 3. Architecture

### Autoloads
| Name | Role |
| --- | --- |
| `Events` | Global signal bus. Gameplay emits; UI, VFX and audio only listen. |
| `LightGrid` | Registry of safe light zones. Linear scan — swap for a spatial hash past ~64 zones. |
| `InputSetup` | Builds the InputMap in code, so no `.godot` input state to sync. |
| `Settings` | Persisted graphics/camera settings. `apply()` emits `changed`; the disk write is debounced 0.75 s and flushed on menu close. |
| `Travel` | Portal fade + spawn payload across `change_scene`. |

`world/main.gd` listens for `Settings.changed` and pushes values into the live window, environment,
lights and camera. Settings is pure data; main.gd is the only thing that applies it.

### Equipment system — the pattern for new content
```
core/util/procmesh.gd            static mesh + material builders, no state
core/items/equipment_piece.gd    Resource. One primitive piece, data only. duplicate()-safe.
core/items/staff_piece.gd        subclass overriding build() for compound items
core/items/lantern_piece.gd      ditto
core/player/default_loadout.gd   the character's look as (socket, key, piece) data
core/player/character_rig.gd     skeleton joints as named sockets + equip() / unequip()
```
The rig owns joints and animation; pieces own geometry. A new armour set is new `EquipmentPiece`
instances, never rig code. The same piece instance is reused for both sides of a symmetric body —
`build()` only reads it.

Sockets: `pelvis`, `chest`, `head`, `hood_peak`, `hip_l/r`, `knee_l/r`, `foot_l/r`,
`shoulder_l/r`, `elbow_l/r`, `hand_l/r`. Staff equips on `hand_r`.

Nights share `core/world/zone.gd`. Physics layers: world=1, player=2. Groups: `Groups.PLAYER`,
`INTERACTABLE`, `LIGHT_SOURCE`, `SHADE`.

### Shaders
| File | Purpose |
| --- | --- |
| `world/sky/vortex.gdshader` | The rift sky. |
| `world/post/grade.gdshader` | Full-screen colour grade driven by Gloom. |
| `world/zones/foliage.gdshader` | Alpha-scissor cards. Coordinated wind wave + player parting. |
| `world/zones/lava.gdshader` | Chasm floor. Self-contained value-noise crust, HDR emission. |
| `core/player/robe_cloth.gdshader` | **Unused.** Cloth was removed; safe to delete. |

Two things not to undo in `foliage.gdshader`: it uses `world_vertex_coords` specifically so the
sway needs no per-vertex `inverse(MODEL_MATRIX)`, and the player-parting reads the global shader
parameter `push_pos`.

### Global shader parameters
`push_pos` (`vec3`) is declared in `project.godot` under `[shader_globals]` and written every
physics frame by `player.gd`. Foliage bends away from it. If you add another, declare it there or
the shader will not compile.

---

## 4. The gameplay loop

Away from light, Gloom rises (3.6/s, 6.3/s past the rift at `z < -40`). At 100 a shade spawns and
flies at the player; reaching a lit brazier unmakes it, being touched Hollows you back to the last
kindled brazier. Braziers are the checkpoints. The chasm floor is lava and kills on contact.

---

## 5. Performance

**Target: 120 fps minimum at 1920×1080. Not yet measured on hardware** — take a baseline first.

- Render resolution is hard-capped at 1080p. `main.gd::_apply_resolution_cap()` drives
  `Window.content_scale_size` to the window's aspect clamped to 1080 tall, so fullscreen on a
  Retina panel renders ~1720×1080 and upscales. Smaller windows stay native.
- **F8** runs a 10 s benchmark: avg, 1% low, render resolution, draw calls. Result goes to stdout
  and is pinned in the F3 overlay.
- F3 also shows `v<version> · baked <timestamp>` so you can confirm which build is running.

Already done: MSAA off + FXAA (the scene is nearly all alpha-scissor foliage, the worst case for
per-sample coverage); shadow maps 4096 → 2048; moon shadow throw 60 → 38 m; canopy shadows off
(alpha-tested shadow casting across every split and every point light); brazier shadows
distance-faded at 22 m; fog volume depth 64 → 32 and length 80 → 55 m; SSAO quality low; the
per-vertex matrix inverse removed from the foliage shader.

Remaining suspects: volumetric fog, SSAO, and the draw-call count from ~139 foliage chunks.

---

## 6. Controls

`WASD` move · mouse look · `Shift` sprint · `Space` jump · `E` kindle · `F1` grade ·
`F2` settings · `F3` stats · `F4` render scale · `F8` benchmark · `F9` demo walk ·
`F11` fullscreen · `Esc` free mouse. Partial gamepad support (sticks, jump, kindle, sprint).

---

## 7. Smoke tests

| Flag | What it proves |
| --- | --- |
| `-- --test-shade` | Spawn → hollow → respawn. Prints `SMOKE` lines, exits itself. |
| `-- --demo --quit-after-demo` | Autopilots the whole zone kindling braziers. Prints `SMOKE demo_done`. |

Both need a GPU context and are slow under software rendering. The shade test is the quick one.

---

## 8. Known gaps

Deliberate, in priority order — the project is mid-polish-pass, so finish polish before adding
systems:

- **No audio of any kind.** The game falls back to a dummy driver. Largest single absence.
- The character body is still a primitive placeholder (cylinders, spheres, a void face). Its own
  docstring says so. Biggest visual weakness, and it is in every frame.
- No foot IK — feet hold a fixed angle, so they float or sink on the stair and on slopes.
- No combat; `cast()` is cosmetic. One enemy type.
- No main menu, no pause menu (the settings menu pauses, nothing else does), no key rebinding.
- No save/load across sessions; the checkpoint is in-session only.
- Trees have no LOD.

A fuller, itemised polish checklist with the performance plan lives in the project roadmap doc the
owner holds — ask for it rather than re-deriving the list.
