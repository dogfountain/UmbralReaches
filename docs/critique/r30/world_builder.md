# r30 critique: world builder / level design

Reviewer lens: realm layout, the hub (now the Crossing), Hearthward and the Keg, the Ossuary and its
pit, the three boss arenas, landmarks and navigation, verticality and traversal, light as
wayfinding, density, wildlife, secrets, world edges, coherence. Read-only review: no project file
was changed except this one.

Evidence was gathered on 2026-11-04 with an isolated HOME (`/private/tmp/claude-501/world_home`):
- headless probes (SceneTree scripts outside the project): `/private/tmp/claude-501/world_probe/probe*.gd`,
  logs next to them (`probe.log` ... `probe4.log`, `regions.gd`, `trav_scan.log`, `arena_gate.log`)
- windowed free-camera captures, 41 PNGs: `/private/tmp/claude-501/world_shots/` (named below as `shot NN_name`)
- existing harnesses run read-only: `zz/trav_realm.tscn -- --scan`, `zz/arena_gate_test.tscn`

## Verdict

The Realm has good bones: a readable radial plan (village in the south, three spokes to three
bosses), strong mid-distance landmarks (the lit Ossuary church over the fen, the henge on its hill
seen from west_way, the lava rift as a north star), short critical-path distances (spawn to henge
~100 m, to the Ossuary door ~165 m, the Crossing ~125 m) and a lot of lore on the ground. What lets
it down is **the edges of every space**: arena gates that shut in front of you (henge) or are never
met at all (Ossuary, summit), a lift that walks out of the Abbot's arena onto the summit, invisible
walls on open ground at all four sides of the map (with a road that runs through two gates into
them and a camp spawned on the far side), five named landmarks that the region system can never
name, a climax arena that is an empty disc under a taller mountain, and a night that is lit almost
only in the rift. Fix the arena contract and the map edges first; the rest is dressing and
wayfinding.

## The arena-entrance bug (Thorn Henge): cause and fix

**Symptom.** Walking up the pilgrim stair to the henge, the thorn seal "uproots" (the bramble
barrier snaps up in the trilithon) before you are through it: the Thornwarden rises inside, the boss
bar shows, and you are locked out on the terrace lip.

**Cause.** `BossArena` started the fight on a plain radius test, and the henge's radius is larger
than its own gate ring:
- `core/world/thorn_henge.gd:247` builds the arena with radius `R - 0.6` = **12.4 m**; the seal is
  `WardSeal.make(... gp + gout * 0.05 ...)` at `thorn_henge.gd:246`, on the menhir ring `RING` =
  **10.5 m** (`thorn_henge.gd:10-12`). Probe: arena r 12.4, gate at (-71.4, 7.7, -7.5), gate->centre
  10.6 m (`probe.log`, `ARENA thornwarden`).
- The stair head lands on the terrace edge at 13.0 m (`HSTAIR seg3 ... dist 13.0 dy 0.00`); the
  first ~2.4 m of terrace lip you step onto (13.0 -> 10.55 m) lies inside 12.4 m but outside the
  gate; my samples along the built flight put its treads at 13.1-14.4 m, so it is the lip, not the
  treads, that wakes it (the new code comment in `boss_arena.gd` blames the stair; the effect is
  the same).
- `core/world/boss_arena.gd:129` (radius / height test) then `_begin()` called `gate.close()`
  (`boss_arena.gd:170` -> `ward_seal.gd:191`): collision on, brambles visible, in front of the player.
- The leash keeps the fight alive until you are `radius + LEAVE` = 18.4 m away
  (`boss_arena.gd:119`), i.e. back near the stair foot (19.8 m); climbing again re-fires it. The
  Thornwarden, and with him the summit, were unreachable.
- `zz/arena_gate_test` confirms it: "stair samples outside the gate but inside the old radius: 4".

**Status.** A fix is already in the working tree (uncommitted, `boss_arena.gd` mtime 20:38 today):
`GATE_CLEAR := 1.5` (`boss_arena.gd:16`) and `_past_gate()` (`boss_arena.gd:146-156`): the fight
only starts once the wanderer is 1.5 m past the gate line, and gates farther than `radius + 2` from
the centre are not tested. I ran `zz/arena_gate_test` on it: **PASS, woke 1.78 m past the gate
line** (`arena_gate.log`). It is the right minimal fix; please commit it and repack.

