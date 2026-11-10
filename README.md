# Umbral Reaches

A short, dark, solo action RPG built in Godot 4.7 (Forward+, GDScript). The sky is draining out of a valley; you are the wanderer who carries light into it. One night, one connected world, played on foot or, for now, on horseback.

Read `docs/PILLARS.md` first, then `AGENTS.md` and `ARCHITECTURE.md`. Decisions are logged in `docs/DECISIONS.md`.

## What it is now

- **The Realm.** A procedural valley round **Hearthward**, the last warm village: the Pilgrims' Road, the Thornwood and Thorn Henge, the Hollow Fen and the Barrow Field, the Ashen Rift and the Ossuary, the Crowns and the Summit of Ascension, and seven far countries (the Holds, the Quarry, the Moor, the Founder's Pits, the Cinder Orchard, the Waiting Field, Corvin's Mere). Hand-built landmarks, generated land, flora and lore, a living village and wildlife, weather, a day-less night.
- **Gloom is the dark's clock.** Away from light it rises; at the top a shade forms and hunts you. Light you made or reached (braziers, fires, bells you have rung) is the only rest.
- **Wounds are your health.** Take too many and you are Hollowed back to your last kindled fire; fires and the Kindling are where you recover.
- **Spells are taught by the story.** Bolt, lance, nova, ward, step and the rest come from people and places, not a skill tree; you choose which four you carry.
- **Three bosses.** The Thornwarden (Thorn Henge), the Bone Abbot (the Ossuary) and the Ascended Warden (the Summit). Solo fights, each with its own composed theme.
- **Acts I to III.** Act I: the two keepers. Act II: the founders' peal, gathered from the far countries' bells. Act III: the Warden and what is left on the latch. Quests, factions (the Rooted, the Kindlers, the road folk), the Kindled Watch on the roads, roaming events and the Gloom tide push the night along.
- **Character.** Gear with item level and sets, charms, relics, rested XP, and a Kindling tree spent with grave ash.

## Run it

| You have | Do this |
| --- | --- |
| Godot 4.7.x editor | Import `project.godot`, press F5 |
| macOS app | Packed by `tools/pack_mac.sh` (a Linux `.pck` placed in the `.app`; see `.cursor/skills/umbral-pack`) |
| Command line | `godot --path .` |

Needs a GPU with Vulkan, Metal (through MoltenVK) or Direct3D 12. First load builds the Realm and warms shaders behind a loading screen.

**Controls** (`autoload/input_setup.gd`; remappable keys are listed by the pause menu):

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move / look | WASD or arrows / mouse | left stick / right stick |
| Sprint / jump / slide | Shift / Space / Ctrl | L3 / A / B |
| Interact | E | X |
| Bolt / Lance | left mouse / right mouse | RT / LT |
| Nova / Ward / Step | Q / F / C | RB / LB / Y |
| Staff strike (tap light, hold heavy) / Guard | G / X | RT up close / slide held, locked on |
| Dodge | V | slide when slow or locked |
| Lock on | middle mouse | R3 |
| Character (gear, charms, relics, staff) | Tab or I | d-pad up |
| Gear | O | |
| Kindling | K | d-pad right |
| Journal / Quests / Map | J / L / M | d-pad down / left |
| Call your horse | H | |
| Settings / free the mouse | F2 or Esc | Start |
| Grade / stats / render scale / fullscreen | F1 / F3 / F4 / F11 | |

## Build, test, pack

```sh
godot --headless --path . --import --quit            # import after a fresh checkout
tools/run_tests.sh                                   # every zz/*_test.tscn, headless, isolated HOME; fails on SCRIPT ERROR / Parse Error / FAIL
tools/run_tests.sh r36_world critD_sound             # just the named tests
godot --headless --path . --export-pack "Linux" "/tmp/Umbral Reaches.pck"
tools/pack_mac.sh "/path/to/Umbral Reaches.app"      # tests, export, copy into the app, sign ad hoc, touch
```

User args go after `--`: `--realm-modules=land,flora`, `--save-dir=PATH`.

Do not headless-rebake `world/main.tscn` (it drops MultiMesh data). Bake and export traps are in `.cursor/skills/umbral-pipeline`.

## Project layout

```
autoload/      Events, LightGrid, InputSetup, Settings, Travel
core/player/   Player (controller) + CharacterRig (skin) + bolts
core/skills/   SkillBook and the spells
core/items/    ItemDB, gear, EquipmentPiece wearables
core/enemy/    Enemy kinds, bosses, EnemySpawner
core/world/    Zone shell, interactables, Tavern, arenas; realm/ = the procedural world;
               mount/ horses, watch/ the Kindled Watch, roam/ roaming events, night/ the act and faction state
core/life/     progression, village, wildlife, secrets, encounters
core/story/    story director, quests, dialogue
core/npc/      the Keg's dwarves
core/vfx/      FX and procedural audio
core/util/     Groups, Layers, ProcMesh, save_dir
ui/            HUD, menus, character screen, loading screen, fonts/Cinzel (OFL)
world/         main.tscn + main.gd (the night), areas/ossuary
zz/            tests and probes
tools/         bakers, generators, run_tests.sh, pack_mac.sh
docs/          PILLARS, DECISIONS, LORE (canon), STORY (how it is wired), THE_NIGHT (the critique)
```

## The v0.1 look measurement

The original atmosphere prototype was checked against a palette target on its demo screenshots. These numbers are the v0.1 measurement (one zone, four braziers), kept as the reference for the look, not a statement about the Realm today.

| Shot | Coloured pixels in 200-290 deg | Median brightness | Near-black |
| --- | --- | --- | --- |
| Sanctuary | 99.9% | 0.180 | 42% |
| Stair foot, brazier lit | 94.4% | 0.180 | 45% |
| Mid-stair (between lights) | 99.9% | 0.118 | 61% |
| Landing, brazier lit | 91.1% | 0.114 | 61% |
| Summit, brazier lit | 94.6% | 0.227 | 29% |
| Gazing into the rift | 98.0% | 0.247 | 32% |

The mid-stair ran darker than the 0.18 target on purpose (that is where Gloom presses in).
