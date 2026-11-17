extends Node3D
## LANDMARK LIGHT SIGNATURES (Luke: "brighter landmarks with fire lights, mysteries etc, with a darker moon").
## The land is dark; every place that matters carries a light of its own, readable from far away, and the wanderer
## navigates the night by them. Two draws for the whole Realm, both one MultiMesh:
##   FAR CARDS  a soft billboard of light per source, 26 m .. 400 m out, that grows with distance (a point of fixed
##              angular size, like a star), unshaded, additive, fog-free, depth-tested (hills hide them). A fire gutters,
##              a window glows steady, a mystery breathes cold and slow, a tower holds a pale gold point, an unkindled
##              brazier shows a faint cold glint that asks to be lit.
##   POOLS      a flat additive disc of coloured light on the ground under a fire or a window, 0 .. 70 m out: the warm
##              pool you see approaching, before the lent real light (FixturePool) reaches it.
## Sources come from the groups the world already keeps (braziers, world_poi hosts, stables, watch posts) and from the
## village's window trails (LivingWindows registers those). Rows live in night_registry.gd. Cost: two draw calls,
## a loop over the rows four times a second, a handful of ground raycasts at start.

const Reg := preload("res://core/world/night_life/night_registry.gd")

const MAX_CARDS := 320
const MAX_POOLS := 96
const NEAR_OFF := 24.0                    ## closer than this the card is gone (the real light and the asset take over)
const NEAR_ON := 90.0
const FAR_FADE_A := 330.0
const FAR_FADE_B := 410.0
const ANGLE := 0.019                      ## on-screen size of a card, radians: a point, not a beacon
const POOL_FADE_A := 34.0
const POOL_FADE_B := 72.0
const TICK := 0.06

const MYSTERY_WORDS := ["barrow", "crypt", "henge", "stones", "circle", "grave", "cairn", "well", "spring", "altar", "falls", "fall", "crater",
	"chain", "oak", "hollow", "rune", "sigil", "cist", "tomb", "sunk", "mere", "ring", "wisp", "star", "ossuary", "vault", "pit_gate"]
const FIRE_WORDS := ["furnace", "forge", "kiln", "camp", "fire", "hearth", "bonfire", "smithy", "smelter", "lava", "cinder", "pyre"]
const TOWER_WORDS := ["tower", "spire", "watch", "belfry", "bell", "lighthouse", "crane", "keep", "gate"]
const WINDOW_WORDS := ["chapel", "nave", "shrine", "almonry", "hall", "inn", "tavern", "mill", "cottage", "house", "lodge", "hermit", "manor",
	"abbey", "cloister", "town", "kiln", "forge", "smithy", "foundry", "press", "stable", "weir", "ford", "market"]

var _cards: MultiMeshInstance3D
var _pools: MultiMeshInstance3D
var _card_mat: StandardMaterial3D
var _pool_mat: StandardMaterial3D
var _t := 0.0
var _tick := 0.0
var _scan := 0.0
var _ground_q: Array[String] = []
var _hold := 0.0
static var _spark_tex: ImageTexture
static var _pool_tex: ImageTexture


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_card_mat = card_material()
	_cards = _multimesh("FarCards", quad, _card_mat, MAX_CARDS)
	var flat := QuadMesh.new()
	flat.size = Vector2.ONE
	flat.orientation = PlaneMesh.FACE_Y
	_pool_mat = pool_material()
	_pools = _multimesh("Pools", flat, _pool_mat, MAX_POOLS)
	Events.brazier_kindled.connect(_on_kindled)
	_scan = 0.0


## The far card's material: unshaded, additive, billboard, fog-free, vertex colour as albedo (NightWarm draws one behind the loading cover).
static func card_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _spark()
	m.albedo_color = Color(1.5, 1.5, 1.5, 1.0)            # over 1: the glow pass (threshold 1.15) blooms the point
	m.no_depth_test = false
	return m


## The ground pool's material: a flat additive disc, proximity-faded where it meets the ground.
static func pool_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _pool()
	m.albedo_color = Color(1.2, 1.2, 1.2, 1.0)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.6
	return m


