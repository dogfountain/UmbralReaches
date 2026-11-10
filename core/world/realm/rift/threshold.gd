extends RefCounted
## THE PILGRIMS' THRESHOLD (RealmRift): the rift's south reach, from the forecourt to the Spindle,
## rebuilt as the place the pilgrims went down to the light (Luke, 9 Nov: "I don't think the lava place
## should be so close to the village", then "make it architectural, explore, make it magical").
## No lava here: the pool is starwater (lava.gdshader's star zone, set by LavaWorks from STAR_Z).
##   - terraces stepping down both walls to the pool, like river steps: vertical ashlar faces stood in
##     front of the rock's slope, flat walks between them, a balustrade on every edge, pilasters
##     carrying violet rune slits, a blind lancet arch on every bay, candle offerings on the walks;
##     left open where a starfall pours down its channel (RealmRift.STARFALLS)
##   - the Watchers: two great lantern pillars carved in stone (art/models/wonders/watchers_*.glb, about 30 m, the east
##     one mirrored) standing in the pool either side of the threshold's mouth, facing the village: a sunk spiral stair
##     up the shaft, a band of Order glyphs, festoons of chain, a forged iron lantern burning violet
##   - the Pilgrims' Chapel (rift/chapel.gd): a small chapel built against the west wall's foot at the starfall,
##     the fall pouring over its roof and across its doorway; the Pilgrims' Stair down the third tower and a quay reach it
##     (a secret: core/life/secrets/site_threshold.gd)
##   - motes rising off the pool
## The east wall above y -6 from z -22 north is the Ossuary's: there the terraces stop below it.
## Collision: the terraces (walkable, reachable down the rock's slope from the rim) and the chapel's walls, floor and pier.

const Starlit := preload("res://core/world/realm/rift/starlit_stone.gd")
const STONE := Starlit.STONE          ## the rift's stone: paler, with a little starlight in it
const Chapel := preload("res://core/world/realm/rift/chapel.gd")
const TowerStair := preload("res://core/world/realm/rift/tower_stair.gd")
const LAVA := -15.5
const TOPS := [-12.0, -8.0, -4.0]      ## each terrace's walk height; the lowest stands in the pool
const BAY := 4.0                       ## metres per terrace bay along the wall
const Z0 := -15.0                      ## the first bay's south edge (the forecourt's rocks are south of it)
## Pedestal feet, in the pool. z -15.6: the pedestal (r 6.7 m at this scale) ends short of the Ossuary's stone
## footings (z -22.5) and the figure well short of its south wall inside the east rock.
const WATCHERS := [Vector3(-13.8, -17.2, -15.6), Vector3(13.8, -17.2, -15.6)]
const WATCHER_LIFT := 1.3              ## the plinth stands this far over the pool's floor, so its lower tread and candles stand 0.3 m clear of the starwater
const WATCHER_R := 7.0                 ## the plinth's reach (a 7 x 7 m foot, about 5 m to its corners, and the rubble) and a little
const Kit := preload("res://core/world/realm/west_marches_kit.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")

var k: OssKit
var space: PhysicsDirectSpaceState3D
var star_z := -46.0
var falls: Array = []
var rng := RandomNumberGenerator.new()
var rune: SurfaceTool                  ## violet rune slits (one emissive mesh)
var report: Array[String] = []
var _skips := {}                       ## why a bay's tier was not built (printed)
var _cols: Array[AABB] = []            ## boxes of collision-less instanced pieces here (the crossing's colonnade)
var _audit: Array[String] = []         ## every piece that was moved or dropped for touching something (printed)
var _last_hit := ""                    ## what the last failed _clear touched
var _temp: Array[Node] = []            ## stand-in bodies for collision-less meshes, while the Threshold is placed
const PROBE_LAYER := 1 << 30           ## their physics layer (nothing else uses it; they are freed after)


