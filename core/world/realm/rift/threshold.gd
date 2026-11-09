extends RefCounted
## THE PILGRIMS' THRESHOLD (RealmRift): the rift's south reach, from the forecourt to the Spindle,
## rebuilt as the place the pilgrims went down to the light (Luke, 9 Nov: "I don't think the lava place
## should be so close to the village", then "make it architectural, explore, make it magical").
## No lava here: the pool is starwater (lava.gdshader's star zone, set by LavaWorks from STAR_Z).
##   - terraces stepping down both walls to the pool, like river steps: vertical ashlar faces stood in
##     front of the rock's slope, flat walks between them, a balustrade on every edge, pilasters
##     carrying violet rune slits, a blind lancet arch on every bay, candle offerings on the walks;
##     left open where a starfall pours down its channel (RealmRift.STARFALLS)
##   - the Watchers: two colossal hooded mages (MageStatue at 4.2x, about 26 m) standing in the pool either
##     side of the threshold's mouth, facing the village, orbs lit violet above the rim; a starfall
##     pours down the wall behind each
##   - the Broken Stair: the pilgrims' stair (the old stair's own steps, stair_step.glb) lifted out of the
##     pool and held in the air where it broke, climbing in a long curve, light in every joint
##   - motes rising off the pool, and light dripping from the stair
## The east wall above y -6 from z -22 north is the Ossuary's: there the terraces stop below it.
## Collision: the terraces (walkable, reachable down the rock's slope from the rim); the stair is a vista.

const STONE := "stone"
const LAVA := -15.5
const TOPS := [-12.0, -8.0, -4.0]      ## each terrace's walk height; the lowest stands in the pool
const BAY := 4.0                       ## metres per terrace bay along the wall
const Z0 := -15.0                      ## the first bay's south edge (the forecourt's rocks are south of it)
const WATCHERS := [Vector3(-14.5, -17.2, -19.5), Vector3(14.5, -17.2, -19.5)]   ## pedestal feet, in the pool
const WATCHER_SCALE := 4.2             ## about 26 m: the hood and the orb stand over the forecourt's walls
const WATCHER_R := 6.4                 ## the pedestal's reach at that scale (1.6 m x 4.2) and a little
const STEP_GLB := "res://art/models/stair_step.glb"

var k: OssKit
var space: PhysicsDirectSpaceState3D
var star_z := -46.0
var falls: Array = []
var rng := RandomNumberGenerator.new()
var rune: SurfaceTool                  ## violet rune slits and the stair's under-light (one emissive mesh)
var report: Array[String] = []
var _skips := {}                       ## why a bay's tier was not built (printed)


