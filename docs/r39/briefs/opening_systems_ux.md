# r39 brief: opening, progression, systems, wholeness and UX

The owner (Luke) asked for this round in his own words. "Make each agent at least contribute 10 meaningful chunky things… massive features… in depth and end to end 100%". "Why are all agents done so soon, this is not in depth at all, this should take 10 hours". "Make at least 1000 word docs for each agent". This brief is the full spec for the opening/systems seat. Read it end to end before writing code, then work through it in order. Keep docs/r39/opening_backlog.md as your live checklist; it is how you will be resumed when your context runs out.

## Who you are and what you own

You are the game designer, systems designer and UX lead for Umbral Reaches. That is a Godot 4.7.2 GDScript open-world night RPG: one long night in a 740 x 548 m Realm, a wanderer with a lantern, fires to kindle against the Gloom, bells, five bosses and the Far Reaches towns.

You own:
- the opening (core/story/opening_shot.gd and the story.gd opening stage);
- the player camera and HUD, the world map, compass integration hooks, the guide, settings and title screen (ui/);
- progression: tiers.gd, levels, the Path/skills, gear curves;
- horse handling, stables, horse bond and hitching posts;
- fast travel (the Ember Road), camps and rest (camp_spot.gd, camp_rite.gd);
- the Count and the Chronicle (core/story/tally.gd, chronicle.gd, ui/tally_panel.gd);
- the night's days (days.gd), the Wayfarer marks and trail, photo mode, and save state for all of these.

You do NOT edit:
- quest definitions, dialogue, NPC casts or lore (the story/sound seat);
- realm geography, props, landmarks or world shaders (the world seat);
- atmosphere, lights, VFX or any posing/animation code (the light/animation seat).

When you need something from them, write it under "Cross-team needs" in your backlog file. The lead will route it.

## The bar

Luke's complaint about the last round was that it was wide and shallow. Several features were small, several were unfinished (no whistle-run, no stash, no courier runs, no charcoal map), and the whole round finished in under half an hour. The bar this round:

1. **Volume and variety.** A feature ships with enough content that a player meets it many times without repeating. That means many lines, many destinations, many variants. One example of each is not enough.
2. **End to end.** Logic, UI and prompts, keyboard and controller input, sound hooks (call the existing audio helpers or leave named hook calls the sound seat can fill), save state with versioned migration for old saves, and how the player is led to it. Every edge case: death, reload, fast travel, mounted, in a boss fight, in a menu, during the opening shot, in photo mode, during a camp.
3. **Polish.** No placeholder text, no "TODO", no debug prints left on, consistent wording in the game's voice (grave, plain, a little wry; see docs/STORY.md).
4. **Documentation.** For each feature, docs/r39/opening_systems.md gets: what it is, how a player meets it, which files, what to check in the engine, and any risk.

## No performance cost (Luke, 17 Nov: "remember this must be at no perf cost")

Every addition this round must cost nothing at runtime. The lead measures before and after each merge, using the play-capture regions tour: average and 1% low frame time, worst frame, draw calls and primitives per region, against the regions_a baseline (about 8.5 ms average, 118 fps at a 120 Hz vsync). Anything that regresses is sent back. In practice:

- **Bake, don't compute.** Detail lives in geometry and vertex colour built once at Realm build time (GenCache) or in shader terms that are already paid for. Nothing new is computed per frame.
- **Pay for what you add.** Added triangles come with LODs and visibility ranges, and are offset by lower far cost: impostors, merged meshes, MultiMesh. Added draw calls are offset by merging. The net count per region must not rise.
- **Lights.** No new shadowed lights. Unshadowed local lights only within the existing budget (the light pool/director), distance-faded. Far glow comes from emissive cards in one MultiMesh.
- **Behaviour.** Anything that updates (NPC acts, animals, weather, the score) runs at reduced rates by distance, sleeps off-screen and beyond range, and never allocates per frame.
- **Audio.** Sound is generated off the main thread and cached. Voices are capped. Nothing is decoded on the main thread mid-play.
- **No hitches.** Nothing is first-used mid-play without a warm-up behind the loading screen: no shader compile, no mesh build, no texture upload.
- **Never.** Dynamic resolution stays off, and main.tscn is never rebaked headless.
- **Document the cost.** Your doc states each item's cost, and how it is kept at zero.

## Workflow