func build(root: Node, host: Node3D, p_star_z: float, p_falls: Array) -> void:
	rng.seed = 2611
	star_z = p_star_z
	falls = p_falls
	space = (root as Node3D).get_world_3d().direct_space_state
	Starlit.ensure()
	k = OssKit.new()
	k.keep_lanes = false
	k.candle_lights = false             # the wax glows; no new lights (the pool and the violet glow light it)
	rune = SurfaceTool.new()
	rune.begin(Mesh.PRIMITIVE_TRIANGLES)
	_collect_instances(host.get_parent())
	_stand_ins(root, host)
	_watchers(host)
	await root.get_tree().physics_frame            # the stand-ins and the Watchers' bodies are in the space first
	_audit_watchers(host)
	_watcher_candles(host)
	var bays := 0
	for side: float in [-1.0, 1.0]:
		var z := Z0
		while z - BAY >= star_z + 1.0:
			bays += _bay(side, z - BAY * 0.5)
			z -= BAY
	var tstair := TowerStair.new()
	var stair_ok := tstair.build(self)
	report.append("tower stair: %d steps (%d narrowed, %d as spans past the fallen column's pier)" % [tstair.steps_built, tstair.narrow_steps, tstair.spans])
	var chapel_ok := _chapel(host)
	for b in _temp:
		b.queue_free()
	_temp.clear()
	k.commit(host, "ThresholdBody")
	# placed on purpose (the pillars' candles stand inside their sites): WorldLanes.cull_scatter keeps them
	print("SITES Threshold owns %d scatter nodes" % WorldLanes.own(host))
	var mi := MeshInstance3D.new()
	mi.name = "Runes"
	mi.mesh = rune.commit()
	mi.material_override = _rune_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	_motes(host)
	_pool_lights(host)
	if not chapel_ok:
		PlacementLog.skip("threshold", "chapel", Vector3(0, 0, Z0), "NOT BUILT")
	if not stair_ok:
		PlacementLog.skip("threshold", "tower_stair", Vector3(0, 0, Z0), "INCOMPLETE")
	report.append("terraces: %d bay tiers, chapel: %s, tower stair: %s, skipped %s" % [bays, "built" if chapel_ok else "NOT BUILT", "built" if stair_ok else "INCOMPLETE", str(_skips)])
	report.append("clearance: %s" % ("nothing touched" if _audit.is_empty() else "; ".join(_audit)))
	for s in report:
		print("THRESHOLD ", s)
	await root.get_tree().physics_frame          # the terraces' collision exists before LavaWorks maps the banks


# --- the terraces ----------------------------------------------------------------------------------

## Where the rock wall is at height y (x of the first terrain hit going out from the middle), or NAN.
## Looks past the crossing's towers and the basalt: only the ground counts.
func _wall_x(side: float, y: float, z: float) -> float:
	var from := Vector3(side * 6.0, y, z)
	for i in 6:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(side * 44.0, y, z), Layers.WORLD))
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).x
		from = (hit.position as Vector3) + Vector3(side * 0.2, 0.0, 0.0)
	return NAN


## True where a terrace may not stand: the crossing (its sites and lanes), the Spindle, a starfall's channel.
func _blocked(x: float, z: float, pad: float) -> bool:
	return _why(x, z, pad) != ""


func _why(x: float, z: float, pad: float) -> String:
	var p := Vector2(x, z)
	if p.distance_to(Vector2(-8.3, -50.0)) < 10.0 + pad:
		return "spindle"
	for w: Vector3 in WATCHERS:
		if p.distance_to(Vector2(w.x, w.z)) < WATCHER_R:
			return "watcher"                             # (the pedestal itself: the terraces may stand right behind it)
	for f: Array in falls:
		if absf(float(f[0]) - z) < 2.0 and signf(x) == signf(float(f[1])):
			return "fall"
	for s: Dictionary in WorldLanes.sites:
		if String(s.name).begins_with("rift_") and not is_nan(WorldLanes.site_floor(s, p, minf(pad, 0.3))):
			return String(s.name)                        # (a tower's own footprint: the terraces may stand close by)
	for l: Array in WorldLanes.extra_lanes:
		if not String(l[0]).begins_with("rift_crossing"):
			continue
		var pts: Array = l[1]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var ab: Vector2 = (pts[i + 1] as Vector2) - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < float(l[2]) + pad:
				return String(l[0])
	return ""


