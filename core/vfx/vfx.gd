class_name Vfx
extends RefCounted
## One-shot combat effects shared by skills, enemies and movement: particle bursts (optionally
## with ribbon trails), persistent emitters, ground shockwave rings, flash lights, ribbon streaks,
## jagged arcs and scorch decals. All GPU resources are built once and cached by preset, so a
## burst costs one node; nodes free themselves when done.
##
## Colours are HDR on purpose (> 1 blooms under the tight glow budget: threshold 1.15).

const ShotLight := preload("res://core/vfx/shot_light.gd")
const Access := preload("res://ui/access.gd")
const RING_SHADER := preload("res://world/vfx/ring_wave.gdshader")

static var _dot: GradientTexture2D
static var _scorch_tex: GradientTexture2D
static var _draw_mats := {}
static var _procs := {}
static var _quads := {}
static var _trail_meshes := {}
static var _ring_mats := {}
static var _ring_mesh: PlaneMesh
static var _fade: GradientTexture1D


## Drop every engine resource held in a static (the night is torn down: BoltPool._exit_tree).
## Statics outlive the renderer at quit, and a rebuilt night should not inherit the last one's
## presets. Pooled emitters are children of the scene going away, so the pool only forgets them.
## Rebuilt on next use. (The exit "ParticlesShaderRD never freed" is NOT these: it survives this
## release -- see the r36 note in core/player/bolt_pool.gd.)
static func release() -> void:
	_dot = null
	_scorch_tex = null
	_scorch_glow_tex = null
	_draw_mats.clear()
	_procs.clear()
	_quads.clear()
	_trail_meshes.clear()
	_ring_mats.clear()
	_ring_mesh = null
	_fade = null
	_pool.clear()
	_keys.clear()
	_idle_total = 0
	_star_tex = null
	_flash_mats.clear()
	_flash_pool.clear()                     # the pooled flash lights went with the night
	_flash_host = 0
	_flash_quad = null


static func host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree else null


# --- particles ------------------------------------------------------------------------------

## opts: count, life, speed (Vector2 min/max), size, gravity (float, +up), spread (deg),
##       dir (Vector3), radius (emission sphere), ring (emission ring radius), damping,
##       additive (bool), trail (seconds, 0 = none), radial (radial accel), scale_var.
## Bursts are pooled per preset: busy fights used to allocate (and free) dozens of new
## GPUParticles3D per second, and relying on `finished` alone could leak nodes when it never
## fired. Each burst now reuses an idle emitter of the same preset and is always reclaimed by a
## timer at lifetime + trail + margin.
static var _pool: Dictionary = {}          # preset key -> Array of idle GPUParticles3D
static var _idle_total := 0
static var _keys := {}                     # hash of (colour, opts as given) -> [colour, opts, key, rounded colour, rounded opts]
const POOL_CAP := 16                       # per preset (a nova killing three foes fires a dozen of one preset at once)
const POOL_TOTAL := 160                    # across presets (effects vary radius etc. -> many presets; each kind's death bursts are warmed)


