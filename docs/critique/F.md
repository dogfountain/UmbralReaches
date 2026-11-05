# Critique F: the world, the interface, robustness (r29)

Agent F. Lens: level layout and readability, stuck spots and collision holes, every area, secrets and
the Ossuary; every UI screen at every window size; save/load integrity, log errors and warnings,
quit aborts, leaks at exit, the export. Severity: S1 breaks or looks broken, S2 clearly hurts, S3 polish.
Status: FIXED (by F), REG (in register.md for its owner), OPEN (noted, not acted on).

All runs used an isolated HOME (scratchpad/critF/home*), never Luke's save or settings.

## Tools written for this pass

- `zz/realm_sweep` drops the wanderer on a grid across the Realm (step 6-8 m; `--deep` tests
  every walkable layer of a column: bridge decks, the Ossuary's tiers, the Lower Count) and drives
  4 directions from each drop: FELL (settled under the surface it stands over), STUCK (can't move
  0.25 m any way), VOID (no surface in bounds), OUT (left the bounds / below the kill height).
- `zz/ui_shot -- --size=WxH` every UI screen (HUD, 4 settings tabs, Satchel, Kindling, Journal, Map,
  Tasks, dialogue, shop) at one window size, with a fit report (off-canvas controls, text under 11 px).
  `--canvas=` / `--settings-layer=` reproduce the old layout for before/after shots.
- `zz/robust_test` damaged settings.cfg, a save with a checkpoint over nothing, every brazier's
  respawn point, the settings menu's tabs and key list. `zz/storage_save_test` gained nested-garbage
  and erase-then-quit checks. `zz/probe_point` now also lists every surface straight down.
- `scratchpad/critF/run_suite.sh` runs any list of zz tests, each in a fresh HOME with a cap, and
  collects every ERROR / WARNING line per test (the "log scanner").

## Findings

(filled in below; see the end for what is still open)

### S1: breaks, or looks broken

1. **The Deeper Night rebuilt a third of the world missing.** FIXED. NG+ (`begin_deeper_night`)
   reloads the night with Travel.go into the same scene, so the Realm is built a second time in
   the same process. `WorldLanes.sites` is static and was never cleared (the r28 "Open" note):
   `register_site` dedupes by name, so the first build's rects stayed and the second build's lore
   saw every spot as taken by itself. Second build: 57 of 92 inscriptions, 41 of 96 sites, 6 of 9
   lights; skipped all road waystones, mileposts and lamps, three barrows (the Barrow Field
   name-slate for "Names for the Yard"), Thornwood's relics, field walls, the woodcutter's hut, the
   cart. Fix: `Realm.reset_registries()` (sites, lanes, portals, floor cache, build progress), called
   from world/main.gd `_exit_tree`. New `zz/rebuild_test` builds twice and compares: all equal now.
   Evidence: scratchpad/critF/logs/rebuild.log (before), rebuild3.log (after).
2. **A respawn point under the ground.** FIXED. `Brazier.spawn_point()` was a fixed +0.3 m, 1.8 m
   in front of the bowl. The Threshold brazier (fen, below the Ossuary's fen door) sits on a rising
   slope: its point was 0.59 m UNDER the terrain (y -0.5 vs ground 0.09). Kindle it, then hollow or
   relaunch, and you are put inside the ground. Now the point is dropped onto the ground under it,
   trying the other three sides if the front is a wall or nothing (zz/robust_test checks every
   brazier).
3. **A save could strand you in the void.** FIXED. The checkpoint is restored blindly at boot: a
   save from an older layout (a brazier that moved: Landing was moved twice) or a damaged one put
   the wanderer over nothing, falling to the kill height and respawning at the same point forever.
   Zone now checks the saved point once the night is built: if it is over nothing or inside a solid
   it first tries the ground right there (older saves of the Threshold point), else the spawn
   brazier, and says so in the log. zz/robust_test: a checkpoint at (400, 3, 400) wakes at the
   Sanctuary.

### S2: clearly hurts

4. **Erase Saved Progress did not stick.** FIXED. The night carries on after an erase, and the
   next save (any kindle, the timer, or the save-on-quit) wrote the running night's fires,
   checkpoint, story and systems straight back. Travel now refuses to save for the rest of the
   session after an erase; the button says "Erased: the next launch starts anew"; its confirm
   lapses after 4 s so a later stray press cannot finish it. storage_save_test checks it.
5. **A damaged save or settings file threw script errors.** FIXED. Travel checked only the top-level
   type of each [progress] value: an item count of "12" or {}, a checkpoint that is a String or
   INF, a relic id that is a number, `hollows = "many"` all reached typed code. Every value is now
   checked as it loads (kindle lists cleaned, counts clamped 0..999999, checkpoints must be finite
   and in range, flags normalised). Settings: wrong types and out-of-range indices (window size 9,
   AA 99, shadow -3, preset 12, NaN blur, "wide" FOV, volume 3.0) indexed tables and assigned
   Strings to floats; every field is now typed and clamped. storage_save_test +8 checks,
   robust_test 8 settings checks.
6. **Settings were not written atomically.** FIXED. `cfg.save(PATH)` straight over the file: a quit
   mid-write left half a settings.cfg. Now temp + rename, like the save.
7. **Closing Settings unpaused the world under another menu.** FIXED. Opened over the Kindling, a
   dialogue, the shop or the Journal (each pauses the tree), Close set `paused = false`, and the
   night ran on behind the open menu. It now restores the pause state it found. And Esc over an
   open menu now closes that menu instead of stacking Settings on top (F2 / Start still open it).
8. **Every banner drew over Settings.** FIXED for Settings (layer 50 -> 70, above the other menus'
   59-62, under the travel fade 80). The same banners over the dialogue box and the Tasks ledger:
   REG to:C. Shots: critF_ui_1280x720_settings_0.png (before), critF_ui720_settings_1_after.png.
9. **At 1280x720 all UI text was two thirds size** (the 1920x1080 canvas scaled 0.67: 15 px labels
   drew 10 px, the pace note 8.7 px). FIXED: windows under 864 rows get a 1600x900 canvas (text
   20 % larger, every panel still fits: Kindling, the Journal (1280x760) and the shop measured).
   Settings fonts also +1-2 px. The HUD's hint line then overran the right edge: REG to:B (B has
   since wrapped it in 3 lines). Shots critF_ui720_{settings_1,settings_3,kindling,journal}_{before,after}.png.
10. **The Controls page listed the wrong keys.** FIXED. A hand-written list with no dodge roll, lock
    on, Kindling or Tasks, "Skills LMB RMB Q F C" (the lance is also R) and no controller column.
    Now built from the live InputMap: keyboard/mouse and pad for every action, so it can't drift.
11. **Tooltips were the only explanation, and pads can't see tooltips.** FIXED. A hint line under the
    tabs shows what the focused (pad/keys) or hovered (mouse) option does; the pages scroll to the
    focused control (`follow_focus`); B closes Settings on a pad.
12. **Lambda capture errors** ("Lambda capture at index 0 was freed") from timer lambdas that
    capture a node freed before the timer fires: twice in secrets_test, once in the double build.
    REG to:A with the candidate list (enemy/boss/progression timer lambdas).
13. **story_test FAILs 2** (keep's hub/news text vs its test). REG to:C.
14. **A Barrow Field camp was silently skipped** ("camp at (101, 60, -50) skipped (inside site
    secrets_barrow)"). FIXED on F's side: the barrow's site rect was +-5 m, the kerb stones need 4.2;
    now +-4.6 and the camp plants.

### S3: polish

15. **No interface sounds** (D's entry). FIXED for Settings: new `ui/ui_sound.gd` (synthesised
    move / tab / confirm / back / tick, SFX bus, plays while paused, no statics). REG to:A, to:C to
    hook their menus.
16. **The Sexton died in 3-5 s** (A's entry): spawn_elite takes `hp_min`; the Sexton has 60 HP.
17. **No Music volume.** Settings has a Music bus + slider (Audio tab); REG to:D to put
    scape_music.gd on it (it plays on Ambience today).
18. **Reset to Defaults kept the anti-aliasing mode.** FIXED (aa_mode = 0).
19. **GenCache wrote its files in place**: a quit mid-write (exports write user://realm_cache) or
    another game process reading the same res:// cache (six agents at once) could see half a file.
    FIXED: temp + rename for .res and .bin; an empty/short .bin is skipped and rebuilt.
20. **AreaStreamer retried a failed area every 0.25 s** (error spam, a leaked node per try). FIXED:
    one error, the area stays unloaded, the node is freed.
21. **Leaks at exit in every run**: "2 RID allocations of type DummyShader leaked" (dwarf.gdshader
    and realm_ground via statics), 3-30 ObjectDB instances, "8 resources still in use",
    AudioStreamWAV/Playback still playing, orphan StringNames. Exit code is 0 everywhere
    (quit_probe exit 0 with all modules). PARTLY FIXED: `Realm.release_caches()` (world/main.gd
    _exit_tree) drops the meshes/materials/shapes F's builders keep in statics (mage statue, gothic,
    realm assets, RockKit, TreeGen, MeshChunks, GenCache shapes, OssKit, Ossuary): "resources still
    in use" and the shader-constant orphans are gone; what is left is audio (REG to:D) and two
    shader RIDs (REG to:C, dwarf_look).
22. **The zone title card and the region banner appear at the same moment** on arrival. REG to:C.
23. **Hotbar skill names ~7 px at 1280x720.** REG to:A. **HUD hint line stays up under menus.** REG to:B.
24. **`_respawn_now` teleports without resetting interpolation** (a streak on every respawn). REG to:B.
26. **Prompts always named the keyboard key** ("[E] Kindle the brazier" with a pad in hand). FIXED:
    Settings tracks the device last used (`using_pad`, `input_device_changed`), and
    Interactable.prompt_key() names the pad button. REG to:B for the HUD hints / hotbar glyphs.
25. **Legacy zz/audit FAILs 2 on the Realm henge** ("thornwarden: no floor at (-62.9, 7.7, -12.7)",
    "floor varies 4.51 m"): the arena circle (r 12.4) takes in the head of the henge stair. Play is
    fine (the stair is walkable); realm_audit does not run arena audits. OPEN (audit.gd is the
    stair-era audit).

### Checked and sound

- **Sweeps:** the whole Realm on a 7 m grid (716 drops before the time cap), the rift and
  Crossing on 6 m (293 ok), the east strip on 7 m (155 ok): no STUCK, no VOID, no OUT. Every FELL
  of the first run was a slide down a steep slope (the north mountains, the rift walls), which the
  probe now tells apart. One real drop: the slot between the Ossuary chapel's east wall and the
  hill (21, -103) reaches -10 m; lava at its foot throws the wanderer back to the last safe ground,
  so it is not a trap.
- **Deep sweeps** (every walkable layer, 3 m grid): the Crossing, the ward landing, the summit
  platform and the dais 433/433 ok. The Ossuary, its gallery, the Lower Count, the Weighing Floor
  and the lift shaft 413/417 ok: three "stuck" drops are sealed pockets UNDER the pit floor
  (y -6 and -16 at (22, -78) and (22, -72)), unreachable unless dropped in by the probe, and one
  1.6 m slide under a ledge lip. No collision holes found anywhere.
- **The export:** `--export-pack Linux` builds (219 MB, was 193 MB at r24) and the pack runs
  headless: Realm built in 4.3 s, BOOT_DIAG 0 FAIL, no errors in 45 s. Not installed in the app.
- **quit_probe** exits 0 with all modules.
- The save is atomic (temp, read-back, .bak), loads old saves, keeps unknown keys; corrupt main
  falls back to .bak (existing storage_save_test, still green).

### Late additions (answers to register entries)

27. **Stick Sensitivity** in Controls (B's entry): Settings.stick_sensitivity, saved, clamped,
    applied to the player by Zone. Rebinding is not done (answered in the register).
28. **The Controls list's pad column** follows B's new bindings (Kindling on D-pad right, L3
    latches the sprint, no pad button for the stats overlay).
29. **Buried Lower Count meshes cast into the moon's shadow map** from the hub (E's entry): 32
    meshes wholly under the chapel floor no longer cast; renders of the Weighing Floor before/after
    are identical (shots/critF_deep_shadow_before|after.png).

## Tests (isolated HOME, 16:50 suite after the fixes)

All pass: check, robust_test (new, 22 checks), rebuild_test (new; passes standalone, its suite row
was a parse error of mine fixed mid-run), storage_save_test (+8 checks), realm_audit,
realm_land_check, realm_rift_walk, realm_walks, realm_lore_test, persist_test, secrets_test (73;
its two lambda errors are gone), secret_expansion_test (60; the barrow camp warning is gone),
trav_realm, move_course 26, boss_test, progression_test, village_test, encounters_test, quest_test,
story_test, lore_codex_test, quit_probe (exit 0), skill_test, combat_duel, life_test,
world_react_test, lanewalk. enemy_kin: 1 FAIL ("chanter: shrouds a packmate", A's, REG).

Performance: nothing F changed runs per frame except one bool check in Zone._process and
Settings._input per input event; the 1600x900 canvas applies only to windows under 864 rows
(not Luke's fullscreen). No render-side change, so no A/B needed.

## Still open

- Banners over menus/dialogue, banner timing (C); hotbar/HUD text size and pad glyphs (A, B);
  `_respawn_now` interpolation (B); music bus routing and audio leaks at exit (D); dwarf shader
  statics (C); timer-lambda captures (A); UiSound hooks in the other menus (A, C).
- The legacy zz/audit henge arena note (S3). The pack is 219 MB (+26 MB since r24); the lead
  should run `storage_cache -- --prune` before packing.
