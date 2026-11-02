# Umbral Reaches — Review 2 (2 Nov 2026)

Scope: assets and look, combat, movement, skill variety, hotbar; plus a second pass over the
rest. Part A is what was built this pass (playtest it). Part B is the critique and the next
work for Cursor, each with method and an Accept line. Constraints from
`.cursor/rules/umbral-constraints.mdc` still bind (no AA, no headless rebake, glow budget).

---

## Part A — Built this pass (uncommitted, needs a Mac playtest)

Not run in an engine: the linked shell is a Linux VM with no Godot. Every new/changed script
passes `gdparse` (gdtoolkit 4) and APIs were cross-checked by hand. First thing on the Mac:

```sh
cd ~/UmbralReaches && godot --headless --path . --import --quit   # registers the new class_names
godot --path .                                                    # F5 equivalent; watch the Output for errors
git add -A && git commit -m "Skills, hotbar, ballistic leapers, Spitter"
```

### Skills (`core/skills/`)
`Skill` (Resource: id, action, cooldown, gloom cost, trigger, glyph) + one subclass per skill.
`SkillBook` is a child Node of Player that owns input, cooldowns, a 0.1 s global lock, charge,
device detection and the hotbar's read surface. Player no longer handles cast input.

| Slot | Skill | Keys (KB / pad) | CD | Gloom | Role |
|---|---|---|---|---|---|
| 1 | Rift Bolt | LMB / RT | 0.34 s, hold to repeat | — | Spam. Each hit = 1 Umbral Mark (max 3, 5 s) |
| 2 | Ember Lance | RMB or R / LT | 1.4 s | +4 | Hold to charge 0.9 s: dmg 2→4, blast 2→3.2 m, speed 18→30. Full charge **pierces**. Walk ×0.55 while charging; orb swells |
| 3 | Umbral Nova | Q / RB | 7 s | +6 | 4.6 m ring: 1 dmg **+1 per Mark consumed**, hard shove, pops spit, unmakes shades |
| 4 | Lantern Ward | F / LB | 24 s | — | 7 s planted warm light registered in LightGrid → Gloom drains, shades dissolve, enemies slink, no respawns inside. Ground ring shows radius |
| 5 | Shadowstep | C / B | 1.6 s | — | 3.4 m blink (17 m/s × 0.2 s) in move dir; 0.32 s untouchable (melee, pounce, spit, shade touch); marks enemies passed through |

Design intent: Gloom is the mana. Lance and Nova push you toward a shade; Ward is the
only skill that buys Gloom back. Loop: bolt to stack marks → Nova to cash them → step out of
the pounce → ward when the meter is high.

### Hotbar (`ui/hotbar.gd`)
Bottom-centre, five 78 px slots drawn in code (no textures): line glyph per skill, key chip
read live from InputMap (switches to pad names on last device used), clockwise cooldown sweep
+ seconds, `+N` Gloom cost, charge ring, cast flash, ready pulse, red shake when refused. Names
show under the slots for 14 s. Lines drawn without antialiasing to keep the hard look. The old
bottom-left controls hint moved under the Gloom bar.

### Movement / feel
- **Combat facing**: for 1.4 s after any cast the body faces the crosshair, so backpedal-and-cast
  no longer fires out of a body turned away.
- Camera kick: `Player.kick()`; the old `_shake` decayed at 8 rad/s (a 0.15° punch lasted ~0.3 ms,
  i.e. invisible). Now ~0.15 s.
- Floating damage numbers (`core/vfx/hit_text.gd`, pooled Label3D, Cinzel, ember + larger ≥ 3 dmg).
  "evaded" pops when a step beats a strike.
- Bolt bug fixed: every explosion added a new `AudioStreamPlayer3D` to the pooled bolt and never
  freed it. Now one player per bolt, pitch-varied.

### Jumpers (`core/enemy/enemy.gd`, `leaper.gd`, `crawler.gd`)
Root cause of short leaps: during flight `_move()` rewrote `velocity.x/z = steer` (walk speed)
every frame, so a "leap" was a 0.85 s hop at 4 m/s ≈ 3.5 m. Now:
- `launch_at(target, apex)`: closed-form ballistic launch (vy = √(2gh), T = vy/g + √(2(h−Δy)/g),
  v_h = Δxz/T) that lands on the target on slopes and stairs; airborne frames keep momentum.
- **Leaper**: CHASE → `LEAP_PREP` (0.5 s coil: body squashes, arm raises — the dodge window) →
  `AIRBORNE` pounce of **4.5–13 m** with 55 % lead on your velocity → one strike in flight → 0.85 s
  landing stagger (punish window). Needs line of sight to commit.
