# Umbral Reaches: Perfecting What Is Already There

A production bible. Critique of the live prototype, then the work that finishes those systems in place.

**Godot 4.7.2 Forward+.** Two nights. Playable pack: Linux `.pck` inside `/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app`.

**This file is the document.** It is not a one-page plan. Read it as a handbook: each chapter is as-is, critique, then a perfection pass that stays inside existing nights, existing types, and the do-not-undo list.

**Supersedes** `DARK_FANTASY_REVIEW.md` for “what to do next.” That review is a 31 October snapshot. Its bloom numbers and “wire gothic architecture” advice contradict the live glow budget and the rule that gothic is lights only. Quote it as history, not as law.

**Does not supersede** `.cursor/skills/` or `.cursor/rules/`. When this bible and a skill disagree, the skill wins.

---

## How to read this

1. **Verdict** — what the game is, what it is not, what “perfect” means here.
2. **Law** — constraints that every later chapter already assumes.
3. **Chapters 1–59** — systems, nights, exact edit passes, then operating procedure.
4. **Appendix** — file map, signals, layers, rejected art, failure log, pack tests.

Each numbered chapter uses the same four beats:

- **As-is** — files, numbers, what actually runs in the Downloads app.
- **Critique** — where the fantasy holds, where it lies, where the code fights itself.
- **Perfection pass** — concrete edits on existing surfaces. No third night. No third enemy class. No new wanderer mesh. No AudioManager. No GameManager.
- **Done when** — what you would see in play after a pack, not after an editor F5.

Pack after visual or gameplay edits:

```sh
godot --headless --path /Users/luke/UmbralReaches --import --quit
godot --headless --path /Users/luke/UmbralReaches --export-pack "Linux" "/tmp/Umbral Reaches.pck"
cp "/tmp/Umbral Reaches.pck" "/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app/Contents/Resources/Umbral Reaches.pck"
codesign --force --deep --sign - "/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app"
touch "/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app"
date "+%H:%M:%S"
```

Quit and relaunch. Quote the Finder time. Do not headless-rebake `world/main.tscn` or `world/vale.tscn`. Do not pkill the owner’s Godot editor. `godot --check-only` hangs; do not use it.

---

## Verdict

Umbral Reaches is a dark-fantasy night walker. You are a hooded wanderer with a staff and a belt lantern. Away from kindled fire, Gloom rises. At 100 a Shade takes shape and hunts you. Kindle a brazier and the Shade unmakes; let it touch you and you Hollow back to the last kindled fire. The chasm floor is lava. A mirror at the summit remembers another night: the Crimson Vale, rose aurora, green river, unlit deck you must kindle yourself.

That loop is real. It is also unfinished.

The README still describes v0.1: one zone, no combat, no audio, primitive characters, unprofiled performance. The live game has two nights, a staff bolt, Wretch and Husk camps, Travel between mirrors, quality presets, and a Mac play path that is a Linux pack inside a signed app. Agents that read the README first will “fix” the wrong game.

The bones are right:

- Player is a controller. CharacterRig is a skin. Equipment is data plus `equip()`.
- Five autoloads. Signals on `Events`. Groups instead of `get_parent()`.
- A night is a `Zone`. Static mass is baked. Wanderer, portals, glimmers, shades, and enemies dress at runtime.
- Light is gameplay. Glow is budgeted. Gothic is window spots, not a cathedral mesh.

The fantasy is unfinished:

- There is still no audio. Braziers, bolts, Hollows, and the river are silent.
- The Shade is still a cylinder with ember eyes. That silhouette is parked. Its *behaviour* is not: a bolt at full Gloom can delete it and it returns the same frame.
- Melee dummies inherit the wanderer’s staff-carry pose. They strike through walls. You walk through them.
- Kindle does not cleanse Gloom; it only starts a 12/s drain. The lantern is not a LightGrid zone, so “your light” is a lie for the meter.
- Vale’s palette darkens stone; Vale’s dress lightens it. Grass goes icy cyan on a rose night. Portal glass is a hardcoded purple vortex.
- Vale camera spring stays 4.4 m. Stair is 3.7 m. The two nights do not share a body.
- Performance was spent on dual-triplanar overlays, extra canopy shadows, and a stack of river lights in volumetric fog. That pass was rolled back. The Vale still has to *prove* 144 fps with headroom on the owner’s machine.
- Travel fade is not `PROCESS_MODE_ALWAYS`. Open settings mid-hop and the glass freezes.
- Esc is bound to settings and to free-mouse. Settings always wins.

Perfecting Umbral Reaches means finishing those loops and surfaces until the two nights feel like one game that knows what it is. It does not mean a third night, a loot table, a skill tree, or generating a new wanderer.

If you only do five things after this bible, do these:

1. Make the Shade stay dead after a bolt until Gloom has actually fallen.
2. Give Wretch and Husk a melee pose, a body bump, and a strike that cannot hit through a wall.
3. Stop Vale dress from clobbering Vale palette. Tint grass wine. Tint the return glass ember.
4. Put Travel on `PROCESS_MODE_ALWAYS`. Match Vale camera to Stair. Default lantern shadows off in the piece, not later in policy.
5. Put sound on the nodes that make it. Kindle, bolt, Hollow, river, footsteps.

Then pack. Then play the Downloads app. Then stop.

---

## Law

These are not taste. They are owner rejections and engine traps that already cost nights.

### Art you do not restore

- `art/models/gothic_bay.glb` and `art/models/toad.glb` as **level meshes**. Gothic is lights only. The toad is a runtime prop via `vale_toad.gd`, about `(5.81, 0.65, -1.75)` after the grove ray.
- Bead-arches, blob guardians, mint glass panes, paper-strip robes, Sketchfab priest.
- Cape, hem, asymmetric sleeves, oversized shade, silver cloth, purple `arcane_robe.gdshader` on the wanderer.
- Wide fire bloom, far DoF, 1440 internal height, summit-portal terrain snap.
- Draping Path or snapping Step / Base / Deck to terrain.

The owner said generated modelwork was terrible and to stop rewriting the wanderer and the shade. Refine in place only if they ask. Staff, gauntlets, boots, void face, robe pieces plus procedural stride stay.

### Glow and camera budget

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

Saved look-dev preset is Cinematic. `dof_enabled` stays false even if the settings checkbox exists. Stair: four **gameplay** braziers on the climb plus a lit sanctuary; gothic window kit is three stations. Arch walkable: `ARCH_W` 1.16, `ARCH_Y0` 0.46.

### Architecture

- Autoloads stay at five: `Events`, `Settings`, `Travel`, `LightGrid`, `InputSetup`.
- No GameManager. No AudioManager. World sounds live on the node that makes them.
- Compose, do not inherit, for Player and CharacterRig. Enemy types inherit `Enemy`. That split is intentional.
- Find things with groups. Spawn into `get_tree().current_scene`.
- Pause is `get_tree().paused`. Settings is `PROCESS_MODE_ALWAYS`. Travel fade must keep running. Do not use `Engine.time_scale = 0`.
- New content is a scene or a Resource. Equipment is `EquipmentPiece` plus `equip()`. Portal targets stay `@export` paths on `MirrorGate`.
- Bake static architecture in `tools/`. Runtime dresses player, portals, glimmers, shades, enemies.
- Never headless-rebake `main.tscn` or `vale.tscn`. MultiMesh AABBs wipe. Forest floor vanishes.
- Pack Linux `.pck` into the Mac app. Do not rewrite the Mach-O.

### What their words actually meant

| They said | They meant | Not |
| --- | --- | --- |
| Remove stones around the bridge | Shrine ring menhirs + baked Posts/Piles | All world stone |
| Remove the crystal on the bridge | Shrine Heart + AltarLight only | EmberCrystals / CrystalLights |
| Random diamond lights | GlowShards octahedrons from `glimmers._scatter_shards` | Existing crystals |
| Delete all the glb stuff | Stop using rejected generated/Sketchfab meshes as levels | Wipe every glTF |
| Gothic | Window spots / hero lights | Bead-arch architecture |
| Deploy / pack | Linux `.pck` into the Downloads app | Rebake or macOS export |

If a request is ambiguous, prefer runtime dress over rebake, and prefer hide/skip one node over deleting a whole class of props.

---

## Stale paper

Agents keep rediscovering the same lies because three documents still describe October.

**`README.md`** says one playable zone, no combat, no audio, characters are placeholders, performance unprofiled. Combat exists. Two nights exist. Audio still does not. Update the README only when asked; until then, this bible is the current map.

**`AGENT_HANDOVER.md`** is stamped 31 Oct 2026. It is wrong on Vale, combat, height cap (1080 vs 960), gloom rates (3.6/6.3 vs 2.0/3.5), settings applied only in `main.gd` (now `Zone`), export path (macOS zip vs Linux pck), and Esc (free mouse vs settings). `AGENTS.md` already says prefer skills when the two disagree. Believe `AGENTS.md`.

**`DARK_FANTASY_REVIEW.md`** asked for bloom 0.18, gothic architecture, far DoF, and a guardian. Owner later rejected all of that. Section 0.6 parked modelling. Do not implement rev 1.

**`vale_palette.gd` and `vale.gd` headers** still say “violet night.” The sky is rose/gold aurora. Fire is the only warm thing. Comments that say violet will make the next agent hue-shift the Vale back to Stair leftover.

**Skills vs code, small drifts this bible treats as bugs:**

- `umbral-player` still quotes gloom 3.6/6.3. Live is 2.0/3.5.
- Skill mentions `robe_cloth.gdshader`. Wanderer cloth is `robe_wave.gdshader`.
- Constraint text says four stair lanterns. Gothic rig is three window stations. Gameplay braziers on the Stair are Sanctuary (lit) plus StairFoot, Landing, Threshold, Shrine.
- Rule text still says two physics layers and “capsule on Player only.” Live layers are WORLD, PLAYER, HURTBOX, INTERACT, PROPS. Enemies have capsules.

---

# 1. What the game is now

## As-is

**Engine.** Godot 4.7.2. Forward Plus. Jolt. Physics interpolation on. Main scene `res://world/main.tscn`. Version `0.1.0`. User data dir `UmbralReaches`. Shader global `push_pos` (`vec3`) is declared in `project.godot` and written every physics frame from `player.gd`. Do not add a new global without declaring it; shaders will fail to compile.

**Nights.**

| Night | Scene | Script | Far plane (then atmosphere) | Identity |
| --- | --- | --- | --- | --- |
| Stair of Ascension | `world/main.tscn` | `world/main.gd` | 82 m | Violet vortex, lava chasm, four climb braziers, summit mirror |
| Crimson Vale | `world/vale.tscn` | `world/vale.gd` | 68 m | Rose aurora, green river, unlit deck brazier, return mirror |

There is no title scene. Boot is the Stair. F5 in the editor and the Downloads app both start there.

**Autoloads (exactly five).**

| Name | Path | Role |
| --- | --- | --- |
| Events | `autoload/events.gd` | Signals only |
| LightGrid | `autoload/light_grid.gd` | Linear scan of safe light zones |
| InputSetup | `autoload/input_setup.gd` | InputMap in code |
| Settings | `autoload/settings.gd` | Persist + `changed`; `PROCESS_MODE_ALWAYS` |
| Travel | `autoload/travel.gd` | Fade + spawn payload across `change_scene_to_packed` |

**Content that exists.**

- Wanderer: `Player` + `CharacterRig` + `DefaultLoadout` (robe glTFs, gauntlets, boots, staff on `hand_r`, lantern on pelvis).
- Combat: `MagicBolt` (1 damage, speed 28, life 2.6 s). Shade at Gloom 100. Wretch (3 HP) and Husk (5 HP) on `enemy_spawner.gd` (3 Stair sites, 6 Vale sites).
- Interactables: `Brazier`, `MirrorGate`, lava kill volume.
- Dress: `dressed_props.gd`, `demo_dress.gd`, `vale_dress.gd`, `seat_props.gd`, `stone_bodies.gd`, `gothic.gd` (lights), `glimmers.gd` (shards off), `vale_toad.gd`.
- UI: `ui/hud.gd`, `ui/settings_menu.gd`, Cinzel OFL.
- Lab: `world/lab/light_lab.tscn` is not a night.

**Play path.** The owner plays the Downloads Mac app. That bundle loads a Linux pck. Script, shader, and player changes pack. Architecture mass does not, unless you GPU-bake (never headless).

## Critique

The project already has a professional spine. Feature folders. Signals. A night shell. Runtime dress so look-dev does not require a bake. That is rarer than it sounds, and it is why the last month of work could swap skies and enemies without destroying the forest floor.

The presentation of the project still pretends it is a weekend atmosphere test. README, handover, and some file headers describe a game that no longer exists. That is not cosmetic. Every new session starts by “adding combat” or “adding a second zone” that are already there, or by “restoring gothic” that was rejected.

The play path is unusual on purpose (Linux pck in a Mac app). It is also undocumented in README, which still talks about Windows exe and a macOS zip. If the owner’s only playable is the Downloads app, then “done” means packed, codesigned, touched, Finder time quoted. Editor F5 is not a ship.

## Perfection pass

1. Keep this bible as the current map until README is rewritten on request.
2. Do not add a sixth autoload for convenience.
3. Do not add `player.tscn` if it requires rebaking both nights to parent it. Dress the baked Player in `_ready` instead (snap, spring length, offsets).
4. Treat `light_lab.tscn` as a bench, not a night, in any future UI.

## Done when

An agent reading only `AGENTS.md` plus this file can name both nights, both enemy types, the five autoloads, the pack command, and the do-not list without opening README.

---

# 2. Fantasy and tone

## As-is

The promise is dark fantasy: scarce warm light in a saturated night, colour only where something is alive or burning, a sky that is a place not a backdrop.

**Stair** keeps that promise when you stand in the dark between braziers. The vortex sky is violet. Unlit stone is cool. Lava is the one hot wound. Crystals along the rift read as path lights because `apply_illumination` multiplies fill energy. Grade `grade.gdshader` protects teal window light and blood-adjacent reds from collapsing into magenta.

**Vale** is supposed to be the other temperature: rose/gold curtains, wine fog, green river as the living thing, fire still the only warm human light. `vale_aurora.gdshader` and `grade_vale.gdshader` (crimson band 340–20 with wrap) are the identity. `violet_amount` on caps is forced to 0.

**Wanderer** is a void-faced robe, not a hero face. Staff orb is lilac. Lantern is amber. That split — cold self, warm tool — is the character.

## Critique

The Stair is closer to the promise. The Vale still contains leftover Stair temperature: icy grass tints (`vale_grass` / `vale_fern` overwritten to about `(0.52, 0.72, 1.05)`), a purple portal pane, a violet toad rim spawned after hue remap, comments that say “violet night,” and dress that brightens stone after the palette darkened it. The player feels that as “this night does not know if it is crimson.”

Colour pop was a live request. The correct reading is: crush the unlit world, let crystals, lava, river, and flame stay HDR. The incorrect reading, already attempted, is to raise bloom. Bloom is locked. Illumination policy (`apply_illumination`) is the legal way to make coloured lamps light the ground.

The wanderer must stay almost black. Prior “refine the character” passes produced silver cloth, purple arcane robes, capes, and paper strips. All rejected. The fantasy of the wanderer is negative space with a staff. Enemies were allowed to be fleshed dummies *because they are not the wanderer*. Mixing those two contracts — giving enemies the staff pose, or giving the wanderer enemy flesh — would collapse the silhouette language.

## Perfection pass

- One Vale albedo for stone/path, owned by `vale_palette.gd`. Dress must not clobber it.
- Retint Vale grass and fern toward olive/wine in the palette dict only. Keep `alpha_cut` and `push_pos`.
- Drive `portal_glass` from `MirrorGate.fire_color` so Stair glass stays lilac and Vale glass goes ember.
- Hue-pull the toad rim the same way leftover violet lights already get pulled.
- Do not touch wanderer robe meshes. Do not put `arcane_robe.gdshader` on the wanderer.
- Do not widen glow.

