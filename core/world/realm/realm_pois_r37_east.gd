extends RefCounted
## East Marches (docs/r37_expansion.md): the places of Stillwater, the Anchorholds, Saltmarket and the
## White Pans, built from the in-house GLBs of tools/blender/r37_east.py (art/models/r37e_*.glb: textured
## stone, timber, salt, plaster, slate and iron, with LODs where the thing is big) and their collision
## boxes (r37_east_boxes.gd, generated from the same numbers).
##
##   spire        The Lamplighters' Spire (Stillwater): a ~33 m beacon tower on the bluff at
##                RealmLayout.SPIRE_C. A stair inside climbs to the lamp room; the great lamp is DARK
##                until the wanderer lights it (pillar: warmth is earned), then a beacon is seen across
##                the Marches (a soft column + one fill light; the glow budget is untouched).
##   cells        The hermits' cells (Anchorholds): portals cut into the Crowns' face round the raid
##                terrace, a timber walk with stairs over its rim, the cliff chapel at the north.
##   anchorhold   The Anchoress's room: four hermits' cairns on the terrace (the lee of the Undertow),
##                the arena (BossArena, core/enemy/anchoress.gd), a boss beacon.
##   saltmarket   The salt-workers' hamlet: three houses, a drying shed, the trader's stall, barrels.
##                Its people walk nodes this file lays (hamlet(), called from village.gd).
##   saltworks    The salt-works (White Pans): the boiling hall, evaporation pans, three timber
##                derricks, heaps of salt. `crust`: the crystal crust, the Pans' secret's ground.
## Built by RealmPois (reserve: before the stamp and the flora; build: after the flora). No class_name.