func build(root: Node, host: Node3D, p_star_z: float, p_falls: Array) -> void:
	rng.seed = 2611
	star_z = p_star_z
	falls = p_falls
	space = (root as Node3D).get_world_3d().direct_space_state
	k = OssKit.new()
	k.keep_lanes = false
	k.candle_lights = false             # the wax glows; no new lights (the pool and the violet glow light it)
	rune = SurfaceTool.new()
	rune.begin(Mesh.PRIMITIVE_TRIANGLES)
	_watchers(host)
	var bays := 0
	for side: float in [-1.0, 1.0]:
		var z := Z0
		while z - BAY >= star_z + 1.0:
			bays += _bay(side, z - BAY * 0.5)
			z -= BAY
	var steps := _broken_stair(host)
	k.commit(host, "ThresholdBody")
	var mi := MeshInstance3D.new()
	mi.name = "Runes"
	mi.mesh = rune.commit()
	mi.material_override = _rune_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	_motes(host)
	_pool_lights(host)
	report.append("terraces: %d bay tiers, broken stair: %d steps, skipped %s" % [bays, steps, str(_skips)])
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
			break
		var lo := Vector3(minf(front, back), yb, zc - BAY * 0.5)
		var hi := Vector3(maxf(front, back), yt, zc + BAY * 0.5)
		k.block(STONE, lo, hi)
		var along := Vector3(0, 0, 1)
		var inward := Vector3(-side, 0, 0)      # from the wall towards the pool
		# coping: a moulded lip along the walk's edge, a hand proud of the face
		k.box(STONE, Vector3(front - side * 0.08, yt + 0.11, zc), Vector3(0.75, 0.22, BAY), Basis.IDENTITY)
		# balustrade on the edge (posts at the pilasters)
		k.parapet(STONE, Vector3(front + side * 0.25, yt + 0.22, zc + BAY * 0.5), Vector3(front + side * 0.25, yt + 0.22, zc - BAY * 0.5), 0.85, 0.26)
		# pilasters at the bay's ends, each with a rune slit down its face
		for e: float in [-1.0, 1.0]:
			var pz := zc + e * (BAY * 0.5 - 0.35)
			var ph := yt - yb
			k.box(STONE, Vector3(front - side * 0.26, yb + ph * 0.5, pz), Vector3(0.52, ph, 0.74), Basis.IDENTITY)
			k.box(STONE, Vector3(front - side * 0.34, yt - 0.2, pz), Vector3(0.68, 0.4, 0.92), Basis.IDENTITY)   # capital
			k.box(STONE, Vector3(front - side * 0.34, yb + 0.25, pz), Vector3(0.68, 0.5, 0.92), Basis.IDENTITY)  # base
			_glyphs(Vector3(front - side * 0.53, 0.0, pz), yb + 0.9, yt - 0.7)
		# a blind lancet arch on the face (the face shows through it: a shallow niche)
		var arch_base := Vector3(front - side * 0.3, yb + (0.0 if i > 0 else 1.2), zc)
		k.arch_panel(STONE, arch_base, along, 1.8, maxf(yt - yb - 2.6 - (0.0 if i > 0 else 1.2), 0.6), yt - arch_base.y - 0.05, 0.56, 0.36, 0.9, 0.0, STONE)
		# a rune glowing at the back of the niche: a pilgrim's mark, a stroke and a bar
		_slab(Vector3(front - side * 0.04, arch_base.y + 1.15, zc), Vector3(0.02, 0.8, 0.06))
		_slab(Vector3(front - side * 0.04, arch_base.y + 1.42, zc), Vector3(0.02, 0.05, 0.36))
		# candle offerings on the walk below this tier, at the niche's foot
		if i > 0 and not is_nan(walk_x):
			k.candle_cluster(Vector3(front + inward.x * 0.55, yb + 0.02, zc + rng.randf_range(-0.6, 0.6)), rng.randi_range(4, 8), 0.32, rng)
		walk_x = front
		built += 1
	return built


# --- the Broken Stair -------------------------------------------------------------------------------

