extends Node3D
## r34 raid room: Thorn Henge's raid floor (RealmLayout.RAIDS "henge": r 31, level at y 9), the
## Thornwarden's room. Built by ThornHenge in Realm mode; BossArena.room points here
## (docs/r34/raids_overworld.md). WoW raid rooms, adapted for one player:
##   - an outer bramble wall (WALL_R) with one raid door at the pilgrim stair's head (the 'henge'
##     seal: shut while its guards live, shut behind you on the pull, open on a wipe or the kill);
##   - an outer ring of great standing stones (STONE_R): line of sight to hide behind (Thornstorm);
##   - the inner ring (ThornHenge's hedge at 12.2, four mouths, its menhirs and the altar);
##   - a bramble maze in the outer ring that GROWS during the fight in three stages (each wall's
##     line fills red before it erupts: never a wall in your face without warning), withers after;
##   - three heart-knot spots (the intermission: burn them while the brambles close);
##   - the closing briars (the burn phase): a ring of thorn that shrinks the floor every BRIAR_STEP s;
##   - lighting: an ember heart over the altar, a pale moon shaft on the floor, four fire bowls at the
##     inner mouths. It turns sap-gold in the intermission and blood-red in the burn.
## Room API (BossArena / Thornwarden): room_begin(boss), room_reset(), room_won(), grow_stage(k, boss),
## wither_stage(k), spawn_knots(boss) -> Array, knots_left(), start_briars(), briars_r, shelter(from, to).

const FLOOR_R := 31.0
const ARENA_R := 29.0
const WALL_R := 30.2
const WALL_H := 5.6
const MOUTH := 0.16                     ## half-angle of the raid door's opening (rad): ~9.6 m chord
const STONE_R := 21.0
const STONES := 10
const KNOT_R := 25.5
const KNOT_HP := 18.0
const KNOT_ANGLES := [60.0, 180.0, 300.0]
const OPENINGS := [0.0, 90.0, 180.0, 270.0]   ## the inner hedge's mouths (degrees from the raid door)
const ERUPT := 1.6                      ## seconds a maze wall's line fills red before it grows
const ERUPT_GLOOM := 20.0
## The maze: [stage, a0 deg, r0, a1 deg, r1] wall from polar (a0, r0) to (a1, r1), angles from the door.
## Stage 1 (the intermission's start): spokes between the inner mouths. Stage 2: arcs before the
## mouths (go round). Stage 3: outer spokes fencing each heart-knot in its own bay (open inward).
const MAZE := [
	[1, 45.0, 14.6, 45.0, 20.0], [1, 135.0, 14.6, 135.0, 20.0], [1, 225.0, 14.6, 225.0, 20.0], [1, 315.0, 14.6, 315.0, 20.0],
	[2, -13.0, 17.4, 0.0, 17.6], [2, 0.0, 17.6, 13.0, 17.4], [2, 77.0, 17.4, 90.0, 17.6], [2, 90.0, 17.6, 103.0, 17.4],
	[2, 167.0, 17.4, 180.0, 17.6], [2, 180.0, 17.6, 193.0, 17.4], [2, 257.0, 17.4, 270.0, 17.6], [2, 270.0, 17.6, 283.0, 17.4],
	[3, 30.0, 22.6, 30.0, 28.4], [3, 90.0, 22.6, 90.0, 28.4], [3, 150.0, 22.6, 150.0, 28.4],
	[3, 210.0, 22.6, 210.0, 28.4], [3, 270.0, 22.6, 270.0, 28.4], [3, 330.0, 22.6, 330.0, 28.4],
]
const BRIAR_START := 29.0
const BRIAR_MIN := 16.0
const BRIAR_STEP := 14.0
const BRIAR_SHRINK := 3.25
const BRIAR_GLOOM := 5.0                ## Gloom per half second outside the briars
const EMBER := Color(1.0, 0.46, 0.2)
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF_PATH := "res://core/world/henge_raid.gd"
const SAP := Color(0.8, 1.0, 0.4)
const BLOOD := Color(1.0, 0.22, 0.1)