const P := preload("res://core/world/realm/realm_pois.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Boxes := preload("res://core/world/realm/r37_east_boxes.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const M := "res://art/models/"
const SPIRE := M + "r37e_spire.glb"
const CELLS := M + "r37e_cells.glb"
const WORKS := M + "r37e_saltworks.glb"
const HAMLET := M + "r37e_hamlet.glb"
const ANCHORESS := "res://core/enemy/anchoress.gd"
const GROUND := 1

## id -> {at, search, half, rise, title, line, region}
const POIS := {
	"lamp_spire": {"at": Vector2(242, 6), "search": 8.0, "half": Vector2(5.0, 5.0), "rise": 6.0,      # the pad fits the bluff's flat top (r 8): a wider one levelled the bluff down to its foot
		"title": "The Lamplighters' Spire", "line": "the flame the Marches steered by", "region": "stillwater"},
	"saltmarket": {"at": Vector2(214, 95), "search": 0.0, "half": Vector2(21, 17), "rise": 6.0,
		"title": "Saltmarket", "line": "salt keeps meat, and keeps the hollowed off a threshold", "region": "saltmarket"},
	"saltworks": {"at": Vector2(232, 168), "search": 0.0, "half": Vector2(20, 22), "rise": 3.0,
		"title": "The Salt-Works", "line": "forty pans and nobody to rake them", "region": "saltpans"},
	"crust": {"at": Vector2(238, 212), "search": 8.0, "half": Vector2(8, 8), "rise": 2.0,
		"title": "The Crystal Crust", "line": "the white that grows back", "region": "saltpans"},
}

const LAMP_Y := 27.0 + 0.3 + 1.6        ## the great lamp's flame above the tower's base (r37_east.py: DECK, ly)
const HAMLET_FIRE := Vector2(218, 98)
const TERRACE_UP := 2.4                 ## the timber walk's height over the raid floor (one flight of Walk_Stair)

static var spots := {}
static var built: Array[String] = []
static var _meshes := {}
static var cairns: Array[Vector3] = []
static var lamp_node: Node3D = null


static func release() -> void:
	_win_mat = null
	_boxes_map.clear()
	_meshes.clear()
	lamp_node = null


# --- reserve (RealmPois.reserve: before the stamp and the flora) ----------------------------------

static func reserve(root: Node, _skip: PackedStringArray) -> void:
	spots.clear()
	for a in OS.get_cmdline_user_args():
		if a == "--no-r37-east":
			return
	var space := (root as Node3D).get_world_3d().direct_space_state
	for id: String in POIS:
		var d: Dictionary = POIS[id]
		var half: Vector2 = d.half
		var pref: Vector2 = d.at
		var q := pref
		if float(d.search) > 0.0:
			q = LK.search_spot(space, pref, float(d.search), half, 1.2, float(d.rise), [], 2.0)
		if q == Vector2.INF:
			print("REALM_POI r37e skip %s: no clear ground near %s (%s)" % [id, pref, LK.blocker(Rect2(pref - half, half * 2.0), 1.2)])
			continue
		var rect := Rect2(q - half, half * 2.0)
		var lo := INF
		var hi := -INF
		for ix in 5:
			for iz in 5:
				var gy := RealmLayout.ground(space, rect.position.x + rect.size.x * ix * 0.25, rect.position.y + rect.size.y * iz * 0.25)
				lo = minf(lo, gy)
				hi = maxf(hi, gy)
		var cy := RealmLayout.ground(space, q.x, q.y)
		var face := _nearest_way(q)
		var to := face - q
		var yaw := atan2(to.x, to.y)
		var base := lo
		if id == "lamp_spire":
			base = cy            # on the bluff's top: the lowest corner of the pad sat on its shoulder and sank the tower
		if id == "saltmarket" or id == "saltworks" or id == "crust":
			base = cy
			yaw = 0.0
			# a level pad (the hamlet's yard, the works' floor): cut and filled to the centre's height
			WorldLanes.register_terrace("poi_" + id, q, maxf(half.x, half.y), cy)
		else:
			WorldLanes.register_site("poi_" + id, rect, lo + 0.05, lo)
		spots[id] = {"at": Vector3(q.x, base, q.y), "yaw": yaw, "rect": rect, "lo": lo, "hi": hi}
	if spots.has("lamp_spire"):
		Flora.tree_clear.append([Vector2((spots.lamp_spire.at as Vector3).x, (spots.lamp_spire.at as Vector3).z), 20.0])
	# the Anchoress's cairns and the walk are built on the raid floor (reserved by RealmBosses)
	print("REALM_POI r37e reserved %s" % [spots.keys()])


static func _nearest_way(q: Vector2) -> Vector2:
	var best := q + Vector2(0, 1)
	var bd := INF
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var ab: Vector2 = (pts[i + 1] as Vector2) - a
			var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var c := a + ab * t
			if c.distance_to(q) < bd:
				bd = c.distance_to(q)
				best = c
	return best


# --- build (after the flora) ------------------------------------------------------------------------

static func build(holder: Node3D) -> void:
	built.clear()
	if "--no-r37-east" in OS.get_cmdline_user_args():
		return
	LK.ensure_mats()
	var space := holder.get_world_3d().direct_space_state
	for id: String in spots:
		var s: Dictionary = spots[id]
		var d: Dictionary = POIS[id]
		var host := Node3D.new()
		host.name = "Poi_" + id
		host.set_meta("site", "poi_" + id)
		holder.add_child(host)
		host.add_to_group(P.GROUP_POI)
		host.set_meta("poi", id)
		host.set_meta("title", d.title)
		host.set_meta("line", d.line)
		host.set_meta("region", d.region)
		host.set_meta("centre", s.at)
		host.set_meta("radius", (d.half as Vector2).length() + 4.0)
		host.set_meta("r37", true)
		match id:
			"lamp_spire": _spire(host, space, s)
			"saltmarket": _saltmarket(host, space, s)
			"saltworks": _saltworks(host, space, s)
			"crust": _crust(host, space, s)
		built.append(id)
		print("REALM_POI r37e %s at %s yaw %.0f" % [id, (s.at as Vector3).snapped(Vector3.ONE * 0.1), rad_to_deg(float(s.yaw))])
	_anchorholds(holder, space)


# --- shared pieces ------------------------------------------------------------------------------------

static func mesh(path: String, nm: String) -> Mesh:
	var key := path + "#" + nm
	if _meshes.has(key):
		return _meshes[key]
	var out: Mesh = null
	var ps := load(path) as PackedScene
	if ps:
		var inst := ps.instantiate()
		var mi := inst.find_child(nm, true, false) as MeshInstance3D
		if mi:
			out = mi.mesh
			# the art wave's textures are night values (the lore kit lifts them 1.1-1.5x): lift them here too
			for i in out.get_surface_count():
				var sm := out.surface_get_material(i) as StandardMaterial3D
				if sm != null and sm.albedo_texture != null:
					var m2 := sm.duplicate() as StandardMaterial3D
					m2.albedo_color = Color(1.2, 1.3, 1.45) if sm.resource_name == "plaster" else Color(1.55, 1.5, 1.45)
					out.surface_set_material(i, m2)
		inst.free()
	_meshes[key] = out
	return out


## One piece of a kit GLB at `xf`; `lod` = [begin, end] visibility range (0 = open) with a fade.
static func piece(host: Node3D, path: String, nm: String, xf: Transform3D, lod := Vector2(0, 0), shadows := true, lit_windows := false) -> MeshInstance3D:
	var m := mesh(path, nm)
	if m == null:
		push_warning("r37e: no mesh %s in %s" % [nm, path])
		return null
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lod != Vector2.ZERO:
		mi.visibility_range_begin = lod.x
		mi.visibility_range_begin_margin = lod.x * 0.12 if lod.x > 0.0 else 0.0
		mi.visibility_range_end = lod.y
		mi.visibility_range_end_margin = lod.y * 0.12 if lod.y > 0.0 else 0.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	host.add_child(mi)
	mi.global_transform = xf
	if lit_windows:
		for i in m.get_surface_count():
			var sm2 := m.surface_get_material(i)
			if sm2 != null and sm2.resource_name == "window_glass":
				mi.set_surface_override_material(i, _window_mat())
	return mi


static var _win_mat: StandardMaterial3D = null


## A lit window: warm and low (under the bloom threshold; the hearth is behind it).
static func _window_mat() -> StandardMaterial3D:
	if _win_mat == null:
		_win_mat = StandardMaterial3D.new()
		_win_mat.albedo_color = Color(0.9, 0.6, 0.3)
		_win_mat.emission_enabled = true
		_win_mat.emission = Color(1.0, 0.62, 0.28)
		_win_mat.emission_energy_multiplier = 1.05
		_win_mat.roughness = 0.4
	return _win_mat


## Collision from a generated box table (rows [c, size, quaternion]) placed by `xf`.
static func cols(host: Node3D, name: String, rows: Array, xf: Transform3D) -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	for r: Array in rows:
		var b := Basis(Quaternion(float(r[6]), float(r[7]), float(r[8]), float(r[9])))
		LK.col_box(k, xf * Vector3(float(r[0]), float(r[1]), float(r[2])), Vector3(float(r[3]), float(r[4]), float(r[5])), xf.basis * b)
	k.commit(host, name)


## A flight's collision: a thin box laid along lo -> hi.
static func ramps(host: Node3D, name: String, rows: Array, xf: Transform3D) -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	for r: Array in rows:
		var lo := xf * Vector3(float(r[0]), float(r[1]), float(r[2]))
		var hi := xf * Vector3(float(r[3]), float(r[4]), float(r[5]))
		var d := hi - lo
		var b := Basis.looking_at(d.normalized(), Vector3.UP)
		LK.col_box(k, (lo + hi) * 0.5 - b.y * 0.12, Vector3(float(r[6]), 0.24, d.length()), b)
	k.commit(host, name)


static var _boxes_map: Dictionary = {}


static func _tbl(name: String) -> Array:
	if _boxes_map.is_empty():
		_boxes_map = (Boxes as Script).get_script_constant_map()
	return _boxes_map.get(name, []) as Array


static func _smoke(host: Node3D, at: Vector3, col: Color, count := 8) -> void:
	var smoke := Vfx.emitter(col, {"count": count, "life": 4.5, "speed": Vector2(0.2, 0.5), "size": 0.9, "gravity": 0.15, "radius": 0.6, "additive": false, "damping": 0.2})
	host.add_child(smoke)
	smoke.global_position = at
	smoke.emitting = true


static func _xf(s: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(s.yaw)), s.at)


