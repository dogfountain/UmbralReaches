extends Node3D
## MOTHS AND MOTES: the night's small creatures answer light. Pale moths circle every fire, window and mystery
## the wanderer comes near (the five nearest, seven each), flicker as their wings catch the glow, and lift away in a
## scatter when the wanderer runs through; a few come to his own lantern as soon as he stands still, and drift off as
## he walks on. Cold mysteries draw slow cold motes instead of moths. One MultiMesh, about forty billboard quads moved
## by a formula (no node, no physics); the nearest rows are picked twice a second from the night registry.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const SRC_N := 5
const PER_SRC := 7
const PER_PLAYER := 6
const RANGE := 30.0
const MAX := SRC_N * PER_SRC + PER_PLAYER

var _mm: MultiMeshInstance3D
var _t := 0.0
var _pick := 0.0
var _rows: PackedInt32Array = PackedInt32Array()
var _scatter := PackedFloat32Array()       ## per picked source: 0 calm .. 1 flown
var _calm := 0.0                           ## seconds the wanderer has stood still
static var _tex: ImageTexture


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for i in SRC_N:
		_rows.append(-1)
		_scatter.append(0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _moth()
	mat.albedo_color = Color(1.4, 1.4, 1.4, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Moths"
	_mm.multimesh = mm
	_mm.material_override = mat
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.custom_aabb = AABB(Vector3(-2000, -400, -2000), Vector3(4000, 1200, 4000))
	_mm.add_to_group(Groups.CULL_SKIP)
	add_child(_mm)


func _process(delta: float) -> void:
	_t += delta
	visible = Reg.enabled
	if not Reg.enabled:
		return
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	# the drawn position (physics interpolation): a tick position would step the moths against the interpolated body
	var pxf := player.get_global_transform_interpolated() if player != null else Transform3D(Basis.IDENTITY, Vector3(1e6, 0.0, 1e6))
	var pp := pxf.origin
	var speed := player.velocity.length() if player != null else 0.0
	_calm = _calm + delta if speed < 0.6 else maxf(0.0, _calm - delta * 3.0)
	_pick -= delta
	if _pick <= 0.0:
		_pick = 0.5
		_choose(pp)
	var mm := _mm.multimesh
	var n := 0
	for s in SRC_N:
		var r := _rows[s]
		if r < 0:
			_scatter[s] = move_toward(_scatter[s], 0.0, delta)
			continue
		var p: Vector3 = Reg.pos[r]
		# a run past the source frightens its moths up and out; they settle again in a few seconds
		var d := pp.distance_to(p)
		var fright := clampf((speed - 4.5) / 3.0, 0.0, 1.0) * (1.0 - smoothstep(3.0, 9.0, d))
		_scatter[s] = move_toward(_scatter[s], fright, delta * (3.0 if fright > _scatter[s] else 0.35))
		var cold := int(Reg.kind[r]) == Reg.Kind.MYSTERY
		var col := Reg.colour(int(Reg.kind[r])).lerp(Color(1, 1, 1), 0.45)
		var vis := smoothstep(RANGE, RANGE * 0.6, d)
		for m in PER_SRC:
			var ph := float(m) * 0.9 + float(s) * 1.7
			var w := (0.9 + 0.5 * float(m % 3)) * (0.35 if cold else 1.0)
			var a := _t * w + ph * 2.1
			var rad := (0.55 + 0.25 * float(m % 4)) * (1.0 + _scatter[s] * 5.0) + 0.2 * sin(_t * 2.3 + ph)
			var h := 0.15 * float(m % 5) - 0.2 + 0.22 * sin(_t * 1.6 + ph * 3.0) + _scatter[s] * 2.0
			var q := p + Vector3(cos(a) * rad, h, sin(a) * rad)
			var size := (0.09 if cold else 0.07) * (0.7 + 0.5 * absf(sin(_t * 17.0 + ph * 5.0)))   # the wings flapping, edge-on and flat
			var glow := (0.45 + 0.55 * absf(sin(_t * 11.0 + ph * 4.0))) * vis * (1.0 - 0.5 * _scatter[s]) * (1.0 - 0.7 * Reg.indoor)
			mm.set_instance_transform(n, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size, size)), q))
			mm.set_instance_color(n, Color(col.r, col.g, col.b, glow))
			n += 1
	# the wanderer's own lantern calls a few
	if player != null and _calm > 1.5:
		var k := clampf((_calm - 1.5) / 4.0, 0.0, 1.0)
		var lantern := pp + Vector3(0.0, 1.15, 0.0) + pxf.basis.x * -0.35
		for m in PER_PLAYER:
			var ph2 := float(m) * 1.3
			var a2 := _t * (1.1 + 0.3 * float(m % 3)) + ph2 * 2.0
			var rad2 := 0.5 + 0.18 * float(m % 3) + 0.15 * sin(_t * 2.0 + ph2)
			var q2 := lantern + Vector3(cos(a2) * rad2, 0.25 * sin(_t * 1.4 + ph2 * 2.0), sin(a2) * rad2)
			var s2 := 0.065 * (0.7 + 0.5 * absf(sin(_t * 16.0 + ph2 * 5.0)))
			mm.set_instance_transform(n, Transform3D(Basis.IDENTITY.scaled(Vector3(s2, s2, s2)), q2))
			mm.set_instance_color(n, Color(1.0, 0.85, 0.6, k * (0.4 + 0.6 * absf(sin(_t * 12.0 + ph2 * 3.0)))))
			n += 1
	mm.visible_instance_count = n


## The nearest fires, windows and mysteries within range get the moths.
func _choose(pp: Vector3) -> void:
	var best: Array = []
	for i in Reg.size():
		if Reg.on[i] == 0 or int(Reg.kind[i]) == Reg.Kind.COLD or int(Reg.kind[i]) == Reg.Kind.TOWER:
			continue
		var d2 := pp.distance_squared_to(Reg.pos[i])
		if d2 < RANGE * RANGE:
			best.append([d2, i])
	best.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var want := PackedInt32Array()
	for j in mini(best.size(), SRC_N):
		want.append(int((best[j] as Array)[1]))
	# keep a source in its slot while it stays wanted (no jump), fill free slots with the new ones
	for s in SRC_N:
		if _rows[s] >= 0 and not want.has(_rows[s]):
			_rows[s] = -1
	for r in want:
		if not _rows.has(r):
			var at := _rows.find(-1)
			if at >= 0:
				_rows[at] = r
				_scatter[at] = 0.0


static func _moth() -> ImageTexture:
	if _tex:
		return _tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(float(x) + 0.5 - n * 0.5, float(y) + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
	_tex = ImageTexture.create_from_image(img)
	return _tex
