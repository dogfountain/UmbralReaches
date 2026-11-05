# Umbral Reaches: full critique (state at commit 41fd7ad, r34, 5 Nov 2026)

How I looked: I read the code (325 scripts, ~107k lines of GDScript), the docs and the earlier critique
rounds (r29 A–F, r30). I ran the full headless test suite (`tools/run_tests.sh`, isolated HOME) and
played the opening windowed with `zz/first_minutes` (isolated HOME; its shots are
`shots/critB_first_review_*.png`). I also went through the newest r33/r34 captures in `shots/`.
Severity follows the house scale: **S1** breaks or looks broken, **S2** clearly hurts, **S3** polish.
Where a finding rests on an older capture rather than today's run, the capture is named.

---

## Verdict

A real achievement as a build. It has a coherent dark-blue night, a strong hero silhouette, good terse
writing, atomic saves, a headless test gate, and a procedural world that rebuilds itself. But the game
has **sprawled faster than it has been finished**. Every round added another genre's layer:
Souls (ash drop, parry, riposte), WoW (GCD, aggro and leashing, rested XP, raid rooms, quest
`!` marks, unit frames, item level), Diablo (sets, reforge, salvage), Enshrouded (glide, updrafts,
grapple), plus a full traversal kit. None of these layers is bad alone. Stacked on a one-night,
three-boss game set in a 0.1 km² box, they bury the one idea that is this game's own: **light holds
back the dark, and the dark is the clock.**

What a new player meets first is noise, not that idea: overlapping text, five spells already on the
bar, a key-list card, a bar filling before they've met anyone. Next comes inconsistency: four art
styles, MMO menus in a gothic game, and Sims babble from grim dwarves.

**Recommendation: freeze features, then do one consolidation round.** Cut or fold systems, add a
single UI/text arbiter, pick one art style per asset class, and fix the bugs below. More content
won't help until that's done.

---

## Top 10

1. **Scope sprawl (S2, design).** About 10 progression systems, 15+ movement verbs, 35 enemy scripts,
   3 raid bosses, 89 quest-chain entries and 92 writings, inside 310 × 325 m. Breadth is crowding
   out depth and polish everywhere below.
2. **Keyboard melee is broken (S1, bug).** `G` is both the staff strike and the Gear menu. Details in B1.
   *Fixed in r35, as were B2, B3, B4 and B8. The single text arbiter in #3 is still open.*
3. **Text collides everywhere (S2, UI).** At least nine independent text channels have no arbiter. In
   today's run the title card and the region banner draw on top of each other 8 s into a new game.
4. **Gloom does five jobs (S2, design).** It's the timer, the health bar, the Shade trigger, the
   overcap death counter, and the fall-damage and enrage sink. One bar can't teach all of that.
5. **Art direction is split four ways (S2, art).** Realistic grass, painterly terrain, blocky
   oversize-brick architecture and clay or doll characters share a frame.
6. **The world reads as a diorama (S2, world).** A flat tabletop in a cliff ring, with a south half of
   rectangles and straight roads. Its 19 "regions" are each about one city block.
7. **No front door (S2, product).** No title screen, main menu, Continue or Quit, and one save slot.
   Debug keys (F8 benchmark, F9 autopilot) are live in the shipped build.
8. **MMO raid rules on a solo action game (S2, design).** Leashing that heals to full, soft enrages,
   add intermissions, and mechanics explained twice in text. The camera can't handle the raid rooms.
9. **Code health is drifting from its own rules (S2, tech).** 605 string `.call()`s, 234
   `has_method`, 54 reads of other objects' `_private` fields, 17 files over 1,000 lines, and UI built
   by about 20 scripts on clashing canvas layers.
10. **Docs and the shipping path have rotted (S2, process).** The README says "No audio yet" and "no
    combat… loot or saves". ARCHITECTURE was verified at r30, and the perf baseline predates the
    Realm. The owner's build is a Linux `.pck` copied into a Mac app in `~/Downloads`.

---

## 1. Bugs found