## Done when

A still of the Vale approach (existing capture path is fine) reads rose sky, dark wine ground, green water, warm deck fire if kindled, and no cyan field. A still of the wanderer still reads as a hole in the night with a staff, not as a textured human.

---

# 3. The night as a loop

## As-is

The loop is Gloom.

Away from LightGrid: +2.0/s. On the Stair past `rift_z = -40`: +3.5/s. Vale sets `rift_enabled = false` on the baked Player, so the Vale has no rift rate. Inside a LightGrid zone: −12/s. At 100, `player.gd` spawns a Shade 16 m behind. A lit zone dissipates the Shade. Shade touch calls `hollow()`: 0.9 s fade, teleport to `checkpoint`, Gloom 0. Lava Area (mask `Layers.PLAYER`) Hollows on contact. Kindle (`Brazier.interact`) sets checkpoint and registers the brazier on LightGrid (radius 11). Sanctuary brazier starts lit. Vale deck brazier is forced unlit in dress.

Travel carries `gloom` and `hollow_count` through the mirror.

There is no “win.” Kindle the fires, reach the glass, walk the other night. F9 demo walk kindles Stair braziers. F8 benches the Stair only.

## Critique

As a toy loop this is elegant. One meter. Light is safety. Dark is death on a delay. The Shade is the meter made flesh. Hollow is the fail state. Lava is the instant fail. You do not need HP.

As a night it is thin.

Kindle does not snap Gloom to 0. You can kindle at 90, stand in the 11 m radius, and wait for the drain. That is honest to “the fire cleanses slowly.” It is also easy to misread as “kindle does nothing.” The toast says the light remembers the place. It does not say you are safe yet.

The lantern does not register on LightGrid. The most characterful light on the wanderer does not affect the meter. So the fantasy “I carry a light” is camera-only. Design can keep that (the lantern is too small to be a sanctuary) but then the HUD should not imply the opposite.

A first Hollow before any kindle returns to spawn, which on the Stair is the sanctuary (already lit) and on the Vale is the gate. That is acceptable. What is not: Shade at 100, player bolts it, Gloom is still 100, Shade spawns again immediately. The fail state has no beat.

There is no lasting Hollow consequence. `hollow_count` travels. Nothing reads it except persistence across the mirror. G2 in the old review (“consequence”) is still true and is still in-place: a deeper vignette, a slower walk for a few seconds, a toast that names the count. Not a new meter.

Finishing a night is undefined. The Stair implies “kindle on the way to the summit and step through.” The Vale implies “kindle the deck and look at the water.” Neither is stated in the HUD after the 16 s hint fades.

## Perfection pass

- On kindle: keep the 12/s drain, and either snap a chunk of Gloom (e.g. −30) or toast “the fire takes the dark slowly” so the rule is spoken.
- After Shade dissipates from a bolt, suppress respawn until Gloom has dropped below a threshold (e.g. 85) or until a short lockout (2 s). Light-zone dissipate can keep instant unmake.
- Read `hollow_count` in the grade or a one-line HUD whisper. Do not add a second bar.
- Do not register the lantern on LightGrid unless the owner asks. Document in this bible that lantern ≠ sanctuary.
- Do not add a quest log. A zone subtitle already exists (`Events.zone_entered`). Use it.

## Done when

Bolting a Shade at 100 does not spawn a second Shade in the same second. Kindling at high Gloom is readable. Vale Hollow before kindle returns to the gate, not into the river.

---

# 4. Stair of Ascension

## As-is

Boot night. `world/main.gd` extends `Zone`. Atmosphere far 82 m. Vortex sky, realtime. Gothic `raise` places three window stations. Summit `MirrorGate` is placed in code, not terrain-snapped. Demo walk and F8 live here. `--test-shade` lives here.

**Mass:** terrain, 60-step stair, sanctuary, ruins, boulders, dead trees, giant trunks, canopy, ForestFloor, rift crystals, lava.

**Braziers:** Sanctuary starts lit at about `(0, sanct_top, 33)`. StairFoot, Landing, Threshold, Shrine start unlit.

**Lava:** `Zone/Lava/Surface` plus `KillVolume`. Emission 7.4. Vis-range skip by Lava ancestor and by name. Extra cull 80. This is the patched “Surface vanished at 57 m because vis-range is to node origin” bug.

**Glimmers:** seed 11, skip corridor, skip shards. Cyan/lilac.

**Player spawn:** sanctuary, about `(0, sanct_top + 0.2, 26.5)`.

**Enemies:** three posts via `seed_stair`, currently about `(-5.5, 5, 12)`, `(5.5, 5, 12)`, `(-5.0, 4, 6)` after ground snap. Wretch, Husk, Wretch.

## Critique

The Stair is the identity night. Permanent dark, one warm grammar (braziers), one wound (lava), one sky (vortex), one destination (glass). When vis-range was applied to the long Stair mesh, the treads faded in, vanished underfoot, then popped back. That is the house trap: **visibility_range is distance to the node origin, not to the mesh.** The stair is one ArrayMesh at `(0,0,0)` that runs tens of metres. Atmosphere now pins span meshes. Do not put vis-range back on `Stair`, `Sanctuary`, `Ruins`, `Terrain`.

Four lanterns in the constraint list and three gothic stations in code are a documentation split, not a missing mesh. Do not add a fourth window to “match the skill.” Do not instance `gothic_bay.glb`. The spots, gobos, and shaft mist are the gothic.

Enemy posts used to sit on the sanctuary lip and in the trees. They idled in LightGrid and looked broken. They now sit mid-stair and leash home. They still animate as if they hold a staff.

The rift Gloom rate past z −40 is Stair-only flavour. It is correct. Keep it off in the Vale.

## Perfection pass

- Leave span vis-range at 0.
- Set floor snap and max angle in `Player._ready` so they are not only baked.
- Melee pose and occupancy (chapter 9) matter more on the Stair than extra props.
- F8 stays Stair-only unless you add a Vale bench later; do not sneak a rebake for markers.

## Done when

Walking the full flight, the stair never fades underfoot. Window spots still read as light, not as floating architecture. Summit glass still sits in air, not snapped into the hill.

---

# 5. Crimson Vale

## As-is

`world/vale.gd` applies palette, then atmosphere (68 m), then `inherit_atmosphere`, then river AABB, six green omnis, toad, glimmers (seed 404, skip river, skip shards), enemies, `finish_zone_setup`, deferred `vale_dress`.

**Mass:** terrain, river, path, shrine (Heart/AltarLight stripped), forest, canopy, ForestFloor, standing stones, boulders, ember crystals, dock, six path lanterns, return mirror, dressed bridge glTF.

**Deck brazier** is moved onto the dressed deck and forced unlit even if the scene says `start_lit`.

**Toad** is `vale_toad.gd` loading `toad.glb` as a prop, raycast from the grove, faces the player.

**Hide under span** scales grass/fern/cap instances to 0.001 in a large AABB along the path corridor.

## Critique

Vale is the night that argues with itself.

Palette says: dark wine stone, rose sky, green water. Dress says: lighten stone and path (path up toward `(0.82, 0.72, 0.78)`). Grass says: icy cyan. Portal says: purple vortex. Toad lamp says: violet. File headers say: violet. The aurora says: crimson. The player believes the aurora and distrusts the ground.

Performance complaints (barely 144 fps) came from stacking: dual world-triplanar plus AO on giant trunks, two extra canopy meshes with shadows turned on by the palette after atmosphere had turned fills off, eleven then six river omnis dumping energy into volumetric fog, extra glimmer omnis, crystal clearcoat. The expensive overlays were stripped. CanopyFill2 is no longer spawned. River is six omnis. That is the legal cost cut. The remaining Vale cost is still real: ForestFloor MultiMeshes with vis-range disabled, vol fog, SSAO on Balanced/Cinematic, canopy shadow, six camps of jointed dummies.

The bridge repair is a success. Baked deck did not meet the banks. Runtime deletes it, instances `vale_bridge.glb`, builds ramps that cannot become walls. Do not drape Path. Do not snap Deck to terrain.

Heart and AltarLight stay gone. EmberCrystals stay. Shards stay off. StandingStones/Heart at a far coordinate still exists; palette hue-pulls its light. That is leftover, not a shrine to restore.

Mirror walk-in: threshold mask 1 (WORLD), player layer 2. You probably cannot walk through. E still works. That is a Vale-and-Stair gate bug.

Hide-under-span AABB is too hungry. It clears floor along most of the path, not only under the deck. The approach should keep grass.

## Perfection pass

- One owner for Vale stone/path colour: palette. Dress paints meshes, does not reset albedo.
- Grass/fern tint wine-olive in `vale_palette.MATERIALS` only.
- Portal shader tinted from `fire_color`. Threshold mask includes PLAYER.
- Shrink hide AABB to dressed deck (cz ≈ 6.17, half-L 5.6).
- Toad rim: class it and let `_lights` pull violet, or colour it ember in `vale_toad.gd`.
- Keep six river omnis unless a still shows dark banks; if you add more, same `light_class` and LightGrid 8.5, do not raise glow knobs.
- Set Vale spring length 3.7 in `vale.gd` `_ready`.
- Do not restore Heart. Do not restore shards. Do not use toad as terrain.

## Done when

Vale ground is dark wine, water is green, glass is ember, grass is not cyan, the path still has a floor outside the deck, and walking into the return mirror either works or the prompt is the only path — not a silent failure. F3 fps on the owner’s machine at the gate has headroom above 144 on Balanced.

---

# 6. Wanderer feel

## As-is

`core/player/player.gd` is the controller. Walk 4.5, sprint 7.5, accel 14, decel 20, air accel 4, jump 5.2, gravity 16, coyote 0.1, jump buffer 0.12. Hold Space to keep jumping on landing (`is_action_pressed` plus `velocity.y <= 0`). No step-up. Camera: `_arm.position.x = 0.95`, `_cam.h_offset = 0.12`, pitch −1.0 to 0.6. Click-to-capture does not cast. Cast is Q / left mouse / right shoulder. Interact E. Sprint Shift. `push_pos` every physics frame.

`CharacterRig` owns sockets, stride, loadout, cloth spring, void face. `driven = true` so idle `_process` does not zero the stride. Trail quiets at sprint. Staff on `hand_r`. Left arm swings.

Loadout: robe torso, hood, peak, sleeves, bracers, boots, gauntlets, staff, lantern. `robe_skirt.glb` exists and is not worn. That is intentional (hem was rejected).

Gloom: max 100, dark 2.0/s, rift 3.5/s, drain 12/s.

## Critique

Movement is considered. Separate accel and decel. Coyote and buffer. OTS offset exists so the crosshair is not on the robe. Those are the right problems to have solved.

Floor snap 0.5 and max angle ~46° live on the baked Player nodes, not in `player.gd`. A future unpack of the subtree would lose them. Vale never sets spring 3.7. The wanderer *feels* different between nights for a one-line omission.

The lantern piece enables shadows; policy disables them later. Editor preview and any zone that forgets `apply_all` violate the constraint.

The skill still names `robe_cloth.gdshader`. Runtime is `robe_wave.gdshader`. `_cape` in the rig is leftover naming from a rejected cape; it now springs cloth. Do not restore a cape to match the variable name.

Do not generate new body meshes. The owner rejected that pass. Gauntlets and boots may keep small fittings. The robe glTFs stay.

## Perfection pass

- In `Player._ready`: set `floor_snap_length` and `floor_max_angle`. Set spring length 3.7 if the night did not.
- In `LanternPiece.build`: `shadow_enabled = false` before add_child.
- In `vale.gd`: spring 3.7 beside the Stair override.
- Leave robe glTFs, void face, staff mesh, socket names.
- Do not add foot IK unless asked.

## Done when

Stair and Vale share camera distance and floor snap. Belt lantern never casts a shadow, even in the editor. The wanderer still looks like the same hole in the night.

---

# 7. Staff and bolt

## As-is

Cooldown 0.42 s. `cast()` on the rig is not cosmetic: it fires `magic_bolt.tscn` from `muzzle()` (orb, else chest). Aim is a screen-centre ray against WORLD | PROPS | HURTBOX, with a camera-forward fallback when the staff-to-hit vector is too short or back-facing (the old OTS miss around the edges up close).

Bolt: speed 28, life 2.6 s, blast 3.1 m, 1 damage, layer 0, mask WORLD | PROPS | HURTBOX. Walks parents for `take_hit`. Burst pooled on `current_scene`. Light class `player_orb`, no shadows, no vol fog energy.

## Critique

Cast used to be a gesture. It is a weapon now. Crosshair convergence was a real bug (parallel-to-camera from the staff offset) and the ray fix is the right one. Do not aim from the staff without the look target.

Blast 3.1 m versus camps that sit ~10–12 m apart is still large if two dummies ever stand closer after a chase. The 1.05 m probe is the honest melee radius; splash should sit near that, not near a grenade.

`magic_bolt.tscn` still stores mask 1. `_ready` overwrites it. Stale scenes lie to the next editor.

`PROPS` is in the mask and in the aim query. Nothing sets `Layers.PROPS` on a body. The spring-arm comment claims PROPS lets the camera ignore rails. The arm mask is WORLD. The comment is a wish.

Smoke `_smoke_bolt.gd` instantiates. It does not fly or hit.

## Perfection pass

- Sync the `.tscn` mask to WORLD | HURTBOX (and PROPS only after something uses it).
- Tighten blast toward ~1.2 m.
- Keep violet orb, trail quiet on sprint, muzzle at the orb.
- Extend smoke to spawn, fire forward, and confirm `take_hit` on a dummy — or delete the smoke file’s pretence.

## Done when

Up close, the bolt lands on the crosshair, not around the shoulder. One bolt does not clear two leashed posts. The tscn mask matches `_ready`.

---

# 8. Gloom, Shade, Hollow

## As-is

Meter in `player.gd`. LightGrid linear scan. Braziers register when lit. Mirrors register on ready. Vale river omnis register 8.5 m. Shade: `shade.gd`, group `SHADE`, cylinder robe, hood, HDR eyes, smoke, hurt sphere on HURTBOX, speed 5.2, touch 1.1 m Hollows. `take_hit` or LightGrid unmakes. Scale-in, scale-out. No world collision.

Hollow: fade, checkpoint, gloom 0, `Events.hollowed`. Lava uses the same Hollow. Checkpoint starts at spawn, then last kindle.

Grade eases toward the meter in `Zone._process`.

## Critique

Gloom-as-health is the best idea in the game. Do not add a red HP bar on the wanderer.

The Shade is the meter’s body. Its look is parked (cylinder). Its physics is a ghost. It flies through the stair. That can be flavour (a wraith) or a bug (it clips into sanctuary stone and looks like a prop error). A single WORLD ray toward the player, or treating it as a `CharacterBody3D` that still ignores the player layer, would keep the wraith and stop the clip.

The full-gloom bolt loop is the worst beat: you do the skillful thing and the night punishes you with a second Shade before the first fade finishes. Fix behaviour, not mesh.

Lantern ≠ LightGrid is a design choice that must be spoken or changed. Spoken is cheaper and keeps sanctuaries special.

Docs quoting 3.6/6.3 will get an agent to “restore” the faster drain. Live is 2.0/3.5 because the owner asked for 1.8× slower. Believe `player.gd`.

## Perfection pass

- Respawn lockout after bolt-unmake until Gloom < 85 or 2 s elapsed.
- Optional: Shade `move_and_slide` on WORLD only, still no player collision.
- Kindle toast names the slow cleanse if you do not snap Gloom.
- Update `umbral-player` skill gloom numbers when you are already touching skills. Do not change live rates.
- Do not replace Shade meshes.

## Done when

A `--test-shade` style full meter, one bolt, and a second of waiting does not produce two Shades. Kindling still unmakes a Shade that is in the radius.

---

# 9. Wretch and Husk

## As-is

