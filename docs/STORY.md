# The story layer

How the valley's story is told in play: the arrival at Hearthward, the people of the Kindled Keg,
the road to the three who hold the valley, and the ending after the Ascended Warden. The canon is
`docs/LORE.md`; this file is how it is wired. House style is LORE.md's: terse, concrete, dark.

## Shape

1. **Arrival.** First night only (no story flags and no progress in the save): about six seconds
   after the zone title card, three lines of narration as subtitles, no pause:
   *The road ends here. Past the last village there is only the Stair, and the sky it opened. /
   Over the Crowns the sky turns inward... / There is light in the Kindled Keg.* Objective: **Find
   the keep in the Kindled Keg.**
1b. **The guide** (a new game only: story flag `guide`; `core/story/guide.gd`). The HUD comes with the
   first line, not with the first step: the objective is pinned top right, the compass and a painted
   waypoint (with its distance) mark the Keg's door, then the keep inside; the move prompt follows on
   painted key caps; lines two and three wait until the wanderer is on the move. After the keep, a
   guided save's first step out is one fire (**Kindle the brazier at the Stair's foot, north of
   Hearthward**, `first_fire`), then the doors. Each new step is announced ("Next", the objective, where
   it is: `guide_lines.gd`). Hearthward's people call out where the step is as the wanderer passes, turn
   and point; "Which way?" is in their conversations and the patrons'. The guide lets go when Brannoc
   has been spoken to after both keepers (`guide_done`), or with Settings > Interface > Guidance off.
2. **The keep.** The first conversation (a menu: what happened, who holds the valley, where to
   start) sets `met_keep` and opens the road: the two seals, and the kindling. The keep knows
   *what* holds the valley, not *who*: "Somebody opened the sky", "whatever stands at the top of
   the Stair with the door open". Aurel is named by the rim's third edict, by Brannoc once a boss
   is down, and by the Warden's bar in phase III (**AUREL, HIERARCH**, `BossArena.phase_titles`).
3. **The road.** Objectives follow the world, not a quest log: break the thorn seal (west, the
   Thornwood edge), cut the Thorn Heart from the Thornwarden; break the gallery seal (the Ossuary,
   south down the Waiting Field's road), take the Abbot's crown from the Bone Abbot; then carry heart and
   crown to the summit ward across the Crossing, and face what holds the door. A ward walked into
   too early says what is missing ("Nothing answers. The crypt's crown still holds below.",
   `BossArena.nothing_answers`). Side line: kindle the valley's four braziers, shown as n/4; each
   names itself when lit (the Stair-foot fire, the glade's fire, the Barrow Field fire, the fen
   fire; node names StairFoot, Shrine, Landing, Threshold never reach the player).
4. **People.** The keep's hub reacts to progress (greeting, "what now", news of the braziers and
   of the village, Hobb's cairn found). Three patrons talk: **Hesk the Woodcutter** (the Ring, the Rooted, the thorn
   seal), **Ostrin Harrow** at the bar (the fen, the three stones, the way to the Ossuary under the Waiting Field), and
   **Brannoc Bellwright** (the bells his mother the Founder cast, the summit ward; "Who's up
   there?" opens after one boss). Each says something different once his boss is dead, and again
   in the Deeper Night. Eleven villagers talk as well (`core/life/village/village_talk_db.gd`).
4b. **Act II: the Founder's peal** (r36). Once heart and crown are taken, the keep sends you to
   Brannoc: the summit door was hung to a bell, and it opens only to a peal. The Founder cast seven
   bells, one for each far country. Each country's giver offers its bell after their own chain. You
   put down its keeper (a named rare), then at the bell you **ring it there** or **lift the tongue
   out for Hearthward**. Four bells open the ward and the dais. Every carried tongue rings at the Keg
   when the Warden wakes, and he holds the door with 5% less.
5. **Ending**, one beat (`story.gd` `_ending` / `_ending_tick`). The Warden's fall raises no toasts
   (boss_arena skips "falls.", summit_dress and reactivity say nothing for him). 1.5 s after the
   bar drops: *The sky stops turning.*, while the vortex's spin eases to **zero** over ~9 s
   (reactivity.gd: `spin_phase` keeps the arms from sweeping back); when that line has gone, one
   deep bell (`ring_bell`: the scape bell two octaves down, non-positional, once); 2.4 s later
   *Somewhere above the Crowns, a bell rings once. From the bottom up. / The cold stays. It no
   longer pulls.* The explore music plucks its bell notes until `ending_seen`, then rings them,
   rarely. Objective: **Return to the Kindled Keg.** The keep's last conversation ("Aurel?": he
   let go / he was hollow / *he was waiting for me*), the rule of who comes back down (end_4), one
   line from what the player did (end_4b: the lantern, the pilgrim who went home, Nan's mug), sets
   `ending_told`, and the title card reads **THE DOOR IS SHUT** / *Hearthward keeps its fire*.
6. **The Deeper Night** (NG+, `director.gd begin_deeper_night`): the cracked bell, rung top first.
   The story's ending flags are filed per cycle (`ending_seen/told/card`, `deeper_met` ->
   `<flag>_ng<n>`) and `deeper` is set, so the next Warden gets the whole ending again; the keep
   opens on `ng_1` ("You rang it. ...Wrong way up."), and Hesk, Ostrin and Brannoc each have a
   `flag:deeper` hub line while their boss stands again.