## One bay of terraces on one wall, centred on z: up to three tiers, each a block stood in front of the
## rock with its face at the rock's most forward point over the tier, a coping, a balustrade, pilasters
## with rune slits, a blind arch on the face and candles on the walk. Returns the tiers built.
func _bay(side: float, zc: float) -> int:
	var built := 0
	var walk_x := NAN                       # the walk this tier stands on (the tier below's top)
	for i in TOPS.size():
		var yb: float = LAVA - 1.0 if i == 0 else float(TOPS[i - 1])
		var yt: float = TOPS[i]
		if side > 0.0 and zc < -21.0 and yt > -7.0:
			break                               # the Ossuary is inside the east wall above y -6
		# the face stands where the rock is furthest forward over the tier's height and the bay's length
		var front := NAN
		for zz: float in [zc - 1.6, zc, zc + 1.6]:
			for yy: float in [yb + 0.4, (yb + yt) * 0.5]:
				var wx := _wall_x(side, yy, zz)
				if not is_nan(wx):
					front = wx if is_nan(front) or absf(wx) < absf(front) else front
		var back := _wall_x(side, yt - 0.1, zc)
		if is_nan(front) or is_nan(back) or absf(front) < 11.0:
			_skips["no wall %s z%.0f" % ["W" if side < 0.0 else "E", zc]] = 1
			PlacementLog.skip("threshold", "no wall %s z%.0f" % ["W" if side < 0.0 else "E", zc], Vector3(side * 11.0, yt, zc), "no clean wall for the tier")
			break                               # no clean wall here (a tower, the forecourt's rocks)
		front -= side * 0.3                     # stood just proud of the rock
		back += side * 1.6                      # and keyed into it
		var why := "wide" if absf(back - front) > 9.0 else _why(front, zc, 1.2)
		if why != "":
			var key := "%s %s z%.0f" % [why, "W" if side < 0.0 else "E", zc]
			_skips[key] = int(_skips.get(key, 0)) + 1
			PlacementLog.skip("threshold", key, Vector3(front, yt, zc), "tier blocked by " + why)
			if why == "wide" or why == "fall" or why == "watcher":
				break
			continue                            # a tower's pier at the foot: the tiers above still stand on the rock
		var lo := Vector3(minf(front, back), yb, zc - BAY * 0.5)
		var hi := Vector3(maxf(front, back), yt, zc + BAY * 0.5)
		# the tier with everything it carries (arch, pilasters, coping, balustrade reach 0.7 m towards the pool)
		var olo := lo - Vector3(0.7 if side > 0.0 else 0.0, 0.0, 0.0)
		var ohi := hi + Vector3(0.7 if side < 0.0 else 0.0, 1.2, 0.0)
		if not _clear(Transform3D(Basis.IDENTITY, (olo + ohi) * 0.5), ohi - olo, 0.1, true):
			_audit.append("tier %s z%.0f y%.0f dropped (%s)" % ["W" if side < 0.0 else "E", zc, yt, _last_hit])
			PlacementLog.skip("threshold", "tier %s z%.0f y%.0f" % ["W" if side < 0.0 else "E", zc, yt], Vector3(front, yt, zc), "dropped, touches " + _last_hit)
			continue                            # the tiers above may still clear it (they stand back on the slope)
		k.block(STONE, lo, hi)
		var along := Vector3(0, 0, 1)
		var inward := Vector3(-side, 0, 0)      # from the wall towards the pool
		# coping: a moulded lip along the walk's edge, a hand proud of the face
		k.box(STONE, Vector3(front - side * 0.08, yt + 0.11, zc), Vector3(0.75, 0.22, BAY), Basis.IDENTITY)
		# balustrade on the edge (posts at the pilasters)
		k.parapet(STONE, Vector3(front + side * 0.25, yt + 0.22, zc + BAY * 0.5), Vector3(front + side * 0.25, yt + 0.22, zc - BAY * 0.5), 0.85, 0.26)
		# pilasters at the bay's ends
		for e: float in [-1.0, 1.0]:
			var pz := zc + e * (BAY * 0.5 - 0.35)
			var ph := yt - yb
			k.box(STONE, Vector3(front - side * 0.26, yb + ph * 0.5, pz), Vector3(0.52, ph, 0.74), Basis.IDENTITY)
			k.box(STONE, Vector3(front - side * 0.34, yt - 0.2, pz), Vector3(0.68, 0.4, 0.92), Basis.IDENTITY)   # capital
			k.box(STONE, Vector3(front - side * 0.34, yb + 0.25, pz), Vector3(0.68, 0.5, 0.92), Basis.IDENTITY)  # base
		# a blind lancet arch on the face (the face shows through it: a shallow niche)
		var arch_base := Vector3(front - side * 0.3, yb + (0.0 if i > 0 else 1.2), zc)
		k.arch_panel(STONE, arch_base, along, 1.8, maxf(yt - yb - 2.6 - (0.0 if i > 0 else 1.2), 0.6), yt - arch_base.y - 0.05, 0.56, 0.36, 0.9, 0.0, STONE)
				# candle offerings on the walk below this tier, at the niche's foot
		if i > 0 and not is_nan(walk_x):
			k.candle_cluster(Vector3(front + inward.x * 0.55, yb + 0.02, zc + rng.randf_range(-0.6, 0.6)), rng.randi_range(4, 8), 0.32, rng)
		walk_x = front
		built += 1
	return built