`Enemy` is a `CharacterBody3D` FSM: IDLE, CHASE, WINDUP (0.42 s), STRIKE (instant `add_gloom`), RECOVER (0.55 s). Layer HURTBOX, mask WORLD. Capsule 0.35 × 1.7. Think 10 Hz. Light-averse multiplies wish by 0.45. Leash `hunt_leash`. Home snap if they fall. Animate only if the player is within 16 m. `sleep()` / `wake()` keep them visible.

Wretch: 3 HP, 3.6 m/s, chase 12, leash 15, strike 1.45, +25 gloom.
Husk: 5 HP, 2.35 m/s, scale `(1.08, 0.86, 1.08)`, chase 10, leash 13, strike 1.55, +32 gloom.

`enemy_body.gd` dresses sockets with triplanar stone/bark/ground. Not the wanderer robe.

Spawner: alternate types, ground ray plus capsule clearance, respawn 10 s, retry if player within 7 m or slot lit. Vale dress also calls `seed_vale`; second call no-ops.

## Critique

They exist. That was not true for a stretch of this project (`type.new() as Enemy` was null; then `_skin` clashed with a function name; then they stood still in LightGrid; then they hid past 46 m; then they chased from 34 m and left the post). The current contract is: visible on the post, hunt when you are close, go home after.

They still lie visually. `_legacy_pose` is a staff-carry. Windup calls `cast()`. There is no staff. The dummy looks like a wanderer who lost his weapon. A pose flag on the shared rig (staff vs melee) is in-place and does not rewrite the wanderer.

They still lie physically. You walk through them. They hit through walls. Occupancy (mask WORLD|PLAYER, or a bump) and a cheap ray before gloom apply are in-place.

Husk squash does not shrink the capsule. The squat body floats in a tall collider. World-triplanar flesh crawls as they walk; local triplanar is the fix.

Spawner prints `ENEMY plant slots=` in play. Wake loop looks for `PROCESS_MODE_DISABLED` that sleep never sets. Dead code.

HP bars are always on. They should appear on first hit or when chasing.

Do not add a third type. Perfect these two.

## Perfection pass

- `CharacterRig`: melee pose (no wand arm). Enemies set it. Player stays staff.
- Strike: ray to player, skip if WORLD blocks.
- Optional player bump without a new layer.
- Husk capsule height scaled by 0.86.
- Local triplanar on dummy flesh.
- Preload `enemy_body.gd`. Remove the print. Delete wake loop or make sleep real (visible stays true if you sleep for CPU; the owner asked them to stay visible on the post, so prefer deleting the loop).
- HP bar after first hit.

## Done when

A Wretch on the Stair post is visible from the sanctuary, does not run the whole flight, raises empty hands not a missing staff, and cannot gloom you through the sanctuary disc. A Husk’s collider matches the squat.

---

# 10. Light as gameplay

## As-is

`LightGrid` is a list of `{node, r2}`. `is_lit(pos)` is a 3D distance check. Braziers register when lit (radius 11). Mirrors register (~6.5–7). Vale river omnis register 8.5. Travel `clear()`s on hop.

`light_policy.gd` classes: beacon, hero, hero_fill, fill, glimmer, lava, river, player_lantern, player_orb, moon. Fade, fog energy, shadows. Braziers do not cast (paraboloid cost). Lantern shadows forced off. Moon carries directional shadow (high quality: 2 splits, max distance 30 m after the perf pass).

`apply_illumination` boosts fill/lava/river/glimmer/hero once via `_illum` meta. That is how crystals light the ground without raising bloom.

Gothic Stair: three `HeroSpot` + fill + shaft mist. Vale: no gothic kit. Six path lanterns plus dock.

Glow knobs locked in `atmosphere._fog` / `_glow_budget`.

## Critique

LightPolicy ended the era where the last fade-at-18 m killed braziers. Classes are the right abstraction. Keep them.

LightGrid is gameplay, not decoration. Putting river omnis on the grid means standing on the Vale bridge drains Gloom. That may be intended (the water is a living light) or a side effect of an illumination pass. If kindling is the only “safe,” unregister river from LightGrid and leave the omnis as beauty. If the river is a sanctuary, say so in a toast once.

Player orb and lantern dump no vol fog. Good. They used to streak.

Sanctuary starts lit with radius 11. Posts at 12 m were “just outside” and still froze when aversion required `not lit` to chase. Aversion now slinks. Do not put camps inside 11 m of a start-lit brazier.

Four lanterns vs three gothic stations: do not add architecture to win the count.

## Perfection pass

- Decide river LightGrid in one sentence in `vale.gd` comments, then match the register call.
- Keep lantern off the grid.
- Keep glow knobs.
- Do not turn brazier shadows on.
- Hero spots stay unshadowed except High quality, as now.

## Done when

Kindled fire is the readable safe. Vale water either is or is not safe, and the meter agrees. Crystals still light the path. Bloom is still 0.06.

---

# 11. HUD and menus

## As-is

`ui/hud.tscn` is instanced in `Zone._ready` as a CanvasLayer. It is not parented under a room that Travel deletes; it is parented under the Zone, and Travel replaces the whole scene, so HUD is reconstructed every hop. That is acceptable if `_ready` is cheap. It is not acceptable if HUD state (crosshair fade, toast queue) is treated as persistent.

**On screen.**

- Crosshair: 2×12 px, colour `Color(0.93, 0.88, 0.78, 0.55)`, `MOUSE_FILTER_IGNORE`.
- Gloom bar: 220 px, height 3, fill 0.78/0.22/0.18. Lives in a 220×3 `Control` named `Gloom`.
- Interact prompt: Cinzel 16, `theme_override_colors/font_color` cream, outline 2, shadow 2. Text comes from `Events.interact_hint`.
- Toast: Cinzel 15, 4 s lifetime, queue of 3. `Events.toast`.
- Zone title: Cinzel 22, fade in 0.8 s, hold, fade out. Total on-screen about 16 s from `Events.zone_entered`.
- HP bar over enemies: `Control` in world-to-screen, always visible while the dummy is in camera.

**Settings.** `ui/settings_menu.tscn`, `PROCESS_MODE_ALWAYS`, opened by F2 or Esc (`toggle_settings`). Also Start on a pad. The menu consumes the event with `set_input_as_handled()`. It does not currently consume `release_mouse`, because the same physical Esc is bound to both actions and settings is handled first.

**Fonts.** Cinzel OFL in `art/fonts/`. Do not swap to a system UI font “for readability.” The HUD is part of the night.

**Grade overlay.** `world/grade.gdshader` (Stair) and `world/grade_vale.gdshader` (Vale) sit as a full-screen ColorRect under the Zone, not in the HUD scene. Gloom eases the grade. Hollows do not currently change it except via the meter snapping to 0.

## Critique

The HUD is the right size. A 3 px bar and a small crosshair match “you are a hole in the night.” Do not add a minimap, a quest tracker, a hotbar, or a compass.

The 16 s zone title is long. On a second visit through the mirror it plays again. Travel could skip the title on return, or the HUD could remember the last `zone_entered` string for the session.

Esc as both pause and free-mouse is a daily annoyance in the editor and in the app. The owner uses Esc to drop the cursor. Settings always wins. Either:

- Unbind Esc from `toggle_settings` and leave F2 + Start, or
- First Esc releases mouse if captured and the menu is closed; second Esc opens settings.

Do not leave both bindings and hope `_unhandled_input` order stays stable.

World-space HP bars on idle camps advertise the combat system from the sanctuary. They should appear on first `take_hit` or when the dummy’s state is CHASE. Always-on bars also cost a `Control` per dummy every frame.

Interact prompt is correct. Kindling uses it. Mirrors use it. There is no prompt for “you cannot walk through this glass” when the Area mask is WORLD only — you walk at a wall and nothing happens. The prompt can still show “the glass remembers.” That is a mixed signal.

Toasts are the only voice the game has. They currently fire on kindle and on some Hollows. They should fire once on first Shade, once on first Wretch strike, and once if the river is a LightGrid zone. Then stop. Do not narrate every kindle forever.

Settings is the only `PROCESS_MODE_ALWAYS` gameplay-adjacent node besides the Settings autoload. Travel fade is not. Opening the menu mid-hop is the freeze. That is chapter 13. The HUD itself pauses with the tree, which is correct.

## Perfection pass

- Esc: prefer unbinding it from settings. Keep F2. Document in `input_setup.gd`.
- Enemy HP: show after first hit or during CHASE; hide after 2 s of IDLE.
- Zone title: 8 s, or skip if Travel payload says `returning`.
- One-shot toasts for Shade and first strike. Kindle toast names the slow cleanse.
- Do not add a second bar for Hollow count. If you surface it, use a whisper under the gloom bar for 2 s after Hollow.
- Keep Cinzel. Keep cream-on-dark. Do not add drop shadows that bloom.

## Done when

Esc in play releases the mouse. HP bars are not a row of red ticks on the Stair from spawn. The Vale title does not linger through the first kindle.

---

# 12. Settings and quality

## As-is

`autoload/settings.gd` persists to user://. `changed` fires. `Zone` applies on ready and on change. Look-dev presets:

| Preset | Intent |
| --- | --- |
| Performance | Scale down, no SSAO, cheaper shadows |
| Balanced | Default-ish |
| High | Moon 2-split, more shadow distance |
| Cinematic | Saved look-dev. Glow still clamped. Far DoF still off |

Internal height cap 960. Render scale via F4 cycles. Fullscreen F11. F1 toggles grade. F3 debug overlay. F8 Stair benchmark. F9 demo walk.

`atmosphere.apply` enforces glow 0.62 / bloom 0.06 / HDR 1.15 / levels 0+1 regardless of the baked Environment and regardless of Cinematic. That is the budget. Cinematic may raise SSAO, fog quality, and moon splits. It may not raise bloom.

`dof_enabled` exists as a setting. Far DoF stays off in atmosphere. Do not “honour the checkbox” by turning far DoF on.

Lantern shadows are forced off in policy even if the piece enables them.

## Critique

The split — presets may spend on shadows and SSAO, never on glow — is the whole look of the game. A future “make it prettier” pass that raises intensity to 0.9 will undo months of owner rejection.

F8 is Stair-only and writes markers into the running tree. Fine for a bench. Do not bake those markers.

F9 kindles Stair braziers and walks. It is a capture tool, not a story skip. Vale has no equivalent. That is acceptable.

Render scale and height cap exist because the Mac app is the playable. 1440 internal was rejected. Stay at 960.

Quality names in comments still mention violet. Players never see those comments. Agents do.

## Perfection pass

- Keep the glow clamp in `atmosphere.apply`. Put a comment at the clamp: do not honour a wider preset.
- Default lantern piece to shadows off so Cinematic preview in editor matches play.
- If you add a Vale F8, instance markers at runtime, never into `vale.tscn`.
- Do not implement far DoF when `dof_enabled` is true.

## Done when

Switching Cinematic in the Downloads app does not bloom the vortex or the aurora. Height stays 960. Lantern still has no shadow.

---

# 13. Travel between nights

## As-is

`autoload/travel.gd` is the hop. `MirrorGate` on interact (and theoretically on walk-in) calls Travel with a packed scene path and a facing. Travel:

1. Captures gloom, hollow_count, and facing into a payload.
2. Fades a ColorRect toward black.
3. `change_scene_to_packed`.
4. `LightGrid.clear()`.
5. Destination `Zone._ready` runs: atmosphere, dress, HUD, settings apply, player spawn.
6. Travel applies payload to the new Player (gloom, hollows, yaw).
7. Fade up.

Stair summit gate → `res://world/vale.tscn`. Vale return gate → `res://world/main.tscn`.

Mirrors register on LightGrid so standing at the glass drains Gloom. That is “the glass is a light.”

## Critique

Travel is the only scene-change in the game. It has to be unbreakable.

**PROCESS_MODE_ALWAYS is missing on the fade.** Settings is ALWAYS. The tree pauses when the menu opens. If the owner hits Esc during the fade, the ColorRect freezes at 50% black on the new night, or the hop never finishes. This is the highest-severity UI bug that is not combat.

**Walk-in does not work.** `MirrorGate` Area mask is 1 (WORLD). Player collision layer is 2. The body_entered path never fires. Interact still works. The gate looks like a door and behaves like a button. Fix: mask `Layers.PLAYER`. Do not also add WORLD if that makes the area think the hill is a traveller.

**Payload is small.** Gloom and hollows travel. Kindled braziers do not. Returning to the Stair relights only Sanctuary; the climb is dark again. That can be flavour (the night forgets) or a bug (the player kindled four fires). In-place perfection: persist a small set of brazier names in Travel payload, keyed by scene path. Do not invent a save file for v0.1 unless asked. A dictionary on Travel is enough for one session.

**HUD reconstructs.** Fine. Player reconstructs. Fine. LightGrid is cleared. Fine. What is not fine is `Events` connections from the old HUD if they were not disconnected. If toasts double after a hop, that is a leftover connect. Audit `Events` on Zone `NOTIFICATION_PREDELETE` or rely on freeing the HUD with the scene (current, should work).

**Facing.** Landing in the Vale looking at the river vs looking at the hill changes the first impression. Export yaw on the gate. Do not snap the player into the hill.

**No title scene.** Boot is Stair. Returning from Vale is Stair at the summit or at sanctuary depending on spawn write. Confirm `main.gd` spawn vs Travel spawn. Travel should win.

## Perfection pass

- `travel.gd` fade layer: `PROCESS_MODE_ALWAYS`.
- `MirrorGate` Area `collision_mask = Layers.PLAYER`.
- Payload: optional `lit: PackedStringArray` of brazier node names. Destination kindles those if present.
- Confirm player spawn node is overwritten by Travel, not by a deferred dress that moves them again (`vale_dress` moving the deck brazier is fine; moving the player is not).
- Do not add a third destination.

## Done when

Esc mid-hop cannot freeze the glass. Walking into the pane travels. Interact still travels. Gloom on arrival matches Gloom on departure.

---

# 14. Audio (the missing layer)

## As-is

There is no audio subsystem. There is no `AudioStreamPlayer` on braziers, bolts, player, river, or HUD. The README is still correct on this one line: no audio.

The architecture rule is: **world sounds live on the node that makes them.** No AudioManager autoload. That is not a gap to “fix” with a sixth autoload. It is the design.

## Critique

A silent night is a preview. Fire without crackle, a bolt without a hiss, a Hollow without a breath, a river without a bed of noise — the Vale especially reads as a painting.

Perfecting in place means:

- One `AudioStreamPlayer3D` (or 2D for UI) on the node.
- A handful of short loops and one-shots in `art/audio/` (new folder is allowed; it is not a rejected mesh).
- Attenuation that matches LightPolicy fade distances so a brazier is heard about as far as it is seen.

It does not mean FMOD, a mixer bus bible, or music that fights the aurora.

Suggested first five, all on existing nodes:

| Sound | Node | Type |
| --- | --- | --- |
| Kindle / fire loop | `Brazier` | One-shot kindle + loop while lit |
| Bolt | `MagicBolt` or Player muzzle | One-shot |
| Hollow | `Player` | One-shot on `hollow()` |
| River bed | `vale.gd` river mesh | Loop, 3D at mid-span |
| Footstep | `CharacterRig` stride tick | Very quiet, dirt vs stone later if you must |

Do not add enemy voice. Do not add a title theme. Do not add shade screams that turn it into a horror game the owner did not ask for.

If you cannot source audio in this pass, leave the nodes ready (`player = AudioStreamPlayer3D.new()` with a null stream is worse than nothing). Prefer shipping four files over a framework.

## Perfection pass

- No sixth autoload.
- Streams as resources. Nodes play them.
- Fire loop stops on unkindle (there is no unkindle today — kindle is one way). Then the loop is lifetime of the night after kindle, which is correct.
- Respect pause: players should pause with the tree except Travel fade (silent anyway).
- Do not auto-generate wavs in Python as a “placeholder.” Silence is better than a beep.

## Done when

