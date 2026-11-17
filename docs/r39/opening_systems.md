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
