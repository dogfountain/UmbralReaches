extends RefCounted
## THE PILGRIMS' CHAPEL (Threshold, core/world/realm/rift/threshold.gd places it): a small stone chapel built against
## the foot of the rift's west wall where the starfall pours (RealmRift.STARFALLS, z -37). Lore: the pilgrims who went
## down to the starwater cut a chapel where the light falls, and left their offerings in it; the Order never counted
## it among its own. The fall pours over its roof and across its doorway like a curtain (LavaWorks drapes the sheet
## over whatever collision it finds, so the facade carries it); you walk down the west terraces to the lowest walk
## (y -12), cross a jetty along the chapel's side to the forecourt and step through the falling light.
## Inside: a pointed vault on ribs, six niches with carved pilgrims and candle stubs, the kneeling stone with the page
## cut into it and the pilgrims' reliquary (the secret: core/life/secrets/site_threshold.gd, which reads `ChapelMarker`).
## Model: tools/blender/wonder_threshold_chapel.py -> art/models/threshold_chapel.glb (origin: the doorway's threshold,
## +Y into the chapel, which the placement turns to face west). Collision: the model's own -colonly boxes.

const R37Kit := preload("res://core/world/realm/r37_west_kit.gd")
const ORIGIN := Vector3(-14.4, -12.0, -36.85)      ## the doorway's threshold on the lowest walk (the facade's face)
const NICHES := [1.9, 3.15, 4.4]                   ## where the six niches stand along the side walls (model y)
const INNER := 1.2

var t
var node: Node3D


## Model point (Blender frame: x across, y into the chapel, z up) to world.
static func to_world(p: Vector3) -> Vector3:
	return ORIGIN + Vector3(-p.y, p.z, -p.x)


static func basis() -> Basis:
	return Basis(Vector3.UP, PI * 0.5)


func build(p_threshold, host: Node3D) -> bool:
	t = p_threshold
	# nothing may touch it but the rock it is keyed into and the water it stands in
	var checks := [["chapel", Vector3(0.0, 4.1, 0.4), Vector3(4.3, 8.9, 10.4)], ["forecourt", Vector3(-1.2, -1.3, 0.4), Vector3(6.7, 2.6, 1.6)],
		["jetty", Vector3(-3.25, 2.15, 0.4), Vector3(2.6, 4.3, 1.6)]]
	var ok := true
	for c: Array in checks:
		var wc := to_world(c[1])
		var sz: Vector3 = c[2]
		if not t._clear(Transform3D(Basis.IDENTITY, wc), Vector3(sz.y, sz.z, sz.x), 0.0, true):
			t._audit.append("chapel %s touches %s" % [c[0], t._last_hit])
			ok = false
	# "Starwater": the runtime spawners (glimmers) never put a pickup on anything under a node whose name has "water"
	var root := Node3D.new()
	root.name = "StarwaterChapel"
	host.add_child(root)
	node = R37Kit.place(root, "threshold_chapel.glb", Transform3D(basis(), ORIGIN), {"range_end": 260.0})
	if node == null:
		return false
	var stone := _mat("stone", Color(1.12, 1.08, 1.24), 0.16)
	var ashlar := _mat("ashlar", Color(1.06, 1.02, 1.16), 0.14)
	for b in node.find_children("*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = Layers.WORLD
		(b as StaticBody3D).collision_mask = 0
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.contains("__rune"):
			mi.material_override = t._rune_mat()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif nm.contains("__stone"):
			mi.material_override = stone
		elif nm.contains("__ashlar"):
			mi.material_override = ashlar
	_dress(host)
	return ok


func _mat(set_name: String, tint: Color, glow: float) -> StandardMaterial3D:
	var m := (R37Kit.mat(set_name) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = Color(0.34, 0.26, 0.62)
	m.emission_energy_multiplier = glow
	m.emission_texture = m.albedo_texture
	return m


## Candles on the sills and before the kneeling stone, one warm light, the marker the secret reads.
func _dress(host: Node3D) -> void:
	var k: OssKit = t.k
	var rng: RandomNumberGenerator = t.rng
	for sx: float in [-1.0, 1.0]:
		for cy: float in NICHES:
			k.candle_cluster(to_world(Vector3(sx * (INNER - 0.04), cy + 0.2, 0.95)), rng.randi_range(2, 4), 0.1, rng)
	k.candle_cluster(to_world(Vector3(-0.9, 4.45, 0.0)), 6, 0.3, rng)
	k.candle_cluster(to_world(Vector3(0.95, 4.2, 0.0)), 5, 0.28, rng)
	k.candle_cluster(to_world(Vector3(-0.55, 1.35, 0.0)), 4, 0.25, rng)
	var l := OmniLight3D.new()
	l.name = "ChapelLight"
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 2.2
	l.omni_range = 7.5
	l.omni_attenuation = 1.1
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 60.0
	l.distance_fade_length = 15.0
	l.set_meta(&"light_class", &"realm")
	host.add_child(l)
	l.global_position = to_world(Vector3(0.0, 3.0, 2.5))
	var mark := Node3D.new()
	mark.name = "ChapelMarker"
	mark.set_meta("floor", to_world(Vector3(0.0, 3.0, 0.0)))
	mark.set_meta("basis", basis())
	mark.set_meta("chest_at", to_world(Vector3(0.95, 4.45, 0.0)))
	mark.set_meta("stone_at", to_world(Vector3(0.0, 4.7, 1.2)))
	mark.set_meta("door", to_world(Vector3(0.0, 0.0, 0.0)))
	host.add_child(mark)
	mark.global_position = to_world(Vector3(0.0, 3.0, 0.0))
