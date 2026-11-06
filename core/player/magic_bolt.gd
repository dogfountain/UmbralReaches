class_name MagicBolt
extends CharacterBody3D
## Violet bolt from the staff. Flies until it hits the world or a shade, then bursts.

const SPEED := 28.0
const LIFE := 2.6
const BLAST := 1.2
const HIT_DMG := 1.0
const FLARE_SHADER := preload("res://world/flare.gdshader")
const MOTE := preload("res://art/materials/rift_mote_particle.tres")
const IMPACT_SFX := preload("res://art/audio/bolt_impact.wav")
const HEAT_SHADER := preload("res://world/vfx/heat_distort.gdshader")
const SHELL_SHADER := preload("res://world/vfx/shell.gdshader")
const LANCE_IMPACT := "res://art/audio/lance_impact.wav"
const CombatState := preload("res://core/skills/combat_state.gd")   # r33 combat
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Afflict := preload("res://core/skills/afflict.gd")
const Combo := preload("res://core/skills/combo.gd")
const STREAK_POINTS := 12
const SPLIT_AT := 0.1             ## Prism Core: seconds of flight before the bolt splits (~3.4 m)
const SPLIT_ANGLE := 0.2          ## rad either side (~11 deg)
const LEAP_RANGE := 9.0           ## Lodestar Core: next foe within this of the strike
const LEAPS := 2
const LEAP_DMG := 0.7
## Staff cores (progression): the bolt's colours. [core glow, aura, light, streak glow, streak core, burst]
const CORE_LOOK := {
	"": [Color(2.2, 1.5, 4.4), Color(0.5, 0.24, 1.1, 0.4), Color("#A98BFF"), Color(1.0, 0.45, 2.6, 0.5), Color(2.4, 1.8, 3.8, 1.0), Color(1.9, 1.0, 3.6)],
	"core_prism": [Color(3.4, 3.6, 4.2), Color(0.45, 0.75, 1.15, 0.4), Color("#CFF4FF"), Color(1.1, 1.3, 2.8, 0.5), Color(3.0, 3.4, 3.9, 1.0), Color(2.2, 2.8, 3.8)],
	"core_lodestar": [Color(4.0, 3.0, 1.3), Color(1.1, 0.72, 0.22, 0.4), Color("#FFD86A"), Color(2.2, 1.35, 0.35, 0.5), Color(3.8, 3.2, 1.9, 1.0), Color(3.2, 2.3, 0.8)],
	"core_cinder": [Color(3.8, 1.5, 0.55), Color(1.15, 0.32, 0.55, 0.4), Color("#FF7A3A"), Color(2.5, 0.65, 0.9, 0.5), Color(3.6, 2.0, 1.1, 1.0), Color(3.0, 1.1, 0.45)],
	"core_rime": [Color(2.3, 3.3, 4.6), Color(0.35, 0.7, 1.25, 0.4), Color("#8FD0FF"), Color(0.55, 1.25, 2.9, 0.5), Color(2.5, 3.2, 4.2, 1.0), Color(1.7, 2.7, 3.9)],
}

var direction := Vector3.FORWARD
var speed := SPEED
var blast := BLAST
var hit_dmg := HIT_DMG
var heavy := false
var marks := 0            ## Umbral Marks applied per hit (Rift Bolt)
var empowered := false    ## Rift Lash (every 3rd bolt in a chain): bigger blast + ring
var thorn := ""           ## Thorn Heart variant: "splinter" | "briar" | ""
var pierce := false       ## pass through bodies, burst only on the world (full Ember Lance)
var core := ""            ## staff core (progression): "core_prism" | "core_lodestar" | "core_cinder" | "core_rime"
var seek := 0.0           ## rad/s the bolt bends toward a foe ahead (Rift Bolt I, Keen)
var shard := false        ## a Prism split: no light, never splits again
var power := 1.0          ## spell power, for core side effects (burn ticks)
var lance_marks := false  ## Ember Lance: flare Marks it bursts on (Kindled Rift)
var burst_hooks: Array[Callable] = []   ## called with (at) when the bolt bursts (Lance cinders)
var resonant := 0         ## r33: Resonance this bolt builds when it first lands (the wanderer's Rift Bolt)
var scar := 0             ## r33: Ember Scar stacks the Lance leaves on what it hits
var school: StringName = &"umbral"   ## r33: damage school for the combat feed
var _built := false
var _leaps := 0
var _first_dmg := 0.0            ## damage of the first strike; every Lodestar leap is a fraction of it, not compounding
var _on_shade := false           ## the bolt met a shade: it passes through, so no burst and no number
var _split := false
var _seek_target: Node3D
var _seek_scan := 0
var _fresh := false
var _combo := false
var _look: Array = CORE_LOOK[""]
static var _core_mats := {}

