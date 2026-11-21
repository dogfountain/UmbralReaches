extends RefCounted
## THE CROSSING, rebuilt as THE CINDER WAY (RealmRift; Luke, 21 Nov: "make the platforms lower", "why is it half water half lava??",
## "redesign it from scratch"): the only walkable way from the rift's south rim (RealmLayout.CROSSING_FOOT) to the summit ward landing
## (RealmLayout.SUMMIT_WARD), low over the lava and then one climb. The plan is rift_from_scratch.md in the docs' round-39 folder:
##   the Lip (the rim terrace, 0.6) -> the Descent, three flights on a basalt ledge against the south-west corner -> the Foot (-12.4; the
##   chapel branch leaves it) -> the causeway on basalt islands across the cooling crust, two low bridges, the Cinder Isle -> the Ward
##   Stair, wound up inside the Ward Crag (a door in its south face, a round shaft, 114 steps two and a half turns round an open well,
##   three windows out through the face) -> the Ward Landing on the crag's top (25.2).
## Modelled in Blender: tools/blender/rift_kit.py (+ rift_lib.py) -> art/models/rift_way.glb (one mesh per section and set, a `-colonly`
## body each, in the rift's own coordinates) and art/models/rift_way_layout.json (lanes, flights, sites, fires, the lavafall's source).
## Materials are the Realm's own: the masonry in WestKit's "stone" (Hearthward's gate and cottages) and "hewn" (the modelled masonry and
## the beacons' dressed stone), the basalt in RockKit's
## "basalt" and "ash" (the rift's rim, the Realm's cliffs), untinted. Walk surfaces: risers 0.33 m, 3.6 m between parapets.

const HW := 1.8                 ## half the clear walk (3.6 m between parapets)
const WestKit := preload("res://core/world/realm/west_marches_kit.gd")
const RockKitS := preload("res://core/world/realm/rock_kit.gd")
const MODEL := "rift_way.glb"
const LAYOUT := "res://art/models/rift_way_layout.json"

var lane: Array[Vector2] = []                        ## the walked centreline (xz): the Lip down the Descent and over the Cinder Way to the climb's foot
var lane_turn: Array[Vector2] = []                   ## ... the Ward Stair
var lanes2: Array[Vector2] = []                      ## ... across the ward landing to the summit's stairs
var lane_chapel: Array[Vector2] = []                 ## the branch from the Foot to the Pilgrims' Chapel
var legs: Array[String] = []                         ## printed summary
var fires: Array = []                                ## [{p, lit, big, tag}]
var sources: Array = []                              ## [[top, out]] the lavafalls out of the crag (rift coordinates)
var points := {}                                     ## named spots (rift coordinates): lip, foot, camp, f, door, well, ward
var layout: Dictionary = {}
var node: Node3D


func build(_root: Node, host: Node3D) -> void:
	layout = read_layout()
	_place(host)
	_register()
	_commit_fires(host)
	_vent(host)
	print("SITES Crossing owns %d scatter nodes" % WorldLanes.own(host))    # its fire posts carry the way: the cull must not thin them
	for s in legs:
		print("RIFT ", s)


