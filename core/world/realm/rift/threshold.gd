extends RefCounted
## THE PILGRIMS' THRESHOLD (RealmRift): the rift's south reach, from the forecourt to the Spindle,
## rebuilt as the place the pilgrims went down to the light (Luke, 9 Nov: "I don't think the lava place
## should be so close to the village", then "make it architectural, explore, make it magical").
## No lava here: the pool is starwater (lava.gdshader's star zone, set by LavaWorks from STAR_Z).
##   - terraces stepping down both walls to the pool, like river steps: vertical ashlar faces stood in
##     front of the rock's slope, flat walks between them, a balustrade on every edge, pilasters
##     carrying violet rune slits, a blind lancet arch on every bay, candle offerings on the walks;
##     left open where a starfall pours down its channel (RealmRift.STARFALLS)
##   - the Watchers: two colossal hooded mages (MageStatue at 4.2x, about 26 m, the east one mirrored) standing
##     in the pool either side of the threshold's mouth, facing the village, open hands over the gate, orbs lit
##     violet above the rim
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
const WATCHERS := [Vector3(-14.5, -17.2, -15.6), Vector3(14.5, -17.2, -15.6)]
const WATCHER_SCALE := 4.2             ## about 26 m: the hood and the orb stand over the forecourt's walls
const WATCHER_R := 6.4                 ## the pedestal's reach at that scale (1.6 m x 4.2) and a little

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
	var mi := MeshInstance3D.new()
	mi.name = "Runes"
	mi.mesh = rune.commit()
	mi.material_override = _rune_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	_motes(host)
	_pool_lights(host)
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
			break                               # no clean wall here (a tower, the forecourt's rocks)
		front -= side * 0.3                     # stood just proud of the rock
		back += side * 1.6                      # and keyed into it
		var why := "wide" if absf(back - front) > 9.0 else _why(front, zc, 1.2)
		if why != "":
			var key := "%s %s z%.0f" % [why, "W" if side < 0.0 else "E", zc]
			_skips[key] = int(_skips.get(key, 0)) + 1
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

## Two colossal hooded mages (the summit's MageStatue at 4.2x) in the pool either side of the mouth, facing
## the village; their orbs burn violet above the rim. Their orb lights are the only new lights here.
func _watchers(host: Node3D) -> void:
	for w: Vector3 in WATCHERS:
		var m := MageStatue.new()
		m.name = "Watcher%s" % ("West" if w.x < 0.0 else "East")
		host.add_child(m)
		m.global_position = w
		m.rotation.y = PI + (0.22 if w.x < 0.0 else -0.22)     # facing the village, turned a little to the mouth
		m.scale = Vector3.ONE * WATCHER_SCALE
		m.set_process(false)
		if w.x > 0.0:
			# mirrored, so both reach their open hand over the gate (the body is symmetric: it stays as built)
			for c in m.get_children():
				if c is Node3D and not (c is CollisionObject3D):
					(c as Node3D).transform = Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO) * (c as Node3D).transform
		var ol := m.find_child("OrbLight", true, false) as OmniLight3D
		if ol:
			ol.light_color = Color(0.6, 0.45, 1.0)
			ol.light_energy = 4.0
			ol.omni_range = 22.0
		var orb := m.find_child("Orb", true, false) as MeshInstance3D
		if orb:
			orb.material_override = _orb_mat()
		# floodlit from the pool: a violet spot at the water in front of the figure, up its robe to the hood
		var up := SpotLight3D.new()
		up.name = "WatcherUplight"
		up.light_color = Color(0.56, 0.42, 1.0)
		up.light_energy = 7.0
		up.spot_range = 34.0
		up.spot_angle = 24.0
		up.spot_attenuation = 0.6
		up.shadow_enabled = false
		up.light_volumetric_fog_energy = 0.4
		up.distance_fade_enabled = true                    # seen from the village: an authored fade, kept by the director
		up.distance_fade_begin = 110.0
		up.distance_fade_length = 20.0
		up.set_meta(&"light_class", &"shaft")
		host.add_child(up)
		var foot := Vector3(w.x * 0.45, LAVA + 0.6, w.z + 4.0)
		up.look_at_from_position(foot, Vector3(w.x, LAVA + 22.0, w.z), Vector3.UP)


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