var C := Vector3.ZERO
var gate_a := 0.0
var walls: Array[Bramble] = []
var knots: Array[HeartKnot] = []
var stones: Array[Node3D] = []
var briars_r := BRIAR_START
var briars_on := false
var mood := "rest"
var _boss: Node = null
var _briar_t := 0.0
var _briar_tick := 0.0
var _heart: OmniLight3D
var _moon: SpotLight3D
var _bowls: Array[OmniLight3D] = []
var _briar_band: MeshInstance3D
var _pulse := 0.0


## A wall of the bramble maze: hidden and passable at rest; grows (and blocks) when its stage comes.
class Bramble extends StaticBody3D:
	var stage := 1
	var length := 4.0
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var grown := false
	var _cs: CollisionShape3D
	var _mi: MeshInstance3D

	func setup(p0: Vector3, p1: Vector3, mesh: Mesh, mat: Material) -> void:
		a = p0
		b = p1
		length = p0.distance_to(p1)
		collision_layer = 0
		collision_mask = 0
		_cs = CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(length + 0.6, 4.6, 1.1)
		_cs.shape = bs
		_cs.position = Vector3(0, 2.3, 0)
		_cs.disabled = true
		add_child(_cs)
		_mi = MeshInstance3D.new()
		_mi.mesh = mesh
		_mi.material_override = mat
		_mi.visible = false
		_mi.scale = Vector3(1, 0.02, 1)
		add_child(_mi)

	## Grow now (the red line has filled): solid, and anyone standing in it is put out to a side.
	func grow(animate := true) -> void:
		if grown:
			return
		grown = true
		_mi.visible = true
		collision_layer = Layers.WORLD
		_cs.disabled = false
		if animate:
			var tw := create_tween()
			tw.tween_property(_mi, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_mi.scale = Vector3.ONE
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if p:
			var local := global_transform.affine_inverse() * p.global_position
			if absf(local.x) < length * 0.5 + 0.6 and absf(local.z) < 1.0 and local.y < 5.0:
				var side := 1.0 if local.z >= 0.0 else -1.0
				p.global_position = global_transform * Vector3(local.x, local.y + 0.1, side * 1.5)
				p.reset_physics_interpolation()

	func wither(animate := true) -> void:
		if not grown and not _mi.visible:
			return
		grown = false
		collision_layer = 0
		_cs.disabled = true
		if animate:
			var tw := create_tween()
			tw.tween_property(_mi, "scale", Vector3(0.8, 0.02, 0.8), 1.2).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void: _mi.visible = false)
		else:
			_mi.visible = false
			_mi.scale = Vector3(1, 0.02, 1)