# --- the Pilgrims' Chapel ---------------------------------------------------------------------------

## The chapel and its pier (chapel.gd): where the starfall pours, the terraces leave the bay open.
func _chapel(host: Node3D) -> bool:
	if "--no-chapel" in OS.get_cmdline_user_args():
		return false                       # (a measuring switch: the Threshold without the chapel)
	return Chapel.new().build(self, host)


# --- the Watchers ---------------------------------------------------------------------------------

## Two great lantern pillars carved in stone (tools/blender/wonder_watchers.py: art/models/wonders/watchers_*.glb) standing
## in the pool either side of the mouth, facing the village: a sunk spiral stair up the shaft, niches, a band of incised
## Order glyphs glowing faintly in the grooves, festoons of chain, a forged iron lantern burning violet on a short drum.
## The east one is the mirrored model. Near mesh with baked maps, a far mesh from 160 m, convex hulls for collision.
## One unshadowed orb light each is the only new light here.
func _watchers(host: Node3D) -> void:
	if OS.get_cmdline_user_args().has("--no-watchers"):      # measurement only: the Threshold without them
		return
	for w: Vector3 in WATCHERS:
		var west := w.x < 0.0
		var m := Kit.place(host, "wonders/watchers_%s.glb" % ("west" if west else "east"), Transform3D(Basis(Vector3.UP, PI + (0.22 if west else -0.22)), w + Vector3.UP * WATCHER_LIFT))
		if m == null:
			continue
		m.name = "Watcher%s" % ("West" if west else "East")
		# the plinth's footprint (and the rubble round it) is a site: the flora and the dress keep off it
		WorldLanes.register_site("watcher_%s" % ("west" if west else "east"), Rect2(w.x - 6.2, w.z - 6.2, 12.4, 12.4), w.y)
		_dress_watcher(m)
		var core := m.find_child("Pillar_core*", true, false) as MeshInstance3D
		var oc := Vector3(0.0, 27.0, 0.0)
		if core:
			oc = core.get_aabb().get_center()
		var ol := OmniLight3D.new()
		ol.name = "OrbLight"
		ol.position = oc
		ol.light_color = Color(0.6, 0.45, 1.0)
		ol.light_energy = 3.0
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
			for mi in far_root.find_children("*", "MeshInstance3D", true, false):
				var fm := mi as MeshInstance3D
				if fm.mesh != null:
					FarDetail.register(m, fm.mesh, Transform3D.IDENTITY, 160.0, _orb_mat() if String(fm.name).contains("orb") else _far_stone_mat(), false)
			far_root.free()
		FarDetail.near_ends(m, 160.0, 30.0)


static var _watcher_mats: Dictionary = {}