**Harden it (recommended, owner F):**
1. Make the trigger geometry explicit instead of inferred: give `BossArena` a `trigger_radius`
   (henge: `RING - 1.5` = 9.0 m) separate from the leash radius, and assert
   `trigger_radius < distance(gate, centre)` in `BossArena.audit()` for any gate on the rim.
2. Add an audit rule: sample the walkable ground outside the gate line within the trigger radius;
   any hit is an error. That catches the next stair that curls round a hill.
3. `zz/arena_gate_test` only walks the henge; extend it to all three arenas (it is cheap).

## Findings

Severity: **Critical** = blocks progression or breaks a core promise; **High** = a player will hit
it and it costs trust or minutes; **Medium** = clearly visible quality or design debt; **Low** = polish.

### Critical

**1. Thorn Henge seals in the player's face** (above). Fixed in the working tree, not committed or
packed; until it ships, the second boss and the summit are unreachable for anyone who walks the
stair. Fix: commit `boss_arena.gd` + `zz/arena_gate_test`, then the hardening above.

### High

**2. The Ossuary and summit gates are decorative: the leash resets the fight before you can reach them.**
- Abbot: gate (bone portcullis) at (21, 8.4, -66.7), **19.9 m** from the pit centre
  (`ossuary.gd:725-726`); leash = 10.4 + 6 = **16.4 m**. Climbing the pit stair past z = -70.4 resets
  the fight ("returns to its rest") 3.7 m before the closed portcullis. The chapel's far end
  (altar z -105.5, ~19.5 m) also resets it: retreating to the altar ends the fight.
- Warden: gate = the summit ward at (0, 25.2, -70.9), **33 m** from the dais (`summit_dress.gd:119-125`);
  leash 20 m. Walking out of the 6.4 m dais mouth onto the platform resets the fight 13 m before
  the ward. The player never sees either seal close.
- Fix: put each arena's barrier at the arena mouth and keep the far seals as progression seals:
  Abbot: a second bone grille in the parapet gap at the stair foot (angle 58 deg, (21, 4.2, -78)) and
  one across the chapel arch at (16, 4.2, -99); Warden: a ward veil across the dais mouth
  (x -3.2..3.2 at z -89.9). Use a dedicated arena-gate object (see 8) so a reset never touches the
  progression seal.

**3. The Abbot's arena has an always-running lift to the summit** (`ossuary.gd:705-710`,
`chain_lift.gd:3` "waits, rises, waits, falls, forever").
- Deck bottom (13, 4.2, -89): **4.2 m from the pit centre, inside the arena**; top 26.56 at the summit
  platform's lift jetty (`summit_dress.gd` LIFT_LANE / LIFT_GATE cut into the rail).
- Consequences: (a) an escape from the Abbot fight (ride up, leash resets); (b) the summit ward is
  bypassed as soon as the gallery camps are cleared: the player stands on the summit before the
  Thornwarden, sees the climax early and gets "Nothing answers. Two seals still hold below." (also
  wrong with one boss down, `boss_arena.gd:137`); (c) the boss leash is horizontal only
  (`boss_arena.gd:114` keeps y), so a boss standing on the deck rides it up.
- Fix: gate the lift exactly like the Sexton's cage (`oss_lift.gd` `unlocked` callable): pinned at
  the bottom until `bone_abbot` is slain, then a reward shortcut both ways. Better still, move its
  foot off the fighting disc onto a jetty at r 12-13 behind the west parapet gap, so the arena floor
  has no moving platform.

**4. Five named landmarks can never be "entered": no banner, no Journal discovery, wrong tier and biome.**
`RealmLayout.region_at` (`realm_layout.gd:117-122`) and the codex's `_region_for` (`ui/codex.gd:312-327`)
both take the first region with the highest weight (`w > best_w`). Every small circle that sits
inside an earlier rect ties at 1.0 and loses. Probe (`regions.gd`), share of each region's own area
it wins:

| region | at its centre the winner is | own area won |
|---|---|---|
| Chapel of the First Kindling | road | 0 % |
| Thorn Henge | thornwood | 0 % |
| Barrow Field | fen | 0 % |
| Summit of Ascension | rift | 0 % |
| Glimmer Glade | thornwood | 0 % |
| Ossuary | rift | 7 % |

`CodexStore.discover(id)` is only called from `enter_region` (`ui/codex.gd:218`), so those Journal
places are never discovered; `tiers.gd:43` (`region_id`) puts the summit in "rift" and the henge in
"thornwood"; `biome_at` makes the glade "oldforest", the chapel "heath", the summit "ash"
(footsteps, weather, wildlife, assets all read it). Fix (lead, layout contract): pick the most
specific region: iterate small regions first, or score `w / area` (or `w + 0.01 * priority`), and
use the same function in the codex (call `RealmLayout.region_at` rather than re-implementing it).

**5. Invisible walls on open ground at all four edges; the road leads through two gates into them.**
- `realm_land.gd:781-818` (`_bounds`): walls 1 m outside BOUNDS; the horizon ring only starts to
  rise at the boundary (`realm_layout.gd` `smoothstep(0, 60, out) * 28`), so the wall stands on flat
  ground at the foot of a visible slope: south heath (shot `b04_b_south_edge`), east fen (shot
  `27_east_edge_fen`), west Thornwood.
- The Pilgrims' Road ends in two open, broken gate arches at x = +-100 (`lore/road.gd:130-172`,
  shots `24_gate_west`, `25_gate_east`): the road visibly continues through them for 10 m into
  nothing. A gate is an invitation.
- `zz/trav_realm -- --scan`: 621 wall-kick spots; 11 of the 12 sampled are on `Zone` (the
  RealmBounds wall at z 80-82). The wall kick's main surface in the world is the invisible wall.
- Fix: start the ring rise ~15 m inside BOUNDS and make the last 10 m physically unclimbable
  (RockKit cliff bands, a ditch and thorn thicket line, fallen trees), keeping the invisible wall
  only as a hidden backstop behind real blockers. Close both road gates diegetically: a collapsed
  arch rubble mound filling the opening with the road vanishing under it, or a ward-veil "the road
  beyond is gloom" with a lore line. Exclude `RealmBounds` from wall kick and ledge grab (meta or
  layer check in the player's surface probes).

**6. A road camp is spawned outside the world.** `enemy_spawner.gd:62` "Pilgrims' Road east" at
(74, 81) is outside BOUNDS (z <= 80); probe: two enemies at (76.5, 12.4, 81.4) and (72.4, 0.3, 83.0)
behind the south wall (shot `26_road_east_camp`: their health bars show through it). Unreachable,
unkillable, visible. "Pilgrims' Road west" (-56, 78) and "Hollow Fen north" (104, -66) are within
2-6 m of a wall. Fix: move the east camp to about (74, 70); keep camps >= 10 m inside BOUNDS and add
that to `realm_audit`.

**7. The Warden has no checkpoint and no light: a ~125 m climb per attempt.** Respawn is the last
kindled fire, at best StairFoot (-5, -2). From there: forecourt, three towers, a full turn of the
Spindle, two flights, the ward-landing camp, the summit approach: ~125 m walked and 25 m climbed
(lane `rift_crossing*`, probe `LANE`). The henge has its fire on the landing (~10 m run-back), the
Abbot ~55 m from Threshold. HANDOFF already notes "The summit dais is lit only by the player's
lantern." Fix: a brazier on the ward landing (0, 25.2, -66), lit at the ward, as the Souls-standard
"fire before the boss"; plus a lit rim (see the summit arena section).

**8. Arena resets force progression seals open.** `BossArena._reset` / `_on_killed` call
`gate.release()` (`boss_arena.gd:184, 207`), which sets the seal's collision off
(`ward_seal.gd:205-206`) whatever `seals_broken` and its camps say. After the lift bypass (3), a
death on the dais opens the summit ward for the session with its camp alive. Fix: arena gates should
be their own objects (`ArenaGate`: close/open only), or `release()` should restore the seal's own
state (`_refresh(false)`) instead of forcing it open.

