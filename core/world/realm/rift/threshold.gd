extends RefCounted
## THE PILGRIMS' THRESHOLD (RealmRift), from scratch (21 Nov): where the pilgrims came down off the rim onto the crust, before the
## fire. The Cinder Way's Descent ends at the Foot (rift/crossing.gd); from there:
##   - the Pilgrims' Chapel (rift/chapel.gd): cut into the west wall at the Foot, the last cool stone before the crossing; a branch of
##     the way leads to its door (a secret: core/life/secrets/site_threshold.gd)
##   - the Watchers: two great lantern pillars carved in stone (art/models/wonders/watchers_*.glb, about 30 m, the east one mirrored),
##     each on a basalt table in the lava (rift_rocks.glb "Plinth"), flanking the Cinder Way's middle and facing the village: a sunk
##     spiral stair up the shaft, a band of Order glyphs, festoons of chain, a forged iron lantern burning violet
## Collision: the Watchers' hulls, their plinths, the chapel's walls and floor.

const Chapel := preload("res://core/world/realm/rift/chapel.gd")
const Kit := preload("res://core/world/realm/west_marches_kit.gd")
const RockKitS := preload("res://core/world/realm/rock_kit.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const ROCKS := "res://art/models/rift_rocks.glb"
const LAVA := -15.5
## The Watchers' feet: the plinths' tops (LAVA + PLINTH_TOP) carry them. West at the molten pool's edge, east in the crust; the Cinder
## Way passes between (rift_from_scratch.md in the docs' round-39 folder).
const WATCHERS := [Vector3(-2.5, LAVA, -42.5), Vector3(16.0, LAVA, -24.0)]
const PLINTH_TOP := 1.3                ## rift_rocks.py: the plinth's flat top over the lava
const WATCHER_R := 7.4                 ## the plinth's reach

var k: OssKit
var space: PhysicsDirectSpaceState3D
var rng := RandomNumberGenerator.new()
var report: Array[String] = []
var _audit: Array[String] = []         ## every piece that touched something it should not (printed)
var _last_hit := ""                    ## what the last failed _clear touched


func build(root: Node, host: Node3D) -> void:
	rng.seed = 2611
	space = (root as Node3D).get_world_3d().direct_space_state
	k = OssKit.new()
	k.keep_lanes = false
	k.candle_lights = false             # the wax glows; no new lights
	_watchers(host)
	await root.get_tree().physics_frame            # the Watchers' bodies are in the space first
	_audit_watchers(host)
	_watcher_candles(host)
	var chapel_ok := _chapel(host)
	k.commit(host, "ThresholdBody")
	print("SITES Threshold owns %d scatter nodes" % WorldLanes.own(host))   # placed on purpose (the pillars' candles stand inside their sites)
	if not chapel_ok:
		PlacementLog.skip("threshold", "chapel", Chapel.ORIGIN, "touches something")
	report.append("chapel: %s" % ("built" if chapel_ok else "built, but touches something"))
	report.append("clearance: %s" % ("nothing touched" if _audit.is_empty() else "; ".join(_audit)))
	for s in report:
		print("THRESHOLD ", s)
	await root.get_tree().physics_frame          # the collision exists before LavaWorks maps the banks


# --- the Pilgrims' Chapel ---------------------------------------------------------------------------

## The chapel (chapel.gd), cut into the west wall at the Foot; the Cinder Way's branch reaches its forecourt.
func _chapel(host: Node3D) -> bool:
	if "--no-chapel" in OS.get_cmdline_user_args():
		return false                       # (a measuring switch: the Threshold without the chapel)
	return Chapel.new().build(self, host)


# --- the Watchers ---------------------------------------------------------------------------------

## Two great lantern pillars carved in stone (tools/blender/wonder_watchers.py: art/models/wonders/watchers_*.glb), each on its basalt
## table in the lava, facing the village. Near mesh with baked maps, a far mesh from 160 m, convex hulls for collision. One unshadowed orb
## light each.
func _watchers(host: Node3D) -> void:
	if OS.get_cmdline_user_args().has("--no-watchers"):      # measurement only: the Threshold without them
		return
	var plinth := _plinth_parts()
	for w: Vector3 in WATCHERS:
		var west := w.x < 0.0
		var tag := "West" if west else "East"
		if not plinth.is_empty():
			var mi := MeshInstance3D.new()
			mi.name = "WatcherPlinth" + tag
			mi.mesh = plinth[0]
			mi.material_override = RockKitS.material(String(plinth[1]))
			host.add_child(mi)
			mi.global_transform = Transform3D(Basis(Vector3.UP, 0.4 if west else -0.7), w)
			var body := StaticBody3D.new()
			body.name = "WatcherPlinth%sBody" % tag
			body.collision_layer = Layers.WORLD
			body.collision_mask = 0
			for s: Array in plinth[2]:
				var cs := CollisionShape3D.new()
				cs.shape = s[0]
				cs.transform = s[1]
				body.add_child(cs)
			host.add_child(body)
			body.global_transform = mi.global_transform
		var m := Kit.place(host, "wonders/watchers_%s.glb" % ("west" if west else "east"), Transform3D(Basis(Vector3.UP, PI + (0.22 if west else -0.22)), w + Vector3.UP * PLINTH_TOP))
		if m == null:
			continue
		m.name = "Watcher" + tag
		# the plinth's footprint is a site: the flora and the dress keep off it
		WorldLanes.register_site("watcher_%s" % tag.to_lower(), Rect2(w.x - 6.6, w.z - 6.6, 13.2, 13.2), w.y + PLINTH_TOP)
		_dress_watcher(m)
		var core := m.find_child("Pillar_core*", true, false) as MeshInstance3D
		var oc := Vector3(0.0, 27.0, 0.0)
		if core:
			oc = core.get_aabb().get_center()
		var ol := OmniLight3D.new()
		ol.name = "OrbLight"
		ol.position = oc
		ol.light_color = Color(0.6, 0.45, 1.0)
		ol.light_energy = 2.2
		ol.omni_range = 26.0
		ol.shadow_enabled = false
		ol.distance_fade_enabled = true
		ol.distance_fade_begin = 120.0
		ol.distance_fade_length = 25.0
		ol.set_meta(&"light_class", &"realm")
		m.add_child(ol)
		# the far mesh from 160 m out to the horizon; the near model fades out where it takes over
		var far_ps := Kit.scene("wonders/watchers_%s_far.glb" % ("west" if west else "east"))
		if far_ps:
			var far_root := far_ps.instantiate() as Node3D
			for mi2 in far_root.find_children("*", "MeshInstance3D", true, false):
				var fm := mi2 as MeshInstance3D
				if fm.mesh != null:
					FarDetail.register(m, fm.mesh, Transform3D.IDENTITY, 160.0, _orb_mat() if String(fm.name).contains("orb") else _far_stone_mat(), false)
			far_root.free()
		FarDetail.near_ends(m, 160.0, 30.0)


## The plinth's mesh, style and collision shapes from rift_rocks.glb ([] when it is missing).
static func _plinth_parts() -> Array:
	var ps := load(ROCKS) as PackedScene
	if ps == null:
		return []
	var inst := ps.instantiate()
	var out: Array = []
	for n in inst.find_children("Plinth__*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var shapes: Array = []
		var body := inst.find_child("Plinth", true, false)
		if body != null:
			for cs in body.find_children("*", "CollisionShape3D", true, false):
				shapes.append([(cs as CollisionShape3D).shape, (cs as Node3D).transform])
		out = [mi.mesh, String(mi.name).get_slice("__", 1).get_slice(".", 0), shapes]
		break
	inst.free()
	return out


static var _watcher_mats: Dictionary = {}


## The baked column maps (with the glyph grooves' faint ember as the emission map); the staff, chains and cage in the iron
## set over their rust vertex colours; the flame in layers (a hot core, a violet halo, a smoked cracked glass shell).
func _dress_watcher(m: Node3D) -> void:
	if _watcher_mats.is_empty():
		var T := "res://art/textures/"
		var W := "res://art/models/wonders/"
		var fig := StandardMaterial3D.new()
		fig.albedo_texture = load(W + "watchers_pillar_albedo.png")
		fig.albedo_color = Color(0.6, 0.58, 0.64)
		fig.normal_enabled = true
		fig.normal_texture = load(W + "watchers_pillar_normal.png")
		var orm: Texture2D = load(W + "watchers_pillar_orm.png")
		fig.ao_enabled = true
		fig.ao_texture = orm
		fig.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		fig.roughness_texture = orm
		fig.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		fig.roughness = 1.0
		fig.emission_enabled = true
		fig.emission_texture = load(W + "watchers_pillar_emit.png")
		fig.emission = Color.WHITE
		fig.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY       # the texture alone (ADD would add white everywhere)
		fig.emission_energy_multiplier = 1.0
		_watcher_mats["fig"] = fig
		var s := StandardMaterial3D.new()
		s.vertex_color_use_as_albedo = true
		s.normal_enabled = true
		s.normal_texture = load(T + "r37_stone_normal.png")
		s.normal_scale = 0.8
		var so: Texture2D = load(T + "r37_stone_orm.png")
		s.roughness_texture = so
		s.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		s.roughness = 1.0
		_watcher_mats["stone"] = s
		_watcher_mats["iron"] = Kit.mat("iron")
		var halo := _orb_mat()
		halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo.albedo_color = Color(0.5, 0.3, 1.0, 0.55)
		halo.emission_energy_multiplier = 2.6
		_watcher_mats["orb"] = halo
		var core := StandardMaterial3D.new()
		core.albedo_color = Color(0.95, 0.9, 1.0)
		core.emission_enabled = true
		core.emission = Color(0.92, 0.85, 1.0)
		core.emission_energy_multiplier = 6.0
		_watcher_mats["core"] = core
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.1, 0.08, 0.14, 0.42)
		glass.roughness = 0.12
		glass.metallic_specular = 0.9
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_watcher_mats["glass"] = glass
	var key := {"Pillar_fig": "fig", "Pillar_iron": "iron", "Pillar_rubble": "stone", "Pillar_orb": "orb",
			"Pillar_core": "core", "Pillar_glass": "glass"}
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.begins_with("Pillar_cand") or nm.begins_with("Pillar_flame"):
			mi.queue_free()             # the model's stub candles: the kit's dripping wax and layered flames stand in (_watcher_candles)
			continue
		for kk: String in key:
			if nm.begins_with(kk):
				mi.material_override = _watcher_mats[key[kk]]
				if key[kk] in ["orb", "core", "glass"]:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				break


## Pilgrims' candles on the pillars' lower tread, in the kit's wax. The plinth (tools/blender/wonder_watchers.py PLINTH) has two square
## treads; the upper is under the moulded torus's overhang, so the candles keep to the lower, 0.7 m up and 0.48 m deep. Each cluster is
## seated by a ray on that tier's collision and dropped if it misses it.
const TREAD_Y := 0.7
const TREAD_MID := 3.2
func _watcher_candles(host: Node3D) -> void:
	var placed := 0
	var cr := RandomNumberGenerator.new()      # its own: what is built after keeps its exact draws
	cr.seed = 7717
	for w: Vector3 in WATCHERS:
		var m := host.get_node_or_null("Watcher%s" % ("West" if w.x < 0.0 else "East")) as Node3D
		if m == null:
			continue
		var xf := m.global_transform
		for side in 4:
			for t: float in [-2.6, -1.3, 0.0, 1.3, 2.6]:
				if cr.randf() < 0.35:
					continue
				var lp := Vector3(t + cr.randf_range(-0.3, 0.3), TREAD_Y, TREAD_MID + cr.randf_range(-0.06, 0.06)).rotated(Vector3.UP, side * PI * 0.5)
				var c := xf * lp
				var y0 := _tread_y(m, c + Vector3.UP * 0.5)
				if is_nan(y0) or absf(y0 - c.y) > 0.08:
					continue
				k.candle_cluster(Vector3(c.x, y0 + 0.01, c.z), cr.randi_range(3, 5), 0.14, cr)
				placed += 1
	report.append("pillar candles: %d clusters on the lower treads" % placed)


## The height of the pillar's own top surface under `c` (a ray down; NAN when it meets anything else first or a slope).
func _tread_y(m: Node3D, c: Vector3) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * 16.0, Layers.WORLD))
	if hit.is_empty() or not m.is_ancestor_of(hit.collider as Node) or (hit.normal as Vector3).y < 0.9:
		return NAN
	return (hit.position as Vector3).y


