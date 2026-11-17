# Light, the living night, VFX and animation (branch r39-light)

Direction (Luke): not a brighter night. A DARKER moon, a dark land, and bright LANDMARKS: fires, braziers, beacons,
lit windows and glowing mysteries that read from far away and pull the wanderer across the dark. The contrast between
the dark land and the lit places is the look. Nothing here lifts the fill, the ambient, the volumetric ambient inject,
black crush or the vignette.

Every system below is built in `core/world/night_life/` and attached by one line in `world/main.gd`
(`NightLife.attach(self)`, after the atmosphere). `Settings > Effects > Living Night` (Settings.night_life, saved)
switches all of it off live (cards hide, lent lights go dark, the moon returns to its fixed place).

## What changed in the constants (small)

| Where | Old | New |
|---|---|---|
| `Atmosphere.MOON_ENERGY` | 1.5 | 1.05 |
| `Atmosphere.MOON_FOG` | 0.35 | 0.22 |
| LightPolicy ILLUM `beacon` | 0.55 / 1.05 | 0.85 / 1.15 (energy / range) |
| ILLUM `lamp` | 0.62 / 1.0 | 0.85 / 1.05 |
| ILLUM `village` | 1.0 / 1.05 | 1.3 / 1.1 |
| ILLUM `kept_lamp` | 0.48 / 0.9 | 0.7 / 1.0 |
| grade hurt wash | 0.75 mix, clamp 0.5..1.0 | 0.5 mix, clamp 0.4..0.85 (`zone.gd`, `grade.gdshader`) |
| danger_zone outline / floor / fill | 0.07 / 0.025 / 0.07 | 0.11 / 0.045 / 0.10 (wider line, visible floor, stronger fill) |

FILL_ENERGY, ambient, ambient inject, black_crush and vignette are untouched.

## The features

1. **Landmark light signatures** (`light_signatures.gd`, `night_registry.gd`). Every brazier (lit: warm fire card; unlit: a faint cold
   glint that asks to be kindled), every `world_poi` host, stable and watch post gets a row classed by name as fire,
   window, tower or mystery. Far cards (one MultiMesh, billboard, additive, fog-free, depth-tested, 24..410 m, fixed
   angular size like a star, fires gutter, windows steady, towers pale gold, mysteries breathe) and ground pools
   (a second MultiMesh, 0..70 m) of warm or cold light on the ground under the source. See: the vista from the
   south-east hill, the road between settlements at night, any camp from 100+ m. Cost: 2 draw calls, a loop over a few
   hundred rows every 0.06 s, six ground raycasts per frame at the start.
2. **Mystery lights** (`mystery_lights.gd`). Every unfound secret (`State.sites`, core/life/secrets) shows a cold teal light
   on the secret itself, visible from afar, with motes drifting up within 70 m. Found: a flare (ring, burst, flash)
   and the light goes out for good. Following the light always leads to a secret. See: the Hollow Oak, barrow, Pilgrims'
   Chapel; walk toward the light, the secret banner arrives with the flare.
3. **Fixture pool** (`fixture_pool.gd`). Ten unshadowed omnis (class `player_orb`, outside the lamp budget) are lent to
   the ten nearest rows without a real light of their own (forge, chapel window, graveyard, mystery) within 42 m,
   eased in and out, so forges, windows and ruins pool real light on stone and trees without hundreds of lights.
4. **Living windows** (`living_windows.gd`). Every cottage with `WindowTrail_n` shafts has a bedtime: lit at dusk in turn, a third
   lit all night, the rest out between 55 and 95 percent of the night (three flickers, then dark); the warm pane
   material (`LitBody` emissive surfaces, duplicated per house) dims with its light, the far card follows. Late at
   night a dark house stirs and lights as the wanderer passes within 9 m. See: Hearthward through the night.