- Work in your worktree (/Users/luke/UmbralReaches/.claude/worktrees/r39-opening). Run `git merge master` now and again before each big item: every team's work lands on master as the lead merges it.
- Do not run Godot, the editor or the tests; the lead runs all of those (the machine crashes under several Godot processes). Run tools/lint.sh after every item and fix what it flags. The ratchet fails on new `.call(`, `has_method`, private gets, and any file over 1000 lines, so put new code in new files.
- Commit after each item with a clear message. Never add Co-Authored-By or any AI or "Generated with" attribution, and never write "claude" in a branch name or message.
- Do not send a final report until every item below is done to the bar. When the list runs out, take the next most valuable item from docs/r39/1_opening_progression_systems.md and keep going.

## Backlog with acceptance criteria

### 1. The opening, finished

The Last Lantern exists; make it the best first minute in the game.
- A title-card moment with a music cue hook.
- Narration rewritten to the new canon: one answered bell opens the door, Aurel the Hierarch speaks through the night, and the drain beat comes from the story seat.
- A guided first walk from the shot to the first fire. Teach movement, the lantern, Gloom and kindling in-world, without cards where possible.
- A second variant for a New Game started after the ending (the Chronicle remembers).

Accept when: a new save goes from title to first kindled fire with no dead air, skipping works at every beat, and a second playthrough opens differently.

### 2. Horses, complete

- A whistle that makes your horse run to you along the ground, pathing round obstacles, never teleporting unless it is more than 300 m away or stuck.
- Saddlebags: a stash UI shared with the hitching post.
- Courier runs between posts: timed deliveries with rewards and a best-time board per route, at least eight routes.
- A horse race event at Hearthward.
- Stable upgrades (shoes, barding, a lantern on the saddle) that change speed, stamina or Gloom resistance.
- Interacting from the saddle: kindle, open and pick up.
- Horse care: feeding and resting at posts feeds the bond.

Accept when: a player has a reason to ride every night and the horse feels like a companion.

### 3. The map, complete

- A charcoal-sketch reveal of unseen ground, drawn in as you explore.
- Landmarks inked when seen.
- Region discovery banners.
- A legend and filters.
- Label de-collision.
- A controller cursor.
- The existing trail and marks kept.

Accept when: the map is a record of the player's own night.

### 4. Death and return with meaning

- Falling leaves your embers where you fell, as a glow on the compass and the map. Fall again before you recover them and they are lost.
- The fire charges a small toll on return.
- A short, quiet return sequence.
- Tied into the Count and the Chronicle.

### 5. Progression rework

- Level-ups offer a real choice between two or three perks per Path. Every perk must change how you play; no flat +5%.
- Review the skill tree and the gear item-level curve against the danger tiers, and write the curve down in the doc.
- Show recommended levels everywhere.
- Build an endgame loop after the Warden that ties into the Deeper Night.

Keep the standing decisions: rested XP, item level, gear sets, the five dailies and NPC babble all stay.

### 6. The night summary and the credits

- A summary screen at the end of each night or session: what you did, what changed, and the Count's highlights.
- An ending credits sequence that reads your Chronicle back to you.

### 7. Travel and tracking

- An Ember Road network screen listing every lit fire, its cost and its danger.
- Bell and peal progress in the journal.
- A clear "what next" in the guide at every story step.

### 8. Accessibility and settings

- Text size.
- Colour-blind telegraph palettes (coordinate the colours through the backlog's cross-team needs).
- Subtitle styles.
- Camera shake and flash toggles.
- Performance and quality presets.
- Controller remapping parity.

### 9. The UX pass

Go over every menu and HUD element for consistency:
- controller navigation everywhere;
- tooltips;
- empty states;
- discoverability of every feature added this round.

### 10. Save robustness

- Versioned migrations for every state key added this round: tally, chronicle, wayfarer marks and trail, horse bond and names, days and night_no, danger_warned, opening_seen, camp state, and the story seat's picks.
- A corrupted-save fallback that keeps the player's progress where it can.

### 11 onward

Then work down your critique's remaining items.

## What the lead will verify

The lead merges your branch, imports it, runs the full suite and films the features. So make each feature easy to reach: list a debug route in your doc (a save flag or a command-line switch already supported by the harnesses) if one exists. Name the exact checks: what to press, where to stand, and what should happen.

A feature that cannot be verified from your doc will be sent back.
