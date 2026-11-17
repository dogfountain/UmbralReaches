extends Node3D
## THE FOLK (r-round "villager acts"): the ambient people of Hearthward that the village's own cast does not cover, kept
## by one node. Twelve people are built once (progressively, a frame apart, once the Realm is up: the mesh is a
## GenCache hit after the first run) and then only woken and slept by distance:
##   a sweeper at the Keg's step, a fiddler and a dancer in the street before it, a porter with a sack, a water-bearer,
##   three children (tag, then hide and seek), a watchman with a lantern, a mourner at the graves, a net-mender, and
##   two people talking on logs by the green.
## They answer the night: a wave at the wanderer (readier the better the village regards him, from the village's
## restorations), a nod to a passer-by, a look up at the eclipse, a run for the Keg when the Gloom tide rises (they
## vanish into the door and are back on their marks when it breaks). Settings.night_life off hides them all.
## Cost: nothing runs for a person beyond SLEEP_R metres or while the Living Night is off; awake, each person poses at
## the villagers' distance rates and eases between poses (folk_actor.gd), no allocation per frame. Rigs are never built
## mid-play after the first seconds. Load by path (no class_name).

const Actor := preload("res://core/life/folk/folk_actor.gd")
const Roles := preload("res://core/life/folk/folk_roles.gd")
const Reg := preload("res://core/world/night_life/night_registry.gd")
const VillageState := preload("res://core/life/village/village_state.gd")

const WAKE_R := 80.0
const SLEEP_R := 100.0
const TICK := 0.4

const SKIN_A := Color(0.86, 0.65, 0.49)
const SKIN_B := Color(0.78, 0.58, 0.42)
const SKIN_C := Color(0.6, 0.43, 0.32)

var ctx := {"player": Vector3.INF, "eclipse": 0.0, "regard": 0.0, "alarm": false, "folk": [], "moon_yaw": 0.0}
var _defs: Array[Dictionary] = []
var _folk: Array = []
var _kids: Array = []
var _game := {}
var _built := 0
var _wait := 0.0
var _tick := 0.0
var _regard_t := 0.0
var _props: Array[Node3D] = []
var _ready_world := false
var _alarm_end := 0.0
var _pets: Node3D
static var _net_tex: ImageTexture


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_defs = _definitions()
	_pets = (load("res://core/life/folk/pets.gd") as GDScript).new() as Node3D
	_pets.name = "Pets"
	_pets.set("ctx", ctx)
	add_child(_pets)
	Events.gloom_tide.connect(_on_tide)