Kindling a brazier is heard. Crossing the Vale bridge is heard. A Hollow is heard. There is still no AudioManager.

---

# 15. Performance and culling

## As-is

The Vale fps complaint was real. The stack that caused it, and the rollback:

| Spend | What happened | Now |
| --- | --- | --- |
| Dual world-triplanar + AO + detail/clearcoat on giant bark | `surface_detail.gd` extra samples on huge trunks | **Stripped.** Sharpness cap 2.0, linear mipmaps, no AO overlay |
| Canopy Fill2 extra shadow casters | Palette turned Fill/Fill2 shadows on after atmosphere turned them off | **Fill2 not spawned.** Shadows only Canopy + GiantTrunks |
| 11 then 6 river omnis in vol fog | Each omni is a fog light | **6 omnis**, energy 2.2, range 10, vol fog energy via policy 0.9 |
| Vol fog length / detail | Long slices across the Vale | Length 40, `detail_spread` 1.15 |
| Glimmer lights | Cap 6, plus wisps, buds, fireflies | Cap 6 lights, 3 wisps, 4 buds `detail 0`, fireflies 1×12, no turbulence, orb 8/5 segs |
| Terrain shader grit | Extra samples | Gated `if (detail > 0.5)` with uniform `detail = 0` |
| Water waves | 5th wave `n3` | Back to 4 waves |
| Moon shadow distance | High quality was long | Capped 30 m |
| SSAO | Cinematic/Balanced | 1.2 / 1.25 / 0.32 — do not raise |

**Culling law** (`umbral-culling`): `visibility_range` is distance to **node origin**. A 60-step stair with origin at `(0,0,0)` will vanish underfoot if you set vis-range 50. ForestFloor MultiMeshes need a real custom AABB; headless bake zeroes it and the grass dies. `extra_cull_margin` is the lever for lava Surface (80). Do not vis-range the Stair, Sanctuary, Ruins, Terrain, or the lava mesh.

Enemies: vis-range 0, extra_cull 2.4, ignore occlusion. Animate only inside 16 m. Atmosphere skips `Groups.ENEMY` in the global cull pass.

Player lantern shadows off. Brazier shadows off. That is fps and constraint.

## Critique

The detail pass and the fps pass fought each other in the same afternoon. That is the lesson: **albedo and normals at 1024 are cheap; extra shader samples on giant world meshes are not; extra shadow-casting meshes are not; extra omnis in volumetric fog are not.**

Improving assets in this project means:

- Better authored textures (already 1024 in `gen_textures.py` / `gen_foliage.py`).
- Better material colour in palettes (cheap).
- Not a second triplanar, not AO applied in a second pass, not clearcoat on bark.

144 fps is the owner’s floor in the Vale, not a marketing number. Forward+ plus vol fog plus SSAO plus a forest will not leave 2× headroom if you add Fill2 again.

CPU: 9 enemies thinking at 10 Hz is nothing. 9 `CharacterRig` idle processes were something; `driven` and the 16 m animate gate exist. Do not put `_process` on every grass blade.

GPU: ForestFloor is the tax. Vis-range on MultiMesh is origin-based too. If you must cull grass, fade in the shader with `push_pos`, which already exists, rather than vis-range the MultiMesh instance.

## Perfection pass

- Leave `surface_detail` in the stripped state. Do not re-enable AO “for quality.”
- Leave Fill2 unspawned.
- Leave river at 6 unless a still shows a dark bank; then add lights with `light_class` river, not by raising energy on the existing six into bloom.
- Do not vis-range span meshes.
- Never headless-rebake to “fix” grass. If grass dies, it was a bake; restore from git, GPU-bake if the owner is in the editor.
- F3 overlay is the bench. Quote fps in the Downloads app, not only in the editor.

## Done when

Vale gate, Balanced, owner’s machine, F3: comfortably above 144. Stair climb, same. Grass still there at the feet. Lava still there when you look down the rift from 57 m.

---

# 16. Pipeline, bake, pack

## As-is

**Import.** `godot --headless --path . --import --quit`.

**Pack.** `godot --headless --path . --export-pack "Linux" "/tmp/Umbral Reaches.pck"` then copy into the Mac app Resources, `codesign --force --deep --sign -`, `touch` the `.app`, quote `date`.

**Bake.** GPU, in the editor, when architecture MultiMeshes must change. Tools under `tools/` generate meshes and textures. `art/blender/` has `.gdignore`. Export glTF with `export_apply=True`, `export_yup=True`. No `.blend` under `art/models/`.

**Do not.** Headless-rebake `main.tscn` / `vale.tscn`. `godot --check-only`. `pkill` the owner’s Godot. macOS export preset for the playable. Replacing the Mach-O.

**Hung tools.** `--check-only` hangs. Some `-s tools/` scripts hang if they wait on the editor. `AGENT_HANDOVER.md` lists traps; skills win if they disagree.

**class_name.** Adding a new `class_name` requires an import so Godot registers it. Pack after. Do not assume the Downloads app sees a new global class without import.

**Smoke.** `tools/_smoke_bolt.gd` and similar. Headless `-s` with `--quit`. They must not open a window and wait.

## Critique

The pack path is the product. Agents that F5 and declare victory are not shipping. Agents that rebake to pick up a shader are destroying ForestFloor.

The Linux-pck-in-Mac-app trick exists because the owner’s playable is that bundle. Do not “simplify” to a Godot export of macOS.

Blender source staying behind `.gdignore` is why glTF in `art/models/` is the runtime truth. Edit blend, export, import, pack. Do not ask Godot to load a blend.

## Perfection pass

- After any script/shader/player/enemy/ui/atmosphere change: pack, codesign, touch, quote time, tell the owner to quit and relaunch.
- After architecture-only experiments: do not pack a headless bake.
- Smoke: one script per bug class (bolt hit, shade lockout, mirror mask) that `--quit`s.
- When adding `class_name`, import then pack.

## Done when

Finder time on the `.app` matches the last pack. Owner relaunch plays the change. Grass is still there.

---

# 17. Architecture (keep the spine)

## As-is

Feature folders: `core/player`, `core/world`, `core/enemy`, `core/items`, `ui`, `world`, `autoload`, `tools`. Files `snake_case`, nodes `PascalCase`.

**Compose, don’t inherit (Player).** `Player` does not subclass a Hero. It owns move, camera, gloom. It talks to the rig through `animate()`, `cast()`, `equip()`. It never writes bone names.

**Inherit (Enemy).** `Wretch` and `Husk` extend `Enemy`. Dress is `CharacterRig` sockets plus `enemy_body.gd`. New enemy types would extend `Enemy` and dress sockets. There is no third type on the table.

**Zone.** `world/main.gd` and `world/vale.gd` extend it and call `finish_zone_setup()` last. Atmosphere, HUD, settings, pause, grade, demo hooks live on Zone so nights do not fork.

**Groups.** `Groups.PLAYER`, `INTERACTABLE`, `LIGHT_SOURCE`, `SHADE`, `ENEMY`. Atmosphere skips ENEMY in cull. Shade lookup uses the group. Interact uses the group. Do not `get_parent()` to find the player.

**Spawn.** `add_child` to `get_tree().current_scene` for bolts, bursts, shades, enemies. Parenting a bolt to the player makes it inherit the player’s layer mask and miss.

**Pause.** `get_tree().paused`. Settings ALWAYS. Travel must ALWAYS. No `Engine.time_scale = 0`.

**Input.** Named actions from `InputSetup`. Gameplay in `_unhandled_input` and `_physics_process`. Menus `set_input_as_handled()`.

**Resources.** `EquipmentPiece` data plus `equip()`. `MirrorGate` `@export` paths. No hardcoded “next level” in Player.

## Critique

This spine is why the project can still be perfected. The failures of the last week were local (null `as Enemy`, vis-range on a long mesh, dual triplanar) not architectural.

The temptation to add GameManager grows every time Travel, Gloom, and checkpoints feel related. They are related. They still do not need a god object. Travel already carries a payload. LightGrid already answers `is_lit`. Events already fires `hollowed`. That is the manager.

`Layers` grew past the two-layer rule. WORLD and PLAYER are still the walk. HURTBOX is combat. INTERACT is prompts. PROPS is a wish for camera-ignore that the spring arm does not implement. Either implement PROPS on rails and the arm mask, or stop mentioning it in comments.

`enemy_spawner` as a static helper is fine. It is not an autoload. Keep it that way.

## Perfection pass

- Fifth autoload remains the last.
- Implement or delete the PROPS story. Do not leave a layer that nothing sets.
- Keep `finish_zone_setup()` last on both nights.
- Keep bolt/shade/enemy parenting on `current_scene`.

## Done when

A new intern (or agent) can add a brazier without touching Player, and a new enemy type without touching Zone.

---

# 18. Play path and how we lie to ourselves

## As-is

Owner plays `/Users/luke/Downloads/UmbralReaches/Umbral Reaches.app`. Editor F5 is development. The repo README still mentions Windows and a macOS zip.

Pack is Linux preset into `Contents/Resources/Umbral Reaches.pck`.

## Critique

If the owner’s hands never enter the editor to “play,” then editor-only bugs are not play bugs, and unpacked script is not a fix. This has already caused “I packed, they did not relaunch” and “they relaunched an old pck because Finder time was not quoted.”

Quote the time. Ask for relaunch. Do not pkill Godot to force it.

Debug keys (F1 grade, F3 overlay, F8 bench, F9 demo) ship in the pck. That is a prototype privilege. Leave them. Do not bind them to keys a player uses for steam overlays if this ever ships; it is not shipping this week.

`--test-shade` and similar CLI flags on `main.gd` are for you. They will not be in the owner’s launch args. Smoke in `tools/` is the repeatable path.

## Perfection pass

- Every gameplay reply that expects playtesting includes Finder time and “quit and relaunch.”
- Do not document a Windows exe as the playable.
- Do not kill the editor.

## Done when

The last pack time in chat matches the `.app` mtime, and the owner’s report matches the code in the pck.

---

# 19. Order of work (do these, in this order)

Work that changes feel comes first. Work that changes look on existing materials second. New audio third. Docs last. Never bake to do any of this.

### Pass A — Combat honesty (one pack)

1. Shade respawn lockout after bolt (`player.gd` spawn condition).
2. Mirror Area mask `Layers.PLAYER`.
3. Travel fade `PROCESS_MODE_ALWAYS`.
4. Enemy melee pose flag on `CharacterRig`; Wretch/Husk set it; `cast()` not used as punch.
5. Strike ray vs WORLD before `add_gloom`.
6. Bolt `.tscn` mask matches `_ready`. Blast ~1.2 m.
7. Esc unbound from settings (F2 remains).
8. HP bar on hit/chase only.

Pack, codesign, touch, relaunch. Play Stair: kindle, bolt a Shade at 100, confirm no twin. Walk a Wretch: it waits, hunts, cannot hit through the disc, you bump them. Walk into the summit glass.

### Pass B — Vale identity (one pack)

1. `vale_dress` stops writing stone/path albedo that fights the palette.
2. Grass/fern tint wine-olive in `vale_palette.gd` only.
3. `portal_glass` tint from `fire_color`.
4. Hide-under-span AABB shrunk to the dressed deck.
5. Vale camera spring 3.7.
6. Toad rim pulled off leftover violet.
7. River LightGrid: comment + match.

Pack. Stand at the Vale gate. Ground is wine. Water is green. Glass is ember. F3 fps.

### Pass C — Wanderer consistency (one pack)

1. `Player._ready` floor snap + max angle.
2. `LanternPiece.build` shadows off.
3. No robe mesh edits.

Pack. Stair and Vale should feel like the same body.

### Pass D — Voice (audio, one pack if files exist)

Four streams on four nodes. No manager.

### Pass E — Persistence lite (optional, same week)

Travel payload kindled names. Returning to Stair, the climb fires you lit are still lit for the session.

### Pass F — README (only if asked)

Replace v0.1 lies. Point at this bible. Do not do this in the same PR as combat if you are splitting work.

**Do not interleave** a detail-texture pass with Pass A. That is how Vale fps died last time.

---

# 20. What not to add

A list so the next energetic session does not “complete” the game by making a different game.

- Third night, title scene, save slots, skill tree, loot, inventory UI, minimap, compass, quest log, XP.
- Third enemy class, elite, boss, guardian, blob, priest, toad-as-enemy.
- New wanderer body, cape, hem, face texture, hair, silver cloth, `arcane_robe.gdshader` on the player.
- Shade mesh rewrite (behaviour only).
- Gothic architecture meshes, bead-arches, `gothic_bay.glb` as level.
- Heart crystal, AltarLight, GlowShards, shrine ring menhirs.
- AudioManager, GameManager, sixth autoload.
- Far DoF, bloom 0.18, glow 0.9, internal 1440, lantern shadows, brazier shadows.
- Headless rebake, `--check-only`, pkill Godot, macOS export as the playable.
- Dual triplanar / AO overlay on world bark.
- Canopy Fill2 shadows.
- `Engine.time_scale = 0`.
- `get_parent()` to find the player.
- Parenting bolts to the staff node.
- Vis-range on Stair / Terrain / Lava / Sanctuary.
- Draping Path, snapping Deck/Step/Base.
- Purple portal glass on the Vale “because the shader default is purple.”
- Icy grass on a crimson night “because cool rim looks 3D.”

If the owner asks for one of these by name, believe the owner, not this list. If an agent infers one of these from “make it better,” believe this list.

---

# Appendix A — File map (current)

Paths an agent actually needs. Not every `.gd`.

### Autoload

| File | Role |
| --- | --- |
| `autoload/events.gd` | Signals only |
| `autoload/settings.gd` | Persist, `changed`, ALWAYS |
| `autoload/travel.gd` | Fade, payload, scene change |
| `autoload/light_grid.gd` | `register` / `unregister` / `is_lit` / `clear` |
| `autoload/input_setup.gd` | InputMap bootstrap |

### Player and items

| File | Role |
| --- | --- |
| `core/player/player.gd` | Move, camera, gloom, hollow, shade spawn, bolt aim |
| `core/player/character_rig.gd` | Skeleton, sockets, stride, `animate` / `cast` / `equip` |
| `core/player/default_loadout.gd` | What the wanderer wears |
| `core/items/equipment_piece.gd` | Data |
| `core/items/staff_piece.gd` | Staff + orb + muzzle |
| `core/items/lantern_piece.gd` | Belt lantern |
| `core/combat/magic_bolt.gd` | Projectile |
| `core/combat/magic_bolt.tscn` | Scene (mask must match script) |

### Enemy

| File | Role |
| --- | --- |
| `core/enemy/enemy.gd` | FSM, leash, sleep/wake, take_hit |
| `core/enemy/wretch.gd` | 3 HP runner |
| `core/enemy/husk.gd` | 5 HP squat |
| `core/enemy/enemy_body.gd` | Dummy dress |
| `core/enemy/enemy_spawner.gd` | Posts, clearance, respawn |
| `core/world/shade.gd` | Gloom-made hunter |

### World / nights

| File | Role |
| --- | --- |
| `world/zone.gd` | Night shell, HUD, atmosphere apply, pause |
| `world/main.gd` | Stair |
| `world/vale.gd` | Vale, river omnis, toad, dress order |
| `world/main.tscn` | Baked Stair — do not headless-rebake |
| `world/vale.tscn` | Baked Vale — do not headless-rebake |
| `core/world/atmosphere.gd` | Fog, glow budget, cull, SSAO |
| `core/world/light_policy.gd` | Classes, fade, shadows, vol fog energy |
| `core/world/vale_palette.gd` | Vale materials and sky |
| `core/world/vale_dress.gd` | Runtime Vale props (must not clobber albedo) |
| `core/world/dressed_props.gd` | Shared dress |
| `core/world/demo_dress.gd` | Stair dress |
| `core/world/glimmers.gd` | Wisps, optional shards (off) |
| `core/world/gothic.gd` | Window spots, not architecture |
| `core/world/brazier.gd` | Kindle, LightGrid 11 m |
| `core/world/mirror_gate.gd` | Travel interact / area |
| `core/world/surface_detail.gd` | Material cleanup (stripped overlays) |
| `core/world/vale_toad.gd` | Toad prop |
| `core/world/water.gdshader` | River / lava-adjacent water |
| `world/grade.gdshader` | Stair colour grade |
| `world/grade_vale.gdshader` | Vale colour grade |
| `world/portal_glass.gdshader` | Mirror pane |