## A heart-knot: roots knotted round an ember heart, grown out of the outer ring in the intermission.
## Hit like a foe (bolts, Lance, Nova find its hurtbox); burned through, it bursts and is gone.
class HeartKnot extends StaticBody3D:
	signal burned(knot: Node)
	var hp := KNOT_HP
	var max_hp := KNOT_HP
	var hp_bar_y := 3.75                ## above the knot's roots (they stand 3.2 m)
	var _core: MeshInstance3D
	var _light: OmniLight3D
	var _label: Label3D
	var _bar: MeshInstance3D            ## the foes' own health plate (health_bar.gdshader), not a text gauge
	var _trail := 1.0
	var _shake := 0.0
	var vis: Node3D                     ## the visuals (grown and burned by scale; the body never scales: Jolt)

	func setup(mesh: Mesh, bark: Material, core_mat: Material) -> void:
		collision_layer = Layers.HURTBOX | Layers.PROPS
		collision_mask = 0
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 1.0
		cap.height = 3.0
		cs.shape = cap
		cs.position = Vector3(0, 1.5, 0)
		add_child(cs)
		vis = Node3D.new()
		add_child(vis)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = bark
		vis.add_child(mi)
		_core = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.62
		sm.height = 1.15
		_core.mesh = sm
		_core.material_override = core_mat
		_core.position = Vector3(0, 1.45, 0)
		_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vis.add_child(_core)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.5, 0.18)
		_light.light_energy = 1.6
		_light.omni_range = 7.0
		_light.shadow_enabled = false
		_light.position = Vector3(0, 1.6, 0)
		_light.set_meta(&"light_class", "fill")
		add_child(_light)
		# a title like an elite's (elites.gd) over the same plate a foe wears
		_label = Label3D.new()
		_label.text = "Heart-Knot"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.pixel_size = 0.0042
		_label.font_size = 44
		_label.outline_size = 10
		_label.modulate = Color(1.0, 0.82, 0.6)
		_label.outline_modulate = Color(0.03, 0.02, 0.05, 0.85)
		_label.position = Vector3(0, hp_bar_y + 0.42, 0)
		_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_label)
		var mat := ShaderMaterial.new()
		mat.shader = load(Enemy.HP_BAR_SHADER)
		mat.set_shader_parameter(&"size", Vector2(1.3, 0.13))   # an objective: a broader plate than a foe's
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = mat
		_bar = MeshInstance3D.new()
		_bar.name = "HealthBar"
		_bar.mesh = quad
		_bar.position = Vector3(0, hp_bar_y, 0)
		_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bar.extra_cull_margin = 2.4
		_bar.ignore_occlusion_culling = true
		add_child(_bar)
		_bar.set_instance_shader_parameter(&"segments", Enemy.hp_segments(int(max_hp)))
		_refresh()

	func is_alive() -> bool:
		return hp > 0.0

	func take_hit(dmg: float, _from: Node = null) -> void:
		if hp <= 0.0 or dmg <= 0.0:
			return
		hp = maxf(0.0, hp - dmg)
		_shake = 0.25
		HitText.pop(global_position + Vector3.UP * (hp_bar_y + 0.4), str(snappedf(dmg, 0.1)), Color(1.0, 0.7, 0.35))
		Vfx.burst(global_position + Vector3.UP * 1.5, Color(1.6, 0.6, 0.15), {"count": 14, "life": 0.4, "speed": Vector2(2.0, 5.0), "size": 0.05, "gravity": -6.0})
		_refresh()
		if hp <= 0.0:
			_burn()

	func _refresh() -> void:
		_bar.set_instance_shader_parameter(&"fill", hp / max_hp)
		_bar.set_instance_shader_parameter(&"trail", _trail)
		_light.light_energy = 0.8 + 1.4 * (hp / max_hp)

	func _process(delta: float) -> void:
		var ratio := hp / max_hp
		if _trail > ratio:                # the lost health eases away behind the fill, as on a foe
			_trail = maxf(ratio, _trail - delta * 0.6)
			_bar.set_instance_shader_parameter(&"trail", _trail)
		if _shake > 0.0:
			_shake -= delta
			_core.position.x = sin(_shake * 90.0) * 0.06
		var s := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.006)
		_core.scale = Vector3.ONE * s

	func _burn() -> void:
		collision_layer = 0
		var at := global_position + Vector3.UP * 1.5
		Vfx.burst(at, Color(2.2, 0.8, 0.2), {"count": 60, "life": 0.9, "speed": Vector2(3.0, 8.0), "size": 0.07, "gravity": -4.0, "trail": 0.08})
		Vfx.light(at, Color(1.0, 0.5, 0.2), 4.0, 12.0, 0.6)
		Vfx.ring(global_position + Vector3.UP * 0.1, 3.0, Color(2.0, 0.6, 0.15), 0.6, 0.08, Vector3.UP, 1.4)
		Sfx.play_stream(BossKit.Synth.get_stream("stagger"), at, 2.0, 0.7)
		burned.emit(self)
		_label.visible = false
		_bar.visible = false
		_light.visible = false
		var tw := create_tween()
		tw.tween_property(vis, "scale", Vector3(1.3, 0.05, 1.3), 0.5).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)