| # | Sev | Where | What | Evidence |
|---|---|---|---|---|
| B1 | **S1** ✅ fixed | `autoload/input_setup.gd:44`, `ui/gear_panel.gd:62-66, 293` | `staff_strike` and `gear` are both bound to **G**. The panel's `_input` opens the Gear menu and pauses the tree. `staff_arts.gd:236` polls `Input.is_action_just_pressed`, so `set_input_as_handled` doesn't stop it. Pressing G opens the menu, and pressing G again closes it *and* swings the staff. On keyboard the only working melee is Mouse 4. Gear also has no row in Settings → Controls. **Fixed:** Gear is now **O**, bound in `InputSetup` (the panel no longer binds its own key). The Satchel button reads the key from the InputMap, and Settings → Controls has a Gear row. `zz/robust_test` now fails if any key or mouse button has two actions; with Gear back on G it reports "key G: staff_strike + gear". | code, robust_test |
| B2 | S2 ✅ fixed | `world/main.gd:38`, `ui/hud.gd:375-398`, `discovery_banner.gd` | On a new game, "THE UMBRAL REACHES" and "HEARTHWARD — the last kindled village" render over each other at 7.75 s, over the 4-line controls card. **Cause:** `main.gd` emits the arrival `zone_entered` before the discovery banner exists (it's built later in the Realm build), so the banner never held for the title at all. **Fixed:** the HUD reports `title_busy()` (a card waiting for the loading screen, or its tween still running, fade-out included). The discovery banner and the Journal's banner wait on it. Re-run: title alone at 7.52 s, Hearthward banner at 12.32 s, no overlap frame (`zz/first_minutes` now flags one). | `shots/critB_first_review_title.png` → `critB_first_fixed3_title.png` |
| B3 | S2 ✅ fixed | `ui/compass.gd`, `ui/minimap.gd` | No label-collision handling. Compass distances print over each other (one reads "179283 M") and minimap place names overlap. **Fixed:** the compass places distance numbers nearest-first and drops any that would touch one already placed. The minimap drops a pin name whose box overlaps one already drawn. | `shots/quests_r34_play_ruan.png` (re-rendered: "109 M", "51 M"; names apart) |
| B4 | S2 ✅ fixed | `core/enemy/enemy.gd:1987`, `zz/enemies_r33_test` | **FAIL: "its packmate resets with it".** A packmate stayed hunting when its leader evaded home. **Cause:** the reset loop judged each mate by its cached `_dist`, which refreshes only at think rate (10 Hz). A leader evading between two of a mate's thinks saw the mate still "near" a wanderer who had gone 33 m away. **Fixed:** the loop measures each mate's distance at that moment. The test now passes (mate state 0), and it prints the mate's state, distance and hunt timer if it fails again. | test log |
| B5 | S3 | `core/vfx` particle material held in a static | Every windowed exit leaks one `ParticlesShaderRD` and one shader RID. It's still open in `register.md`. | `first_minutes` log tail |
| B6 | S3 | `player.gd:666`, `player.gd:1404`, `enemy.gd:1605` | Three writers of `Engine.time_scale`, and only the hitstop is token-guarded. The perfect-dodge timer's `time_scale = 1.0` can cut a hitstop short or end another slow-mo. It also slows every UI tween. | code |
| B7 | S3 | player body yaw | While strafing and reversing, the wanderer's turn moves only on physics ticks (tick ratio 0.22 / 0.32), so it visibly steps at 60 Hz on a 120/144 Hz display. | `FEEL strafe body_yaw 0.22` |
| B8 | S2 ✅ fixed | `core/player/player.gd` (`_shoulder_tick`, `_thin_occluder`) | A stele hides the wanderer completely while strafing. In the henge raid a standing stone fills half the screen mid-fight. **Cause:** the camera boom sits 0.95 m over the right shoulder, and every occlusion check ran along the boom, not along the line from the camera to the wanderer. The "thin prop" rule also passed anything that left one edge ray clear. **Fixed:** each frame six rays (chest and head, three across) look at the wanderer from the full-shoulder camera spot. If 4 or more are blocked, or that camera would sit closer than 1.8 m, the boom eases in behind the wanderer and back out when clear (judged from a spot that doesn't move with the swing, so it can't feed back on itself). "Thin" now means fewer than half of five rays across the boom are blocked. Re-run: open ground keeps the shoulder (1.00). At the stele it swings in (0.01) and the wanderer is in view at 3.05 m. The henge maze frame shows the arena and the boss. | `critB_first_review_seg_strafe.png` → `critB_first_fixed5_seg_strafe.png`, `raid_henge_p2_maze.png` |
| B9 | S3 | discovery banner vs minimap plate | Two region names show at once: the banner says "The Crossing" while the minimap plate says "Hearthward". | `critB_first_review_seg_strafe.png` |
| B10 | S3 | `Travel.erase_save` → `erased` blocks `save_game` (`travel.gd:307`) | After "Erase Saved Progress" you keep playing a session that silently never saves, and no restart is offered. | code |
| B11 | S3 | `core/life/village/villager*.gd` | Villagers have no separation or avoidance, and two render inside each other at the green. | `critC_npc_nan_final_mid.png` (4 Nov) |
| B12 | S3 | `ui/satchel.gd`, toasts | The satchel's materials row is cut in half by its scroll area. Loot toasts run off the right edge ("…ADDED TO YOUR SATCH"). | `loot_satchel.png` (r33) |
| B13 | S3 | `input_setup.gd:31,33` | F9 (demo autopilot) and F8 (benchmark) are bound in the shipping build. A player pressing F9 hands the wanderer to an autopilot. | code |
| B14 | S3 | `ui/codex.gd` | The Journal opens on its empty tab: nine "…a part not yet found" rows and "Nothing here yet." | `critF_ui_1600x900_journal.png` |
| B15 | S3 | input | Five scripts add their own InputMap actions outside `InputSetup` (L, M, J, G, and K **twice**: `growth.gd:258`, `kindling.gd:55`). That's how B1 slipped through. | code |

---

## 2. Game design

### 2.1 The core loop: light vs Gloom
- **The idea is good and specific:** warmth only where there's gameplay, and the dark as a clock.
  Keep it as the spine.
- **Gloom is overloaded (S2).** It's a passive timer (2/s in the dark, ×1.5 sprinting, 3.5/s in the
  rift: 0→100 in 50 s, or 33 s sprinting). Enemy blows fill it, so it's also the health bar. At 100 a
  Shade spawns, and *also* each further blow counts toward a 3-hit Hollowing. Falls add to it, and
  boss enrages multiply it. The player sees one purple bar and must infer all five rules.