### UI

| File | Role |
| --- | --- |
| `ui/hud.gd` | Bar, prompt, toast, title, crosshair |
| `ui/settings_menu.gd` | ALWAYS, quality |

### Tools (do not run as play)

| File | Role |
| --- | --- |
| `tools/gen_textures.py` | Albedo/normal/rough 1024 |
| `tools/gen_foliage.py` | Grass/fern cards |
| `tools/_smoke_bolt.gd` | Incomplete bolt smoke |
| Pack commands | `AGENTS.md` |

### Docs

| File | Role |
| --- | --- |
| `docs/perfecting_umbral_reaches.md` | This bible |
| `AGENTS.md` | Everyday law |
| `AGENT_HANDOVER.md` | Stale 31 Oct traps; skills win |
| `DARK_FANTASY_REVIEW.md` | Stale look-dev; do not implement |
| `README.md` | Stale v0.1 pitch |
| `.cursor/skills/*` | Binding playbook |
| `.cursor/rules/*` | Binding architecture and constraints |

---

# Appendix B — Signals, groups, layers, input

### Events (signals only)

Typical emitters. If a name is missing from `events.gd` when you implement a toast, add the signal there, not on Player.

- `gloom_changed(value, max_value)`
- `interact_hint(text)` — empty string hides the prompt
- `brazier_kindled(brazier)`
- `shade_spawned()`
- `enemy_killed(enemy)`
- `toast(text)`
- `zone_entered(title, subtitle)`
- `hollowed()`
- `respawned(at)`
- `autopilot_reached(marker_name)` / `autopilot_finished()`
- `benchmark_done(summary)`
- Settings uses `changed` on the Settings autoload, not Events

Do not put gameplay state on Events. It is not a blackboard.

### Groups

| Constant | Who |
| --- | --- |
| `Groups.PLAYER` | The wanderer body |
| `Groups.INTERACTABLE` | Braziers, gates |
| `Groups.LIGHT_SOURCE` | Registered lights if used |
| `Groups.SHADE` | The gloom hunter |
| `Groups.ENEMY` | Wretch / Husk; atmosphere skips in cull |

### Layers (`core/util/layers.gd`)

| Name | Bit value | Use |
| --- | --- | --- |
| WORLD | 1 | Walk, camera spring, bolt stop |
| PLAYER | 2 | Wanderer; lava mask; should be mirror mask |
| HURTBOX | 4 | Enemies, shade hurt, bolt mask |
| INTERACT | 8 | Prompt areas |
| PROPS | 16 | Intended for rails the camera ignores — unused on bodies |

Player collision: capsule on Player. Enemies: their own capsules. Camera spring: mask WORLD today.

### Input (`autoload/input_setup.gd`)

| Action | Keys / buttons |
| --- | --- |
| move_* | WASD / arrows / left stick |
| sprint | Shift / left stick click |
| jump | Space / A |
| interact | E / X |
| cast | Q, LMB, RB, RT |
| toggle_settings | F2, Esc, Start |
| release_mouse | Esc |
| toggle_grade | F1 |
| toggle_debug | F3 / Back |
| render_scale | F4 |
| benchmark | F8 |
| demo | F9 |
| fullscreen | F11 |

Physical keys. Xbox layout on pad. Deadzone 0.2.

---

# Appendix C — Numbers (live, not the Oct 31 review)

### Movement and camera

| | |
| --- | --- |
| Walk | 4.5 |
| Sprint | 7.5 |
| Accel / decel / air | 14 / 20 / 4 |
| Jump / gravity | 5.2 / 16 |
| Coyote / buffer | 0.1 / 0.12 |
| Arm x / cam h_offset | 0.95 / 0.12 |
| Pitch | −1.0 .. 0.6 |
| Spring | 3.7 Stair; **set Vale to match** (baked 4.4) |
| Floor snap / max angle | 0.5 / ~46° on baked Player; **set in `_ready`** |

### Gloom

| | |
| --- | --- |
| Max | 100 |
| Dark gain | 2.0/s |
| Rift gain | 3.5/s (Stair z < −40) |
| Drain in light | 12/s |
| Shade spawn | 16 m behind at 100 |
| Hollow fade | 0.9 s |

### Bolt

| | |
| --- | --- |
| Cooldown | 0.42 s |
| Speed | 28 |
| Life | 2.6 s |
| Blast | 3.1 m (**tighten ~1.2**) |
| Damage | 1 |
| Mask | WORLD \| PROPS \| HURTBOX in script |

### Enemies

| | Wretch | Husk |
| --- | --- | --- |
| HP | 3 | 5 |
| Walk | 3.6 | 2.35 |
| Chase | 12 | 10 |
| Leash | 15 | 13 |
| Strike reach | 1.45 | 1.55 |
| Gloom on hit | +25 | +32 |
| Scale | 1 | (1.08, 0.86, 1.08) |
| Windup / recover | 0.42 / 0.55 | same |
| Light-averse | ×0.45 slink | same |
| Think | 10 Hz | same |
| Animate distance | 16 m | same |
| Respawn | 10 s | 10 s |
| Retry if player | < 7 m or slot lit | same |

### Lights and fog

| | |
| --- | --- |
| Brazier radius | 11 |
| Sanctuary | starts lit |
| Vale deck | forced unlit |
| River omnis | 6 × energy 2.2 × range 10, LightGrid 8.5 |
| Glow / bloom / HDR | 0.62 / 0.06 / 1.15 |
| Glow levels | 0 and 1 |
| Height cap | 960 |
| Stair far / Vale far | 82 / 68 |
| Vol fog length | 40 |
| Moon shadow max | 30 |
| SSAO | 1.2 / 1.25 / 0.32 |
| Arch | `ARCH_W` 1.16, `ARCH_Y0` 0.46 |
| Stair gameplay braziers | Sanctuary, StairFoot, Landing, Threshold, Shrine |
| Gothic stations | 3 window kits |

### Spawner posts (approx, after snap)

Stair: `(-5.5, 5, 12)`, `(5.5, 5, 12)`, `(-5.0, 4, 6)`.

Vale: six sites ~8–10 m from the path, not in the river, not in the deck LightGrid once kindled.

---

# Appendix D — Rejected art (do not undo)

If a ticket says “restore,” “rebuild gothic,” “real architecture,” “better character,” “guardian,” or “the toad as a boss,” stop and read this list.

- `gothic_bay.glb` as a level mesh
- `toad.glb` as terrain or as an enemy; runtime prop only
- Bead-arches
- Blob guardian
- Mint glass panes
- Paper-strip robes
- Sketchfab priest
- Cape, hem, asymmetric sleeves
- Oversized shade
- Silver cloth
- Purple `arcane_robe.gdshader` on the wanderer
- Wide fire bloom / far DoF / 1440 height
- Summit portal terrain snap
- Drape Path; snap Step / Base / Deck
- Shrine Heart + AltarLight
- GlowShards octahedrons
- Shrine ring menhirs (the “stones around the bridge”)
- Enemy wearing the wanderer robe set

The owner’s words that produced these bans are in `umbral-donts`. This appendix exists so this bible cannot be quoted as permission to restore them.

---

# Appendix E — Failure log (so we do not repeat it)

| What you saw | Actual cause | Fix that stayed | Fix that must not return |
| --- | --- | --- | --- |
| Stair treads vanish underfoot | vis-range vs origin on a long ArrayMesh | Skip span meshes in atmosphere cull | vis-range 50 on Stair |
| Bolt misses around the body | Aim parallel to camera from offset staff | Screen-centre ray + fallback | Aim only from muzzle |
| No enemies | `type.new() as Enemy` null; `static var _skin` vs `func _skin` | `Enemy.spawn`, rename | Dynamic script without class_name import |
| Wretches stand still | IDLE while LightGrid true; sanctuary radius 11 | Slink ×0.45; posts off sanctuary | Freeze in light |
| Invisible camps | `sleep()` `visible = false`; 34 m chase off-nav | Stay visible; chase 12; leash 14 | Hide to “optimise” |
| Vale ~144 fps | Dual triplanar+AO, Fill2 shadows, river omnis in vol fog | Strip overlays, no Fill2, 6 omnis | Re-enable for “detail” |
| Forest floor gone | Headless bake wiped MultiMesh AABB | Never headless-rebake nights | Headless bake to pick up a shader |
| Enemies look like staff beggars | Shared `_legacy_pose` + `cast()` | Melee pose flag (Pass A) | New enemy skeleton this week |
| Twin Shade | Bolt unmake while gloom still 100 | Lockout (Pass A) | Give Shade 50 HP |
| Frozen travel | Fade not ALWAYS | ALWAYS (Pass A) | `time_scale = 0` |
| Esc opens settings | Dual bind | Unbind Esc from settings (Pass A) | More Esc actions |
| Icy Vale grass | Dress/palette tint `(0.52, 0.72, 1.05)` | Palette wine-olive (Pass B) | Add snow |
| Purple Vale glass | Shader default | `fire_color` (Pass B) | New portal mesh |

---

# Appendix F — How to test after a pack

Play only the Downloads app after quit/relaunch. F3 on.

### Stair (10 minutes)

1. Spawn in sanctuary. Confirm lit, Gloom draining, four unlit climb fires, window spots, no HP bars in the dark yet.
2. Walk to first post. Wretch visible, idle, hunts at ~12 m, slinks if you kite through sanctuary light, leashes home.
3. Bolt: crosshair hit up close. One dummy dies in 3 hits. Neighbour does not die to splash.
4. Kindle StairFoot. Toast. Drain. Checkpoint.
5. Let Gloom 100. Shade spawns behind. Bolt it. **No second Shade.** Kindle to unmake if you skip the bolt.
6. Hollow on lava or Shade touch. Return to last kindle, Gloom 0.
7. Summit glass: E works. Walk-in works after Pass A. Arrive Vale with same Gloom.

### Vale (10 minutes)

1. Camera distance matches Stair.
2. Ground wine, grass not cyan, water green, glass ember.
3. Deck brazier unlit. Kindle it. Floor under the deck clear; grass on the approach present.
4. Six camps: visible, leashed, not in the river.
5. F3 fps at gate and on the bridge. Headroom above 144 Balanced.
6. Return glass. Esc during fade does not freeze (Pass A).
7. Toad is a frog on a bank, not a hill.

### Regression (2 minutes)

- Lantern: no shadow under the belt.
- Grade F1 still toggles.
- Settings F2, not Esc, unless you chose the two-step Esc.
- Grass at feet on both nights.
- Lava visible from the far rift.

---

# Appendix G — Chapter index

Continued in the full index at the end of this file (chapters 1–59 plus appendices A–F).

---

# 21. First Stair night, beat by beat

This chapter is a playtest script and a critique at once. If a future session only has time for one night, run this.

## Boot

The Downloads app launches `world/main.tscn`. `InputSetup` fills the InputMap. `Zone._ready` connects `Events.gloom_changed` and `Settings.changed`. `main.gd` then places gothic window stations, the summit gate, dress, glimmers, enemies, and **must** call `finish_zone_setup()` last so `refresh_lights` sees every OmniLight3D that dress just spawned.

If `finish_zone_setup` runs before dress, LightPolicy never sees the new crystals and gothic fills. That has happened. The rule on Zone exists because of it.

HUD instances. Title: `STAIR OF ASCENSION` / `where the sky turns inward`. Sixteen seconds is long; you will still be reading it at the first unlit brazier.

Mouse is captured on first click. Click does not cast. That is correct. The first-click-capture exists so a stray LMB in the menu does not fire a bolt.

## Sanctuary (t = 0–20 s)

You stand on a disc. Brazier already lit (`start_lit`). LightGrid radius 11 m. Gloom is 0 and draining is a no-op. Belt lantern is on. Window spots hit the stone from the sides; they are not a building.

**What should be true**

- Floor snap holds you on the disc. If you jitter, baked `floor_snap_length` was lost.
- Camera spring 3.7, offset 0.95, h_offset 0.12. The crosshair is not on your hood.
- No enemy HP bars in the trees yet (after Pass A). Today they may already tick in the dark. That is a lie.
- F3 overlay optional. Quote fps here as the cheap-scene baseline versus Vale.

**What is allowed to be quiet**

- No audio. This is the missing layer, not a Stair-only bug.
- No quest text after the title fades. Kindle is the tutorial.

Walk to the rim. Gloom should start climbing at 2.0/s as soon as you leave the 11 m sphere. If it does not, LightGrid still thinks you are in the sanctuary (radius too large) or `is_lit` is using 2D XZ and the disc is not where you think. It is 3D distance. Jumping does not save you.

## First flight (t = 20–90 s)

The stair is one mesh. Treads must not fade. If they do, someone put vis-range back.

Posts around `z = 12`. A Wretch should be standing, visible, not in the trees. At ~12 m it hunts. You can kite into sanctuary light; it slinks at ×0.45, it does not freeze. If it stands still in the dark, chase_range or the think loop is broken again.

**Strike.** Windup 0.42 s is readable if the pose is a raise, not a staff cast. Today it is a staff cast without a staff. Pass A.

If you stand still it will gloom you through the disc if the disc is WORLD and the strike has no ray. Pass A.

Three bolts kill a Wretch. Blast 3.1 may tick the Husk if they drifted together. Unlikely at 10 m posts, likely if both leashed onto the same tread.

Kindle StairFoot. Toast: “Brazier kindled. Your light remembers this place.” Checkpoint moves to `spawn_point()` (offset 0.3 up, 1.8 along local Z). If you Hollow now, you land here, not at sanctuary, unless you never kindled.

Gloom does not snap to 0. You stand in the 11 m sphere and watch the bar fall at 12/s. From 90 that is 7.5 s. Speak it or snap a chunk.

## Landing and Threshold

Same grammar. Dark between fires. Rift on your left or right depending on the stair’s turn: lava must remain visible when you look down from tens of metres. Extra cull 80 on Surface is why.

Past `z = -40`, Gloom ticks 3.5/s. You should feel the rift as a pressure, not as a new UI. If Vale accidentally left `rift_enabled` true on a shared Player scene, the Vale would also accelerate. Vale must set `rift_enabled = false` on the instance.

## Shrine and summit

Last climb brazier. Mirror. Interact `[E]`. Walk-in currently fails (mask WORLD). After Pass A, walking in is the fantasy; E is the fallback.

Travel fade 0.5 s in, scene change, 0.7 s out. Gloom preserved. If the packed Vale is unloadable, toast “The glass would not open.” and fade lifts on the Stair. That path exists because a broken material once did that. Do not remove the failure toast.

## Shade event (inject at any dark stretch)

Stand off LightGrid until 100. `shade_spawned`. Cylinder 16 m behind. It does not collide with you until 1.1 m, then Hollow.

Bolt it. It unmakes. If Gloom is still 100, a new one must **not** appear (Pass A). Today it may. That single beat is the difference between “I fight the dark” and “the meter is a spawn clock.”

Kindling while it exists should unmake it without a lockout. Light wins instantly. Bolt wins with a cost: you still have to find fire.

## Hollow

0.9 s fade. Teleport checkpoint. Gloom 0. `hollowed` + `respawned`. Grade eases down. You keep hollow_count. Nothing reads it. Pass A whisper is enough.

Lava uses the same Hollow. Instant, no Shade required. Do not add a unique lava death. The night has one fail state.

## Demo and bench (optional)

F9 walks and kindles. Useful for captures. Not a story skip the owner needs in play.

F8 samples the Stair and pins a summary on F3. Do not add runtime markers to the tscn.

