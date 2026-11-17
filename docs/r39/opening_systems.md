# Opening, progression and systems: what was built

Branch `r39-opening`. Nothing here was run in the engine (the lead runs Godot); everything was written against the code as read and `tools/lint.sh` passes. Each feature is new play, with its own files; edits to shared files are one-line hooks.

## 1. The Last Lantern (opening shot)
A new game no longer drops the player on the green with a control card. After the title card the camera is taken: black bars slide in, the lens stands on the green and looks at the empty dark, rises up the Order's chain to the turning sky (0-17 s), comes down into the village and circles the wanderer at the fire (17-33 s), and settles on the follow camera's own pose and is handed back without a cut (33-46 s). The three narration lines are spoken at the beats (1 s, 9 s, 33 s). Line 1 is corrected: it no longer says there is no village past Hearthward.
- Reach it: New Game (a save with no `arrived` flag). Skip: hold the interact key 0.8 s after the first 1.5 s (a "Hold [E] to skip" hint appears); skipping speaks the last line and gives the HUD. Off: Settings > Interface > "Opening Shot". Plays once (story flag `opening_seen`); never for Continue.
- Files: `core/story/opening_shot.gd` (new), `core/story/story.gd` (`_play_opening`, called in `_stage_opening`), `core/story/dialogue_db.gd` (OPENING line 1), `ui/hud_prefs.gd`, `ui/settings_menu.gd`.
- No mesh, material or light is made; the shot uses its own `Camera3D` (like the loading tour) and freezes the player (`process_mode`) until it ends.
- Check: the lens never ends inside a wall (rays pull it clear); the hand-off to the follow camera has no jump (pose equals `_home` for the last 0.4 s); the HUD appears only after; skip works at any time after 1.5 s; the opening test (`zz/opening_test`) still takes the old path because its stand-in player has no camera.

## 2. Danger made legible
The minimap's plate no longer prints "Dusk / Night / Deep Night" (danger-tier names that read as a clock). It prints Haven, Gentle, Even, Perilous or Deadly with the level of a pawn there (`Even · Lv 9`), tinted green to red, set against the wanderer's Remembrance. Bosses show "Suggested level N (you are M)" on the map's tooltip and on the guide's "Next" banner for the seals and keepers. Entering a country whose pawns are 5+ levels above the wanderer says so once, in a toast, per country (saved: story `danger_warned`).
- Files: `core/life/encounters/danger.gd`, `danger_watch.gd` (new); `ui/minimap.gd`, `ui/world_map.gd`, `core/story/guide.gd`, `core/story/story.gd` (adds the watch).
- Check: plate text and colours at Hearthward (Haven), the Thornwood, the Marches, the far corners; the warning fires once and not at Hearthward; enemy name plates still print the old tier names (`ui/unit_frames.gd:610`), a follow-up.

## 3. The Ember Road from the map
Fast travel existed only at the iron post beside a lit fire and was taught nowhere. Now: beside a lit fire, open the world map and every other lit fire answers a click (or pad confirm); the tooltip says "Click to ride the Ember Road here, from X". Away from a fire it says to stand beside one. Same rules as the road (never in a boss fight or with a foe awake near, never mid-camp). Taught by the first-hour lesson when two fires burn (feature 8).
- Files: `ui/world_map_travel.gd` (new), `ui/world_map.gd` (hooks).

