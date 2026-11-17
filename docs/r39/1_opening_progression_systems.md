# Umbral Reaches: critique, seat 1 (introduction, progression, systems, wholeness, UX, QA)

Read: AGENTS.md, ARCHITECTURE.md, PILLARS, far_reaches, DECISIONS, STORY; code in `core/story`, `core/life/progression`, `core/life/encounters/tiers.gd`, `ui/`; captures in `scratchpad/play/` (regions_a, regions_b, places, villagers, ui). Read-only: nothing run. Where I infer rather than saw, I say "verify".

Severity: P0 blocks or breaks; P1 hurts the whole game; P2 hurts a part; P3 polish. I found no P0. Evidence is `file:line` or capture filename (under `play/`).

---

## 1. Introduction: how a new game starts today

**What happens (traced in code).** Title (`ui/title_screen.gd`: Continue / New Game / Settings / Quit; `ui/title_screen.png`, a clean screen with the tagline "where the sky turns inward") -> slot -> `world/main.tscn` -> loading screen builds and warms the Realm under a camera tour (`ui/loading_screen.gd:19-40`) -> the cover lifts. `Story._opening()` (`core/story/story.gd:414-430`) sets `arrived` and `guide`, then `_stage_opening` (`:440-490`) does: 3 s black lift + zone title card -> narration line 1 ("The road ends here. Past the last village there is only the Stair, and the sky it opened.", `dialogue_db.gd:633`) -> HUD arrives with the first objective, compass and waypoint -> "Move / Look / Sprint / Jump" caps -> line 2 once you move -> line 3 ("There is light in the Kindled Keg. Find the keep.").

**Answer to Luke: yes, the player simply appears on the Sanctuary fire on Hearthward's green** (`RealmLayout.SPAWN = (0,0,33)`, `realm_layout.gd:18`), with the camera behind the wanderer's back (`ui/hud_exploring.png`). There is no authored camera anywhere in the shipped game: `PlayerCamera` has only the follow-cam (`core/player/player_camera.gd`); every cinematic camera (`zz/trailer_cam.gd`, `zz/boss_intro_shots.gd`) lives in `zz/`, which is not shipped. The opening is well engineered (one message at a time, HUD held back, key caps) but it is text over a gameplay view. It tells the player what to do before it has told them why.

**Findings**

- **I-1 (P1) The game has no opening image.** Its best asset, the turning sky with the Order's chain hanging into it, is visible in nearly every outdoor capture (`regions_a/region_road_0.png`, `ui/hud_exploring.png`) but is never *presented*. The trailer already has a cold open ("black, THE SKY TURNS INWARD, crane over the green", `zz/trailer_shotlist.md`, shot `cold`) that the game does not use. Fix below, ~3-4 days.
- **I-2 (P1) Line 1 is now false.** "Past the last village there is only the Stair" was written when the world ended at Hearthward. Since the Far Reaches, Lastlight, Reedholm and Fallowmere are villages beyond it, and the Stair/endgame moved 310 m east (`far_reaches.md` "The endgame, moved"). Same text in `docs/STORY.md` "Arrival". Fix: rewrite line 1, 10 minutes (suggestion in the proposal).
- **I-3 (P2) The first prompt is a control card, not a reason.** `hud_exploring.png`: "W A S D Move / Look / Sprint / Jump" at the centre, "Level 0" bottom-left, a "176 M" waypoint to a gold rune that means nothing yet, and (in the capture) no visible objective text. A new player is told how to walk before they know there is a fire to reach. The opening should hand over *at an action* (see proposal), not at a walk card.
- **I-4 (P3) Time-of-day labels that are not time of day.** The region plate's second line reads "Dusk" / "Night" / "Deep Night" (`hud_exploring.png`, `quest_offer.png`) but these are danger-tier names (`tiers.gd:44-50`). In a one-night game the player reads them as a clock. Rename the tier line ("Safe / Wary / Dangerous / Deadly") or hide it.