## Files

| File | What |
|---|---|
| `core/story/story.gd` | The director (group `story`). Added by `Tavern._patrons()`. Holds no state of its own: `Travel.story`. `talk(conv, npc, player)`, `objectives()`, `flag()/set_flag()`, `kindled()`, `world()`. Opening and ending beats. |
| `core/story/quest_db.gd` | `OBJECTIVES` and the condition language. Pure/static: `active(ws)`, `test(cond, ws)`. |
| `core/story/dialogue_db.gd` | `CONV` (keep, hesk, harrow, brannoc), `OPENING`, `ENDING`; `start_node`, `text_of`, `choices_of`, `audit()`. |
| `core/story/objective_line.gd` | The HUD's objective lines (top right). Polls the director twice a second. |
| `ui/dialogue.gd` | The box: live portrait, name plate, typewriter, choices, pause; `narrate()` subtitles. |
| `core/npc/*` | The dwarves (see below). `DwarfNpc.talk_id` / `Bartender.talk_id` make them speak. |

### State (save)

`Travel.story = {"flags": {id: true}, "picked": {choice key: true}}`, written in its own `[story]`
section of `user://savegame.cfg` (`state` key). Older saves have no `[story]` section and load as
`{}`. A save that already has seals or bosses but no story flags is treated as arrived and met (no
opening narration, no "find the keep"). Flags: `arrived`, `met_keep`, `met_hesk`, `met_harrow`,
`met_brannoc`, `ending_seen` (narration fired), `ending_told` (last conversation), `ending_card`,
`deeper` (a Deeper Night has been rung), `deeper_met` (the keep has greeted it), and the filed
`*_ng<n>` copies.

### Conditions

Terms joined by `,` (and) and `|` (or; looser than `,`); `!` negates a term:
`flag:x`, `seal:x` (`henge`, `oss_gallery`, `summit`), `boss:x` (`thornwarden`, `bone_abbot`,
`ascended_warden`), `item:x`, `kindled:n` (at least n of the four), `bosses:n`. `""` is always.
An objective shows while `when` holds and is done while `done` holds, so out-of-order play (the
Abbot before the keep, a seal before the talk) just counts.

### Conversations

A node has `say` or `say_if` ([[cond, text], ...], first match, last one unconditional), an
optional `do` (flags set on entering), and `next` or `choices` (`{text, to, if?, do?, once?}`;
`to: ""` ends; `once` choices vanish after they are picked). `{kindled}` in text is replaced.
`DialogueDB.audit()` checks every target, condition and fallback (zz/story_test runs it).

### The box

`E`/Space/Enter/click finishes the line, then continues; `1-4` or W/S + `E` pick a choice; `Esc`
leaves. The world pauses (`get_tree().paused`), the mouse is freed and restored. The box is a
CanvasLayer (60) added to the root, last in the tree, so it sees input before the settings menu
and the satchel. The portrait is the speaker's own `DwarfRig` (cached mesh) in a 256 px
SubViewport, rendered only while open; its jaw moves while the line types, and so does the NPC's in
the room (`speaking`), who turns to face the wanderer (`attend`).

## The tavern dwarves (core/npc)

