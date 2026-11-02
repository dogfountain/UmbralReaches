# Umbral Reaches — Zone Expansion Plan

Status: design, nothing built yet. Written 2 Nov 2026 against the current `main.tscn` (Ascension night).
Audience: Luke (approve and pick the order), then Cursor or Claude (implement one phase at a time).

## 0. Ground rules (carry into every phase)

- **Never headless-rebake `main.tscn`.** New areas are **separate sub-scenes**. `main.gd` instances them at runtime through an `AreaStreamer`, so the hub file never changes. Baking each area's own `.tscn` with its own tool is fine.
- **Don't fight the existing heightfield.** The baked terrain covers x −130..130, z −170..110 (`tools/bake_main.gd height()`). Each area goes in one of these places:
  - inside a cliff (an interior, with no terrain conflict);
  - on top of the existing cliff plateaus (dress the terrain that is already there);
  - down in the chasm (props over lava);
  - in its own zone scene reached by mirror or rift travel (`Travel.go`, which already exists).
- **Fixed look budget:**
  - Glow: intensity 0.62, bloom 0.06, threshold 1.15, levels 0–1.
  - No anti-aliasing.
  - Emissive art is tuned to that budget, not the other way round.
- **Per-area perf budget (M4 Pro, 960-tall buffer):**
  - ≤ 350 draws and ≤ 1.2 M primitives inside the area, ≤ 6 shadowed lights.
  - 1% low ≥ 110 fps, measured with `--perf-baseline` standing points added for each area.
  - The current hub is already at 769 draws at the sanctuary, so areas must not stack on top of it. That is what streaming is for.
- **Every area ends in a brazier and a Reliquary.**
  - The brazier is a checkpoint and a light zone.
  - The Reliquary is a skill variant (section 7), so exploring feeds combat variety.

## 1. World map

```
                                   N (−z)
                    ┌──────────────────────────────────┐
                    │   CATHEDRAL OF THE INWARD SKY     │  separate zone scene
                    │   (entered through summit rift)   │  y 25–45 feel, own terrain
                    └───────────────▲──────────────────┘
                                    │ rift at summit (0, 24.5, −83.5)
 ┌───────────────┐      ┌───────────┴───────────┐      ┌────────────────────┐
 │  HOLLOW WOOD   │      │   STAIR + SUMMIT (hub) │      │  OSSUARY TERRACE    │
 │  west plateau  │◄────►│   chasm / lava below   │◄────►│  inside east cliff  │
 │  x −50..−125   │ root │                        │ bone │  x 34..70 interior  │
 │  y 20–30       │ ramp │     ▼ spiral descent   │bridge│  y 4–14             │
 └───────────────┘      │   EMBER RIFT (chasm    │      └─────────┬──────────┘
          ▲             │   floor, y −15)        │                │ drowned crypt mirror
          │ shrine      └───────────┬───────────┘                ▼
  shrine brazier (−15,h,6)          │                  ┌────────────────────┐
                        SANCTUARY (0, h, 30) — start    │   VIOLET MIRE       │ separate zone scene
                                   S (+z)               │   east lowlands     │
                                                        └────────────────────┘
```

**Critical path:** Sanctuary → Stair → Ossuary (east) → Ember Rift (down) → Summit → Cathedral (boss).
**Optional loops:** Hollow Wood (west), Violet Mire (through the Ossuary crypt mirror).

The hub stays the anchor. Every area is reachable from a brazier you have already kindled, and each one opens a shortcut back to the hub.

## 2. Areas

### 2.1 Ossuary Terrace (P1, critical path)

**Fantasy:** A burial terrace carved into the east cliff. Thousands of candles, skull niches, and a bone bridge over the lava glow. Warm amber light against the violet night, which is a palette the hub doesn't have yet.

**Access.**
- The stair landing (after step 30) sits at z −33..−36, y 12.6.
- A **bone bridge** runs east from the landing at x 2.5 → x 34, about 31 m. It is 3 m wide, with ribs as railings.
- One section is broken: a 6 m gap. It teaches Rift Step (7.5 m) and the double jump over the lava.
- The bridge ends at a carved gate in the cliff face (x ≈ 34, the cliff is ≈ 20 m tall there).