## opts "ratio" (0..1) emits that share of `count` (amount_ratio) without making a new preset: vary
## the size of a burst with it, never with count/speed/etc. -- each distinct opts is a preset kept
## forever (a material in _procs, up to POOL_CAP emitters), so a value per hit grew without bound.
static func burst(at: Vector3, color: Color, opts := {}) -> GPUParticles3D:
	var h := host()
	if h == null:
		return null
	var ratio := 1.0
	var dir := Vector3.UP
	# the direction is the emitter's own turn, not part of the preset: a hit's normal or a blow's line made a
	# preset (a material and up to POOL_CAP emitters) for every direction, the pool filled with one-offs, and a
	# fight built some 25 new particle systems a second. (A ring's axis stays the preset's: it is not turned.)
	var turned := opts.has("dir") and not opts.has("ring")
	if opts.has("ratio") or turned:
		opts = opts.duplicate()
		if opts.has("ratio"):
			ratio = clampf(float(opts.ratio), 0.0, 1.0)
			opts.erase("ratio")
		if turned:
			var d: Vector3 = opts.dir
			if d.length_squared() > 0.0001:
				dir = d.normalized()
			opts.erase("dir")
	# the preset's key (the rounded values as text) is remembered for the values as given: working it out was
	# most of a pooled burst's cost
	var memo: Array = _keys.get([color, opts].hash(), [])
	if memo.is_empty() or memo[0] != color or memo[1] != opts:
		var given := opts
		var given_col := color
		opts = _round_opts(opts)
		color = Color(_sig2(color.r), _sig2(color.g), _sig2(color.b), _sig2(color.a))
		if _keys.size() > 512:
			_keys.clear()
		memo = [given_col, given.duplicate(), "%s|%s" % [color, opts], color, opts]
		_keys[[given_col, given].hash()] = memo
	var key: String = memo[2]
	color = memo[3]
	opts = memo[4]
	var p: GPUParticles3D = null
	var idle: Array = _pool.get(key, [])
	while not idle.is_empty() and p == null:
		var c: Variant = idle.pop_back()
		_idle_total = maxi(0, _idle_total - 1)
		if is_instance_valid(c) and (c as Node).get_parent() == h:
			p = c
	if p == null:
		p = _make(color, opts, true)
		h.add_child(p)
	p.visible = true
	p.global_transform = Transform3D(_turn(dir), at)
	p.amount_ratio = ratio
	p.process_material.set_meta(&"vfx_used", Time.get_ticks_msec())     # the preset's last use (_evict_stale)
	p.restart()
	p.emitting = true
	var life := p.lifetime + (p.trail_lifetime if p.trail_enabled else 0.0) + 0.4
	var tree := h.get_tree()
	var token := Time.get_ticks_usec()
	p.set_meta(&"burst_token", token)
	var pid := p.get_instance_id()          # an id, not the node: a scene change frees it first
	tree.create_timer(life, false).timeout.connect(func() -> void: _reclaim(instance_from_id(pid) as GPUParticles3D, key, token))
	return p


## The turn that takes up (a preset's direction when the burst gives one) to `dir`.
static func _turn(dir: Vector3) -> Basis:
	var c := Vector3.UP.dot(dir)
	if c > 0.9999:
		return Basis.IDENTITY
	if c < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, dir))


static func _reclaim(p: GPUParticles3D, key: String, token: int) -> void:
	if not is_instance_valid(p) or int(p.get_meta(&"burst_token", -1)) != token:
		return                                  # freed with its scene, or already reused
	p.emitting = false
	p.visible = false
	var idle: Array = _pool.get(key, [])
	if idle.size() >= POOL_CAP:
		p.queue_free()
		return
	if _idle_total >= POOL_TOTAL and not _evict_stale(key):
		p.queue_free()
		return
	idle.append(p)
	_idle_total += 1
	_pool[key] = idle


## A full pool makes room by freeing an idle emitter of the preset used longest ago (not this one): before, a
## full pool freed every returning emitter, so after the first one-off presets filled it nothing was pooled and
## every burst in a fight built a new particle system. A preset's last use is stamped on its shared material.

static func _evict_stale(keep: String) -> bool:
	var oldest := ""
	var t := 1 << 62
	for k: String in _pool:
		var idle: Array = _pool[k]
		if k == keep or idle.is_empty() or not is_instance_valid(idle[0]):
			continue
		var used := int((idle[0] as GPUParticles3D).process_material.get_meta(&"vfx_used", 0))
		if used < t:
			t = used
			oldest = k
	if oldest == "":
		return false
	var c: Variant = (_pool[oldest] as Array).pop_back()
	_idle_total = maxi(0, _idle_total - 1)
	if is_instance_valid(c):
		(c as Node).queue_free()
	return true


