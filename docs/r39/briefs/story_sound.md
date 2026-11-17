# r39 brief: story, quests, NPCs, world meaning, fantasy and sound

The owner (Luke) asked for this round in his own words:
- "Make each agent at least contribute 10 meaningful chunky things… new quests, long quests… new NPCs… crazy features that make a person feel immersed… in depth and end to end 100%".
- "The story agent should do a full rework of sound, improve everything".
- "Why are all agents done so soon, this is not in depth at all, this should take 10 hours".
- "Make at least 1000 word docs for each agent".

This brief is your full spec. Read it end to end, then work through it in order. Keep docs/r39/story_sound_backlog.md as your live checklist, so the lead can resume you if your context runs out.

## Who you are and what you own

You are the narrative director and the audio director of Umbral Reaches, a Godot 4.7.2 GDScript open-world night RPG.

You own:
- quest data and logic (core/story/quest_db.gd and the quest_chains files) and the quest verbs;
- NPC casts, talk and routines (core/life/village/village_cast*, village_talk*);
- dialogue (dialogue_db.gd) and lore (core/world/realm/lore_db.gd and the readables);
- boss emotes (BossKit.emote) and boss themes, and Aurel's voice;
- the Chronicle's voice lines (core/story/chronicle.gd);
- every sound system: core/vfx/foley.gd, ambience.gd, core/npc/npc_voice.gd, boss_themes.gd, the enemy audio, the UI sounds, the bus layout, music and score.

You do NOT edit:
- realm geography or props (the world seat);
- lights, VFX or posing (the light/animation seat);
- UI layout or the opening camera (the opening/systems seat).

Place quest objects only through the existing quest-world helpers and POIs. List anything you need from the others under "Cross-team needs" in your backlog.

## The bar

1. **Volume and variety.**
   - A long questline has 6-12 stages across several places. It uses at least three different quest verbs (clues, tracks, lantern_walk, order, vigil, leaves, qc:). Its dialogue covers every stage and every choice.
   - Every sound has several variations and is never one sample on repeat.
   - Ambience changes by region, by hour of the night and by weather.
2. **End to end.**
   - Every quest:
     - can be started, progressed and finished in the game;
     - writes to the journal and the trail;
     - saves and loads at every stage;
     - survives death, fast travel and reload;
     - ends with a consequence the player can see: a place relit, an NPC moved, a door opened, a line changed.
   - Every sound plays in the game, at the right bus and volume, with no hitches. Generate audio off the main thread as the existing code does.
3. **Voice.** Grave, plain, a little wry, never modern. The register is in docs/STORY.md and LORE.md, and the canon is there too: eight road bells, the rim's three for the Order, one answered bell opens the door. Never contradict it.
4. **Documentation.** docs/r39/story_quests_npcs.md and docs/r39/sound.md say for each item: what it is, how to reach or hear it, its files, and what the lead must check.

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

- **Your branch.** Work in /Users/luke/UmbralReaches/.claude/worktrees/r39-sound (branched from your story work). Run `git merge master` now and before each big item: master has the light team's living night, the opening team's camp, Count, Chronicle, photo mode and horse bond, and the world team's landmarks.
- **No Godot.** Do not run Godot or the tests; the lead does. Run tools/lint.sh after every item and fix what it flags. The ratchet fails on new `.call(`, `has_method`, private gets, and any file over 1000 lines, so split new content into new files.
- **Commits.** Commit after each item. Never add Co-Authored-By or AI attribution, and never write "claude" anywhere.
- **Standing decisions.** The NPC babble voices, rested XP, item level, gear sets and the five dailies all stay.
- **Don't stop early.** Do not send a final report until every item below is done to the bar. When the list runs out, take the next most valuable item from docs/r39/2_story_meaning_fantasy.md and keep going.

## Part A: the sound rework (current task, go deep)

### A1. Mixing

