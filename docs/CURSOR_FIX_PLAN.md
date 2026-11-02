# Umbral Reaches — Fix Plan for Cursor (2 Nov 2026)

Source: full read of first-party code (~17k lines GDScript/GLSL/Python, addons excluded), `project.godot`,
`world/main.tscn` stats, asset hashes. Every item cites file:line as of today.

## How to execute this plan (read first)

- Work **phase by phase, item by item**. One item = one commit. Each item has an **Accept** line: do not
  move on until it passes.
- **Binding constraints that still hold** (from `.cursor/rules/umbral-constraints.mdc`): no anti-aliasing
  of any kind (owner likes the hard-edged look); never `--headless` bake `main.tscn`; glow budget
  (0.62 / 0.06 / 1.15, levels 0–1); Mac `.app` packed via the Linux preset; don't pkill the owner's editor.
- Where this plan contradicts other docs, **this plan wins** until Phase 5 consolidates the docs.
- Never playtest in a container. Owner playtests on his M4 Pro Mac.

---

## Phase 0 — Safety net (do before anything else)

### 0.1 There is no version control
`git status` → "not a git repository". 553 MB project, an agent editing it daily, and the only undo is
`*.bak` files. **This is the single highest risk in the project.**
- `git init`, `git lfs install`, track `*.glb *.png *.jpg *.tga *.blend *.res *.wav *.ogg` with LFS.
- Extend `.gitignore`: `.godot/`, `build/`, `*.tmp`, `*.blend1`, `docs/anim/`, `/tmp*`, `.DS_Store`.
- First commit = current state, tag `baseline-2026-11-02`.
- **Accept:** `git log` shows the baseline; `git lfs ls-files | wc -l` > 0.

### 0.2 Take real numbers before optimising
The F3 overlay and F8 benchmark currently measure the wrong things (see 2.9). Fix 2.9 first, then record on
the Mac at fullscreen, standing at: sanctuary, mid-stair, summit facing rift.
- Record: avg fps, 1% low, **GPU ms**, CPU ms, draw calls, primitives, and **boot-to-first-frame ms**
  (add `var t0 := Time.get_ticks_usec()` at top of `Zone._ready`, print delta in `finish_zone_setup` and
  again after the first `process_frame`).
- Save as `docs/perf_baseline.md`. Every Phase 2 item re-measures against it.

---

## Phase 1 — Correctness bugs

### 1.1 Camera look is tied to the 60 Hz physics tick (input latency + judder at 120 fps)
`player.gd:101-102,119-122,167,203` — mouse/stick look writes `_yaw/_pitch`, but they are only applied to
`_rig`/`_pitch_node` inside `_physics_process`. With `physics_interpolation=true` the rig is a child of the
body, so the view is interpolated one tick behind: ~16.7 ms extra latency, and at 120 Hz the camera
rotation only changes every other frame before interpolation smooths it.