static func _gy(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


static func _glow_mat(e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.6, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.58, 0.22)
	m.emission_energy_multiplier = e
	m.roughness = 0.3
	return m


# --- The Lamplighters' Spire -------------------------------------------------------------------------

static func _spire(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var xf := _xf(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37101
	# a plinth of the bluff's own rock round the foot: the tower never floats on a slope
	var lod0 := piece(host, SPIRE, "Spire_LOD0", xf, Vector2(0, 115))
	piece(host, SPIRE, "Spire_LOD1", xf, Vector2(95, 320), false)
	var far_m := mesh(SPIRE, "Spire_Far")
	if far_m != null:
		FarDetail.register(host, far_m, xf, 290.0, null, false)
	cols(host, "SpireBody", _tbl("SPIRE_BOXES"), xf)
	ramps(host, "SpireStair", _tbl("SPIRE_RAMPS"), xf)
	Interiors.add("lamp_spire", xf * Vector3(0, 7.0, 0), xf.basis.get_euler().y, Vector3(2.5, 7.0, 2.5), false)       # a cold stair, its candles warm
	for ly: float in [1.6, 5.4, 9.2]:
		Interiors.light(host, "SpireCandles", xf * Vector3(0, ly, 1.6), Interiors.CANDLE, 1.3, 5.5, false, 0.1)
	_plinth(host, space, xf)
	# rock heaped at the foot, round the three sides the door is not on
	for i in 7:
		var a := float(i) / 7.0 * TAU + rng.randf() * 0.4
		var q := Vector3(cos(a) * 6.4, 0.0, sin(a) * 6.4)
		if q.z > 3.0 and absf(q.x) < 3.5:
			continue
		var w := xf * q
		w.y = _gy(space, w.x, w.z) - 0.3
		P._rock(host, w, Vector3(2.2, 1.6, 2.0) * rng.randf_range(0.8, 1.3), "ash", 20 + i, rng.randf() * TAU)
	# the great lamp: dark until the wanderer lights it
	var lamp_at := xf * Vector3(0, LAMP_Y - 0.7, 0)
	var state := {"lit": State.has("open", "spire_lamp")}
	var glass_mat := _glow_mat(3.2)
	var flame := MeshInstance3D.new()
	flame.name = "LampFlame"
	var qm := QuadMesh.new()
	qm.size = Vector2(1.5, 2.2)
	flame.mesh = qm
	flame.material_override = Kit.shader_mat("glint")
	flame.set_instance_shader_parameter(&"tint", Color(1.0, 0.72, 0.4))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(flame)
	flame.global_position = lamp_at + Vector3(0, 0.6, 0)
	var light := P._light(host, lamp_at + Vector3(0, 0.8, 0), Color(1.0, 0.68, 0.36), 2.6, 42.0)
	var bh: Array = [null]
	var apply := func(animate: bool) -> void:
		var on: bool = state.lit
		flame.visible = on
		light.visible = on
		if lod0 != null:
			for i in lod0.mesh.get_surface_count():
				var sm := lod0.mesh.surface_get_material(i)
				if sm != null and sm.resource_name == "lamp_glass":
					lod0.set_surface_override_material(i, glass_mat if on else null)
		if on and bh[0] == null:
			var b: Variant = Wayfinding.beacon(host, xf * Vector3(0, 0, 0), "", Color(1.0, 0.74, 0.4), 70.0, 0.5, LAMP_Y + 6.0, true, 110.0)
			if b is Node:
				bh[0] = b
				(b as Node).name = "Beacon_spire_lamp"
		if on and animate:
			Kit.play("chime", lamp_at, -2.0, 0.7)
			Kit.fx_sparks(lamp_at + Vector3.UP * 0.8, Color(1.6, 0.9, 0.4))
	apply.call(false)
	var t := Kit.touch(host, lamp_at + Vector3(0, 0.2, 1.1), "", func(_by: Node) -> void:
		if bool(state.lit):
			return
		state.lit = true
		State.mark("open", "spire_lamp")
		State.toast("The wick takes. The Lamplighters' lamp is lit again, for the first time in nine winters.")
		State.banner("the Spire is lit", "The Lamplighters' Spire")
		apply.call(true), 2.6)
	t.name = "LampSwitch"
	t.set("prompt_fn", func() -> String: return "" if bool(state.lit) else "Light the great lamp")
	lamp_node = t
	# the writing in it: the door, the keeper's log on the stair, the lamp's plate
	P._lore(host, "r37e_spire_door", xf * Vector3(2.4, 1.4, 4.6), xf * Vector3(1.3, 1.7, 4.2))
	P._lore(host, "r37e_spire_log", xf * Vector3(1.4, 2.0, 2.2))
	P._lore(host, "r37e_spire_plate", xf * Vector3(-1.3, LAMP_Y - 0.5, 1.9))
	P._grapple(host, xf * Vector3(0.0, 28.4, 4.25), xf * Vector3(0.0, 28.4, 3.0))
	P._perch(host, xf * Vector3(0.0, 28.3, 4.0), xf.basis.z, 26.0)
	host.set_meta("route", [xf * Vector3(0, 1.4, 6.0), xf * Vector3(0, 1.4, 3.2), xf * Vector3(-1.95, 1.4, 1.95), xf * Vector3(1.95, 27.0, -1.95), xf * Vector3(0.0, 27.4, 0.5)] as Array[Vector3])
	host.set_meta("walk", [true, true, true, true, true])
	host.set_meta("approach", xf * Vector3(0, 0.0, 7.5))


const PLINTH_CELL := 1.04
const PLINTH_BURY := 1.6

## The tower's slab (10.4 m square) and its steps were modelled on a level top and the bluff falls away
## under their edges: a column of dressed stone is built under each cell of the footprint down to its lowest
## ground (and well below, into it), so the base meets the land on every side, however it falls.
static func _plinth(host: Node3D, space: PhysicsDirectSpaceState3D, xf: Transform3D) -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	var cells: Array = []             # [centre x, centre z, size x, size z] in the tower's frame
	var half := 5.2
	var n := roundi(half * 2.0 / PLINTH_CELL)
	for ix in n:
		for iz in n:
			cells.append([-half + (float(ix) + 0.5) * PLINTH_CELL, -half + (float(iz) + 0.5) * PLINTH_CELL, PLINTH_CELL, PLINTH_CELL])
	for sx: float in [-1.2, 0.0, 1.2]:          # the steps in front of the door
		cells.append([sx, half + 1.0, 1.2, 2.0])
	for c: Array in cells:
		var lo := INF
		var cx: float = c[0]
		var cz: float = c[1]
		var hx: float = float(c[2]) * 0.5
		var hz: float = float(c[3]) * 0.5
		for dx: float in [-1.0, 0.0, 1.0]:
			for dz: float in [-1.0, 0.0, 1.0]:
				var w := xf * Vector3(cx + dx * hx, 0.0, cz + dz * hz)
				lo = minf(lo, _gy(space, w.x, w.z))
		var top := xf.origin.y + 0.06
		if lo > xf.origin.y - 0.05:
			continue
		var bottom := lo - PLINTH_BURY
		var mid := xf * Vector3(cx, 0.0, cz)
		mid.y = (top + bottom) * 0.5
		k.box("stone", mid, Vector3(float(c[2]) + 0.02, top - bottom, float(c[3]) + 0.02), xf.basis, true, 1.0)
	var holder := Node3D.new()
	holder.name = "SpirePlinth"
	host.add_child(holder)
	holder.global_transform = Transform3D.IDENTITY
	k.commit(holder, "Body")
	# the same stone as the tower above it, a shade paler: it stands in the tower's shadow
	var lit := (OssKit.mat("stone") as StandardMaterial3D).duplicate() as StandardMaterial3D
	lit.albedo_color = lit.albedo_color * 1.8
	for c in holder.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = lit


# --- The hamlet ---------------------------------------------------------------------------------------

## [mesh, local offset from the yard's centre (xz), yaw degrees]
const HOUSES := [["House_A", Vector2(-12, -6), 90.0], ["House_B", Vector2(-12, 10), 90.0], ["House_C", Vector2(13, -10), -90.0],
	["Drying_Shed", Vector2(14, 10), 90.0], ["Stall", Vector2(8, 10), 180.0]]
const HOUSE_COL := {"House_A": "HOUSE_A_BOXES", "House_B": "HOUSE_B_BOXES", "House_C": "HOUSE_C_BOXES", "Drying_Shed": "DRYING_SHED_BOXES", "Stall": "STALL_BOXES"}


static func _saltmarket(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var c: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 37201
	for h: Array in HOUSES:
		var off: Vector2 = h[1]
		var p := Vector3(c.x + off.x, c.y, c.z + off.y)
		p.y = _gy(space, p.x, p.z)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(h[2]))), p)
		piece(host, HAMLET, String(h[0]), xf, Vector2(0, 230), true, String(h[0]) in ["House_A", "House_B"])
		cols(host, String(h[0]) + "Body", _tbl(HOUSE_COL[h[0]]), xf)
		if String(h[0]) == "Stall":
			P._light(host, p + Vector3(0, 2.2, 0.4), Color(1.0, 0.62, 0.3), 0.9, 8.0)
			P._lore(host, "r37e_market_board", xf * Vector3(2.0, 1.0, 0.4))
		if String(h[0]) == "House_A" or String(h[0]) == "House_B":
			P._light(host, p + xf.basis * Vector3(0, 1.9, 3.3), Color(1.0, 0.66, 0.34), 0.7, 6.0)       # the hearth through the window
	# the yard: barrels and crates stacked against the houses' backs (nothing on the walks), heaps of salt
	var k := OssKit.new()
	k.keep_lanes = false
	var spots_xz: Array[Vector2] = [Vector2(-17, -9), Vector2(-17, -3.5), Vector2(-17, 13), Vector2(19, -14), Vector2(19, -7), Vector2(19, 15), Vector2(12, 15), Vector2(4, 16)]
	for i in spots_xz.size():
		var q := Vector3(c.x + spots_xz[i].x, 0, c.z + spots_xz[i].y)
		q.y = _gy(space, q.x, q.z)
		var a := rng.randf() * TAU
		if i % 2 == 0:
			k.box("wood", q + Vector3.UP * 0.4, Vector3(0.7, 0.8, 0.7), Basis(Vector3.UP, a), true, 0.7)
		else:
			k.box("wood", q + Vector3.UP * 0.3, Vector3(0.9, 0.6, 0.7), Basis(Vector3.UP, a), true, 0.72)
	var seat := Vector3(HAMLET_FIRE.x + 1.6, 0, HAMLET_FIRE.y + 0.8)
	seat.y = _gy(space, seat.x, seat.z)
	k.box("wood", seat + Vector3.UP * 0.2, Vector3(1.4, 0.4, 0.4), Basis(Vector3.UP, 0.3), false, 0.7)
	k.commit(host, "YardBody")
	for i in 3:
		var q2 := Vector3(c.x + [-15.0, 14.0, -2.0][i], 0, c.z + [18.0, 19.0, 21.0][i])
		q2.y = _gy(space, q2.x, q2.z)
		piece(host, WORKS, "Salt_Heap", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q2), Vector2(0, 140))
	P._lore(host, "r37e_salt_marker", Vector3(c.x + 1.0, _gy(space, c.x + 1.0, c.z - 15.0) + 1.0, c.z - 15.0))
	P._lore(host, "r37e_hearth_slate", Vector3(HAMLET_FIRE.x - 2.4, _gy(space, HAMLET_FIRE.x - 2.4, HAMLET_FIRE.y) + 0.9, HAMLET_FIRE.y - 1.0))


