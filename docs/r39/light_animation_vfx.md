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
3. **Fixture pool** (`fixture_pool.gd`). Seven unshadowed omnis are built (class `player_orb`, outside the lamp budget) and three, five or seven of them lent by the detail setting (low, medium, high) to
   the nearest rows without a real light of their own (forge, chapel window, graveyard, mystery) within 34 m,
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
9. **Fog banks** (`fog_banks.gd`). Eight soft mist banks (none on the low detail setting) drift on a turning wind round the wanderer, wrapping at 70 m; within
   reach of a fire or window they glow warm, near a mystery cold. Cost: one MultiMesh of 8 alpha quads.
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


---

# Round two: the sky, the weather, the VFX library, the arenas, the interiors, the palette

All of it is attached by `NightLife` (core/world/night_life/night_life.gd), is switched off live by Settings > Effects > Living Night, and is
written to cost nothing at rest. Each entry gives: what, where to see it, what to film, cost, files.

## 14. The living sky (sky_life.gd, world/sky/vortex.gdshader)
- **What.** The moon has a phase tied to the saved night count (eight nights to a cycle: night 0 full, night 4 new). The disc is drawn as a lit
  sphere (a dot-product terminator); the moon's light scales by it (0.6 at a new moon, 1.0 at full: a thin moon is a darker night, so the
  landmarks shine the more). The eclipse takes the disc, corona and streaks to a tenth and turns them copper, brings the stars and the
  constellations up half again and swells the aurora. Five constellations (the Lantern, the Crown, the Bell, the Anchor, the Long Road) are baked
  once into a 512 x 256 equirect and drawn with one texture fetch. The aurora's strength is a hash of the night count (a faint thread or a great
  curtain). A cloud deck overhead (cover from a hash of the night plus the weather's mist and rain) is lit warm from below over the six strongest fires within
  260 m (passed as a uniform array) and hides the stars behind it. The last tenth of the night puts a grey band low in the east.
- **See / film.** Look at the sky from the Hearthward green on nights 0, 2 and 4 (camp at a fire, 10 minutes apart, to advance the count: `Travel.story["night_no"]`);
  the eclipse at about nine and a half minutes into a session (or set `Reg.clock` to 0.49); the constellations at 40 to 60 degrees up to the east, south and west;
  cloud lit over a fire from 50 m back in drizzle.
- **Cost.** One texture fetch, a six-iteration dot product loop and three fbm octaves in the half-resolution sky pass (a few hundred thousand pixels), nothing per frame in
  script (twice a second). The cube pass is untouched. Zero when the Living Night is off (all terms back to the old sky).
- **Files.** core/world/night_life/sky_life.gd, world/sky/vortex.gdshader, moon_course.gd (phase gain), night_registry.gd.

## 15. Weather made visible (weather_life.gd, realm_ground.gdshader, terrain.gdshader, project.godot)
- **What.** The weather node (weather.gd) already makes fronts, rain, wind and storms; each night now opens on a different front (night count x 5 modulo the cycle:
  night 0 is clear, as before, so a reload brings the same weather). New: a global shader float `wetness` (declared in project.godot) rises over a minute of rain and dries over
  five: the ground goes smoother and a little darker and the lamps' and fires' own GGX highlight shows in it; a ring of 28 puddle glints on a 3 m grid round the wanderer
  (pale sky blue; where a fire or lit window stands near, the puddle takes its colour and a bright streak toward the camera); drips from lit eaves; steam from the nearest
  fire; the far cards swell into halos in mist and rain; fires gutter lower and flicker harder in rain and gusts; lightning flashes every landmark card; at the end of the
  night mist is brought in and the sky gains a grey dawn band.
- **See / film.** `Weather.force("drizzle")` from the debugger, then the green and the Keg: the paving shining under the brazier, glints, drips, steam, halos on the far
  windows; a storm from the hill south-east of Hearthward (vista_realm_from_se): landmark cards flaring with each flash; Reg.clock 0.92 for the mist and grey east.
- **Cost.** One MultiMesh (28 instances, rewritten at 12 Hz only while wet), a global float, two shader terms already paid for, a few pooled bursts a second in rain; nothing when dry.
- **Files.** core/world/night_life/weather_life.gd, light_signatures.gd (haze, flash), night_registry.gd, core/life/wildlife/weather.gd (night opening), world/realm/realm_ground.gdshader, world/zones/terrain.gdshader.

## 16. The VFX library (vfx_library.gd, hit_reads.gd, telegraph_glow.gd, kindling_surge.gd, arena_light.gd)
- **What.** Casts: a rune ring closing at the wanderer's feet over the cast's time in the skill's colour, a burst on completion, ground shock rings for nova, ward and peal, a red
  fizzle on a break. Statuses: a small continuous effect per carrier in its status colour (embers off a scarred foe, more per stack; violet shards from a sundered one; red sparks
  from a shaken one; the mark's motes; resonance violet and surge gold on the wanderer), at most ten carriers and four bursts a second. Pickups: a gold lift and ring. Level-up: a
  tall column of light (one card) over him, two rings, sixty motes, a flash and every landmark flaring (registry pulse). Hits and kills (hit_reads) and tells (telegraph_glow) and
  the kindling surge as in round one; boss phases in arena_light.
- **See / film.** A fight in the Thornwood at night: casting nova, being hit, a foe burning (ember scar), a kill; picking up an item; levelling up; kindling a brazier.
- **Cost.** All Vfx pooled (Vfx keeps its emitters; presets are bounded: a dozen new ones, warmed by the first use in a fight); per-event only; the column is one card.
- **Files.** core/world/night_life/vfx_library.gd.

## 17. The arenas (arena_light.gd)
- **What.** Each boss has a three-phase palette for the fog's colour and emission (never its density: the weather owns that), the set-piece lights on the rim (two, three or four
  by the detail setting, unshadowed, class player_orb) and the moon dimmed to two thirds while the fight lasts. A phase change is marked (two rings and a burst at the boss, a flash,
  the landmark cards flaring, the lights surging). A wipe, a kill, a fast travel or the Living Night off eases everything back.
- **See / film.** The Thornwarden (green, then crimson, then blood red), the Bone Abbot (candle gold, bone blue, ember), the Ascended Warden (ivory and gold, white-blue, blinding white), the Anchoress (drowned teal, deep blue,
  cold white), the Speaking Crown (brass, violet, furnace): film each at the pull and at each phase from 12 m.
- **Cost.** Up to four unshadowed lights while a boss is up and a handful of colour writes a frame; nothing otherwise.
- **Files.** core/world/night_life/arena_light.gd, night_registry.gd (arena_dim), moon_course.gd.

## 18. The door and the rooms (interior_light.gd, interiors.gd)
- **What.** The camera inside a registered room (Interiors.at) eases a term (about a third of a second) that fades the mist banks, puddle glints, drips, moths' glow, ground pools and lent
  lights out at the door and back in as he leaves, so the threshold dissolves. Every registered room is checked for a light inside its box at 4 s and 34 s after start; a room with none is
  given a warm hearth glow through Interiors.light (director-budgeted and flickering). (The warm ambient and thin fog at the door are the weather's, already.)
- **See / film.** Walk into the Keg, a cottage, the chapel in rain and mist: the mist and glints go out as the door passes; no room is dark.
- **Cost.** One Interiors.at test a frame; two audits of the scene's lights.
- **Files.** core/world/night_life/interior_light.gd, core/world/interiors.gd (a read-only `rooms()`).

## 19. The grade and the palette (region_grade.gd, grade.gdshader, realm_foliage.gdshader)
- **What.** The shadow tint, mid tint and saturation drift by the biome underfoot (old forest a deeper green-teal, fen teal-blue and paler, ruins cooler and stonier, ash and foundry warmer and greyer, crags colder, the glade a little more alive;
  eased at 0.5 per second, never brighter) and warm a touch toward dawn. The grass and the leaf: ground cards give up a share of chroma and take a soft shoulder on value so a tuft never outshines
  what it hides; the grade's saturation push is eased by 24 percent on plain greens (hue 70 to 150 degrees); the near-camera leaf dither narrowed from 1.6 m to 1.1 m (the coarse stipple under a crown).
- **See / film.** A walk from the Hearthward green through the Thornwood to the Fen to the Foundry, and the same views as region_hearth_0, region_fen_0, region_necropolis_0 (grass luminance against the path).
- **Cost.** Three uniform writes while easing, none at rest; shader terms already paid for.
- **Files.** core/world/night_life/region_grade.gd, world/post/grade.gdshader, core/world/realm/flora/realm_foliage.gdshader.

## Cost summary (the lead's check against regions_a, ~8.5 ms average)
Always on, cheap: LightSignatures (2 draws, 16 Hz loop), FixturePool (3/5/7 unshadowed lights by detail), FogBanks (8 alpha quads, none on low), LightMoths (1 draw), MoonCourse, SkyLife, RegionGrade (uniform writes).
Event or condition only: weather_life (wet), vfx_library, arena_light, hit_reads, telegraph_glow, kindling_surge, interior_light. Folk and pets: awake only within 80 m, posed at the villagers' distance rates.
Never mid-play: no mesh, texture or shader is first built after the loading start-up (the constellation and glint textures are generated at attach; the folk rigs are a GenCache hit after the first run).


## 20. Bats at the fires (fire_bats.gd)
- **What.** Every lit brazier in the night registry gathers four bats that circle high over its glow (up to twenty fires); a fire kindled in the dark draws its own within seconds. The wildlife's bat body and its orbit shader do all the
  flying (the instance origin is the fire, the radius, speed, tilt and phase are in its custom data): one draw call, no script per bat.
- **See / film.** The spawn brazier at night from 40 m, a newly kindled fire (bats arrive within four seconds), the vista from the south-east hill (specks wheeling over the fires).
- **Cost.** One MultiMesh of 80 instances, written once as a fire is found; a registry scan every four seconds; visible within 160 m.
- **Files.** core/world/night_life/fire_bats.gd.

---

# The warm-up (frame stutter: nothing is first built in play)

The loading screen (ui/loading_screen.gd) already tours the Realm under its cover and shows the combat set once at the first stop so the engine compiles every world material and
builds every pooled effect there. The living night joins it with `NightWarm.show` (core/world/night_life/night_warm.gd), called where the combat set is shown (one line):
- **Materials, each on the real instanced path the night uses** (a MultiMesh with per-instance colour): the far card, the ground pool, the moth, the mist bank, the puddle glint; plus the
  level-up column, the log and the net (folk), a dog or cat and a bat (the fox creature material and the bat orbit shader, one instance each).
- **Particle bursts.** Every burst the night throws is a named preset in `night_fx.gd` (`NightFx.burst(at, colour, id, dir, ratio)`; a count that varies with a stack is the preset's `ratio`, never a new
  preset). `NightFx.warm_list` lists every (preset, colour) pair, including the fifteen arena palette colours, and the warm-up throws one of each, so every emitter and process material is built and
  pooled before play (Vfx pools by colour and options).
- **Already covered elsewhere**: the five bosses' FX overlay shaders (the loading screen's BOSSES list builds each boss and its rig), the sky shader (drawn from the first frame; the new terms are uniforms),
  the ground and terrain shaders (`wetness` is a term in the shader they already compile), the folk's and villagers' bodies (VillagerRig, GenCache, built behind the cover once the Realm is up).
- **The guard.** `zz/night_life_test.tscn` fails if any file under core/world/night_life or core/life/folk builds a material, a creature group or a burst without being listed in `NightWarm.COVERED`, if
  any file throws a raw `Vfx.burst` instead of a preset, if a preset name does not exist, or if a covered file does not exist. A new system cannot add an unwarmed material.
- **Cost.** One frame group of about fifty small bursts and a dozen quads while the cover is up (about 0.2 s of the tour); nothing in play.