static func build(host: Node3D, centre: Vector3, gate_angle: float) -> Node3D:
	var r := (load("res://core/world/henge_raid.gd") as GDScript).new() as Node3D
	r.name = "HengeRaid"
	host.add_child(r)
	r.set("C", centre)
	r.set("gate_a", gate_angle)
	r.call("_build")
	return r


func _dir(deg: float) -> Vector3:
	var a := gate_a + deg_to_rad(deg)
	return Vector3(cos(a), 0.0, sin(a))


func at_polar(deg: float, r: float) -> Vector3:
	return C + _dir(deg) * r


func _build() -> void:
	var t0 := Time.get_ticks_msec()
	_outer_wall()
	_stones()
	_maze()
	_bowls_and_lights()
	_briar_band_build()
	print("HENGE_RAID room r %.1f: wall %.1f, %d stones, %d maze walls, %d bowls (%d ms)" % [FLOOR_R, WALL_R, stones.size(), walls.size(), _bowls.size(), Time.get_ticks_msec() - t0])


## The bramble meshes are pure GDScript (a thousand noisy tubes): built once, then read from the
## Realm's mesh cache (GenCache; keyed by the room's shape, rebuilt when this file changes).
func _cached(key: String, make: Callable) -> ArrayMesh:
	var full := "henge_raid_%s_%d" % [key, hash(Vector4(C.x, C.z, gate_a, WALL_R))]
	var m := GenCache.load_mesh(full, SELF_PATH)
	if m == null:
		m = make.call()
		GenCache.save_mesh(full, SELF_PATH, m)
	return m


func _bramble_mat() -> StandardMaterial3D:
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.95
	bm.emission_enabled = true
	bm.emission = Color(0.4, 0.06, 0.03)
	bm.emission_energy_multiplier = 0.15
	return bm


## Brambles along a line (local x from -len/2 to len/2), `h` tall, into `cm` at `xf`.
func _brambles(cm: CreatureMesh, rng: RandomNumberGenerator, xf: Transform3D, length: float, h: float, per_m := 1.3) -> void:
	var clumps := maxi(2, int(length * per_m))
	for c in clumps:
		var x := lerpf(-length * 0.5, length * 0.5, (float(c) + 0.5) / float(clumps))
		for j in 4:
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			var o := Vector3(x + rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.35, 0.35))
			var tall := h * rng.randf_range(0.6, 1.0)
			for q in 6:
				var t := float(q) / 5.0
				pts.append(xf * (o + Vector3(sin(t * 6.0 + float(j) * 1.7) * 0.4, t * tall, cos(t * 5.0 + float(c)) * 0.35)))
				rad.append(lerpf(0.11, 0.025, t))
			cm.tube(pts, rad, 5, Color(0.15, 0.085, 0.06), 0.0, 0.25, 0.0, Vector2.ONE, 0.4)


## The outer bramble wall, solid and above a double jump's reach, open only at the raid door.
func _outer_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3401
	var body := StaticBody3D.new()
	body.name = "RaidWallBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	var segs := 96
	for i in segs:
		var a0 := gate_a + TAU * (float(i) + 0.5) / float(segs)
		if absf(wrapf(a0 - gate_a, -PI, PI)) < MOUTH:
			continue
		var p := Vector3(C.x + cos(a0) * WALL_R, C.y, C.z + sin(a0) * WALL_R)
		var bas := Basis(Vector3.UP, -a0 + PI * 0.5)
		var seg_len := TAU * WALL_R / float(segs) + 0.12
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(seg_len, WALL_H, 0.9)
		cs.shape = bs
		cs.transform = Transform3D(bas, p + Vector3.UP * WALL_H * 0.5)
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "RaidWall"
	mi.mesh = _cached("wall", _wall_mesh.bind(rng, segs))
	mi.material_override = _bramble_mat()
	add_child(mi)
	_door_frame()