## Called by village.gd (after the outposts): the hamlet's walking nodes, anchors and edges, so its five
## people have routines round the fire, the stall, the doors and the drying shed. Returns true if laid.
static func hamlet(v: Node3D, space: PhysicsDirectSpaceState3D, node_xz: Dictionary, edges: Array) -> bool:
	if not spots.has("saltmarket") or "--no-r37-east" in OS.get_cmdline_user_args():
		return false
	var c: Vector3 = spots.saltmarket.at
	var f := HAMLET_FIRE
	var n := {
		"sm_fire": f + Vector2(-1.8, 0.6), "sm_seat": f + Vector2(1.6, 2.0), "sm_stall": Vector2(c.x + 8.0, c.z + 11.4), "sm_stall_w": Vector2(c.x + 4.6, c.z + 11.2),
		"sm_w1": f + Vector2(-5, -4), "sm_w2": f + Vector2(0, -7), "sm_w3": f + Vector2(-5, 4),
		"sm_door_a": Vector2(c.x - 8.0, c.z - 6.6), "sm_door_b": Vector2(c.x - 8.0, c.z + 10.8), "sm_door_c": Vector2(c.x + 8.4, c.z - 10.0),
		"sm_shed": Vector2(c.x + 11.0, c.z + 10.0),
	}
	for k: String in n:
		node_xz[k] = n[k]
	edges.append_array([["sm_fire", "sm_seat"], ["sm_fire", "sm_w1"], ["sm_w1", "sm_w2"], ["sm_w2", "sm_w3"], ["sm_w3", "sm_fire"],
		["sm_fire", "sm_stall_w"], ["sm_w3", "sm_stall_w"], ["sm_stall_w", "sm_stall"], ["sm_stall", "sm_shed"], ["sm_w2", "sm_shed"], ["sm_w1", "sm_door_a"], ["sm_w3", "sm_door_a"],
		["sm_w3", "sm_door_b"], ["sm_fire", "sm_door_b"], ["sm_w2", "sm_door_c"], ["sm_w1", "sm_door_c"], ["sm_seat", "sm_stall_w"]])
	var gy := _gy(space, f.x, f.y)
	var anchors: Dictionary = v.get("anchors")
	anchors["@sm_fire"] = Vector3(f.x, gy + 0.9, f.y)
	anchors["@stall"] = Vector3(c.x + 8.0, _gy(space, c.x + 8.0, c.z + 9.4) + 1.0, c.z + 9.4)
	anchors["@sm_shed"] = Vector3(c.x + 14.0, _gy(space, c.x + 14.0, c.z + 10.0) + 1.4, c.z + 10.0)
	anchors["@spire"] = Vector3(240.0, 26.0, 8.0)
	anchors["@out_sm"] = Vector3(f.x + 6.0, gy + 1.4, f.y - 12.0)
	var oa: Dictionary = v.get("outpost_at")
	for who: String in ["marl", "ardel"]:
		oa[who] = Vector3(f.x, gy, f.y)
		anchors["@fire_" + who] = Vector3(f.x, gy + 0.2, f.y)
	return true