- **DwarfRig** (`dwarf_rig.gd`): 15 bones (root, spine, chest, head, jaw, arm/fore/hand x2,
  thigh/shin x2), built by `dwarf_mesh.gd` (tubes, ellipsoids, strands, braids, rings, two-sided
  cloth sheets; metres UVs, material layer in UV2.x, baked AO in COLOR.a, two-bone soft skinning)
  and shaded by `dwarf.gdshader` with procedural detail arrays from `dwarf_look.gd` (skin pores,
  wool/linen weave, leather grain, hair strands, hammered iron, wood grain, foam, fur; Image +
  FastNoiseLite, normal maps via `bump_map_to_normal_map`, cached in GenCache). One skinned
  surface + LODs: **1 draw per dwarf**, ~12-15k verts / ~20k tris at LOD0. Cache key includes the
  hash of `dwarf_mesh.gd`, so editing either script rebuilds (~0.3 s a dwarf, once).
  Posing: `q(bone, quat)`, `fk_all()`, `arm_to(side, wrist, pole, hand_q)` (two-bone IK),
  `wrist_for(side, rest_point, goal, hand_q)`, `lips()`, `apply()`.
  Colour under the grade: palettes are sRGB and deep but bright enough for the grade's warm
  protection; skin and reds sit at hue 15-28 deg (below ~10 deg the grade pulls them to magenta);
  AO cuts the azure ambient in creases; a small warm bounce term (`bounce` 0.16) stands in for the
  hearth's light on cloth facing away from the lamps.
- **DwarfNpc** (`dwarf_npc.gd`): seated (bench/chair, origin on the floor, seat 0.47) or leaning at
  the bar. Beats: drink (IK mug to the lips, head back, a moustache wipe), toast (with the partner,
  then drink together), laugh (jaw, shake, table slap), talk (jaw + hand), listen (nods), look.
  Pairs across a table share beats through `partner`/`leader`.
- **Bartender** (`bartender.gd`): the keep. Walks the duckboard (legs swing), wipes the counter with
  his cloth, polishes the tankard, fills it at the keg tap, serves tankards to the counter, leans in
  to talk with the bar regular, faces and gestures at the wanderer at the bar.
- **Placement** (`core/world/tavern.gd`, `_patrons`, `PATRONS`, `CHAIRS`, `SEAT_Y`, `KEEP_IN`,
  `STEP_Y`, `CHAIR_IN`): the keep's lane is `bz - 0.575` (his apron clears the counter's back edge
  at `bz - 0.92`, his back the shelves at `bz - 0.35`); the regular stands on the foot step at
  z 32.34 (clear of the counter face at `bz - 1.55`); chair sitters sit 6 cm forward of the chair
  with feet tucked. `zz/story_test` measures all of it.

## Tests and renders

- `godot --headless --path . res://zz/story_test.tscn` -> `STORY TEST PASS` (quests, dialogue data,
  the director + box flow, persistence incl. an older save, rig clearances, every beat without
  NaNs). It copies the real save aside and restores it.
- `godot --path . res://zz/story_studio.tscn -- --name=x [--times=1,2] [--views=table,face,keep,bar,chair,line,line_close,line_back,line_side] [--nograde] [--nolod]`
  studio set at the tavern's real heights (pair, chair sitter, regular, keep, a line-up).
- `godot --path . res://zz/story_shot.tscn -- --at= --look= --name= [--times=] [--keep=x]` in-game
  frames with the colour grade ON (spot_shot hides it); never writes the save.
- `godot --path . res://zz/story_ui_shot.tscn` the dialogue box and objective lines in game.

## Known gaps

- No voice or sound for talk; no lip shapes beyond the jaw.
- At the Keg only the keep and three patrons talk; the other five keep to themselves.
- r30 storyteller items left for other lanes: the opening still spawns on the green, not on the
  road at waystone III; the summit ward has no sockets (it still checks `bosses_slain`); the
  Warden does not yet hold the door with a raised arm and a thread to the sky; no bell hangs
  over the dais; no Ossuant says "...Wenna?"; the Deeper Night bell has no sound of its own.
  Oswin/Ostrin/Osric keep their names (renaming touches tests and the cast).
- Two patrons get up and walk to the bar and back (`tavern.gd` WANDERERS); the others stay seated, and the keep never leaves the duckboard.
- The portrait is lit in its own little world (not the room's light).