## The old stair's own steps rising out of the pool on a long curve east of the crossing, past the rim:
## whole and close at the foot, drifting apart and turning as they climb, as if the stair broke and was
## held. Every joint leaks light (a seam under the front and back edge), shards drift by the upper ones.
func _broken_stair(host: Node3D) -> int:
	var scene := load(STEP_GLB) as PackedScene if ResourceLoader.exists(STEP_GLB) else null
	var n := 15
	var placed := 0
	var prev := Vector3.ZERO
	for i in n:
		var t := float(i) / float(n - 1)
		var p := Vector3(7.4 + 3.4 * sin(t * PI * 0.9), LAVA + 0.8 + t * 22.0 + t * t * 4.0, -27.5 - 17.0 * t)
		p.x += rng.randf_range(-0.3, 0.3) * t * 3.0
		p.z += rng.randf_range(-0.3, 0.3) * t * 2.0
		var dir := (p - prev).normalized() if i > 0 else Vector3(0.15, 0.0, -1.0)
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		var bas := Basis(flat.cross(Vector3.UP).normalized(), Vector3.UP, -flat)
		var tilt := t * t * 0.5
		bas = bas * Basis(Vector3.FORWARD, rng.randf_range(-tilt, tilt)) * Basis(Vector3.RIGHT, rng.randf_range(-tilt, tilt) * 0.6) * Basis(Vector3.UP, rng.randf_range(-tilt, tilt))
		var size := Vector3(rng.randf_range(2.8, 3.3) * (1.0 - t * 0.2), 0.52, rng.randf_range(1.2, 1.45))
		prev = p
		if _blocked(p.x, p.z, 1.0):
			continue
		if scene:
			_fit(host, scene, p, bas, size)
		else:
			k.box("hub", p, size, bas, false)
		# light in the joints: thin seams along the step's lower front and back edges
		for e: float in [-1.0, 1.0]:
			_slab(p - bas.y * (size.y * 0.5 - 0.02) + bas.z * (e * size.z * 0.46), Vector3(size.x * 0.86, 0.035, 0.05), bas)
		# shards broken off the upper steps, drifting beside them
		if t > 0.45 and rng.randf() < 0.7:
			var sp := p + bas.x * rng.randf_range(-2.4, 2.4) + Vector3(0.0, rng.randf_range(-1.2, 1.4), rng.randf_range(-1.0, 1.0))
			var sb := Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU)
			k.box("hub", sp, Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.25, 0.4), rng.randf_range(0.4, 0.8)), sb, false)
		placed += 1
	return placed


## One step model fitted to `size` (x across, y up, z run) at `c` with basis `b`, in the hub stair's stone.
func _fit(host: Node3D, scene: PackedScene, c: Vector3, b: Basis, size: Vector3) -> void:
	var model := scene.instantiate() as Node3D
	model.name = "FloatingStep%d" % host.get_child_count()
	host.add_child(model)
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var bb: AABB = model.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
		mi.material_override = OssKit.mat("hub")
	if first:
		return
	var s := Vector3(size.x / maxf(box.size.x, 0.01), size.y / maxf(box.size.y, 0.01), size.z / maxf(box.size.z, 0.01))
	var bs := b * Basis.from_scale(s)
	model.global_transform = Transform3D(bs, c - bs * box.get_center())


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
	m.emission_energy_multiplier = 3.2
	m.roughness = 0.6
	return m


## The pool lights the place from below (the moon never reaches the floor): two low violet lights over the
## water, with LavaWorks' Glow0 between them. Unshadowed, budgeted like the Realm's own lights.
func _pool_lights(host: Node3D) -> void:
	for at: Vector3 in [Vector3(0.0, LAVA + 1.6, -18.5), Vector3(4.0, LAVA + 1.6, -38.0)]:
		var l := OmniLight3D.new()
		l.name = "PoolLight"
		l.light_color = Color(0.5, 0.38, 1.0)
		l.light_energy = 2.6
		l.omni_range = 18.0
		l.omni_attenuation = 0.8
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.5
		l.distance_fade_enabled = true
		l.distance_fade_begin = 90.0
		l.distance_fade_length = 20.0
		l.set_meta(&"light_class", &"realm")
		host.add_child(l)
		l.global_position = at


## Motes rising off the pool, and light dripping from the stair.
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
	var drip := Vfx.emitter(Color(0.8, 0.72, 1.7), {"count": 70, "life": 5.0, "speed": Vector2(0.05, 0.2), "size": 0.04, "gravity": 0.35, "radius": 1.0, "turbulence": true, "explosive": 0.0})
	if drip:
		drip.name = "StairLight"
		var dm := (drip.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		dm.emission_box_extents = Vector3(2.5, 9.0, 11.0)
		drip.process_material = dm
		drip.visibility_aabb = AABB(Vector3(-8, -22, -16), Vector3(16, 40, 32))
		drip.preprocess = 5.0
		host.add_child(drip)
		drip.global_position = Vector3(9.5, -1.0, -36.0)
		drip.emitting = true
