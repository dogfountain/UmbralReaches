# Story and sound backlog (r39-sound branch): resume from here

Tick as done. Each item: committed, lint clean, doc entry in docs/r39/sound.md or docs/r39/story_depth.md.

## Sound (the rework)
- [x] synth kit, cue bank (~70 cues), score stems + director, mix director, occlusion, acoustic zones, cue router, hours, landmark voices
- [x] S1 variants: several takes per cue (pitch / timing / seed jitter), round-robin without repeats
- [x] S2 ambient details by hour and region (dawn chorus, shutters, chimes, rockfall, bones settling, owls)
- [x] S3 combat depth: hurt by tier, dodge / roll / land cloth and gear, parry variants, spell-school variants, death flourishes by family
- [x] S4 creature signatures: per-family idle / alert murmurs layered under the bank takes (distance-aware)
- [x] S5 score depth: motifs per act and region, more stems (dusk, night, dawn), the ending's score, stingers
- [x] S6 reverb zones: registered halls for each new landmark interior; moor / cave presets tuned
- [x] S7 docs/r39/sound.md (every change, where to hear it, what the lead must check)

## Story backlog
- [x] B1 a long questline for each region that lacks one (6-12 stages, world consequences)
- [x] B2 readables placed through the world (books, letters, steles, graffiti), collected in the journal
- [x] B3 barks and ambient dialogue (villagers comment on deeds, state, time; talk to each other in scenes)
- [x] B4 (favours for Col, Wenna, Pell/Nan, Grisel; Late Ringer; the five; routines already exist for the rest: more favours welcome) every named NPC: daily routine, relationships, a quest or favour
- [x] B5 the ending: epilogues per pick combination, a final walk, credits text
- [x] B6 a companion / recurring wanderer NPC who meets you at landmarks
- [x] B7 the four doors expanded to their payoffs; the Far Reaches' outliers given story weight
- [x] B8 lore for the new landmarks (Sleeper, Hollow King, Salt Ship, Wardens' Line, Chain Span, Titan Gates, roadside scenes)
- [ ] B9+ continue down the critique (docs/r39/2_story_meaning_fantasy.md)

## Cross-team needs
- The world seat: landmark hosts should keep the group `world_poi` and meta `wonder` names (TheSleeper, HollowKing, SaltShip, WardensTower*, ChainSpan, TitanGate_*, HermitCache*) so landmark voices and readables find them.
- The lead: re-run the Realm cache bake once (the story outposts' near lists are read by the flora keep-out).

## Third wave (lead's order)
- [x] 1 default_bus_layout.tres (Master compressor + limiter; Score, World, Combat, Voices, UI, Stingers, AmbOut); the runtime builders only fill gaps. Voices stays the one creature-voice slider.
- [x] 2 per-family creature voices (15 families x idle/alert/attack/hurt/die x 3 takes), wired in EnemyAudio.say; family wind-up character on every tell
- [x] 3 every named person has a task (seven new favours); audit table in story_depth.md
- [x] 4 barks name only real ids; static check in zz/sound_rework_test
- [x] 5 horse whistle and nicker; Wardens' beacons heard through their toasts; boss phase cues verified to fire on `phase` change; Late Ringer's sixth station