func _wall_mesh(rng: RandomNumberGenerator, segs: int) -> ArrayMesh:
	var cm := CreatureMesh.new(3402)
	for i in segs:
		var a0 := gate_a + TAU * (float(i) + 0.5) / float(segs)
		if absf(wrapf(a0 - gate_a, -PI, PI)) < MOUTH:
			continue
		var p := Vector3(C.x + cos(a0) * WALL_R, C.y, C.z + sin(a0) * WALL_R)
		var bas := Basis(Vector3.UP, -a0 + PI * 0.5)
		var seg_len := TAU * WALL_R / float(segs) + 0.12
		_brambles(cm, rng, Transform3D(bas, p), seg_len, WALL_H * 0.92, 1.3)
		if i % 6 == 3:
			# a thorn trunk: an old briar grown thick as a tree, the wall's silhouette
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			var tall := rng.randf_range(7.0, 9.5)
			for q in 8:
				var t := float(q) / 7.0
				pts.append(p + Vector3(sin(t * 4.0 + float(i)) * 0.6, t * tall, cos(t * 3.0 + float(i)) * 0.5))
				rad.append(lerpf(0.42, 0.04, t))
			cm.tube(pts, rad, 7, Color(0.12, 0.07, 0.05), 0.0, 0.3, 0.0, Vector2.ONE, 0.3)
			for k in 5:
				var t := 0.25 + 0.14 * float(k)
				var base := pts[int(t * 7.0)]
				var out := Vector3(cos(float(k) * 2.4), 0.5, sin(float(k) * 2.4)).normalized()
				cm.claw(base, out, 1.2, 0.08, Vector3(0, 0.3, 0), Color(0.18, 0.1, 0.07))
	return OssKit.with_lods(cm.commit())


func _door_frame() -> void:
	# the raid door's frame: two great uprights and a lintel of the Realm's weathered stone
	var rk := load("res://core/world/realm/rock_kit.gd")
	var out := _dir(0.0)
	var side := out.cross(Vector3.UP).normalized()
	var gb := Basis(side, Vector3.UP, out)
	var gp := C + out * (WALL_R * cos(MOUTH))
	var half := WALL_R * sin(MOUTH)
	for s: float in [-1.0, 1.0]:
		rk.spawn(self, rk.slab(3411 + int(s), Vector3(1.6, 7.4, 1.3), "granite", 0.08), Transform3D(gb, gp + side * (s * (half + 0.9)) + Vector3.DOWN * 0.4), true, 120.0)
	rk.spawn(self, rk.slab(3415, Vector3(half * 2.0 + 3.6, 1.1, 1.5), "granite", 0.02), Transform3D(gb, gp + Vector3.UP * 6.6), true, 120.0)


## The outer ring of great stones: shelter from the Thornstorm (line of sight), between the wall and
## the inner hedge. Skipped where the raid door's line runs in.
func _stones() -> void:
	var rk := load("res://core/world/realm/rock_kit.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3420
	for i in STONES:
		var deg := 18.0 + 36.0 * float(i)
		var p := at_polar(deg, STONE_R)
		var out := _dir(deg)
		var b := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out).rotated(Vector3.UP, rng.randf_range(-0.2, 0.2))
		var tall := rng.randf_range(6.8, 8.4)
		var mi: MeshInstance3D = rk.spawn(self, rk.slab(3421 + i, Vector3(2.6, tall, 1.8), "mossy" if i % 3 == 0 else "granite", 0.18), Transform3D(b, p + Vector3.DOWN * 0.35), true, 140.0)
		if mi:
			mi.name = "RaidStone%d" % i
			stones.append(mi)