static func _far_stone_mat() -> StandardMaterial3D:
	var f := StandardMaterial3D.new()
	f.albedo_color = Color(0.32, 0.33, 0.37)
	f.roughness = 1.0
	return f


# --- clearance ---------------------------------------------------------------------------------------

## True when a box `size` at `xf` touches nothing built (the ground is allowed when `ground_ok`: the chapel keys into the rock); `grow`
## pads it all round.
func _clear(xf: Transform3D, size: Vector3, grow := 0.3, ground_ok := false) -> bool:
	var sh := BoxShape3D.new()
	sh.size = size + Vector3.ONE * grow * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = xf
	q.collision_mask = Layers.WORLD
	for hit: Dictionary in space.intersect_shape(q, 24):
		var c := hit.get("collider") as Node
		if ground_ok and c != null and String(c.name).begins_with("Terrain"):
			continue
		_last_hit = String(c.get_path()) if c else "?"
		return false
	return true


## Each Watcher's own convex hulls against the world: nothing may touch them but their basalt plinth.
func _audit_watchers(host: Node3D) -> void:
	for w in host.get_children():
		if not (w is Node3D) or w is Light3D or not String(w.name).begins_with("Watcher") or String(w.name).begins_with("WatcherPlinth"):
			continue
		var m := w as Node3D
		var own := {}
		for b in m.find_children("*", "CollisionObject3D", true, false):
			own[b] = true
		for b in m.find_children("*", "StaticBody3D", true, false):
			for cs in b.get_children():
				if not (cs is CollisionShape3D) or (cs as CollisionShape3D).shape == null:
					continue
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = (cs as CollisionShape3D).shape
				q.transform = (cs as CollisionShape3D).global_transform
				q.collision_mask = Layers.WORLD
				var touched := {}
				for hit: Dictionary in space.intersect_shape(q, 24):
					var c := hit.get("collider") as Node
					if c == null or own.has(c) or String(c.name).begins_with("WatcherPlinth"):
						continue
					touched[String(c.name)] = true
				if not touched.is_empty():
					_audit.append("%s %s touches %s" % [m.name, b.name, ", ".join(touched.keys())])


# --- light ---------------------------------------------------------------------------------------------

static func _orb_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.6, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.66, 0.52, 1.0)
	m.emission_energy_multiplier = 5.0
	return m


## The chapel's carved runes (its `__rune` parts): a faint violet in the grooves.
static func _rune_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.22, 0.7)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.4, 1.0)
	m.emission_energy_multiplier = 3.4
	m.roughness = 0.6
	return m
