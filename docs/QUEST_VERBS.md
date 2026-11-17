# Task verbs

Luke's review: the 119 tasks are courier loops (find 58, slay 48, place 36, visit 28). These are the new step
kinds ("verbs") a task declares in its `steps` like any other kind, and the one way a finished task is
*remembered*. Existing systems and in-house assets only: every prop is a `quest_props.gd` kind, every foe an
enemy script, every light the one that was already there.

| Verb | Kind | What the player does | Code |
| --- | --- | --- | --- |
| Investigation | `clues` | Searches an AREA; reads signs with the interact key; what was read changes the accusation | `verb_world.gd`, `verb_kit.gd` |
| Follow a trail | `tracks` | Finds marks one at a time, each pointing the way to the next | `verb_world.gd`, `verb_kit.gd` |
| Keep a light | `lantern_walk` | Carries a lit lamp A to B without running, rolling, being hit or swimming | `verb_lantern.gd` |
| Sequence puzzle | `order` | Touches things in the order a lore line or conversation gave; wrong wakes a foe | `verb_world.gd` |
| Vigil | `vigil` | Stays within `r` of a place for `time` seconds while the Gloom rises and foes come | `defend.gd` (generalised) |
| Remember | `outcome`, `qp:`, `qc:`, `leaves` | A finished task changes later talk and leaves a prop | `quest_book.gd`, `verb_world.gd` |

