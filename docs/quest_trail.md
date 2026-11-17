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
- **One waypoint, Destiny's moving waypoint** (Luke, 17 Nov: "why do 3 markers pop up and not 1 like Destiny"; the
  first build mixed in Fable's breadcrumbs and gave the way and the place different marks). One painted mark, the task's
  own icon, with the metres still to go along the way under it (ui/waypoint.gd). While the way bends it hangs over the
  next bend and moves on as you round it; on the last straight it is over the place. It reads from a few metres to
  ~500 m and goes in the last few metres. Its bearing is on the compass strip and its pin on the map: all from the
  tracked task.
- **The route follows the ways.** The road and lane network (RealmLayout.PATHS and the walkway lanes) is the route
  where it helps; the navigation mesh carries you onto it and from it to the place, and is the fallback where the ways
  do not help.

## What we change for a dark night action game

- **Nothing glows for free** (pillar 2). The mark is HUD paint, not light in the world: it lights nothing and the
  night stays dark around it.
- **Sparse and quiet.** One mark, never a line; none in the last few metres (the place's own mark and prompt take
  over), behind the camera or off the screen (the compass carries the bearing), and none at all in a fight, a
  conversation, narration, a menu, the loading screen or the staged opening. The dark is still the clock: the mark
  tells you the way, not that you are safe.
- **Always in place.** No setting turns it off (Luke). Settings > Interface > Guidance now only covers the first act's
  lessons, the "Next" banners and Hearthward's people pointing the way.
- **One way of guiding.** The guide's waypoint, compass mark, map pin and pinned objective (core/story/guide.gd) were
  a second system beside the tasks'. Now the guide only says what the story's step is and where; the tracker
  (core/story/quest_track.gd) decides what is followed, and the waypoint, the compass, the objective line and the trail
  all read the tracker.
- **Painted, in-house icons.** The trail icons (`trail/step`, `trail/end`, painted for the first build and kept in the kit) and the story's row in
  the ledger (`lore/story`) are painted with the icon kit (tools/icon_kit/trail.py), like every other icon.

## How it is built

| Piece | File | What it does |
| --- | --- | --- |
| The pick | `core/story/quest_book.gd` | `follow(id)` / `followed()`: story key `follow` ("" = the default, "main" = the story, else a task id). Old saves' `track` dict is left alone and unread. |
| The tracker | `core/story/quest_track.gd` | One per night, child of the story director, group `quest_track`. Every 0.25 s: which task is followed (the pick, else the default) and where its step is (`current()`: id, title, text, target, foot, kind, art, label). The places: the guide's spine step for the story; for a task, its step's `at` / `to`, its pickup, the person to talk to, its seal, the bell or rare it wants, the region its foes are in. |
| The route | `core/story/trail_route.gd` | The ways as a graph (AStar2D over PATHS, the walked lanes and the henge's pilgrim stair, a node every 6 m or less, joined where ways meet or cross within 5 m; built once). The network is in pieces, so `route()` is one A* from the wanderer to the place in which every node within 120 m of the wanderer is a way on and every node within 150 m of the place a way off, the legs across country costing 2.5 a metre (17 Nov: it took the node nearest the wanderer, on a lane that went nowhere, and every far route fell back to the navigation mesh across country). The trail joins the legs on and off by the navigation mesh. zz/trail_route_test.tscn walks fifteen routes and fails on a checkpoint off the ways. |
| The trail | `core/story/quest_trail.gd` | Where the one waypoint hangs (`guide`, INF on the last straight) and the metres along the way (`left`). Five times a second: the farthest route point ahead (at most 220 m) whose straight sight-line keeps within 5 m of the route before it; it only moves on. The point is seated on the floor nearest the way's height and the mark hangs 2.4 m over it. The route is rebuilt only when the step or its place changes, the place moves more than 8 m, or you stray 14 m off it (at most every 1.5 s). |
| The HUD | `ui/waypoint.gd`, `ui/compass.gd`, `core/story/objective_line.gd` | Read the tracker. The waypoint draws the one mark over the trail's point (or the place), dips out and back in when it moves on to the next bend, is kept inside the HUD's frame while on screen and fades from 7 m to 3.5 m. The tracked task heads the objective lines with the painted pin. |
| The ledger | `ui/quest_log.gd` | "The night's road" heads the list; Track picks the one followed; the tracked row wears the pin. |
