# r39 brief: light, the night's look, VFX and animation

The owner (Luke) asked for this round in his own words.

On the round itself:
- "Make each agent at least contribute 10 meaningful chunky things… new animations… crazy features that make a person feel immersed… in depth and end to end 100%".
- "Why are all agents done so soon… this should take 10 hours".
- "Make at least 1000 word docs for each agent".

On light:
- "No it's not brighter night, it's brighter landmarks with fire lights, mysteries etc, with darker moon".

On animation:
- "Give another agent animation smoothing, this is extremely critical".

This brief is your full spec. Read it end to end, then work through it in order. Keep docs/r39/light_backlog.md as your live checklist; it is how the lead resumes you if your context runs out.

## Who you are and what you own

You are the lighting director, VFX lead and lead animator of Umbral Reaches, a Godot 4.7.2 Forward+ open-world night RPG.

You own:
- global lighting: core/world/atmosphere.gd, light_director, light_policy and the grade;
- the living night: core/world/night_life/ (signatures, mystery lights, windows, moon course, eclipse, moths, fog banks, hit reads, telegraph glow);
- all VFX and telegraphs;
- every posing and animation system:
  - the wanderer's rig (character_rig.gd, posing only);
  - the enemies' rigs (HunchRig, QuadRig, ClipRig, VillagerBossRig, BeastRig, pose_smooth.gd);
  - villager and dwarf posing (villager.gd, villager_idle.gd, villager_fidgets.gd, npc_life.gd, dwarf_npc.gd);
  - horses' and wildlife posing.

You do NOT edit:
- mesh-building functions, landmarks, props or terrain (the world seat owns the meshes of villagers and bosses);
- quests, dialogue or sound (the story seat);
- the UI or the opening camera (the opening seat).

The direction is fixed. The moon is darker and the land stays dark. Never lift global fill, ambient or the grade to brighten the frame. Landmarks, fires, windows and mysteries are the bright things, and they read from afar.

## The bar

1. **Smoothness first.** Every pose system blends with frame-rate-independent damping. That means crossfades on every mode or act change, springs for impulses, interpolation between ticks and between low-rate updates, slerp for rotations. No pop, snap, step, jitter or foot skating at 60, 120 or 144 Hz. Use the PoseSmooth you built.
2. **Volume and variety.**
   - Many acts and idles, so villagers never look alike.
   - Animals with real behaviour.
   - A sky that changes from night to night.
   - Weather that changes the world.
   - A VFX language that covers every spell, enemy family and boss phase.
3. **End to end.**
   - Wired into the night's systems.
   - Edge cases: indoors, fast travel, bosses, reload, the Living Night setting off.
   - Settings where it matters.
4. **Performance.**
   - No hitches (frame stutter is Luke's top complaint).
   - No shadowed lights at scale.
   - Emissive cards and the existing light budget.
   - No per-frame allocations.
   - Never dynamic resolution.
5. **Documentation.**
   - docs/r39/light_animation_vfx.md and docs/r39/animation_smoothing.md say, for each item: where to see it, what to film, the cost, and the files.

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

- **Worktree.** Work in /Users/luke/UmbralReaches/.claude/worktrees/r39-anim. Run `git merge master` now and before each big item; the lead merges your branch as you go.
- **No Godot.** Do not run Godot or the tests; the lead does, and films your motion with frame strips at 60 and 144 Hz.
- **Lint.** Run tools/lint.sh after every item and fix what it flags. The ratchet fails on new `.call(`, `has_method`, private gets, and any file over 1000 lines.
- **Commits.** Commit after each item. Never add Co-Authored-By or AI attribution, and never write "claude" anywhere.
- **Don't stop early.** Do not send a final report until every item below is done to the bar. When the list runs out, take the next most valuable item from docs/r39/4_light_visuals.md and keep going.

## Backlog with acceptance criteria

### 1. Villager acts you didn't build

- **Work:**
  - sweeping;
  - carrying sacks and water;
  - chopping wood;
  - mending nets.
- **Children:** playing tag and hiding.
- **The Keg:** a fiddler and a dancer.
- **Watch and graves:**
  - a watchman's round with a lantern;
  - a mourner at the graves.
- **Social:**
  - people greeting each other;
  - people waving at the wanderer when he has done right by them (read the regard state);
  - sitting conversations with gestures.

Each act blends in and out smoothly and runs at the low update rates without stepping.

### 2. Animals with behaviour

- **Dogs** follow villagers, bark at enemies and hide during the eclipse.
- **Cats** sit on roofs.
- **Birds** scatter from the wanderer.
- **Crows** gather at graves and boss arenas.
- **Horses** wander in paddocks.
- **Owls and bats** react to light.

### 3. The wanderer's life

- **Idles by place:** cold, firelight, rain.
- **Attention:** he glances at nearby landmarks and NPCs.
- **Breathing,** and catching his breath after a sprint.
- **The lantern** rises in the dark.
- **Low health:** an injured gait.
- **Turning:** smooth turn-in-place.

### 4. A full sky

- Constellations and shooting stars.
- Clouds lit from below by the fires.
- Aurora nights.
- Moon phases across the nights, tied to the saved night_no.
- The eclipse's sky.

### 5. Weather

- **Rain:**
  - wet surfaces and puddle glints;
  - drips and lamp halos;
  - fires that hiss.
- **Dawn:** mist mornings.
- **Wind:** gusts that move grass, trees, cloth and fires.
- **Storms:** distant lightning lighting the landmarks.
- **Selection:** weather picked per night and saved.

### 6. A VFX library

A readable visual effect at night for:
- every spell and staged cast;
- every enemy attack family;
- every boss phase.

Plus:
- status effects on the player and on foes;
- pickups and level-ups;
- the kindling.

### 7. Interiors

- Every enterable interior is lit by its own fixtures, warm and readable.
- Light transitions smoothly at doors.

### 8. The wanderer's lantern

- It matters at night: its light radius ties to the Gloom.
- It flickers and swings.
- It can be raised.

### 9. Boss arenas

Each of the five gets its own lighting design and atmosphere (fog, colour, set-piece lights) that changes per phase.

### 10. Palette

- A subtle grade per region.
- The grass and foliage palette fix.
- The far-leaf dither fix in realm_foliage.gdshader.

### 11 onward

Then work down your critique.

## What the lead will verify

- **Motion.** The lead merges your branch, imports it, runs the full suite, then films every animation item at 60 and 144 Hz as frame strips. It looks for pops at act changes and stepping at distance.
- **Light.** It captures every light item at night from near and far and compares frame time to the regions_a numbers.
- **Your doc.** For each item, give what to film, where, and what good looks like.

Anything that pops, steps or hitches is sent back.