func _multimesh(n: String, mesh: Mesh, mat: Material, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.custom_aabb = AABB(Vector3(-2000, -400, -2000), Vector3(4000, 1200, 4000))      # the instances span the Realm
	mi.extra_cull_margin = 200.0
	mi.ignore_occlusion_culling = true
	mi.add_to_group(Groups.CULL_SKIP)
	add_child(mi)
	return mi


func _on_kindled(_b: Node3D) -> void:
	_scan = 0.0
	_hold = 0.0


func _process(delta: float) -> void:
	_t += delta
	Reg.pulse = maxf(0.0, Reg.pulse - delta * 1.8)
	visible = Reg.enabled
	if not Reg.enabled:
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 6.0 if Reg.size() > 0 else 1.0
		_discover()
	_ground_step()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	_draw()


## Rows from the groups the world already keeps. A cheap pass (a few hundred nodes), every six seconds.
func _discover() -> void:
	var tree := get_tree()
	for n: Node in tree.get_nodes_in_group(Groups.BRAZIER):
		var b := n as Brazier
		if b == null or not b.is_inside_tree():
			continue
		var key := "br_%s_%d" % [b.name, hash(b.get_path())]
		var p := b.global_position + Vector3(0.0, 1.5, 0.0)
		var fresh := not Reg.has(key)
		if b.lit:
			Reg.put(key, p, Reg.Kind.FIRE, 1.15, b.global_position.y, true)
		else:
			Reg.put(key, p + Vector3(0.0, 0.3, 0.0), Reg.Kind.COLD, 0.7, b.global_position.y, true)
		if fresh:
			_ground_q.append(key)
	for n: Node in tree.get_nodes_in_group(&"world_poi"):
		var h := n as Node3D
		if h == null or not h.is_inside_tree():
			continue
		var key := "poi_%d" % hash(h.get_path())
		if Reg.has(key):
			continue
		var c := h.global_position
		var cm: Variant = h.get_meta("centre") if h.has_meta("centre") else null      # (a null default still errors when absent)
		if cm is Vector3 and (cm as Vector3).length_squared() > 0.01:
			c = cm
		var id := String(h.get_meta("poi", String(h.name))).to_lower()
		var k := _classify(id + " " + String(h.name).to_lower())
		var height := 4.5 if k == Reg.Kind.TOWER else 2.2
		Reg.put(key, c + Vector3(0.0, height, 0.0), k, 0.62 if k != Reg.Kind.MYSTERY else 0.8, c.y)
		_ground_q.append(key)
	for g: StringName in [&"stables", &"watch_post"]:
		for n: Node in tree.get_nodes_in_group(g):
			var h := n as Node3D
			if h == null or not h.is_inside_tree():
				continue
			var key := "%s_%d" % [g, hash(h.get_path())]
			if Reg.has(key):
				continue
			var c := h.global_position
			Reg.put(key, c + Vector3(0.0, 3.0 if g == &"watch_post" else 2.0, 0.0), Reg.Kind.TOWER if g == &"watch_post" else Reg.Kind.WINDOW, 0.6, c.y)
			_ground_q.append(key)


static func _classify(s: String) -> int:
	for w: String in FIRE_WORDS:
		if s.contains(w):
			return Reg.Kind.FIRE
	for w: String in TOWER_WORDS:
		if s.contains(w):
			return Reg.Kind.TOWER
	for w: String in MYSTERY_WORDS:
		if s.contains(w):
			return Reg.Kind.MYSTERY
	for w: String in WINDOW_WORDS:
		if s.contains(w):
			return Reg.Kind.WINDOW
	return Reg.Kind.FIRE


## Six ground raycasts a frame at most: a source's pool lies on the real ground under it.
func _ground_step() -> void:
	if _ground_q.is_empty():
		return
	var world := get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	var n := 0
	while n < 6 and not _ground_q.is_empty():
		var key: String = _ground_q.pop_back()
		var i: int = Reg.keys.get(key, -1)
		if i < 0:
			continue
		var p: Vector3 = Reg.pos[i]
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 40.0, p.z), Vector3(p.x, p.y - 80.0, p.z), Layers.WORLD)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			Reg.ground[i] = (hit.position as Vector3).y
		n += 1


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var cmm := _cards.multimesh
	var pmm := _pools.multimesh
	var nc := 0
	var np := 0
	var t := _t
	var gm := Reg.gain_mul
	for i in Reg.size():
		if Reg.on[i] == 0:
			continue
		var p: Vector3 = Reg.pos[i]
		var d := cp.distance_to(p)
		var k := int(Reg.kind[i])
		var col := Reg.colour(k)
		var sh := Reg.shimmer(i, t)
		var g: float = Reg.gain[i] * gm * (1.0 + Reg.boost[i] + 0.9 * Reg.flash + 1.2 * Reg.pulse)
		if d > NEAR_OFF and d < FAR_FADE_B and nc < MAX_CARDS:
			var a := smoothstep(NEAR_OFF, NEAR_ON, d) * (1.0 - smoothstep(FAR_FADE_A, FAR_FADE_B, d)) * g * sh
			if a > 0.01:
				var s := d * ANGLE * (1.0 + 0.7 * Reg.haze) * (1.25 if k == Reg.Kind.FIRE or k == Reg.Kind.TOWER else (0.8 if k == Reg.Kind.WINDOW else 1.0))
				var bob := Vector3.ZERO
				if k == Reg.Kind.MYSTERY:
					bob = Vector3(sin(t * 0.37 + Reg.phase[i]) * 0.6, sin(t * 0.61 + Reg.phase[i] * 2.0) * 0.7, cos(t * 0.29 + Reg.phase[i]) * 0.6)
				cmm.set_instance_transform(nc, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), p + bob))
				cmm.set_instance_color(nc, Color(col.r, col.g, col.b, minf(a, 1.0)))
				nc += 1
		if d < POOL_FADE_B and Reg.real[i] == 0 and k != Reg.Kind.COLD and np < MAX_POOLS:
			var pa := (1.0 - smoothstep(POOL_FADE_A, POOL_FADE_B, d)) * g * sh * 0.26 * (1.0 - Reg.indoor)
			if pa > 0.01:
				var r := 4.6 if k == Reg.Kind.FIRE else (2.4 if k == Reg.Kind.WINDOW else 3.4)
				var gy: float = Reg.ground[i]
				pmm.set_instance_transform(np, Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1.0, r * 2.0)), Vector3(p.x, gy + 0.07, p.z)))
				pmm.set_instance_color(np, Color(col.r, col.g, col.b, minf(pa, 1.0)))
				np += 1
	cmm.visible_instance_count = nc
	pmm.visible_instance_count = np


## A soft point: a hot centre, a long gentle skirt.
static func _spark() -> ImageTexture:
	if _spark_tex:
		return _spark_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(float(x) + 0.5 - n * 0.5, float(y) + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * 0.5 + pow(a, 6.0) * 0.55
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex


## A flat pool of light: bright near the middle, a long fall-off to a soft rim.
static func _pool() -> ImageTexture:
	if _pool_tex:
		return _pool_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(float(x) + 0.5 - n * 0.5, float(y) + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * 0.9 + a * 0.1))
	_pool_tex = ImageTexture.create_from_image(img)
	return _pool_tex