var _age := 0.0
var _spent := false
var _core: MeshInstance3D
var _aura: MeshInstance3D
var _light: OmniLight3D
var _trail: GPUParticles3D
var _hurt: Area3D
var _hurt_shape: SphereShape3D
var _hit_ids: Dictionary = {}
var _pooled := false
var _sfx: AudioStreamPlayer3D
var _excepted: Array[PhysicsBody3D] = []
var _streak: MeshInstance3D
var _streak_mesh: ImmediateMesh
var _hist := PackedVector3Array()
var _heat: MeshInstance3D
var _hit_normal := Vector3.UP

static var _streak_mat: StandardMaterial3D
static var _heat_mesh: SphereMesh
static var _heat_mat: ShaderMaterial
static var _glow_pierce: StandardMaterial3D

static var _core_mesh: SphereMesh
static var _core_mesh_h: SphereMesh
static var _aura_mesh: SphereMesh
static var _aura_mesh_h: SphereMesh
static var _glow: Material
static var _glow_h: Material
static var _shell: Material
static var _shell_h: Material
static var _trail_pm: ParticleProcessMaterial
static var _burst_pm: ParticleProcessMaterial
static var _trail_quad: QuadMesh
static var _burst_quad: QuadMesh
static var _shock_mesh: SphereMesh
static var _shock_mat: ShaderMaterial
static var _flare_mesh: QuadMesh


func _ready() -> void:
	name = "MagicBolt"
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.HURTBOX
	motion_mode = MOTION_MODE_FLOATING
	var col := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.14
	col.shape = ball
	add_child(col)
	_hurt = Area3D.new()
	_hurt.name = "Hurt"
	_hurt.collision_layer = 0
	_hurt.collision_mask = Layers.HURTBOX
	_hurt.monitoring = true
	_hurt.monitorable = false
	var hcol := CollisionShape3D.new()
	_hurt_shape = SphereShape3D.new()
	_hurt_shape.radius = 0.32
	hcol.shape = _hurt_shape
	_hurt.add_child(hcol)
	add_child(_hurt)
	_ensure_shared()
	_build_visual()


func arm(is_heavy: bool) -> void:
	heavy = is_heavy
	if heavy:
		hit_dmg = 3.0
		blast = 2.6
		speed = 18.0
	else:
		hit_dmg = HIT_DMG
		blast = BLAST
		speed = SPEED
	_age = 0.0
	_spent = false
	_hit_ids.clear()
	_pooled = false
	marks = 0
	pierce = false
	core = ""
	seek = 0.0
	shard = false
	power = 1.0
	lance_marks = false
	burst_hooks.clear()
	_leaps = 0
	_first_dmg = 0.0
	_on_shade = false
	_split = false
	_seek_target = null
	_combo = false
	_look = CORE_LOOK[""]
	for b in _excepted:
		if is_instance_valid(b):
			remove_collision_exception_with(b)
	_excepted.clear()
	if _aura:
		_aura.scale = Vector3(1.0, 1.0, 1.8) if not heavy else Vector3(1.0, 1.0, 2.4)
	if _core:
		# stretched along flight (-Z of the bolt basis): a dart, and for the Lance a spearhead
		_core.scale = Vector3(1.0, 1.0, 2.6) if not heavy else Vector3(1.5, 1.5, 1.3)
	if _heat:
		_heat.visible = heavy
	_hist.clear()
	_hit_normal = Vector3.UP
	if _streak:
		_streak.visible = true
	if _hurt_shape:
		_hurt_shape.radius = 0.45 if heavy else 0.32
	if _core:
		_core.visible = true
		_core.mesh = SpellFx.spear_mesh() if heavy else _core_mesh
		_core.material_override = _glow_h if heavy else _glow
	if _aura:
		_aura.mesh = _aura_mesh_h if heavy else _aura_mesh
		_aura.material_override = _shell_h if heavy else _shell
	if _trail:
		_trail.emitting = true
	if _light:
		_light.visible = true
		_light.light_color = Color("#FF7A4A") if heavy else Color("#A98BFF")
		_light.light_energy = 2.2 if heavy else 1.6
		_light.omni_range = 6.0 if heavy else 4.6
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