- **Crawler**: ballistic 3.4 m skitter-hops instead of vertical bounces.

### New enemy: Spitter (`spitter.gd`, `spit_orb.gd`)
1 HP, pale bile palette, glowing throat sac. Kites at 6–10 m with alternating strafes, 0.6 s
windup (sac swells), spits a slow 9 m/s teal orb (half lead, droop pre-compensated). Orb adds 10
Gloom, can be shot down (HURTBOX layer), popped by Nova, stepped through. Teal chosen because
`grade.gdshader` protects 155–200°; violet is the player, warm is safe light.

### Encounters (`enemy_spawner.gd`)
Stair foot camps now mix roles: wretch + 2 crawlers; leaper + spitter; wretch + spitter; lone
leaper (4 camps, 8 enemies, was 3 wretches).

---

## Part B — Critique and next work

### B1. Assets and look

Measured from the GLBs (tris = index count / 3):

| Asset | Tris | Meshes | Notes |
|---|---:|---:|---|
| `mossy_platform.glb` | **879 461** | 112 | 22 MB, summit dressing. This is most of the 2.7 M prims at the summit |
| `gothic_bay.glb` | 92 485 | 9 | Banned as a level mesh by the rules, still 4.8 MB in the project |
| `summit_pillar.glb` | 66 721 | 9 | |
| `robe_torso.glb` | 26 260 | 1 | Hero mesh, fine |
| `robe_bracer.glb` | 6 440 | 1 | **2× the sleeve (3 092)** for a forearm cuff — budget inverted |
| `wretch_torso/head` | 920 / 1 156 | 6 / 9 | Rest of each enemy is ~60 primitive cylinders/spheres |
| `rock_a/b`, `stair_step` | 80 / 140 | 1 | Silhouettes read as boxes at mid range |
| Animations / skins in any GLB | **0** | | Every character is procedural joints |

**B1.1 Summit platform: decimate and split.** Blender: Decimate (collapse, ratio ~0.03 → ~25k),
bake the lost detail to a normal map from the original (Cycles bake, cage 0.02), join the 112
parts by material (target ≤ 4 meshes). Keep import `generate_lods=true`.
Accept: summit prims < 900k, draw calls −100.

**B1.2 Enemies look like stone dolls.** They have no textures of their own; `enemy_body.gd`
puts **stone/bark/ground triplanar** maps on flesh, so skin reads as rock and every type reads
as the same mannequin at 10 m. Method, in order of payoff:
1. Silhouette first: each type needs one unmistakable shape at 15 m in silhouette (grade it in
   greyscale): Wretch = hunched, long arms; Crawler = flat quadruped; Leaper = tall, digitigrade
   legs, long tail; Husk = wide, ribcage open; Spitter = bloated neck sac (now present).
2. Buy one rigged, animated creature pack under $10 (owner budget) — Quaternius and KayKit
   publish CC0 monster packs; Synty-style packs often discount. Retarget onto the existing
   sockets via `Skeleton3D` + `BoneAttachment3D` so `CharacterRig` sockets keep working.
3. Until then, give flesh its own material: albedo from `gen_textures.py` (cellular noise veins
   + cavity AO), subsurface off, roughness 0.55, rim 0.3 — not stone.
Accept: in a greyscale screenshot at 15 m each enemy type is identifiable.

**B1.3 Texture packing.** Every material ships separate `*_ao.png` and `*_rough.png` (L8, 1024²).
Pack AO→R, rough→G, metal→B into one `*_orm.png` (Pillow in `gen_textures.py`) and switch to
`ORMMaterial3D`. Two texture fetches and samplers per material become one; memory is roughly
neutral, the win is bandwidth and fewer material slots.

**B1.4 Rocks and steps.** 80-tri rocks and 140-tri steps are the most-seen geometry on the
climb. Regenerate in `make_stone_kit.py` with 600–1 200 tris, bevelled edges (weighted normals),
and 3 variants each so repetition breaks. Hard edges stay (no AA), but bevels catch the rim
light that sells the look.

**B1.5 The reference look (light through windows, flare) still depends on three hero spots.**
The window gobo + ShaftMist are the strongest shots; there are three. Add one per landing (every
10 steps) and aim each so the shaft crosses the stair at standing height — the player walks
through light rather than past it. Budget: hero spots cast shadows only on "High".