**Layout.** An interior, so terrain is irrelevant and occlusion culling does the heavy lifting.
1. **Gate Hall.** 12×18 m, 9 m vault. Holds the brazier "Terrace Gate" at the entrance, as the checkpoint.
2. **Niche Galleries.** Two parallel 4 m corridors with skull niches. Wretches climb out of the niches (spawn on aggro). Side alcoves hold candles that are optional light pockets.
3. **Charnel Pit.** A round arena, 18 m across and sunk 4 m. Bone piles. The wave encounter: husks and spitters on a ring balcony.
4. **Reliquary Chapel.** Upgrade 1, plus the drowned crypt stair down to the Mire mirror (gated until the Ember Rift is done).
5. **Exit.** A balcony opening back onto the chasm at y ≈ 4. A rope or chain lift drops to the Ember Rift spiral descent: the one-way critical path.

**New enemy: Ossuant.**
- A husk-sized body with bone plates (CreatureMesh: `rib()` and `vertebrae()` over the husk frame).
- At 0 HP it **collapses and reassembles after 4 s** unless it is marked, hit by a Nova detonation, or burned by the Lance within those 4 s.
- This teaches the Mark/Nova loop the combat system already has.

**Light identity.**
- Hundreds of candles drawn as a MultiMesh: flame quads with the `brazier_flame` shader at a small scale. They cost no lights.
- 4–5 real OmniLights, one per room, unshadowed except the Pit.
- The bridge is lit from below by the lava. Use one large unshadowed orange OmniLight under it plus emission on the lava.

**Assets.**
- **Kit** (`tools/make_ossuary_kit.py`, Blender, same pattern as `make_stone_kit.py`):
  - pointed arch, barrel-vault segment (4 m)
  - skull niche wall (with and without skulls), skull and bone props
  - sarcophagus with lid variant, candle clusters (3 LODs: 1, 5, 12 candles)
  - bone bridge segment (rib arch and deck), broken segment end-caps
  - chain lift platform, iron candelabrum
- **Textures** (`tools/gen_textures.py`, new functions):
  - `ossuary_plaster`: cracked lime plaster over brick, with soot gradient baked into AO
  - `bone`: ivory, porous, with a micro-pit normal
  - `wax`: subsurface-ish. Use the albedo plus a small emission near the wick, drawn with a vertex-colour mask.
- **Materials:** a triplanar pass like `_triplanar()` for walls, and a UV-mapped kit for bone and props.

**Budget estimate.** About 220 draws in the Pit view. Kit pieces use MultiMesh, and the candles are one MultiMesh per room. 4 shadowed lights.

### 2.2 Ember Rift (P2, critical path)

**Fantasy:** The lava chasm floor you have been looking down into. Basalt column islands, heat haze, falling embers, and a skull-sky reflection on the lava (`ember_skulls.gdshader` exists already).

**Access.**
- **In:** the Ossuary chain lift drops you to a basalt shelf at y ≈ −12 (x 30, z −40).
- **Out:** a **spiral descent / ascent** up the chasm wall under the stair foot (x −8..8, z −2..−10). It climbs y −14 → 0 and comes out next to the StairFoot brazier. That is the shortcut back to the hub.

**Layout.** It runs along the chasm (z −10 to −130), so movement is the challenge.
1. **Column Fields.** Hex basalt islands at varying heights, 2–6 m apart. Gaps need the double jump, Rift Step or a slide-jump. This uses every movement tool shipped this week.
2. **Slag Slides.** Tilted obsidian ramps where `slide_slope_gain` turns a slide into a fast downhill run, with jumps between ramps. A purpose-built showcase for the slide.
3. **Cinder Nest.** A wide island arena (r 14 m) under the summit. Cinder Husks plus leapers pouncing from columns.
4. **Reliquary 2,** on a column under the stair landing. You can see it from the bridge above, which is good foreshadowing.

**Hazard.** The lava at y −15.5 does damage plus knockback-to-last-ground, not instant death. Falls into it should cost gloom, not a reload. Add a `LavaVolume` Area3D that calls `add_gloom_from_enemy(8, pos)` and does a ballistic hop back to the last floor position. Store that position in Player each grounded frame.

**New enemy: Cinder Husk.**
- A husk with a cracked emissive core (flesh shader plus an `ember` mask channel).
- Leaves a burning trail decal on the ground. The trail uses `aoe_disc` style 1, small radius, short life, and does damage-over-time.
- Immune to Lance burn. Nova *quenches* it, removing its trail for 5 s.
- This makes the Q-versus-RMB choice matter.

