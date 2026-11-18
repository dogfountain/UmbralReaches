# r39 brief: critique combat brutally, then fix it

Luke, 18 Nov: "Spawn another extra agent to fix combat."

You are that agent. You own how fighting feels and reads in Umbral Reaches, end to end:
- the player's side: the staff, bolts, spells, Rift Step, stamina, targeting, the camera in a fight, mounts in a fight;
- the enemies' side: every regular kind, the elites and rares, and the five bosses' fights (not their models);
- the feedback: hit-stop, flinch, knockback, telegraphs, sound cues, hit and death VFX, damage numbers, the HUD in a fight;
- the numbers: damage, health, poise, cooldowns, aggro ranges, pack tokens, scaling by level and by bosses felled.

Read this brief end to end. Then read:
- `AGENTS.md` and `docs/PILLARS.md`;
- `docs/r39/CRITIQUE.md` (its light and QA seats name combat faults: 1-2 px telegraph rings, a hurt wash that covers them);
- `docs/r39/boss_rework_plan.md`;
- `.cursor/skills/umbral-player`, `umbral-donts` and `umbral-nights`;
- the last fifty rows of `docs/DECISIONS.md`.

Keep a live checklist at `docs/r39/combat_fix.md`, with every finding, its evidence (a frame path, a log line or a code line), its fix and the commit. It is how the lead resumes you if your context runs out. This should take you many hours. Do not report until every finding is fixed, or plainly marked as not fixable with the reason.

## What is fresh, and what is not yours

**Fresh today**
- The five boss arenas grew 1.6x (DECISIONS.md, 18 Nov). Their fight radii, spreads and telegraph rings were scaled with them.
- The bosses were rebuilt in Blender with authored clips. ClipRig `boss_move(nm, dur, then)` plays a move then holds a looping clip; any clip ending `_hold` loops.
- Check that every boss move's telegraph, hit window and animation line up in time and in space at the new size. A ring scaled x1.6 on a move whose hitbox did not scale is a lie.

**Not yours** (other work is running in parallel; stay off these files)
- **World placement and level dressing.** A map-audit agent owns them in its own clone: `core/world/realm/*` layout, POIs, wayside, flora, lamps, the arenas' surroundings and terrain.
  - Where a fight is broken by the ground (an arena floor with a hole, a camp on a slope), note it in your checklist as "map audit" and move on.
  - You may change a spawn's fight parameters (aggro radius, pack make-up, leash), but not where things stand.
- **Regular enemy models.** Luke: "no regular enemies stay same for now". Do not remodel or re-skin them. Their animation timing, poses inside existing rigs, hit reactions and telegraph VFX are yours.
- **The boss models and authored clips.** Do not re-export boss GLBs. If a clip's timing is wrong, retime it in code (playback speed, `boss_move` duration, the hit frame) and log it.

## Where you work

- Your own APFS clone, on your branch: `/Users/luke/UmbralReaches_combat` (branch `combat-fix`). `cd` into it for every command, and work only there.
- Commit on your branch with plain messages. Do not push; the lead merges.
- Godot 4.7.2: `godot`. The import cache is already in the clone.

## The code (start here)

**Player**: `core/player/`
- `player.gd`, the controller;
- `player_casting.gd`, `staff_arts.gd`, `magic_bolt.gd`, `bolt_pool.gd`;
- `player_evasion.gd` (Rift Step), `player_targeting.gd`, `stamina.gd`, `player_vitals.gd`, `player_camera.gd`.

**Enemies**: `core/enemy/`
- `enemy.gd` (2352 lines: the brain, tokens, telegraphs, poise, death) and `attack_kit.gd`;
- each kind's script;
- `boss_kit.gd`, `boss_frame.gd`, `boss_title.gd`, `clip_rig.gd`, `pose_smooth.gd`, `enemy_status.gd`, `enemy_spawner.gd`, `rares.gd`;
- the bosses: `thornwarden.gd`, `bone_abbot.gd`, `ascended_warden.gd`, `hierarch_voice.gd`, `anchoress.gd`.

**HUD**: `ui/hud.gd` and its siblings.

**Combat harnesses already built** (use them before writing new ones)
- `zz/combat_duel.tscn`: a bare floor, a real Player, every kind and boss in turn, and the melee loop checks.
- `zz/combat_shots.tscn`: in-game frames through the real camera and grade, with `--at=x,z --set=pack|warband|r31|brood|boss_*`.
- `zz/combat_studio.tscn`: studio renders, with poses.
- `zz/combat_qa_test`, `combat_r31_test`, `combat_r33_test`, `floor_fight_test`.
- `zz/play_capture.gd` and `tools/play_capture.sh`: the real night.

## The critique: brutal, by role

Before fixing anything, play every fight through the harnesses and capture it:
- frame strips at 10-20 fps through the real camera, not single stills;
- logs of every hit: who, what, damage, poise, the frame it landed on against the frame its telegraph showed.

Read every frame at full size with the Read tool.

Write the critique into `docs/r39/combat_fix.md` from each seat below. Nothing is "fine". Be specific: the move, what is wrong, why it matters, and what good looks like (name the reference: Elden Ring, Enshrouded, WoW, Hades, God of War 2018, ...).