## Skill-facing arm: heavy look + explicit numbers. Missing keys keep arm()'s defaults.
func arm_with(cfg: Dictionary) -> void:
	arm(bool(cfg.get("heavy", false)))
	hit_dmg = float(cfg.get("dmg", hit_dmg))
	blast = float(cfg.get("blast", blast))
	speed = float(cfg.get("speed", speed))
	marks = int(cfg.get("marks", 0))
	pierce = bool(cfg.get("pierce", false))
	empowered = bool(cfg.get("empower", false))
	thorn = String(cfg.get("thorn", ""))
	core = String(cfg.get("core", "")) if not heavy else ""
	seek = float(cfg.get("seek", 0.0))
	shard = bool(cfg.get("shard", false))
	power = float(cfg.get("power", 1.0))
	lance_marks = heavy and bool(cfg.get("kindle", true))
	resonant = 0                              # r33: fire_bolt sets these after arming
	scar = 0
	school = &"ember" if heavy else &"umbral"
	_built = false
	if core != "" and CORE_LOOK.has(core):
		_look = CORE_LOOK[core]
		var mats := _core_mat(core)
		if _core:
			_core.material_override = mats[0]
		if _aura:
			_aura.material_override = mats[1]
		if _light:
			_light.light_color = _look[2]
	if shard:
		if _light:
			_light.visible = false                # three lights per shot is too many: shards go dark
		if _core:
			_core.scale = Vector3(0.75, 0.75, 2.4)
		if _aura:
			_aura.scale = Vector3(0.7, 0.7, 1.6)
	if empowered:                            # Rift Lash: a fatter, brighter bolt
		if _core:
			_core.scale = Vector3(1.7, 1.7, 3.4)
		if _aura:
			_aura.scale = Vector3(1.8, 1.8, 2.6)
		if _light:
			_light.light_energy = 2.0
			_light.omni_range = 5.0
	if pierce and _aura:
		_aura.scale = Vector3(1.6, 1.6, 3.2)
	if pierce and _core:
		if _glow_pierce == null:
			_glow_pierce = ProcMesh.glow_mat(Color(3.2, 2.4, 1.6))
		_core.material_override = _glow_pierce   # white-hot


## Pool teardown: let go of the particle material before the node (see BoltPool._exit_tree).
func drop_materials() -> void:
	if _trail:
		_trail.process_material = null
		_trail.draw_pass_1 = null


func reset_idle() -> void:
	if _streak_mesh:
		_streak_mesh.clear_surfaces()
	_hist.clear()
	_spent = true
	_age = 0.0
	_hit_ids.clear()
	_pooled = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if _trail:
		_trail.emitting = false
	if _core:
		_core.visible = true
	if _light:
		_light.light_energy = 1.15


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	if _age >= LIFE:
		explode(global_position)
		return
	if core == "core_prism" and not shard and not empowered and not _split and _age >= SPLIT_AT:
		_do_split()
	if seek > 0.0:
		_steer(delta)
	_fresh = false
	if _hurt_near() and not pierce:
		if core == "core_lodestar":
			if _fresh and not _leap(global_position):
				explode(global_position)
				return
		else:
			explode(global_position)
			return
	var hit := move_and_collide(direction * speed * delta)
	_push_hist()
	if hit:
		_hit_normal = hit.get_normal()
		var col := hit.get_collider()
		_fresh = false
		var hurt := _apply_hit(col)
		if pierce and hurt and col is PhysicsBody3D:
			add_collision_exception_with(col)
			_excepted.append(col as PhysicsBody3D)
		elif hurt and core == "core_lodestar" and col is PhysicsBody3D and (not _fresh or _leap(hit.get_position())):
			# a body already struck (the leap starts inside it) or a fresh strike that leaps on
			add_collision_exception_with(col)
			_excepted.append(col as PhysicsBody3D)
		else:
			explode(hit.get_position())


func explode(at: Vector3) -> void:
	if _spent:
		return
	_spent = true
	global_position = at
	_blast(at, blast)
	if thorn == "splinter":
		_splinter(at)
	if _core:
		_core.visible = false
	if _heat:
		_heat.visible = false
	if _trail:
		_trail.emitting = false
	if _streak:
		_streak.visible = false
	_impact_fx(at)
	_play_impact()
	for hook in burst_hooks:
		if hook.is_valid():
			hook.call(at)
	burst_hooks.clear()
	if heavy:
		_kindle_wells(at)
	var flash := _light
	if flash:
		flash.light_energy = 2.4
		flash.omni_range = 7.0
		var tw := create_tween()
		tw.tween_property(flash, "light_energy", 0.0, 0.28)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	if pool:
		pool.release(self)
	else:
		queue_free()


## Blast damage as a direct shape query: resizing the Area3D and reading its overlaps in the same
## frame (the old way) only sees bodies on the next physics step, so blasts mostly missed.
func _blast(at: Vector3, radius: float) -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var sph := SphereShape3D.new()
	sph.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = Layers.HURTBOX
	q.collide_with_areas = true
	q.collide_with_bodies = true
	for hit in space.intersect_shape(q, 16):
		_apply_hit(hit.get("collider"))