**B1.6 Grade cost regression (from `perf_baseline.md`).** After the `canvas_items` change the
grade runs on the 2D canvas at window size (~1920×1205+), not the 960p 3D buffer: GPU
+1.8 ms and the sanctuary 1 % low fell to 86. Method: move the grade to a `CompositorEffect`
(post-transparent, compute shader over the 3D colour buffer at internal res), keep HUD
untouched. Port the existing GLSL nearly verbatim; sample the colour image with `imageLoad`.
Accept: GPU ms back to ≤ 5.0 at sanctuary with grade on, HUD still crisp.

### B2. Combat

- **There is no player failure besides Gloom.** All damage is Gloom; Gloom 100 → shade → Hollow.
  That's good and distinctive — keep it — but nothing communicates a *hit*. Add: 80 ms violet
  screen-edge flash (grade param `hurt`), brief 0.06 s player hitstop, directional indicator
  (HUD arc toward attacker). Accept: in a blind test, you can tell where a hit came from.
- **Melee windups are under-telegraphed.** WINDUP is 0.42 s with only the arm gesture. Add a
  bright eye/claw glint at WINDUP start (instance uniform on the enemy flesh material) and a
  short audio cue. Pounces now have the coil; strikes need parity.
- **Enemy AI has no separation.** Packs stack into one point. Method: in `Enemy._move`, add a
  separation term `Σ (self−other)/d²` over enemies within 1.4 m (cache the group list per think
  tick) and a 35° flanking offset per pack index so they surround instead of queue.
- **No navmesh.** Flat steering + "stuck sidestep" works on the stair foot only. When camps move
  up the climb, bake a `NavigationRegion3D` (in `bake_main.gd`, GPU bake) and drive CHASE through
  `NavigationAgent3D` with avoidance on.
- **Marks need a sound and a read on the enemy.** Pips exist; add a soft tick per stack and a
  louder chord when Nova consumes ≥ 2.
- **Encounters only exist at the stair foot.** The whole climb above z = 6 is empty. Place camps at
  each landing and at the summit approach (use the `Demo/WP*` markers as anchors), escalating:
  foot = wretch/crawler, landing = +leaper, summit = spitter pairs behind melee.

### B3. Movement

- Jump is a 5.2 m/s, 16 g arc (0.85 m apex). With leapers covering 13 m the player now needs
  vertical options: add **variable jump height** (release jump early → `velocity.y *= 0.5`) and
  keep coyote/buffer.
- No **air control floor**: `air_accel 4` makes direction changes in the air near-impossible;
  raise to 6 and clamp to 60 % of ground speed.
- **Slope speed**: stairs at 46° max floor angle are walked at full speed both ways. Scale target
  speed by `1 − 0.25·max(0, up·slope)` uphill for weight.
- **Foot IK** still missing (handover gap). On the stair the feet float or sink every step. The
  rig is plain Node3D joints, so engine IK nodes don't apply: raycast down from each `foot_*`
  socket and solve hip/knee analytically (two-bone, law of cosines) toward the hit point.

### B4. Skill variety — next steps

The system is data-driven now; growth should be loadout, not more buttons:
1. **Skill pool + loadout UI**: 8–10 skills, 5 slots, swap at braziers (fits the checkpoint loop).
   Candidates: *Gloomtide* (spend 20 Gloom → 3 s of double bolt rate), *Chain Hex* (bolt that
   jumps to 2 marked targets), *Grasp* (pull one enemy to you), *Pyre* (convert a lit brazier
   into a 4 s AoE).
2. **Modifiers on braziers**: each kindle offers 1 of 3 rune modifiers (bolt +1 mark; Nova radius
   +1 m; step leaves a Ward for 1 s). Store on `SkillBook` as an `Array[Resource]` that skills
   query.
3. Save the loadout to `user://` with Settings-style debounce.

### B5. Other deep-dive findings

- **Uncommitted foreign changes**: before this pass, `git status` already showed edits to
  `lantern_piece.gd`, `character_rig.gd`, `default_loadout.gd`, `atmosphere.gd`, `bake_main.gd`
  (the lantern swing was removed from the rig). Review them before committing so they don't ride
  in under the skills commit.
- **Agent VM can't commit**: the linked shell can't delete files, so git leaves `.lock` files.
  Commit from your Mac Terminal or Cursor.
- `Enemy.sleep()` now disables processing at 46 m — but leapers/spitters woken at 46 m still
  check line of sight every think tick; fine at 8 enemies, revisit at 30+.
- `HitText`, `SpitOrb`, `LanternWard` are new runtime nodes under `current_scene`; Travel's
  scene change frees them — pools prune dead refs on use.
- HUD Gloom bar lerps to red past 50 %; with Gloom now also a cost, show the *pending* cost as a
  ghost segment while charging Lance.