Where things live: step data is in the task (`quest_chains*.gd`; the five demos in `quest_chains_verbs.gd`); state is
`quest_book.gd` (all of it in the task's saved dictionary, so a reload mid-step keeps it); the runner
(`quest_runner.gd`) stands up the live nodes (`vigil`, `lantern_walk`); `verb_world.gd` is the ground-side node
(a child of `quest_world.gd`) for clues, trails, orders and left props; `verb_kit.gd` is the data side (audit,
count, search areas). `Chains.audit()` runs `VerbKit.audit()` over every step, so a malformed verb fails the suite.
`zz/quest_verbs_test.gd` is the headless test (fast tier).

Performance rule kept: no per-frame tree scans, nothing built mid-play that could be built at load. Floor points for
every clue, mark, thing and left prop are found once at load (`VerbWorld.prepare`, called from `QuestWorld.prepare`).
While a step is current only its own few nodes exist. The one 4 Hz check is a distance test, and only while a trail is
under way. The lantern reads four Player state values a frame, only while a lantern_walk step is current.

---

## 1. `clues` (investigation) and the accusation

A step with several signs to read in the world, needing `need` of them. Reading is the ordinary interact prompt on a
glint (optionally with a prop) at each spot. The player is sent to an AREA, not a point.

```gdscript
{"kind": "clues", "at": Vector2(27.5, 32.4), "r": 12.0, "need": 2, "label": "Signs behind the Keg",
	"text": "Search behind the Kindled Keg, by the chimney, for signs of the ale thief ({n}/{of} read)",
	"clues": [
		{"key": "circle", "at": Vector2(27.5, 32.4), "prop": "mug", "name": "a dropped mug", "text": "One of the Keg's mugs, dry, on its side..."},
		{"key": "gnaw", "at": Vector2(30.0, 30.6), "prop": "loaf", "name": "a gnawed crust", "false": true, "text": "A heel of oat-cake ... Something small."},
		{"key": "prints", "at": Vector2(25.4, 34.4), "name": "spilled ale", "text": "... Small feet went through it. Bare, narrow."},
		{"key": "latch", "at": Vector2(30.4, 34.2), "name": "the back keg", "text": "The back keg's bung is out and set down neat on the lid. Rats don't put things back."},
	]},
```

Fields. Step: `at` (the area's centre), `r` (its radius, default 16 m), `need` (default: all), `label` (the progress toast's
title), `text` (may use `{n}` read and `{of}` wanted). Clue: `key` (no `:` or `,`; unique in the step), `at`, `text` (the
line read out), optional `prop` (a `QuestProps.make` kind; none = a glint only), `name` / `verb` (the prompt: "Look at
a gnawed crust"), `false` (a note for writers: the engine treats a red herring like any clue; the dialogue is what
tells them apart).

**What the player sees.** The objective counts "(1/2 read)". The map shows a gold CIRCLE over the area (minimap and
world map; a pin at its centre) and the waypoint hangs over the centre and vanishes at the circle's edge, so the
search is theirs. Each sign is a small glint; using it reads its line (the subtitle) and puts out its glint. Reading
the `need`th moves the task on; unread signs go. A sign read twice counts once.

**The accusation.** Every examined clue is remembered, with the task, for good (it stays after the task is done):
`QuestBook.find(id, "c:<key>")`, so a condition `qc:<quest>:<key>` is true from then on, in any dialogue `if`, `say_if`,
`start` or `avail`. A later talk step gates its choices on it. The wrong accusation is a different outcome, not a
failure: it sets a pick and the task still ends.

```gdscript
# village_talk_db.gd, Nan, step 2 of keg_thief
"thief": {"say": "...You've been following my circles... What did you find?", "choices": [
	{"text": "Bare feet in the spilled ale. Small ones. Yours.", "to": "thief2", "if": "qc:keg_thief:prints"},
	{"text": "The bung was set back on the keg. Rats don't do that.", "to": "thief2", "if": "qc:keg_thief:latch"},
	{"text": "Rats. They've gnawed the stores all down the chimney wall.", "to": "wrong", "if": "qc:keg_thief:gnaw",
		"do": "qp:keg_thief:wrong,qa:keg_thief,att:nan:1"},
	{"text": "The circles. Everyone knows your chalk.", "to": "thief2", "if": "!qc:keg_thief:prints,!qc:keg_thief:latch", "do": "att:nan:-1"},
```

The keep's report then has a `qp:keg_thief:wrong` choice and a `say_if` on `qc:keg_thief:latch` ("odd rats, that put the
bung back"), and the task's `outcome` and `alt` have a `wrong` key. **Writing a good one:** make `need` smaller than the
number of clues so what you read is a choice; give the false clue a good reason to be believed; give each strong clue a
line only it unlocks; always keep a way through for the player who read the weakest two.

**Saves.** The read keys are in the task's `f` dictionary (`"c:<key>"`). Nodes are rebuilt from state on load, read ones
without a glint.

## 2. `tracks` (follow a trail)

A list of marks, only the next of which exists. Within 4 m of it, the mark reads out and the one after is revealed;
the last ends the step, usually at a place where the next step is a `kill` / `slay` / `find`.

```gdscript
{"kind": "tracks", "r": 14.0, "label": "Father Harrow's trail",
	"text": "Follow Father Harrow's lantern-oil north from the fen graves into the reeds ({n}/{of})",
	"marks": [
		{"at": Vector2(56.0, 14.0), "text": "A drip of lantern oil on a grave-marker's lip, dried to a skin. Another, a long stride on, going north."},
		{"at": Vector2(58.0, -4.0), "text": "Oil again, and a bootprint pressed in it, the heel dragged..."},
		{"at": Vector2(60.0, -24.0), "text": "The drops leave the high ground here and go into the reeds..."},
		{"at": Vector2(60.0, -38.0), "text": "The oil ends. A lantern lies in the reeds ahead, and a man stands over it..."},
	]},
```

Fields. Step: `r` (the area round the next mark, default 14 m), `marks`, `label`, `text`. Mark: `at`, `text`, optional
`prop`.

**What the player sees.** The tracker points at the AREA of the next mark: a circle on the map and a waypoint that
hangs over the circle's centre and goes out at its edge. The centre is the mark moved a fixed way (from the task and
the mark's number: the same every time) by under half the radius, so the mark is inside the circle and never in its
middle. In the circle the mark is a glint (and a prop) in the open. Finding it reads its line, counts "(2/4)" and moves the
circle to the next. No interact key: walking up is enough.

**Saves.** `n` (the marks found) in the task; reset when the step moves on. The mark standing now is rebuilt from it.

## 3. `lantern_walk` (keep a light)

Carry a lit lamp from A to B. The step before it is a `find` whose pickup is the lamp lit at A (the `carry` pattern:
`from` names that pickup, and it has `step: <this step - 1>`).

```gdscript
{"kind": "find", "text": "Light a lamp at the green's fire for the Watchers' Spire"},
{"kind": "lantern_walk", "from": "spire_flame", "to": Vector2(-52.0, -100.0), "r": 8.0, "label": "The Watchers' Spire",
	"relight": "Light another at the green's fire.",
	"arrive": "You hang the lamp in the Spire's cradle. It takes. The sky turns slowly over it.",
	"text": "Carry the lit lamp up to the Watchers' Spire under the Crowns. Walk it: a run, a roll, a blow or deep water puts it out"},
```
(the pickup is `PICKUPS["spire_flame"]` with `kind: "lantern_lit"`.) Fields: `from`, `to`, `r` (default 5 m), `label`,
`text`; optional `time` (seconds, shown by `{t}`; out when it is up), `lost` (replaces the toast of any cause),
`relight`, `arrive`.

**What the player sees.** A small lit lamp at their hip. It goes out, with a line saying why, when they: sprint
(`Player.is_sprinting`, at speed, not merely the key), roll, dodge or parry (`Player.is_evading`), are hurt
(`Events.player_hurt`) or hollowed, or wade deeper than knee height (0.55 m of water over their feet). The first 0.6 s
after the lamp is lit forgive a blow or a roll already under way. Out: the task falls back one step to the lit-lamp
pickup, as a coal does: never a failure, never a dead end. Arrival within `r` ends the step and shows `arrive`. The map
and waypoint point at `to` exactly.

**Saves.** The step. The flame itself is not saved: carried across a reload, the lamp comes back lit.

## 4. `order` (a sequence puzzle)

Touch N things in the order a lore line or a conversation gave. The order is not shown anywhere in the HUD: the
objective text says where it was learned.

```gdscript
{"kind": "order", "at": Vector2(81.5, -19.0), "label": "The belfry's slates",
	"text": "Touch the three slates round the belfry in the order Brannoc taught you",
	"things": [
		{"key": "ferryman", "at": Vector2(86.0, -21.0), "prop": "slate", "name": "the ferryman's slate", "text": "The ferryman's slate hums under your palm..."},
		{"key": "choir", "at": Vector2(79.0, -23.0), "prop": "slate", "name": "the choir's slate", "text": "..."},
		{"key": "child", "at": Vector2(76.5, -17.5), "prop": "slate", "name": "the child's slate", "text": "..."},
	],
	"order": ["ferryman", "choir", "child"],
	"wrong": "The slate goes dead under your hand. The water has remembered. Something in it stands up.",
	"wrong_spawns": {"kind": "ossuant", "n": 1},
	"done": "Ferryman, choir, child. The belfry is quiet."},
```
and the order is in the offer text (`text` of the task): "...in the order they went under: the ferryman, then the choir,
then the child on the stair." Fields. Step: `at` (the place, for the map pin), `things` (`key`, `at`, `text` read when it
is right, optional `prop`, `name`, `verb` default "Touch"), `order` (keys; may repeat), `wrong` (the line on a wrong
touch), `wrong_spawns` `{kind, n}` (optional: an enemy script's name, how many, ~6 m round the thing; at most six stand
at once, and they are cleared when the step is over), `done`.

