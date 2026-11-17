# The sound rework (r39-sound)

Luke: "the story agent should do a full rework of sound, improve everything". Everything is in-house procedural synthesis (the
same approach as the existing code), rendered on worker threads, cached through GenCache, never built on the main thread. The NPC
babble voices are untouched (a standing decision). Nothing here was run in the engine by its author; the lead's checklist is at
the end. New code is under `core/audio/`; existing files got small, additive edits.

## What was audited

Existing and kept: `Foley` (footsteps by surface, hooves, cloth, beds), `Ambience` (region beds, spots, reverb rooms, the master
compressor and limiter, the Voices compressor, the indoor low-pass, dialogue/pause ducks), `ScapeMusic` (the generative lyre, pads,
heartbeat, relief), `BossThemes` (three composed themes), `EnemyAudio` (22 rendered voice sets, hits by material), `StaffSfx`,
`Synth`, `UiSound`, `Sfx` (the 24-voice 3D pool with a stacking limiter). The gaps the rework fills: no tension / combat /
aftermath layers, no hour-of-night variation, a fixed handful of interface tones, no sound for the new night features, no
occlusion, no rooms for new interiors, two bosses without a theme, nothing for the landmarks.

## 1. The shelf (`synth_kit.gd`, `cue_bank.gd`)

A small instrument shelf (partials with glides, bells, plucks, band-passed noise, thuds, choirs, horns) and a data-driven bank of
about 85 cues, each rendered in three takes (pitch nudged +-4.5%, notes 7% early or late, noise reseeded) played round-robin, so a
frequent sound never repeats. Long set pieces (bosses, eclipse, camp, stingers) have one take. Rendering is one worker task started
by the Soundstage; cached bytes load from disk on later runs; a cue not yet rendered is simply not played. Bump `VERSION` in
`cue_bank.gd` when `synth_kit.gd` changes (the cache salt hashes only the file that calls GenCache).
Groups: `ui_*` (open, close, page, map open/close/pin, deny, buy, equip, unequip, toast, Count, Chronicle quill, photo shutter,
slider), world (door open/close, chest, pickup, rare pickup, ash, kindle breath, beacon, camp begin/end, horse bond and nicker,
landmark hum), night (eclipse approach / totality / return, moth flutter, fog breath), combat (hurt light / body / heavy, parry
ring and spark, block, crit shimmer, school colours ember / umbral / light, kill flourish, wind-up tells, a broken cast, the gloom's
heartbeat, dodge cloth, soft land, gear clink), story (quest step, three stingers), small life (three birds, owl, shutter, chime,
rockfall, bones settling, stone tick, wind gust), and the five bosses' intro / phase / death.

## 2. The cue router (`cue_router.gd`)

One place where events become sound (no gameplay script grew an audio call, except where noted):
blows (crit, school, kill), the wanderer's hurt (three tiers, under the library take), parry / dodge / riposte, enemy wind-up tells
(bright when interruptible, low when not) and the snap of a broken cast, a kindled fire's breath, a beacon tower's horn (a name with
"beacon" or "spire"), pickups and ash, quest steps, every boss's intro / phase turn / death and the stinger after it (the act's bell
peal for the story's three, a plainer one for the rest), being hollowed, the Gloom tide, the gloom's heartbeat past 80%, the eclipse's
three cues, moths at the fire you stand by, fog breathing over the fen, a door when you cross into a room (tavern, hall, cave,
crypt), the camp rite's settling pad and its dawn bell, and by hour and region the small things (dawn chorus after 90% of the night,
owls in the late hours, a shutter or far chime in the village, rockfall on the heights, bones in the crypt, gusts).

## 3. The dynamic score (`score_stems.gd`, `score_director.gd`)