## Where each person stands and how they look. Positions are the village's own walking nodes (village_cast.gd NODES)
## or the street before the Keg; looks are VillagerRig options.
func _definitions() -> Array[Dictionary]:
	var keg := Roles.node_pos("keg", Vector2(17.6, 20.0))
	var well := Roles.node_pos("well", Vector2(-10.0, 46.3))
	var maud := Roles.node_pos("maud", Vector2(-13.2, 39.0))
	var forge := Roles.node_pos("forge_front", Vector2(12.5, 56.0))
	var road := Roles.node_pos("road_e1", Vector2(11.0, 48.2))
	var reed := Roles.node_pos("reed_s", Vector2(24.5, 37.3))
	var gw := Roles.node_pos("green_w", Vector2(-7.0, 34.0))
	var out: Array[Dictionary] = []
	out.append({"id": "sweeper", "role": "sweeper", "at": keg + Vector2(0.0, -0.3), "face": PI,
		"look": {"seed": 9101, "sex": "f", "age": "old", "garment": "dress", "apron": "linen", "hair": "bun", "hat": "kerchief", "r": "broom",
			"cloth": Color(0.34, 0.28, 0.3), "cloth2": Color(0.4, 0.34, 0.3), "hair_c": Color(0.62, 0.6, 0.58), "skin": SKIN_B, "leather": Color(0.35, 0.24, 0.14)}})
	out.append({"id": "fiddler", "role": "fiddler", "at": keg + Vector2(2.9, -0.1), "face": PI * 0.5,
		"look": {"seed": 9102, "sex": "m", "age": "adult", "garment": "coat", "hat": "brim", "hair": "short", "beard": "short", "l": "fiddle", "r": "bow",
			"cloth": Color(0.3, 0.2, 0.18), "cloth2": Color(0.5, 0.3, 0.2), "hair_c": Color(0.28, 0.2, 0.14), "skin": SKIN_A, "leather": Color(0.3, 0.2, 0.12)}})
	out.append({"id": "dancer", "role": "dancer", "at": keg + Vector2(-2.4, -0.2), "face": -PI * 0.5,
		"look": {"seed": 9103, "sex": "f", "age": "teen", "garment": "dress", "hair": "long",
			"cloth": Color(0.5, 0.22, 0.2), "cloth2": Color(0.62, 0.42, 0.22), "hair_c": Color(0.3, 0.18, 0.1), "skin": SKIN_A, "leather": Color(0.35, 0.22, 0.14)}})
	out.append({"id": "porter", "role": "porter", "at": forge, "other": road, "face": 0.0,
		"look": {"seed": 9104, "sex": "m", "age": "adult", "garment": "shirt", "apron": "leather", "hair": "short", "r": "sack",
			"cloth": Color(0.4, 0.34, 0.26), "cloth2": Color(0.36, 0.3, 0.24), "hair_c": Color(0.2, 0.15, 0.1), "skin": SKIN_C, "leather": Color(0.3, 0.2, 0.12)}})
	out.append({"id": "water", "role": "waterbearer", "at": well, "other": maud, "face": 0.0,
		"look": {"seed": 9105, "sex": "f", "age": "adult", "garment": "dress", "apron": "linen", "hair": "braids", "r": "bucket",
			"cloth": Color(0.3, 0.36, 0.42), "cloth2": Color(0.5, 0.46, 0.38), "hair_c": Color(0.4, 0.26, 0.14), "skin": SKIN_B, "leather": Color(0.36, 0.24, 0.14)}})
	var ang := [0.0, 2.1, 4.2]
	var kid_looks := [
		{"seed": 9111, "sex": "f", "age": "child", "garment": "dress", "hair": "braids", "cloth": Color(0.5, 0.3, 0.24), "cloth2": Color(0.44, 0.36, 0.26), "hair_c": Color(0.5, 0.3, 0.12), "skin": SKIN_A, "leather": Color(0.4, 0.26, 0.14)},
		{"seed": 9112, "sex": "m", "age": "child", "garment": "shirt", "hair": "short", "cloth": Color(0.36, 0.42, 0.34), "cloth2": Color(0.4, 0.34, 0.26), "hair_c": Color(0.24, 0.16, 0.1), "skin": SKIN_B, "leather": Color(0.34, 0.22, 0.12)},
		{"seed": 9113, "sex": "f", "age": "child", "garment": "dress", "hair": "wild", "cloth": Color(0.3, 0.34, 0.5), "cloth2": Color(0.44, 0.38, 0.3), "hair_c": Color(0.15, 0.1, 0.08), "skin": SKIN_C, "leather": Color(0.34, 0.22, 0.12)}]
	for i in 3:
		out.append({"id": "kid%d" % i, "role": "kid", "at": Roles.ring_point(Roles.RING + 0.5 * float(i), ang[i]), "face": 0.0, "look": kid_looks[i]})
	out.append({"id": "watchman", "role": "watchman", "at": Roles.ring_point(Roles.ROUND, 1.0), "face": 0.0,
		"look": {"seed": 9121, "sex": "m", "age": "adult", "garment": "coat", "hat": "cap", "hair": "short", "beard": "short", "r": "staff", "l": "lantern",
			"cloth": Color(0.22, 0.26, 0.3), "cloth2": Color(0.3, 0.3, 0.28), "hair_c": Color(0.3, 0.3, 0.3), "skin": SKIN_A, "leather": Color(0.28, 0.2, 0.12)}})
	out.append({"id": "mourner", "role": "mourner", "at": Vector2(-55.5, 42.2), "face": 0.0,
		"look": {"seed": 9131, "sex": "m", "age": "old", "garment": "robe", "hood": true, "hair": "short", "beard": "long",
			"cloth": Color(0.2, 0.2, 0.24), "cloth2": Color(0.28, 0.26, 0.26), "hair_c": Color(0.7, 0.7, 0.7), "skin": SKIN_B, "leather": Color(0.26, 0.18, 0.12)}})
	out.append({"id": "netmender", "role": "netmender", "at": reed, "face": PI * 0.5,
		"look": {"seed": 9141, "sex": "f", "age": "old", "garment": "dress", "hat": "kerchief", "hair": "bun",
			"cloth": Color(0.28, 0.36, 0.34), "cloth2": Color(0.4, 0.4, 0.34), "hair_c": Color(0.6, 0.58, 0.56), "skin": SKIN_C, "leather": Color(0.32, 0.22, 0.12)}})
	out.append({"id": "talk_a", "role": "talk_a", "at": gw + Vector2(-1.3, -1.1), "face": PI, "log": true,
		"look": {"seed": 9151, "sex": "m", "age": "adult", "garment": "coat", "hair": "short", "beard": "long",
			"cloth": Color(0.32, 0.26, 0.2), "cloth2": Color(0.36, 0.3, 0.24), "hair_c": Color(0.3, 0.22, 0.14), "skin": SKIN_A, "leather": Color(0.3, 0.2, 0.12)}})
	out.append({"id": "talk_b", "role": "talk_b", "at": gw + Vector2(-1.3, 1.1), "face": 0.0, "log": true,
		"look": {"seed": 9152, "sex": "f", "age": "adult", "garment": "dress", "hair": "bun", "apron": "linen",
			"cloth": Color(0.4, 0.28, 0.3), "cloth2": Color(0.5, 0.44, 0.36), "hair_c": Color(0.36, 0.22, 0.12), "skin": SKIN_B, "leather": Color(0.34, 0.22, 0.14)}})
	return out