## Effect numbers to two significant figures (5.135 m -> 5.1, a 0.894 direction -> 0.89): a radius or a
## direction worked out per hit made a new preset (a material and its emitters) every time, never reused.
static func _sig2(v: float) -> float:
	if v == 0.0:
		return 0.0
	var m := pow(10.0, floorf(log(absf(v)) / log(10.0)) - 1.0)
	return roundf(v / m) * m


static func _round_opts(o: Dictionary) -> Dictionary:
	var q := {}
	for k: Variant in o:
		var v: Variant = o[k]
		if v is float:
			q[k] = _sig2(v)
		elif v is Vector2:
			q[k] = Vector2(_sig2((v as Vector2).x), _sig2((v as Vector2).y))
		elif v is Vector3:
			q[k] = Vector3(_sig2((v as Vector3).x), _sig2((v as Vector3).y), _sig2((v as Vector3).z))
		else:
			q[k] = v
	return q


## Same presets, but looping and owned by the caller (charge swirl, slide dust, ward embers).
static func emitter(color: Color, opts := {}) -> GPUParticles3D:
	var p := _make(color, opts, false)
	p.emitting = false
	return p


static func _make(color: Color, opts: Dictionary, one_shot: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(opts.get("count", 32))
	p.lifetime = float(opts.get("life", 0.5))
	p.one_shot = one_shot
	p.explosiveness = float(opts.get("explosive", 0.95 if one_shot else 0.0))
	p.local_coords = bool(opts.get("local", false))
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = _proc(color, opts)
	var additive := bool(opts.get("additive", true))
	var trail := float(opts.get("trail", 0.0))
	if trail > 0.0:
		p.trail_enabled = true
		p.trail_lifetime = trail
		p.draw_pass_1 = _trail_mesh(float(opts.get("size", 0.06)), additive)
	else:
		p.draw_pass_1 = _quad(float(opts.get("size", 0.1)), additive)
	return p


static func _proc(color: Color, opts: Dictionary) -> ParticleProcessMaterial:
	var key := "%s|%s" % [color, opts]
	if _procs.has(key):
		return _procs[key]
	var pm := ParticleProcessMaterial.new()
	if opts.has("ring"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_radius = float(opts.ring)
		pm.emission_ring_inner_radius = float(opts.ring) * 0.85
		pm.emission_ring_height = 0.05
		pm.emission_ring_axis = Vector3.UP
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(opts.get("radius", 0.1))
	pm.direction = opts.get("dir", Vector3.UP)
	pm.spread = float(opts.get("spread", 180.0))
	var spd: Vector2 = opts.get("speed", Vector2(1.5, 4.0))
	pm.initial_velocity_min = spd.x
	pm.initial_velocity_max = spd.y
	pm.gravity = Vector3(0.0, float(opts.get("gravity", -2.0)), 0.0)
	pm.damping_min = float(opts.get("damping", 1.5))
	pm.damping_max = float(opts.get("damping", 1.5)) * 1.6
	pm.radial_accel_min = float(opts.get("radial", 0.0))
	pm.radial_accel_max = float(opts.get("radial", 0.0))
	pm.tangential_accel_min = float(opts.get("swirl", 0.0))
	pm.tangential_accel_max = float(opts.get("swirl", 0.0)) * 1.4
	pm.scale_min = 1.0 - float(opts.get("scale_var", 0.45))
	pm.scale_max = 1.0 + float(opts.get("scale_var", 0.45))
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, float(opts.get("grow", 1.0))))
	sc.add_point(Vector2(1.0, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color = color
	pm.color_ramp = _fade_ramp()
	if bool(opts.get("turbulence", false)):
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.4
		pm.turbulence_noise_scale = 3.0
	_procs[key] = pm
	return pm


static func _fade_ramp() -> GradientTexture1D:
	if _fade == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.6, 1.5, 1.6, 1.0))
		g.add_point(0.25, Color(1, 1, 1, 0.95))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
		_fade = GradientTexture1D.new()
		_fade.gradient = g
	return _fade