ScapeMusic stays the night's melody; the score is its orchestra, on a new `Score` bus under Music. Eleven looping stems (tension,
combat floor, combat heat, aftermath, three act beds, dusk, late hours, dawn, the ending's bed) and eight motifs (five region
families, three act motifs: the bell motif rung bottom to top in acts I and II and top first in act III, the way the bells stopped).
States: explore (the act's bed at a whisper by the hour), tension (a hostile within 45 m), combat (blows in the last five seconds, then
the heat layer by how many), aftermath (22 s after the last foe falls), rest (by a lit fire), boss (the theme takes the floor),
silence (after a great one falls, after being hollowed, in the eclipse's totality: every stem steps back and the Music bus is ducked).
All five bosses now have a theme (`boss_themes.gd`: the Anchoress and the Speaking Crown). Region motifs play every 70-120 s in
explore, never over tension or combat.

## 4. The mix (`mix_director.gd`, `occlusion.gd`, `acoustic_zones.gd`, Settings)

New buses `UI` (under SFX) and `Score` (under Music), each with a slider (Settings > Audio: Score, Voices, Interface; the Voices bus
Ambience already made now has its slider). A gentle compressor on SFX and a slow one on Music. Named ducks on Music and Ambience
(a dB, a hold, a release; the smallest request wins; stingers, the eclipse, the Gloom tide, a beacon use them). Occlusion: one ray
from the camera per one-shot (six a frame at most): a hill or wall in between costs 3-7 dB and darkens the sound (the voice's
low-pass drops to 1.6 kHz). Rooms: `hall`, `cave`, `crypt` reverb presets and muffles, a `moor` open-air preset (heath, moor, downs,
cairns, barrow heath), and `AcousticZones.register(aabb, room)` for any builder (the Wardens' towers and the Hollow King's hollow
register themselves). Three new soundscapes: the Chapel (the First Hearth's crackle), the Ring (a low stone hum), the Tally (drip).

## 5. The night's hours and the eclipse (`soundstage.gd`)

Once a second the beds' multipliers follow the night clock: the insects thin as it gets late and cold and return at dawn, the wind
rises, a dawn chorus lifts the meadow bed in the last tenth; the eclipse hushes insects, meadow and leaves, steps the music back,
and plays its own three cues.

## 6. Landmarks (`landmark_voices.gd`)

Each landmark has a twelve-second bed that fades in within ~85 m (hermit caches 40 m; three at once at most): the Sleeper breathes,
the Hollow King groans, the Salt Ship's planks work, a Wardens' tower hums and ticks, the Chain Span's links tick, a Titan Gate holds
one chord, a hermit's pole chimes. Found as the group `world_poi` (meta `wonder`); position is the centre of their meshes' bounds.

## 7. Interface

Menus keep their quiet tones; the richer cues replace them as soon as they have rendered (the UiSound kinds `map_open`, `map_close`,
`count_open`, `buy`, `equip`, `unequip`, `deny`, `toast`, `page`, `pin`, `shutter`, `chronicle`, `open`, `close`, `slider` fall back to
the old tones until then). Wired: the world map, the Count, the shop, the gear panel's upgrade / reforge (success equips, failure
denies), the photo shutter, the Chronicle's quill (every new line), a lore scrap's page turn, a chest's creak, a horse's bond.

## Where to hear it

Walk the green at dusk (dusk bed, shutters); kindle the four fires (the rising bell phrase from the story branch, now with each fire's
breath); stand by a lit fire (moths); start a fight (tension, then the war drum, then the snares as it heats; the aftermath after);
fight a boss (intro, phase cues, death, stinger; the Anchoress and the Crown have their own themes); wait for the eclipse (about the
middle of the night: three cues, a hush, silence in the totality); walk the fen (fog breath); walk to the Chapel (the hearth's
crackle), the Ring (the hum), the Barrow Field (the drip); stand by the Sleeper / Hollow King / a Wardens' tower; make camp; buy a
horse and ride (bond cue); take a photo; open the Count and the map; open a chest.

## What the lead must check in the engine

1. `zz/sound_rework_test` (new; also in the quick tier) and `zz/boss_theme_test` (now 5 themes): render times, seams, no NaN.
2. Hitches: the cue worker renders ~255 takes and the stems ~19 loops and motifs on first run (a few seconds on one worker thread);
   later runs read the cache. Watch frame time during the first minute and while the Soundstage first plays a cue.
3. Level: the score and the new cues against the existing mix (`--sfx-trace` lists one-shots); the `hurt_*` cues sit under the
   wanderer's own hurt take; the Score slider at its default 80%.
4. The new sliders appear and persist (Score, Voices, Interface) and the buses `UI`, `Score` exist before the Ambience builds.
5. Occlusion does not darken sounds on open rolling ground too often (it counts any world-layer hit between you and the emitter).
6. The Wardens' tower and Hollow King rooms: the reverb and muffle change as you step in; the landmark beds find their centres.
7. Eclipse: the three cues line up with the moon course; the score falls silent in the totality.
8. `ScoreStems` loops: no click at the seam in the combat and hour stems.

## Cost, and how it is kept at zero (Luke: "this must be at no perf cost")

| Item | Cost at runtime | How it is kept down |
|---|---|---|
| Cue bank (~90 cues x 3 takes) | none on the main thread; one worker task at load, memory about 6 MB | rendered on a worker, cached through GenCache (later runs just read bytes), a cue not yet rendered is not played; `CueBank.play` makes one pooled-style player per cue and frees it on `finished` |
| Score stems (11 loops, 8 motifs) | memory about 7 MB; one worker task at load | same; a stem below 1.2% level is stopped, so at rest 1-2 players run; stems start at a random offset |
| ScoreDirector | a 1 s enemy scan (the same scan ScapeMusic does every 0.5 s), then a few float moves per frame | no allocation per frame; the scan reads the ENEMY group once a second |
| Cue router | signal handlers only; a 0.25 s tick for the boss phase, eclipse, room, small-life and moth checks | moths rescan braziers every 8 s; details run every 14-32 s; all throttled by `_gate` |
| Occlusion | at most 3 rays per physics frame, only for a one-shot more than 6 m away, world layer only | budget per frame; a spent budget means "open" |
| Landmark voices | up to 3 looping 3D players within 85 m; a 2 s tick; a rescan every 12 s | beds fade out and free past range; the bounds are cached in the host list |
| Mix director | two AudioEffectAmplify and two compressors on buses; a per-frame float move for the ducks | no allocation |
| Hour variation | one small dictionary assignment a second | none |
| Buses | five new buses (UI, Score, World, Combat, Stingers) | empty buses cost nothing; the SFX and Music compressors are the only DSP added |
| The bus layout | `default_bus_layout.tres` (Master compressor + limiter, the sends); Settings and Ambience only add buses the file lacks | no runtime cost |

## Creature voices by family (`family_voices.gd`, wired in `EnemyAudio.say`)

The library takes (art/audio/enemy) stay the voices. For fifteen ordinary families the rework adds a procedural layer under the library take for each of
idle, alert, attack, hurt and death: 120 cues, three takes each (360 takes), rendered by the cue bank's worker and cached; played through the shared 3D
pool (capped, 34 m culled, occluded) at 19-26 dB under the cue's own level so it thickens a voice rather than doubling it. It is called from
`EnemyAudio.say` after a take has played, so it inherits that function's per-enemy and per-set rate limits and voice cap: no new timers or scans.
Families and their character: **hollow** (a breathy moan), **gaunt** (a dry rasp), **husk** (a low grunt), **bulwark** (a deeper, heavier grunt),
**gurgle** (a wet bubbling throat), **leaper** (a high rising screech), **chanter** (a held chanted vowel), **tollman** (a tolled iron note), **quiller**
(a quill rattle), **ossuant** (bones knocking), **crawler** (a skitter of ticks), **burrower** (a scraping drag), **shade** (a whispering swell),
**cinder** (a crackle and a sigh), **brood** (a chittering swarm). Bosses keep their phase cues (`boss_<id>_intro/phase/death`, fired by the router on
engage, on each phase turn and on death). **Cost:** none on the main thread; the render is
part of the cue worker's one-time job.

## Sound coverage audit (fifth wave)

Every `Events` signal and gameplay action was walked; those without a sound now have a cue (three takes each, through the cue bank, router-driven):
climbing (`grab_clink`, `vault_whoosh`, `mantle_grunt`, hooked in `player_traversal.gd`), wading into water (`wade_splash`), landing (existing `land_soft`), respawn (`respawn_breath`),
seals (`seal_tick` on progress, `seal_break`), the Ember Road (`fire_whoosh` and the toll's `toll_grains`), a status taken on (`status_buff` / `status_debuff`, wanderer only),
a night turning (`night_turn`), the credits told (`stinger_credits`), a denied cast (`ui_deny` via `skill_failed`), a world event's warning (`event_warn`), the horse whistle. Already covered
elsewhere: map open/close, the Count, the shop, level choices, quest steps, camp, kindling, pickups. There is no stash, crafting or swimming in the game (pools are waded), so none was invented.

## Interior beds (`interior_beds.gd`, `acoustic_zones.gd`)

`AcousticZones.register(aabb, room, label)` now carries the zone's bed name. Standing in a zone fades in its twelve-second loop (non-positional on the Ambience bus, so the outdoor muffle
does not touch it): **hall**, **cave**, **crypt**, **tower** (Wardens' towers: wind in iron, a fire's tick), **hollow** (the Hollow King's hall), **heart** (a furnace's slow pulse),
**hold** (a ship's timbers and water), **nave** (a held chord and drips). A builder registers a zone with the label it wants; one without a bed of its own gets its room's. The reverb room (hall,
cave, crypt) and indoor muffle are Ambience's. **Cost:** one non-positional player; a 0.5 s zone lookup over the registered boxes; the worker renders eight loops once.
**Check:** the world seat's interiors (Sleeper's heart-hall, the ship's hold, a cathedral nave, the Wardens' halls) call `AcousticZones.register` with these labels when they land; until then only the Wardens' towers and the Hollow King's hall register (from `landmark_voices.gd`).
