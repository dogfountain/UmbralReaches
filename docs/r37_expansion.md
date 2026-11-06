# r37: the Outer Marches

Luke, 6 Nov 2026: double the Realm's area and fill the new ground with what the game already does
(bosses, mini-bosses, people, quests, secrets, lore, camps, fires), with landmarks unlike anything on
the map now and new assets made in-house. The numbers are in `core/world/realm/realm_layout.gd`
(BOUNDS, OLD_BOUNDS, REGIONS, RAIDS, SLOTS, BASE_PATHS, RIVER, LAKE_*, WELL_*, MARCH_*): that file is
the contract.

## The shape

The old Realm (x -155..155, z -150..175) is unchanged. It grows to x -260..260, z -150..240
(520 x 390 m, 2.0x the area): past the West and East Gates into the **Outer Marches**, and south of
the Waiting Field into the **Southern Downs**. The Crowns stay the north wall the whole width.

The r34 edge rims at x +-155 become the **March Wall**: the old Realm's boundary wall, gates where the
Pilgrims' Road crosses it, breaches where tracks do. Beyond it the Marches: the country the Order
shut out.

| Region | Where | Landmark (new kind of place) | Content |
| --- | --- | --- | --- |
| Weirford | road x -205 | a living outpost town at the river crossing: stone bridge, weir, watermill, inn, smithy, stables | 6-8 people with routines, quest hub, watch post (sword NPCs), fire |
| The Sorrow's Banks | west, north of town | a river valley (the Sorrow) with fords and alder banks; a drowned shrine | camps, rares, a secret, fire |
| The Fallen Hierarch | NW at the Crowns' foot | a ~60 m toppled statue of the Hierarch in a moss valley; walk its body; the head split open | BOSS in the broken crown (RAIDS "hierarch"), camp, fire |
| The Siege Lines | SW | earthwork rings, palisades, rotted trebuchets, a siege tower you climb | 2 camps, named mini-boss (the siege-captain), fire |
| Stillwater | east | a cold lake under a bluff; the Lamplighters' Spire, a climbable beacon tower; relighting its lamp is a quest | camp, sunken boat-house, a secret, fire |
| The Anchorholds | NE in the Crowns' face | hermits' cells cut into the cliff, ladders, walkways, a cliff chapel | BOSS on the cliff terrace (RAIDS "anchorhold"), fire |
| Saltmarket | east road fork | a salt-workers' hamlet | 4-6 people, trader, quests, fire |
| The White Pans | SE | salt flats: evaporation pans, timber derricks, a salt-works, crystal crusts (biome "salt") | 2 camps, named mini-boss, a secret |
| The Southern Downs | south strip | open chalk downs, a shepherds' hut and fold | 2 camps, rares |
| The Grandmother Oak | south-west | a colossal hollow dead oak: a stair inside the trunk, walks along the great limbs | named mini-boss, a secret at the top, fire |
| The Well of Echoes | south-east | an open sinkhole ~40 m across, 24 m deep, a waterfall in, a ledge path down to a pool and a cave | named mini-boss below, a secret, fire |

Totals: 2 bosses, 4 named mini-bosses (elite_kit), ~14 camps, rares per region, 10-14 people,
8-10 quest chains, 5 secrets, a fire per region (Ember Road stops), lore and codex places for all.

## Rules for every agent

- **Existing systems only.** BossKit/BossArena for bosses, elite_kit for mini-bosses, rares, camps
  (encounters tiers/variants/guardians), village/villager routines and talk, watch posts, stables,
  quest_chains step kinds, secrets sites, lore_db and the codex, braziers/fire_spot for fires. No new
  autoloads, no new frameworks. A boss is a new script on BossKit over an existing rig family
  (hunch_rig, quad_rig, grunt_model, creature_mesh) with new in-house meshes; that is allowed this round.
- **Assets are made, not downloaded.** Blender by script (tools/blender, the umbral-blender skill),
  procedural textures and bakes, realistic (docs: the Enshrouded-level bar). No CC0, no downloads.
- **Budgets.** 120 fps on this Mac in the new ground; ~1.5M primitives in view; every big landmark has
  LODs and a low-detail far mesh (see Far detail). The Realm build must stay under ~40 s (it is ~23 s).
- **The pillars** (docs/PILLARS.md): the dark is the clock, warmth is earned (the Spire's lamp is lit
  by the player, never for free), the world teaches.
- Binding don'ts stay (.cursor/rules, the umbral-donts skill): glow levels, four stair fires, no
  Engine.time_scale = 0, never headless-rebake world/main.tscn, NPC voices stay babble, and so on.
- Put new content in new files named for your area (e.g. `realm_pois_r37_west.gd`,
  `quest_chains_r37_west.gd`, `site_r37_west.gd`). Where a shared registry must list it (quest chains,
  lore_db, elites, guardians, realm_bosses, codex), add ONE block marked `# --- r37 <area> ---` at the
  end of the list, so the lead can merge four branches cleanly.

## Far detail (the Foundation agent)

Things must not pop into existence on the horizon. Everything big is loaded and drawn at very low
detail far away (terrain is already whole; landmark silhouettes, the March Wall, tree masses as
impostor cards or a far canopy shell) and detail fades in up close with visibility-range fades and
dependency HLOD, never a hard cut. Grass and small props may still end at range, but fade.