## 4. Map pins that fold
Crowded pins of one kind (six task marks at Hearthward, a ridge of lamps) become one pin with a count badge at the whole-map zoom and come apart when zoomed in; the wanderer, bosses and the followed task are never folded; hover finds the pin shown. Hitching posts are now pins (the horse glyph), always known.
- Files: `ui/world_map_cluster.gd` (new), `ui/world_map.gd`. The label placer (`world_map_labels.gd`) already avoids marks and other names; it was not changed.
- Check: whole-map zoom at Hearthward; zooming in separates the pins; `world_map.gd` is 1000 lines (the lint's ceiling).

## 5. Make camp
A "Make camp" seat stands by every lit fire (`CampSpot`, laid by the Kindling runtime beside the fire's own spot, 1.9 m east, 1.5 m north of the fire). Use it: the wanderer sits, the HUD steps back, the lens circles the fire under black bars for 11 s, three lines are said (what the fire does; what the Count stands at and the last name counted; where the night's road leads next, from the story's own objective), and at the end the wanderer is whole (Gloom gone, Wounds mended), the fire remembers her (checkpoint), the game is saved, and "Rested. Press [E] to read the Count" appears.
- Breaks: any blow or a foe waking nearby ends the camp with no rest; the interact key after 1 s finishes it at once with the rest granted; the fire going out ends it. Refused: on a horse, in a boss's fight, with a foe awake close, on the Ember Road.
- Rested XP is untouched (still earned at home).
- Files: `core/world/camp_spot.gd`, `core/world/camp_rite.gd` (class `CampRite`), `core/life/progression/kindling.gd` (lays the seat).
- Check: the seat's prompt appears at lit fires only, not at the fire's own "Rest" prompt's spot; the camera ray keeps the lens out of walls; the player is restored (process, camera, HUD) on every exit; pausing mid-camp pauses it.

## 6. The Count (P)
Every hollowed thing put down is counted by kind and given a pilgrim's name (a stable function of its number, the way the Bearers count the dead; titles and names drawn from the valley's own). The Count page lists foes by kind, the great ones fallen, camps made, times hollowed, places found, bells answered of eight, fires burning, lamps lit, how each country regards the wanderer (known / friend / kin), and the latest five names. It pauses the night like the map.
- Reach it: **B** (rebindable, "The Count"), or the interact key within six seconds after a camp (how a pad reads it).
- Files: `core/story/tally.gd`, `ui/tally_panel.gd` (new), `autoload/input_setup.gd` (action `tally`), both added by the story director. Saved in `Travel.story["tally"]`.
- Check: counts rise as foes die; names are the same after a reload; the panel opens and closes with B/Esc, and releases the mouse state; at the cap of the list it says "and N more".

## 7. The night's days (dailies)
A daily used to return every ten minutes of the village clock, and the count was not saved. A day is now a saved night: `Travel.story["night_no"]` advances when the wanderer makes camp after at least 600 s of play since the last (`night_age`, ticked by `core/story/days.gd`). `QuestBook.today()` reads it. A camp that turns the night says so ("The ledger's daily work is open again").
- Files: `core/story/days.gd` (new), `core/story/quest_book.gd` (`today`).
- Check: a daily handed in stays closed across a relaunch until a camp after 10+ min; the village cart's restock (`Village.nights`) is unchanged.

## 8. The first hour, taught in play
Six one-time lessons, each waiting for its moment, in the lesson lane: the first fire (what a fire does; the camp seat), the first Gloom (30% of the bar), two fires lit and near one (the Ember Road and the map), within 10 m of a hitching post (horses), 160 m from home with 40 ash and no horse (a horse would carry this road), six foes counted (the Count), and both keepers down (the bells: eight hang, answer four).
- Files: `core/story/first_hour.gd` (new, added by the story director). Quiet during the opening, a camp, a hunt or a boss.

## 9. Immersion mode
Settings > Interface > "HUD Rests While Exploring" (off by default). While the night is quiet for 7 s (no foe awake near, no boss, no lock, nothing cast or struck, Gloom and Wounds under 35%, no menu) the wanderer's frame, the hotbar, the XP strip and the minimap fade; the compass dims to a third; the objective, waypoint and prompts stay. A blow, a cast, a lock or a low bar brings them back in 0.25 s.
- Files: `ui/hud_rest.gd` (new), `ui/hud.gd` (the gauges now sit under one wrapper `Gauges` so they fade together), `ui/hud_prefs.gd`, `ui/settings_menu.gd`.
- Check: the Hotbar, Minimap, XpBar and UnitFrames still lay out under the wrapper (they are full-rect anchored); the hotbar's slot teaching still shows.

## 10. The Outliers (the Far Reaches in the night's standing)
The Far Reaches' thirteen tasks now count: a fifth country, "the Outliers", with standing from tasks done in the eleven Reach regions and their towns, a gift at friend (ember shards, relic fragments, grave iron), and at kin quieter camps and sturdier watchmen there (the same effects as the other countries). Shown in the Count.
- Files: `core/world/night/reach_state.gd` (FACTIONS), `ui/tally_panel.gd`.

## 11. Horses worth riding
Trot is now faster than the sprint and the gallop half again as fast (palfrey 8/14, garron 7.6/12.5, draught 7/11.5, fen pony 7.8/13, cob 7.8/13.2 m/s; sprint is 7.5). The buy prompt states it. Hitching posts are pins on the world map; the post lesson (8) says what a horse is.
- Files: `core/world/mount/horse_db.gd`, `horse.gd`, `stables.gd`.
- Check: the gait blend still reads (thresholds are the breed's own); jumps over a plain horse at gallop; the camera at 14 m/s.

## 12. The peal counts
The peal objective now reads "(n/4)" (bells answered, capped at four) on the HUD.

## Second round (after the merge of the first)

### 13. Horses know you (bond, names, waiting)
Each horse you buy is named (kept in the save), and every metre ridden grows a bond: Strange, Known (2 km), Trusted (6 km), Bonded (15 km). Each level is +4% speed at every gait and a line from the horse's side when it is crossed ("Brindle answers the whistle from further off..."). The ride prompt names it ("Ride Brindle (Pilgrim's Palfrey, Trusted)"), the whistle says "Hooves in the dark. Brindle comes.", and the Count lists "Brindle, your horse: Trusted, 7 km". A horse you got down from waits where you left it, across a reload (the save keeps the spot and heading), and the map's "Your horse" pin follows.
- Files: `core/world/mount/horse_bond.gd` (new), `horse.gd`, `stables.gd`, `ui/tally_panel.gd`. Saved in `Travel.system_state("stable")` keys `bond`, `names`, `left`.
- Check: bond metres accumulate only while ridden; the speed multiplier does not break the gait blend; the 15 km bonus is +12%; a reload puts the horse back where you dismounted, on the ground (not in a wall), and `[H]` still brings it.

### 14. The Chronicle
The run is written down as it happens, with the night it fell on: the arrival, each seal, each great one, each country first walked, each fifth level, bells answered, horses bought, the first Ember Road ride, falls into the dark (the first and every fifth), nights turned at camp, and the first photograph. It is the Count's second page (**B**, then **Q/E** or the arrows) showing the newest sixteen. The title screen's slot list quotes each save's last line under its summary, so a returning player is told where they stopped.
- Files: `core/story/chronicle.gd` (new), `ui/tally_panel.gd`, `autoload/travel.gd` (`slot_summary` returns `last`), `ui/title_screen.gd`. Saved in `Travel.story["chronicle"]` (newest 240) and `chronicle_keys` (so a line is written once).
- Check: the slot button's second line renders (a multi-line Button); an old save has no chronicle (it starts one at the next load with the arrival line); entries are not duplicated after a reload.

### 15. The wanderer's trail and her own marks (map)
The world map now draws where she has walked as a dotted charcoal line (a point every 9 m, the newest 2,600, broken where she was carried by the Ember Road or a fall) and lets her set up to twelve marks by hand: right-click bare parchment (Y on a pad, at the reticle) to set one, the same on a mark to lift it. A mark stands in the world as a beacon: it shows on the compass and the minimap, so it is something to walk to. Marks are listed with a medallion and fold with the other pins. The map's controls line says so.
- Files: `core/story/wayfarer.gd` (class `Wayfarer`), `ui/world_map.gd` (hooks), `ui/world_map_util.gd` (helpers moved out to keep `world_map.gd` under the 1000-line ceiling). Saved in `Travel.story["trail"]` and `["pins"]`.
- Check: the trail follows real walking and does not draw a line across a fast-travel jump; marks survive a reload (the nodes are rebuilt in `Wayfarer._ready`); the compass shows them; right-clicking a world mark does nothing; a thirteenth mark says so.

### 16. Photo mode (F12)
The night holds still and the lens is yours: a free camera from where the wanderer's was, flying within 45 m of her (WASD, mouse look, Space and Ctrl for up and down, Shift fast, wheel for field of view, T for black bars). Enter or a click keeps the view as a PNG in the save folder's `photos/` (HUD and controls hidden for the frame; a flash and a sound answer; the file is named for the region and night). P or Esc gives the night back exactly as it was. Refused in the opening shot, a camp, a boss's fight, hollowing, loading, and under another menu. Every picture is counted (`tally.photos`), the first is chronicled, and a lesson offers it after the first foes and a first country.
- Files: `core/story/photo_mode.gd` (class `PhotoMode`), `autoload/input_setup.gd` (action `photo`, rebindable), `core/story/first_hour.gd`. Keyboard and mouse only (a pad cannot reach it).
- Check: pausing and restoring (tree pause, mouse mode, HUD, the follow camera current again); the lens stops at walls and the ground; the saved image has no HUD; `P` is not bound elsewhere; Esc leaves photo mode and does not also open Settings.

### 17. The Ember Road names the danger
Each destination in the fire menu now ends with its plate ("Perilous · Lv 14"), so a fast travel into ground above the wanderer's level is a choice made with the number in view.

## Third round (the long round; brief: docs/r39/briefs/opening_systems_ux.md)

Cost statement for everything below: nothing runs per frame. Signals, 0.5 to 3 s polls, and panels that are built hidden at the start and filled only when opened. The horse's `_physics_process` is switched off except while a whistle runs. `Days` writes its playtime once a second. The map's trail and folding draw only while the map is open.

### 18. The opening, finished
After the title card the shot now has: the game's name over the dark (shot 2 to 7 s, "THE SECOND NIGHT" on a repeat), a low bell stroke under the black (`BellVoice`), the narration at 1, 9 and 33 s, the story seat's drain beat started with the second line so the green's people go indoors while the lens circles it, and a lantern chime (a rising fifth and octave) at the hand-off. A New Game after an ending (the profile, `core/util/profile.gd`, counts endings in `profile.cfg`, shared by every save) opens as the second night: a 1.5x faster shot and `DialogueDB.OPENING_AGAIN`. The keep's door lesson ("the keep is behind the bar") fires within 7 m of the Keg before the keep has been met. The bells lesson follows the one-bell canon.
- Files: `opening_shot.gd`, `story.gd` (`_play_opening`), `dialogue_db.gd` (OPENING_AGAIN), `core/util/profile.gd`, `first_hour.gd`.
- Reach: New Game. For the second night: set `endings=1` in `profile.cfg` under the save dir, or finish the ending. Check: skip at every beat (hold interact after 1.5 s); no lines repeat after the shot; the drain beat does not play twice.

### 19. The stable (horse care, tack, saddlebags, whistle, courier runs)
- **Whistle**: `[H]` now makes the horse run to you along the ground, probing round obstacles with rays (turns of 35 and 70 degrees), slowing in water, stopping 3 m off, giving up after 45 s or when stuck for 1.6 s (then it stands beside you as the old whistle did); beyond 320 m it comes beside you at once. Gallop speed uses the bond and care multipliers. Files: `horse.gd` (`call_to`, `_physics_process`), `stables.gd`.
- **Tend the stable**: every hitching post has a rail you can use ("[E] Tend the stable", `post_spot.gd`), which opens `ui/horse_panel.gd` with three pages (Q/E, LB/RB, or the tab buttons; d-pad and A on the buttons):
  - Care: bond, spirit (0 to 100; a worn horse is 8% slower, a fresh one learns you half again as fast), Feed (an ash-bloom, +45), Groom (free once a night, +20 and a little bond), and five pieces of tack: Iron shoes (+6% speed), Barding (tires half as fast), Saddle lantern (the Gloom gathers a third slower while riding, ticked by `Vows`/`Horse`), Larger and Deep saddlebags (+60, +120 capacity).
  - Saddlebags: five materials moved between the satchel and the bags (put 1, put all, take 1, take all); capacity 60 base; what is in the bags is safe from the ash mound on a fall.
  - Courier: ten roads between the five posts (`core/world/mount/courier.gd`): take a parcel, ride to the other post's rail, gold/silver/bronze/late limits from the distance, rewards in grave ash and ember shards, best times in `profile.cfg`, a timer line at the top, the destination as a compass beacon. Hollowing loses the parcel; the Ember Road is shut while one is carried; a reload resumes the run with its elapsed time.
- Saved: stable `bond`, `names`, `left`, `spirit`, `tack`, `groomed`, `bags`; story `courier`.
- Not built: the horse race at Hearthward; the saddle lantern's light is a Gloom effect only. Interacting from the saddle already worked (the interact key uses any target except the horse).
- Check: horse runs round a fence, a tree line, a hill; buy a horse, feed it, put grave ash in the bags and die: the ash is still there; take "The Tor Parcel" and deliver it; a second parcel is refused while one is carried.

### 20. Falling means something
The ash mound (existing) is now a beacon on the compass and the dial and a map pin ("Your embers", with its amount); the old heap lost on a second fall is counted (`embers_lost`) and announced. The return is a quiet 3 s with black bars and one of 40 lines (the first fall, a deep-ground fall, later falls), then the fire's toll: free for the first two falls, then a twelfth of the grave ash carried (2 to 40), logged in the Count (`tolls`) and the Chronicle. Ash in the saddlebags is not touched. Files: `core/story/ember_trace.gd`, `ui/world_map_travel.gd`.

### 21. Vows (progression choices)
At Remembrance 5, 10, 15, 20, 25 and 30 a panel offers three vows (18 in all; `core/life/progression/vows.gd`, `ui/vow_panel.gd`). Examples: Tithe of Embers (kills near a lit fire leave ash), Fireside Lore (a camp gives Rested), Horse-Lord, Light Step (no toll), Lantern-Bearer (slower Gloom while mounted or carrying a parcel), Kin of the Ember Road (the road sets you down clean and free), Keeper's Spoils (double memory after a great one falls), Night-Hardened, The Long Night's End (a night turns after 300 s). The panel opens by itself when safe and every two minutes until one is chosen; Esc or B defers; picking asks for confirmation ("Swear it"). Sworn vows are listed in the Count and the Chronicle. Saved in `story["vows"]`. The Paths tree is unchanged.
- Check: set a level 5 save; the panel appears when no foe is near; each vow's effect (see the table in `vows.gd`); `Courier`, `HorseBond`, `Days`, `FireRoad` and `EmberTrace` read `Vows.has(id)`.

### 22. The night summary and the credits
When a camp turns the night, a page lists the night's put-down, falls, countries, parcels, camps, level gained, the names counted, up to eight Chronicle lines of that night and a closing line. After the ending's card (and nine seconds), the credits read the whole Chronicle back, then the Count, then thirty counted names, then "Hearthward keeps its fire"; replayable from the Chronicle page. Files: `ui/night_panel.gd`, `story.gd`, `camp_rite.gd`, `tally_panel.gd`. Leave with interact, Esc or B.

### 23. The Ember Road, priced and shown
Every fire in the Ember Road menu and every lit fire on the map now shows its danger plate and its toll: a grave ash a sixty metres (1 to 15), never more than you carry; the Ember Road vow waives it. The Count's third page tracks the eight bells (where each hangs and what was done). Files: `fire_road.gd`, `world_map_travel.gd`, `tally_panel.gd`.

### 24. Comfort and accessibility
Settings > Interface > Comfort: Reduce Camera Shake (kicks and casts), Reduce Flashes (photo shutter now; other seats should multiply flash alpha by `Access.flash()`), Subtitles (Standard, High Contrast, Large) and Colour Palette (Original or Colour-Blind Safe: the danger scale and a `Access.telegraph(color)` helper the enemy/VFX seat should route telegraph colours through). Saved in `hud.cfg` (per player). Files: `ui/access.gd`, `hud_prefs.gd`, `settings_menu.gd`, `dialogue.gd`, `player_camera.gd`, `danger.gd`. Presets (performance/quality) already exist in Display; controller remapping parity was not changed.

### 25. Save robustness
`core/util/state_migrate.gd` runs on every slot load: it creates the keys added this round (`tally`, `chronicle`, `chronicle_keys`, `trail`, `pins`, `night_no`, `night_age`, `danger_warned`, `courier`, `vows`, and the `stable` keys) and repairs a damaged one (a number where a list belongs, an odd-length trail, negative counts, a chronicle line with no text) instead of failing later. A save from a newer build is left alone. The slot loader already falls back to the `.bak` and `.tmp` files.

## Data and content the lead should hand to the other agents (not edited here)
- Story: Brannoc's `far_work` is gated on `peal:4`; open a Reach errand or a word in Hearthward in Act I (barks in `guide_lines.gd`); give one bell a home in a Reach so the Outliers touch the peal; quest endings that send the wanderer to a stable ("a horse would help" tasks) and a line in villagers' talk about the Count and the camp.
- World: waystation hitching posts on the long roads (HorseDB has one post per breed; a second post for the same breed needs a data row); a seat prop for the camp (the interaction works without a model).
- Light: nothing new casts light; a warm vignette is a plain rectangle.
- Enemy plates still show tier names in `ui/unit_frames.gd:610`.

## What to test first (in this order)
1. Boot a new game: shot plays, skip works, HUD arrives, first objective and waypoint appear.
2. Walk to the Keg and back; light the meadow fire: the fire lesson; sit at the seat beside it.
3. Camp: rite plays, ends well, B opens the Count; a second camp within ten minutes does not turn the night.
4. World map: pins fold; beside a lit fire another fire answers a click.
5. Plate: colours and levels at Hearthward, the Thornwood, Lastlight; the warning toast once in a deadly country.
6. Settings: Opening Shot and HUD Rests toggles save to `hud.cfg`; immersion fades and returns.
7. Buy a horse, gallop; the post pin on the map.