static func read_layout() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if d is Dictionary:
		return d
	push_warning("crossing: no layout at %s" % LAYOUT)
	return {}


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _v2s(a: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Array in a:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


## Rift coordinates of a named spot in the layout (Vector3.INF when it has none by that name).
static func point(key: String) -> Vector3:
	var d := read_layout()
	if d.has("points") and (d.points as Dictionary).has(key):
		return _v3(d.points[key])
	return Vector3.INF


## The walked line of one of the layout's lanes (rift coordinates, xz).
static func lane_pts(key: String) -> Array[Vector2]:
	return _v2s((read_layout().get("lanes", {}) as Dictionary).get(key, []))


## The modelled way: the masonry dressed by WestKit.place (its sets), the basalt in RockKit's, the coals glowing; every body on the
## world layer; the big meshes cut in 24 m cells with LODs (the far half culls).
func _place(host: Node3D) -> void:
	node = WestKit.place(host, MODEL, Transform3D.IDENTITY, {})
	if node == null:
		push_warning("crossing: no model")
		return
	node.name = "CinderWay"
	for b in node.find_children("*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = Layers.WORLD
		(b as StaticBody3D).collision_mask = 0
	var chunk: Array[MeshInstance3D] = []
	var tris := 0
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.contains("-colonly") or mi.mesh == null:
			continue
		var set_name := nm.get_slice("__", 1).get_slice(".", 0) if nm.contains("__") else ""
		if set_name == "basalt" or set_name == "ash":           # (exactly: "__ashlar" once matched "__ash" and the flags wore the ember rock)
			mi.material_override = RockKitS.material(set_name)
		elif set_name == "ember":
			mi.material_override = coal_mat()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		elif set_name == "fall":
			mi.material_override = _fall_mat()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 4.0
			continue
		for si in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(si) / 3
		chunk.append(mi)
	for mi in chunk:
		if MeshChunks.split(mi) > 0:
			mi.visible = false
	legs.append("model: %d meshes (%d triangles) cut into chunks, %d fires" % [chunk.size(), tris, (layout.get("fires", []) as Array).size()])


static var _coal: StandardMaterial3D


## The lavafall out of the Ward Crag's cleft: LavaWorks' fall shader (a slow crawl in the channel from the vent, a rush with rafts of crust
## once it pours over the lip), told the sheet's lengths by the layout.
func _fall_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = LavaWorks.FALL_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var lf: Dictionary = layout.get("lavafall", {})
	m.set_shader_parameter("lip", float(lf.get("lip_m", 2.5)))
	m.set_shader_parameter("total", float(lf.get("total_m", 40.0)))
	return m


## The vent at the head of the lavafall: embers and a smoke column (no light: the lava's own glow lights stand by the fall).
func _vent(host: Node3D) -> void:
	var lf: Dictionary = layout.get("lavafall", {})
	if lf.is_empty():
		return
	var at := _v3(lf["vent"])
	var spit := Vfx.emitter(Color(1.8, 0.6, 0.12), {"count": 26, "life": 2.0, "speed": Vector2(0.6, 2.2), "size": 0.06, "gravity": -0.8, "radius": 0.8, "spread": 25.0, "turbulence": true})
	if spit:
		spit.name = "VentEmbers"
		host.add_child(spit)
		spit.global_position = at + Vector3.UP * 0.2
		spit.emitting = true
	var smoke := Vfx.emitter(Color(0.16, 0.13, 0.13, 0.35), {"count": 12, "life": 7.0, "speed": Vector2(0.6, 1.2), "size": 2.6, "gravity": 0.25, "radius": 0.8, "spread": 10.0, "additive": false, "turbulence": true, "damping": 0.2, "grow": 0.5})
	if smoke:
		smoke.name = "VentSmoke"
		smoke.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 18, 12))
		smoke.preprocess = 6.0
		host.add_child(smoke)
		smoke.global_position = at + Vector3.UP * 0.4
		smoke.emitting = true
	_splash(host, _v3(lf["foot"]))


## The lavafall's splash pool: where the sheet lands it throws glowing droplets up and falls back, a hot veil hangs over the churn
## (the boil is realm_rift.gd's, the light LavaWorks' first glow), and the fumes rise off it.
func _splash(host: Node3D, foot: Vector3) -> void:
	var at := Vector3(foot.x, -15.3, foot.z + 0.8)
	var drops := Vfx.emitter(Color(2.2, 0.8, 0.2), {"count": 64, "life": 1.1, "speed": Vector2(2.5, 6.0), "size": 0.1, "gravity": -9.0, "radius": 2.2, "spread": 35.0, "damping": 0.2})
	if drops:
		drops.name = "FallSplash"
		host.add_child(drops)
		drops.global_position = at
		drops.emitting = true
	var veil := Vfx.emitter(Color(1.5, 0.45, 0.1, 0.35), {"count": 18, "life": 1.6, "speed": Vector2(0.5, 1.5), "size": 1.4, "gravity": 0.6, "radius": 2.2, "spread": 30.0, "grow": 1.2})
	if veil:
		veil.name = "FallVeil"
		host.add_child(veil)
		veil.global_position = at + Vector3.UP * 0.4
		veil.emitting = true
	var fume := Vfx.emitter(Color(0.17, 0.13, 0.12, 0.35), {"count": 10, "life": 6.0, "speed": Vector2(0.8, 1.6), "size": 2.8, "gravity": 0.3, "radius": 1.8, "spread": 14.0, "additive": false, "turbulence": true, "damping": 0.2, "grow": 0.5})
	if fume:
		fume.name = "FallFume"
		fume.visibility_aabb = AABB(Vector3(-7, -1, -7), Vector3(14, 20, 14))
		fume.preprocess = 4.0
		host.add_child(fume)
		fume.global_position = at + Vector3.UP * 0.8
		fume.emitting = true