**9. Light does not lead the way outside the rift.** Probe `probe3.log`: 100 non-directional lights
in the night; **64 are in the rift/Crossing**, 12 in Hearthward, 12 over the whole Thornwood
(80 x 115 m), 7 in the fen, 4 on the 220 m road. **0 lamps on east_way (83 m) or fen_descent (51 m)**,
none on west_way but the glade shrine. Unlit checkpoint braziers carry a 0.39-energy, 3.4 m ember
light, invisible past ~10 m at night, so a new player cannot find Shrine, Landing, Threshold or
StairFoot by eye. Sanctuary (LightGrid) is only lit braziers (r 11), mirrors and the ward spell. Fix:
waystone lanterns every ~25-30 m on the three spokes (warm, small range, no shadows) and a cold
"unkindled" glow on dark braziers visible at 40 m (a pale flame or coal glint above the bowl); let
lanterns be kindled at a fire to extend sanctuary along the roads as progression.

**10. The summit does not read as a summit, and the goal is not visible.** Dais top 27.35; the Crowns
behind rise past it (z -140 ~ 16 m, z -160 ~ 50 m) and the dais faces a dark slope ~20 m away (shot
`b02_b_dais_eye`). From spawn the summit is hidden behind the Crossing and the Ossuary (shot
`02_spawn_north`); the eye goes to the vortex, not to a place. Fix: see the summit arena section
(beacon, orientation, backdrop).

### Medium

