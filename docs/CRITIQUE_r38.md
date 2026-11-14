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

## Animator (judged in motion: zz/enemy_seq strips of all 19 kinds, walk / attack / stagger / death, shot in real time; zz/move_seq loco, combat, traversal; horse_studio gaits)
17. **A stagger read as standing to attention.** Every biped (wretch, husk, tollman, the Abbot...) snapped upright
    with its arms down and stood still for the 1.1 s punish window. Fixed (hunch_rig): the blow knocks it back,
    arms flung, then it sags on buckling knees, head hanging, weaving from foot to foot.
17a. **The wind-up was a dead hold.** It rose in 0.2 s and froze until the strike. Fixed: through the hold the
    coil keeps tightening (deeper knees, arms further back) and the tremble grows.
17b. **Deaths: planks and tipped toys.** Robed bosses fell as one rigid board; quadrupeds rolled onto their backs
    with four stiff legs in the air. Fixed: bipeds drop to their knees, arms thrown, and twist as they go over;
    quadruped legs kick once and curl in, and the roll stops short of belly-up.
17c. **The Thornwarden's mane floated 23 cm above his back** (rooted in the air in the model). Fixed in
    tools/blender/boss_thornwarden.py and re-exported.
17d. **The Ascended Warden slid like a statue** (it floats, so no stride, and nothing else moved). Fixed: a
    hovering rig leans into its travel, bobs on a slow breath and trails its arms.
17e. **Quadruped stagger was one frozen pose.** Fixed: it shudders, shakes its head and scrabbles.
17f. **Horse: at a gallop the mane blew flat across the saddle**, over the rider's seat. Sweep halved. Walk,
    trot and gallop poses read; the mane cards are saw-toothed up close (art, open).
17g. Wanderer: walk, sprint, strafe, backpedal and the casts hold strong poses. Open: the stop out of a sprint
    snaps upright in two frames; feet slide 7-10 cm per metre travelled (move_seq's measure).
17h. Open: the leaper's dorsal spines part from its back when it arches; the burrower stands on straight pins.

## Sound designer (measured, not heard: tools/analyze_foley.py, the bus chain in core/world/ambience.gd)
17i. **Footsteps and hooves were level-matched by their tallest sample**, so a click on stone sat 8-10 dB under
    a squelch in mud (11.7 dB spread across 24 one-shots). Fixed (foley.gd): matched on the loudest 40 ms with a
    soft-clipped ceiling; spread now about 6 dB. Two kinds (stone, salt) still read over 0 dBFS true peak before
    the master limiter (-0.5 dB), which catches them.
17j. The chain is sound: a compressor and hard limiter on Master, a compressor on Voices, reverb and a muffle
    low-pass for rooms. Not judged by ear: music, boss themes, voices (no one can listen from here; say so).

## QA
18. The banner / title overlap above. No script errors in any capture run.

## Performance
19. Open world holds the display's 120; one frame over 18 ms after load. Fights as in 6.