Method (Godot's documented pattern for interpolated cameras):
```gdscript
# player.gd
func _ready() -> void:
    ...
    _rig.top_level = true
    _rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _process(delta: float) -> void:
    # stick look moves here from _physics_process
    var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")  # add actions in InputSetup
    if look.length() > 0.15 and not autopilot:
        _yaw -= look.x * stick_sensitivity * delta
        _pitch = clampf(_pitch - look.y * stick_sensitivity * delta, pitch_min, pitch_max)
    var body_xf := get_global_transform_interpolated()
    _rig.global_position = body_xf.origin + Vector3(0, CAMERA_RIG_HEIGHT, 0)  # use current local offset
    _rig.global_rotation = Vector3(0.0, _yaw, 0.0)
    _pitch_node.rotation.x = _pitch - _land_dip * 0.12
```
- Movement wish still reads `_yaw` in `_physics_process` (that's fine; it's the latest value).
- Remove the `_rig.rotation = ...` line in `_physics_process` and the pitch write in `_update_camera`.
- Replace raw `Input.get_joy_axis(0, ...)` with named actions (`look_*`) so device 0 isn't hard-coded.
- **Accept:** at 120 fps with physics at 60, fast mouse flicks show no stair-step; FOV kick and land dip still work.

### 1.2 Frame-rate-dependent smoothing everywhere
`lerp(a, b, clampf(k * delta, 0, 1))` is not frame-rate independent (it converges faster at low fps and
clamps to a snap below 1/k s). Occurrences: `player.gd:145,196,210,378,383,403`,
`character_rig.gd:219,235`, `enemy.gd:380`.
Method: `lerp(a, b, 1.0 - exp(-k * delta))` (same for `lerp_angle`, `Vector3.lerp`). Keep the same `k`
values — the curve matches at 60 fps closely enough; re-tune only if feel changes.
- **Accept:** set `Engine.max_fps = 30` then `240`; accel/turn/feel identical to the eye.

### 1.3 Light policy is not idempotent (values drift every time it runs)
`light_policy.gd:114-150` multiplies `light_energy`/`omni_range` in place; guarded by `_illum` meta, but
- `brazier.gd:70` then overwrites `omni_range` with `lit_range` on kindle → the ×1.22 "beacon" grow is lost
  after kindling but present before; unlit braziers get the ×1.35 "fill" grow on a 2.5 m range.
- `brazier.gd:87` overwrites `light_energy` every frame → the energy multipliers on beacons are dead code.
- Classification depends on *when* it runs (brazier meta is "fill" at load, "beacon" later).

Method: make lights a pure function of (authored base, class, settings).
```gdscript
# light_policy.gd
static func _base(light: Light3D) -> Dictionary:
    if not light.has_meta(&"base"):
        var o := light as OmniLight3D
        light.set_meta(&"base", {"e": light.light_energy, "r": o.omni_range if o else 0.0,
                                 "a": o.omni_attenuation if o else 1.0})
    return light.get_meta(&"base")

const ILLUM := { &"beacon": [1.0, 1.22, 1.05], &"fill": [1.55, 1.35, 1.0], ... } # [energy, range, atten]

static func energy_mult(kind: StringName) -> float: return ILLUM.get(kind, [1.0,1.0,1.0])[0]
static func apply_illumination(light: Light3D) -> void:
    var b := _base(light); var m: Array = ILLUM.get(classify(light), [1.0, 1.0, 1.0])
    light.light_energy = b.e * m[0]
    if light is OmniLight3D:
        light.omni_range = b.r * m[1]; light.omni_attenuation = m[2]
```
- Brazier: store `lit_range`/`lit_energy` as the base (`set_meta(&"base", …)` in `_set_lit`), then call
  `apply_illumination`; in `_process` use `base_e * LightPolicy.energy_mult(kind) * flicker`.
- Delete the `_illum` meta.
- **Accept:** call `apply_all` 10× in a row and toggle a brazier: a debug dump of every light's
  energy/range is byte-identical across runs.

### 1.4 Terrain normals are wrong on every slope
`world/zones/terrain.gdshader:45-53` samples rock normals with *world-projected* UVs but writes them to
`NORMAL_MAP`, which Godot interprets in the mesh's *tangent* space. On cliffs the bumps light from the
wrong direction. Also `wnrm` uses `MODEL_MATRIX` (wrong under non-uniform scale).

Method: whiteout triplanar blend in world space, then write `NORMAL` (view space) instead of `NORMAL_MAP`.
```glsl
varying vec3 wpos; varying vec3 wnrm;
void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 unpack(sampler2D t, vec2 uv) {          // RG-only safe (BC5/RGTC normal maps have no usable B)
    vec2 xy = texture(t, uv).rg * 2.0 - 1.0;
    return vec3(xy, sqrt(max(1.0 - dot(xy, xy), 0.0)));
}
vec3 triplanar_normal(sampler2D t, float s, vec3 w) {
    vec3 sgn = sign(wnrm);
    vec3 nx = unpack(t, wpos.zy * s); vec3 ny = unpack(t, wpos.xz * s); vec3 nz = unpack(t, wpos.xy * s);
    nx = vec3(nx.xy + wnrm.zy, abs(nx.z) * wnrm.x);
    ny = vec3(ny.xy + wnrm.xz, abs(ny.z) * wnrm.y);
    nz = vec3(nz.xy + wnrm.xy, abs(nz.z) * wnrm.z);
    return normalize(nx.zyx * w.x + ny.xzy * w.y + nz.xyz * w.z);
}
// fragment: vec3 n_ws = mix(rock_n_ws, ground_n_ws, flatness);
//           NORMAL = normalize((VIEW_MATRIX * vec4(n_ws, 0.0)).xyz);
```
- Verify sign handling on the -X/-Z faces with a checker normal map in `world/lab/light_lab`.
- `cavity`/`wet` (lines 55-58) read `NORMAL_MAP.b`. With Godot's normal-map import (RGTC) the blue channel
  is not the authored blue. Derive cavity from the reconstructed tangent z of the ground normal, or pack a
  cavity/AO map into ground albedo alpha in `tools/gen_textures.py`. **Check** the import dock of
  `ground_normal.png` to confirm compression mode first.
- **Accept:** in light_lab, rotate the moon around a cliff: highlights track the light on all four sides.

### 1.5 Bolt spawns at the world origin for one frame
`player.gd:335-345` — `host.add_child(bolt)` runs `_ready` (collision shape + visuals) at (0,0,0), then the
position is set. Method: set `bolt.transform = Transform3D(Basis.looking_at(aim), muzzle + aim * 0.28)`
**before** `add_child` (host is the scene root, so local == global). **Accept:** print bolt
`global_position` in its `_ready` → equals muzzle.

### 1.6 The auto render scale is a no-op, and the 960 cap blurs the HUD
`zone.gd:94-120` + `project.godot [display] stretch/mode="viewport"`:
- `_apply_resolution_cap` shrinks `content_scale_size` to 960 tall. With `stretch=viewport` that scales
  **everything, including the HUD and Cinzel text**, then upsamples → soft UI.
- `_apply_render_scale` auto mode computes `sqrt(960²·16/9 / (w·h))` on a viewport that is *already*
  960 tall → ≈1.0 always. Two resolution systems, one does nothing.

Method:
- `project.godot`: `window/stretch/mode="canvas_items"`.
- Delete `_apply_resolution_cap`. Single source: `scale_3d = Settings.render_scale if > 0 else
  minf(1.0, float(Settings.render_height_cap()) / float(get_window().size.y))`.
- Keep `SCALING_3D_MODE_BILINEAR` (no AA rule: **do not** switch to FSR2/MetalFX temporal; FSR1 is
  spatial-only but adds sharpening — only offer it as an opt-in setting).
- **Accept:** fullscreen on the Retina panel: F3 shows 3D at ~960 tall, HUD text is pixel-sharp.

### 1.7 F8 benchmark runs under vsync
`main.gd:116-121` — only `--bench` disables vsync (line 158). F8 in game is capped at the refresh rate, so
"avg 120" means nothing. Method: in `_start_benchmark` remember the vsync mode, set
`VSYNC_DISABLED`, restore in `_finish_benchmark`. **Accept:** F8 reports >120 where the GPU allows.

### 1.8 Shade can stalemate the loop
`shade.gd:113-117` + `player.gd:226` — the shade flies through walls but refuses to touch through them
(`_blocked`). If the player is at 100 Gloom behind geometry, the shade hovers forever, no new shade spawns,
no Hollow. Method: track `_blocked_t`; after 2.5 s blocked, lift the shade's goal by +3 m and steer around
(or slide to the nearest unblocked point on a ring around the player via 8 ray probes).
**Accept:** stand in a nook at 100 Gloom → Hollowed within ~6 s.

### 1.9 Spawner probes physics before bodies exist
`enemy_spawner.gd:39-50` runs `_ground()` ray/shape queries in `_ready`. With Jolt, statics added this
frame may not be queryable until the first physics step → spawns can fall back to `y=0.6`. `glimmers.gd:22`
already awaits a physics frame; be consistent. Method: `await get_tree().physics_frame` at the top of
`_plant()`. Also cache the `CapsuleShape3D` in a `static var` instead of `new()` per call.

### 1.10 Smaller correctness items
- `input_setup.gd:25,27` — Escape is bound to both `toggle_settings` and `release_mouse`; the result depends
  on node order. Make Escape `toggle_settings` only; settings menu releases the mouse when it opens.
- `hud.gd:178` toggles debug with `Input.is_action_just_pressed` in `_process`; move to
  `_unhandled_input` + `set_input_as_handled()` like the rest.
- `player.gd:276-279`, `magic_bolt.gd:72` — `await` on timers then touch `self`; add
  `if not is_inside_tree(): return` after each await (scene change mid-await = errors).
- `atmosphere.gd:153` — `bark_giant` albedo `(1.25, 1.35, 1.75)`: albedo > 1 reflects more light than it
  receives (breaks energy conservation, blows out under bloom). Clamp ≤ 0.9 and raise light/emission
  instead.

---

## Phase 2 — Performance (target: 120 fps @ 1080p-class on M4 Pro; measure each item)

### 2.1 Sky radiance re-renders every frame for no reason  ★ biggest cheap win
`atmosphere.gd:409` sets `Sky.PROCESS_MODE_REALTIME`. Process mode only controls the **radiance cubemap**
(reflections/ambient). The visible sky animates regardless. Your `vortex.gdshader:52-60` cubemap branch is
already static (no `TIME`), so realtime re-renders 6 faces + filtering every frame to produce an
identical image.
Method: `env.sky.process_mode = Sky.PROCESS_MODE_QUALITY` (radiance computed once / on param change).
**Accept:** GPU ms drops; reflections on stone unchanged; vortex still spins.

### 2.2 Grade pass forces a screen-texture mip chain every frame
`grade.gdshader:3` — `hint_screen_texture, filter_linear_mipmap` makes Godot generate mipmaps of the full
screen copy each frame, but the shader only samples LOD 0. Method: `filter_nearest` (also crisper, matches
the no-AA look). Also:
- Centre tap is fetched twice (lines 40 & implicit in blur): fetch centre once as `c`, use `c.g` for G.
- Grain hash `sin(dot(SCREEN_UV*1400 + TIME*0.7, …))` loses precision as `TIME` grows (pattern degrades
  after long sessions). Use an integer hash on `uvec2(FRAGCOORD.xy)` xor a frame seed
  `uint(fract(TIME * 17.0) * 65536.0)`.
- Optional (Phase 3): bake hue-pull + split-tone + saturation + black-crush into a 32³ LUT with a tool
  script and set `Environment.adjustment_color_correction`; keep only sharpen/CA/vignette/gloom/grain in
  the canvas shader. Removes `rgb2hsv`/`hsv2rgb` per pixel.
- **Accept:** identical screenshot (diff < 1/255 except grain) and lower GPU ms.

### 2.3 Foliage: 139 MultiMesh chunks all have their origin at world (0,0,0)
`atmosphere.gd:208-213,247-270` comments confirm it: visibility ranges measure distance to the **node
origin**, so they can't cull chunks, so every chunk is "pinned" and drawn (×shadow cascades) whenever its
AABB touches the frustum. `_repair_floor_aabb` then walks every instance in GDScript at boot.
Method (in `tools/bake_main.gd`, `_ground_cover()`):
- Bucket instances into **16 m × 16 m cells**; one `MultiMeshInstance3D` per (cell, kind); set the node
  position to the cell centre and store instance transforms **relative to it**.
- Set `custom_aabb` at bake time (already a rule) — then delete `_repair_floor_aabb`.
- Per kind: `visibility_range_end` (grass 28 m, ferns 40 m, caps 45 m),
  `visibility_range_fade_mode = DISABLED` (FADE_SELF is documented as slower and routes the mesh through
  transparency during the fade — wrong for alpha-scissor foliage), `cast_shadow` off for grass.
- Bake with a GPU context, never headless (existing rule).
- **Accept:** draw calls at mid-stair drop by >40%; no visible pop within 20 m.

### 2.4 Enemies are ~60 draw calls each, unbatched
`enemy_body.gd:27-80` builds 50–70 `MeshInstance3D`s per enemy (fingers, claws, fangs…), each with a
**new** `CylinderMesh`/`SphereMesh` resource, and `enemy.gd:173-182` disables culling on all of them
(`ignore_occlusion_culling`, extra margin).
Method, tier 1 (do now): per kind, merge all primitives under each joint into **one `ArrayMesh` per joint
per material** with `SurfaceTool.append_from(mesh, 0, local_xform)`; cache in
`static var _joint_meshes := {}` keyed `kind/joint/material`; every enemy of that kind reuses the same
resources. ~60 → ~14 draws, shared GPU buffers.
Tier 2 (later): one `Skeleton3D` + single skinned mesh with rigid 1-bone weights → 1 draw per material.
Remove `_pin_visuals` culling overrides except for the HP bar.
- **Accept:** F3 draw calls with 3 wretches on screen drop by ≥120.

### 2.5 Per-frame tree walks and allocations
- `player.gd:294-312` `_scan_interactables`: `get_nodes_in_group` (array alloc) + `sqrt` distance every
  physics tick. Method: you already defined `Layers.INTERACT` (8) but never use it. Give interactables an
  `Area3D` on layer INTERACT, give the player an `Area3D` sensor (mask INTERACT, radius 3.2) and keep a
  candidate list via `area_entered/area_exited`; pick best by `distance_squared_to` only over candidates.
- `enemy.gd:265-271,445` `_player_planar` builds a Dictionary and calls `get_first_node_in_group` up to
  3× per enemy per physics frame. Method: cache `var _p: Player` (resolve once, re-resolve if
  `not is_instance_valid`), compute `_to`, `_dist` once per tick into members.
- `zone.gd:88-91` `refresh_lights` walks `get_tree().root` and fills `_omni_lights`, which is **never read**.
  Delete it (and the call in `glimmers.gd:42-43`), or make it the cached list for 2.6.
- `zone.gd:53-55` sets the `gloom` shader param every frame; only set when `_gloom_vis` changed
  (`if not is_equal_approx`).
- `hud.gd:184` calls `load()` on boot_diag every frame while F3 is open; preload once.

### 2.6 Settings changes re-walk the whole scene
`zone.gd:82` → `atmosphere.apply_zone_settings` → `light_policy.apply_all` → `find_children("*","Light3D")`
over the whole tree, and `classify()` builds `str(get_path())` per light. Dragging a slider fires this
**every frame** (`settings.gd:80-84`).
Method: build `var _lights: Array[Light3D]` once in `finish_zone_setup` (plus `Glimmers` registering its
own via a signal); `apply_zone_settings` only toggles shadows/fog/SSAO on the cached list; cache each
light's class in meta at first classify. Coalesce: `Settings.apply()` emits `changed` at most once per
frame (`call_deferred` flag).

### 2.7 Runtime "dressing" costs load time and stutter
At boot the game runs: `gothic.raise` (gobo built with 32 768 `set_pixel` calls, `gothic.gd:98-115`),
`dressed_props` (triangle island union-find + mesh rebuild, `dressed_props.gd:291-360`), `seat_props`,
`demo/night/summit_dress`, `stone_bodies`, `glimmers` scatter, `atmosphere` occluder generation, canopy
duplication, MultiMesh AABB repair, three `ReflectionProbe`s with `UPDATE_ONCE` (6-face renders on frame 1),
and `boot_diag` loading 16 GLBs (2.8).
Method: see 3.1 — move all deterministic dressing to bake time. Interim quick wins:
- Save the gobo once as `art/textures/window_gobo.png` and `preload` it.
- Gate `boot_diag` (2.8).
- **Accept:** boot-to-first-frame ms (0.2) drops; no hitch on first frame.

### 2.8 Debug code ships in release
`zone.gd:34-46` runs `boot_diag.run()` every boot (writes a log, loads 16 GLBs). Method:
`if OS.is_debug_build() or "--diag" in OS.get_cmdline_user_args():`. Same for `deepdive_rec`,
`--walk-rec`, `--demo`, `--test-shade` parsing paths (fine to keep, but no work unless flagged).
Remove the 4 addon autoloads in 5.1 (Beehave debugger/metrics, DialogueManager, PhantomCameraManager run
every frame for nothing).

### 2.9 The perf overlay reports the wrong metric
`hud.gd:188-191` labels `Performance.TIME_PROCESS` as frame ms — that's script `_process` CPU time only.
Method:
```gdscript
var rid := get_viewport().get_viewport_rid()
RenderingServer.viewport_set_measure_render_time(rid, true)   # once, in _ready
# per refresh (4 Hz, not every frame):
var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
```
Show `frame ms (1000/fps)`, `GPU ms`, `render CPU ms`, `process ms`, `physics ms`. Refresh text at 4 Hz.

### 2.10 Bolts allocate a full material/particle set per shot
`magic_bolt.gd:108-229` creates `ParticleProcessMaterial`, `Curve`, `CurveTexture`, `Gradient`,
`GradientTexture1D`, `ShaderMaterial`, `QuadMesh`, `OmniLight3D` per bolt, plus a new shock sphere +
material per hit. New resource instances can trigger pipeline compilation hitches on first use and churn
memory. `_burst_pool` is `static` and keeps dead refs after scene change (never pruned).
Method: author `magic_bolt.tscn` with all visuals as **shared sub-resources** (heavy variant = second
scene or swapped exported resources); `_ready` only sets per-instance values. Pool 12 bolts + 6 bursts +
6 shock meshes on the Zone (not static). Prewarm: spawn one bolt + burst at zone load 100 m below the map.
Replace the per-tick proximity `intersect_shape` (`magic_bolt.gd:46`) with an `Area3D` child (mask HURTBOX)
and `has_overlapping_bodies()`.

### 2.11 Terrain shader fetch count
`terrain.gdshader` does ~11 texture fetches per pixel everywhere, including flats where rock weight is 0.
Method: compute `flatness` first; `if (flatness < 0.999)` around rock fetches, `if (flatness > 0.001)` around
ground; skip triplanar axes with weight < 0.01; make `detail` a `#define` / `uniform bool` (compile-time
off for Performance preset via a second material). Coherent branches are cheap on Apple GPUs.

### 2.12 Renderer backend
All your commands force `--rendering-driver vulkan` (MoltenVK translation on macOS). Godot 4.7 has a
native Metal driver. **Benchmark both** with the fixed F8 (0.2) at the three standing points; keep the
faster as the export default (`rendering/rendering_device/driver.macos`). Don't enable MetalFX temporal
(no-AA rule).

---

## Phase 3 — Architecture

### 3.1 Stop dressing the world at runtime; bake dress into a separate scene
Root cause of most fragility: the headless bake wiped MultiMesh data once, so the project banned
re-baking and moved everything into runtime patch scripts. Result: the editor shows a different world from
the game, load is slow, and logic is order-dependent.
Method:
1. New tool `tools/bake_dress.gd` (GPU context, same as `bake_main`): instantiate `main.tscn`, run the
   deterministic dress functions (`gothic.raise`, `dressed_props.dress_zone`, `seat_props`, glimmer
   scatter with fixed seed, occluders, canopy fill), then move **only the created nodes** under a new root,
   set `owner` recursively, and `ResourceSaver.save(PackedScene)` to
   `world/zones/ascension/dress.tscn`. `main.tscn` is **not** re-baked — it just instances `dress.tscn`.
2. Runtime keeps only what's dynamic: player, enemies, shades, light flicker/pulse, Settings.
3. Runtime dress scripts become `@tool` bake helpers, never called from `_ready`.
- **Accept:** opening `main.tscn` in the editor shows the same world as the game; boot time down; F3 draw
  calls unchanged or lower.

### 3.2 Replace name-substring classification with explicit tags
`atmosphere.gd:27-45,191-320,362-371`, `light_policy.gd:7-31`, `glimmers.gd:65-67` decide culling,
particle thinning, shadow policy and occluders by `String(name).contains("cap"|"arch"|"walk"|"leaf"|…)`.
`"cap"` matches `Landscape`/`Escape`, `"arch"` matches `Larch`, renaming a node silently changes rendering.
Method: the bake assigns **groups** (`cull_span`, `cull_small`, `cull_foliage`, `occluder_trunk`) and lights
get `set_meta(&"light_class", …)` at creation (gothic/brazier already do — extend to all). Policies read
only tags; unknown → log once and use default. Delete `_skips_range`, `_is_span_mesh`, `_named_under`,
path-string checks.

### 3.3 Stop mutating shared `.tres` materials at runtime
`atmosphere.gd:131-166` rewrites `stone.tres`, `rock.tres`, `bark*.tres`, `terrain.tres`, `crystal.tres` in
memory on every zone load. The files on disk are not what the game renders; tuning them in the editor
does nothing. Method: copy the runtime values into the `.tres` files once, delete `_darken_unlit`.

### 3.4 Replace `load("res://x.gd").func()` with `class_name` + `preload`
75 runtime `load("res://…")` calls; 28 of the `load(...).method(...)` pattern (atmosphere, light_policy,
dressed_props, enemy_body, gothic, glimmers, seat_props…). These are untyped (no autocompletion, no
static errors) and hit the resource cache each call.
Method: give each static helper a `class_name` (`Atmosphere`, `LightPolicy`, `EnemyBody`, `Gothic`, …) and
call directly. Where a cycle prevents `class_name`, use `const X := preload(...)` at file top. Spawner:
`_scripts` → `{"wretch": Wretch, ...}` and delete `Enemy.spawn()` + its "null on dynamically loaded
script" workaround (that problem only exists because of `load`).
Also remove string reflection on privates: `main.gd:57-58` `_player.set("_yaw", …)` and
`set_meta("force_wish")` (`player.gd:127-130`) → give Player a public `debug_drive(wish: Vector3,
sprint: bool)` and `set_view(yaw, pitch)`.

### 3.5 Enemy sleep/wake is dead code
`enemy.gd:157-166` — `wake()` and `sleep()` do the same thing; `sleep_range` (46 m) is unused; all enemies
tick physics forever. Method: spawner checks distance to player at 2 Hz;
beyond `sleep_range` → `process_mode = PROCESS_MODE_DISABLED` (stay visible, per the existing comment);
within → `INHERIT`. Rig animation already gated at 16 m (`enemy.gd:372`) — keep.

### 3.6 Travel loads synchronously during the fade
`travel.gd:64` `load(path)` blocks the main thread; `_wait_for_scene` (95-108) polls by file/name match.
Low priority (one zone today) but fix before the next night: `ResourceLoader.load_threaded_request` when
the fade starts, poll `load_threaded_get_status` each frame, `change_scene_to_packed` when loaded; then
await frames until `get_tree().current_scene != old_scene`.

### 3.7 Rig: shared cloth materials
`character_rig.gd:370-417` makes a unique `ShaderMaterial` per cloth surface and sets 6 uniforms per
material per frame (316-322). Method: one material per cloth *type* (coat/hood/sleeve) with the
per-frame values as `instance uniform`s set via `set_instance_shader_parameter` on each MeshInstance3D,
and only when the value changed beyond epsilon. `robe_wave.gdshader` displaces vertices without updating
`NORMAL` — acceptable for wool, but if hem lighting looks flat, recompute normal by finite difference of
the displacement function (two extra evaluations).

---

## Phase 4 — Gameplay and feel

- **Auto-bunny-hop** (`player.gd:156`): holding Space re-buffers a jump every landing. Intended? If not,
  only `is_action_just_pressed` buffers.
- **Cast feedback**: `cast()` has a 0.42 s CD but no hit-stop / camera impulse. Add 40 ms hit-stop on enemy
  hit (`Engine.time_scale` is banned by the rules → instead freeze the enemy's `_state_t` and rig for 3
  physics frames) and a 0.15° camera shake via the pitch node.
- **Gloom signal spam**: `player.gd:224-225` emits every physics tick while changing; HUD and Zone both
  respond. Emit only when the value crosses a 0.5-unit step or every 0.1 s.
- **No audio at all** (handover §8 lists it as the biggest gap). Minimum: footstep per stride half-cycle
  from `CharacterRig._phase`, brazier loop (AudioStreamPlayer3D on the brazier, per the "no
  AudioManager" rule), shade whisper rising with Gloom, bolt cast/impact. Use `AudioStreamRandomizer` for
  variation.
- **Interact prompt** hard-codes "[E]" (`brazier.gd:38`) — read the bound key/button from InputMap so
  gamepad shows X.

---

## Phase 5 — Repo hygiene

### 5.1 Unused addons (14 MB + 4 autoloads running every frame)
First-party references: phantom_camera 0, proton_scatter 0, dialogue_manager 0, spatial_gardener 0,
boujie_water_shader 0, beehave only via `core/enemy/shade_beehave.gd` (itself unreferenced dead stub).
Method: remove the four addon autoloads from `[autoload]`, disable the plugins, move the addon folders out
of the project (keep a zip). Delete `shade_beehave.gd`, orphan `dialogue/wastes_intro.dialogue.import`.

### 5.2 49 MB water-shader demo and 43 MB of capture PNGs are imported (and exportable)
`example/` (addon demo) and `docs/anim/*.png` have `.import` files, and the export presets use
`export_filter="all_resources"` with `exclude_filter="tools/*, *.md, assets/*"` → both can end up in the
`.pck`. Method: delete `example/`; add `.gdignore` to `docs/` (and remove the `docs/*.import`); exclude
filter becomes `tools/*, docs/*, example/*, *.md, assets/*, art/blender/*`.

### 5.3 Duplicate textures
md5 shows identical files: dwarf skin/cloth/leather/beard/iron albedo/normal/rough duplicated **5×**
(`art/models/dwarf_{bartender,patron_a,patron_b,patron_c}_*.png` + `art/textures/dwarf_*.png`), and
`rock_moss_{diff,nor}.jpg` 3×. Each copy is a separate VRAM texture at runtime. Method: re-export the
dwarf GLBs with external textures pointing at `art/textures/dwarf_*` (or set the GLB import to use
external materials and point all four at shared `.tres`), then delete the copies.

### 5.4 Unreferenced assets
Heuristic scan: 115 files / ~37 MB in `art/` with no `res://` path or filename reference in any
`.gd/.tscn/.tres/.import`. Method: list them (`tools/orphans.py`: parse all text resources + GLB import
external refs), owner reviews, move to `art/_unused/` with a `.gdignore`.

### 5.5 Dead code
`core/player/robe_cloth.gdshader`, `core/player/arcane_robe.gdshader` (0 refs), `world/lab/light_lab.gd`
(0 refs — keep if used manually, otherwise move to `tools/`), `Zone._omni_lights`, `Enemy.spawn`,
`CharacterRig._cape` naming ("leftover from rejected cape" — rename `_hem_spring`), husk/crawler/leaper
are registered but never spawned (fine, but note it).

### 5.6 Agent docs contradict each other (this causes regressions)
Six overlapping instruction sources (README, AGENTS, AGENT_HANDOVER — which calls itself stale,
DARK_FANTASY_REVIEW 41 KB, perfecting_umbral_reaches 124 KB, 2 rules + 31 skills = 364 KB) disagree:
1080 vs 960 cap; FXAA claimed but AA is off (correctly); `world/vale.gd` referenced but removed; "no
skeletal animation / primitives" vs current GLB robe; Windows build paths that don't exist.
Method: one `ARCHITECTURE.md` (current truth, ≤ 2 pages), one `.cursor/rules/umbral-constraints.mdc`
(do-not-undo list only), this plan; move everything else to `docs/archive/` with `.gdignore`. Add a
"last verified" date line to each living doc.

---

## Priority summary (do in this order)

| # | Item | Why first |
|---|------|-----------|
| 0.1 | git + LFS | No undo exists today |
| 2.9, 1.7, 0.2 | Correct metrics, baseline | Can't optimise blind |
| 2.1 | Sky QUALITY mode | One line, large GPU win |
| 1.1 | Camera in `_process` | Felt every frame |
| 1.6 | canvas_items stretch | HUD sharpness + removes dead system |
| 2.2 | Grade nearest + hash | One line + small edit |
| 1.3, 2.6 | Idempotent light policy + cached list | Fixes drift and slider hitches |
| 1.4 | Terrain normals | Visible lighting bug on every cliff |
| 2.3 | Foliage cells with real origins | Largest draw-call cut |
| 2.4 | Enemy mesh merge | Second largest draw-call cut |
| 3.1–3.4 | Bake dress, tags, no runtime .tres edits, class_name | Removes the fragility class |
| 5.x | Hygiene | Smaller repo, smaller pck, saner agents |