---

# 22. First Vale night, beat by beat

## Arrival

You should be at the gate, facing the night Travel asked for, Gloom unchanged. Camera spring must be 3.7 after Pass C. Today 4.4 makes you feel smaller and shows more sky; the aurora then dominates the first frame. That is pretty and wrong. The wanderer is the same person who climbed the Stair.

Title: Crimson Vale. Sixteen seconds over the aurora is prettier than on the Stair and still too long on a return trip.

## The argument on the ground

Look down before you walk.

- Path and stone should be dark wine. If they are pale, dress clobbered palette.
- Grass should not be icy cyan. If it is, `vale_grass` / `vale_fern` tints in the palette dict.
- River should be green, thick enough to read as a body, not a sheet. Water shader is 4 waves. Do not add a fifth for “quality.”
- Return glass should be ember, not Stair lilac. Shader default is purple. Drive it from `fire_color`.

This first look is Pass B. No amount of enemy polish saves a Vale that looks like a Stair leftover with a rose skybox.

## Deck and brazier

The dressed bridge replaced a baked deck that did not meet the banks. You walk ramps, not walls. Hide-under-span currently kills grass along a long AABB; shrink it to the deck so the approach still has a floor.

Deck brazier is unlit even if the scene file says otherwise. That is `vale_dress` forcing the tutorial: you kindle this night yourself. Keep that.

Kindle. LightGrid 11 m. River omnis also register 8.5 m. Standing on the water or the banks may already drain Gloom. Decide. If the river is holy, toast once: the water holds the dark. If only fire is holy, unregister river omnis from LightGrid and leave them as beauty.

## Forest and camps

Six posts, ~8–10 m off the path, clearance spiral so they are not in trunks. Visible. Leash 13–15. They must not enter the river (no nav, they will sink and snap home at y-8, which looks like a teleport).

Toad on a bank around `(5.81, 0.65, -1.75)` after the grove ray. Prop. Not a hill. Rim light must not be leftover violet.

Heart crystal is gone. Do not look for it. Ember crystals along the path stay; they are lamps, not the shrine.

StandingStones/Heart far away may still have a light. Palette hue-pulls it. Leave it. Do not walk out there to “finish the shrine.”

## Performance checkpoint

F3 at the gate, then on the bridge, then under canopy.

You are looking for: Balanced comfortably above 144; Cinematic allowed to dip, not to 40. If Cinematic is 40, SSAO + vol fog + canopy shadow is the stack — do not “fix” it by turning vis-range on ForestFloor. Fade grass in the terrain/foliage shader with `push_pos` if you must.

If someone re-enables Fill2 or dual triplanar, fps dies and this chapter is why you revert.

## Return

Walk-in and E. Fade ALWAYS so Esc cannot freeze it. Stair summit or Travel spawn, Gloom preserved. Sanctuary may be the only lit fire unless Pass E persisted kindles.

---

# 23. Gloom math (worked)

All rates are per second. Meter 0–100.

## Leaving sanctuary

Radius 11. At t=0 you step from 10.9 m to 11.1 m. `is_lit` flips. Gain 2.0/s.

| t | Gloom | Note |
| --- | --- | --- |
| 0 | 0 | last frame lit |
| 10 s | 20 | bar readable |
| 25 s | 50 | grade visible |
| 50 s | 100 | Shade |

Rift (`z < -40`, Stair only): 3.5/s. 100 in 28.6 s. That is the pressure of the lower stair. Do not “balance” it back to 2.0; it is the Stair’s identity.

## Kindling at 90

Drain 12/s. 90 → 0 in 7.5 s if you stand in the sphere. A −30 snap on kindle would put you at 60, then 5 s to clear. Either is readable. Silent 7.5 s is the current complaint.

## Wretch hit

+25. Two hits from 0 is 50. Four hits is 100 plus a Shade on the fourth if you were already dark. Strike rate: windup 0.42 + strike 0 + recover 0.55 ≈ 1 s cycle if you stand in range. A Wretch can fill the meter in four stands if you never kite. That is harsh and acceptable if occupancy lets you jostle. If you clip into them and take two hits a second through a wall, it is not acceptable.

Husk +32. Three hits to 96. Fourth Shade.

## Bolt vs Shade at 100

Unmake is instant. Meter still 100. Without lockout, next `_physics_process` spawns again. Lockout: either `gloom < 85` (player must find 1.25 s of light at drain 12, or 7.5 s of… no, they need light; in the dark gloom stays 100 so the threshold **must** be a timer, not only a meter check).

Correct lockout: `if gloom >= 100 and _shade == null and _shade_lock <= 0`. Bolt sets `_shade_lock = 2.0`. Light-zone dissipate does not need the lock; LightGrid prevents spawn anyway because `is_lit` is true.

Do not set lockout to 30 s. Two seconds is a beat. Ten seconds is a cooldown in a game that has no cooldowns except the bolt’s 0.42.

## Lantern

Not on the grid. Standing in pitch black with a belt lamp still gains 2.0/s. That is the design. The lamp is so you can see the ground, not so you are safe. Do not “fix” this unless the owner says the lantern should be a mobile sanctuary.

---

# 24. Enemy FSM (worked)

States: IDLE, CHASE, WINDUP, STRIKE, RECOVER, DEAD. Think 10 Hz. Physics every frame for move and gravity.

## IDLE

`_wish` zero or small. Face last dir. If player distance < chase_range **and** (not light_averse or slink allowed): go CHASE.

Light-averse today slinks rather than blocking CHASE. A dummy in a brazier radius still enters CHASE at ×0.45. Posts must not sit inside radius 11 of a start-lit fire or they will slink-chase the sanctuary forever.

Distance is 3D. A dummy on a ledge 12 m up is not a hunt. Good.

## CHASE

Move toward player at walk_speed. If distance > hunt_leash from **home** (not from player): return. Home is set deferred after spawn. If they fall below home.y − 8, snap. That is the river/lava trapdoor.

If distance to player < strike_range: WINDUP.

If player is gone (none in group): IDLE, walk home.

## WINDUP

0.42 s. Today calls `cast()` on the rig. That is the wand pose. Pass A: a melee animate flag, arms up, no staff.

## STRIKE

Instant `player.add_gloom(strike_gloom)` if in range. No ray. Pass A: ray WORLD, if hit skip gloom. Then RECOVER.

## RECOVER

0.55 s. Then CHASE if still in range else IDLE/home.

## DEAD

HP 0. `enemy_killed`. queue_free or a short dissolve. Spawner starts 10 s timer. Retry if player < 7 m or slot `is_lit`. So you cannot camp a spawn inside a kindled radius. Good.

## Sleep/wake

`sleep_range` 46 m still exists. `sleep()` used to hide them. Owner asked them visible on the post. Sleep should at most pause think, never `visible = false`. Wake loop looking for `PROCESS_MODE_DISABLED` is dead if sleep never sets it. Delete one or honour the other. Prefer: no sleep. 9 dummies at 10 Hz is free. Animate gate 16 m already saves the rig.

## Pose theft

`attach_rig()` uses the wanderer’s CharacterRig with `dress_default` off. `_legacy_pose` still holds a staff. The dummy is a wanderer silhouette with bark flesh. Melee pose is the in-place fix. A new skeleton is a rewrite. Do not.

---

# 25. Pass A — exact edits

Do these in one session. Pack once at the end. Do not rebake.

### A1. Shade lockout — `core/player/player.gd`

Where Shade is spawned at gloom >= 100, add `_shade_lock: float` decremented in `_physics_process`. Spawn only if `_shade_lock <= 0.0`. When the existing Shade is unmade by hit (detect `Groups.SHADE` empty after it was set, or connect to tree_exiting), set `_shade_lock = 2.0`. When LightGrid unmakes, leave lock at 0 (spawn is already blocked by `is_lit`).

Do not change gloom rates.

### A2. Mirror mask — `core/world/mirror_gate.gd` (or the Area in the scene)

`collision_mask = Layers.PLAYER`. Keep interact. Test both gates.

### A3. Travel ALWAYS — `autoload/travel.gd`

After creating `_fade_layer`, `_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS` and the same on `self` if tweens live on the autoload. Autoloads pause with the tree unless ALWAYS. Settings is ALWAYS; Travel must match.

### A4. Melee pose — `core/player/character_rig.gd` + enemy

Add `var melee := false` (or `style`). `_legacy_pose` branches: if melee, right arm forward/down, no wand wrist, left arm guard. `cast()` becomes a lunge if melee. `Wretch`/`Husk` set `melee = true` after `attach_rig()`. Player never sets it.

Do not change wanderer sockets or loadout.

### A5. Strike ray — `core/enemy/enemy.gd` STRIKE

`intersect_ray` from chest to player chest, mask WORLD. If collider is not the player (it will not be; player is layer PLAYER, not WORLD), skip gloom. If the ray hits WORLD, skip. If the ray hits nothing, apply gloom only if distance <= strike_range (already).

### A6. Bolt tscn + blast — `core/player/magic_bolt.gd` / `.tscn`

Set `BLAST` to ~1.2. Open the tscn and set collision_mask bits to WORLD | HURTBOX. Keep `_ready` overwrite as belt-and-suspenders.

### A7. Esc — `autoload/input_setup.gd`

Remove `KEY_ESCAPE` from `toggle_settings`. Keep F2 and Start. Leave `release_mouse` on Esc.

### A8. HP bar — `core/enemy/enemy.gd`

`_hp_bar.visible = _state == CHASE or _flash > 0.0 or hp < max_hp` (after first hit, hp < max). Hide when IDLE and full.

### A9. Spawner print

Delete `print("ENEMY plant slots="...)` in `enemy_spawner.gd`.

Pack. Relaunch. Run Appendix F Stair tests.

---

# 26. Pass B — exact edits

### B1. Albedo owner — `core/world/vale_dress.gd`

Search assignments to `albedo_color` / `albedo` on stone, path, deck. Remove those that fight `vale_palette.gd`. Dress may still swap meshes, instance the bridge, move the brazier, hide Heart.

### B2. Grass tint — `core/world/vale_palette.gd`

`vale_grass` and `vale_fern` colours: move from icy `(~0.52, 0.72, 1.05)` toward olive-wine, e.g. a dim `(0.45, 0.32, 0.28)` multiplied in the existing dict format. Keep `alpha_cut`, keep `push_pos`. Do not retouch PNGs if the tint is a material multiply.

### B3. Portal — `core/world/mirror_gate.gd` + `world/portal_glass.gdshader`

Set shader param from `fire_color` (already exported on the gate). Stair gate keeps lilac. Vale gate sets ember in `vale.gd` when it places or finds the mirror.

### B4. Hide AABB — wherever hide-under-span lives (`vale_dress` or palette)

Centre on dressed deck (`cz ≈ 6.17`), half-length ≈ 5.6, width the deck only. Do not cover the whole path corridor.

### B5. Camera — `world/vale.gd`

On the Player’s SpringArm, `spring_length = 3.7` in `_ready` before or after super. Match Stair.

### B6. Toad rim — `core/world/vale_toad.gd`

If it adds an OmniLight, `set_meta("light_class", "glimmer")` or colour it from the Vale fire. Do not leave a violet Omni that palette’s `_lights` misses because it spawned deferred.

### B7. River grid

One comment at the register call in `vale.gd`: either “river is a sanctuary” or “beauty only.” If beauty only, do not call `LightGrid.register` on those omnis. Keep `apply_illumination`.

Pack. Relaunch into Vale via the Stair glass so you test Travel too.

---

# 27. Pass C and D — exact edits

### C1. Floor — `core/player/player.gd` `_ready`

```
floor_snap_length = 0.5
floor_max_angle = deg_to_rad(46.0)
```

Enemies already set this. Player should too so unpacking the subtree cannot drop it.

### C2. Spring default

If `_arm.spring_length > 3.75` and the zone has not set a night-specific value, set 3.7. Cleaner: always 3.7 in Player, Vale/Stair only override if they ever need a different body (they do not).

### C3. Lantern — `core/items/lantern_piece.gd` `build`

`shadow_enabled = false` on the OmniLight3D before `add_child`. Policy remains a second clamp.

### D1. Audio nodes

`Brazier._set_lit(true)`: play a one-shot, start a loop `AudioStreamPlayer3D`. `Player.hollow()`: one-shot. `MagicBolt.explode`: one-shot. `vale.gd` river: loop at mid-span, max distance ~20 m.

No autoload. Streams as `.ogg` in `art/audio/`. If files are missing, skip the pack; do not ship silence players.

---

# 28. Atmosphere apply order (why fps died)

`Zone._apply_settings` calls `atmosphere.apply_zone_settings`. That function:

1. Sets fog, vol fog, glow **budget** (the clamp).
2. Applies SSAO from quality.
3. Culls / vis-range policy on named nodes; skips ENEMY, skips Lava Surface, skips span meshes.
4. Calls `surface_detail.apply` after darkening unlit materials.
5. Moon shadow distance from quality, then light_policy cap 30.

`vale.gd` order today:

1. Palette (materials, sky, some light colours).
2. Atmosphere far 68.
3. inherit_atmosphere.
4. River AABB + 6 omnis.
5. Toad, glimmers, enemies.
6. `finish_zone_setup()` → refresh lights + settings → atmosphere again.
7. Deferred `vale_dress`.

Dress after atmosphere can:

- Add lights that miss `refresh_lights` unless something calls it again.
- Reset material albedo (the palette fight).
- Spawn Fill2 if dress still thinks it should (it must not).

**Law:** palette owns colour. Atmosphere owns budget and cull. Dress owns meshes and positions. If dress needs lights registered, it must call `zone.refresh_lights()` or the lights must be present before `finish_zone_setup`.

The dual-triplanar lived in `surface_detail` and in leftover Cinematic comments. It sampled world XZ on giant trunks every pixel. AO maps from `gen_textures.py` still exist on disk; runtime must not sample them a second time. The generator can keep writing AO for a future cheap baked multiply. Do not wire it in `surface_detail` without a still *and* an F3 fps quote.

---

# 29. CharacterRig contract

Player may call:

- `animate(wish, sprint, on_floor, delta)`
- `cast()`
- `equip(piece)`
- sockets via `muzzle()`, `hand_r`, pelvis lantern — **through methods**, not bone strings in Player

Player may not:

- Set `Skeleton3D` bone poses
- `get_node("Visual/Armature/...")`
- Parent a bolt to `hand_r` (parent to `current_scene`, origin at muzzle)

Rig owns:

- Stride
- Cloth spring (`_cape` name is leftover; not a cape mesh)
- Void face
- `driven` (Player sets true and `set_process(false)` so only Player’s physics drives animate)
- Trail quiet at sprint
- `walk_speed` / `sprint_speed` copies from Player

Enemies attach a rig with default dress off, then `enemy_body` paints sockets. They should set `melee` (Pass A). They should not `equip()` the wanderer staff.

`@tool` `_ready` on the rig must not `queue_free` when `_pelvis` exists. That bug ate characters in the editor. Do not “clean up” the tool path without the owner in the editor.

---

# 30. LightPolicy classes (do not flatten)

| Class | Typical user | Shadows | Vol fog energy | Fade |
| --- | --- | --- | --- | --- |
| beacon | lit brazier | off | modest | long |
| hero | gothic spots | High only | modest | long |
| hero_fill | gothic fill | off | low | medium |
| fill | unlit coals, junk | off | low | short |
| glimmer | shards, wisps | off | 0.28 | 16 m |
| lava | rift | off | as now | skip vis-range |
| river | Vale omnis | off | 0.9 | 28 m |
| player_lantern | belt | **off** | 0 | n/a |
| player_orb | bolt, staff | off | 0 | n/a |
| moon | DirectionalLight3D | on, 30 m cap | 1.15 then policy | n/a |

`apply_illumination` multiplies fill/lava/river/glimmer/hero **once** (`_illum` meta). That is the legal “make crystals light the ground.” Running it twice stacks energy. Do not call it in a loop.