# --- The salt-works -----------------------------------------------------------------------------------

static func _saltworks(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var c: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 37301
	var at := func(dx: float, dz: float) -> Vector3:
		return Vector3(c.x + dx, _gy(space, c.x + dx, c.z + dz), c.z + dz)
	# the boiling hall, its door facing the pans
	var hx := Transform3D(Basis(Vector3.UP, -PI * 0.5), at.call(2.0, -14.0))
	piece(host, WORKS, "Works_Hall", hx, Vector2(0, 260))
	FarDetail.register(host, FarDetail.hull(AABB(Vector3(-8.0, 0.0, -5.0), Vector3(16.0, 11.0, 10.0)), 0.25), hx, 250.0, null, false)
	cols(host, "HallBody", _tbl("WORKS_HALL_BOXES"), hx)
	_smoke(host, hx * Vector3(5.0, 11.4, -1.0), Color(0.55, 0.55, 0.55), 8)
	P._light(host, hx * Vector3(-3.0, 3.4, 4.6), Color(1.0, 0.6, 0.3), 1.0, 9.0)
	P._lore(host, "r37e_works_ledger", hx * Vector3(1.6, 1.3, 4.0))
	P._lore(host, "r37e_works_gate", hx * Vector3(-5.5, 1.1, 5.2))
	# the pans: a grid, rakes left standing in them
	var pans: Array[Vector3] = []
	for col_x: float in [-10.0, 8.0]:
		for row_z: float in [2.0, 10.0]:
			var p: Vector3 = at.call(col_x, row_z)
			var px := Transform3D(Basis(Vector3.UP, 0.0), p)
			piece(host, WORKS, "Pan_Unit", px, Vector2(0, 150), false)
			cols(host, "PanBody", _tbl("PAN_BOXES"), px)
			pans.append(p)
	# three derricks reaching over the pans (their booms swing out over the brine)
	var derricks: Array[Vector3] = []
	for dd: Vector2 in [Vector2(-1.0, 6.0), Vector2(-1.0, -4.0), Vector2(17.0, 6.0)]:
		var dp: Vector3 = at.call(dd.x, dd.y)
		var dx := Transform3D(Basis(Vector3.UP, PI * (0.5 if dd.x < 10.0 else 1.5)), dp)
		piece(host, WORKS, "Derrick", dx, Vector2(0, 250))
		cols(host, "DerrickBody", _tbl("DERRICK_BOXES"), dx)
		derricks.append(dp)
	for i in 5:
		var hp: Vector3 = at.call(rng.randf_range(-16.0, 16.0), rng.randf_range(-4.0, 18.0))
		var near := false
		for pp in pans:
			if absf(hp.x - pp.x) < 4.6 and absf(hp.z - pp.z) < 3.4:
				near = true
		if not near:
			piece(host, WORKS, "Salt_Heap", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), hp), Vector2(0, 150))
	s["derricks"] = derricks
	s["pans"] = pans
	spots["saltworks"] = s
	host.set_meta("derricks", derricks)
	host.set_meta("approach", at.call(-4.0, -6.0))