func _impact_fx(at: Vector3) -> void:
	var n := _hit_normal
	if _on_shade and not heavy and not empowered:
		return
	if heavy:
		SpellFx.lance_impact(at, n, blast, pierce)   # round fire field at exactly the blast radius
		StaffSfx.play("lance_hit", at, 0.0)
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p and p.global_position.distance_to(at) < 9.0:
			p.kick(0.6)
	elif empowered:
		_burst(at)
		SpellFx.disc(at, blast, 0, SpellFx.VIOLET, SpellFx.VIOLET_HOT, 0.7, n)
		SpellFx.shell(at, 0.3, blast, Color(1.2, 0.5, 2.8), 0.3)
		Vfx.burst(at, Color(1.8, 0.9, 3.4), {"count": 36, "life": 0.45, "speed": Vector2(3.0, 8.0), "size": 0.045, "gravity": -6.0, "trail": 0.08, "dir": n, "spread": 80.0})
		Vfx.light(at, Color(0.7, 0.4, 1.0), 3.0, blast * 2.4, 0.3)
	else:
		var bc: Color = _look[5]
		if shard:
			Vfx.ring(at, 0.7, bc, 0.2, 0.12, n)
			Vfx.burst(at, bc, {"count": 12, "life": 0.3, "speed": Vector2(2.0, 5.0), "size": 0.035, "gravity": -6.0, "trail": 0.06, "dir": n, "spread": 75.0})
			return
		_burst(at)
		if core != "":
			Vfx.burst(at, bc, {"count": 30, "life": 0.45, "speed": Vector2(2.0, 5.5), "size": 0.06, "gravity": -3.0, "trail": 0.05})
		Vfx.ring(at, 1.25, Color(1.6, 0.8, 3.4) if core == "" else bc, 0.28, 0.18, n)
		SpellFx.shell(at, 0.15, 0.85, Color(1.2, 0.55, 2.8) if core == "" else Color(bc.r, bc.g, bc.b) * 0.7, 0.18)
		Vfx.burst(at, bc, {"count": 26, "life": 0.4, "speed": Vector2(2.5, 6.5), "size": 0.04, "gravity": -6.0, "trail": 0.08, "dir": n, "spread": 75.0})
		match core:
			"core_cinder":
				Vfx.burst(at, Color(2.8, 0.9, 0.3), {"count": 18, "life": 0.7, "speed": Vector2(0.8, 2.6), "size": 0.05, "gravity": 2.0, "radius": 0.3, "turbulence": true})
			"core_rime":
				Vfx.burst(at, Color(0.75, 0.9, 1.0, 0.85), {"count": 14, "life": 0.7, "speed": Vector2(1.0, 3.0), "size": 0.07, "gravity": -7.0, "additive": false, "dir": n, "spread": 70.0})
			"core_lodestar":
				Vfx.ring(at, 1.8, Color(3.0, 2.2, 0.7), 0.35, 0.1, n)


## Physics tick: remember where the bolt was (the tail). The ribbon itself is drawn every rendered
## frame in _process from the bolt's INTERPOLATED head, so at 120 fps it never steps at 60 Hz.
func _push_hist() -> void:
	_hist.insert(0, global_position)
	if _hist.size() > STREAK_POINTS:
		_hist.resize(STREAK_POINTS)


func _process(_d: float) -> void:
	if _spent or not visible or _streak == null:
		return
	_update_streak()


func _update_streak() -> void:
	_streak_mesh.clear_surfaces()
	if _hist.size() < 2:
		return
	var head := get_global_transform_interpolated().origin
	var pts := PackedVector3Array([head])
	for i in range(1, _hist.size()):
		pts.append(_hist[i])
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else head + Vector3.UP
	# two ribbons: a wide soft glow, and a thin white-hot core inside it
	var outer: Color = Color(2.4, 0.85, 0.3, 0.55) if heavy else _look[3]
	var inner: Color = Color(3.4, 2.2, 1.2, 1.0) if heavy else _look[4]
	var w_out := 0.42 if heavy else (0.34 if empowered else (0.16 if shard else 0.24))
	var w_in := 0.12 if heavy else (0.1 if empowered else (0.05 if shard else 0.07))
	if seek > 0.0 and not heavy:
		w_in *= 1.35                                  # Keen bolts: a hotter, longer core
		inner = Color(inner.r * 1.15, inner.g * 1.15, inner.b * 1.1, 1.0)
	for layer in 2:
		var w := w_out if layer == 0 else w_in
		var col := outer if layer == 0 else inner
		var reach := 1.0 if layer == 0 else 0.6          # the core is shorter than the glow
		_streak_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _streak_mat)
		var last := maxi(1, int(round(float(pts.size() - 1) * reach)))
		for i in last + 1:
			var t := float(i) / float(last)
			var fwd := (pts[maxi(i - 1, 0)] - pts[mini(i + 1, pts.size() - 1)]).normalized()
			var side := fwd.cross(eye - pts[i]).normalized() * w * (1.0 - t * 0.85) * 0.5
			var c := Color(col.r, col.g, col.b, col.a * pow(1.0 - t, 1.4))
			_streak_mesh.surface_set_color(c)
			_streak_mesh.surface_add_vertex(pts[i] + side)
			_streak_mesh.surface_set_color(c)
			_streak_mesh.surface_add_vertex(pts[i] - side)
		_streak_mesh.surface_end()