static var _scorch_glow_tex: GradientTexture2D


static func _scorch_glow() -> GradientTexture2D:
	if _scorch_glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 0.95])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.45, 0.45, 0.45, 1), Color(0, 0, 0, 1)])
		_scorch_glow_tex = GradientTexture2D.new()
		_scorch_glow_tex.gradient = g
		_scorch_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_scorch_glow_tex.fill_from = Vector2(0.5, 0.5)
		_scorch_glow_tex.fill_to = Vector2(0.5, 0.0)
		_scorch_glow_tex.width = 64
		_scorch_glow_tex.height = 64
	return _scorch_glow_tex


static func dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.6))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 64
		_dot.height = 64
	return _dot


static func _draw_mat(additive: bool, trails: bool) -> StandardMaterial3D:
	var key := "%s%s" % [additive, trails]
	if _draw_mats.has(key):
		return _draw_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# a spark or ribbon that drifts across the lens is a fat white pill: fade it out inside ~1.4 m
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.35
	m.distance_fade_max_distance = 1.5
	if trails:
		m.use_particle_trails = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_texture = dot()
	_draw_mats[key] = m
	return m


static func _quad(size: float, additive: bool) -> QuadMesh:
	var key := "%s%s" % [size, additive]
	if _quads.has(key):
		return _quads[key]
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _draw_mat(additive, false)
	_quads[key] = q
	return q


static func _trail_mesh(size: float, additive: bool) -> RibbonTrailMesh:
	var key := "%s%s" % [size, additive]
	if _trail_meshes.has(key):
		return _trail_meshes[key]
	var r := RibbonTrailMesh.new()
	r.shape = RibbonTrailMesh.SHAPE_CROSS
	r.size = size
	r.sections = 4
	r.section_segments = 2
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	r.curve = c
	r.material = _draw_mat(additive, true)
	_trail_meshes[key] = r
	return r


# --- rings, lights, decals ------------------------------------------------------------------

## Expanding ground (or `up`-facing) shockwave ring.
static func ring(at: Vector3, radius: float, color: Color, time := 0.45, width := 0.08, up := Vector3.UP, energy := 1.0) -> void:
	var h := host()
	if h == null:
		return
	if _ring_mesh == null:
		_ring_mesh = PlaneMesh.new()
		_ring_mesh.size = Vector2(2.0, 2.0)
	var key := "%s|%s" % [color, width]
	if not _ring_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = RING_SHADER
		m.set_shader_parameter("color", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter("width", width)
		_ring_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	mi.material_override = _ring_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)
	var b := Basis.IDENTITY
	if absf(up.dot(Vector3.UP)) < 0.999:
		var x := up.cross(Vector3.UP).normalized()
		b = Basis(x, up, x.cross(up)).orthonormalized()
	mi.global_transform = Transform3D(Basis(b.x * radius, b.y, b.z * radius), at + up * 0.04)
	mi.set_instance_shader_parameter(&"energy", energy)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter(&"progress", v), 0.0, 1.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(mi.queue_free)


const LIGHT_CAP := 12                  ## transient flashes + carried shot lights alive at once
const LIGHT_GROUP := &"vfx_light"


## An effect's HDR colour as a light colour: same hue, brightest channel at 1 (the energy carries power).
static func tone(col: Color) -> Color:
	var m := maxf(col.r, maxf(col.g, col.b))
	if m <= 0.001:
		return Color(1, 1, 1)
	return Color(col.r / m, col.g / m, col.b / m)


## A body's glow colour lifted toward white-hot: the spark colour of a hit on it.
static func hot(g: Color) -> Color:
	return Color(g.r * 0.9 + 0.5, g.g * 0.9 + 0.3, g.b * 0.9 + 0.3)