**Assets.**
- **Kit** (`tools/make_basalt_kit.py`, procedural and cheap):
  - hex column clusters (seeded heights, chamfered tops), 6 variants
  - obsidian ramp slabs, spiral-stair basalt steps (reuse the stair-bake maths)
  - slag "frozen pour" blobs: metaball → remesh in Blender
- **Textures:**
  - `basalt`: dark grey-blue, vertical striations, with a rough top / smooth sides split via triplanar
  - `obsidian`: near-black, high gloss, with a thin violet sheen at grazing angles (fresnel tint)
  - `crust_glow`: an emissive crack mask for lava edges and Cinder Husks
- **VFX:** a heat-haze plane per lava region (`heat_distort.gdshader` exists), a rising-ember GPUParticles volume per island cluster (one emitter per 30 m, not per island), and occasional lava bubbles (burst + ring).

**Budget.** The summit view already throws 2.7 M primitives at the far terrain, so the Rift area must stream in only below y −5. Islands use `visibility_range_end` 90 m with a fade.

### 2.3 Cathedral of the Inward Sky (P3, critical path end)

**Fantasy.** This is your target look: huge pointed windows, hero light shafts through dust, a violet void beyond the glass. The final area and the boss.

**Access.** The summit rift becomes a **portal** once Reliquaries 1 and 2 are taken, entered through `Travel.go("res://world/zones/cathedral/cathedral.tscn", …)`. It is a separate scene, so it gets its full budget without the hub's 769 draws.

**Layout.** Linear, vertical, three acts:
1. **Narthex.** A low ceiling, dark and tight. The contrast sets up the reveal.
2. **The Nave.** 70 m long and 24 m tall. 8 bays, each with a 14 m lancet window.
   - **The hero lighting:** each window is one SpotLight3D with the `window_gobo.png` projector (the asset already exists) plus volumetric fog density 0.03.
   - 6 shadowed spots maximum. The other 2 windows are fake: a cone mesh with additive dust.
   - Pews are cover. Choir Wretches sing, and a song buffs nearby enemies, so you interrupt it with a stagger.
3. **Triforium climb.** Upper galleries reached by buttress jumps outside, with the sky vortex (`vortex.gdshader`) visible. A Rift Step puzzle over the open nave.
4. **The Crossing (boss).** A 30 m round arena under the dome. The rose window acts as a light clock.

**Boss: Choir Matriarch.**
- About 4 m tall. CreatureMesh: a humanoid frame stretched, wearing a robe built from `tube()` drapes, with 3 extra arms holding candelabra.
- **Phase 1 (100–60%).** Sweeping candle arcs: telegraphed ground cones drawn with an aoe_disc sector variant.
- **Phase 2 (60–25%).** She snuffs the windows one by one, and the arena darkens. Light pockets from the remaining windows are the only places where gloom doesn't climb. The light grid already supports this through zones you remove at runtime.
- **Phase 3 (25–0%).** She hangs in the dome. Lance her through the rose-window beam; the window light makes her vulnerable. Nova clears the choir adds.
- Death drops the final Reliquary, and the rose window relights the whole nave.

**Assets.**
- **Gothic kit** (`tools/make_cathedral_kit.py`):
  - clustered pier, rib-vault bay (4 ribs + boss stone), lancet window frame with tracery
  - rose window (radial tracery generated procedurally), flying buttress, pinnacle
  - pew, altar, organ pipes (array), broken floor slabs
- **Textures:**
  - `limestone_block`: pale with a cool tint, block joints, waterline staining
  - `marble_floor`: a checker of two stones, glossy, with cracks
  - `stained_glass`: an emissive albedo from a generated Voronoi lead-came pattern with a violet/amber palette. One 2K atlas for all windows.
  - `lead_came`: a dark metal for the tracery.
- **VFX:** dust motes in each shaft (one GPUParticles per shaft, box emission matching the cone), choir song rings (`ring_wave`), and a window-snuff implosion.

**Budget.** Nave view ≤ 320 draws: the kit is MultiMesh per bay type. 6 shadowed spots. Fog volumes, not global fog density, so the shafts stay crisp.

### 2.4 Hollow Wood (P4, optional loop, west)

**Fantasy.** A dead, giant-trunk forest on the west plateau. Fungus rings glow cyan. Fog pools in hollows. It is crawler and leaper territory, so the new quadruped jumpers finally get the terrain they were built for.

