extends RefCounted
## THE CROSSING (RealmRift): the only walkable way from the rift's south rim (RealmLayout.CROSSING_FOOT) up to the summit ward
## (RealmLayout.SUMMIT_WARD), as the ruin of the pilgrims' viaduct, redesigned (21 Nov: Luke, "the stairway area is so badly designed,
## it makes no sense", "with the lava", "it needs a complete redesign"). One legible route (the plan is crossing_redesign.md in the docs' round-39 folder):
##   forecourt and its gate on the rim -> the Causeway, a three-bay stair-viaduct over the starwater rising 5 m, straight at the
##   Pilgrims' Gate (T3, the junction: the Pilgrims' Stair goes down its east side, rift/tower_stair.gd) -> a flight north into the Spindle
##   Gate -> one helix of 49 steps round the basalt Spindle with three rest landings, fires and benches (the way in passes under the way
##   out, through the Gate) -> the Gate's roof -> a two-bay bridge over the lava on a pier in the flow -> the ward landing.
## Every stone is modelled: tools/blender/crossing_kit.py (+ crossing_lib/deck/towers/spindle.py) -> art/models/crossing.glb (one mesh per
## section and set, a `-colonly` body each, in the Crossing's own coordinates) and art/models/crossing_layout.json (the lanes, flights,
## sites and fires the game reads). The Spindle's basalt stack is built here (rift/basalt.gd), with its collision cylinder.
## Walk surfaces: rise <= Metrics.STEP_MAX, clear width >= 3.5 m, parapets level or stepped. Collision: decks and flights (ramps through the
## tread middles), parapets, piers (their feet reach the lava line, so LavaWorks' bank mask sees them) and the Spindle (a cylinder).

const HW := 2.2                 ## half walk width (deck 4.4 m, 3.5 m between parapets)
const BED := -17.5              ## pier feet, sunk in the lava
const LAVA := -15.5
const Starlit := preload("res://core/world/realm/rift/starlit_stone.gd")
const WestKit := preload("res://core/world/realm/west_marches_kit.gd")
const Basalt := preload("res://core/world/realm/rift/basalt.gd")
const MODEL := "crossing.glb"
const LAYOUT := "res://art/models/crossing_layout.json"

const SPIN_C := Vector2(-8.3, -50.0)                 ## the Spindle (basalt stack) the stair turns round
const SPIN_R := 6.5                                  ## centreline radius of the turn
const SPIN_CORE := 4.1                               ## the stack's radius (collision cylinder)

var rng := RandomNumberGenerator.new()
var lane: Array[Vector2] = []                        ## the walked centreline (xz): the forecourt to the Pilgrims' Gate
var lane_turn: Array[Vector2] = []                   ## ... round the Spindle
var lanes2: Array[Vector2] = []                      ## ... and the bridge onto the ward landing
var legs: Array[String] = []                         ## printed summary
var fires: Array = []                                ## [{p, lit, big, tag}]
var layout: Dictionary = {}
var node: Node3D


func build(_root: Node, host: Node3D) -> void:
	rng.seed = 51
	Starlit.ensure()
	layout = _read_layout()
	_place(host)
	_register()
	_spindle(host)
	_commit_fires(host)
	_underglow(host)
	print("SITES Crossing owns %d scatter nodes" % WorldLanes.own(host))    # its fire posts carry the way: the cull must not thin them
	for s in legs:
		print("RIFT ", s)


func _read_layout() -> Dictionary:
	var txt := FileAccess.get_file_as_string(LAYOUT)
	var d: Variant = JSON.parse_string(txt)
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