**11. Hearthward is a scatter, not a village.** Five cottages (one lit, one ruin, a burned barn, two
dark) 15-35 m apart over a ~70 m meadow (`lore/hearthward.gd:23-27`; shot `04_hub_top`), no street,
no fences tying them together, the green is a lawn. The safe light (r 11 round the spawn fire) covers
only the green. A camp sits 15 m from the burned barn ("Thornwood's village edge" (-48, 30)) and
14 m from Abel's grave dig (-58, 39), with the villager working calmly beside it; Wyck the hermit is
18 m from the Thornwood west camp. Fix (C, lore/village): pull the cottages into two short lanes
off the green (8-12 m spacing), add a low wall/ditch and a lychgate where west_way and east_way
leave, light the lanes (that is where the village system's relit cottages pay off), and move the
village-edge camp to >= 30 m from any NPC.

**12. Henge approach earthworks.** The stair-pin terraces (`thorn_henge.gd` `henge_stair_pin%d`)
leave a raw triangular earth wedge rising over the flight and half-bury the cheek walls (shots
`05_westway_henge`, `06_henge_stair_foot`); the retaining wall shows a clean seam against smooth
fill. Also the henge seal camp "under the henge, west of the stair" (-70, 6) is **8.7 m** from
HengeFire (-64.9, -1.1): its spawn point is inside the fire's sanctuary radius (11 m) once lit.
Fix: dress the fill with RockKit boulders and roots, cut the wedge back to a 35 deg bank, and move
that camp to >= 14 m from the fire.

**13. The thorn seal and hedge read as red wire.** The hedge is straight red tubes 2.4-3.4 m tall
with 4.2 m box collision (1 m of invisible wall over the brambles), and the seal "closes" by popping
visible (the thorn branch of `close()` tweens `position:y` from 0 to 0, `ward_seal.gd:191-200`):
that pop is the "uproot". Fix (F/E): thicker twisted bramble meshes with thorns and leaves, collision
matched to the mesh top, and a real close animation (stems growing out of the ground over 0.6 s with
a root-crack burst and dust).

**14. Stair-era leftovers in the Realm.** `world/main.gd:41` still raises `Gothic.raise` (WindowRig):
three shadowed cyan gobo spotlights (e 5.19) at (0, 4.4, 16.6), (1.3, 14.4, -36.4) and
(1.4, 27, -75.4) (`probe3.log`) shine window patterns through windows that no longer exist (old
stair coordinates; one hangs in the rift air beside the Crossing, one by the summit ward). The
arrival card still says "STAIR OF ASCENSION / where the sky turns inward" (`main.gd:35`) though
there is no stair. Fix: skip `Gothic.raise` under `Realm.enabled()` (or add WindowRig to
`Realm.RETIRED`) and title the night for what it is now.

**15. Traversal is supported by the player, not by the world.** Scan: 573 vault spots (mostly drystone
field walls, good), 209 incidental ledge grabs, and almost no legitimate wall-kick surfaces
(see 5). The land is flat where people walk (Hearthward ~0, the fen -1 over 70 x 160 m, the road
0.5); the only real height is the henge hill (+8) and the Crossing (+25). Nothing to climb for a
vista. Fix: author 4-6 traversal set pieces: a climbable ruined belfry or watchtower by the green
(grab + shimmy, roof vista over all three spokes), a back way up the henge hill (two grab ledges and
a kick chimney between boulders into the hedge corridor's outside, not into the arena), a kick
chimney on the rift wall to the Founder's Spill ledge, vault lines of fallen trunks across Thornwood
shortcuts, beam-balance logs over fen pools.

**16. Wildlife misses the biggest region and the high ground.** Probe `LIFEG`: the Thornwood (the
largest region) has only owls and the henge crows: deer herds stand on open ground at forest
edges (`life_director.gd:327-363`), the elk on an open rise (`:385-410`), and the foxes are placed in
the village ((-27, 38), (-27, 13), `:367`). Nothing lives
on the crags, the Crossing or the summit. Deer1 grazes at (17, 13), between the Keg and the rift-rim
camp (22, -6). Fix (D): Thornwood fauna that lives under trees (boar or badger at dusk, a stag in
the clearings at (-62, 22) and (-88, -40), woodpecker/jay calls), ravens and a circling raptor on
the Crowns and over the lava updraft, bats at the Ossuary towers; keep grazers >= 30 m from camps;
move foxes to the village edge gardens instead of the green.

**17. The Hollow Fen is flat and thin.** 70 x 160 m at -1 m (`probe.log` grid H row), 65 of its
103 10-m cells contain no authored mesh (`DENS fen`); from above the pools read as one geometric
sheet with stepped edges (shot `00_overview_n`, right). It is pretty at eye level (shot `18_fen_wide`)
but there is nothing to navigate by between the drowned graves and the barrows. Fix: hummocks and
causeways (raised boardwalks on posts, a sunken chapel tower as the fen's landmark visible from
east_way), pool shores broken by reed islands, and a single tall dead tree or gibbet per pool group.

**18. The Crowns are a blanket.** The north wall is a smooth noise heightfield with no cliffs or
strata (shots `21_north_edge`, `b04_b_south_edge` for the south ring); Hobb's cairn is a lone stair
up a bare slope. Fix: RockKit cliff bands (granite style, the kit already makes sawtooth ledges) on
the Crowns and the horizon ring nearest the playable edge, a few pines in the gullies.

**19. The Abbot's pit is a balcony, not a crypt.** An open-air 11 m disc over lava (shots
`13_oss_pit_top`, `b01_b_pit_eye`), a 0.8 m parapet that is vaultable (VAULT_MAX 1.25), and a west
parapet gap at angle 180 deg (`ossuary.gd:573` "lift (west)") that opens onto a 7 m drop with lava
drops either side (`DROP pit r11.3 170:-25.3 180:-7.2 190:-2.5`), though the lift is not there
(it is at 225 deg, r 4.2). See the Ossuary arena section.

### Low

**20.** "Nothing answers. Two seals still hold below." is hard-coded (`boss_arena.gd:137`), wrong
with one boss down (also in the storyteller report). Count the missing bosses.

**21.** The OssuaryGate brazier (24, 12.6, -31) sits in the gate hall, 25 m behind the way in and up
a flight: an off-route checkpoint. Threshold outside does the job; consider a fire in the gallery
instead.

**22.** `world/main.gd` still moves the Landing brazier to x -1.6 (stair-era) before RealmBosses moves
it again; dead code that confuses readers.

**23.** The bone portcullis is flat salmon boxes (shot `12_oss_pit_from_stair`) and the summit ward a
flat translucent quad with three rings (shot `b08_b_crossing_top_north`); both are the last thing
you see before a boss. Use OssKit bones/skulls for the portcullis and a layered veil (fresnel,
drifting runes) for the ward.

**24.** The Ashen Rift reads as a rectangle from above (straight south edge at z -12, straight
glowing crust lines on the lava, shots `00_overview_n`, `04_hub_top`, `28_rift_rim`). Break the
south lip with basalt and a rockfall tongue.

## Boss arenas

### Thorn Henge (Thornwarden)

Measured (`probe2.log` ring scans, capsule r 0.35):
- Terrace r 13 at y 7.75, retaining wall + coping all round (outside ground 0.2-3.1 m lower).
- Bramble hedge r 12.2, solid except the stair gap (70-104 deg); menhir ring r 10.5, 21 stones with
  1.4-2 m gaps between them; a 1.5 m corridor between ring and hedge that runs all the way round.
- Trilithon + seal at 87 deg; the gate complex (seal, uprights, the two neighbouring menhirs) is
  closed: no bypass from the corridor to the stair gap. Good.
- Fighting floor r ~10 (314 m2): altar boulder at the centre (0.7 m, no sightline block), 7-stone
  horseshoe at r 5.4 on the far side (3-3.8 m tall: the only cover). Boss spawns 4.5 m west of
  centre, ~11 m from the gate. Leash radius 11.9 lets the boss into the corridor behind the menhirs.
- Lighting: one cold omni (e 1.2, r 18) over the altar; the rune ring.

Problems: the trigger (fixed in the working tree); the boss can kite behind the 21-stone ring while
the player is shut out of the corridor's sightlines; no reason in the space for the corridor; the
cover is all on one side; the seal close is a pop.

Redesign:
1. Trigger at r 9 (inside the ring), leash 10.0, so the boss fights inside the stones. Treat the
   corridor as **phase 2**: at 50 % the Thornwarden's roots burst the menhir gaps open (the real
   "uproot", visual + collision off on 4 chosen gaps), the fight spills into the outer ring, and the
   hedge itself becomes the hazard (contact damage, thorns lunge from it at telegraphed spots).