- **Two different deaths share one bar (S2):** the Shade's touch, or 3 overcap hits. The toast "They
  do not kill. They fill the dark." is a lovely line, and the system then makes it untrue.
- **The clock fights the content (S2).** The game asks you to read 92 writings and inscriptions
  ("[E] Read the inscription"), take quests and forage, while a 50-second timer runs. In today's
  run, about 25 s of scripted movement from the spawn put Gloom at roughly half. A first-time player
  meets a filling bar before meeting the Keep.
- **The light pillar is diluting (S3).** Four braziers became 4 + 7 fires, Lantern Ward, mirrors,
  wayfinding lanterns, floating lamps and fire bowls. When light is everywhere, "warm only where
  there's gameplay" stops meaning anything.
- *Direction:* let Gloom be **only** the dark's clock and give combat its own visible cost. That could
  be lantern oil, light radius, or a short Wounds bar that fire heals. One rule per bar.

### 2.2 Combat
- **Rule count is far past what the encounter count can teach (S2).** There are 5 hotbar spells plus
  learnable Tether, Well and Familiar. On top: staff light and heavy, guard, parry, perfect dodge,
  riposte, Marks, Resonance, Rift Surge, burn, chill, freeze, shatter, Maelstrom, Kill Chain, a 0.5 s
  GCD, cast queue, pushback, interrupts and lockouts. A player meets a handful of packs between fires.
- **A WoW GCD inside a Souls-like dodge kit (S2).** A 0.5 s global cooldown with a 0.3 s queue makes
  spell input feel late next to an instant roll and slide. Pick one tempo.
- **Five spells are on the bar from minute one (S2).** The hotbar teaches nothing, and the first
  screenshot already has a full MMO action bar.
- **Melee is a second-class citizen.** It's on G (broken, B1) or the mouse side buttons, and on a pad
  it's "RT up close". Guard is X or Mouse 5, and on a pad "B held, locked on". Verbs this central to a
  Souls-like need primary buttons.
- **Readability.** Every enemy, from husk to elite, carries the same orange segmented world-space bar.
  The bars draw over geometry and over each other (`enemies_r34_lineup.png`). "Lv 5 · Elite"
  plates and an "IN COMBAT" tag on the player frame are MMO furniture in an action game.

### 2.3 Enemies and AI
- 35 enemy scripts, but the roster's look is incoherent. Robed candle pilgrims, beige bandaged runners
  with lantern heads, a pale pink humanoid ringed in red, and a black quadruped all stand on one road
  (`enemies_r34_lineup.png`). Each reads as a different game's asset.
- **WoW leashing in a solo game (S2).** An enemy you drag too far runs home immune and heals to full.
  In an MMO that protects other players' pulls. Alone, it reads as a bug, punishes kiting (which the
  movement kit invites), and is currently half-broken (B4).