static func _crust(host: Node3D, space: PhysicsDirectSpaceState3D, s: Dictionary) -> void:
	var c: Vector3 = s.at
	var rng := RandomNumberGenerator.new()
	rng.seed = 37401
	for i in 15:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 7.0
		var q := Vector3(c.x + cos(a) * r, 0, c.z + sin(a) * r)
		q.y = _gy(space, q.x, q.z) - 0.05
		var big := i == 0
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (2.6 if big else rng.randf_range(0.7, 1.5))), q if not big else Vector3(c.x, _gy(space, c.x, c.z) - 0.05, c.z))
		piece(host, WORKS, "Crystal_A" if i % 2 == 0 else "Crystal_B", xf, Vector2(0, 190))
		if big or r < 3.0:
			var k := OssKit.new()
			k.keep_lanes = false
			LK.col_box(k, xf.origin + Vector3.UP * 0.9, Vector3(0.9, 1.8, 0.9) * (2.0 if big else 1.0), xf.basis.orthonormalized())
			k.commit(host, "CrystalBody")
	P._lore(host, "r37e_crust_slate", Vector3(c.x - 5.0, _gy(space, c.x - 5.0, c.z + 3.0) + 0.9, c.z + 3.0))


# --- The Anchorholds ----------------------------------------------------------------------------------

