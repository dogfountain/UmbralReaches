# Feature critique, 14 Nov 2026 (the panel, against the live build 880deb1)

Evidence: zz/first_minutes (the opening and movement feel), ui_shot, char_screen_shots, combat_shots (a pack on the
road, the Thornwarden in the henge), creature_shots (every enemy at play distance), skill_shots, menu_shots,
world_map_shot, horse_studio, the fight bench and the baseline views. Findings are ranked within each seat; the
"fix" column is what this round does. Delete this file when its fixes are merged.

## Creative director (pillars)
1. **The dark is the clock, and the clock is the smallest thing on the HUD.** Gloom is a 3 px bar under the name
   plate reading "7 / 100". Wounds are five times its size. The pillar says everything is measured against the
   dark. Fix: Gloom gets its own readable meter, and the world (not only the bar) shows it rising.
2. **The first ten seconds are three messages on top of each other.** The region banner, the title card and the
   opening narration all draw at once (first_minutes: "FAIL banner and title card on screen together"), over a
   camera that faces a cottage wall and a lamp post: the scaled-up Hearthward cottage now crowds the start spot.
   Fix: one message at a time; the start looks down the road at the gate and the stair.
3. **"Daily" quests in a game that is one night.** Five chains are `repeat: "daily"`. PILLARS.md lists "daily
   chores" under "not this game". Luke's call (see the question to him).

## Combat designer
4. **Grunts do not read against the night.** At play distance a wretch or husk is a dark grey figure on dark blue
   ground; in a pack the wanderer's own body covers them. Only the Bone Abbot (lit from inside) reads at once.
   Fix: every enemy carries a readable accent (eyes, a rim, a kind colour) that survives the grade.
5. **The Thornwarden is the smallest thing in his own arena.** He rises behind the standing stones, a third of
   the wanderer's height on screen, under one line of small yellow text. Fix: staging: he rises in the open on
   the camera's axis, the camera gives him the frame, and the intro line is a boss title, not a toast.
6. Fights average 115-117 fps on the release build, not a held 120 (measured; the visual trades are Luke's).

## UX
7. **Gear page: body text at about 9 px** on a 1600 px window, three columns of it; set bonus, traits and
   comparison all the same weight. Fix: a type scale (title, stat, flavour), fewer words, the comparison first.
8. **Kindling and Tasks float as small panels in an empty screen**, while Gear is crammed. One layout grid.
9. **The journal map is dots without names.** 60 pips, no labels, no "you are here" that reads. Fix: named
   places, the wanderer's mark, the road drawn heavier.
10. **Loot: the prompt and item name draw under the window and the hotbar** ("Charnel Censer" clipped behind the
    panel, "LOOT THE GREAT ONE'S HOARD" behind the hotbar).
11. **XP line "Level0 · 20 / 40 +20 discover"** is 8 px in the corner with a missing space.
12. The compass shows four distance tags at once, two of them dimmed to unreadable.

## Art director / environment / tech art
13. **The washing line at the spawn is three flat untextured rectangles** the size of doors, in the first frame
    of the game. Cut to cloth with folds and sag, or remove.
14. **Willows still read as green slabs** at mid distance in three of the combat stills.
15. Hearthward's forge lean-to, shrine, well and notice board are the old code-built pieces at the old scale.
16. The title screen is very dark: the title is at about 15 % contrast on black (as captured).

## Animator
17. Movement feel passes the tool's smoothness read (walk, sprint: camera and body move on rendered frames).
    Not judged this round: enemy and boss animation in motion (stills only), the horse's new hop.

## Sound designer
Not judged this round: nothing was listened to. No claim either way.

## QA
18. The banner / title overlap above. No script errors in any capture run.

## Performance
19. Open world holds the display's 120; one frame over 18 ms after load. Fights as in 6.