5. **Moon course** (`moon_course.gd`). The night is 25 minutes: the moon crosses 40 degrees of bearing, rides higher and whiter at
   midnight, its light breathes and clouds take a quarter now and then; the NightFill, the sky's moon direction and the
   flare follow. Yields for 25 s if another system (the Henge raid) drives the moon's energy.
6. **The eclipse** (same file). Once per run at half the night: copper warning (toast), 45 s of totality (moon at a tenth,
   fill halved, sky dimmed, every landmark card and lent light up by half, the wanderer's lantern swells) and the moon
   returns (toast). Eased out and held back while a boss is engaged. See: about 9.5 minutes into a session
   (or set `Reg.clock` to 0.49 from the debugger).
7. **Kindling surge** (`kindling_surge.gd`). Kindling a brazier throws a wide heat ring, embers, a flash, and the fire's far
   card surges to double and settles over six seconds; every unkindled brazier within 180 m glints brighter for 20 s.
8. **Light moths** (`light_moths.gd`). Moths circle the five nearest fires, windows and mysteries (cold slow motes at
   mysteries), flicker as their wings catch the light, scatter up and out when the wanderer runs past, and come to his
   own lantern after he has stood still for two seconds.
9. **Fog banks** (`fog_banks.gd`). Twelve soft mist banks drift on a turning wind round the wanderer, wrapping at 70 m; within
   reach of a fire or window they glow warm, near a mystery cold. Cost: one MultiMesh of 12 alpha quads.
10. **Hit reads** (`hit_reads.gd`). Heavy hits and criticals add a shock ring tinted by damage school; criticals a gold starburst and
    flash; a kill lets go a rising column of motes, a ring and a ground-lighting flash. DoT ticks stay quiet. Budgeted
    to 8 effects a second.
11. **Telegraph glow** (`telegraph_glow.gd`, `danger_zone.gdshader`). A caster is lit from below in amber, swelling across the cast
    and pulsing in the last quarter; interruptible casts are cold white-blue with a closing ring; a broken cast snaps
    (sparks, ring, flash). The ground zone itself reads stronger at night.
12. **Villager fidgets and crowd de-sync** (`core/life/village/villager_fidgets.gd`, hook in `villager_idle.gd`, desync in
    `villager.gd`). Six new standing gestures (neck scratch, shading the eyes, hands on hips, a yawn, blowing into cupped
    hands, tapping a foot); each villager's walking speed varies +-8 percent and starts at its own gait phase, so
    no two walk in step.
13. **Wanderer life** (`wanderer_life.gd`). Still near a lit fire he reaches a hand to warm it (with embers rising to the hand);
    still nine seconds he reaches toward the moths; during an eclipse his lantern swells.

## What the lead must check in the engine (nothing was run)

- Parse: `godot --headless --path . --import --quit` then the quick tier. New files have no `.uid` yet (the import writes them).
- `GeometryInstance3D.custom_aabb` on the MultiMeshInstance3D nodes, `QuadMesh.orientation = PlaneMesh.FACE_Y`, and
  billboard + MultiMesh scale (cards must be round soft points, not edge-on slivers).
- Far cards from 100 to 400 m on a clear vista; the pools on slopes (they sit 7 cm above the ground, may float on steep
  ground; lower `POOL_FADE_B` if they look wrong).
- Windows: do the `LitBody` emissive surfaces dim per house (it needs `StandardMaterial3D` with emission); if a village's
  panes stay lit the lights still follow and the far cards go out.
- Frame time of `LightSignatures._draw`, `FogBanks._process` and `FixturePool` (expect well under 0.1 ms); no hitch at
  the first frame (the one scan of `WindowTrail_*` runs once, 5 s after load, with a find_children over the tree).
- The eclipse toast and totality at about clock 0.5, and that the Henge raid's moon still works.
- Moon course: shadows creeping must not shimmer; the vista scenes that read the moon once (star crater glints, plume)
  are fixed to the start bearing (a 20 degree swing is the most they can be out).
- Settings toggle: Living Night off restores the moon and hides everything at once.