static func _anchorholds(holder: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var raid := RealmLayout.raid("anchorhold")
	if raid.is_empty():
		return
	var rc: Vector2 = raid.c
	var ry := float(raid.y)
	var C := Vector3(rc.x, ry, rc.y)
	var host := Node3D.new()
	host.name = "Poi_anchorholds"
	host.set_meta("site", "poi_anchorholds")
	holder.add_child(host)
	host.add_to_group(P.GROUP_POI)
	host.set_meta("poi", "anchorholds")
	host.set_meta("title", "The Anchorholds")
	host.set_meta("line", "walled in to pray the sky still")
	host.set_meta("region", "anchorholds")
	host.set_meta("centre", C)
	host.set_meta("radius", float(raid.r) + 14.0)
	host.set_meta("r37", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 37501
	# the floor's true height (the raid terrace is levelled to ry; read it back)
	var fy := _gy(space, C.x, C.z)
	C.y = fy
	# the cairns: four hermits' stones in the floor (the lee of the Undertow); the room carries them
	var room := Node3D.new()
	room.name = "AnchorholdRoom"
	host.add_child(room)
	cairns.clear()
	var k := OssKit.new()
	k.keep_lanes = false
	for i in 4:
		var a := deg_to_rad(45.0 + 90.0 * float(i)) + 0.18
		var q := Vector3(C.x + cos(a) * 9.6, 0, C.z + sin(a) * 9.6)
		q.y = _gy(space, q.x, q.z)
		cairns.append(q)
		var yaw := a
		for j in 5:
			var w := 2.3 - 0.36 * float(j)
			k.box("stone", q + Vector3(rng.randf_range(-0.08, 0.08), 0.35 + 0.62 * float(j), rng.randf_range(-0.08, 0.08)), Vector3(w, 0.62, w * 0.9),
				Basis(Vector3.UP, yaw + rng.randf_range(-0.3, 0.3)), true, 0.8)
		k.box("iron", q + Vector3(0, 3.55, 0), Vector3(0.14, 0.4, 0.14), Basis.IDENTITY, false, 0.8)
	k.commit(room, "CairnBody")
	room.set_meta("cairns", cairns.duplicate())
	# the cliff: portals cut into its face, the timber walk over the rim, the chapel at the north
	_cells(host, space, C, float(raid.r))
	# the boss: the arena on the floor, its beacon, the room, what it leaves
	var script := load(ANCHORESS) as GDScript
	var arena := BossArena.make(host, "r37_anchoress", "The Anchoress", C, float(raid.r) - 1.0, script, C + Vector3(0, 0.1, -5.5))
	arena.room = room
	arena.ceiling = 10.0
	arena.max_rise = 2.6
	arena.subtitle = "walled in to pray the sky still"
	arena.on_slain = func(fresh: bool) -> void:
		if fresh:
			Events.toast.emit("The chain goes slack. Somewhere in the rock a cell door swings open, and stays open.")
	var bc: Variant = Wayfinding.beacon(host, C, "r37_anchoress", Color(1.0, 0.66, 0.36), 46.0, 0.4, 14.0, false, 260.0)
	if bc is Node:
		(bc as Node).name = "Beacon_r37_anchoress"
	# a chest in the first cell, a page at the gate
	var gate: Vector2 = raid.gate
	var gy := _gy(space, gate.x, gate.y)
	P._lore(host, "r37e_anchor_gate", Vector3(gate.x + 1.6, gy + 1.0, gate.y + 0.6))
	var cell_y := fy + 0.4
	var ch := P._chest(host, "anchorhold_cell", Vector3(C.x + 12.0 * cos(deg_to_rad(-60.0)), cell_y, C.z + 12.0 * sin(deg_to_rad(-60.0))), deg_to_rad(120.0))
	if ch:
		ch.set("tier", "iron")
		ch.set("loot", {"grave_ash": 16, "relic_fragment": 1, "ember_shard": 1})
	built.append("anchorholds")
	print("REALM_POI r37e anchorholds arena at %s r %.1f cairns %s" % [C.snapped(Vector3.ONE * 0.1), float(raid.r) - 1.0, cairns.size()])


## Raycast the face at `y` from inside the floor outward along `ang` (radians, xz): [point, outward normal] or [].
static func _face(space: PhysicsDirectSpaceState3D, C: Vector3, ang: float, y: float, r0: float) -> Array:
	var dir := Vector3(cos(ang), 0, sin(ang))
	var from := Vector3(C.x, y, C.z) + dir * r0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 26.0, GROUND))
	if not hit.is_empty():
		var n: Vector3 = hit.normal
		n.y = 0.0
		if n.length() < 0.2:
			n = -dir
		return [hit.position as Vector3, n.normalized()]
	# the terrace's collider may not be in the physics space yet (built this frame): march the designed
	# landform (RealmLayout.macro_height, which carries the raid floor) to where it climbs past `y`
	var r := r0
	while r < r0 + 26.0:
		var p := C + dir * r
		if RealmLayout.macro_height(p.x, p.z) > y:
			var gx := RealmLayout.macro_height(p.x + 1.0, p.z) - RealmLayout.macro_height(p.x - 1.0, p.z)
			var gz := RealmLayout.macro_height(p.x, p.z + 1.0) - RealmLayout.macro_height(p.x, p.z - 1.0)
			var n2 := Vector3(-gx, 0.0, -gz)
			if n2.length() < 0.05:
				n2 = -dir
			return [Vector3(p.x, y, p.z), n2.normalized()]
		r += 0.5
	return []