## The baked column maps (with the glyph grooves' faint ember as the emission map); the staff, chains and cage in the iron
## set over their rust vertex colours; the flame in layers (a hot core, a violet halo, a smoked cracked glass shell).
func _dress_watcher(m: Node3D) -> void:
	if _watcher_mats.is_empty():
		var T := "res://art/textures/"
		var W := "res://art/models/wonders/"
		var fig := StandardMaterial3D.new()
		fig.albedo_texture = load(W + "watchers_pillar_albedo.png")
		fig.albedo_color = Color(0.92, 0.92, 0.94)
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
		_watcher_mats["iron"] = load("res://core/world/realm/west_marches_kit.gd").mat("iron")
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
		for k: String in key:
			if nm.begins_with(k):
				mi.material_override = _watcher_mats[key[k]]
				if key[k] in ["orb", "core", "glass"]:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				break


## Pilgrims' candles on the pillars' lower tread, in the kit's wax (the chapel's and the terraces' own). The plinth
## (tools/blender/wonder_watchers.py PLINTH) has two square treads; the upper is under the moulded torus's overhang,
## so the candles keep to the lower, 0.7 m up and 0.48 m deep (half 2.97 m to the lip at 3.45 m), clear of the
## starwater by WATCHER_LIFT. Each cluster is seated by a ray on that tier's collision and dropped if it misses it.
const TREAD_Y := 0.7
const TREAD_MID := 3.2
func _watcher_candles(host: Node3D) -> void:
	var placed := 0
	var cr := RandomNumberGenerator.new()      # its own: the terraces after it keep their exact draws
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

## The rift's MultiMesh pieces carry no collision (the crossing's colonnade columns, the ash drifts): keep
## each instance's world box near the Threshold so nothing is placed through one.
func _collect_instances(rift: Node) -> void:
	if rift == null:
		return
	var area := AABB(Vector3(-34.0, -24.0, star_z - 14.0), Vector3(68.0, 60.0, -star_z + 6.0))
	for n in rift.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var mb := mmi.multimesh.mesh.get_aabb()
		for i in mmi.multimesh.instance_count:
			var bb: AABB = mmi.global_transform * mmi.multimesh.get_instance_transform(i) * mb
			if bb.intersects(area):
				_cols.append(bb)


## Visual meshes with no collision (the Ossuary's bone colonnade, ornament) are obstacles too: each one
## in the Threshold's reach gets a temporary trimesh body on PROBE_LAYER while pieces are placed. The
## ground, the water, the flora and the lava are left out (the ground has its own collision).
func _stand_ins(root: Node, host: Node3D) -> void:
	var area := AABB(Vector3(-34.0, -24.0, star_z - 6.0), Vector3(68.0, 60.0, -star_z - 2.0))
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or host.is_ancestor_of(mi):
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if not bb.intersects(area) or bb.size.x * bb.size.z > 6000.0:
			continue
		var path := String(mi.get_path())
		if path.contains("Terrain") or path.contains("Lava") or path.contains("Flora") or path.contains("FenWater") or path.contains("Fall"):
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = "StandIn"
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		body.set_meta(&"stands_for", path.trim_prefix("/root/Main/"))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		host.add_child(body)
		body.global_transform = mi.global_transform
		_temp.append(body)


## True when a box `size` at `xf` touches nothing already built: no collision (the ground excepted when
## `ground_ok`: a terrace keys into the rock) and no collision-less instance; `grow` pads it all round.
func _clear(xf: Transform3D, size: Vector3, grow := 0.3, ground_ok := false) -> bool:
	var sh := BoxShape3D.new()
	sh.size = size + Vector3.ONE * grow * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = xf
	q.collision_mask = Layers.WORLD | PROBE_LAYER
	for hit: Dictionary in space.intersect_shape(q, 24):
		var c := hit.get("collider") as Node
		if ground_ok and c != null and String(c.name).begins_with("Terrain"):
			continue
		_last_hit = String(c.get_meta(&"stands_for", c.get_path())) if c else "?"
		return false
	var bb: AABB = xf * AABB(-size * 0.5 - Vector3.ONE * grow, size + Vector3.ONE * grow * 2.0)
	for cb: AABB in _cols:
		if cb.intersects(bb):
			_last_hit = "an instanced piece at %s" % cb.get_center().snapped(Vector3.ONE * 0.1)
			return false
	return true