### Recommended opening: "The Last Lantern" (about 48 s, skippable)

One authored sequence, replacing the black-lift + wait in `_stage_opening`. It uses only things that already exist (sky, chain, villagers' work loops, lamps, the Keg, the staff) and is pre-warmed by the loading tour (VIEWS 0 and 1 are exactly the green and the Keg interior), so it adds no shader compiles (frame stutter is Luke's top issue; this is why I chose the village over a flythrough of the Realm).

| t (s) | Shot | Sound / text | Teaches |
| --- | --- | --- | --- |
| 0-6 | Black. Tagline card ("where the sky turns inward", reuse title text). | Gloom drone swells; one low bell (the `ring_bell` the ending uses, `story.gd` ending). Line 1, rewritten: "The road ran out of pilgrims a long time ago. Past Hearthward the sky is turning inward." | The sky is the antagonist (pillar 1). |
| 6-20 | Lens at 1.6 m on the green, cranes up past the Keg chimney to the vortex and the chain, slow tilt along the chain to the Crowns. | Line 2 (existing): "Over the Crowns the sky turns inward. The cold comes down the mountain to meet you." | The goal is up there; the dark comes from it. |
| 20-34 | Crane down to 3 m, dolly through the square: Fennick lighting a lamp on his pole, Hild's forge sparks, windows of the Keg, villagers at their loops (all existing). Light pools end at the lamp's edge; beyond is black. | Village ambience, no text. | Pillar 2 ("warmth is earned"): every light was made by hand; where light stops, danger starts. |
| 34-42 | Settles behind the wanderer at the Sanctuary fire; wanderer lifts the staff; lantern flares (the Lantern Ward's flare FX, visual only, no cast). | Line 3 (existing): "There is light in the Kindled Keg. Find the keep." | The staff/lantern is the player's tool. |
| 42-48 | Camera eases into the normal shoulder cam over 1.2 s; HUD fades in with the objective and waypoint (existing `hold_opening(false)`); the Move prompt appears, now *after* a reason. | Move lesson as today. | Hand-off at "walk to the lit door", 22 m east. |

Skip: hold interact / Start; a small "Hold [E] to skip" through the text director's lesson lane after 1.5 s; skipping lands on the same hand-off state (HUD up, line 3 spoken). Plays only for a real new game (the existing `_staged_hud()` test), once (`opening_seen` flag), never for Continue or the Deeper Night; a Settings > Interface "Play opening" toggle beside Guidance (`ui/hud_prefs.gd`).

**Code it touches**
1. New `core/story/opening_shot.gd`: a pure function of a clock, borrowing the math in `zz/trailer_cam.gd` (`vista`, `frame_cam` collision check): promote that to `core/util/cam_rail.gd`. A child of Story.
2. `core/player/player_camera.gd`: one override (`cine_pose(from, at, fov)` and release), and a player input lock (the loading screen already freezes the player; reuse that path).
3. `core/story/story.gd` `_stage_opening`: call the shot between `fade_in_opening` and the first `narrate`; set `opening_seen`.
4. `ui/hud.gd`: two letterbox rects beside `_fade`, the skip prompt; `hold_opening` / `fade_in_opening` already exist.
5. `core/story/dialogue_db.gd:633-637` (new line 1); `ui/settings_menu.gd`, `ui/hud_prefs.gd` (toggle).
6. Villagers: no code; suppress the guide's barks while the shot runs (`guide.gd:336`, `_barks`).
7. `zz/opening_test.gd`: add skip path, camera-handoff continuity (pose within 0.3 m of the follow cam), no HUD under the shot, no save write.

Rejected: an arrival on the road (300+ m of walking before anything happens, new stutter risk, nothing to show at the road's end); a Realm flythrough (pre-warm covers only the loading tour's stops; far content at 420 m would stream).

---

## 2. Progression

**The spine, as coded** (`quest_db.gd:19-49`): keep -> kindle the meadow fire (guided only) -> pick a door (Thornwarden west or Bone Abbot south, either order) -> second keeper -> **peal: answer any 4 of 8 bells** -> carry heart and crown to the summit ward -> Warden -> return to the Keg. Spells are staged by deeds (`kindling.gd:61, 243, 253`: first kill -> Ember Lance, first seal -> Rift Step, first great one -> Nova), which is good. Level curve 60 + 20 per level, cap 30 (`level.gd`, `paths_db.gd`). Levels buy 24 Path nodes totalling 38 points (33 points exist by cap + three keepers; counted from `paths_db.gd`).

**What the player wants**
- 10 min: the first kill, the first fire (40 XP of the 60 for Level 1), a new spell. Served well: staged spells and a quick first level are the strongest part of the early game.
- 1 h: the first boss and the second door. Fine, but there is no signal for *which* door first (henge is tier 1, the Ossuary tier 2, `tiers.gd:14-21`; no level hint anywhere).
- 5 h: ... nothing named. The 4-of-8 bell middle, then an ending. This is where the spine goes soft.

**Findings**

- **P-1 (P1) Act II has no progress readout and the guide leaves exactly there.** `peal` has no `count`/`of` (only the minor `kindle` row does: `quest_db.gd:47-48`), so the HUD never says "2/4 bells". The guide lets go at Brannoc (`guide.gd:115-117`, `_finish`), i.e. right where the player must choose 4 of 8 bells across seven countries. The tracked-task waypoint still works (`QuestMarkers.next_bell`), but "how far am I" is unanswered. Fix: add `count: "peal", of: 4` to the row and render "Bells 1/4" on the objective block and the Keg's tongue-count; ~0.5 day.
- **P-2 (P1) The world's danger follows the boss count, not the player's power, and level gates nothing.** `tiers.gd:126-127`: `tier = region base + night_depth` (every boss felled deepens *the whole night*), and a plain pawn's plate level is a function of tier and distance from the hub (`LEVEL_BAND`, `:36`), never of the player. Consequences: (a) killing the first keeper makes ground you already cleared harder (up to HP x2.1-3.0, `TIERS`); (b) a boss-beeline player meets tier-6 plates (28-31) at the summit with ~lvl 15-20, because the XP tally says the cap lands "near the Warden" only if you finish ~75% of all content (`DECISIONS.md` 15 Nov). That makes the side content mandatory in effect, which is the MMO treadmill `PILLARS.md:12` rules out. Fix options: (i) say it, add a level recommendation to boss and seal prompts and the plate ("Recommended: 14"), 1 day; (ii) cap `night_depth`'s effect on regions the player has cleared, or scale elites by max(depth, player level band), 2-3 days and a playtest.
- **P-3 (P2) Level-ups are small and live in a menu.** Paths are +5% damage, +4% recovery, +10 Gloom (`ui/char_kindling_paths.png`: "+5% damage from every spell", "Walk and run 5% faster"); the toast is "Something comes back to you. Remembrance 2: a step on the Paths [K]" (`ui/quest_offer.png`). Thirty levels with no new verb after the fifth spell. Also three names for one number: HUD "Level 0", Kindling "LEVEL 0 (REMEMBRANCE)", docs "memory/XP". Fix: let every fifth Path node be a verb or a visible change (a Ward variant, a Step charge), and call the HUD number "Remembrance" or drop "Remembrance"; ~2-3 days data + UI text.
- **P-4 (P2) The Far Reaches are half the map and outside the spine.** They are pointed at only after `peal:4` (`dialogue_db.gd:339-342`, Brannoc's `far_work`), earn no faction standing (`reach_state.gd` FACTIONS lists none of the 11 Reach regions: 0 matches for reedmere/lastlight/fallow), and take no part in the peal. East-Reach ground (Lastlight) is on the way to the summit anyway, so a player passes it unprepared. Fix: give the Reaches a fifth faction ("the Outliers": the Reaches' three towns plus Greyfell, Kings' Barrows, Cairns...) with a gift at FRIEND and make one bell hang in a Reach, ~1-2 days; or at least have Hearthward's people mention a Reach town in Act I.
- **P-5 (P2) Dailies: "a day" is ten minutes.** `today()` = village night count (`quest_book.gd:259-267`), and `Village.nights` is one CYCLE of 600 s (`village.gd:40, 457`) and is *session-only* (`:69`). So the five dailies re-offer every 10 min of play (half XP each, `level.gd`), the treadmill the pillars warn against, and after a relaunch the label resets to "night 0", so a daily handed in at "night 0" last session is locked again until the clock runs. Per decision I do not propose cutting them. Fix: store `nights` in the save and make a "day" per boss felled / per bell rung (the story's own clock), 0.5 day; and show the "back tomorrow" state in the ledger.

---

## 3. Systems

Kept by decision (rested XP, item level, sets, babble, dailies): judged only for integration.

| System | Verdict | Evidence / note |
| --- | --- | --- |
| Light, Gloom, fires, lamps | **Pulls the most weight.** The spine of the pillars; fires are the only rest, lamps are wayfinding. | `PILLARS.md:5-6`; lamps rule `DECISIONS.md` 7 Nov |
| Spell staging by deed | Pulls weight. | `kindling.gd:61,243,253` |
| Tracked waypoint and trail | Pulls weight; the 17 Nov rework (one waypoint, follows roads) is right. | `quest_trail.md`, `DECISIONS` 50, 52 |
| Quest verbs (clues, tracks, lantern_walk, order, vigil) | Pull weight and are the most distinctive content; 119 tasks is a lot for one night. | `DECISIONS` 58-61 |
| Gear/ilvl/sets, raise/reforge/salvage | Works as a sink, kept. Integration gap: five materials (grave ash, ember shard, ash-bloom, grave iron, relic fragment, `item_db.gd:9-65`) plus XP plus Path points; `char_wanderer_gear.png` is dense but readable. There is no crafting, so the "crafting?" question is moot: it is reforge only. | |
| Hearth trades and "the bells" (fast travel) | **Disconnected / buried.** Fast travel lives in Kindling > Hearth > "bells" (`growth.gd:980-1034`), reachable only at a lit fire, taught nowhere (`PROMPTS` in `hud.gd:489` has no entry). Most players will never find it. Fix: a world-map prompt when a fire is lit and a hint on the first lit fire; ~0.5 day. |
| Horses | **Weakly integrated.** Five breeds bought at hitching posts for 40-80 ash (`horse_db.gd:9-23`); post pin is the "vendor" glyph (`stables.gd:56`) so it reads as a shop; the only teaching is a "ride" prompt; quests say "a horse would help" (`quest_chains_r38_east.gd:64`, `_south.gd:31`) but nothing sends you to a stable. Gallop 11 m/s vs sprint 7.5 (`player.gd`, `horse_db.gd`): trot 6.5 is *slower* than a sprint, so the benefit is real only at gallop. Fix: horse glyph on map (the legend already lists "Horse"), one early quest that ends with a stable, trot speed above sprint; 1-2 days. |
| Kindled Watch / outposts / roaming events | Fine, but invisible to a new player; the watch fights are hard to read (`villagers/watchman_fight_3q.png`). Teach by a first-lit-fire hint. | |
| Bells (8, four needed) | Content-rich but the spine's weakest link (P-1). Also told three ways: "seven bells" (`STORY.md:44`, `DECISIONS` 5 Nov row), eight (`quest_chains.gd:639`), the Bellfall's "eighth bell" (`far_reaches.md:28`). | |
| Factions (Rooted, Kindlers, road folk, Marchers) | Disconnected from the Reaches (P-4). | `reach_state.gd:21-36` |
| NPC babble | Kept. The dialogue box is excellent; `[E] skip` is tiny. | `villager_talk_1_fennick_a.png` |

---

## 4. Wholeness: one game or a pile of features?

Closer to a pile with a strong skin. The look, the sound and the tracking tools hold together; the *argument* does not.

- **W-1 (P1) The pillars describe a different game.** `PILLARS.md:3` "short ... solo", `:8` "A thirty-minute slice", `:14` "not an open world (a map to clear)", `:12` no treadmill. The game today is a 740 x 548 m Realm with 41 regions, 119 tasks, dailies, item level, gear sets, rested XP, horses and a world map with outposts and rares (`ui/world_map_whole.png`). The file itself admits the tension (`PILLARS.md:28`) but nothing replaces the test. Fix: a one-page rewrite of the pillars for the Far Reaches game (what "dark is the clock" now means at 5 h; what the open world is *for*), half a day of Luke's time. Without it every new system passes the "which pillar" test by default.
- **W-2 (P2) The spine and the content are two different games.** The spine is a four-fight rail; 119 tasks and the Far Reaches hang off it with no pull toward it. After the peal nothing but the ending remains and the Reaches are "post-ending" (`DECISIONS` 62). Make the Reaches matter before the ending (P-4).
- **W-3 (P2) Geography seams from the moved endgame.** The Stair, the Crossing and the summit moved 310 m east; text still says "the Stair" in the opening (I-2), docs and node names (`StairFoot`, kept for saves). The first sight of the chain in the sky is the only hint of where to go, and it is never framed (I-1).
- **W-4 (P2) Content waves are visible in the code.** 22 `quest_chains_*.gd` files named by round (`r38_*`, `deepen_a/b/c`, `far_reaches_*`, `signature`, `verbs`), and a 11,877-line `docs/THE_NIGHT.md` from 6 Nov under a "consolidation" phase. New people cannot find the live design. Fix: one `docs/DESIGN_NOW.md` (the spine, the clocks, the currencies), 1 day; archive THE_NIGHT.
- **W-5 (P3) Tone.** The prose is consistently good ("the hollowed", "from the bottom up"). The tier names (I-4) and the "Level 0 (Remembrance)" mix (P-3) are the places where game-speak leaks into it.

---

## 5. UX (from `ui/` captures)

What works: the painted key caps, the Journal/Kindling/Pack/Wanderer top tabs (`char_*`), the quest offer card ("What is wanted / What it pays", `quest_offer.png`), the shop and loot windows, a legible compass, the settings split. The medieval style is consistent.

- **U-1 (P2) The world map's task markers pile up.** Around Hearthward at least eight overlapping gold "!" pins (`world_map_whole.png`, `world_map_all_10.png`), and names collide: "THE SUMMIT OF ASCENSION" runs into "THE ANCHORHOLDS" and "THE ASHEN RIFT". At 41 regions this will get worse. Fix: cluster pins with a count badge at the whole-map zoom and a label-collision pass; ~1 day.
- **U-2 (P2) The undiscovered map is a big blank cross.** `world_map_whole.png` at "28 of 41": the West Reach column and the SE/E blocks are plain parchment; that reads as unfinished, not as fog. The fully revealed map (`world_map_all_10.png`) is lovely. Fix: draw an inked, un-labelled coastline/ridge outline for the unseen ground and the first letters of the region names; 0.5-1 day.
- **U-3 (P3) HUD duplicates.** One waypoint is shown twice: "176 M" under the compass and "176 M" under the gold rune on the world (`hud_exploring.png`); the compass strip carries five near-identical orange icons; the minimap draws "Facing the Mountain / The Hearthward fire" over the map face. The 17 Nov decision made the trail one waypoint; the compass still carries its own mark.
- **U-4 (P3) Toast stack and the bottom-left XP line.** On a level-up the toasts (`quest_offer.png`: "+25 grave ash (145)", "+4 ember shard (11)") sit between the hotbar and minimap over the minimap's lower rim; "Level 3  55 / 120  +120 home" at bottom-left is 10 px grey on busy ground. The XP bar needs a clearer home, the "+120 home" (rested) wants a plain-words label.
- **U-5 (P3) Small type.** `[E] skip` in the dialogue box and the footers (`[W / S] choose  [Enter] select`) are the smallest text on screen; Text Scale exists, but the default is small at 1080p.
- **U-6 (P2) Menu count.** Four top tabs x 5-6 sub-tabs, plus Tasks (L), Map (M), Satchel, Objective (hold Y); seven separate keys (`input_setup.gd:46-82`). Esc is both Settings and "close menu" (`:31`). Acceptable for the genre, but with no onboarding for Kindling > Hearth (fast travel) or the Pack's raise/reforge (shown only at a fire: "Raise: Only at a kindled fire", `char_wanderer_gear.png`). Fix: a one-line tip when a first fire is lit (P: `HUD.PROMPTS`).
- **U-7 (P3) Pad:** two "This control can't grab focus" warnings in the UI capture log (`ui/errors.txt`): some control is not focusable; check on pad navigation.

---

## 6. QA: broken or suspicious (cited)

- **Q-1 (P2) Engine "indexing did not unpair geometries from light" x4** in the villager capture (`villagers/errors.txt`). A light being freed with geometry bound; plausible source is the lamp/villager lights. Bisect by running the villagers section with lamps off (`--no-lamps`).
- **Q-2 (P2) Frame spikes at the first region and the wood.** `regions_a/perf.txt`: `region_hearth` worst 84.5 ms, `region_thornwood` worst 47.4 ms, 1% low 16.7 ms (60 fps) in 8 of 15 regions. The Hearth value is the capture's first region (likely the first-frame cost the DECISIONS row 48 calls out: 80-105 ms after the cover lifts); thornwood is a mid-game hitch. Frame stutter is Luke's top complaint.
- **Q-3 (P2) Far silhouette ends in a hard vertical edge** at the top left of `places/vista_realm_from_se.png` (x about 620): a flat dark slab runs to a clean cut against the Crowns. Looks like a horizon-ring or FarDetail seam. Verify in game from the same spot.
- **Q-4 (P3) Capture harness**: `places/vista_rift_summit.png` is the camera inside a tree canopy (nothing to review); `regions_b` "region plinth: only 1 usable view(s)" and a watchdog timeout (`regions_b/errors.txt`). Not game bugs, but the Plinth was not captured, so it is unreviewed.
- **Q-5 (P3) Portrait**: Old Fennick's beard renders as pale shards (`villagers/villager_talk_1_fennick_a.png`) next to a smooth face; portraits are the first thing a player studies in a long talk.
- **Q-6 (P3) Leaks at exit**: ParticlesShaderRD (known, `DECISIONS` 15 Nov).
- **Q-7 (P3) Stale text**: the opening line (I-2), `STORY.md` (the first fire is "at the Stair's foot"), "Lamps 0 of 94" vs "~70 lamps" in `DECISIONS` 7 Nov.

---

## Priority list (do in this order)

1. **I-1 + I-2** the opening and its line 1 (P1, 3-4 days; the line alone is 10 minutes today).
2. **P-1** bells counter and Act II progress on the HUD (P1, 0.5 day).
3. **P-2** make danger legible: recommended-level on seals and bosses, and decide whether `night_depth` hardens cleared ground (P1, 1 day to say it, 2-3 to change it).
4. **W-1** rewrite the pillars to the game that exists (P1, half a day).
5. **P-4** give the Far Reaches a faction and a stake in the spine (P2, 1-2 days).
6. **P-5** a "day" that is not ten minutes, saved (P2, 0.5 day).
7. **U-1/U-2** map pin clustering and an unseen-ground sketch (P2, 1-1.5 days).
8. **Hearth "bells"/fast-travel hint and horse glyph** (P2, 1 day total).
9. **Q-1..Q-3** bisect the light bug, the Hearth/thornwood spikes, the horizon seam (P2, 2 days).
10. **P-3, U-3..U-5** level-up verbs and HUD tidying (P2-P3, 3-4 days).