func _hurt_near() -> bool:
	if _hurt == null:
		return false
	var any := false
	for n in _hurt.get_overlapping_bodies():
		if _apply_hit(n):
			any = true
	for n in _hurt.get_overlapping_areas():
		if _apply_hit(n):
			any = true
	return any


func _apply_hit(node: Object) -> bool:
	var n := node as Node
	while n:
		if n.has_method("take_hit"):
			var id := n.get_instance_id()
			if _hit_ids.has(id):
				return true
			_hit_ids[id] = true
			_fresh = true
			var dmg := hit_dmg
			if _first_dmg <= 0.0:
				_first_dmg = dmg
			if heavy and n is Enemy:
				dmg *= Afflict.shatter(n)
				if lance_marks:
					_kindle_marks(n as Enemy)
			if marks > 0 and n.has_method("add_mark"):
				n.add_mark(marks)
			_strike(n, dmg)
			if thorn == "briar" and n is Enemy:
				_briar(n as Enemy)
			if n is Enemy:
				match core:
					"core_cinder":
						Afflict.burn(n, 2.0, Afflict.BURN_DMG)
						StaffSfx.play("burn_hit", global_position, -4.0)
					"core_rime":
						Afflict.chill(n)
						StaffSfx.play("chill_hit", global_position, -4.0)
			return true
		n = n.get_parent()
	return false


func _build_visual() -> void:
	_core = MeshInstance3D.new()
	_core.name = "Core"
	_core.mesh = _core_mesh
	_core.material_override = _glow
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_aura = MeshInstance3D.new()
	_aura.name = "Aura"
	_aura.mesh = _aura_mesh
	_aura.material_override = _shell
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)
	_light = OmniLight3D.new()
	_light.name = "BoltLight"
	_light.light_color = Color("#A98BFF")
	_light.light_energy = 1.15
	_light.omni_range = 3.8
	_light.shadow_enabled = false
	_light.set_meta("light_class", "player_orb")
	add_child(_light)
	_trail = make_particles(false)
	add_child(_trail)
	_streak_mesh = ImmediateMesh.new()
	_streak = MeshInstance3D.new()
	_streak.name = "Streak"
	_streak.mesh = _streak_mesh
	_streak.top_level = true                 # world-space ribbon behind the bolt
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak.extra_cull_margin = 16.0
	add_child(_streak)
	_heat = MeshInstance3D.new()
	_heat.name = "Heat"
	_heat.mesh = _heat_mesh
	_heat.material_override = _heat_mat
	_heat.scale = Vector3(1.0, 1.0, 2.2)
	_heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heat.visible = false
	add_child(_heat)
	var flare := MeshInstance3D.new()
	flare.name = "Flare"
	flare.mesh = _flare_mesh
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flare)


## Drop the shared meshes and materials (night teardown: BoltPool._exit_tree). Statics outlive the
## renderer at quit. Rebuilt by _ensure_shared on the next bolt.
static func release_shared() -> void:
	_core_mats.clear()
	_shock_mats.clear()
	_streak_mat = null
	_heat_mesh = null
	_heat_mat = null
	_glow_pierce = null
	_core_mesh = null
	_core_mesh_h = null
	_aura_mesh = null
	_aura_mesh_h = null
	_glow = null
	_glow_h = null
	_shell = null
	_shell_h = null
	_trail_pm = null
	_burst_pm = null
	_trail_quad = null
	_burst_quad = null
	_shock_mesh = null
	_shock_mat = null
	_flare_mesh = null