func _maze() -> void:
	var mat := _bramble_mat()
	for m: Array in MAZE:
		var p0 := at_polar(float(m[1]), float(m[2]))
		var p1 := at_polar(float(m[3]), float(m[4]))
		var mid := (p0 + p1) * 0.5
		var along := (p1 - p0)
		along.y = 0.0
		var length := along.length()
		var bas := Basis(along.normalized(), Vector3.UP, along.normalized().cross(Vector3.UP)).orthonormalized()
		var w := Bramble.new()
		w.name = "Maze%d_%d" % [int(m[0]), walls.size()]
		w.stage = int(m[0])
		add_child(w)
		w.global_transform = Transform3D(bas, mid)
		var idx := walls.size()
		w.setup(p0, p1, _cached("maze%d" % idx, func() -> ArrayMesh:
			var cm := CreatureMesh.new(3441 + idx)
			var r2 := RandomNumberGenerator.new()
			r2.seed = 3440 + idx
			_brambles(cm, r2, Transform3D.IDENTITY, length + 0.4, 4.4, 1.2)
			return cm.commit()), mat)
		walls.append(w)


func _bowls_and_lights() -> void:
	# the ember heart over the altar (ThornHenge's own light is recoloured to it)
	_heart = OmniLight3D.new()
	_heart.name = "HeartLight"
	_heart.light_color = EMBER
	_heart.light_energy = 1.0
	_heart.omni_range = 28.0
	_heart.omni_attenuation = 1.4
	_heart.shadow_enabled = false
	_heart.set_meta(&"light_class", "fill")
	add_child(_heart)
	_heart.global_position = C + Vector3.UP * 4.5
	LightPolicy.apply_fade(_heart)
	# a pale moon shaft over the floor: the room reads from any side (no shadows: the budget)
	_moon = SpotLight3D.new()
	_moon.name = "MoonShaft"
	_moon.light_color = Color(0.6, 0.7, 0.95)
	_moon.light_energy = 1.6
	_moon.spot_range = 80.0
	_moon.spot_angle = 40.0
	_moon.spot_attenuation = 0.4
	_moon.shadow_enabled = false
	_moon.set_meta(&"light_class", "fill")
	add_child(_moon)
	_moon.global_position = C + Vector3(8.0, 44.0, 12.0)
	_moon.look_at(C, Vector3.UP)
	LightPolicy.apply_fade(_moon)
	# fire bowls beside the inner hedge's mouths
	var k := OssKit.new()
	k.keep_lanes = false
	var spots: Array[Vector3] = []
	for deg: float in OPENINGS:
		var side := _dir(deg).cross(Vector3.UP).normalized()
		spots.append(at_polar(deg, 14.2) + side * 3.6)
	for p in spots:
		k.box("stone", p + Vector3.UP * 0.5, Vector3(0.8, 1.0, 0.8), Basis.IDENTITY, true, 0.88)
		k.box("stone", p + Vector3.UP * 1.08, Vector3(1.15, 0.16, 1.15), Basis.IDENTITY, true, 0.8)
		k.box("iron", p + Vector3.UP * 1.22, Vector3(1.0, 0.14, 1.0), Basis.IDENTITY, false)
	var host := Node3D.new()
	host.name = "RaidBowls"
	add_child(host)
	k.commit(host, "BowlBody")
	var Glow := load("res://core/world/realm/unkindled_glow.gd")
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.albedo_texture = Glow.call("_tongue")
	fm.albedo_color = Color(1.3, 0.55, 0.2, 1.0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.85, 1.4)
	qm.center_offset = Vector3(0, 0.65, 0)
	for p in spots:
		var flame := MeshInstance3D.new()
		flame.mesh = qm
		flame.material_override = fm
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(flame)
		flame.global_position = p + Vector3.UP * 1.27
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.25)
		l.light_energy = 2.0
		l.omni_range = 3.5
		l.shadow_enabled = false
		l.set_meta(&"light_class", "fill")
		host.add_child(l)
		l.global_position = p + Vector3.UP * 2.1
		LightPolicy.apply_fade(l)
		_bowls.append(l)