static func _cells(host: Node3D, space: PhysicsDirectSpaceState3D, C: Vector3, r: float) -> void:
	var made := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 37601
	# the lower cells, on the floor against the face; the upper cells and the timber walk 4.6 m over it
	for lvl in 2:
		var y := C.y + (0.2 if lvl == 0 else TERRACE_UP)
		for deg: float in [-160.0, -140.0, -120.0, -60.0, -20.0]:
			var ang := deg_to_rad(deg + (rng.randf_range(-4.0, 4.0)))
			var f := _face(space, C, ang, y + 1.6, r - 6.0)
			if f.is_empty():
				continue
			var p: Vector3 = f[0]
			var n: Vector3 = f[1]
			var xf := Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), Vector3(p.x, y - (0.0 if lvl == 0 else 0.0), p.z) + n * 0.3)
			if lvl == 0:
				xf.origin.y = _gy(space, xf.origin.x, xf.origin.z)
			piece(host, CELLS, "Cell_Portal" if (made + lvl) % 3 != 2 else "Cell_Slit", xf, Vector2(0, 160))
			if (made + lvl) % 3 != 2:
				cols(host, "CellBody", _tbl("CELL_PORTAL_BOXES"), xf)
			made += 1
			if made == 2:
				P._lore(host, "r37e_cell_scratch", xf * Vector3(-2.0, 1.2, 1.0))
			if made == 5:
				P._lore(host, "r37e_cell_ledger", xf * Vector3(2.0, 1.2, 1.0))
	print("REALM_POI r37e cells: %d portals/slits" % made)
	# the chapel: at the north-east (the north rim is the world's edge), on the floor, its face to the arena
	var cf := _face(space, C, deg_to_rad(-40.0), C.y + 2.0, r - 8.0)
	if not cf.is_empty():
		var cn: Vector3 = cf[1]
		var cp: Vector3 = cf[0] + cn * 0.7
		cp.y = _gy(space, cp.x, cp.z)
		var cxf := Transform3D(Basis(Vector3.UP, atan2(cn.x, cn.z)), cp)
		print("REALM_POI r37e chapel at %s" % [cxf.origin.snapped(Vector3.ONE * 0.1)])
		piece(host, CELLS, "Chapel_Front", cxf, Vector2(0, 260))
		FarDetail.register(host, FarDetail.hull(AABB(Vector3(-4.0, 0.0, -1.0), Vector3(8.0, 9.5, 2.0)), 0.3), cxf, 250.0, null, false)
		cols(host, "ChapelBody", _tbl("CHAPEL_BOXES"), cxf)
		P._lore(host, "r37e_chapel_lintel", cxf * Vector3(2.4, 1.0, 2.2))
		P._light(host, cxf * Vector3(0, 2.4, 1.6), Color(1.0, 0.7, 0.4), 0.7, 7.0)
	# the timber walk over the rim: spans on posts along r - 1.4, a stair up at the west end
	var wr := r - 1.0
	var ws := 2.4
	var a0 := deg_to_rad(-170.0)
	var a1 := deg_to_rad(-10.0)
	var steps := int((a1 - a0) * wr / 3.0)
	var spans := 0
	for i in steps:
		var a := a0 + (a1 - a0) * (float(i) + 0.5) / float(steps)
		var pos := Vector3(C.x + cos(a) * wr, C.y + TERRACE_UP, C.z + sin(a) * wr)
		var tang := Vector3(-sin(a), 0, cos(a))
		var xf := Transform3D(Basis(Vector3.UP, atan2(tang.x, tang.z)), pos)
		# only where the walk has ground beneath it to stand on, or a cliff behind to hang from
		var back := _face(space, C, a, C.y + TERRACE_UP, wr)
		if back.is_empty():
			continue
		piece(host, CELLS, "Walk_Span", xf, Vector2(0, 150))
		cols(host, "WalkBody", _tbl("WALK_SPAN_BOXES"), xf)
		spans += 1
		var k := OssKit.new()
		k.keep_lanes = false
		var ground_y := _gy(space, pos.x, pos.z)
		for sx: float in [-0.7, 0.7]:
			var pp := pos + xf.basis * Vector3(sx, 0, 0)
			k.box("wood", Vector3(pp.x, (pos.y - 0.2 + ground_y) * 0.5, pp.z), Vector3(0.22, maxf(pos.y - 0.2 - ground_y, 0.2), 0.22), Basis.IDENTITY, false, 0.7)
		k.commit(host, "WalkPosts")
		if i == steps / 2:
			P._lore(host, "r37e_walk_plate", xf * Vector3(0.9, 1.1, 0.0))
	print("REALM_POI r37e walk: %d spans over %d steps" % [spans, steps])
	# the stair at the walk's west end: its head meets the first span, its foot on the floor
	if steps > 0:
		var fa := a0 + (a1 - a0) * 0.5 / float(steps)
		var fp := Vector3(C.x + cos(fa) * wr, C.y, C.z + sin(fa) * wr)
		var ft := Vector3(-sin(fa), 0, cos(fa))
		var sxf := Transform3D(Basis(Vector3.UP, atan2(ft.x, ft.z)), fp - ft * 3.5)
		sxf.origin.y = _gy(space, sxf.origin.x, sxf.origin.z)
		piece(host, CELLS, "Walk_Stair", sxf, Vector2(0, 150))
		ramps(host, "WalkStair", _tbl("WALK_STAIR_RAMPS"), sxf)
		cols(host, "WalkStairRails", _tbl("WALK_STAIR_BOXES"), sxf)
		var lxf := Transform3D(Basis(Vector3.UP, atan2(ft.x, ft.z) + PI * 0.5), fp - ft * 3.5 + Vector3(0, 0, 0) + Basis(Vector3.UP, atan2(ft.x, ft.z)) * Vector3(1.6, 0, 1.0))
		lxf.origin.y = sxf.origin.y
		piece(host, CELLS, "Ladder_4m", lxf, Vector2(0, 120), false)