## Each Watcher as its parts (MageStatue's own proportions, at full scale): the pedestal, the body, the staff
## and the outstretched arm with its sleeve, tested against everything built and drawn (and the rock, but for
## the pedestal, which stands on the floor). Anything touched is printed in the clearance line.
func _audit_watchers(host: Node3D) -> void:
	var fs := MageStatue.FIG_SCALE
	var ph := MageStatue.PEDESTAL_H
	for w in host.get_children():
		if not (w is MageStatue):
			continue
		var m := w as Node3D
		var mx := -1.0 if m.global_position.x > 0.0 else 1.0            # the east one is mirrored
		var fig := func(v: Vector3) -> Vector3: return Vector3(v.x * fs * mx, v.y * fs + ph, v.z * fs)
		var parts: Array = []
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.6 * WATCHER_SCALE
		cyl.height = ph * WATCHER_SCALE
		parts.append(["pedestal", cyl, Vector3(0, ph * 0.5, 0), Basis.IDENTITY, true])
		var cap := CapsuleShape3D.new()
		cap.radius = 0.55 * fs * WATCHER_SCALE
		cap.height = 2.9 * fs * WATCHER_SCALE
		parts.append(["body", cap, Vector3(0, ph + 1.45 * fs, 0), Basis.IDENTITY, false])
		parts.append(_bar("staff", fig.call(Vector3(0.62, 0.0, -0.38)), fig.call(Vector3(0.62, 4.0, -0.38)), 0.12 * fs))
		parts.append(_bar("arm", fig.call(Vector3(-0.4, 2.56, 0.0)), fig.call(Vector3(-0.63, 2.55, -1.0)), 0.36 * fs))
		parts.append(_bar("sleeve", fig.call(Vector3(-0.66, 2.44, -0.62)), fig.call(Vector3(-0.64, 1.78, -0.5)), 0.3 * fs))
		var own := m.find_child("StatueBody", true, false)
		for part: Array in parts:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = part[1]
			var rot := m.global_transform.basis.orthonormalized()
			q.transform = Transform3D(rot * (part[3] as Basis), m.global_transform * (part[2] as Vector3))
			q.collision_mask = Layers.WORLD | PROBE_LAYER
			var touched := {}
			for hit: Dictionary in space.intersect_shape(q, 24):
				var c := hit.get("collider") as Node
				if c == null or c == own or (bool(part[4]) and String(c.name).begins_with("Terrain")):
					continue
				touched[String(c.get_meta(&"stands_for", c.name))] = true
			if not touched.is_empty():
				_audit.append("%s %s touches %s" % [m.name, part[0], ", ".join(touched.keys())])


## A thin box from a to b (node-local, before the node's scale), `t` thick, as an audit part.
func _bar(n: String, a: Vector3, b: Vector3, t: float) -> Array:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var box := BoxShape3D.new()
	box.size = Vector3(t, d.length(), t) * WATCHER_SCALE
	return [n, box, (a + b) * 0.5, Basis(x, y, x.cross(y)), false]


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


## A column of carved glyphs down a pilaster's face: short strokes and bars of rune-light, never a line.
func _glyphs(at: Vector3, y0: float, y1: float) -> void:
	var y := y1
	while y > y0 + 0.2:
		var h := rng.randf_range(0.12, 0.34)
		var kind := rng.randi_range(0, 2)
		if kind == 0:
			_slab(Vector3(at.x, y - h * 0.5, at.z), Vector3(0.02, h, 0.05))                    # a stroke
		elif kind == 1:
			_slab(Vector3(at.x, y - 0.03, at.z), Vector3(0.02, 0.05, rng.randf_range(0.18, 0.3)))   # a bar
		else:
			_slab(Vector3(at.x, y - h * 0.5, at.z), Vector3(0.02, h, 0.05))
			_slab(Vector3(at.x, y - h * 0.3, at.z), Vector3(0.02, 0.05, 0.2))                 # a cross
		y -= h + rng.randf_range(0.14, 0.3)


static func _orb_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.6, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.66, 0.52, 1.0)
	m.emission_energy_multiplier = 9.0
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