static func _ensure_shared() -> void:
	if _core_mesh != null:
		return
	_core_mesh = SphereMesh.new()
	_core_mesh.radius = 0.12
	_core_mesh.height = 0.24
	_core_mesh.radial_segments = 12
	_core_mesh.rings = 8
	_core_mesh_h = SphereMesh.new()
	_core_mesh_h.radius = 0.16
	_core_mesh_h.height = 0.32
	_core_mesh_h.radial_segments = 12
	_core_mesh_h.rings = 8
	_aura_mesh = SphereMesh.new()
	_aura_mesh.radius = 0.26
	_aura_mesh.height = 0.52
	_aura_mesh.radial_segments = 10
	_aura_mesh.rings = 6
	_aura_mesh_h = SphereMesh.new()
	_aura_mesh_h.radius = 0.3
	_aura_mesh_h.height = 0.6
	_aura_mesh_h.radial_segments = 10
	_aura_mesh_h.rings = 6
	_glow = ProcMesh.glow_mat(Color(2.2, 1.5, 4.4))          # white-violet hot core
	_glow_h = ProcMesh.glow_mat(Color(3.2, 1.25, 0.45))      # the Lance's spearhead burns
	# auras glow additively (a soft halo), not as an alpha sphere (that read as a flat disc)
	_shell = ProcMesh.glow_mat(Color(0.5, 0.24, 1.1, 0.4))
	_shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shell.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_shell_h = ProcMesh.glow_mat(Color(1.1, 0.38, 0.12, 0.35))
	_shell_h.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_h.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shell_h.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_trail_pm = _particle_mat(false)
	_burst_pm = _particle_mat(true)
	_trail_quad = QuadMesh.new()
	_trail_quad.size = Vector2(0.07, 0.07)
	_trail_quad.material = MOTE
	_burst_quad = QuadMesh.new()
	_burst_quad.size = Vector2(0.11, 0.11)
	_burst_quad.material = MOTE
	_shock_mesh = SphereMesh.new()
	_shock_mesh.radius = 0.2
	_shock_mesh.height = 0.4
	_shock_mesh.radial_segments = 14
	_shock_mesh.rings = 8
	# the impact dome: a fresnel rim (world/vfx/shell), not an alpha sphere (that read as a flat disc)
	_shock_mat = ShaderMaterial.new()
	_shock_mat.shader = SHELL_SHADER
	_shock_mat.set_shader_parameter("color", Color(0.85, 0.45, 2.2))
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_mat.vertex_color_use_as_albedo = true
	_streak_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_streak_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_heat_mesh = SphereMesh.new()
	_heat_mesh.radius = 0.3
	_heat_mesh.height = 0.6
	_heat_mesh.radial_segments = 12
	_heat_mesh.rings = 6
	_heat_mat = ShaderMaterial.new()
	_heat_mat.shader = HEAT_SHADER
	_flare_mesh = QuadMesh.new()
	_flare_mesh.size = Vector2(0.9, 0.9)
	var fmat := ShaderMaterial.new()
	fmat.shader = FLARE_SHADER
	fmat.set_shader_parameter("color", Color(1.05, 0.62, 2.8))
	_flare_mesh.material = fmat


static func make_particles(burst: bool) -> GPUParticles3D:
	_ensure_shared()
	var p := GPUParticles3D.new()
	p.name = "Burst" if burst else "Trail"
	p.amount = 42 if burst else 36
	p.lifetime = 0.45 if burst else 0.35
	p.one_shot = burst
	p.emitting = not burst
	p.explosiveness = 0.95 if burst else 0.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = _burst_pm if burst else _trail_pm
	p.draw_pass_1 = _burst_quad if burst else _trail_quad
	return p


static func make_shock() -> MeshInstance3D:
	_ensure_shared()
	var shock := MeshInstance3D.new()
	shock.name = "Shock"
	shock.mesh = _shock_mesh
	shock.material_override = _shock_mat
	shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shock.visible = false
	return shock


func _burst(at: Vector3) -> void:
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	var bang: GPUParticles3D
	if pool:
		bang = pool.take_burst()
	else:
		bang = make_particles(true)
		var host := get_tree().current_scene
		if host:
			host.add_child(bang)
	bang.global_position = at
	bang.restart()
	bang.emitting = true
	var shock: MeshInstance3D
	if pool:
		shock = pool.take_shock()
	else:
		shock = make_shock()
		var host2 := get_tree().current_scene
		if host2:
			host2.add_child(shock)
	var old: Variant = shock.get_meta(&"burst_tween") if shock.has_meta(&"burst_tween") else null   # get_meta(k, null) still errors
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()                       # a reused dome starts over, its old tween must not hide it
	shock.visible = true
	shock.scale = Vector3.ONE
	shock.global_position = at
	shock.material_override = _shock_for(core)
	shock.set_instance_shader_parameter(&"progress", 0.0)
	var tw := shock.create_tween()
	shock.set_meta(&"burst_tween", tw)
	tw.set_parallel(true)
	tw.tween_property(shock, "scale", Vector3.ONE * 6.5, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: shock.set_instance_shader_parameter(&"progress", v), 0.0, 1.0, 0.32)
	tw.chain().tween_callback(func() -> void:
		shock.visible = false
		shock.scale = Vector3.ONE
	)


## The impact dome in the core's colour (the Hollow Core's is the shared violet one).
static var _shock_mats := {}


static func _shock_for(c: String) -> ShaderMaterial:
	if c == "" or not CORE_LOOK.has(c):
		return _shock_mat
	if not _shock_mats.has(c):
		var m := ShaderMaterial.new()
		m.shader = SHELL_SHADER
		var col: Color = CORE_LOOK[c][5]
		m.set_shader_parameter("color", Color(col.r, col.g, col.b) * 0.6)
		_shock_mats[c] = m
	return _shock_mats[c]