## Flash light at an effect, in the effect's own colour (`color` may be the HDR effect colour).
## Unshadowed, tweened out. At most LIGHT_CAP are alive (flashes and carried shot lights together): a
## new one beyond the cap takes the place of the lowest-priority, oldest flash, or is dropped when
## everything alive outranks it. `priority`: 0 spark, 1 default, 2 heavy hit / boss, 3 the player's own.
static func light(at: Vector3, color: Color, energy: float, rng: float, time := 0.3, priority := 1) -> void:
	var h := host()
	if h == null or not h.is_inside_tree():
		return
	var l := _flash_light(h, priority)
	if l == null:
		return
	l.light_color = tone(color)
	l.light_energy = energy * Access.flash()          # Reduce Flashes
	l.omni_range = rng
	l.set_meta(&"vfx_pri", priority)
	l.set_meta(&"vfx_born", Time.get_ticks_msec())
	l.global_position = at
	l.visible = true
	var old: Variant = l.get_meta(&"vfx_tween") if l.has_meta(&"vfx_tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := l.create_tween()
	l.set_meta(&"vfx_tween", tw)
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		l.visible = false
		l.remove_from_group(LIGHT_GROUP))


## The flashes are a fixed set of lights kept under the scene and reused (a hit, a swipe, a death, a landing each made an
## OmniLight3D and freed it 0.3 s later: light churn every blow, and the engine's "indexing did not unpair geometries
## from light" when a light died the frame a body near it changed). A free one if any (hidden, out of LIGHT_GROUP);
## else room is made under LIGHT_CAP as before (a lower-priority, older flash gives its light up), else null.
static var _flash_pool: Array = []
static var _flash_host := 0                ## the instance id of the node the pool lives under (an id: no static holds a node across nights)


static func _flash_light(h: Node, priority: int) -> OmniLight3D:
	var stale := _flash_host != h.get_instance_id()
	for i in _flash_pool.size():
		if not is_instance_valid(_flash_pool[i]):
			stale = true
	if stale:
		_flash_pool.clear()
		_flash_host = h.get_instance_id()
	for v: Variant in _flash_pool:
		var o := v as OmniLight3D
		if not o.visible:
			if not _make_room(h.get_tree(), priority):
				return null
			o.add_to_group(LIGHT_GROUP)
			return o
	if _flash_pool.size() < LIGHT_CAP:
		if not _make_room(h.get_tree(), priority):
			return null
		var l := OmniLight3D.new()
		l.name = "VfxFlash%d" % _flash_pool.size()
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.6
		l.set_meta("light_class", "player_orb")
		l.visible = false
		h.add_child(l)
		_flash_pool.append(l)
		l.add_to_group(LIGHT_GROUP)
		return l
	# every pooled light is lit: the lowest-priority, oldest flash gives way to this one (or nothing does)
	var victim: OmniLight3D = null
	var vkey := 1 << 60
	for v2: Variant in _flash_pool:
		var o := v2 as OmniLight3D
		var key := int(o.get_meta(&"vfx_pri", 1)) * (1 << 40) + int(o.get_meta(&"vfx_born", 0))
		if key < vkey:
			vkey = key
			victim = o
	if victim == null or int(victim.get_meta(&"vfx_pri", 1)) > priority:
		return null
	return victim


## A light carried by a shot (child of `parent`), in the shot's colour. Counts against the cap but
## is never culled: it makes room by retiring flashes. Quiet beside the player's lantern (ShotLight).
static func carry(parent: Node, color: Color, energy: float, rng: float, dim := false) -> OmniLight3D:
	var l := ShotLight.new()
	l.light_color = tone(color)
	l.base_energy = energy * (0.4 if dim else 1.0)
	l.light_energy = l.base_energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.0 if dim else 0.3
	l.set_meta("light_class", "glimmer")
	l.set_meta(&"vfx_pri", 3)
	l.add_to_group(LIGHT_GROUP)
	parent.add_child(l)
	if parent.is_inside_tree():
		_make_room(parent.get_tree(), 3)
	return l


