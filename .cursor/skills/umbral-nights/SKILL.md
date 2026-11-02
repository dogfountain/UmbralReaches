---
name: umbral-nights
description: Stair of Ascension content facts. Use when editing stair, main.tscn, crystals, shards, sky, fog, braziers, stones, particles, or zone dressing.
---

# Nights

Playable night: Stair of Ascension. Extends `Zone` and must call `finish_zone_setup()` last. Dress at runtime. Do not headless-rebake `world/main.tscn`.

Crimson Vale has been removed — next night is TBD. Do not restore `vale.tscn` / `vale_dress` / `vale_palette` unless the owner asks for a new night from scratch.

| Night | Scene | Palette / sky |
| --- | --- | --- |
| Stair of Ascension | `world/main.tscn` + `world/main.gd` | `vortex.gdshader`, realtime (`process_mode` 3). Incremental sky (`process_mode` 2) **freezes TIME**. `SkyFlare` is a moon halo only — no anamorphic streak. A shader compile error on that material draws a solid white rectangle in front of the camera. |

## Crystals vs shards

- **Keep** EmberCrystals and CrystalLights on the Stair.
- **Shards off**: `glimmers.skip_shards = true`. Those are the random diamond lights.
- `seat_props.gd` seats existing crystals; do not delete them to "clean up".

## Stair

- Gothic = lights only. Four lanterns.
- Lava kills on contact; Area mask must be `Layers.PLAYER`. Surface named `Surface` must skip atmosphere vis-range (name match used to cull it at ~57 m). Emission ~7.4, `light_class` `lava`.
- Summit portal removed with the Vale; do not re-add a glass to a missing night.
- Demo walk / F8 bench live here.

## Particles

Thin heavy fields only (rift/spirit ~0.22, ember/spore/firefly ~0.30, spark ~0.38). **Never thin brazier flames.**

Staff run trail is a player concern (`character_rig.gd`), not zone particles.