## Staff core materials (glow core, additive aura), made once per core.
static func _core_mat(c: String) -> Array:
	if _core_mats.has(c):
		return _core_mats[c]
	var look: Array = CORE_LOOK[c]
	var glow := ProcMesh.glow_mat(look[0])
	var shell := ProcMesh.glow_mat(look[1])
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shell.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_core_mats[c] = [glow, shell]
	return _core_mats[c]


## Rift Bolt I, Keen: bend toward the foe nearest the line of flight (a 20 deg cone, 26 m).
func _steer(delta: float) -> void:
	_seek_scan -= 1
	if _seek_scan <= 0:
		_seek_scan = 4
		_seek_target = null
		var best := 0.94
		for node in get_tree().get_nodes_in_group(Groups.ENEMY):
			var e := node as Enemy
			if e == null or not e.is_alive() or _hit_ids.has(e.get_instance_id()):
				continue
			var to := e.global_position + Vector3.UP * (e.hp_bar_y * 0.5) - global_position
			var d := to.length()
			if d < 0.5 or d > 26.0:
				continue
			var dt := (to / d).dot(direction)
			if dt > best:
				best = dt
				_seek_target = e
	if _seek_target == null or not is_instance_valid(_seek_target):
		return
	var want := (_seek_target.global_position + Vector3.UP * (float(_seek_target.get("hp_bar_y")) * 0.5) - global_position).normalized()
	var ang := direction.angle_to(want)
	if ang < 0.001:
		return
	direction = direction.slerp(want, minf(1.0, seek * delta / ang)).normalized()
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)


## Prism Core: two shards peel off either side; this bolt flies on as the middle one.
func _do_split() -> void:
	_split = true
	var pool := get_tree().get_first_node_in_group("bolt_pool") as BoltPool
	if pool == null:
		return
	var each := hit_dmg * 0.45
	hit_dmg = each
	marks = maxi(marks, 1)
	var axis := global_basis.y.normalized()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as PhysicsBody3D
	for sgn: float in [-1.0, 1.0]:
		var b := pool.take()
		if b == null:
			break                                     # the pool is at its cap: no split
		var dir := direction.rotated(axis, SPLIT_ANGLE * sgn).normalized()
		b.transform = Transform3D(Basis.looking_at(dir, axis), global_position + dir * 0.1)
		b.direction = dir
		b.arm_with({"dmg": each, "blast": 1.2, "speed": speed, "marks": 1, "core": core, "shard": true, "power": power})
		if p:
			b.add_collision_exception_with(p)
		for id in _hit_ids:
			b._hit_ids[id] = true
	Vfx.burst(global_position, Color(2.6, 3.0, 3.8), {"count": 16, "life": 0.25, "speed": Vector2(2.0, 5.0), "size": 0.035, "gravity": 0.0, "trail": 0.05})
	Vfx.ring(global_position, 0.45, Color(2.2, 2.8, 3.8), 0.16, 0.08, direction)
	StaffSfx.play("split", global_position, -3.0)


## Lodestar Core: after striking, leap to the next foe within LEAP_RANGE (not one already hit).
func _leap(at: Vector3) -> bool:
	if _leaps >= LEAPS:
		return false
	var best: Enemy = null
	var best_d := LEAP_RANGE
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive() or _hit_ids.has(e.get_instance_id()):
			continue
		var d := e.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return false
	if _first_dmg <= 0.0:
		_first_dmg = hit_dmg
	_leaps += 1
	hit_dmg = _first_dmg * LEAP_DMG
	var to := best.global_position + Vector3.UP * (best.hp_bar_y * 0.55)
	direction = (to - at).normalized()
	global_position = at + direction * 0.3
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
	_age = minf(_age, LIFE - 1.0)
	Vfx.ring(at, 0.9, Color(3.2, 2.4, 0.8), 0.22, 0.1, direction)
	Vfx.burst(at, Color(3.0, 2.2, 0.8), {"count": 14, "life": 0.3, "speed": Vector2(2.0, 5.0), "size": 0.04, "gravity": -4.0, "trail": 0.06})
	Vfx.arc(at, to, Color(2.4, 1.8, 0.6), 0.2, 0.15)
	StaffSfx.play("ricochet", at, -2.0, 1.0 + 0.12 * float(_leaps))
	return true


## r33 combat: the hit goes through CombatState (crit, Sundered, the damage feed); the first foe a
## Rift Bolt lands on builds Resonance, the Lance leaves Ember Scar. Plain take_hit without one.
func _strike(n: Node, dmg: float) -> void:
	if n.is_in_group(Groups.SHADE):
		_on_shade = true
		n.take_hit(dmg, self)           # a shade takes no number and no burst: only light unmakes it
		return
	var cs := CombatState.of(self)
	if cs == null:
		n.take_hit(dmg, self)
		return
	cs.deal(n, dmg, school, self)
	if not (n is Enemy):
		return
	if resonant > 0 and not _built:
		_built = true
		cs.build(resonant)
	if scar > 0 and is_instance_valid(n) and (n as Enemy).is_alive():
		cs.apply(n, &"ember_scar", scar)