static func _make_room(tree: SceneTree, priority: int) -> bool:
	var live := tree.get_nodes_in_group(LIGHT_GROUP)
	if live.size() < LIGHT_CAP:
		return true
	var victim: OmniLight3D = null
	var vkey := 1 << 60
	for n in live:
		var o := n as OmniLight3D
		if o == null or o.is_queued_for_deletion() or not o.has_meta(&"vfx_born"):
			continue                       # carried lights are not culled
		var key := int(o.get_meta(&"vfx_pri", 1)) * (1 << 40) + int(o.get_meta(&"vfx_born", 0))
		if key < vkey:
			vkey = key
			victim = o
	if victim == null or int(victim.get_meta(&"vfx_pri", 1)) > priority:
		return false
	victim.remove_from_group(LIGHT_GROUP)
	if _flash_pool.has(victim):
		victim.visible = false                 # a pooled flash is put out, kept for the next
		var tw: Variant = victim.get_meta(&"vfx_tween") if victim.has_meta(&"vfx_tween") else null
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	else:
		victim.queue_free()
	return true


## Burn mark projected onto whatever is below (lance impact, nova). Glows, then cools to soot.
static func scorch(at: Vector3, radius: float, glow: Color, time := 2.5) -> void:
	var h := host()
	if h == null:
		return
	if _scorch_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.95))
		g.add_point(0.55, Color(0, 0, 0, 0.6))
		g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0))
		_scorch_tex = GradientTexture2D.new()
		_scorch_tex.gradient = g
		_scorch_tex.fill = GradientTexture2D.FILL_RADIAL
		_scorch_tex.fill_from = Vector2(0.5, 0.5)
		_scorch_tex.fill_to = Vector2(0.5, 0.0)
	var d := Decal.new()
	d.size = Vector3(radius * 2.0, 1.6, radius * 2.0)
	d.texture_albedo = _scorch_tex
	d.texture_emission = _scorch_glow()     # black RGB at the rim: a dot() here glowed as a square
	d.emission_energy = 2.5
	d.modulate = glow
	d.albedo_mix = 0.85
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	h.add_child(d)
	d.global_position = at
	d.rotation.y = randf() * TAU
	var tw := d.create_tween()
	tw.tween_property(d, "emission_energy", 0.0, time * 0.35)
	tw.tween_property(d, "albedo_mix", 0.0, time * 0.65)
	tw.tween_callback(d.queue_free)


# --- ribbons and arcs -----------------------------------------------------------------------

## A crossed ribbon through `pts`, tapering width0 → width1, fading out over `time`.
static func ribbon(pts: PackedVector3Array, width0: float, width1: float, color: Color, time := 0.25, additive := true) -> void:
	var h := host()
	if h == null or pts.size() < 2:
		return
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA      # a ribbon passing the lens is a fat white bar
	mat.distance_fade_min_distance = 0.5
	mat.distance_fade_max_distance = 3.0
	for plane in 2:
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
		for i in pts.size():
			var t := float(i) / float(pts.size() - 1)
			var fwd := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var side := fwd.cross(Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT).normalized()
			if plane == 1:
				side = side.cross(fwd).normalized()
			var w := lerpf(width0, width1, t) * 0.5
			var c := Color(color.r, color.g, color.b, color.a * (0.35 + 0.65 * t))
			im.surface_set_color(c)
			im.surface_add_vertex(pts[i] + side * w)
			im.surface_set_color(c)
			im.surface_add_vertex(pts[i] - side * w)
		im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## Jagged lightning between two points (Nova detonating a mark).
