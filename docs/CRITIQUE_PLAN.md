# Critique and hardening pass (r29): six agents

Luke: "Critique every single point in the game, even things outside the named areas, then act on
the issues: harden, improve, optimise, deepen, error-handle. The game must be smooth and beautiful."

Six agents, each with a lens that owns a set of files. **Every agent critiques the whole game as a
player would (anything it meets, anywhere), not only its own lens.** Each agent fixes issues in its
own files; issues it finds elsewhere go into the shared register for the owner, and owners must act
on or answer every entry addressed to them before they finish.

## Lenses and ownership

| Agent | Lens (critique + fix) | Owns |
|---|---|---|
| **A Combat** | enemies, bosses, encounters, skills, staff, cores, combos, progression, items, balance and difficulty curve, readability of every attack and spell, hit feel | `core/enemy/*`, `core/life/encounters/*`, `core/skills/*`, `core/player/magic_bolt.gd`, `bolt_pool.gd`, `core/vfx/{spell_fx,vfx,synth,staff_sfx}.gd`, `core/life/progression/*`, `core/items/*`, `ui/{hotbar,growth,satchel,combo_readout}.gd` |
| **B Player & controls** | movement, traversal, camera, animation (wanderer), input and rebinding, controller support, game feel, the first minutes of play (onboarding, prompts) | `core/player/*` except A's files, `autoload/input_setup.gd`, `ui/hud.gd` |
| **C Story & people** | NPCs (looks, faces, animation, voices), dialogue writing and flow, quests and their logic, village and tavern life, lore writing, the Journal, the opening and ending | `core/npc/*`, `core/life/village/*`, `core/story/*`, `core/world/tavern.gd`, `core/world/realm/lore/*`, `ui/{dialogue,shop,quest_log,codex}.gd` |
| **D Life & sound** | wildlife, weather, night phenomena, ambience and music, the mix and levels of EVERY sound in the game (spells, enemies, UI, footsteps, voices), audio buses and settings | `core/life/wildlife/*`, `core/world/ambience.gd`, `core/vfx/sfx.gd`, `art/audio/*` |
| **E Visuals & performance** | shadows (the "weird shadow lines" Luke sees), lighting, materials, terrain and flora shaders, the colour grade (keep its r21 intent: not duller), sky, fog, anti-aliasing quality, VFX quality, LOD and culling, frame pacing, hitches, memory, the loading screen and its warm-up | `core/world/{atmosphere,light_policy}.gd`, `world/post/*`, `world/realm/*.gdshader`, `core/world/realm/flora/*`, `core/world/realm/realm_flora.gd`, `core/world/realm/realm_land*.gd`, `core/vfx/motion_blur.gd`, `ui/loading_screen.gd`, `core/debug/*`, `zz/perf_*` |
| **F World, UI & robustness** | level layout and readability, stuck spots, collision holes, falling through, secrets and the Ossuary, the summit and every area; every UI screen (settings, satchel, shop, menus, prompts, fonts, layout at all window sizes); save and load integrity, error handling, log errors and warnings, crashes, export/packaging | `core/life/secrets/*`, `world/areas/*`, `core/world/*` not owned above (zone, realm modules, braziers, seals, arenas, streamer, glimmers...), `ui/settings_menu.gd`, `autoload/{settings,travel,events}.gd`, `world/main.gd` |

Shared seams: small additive edits with the Edit tool only, never whole-file rewrites; leave other
agents' marked sections alone. `world/main.tscn` is never rebaked (F owns main.gd, not the scene).

## Method (every agent)

1. **Critique first.** Play the game through the harnesses (zz/move_*, zz/skill_shots,
   zz/look_shots, zz/perf_tour, zz/smooth_probe, zz/loading_shot, quest/secret/world tests, your own
   new probes), read the logs, look at renders and filmstrips, measure. Write
   `docs/critique/<agent>.md`: every issue found, anywhere, each with where, what is wrong, why it
   matters, a severity (S1 breaks or looks broken, S2 clearly hurts, S3 polish) and the evidence
   (screenshot path, log line, number).
2. **Register.** Issues outside your files go into `docs/critique/register.md` as one line each:
   `- [ ] to:<agent> S<n> <where>: <issue> (from <you>, evidence)`. Check the register for entries
   to you at least every hour of work and before you finish; mark them `[x] fixed` or
   `[~] answered: <why not>`.
3. **Act**, worst first: fix, harden (null and validity checks, guards against freed nodes, no
   errors or warnings in the logs, safe fallbacks), optimise, deepen. Before/after evidence for
   every visible change (`shots/<agent>_<what>_before|after.png`).
4. **Smoothness is a hard requirement:** no hitches, no frame over budget at Luke's settings
   (Cinematic, 120-144 Hz, fullscreen), no 60 Hz stepping in anything that moves on screen, no
   script or shader errors in any run.

## Rules (binding; see also AGENTS.md)

- Godot 4.7.2, typed GDScript. No `class_name` in new scripts. GenCache for generated data.
  Never rebake `world/main.tscn`. Keep the wanderer's identity (robe, void face, staff in hand_r).
  Keep the r21 colour direction (deep blue night, protected warm lights, not duller). Glow budget
  and AA: AA is now a player option (Settings.aa_mode); don't force it on.
- **Never touch Luke's save or settings:** run every Godot process with
  `HOME=/private/tmp/claude-501/-Users-luke-UmbralReaches/188e5aff-c3ac-4f51-b6e2-f43e7856ac71/scratchpad/crit<X>/home`
  and hold `Travel._busy = true` in new tests.
- Make every test and tool quit by itself (a real-time cap). Never leave Godot processes running;
  never pkill Godot; kill only your own PIDs. `rm` only explicit full paths. No commits, no branches.
- Performance budget: hub stress fps no worse than now (A/B in alternation; other agents render at
  the same time); scripts within +0.1 ms; <= 900 draws, <= 1.5 M primitives; life_test < 500 us.
- Keep every test green (the full list is in docs/HANDOFF.md r28 and the zz/ folder). Add tests for
  what you fix. zz/quit_probe must exit 0 (no abort at quit).

## Report (each agent, at the end)

The critique's top findings and what you did about each, everything you changed (player-facing
first), register entries you answered, tests and results, before/after numbers and shots, and
what is still open.