## The modelled Crossing in the rift's own stone: the sets dressed with the rift's tint and starlight (starlit_stone.gd), every body on the
## world layer, the big meshes cut in 24 m cells with LODs (the far half culls).
func _place(host: Node3D) -> void:
	node = WestKit.place(host, MODEL, Transform3D.IDENTITY, {})
	if node == null:
		push_warning("crossing: no model")
		return
	node.name = "CrossingModel"
	for b in node.find_children("*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = Layers.WORLD
		(b as StaticBody3D).collision_mask = 0
	var hewn := _mat("hewn", Color(1.28, 1.25, 1.3), 0.17)
	var slate := _mat("slate", Color(1.24, 1.21, 1.27), 0.14)
	var core := _mat("stone", Color(0.8, 0.78, 0.82), 0.04)
	var chunk: Array[MeshInstance3D] = []
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.contains("-colonly"):
			continue
		if nm.contains("__hewn"):
			mi.material_override = hewn
			chunk.append(mi)
		elif nm.contains("__slate"):
			mi.material_override = slate
			chunk.append(mi)
		elif nm.contains("__stone"):
			mi.material_override = core
		elif nm.contains("__rune"):
			mi.material_override = _glow_mat(Color(0.6, 0.45, 1.0), 2.4)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nm.contains("__ember"):
			mi.material_override = _glow_mat(Color(1.0, 0.45, 0.12), 3.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in chunk:
		if MeshChunks.split(mi) > 0:
			mi.visible = false
	legs.append("model: %d meshes cut into chunks, %d fires" % [chunk.size(), (layout.get("fires", []) as Array).size()])


func _mat(set_name: String, tint: Color, glow: float) -> StandardMaterial3D:
	var m := (WestKit.mat(set_name) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = tint
	m.normal_scale = 0.5
	m.emission_enabled = true
	m.emission = Color(0.3, 0.3, 0.44)       # cold starlight, not violet (the pool lights and the pillars' lanterns carry the violet)
	m.emission_energy_multiplier = glow
	m.emission_texture = m.albedo_texture
	return m


static func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## The sites, flights and lanes WorldLanes keeps flora and props off (and the Threshold's terraces and the rift's features read).
func _register() -> void:
	for s: Dictionary in layout.get("sites", []):
		var r: Array = s["rect"]
		var y := float(s["y"])
		WorldLanes.register_site(String(s["name"]), Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), y, y - 0.3, bool(s.get("hard", s["name"] == "rift_ward_landing")))
	for f: Dictionary in layout.get("flights", []):
		WorldLanes.register_flight(String(f["name"]), _v3(f["a"]), _v3(f["b"]), float(f["hw"]))
		legs.append("flight %s: %.1f m rise %.2f" % [f["name"], Vector2(f["a"][0] - f["b"][0], f["a"][2] - f["b"][2]).length(), float(f["b"][1]) - float(f["a"][1])])
	var lanes: Dictionary = layout.get("lanes", {})
	lane = _v2s(lanes.get("rift_crossing", [[0.0, -7.0], [0.0, -14.0], [-1.8, -40.0]]))
	lane_turn = _v2s(lanes.get("rift_crossing_turn", []))
	lanes2 = _v2s(lanes.get("rift_crossing_top", []))
	fires = layout.get("fires", [])


## The Spindle: a hex basalt stack taller than the stair, collision a cylinder (the stair's inner edge is 0.2 m off it: no one gets between).
func _spindle(host: Node3D) -> void:
	var st := Basalt.new_tool()
	var top_at := func(d: float) -> float: return lerpf(29.5, 23.6, d * d) + rng.randf_range(-0.6, 2.2) + (rng.randf_range(-6.0, -2.0) if d < 0.5 and rng.randf() < 0.2 else 0.0)
	var cols := Basalt.bundle(st, rng, Vector3(SPIN_C.x, BED - 0.5, SPIN_C.y), SPIN_CORE - 0.3, 0.5, top_at, 0.6)
	for i in 3:                                          # a few spires breaking the skyline
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.5, 2.2)
		Basalt.column(st, rng, Vector3(SPIN_C.x + cos(a) * d, 24.0, SPIN_C.y + sin(a) * d), 0.5, rng.randf_range(31.0, 34.0))
	var sp := Basalt.commit(st, host, "Spindle", "basalt", false)
	if sp:
		MeshChunks.split(sp)
		sp.queue_free()
	var body := StaticBody3D.new()
	body.name = "SpindleBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = SPIN_CORE
	cyl.height = 30.0 - BED
	cs.shape = cyl
	cs.position = Vector3(SPIN_C.x, (30.0 + BED) * 0.5, SPIN_C.y)
	body.add_child(cs)
	host.add_child(body)
	legs.append("spindle: %d basalt columns, core r %.1f" % [cols, SPIN_CORE])


## The fires on the way: a flame at every basket, a warm unshadowed light at the lit ones (the Spindle's, the Gate's, the ward's: the
## column of fires that climbs from the rim to the ward landing).
func _commit_fires(host: Node3D) -> void:
	var lit := 0
	for f: Dictionary in fires:
		var p := _v3(f["p"])
		var big := bool(f.get("big", false))
		var flame := Vfx.emitter(Color(1.9, 0.75, 0.22), {"count": 40 if big else 26, "life": 0.85 if big else 0.75, "speed": Vector2(0.4, 1.2) if big else Vector2(0.3, 0.9), "size": 0.3 if big else 0.2, "gravity": 2.4, "radius": 0.2 if big else 0.14, "spread": 14.0, "grow": 1.0})
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


## The lava's light on the underside of the climb: four soft warm unshadowed lights low in the chasm, so the piers, the helix's soffit, the bridge's arches
## and the ward landing's foot glow red from below (the crossing stands over the flow from the Spindle on).
const UNDERGLOW := [Vector3(-13.0, -11.0, -53.0), Vector3(-4.0, -11.0, -58.0), Vector3(2.0, -11.0, -48.0), Vector3(0.0, -11.0, -67.0)]


func _underglow(host: Node3D) -> void:
	for at: Vector3 in UNDERGLOW:
		var l := OmniLight3D.new()
		l.name = "LavaGlow"
		l.light_color = Color(1.0, 0.4, 0.12)
		l.light_energy = 1.3
		l.omni_range = 14.0
		l.shadow_enabled = false
		l.set_meta("light_class", "realm")
		host.add_child(l)
		l.global_position = at
	legs.append("underglow lights %d" % UNDERGLOW.size())