**Access.**
- A **root ramp** climbs the west cliff from the Shrine brazier (−15, h, 6). It is a twisting root mesh (`tube()` chains, same code family as CreatureMesh) running up to the plateau at about x −50, y ≈ 22.
- A second exit drops back near the sanctuary, giving a loop.

**Layout.** It uses the existing terrain at x −50..−125, z −40..60. Only dressing is needed: no terrain change, no main rebake. Dressing is runtime-instanced from the area scene.
1. **Fungus Rings.** Glowing circles that are mini light zones. Crawlers won't enter them (`LightGrid` already repels). They are safe stepping-stones through a dark forest, which makes them navigation by light.
2. **The Hollow Trunk.** A 12 m wide fallen giant you can walk through. Leaper ambush from the top.
3. **Stag Clearing.** The **Hollow Stag**: a big QuadRig with antlers built from `claw()` chains. It charges in straight lines, and a Rift Step through it applies a mark plus a stagger. A mini-boss.
4. **Reliquary (optional).**

**Assets.**
- Reuse `bark_giant`, `leaves`, `moss_hang`, `fern_card`, `glowcap` and `nightcap`, which already exist. This is the cheapest area.
- **New:**
  - `make_wood_kit.py`: root arch, hollow trunk (bark_giant material), shelf fungus.
  - `fungus_ring` shader: emissive cap plus pulse.
  - `forest_floor` texture variant: leaf litter, darker.

**Budget.** The foliage is the risk. Grass cards stay one MultiMesh per 32 m chunk (as now: 48 chunks / 7.2k blades). Trees use `visibility_range` with impostor cards past 60 m.

### 2.5 Violet Mire (P5, optional loop)

**Fantasy.** Bioluminescent marsh, still black water reflecting violet moss, and a half-sunk chapel. Spitter colonies.

**Access.** The Ossuary drowned-crypt mirror leads to a separate zone scene. A return mirror sits at the chapel.

**Layout.**
1. **Reed Shallows.** 0.4 m deep water that slows movement (`move_scale` 0.8) and blocks sliding.
2. **Lurker Pools.** Deep pools. The **Mire Lurker** waits submerged and only shows a ripple ring (the `ring_wave` shader on the water). It lunges, then is exposed for 1.5 s.
3. **Spitter Colony.** Mounds of spitters. A long sightline teaches Lance pierce.
4. **Drowned Chapel.** A half-sunk interior (re-use the cathedral kit at small scale). Reliquary and the return mirror.

**Assets.**
- `water.gdshader` exists; extend it with a ripple input for lurkers and the player.
- **New:**
  - `make_mire_kit.py`: reed clumps (cards), dead mangrove roots (`tube`), moss mounds, spitter mounds.
  - **Textures:** `peat_mud` (wet roughness via a puddle mask) and `violet_moss` (emissive tips).

## 3. Technical architecture

### 3.1 AreaStreamer (new, `core/world/area_streamer.gd`)

- `main.gd` creates it in `_ready`. It holds a table: `{id, scene_path, anchor: Vector3, load_r, unload_r, y_band}`.
- Every 0.25 s it checks the player's distance to each anchor:
  - **< load_r:** `ResourceLoader.load_threaded_request` the area scene.
  - **When loaded:** instance it under `Areas/`. This happens on a frame where the player isn't in combat, or else after a 0.5 s fallback.
  - **> unload_r:** free it.
- Hysteresis: load at 70 m, unload at 120 m.
- `y_band` lets the Ember Rift load only when the player is below y −2 or standing on the descent.
- Each area scene contains:
  - its static geometry with baked collision;
  - spawners;
  - light zones (registered with `LightGrid` on `_enter_tree` and removed on exit);
  - braziers;
  - an `AreaInfo` node with its perf standing points.
- **Brazier kindles persist** through the existing `Travel.restore_kindles` path. Extend the keying to `area_id/brazier_name` so a streamed-out area doesn't forget.

### 3.2 Per-area bake tool

`tools/bake_area.gd <id>` builds the area scene from that area's kit `.glb` files and a layout script (`world/areas/<id>/layout.gd`, a pure data placement list). It writes `world/areas/<id>/<id>.tscn`. This is the same pattern as `bake_main`, but it never touches `main.tscn`.

### 3.3 Interiors