Unlit brazier uses class fill, energy 0.25, range 2.5. Lit uses beacon, energy 4.6, range 14.5, grid 11. The mismatch (grid 11 vs range 14.5) means you can see firelight on stone a little past where Gloom drains. That is acceptable: the eye outruns the mechanic by a couple of metres.

---

# 31. Agent operating procedure

A session that “improves the game” without this list will repeat October.

1. Read `AGENTS.md`, this bible, `umbral-donts`, and the skill for the subsystem (`umbral-player`, `umbral-nights`, `umbral-culling`, `umbral-pack`, `umbral-pipeline`).
2. Do not open `DARK_FANTASY_REVIEW.md` as a task list.
3. Do not headless-rebake nights.
4. Do not pkill Godot.
5. If the request is “more detail,” change albedo/tint/palette, not shader sample count.
6. If the request is “it stutters,” strip lights and samples, do not vis-range span meshes.
7. If the request is “fix enemies,” check spawn null, vis-range, LightGrid idle, leash, pose — in that order. History is Appendix E.
8. Pack Linux pck, copy, codesign, touch, quote `%H:%M:%S`, ask for quit/relaunch.
9. Do not declare done from editor F5.
10. Do not add autoloads, managers, or a third night “while you’re here.”

Hung process: `godot --check-only` will hang. Import `--quit` is the legal headless. If a `-s` tool hangs, it is waiting on a window; add `--quit` or do not run it.

---

# 32. Traceability (chapter → files)

| Chapter | Primary files |
| --- | --- |
| 1 What it is | `project.godot`, `AGENTS.md` |
| 2 Fantasy | `vale_palette.gd`, `grade*.gdshader`, `portal_glass.gdshader` |
| 3 Loop | `player.gd`, `light_grid.gd`, `brazier.gd`, `shade.gd` |
| 4 Stair | `world/main.gd`, `world/main.tscn`, `gothic.gd` |
| 5 Vale | `world/vale.gd`, `vale_dress.gd`, `vale_toad.gd` |
| 6 Wanderer | `player.gd`, `character_rig.gd`, `default_loadout.gd` |
| 7 Bolt | `player.gd` `_try_cast`, `magic_bolt.gd` |
| 8 Shade | `player.gd`, `shade.gd` |
| 9 Melee | `enemy.gd`, `wretch.gd`, `husk.gd`, `enemy_body.gd`, `enemy_spawner.gd` |
| 10 Light | `light_policy.gd`, `atmosphere.gd`, `brazier.gd` |
| 11 HUD | `ui/hud.gd`, `input_setup.gd` |
| 12 Settings | `settings.gd`, `zone.gd`, `atmosphere.gd` |
| 13 Travel | `travel.gd`, `mirror_gate.gd` |
| 14 Audio | nodes above; `art/audio/` (does not exist yet) |
| 15 Perf | `atmosphere.gd`, `surface_detail.gd`, `vale_palette.gd`, `glimmers.gd` |
| 16 Pipeline | `AGENTS.md`, `umbral-pack`, `umbral-pipeline` |
| 17 Spine | `zone.gd`, `groups`, `layers.gd` |
| 18 Play path | Downloads app |
| 19 Order | this file Pass A–F |
| 20 Do not add | `umbral-donts` |

---

# 33. Glossary

- **Night** — a `Zone` scene you can walk. Stair and Vale. Not the lab.
- **Pack** — Linux export-pack into the Mac app Resources. Not a rebake. Not a macOS export.
- **Bake** — GPU write of architecture MultiMeshes into `main.tscn` / `vale.tscn`. Editor only.
- **Dress** — runtime code that instances props, paints materials, places gates.
- **LightGrid** — gameplay safe-radius list. Not the renderer.
- **LightPolicy** — per-class fade, shadow, fog energy.
- **Gloom** — 0–100 meter. Not HP. Hollow is the fail.
- **Shade** — spawn at 100. Cylinder. Parked look.
- **Hollow** — fade, checkpoint, gloom 0.
- **Kindle** — brazier on, register grid, checkpoint, toast.
- **Wretch / Husk** — 3 HP / 5 HP melee. Only enemy types.
- **Wanderer** — Player + CharacterRig + loadout. Do not generate a new one.
- **Gothic** — window spots on the Stair. Not a cathedral glb.
- **Push pos** — shader global, player position, foliage/cloth.
- **Span mesh** — long ArrayMesh whose origin is not its visual centre (Stair, lava Surface).
- **Downloads app** — the only playable that counts.

---

# 34. Open decisions (do not stall Pass A on these)

Pass A does not need owner input. These do, if you reach them:

1. **River as sanctuary or beauty.** Default in this bible: beauty only (unregister). Override if they say the water should heal.
2. **Kindle snap vs toast.** Default: toast that names the slow drain; no snap. Snap −30 if they still think kindle is broken.
3. **Persist kindles across Travel.** Default: Pass E, session only, no save file.
4. **Audio sources.** Default: four one-shots/loops on nodes. Skip if no files.
5. **PROPS layer.** Default: implement on bridge rails and set spring mask WORLD only, or delete the layer comment. Do not add a sixth physics layer.

Do not AskQuestion these in a combat hotfix session.

---

# 35. README lies (line-level)

When asked to update README, replace at least:

- “One playable zone” → two nights, Stair boot, Vale via summit glass.
- “No combat” → staff bolt, Shade, Wretch, Husk. No wanderer HP bar.
- “No audio” → still true until Pass D.
- “Characters are placeholders” → wanderer is the character; do not rewrite. Enemies are dressed dummies.
- “Performance unprofiled” → glow budget locked; Vale 144 fps is a floor; F3 exists.
- Windows exe / macOS zip as playable → Linux pck in the Mac app.

Until that edit is asked, this bible is the map.

Handover 31 Oct is wrong on: Vale existence, combat, height 1080, gloom 3.6/6.3, settings only in main.gd, macOS zip, Esc as free-mouse only. Skills win.

`DARK_FANTASY_REVIEW.md` bloom 0.18, gothic architecture, far DoF, guardian: rejected.

---

# 36. Shader and material inventory (touch with care)

| Asset | Night | Notes |
| --- | --- | --- |
| `world/grade.gdshader` | Stair | Protects teal and blood reds |
| `world/grade_vale.gdshader` | Vale | Crimson band 340–20 wrap |
| `world/portal_glass.gdshader` | both | Default purple; drive colour |
| `world/vale_aurora.gdshader` | Vale | Identity. Do not hue-shift to violet |
| `world/water.gdshader` | Vale (+) | 4 waves. No n3 |
| `world/zones/terrain.gdshader` | both | `detail` uniform 0; extra grit gated |
| `core/player/robe_wave.gdshader` | wanderer | Cloth. Not `arcane_robe` |
| `core/player/arcane_robe.gdshader` | unused on wanderer | Do not assign |
| `core/enemy/health_bar.gdshader` | enemies | Trail hold 0.28 / rate 1.4 |
| Lava material | Stair | Emission 7.4, extra cull 80 |
| ForestFloor MultiMeshes | both | Custom AABB; headless bake kills them |
| `gen_textures.py` 1024 maps | disk | AO unused at runtime on purpose |

Triplanar on enemy flesh must be **local**, or world crawl as they walk. World triplanar on static trunks is fine at sharpness <= 2.0 without a second overlay.

---

# 37. Spawn and parenting rules

| Thing | Parent | Why |
| --- | --- | --- |
| MagicBolt | `current_scene` | Player parent inherits layers; staff parent inherits motion |
| Bolt burst particles | pooled on `current_scene` | Do not leak under Player |
| Shade | `current_scene` | Lives past? no, but must not follow Player transform |
| Enemies | `current_scene` via `Enemy.spawn` | Not under spawner node that might free |
| HUD | Zone | Frees on Travel; reconnect Events |
| Settings menu | Zone or always-on child | ALWAYS process |
| Travel fade | Travel autoload | Must ALWAYS; survives change_scene |
| Toad | Vale / current_scene | Prop |
| Dressed bridge | Vale | Replaces baked deck |

`Enemy.spawn` exists because `Wretch.new() as Enemy` was null when the script was loaded dynamically without the global class cache. After import, `class_name` works. Still use `spawn`.

---

# 38. Pause and process modes

| Node | Mode | Why |
| --- | --- | --- |
| Tree | `paused` true when settings open | Legal pause |
| Settings autoload | ALWAYS | Persist + apply while paused |
| Settings menu | ALWAYS | Can unpause |
| Travel fade / autoload | **must ALWAYS** | Hop mid-pause |
| HUD | inherit | Pauses with tree |
| Player | inherit | No walking in menus |
| Enemies | inherit | No sliding in menus |
| Braziers | inherit | Flame pause is fine |
| Demo/F8 | inherit | Do not bench while paused |

Never `Engine.time_scale = 0`. It breaks tweens, particles, and Travel.

---

# 39. Input ownership

Gameplay: `Player._unhandled_input` and `_physics_process`. Interact and cast from unhandled so a menu that handles the event wins.

Menus: `set_input_as_handled()` on consume.

Click-to-capture: mouse button while not captured captures and does not cast (`_try_cast` checks captured for mouse buttons). Keyboard Q still casts uncaptured; that is odd and acceptable.

Autopilot (F9 / tests): `_unhandled_input` returns early. Physics still runs `_autopilot`.

`toggle_settings` currently includes Esc, which is also `release_mouse`. Settings menu is processed first as ALWAYS overlay. Pass A unbinds Esc from settings.

Pad: Start opens settings. Face buttons match Xbox. Left stick click sprint is easy to hit by accident; leave it unless the owner complains.

---

# 40. What “perfect” looks like on one screen

**Stair, mid-flight, one Wretch hunting, one brazier you just kindled, Gloom at 40.**

- Stone reads cool and dark except the fire cone and window hits.
- Wanderer is a hole. Staff orb lilac. Lantern amber, no shadow.
- Wretch is bark-flesh, melee pose, bumpable, not a staff beggar.
- Bar is a 3 px wound, not a health pack UI.
- No bloom halo swallowing the vortex.
- Bolt lands on the crosshair.
- fps boringly high.

**Vale, on the dressed deck, brazier kindled, looking at the return glass.**

- Wine ground, green water, rose sky, ember glass.
- Grass on the banks, not under the boards.
- Camps visible in the trees, not in the river.
- Toad is a toad.
- F3 > 144 Balanced.
- Same camera body as the Stair.

If a change does not move one of those pixels or beats, it is not this bible’s work.

---

# 41. Movement feel in `player.gd`

The wanderer is not a Souls character and not a platformer. The numbers in `_physics_process` are the whole game’s “hand.”

**Grounded lerp.** Wish is yaw-basis times WASD. Target is wish × walk 4.5 or sprint 7.5. Horizontal velocity lerps at `accel` 14 if you have wish, `decel` 20 if you do not, `air_accel` 4 if you are off the floor. Stopping is snappier than starting. That is why the body does not ice-skate. Do not unify accel and decel “for simplicity.”

**Jump.** Coyote 0.1 and buffer 0.12 exist because a jump one frame late felt like the game ate the input. Hold Space on landing refills the buffer while `velocity.y <= 0`, so you can bunny-hop the stair without re-tapping. That is a feature. Do not “fix” it unless the owner says the stair is too easy to skip. There is no step-up; small lips will stop you. Floor snap 0.5 is supposed to eat those lips. Set it in `_ready`.

**Fall death.** `y < -40` calls `_respawn_now` immediately, no 0.9 s Hollow fade. Lava Area Hollows with fade. Two fail paths. Unifying them is optional polish; not Pass A.

**Camera.** Sprint FOV kick +6, lerp rate 6. Landing dip from impact velocity, pitch node dips 0.12 rad at full, recovers at 3/s. Base FOV is Settings.fov. Do not bake 75 into the Camera3D. Spring arm excludes the player RID so it does not collide the capsule.

**Animate.** Visual yaw lerps to travel at rate 10, same as enemy `TURN_RATE`. `animate(velocity, on_floor, delta)` — not wish. The rig sees actual slide, including knockback if you add it.

**Interact is a cast.** `_try_interact` calls `_visual.cast()` then `interact()`. Kindling plays the staff gesture. That is charming. After melee pose exists, enemies lunge on `cast()`; the wanderer must keep the staff gesture. Branch on `melee`.

**Gloom update** is in physics, not process. Grade in Zone process eases at 0.8 toward the ratio. The bar in HUD should follow `gloom_changed` directly, not the eased grade, or the UI lags the danger.

**Shade spawn** has a toast: “The dark has taken shape. Find light.” First time is enough. Gate it with a `var _shade_warned` or the toast will fire every lockout expiry if you are still at 100. Pass A lockout plus a once-per-Hollow warning is cleaner.

**Autopilot** is for F9 and tests. It must not read WASD. It must still update gloom, or a demo walk will not spawn a Shade when you want a capture of one.

---

# 42. HUD implementation notes

`ui/hud.gd` (names may vary slightly; grep `Gloom` and `interact_hint`):

- Connect `Events.gloom_changed`, `interact_hint`, `toast`, `zone_entered`, `hollowed`, `shade_spawned` if you add one-shot copy.
- Gloom fill `anchor_right` or a ColorRect width = 220 * ratio. Colour stays 0.78/0.22/0.18. Do not turn it green when lit. Lit is the world, not the bar.
- Prompt: show when text nonempty. Hide on `""`. Travel already emits `interact_hint("")` before the hop so a stale “[E] Kindle” does not sit on the Vale title.
- Toast queue of 3, 4 s each. Kindle toast is long enough. Do not stack five kindle toasts if the player mash-Es; `can_interact` is false once lit, so that is already handled.
- Zone title: CanvasItem modulate fade. Cut hold so total ~8 s after Pass A, or skip when `Travel.pending` was true on arrival (returning).
- Crosshair is a Control, not a 3D decal. `MOUSE_FILTER_IGNORE` so clicks pass. Colour cream 0.55 alpha. Do not pulse it with gloom.

Settings menu must call `get_viewport().set_input_as_handled()` on Esc/F2 so Player does not also release mouse in a weird order. After Pass A, Esc will only release mouse while the menu is closed, which is what the owner wants in play.

Do not put the settings menu only under a room node that `change_scene` deletes without Travel restoring it. Today it is per-night instance. Fine.

---

# 43. `vale.gd` `_ready` order (live)

`vale.gd` extends Zone and **does** call `super._ready()` first. That connects gloom and settings. Do not drop the super.

Live order:

1. `super._ready()`
2. `Events.zone_entered.emit("THE CRIMSON VALE", "red water, stone, and a watching sky")`
3. `vale_palette.apply(self, _env, _moon)`
4. `atmosphere.apply(..., 68.0, pal.FOG_*)`
5. `pal.inherit_atmosphere(_env)` then `pal._canopy_shade(self)`
6. `_rose_flare()` — SkyFlare quad to rose `(1.0, 0.58, 0.62)`
7. `_hide_bridge_crystal()` — Heart and AltarLight `queue_free`
8. `_thin_river_fog()` — RiverBreath density 0.03, height 2
9. `_show_river()` — custom AABB, extra_cull 8, vis-range 0, ignore occlusion
10. `_light_river()` — six omnis, class river, energy 2.2, range 10, colour `(0.28, 1.35, 0.42)`, **`LightGrid.register(light, 8.5)`**, `refresh_lights()`
11. `_river_probe()` — ReflectionProbe UPDATE_ONCE, box projection, size `(42, 8, 28)`
12. `_spawn_glimmers()` — seed 404, skip_river, skip_shards, rose palettes
13. `_spawn_toad()`
14. `enemy_spawner.seed_vale`
15. `finish_zone_setup()`
16. `call_deferred("_dress_vale")` which waits two physics frames then `vale_dress.dress`
17. Capture mouse if not already captured
18. `--shot` stills path