## The closing briars' band: a ring of ember mist at the briars' edge, shown only in the burn.
func _briar_band_build() -> void:
	_briar_band = MeshInstance3D.new()
	_briar_band.name = "BriarBand"
	var cy := CylinderMesh.new()
	cy.top_radius = 1.0
	cy.bottom_radius = 1.0
	cy.height = 1.0
	cy.cap_top = false
	cy.cap_bottom = false
	cy.radial_segments = 64
	cy.rings = 1
	_briar_band.mesh = cy
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.55, 0.12, 0.05, 0.2)
	m.disable_fog = true
	_briar_band.material_override = m
	_briar_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_briar_band.visible = false
	add_child(_briar_band)
	_briar_band.global_position = C + Vector3.UP * 0.6


# --- the room's state ---------------------------------------------------------------------------

func room_begin(boss: Node) -> void:
	_boss = boss
	_clear(false)
	set_mood("fight")


func room_reset() -> void:
	_boss = null
	_clear(true)
	set_mood("rest")


func room_won() -> void:
	_boss = null
	_clear(true)
	set_mood("won")


func _clear(animate: bool) -> void:
	for w in walls:
		w.wither(animate)
	for kn in knots:
		if is_instance_valid(kn):
			kn.queue_free()
	knots.clear()
	briars_on = false
	briars_r = BRIAR_START
	if _briar_band:
		_briar_band.visible = false


## The light follows the fight: "rest" (embers low), "fight", "rooted" (sap-gold), "bloom" (blood).
func set_mood(m: String) -> void:
	mood = m
	if _heart == null:
		return
	var col: Color = {"rest": EMBER, "fight": EMBER, "rooted": SAP, "bloom": BLOOD, "won": Color(0.9, 0.6, 0.4)}.get(m, EMBER)
	var e: float = {"rest": 1.1, "fight": 2.1, "rooted": 2.6, "bloom": 2.8, "won": 0.7}.get(m, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_heart, "light_color", col, 1.2)
	tw.tween_property(_heart, "light_energy", e, 1.2)
	var bowl_e: float = {"rooted": 1.2, "bloom": 2.6}.get(m, 2.0)
	var bowl_c: Color = Color(1.0, 0.3, 0.15) if m == "bloom" else Color(1.0, 0.55, 0.25)
	for l in _bowls:
		tw.tween_property(l, "light_energy", bowl_e, 1.2)
		tw.tween_property(l, "light_color", bowl_c, 1.2)
	tw.tween_property(_moon, "light_energy", 0.9 if m == "bloom" else 1.6, 1.2)


## Grow every wall of stage `k`: each line fills red for ERUPT s, then the brambles erupt along it.
func grow_stage(k: int, boss: Node = null) -> void:
	for w in walls:
		if w.stage != k or w.grown:
			continue
		var d := w.b - w.a
		d.y = 0.0
		var yaw := atan2(-d.x, -d.z)
		BossKit.zone(self, w.a + Vector3.UP * 0.02, ERUPT, ERUPT_GLOOM, {"rect": Vector2(0.9, d.length() * 0.5 + 0.2), "yaw": yaw, "spikes": "thorn", "color": BossKit.THORN})
		var wid := w.get_instance_id()
		get_tree().create_timer(ERUPT, false).timeout.connect(func() -> void:
			var ww := instance_from_id(wid) as Bramble
			if ww != null and is_instance_valid(_boss) and (_boss as Enemy).is_alive():
				ww.grow())
	if boss != null:
		Sfx.play_stream(BossKit.Synth.get_stream("spike"), C + Vector3.UP, 2.0, 0.6)


func wither_stage(k: int) -> void:
	for w in walls:
		if w.stage == k:
			w.wither(true)


func grown_count() -> int:
	var n := 0
	for w in walls:
		if w.grown:
			n += 1
	return n