2. Rebalance cover: two fallen menhirs lying at r 7 on the gate side (low cover against his thorn
   volleys), keep the horseshoe on the far side; raise the altar to a 1.2 m capstone the player can
   vault (VAULT range) to break a charge.
3. The gate: thorns grow out of the ground behind you as you pass 1.5 m in (0.6 s, root-crack sound),
   and wither in a burst when he falls (the secrets reactivity already withers the wood).
4. Landmark: a tall cold light shaft or ember-red glow over the henge visible from west_way and the
   glade, so the hill reads as "the boss is here" from 60 m.
5. Move the seal camp at (-70, 6) to >= 14 m from HengeFire.

### The Ossuary pit (Bone Abbot)

Measured (`probe2/4.log`): floor disc r 11 at y 4.2 over lava (y -16.5); parapet 0.8 m at r 10.75 with
three gaps: stair (58 deg), chapel (270 deg), "lift" (180 deg, a 7 m drop flanked by 25 m drops to
lava); 12 broken columns at r 9.4 (1.6-6.5 m), 4 bone heaps at r 6.2, 2 spitter plinths (2 x 2 x 1.6)
at r 7.8, the charnel mound at the centre, the ChainLift deck and its stone column at r 4.2-4.9.
Gate (portcullis) 19.9 m away at the stair head; leash 16.4 m; chapel (z -99..-107) half outside the
leash. Boss spawns 4.5 m from the centre, ~6 m from where you step off the stair.

Problems: the gate is never met (2); the lift (3); an unexplained lava gap in the parapet; the
chapel half in, half out of the fight; open sky over a "crypt"; the boss is on you the moment you
land.

Redesign:
1. **Gates at the mouth**: a bone grille drops across the stair-foot gap when you are 1.5 m onto the
   disc, and a second across the chapel arch; the portcullis upstairs stays the progression seal.
   Leash 14 m.