func _process(delta: float) -> void:
	visible = Reg.enabled
	if not Reg.enabled:
		for f: Variant in _folk:
			f.set_awake(false)
		return
	_build_step(delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_refresh()
	if _alarm_end > 0.0:
		_alarm_end -= delta
		if _alarm_end <= 0.0:
			_end_alarm()
	# the children's game is one script over the three of them
	if _kids.size() == 3 and bool(_kids[0].awake) and not bool(ctx.alarm):
		Roles.game(_kids, _game, minf(delta, 0.1))


## The world is up when the places and fires have registered: then one person a frame (a mesh from GenCache, or built once
## behind the loading cover on a first run).
func _build_step(delta: float) -> void:
	if _built >= _defs.size():
		ctx["ready"] = true
		return
	if not _ready_world:
		_wait += delta
		if _wait < 1.5:
			return
		_wait = 0.0
		if get_tree().get_nodes_in_group(&"world_poi").is_empty():
			return
		_ready_world = true
	var d: Dictionary = _defs[_built]
	_built += 1
	var a := Actor.new()
	a.setup(String(d.id), String(d.role), d.look, ctx)
	add_child(a)
	var at: Vector2 = d.at
	a.global_position = Vector3(at.x, _ground(at), at.y)
	a.gy = a.global_position.y
	a.rotation.y = float(d.face)
	a.face = float(d.face)
	a.data["home"] = at
	a.data["face"] = float(d.face)
	if d.has("other"):
		a.data["other"] = d.other
	a.data["to_other"] = true
	_folk.append(a)
	ctx["folk"] = _folk
	if String(d.role) == "kid":
		_kids.append(a)
	if bool(d.get("log", false)):
		_log(at)
	if String(d.role) == "netmender":
		_net(at, float(d.face))


func _ground(at: Vector2) -> float:
	var world := get_world_3d()
	if world == null:
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 60.0, at.y), Vector3(at.x, -40.0, at.y), Layers.WORLD)
	var hit := world.direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


## A log to sit on, lying along x.
func _log(at: Vector2) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.22
	c.height = 1.5
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.15, 0.1)
	mat.roughness = 1.0
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visibility_range_end = 70.0
	add_child(m)
	m.global_position = Vector3(at.x, _ground(at) + 0.2, at.y)
	m.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_props.append(m)


## The net spread over the mender's knees: a flat card with a woven texture (made once).
func _net(at: Vector2, face: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _net_texture()
	mat.albedo_color = Color(0.5, 0.42, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visibility_range_end = 50.0
	add_child(m)
	var fwd := Vector2(-sin(face), -cos(face))
	var p := at + fwd * 0.45
	m.global_position = Vector3(p.x, _ground(at) + 0.36, p.y)
	m.rotation.y = face
	_props.append(m)


static func _net_texture() -> ImageTexture:
	if _net_tex:
		return _net_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + y) % 16
			var v := (x - y + 64) % 16
			var on := u < 2 or v < 2
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if on else 0.0))
	_net_tex = ImageTexture.create_from_image(img)
	return _net_tex


func _refresh() -> void:
	var cam := get_viewport().get_camera_3d()
	var pp := cam.global_position if cam != null else Vector3.INF
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	ctx["player"] = player.global_position if player != null else Vector3.INF
	ctx["player_speed"] = (player as CharacterBody3D).velocity.length() if player is CharacterBody3D else 0.0
	ctx["eclipse"] = clampf((Reg.gain_mul - 1.0) / 0.55, 0.0, 1.0)
	_regard_t -= TICK
	if _regard_t <= 0.0:
		_regard_t = 5.0
		var restored := (VillageState.data().restored as Dictionary).size()
		ctx["regard"] = clampf(float(restored) / 6.0, 0.0, 1.0)
		var moon := get_parent().get_parent().get_node_or_null("Moon") as DirectionalLight3D
		if moon != null:
			var dm := moon.global_basis.z
			ctx["moon_yaw"] = atan2(-dm.x, -dm.z)
	for f: Variant in _folk:
		if bool(ctx.alarm) and bool(f.held):
			continue
		var d: float = pp.distance_to((f as Node3D).global_position) if pp != Vector3.INF else 1e9
		if f.awake:
			if d > SLEEP_R:
				f.set_awake(false)
		elif d < WAKE_R and not bool(f.held):
			f.set_awake(true)


func _on_tide(active: bool) -> void:
	ctx["alarm"] = active
	if not active:
		_alarm_end = 6.0


## The tide has broken: everyone who ran for the door is back on their mark, and the day's games begin again.
func _end_alarm() -> void:
	ctx["alarm"] = false
	for f: Variant in _folk:
		var home: Vector2 = f.data.get("home", Vector2.ZERO)
		(f as Node3D).global_position = Vector3(home.x, _ground(home), home.y)
		f.spd = 0.0
		f.has_goal = false
		f.hold(false)
	_game = {}
