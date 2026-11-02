---
name: umbral-donts
description: Binding owner rejections and do-not-undo art for Umbral Reaches. Use before making models, robes, gothic architecture, shades, portals, glow, crystals, or stones, and when a request sounds like restore/rebuild/refine those.
---

# Do not undo

These were tried, rejected, and cost hours. Do not recreate them. Do not "improve" by going back.

## Rejected assets (never restore)

- `art/models/gothic_bay.glb` and `art/models/toad.glb` as **level meshes**. Gothic is **lights only**. Toad is a runtime prop via `vale_toad.gd`, about `(5.81, 0.65, -1.75)`.
- Bead-arches, blob guardians, mint glass panes, paper-strip robes, Sketchfab priest.
- Cape, hem, asymmetric sleeves, oversized shade, silver cloth, purple `arcane_robe.gdshader` on the wanderer.
- Wide fire bloom, far DoF, 1440 internal height, summit-portal terrain snap.
- Draping Path or snapping Step / Base / Deck to terrain.

The owner said the generated modelwork was terrible and to **stop rewriting** the wanderer and shade. Refine in place only if they ask. Staff, gauntlets, boots, void face, robe pieces + procedural stride stay.

## Glow and camera budget

Do not widen:

| Knob | Value |
| --- | --- |
| Glow intensity | 0.62 |
| Bloom | 0.06 |
| HDR threshold | 1.15 |
| Glow levels | 0 and 1 only |
| Internal height cap | 960 |
| Far DoF | off |
| Player lantern shadows | off |

Saved preset is Cinematic; `dof_enabled` stays false. Stair: four lanterns only. Arch walkable: `ARCH_W` 1.16, `ARCH_Y0` 0.46.

## What their words actually mean

| They said | They meant | Not |
| --- | --- | --- |
| Remove stones around the bridge | Shrine ring menhirs + baked Posts/Piles | All world stone |
| Remove the crystal on the bridge | Shrine Heart + AltarLight only | EmberCrystals / CrystalLights |
| Random diamond lights | GlowShards octahedrons from `glimmers._scatter_shards` | Existing crystals |
| Delete all the glb stuff | Stop using rejected generated/Sketchfab meshes as levels | Wipe every glTF |
| Gothic | Window spots / hero lights | Bead-arch architecture |
| Deploy / pack | Linux `.pck` into the Downloads app | Rebake or macOS export |

If a request is ambiguous, prefer **runtime dress** over rebake, and prefer **hide/skip one node** over deleting a whole class of props.