## The fire baskets' coals (the flames over them are particles): a banked glow.
static func coal_mat() -> StandardMaterial3D:
	if _coal == null:
		_coal = StandardMaterial3D.new()
		_coal.albedo_color = Color(0.2, 0.06, 0.03)
		_coal.emission_enabled = true
		_coal.emission = Color(1.0, 0.36, 0.08)
		_coal.emission_energy_multiplier = 2.2
	return _coal


## The sites, flights and lanes WorldLanes keeps flora and props off (the Threshold, the features and the trail read them too).
func _register() -> void:
	for s: Dictionary in layout.get("sites", []):
		var r: Array = s["rect"]
		var y := float(s["y"])
		WorldLanes.register_site(String(s["name"]), Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), y, y - 0.3, bool(s.get("hard", false)))
	for f: Dictionary in layout.get("flights", []):
		WorldLanes.register_flight(String(f["name"]), _v3(f["a"]), _v3(f["b"]), float(f["hw"]))
		legs.append("flight %s: %.1f m, rise %.2f" % [f["name"], Vector2(f["a"][0] - f["b"][0], f["a"][2] - f["b"][2]).length(), float(f["b"][1]) - float(f["a"][1])])
	var lanes: Dictionary = layout.get("lanes", {})
	lane = _v2s(lanes.get("rift_crossing", [[0.0, -3.0], [0.0, -8.0]]))
	lane_turn = _v2s(lanes.get("rift_crossing_turn", []))
	lanes2 = _v2s(lanes.get("rift_crossing_top", []))
	lane_chapel = _v2s(lanes.get("rift_crossing_chapel", []))
	fires = layout.get("fires", [])
	for s: Dictionary in layout.get("sources", []):
		sources.append([_v3(s["top"]), _v3(s["out"])])
	for k: String in (layout.get("points", {}) as Dictionary):
		points[k] = _v3(layout["points"][k])


## The fires on the way: a flame in every basket, a warm unshadowed light at the lit ones: from the Lip the fires climb the dark crag.
func _commit_fires(host: Node3D) -> void:
	var lit := 0
	for f: Dictionary in fires:
		var p := _v3(f["p"])
		var big := bool(f.get("big", false))
		var flame := Vfx.emitter(Color(1.9, 0.75, 0.22), {"count": 56 if big else 30, "life": 0.95 if big else 0.8, "speed": Vector2(0.4, 1.2) if big else Vector2(0.3, 0.9), "size": 0.38 if big else 0.24, "gravity": 2.4, "radius": 0.24 if big else 0.16, "spread": 14.0, "grow": 1.0})
		if flame:
			flame.name = "Flame"
			host.add_child(flame)
			flame.global_position = p
			flame.emitting = true
		if bool(f.get("lit", false)):
			var l := OmniLight3D.new()
			l.name = "FireLight"
			l.light_color = Color(1.0, 0.6, 0.3)
			l.light_energy = 2.4 if big else 1.6
			l.omni_range = 12.0 if big else 9.0
			l.shadow_enabled = false
			l.set_meta("light_class", "prop")
			host.add_child(l)
			l.global_position = p + Vector3.UP * 0.5
			lit += 1
	legs.append("fires %d (%d lit)" % [fires.size(), lit])
