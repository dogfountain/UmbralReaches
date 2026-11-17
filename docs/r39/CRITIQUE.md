# r39 critique: the whole game (17 Nov)

Luke asked for four critics across:
- visuals, systems, story, wholeness, progression;
- the introduction;
- world landscaping, fullness, meaning, exploration, models, textures, fantasy and scale;
- places that have light, and "brighter while the moon is darker";
- then more critiques.

Four Sonnet critics read the code and docs and viewed a fresh capture of the night. That capture was 141 stills of every region, the places, the villagers and the menus. Their full reports sit beside this file:
- [1_opening_progression_systems.md](1_opening_progression_systems.md)
- [2_story_meaning_fantasy.md](2_story_meaning_fantasy.md)
- [3_world_models_textures.md](3_world_models_textures.md)
- [4_light_visuals.md](4_light_visuals.md)

The lead added the performance seat. The build wave that answers all of this (ten or more chunky additions per team) is written up per team in docs/r39/*.md.

## The answers to Luke's direct questions

**Should the player spawn in the middle of the village, or should something introduce the world first?**

Today the player just appears on the Sanctuary fire on Hearthward's green. A black lift, narration over the gameplay view and a WASD card are all the game does; every authored camera lives only in zz/. Line 1 of the opening is also false now: "Past the last village there is only the Stair", but the Far Reaches towns exist.

The recommendation is a cold open, "The Last Lantern": about 45 s and skippable. The camera cranes down the sky and the Chain, dollies through the lit square, ends on the wanderer's lantern flaring, then eases into the shoulder cam as the HUD arrives. It reuses the loading tour's pre-warmed views, so it costs no new shader compiles.

**Should it be brighter while the moon is darker?**

Yes. The lever is the shadowless fill and the ambient light, not the moon disc. All of these are free:

| Setting | Now | Proposed |
|---|---|---|
| MOON_ENERGY | 1.5 | 1.2 |
| FILL_ENERGY | 0.6 | 0.85 |
| FILL_ELEVATION | 24 | 32 |
| ambient light | 0.125 | 0.19 |
| volumetric ambient inject | 0.06 | 0.10 |
| beacon lights | 0.55× | 0.75× |
| lamps | 0.62× | 0.85× |
| village lights | 1.0× | 1.2× |
| grade black crush | 0.055 | 0.035 |
| vignette | 0.42 | 0.34 |

Lit ground against the shadow floor goes from about 5:1 to about 3:1. Warm pools stay at least twice their surroundings.

**Model detail at no performance cost, the Enshrouded way?**

Bake detail once and let contrast show it, rather than raising polygon counts or exposure:
- per-block jitter, chamfered edges and edge wear in OssKit (the masonry reads as a voxel grid now);
- a value gradient through tree crowns (now single-hue domes);
- detail normals and macro layering on masonry and wood, near only;
- shared moss, dirt and soot masks by world normal;
- vertex AO on every prop;
- a ground-litter layer;
- LODs and impostors, so near detail can rise while far cost falls.

## The worst of it, by seat

**Story (P0)**
- The bells contradict themselves: 3, 7, 8, "four" and 40 all appear.
- The climax gate is a scavenger hunt (any four of eight template bell quests), not a scene.
- Aurel, the villain, never speaks.
- The premise is told in subtitles, and the drain is never shown.
- The Anchoress and the Speaking Crown, the strongest boss premises, sit off the main line with no theme, no voice and no mention.

**Progression (P1)**
- The Act II bells have no "n/4" counter.
- Danger follows the number of bosses killed, not the player: every keeper felled hardens ground already cleared, and level gates nothing.
- Horses, fast travel and the Far Reaches are disconnected from the spine.
- Dailies reset every 600 s and the "day" isn't saved.

**Wholeness (P1)**
- PILLARS.md describes a short 30-minute game that is no longer this one.
- The map's task pins pile up at Hearthward.
- The region plate's "Dusk / Night / Deep Night" is a danger tier dressed as a clock.

**World (P0/P1)**
- The masonry reads as a pixel grid.
- Tree crowns are flat.
- Terrain between landmarks is soft dunes.
- The fill is the same three items everywhere.
- Rewards sit in sight of the road.
- Masonry scales disagree between cottages, ruins and towers.
- Nothing near the boss approaches hints at an 8 m creature.

**Light (P1)**
- Hearthward up close is the best frame in the game, but almost no place reads from afar.
- Lit sources at the Foundry, the Glade and the graveyard cast no light.
- The grade is one teal hue.
- The grass is the loudest thing in the frame.
- Telegraph rings are 1-2 px lines.
- The hurt wash covers the ground telegraphs.

**Animation**
- The Saltmarket crowd walks in lockstep.

**Performance (the lead)**
- About 118 fps on a 120 Hz vsync.
- In 9 of 16 regions the 1% low falls to 60 fps: at least one frame in a hundred misses its refresh.
- There are spikes of 84 ms at the Hearth, 47 ms in the Thornwood and 25-31 ms elsewhere, on first views. Pre-warm those materials behind the loading screen.
- The Realm builds in 17 s.

**QA**
- 4× "indexing did not unpair geometries from light" in the villagers run.
- A hard vertical edge on the far silhouette in vista_realm_from_se.png.
- The boss arena captures are broken (the Abbot upside-down, the Anchoress behind a branch).
- Fennick's portrait beard renders as shards.