## Each Watcher's own convex hulls (the plinth's tiers, the base, the shaft, the capital, the lantern) against the world:
## nothing may touch but the pool floor under the plinth.
func _audit_watchers(host: Node3D) -> void:
	for w in host.get_children():
		if not (w is Node3D) or w is Light3D or not String(w.name).begins_with("Watcher"):
			continue
		var m := w as Node3D
		var own := {}
		for b in m.find_children("*", "CollisionObject3D", true, false):
			own[b] = true
		for b in m.find_children("*", "StaticBody3D", true, false):
			var tier := String(b.name).begins_with("Pillar_tier")
			for cs in b.get_children():
				if not (cs is CollisionShape3D) or (cs as CollisionShape3D).shape == null:
					continue
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = (cs as CollisionShape3D).shape
				q.transform = (cs as CollisionShape3D).global_transform
				q.collision_mask = Layers.WORLD | PROBE_LAYER
				var touched := {}
				for hit: Dictionary in space.intersect_shape(q, 24):
					var c := hit.get("collider") as Node
					if c == null or own.has(c) or (tier and String(c.name).begins_with("Terrain")):
						continue
					touched[String(c.get_meta(&"stands_for", c.name))] = true
				if not touched.is_empty():
					_audit.append("%s %s touches %s" % [m.name, b.name, ", ".join(touched.keys())])


# --- light ---------------------------------------------------------------------------------------------

## A box of rune-light into the emissive mesh (six faces).
func _slab(c: Vector3, size: Vector3, b := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var ax := [b.x * h.x, b.y * h.y, b.z * h.z]
	for a in 3:
		for s: float in [-1.0, 1.0]:
			var n: Vector3 = (ax[a] as Vector3) * s
			var u: Vector3 = ax[(a + 1) % 3]
			var v: Vector3 = ax[(a + 2) % 3]
			var o := c + n
			var q := [o - u - v, o + u - v, o + u + v, o - u + v]
			var nn := n.normalized()
			for idx: int in ([0, 1, 2, 0, 2, 3] if s > 0.0 else [0, 2, 1, 0, 3, 2]):
				rune.set_normal(nn)
				rune.add_vertex(q[idx])


static func _orb_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.6, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.66, 0.52, 1.0)
	m.emission_energy_multiplier = 5.0
	return m


static func _rune_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.22, 0.7)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.4, 1.0)
	m.emission_energy_multiplier = 3.4
	m.roughness = 0.6
	return m


## The pool lights the place from below (the moon never reaches the floor): two low violet lights over the
## water, with LavaWorks' Glow0 between them, and one higher in front of the chapel that lights the west terraces' faces and the
## chapel's facade. Unshadowed, budgeted like the Realm's own lights.
func _pool_lights(host: Node3D) -> void:
	for spec: Array in [[Vector3(0.0, LAVA + 1.6, -18.5), 4.0, 24.0], [Vector3(4.0, LAVA + 1.6, -38.0), 4.0, 24.0], [Vector3(-11.0, LAVA + 6.5, -37.0), 3.2, 13.0]]:
		var at: Vector3 = spec[0]
		var l := OmniLight3D.new()
		l.name = "PoolLight"
		l.light_color = Color(0.5, 0.38, 1.0)
		l.light_energy = float(spec[1])
		l.omni_range = float(spec[2])
		l.omni_attenuation = 0.8
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.5
		l.distance_fade_enabled = true
		l.distance_fade_begin = 90.0
		l.distance_fade_length = 20.0
		l.set_meta(&"light_class", &"realm")
		host.add_child(l)
		l.global_position = at


## Motes rising off the pool.
func _motes(host: Node3D) -> void:
	var mid := (Z0 + star_z) * 0.5
	var rise := Vfx.emitter(Color(0.75, 0.66, 1.6), {"count": 220, "life": 9.0, "speed": Vector2(0.15, 0.5), "size": 0.05, "gravity": -0.12, "radius": 1.0, "turbulence": true, "explosive": 0.0})
	if rise:
		rise.name = "StarMotes"
		var pm := (rise.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(16.0, 0.3, (Z0 - star_z) * 0.5)
		rise.process_material = pm
		rise.visibility_aabb = AABB(Vector3(-24, -2, -24), Vector3(48, 34, 48))
		rise.preprocess = 8.0
		host.add_child(rise)
		rise.global_position = Vector3(0.0, LAVA + 0.4, mid)
		rise.emitting = true