**What the player sees.** The things stand with a glint each; the ones already touched in the right order go dark.
Right: the line, and the next is waited for. Wrong: the sequence starts over (the lit ones glint again), the `wrong`
line and the foes. All right: `done`, and the task moves on. The map pin is the place (`at`), not a hint of the order.

**Saves.** `o` (how many are right so far) in the task; reset when the step moves on. The foes a wrong touch woke are
not saved (they were a reaction; on a reload there are none).

## 5. `vigil`

Stay within `r` of a place for `time` seconds. It is the `defend` node (`defend.gd`) without a ward: nothing stands
there to be hurt, only the wanderer who keeps the place, so the foes of its `waves` go for her.

```gdscript
{"kind": "vigil", "at": Vector2(44.0, 44.0), "r": 9.0, "time": 45.0, "gloom": 0.8, "label": "The Almonry's hour", "noun": "step",
	"prop": "loaf_circle",
	"waves": [{"at": 14.0, "kinds": ["wretch"], "n": 2, "say": "The hungry have smelled the loaf."},
		{"at": 30.0, "kinds": ["wretch"], "n": 2, "say": "More. They keep the Almonry's hours."}],
	"held": "The hour is out. The loaf is whole.", "away": "Go back to the step. A blessing is kept sitting down.",
	"text": "Sit out the Almonry's hour on its step, the loaf in your hands ({t} s)"},
```
Fields: `at`, `r` (default 8 m), `time`, `gloom` (Gloom a second while she keeps it, Player units, the bar is 100), `waves`
(as `defend`: `at` seconds kept, `kinds`, `n`, `say`), `label`, `noun`, `held` / `away` (the toasts), `prop` (marks the
place; none = nothing stands). **What the player sees.** The small frame at the top of the screen fills with the
time kept; the objective counts `{t}` down. The clock runs only while she is within `r`; leaving stops it (the toast
says so), nothing resets. Gloom rises while she keeps it (so a lit fire near the place helps, as anywhere), the waves
come out of the dark round the place. The clock out ends the step. **Saves.** The step; the clock restarts if the game
is reloaded mid-vigil (as `defend`'s does).

## 6. Remember (an outcome that changes later talk and props)

This was already there; the verbs add two things to it. The mechanisms, all generic:

* `qp:<task>:<pick>` in any dialogue condition (`if`, `say_if`, `start`, `avail`; village talk, the Keg, the offer
  screen): a choice the player made. Set it with the action `qp:<task>:<pick>` in a choice's `do`. `qd:` (done),
  `qat:<task>:<n>` (on step n) and `q:<task>:<n>` (at least step n) complement it.
* `qc:<task>:<key>`: a clue read (`clues` step), true for good, even after the task is done.
* `alt` {pick: {step: text}}: a step's objective text after a pick (see `keg_thief`).
* `outcome` {pick: text}: the line the ledger shows for the way it ended.
* `leaves` {pick or "": {at: Vector2, prop: kind}} (new): once the task is done a prop stands at `at` for the way it ended,
  with the key `""` for any ending. Built at load from the saved state, so a reload keeps it; a prop is any
  `quest_props.gd` kind. `drowned_bell` leaves a slate at the belfry. (`found_prop` / `stands` are the older, one-off forms.)

```gdscript
"leaves": {"": {"at": Vector2(84.0, -15.0), "prop": "slate"}},          # drowned_bell: whatever you picked
"leaves": {"truth": {"at": ..., "prop": "lantern_lit"}, "mercy": {"at": ..., "prop": "lantern"}},   # a pick decides
```
Props left by older tasks (the tongs, the mug, Oswin's staff) are hard-coded in `quest_world.gd`; new ones should use
`leaves`.

---

## The five demos (ids and rewards unchanged)

| Task | Giver | Verb | What changed |
| --- | --- | --- | --- |
| The Keg's Missing Ale (`keg_thief`) | the keep | `clues` + accusation | step 0: four signs behind the Keg, two read; Nan's and the keep's talk branch on what was read; a new `wrong` ending |
| The Slow Way Down (`slow_way`) | Ostrin | `tracks` | step 0: four marks of lantern oil from the fen graves to the lantern, was "search the fen" |
| A Lamp on the Spire (`spire_lamps`) | Fennick | `lantern_walk` | step 0 lights a lamp at the green's fire, step 1 carries it up, was "visit the Spire" |
| One Loaf, One Blessing (`alms_loaf`) | Nan | `vigil` | a new step 2: sit out the Almonry's hour on its step |
| The Drowned Bell (`drowned_bell`) | Brannoc | `order` + `leaves` | a new step 1: the belfry's three slates in Brannoc's order; the tongue's pickup moves to step 2 |

Step indices changed in `slow_way` (none), `spire_lamps` (+1), `alms_loaf` (+1), `drowned_bell` (+1), `keg_thief`
(none). Conditions in dialogue on `qat:` / `q:` of those tasks were checked: only the keep's and Nan's use them, on
steps that did not move.
