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

## West Marches (the West agent)

Built in `core/world/realm/realm_pois_r37_west.gd` (reserve before the stamp and flora, build after), hooked by
the `# --- r37 west ---` blocks in the shared registries. Assets are made by script in `tools/blender`
(`r37_west_textures.py`: seamless procedural PBR sets; `r37_west.py`: statue, mill, bridge, palisade, trebuchets,
siege tower; `boss_hierarch.py`: the boss) and placed through `r37_west_kit.gd` (tiling `art/textures/r37_*`
sets over `<part>__<set>` meshes, `<asset>-colonly` collision, vertex-colour macro tone).

- **Weirford** (road x -205): the stone bridge over the Sorrow, the weir and a working mill (the wheel turns:
  `r37_wheel_spin.gd`), the Grey Heron inn, the smithy, two cottages, stables (the Weir Cob, `horse_db.gd`), the watch
  post (`watch_posts.gd` "weirford", three sword watchmen), a covered well, a stall, lit windows without lights, an
  Ember Road fire (`WeirfordFire`). Eight people with routines and babble talk: `village_cast_r37_west.gd`
  (merged by `village.gd` `cast_all()` and the nodes/edges), `village_talk_r37_west.gd`.
- **The Sorrow's Banks**: the drowned shrine in the river (a chest and the secret *Aldith's Walk*,
  `core/life/secrets/site_r37_west.gd`: an iron ring raises a sunk walk to a lamp-islet and a box), ford posts,
  two camps, a rare (the Drowned Reeve), a fire (`SorrowFire`).
- **The Fallen Hierarch**: `r37_statue.glb` (head shell ~28 k tris, torso and arm ~10 k, debris; the engine
  generates mesh LODs on import) plus a separate ~1.6 k-tri far mesh node `StatueFar` (meta `far_mesh`, fades in from
  330 m while the near model fades out from 420 m; the Foundation's far-detail hook can replace it). The skull is a
  hollow bowl split open round the raid floor; the body lies away from it (`BODY_DIR`); the open hand is a POI with a
  stair of fallen blocks and a chest. Boss: **the Speaking Crown** (`core/enemy/hierarch_voice.gd`, a Husk rig with
  `boss_hierarch.glb`, 640 HP, 3 phases; room `core/world/hierarch_raid.gd`; id `r37_hierarch`, trophy `crown_shard`).
- **The Siege Lines**: the outer earthwork's palisade and gate, rotted trebuchets (`r37_trebuchet.glb`), a four-storey
  siege tower with its stairs built in (a chest on top), two more camps, a rare (the Gate-Breaker), the mini-boss
  **Captain Varr, the Wall-Breaker** (`elite_siege_captain.gd`, `Elites.ELITES["siege_captain"]`), a fire (`SiegeFire`).
- **Quests** (`quest_chains_r37_west.gd`): The Stopped Wheel, The Lamp on the Lines, Lights for the Sunk, and
  The Voice in the Head (after the Wheel; ends in the boss). Lore: `lore/r37_west_texts.gd` (22 texts, a series,
  four codex places), placed by `lore/r37_west_places.gd` and the POIs.

Tuning notes: the statue's head is oversized so the raid floor (r 24) fits inside it; the whole figure is about
100 m long rather than 60. Switches: `--no-r37-west` (places, writings, secret).