- Ossuary and the cathedral narthex get `OccluderInstance3D` boxes per wall mass (Godot 4 raster occlusion). Enable `rendering/occlusion_culling/use_occlusion_culling` (check the cost on the hub first).
- Use a `ReflectionProbe` per room on UPDATE_ONCE. This matches what the hub does already.

### 3.4 Enemy additions

- All new creatures go through `EnemyBody.dress(rig, kind)` with new kind ids, so `flesh.gdshader` hit-flash and dissolve work for free.
- New behaviours as subclasses:
  - **Ossuant:** `reassemble` state.
  - **Cinder Husk:** `trail` timer plus a `quench(t)` hook called from the Nova.
  - **Lurker:** a `submerged` state, untargetable, with a ripple ring.
  - **Choir Wretch:** `sing` buff aura (+30% move and attack speed to allies within 8 m, cancelled by stagger).
  - **Hollow Stag:** QuadRig charge.
  - **Matriarch:** a `boss.gd` with a phase table.
- `Enemy._light_barrier` already keeps everything out of brazier radii. Fungus rings and cathedral window pools reuse it with zero new code.

### 3.5 Texture pipeline

- Extend `tools/gen_textures.py` with the new materials listed per area. Everything procedural, tileable, 1K (2K only for the stained-glass atlas).
- Keep the painted look consistent with the existing `stone_*`, `rock_*` and `ground_*` sets.
- Optional CC0 top-up for photographic detail normals: ambientCG / Poly Haven, sources noted in `art/textures/SOURCES.md`. Only for basalt and limestone, if the procedural versions look flat. No paid assets needed.

## 4. Skill variety tie-in: Reliquaries

Each Reliquary unlocks one variant, picked at any brazier. This expands combat without new buttons.

| Reliquary | Where | Variant options (choose 1, swap at braziers) |
| --- | --- | --- |
| 1 Bone Reliquary | Ossuary chapel | **Nova → Implosion:** pulls enemies in for 0.4 s, then detonates. *or* **Nova → Wake:** leaves a 3 s violet disc that slows. |
| 2 Cinder Reliquary | Ember Rift | **Lance → Splinter:** full charge splits into 3 on impact. *or* **Lance → Brand:** the impact leaves a burning field (aoe_disc style 1, 2.5 s DoT). |
| 3 Moss Reliquary | Hollow Wood | **Rift Step → Twin Tear:** 2 charges, 3.2 s each. *or* **Rift Step → Echo:** the origin tear detonates 0.6 s later (small Nova). |
| 4 Mire Reliquary | Violet Mire | **Bolt → Seeker:** gentle homing. *or* **Bolt → Chain:** the third hit in a row arcs to a nearby target. |
| 5 Rose Reliquary | Cathedral boss | **Ward → Sanctum:** the lantern ward becomes a mobile 4 m light zone for 6 s, so enemies can't enter. |

All of these are built from effects that already exist: SpellFx disc, shell, tear and arc, plus `_blast`.

## 5. Phasing and effort

| Phase | Area | Scope | Est. sessions |
| --- | --- | --- | --- |
| **P0** | Infra | AreaStreamer, `bake_area.gd`, persistence keying, lava volume, perf standing-point hook | 1 |
| **P1** | Ossuary | kit + 3 textures + Ossuant + bridge + 5 rooms + Reliquary 1 | 2–3 |
| **P2** | Ember Rift | basalt kit + 3 textures + Cinder Husk + islands + slag slides + spiral shortcut + Reliquary 2 | 2–3 |
| **P3** | Cathedral | gothic kit + glass atlas + lighting pass + Choir Wretch + Matriarch boss + Reliquary 5 | 3–4 |
| **P4** | Hollow Wood | wood kit + root ramp + fungus rings + Hollow Stag + Reliquary 3 | 2 |
| **P5** | Violet Mire | mire kit + water ripples + Lurker + chapel + Reliquary 4 | 2–3 |

**Every phase ends with:**
- a `--perf-baseline` run with that area's standing points appended to `docs/perf_baseline.md`;
- a walkthrough video (`tools/walk_video.sh`);
- Luke playtesting on the Mac.

## 6. Acceptance per area

- You can see it from the hub before you can reach it (silhouette or light), and it opens a shortcut home.
- It has one movement-skill showcase and one combat-skill showcase.
- It holds its draw, primitive and light budget, and its 1% low ≥ 110 fps.
- It has no `--headless` bake of `main.tscn` in the commit history.

---

## 8. Progress log