## Ember Lance on a Marked foe (Kindled Rift): each Mark flares for 0.5 x power (the Marks stay for
## the Nova), and the foe catches fire.
func _kindle_marks(e: Enemy) -> void:
	if e.marks <= 0 or not e.is_alive():
		return
	var mk := e.marks
	var at := e.global_position + Vector3.UP * (e.hp_bar_y * 0.6)
	e.take_hit(0.5 * float(mk) * power, null)
	Afflict.burn(e, 2.5, Afflict.BURN_DMG * 1.3)
	Vfx.burst(at, Color(3.0, 1.0, 2.2), {"count": 18 + 8 * mk, "life": 0.5, "speed": Vector2(2.0, 5.5), "size": 0.05, "gravity": -3.0, "trail": 0.07})
	SpellFx.shell(at, 0.2, 1.2, Color(2.4, 0.7, 1.6), 0.25)
	if not _combo:
		_combo = true
		Combo.note("KINDLED RIFT", at, Color(1.0, 0.55, 0.85), "+%.1f" % (0.5 * float(mk) * power))


## Ember Lance burst over an Umbral Well: the well catches (MAELSTROM).
func _kindle_wells(at: Vector3) -> void:
	for w in get_tree().get_nodes_in_group(&"umbral_well"):
		var wn := w as Node3D
		if wn and wn.has_method("ignite") and wn.global_position.distance_to(at) <= float(wn.get("radius")) + blast:
			wn.call("ignite")


## One player per bolt, made once. The old version added a new AudioStreamPlayer3D on every
## explosion and never freed it, so pooled bolts piled up players.
func _play_impact() -> void:
	if heavy:
		return                                    # the Lance's blast plays in _impact_fx
	StaffSfx.play("bolt_hit", global_position, 1.0 if empowered else -2.0, 0.85 if empowered else 1.0)
	return
	@warning_ignore("unreachable_code")
	if _sfx == null:
		_sfx = AudioStreamPlayer3D.new()
		_sfx.bus = &"SFX"
		_sfx.stream = IMPACT_SFX
		_sfx.max_distance = 24.0
		add_child(_sfx)
	_sfx.pitch_scale = randf_range(0.85, 1.12) * (0.8 if heavy else 1.0)
	_sfx.play()


static func _particle_mat(burst: bool) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12 if burst else 0.05
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.4 if burst else 0.05
	pm.initial_velocity_max = 5.4 if burst else 0.2
	pm.gravity = Vector3(0, -1.2, 0) if burst else Vector3.ZERO
	pm.damping_min = 1.6 if burst else 0.4
	pm.damping_max = 3.2 if burst else 1.0
	pm.scale_min = 0.45
	pm.scale_max = 1.15
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 1.0, 1.0))
	ramp.add_point(0.4, Color(0.72, 0.4, 1.15, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.35, 0.12, 0.8, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	return pm


## Thorn Heart · Splinter: the bolt bursts into thorns that find up to three more enemies within
## 4.5 m of the impact (not ones the bolt already hit): a pinch of damage and a Mark each.
func _splinter(at: Vector3) -> void:
	var near: Array = []
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive() or _hit_ids.has(e.get_instance_id()):
			continue
		var d := e.global_position.distance_to(at)
		if d < 4.5:
			near.append([d, e])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(3, near.size()):
		var e: Enemy = near[i][1]
		var to := e.global_position + Vector3.UP * (e.hp_bar_y * 0.5)
		for k in 4:
			Vfx.burst(at.lerp(to, float(k + 1) / 5.0), Color(2.2, 0.35, 0.3), {"count": 3, "life": 0.25, "speed": Vector2(0.2, 0.8), "size": 0.04, "gravity": 0.0})
		e.add_mark(1)
		e.take_hit(0.6, self)
	Vfx.burst(at, Color(2.4, 0.4, 0.35), {"count": 18, "life": 0.4, "speed": Vector2(3.0, 7.0), "size": 0.035, "gravity": -4.0, "trail": 0.06})


## Thorn Heart · Briar: what the bolt hits is rooted in brambles: 45 % speed for 2.2 s.
func _briar(e: Enemy) -> void:
	Afflict.hold(e, &"briar", 2200)
	Vfx.ring(e.global_position + Vector3.UP * 0.06, 0.9, Color(2.0, 0.3, 0.25), 0.5, 0.06, Vector3.UP, 1.0)
	Vfx.burst(e.global_position + Vector3.UP * 0.3, Color(0.5, 0.08, 0.06), {"count": 12, "life": 0.6, "speed": Vector2(0.5, 1.6), "size": 0.06, "gravity": 2.0, "additive": false})