**Gaps in this order.** Spring length is not set (Stair sets 3.7 in `main.gd`; Vale keeps the baked 4.4). `rift_enabled = false` is on the baked Player in `vale.tscn`, not in this `_ready` — keep it there, or set it in `_ready` so a Player unpack cannot restore rift rate. Dress runs **after** `finish_zone_setup`, so new lights from dress miss the first `refresh_lights` unless dress calls it. Palette then dress is the albedo fight.

**River is currently a sanctuary.** Six omnis on LightGrid at 8.5 m. The bridge drains Gloom without kindling. Pass B7 is a real change if you want fire-only safety: delete those `LightGrid.register` lines and keep the omnis.

File header still says “violet night.” The emit title and the aurora are crimson. Fix the comment when you touch the file.

`inherit_atmosphere` copies Stair-like glow clamp onto Vale. Do not inherit Stair fog colour. Vale fog is wine.

---

# 44. Stair `main.gd` order

1. Super ready / connections.
2. Gothic `raise` three stations.
3. Summit MirrorGate in code, not terrain snap. `fire_color` lilac.
4. Demo dress / seated props / stone bodies as today’s dress path.
5. Glimmers seed 11, skip corridor, skip shards.
6. Sanctuary brazier left `start_lit`. Climb braziers unlit.
7. Enemies `seed_stair`.
8. `finish_zone_setup()`.
9. Optional `--test-shade` CLI.

Lava KillVolume mask PLAYER. Surface extra_cull 80, vis-range skip.

Player spawn if not Travel: sanctuary `(0, sanct_top + 0.2, 26.5)` — numbers from dress; do not hardcode a new vector without measuring.

---

# 45. Glimmers and crystals (what stays off)

`core/world/glimmers.gd`:

- Cap lights 6.
- Wisps 3.
- Buds 4, terrain `detail` 0.
- Fireflies 1 emitter × 12 particles, no turbulence.
- Orb segments 8 / 5.
- `_scatter_shards` **off** on both nights. Those were the “random diamond lights.” Do not turn the bool back on to “fill the Vale.”
- Skip corridor on Stair so the climb is not a disco.
- Skip river on Vale so omnis and wisps do not fight.

Ember crystals and CrystalLights on the Vale path are **baked / dressed lamps**, not shards. They stay. Heart and AltarLight stay gone.

`apply_illumination` is why crystals actually light stone. If you disable it, the path goes dead and someone will raise bloom. Keep illumination; keep bloom 0.06.

---

# 46. Gothic kit (lights only)

`core/world/gothic.gd` `raise` places three stations. Each is roughly: HeroSpot, fill, gobo or cookie if present, shaft mist particles. Names like `HeroSpot`. Class hero / hero_fill.

Do not instance `gothic_bay.glb`. Do not add a fourth station to match a skill that says “four lanterns.” Four **gameplay** braziers on the climb plus sanctuary fire are the lanterns. Gothic is the windows.

Shaft mist is particles; `_thin_particles` in atmosphere must **skip** names containing `flame` and should not gut shaft mist below readability. If stations look empty, check thin_particles keep ratio, not the glb.

Vale has no gothic kit. Do not “bring gothic to the Vale” as architecture or as three more hero spots. Vale’s hero lights are path lanterns and the deck fire.

---

# 47. ForestFloor and the AABB

Grass is MultiMesh. Custom AABB must enclose every instance. Headless bake serializes empty AABB → Godot frustum-culls the whole floor → “grass pop / grass gone.”

Never:

- Headless `--import` that re-saves the night tscn with MultiMesh data
- Set `visibility_range_begin/end` on the ForestFloor node (origin-based)
- Scale instances to 0.001 in a huge hide AABB (Vale path already does this too wide)

Legal:

- Shader fade with `push_pos`
- `extra_cull_margin` if a still shows pop at the feet
- GPU bake in the editor when the owner is present

`umbral-culling` is the skill. This chapter exists so the bible does not forget it between enemy tickets.

---

# 48. Settings keys and quality mapping

`autoload/settings.gd` (persist user://):

Typical fields: `quality_preset`, `grade_enabled`, `ssao_enabled`, `glow_enabled`, `fog_enabled`, `fullscreen`, `vsync`, `render_scale`, `window_size_index`, `mouse_sensitivity`, `fov`, `dof_enabled` (ignored for far DoF).

`atmosphere.apply_quality` / `apply_zone_settings`:

- Preset 0 Performance: vol fog off, cheaper shadows, SSAO off unless the checkbox fights it — checkbox should follow preset.
- Glow enabled may be false on Performance. Intensity when on is still 0.62.
- `render_height_cap()` 960.
- F4 cycles `QUICK_SCALES` `[0, 1, 0.85, 0.7, 0.5]` on the Zone. 0 is a debug hide; be aware.

Cinematic is look-dev. It is allowed to be heavier. It is not allowed to undo the glow budget. The clamp in `_fog` / `_glow_budget` is the law, not the Environment resource in the tscn. Baked env can say bloom 0.2; apply overwrites it. If you “fix” bloom by editing the tscn only, play may still look correct because apply runs — until someone comments out the clamp. Leave the clamp. Leave a comment.

---

# 49. Anti-patterns (short, memorise)

1. **New autoload for one function.** Put the function on the node or on a RefCounted helper (`atmosphere.gd` is a RefCounted, not an autoload).
2. **`as Enemy` after `Script.new()`.** Use `Enemy.spawn`.
3. **`static var x` and `static func x()`.** GDScript clash.
4. **`visible = false` to optimise characters.** They vanish and the owner files “invisible enemies.”
5. **vis-range on a long mesh.** Stair, lava, terrain.
6. **Headless rebake.** Grass death.
7. **`--check-only`.** Hang.
8. **pkill Godot.** Owner’s editor.
9. **Dual triplanar + AO overlay.** Vale fps.
10. **Fill2 shadows on.** Vale fps.
11. **Parent bolt to staff.** Misses.
12. **Aim bolt parallel to camera.** OTS miss. Use `_look_target`.
13. **Esc on two actions.** Settings wins.
14. **Travel not ALWAYS.** Frozen fade.
15. **Mirror mask WORLD.** Walk-in dead.
16. **Dress clobbers palette.** Pale Vale.
17. **Icy grass multiply.** Cyan fields.
18. **Shader default portal colour.** Purple Vale glass.
19. **`arcane_robe` on wanderer.** Rejected.
20. **Restore Heart because the node still exists.** Rejected.
21. **Shards on because glimmers has a bool.** Rejected.
22. **Generate a new wanderer.** Rejected.
23. **Bloom to make lamps read.** Use `apply_illumination`.
24. **Lantern shadows for quality.** Off.
25. **time_scale 0.** Breaks Travel.
26. **GameManager.** Events + Travel + LightGrid.
27. **AudioManager.** Sound on the node.
28. **Third enemy “for variety.”** Perfect two.
29. **HP bar on the wanderer.** Gloom is the meter.
30. **README as task list.** Stale.

---

# 50. Week plan if this is scheduled

Not a promise. A way to not do everything in one unhinged night.

**Day 1 — Pass A.** Combat honesty. Pack. Play Stair 10 min, Vale hop, Esc, Shade bolt. Stop.

**Day 2 — Pass B.** Vale identity. Pack. Stills at gate, deck, glass. F3. Stop.

**Day 3 — Pass C.** Floor snap, lantern shadows, Vale spring if not done in B. Pack. Walk both nights for body feel.

**Day 4 — Audio if files exist.** Else skip.

**Day 5 — Pass E persistence if kindles resetting annoys the owner.** Else skip.

**Later, only if asked.** README. Handover rewrite. Skill gloom number fix. PROPS layer. Shade as CharacterBody3D. Local triplanar on dummy flesh. Husk capsule scale.

Do not schedule a “detail week” that reopens `surface_detail.gd`.

---

# 51. Skill drifts to fix when you are already in those files

Do not make a docs-only PR unless asked. When you touch the skill:

- `umbral-player`: gloom 2.0 / 3.5 not 3.6 / 6.3; cloth `robe_wave.gdshader`; interact also triggers `cast()` pose; Vale spring should be 3.7.
- Architecture rule “two layers, capsule on Player only”: note HURTBOX / INTERACT / PROPS and enemy capsules, or update the rule.
- “Four stair lanterns” vs three gothic stations: write both sentences so agents stop adding a window.

This bible already contains the live numbers. Skills should catch up so the next session does not “restore” 3.6/s.

---

# 52. `LightGrid` implementation caveats

Linear scan of a small array. Fine for < 20 zones. Each register is `{node, r2}`. `is_lit` uses `global_position.distance_squared_to`. If a brazier is freed without unregister, you crash or always-lit. `Travel.go` calls `clear()` on hop. Brazier `_set_lit(false)` unregisters; there is no gameplay unkindle, but start-unlit then lit is the path.

Mirrors register on ready. They are always “lit” for Gloom. Standing at the glass is safe. That is a nice accident. Keep it.

River omnis: if registered, the bridge is a linear sanctuary. That collapses the Vale’s “kindle the deck” tutorial. Default this bible: do not register.

Player position is the capsule origin, not the head. A 2 m tall wanderer with origin at feet might still be “in” an 11 m sphere when the camera is out. Fine.

Do not spatial-partition LightGrid. Nine lights.

---

# 53. `MagicBolt` burst and pool

`explode` hurts BLAST radius, hides core, stops trail, `_burst` from a static pool of GPUParticles3D parented to the scene, flashes the omni 2.4 / range 7, tweens energy 0 in 0.28 s, waits 0.55, `queue_free`. `_hurt_radius` uses a sphere query, mask HURTBOX, walks parents for `take_hit`, de-dupes with `_hit_ids`.

Tighten BLAST. Keep the 1.05 m probe as the “touched a hurtbox while flying” radius so you do not need a direct collider on thin husks.

`light_class` player_orb, no shadows, no vol fog. Do not class it glimmer or it will pick up illumination multiply and bloom the camera.

`.tscn` mask 1 is a lie. Fix the file.

Smoke `_smoke_bolt.gd` instantiates and quits. Extend it to `direction = Vector3.FORWARD`, `await` 0.2 s, or delete it so nobody trusts it.

---

# 54. Shade behaviour (mesh parked)

`core/world/shade.gd`: group SHADE, speed 5.2, touch 1.1 Hollows, `take_hit` unmakes, LightGrid dissipate from Player. No WORLD collision. Eyes HDR. Smoke particles. Hurt sphere HURTBOX so bolts hit.

Flying through the stair is a wraith. Flying through the sanctuary disc and Hollowing you on the safe side of the fire is a bug. If you add a WORLD ray toward the player, the Shade stops at the disc and you can kindle in peace. That is behaviour, not a mesh rewrite. Allowed.

Do not give it 50 HP. One bolt is the skill. Lockout is the beat.

Scale-in / scale-out is the unmake. Let it finish. Lockout 2 s covers the animation.

---

# 55. Occupancy (why you walk through Wretches)

Player mask WORLD only. Enemy layer HURTBOX, mask WORLD. They do not see each other. Bolts see HURTBOX. You slide through.

In-place options:

- Player mask WORLD | HURTBOX — you bump enemies, they need to not explode from `move_and_slide` on the player. Enemy mask stays WORLD so they do not push you into lava easily… actually if you mask HURTBOX you push them. Try it. If they jostle you off the stair, revert.
- A separate bump Area on the enemy, layer unused, or use PROPS. Heavy.
- Keep ghost melee but ray the strike so they cannot gloom through walls. Pass A minimum.

Recommended: Pass A ray only. Occupancy as a follow-up if ghosting still feels wrong in play.

---

# 56. Copy deck (toasts and titles)

Existing:

- Kindle: “Brazier kindled. Your light remembers this place.”
- Shade: “The dark has taken shape. Find light.”
- Travel fail: “The glass would not open.”
- Interact brazier: “[E]  Kindle the brazier”
- Gates: whatever `interact_text` is now (glass remembers / step through).

Add, once:

- First Wretch strike: “They do not kill. They fill the dark.”
- Kindle optional second line only if people still think kindle is broken: “Stand in the fire. The dark leaves slowly.”
- River if sanctuary: “The water holds the dark.”
- Hollow whisper: use `hollow_count` in a 2 s label, not a sermon.

Do not add a narrator.

Titles: “Stair of Ascension” / “Crimson Vale” plus one subtitle each. Do not change names. The owner’s nights are named.

---

# 57. Capture and stills

Existing capture path (F9 demo, or a tools script) is for look-dev. After Pass B, stills that matter:

1. Stair sanctuary, looking up the flight, window hits visible, no HP bars.
2. Stair mid, Wretch in melee pose, fire cone, wanderer as hole.
3. Stair summit glass, lilac, not snapped into hill.
4. Vale gate, wine ground, rose sky, green river.
5. Vale deck kindled, grass on banks, ember glass.
6. Vale F3 overlay at gate showing fps.

Do not use Cinematic bloom screenshots as proof the budget changed. The clamp holds.

---

# 58. Risk register

| Change | Risk | Mitigation |
| --- | --- | --- |
| Shade lockout | Feels like the Shade “broke” | 2 s only; light still unmakes |
| Mirror PLAYER mask | Hill retriggers travel | Area small; once `_busy` |
| Travel ALWAYS | Menu + hop race | `_busy` already gates re-entry |
| Melee pose | Wanderer arms if flag leaks | Default false |
| Strike ray | Never hits on stairs | Ray to chest, not feet |
| BLAST 1.2 | Husk feels tanky | 5 HP was already 5 bolts |
| Unbind Esc | Owner uses Esc for settings | F2; say so in toast once? no. Tell them in chat |
| Palette/dress split | Grey materials if dress stops writing and palette missed a mesh | Grep albedo in both files |
| Grass tint | Cards go brown-dead | Tune in palette, pack, look |
| Unregister river | Gloom spikes on bridge | Intended if fire-only |
| Audio | Beeps | Skip without real streams |
| Occupancy | Push off stair | After Pass A, play before keep |

---

# 59. Definition of done for the game, not the doc

The bible is done when this file is in `docs/` and `AGENTS.md` points at it.

The **game** is not done because this file exists. The game is done for this phase when Pass A–C are packed and the Appendix F tests pass on the Downloads app.

Do not implement Pass A in the same session as writing this file unless the owner says to execute the polish. They asked for the document. The document is the deliverable. Polish is the next ask.

---

# Appendix G — Chapter index (full)

0. How to read / Verdict / Law / Stale paper
1. What the game is now
2. Fantasy and tone
3. The night as a loop
4. Stair of Ascension
5. Crimson Vale
6. Wanderer feel
7. Staff and bolt
8. Gloom, Shade, Hollow
9. Wretch and Husk
10. Light as gameplay
11. HUD and menus
12. Settings and quality
13. Travel between nights
14. Audio
15. Performance and culling
16. Pipeline, bake, pack
17. Architecture
18. Play path
19. Order of work
20. What not to add
21. First Stair night, beat by beat
22. First Vale night, beat by beat
23. Gloom math
24. Enemy FSM
25. Pass A exact edits
26. Pass B exact edits
27. Pass C and D exact edits
28. Atmosphere apply order
29. CharacterRig contract
30. LightPolicy classes
31. Agent operating procedure
32. Traceability
33. Glossary
34. Open decisions
35. README lies
36. Shader inventory
37. Spawn and parenting
38. Pause and process modes
39. Input ownership
40. What perfect looks like
41. Movement feel in player.gd
42. HUD implementation notes
43. vale.gd _ready order
44. Stair main.gd order
45. Glimmers and crystals
46. Gothic kit
47. ForestFloor and the AABB
48. Settings keys and quality
49. Anti-patterns
50. Week plan
51. Skill drifts
52. LightGrid caveats
53. MagicBolt burst and pool
54. Shade behaviour
55. Occupancy
56. Copy deck
57. Capture and stills
58. Risk register
59. Definition of done
A–F. File map, signals, numbers, rejected art, failure log, pack tests

---

*End of bible. Perfect what is in place. Pack. Play the Downloads app. Do not add a third night.*