- **Buses.** Lay out Master, Music, Ambience, World, Combat, Voice, UI and Stingers in default_bus_layout.tres.
- **Ducking.** Voice and stingers duck music and ambience. Combat ducks the ambience a little.
- **Master.** Put a limiter and a gentle compressor on Master.
- **Loudness.** Match loudness across every source.
- **Attenuation.** Give distance attenuation curves per category.
- **Occlusion.** Muffle sounds behind walls and indoors with a cheap ray or area test.
- **Settings.** A slider per bus.

### A2. A dynamic score

- **Layers.** Exploration, tension (an enemy near), combat, boss and aftermath, cross-faded by game state.
- **Motifs.** A motif per act and per region. The bell motif runs through everything and rises as fires are kindled.
- **Silence.** Use it on purpose, after a boss falls and at the eclipse.
- **Stingers.** For discoveries, level-ups, quest steps, a camp and a bell answered.

### A3. Ambience

- **Beds.** Every region and every interior gets its own layered bed: wind, water, insects, distant life and its signature sound.
- **Night hours.** The beds vary by hour.
- **Weather and the eclipse.** Weather changes the bed, and the eclipse silences the land.
- **New landmarks.** The world seat's landmarks get their own beds (the Sleeper's hollow, the Salt Ship's creak, the Chain Span's wind).

### A4. Acoustics

Reverb zones for interiors, caves, halls, the new landmarks and the open moor, blended smoothly at thresholds.

### A5. Foley

- **Footsteps.** Surface-aware for the wanderer, horses and creatures: grass, stone, wood, mud, water, salt, ash.
- **Movement.** Cloth and gear rustle, jumping and landing.
- **Objects.** Doors, chests, pickups, kindling, the camp fire.

### A6. Combat

- **Hits.** Weighty hits by damage school, plus crits, blocks and parries.
- **Wind-ups.** Telegraph wind-ups per enemy family.
- **Spells.** Each spell and staged cast.
- **Deaths.** Each family's death sound.
- **Visual effects.** Every hit-read visual effect gets a matching sound.

### A7. Creatures and bosses

Each enemy family gets a voice: idle, alert, attack, hurt and death. The five bosses get signature sounds per phase.

### A8. UI

Menus, the map, the Count and the Chronicle, the photo shutter, level-up, quest steps and the danger warning.

### A9. The other teams' features

The eclipse, moths, fog banks, the kindling surge, landmark beacons, the Wardens' Line towers lighting, the camp rite, the horse bond and the whistle.

## Part B: the story backlog

### B1. Regional questlines

A long questline for every region that lacks one. Each has 6-12 stages and real consequences in the world.

### B2. Readables

Books, letters, steles and graffiti placed through the world. They tell the history of the Order, the Hierarch, the bells and each region. Collect them in the journal; at least forty.

### B3. Barks and ambient dialogue

- **Reacting to the night.** Villagers comment on what you did: bosses, picks, kindled fires, the eclipse, your horse's name.
- **Reacting to you.** They react to your state: wounded, hollowing, at night's end.
- **Scenes.** They talk to each other in short scenes.

### B4. Named NPCs

Every named NPC gets a full routine, relationships and a favour or quest.

### B5. The ending

- **Epilogues.** A scene for each major pick combination.
- **The final walk.** A walk through the changed world.
- **Credits.** The text of the credits.

### B6. A recurring wanderer

A recurring stranger meets you at landmarks across the night, with a story arc of their own.

### B7. Deepening

Expand the four doors' payoffs, and give the Far Reaches' Outliers story weight.

### B8. Lore for the new landmarks

Readables and NPC lines that explain the Sleeper, the Hollow King, the Salt Ship, the Wardens' Line, the Chain Span, the Titan Gates and the roadside scenes.

### B9 onward

Then work down your critique's remaining items.

## What the lead will verify

The lead merges, imports, runs the full suite and the story audits (QuestChains.audit, DialogueDB.audit, story_test, act2_test, world_sound_test, boss_theme_test), then plays through and listens. Make each item easy to reach from your doc: where to go, what to say, what should happen, what you should hear.

An item the lead cannot reach from your doc will be sent back.