2. **Lift out of the ring**: move the ChainLift foot to a jetty at r 12.5 beyond the west gap (that
   finally explains the gap), locked until the Abbot falls (a bone latch that shatters with him).
   Raise the parapet to 1.3 m (above VAULT_MAX 1.25) except at the jetty, so the lava edge is a
   threat you see, not one you vault into while dodging.
3. **Make it a crypt**: great ribs (the `_great_rib_mesh` already exists) arching over the pit from the
   gallery wall, with hanging chains and censers; light from candles and a single shaft through a
   broken rib. Keep the open view to the summit through the break (it sells the lift reward).
4. **Approach**: let the Abbot be seen first (kneeling at the mound, back to you) and rise only when
   the grille drops; spawn him at the far side (r 6 opposite the stair) so the player gets 2 s.
5. Use the plinths: spitters rise on them at phase 2 (they are already sized for it).

### The summit dais (Ascended Warden)

Measured: paved disc r 14 at y 27.35 (615 m2), rim wall, one 6.4 m mouth to the platform
(`DROP dais` / ring scans), nothing on the floor; ceiling 8; boss spawns 2 m behind the centre;
blink anchors at 0.7 r. Gate = the summit ward 33 m back; leash 20 m; the ChainLift jetty on the
platform; no checkpoint; no light but the lantern (shot `17_summit_top`, `b02_b_dais_eye`).

Problems: a flat empty disc gives the Warden's blinks nothing to play against and the player
nothing to use; the backdrop is a dark slope 20 m away under a taller mountain; the fight is
unsealed (2) and far from a fire (7); the climax is not visible from anywhere below (10).

Redesign:
1. **Seal at the mouth**: a ward veil across the 6.4 m mouth when you are 1.5 m in; the crossing ward
   stays the progression seal. Brazier on the ward landing (0, 25.2, -66).
2. **Orientation and backdrop**: put the player's entry on the north side and the open rim on the
   south, so the fight is framed by the drop to the rift, the Crossing and the lit village far below
   (the whole journey in one view), with the vortex overhead; or lower the Crowns behind the dais
   (the macro `north * north * 45` term) and raise the dais 6-8 m on a basalt pinnacle so it is the
   highest built thing in the world.
3. **Cover and rhythm**: four broken pillars at r 9 (the summit_pillar GLB is already loaded) that the
   Warden's blink anchors sit beside; one pillar falls per phase, so the arena opens up as he grows
   desperate. Four rim braziers he lights (phase 1) and snuffs (phase 3) as the lighting design.
4. **Beacon**: a thin pale light column from the dais up into the vortex eye, visible from spawn and
   every spoke (cheap: an unshaded additive cylinder within the glow budget), that dies when he falls.
   This is the "where do I go" answer for the whole map.

## Top 10 to do first

1. Commit and pack the GATE_CLEAR fix (`boss_arena.gd`, `zz/arena_gate_test`), extend the test to all
   three arenas and add the trigger-inside-gate audit (Critical 1).
2. Lock the Ossuary ChainLift until the Abbot is slain and move its foot off the fighting disc (High 3).
3. Put each arena's barrier at its mouth (Ossuary stair foot + chapel arch, summit dais mouth) as
   arena-only gates; stop resets from forcing progression seals open (High 2, 8).
4. Fix `region_at` / the codex region pick so small regions win; one shared function (High 4).
5. Move the "Pilgrims' Road east" camp inside BOUNDS and audit all camps >= 10 m from the walls (High 6).
6. Replace invisible walls on open ground with visible blockers; close the two road gates; exclude
   RealmBounds from wall kick and grab (High 5).
7. A checkpoint brazier on the ward landing and a lit summit rim (High 7).
8. Waystone lanterns along west_way, east_way, fen_descent; a visible cold glow on unlit braziers
   (High 9).
9. A summit beacon and a summit that reads as the highest place (High 10, summit section).
10. Retire the WindowRig gobo lights and the "STAIR OF ASCENSION" card under the Realm (Medium 14),
    then start on Hearthward's lanes (Medium 11).