**Combat designer**
- Is every enemy kind distinct in what it asks of the player, or are they the same chase-and-swing with new skins?
- Do packs make interesting problems?
- Is there a reason to use every spell?
- Does the build (gear, staff arts, talents) change how you fight?
- Is there a skill ceiling?
- Are fights too long, too short, or spongy?
- Can you cheese bosses (pillars, leash, ledges, kiting at range)?

**Encounter and boss designer**
- For each of the five bosses: a readable phase arc, a signature move you remember, fair tells, punish windows, and arena use at 1.6x (do they use the new space, or stand in the middle?).
- Do the adds help or just pad?
- Does the fight start well (the pull, the title, the music) and end well (the death, the reward, the quiet)?

**Animator**
- Anticipation, contact and recovery on every attack, player and enemy.
- Hit reactions that read.
- No pops, snaps or foot-sliding in a fight (Luke: animation smoothing is critical; dt-damped blends, verified with frame strips).
- Deaths that land.

**Game feel / VFX**
- Hit-stop length per weight, camera shake, impact flashes, bolt trails, the sound of a hit landing against a miss.
- Is a crit or a stagger felt?
- Telegraph rings and cones: thickness, contrast at night, under the hurt wash, on slopes and steps.

**UX**
- Can a new player read who is targeted, who is about to strike, how hurt they are, why they died, what their cooldowns are?
- The lock-on and target cycling.
- The camera in a fight with a big boss, and against a wall or in a corridor (the Ossuary).
- Controller and keyboard both.

**Systems / balance**
- The damage, health and poise tables across levels 1 to cap.
- Danger follows bosses killed, not the player (CRITIQUE.md, Progression): is that right for combat, and if not, fix it.
- Rested XP, gear and stamina economy in a fight.
- Time-to-kill per kind at each tier.

**AI programmer**
- Pathing in a fight (stuck on rocks, circling on stairs, sliding off ledges).
- Leash and reset behaviour.
- Pack tokens (at most 2 attack at once).
- Aggro through walls.
- Enemies that stand still when they should flank.
- Ranged enemies that shoot through terrain.

**QA**
- Hitboxes that miss what they touch or hit what they don't.
- Damage on the wrong frame.
- I-frames that don't protect.
- Double hits.
- Deaths that don't count.
- Bosses that don't reset on the player's death.
- Errors in the log.

**Performance**
- Every hitch in a fight: first-cast shader compiles, VFX spawns, many enemies at once.
- Frame stutter is Luke's top complaint. Profile one big pack fight and each boss fight once.

## Fixing it

Then fix every finding, worst first, end to end. Luke wants features massive and finished, not "partly worked".

Make every fix first; then ONE re-capture pass of everything you fixed, read at full size, before you tick them (Luke, 18 Nov: "it only gets reshot after everything is fixed to save time and tokens").

Rules:
- **Perf:** zero perf cost. No new shadowed lights. Pool VFX and pre-warm every new material behind the loading screen (nothing compiles on first hit). MultiMesh for repeats.
- **Content:** never cut content. Make a weak enemy or move better, never delete it.
- **Assets:** in-house assets only. Painted 2D icon art for any icon (the in-house kit), never glyph shapes.
- **Never:** never enable dynamic resolution. Never rebake `world/main.tscn`.
- **Code:** typed calls, not `.call("name")` or `has_method` (the lint ratchet fails CI on them). Run `tools/lint.sh` (seconds) any time.
- **Godot convention:** signals through `Events`, groups through `Groups.*`, feature folders (AGENTS.md).

Tests, Luke's standing rule (18 Nov):
- Do not run the test suite or test batches while you build.
- The harness runs that show you a fight are how you see, so use them freely. The `zz/*_test` suites are not.
- Only when every fix is in, run the tests once: `tools/run_tests.sh --quick`, then the world tests that cover what you touched (`combat_duel`, `combat_qa_test`, `combat_r31_test`, `combat_r33_test`, `floor_fight_test`, `boss_test`, `enemies_r34_test`, `raids_r34_test`, `crypt_r34_test`). Then fix what they find.
- Never loosen a test without saying why in the commit.

## Machine rules

- **Locks:** one Godot and one Blender process on the machine at a time, shared with the lead and the map-audit agent.
  - Take `mkdir /tmp/umbral_godot.lock` (retry every 30 s while it exists) around every Godot run, and `/tmp/umbral_blender.lock` around every Blender run.
  - `rmdir` the lock when the run ends, also on failure.
  - Never wait with a pgrep loop.
  - Keep each Godot run short (a few minutes), so the map audit gets its turns.
- **Scratch:** use `/private/tmp/claude-501/-Users-luke-UmbralReaches/10dbc585-c502-4f27-b1e3-a047668e1104/scratchpad/combat/`.
  - Keep the before/after strips of fixed fights and delete the rest as you go (the disk filled once).
  - Never write captures into the repo's `shots/`.
- **Commits** come only from Luke: never add a `Co-Authored-By` line or any AI attribution.

## Report

Only when the checklist is done, report:
- your branch and commits;
- the critique's headline findings by seat;
- what you fixed, with before/after strip paths;
- what you could not fix and why;
- what you handed to the map audit;
- the tests run and their results.
