# Critique C: story and people (r29)

Lens: the NPCs (villagers, the Keg's dwarves: faces, bodies, animation, the night grade, voices),
dialogue writing and flow, the five task chains and their edge cases, village and tavern life (routines,
Keg scenes, shop, rumours), lore and the Journal, the opening and the ending, and how the story pulls a
player through the night.

How I played it: every conversation walked in full under four world states (fresh, midway, both
bosses down, after the ending) and read as a player would (zz/critc_talk_dump: transcript in the
isolated HOME, user://critc_talk.txt); every task run through its edge cases in the built world
(zz/critc_quest_edges); every NPC rendered close up, at talking distance and from the wanderer's own
camera height with the grade on (zz/critc_npc_tour, shots/critC_npc_<id>_<tag>[_mid|_high].png); the
existing harnesses (quest_test, story_test, village_test, quest_shot, story_ui_shot, lore_codex_shots,
npc_perf, voice_test, lore tests, quit_probe --verbose).

Severity: S1 breaks or looks broken, S2 clearly hurts, S3 polish. Status after the pass in brackets.

## S1

1. **Nan accuses every new player of telling on her.** Her hub's first condition was `att:nan:-2`,
   which means "attitude at least -2", so it was true for everyone at 0: her first line, forever, was
   "I'm not talking to you. You tell." Her Pell and home lines never showed.
   Evidence: transcript, state "fresh", Nan Wright hub. [fixed: `!att:nan:-1`]
2. **Pell's one spoken line was unreachable.** The node that says "(Very quietly, to the fire:) It isn't
   warm up there." also set `met:pell` in its `do`, which runs before the line is chosen, so the
   first visit already read "(She does not look up.)". The ending's quietest beat never played.
   [fixed: a say_if line may now carry its own action, run when that line is the one said]

## S2

3. **After the ending the valley still sends you up the Stair.** The keep's "What now?" said "Up.
   Aurel's at the top... Make him let go of the door", his goodbye "Bring him down", "the three" ended
   "nothing shuts the door but you", Brannoc explained how to reach Aurel and what happens "if he
   falls", Ostrin said "Finish it" about the Abbot after he was dead, Oswin (faith) waited for a bell
   that had already rung. [fixed: post-ending lines for the keep (hub, next, bye, the three),
   Brannoc (reach, falls), Ostrin (oss), Oswin, Abel, Wyck; the keep's "news" knows Hobb and Oswin]
4. **Abel stuck on one line for good.** After the tongs went back on Edda's stone his greeting
   waited on `flag:abel_tongs`, which nothing ever set: the names, the Abbot, the hollows lines below
   it could never show again. [fixed: the line is said once, then retired (`v:abel_tongs`)]
5. **The keep sold "Nothing new" for 2 ash.** Once the rumours ran out the slate still took ash for
   "Nothing new. The dark's quiet tonight." [fixed: the row reads "The room has nothing new tonight"
   and can't be bought; 7 new rumours for the later night (appended: heard rumours are saved by index)]
6. **Grisel sold lamp oil that lit nothing.** After the braziers (kindled 3) or two bosses had already
   lit Fennick's round, oil (8) and more oil (12) were still on her cart and she and Fennick still
   asked for it. [fixed: offered only while the lamps it lights are dark; village_test buys it in that
   state]
7. **Tavern windows from inside were flat orange cards.** The kit's window glass is unshaded,
   emissive and double-sided, so from inside every window was a bright orange slab, behind the keep
   in every conversation at the bar. shots/critC_keg_windows_before.png, critC_npc_keep_before.png ->
   critC_npc_keep_after.png, story_ui_menu.png. [fixed: tavern.gd gives the panes their own
   one-sided surface: warm from the street, the night through the leading from inside. +1 draw]
8. **Old Fennick has no face.** His brim, level and 0.155 wide, hid his whole face from any camera
   above eye height, which is every camera the wanderer has. shots/critC_npc_fennick_before.png ->
   _after.png. [fixed: brimmed hats sit pushed back (0.24 rad) and a little narrower; Abel too]
9. **Oswin's walk could not be abandoned.** Once started, he followed the wanderer until he reached the
   stone: no way to send him back, no way to drop the task. [fixed: "Go back to the road's rest.
   Another night." in his own conversation; QuestBook `qx:` (set aside, can be taken up again);
   QuestWorld releases him back into his night if the task is gone, also after a reload]
10. **Banners over menus** (register, from F): the task and region banners drew over the dialogue
    box, inside the ledger, over Settings. [fixed: hidden while the tree is paused; their tweens hold
    and play when the menu closes, so a task begun in a conversation still gets its banner]
11. **The ending's words could be lost.** `ending_seen` was set when the Warden fell and the words came
    4 s later: leave in between and they never play. [fixed: the flag is set when they are said, and
    a load with the Warden down and the words unsaid says them]
12. **Two drivers fought over the portrait's jaw.** The story's live layer (npc_life: syllable jaw,
    blinks, glances) posed the Keg's portraits, then the box's own sine sway overwrote jaw and head
    every frame, so dwarves' mouths never followed their words. [fixed: the box stands aside when the
    live layer drives]
13. **Subtitles under the dialogue box.** A pickup's narration or Oswin's "Forty-one" arriving as you
    open a conversation drew through the box. [fixed: they wait, not lost, until it closes]
14. **The Journal map didn't help you play.** Regions, roads and found secrets only: no braziers, no
    Keg, nothing about the tasks you carry. shots/critC_map_before.png. [fixed: braziers (a flame,
    grey until kindled), the Keg, and a gold ring for each task's current place (the thing to find,
    the stone, the fen, the person to talk to), with a "Tasks under way" list that focuses each ring.
    shots/critC_map_after.png]
15. **NPC walkers stepped at 60 Hz at Luke's 120-144 Hz.** Within 11 m a walking villager posed at
    60 Hz (30 Hz for 11-20 m) against a root that moves every frame. [fixed: within 11 m walkers pose
    every frame, 11-20 m at 30 Hz; still bodies unchanged]
16. **The faces read as dolls next to the wanderer.** Smooth one-surface heads, big round eyes, split
    blue/orange under the grade, beards as white spikes (Fennick), the dialogue portrait of the keep
    washed out pale. shots/critC_npc_*_before.png, story_ui_menu.png. [open: a sculpt pass on
    npc_face.gd and a darker portrait key; out of reach for this pass without risking the look]

35. **Fennick can end up standing inside Grisel's cart** (intermittent): one village_test run of
    four sampled him 74 times at (-7.8, 29.95), the cart's own centre (its bed is solid at 0.74);
    the rerun passed. The cart stands 1.05 m from Grisel's node toward the green, 0.34 m from the
    green_w-green_sw walking edge. [open S2: needs the walker's path vs the cart's footprint traced;
    scratchpad critC/logs/village_test.log]

## S3

17. Ostrin, a patron, asked "Buying, or asking?" [fixed: "Drinking, or asking?"]
18. Brazier counts written wrong: the keep said "I can see one from the door" with 2-3 lit; Fennick
    "I can see two" with 3-4. [fixed: their own lines for 2, 3 and 4]
19. "Ostrin went quiet when he heard" fired after the Thornwarden, which is not his story. [fixed: on
    the Abbot; Hesk gets the Thornwarden line]
20. Abel's choice "One of them was standing when I found the slate. Hollow. I put it down." claimed a
    fight the game never stages. [fixed: "I read them out loud where I found them, like you said",
    which is what he asked]
21. The Keg's scenes repeat within minutes: 3 argument pairs, 2 dice lines. [deepened: 8 pairs, 5
    dice lines]
22. Hobb (Maud's son, a named elite) is never acknowledged in the village. [deepened: `elite:id`
    condition term; the keep's news and a rumour know when the knocking stops]
23. The opening narration repeated the region banner word for word ("Hearthward. The last kindled
    village..." twice in two seconds), and the banner landed on top of the zone's title card
    (register, from F). [fixed: a new first line; region banners wait out a title card]
24. Father Harrow's title ("Father Harrow, hollowed") was data nothing showed: the fight was a nameless
    husk. [fixed: the task banner names him when he wakes]
25. Freed-node use: the village talk driver and the story director used `if who:` / `if _npc:` on
    NPCs that can be freed mid-talk (Oswin leaving, a rebuild); the shop handoff passed a freed node.
    [fixed: is_instance_valid everywhere; the edge probe frees Grisel mid-conversation]
26. Static caches outlived the renderer at quit (dwarf_look materials, npc_voice banks, village_audio,
    village_props, villager_rig meshes, lore_assets/lore_kit/inscription). [fixed: release() on the
    night's teardown]. dwarf.gdshader's global const arrays were orphaned at every exit [fixed:
    per-vertex layer params, same look]. The 2 DummyShader RIDs left are not the dwarf shader
    (register to:E, realm_ground).
27. The objective "Break the gallery seal in the Ossuary, down from the Barrow Field" wrapped and ran
    into the controls hint row. [fixed: shortened; the hint row's width is B's, registered]
28. Grisel's hood rim crosses her face at close range when she turns her head; Oswin's, Pell's are
    fine. [partly: the rim of every hood sits forward of the brow and nearly upright, which frames
    Oswin's face better; Grisel's close-up (< 1.5 m) is still off. Open]
29. Fennick carries a lantern that is never lit (the lamplighter). [open]
30. The forty-first waystone reads as a brick post, not a waystone. shots/agentE_stair_after.png [open]
31. Nan's mug "by the fire" stands 3.6 m off the brazier in open grass. It is where Pell sits once
    she is back, which is the point; left. 
32. Grisel's conversation has two dead nodes ("poor", "none") nothing reaches. [left; the talk dump
    exempts them]
33. The Journal map is small inside its page (a tall valley in a wide panel). [open]
34. Rumours are saved by their index: inserting one in the middle reshuffles what the save thinks
    you heard. [documented in the data: add at the end only]

## Outside my files (all in docs/critique/register.md)

- to:B S1: core/player/character_rig.gd:1320 `Sfx.has_method("play")` is a parse error: CharacterRig
  and every rig that extends it fail to compile in every run since about 16:20 (headless tests still
  pass, so they do not catch it).
- to:B S3: the controls hint row runs under the objective column for the first 16 s on a progressed
  save; the camera sits under Hild's forge awning for a whole conversation.
- to:E S3: realm_ground.gdshader's global const arrays (SCALE, LAYER_CS) are the last orphan names at
  exit; 2 DummyShader RIDs still leak.

## The story's pull, overall

The spine is clear and short (keep -> braziers -> two seals -> two bosses -> the Crossing -> Aurel ->
back to the Keg) and the HUD always says the next thing. What was weak was the middle and the end:
the village did not notice what you did (fixed for the ending, Hobb, Oswin, the bosses), the Journal
map could not show you where your tasks were (fixed), and after the ending half the valley was still
pointing up the Stair (fixed). What is still thin: there is no waypoint or compass beyond the map,
and nothing in the world draws the eye toward an unlit brazier from Hearthward.

## Tests

New: zz/critc_talk_dump (every conversation under four world states: reachability, placeholders,
empty or over-long lines, lines repeated across people; writes the transcript), zz/critc_quest_edges
(the hollowed man freed and re-woken, Oswin's walk set aside and taken up again, every step of every
task through the save's encoding and a cold sync, slates in any order, a pickup out of order refused,
a villager freed mid-talk, the Journal map's rings, rumours running out), zz/critc_npc_tour (every
NPC: face, talking distance, the wanderer's camera height). Updated: story_test (post-ending lines,
the brazier count), village_test (oil only while its lamps are dark).