## The intermission's knots: three out of the outer ring, each in its own bay. Returns them.
func spawn_knots(boss: Node) -> Array[HeartKnot]:
	for kn in knots:
		if is_instance_valid(kn):
			kn.queue_free()
	knots.clear()
	var cm := CreatureMesh.new(3460)
	for j in 7:
		var a := TAU * float(j) / 7.0
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for q in 7:
			var t := float(q) / 6.0
			var rr := 1.0 - 0.75 * absf(t - 0.45) * 2.0
			pts.append(Vector3(cos(a + t * 2.2) * rr * 1.05, t * 3.2, sin(a + t * 2.2) * rr * 1.05))
			rad.append(lerpf(0.24, 0.07, t))
		cm.tube(pts, rad, 6, Color(0.17, 0.1, 0.07), 0.0, 0.3)
	var bark := _bramble_mat()
	var core := StandardMaterial3D.new()
	core.albedo_color = Color(0.4, 0.12, 0.03)
	core.emission_enabled = true
	core.emission = Color(1.0, 0.4, 0.1)
	core.emission_energy_multiplier = 1.5
	var mesh := cm.commit()
	for deg: float in KNOT_ANGLES:
		var kn := HeartKnot.new()
		kn.name = "HeartKnot%d" % knots.size()
		add_child(kn)
		kn.global_position = at_polar(deg, KNOT_R)
		kn.setup(mesh, bark, core)
		kn.set_meta(&"summoned_by", String(boss.get_meta(&"boss_id", "")) if boss else "")
		kn.vis.scale = Vector3(1, 0.05, 1)
		kn.create_tween().tween_property(kn.vis, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		SpellFx.rift_in(kn.global_position)
		knots.append(kn)
	return knots


func knots_left() -> int:
	var n := 0
	for kn in knots:
		if is_instance_valid(kn) and kn.is_alive():
			n += 1
	return n


## The burn phase: the floor closes in ring by ring.
func start_briars() -> void:
	briars_on = true
	briars_r = BRIAR_START
	_briar_t = BRIAR_STEP
	_briar_tick = 0.0
	_briar_band.visible = true
	_briar_band.scale = Vector3(briars_r, 2.2, briars_r)


## True when something solid (a standing stone, a grown wall, the hedge) stands between the two.
func shelter(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.6, to + Vector3.UP * 1.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty()


func _physics_process(delta: float) -> void:
	if not briars_on:
		return
	if _boss == null or not is_instance_valid(_boss):
		return
	var haste := 1.0
	_briar_t -= delta * haste
	if _briar_t <= 3.0 and _briar_t + delta > 3.0 and briars_r > BRIAR_MIN + 0.1:
		var nr := maxf(BRIAR_MIN, briars_r - BRIAR_SHRINK)
		Vfx.ring(C + Vector3.UP * 0.12, nr, BossKit.THORN, 3.0, 0.14, Vector3.UP, 1.4)
		BossKit.emote(_boss, "The briars close.", Color(1.0, 0.5, 0.35))
	if _briar_t <= 0.0:
		_briar_t = BRIAR_STEP
		if briars_r > BRIAR_MIN + 0.1:
			briars_r = maxf(BRIAR_MIN, briars_r - BRIAR_SHRINK)
			var tw := create_tween()
			tw.tween_property(_briar_band, "scale", Vector3(briars_r, 2.2, briars_r), 1.0).set_ease(Tween.EASE_OUT)
	_briar_tick -= delta
	if _briar_tick <= 0.0:
		_briar_tick = 0.5
		var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p:
			var d := p.global_position - C
			if Vector2(d.x, d.z).length() > briars_r and absf(d.y) < 6.0:
				var mult := (_boss as Enemy).dmg_mult if _boss is Enemy else 1.0
				p.take_wound(BRIAR_GLOOM * mult, C + d.normalized() * (briars_r + 2.0))
				HitText.pop(p.global_position + Vector3.UP * 2.2, "briars", Color(1.0, 0.4, 0.25))
