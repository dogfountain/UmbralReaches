# Umbral Reaches — handoff to Claude Code (local)

State as of **r17** (local session 2026-11-03, not yet deployed or committed). Godot **4.7.2**
Forward+, Jolt, typed GDScript. Read `AGENTS.md` and `ARCHITECTURE.md` first; `.cursor/rules/` are binding.

## Hard rules (from Luke)

- **Never headless-rebake `world/main.tscn`.** Everything new is built at runtime by scripts.
- Do **not** restyle: the hub stair, the spawn/sanctuary textures, or the player robe.
- No anti-aliasing. Glow budget is fixed — don't add bloom or raise glow.
- Keep tests fast; use headless checks first, renders only when a visual matters.
- `rm` only explicit full paths, never `./*` or globs.
- Luke runs git himself; don't commit unless asked.

## Open

- **Playtest r16 in motion.** Everything below was verified headless and in still renders only:
  lava crust drift, swells and fall motion, and the Warden fight on the new dais, are unplayed.
- The summit dais is lit only by the player's lantern; it may want braziers (within the glow budget).
- The master-plan doc (Claude Docs artifact) is behind r15/r16. Sizes, terracing and the dais aren't in it.
- `zz/walk.tscn` is listed below but does not exist (only `walk.gd`); give it a scene or drop it.
- Playtest the tavern: dwarves are only verified in stills and short frame sequences.
- `shots/` is large (about 13 MB per full-size render, plus two survey folders). It probably
  belongs in `.gitignore`.

## Systems pass (r22, in progress: docs/SYSTEMS_PLAN.md)

- **Storage:** 85 textures VRAM-compressed (BC1/BC7 colour, BC5 normals; grayscale + 2 noisy
  normals kept lossless), summit GLBs drop their unused embedded textures (~100 MB VRAM). Texture
  VRAM 986 -> 777 MB; .pck -37 MB like-for-like. export_presets: include `art/realm_cache/*.bin`
  (was missing: exports rebuilt tree data and summit hulls on first run), exclude zz/, shots/,
  build/ and unused-asset candidates. GenCache: salt manifest `_salts.bin` (exports reject stale
  entries), `gen_script` per entry, `report()` / `prune()`. **Before exporting:**
  `godot --headless --path . res://zz/storage_cache.tscn -- --prune`. Save: atomic temp+rename,
  `.bak` fallback, unknown keys preserved, old saves load (fixture zz/fixtures/). Tools:
  zz/storage_mem, zz/storage_cache, zz/storage_save_test. Unused candidates (not deleted): the old
  dwarf GLBs + textures (~41 MB), gothic_bay/toad, duplicate mossy_platform/summit_pillar images.
- **Combat:** HunchRig poses, ground telegraphs (danger_zone shader), hit-stop/poise/stagger,
  2-attacker pack tokens, boss phases with a notched bar, far more detailed enemy/boss bodies with
  per-kind skin maps (GenCache). Tests: zz/combat_duel (79 checks), boss_test 27/27.