- Flat steering and no navmesh ("Flat steering, no navmesh" in `enemy.gd`'s header). It works on the
  meadows, but with the r34 maze walls, benches and pits, expect wall-hugging and stuck pursuers.
  `shade.gd`'s "steer around walls after 2.5 s blocked" is a symptom.

### 2.4 Bosses and raids
- Ambitious and data-rich: the growing bramble maze, shrinking briar ring, intermission knots, the
  Warden's gale and pylons. The *ideas* are good boss design.
- **Mechanics are told, not shown (S2).** The summit shows the boss emote "The door behind him opens a
  crack. A gale! Lean into it, or shelter behind a lit pylon." *and* a hint line "Gale of the Door:
  walk into the wind or stand behind a lit pylon." Both say the same thing, at the top and the middle
  of the screen (`raid_summit_p2_gale.png`). That's a raid-addon habit. The arena should carry it:
  sound, wind particles, pylon glow.
- **Group mechanics as solo chores (S2).** Line-of-sight hiding from Thornstorm, burning three knots
  during an intermission, a soft enrage at 400 s. Enrage punishes the learning attempts a solo player
  needs.
- **The final boss has no scale (S2).** The Ascended Warden is a player-sized robed figure with a halo
  on a flat disc with a polar grid. The pylons are brick chimneys with cone flames. Nothing about it
  says "halfway into the sky" (the Keep's own words). The Bone Abbot reads as pink plasticine
  (`combat/after_bone_abbot_0.png`).
- **The camera breaks in raid rooms (S2, B8).** Big standing stones and walls inside a 29 m arena
  plus a 3.7 m arm with no occluder fade means fights get played half-blind.

### 2.5 Progression and economy
- **Count the systems:** grave ash (Kindling ranks), Memory XP to level 30, **rested XP**, Path
  points, gear with item level, four slots, sets, raise, reforge and salvage. Then charms and charm
  slots, cores, relic variants, ember shards, relic fragments, ash-bloom, grave-iron, attunements,
  meals and village trades.
- **The gear panel is stat soup (S2).** "+0.15 damage per Mark detonated", "+9% faster Lance charge",
  "ilvl 29 vs 18" (`loot_gear_panel.png`). An item-level treadmill needs an endgame to climb toward,
  and this game has three bosses.
- **Rested XP has no reason to exist (S3).** It's WoW's log-off bonus, and this is a single night.
- **Menu sprawl (S2).** Kindling has **9** tabs (Embers, Spells, Oaths, Relics, Charms, Staff,
  Loadout, Paths, Hearth; `ui/growth.gd:36`). Separately there's Gear [G], Satchel [Tab], Journal [J]
  with 6 tabs, Tasks [L] and Map [M]. Relics show in three places (Satchel, Kindling and Journal) and
  charms in two. Collapse these into one character screen.

### 2.6 Quests
- The writing in offers is good ("…like a dog with no master").
- The frame is a WoW checklist: a `!` over the head, a modal with "What is wanted / What it pays",
  Accept and Decline. The `!` is about as tall as the NPC's torso at 6 m, and the giver stands
  waist-deep in grass (`quests_r34_cadoc.png`).
- **The main story ignores the new half (S2).** The Keep's spine is still four braziers, two seals and
  three bosses. The seven r34 regions hang off side chains, so doubling the world didn't double the
  story.

### 2.7 Exploration and secrets
- Credit: the discovery banners with poetic subtitles ("they never looked up") are lovely.
- In a dense small world they fire constantly and stack with the other text (§5). Rate-limit them,
  and make sub-places quieter than regions.

---

## 3. Player, controls and onboarding

- **Verb count (S2).** Walk, sprint, jump, double jump, jump-cut, slide, slide-hop, roll, perfect
  dodge, mantle, vault, ledge hang, climb, wall kick, glide, updrafts, grapple/tether and Rift Step:
  about 18 verbs. The world isn't built around most of them, and r30 already said the kit has no
  combat payoff. Each verb adds edge cases to one 3,203-line file.
- **Feel is good where measured.** Exponential accel and decel, coyote time, a jump buffer and apex
  hang. Camera, body and hand all move on rendered frames (tick ratio about 1.2), except body yaw
  while strafing and reversing (B7).
- **No rebinding (S2).** Settings → Controls is a read-only list, and with keys spread over
  G/X/V/C/F/Q/R/T/E/K/J/L/M/Tab/I/Ctrl/Shift plus Mouse 4/5, that's a real accessibility gap.
- **The pad is context-sensitive (S2).** B is slide, dodge or guard depending on speed and lock. RT is
  bolt or staff strike depending on distance. Players can't predict what a button will do.
- **Camera (S3).** The default FOV is 54°, narrow for a third-person game with threats all around. The
  960-line internal cap plus AA off by default leaves grass, beards and fences shimmering on a Retina
  display.
- **The first 15 seconds (S2).** A 6.6 s loading screen, then all at once: the controls card (4 lines
  of keys), title card and region banner overlapping (B2), narration subtitles, an objective, compass,
  minimap, a full hotbar and a filling Gloom bar. Stage it: title, then one line of narration, then
  movement, then the first fire teaches Gloom, then the first spell.

---

## 4. World and level design

- **Diorama, not a valley (S2).** From above (`flora_r34_overview_after.png`,
  `r34_layout/layout_overview_south.png`) the Realm is a flat tabletop inside a heightfield rim. The
  north "Crowns" is one straight cliff wall. The south expansion is a grid of rectangular fields
  divided by straight orthogonal roads, which reads like farm plots.
- **Regions are rooms (S2).** There are 19 named regions in 100,750 m², and several are only r 18–22 m
  (Hearthward r 34, Glade r 18, Holds r 18). A banner announces a "region" every 20 seconds of
  walking.
- **The hero landmark has no silhouette (S2).** The Stair and summit back onto the north wall, so
  nothing rises against the sky. A white light beam marks the goal instead. The vortex sky does the
  dramatic work the mountain should.
- **Wayfinding by UI, not by world (S3).** The compass with distances, minimap, quest pins, beam,
  lanterns and region plates are redundant aids for a space you can cross in a minute. That's a sign
  the world isn't legible on its own.
- **Kit scale and placement (S3).** Ossuary bricks are oversized next to candles and doors
  (`spot_critF_osspit.png`), and grass grows on near-vertical rock. Ruin blocks are smooth, bevelled
  and light blue, so they read as toy blocks (`enemies_r34_0_pilgrim.png`).
- **Credit:** the spawn faces the Stair and the vortex. It's a strong first view.

---

## 5. UI and UX

- **No text arbiter (S2).** These all draw independently: toasts, the lesson/tip line, narration
  subtitles, boss emotes, floating combat text ("+14 GLOOM", "DRIVEN BACK 2/3"), discovery banners,
  quest banners, the region plate with tier, encounter HUD, nameplates and unit frames. Overlaps seen:
  title vs banner (B2), hint vs combat text (`raid_henge_p2_maze.png`), compass vs compass (B3), and
  minimap vs minimap. Build one queue with priorities, lanes and a "the screen is busy" rule.
- **HUD density (S2).** The fight frame shows a portrait with Gloom, status icons, Kill Chain, the
  controls card, compass, quest tracker, region plate, minimap, hotbar with names, boss bar with phase
  and %, target frame with cast bar and debuffs, nameplates, combat text and subtitles. The centre of
  the screen, where the fight is, is often the most covered part.
- **Typography (S2).** Cinzel all-caps at 12–17 pt on a 1920 canvas comes out at about 8–11 px at
  1280×720. Long all-caps objectives wrap to two lines ("…FROM THE THORNWARDEN IN / THE RING").
  Cinzel is a title face. Use it for titles and the body face for anything you read twice.
- **No UI root (S2, tech).** About 20 scripts create CanvasLayers. Seven menus share layers 59–62, and
  each manages pause itself ("someone else unpaused the world" in `gear_panel.gd:285`). Menus need one
  owner: a stack, focus, pause and HUD-hiding in one place.
- **Panels.** Each menu has its own frame and key-hint style. The quest-offer modal is two-thirds
  empty, and the Journal opens empty (B14).
- **Settings coverage.** Good: render scale, AA, fps cap, FOV, invert, sensitivities, four audio buses
  and HUD toggles. Missing: **rebinding, Quit**, subtitle size and background, HUD and text scale,
  colour-blind support (the tells are red, the bars orange and the AoE rings green), camera-shake and
  hitstop toggles, and difficulty or assist options.
- **No main menu (S2).** The game boots straight into the world with one save, with no Continue, New
  Game or Quit. "Erase Saved Progress" sits next to graphics options (and see B10).

---

## 6. Art and presentation

- **The wanderer is the best asset.** A hood, void face, staff with an orb and a lantern make a clear
  silhouette at any distance. The robe's identity has wobbled, though: blue crack-lines in r33
  (`look_sheet_ensA_after.png`), orange ember cracks now. The orange makes it read as a lava golem.
  Pick one and lock it.
- **Four styles in one frame (S2).** Dense realistic grass cards, painterly tiled terrain and cobbles,
  primitive blocky architecture with big bevels, and procedural clay-and-doll characters. Enshrouded
  works because every asset class shares one stylisation level. Here each was tuned in a different
  round.
- **Characters (S2).** NPC faces are doll-like. The Keep under hearth light turns uniformly orange,
  and the beards are stacks of aliased strands (`critC_npc_keep_final.png`). Villagers stand stiff,
  and two can occupy the same space (B11).
- **Enemies (S2).** Fidelity varies wildly across the roster (§2.3). Bosses were "sculpted", but the
  materials read as clay rather than bone, stone or cloth.
- **Lighting and grade.** Credit: the r21 deep-blue night holds across the whole map. Problems:
  everything in shadow collapses toward one blue value, so regions lose identity. Warm emissives clip
  to white blobs. The village brazier's flame is a white rectangle (`critC_npc_nan_final_mid.png`),
  and the Founder's Pits floor is covered in blown-out white patches (`flora_r34_foundry_after.png`).
  Lava veins on the hillsides read as neon squiggles, not geology.
- **Sky.** The violet vortex is the signature image, so keep it. The meteor and falling-star streaks
  are numerous enough to read as noise in stills.
- **Image quality (S3).** AA off is your stated preference ("the crisp look"), and the 960p cap is a
  binding rule and a defensible perf choice. Together on a 3024×1964 Retina they cost a lot of stability: grass, beards
  and fences crawl in motion. Worth an A/B with TAA or FSR on Cinematic only, leaving the default
  alone.

---

## 7. Audio

- **Everything is synthesised (S2).** About 55 generated WAVs plus runtime synths: a generative lyre,
  pads and bell in D-minor pentatonic, and Sims-style babble for NPC voices. It's clever engineering,
  but:
  - **No composed themes.** All three bosses and the finale get the same "danger" state (dark pad plus
    heartbeat). A final boss with no theme of its own is a missed beat.
  - **The babble undercuts the tone (S2).** The writing is grim, terse and adult, and the voices are
    The Sims. Use breaths, murmurs and single words, or silence with typing clicks.
  - The ending bell is the synth bell pitched down two octaves (`story.gd:416`). It's the game's one
    big sound moment, and it deserves a real recorded or properly designed bell.
- Credit: the mix work from r29 (buses, levels, the music finally audible) is solid.

---

## 8. Story and writing

- **The strongest discipline in the project.** House style is terse, concrete and dark. "Questions
  are free. Beds cost ash." "Fire stays. Hollows do not." The three-line opening and three-line
  ending are well restrained.
- **Mechanics leak into flavour slots (S3).** The Thorn Heart's description: "Changes Rift Bolt:
  Splinter or Briar. Also a seal shard: the summit ward counts it." Split rules text from lore text
  visually, or move it to the tooltip.
- **Proper-noun density (S3).** Edda, Osric, Aurel, Ostrin, Oswin, Hesk, Brannoc, Pell, Nan, Maud,
  Lisle, Hobb, Corvin, Wenna, Fennick, Ruan, Cadoc, Agathe, Linnet, Elspeth, Ysolt, Jory, plus the
  Rooted, the Order, the Ninth Company, the Kindlers and the Founder. That's a lot for a game of a
  couple of hours. Make sure the three bosses' stories land before anything else asks for memory.
- **The story didn't grow with the world (S2).** See §2.6.

---

## 9. Technical

- **What's good.** Atomic saves with `.tmp`, `.bak` and versioning. `SessionState` reset discipline,
  a static-var lint, GenCache, the worker-thread travel load, pooled bolts and FX, and a real headless
  gate with an isolated HOME.
- **God files (S2).** `player.gd` 3,203 lines (movement, 18 verbs, camera, lock-on, Gloom, interact,
  casting, autopilot); `character_rig.gd` 2,336; `enemy.gd` 2,168; 17 files over 1,000 lines. Split
  the player into Locomotion, Traversal, Camera, Targeting and Gloom components.
- **Rules vs reality (S2).** ARCHITECTURE says to reach other features through typed refs. The code
  has 605 `.call("name")`, 234 `has_method` and 54 `.get("_private")` reads (for example
  `Player.boss_fight_active` reads every arena's `_active`). Renames fail silently, and the type
  checker can't help.
- **Global state.** 366 `static var`. The lint keeps them safe, but that's a lot of hidden coupling.
- **Comments as changelog (S3).** 819 `rNN` tags, plus lines like "(was 3.6; 1.8× slower)". They tell
  the history, not the intent. Git has the history.
- **Debug in shipping (S3).** 145 `print()` calls, 35 harness flags parsed by shipping code
  (`--demo`, `--test-shade`, `--walk-rec`…), and the F8/F9 bindings (B13).
- **Tests.** 43 scenes. This run: see "Test run" below. The suite is slow (several tests rebuild the
  whole Realm, a few minutes each at 4 jobs). A cached prebuilt world for tests would cut it a lot.
- **Performance is unmeasured since the doubling (S2).** `docs/perf_baseline.md` is from 2 Nov on the
  old baked stair: 769 draws and 113 fps 1%-low at the sanctuary. The Realm has since doubled, and
  three raid rooms and seven regions of flora and wildlife were added. Re-baseline before anything
  else lands.
- **Shipping (S2).** The owner plays a Mac `.app` that loads a **Linux** `.pck` copied into
  `~/Downloads/…/Contents/Resources`. It's a binding rule (`.cursor/rules/umbral-constraints.mdc`),
  so it's deliberate, but it's still fragile. The bundle is hand-maintained, nobody else can rebuild
  it from the repo, and it skips the macOS preset that exists in `export_presets.cfg`. Write down why
  the Linux route won and make it a script. The README points at `build/windows/UmbralReaches.exe`
  and `build/linux/…`, which don't exist (only `build/macos/Umbral Reaches.pck`).
- **Repo hygiene (S3).** `.git` is 589 MB as 4,288 loose objects with zero packs (`git gc` has never
  run). `shots/` is 9.2 GB on disk, ignored but growing. Stray `base.log`, `noshadow.log`,
  `nossao.log` and `nossr.log` sit at the root.
- **Docs drift (S2).** The README's "Known limits" (no audio, no combat, loot or saves; primitive
  placeholders) and its controls list ("E kindle", no skills) describe v0.1. ARCHITECTURE says
  "verified r30", and AGENTS.md says "Crimson Vale removed — next night TBD". An agent or a new
  reader starts from wrong facts.

---

## 10. Keep these (don't cut in the consolidation)

The light-vs-dark clock. The deep-blue night with protected warm lights. The vortex sky. The
wanderer's silhouette. The Keep's voice and the opening and ending narration. Discovery-banner
subtitles. The save robustness. The headless test gate. The exponential movement feel. The Rift
Step. The *ideas* in the three boss rooms (bramble maze, shrinking briars, the gale and pylons).

---

## 11. Suggested order

1. **Fix the bugs:** B1 (one input table, no feature binds its own keys), B2 and B3 (text arbiter),
   B4, B8 (camera occluder fade), B13.
2. **Front door:** title screen, Continue, New Game, Quit, Settings, and save slots.
3. **Re-baseline performance** on the doubled Realm at the owner's settings.
4. **Consolidate the systems:** one bar per rule (§2.1). Cut rested XP and item level, or fold them
   into Kindling. Merge Satchel, Gear, Kindling and Journal into one character screen. Stage the
   spells and unlock the hotbar over the first hour.
5. **Solo-ise the bosses:** drop leash heal-to-full and soft enrages, replace the text instructions
   with world tells, and give the Warden scale.
6. **One art pass per asset class:** characters first (NPC faces and beards, the enemy roster's
   materials), then architecture kit scale, then warm-emissive clipping.
7. **Audio identity:** a boss theme for each of the three, a real final bell, and NPC vocalisations
   that fit the tone.
8. **Refresh the docs:** README, ARCHITECTURE, AGENTS.md. Pack the repo and clear the root logs.

---

## Decisions (Luke, 5 Nov 2026)

- **Gloom: split.** Gloom becomes only the dark's clock. Enemy blows go to a separate short Wounds
  bar that a fire heals. One rule per bar.
- **Progression:** (rested XP stays: Luke reversed the cut later the same day.) Merge Satchel, Gear, Kindling and Journal into one character
  screen. Stage the spells: start with Rift Bolt and unlock the other four over the first hour.
  Item level and gear sets **stay**.
- **Bosses, for a solo player:** no heal-to-full leash (enemies that lose you walk home and keep
  their damage, and bosses never reset mid-fight). Drop the soft enrages. Replace emote and hint
  text with world cues (sound, particles, arena light), at most one short line. Give the Ascended
  Warden scale.
- **Art and audio, all four:** a characters pass (NPC faces and beards, the enemy roster and boss
  materials toward one look), replace the Sims babble, a composed theme for each boss plus a real
  final bell, and reshape the world (break up the grid south half and the straight north wall, and
  give the summit a skyline).

### Decisions, round two (Luke, 5 Nov 2026)

- **Character screen:** four tabs under one key. Wanderer (gear, charms, relics), Kindling
  (embers, spells, oaths, paths), Pack (materials, trophies) and Journal (writings, places, map,
  tasks).
- **Spells:** start with Rift Bolt. The other four are taught through the story (the Keep and key
  moments such as the first fight, first seal and first boss).
- **First-hit line:** keep "They wound. A fire closes what they open."
- **Music:** synthesised boss themes and the final bell, composed in the existing procedural synth.

### Implemented so far (r35)

- **Gloom split.** `Player.wounds` / `wounds_max` (120, about five plain strikes) /
  `wounds_mend_lit` (14/s in a fire, scaled by the same `lit_mult` as the Gloom drain).
  - Every blow from the world goes through `Player.take_wound()` (renamed from
    `add_gloom_from_enemy`): foes, bosses, their hazards, spit orbs and the briars. Falls, lava
    and the crypt push-back use `add_wounds()`. At `wounds_max` you are hollowed.
  - The 3-hit overcap death is gone. Gloom is only the dark's clock: it gathers away from light and
    as spell cost, a fire drains it, and at full a Shade hunts you.
  - Kills, spent Resonance, Nova motes and the Door now `mend()` Wounds, and their item, Path and
    oath texts say so.
  - The player frame's top bar shows what the Wounds leave (red), with the slim Gloom bar under
    it. The "Hollowing 1/3" indicators are removed.
  - `Events.wounds_changed` was added, and Wounds carry across scene travel.
- **Leashing.** A foe that loses you walks home (it ran there at 1.8× before), keeps its damage,
  and a blow on the way turns it back. It was immune and healed to full.
- **Bosses never reset mid-fight.** Walking or falling out of an arena now *holds* the fight
  (`BossArena._hold_fight`): the boss, its adds and the room are frozen as they stand, the gates
  open, the bar hides and Gloom gathers again. Walking back in resumes the same fight. Only being
  hollowed resets it.
- **No soft enrages.** `BossKit.enrage_tick`, the `ENRAGE_AT` constants, `fight_t`, the
  "ENRAGED" bar label and `enrage_left` are removed. The half-health "enrages" of guardians and the
  Brood-Mother are phase changes and stay.
- **World cues, not text.** Every boss emote is one short statement with no instruction ("The
  door behind him opens a crack."). The eight mechanic `Hints.once` explanations are removed.
  The Thornstorm and the Gale now light the lee of each shelter (`BossKit.lee_marks`: a pool of
  light, rings and a column behind each standing stone or lit pylon). The other mechanics already
  marked their safe ground: the Abbot's pale mound shadow, gold plates, pylon rings, the briar
  ring, glowing heart-knots, and the Mandorla's column.
- **The Ascended Warden's scale** is 3× → 5× (about 9 m), his halo light is wider, and he rises
  15 m when ascending.

### Implemented: character screen and story-taught spells (r35)

- **One character screen** (`ui/character_screen.gd`). Tab / I / d-pad up opens it, with four tabs
  and their pages: Wanderer (Gear, Charms, Relics, Staff), Kindling (Embers, Spells, Loadout, Oaths,
  Paths, Hearth), Pack (trophies and materials) and Journal (Wenna's Journal, Stories, Writings,
  Places, Map, Relic lore, Tasks).
  - 1–4 or LT/RT change tabs, Q/E or LB/RB change pages, and Tab / Esc / B close it. O, K, J and L
    jump straight to Gear, Kindling, Journal and Tasks.
  - Each page is one of the old panels opened "hosted": its own tab strip and header links are
    hidden, and the screen owns the pause, the mouse and the keys. A dim backdrop sits under every
    page.
  - The old panels route their own `open` calls to the screen, so a fire's Kindling opens Kindling
    → Embers and the Satchel's attune opens Wanderer → Relics.
  - Checked by `zz/char_screen_test` (26 checks). Renders: `zz/char_screen_shots`.
- **Spells are taught by the story.** A new game starts with Rift Bolt, and slots 1–4 are sealed
  (empty, cast nothing). The Keep's first talk teaches Lantern Ward, the first kill Ember Lance, the
  first seal Rift Step, and the first great one Umbral Nova. Each is announced once with its key,
  e.g. "The first of them falls, and the staff drinks its ember. Ember Lance: RMB / R."
  - Saves from before staging, and the `zz/` harnesses, keep all five. A test can opt in with
    Engine meta `staged_spells`.
  - The Kindling refuses ranks for untaught spells and shows them as "Not yet taught".
  - Checked by `zz/spell_staging_test` (13 checks).

### Implemented: boss themes and the great bell (r35)

- `core/life/wildlife/boss_themes.gd` composes a theme for each great one, synthesised like the
  rest of the music. Each has two stems that loop in step: BASE from the pull, and HIGH, which rises
  with the boss's phase and is full in its last.
  - **Thornwarden:** D dorian, 6/8, 88 bpm. A frame drum and rim, a reed drone on D–A, and a plucked
    ostinato on Dm / C / Bb / C. HIGH adds a bowed fiddle line and a doubled drum.
  - **Bone Abbot:** D phrygian, 4/4, 56 bpm. Organ on Dm / Eb / Bb–A, a low choir, a toll on every
    downbeat and a bone tick on every beat ("he counts"). HIGH adds the chant and timpani.
  - **Ascended Warden:** D lydian, 3/4, 72 bpm. A high choir on D / E / D / C#m, bell arpeggios
    rising through each bar and a sub drone. HIGH adds timpani and a falling brass line ("the sky
    falls").
  - Rendered on a worker thread on the first pull (0.2–1.3 s a stem) and cached by GenCache.
    ScapeMusic's danger pad and heartbeat step aside while a theme plays. The theme fades when the
    boss falls, the fight is held, or you walk away.
- **The ending's bell** is a tower bell built from its partials: hum, prime, minor-third tierce,
  quint, nominal and above on A2. The hum swells in after the strike ("from the bottom up") and it
  rings for about 24 s. It replaces the small bell pitched two octaves down.
- Checked by `zz/boss_theme_test` (lengths, body, loop seams, stems in step, the bell's length and
  strike; `--dump=<dir>` writes WAVs) and three new checks in `zz/raids_r34_test`. The music has not
  been listened to by a person yet.

### Tried and reverted: NPC voices without babble (r35)

**Reverted at Luke's call after playing it:** the one-gesture-a-line voices were "too quick and
uninvolved". The syllable babble is back (commit def0887 undone). What follows is what was tried.


- Speech is **one human sound a line**, then the text types in silence. A breath, a "hm" (rising
  on a question), a sigh on "...", a grunt on "!" and on short dry lines, a dry "heh" on a
  laugh-line, and a greeting "hah" on a speaker's first line.
  - Built by `npc_voice.gd` (`gesture_for`, `gestures_of`, `gesture`) on the same glottal source
    and formants as before, so each family keeps its pitch, size, breath and rasp (a dwarf grunts
    lower than a child).
  - The dialogue box and the shop play one gesture as a line starts. Ambient talk (villagers, the
    Keg's dwarves, the bartender) is an occasional low murmur, at most one per speaker every 3.5 s.
  - Laughter and the Keg's sung tunes keep their syllables, since they are laughter and music, not
    speech.
  - Gestures are prewarmed with the voice banks behind the loading screen and cached on disk.
- Checked by `zz/npc_gesture_test` (all 8 families × 7 gestures, the picker on the game's own lines,
  determinism, family pitch; `--dump=<dir>` writes WAVs). Not yet heard by a person.

### Implemented: character pass and world reshape (r35)

- **Characters:** one shared finish (`core/vfx/char_look.gdshaderinc`) in all four character
  shaders (dwarves and villagers, procedural enemies, modelled enemies, bosses). It adds painted
  cavity from the baked occlusion, albedo and roughness breakup, and one warm back-rim for everyone.
  Bosses take more cavity and breakup, against the clay look.
  - NPC skin: its warm self-glow dropped from 0.12 to 0.05 and its translucency is less orange.
  - NPC hair detail is coarser and shallower, so it no longer crawls at 960p.
  - Quest marks: one per person (the Keep wore two), smaller and higher, and hidden within 3.5 m
    so they never sit over a face.
  - `zz/combat_studio` knows the r34 kinds and skips unknown names instead of hanging.
  - **Honest scale:** the shader pass is a modest improvement (more depth, less flat tone). A real
    jump for the characters needs asset work: re-sculpted and re-baked bosses, rebuilt procedural
    faces.
- **World:**
  - The Crowns' straight cliff now recesses north 0–12 m (never south of z −110, so nothing in the
    valley moved), its crest varies from about 32 to 56 m, and three peaks stand beyond the edge,
    the tallest behind the summit.
  - The southern tracks and lanes meander between their unchanged vertices (`RealmLayout.PATHS` is
    now derived from `BASE_PATHS`). The main road keeps its line: its waystones and cart are placed
    beside it, and the meander pushed two of them off.
  - Rectangular regions' biome edges and the mere, Waiting Field and orchard shapes are warped.
    Region names, places and tiers keep their exact rectangles.
  - The Waiting Field's grass was raised 1.15 → 1.42, because it sat on the floor of its density
    band against heath.
  - The topology is unchanged: the road network is still a cross of roads, which is now visible
    but softer.
  - The shipped `art/realm_cache` is unaffected (flora and land are not cached).

## Test run (this critique)

`tools/run_tests.sh`, 4 jobs, isolated HOME.

- **After the character pass and world reshape:** 45 of 47 in the full run. `lore_codex_test` lost two
  roadside lore pieces to the road meander; the main road was then kept straight and it passes.
  `world_react_test` is the flaky fox test (it timed out).
- **After the bug fixes and the Wounds, leash, boss and enrage changes:** 41 of 43 pass.
  `world_react_test` is the fox pounce below (unchanged). `village_test` failed once under load
  ("every villager on the floor (77 off)") and passed twice alone (0 off), so it's flaky, not a
  regression.
- **Before the fixes (41fd7ad):** 2 of 43 failed. `enemies_r33_test` ("its packmate resets with it",
  B4) and `world_react_test` ("and leaps on it (pounces 0, catches 0)": the fox's pounce in the
  wildlife reactions; not investigated, possibly timing under 4 parallel jobs).