static func arc(from: Vector3, to: Vector3, color: Color, time := 0.22, jag := 0.28) -> void:
	var pts := PackedVector3Array()
	var n := 9
	var dir := (to - from)
	var side := dir.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var up2 := side.cross(dir.normalized())
	for i in n:
		var t := float(i) / float(n - 1)
		var j := sin(t * PI) * jag
		pts.append(from + dir * t + side * randf_range(-j, j) + up2 * randf_range(-j, j))
	ribbon(pts, 0.09, 0.03, color, time)
	ribbon(pts, 0.22, 0.08, Color(color.r, color.g, color.b, 0.35), time * 0.8)


# --- impacts (ENS art pass, docs/enshrouded/art.md) ---------------------------------------------

static var _star_tex: ImageTexture
static var _flash_mats := {}
static var _flash_quad: QuadMesh
const IMPACT_CORE := Color(2.6, 2.1, 1.5)          ## warm white-gold: the grade keeps bright warm light

## A melee/bolt hit that reads at a glance: a 0.12 s four-point flash star at the contact point
## (warm white core, scaled by `big`), hot sparks thrown along `dir` (the blow's direction; ZERO =
## all round) in `color`, and for big hits a short flash light. Two pooled bursts + one quad.
static func impact(at: Vector3, color: Color, dir := Vector3.ZERO, big := false) -> void:
	var h := host()
	if h == null:
		return
	var d := dir.normalized() if dir.length_squared() > 0.01 else Vector3.UP
	var spread := 55.0 if dir.length_squared() > 0.01 else 180.0
	# sparks: keyed on a quantised direction so the preset count stays bounded (Vfx caches per opts)
	var qd := Vector3(snappedf(d.x, 0.5), snappedf(d.y + 0.35, 0.5), snappedf(d.z, 0.5))
	if qd.length_squared() < 0.01:
		qd = Vector3.UP
	burst(at, color, {"count": 26 if big else 14, "life": 0.38, "speed": Vector2(4.0, 10.0), "size": 0.05, "gravity": -11.0, "trail": 0.1, "dir": qd.normalized(), "spread": spread, "damping": 3.0})
	burst(at, IMPACT_CORE, {"count": 6, "life": 0.18, "speed": Vector2(0.4, 1.4), "size": 0.16 if big else 0.11, "gravity": 0.0, "scale_var": 0.3})
	var fk := Access.flash()
	_flash_star(h, at, Color(color.r * fk, color.g * fk, color.b * fk, color.a), 0.95 if big else 0.6)
	if big:
		light(at, color, 2.4, 3.5, 0.14, 2)


static func _star() -> ImageTexture:
	if _star_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := (float(x) + 0.5) / n * 2.0 - 1.0
				var v := (float(y) + 0.5) / n * 2.0 - 1.0
				var r := sqrt(u * u + v * v)
				var core := pow(maxf(0.0, 1.0 - r / 0.42), 2.0)
				var spike := pow(maxf(0.0, 1.0 - absf(u) / 0.07), 2.0) * maxf(0.0, 1.0 - absf(v)) \
						+ pow(maxf(0.0, 1.0 - absf(v) / 0.07), 2.0) * maxf(0.0, 1.0 - absf(u))
				var a := clampf(core + spike * 0.85, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_star_tex = ImageTexture.create_from_image(img)
	return _star_tex


static func _flash_star(h: Node, at: Vector3, color: Color, size: float) -> void:
	if _flash_quad == null:
		_flash_quad = QuadMesh.new()
		_flash_quad.size = Vector2.ONE
	var key := "%s" % color
	if not _flash_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true
		m.disable_receive_shadows = true
		m.disable_fog = true
		m.albedo_texture = _star()
		# white-hot middle, the hit's own colour at the tips: lerp half-way to the warm core
		m.albedo_color = Color(lerpf(color.r, IMPACT_CORE.r, 0.5), lerpf(color.g, IMPACT_CORE.g, 0.5), lerpf(color.b, IMPACT_CORE.b, 0.5), 1.0)
		m.render_priority = 8
		_flash_mats[key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = _flash_quad
	mi.material_override = _flash_mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * size * 0.35
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * size * 0.2, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