- **Lore:** Journal/codex (J, d-pad down; own file user://codex.cfg, cleared by Erase Save),
  reading panel, region banners, 86 writings / 7 series, carved/thatched/timbered landmarks
  (lore_assets.gd, GenCache). Tests: zz/realm_lore_test, zz/lore_codex_test.
- **Movement + main character:** generated wanderer gear (wanderer_gen/tex/piece/staff.gd, the
  old robe GLBs unused by default, `DefaultLoadout.use_legacy` for A/B), ground model, stair
  stepping, foot IK, camera probe, `teleport()` + auto-reset on external jumps > 2 m.
  Test: zz/move_course (13/13).
- **Story + tavern NPCs:** 15-bone DwarfRig with detailed generated meshes/textures
  (dwarf_mesh.gd, dwarf_look.gd), clearances fixed, dialogue box (ui/dialogue.gd), quests and
  objective line (core/story/*), opening and ending. Travel.story. Test: zz/story_test.
- **Optimisation:** occlusion culling on (kit + terrain occluders), Atmosphere.post_build (chunks
  big no-LOD meshes, shadow/particle ranges), LightPolicy.realm_pass, Settings.detail per preset
  (Performance ~2x Balanced). zz/perf_tour: --stress, --census, --attrib, --path-only.
  Lead follow-up: summit moss rocks cast no shadows -> summit 1.41 M -> 0.89 M prims.
- Lead: boss_test/ingame2 find the Satchel CanvasLayer (the wanderer now has a "Satchel" node).

## Critique and hardening pass (r29, docs/CRITIQUE_PLAN.md, docs/critique/A-F.md + register.md)
Six agents critiqued the whole game through six lenses, logged cross-area issues in
docs/critique/register.md (42 entries: 36 fixed, 3 answered, 3 small ones open), then fixed their own.
- **A combat:** the grade had turned every red blue: telegraphs and HP bars are now ember
  (2.6, 0.55, 0.1) with per-kind hues (lime Chanter sigil, teal acid, bone Abbot); danger_zone draws
  its outline through grass and slopes (depth test with a 1.4 m allowance); strikes land on the frame
  the red fills; boss HP 72/90/120 (kill 16-28 s), elites x1.5; boss zones owned by their caster
  (BossKit.zone by:self); Burrower can't be stranded; Tether breaks tells; pulls limited to +-3 m;
  east_way and the Barrow Field camp populated. zz/critA_probe, critA_harden, critA_color_shot.
- **B player:** roll-into-wall crouch lock (stand-up uses _headroom; crawl under low ceilings);
  FOV kick / strafe roll / landing dip / lance charge visuals / cloth inputs no longer step at 60 Hz;
  robe drapes over the forward knee (robe_skin hip/knee uniforms 11-14); fall-out and unstuck
  rescues; mouse captured on first show; a four-line controls card (device-aware, hides in menus,
  fades); first-time tips; pad sprint latch, look curve, Kindling on D-pad right; queued toasts;
  surface footsteps. move_course 26, zz/first_minutes.
- **C story:** Nan's inverted attitude condition, Pell's unreachable line, post-ending lines for six
  people, Abel's stuck greeting, the keep's free "nothing new", Grisel's useless oil; tavern windows
  one-sided; hat brims tilted off faces; portrait jaws follow the words; escort can be set aside
  (qx: action); Journal map shows braziers, Keg and task rings; ending survives a quick quit.
  zz/critc_talk_dump, critc_quest_edges, critc_npc_tour.
- **D life & sound:** master limiter (-0.5 dB) and same-sound ducking; music +12 dB on its own Music
  bus; rain +7-10.5 dB, storm clouds (storm_veil.gdshader); mist banks keep home hollows; frogs and
  crows audible; moving groups glide every frame between logic ticks; wildlife script time 447-545
  -> ~307-342 us (logic/draw split, culled redraws, GPU frog throats, weather ~40 Hz); Sfx skips
  sounds past 36 m and steals the oldest voice. zz/critD_levels, critD_mix, critD_lifeprof.
- **E visuals:** the shadow lines were moon PCSS acne + the near split boundary under the feet:
  bias 0.06, normal bias 2.5, near split 7.5 m on High (LightPolicy._moon is the only place now);
  a 9-px upscale grid at 1080 output (bilinear 960 -> 1080 sharpened by the grade) now FSR 1;
  brazier flames were white sheets (unshaded ALBEDO) and are fire; the grade keeps saturated lit reds
  and warm fire cores; leaves dither out within 1.6 m of the camera. zz/perf_lines; perf_tour --luke
  really runs 1920x1080 again, --reps, --moon, --rs. Luke's settings.cfg has shadows Off.
- **F world/UI/robustness:** NG+ rebuilt the Realm with a third missing (WorldLanes.sites never
  cleared): Realm.reset_registries/release_caches on exit, zz/rebuild_test; the Threshold respawn
  was under the terrain; a checkpoint over nothing now snaps to ground; Erase Save holds for the
  session; type-checked saves and settings, atomic settings writes; Settings restores the previous
  pause and draws over banners; 1280x720 gets a 1600x900 canvas; live Controls page with pad
  column; Music slider, Stick Sensitivity, UI sounds (ui/ui_sound.gd). zz/realm_sweep, ui_shot,
  robust_test.
- **Lead:** the opening narration waits for the loading cover (Story._after_cover).
- Suite: 34 tests, all pass (world_react_test re-checked at 307 us). Pack 215 MB.

## Expansion pass (r28, docs/EXPANSION_PLAN.md): six agents
- **A combat & enemies:** pack AI in enemy.gd (call/howl, flank/guard/support roles, retreat when
  hurt, Nova back-off, Ward siege), wretch rake combos + feints ("no red, no hit"), husk slam and
  charge, leaper tail sweep, spitter lob + acid pool, tells cancelled by heavy hits/poise breaks
  (core/enemy/attack_kit.gd). New kin (by path, no class_name): bulwark.gd (shield breaks, circle
  it), chanter.gd (sigil, shroud, slips away), burrower.gd (tunnels), mite.gd (swarms of 5).
  Camps moved (5 had been silently skipped) and added: 15 camps / 47 slots; tiers.gd pools. Bosses:
  BossKit.transition on every phase; Bone Abbot crozier sweep + phase 3 "Requiem" (phase_marks
  [0.5, 0.25]). Synth creature voices (7 families x tell/hurt/die/call/flee), mass knockback, pack
  broken beat. Husk-based elites also get slam/charge (Old Sunk's slam is off). Test zz/enemy_kin.
- **B skills, staff & progression:** every rank adds behaviour; new learned spells Rift Tether,
  Umbral Well, Bound Shade; loadout swap at fires (bolt fixed on LMB); staff cores (Prism split,
  Lodestar chain, Cinder burn, Rime chill/freeze) change the orb and bolt; 7 named combos with a
  readout (ui/combo_readout.gd); build charms incl. E's quest charms (charm_ferrule, charm_waystone,
  charm_chalk); Kindling "Now / With II" cards, Staff and Loadout pages. 19 more StaffSfx kinds.
  Test zz/skill_test (a partial --only run always fails "combos seen >= 6": judge the full run).
- **C movement & animation:** planted-foot gait with 2-bone IK (stride, duty and lift by speed;
  strafe/backpedal), legs 0.40+0.40 (merged body re-keyed in GenCache), lean, hood spring, air
  poses, hard landing crouch/roll, idle actions. Traversal: ledge grab/shimmy/climb, vault, wall
  kick, steep-slope slide, beam balance. Lock-on (MMB / right stick), dodge roll (V; slide button
  when slow or locked), casting while running (chest twists to 65 deg). Camera: jump damping, lead,
  thin occluders ignored. Cast poses for tether/well/familiar. Tests move_course 21, zz/trav_realm.
- **D exploration & secrets:** the Lower Count under the Ossuary (oss_deep.gd: sexton's slab after
  the Abbot, Uncounted Cells, count-wheel puzzle raising a bone bridge, the rotating Count Drum with
  a mirror light puzzle (secrets/beam.gd), the Weighing Floor arena with "The Sexton", a called lift
  back up (oss_lift.gd), a belfry beacon when the hoard opens). New secrets: Singing Stones
  (site_glade.gd), Ash-Hermit's Perch (vent ride), the Ninth Company story scenes (lore/scenes.gd).
  Journal Map tab; completed stories pay 20 ash. Test zz/secret_expansion_test. **Fixed the exit
  abort** (exit 134, "recursive_mutex lock failed", Luke's crash dialogs): secrets kept engine
  resources in static vars; director._exit_tree releases them. zz/quit_probe -- --realm-modules=...
  bisects any future one. AnimatableBody3D sync_to_physics: set position BEFORE add_child.
- **E village & quests:** five quest chains (Edda's Tongs, The Forty-First Stone, Names for the
  Yard, The Keg's Missing Ale, The Slow Way Down) with branching endings that stay in the world;
  attitudes and remembered choices; Grisel's shop (ui/shop.gd) and the keep's slate; villagers
  visit, shelter from rain, flee into the Keg in danger; Keg scenes (song, dice, argument); task
  ledger on L (ui/quest_log.gd). State in Travel.story (quests, att, rumours, tick). zz/quest_test.
- **F living world & soundscape:** graded herd alarm, owl/mouse and fox hunts, lapwing flocks,
  moths to lit braziers, tracks; storms with lightning bolts + distance-delayed thunder, surface rain
  sound and splashes, gusts through grass and trees, rolling fog banks; meteor showers, rift surges,
  will-o'-wisps (read secrets' state.gd), the white hart; regional ambience beds with crossfades,
  3D calls, indoor muffling and reverb (runtime AmbOut bus), generative rest/explore/danger music
  (on the Ambience bus; a Music slider is still to do). `--scape-off` A/B. Sky effects draw in a
  sky layer. Tests zz/world_react_test, world_weather_test, world_sound_test (self-terminating).
- **Lead:** loading warm-up shows the new kin, Well, Shade, Tether, cinders, burn/chill, lob/linger,
  a bolt per staff core and F's weather/sky effects (Wildlife.warm_show), and tours D's new places.
  HUD hints add V roll, MMB lock on, J journal, L tasks. `release_mouse` is now defined (it was
  checked by four scripts but never existed: an InputMap error on every input event).
- Open: WorldLanes.sites is never cleared (a second build in one process skips claimed spots);
  cull_scatter thins MultiMeshes by xz alone (D marks its own `site_owned`).

## Staff, combat feel, NPC voices (r27)
- `core/vfx/staff_sfx.gd`: synthesised staff sounds with 4 variants each, round-robin (bolt, lash,
  bolt_hit, lance_fire, lance_hit, nova, tap, swish, lance_charge loop); prewarmed by the loading
  screen, GenCache. Ferrule tap on alternate walking steps and on real landings. zz/staff_sfx_test.
- Bolt: bigger white-violet core, additive auras (alpha spheres read as flat discs), two-layer
  streak drawn every rendered frame from the interpolated head (was 60 Hz), muzzle pulse + ring,
  fuller impact. Lance: ember orb swelling at the staff head while charging (+ light), hotter
  spearhead. Held Rift Bolt no longer snaps the staff back each shot (cast_pose carries a repeat on
  from the current pose), flicks alternate sides, small recoil. zz/skill_shots (contact sheet).
- Interact feel (`Interactable.interact_feel()`): NPCs (anything with an npc_life) get a nod, plain
  objects a reach; only fires, wards, bells, mirrors, reliquaries and secrets cast the staff spell.
- NPC voices (core/npc/npc_voice.gd, separate session): formant babble per family and per NPC,
  voiced dialogue typing, ambient chatter and laughs.

## Loading screen + shader warm-up (r26)
- `ui/loading_screen.gd` (opened by Zone._ready; skipped under zz/ harnesses unless `--loading`,
  `--no-loading` skips it): covers the night until it is built AND warmed. Phases: build (Realm
  `progress`/`stage`, one frame yielded per stage so the bar moves), settle (zone meta `post_done`
  set at the end of Atmosphere.post_build), warm (a WarmCam tours 17 stops x 6 headings under the
  cover; at the first stop one of each enemy (disabled, out of the ENEMY group), the SpellFx and
  Vfx kinds are shown for 14 frames), steady (20 even frames or 3 s), fade. Player is frozen
  (process disabled) and input swallowed until it lifts. ~2 s of warm-up.
- Why: almost every material is built in code, so Godot's Shader Baker can't pre-bake them, and
  every rebuild changes shaders: the first sight of each one compiled mid-play. Cold-cache walk:
  80 ms spindle hitch gone, 1% low 79 -> 93 fps. Two ~27 ms frames remain on the perf_tour path at
  leg changes with or without the warm-up (likely the harness).
- The Ossuary now loads at boot (load_r 400): it was a ~265 ms freeze when first approached.
- Tools: zz/loading_shot (frames of the screen), perf_tour --loading --early.

## Display settings (r25)
- Luke plays fullscreen on an AOC 24G1WG4 at 144 Hz (screen 1). macOS reports it as 3840x2160
  (HiDPI), so fullscreen rendered the WHOLE frame at 4K: GPU-bound at 60-70 fps, which V-Sync
  showed as 72. Zone._apply_output: when the window is taller than ~1240 px, the root renders at
  Settings.OUTPUT_BASE (1920x1080, aspect expanded, content_scale_mode VIEWPORT) and is stretched
  once; "Full-Res Output" in Display turns that off. Measured on the AOC (with Luke's game also
  running): 60-70 -> 83-92 fps. HiDPI off made no further difference.
- Frame Rate Limit is now a value (`fps_limit`: -1 Match Display, 0 Unlimited, 30..240; old
  `fps_limit_index` migrates). `Settings.effective_max_fps()`: with V-Sync, Unlimited or above the
  refresh = the refresh (vsync + max_fps 144 held 144.7; vsync + 0 wandered 127-133). A note under
  the options says what you will actually get. macOS never shows more frames than the refresh.
- Monitor choice (`Settings.monitor`, -1 Automatic): Zone._move_to_screen leaves fullscreen, moves
  and centres, re-applies; one attempt per choice. Refresh rate re-read on every window resize.
- V-Sync 72 on the AOC was its FIXED 144 Hz refresh: frames over 6.9 ms wait a refresh. The
  MacBook (ProMotion, variable) never halves; Godot's mailbox/adaptive modes changed nothing on
  Metal. Fix was on Luke's side: Variable refresh for the AOC in macOS Displays. The menu note
  says so when V-Sync is on a > 120 Hz screen.
- **Stutter at 120 fps ("feels under 60"):** the SpringArm3D moved its camera only on physics ticks
  (internal physics process), so every change of camera distance (run +0.35 m, slide, easing back
  from a wall) stepped on alternate frames. Player now disables the arm's internal physics and sets
  `_cam.position.z = _cam_len` every frame. zz/smooth_probe measures per-rendered-frame motion of
  camera / body / hand bone (jitter vs neighbours; bone poses confirmed interpolated every frame).
- **Ground stripes:** moon shadow acne on the terrain; `shadow_normal_bias` 0.9 -> 1.8 (light_policy
  and atmosphere). Flora shadows were not the cause. zz/look_shots: --view=, --set=, --moon=,
  --noflora-shadow.
- Secrets kit lights stored meta "base" as an Array; LightPolicy expects {e,r,a} (script errors on
  every settings apply). Fixed.
- zz/perf_tour: --screen=N --fullscreen --vsync=0|1|2|3 --cap=N (-1 match) --native.
  zz/settings_shot and zz/look_shots hold Travel._busy.

## Polish + performance pass (r24, docs/POLISH_PLAN.md)
- **Wanderer** (core/player): all gear bakes into ONE skinned body on a runtime Skeleton3D
  (wanderer_body.gd; 3 surfaces: robe_skin / wanderer_gear (Texture2DArray) / wanderer_orb shaders),
  bone poses blended between physics ticks, GenCache + LODs. Shadows from a ~2.9k-tri ShadowProxy
  only. Rim OmniLight replaced by in-shader rim. Staff orb flare = core/player/orb_flare.gdshader (no
  depth read: the old world/flare.gdshader forced a depth copy, ~0.33 ms; bolts/ward/spit still use
  it). Player attrib 2.14 -> 0.58 ms, draws 49 -> 7, shadow draws up to 78 -> 2-3. New detail: torn
  hem, two-layer hood, stitched leather, carved rune staff with iron claws, generated lantern.
  Animation: look-at, walk/run/sprint staff carries, idle weight shift + breath, per-skill cast
  poses, hit react, turn-in-place shuffle, hood secondary. `equip()` after bake does not rebuild.
  Tools: zz/char_cost (paired-median A/B), zz/char_wrap (any test with the save locked).
  Boot diag checks Body/ShadowProxy when the merged body is on.
- **NPCs** (core/npc, core/life/village): sculpted one-surface faces (npc_face.gd) with mouth slit,
  teeth, lids on a 16th "lid" bone, ears, brows; lofted villager torsos/coats (`loft()` in
  dwarf_mesh.gd). Shared life layer npc_life.gd: blinks, breath, gaze, syllable speech driving jaw
  and gestures, live dialogue portraits. Patrons 2 and 3 make bar trips (seated -> standing build
  hand-off, keep `serve_at`). Villager gait by age, eased acts, weighted tool blows. LOD'd update
  rates (every frame < 4 m ... frozen > 35 m); ~0.1 ms/frame all NPCs. Shader `chroma`,
  `skin_back`, `skin_bounce`. Forge flare (1.0,0.7,0.42) base 0.22. Tools: zz/npc_studio,
  npc_shot, npc_perf.
- **Combined (all of r24, Cinematic --stress=2):** spawn_west 65.4 -> 82.8 fps (1% low 38.6 ->
  75.8, worst 13.4 ms), spawn_north 62.7 -> 80.6, meadow 82.3, tavern 75.6. At Luke's settings
  (`--luke`) every hub point holds 120 fps, worst frame 8.3 ms. Suite: all pass; realm_walks
  only fails in-suite when an earlier test leaves Deeper Night in the save (passes alone).
  App repacked 2026-11-04 11:42 (193 MB pck).
- **Perf** (hub, Cinematic stress, ABAB): ~65 -> ~81 fps (tavern 67 -> 77). Undergrowth chunks
  thin per plant over the fade band instead of the engine's alpha fade (transparent pass);
  motion blur off when the camera is still / smear < 0.5 px, 3-8 taps; terrain lump normal
  analytic; lava bank re-map sliced (2.5 ms) and skipped when unchanged; life_director caches
  group centres (and now really removes rat groups). Balanced/Performance now scale (94 / 130).
  Kept for the look: SSR 1.7 ms, moon PCSS + blend 0.9, leaf coverage 1.6, glow, grade.
  Tools: perf_tour --luke --pan --hitches --mute --shader --feat; zz/perf_look (save-safe look
  diff), zz/perf_safe -- --run=<scene>.
- **Lead:** grade blends partly protected warm pixels in RGB instead of rotating hue (firelit
  skin/cloth went magenta). Village sounds (village_audio.gd) and combat sounds (core/vfx/synth.gd)
  are prewarmed at load and cached in GenCache: synthesising on first play was the 30-40 ms hitch
  ~10 s after load (Hild's first anvil strike) and on a fight's first hit. Hub at Luke's settings
  now holds 120 fps with worst frame 8.3 ms. zz/look_shots sets Travel._busy.

## Living-world pass (r23, docs/LIFE_PLAN.md)
Five systems built last by Realm.build from core/life/<system>/, each saving via
`Travel.system_state("<id>")` ([systems] section). Warm build adds ~180 ms (app: 2.9 s total).
- **progression:** Kindling menu at lit fires / [K] (ui/growth.gd): embers, 3 ranks per spell
  (rank III changes behaviour), oaths, relic rites, 6 world charms + 6 elite-trophy charms.
  Publishes `tier` and `spent`. Test: zz/progression_test.
- **village:** 11 villagers on a 10-min night cycle (forge, lamplighter, sexton, hermit...), Grisel
  trades ash for village projects, restoration steps on bosses/seals/braziers. zz/village_test.
- **life:** moths, fireflies, bats, crows, owls, herons, frogs, deer, foxes, rats, elk; weather
  fronts (mist, gusts, drizzle, storm) as temporary env offsets. zz/life_test. Lead fixes: herds
  move their node with the animals, no visibility range on herds, no physics interpolation on
  life MultiMeshes. Note: zz/life_shots' free camera can fail to show herds; the player camera
  (zz/spot_shot) shows them.
- **secrets:** 10 secrets (bells puzzle, lava ledge, rim bridge, barrow, drowned crypt, postern
  shortcut, hollow oak, Ansel's cist, Pell's den, Hobb's cairn), elites, boss reactivity (brambles
  wither, fen clears, sky calms). `relic_fragment` is in ItemDB (lead). Lead fix: Kit.site trims a
  secret's rect off earlier sites (realm_lore_test overlaps). zz/secrets_test.
- **encounters:** 7 danger tiers, rest refill, Gloom tide, road ambushes, 5 named elites (+ the
  Penitent in NG+) with bounty posts, Deeper Night via the cracked bell. Event
  `Events.gloom_tide`. zz/encounters_test (-- --fresh).
- Full suite 2026-11-04: all 19 pass. realm_walks only fails on a save in Deeper Night (seals
  re-close; the test frees the guards) and persist_test only reports what the save holds.
- **Save hygiene:** tests must set `Travel._busy = true`. A test run once overwrote Luke's save; it
  was restored from a lead copy.

## Done in r21 — colour pass toward Luke's reference reels

Reference: 6 phone recordings of dark-fantasy reels (deep azure night, bright moonlit stone,
small vivid warm/green accents). Measured with ffmpeg (frames -> PNG -> signalstats + 1x1 mean
colour; NOTE signalstats HUEAVG is not usable: reversed and meaningless on mixed frames).
| | mid Y | low | high | sat | R/B | G/B |
|---|---|---|---|---|---|---|
| reference | 48 | 23 | 91 | 19.4 | 0.38 | 0.54 |
| before | 38 | 18 | 68 | 17.9 | 0.46 (violet) | 0.42 |
| after | 47 | 20 | 83 | 23.1 | 0.32 | 0.52 (azure) |
Changes: Atmosphere._moon azure key 0.45,0.73,1 at 1.05 (was lavender 0.6); exposure 0.91 -> 1.2;
ambient 45 % sky + azure colour (the violet vortex sky cast magenta on stone); fog emission
#3A2480 violet -> #1E4AA0 azure, 0.22 -> 0.16 (main.gd). Grade (world/post/grade.gdshader +
grade_material.tres): luminance S-curve (`contrast`, `pivot`) and `highlight_gain`; blue band
205-236 deg with full pull (partial pulls turned reds violet); warm protected only when bright
(`warm_min_v`); greens/teals 85-200 deg protected (`green_lo`); azure split-tone tints;
saturation 1.6. Glow budget untouched. Tool: `zz/look_shots.tscn [-- --tag=x]` (8 player-camera
views + sheet). Known: a faint orange->blue edge where lantern pools fade on stone.

## Done in r20 — Realm load time 9.5 s -> 3.4 s

- `core/world/realm/gen_cache.gd`: disk cache for deterministic generated meshes and shapes.
  Dev (editor binary) runs write `res://art/realm_cache/` (ships with the export; exported builds
  read it and fall back to `user://realm_cache/`). Each entry is salted with a hash of its
  generator's source, so editing a generator rebuilds its entries; delete the folder to force a
  rebuild. **Run the game once from the editor before exporting** so the cache is complete.
  Runtime materials are stripped on save and re-applied by the caller.
- Cached: RockKit meshes, TreeGen kinds, MeshChunks.split chunks (keyed by a hash of the source
  mesh), the summit moss rocks' simplified convex hulls (1.3 s -> 15 ms), the mage statue, and
  every tavern dwarf (keyed by its options).
- RealmLand heights computed across worker threads (WorkerThreadPool, 550 -> 277 ms).
- Realm.build starts threaded loads of the summit platform/pillar/mage scenes at the start, so
  SummitDress no longer blocks on them (760 -> 147 ms).
- `Realm.prof` prints a `REALM_PROF` breakdown (stages, modules, generators) at the end of build.
- Fixed: MultiMesh copies in SeatProps (duplicate() restored the buffer before the instance count).
Warm build ~3.4 s headless (cold, first run ~8 s). Biggest left: lore 0.9 s, flora 0.9 s
(placement loops using physics queries, main thread only), rift 0.56 s, land 0.53 s.

## Done in r19 — the Realm (the zone redesigned from scratch)

The zone is now **the Realm** (docs/REALM_PLAN.md: map, modules, rules; docs/LORE.md: mythos).
It is the default; `-- --no-realm` builds the old stair-era world (kept for its legacy tests).
Built at runtime by six modules under `core/world/realm/` (entry `Realm.build`, contract
`RealmLayout`), each written by a parallel agent and integrated by the lead:
- **land** — new 2 m terrain over x -110..110, z -150..80 (about 2x), 7 blended biome ground
  layers, carved paths, fen water, horizon ring, invisible bounds; old heights kept in the rift,
  Ossuary and summit. API on realm_land.gd (height_at, biome_weights, in_water, WATER_Y -0.9).
- **rift** — the Ashen Rift (basalt organ pipes, cliffs, crust islands, fissures, vents, 7 lava
  falls) and **the Crossing**, the ruined viaduct from (0,0.6,-8) to the ward landing
  (0,25.2,-70.9) that replaces the hub stair (towers, arched piers, a fallen column, a spiral
  round the Spindle). lava_works.gd waits for the rift and pours falls at its stations.
- **bosses** — Thorn Henge moved to (-72,-18) with RockKit megaliths; the Ossuary's new fen
  door (34,4,-66) with a stair up into the gallery; braziers re-sited (StairFoot, Shrine,
  Landing, Threshold; the spawn brazier untouched); REALM_CAMPS (seal guards + roaming packs).
- **lore** — 56 inscriptions (incl. Wenna Ashby's journal), Hearthward village, Chapel of the
  First Kindling, road gates/waystones/graves, Shrine of the Lost, Barrow Field, drowned graves,
  Thornwood relics; 78 registered sites; 7 lights.
- **flora** — 8 tree types (oak, pine, birch, willow, snag, saplings...) built by tree_gen.gd,
  ~33k instances incl. undergrowth, chunked MultiMeshes, near/far tree meshes, trunk colliders.
- **assets** — RockKit (boulder/cliff/basalt_columns/slab, 4 styles, LODs), upgraded menhir,
  cairn, rune slab, rocks, lantern, stone frame; material pass; mipmaps on Ossuary textures.

Tests (Realm is the default, no flag needed): check, realm_audit (AUDIT PASS), realm_land_check,
realm_rift_walk (spawn -> Crossing -> dais), realm_walks (henge, barrows, fen door, crypt),
realm_lore_test, realm_flora_check, boss_test 27/27. Old world: henge_walk, summit_probe and
boss_test 27/27 with `-- --no-realm`. perf_tour: 474-752 draws, 0.5-1.1 M prims, 110-120 fps
windowed 1600x1000. Survey: shots/realm_survey/. Build at load ~9.5 s (lore 2.2, rift 1.4,
flora 1.3, land 0.9 s + stamping/summit) — the next optimisation target (cache generated meshes).
Open: willow crowns a bit boxy; no garden hedges; rift lava walls still straight (kept chasm);
the Crossing's Spindle heavy; boss_test clears Travel progress in memory at start.

## Done in r18

- **Bare trees at spawn.** Two causes: (1) site clearance dropped every canopy crown inside a
  removed tree's whole footprint (15-40 m across), stripping the neighbours; now a crown goes only
  if a removed tree held it and no remaining tree does, or it hangs over a building
  (`WorldLanes._drop_crowns`). (2) the canopy chunks got generated LODs, which collapse flat leaf
  cards; `MeshChunks.split(mi, false)` for Canopy/CanopyFill (culling only). prop_audit: 0 orphans.
- **Motion blur only on its own camera** (`owner_pos` check): mirrors, portals and free cameras
  were being smeared with the player camera's history.

- **Motion blur** (`core/vfx/motion_blur.gd`, `Settings.motion_blur`, default 25 %; 35 % on
  Cinematic): a full-screen quad under the camera reprojects each pixel with last frame's camera
  and smears along its screen motion (8 jittered taps, capped at 2 % of the screen, normalised to
  a 60 fps shutter). Drawn first in the transparent pass so flames/particles stay crisp; nothing
  within ~5 m of the camera blurs (the wanderer stays sharp); 0 hides it (no cost). Camera
  motion only — moving enemies are not blurred. It is not AA and does not touch the glow budget.
- **Settings menu rebuilt** (`ui/settings_menu.gd`): tabs (Display / Graphics / Audio / Controls,
  Q / E or the bumpers switch), each scrollable inside a padded panel that fits the window (it
  used to overflow off the bottom over the hotbar), tooltips, value readouts on every slider,
  layer 50 above the HUD, focus on the page's first control for keyboard/pad. New: frame-rate
  limit, motion blur, invert look (mouse and stick), a key reference. Mouse sensitivity reads as
  a 1-12 scale (5 = default). The quality preset shows "Custom" once an option is changed
  (`Settings.matching_preset()`). Removed the dead Depth of Field toggle (it could never turn on;
  far DoF stays off by rule). Reset now also resets audio, FPS limit and invert.
- **Fog toggle fixed:** "Volumetric Fog" switched both fog kinds, and the Performance preset turned
  volumetric off behind the toggle's back. Now the toggle is the volumetric fog only (distance fog
  is the night's depth and stays), and Performance sets it off visibly through the toggle.

## Done in r17

- **Floating trees at spawn — `CanopyFill`.** `Atmosphere._canopy_fill` (a second, denser copy of
  the canopy) scaled and turned the whole Canopy node about the world origin, so every copied
  crown landed 5-15 m off its trunk. Now each crown is thickened about its own centre, and
  `Atmosphere.refresh_canopy_fill()` rebuilds it after the terraces/clearance moved crowns.
  `zz/prop_audit` checks Canopy and CanopyFill crowns for a trunk under them (0 now; 17 before).
- **Branch/moss cards** (`NightDress`) were hung on random points in the forest meshes' bounding
  box, i.e. in open air; now on real trunks (`SeatProps.pieces`), on the bark.
- **Tavern dwarves.** `core/npc/dwarf_rig.gd` (`DwarfRig`): procedural dwarves from CreatureMesh
  (tunic and belly, sleeved arms and fists, tankard with foam, face with nose/brows/eyes, full
  beard with moustache and braid or fork, helm/hood/cap/hair, boots; seeded colours and styles)
  on a runtime 7-bone skeleton, one skinned mesh with LODs, 2 draws each. The old unrigged
  `art/models/dwarf_*.glb` are no longer used.
  `DwarfNpc` (9 patrons, `Tavern.PATRONS`): drinks (mug to the beard, head back), toasts, laughs,
  talks with the free hand, looks about; own clock each; capsule collision. `Bartender` ("Keep"):
  walks the duckboard behind the bar, wipes the counter, polishes a mug, fills one at the keg tap
  (beer stream), sets mugs out on the counter (max 5), turns to talk when you come to the bar.
  Tavern additions: 4 chairs at table ends, a duckboard behind the bar (+0.3 m), a foot step in
  front of it, a tap on the keg. Animation stops past 30 m from the camera.
- **Assets.** Giant-trunk bark regenerated as fissured plates (`tools/gen_bark_giant.gd`; the
  python `bark_giant()` is retired), less emission/rim; AO maps wired into bark, giant bark and
  rock materials (they existed unused); tavern wood tint lighter. The stone material (stair,
  sanctuary), terrain and robe were deliberately left alone (hard rules).
- **Optimisation.** `MeshChunks.split()` cuts GiantTrunks, Canopy, CanopyFill, DeadTrees and
  Boulders into 24 m chunks with generated LODs (frustum culling and LOD now work; 78 chunks,
  ~110 ms once at load). Forest-floor scatter meshes get LODs (`MeshChunks.with_lods`), dwarves
  get LODs, crypt skull/bone ranges 48/40 -> 34/30 m, summit moss rocks `lod_bias` 0.3, lava bank
  mapping spread over ~10 frames (no load hitch). `zz/perf_tour`: primitives -23 to -37 % at
  spawn/sanctuary/tavern/henge/mid-stair; fps unchanged within noise (~140-175 windowed at
  1600x1000 on this Mac). The frame is not geometry-bound: process time ~7 ms is the whole frame
  waiting on the GPU (Metal reports no GPU timings), so the remaining cost is fill/post (fog,
  SSAO, glow) — glow is fixed by the hard rules; the quality presets cover the rest.

## Done in r16

### Foliage and props follow the terraced hills
`TerrainStamp.shape()` drops the tall hills by up to ~13 m. Nothing baked used to follow.
- **Ground delta:** `TerrainStamp` records how far each ground vertex moved.
  `delta_at(x, z)` is the total (terracing plus site stamps); `shape_delta_at(x, z)` is the
  terracing alone. Both are bilinear and reset per terrain body.
- **Scatter** (`SeatProps.seat(root, baked=true)`, called from glimmers): grass, ferns, caps and
  pebbles move by `delta_at`, then fine-snap with the old ±2.2 m ray. Spores and other unknown
  kinds move and are kept above the ground. Builder nodes (`BUILT`, meta `site`, `Area_*`) are
  skipped.
- **Stale buffer reads (the real cause of the floating clumps).** On Metal, reading
  `multimesh.buffer` back in the same frame returns stale GPU data, and per-instance setters did
  not stick. Seating now edits the whole buffer once (`_xf_at` / `_put_xf`) and leaves the CPU
  copy in meta `cpu_buffer`. `WorldLanes.cull_scatter` reads that copy instead of the GPU, so it
  no longer writes the old heights back. Seating also grows `custom_aabb` so lowered cells aren't
  frustum-culled.
- **Trees, rocks, ruins and crystals** (`SeatProps.follow_terrain`, run right after
  `TerrainStamp.apply`): each piece moves rigidly by `shape_delta_at` under its base. Its
  collision (trunk primitives, trimesh faces), its trunk occluders, and the canopy crowns over it
  move with it, and so do menhirs, lanterns, braziers and gates.
- **Piece grouping:** `SeatProps.pieces()` splits a mesh into individual props. Each welded island
  hangs off the lowest-starting island whose box overlaps it, so a branch belongs to its trunk and
  touching crowns never chain a grove together. `_drop_loose_bits` deletes small tree fragments
  left hanging over nothing.
- **Site clearance** (`WorldLanes.clear_fragments`) works on whole pieces. Each piece is judged at
  the height it will stand at after terracing; before, props were still at the old hill height
  and missed the keep-out boxes. A tree is dropped only if its ground-level part intrudes, so an
  overhanging branch doesn't remove it. Crowns over a cleared tree go whole.
- **Results:** `zz/foliage_audit` reports 0 of 8,798 off the ground. `zz/prop_audit` went from
  2,347 floating pieces to 0 trees, rocks or ruins. The 14 hub-stair rift-crystal islands it still
  flags are baked on the stair edge on purpose; the stair's collision is narrower than its mesh,
  so the audit's ray misses it.

### Summit: physically larger fighting dais (option A)
- **The dais:** `SummitDress._extended_dais` builds an OssKit paved disc, `DAIS_R` 14 m at
  `TOP_DECK_Y`, centred at holder `DAIS_C` (0, −20.4), behind the deck. It has a coped parapet
  with pinnacles, open at the deck junction and at the lift jetty (`LIFT_LANE`), plus 10 piers to
  the chasm floor that only land on terrain.
- **Cleared for it:** `_cut_dais` removes the back rail it covers (collision too), and moss rocks
  under it are hidden. `_clear_airspace` pushes rift-debris rocks out past the parapet.
- **Registration:** hard site `summit_dais` is registered as the square *inside* the disc, because
  the outer square took in the jetty, rails and a rock. The host node has meta `site`.
- **Arena:** centred on the dais, radius 14, `max_rise` 0.5, spawn 2 m behind the centre. The
  Warden's blink anchors are at 0.7 × radius.

### Lava
- **Surface** (`world/zones/lava.gdshader`, `art/materials/lava.tres`): `emission_energy`
  7.4 → 3.0 and `crack_width` 0.42 → 0.1, so it's dark crust with bright cracks instead of a
  blown-out sheet. Embers are round and sparse rather than square cells, and the crust has grain.
- **Bank mask** (`LavaWorks._map_banks`): 0.5 m cells, and only rock at or above the surface
  counts as shore, so the bright rim now hugs the real shoreline. It costs about 48 ms and runs
  twice after load (2.5 s and 9 s).
- **Falls** (`LavaWorks._fall`): each is one stream. It wells up from a vent with embers 1.5–5 m
  back from the lip, crawls along the shelf under a crust, rolls over the lip, and follows the
  real rock face down (each edge sampled every 0.5 m). It plunges under the river into a froth
  pool with a splash. The material is alpha-blended (additive turned the falls pink in the fog).

## World assembly pipeline (order matters) — core/world/glimmers.gd `_ready`

1. `TerrainStamp.shape(root)`: terracing (noise-varied step 2.4–4.4 m, warped edges,
   `SHAPE_FLAT` 0.52 of each band level). `KEEP` rects (spawn, sanctuary, Ossuary approach) are
   left untouched, with falloff. Records `shape_delta_at`.
2. `await physics_frame`
3. Builders register sites, lanes and portals: `Tavern.build`, `ThornHenge.build`, `StairWorks.build`.
   (`SummitDress` registers `summit_dais` from `DressedProps.dress_zone`, step 7.)
4. `WorldLanes.clear_fragments(...)` for Ruins, GiantTrunks (+Canopy), Boulders, DeadTrees and
   RiftCrystals: whole pieces (`SeatProps.pieces`) judged at their post-terrace height, which also
   kills their collision.
5. `await TerrainStamp.apply(root)`: stamps site floors (level sites cut+fill, rect/flight cut only,
   `hard` sites without falloff). `delta_at` now includes these.
6. `SeatProps.follow_terrain(root)`: trees, rocks, ruins and their collision come down with the terraces.
7. `SeatProps.seat(root, true)` → `sink_river_crystals` → `SeatProps.plant_solid` → `DressedProps.dress_zone`
8. `WorldLanes.cull_scatter(root)` (buffer-level MultiMesh cull; reads meta `cpu_buffer`), then
   `line_lanes(root, "Menhir")`.

Key registries: `core/world/world_lanes.gd`. Static tables: `LANES`, `FIXED_LANES`, `FOOTPRINTS`.
Runtime registries: `sites`, `extra_lanes`, `portals`. Functions: `register_site(n, rect, floor_y,
cut_y, hard)`, `register_terrace`, `register_flight`, `register_lane`, `register_portal`, `intrudes`,
`site_floor`, `site_at`.

## Landmarks (r16 numbers)

| Landmark | File | Key numbers |
|---|---|---|
| Tavern | core/world/tavern.gd | X 10–26, Z 25.6–34.8, floor −0.7, door x 17.6, east yard retaining wall (`_yard_wall`, hard site "tavern_yard") |
| Thorn Henge (boss: Thornwarden) | core/world/thorn_henge.gd | C (−42, median ground, 1), R 13, ring 10.5, hedge 12.2, stair foot (−20, 22), 3.9 m wide, seal "henge" |
| Ossuary crypt (boss: Bone Abbot) | world/areas/ossuary/ossuary.gd | PIT_R 11, arena r 10.4, gallery seal "oss_gallery", bone portcullis (21, GAL_Y, −66.7), Reliquary size 2.4 on kill |
| Summit (boss: Ascended Warden) | core/world/summit_dress.gd | needs thornwarden + bone_abbot; platform r 12 at (0, 24.5, −83.5); fighting dais r 14 at world (0, 27.35, −103.9), arena r 14 |
| Hub stair works | core/world/stair_works.gd | buttresses, lava −15.5 |
| Lava falls | core/world/lava_works.gd | auto-placed on the steepest walls: west (−28, 3.4, −100) lip, east (31.7, 11.2, −20) lip |

Progression: `WardSeal` (core/world/ward_seal.gd; camps tagged `seal` in EnemySpawner) →
`BossArena` (core/world/boss_arena.gd: leash, LEAVE 6 m reset, top HP bar, `audit()`) →
`Travel` (autoload/travel.gd) persists `seals_broken`, `bosses_slain`, `items`, relics.
Items: core/items/item_db.gd. Inventory UI: ui/satchel.gd (Tab/I/dpad-up; attune at lit braziers).
Relic variants: core/world/reliquary.gd `VARIANTS` (bone: implosion/wake; thorn: splinter/briar).

## Test harness (zz/)

Run from the project root (`godot` = your 4.7.2 binary):

```sh
godot --headless --path . --editor --quit            # once after adding a class_name
godot --headless --path . res://zz/check.tscn         # must print: CHECK DONE bad=0
godot --headless --path . res://zz/audit.tscn         # collision/clipping/site audit → AUDIT PASS
godot --headless --path . res://zz/boss_test.tscn     # 27 checks; writes a save with seals broken (see gotchas)
godot --headless --path . res://zz/persist_test.tscn
godot --headless --path . res://zz/lanewalk.tscn
godot --headless --path . res://zz/summit_probe.tscn  # walks the summit and across the dais
godot --headless --path . res://zz/henge_walk.tscn    # "DONE all legs ok"
godot --headless --path . res://zz/fit.tscn           # structure edges floating/buried vs terrain
godot --headless --path . res://zz/prop_audit.tscn    # trees/rocks/ruins floating, crowns with no trunk → "PROPS floating=N"
godot --path . res://zz/foliage_audit.tscn            # needs a renderer; "FOLIAGE off=0 of N"
godot --path . res://zz/ingame2.tscn                  # player-view screenshots → shots/ig_<view>.png (views at top of the script)
godot --path . res://zz/lava_shots.tscn               # lava overview/bank + every fall (whole, lip, base) → shots/lava_*.png
godot --path . res://zz/summit_top.tscn               # top-down + oblique summit → shots/summit_*.png
godot --path . res://zz/survey.tscn                   # whole-zone walk: every walkable point on a 12 m grid, 4 directions
                                                      #   → shots/survey/sheet_NN.png + manifest.txt (about 8 min)
                                                      #   args after --: --step=6, --only=x0,z0,x1,z1
godot --path . res://zz/spot_shot.tscn -- --at=x,y,z --look=x,y,z --name=n [--times=9,10,11]   # free-camera frames
godot --path . res://zz/perf_tour.tscn [-- --blame]   # windowed fps/draws/prims at 6 points (--blame is noisy on Metal)
godot --path . res://zz/model_shot.tscn -- --rig --model=seated|standing --name=n   # studio render of a DwarfRig
godot --headless --path . res://zz/mesh_census.tscn [-- --under=Node]   # heaviest meshes: tris, LODs, ranges
godot --headless --path . res://zz/trunk_gaps.tscn    # worst gap under each tree/rock's bottom ring
godot --headless -s zz/tile.gd -- out.png cols width in1.png in2.png ...   # contact sheet
godot --path . res://zz/settings_shot.tscn            # the settings menu, every tab -> shots/settings_<n>.png
godot --path . res://zz/blur_shot.tscn                # motion blur: still / mid-turn / running frames
```

`shots/survey_before/` holds the r15 survey (floating trees, rocks, lava falls), for comparison.

Gotchas learned the hard way:
- In headless mode MultiMesh buffers read back as identity, so prop-level and foliage
  checks need a real renderer (run without `--headless` on the Mac, which is much faster than
  the cloud's xvfb/vulkan at ~2–3 min a shot).
- **On Metal, a same-frame read of `multimesh.buffer` returns stale GPU data, and per-instance
  `set_instance_transform` may not stick.** Edit the whole buffer once and pass the CPU copy on
  (meta `cpu_buffer`, see `SeatProps._commit` and `WorldLanes.cull_scatter`).
- `boss_test` reads and writes the real save (`~/Library/Application Support/UmbralReaches/savegame.cfg`).
  With bosses already slain it reports 4–8 false FAILs ("… rose"). Move the save aside for a clean run.
- Baked prop meshes are one mesh per kind. Group islands into props with `SeatProps.pieces()`,
  never by box overlap (that chains whole groves into one piece).
- `SurfaceTool.append_from` into an existing key drops geometry. OssKit uses a separate `key#m` surface.
- StoneBodies hardens meshes into collision; anything a builder makes needs meta `site` on an
  ancestor or it gets solidified and blocks gates.
- Seal camps skipped for the haven must be removed from `_seal_camps`, or the seal never opens.
- Stair foot rise must stay ≤ STEP_MAX 0.45. Set the foot into the lowest surrounding ground − 0.12.
- `ingame2`, `survey` and the other render scripts can hang on quit, so kill the process rather than waiting.
- There's no `timeout` on macOS; poll the log in a loop and kill the PID.

## Suggested next session

1. Luke playtests r16 (dais fight, lava in motion, a walk over the terraces).
2. Act on the feedback; re-run `zz/survey` and compare against `shots/survey_before/`.
3. Light the summit dais if it reads too dark in play.
4. Bring the master-plan doc up to date.
