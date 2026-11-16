# The tracked task and its trail

Luke (16 Nov): "build a quest location system that works like destiny, where it places markers on pathways, here and
there based on the active quest to guide you to a location. Also create the ability to select an active quest to
display on your hud, that quest pops up the markers." And then: "its not a hud option, its what will be in place":
the tracked task and its trail are the game's one way of guiding, not a setting.

## What the games we looked at do

- **Destiny 1 and 2.** One quest is tracked from the quest screen (the Director's Quests tab; at one point up to
  three pursuits). The tracked quest's step is on the HUD and its objective wears a diamond waypoint with its distance
  in metres. The waypoint does not always sit on the goal: in a cave or a building it stands on the next point of
  the way and moves on as you reach it, so it leads you round walls rather than through them (players notice it
  "keeps moving forward to other positions as you progress through the area"). Players complained that tracking had
  to be set again after every step.
- **Fable II.** A gold breadcrumb trail on the ground to the next objective, updated as you wander; it thins when
  you go far off it, it rings the person you are looking for, and it can be turned off in the pause menu.
- **Dead Space.** A locator line called up on demand. It shows the path to the objective for a few seconds and
  fades, so the corridor stays dark the rest of the time.
- **Ghost of Tsushima.** The guiding wind: one vector from the hero toward the goal, shown in the world (wind, grass)
  instead of on a HUD.

Sources: [Steam: Destiny 2 waypoints](https://steamcommunity.com/app/1085660/discussions/0/3191363817375468999/),
[MobileSyrup: Destiny 2 pursuits](https://mobilesyrup.com/2019/08/13/bungie-fix-pursuits-destiny-2/),
[devtrackers: tracking after each step](https://devtrackers.gg/destiny2/p/38c0b546-bungie-don-t-force-me-to-track-a-quest-again-after-finishing-a-quest-step),
[GamesRadar: Fable 2](https://gamesradar.com/fable-2-fresh-look/2),
[Prima: Dead Space 3 locator](https://primagames.com/eguides/dead-space-3-with-interactive-map-eguide/essentials/the-basics),
[GameDeveloper: Tsushima's wind](https://gamedeveloper.com/design/using-vorticles-to-simulate-wind-in-i-ghost-of-tsushima-i-).

## What we take

- **One tracked task**, picked in the ledger with Track, and it stays tracked across its steps until it is done (the
  Destiny complaint fixed). The story's own way ("The night's road", the spine of QuestDB.OBJECTIVES) is a row of
  the ledger too, so you can always go back to it. Nothing picked: the guided first act while the guide is on, else
  the newest task, else the story.
- **The waypoint and its distance** over the place (ui/waypoint.gd), its mark on the compass strip, its pin on the
  map: all from the tracked task.
- **Marks on the way, a few at a time** (Fable's breadcrumbs, Destiny's moving waypoint): small marks on the ground of
  the road you should take, every 13 m or so and at the turns, three or four ahead of you. Each comes up as you near
  it and goes out once you pass it. Never a continuous line.
- **The route follows the ways.** The road and lane network (RealmLayout.PATHS and the walkway lanes) is the route
  where it helps; the navigation mesh carries you onto it and from it to the place, and is the fallback where the ways
  do not help.

## What we change for a dark night action game

- **Nothing glows for free** (pillar 2). A mark is a painted pilgrim's waymark worn into the ground, a decal that the
  lantern and the fires light, with only a faint ember in its cut so it can be found in the dark. Its emission stays
  under the glow threshold: it never blooms, and the night stays dark around it.
- **Sparse and quiet.** A few marks ahead, none behind, none in the last few metres (the place's own mark and prompt
  take over), and none at all in a fight, a conversation, narration, a menu, the loading screen or the staged
  opening. The dark is still the clock: the trail tells you the way, not that you are safe.
- **Always in place.** No setting turns it off (Luke). Settings > Interface > Guidance now only covers the first act's
  lessons, the "Next" banners and Hearthward's people pointing the way.
- **One way of guiding.** The guide's waypoint, compass mark, map pin and pinned objective (core/story/guide.gd) were
  a second system beside the tasks'. Now the guide only says what the story's step is and where; the tracker
  (core/story/quest_track.gd) decides what is followed, and the waypoint, the compass, the objective line and the trail
  all read the tracker.
- **Painted, in-house icons.** The ground mark (`trail/step`), the arrival mark (`trail/end`) and the story's row in
  the ledger (`lore/story`) are painted with the icon kit (tools/icon_kit/trail.py), like every other icon.

## How it is built

| Piece | File | What it does |
| --- | --- | --- |
| The pick | `core/story/quest_book.gd` | `follow(id)` / `followed()`: story key `follow` ("" = the default, "main" = the story, else a task id). Old saves' `track` dict is left alone and unread. |
| The tracker | `core/story/quest_track.gd` | One per night, child of the story director, group `quest_track`. Every 0.25 s: which task is followed (the pick, else the default) and where its step is (`current()`: id, title, text, target, foot, kind, art, label). The places: the guide's spine step for the story; for a task, its step's `at` / `to`, its pickup, the person to talk to, its seal, the bell or rare it wants, the region its foes are in. |
| The route | `core/story/trail_route.gd` | The ways as a graph (AStar3D over PATHS and the walkway lanes, a node every 8 m or less, joined where ways meet or cross; built once). `build()`: onto the nearest way, along it, off at the way's point nearest the place, nav legs on and off; the plain nav path (or a straight line before the mesh is in) when the ways would not help. |
| The trail | `core/story/quest_trail.gd` | Six pooled Decals. Marks every ~13 m along the route and at turns over 35 degrees; the next three or four within ~45 m (more on a horse) are shown. Each is seated once (the floor nearest the way's height among the surfaces under it) and fades in and out. The route is rebuilt only when the step or its place changes, the place moves more than 8 m, or you stray 14 m off it (at most every 1.5 s). |
| The HUD | `ui/waypoint.gd`, `ui/compass.gd`, `core/story/objective_line.gd` | Read the tracker. The tracked task heads the objective lines with the painted pin. |
| The ledger | `ui/quest_log.gd` | "The night's road" heads the list; Track picks the one followed; the tracked row wears the pin. |
