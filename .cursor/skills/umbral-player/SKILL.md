---
name: umbral-player
description: Wanderer, camera, staff, gloom, and combat facts for Umbral Reaches. Use when editing player, CharacterRig, loadout, HUD crosshair, staff trail, magic bolt, movement, or gloom.
---

# Player

Last verified 2026-11-04 against `core/player/player.gd`. Since 2026-11-06 `player.gd` keeps state, signals, exports and the tick order; the logic is in `core/player/player_*.gd` components (see ARCHITECTURE.md). Public names are unchanged.

`Player` (`CharacterBody3D`) owns move, camera, gloom, interact, cast. `CharacterRig` owns skeleton, sockets, stride, loadout. Talk through `animate()`, `cast()`, `equip()` — never bone names.

## Look (do not rewrite)

- Robe **pieces** + procedural stride. Dark void face.
- Wave shader on cloth (`robe_wave.gdshader`). Not silver. Not purple `arcane_robe.gdshader`.
- Staff on `hand_r` only. Left arm swings. Gauntlets and boots stay.
- Stop generating new body meshes unless the owner asks. Prior "refine the character" passes were rejected.

## Camera / HUD

Over-the-shoulder so the crosshair is not on their back:

- `_arm.position.x = 0.95`
- `_cam.h_offset = 0.12`
- Stair spring length 3.7

Crosshair: `ui/hud.gd`, 48×48 center, plus + dot, lilac/cream.

## Staff

- One-hand. Trail quiet while running: `amount_ratio` / lifetime drop toward 0.16 / 0.38 at sprint (`character_rig.gd`).
- Cast: `magic_bolt.tscn` from the Zone's `BoltPool`; Rift Bolt cooldown 0.28 (`core/skills/skill_bolt.gd`). Skills live in `core/skills/` behind `SkillBook`. `cast()` is no longer cosmetic.
- Layers: player body `Layers.PLAYER`, mask `Layers.WORLD`. Bolt masks WORLD.

## Move / gloom

- Walk 4.5, sprint 7.5, jump 5.2, air (double) jump 5.8. Hold Space to keep jumping on landing (`is_action_pressed` + `velocity.y <= 0`). Step-up walks ledges up to `STEP_MAX` 0.45 m; mantle to 1.1 m (about 2.4 m with a jump); plus slide, hang, climb, vault, roll. Floor snap 0.5, floor max angle 46°.
- Gloom `gloom_rate_dark` 0.75/s away from light (about 2 min 13 s to a full bar), `gloom_rate_rift` 1.25/s in the Starwater Rift (the old chasm, region `rift`); sprinting in the dark ×1.5; each kill drains 6. Drain 12/s in LightGrid zones. A live boss arena keeps `Player.FIGHT_GATHER` (0.28) of that place's rate, and sprint still multiplies; the clock does not pause. 100 spawns a shade; touch Hollows to last kindled brazier. Lava Hollows on contact (`Area` mask **must** be `Layers.PLAYER`).
- `push_pos` is a project shader global, written every physics frame from `player.gd`. Declare new globals in `project.godot` or shaders fail to compile.

## Composition

Sockets: `pelvis`, `chest`, `head`, `hood_peak`, `hip_l/r`, `knee_l/r`, `foot_l/r`, `shoulder_l/r`, `elbow_l/r`, `hand_l/r`. New armour is `EquipmentPiece` data, not rig edits. Collision capsule on Player only.