### Session 1 — 3 Nov 2026: P0 infra + P1 Ossuary (playable first pass)

**Built.**

- **P0 infra.**
  - `core/world/area.gd` (Area base): builds on stream-in, keeps per-area kindle memory in `Travel.area_lit`, title card on entry, `make_brazier()` clones a dressed hub brazier, and `perf_points` for the benchmark.
  - `core/world/area_streamer.gd`: distance/hysteresis load and unload, an optional `y_max` band, and a synchronous load on respawn.
  - Wired from `world/main.gd` (`AREAS` table). **`main.tscn` untouched.**
  - Lava no longer hollows outright. `Player.lava_burn()` adds +35 gloom and throws you back to the last ground you stood on for 0.25 s (`_safe_ground`).
- **Ossuary Terrace** (`world/areas/ossuary/`). It differs from §2.1 in one way: it is built as a **cliff monastery on the chasm face**, not inside the cliff, so no terrain cut was needed. Every floor was checked against the `bake_main` heightfield.
  - **Bone bridge** from the step-30 landing, with a 5 m broken span (the Rift Step / double-jump test; a miss means lava burn and return).
  - **Gate Hall** (y 12.6): brazier `OssuaryGate`, four piers with arches, a skull-niche wall, lit lancet windows, and a bell tower plus spire. The spire is the landmark from the sanctuary.
  - **Niche Gallery** (y 8.4): two aisles split by an arcade, two rows of skull niches, bone heaps, and an open arcade over the chasm.
  - **Charnel Pit** (y 4.2): a round platform cantilevered over the lava, with a broken colonnade, bone mounds, spitter plinths and the main fight.
  - **Chain lift** from the pit to the summit plinth ring, so the run loops back to the summit.
  - **Chapel:** the Bone Reliquary.
  - **Kit** (`oss_kit.gd`): procedural pieces (pointed-arch walls, niches, stairs with smooth ramp collision, pinnacles, glowing panes). They merge into **one mesh per material (12 draws for the whole area)** plus MultiMesh skulls, bones and candles (365 candles, about 185 skulls).
- **Ossuant** (`core/enemy/ossuant.gd`): a bone-pale husk. At 0 HP it collapses and reforms after 4 s at half HP, unless it was Marked or the heap is hit.
- **Bone Reliquary → Nova variants** (`Travel.relics["bone"]`, swapped at the reliquary):
  - **Implosion:** pulls and marks everything within 7.5 m, then detonates 0.35 s later.
  - **Wake:** a 3 s field that marks anything inside it once per second.
- **Fix:** `EnemySpawner._process` was raising a script error every 0.5 s whenever a killed pawn had been freed (`pawn is Enemy` on a freed object). Fixed.

**Verified in the container** (Godot 4.7.2, real project):
- Full-project compile: 0 failures.
- Headless smoke tests:
  - Every tier floor is solid; walking the stair works; the gap is open.
  - A gap fall ends in lava burn and a return to the bridge.
  - The lift carries the player from y 4.2 to 26.56 and they walk onto the summit.
  - The brazier kindles, sets a checkpoint, and is remembered per area.
  - Reliquary taking and swapping works.
  - Both Nova variants work.
  - The Ossuant crumble / reform / shatter cycle works.
- Lavapipe renders: 98–272 draws and 0.24–0.40 M primitives per view, including shadows. That is inside the §0 budget.

**Known gaps / next session.**
- **Needs the Mac:**
  - Look and lighting under the real moon and fog. The lab renders had no cliff or fog behind them.
  - A `--perf-baseline` run with the three `perf_points`. They are not yet wired into `main.gd`'s benchmark.
  - Playtest the pit's difficulty: three ossuants plus a husk plus two spitters aggro together.
- **Build cost:** 310 ms headless. The Ossuary loads at boot because the hub always sits inside `load_r`. Later areas that stream mid-play need the build on a `WorkerThreadPool` or baked to `.res`.
- **Missing from the plan:**
  - The exit balcony and chain drop to the Ember Rift (P2).
  - The drowned-crypt stair to the Mire mirror (P5).
  - The Ossuant's extra bone plating. It currently reuses the husk body with a bone palette.
  - New textures. It reuses `tavern_*` and `stone_*`. `ossuary_plaster`, `bone` and `wax` in `gen_textures.py` are still to do.
- **Next:** P2 Ember Rift, which needs the threaded build first.
