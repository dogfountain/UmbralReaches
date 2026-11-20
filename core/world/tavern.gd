class_name Tavern
extends Node3D
## The Hollow Lantern: a two-storey coaching inn east of the sanctuary. Built from OssKit pieces on
## the world metrics (Metrics), in the plan's placement order:
##   1. measure the ground under the footprint, 2. register the site + its path (WorldLanes),
##   3. (TerrainStamp cuts the site; grass and props avoid it), 4. foundation below grade,
##   5. layered shell: stone ground floor -> jettied timber upper -> slate gable roof -> chimney,
##   6. interior (walk-in): hearth, bar, tables, chandelier, candles.
## Everything is world space; the node sits at the origin.

const X0 := 10.0
const X1 := 26.0                      ## 16 m frontage
const Z0 := 25.6
const Z1 := 34.8
const FY := -0.7                      ## floor top
const T := 0.55                       ## stone wall
const H1 := Metrics.STOREY            ## ground storey
const JET := 0.35                     ## upper storey overhang
const H2 := 2.6
const GLOW_ONE := preload("res://world/areas/ossuary/oss_glow_one.gdshader")      ## the kit's lit glass, drawn from outside only
const DOOR_X := 17.6                  ## south door centre (east of the giant trunk's roots at x <= 14.7)
const CHIM := Rect2(26.0, 29.4, 1.1, 1.6)

var _rng := RandomNumberGenerator.new()
const Props := preload("res://core/world/realm/site_props.gd")
## Modelled furniture (tools/blender/props_square.py, art/models/props/): glb file -> [Transform3D], drawn as one
## MultiMesh per (file, material set) when the build is done (_place_props). Colliders stay in the kit.
var _props := {}


## Start making every rig mesh the Keg will ask for on worker threads (cache misses only); the Realm
## starts it with the load and prewarm_rigs() collects it.
static func warm_start() -> Dictionary:
	var warm: Array = []
	for i in PATRONS.size():
		var sd := 911 + i * 37
		warm.append({"seated": bool(PATRONS[i][3]), "seed": sd, "hat": String(PATRONS[i][4])})
		if WANDERERS.has(i) and bool(PATRONS[i][3]):
			warm.append({"seated": false, "seed": sd, "hat": String(PATRONS[i][4])})
	warm.append({"seated": false, "seed": 5150, "apron": true, "hat": "bare", "rag": true})
	return DwarfRig.warm_start(warm)


## Wait for the Keg's rig meshes (started by the Realm, or started here when it is not running).
static func prewarm_rigs(root: Node) -> void:
	var h: Dictionary = DwarfRig.warm_batches.get("tavern", {})
	if h.is_empty():
		h = warm_start()
	await DwarfRig.warm_finish(h, root.get_tree())


static func build(root: Node) -> Tavern:
	if root.get_node_or_null("HollowLantern") != null:
		return null
	(load("res://core/npc/npc_voice.gd") as GDScript).call("prewarm", ["dwarf", "keep"])   # the Keg's voices, at load
	var t := Tavern.new()
	t.name = "HollowLantern"
	t.set_meta("site", "tavern")
	root.add_child(t)
	t._build()
	return t


## The night is torn down: the Keg's people let go of their static materials and voice banks.
func _exit_tree() -> void:
	(load("res://core/npc/dwarf_look.gd") as GDScript).call("release")
	(load("res://core/npc/npc_voice.gd") as GDScript).call("release")


func _ground_range(space: PhysicsDirectSpaceState3D, r: Rect2) -> Vector2:
	var lo := INF
	var hi := -INF
	var x := r.position.x
	while x <= r.end.x + 0.01:
		var z := r.position.y
		while z <= r.end.y + 0.01:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -30, z), Layers.WORLD))
			if hit:
				lo = minf(lo, (hit.position as Vector3).y)
				hi = maxf(hi, (hit.position as Vector3).y)
			z += 1.0
		x += 1.0
	return Vector2(lo if lo < INF else FY - 1.0, hi if hi > -INF else FY)


func _build() -> void:
	_rng.seed = 7341
	var space := get_world_3d().direct_space_state
	var site := Rect2(X0 - 0.2, Z0 - 0.6, (CHIM.end.x + 0.2) - (X0 - 0.2), (Z1 + 0.6) - (Z0 - 0.6))
	var porch := Rect2(DOOR_X - 1.2, Z0 - 4.4, 2.4, 3.8)
	var g := _ground_range(space, site)
	WorldLanes.register_site("tavern", site, FY, FY - 0.3)

	WorldLanes.register_site("tavern_porch", porch, FY, FY - 0.3)
	WorldLanes.register_portal("tavern_door", Vector3(DOOR_X, FY, Z0 - 1.4), Vector3.FORWARD)
	WorldLanes.register_lane("tavern_path", [Vector2(3.0, 18.0), Vector2(12.0, 18.0), Vector2(DOOR_X, 21.0), Vector2(DOOR_X, 22.6)], 1.0)
	var k := OssKit.new()
	k.candle_lights = false                  # the room has its own lit pools (_lights)
	k.under_shade = 0.88                     # rafters and the ceiling take the hearth instead of a black grid
	_yard_wall(k, space)
	# --- foundation and floor --------------------------------------------------------------
	k.foundation("stone", Vector2(X0 - 0.05, Z0 - 0.05), Vector2(X1 + 0.05, Z1 + 0.05), FY, g.x)
	k.block("floor", Vector3(X0 + T, FY - 0.2, Z0 + T), Vector3(X1 - T, FY + 0.001, Z1 - T))
	# --- ground storey: dressed stone, rectangular openings ---------------------------------
	var win := {"w": 1.0, "sill": 1.0, "top": 2.2, "glow": true}
	_wall(k, "stone", Vector3(X0, FY, Z0), Vector3(X1, FY, Z0), T, H1, [
		_o(win, 1.8), _o(win, 4.8), _o(win, 10.6), _o(win, 13.6), {"at": DOOR_X - X0, "w": Metrics.DOOR.x, "sill": 0.0, "top": Metrics.DOOR.y, "door": true}])
	_wall(k, "stone", Vector3(X1, FY, Z1), Vector3(X0, FY, Z1), T, H1, [_o(win, 2.2), _o(win, 5.6), _o(win, 10.4), _o(win, 13.8)])
	_wall(k, "stone", Vector3(X0, FY, Z1), Vector3(X0, FY, Z0), T, H1, [_o(win, 2.2), _o(win, 6.8)])
	_wall(k, "stone", Vector3(X1, FY, Z0), Vector3(X1, FY, Z1), T, H1, [])
	# quoins: larger corner stones, alternating, catching light on the arris
	for c: Vector2 in [Vector2(X0, Z0), Vector2(X1, Z0), Vector2(X0, Z1), Vector2(X1, Z1)]:
		var y := FY + 0.15
		var i := 0
		while y < FY + H1 - 0.2:
			var lx := 0.5 if i % 2 == 0 else 0.3
			var lz := 0.3 if i % 2 == 0 else 0.5
			k.box("stone", Vector3(c.x, y + 0.17, c.y), Vector3(T + lx, 0.34, T + lz), Basis.IDENTITY, false, 0.86)
			y += 0.38
			i += 1
	# --- jettied timber upper storey ------------------------------------------------------
	var uy := FY + H1
	var ux0 := X0 - JET
	var ux1 := X1 + JET
	var uz0 := Z0 - JET
	var uz1 := Z1 + JET
	k.block("wood", Vector3(X0 + 0.1, uy, Z0 + 0.1), Vector3(X1 - 0.1, uy + 0.28, Z1 - 0.1))       # floor/ceiling slab
	for i in 15:                                                    # joist ends carrying the jetty
		var x := lerpf(X0 + 0.4, X1 - 0.4, float(i) / 14.0)
		for zz: float in [Z0, Z1]:
			k.box("wood", Vector3(x, uy + 0.12, zz), Vector3(0.18, 0.2, JET * 2.0 + 0.3), Basis.IDENTITY, false, 0.8)
	k.block("wood", Vector3(ux0, uy + 0.22, uz0), Vector3(ux1, uy + 0.42, uz1), true, 0.75)       # sole plate
	var up := {"w": 0.9, "sill": 0.7, "top": 1.8, "glow": true}
	var tim := 0.22
	_wall(k, "plaster", Vector3(ux0, uy + 0.42, uz0), Vector3(ux1, uy + 0.42, uz0), tim, H2 - 0.42, [_o(up, 2.4), _o(up, 5.6), _o(up, 8.8), _o(up, 12.0), _o(up, 14.8)], 0.0)
	_wall(k, "plaster", Vector3(ux1, uy + 0.42, uz1), Vector3(ux0, uy + 0.42, uz1), tim, H2 - 0.42, [_o(up, 3.0), _o(up, 6.5), _o(up, 10.2), _o(up, 13.7)], 0.0)
	_wall(k, "plaster", Vector3(ux0, uy + 0.42, uz1), Vector3(ux0, uy + 0.42, uz0), tim, H2 - 0.42, [_o(up, 2.8), _o(up, 7.0)], 0.0)
	_wall(k, "plaster", Vector3(ux1, uy + 0.42, uz0), Vector3(ux1, uy + 0.42, uz1), tim, H2 - 0.42, [], 0.0)
	_timber_frame(k, Vector3(ux0, uy + 0.42, uz0), Vector3(ux1, uy + 0.42, uz0), H2 - 0.42, Vector3.BACK * -1.0)
	_timber_frame(k, Vector3(ux1, uy + 0.42, uz1), Vector3(ux0, uy + 0.42, uz1), H2 - 0.42, Vector3.BACK)
	_timber_frame(k, Vector3(ux0, uy + 0.42, uz1), Vector3(ux0, uy + 0.42, uz0), H2 - 0.42, Vector3.LEFT)
	_timber_frame(k, Vector3(ux1, uy + 0.42, uz0), Vector3(ux1, uy + 0.42, uz1), H2 - 0.42, Vector3.RIGHT)
	# --- slate gable roof (ridge along X) -----------------------------------------------
	var ey := uy + H2
	var ry := ey + 3.6
	var ov := 0.55
	var rx0 := ux0 - 0.45
	var rx1 := ux1 + 0.45
	var zm := (Z0 + Z1) * 0.5
	for s: float in [-1.0, 1.0]:
		var ze := (uz0 - ov) if s < 0.0 else (uz1 + ov)
		var drop := ov * (ry - ey) / (zm - uz0)        # keep the pitch past the wall line
		var slope := Vector3(0.0, ry - (ey - drop), zm - ze)
		var out := Vector3.RIGHT.cross(slope).normalized()
		if out.y < 0.0:
			out = -out
		var sb := Basis(Vector3.RIGHT, out, Vector3.RIGHT.cross(out).normalized())
		var a := Vector3(rx0, ey - drop, ze)
		var b := Vector3(rx1, ey - drop, ze)
		var c := Vector3(rx1, ry, zm)
		var d := Vector3(rx0, ry, zm)
		k.quad("slate", a, b, c, d, out)
		var th := 0.16
		k.quad("wood", a + Vector3.DOWN * th, b + Vector3.DOWN * th, c + Vector3.DOWN * th, d + Vector3.DOWN * th, -out, false)
		k.quad("slate", a, b, b + Vector3.DOWN * th, a + Vector3.DOWN * th, Vector3(0, 0, s), false)       # eave edge
		# slate courses: thin proud strips every 0.45 m up the slope
		for i in 7:
			var t := (float(i) + 0.5) / 7.5
			var p0 := a.lerp(d, t)
			var p1 := b.lerp(c, t)
			k.box("slate", (p0 + p1) * 0.5 + out * 0.02, Vector3(p1.x - p0.x, 0.035, 0.42), sb, false, 0.85)
	k.box("wood", Vector3((rx0 + rx1) * 0.5, ry + 0.06, zm), Vector3(rx1 - rx0 + 0.1, 0.22, 0.3), Basis.IDENTITY, false, 0.7)   # ridge
	# gable ends: plaster triangles with a timber king post and bargeboards
	for gx: float in [ux0, ux1]:
		var s := -1.0 if gx == ux0 else 1.0
		k.quad("plaster", Vector3(gx, ey, uz0), Vector3(gx, ey, uz1), Vector3(gx, ry - 0.05, zm), Vector3(gx, ry - 0.05, zm), Vector3(s, 0, 0))
		k.quad("plaster", Vector3(gx - s * tim, ey, uz0), Vector3(gx - s * tim, ey, uz1), Vector3(gx - s * tim, ry - 0.05, zm), Vector3(gx - s * tim, ry - 0.05, zm), Vector3(-s, 0, 0), false)
		k.box("wood", Vector3(gx + s * 0.03, (ey + ry) * 0.5, zm), Vector3(0.06, ry - ey, 0.2), Basis.IDENTITY, false, 0.75)
		k.box("wood", Vector3(gx + s * 0.03, ey + 0.1, zm), Vector3(0.06, 0.2, uz1 - uz0), Basis.IDENTITY, false, 0.75)
		for zs: float in [-1.0, 1.0]:
			var e := Vector3(gx + s * 0.5, ey - 0.35, zm + zs * (zm - uz0 + ov))
			var r := Vector3(gx + s * 0.5, ry + 0.05, zm)
			var bz := (r - e).normalized()
			k.box("wood", (e + r) * 0.5, Vector3(0.08, 0.26, e.distance_to(r)), Basis(Vector3.RIGHT, bz.cross(Vector3.RIGHT).normalized(), bz), false, 0.7)
	# --- chimney on the east gable ----------------------------------------------------------
	var cb := minf(g.x, FY) - Metrics.FOUNDATION_BURY
	k.block("stone", Vector3(CHIM.position.x, cb, CHIM.position.y), Vector3(CHIM.end.x, ry + 1.3, CHIM.end.y), true, 0.9)
	k.block("stone", Vector3(CHIM.position.x - 0.1, ry + 1.1, CHIM.position.y - 0.1), Vector3(CHIM.end.x + 0.1, ry + 1.35, CHIM.end.y + 0.1), true, 0.8)
	for o: float in [-0.35, 0.35]:
		k.box("iron", Vector3(CHIM.get_center().x, ry + 1.6, CHIM.get_center().y + o), Vector3(0.28, 0.5, 0.28), Basis.IDENTITY, false, 0.6)
	# --- porch: landing + steps down to the path ---------------------------------------------
	var gy := _ground_range(space, Rect2(DOOR_X - 1.0, Z0 - 3.6, 2.0, 2.2))
	k.foundation("stone", Vector2(DOOR_X - 1.1, Z0 - 1.4), Vector2(DOOR_X + 1.1, Z0), FY, gy.x)
	var rise := FY - gy.y
	if rise > 0.12:
		var n := Metrics.steps_for(rise)
		k.stairs("stone", Vector3(DOOR_X, gy.y, Z0 - 1.4 - Metrics.TREAD * float(n)), Vector3(DOOR_X, FY, Z0 - 1.4), 2.0, n, gy.x - Metrics.FOUNDATION_BURY)
	# --- interior ------------------------------------------------------------------------------
	_interior(k)
	# --- exterior dressing ---------------------------------------------------------------------
	_barrel(k, Vector3(X0 - 0.5, g.x, 27.0), 1.0)
	_barrel(k, Vector3(X0 - 0.45, g.x, 27.8), 0.9)
	_sign(k)
	var post := Vector3(DOOR_X + 1.6, gy.x, Z0 - 2.4)
	k.box("iron", post + Vector3.UP * 1.3, Vector3(0.1, 2.6, 0.1), Basis.IDENTITY, true)
	k.box("iron", post + Vector3(0, 2.5, -0.25), Vector3(0.06, 0.06, 0.5), Basis.IDENTITY, false)
	k.box("glow", post + Vector3(0, 2.25, -0.5), Vector3(0.22, 0.3, 0.22), Basis.IDENTITY, false)
	k.box("iron", post + Vector3(0, 2.43, -0.5), Vector3(0.3, 0.05, 0.3), Basis.IDENTITY, false)
	k.commit(self, "TavernBody")
	_place_props()
	_panes_one_sided()
	_warm_materials()
	print("SITES Tavern owns %d scatter nodes" % WorldLanes.own(self))   # its candles stand inside its sites
	_lights(post + Vector3(0, 2.2, -0.5))
	_patrons()
	print("TAVERN built: floor %.2f, ground %.2f..%.2f, rejected props %d" % [FY, g.x, g.y, k.rejected])


## The inn is cut into the foot of a terrace: where the ground east of it stands more than 0.8 m
## above the floor, a coped stone retaining wall holds the bank back and a level yard runs between
## it and the inn (a hard-edged site, so the cut stops at the wall instead of fading into a ditch).
const YARD_X := 29.0


func _yard_wall(k: OssKit, space: PhysicsDirectSpaceState3D) -> void:
	var segs: Array = []
	var z := Z0 - 1.6
	while z < Z1 + 1.6:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(YARD_X + 0.6, 40, z + 0.4), Vector3(YARD_X + 0.6, -30, z + 0.4), Layers.WORLD))
		var g: float = (hit.position as Vector3).y if hit else FY
		segs.append([z, g])
		z += 0.8
	var high := false
	for sg: Array in segs:
		if float(sg[1]) > FY + 0.8:
			high = true
	if not high:
		return
	WorldLanes.register_site("tavern_yard", Rect2(CHIM.end.x - 0.2, Z0 - 1.6, YARD_X - CHIM.end.x + 0.2, Z1 - Z0 + 3.2), FY, FY - 0.25, true)
	for sg: Array in segs:
		var top := maxf(float(sg[1]) + 0.35, FY + 1.0)
		k.block("stone", Vector3(YARD_X, FY - 0.8, float(sg[0])), Vector3(YARD_X + 0.9, top, float(sg[0]) + 0.81), true, 0.86)
		k.block("stone", Vector3(YARD_X - 0.08, top, float(sg[0]) - 0.01), Vector3(YARD_X + 0.98, top + 0.16, float(sg[0]) + 0.82), true, 0.94)
	# buttresses every few metres, and returns at both ends so the bank never shows a raw edge
	for i in range(0, segs.size(), 4):
		var sg: Array = segs[i]
		k.block("stone", Vector3(YARD_X - 0.6, FY - 0.8, float(sg[0]) + 0.1), Vector3(YARD_X, maxf(float(sg[1]) - 0.2, FY + 0.6), float(sg[0]) + 0.7), true, 0.8)


static func _o(base: Dictionary, at: float) -> Dictionary:
	var d := base.duplicate()
	d["at"] = at
	return d


## Straight wall a->b (floor level, outer face on the a-b line, thickness inward), `h` tall,
## with rectangular openings {at (centre, m from a), w, sill, top, glow?, door?}.
func _wall(k: OssKit, key: String, a: Vector3, b: Vector3, t: float, h: float, openings: Array, lintel := 0.18) -> void:
	var along := (b - a).normalized()
	var inward := along.cross(Vector3.UP).normalized()
	var length := a.distance_to(b)
	var bas := Basis(along, Vector3.UP, inward)
	var seg := func(x0: float, x1: float, y0: float, y1: float) -> void:
		if x1 - x0 < 0.01 or y1 - y0 < 0.01:
			return
		var c := a + along * ((x0 + x1) * 0.5) + Vector3.UP * ((y0 + y1) * 0.5) + inward * (t * 0.5)
		k.box(key, c, Vector3(x1 - x0, y1 - y0, t), bas, true)
	var cursor := 0.0
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return float(p.at) < float(q.at))
	for o: Dictionary in ops:
		var x0: float = float(o.at) - float(o.w) * 0.5
		var x1: float = float(o.at) + float(o.w) * 0.5
		seg.call(cursor, x0, 0.0, h)
		seg.call(x0, x1, 0.0, float(o.sill))
		seg.call(x0, x1, float(o.top), h)
		var mid := a + along * float(o.at)
		if lintel > 0.0:
			k.box(key, mid + Vector3.UP * (float(o.top) + 0.12) + inward * (t * 0.5), Vector3(float(o.w) + 0.4, 0.24, t + 0.06), bas, false, 0.78)
			if float(o.sill) > 0.0:
				k.box(key, mid + Vector3.UP * (float(o.sill) - 0.04) + inward * (t * 0.5 - 0.05), Vector3(float(o.w) + 0.2, 0.08, t + 0.1), bas, false, 0.82)
		else:
			for s: float in [-1.0, 1.0]:                # timber window frame
				k.box("wood", mid + along * (s * (float(o.w) * 0.5 + 0.04)) + Vector3.UP * ((float(o.sill) + float(o.top)) * 0.5) - inward * 0.02, Vector3(0.1, float(o.top) - float(o.sill) + 0.16, t + 0.06), bas, false, 0.7)
			k.box("wood", mid + Vector3.UP * (float(o.sill) - 0.04) - inward * 0.02, Vector3(float(o.w) + 0.2, 0.09, t + 0.12), bas, false, 0.7)
		if o.get("glow", false):
			var pc := mid + inward * (t * 0.6) + Vector3.UP * ((float(o.sill) + float(o.top)) * 0.5)
			var hw := along * (float(o.w) * 0.5)
			var hh := Vector3.UP * ((float(o.top) - float(o.sill)) * 0.5)
			# its own surface (glow#pane): lit from the street, seen through from inside (_panes_one_sided)
			k.quad("glow#pane", pc - hw - hh, pc + hw - hh, pc + hw + hh, pc - hw + hh, -inward, false, 0.42)
			# leaded lights: a mullion, a transom, and a lattice of thin cames
			var hgt := float(o.top) - float(o.sill)
			k.box("iron", pc - inward * 0.02, Vector3(0.06, hgt, 0.06), bas, false, 0.5)
			k.box("iron", pc - inward * 0.02 + Vector3.UP * (hgt * 0.12), Vector3(float(o.w), 0.06, 0.06), bas, false, 0.5)
			for q in 5:
				var f := (float(q) + 0.5) / 5.0 - 0.5
				k.box("iron", pc - inward * 0.025 + Vector3.UP * (f * hgt), Vector3(float(o.w), 0.02, 0.02), bas, false, 0.4)
			for q: float in [-0.25, 0.25]:
				k.box("iron", pc - inward * 0.025 + along * (q * float(o.w)), Vector3(0.02, hgt, 0.02), bas, false, 0.4)
		if o.get("door", false):
			# heavy plank door standing open inward, hinged on the left jamb
			var hinge := a + along * x0 + inward * (t + 0.03)
			var leaf := Basis(Vector3.UP, deg_to_rad(-100.0)) * bas
			k.box("wood", hinge + leaf.x * (float(o.w) * 0.5) + Vector3.UP * (float(o.top) * 0.5), Vector3(float(o.w) - 0.05, float(o.top) - 0.05, 0.09), leaf, true, 0.8)
			for yy: float in [0.5, 2.0]:
				k.box("iron", hinge + leaf.x * (float(o.w) * 0.45) + Vector3.UP * yy - leaf.z * 0.05, Vector3(float(o.w) * 0.85, 0.06, 0.02), leaf, false)
			k.box("stone", mid + Vector3.UP * 0.03 + inward * (t * 0.5), Vector3(float(o.w), 0.06, t + 0.2), bas, false, 0.75)   # threshold
		cursor = x1
	seg.call(cursor, length, 0.0, h)


## Close-studded frame proud of a plaster wall: posts every ~1.1 m, rails, and K-braces.
func _timber_frame(k: OssKit, a: Vector3, b: Vector3, h: float, out: Vector3) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var bas := Basis(along, Vector3.UP, out.normalized())
	var face := out.normalized() * 0.03
	var n := maxi(2, roundi(length / 1.1))
	for i in n + 1:
		var x := length * float(i) / float(n)
		k.box("wood", a + along * x + Vector3.UP * (h * 0.5) + face, Vector3(0.16, h, 0.06), bas, false, 0.72)
	k.box("wood", a + along * (length * 0.5) + Vector3.UP * (h - 0.08) + face, Vector3(length, 0.16, 0.07), bas, false, 0.7)
	k.box("wood", a + along * (length * 0.5) + Vector3.UP * 0.55 + face, Vector3(length, 0.1, 0.06), bas, false, 0.74)
	for i in [0, n - 1]:
		var x0 := length * float(i) / float(n)
		var x1 := length * float(i + 1) / float(n)
		var p0 := a + along * x0 + Vector3.UP * 0.6
		var p1 := a + along * x1 + Vector3.UP * (h - 0.15)
		if i != 0:
			p0 = a + along * x1 + Vector3.UP * 0.6
			p1 = a + along * x0 + Vector3.UP * (h - 0.15)
		var d := p1 - p0
		var ang := atan2(d.y, d.dot(along))
		k.box("wood", (p0 + p1) * 0.5 + face, Vector3(d.length(), 0.14, 0.06), bas * Basis(Vector3.BACK, ang), false, 0.7)


func _interior(k: OssKit) -> void:
	var y := FY
	# hearth against the east wall
	var hx := X1 - T
	var hz := CHIM.get_center().y
	k.block("stone", Vector3(hx - 0.9, y, hz - 1.4), Vector3(hx, y + 0.3, hz + 1.4), true, 0.8)               # hearthstone
	for zz: float in [hz - 1.3, hz + 1.3]:
		k.block("stone", Vector3(hx - 0.55, y, zz - 0.2), Vector3(hx, y + 1.5, zz + 0.2), true, 0.88)   # cheeks
	k.block("stone", Vector3(hx - 0.7, y + 1.5, hz - 1.6), Vector3(hx, y + 1.75, hz + 1.6), true, 0.78)       # mantel
	k.block("stone", Vector3(hx - 0.45, y + 1.75, hz - 1.2), Vector3(hx, y + H1, hz + 1.2), true, 0.92)       # breast
	k.block("dark", Vector3(hx - 0.05, y + 0.3, hz - 1.1), Vector3(hx + 0.01, y + 1.5, hz + 1.1), false, 0.3)  # soot back
	k.box("glow", Vector3(hx - 0.3, y + 0.36, hz), Vector3(0.6, 0.1, 1.2), Basis.IDENTITY, false, 0.9)   # coals
	for i in 4:
		k.box("wood", Vector3(hx - 0.3, y + 0.45 + 0.07 * float(i % 2), hz - 0.4 + 0.25 * float(i)), Vector3(0.12, 0.12, 0.7), Basis(Vector3.UP, 0.4 * float(i) - 0.6), false, 0.5)
	k.candle_cluster(Vector3(hx - 0.35, y + 1.75, hz - 1.3), 3, 0.12, _rng)
	k.candle_cluster(Vector3(hx - 0.35, y + 1.75, hz + 1.3), 3, 0.12, _rng)
	# bar counter along the north wall, shelves behind
	var bz := Z1 - T
	k.collider(Vector3(15.0, y + 0.5, bz - 1.275), Vector3(7.2, 1.0, 0.55))
	k.collider(Vector3(15.0, y + 1.04, bz - 1.285), Vector3(7.4, 0.08, 0.73))
	for i in 6:                                     # the counter and the shelves behind it: six 1.2 m bays
		var bx := 12.0 + 1.2 * float(i)
		_prop("bar_counter", Transform3D(Basis.IDENTITY, Vector3(bx, y, bz - 1.285)))
		_prop("bar_shelf" if i % 2 == 0 else "bar_shelf_b", Transform3D(Basis.IDENTITY, Vector3(bx, y, bz - 0.175)))
	for c: float in [12.2, 15.2, 17.9]:
		k.candle_cluster(Vector3(c, y + 1.08, bz - 1.3), 3, 0.12, _rng)
	_barrel(k, Vector3(19.6, y, bz - 0.5), 1.0)
	_barrel(k, Vector3(20.4, y, bz - 0.55), 0.95)
	_barrel(k, Vector3(20.0, y + 0.86, bz - 0.5), 0.85, true)
	_barrel(k, Vector3(21.2, y, bz - 0.5), 1.0)
	k.box("iron", Vector3(19.6 - 0.34, y + 0.5, bz - 0.5), Vector3(0.12, 0.05, 0.05), Basis.IDENTITY, false, 0.6)   # tap
	k.box("iron", Vector3(19.6 - 0.39, y + 0.46, bz - 0.5), Vector3(0.03, 0.08, 0.03), Basis.IDENTITY, false, 0.6)
	# the keep's duckboard behind the counter (a dwarf at a 1.08 m bar), and a foot step in front
	k.block("wood", Vector3(11.4, y, bz - 0.92), Vector3(BAR_X1 + 0.6, y + DUCK, bz - 0.36), true, 0.62)
	k.block("wood", Vector3(11.6, y, bz - 2.05), Vector3(18.4, y + 0.22, bz - 1.66), true, 0.7)
	# two trestle tables with benches
	for tc: Vector2 in [Vector2(12.6, 28.9), Vector2(15.2, 29.6), Vector2(20.4, 28.9), Vector2(21.8, 31.8)]:
		_prop("tavern_table", Transform3D(Basis.IDENTITY, Vector3(tc.x, y, tc.y)))
		k.collider(Vector3(tc.x, y + 0.76, tc.y), Vector3(1.8, 0.08, 0.9))
		for s: float in [-1.0, 1.0]:
			k.collider(Vector3(tc.x + s * 0.7, y + 0.36, tc.y), Vector3(0.12, 0.72, 0.6))
			# the benches (1.5 m bench.glb drawn out to the table's 1.7 m)
			_prop("bench", Transform3D(Basis.IDENTITY.scaled(Vector3(1.13, 1.0, 0.85)), Vector3(tc.x, y, tc.y + s * 0.85)))
			k.collider(Vector3(tc.x, y + 0.445, tc.y + s * 0.85), Vector3(1.7, 0.05, 0.28))
		k.candle_cluster(Vector3(tc.x, y + 0.8, tc.y), 4, 0.18, _rng)
	for ch: Array in CHAIRS:
		_chair(k, Vector3(ch[0], y, ch[1]), float(ch[2]))
	# iron ring chandelier over the room
	for cx: float in [14.2, 20.6]:
		var cc := Vector3(cx, y + H1 - 0.75, 30.2)
		_prop("chandelier", Transform3D(Basis.IDENTITY, cc))
		for i in 8:                                  # a candle in each of its eight cups
			var a := TAU * float(i) / 8.0
			var p := cc + Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55)
			(k.candles[1] as Array).append(Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.03))
	# rushes / scattered straw on the floor near the door
	k.block("wood", Vector3(DOOR_X - 1.0, y + 0.001, Z0 + T + 0.1), Vector3(DOOR_X + 1.0, y + 0.02, Z0 + T + 1.4), false, 0.55)


## A stout chair facing `yaw` (0 = the sitter faces -z), seat top at 0.47 like the benches.
func _chair(k: OssKit, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	_prop("tavern_chair", Transform3D(b, at))
	k.collider(at + Vector3.UP * 0.445, Vector3(0.5, 0.05, 0.48), b)


## The room's regulars and the keep (core/npc), and the story director (core/story/story.gd).
## A seated DwarfRig has its origin on the floor and rests on a 0.47 m seat (benches and chairs both
## have their tops at 0.47), so seated patrons stand at floor level (`SEAT_Y` 0). Bench sitters sit
## on the bench's centre line, 0.85 m off the table's, with the board's edge 0.4 m in front of them;
## chair sitters sit 0.06 m forward of the chair's centre (clear of its back) with their feet tucked
## (clear of the trestle). Across-the-table neighbours drink as pairs (DwarfNpc.partner).
const SEAT_Y := 0.0
const DUCK := 0.3                     ## duckboard behind the bar
const BAR_X1 := 18.6
const STEP_Y := 0.22                  ## the foot step in front of the counter
const CHAIR_IN := 0.06
## [x, z, sitter yaw] chairs at table ends
const CHAIRS := [
	[12.6 - 1.32, 28.9, -PI * 0.5],
	[15.2 + 1.32, 29.6, PI * 0.5],
	[20.4 - 1.32, 28.9, -PI * 0.5],
	[21.8 + 1.32, 31.8, PI * 0.5],
]
const PATRONS := [
	# [x, z, yaw, seated, hat, seat ("bench"/"chair"/"bar"), talk id, name, partner index]
	[12.25, 28.9 + 0.85, 0.0, true, "helm", "bench", "hesk", "Hesk the Woodcutter", 1],
	[13.0, 28.9 - 0.85, PI, true, "hood", "bench", "", "", 0],
	[12.6 - 1.32, 28.9, -PI * 0.5, true, "", "chair", "", "", -1],
	[15.2 + 1.32, 29.6, PI * 0.5, true, "cap", "chair", "", "", 4],
	[15.5, 29.6 - 0.85, PI, true, "", "bench", "", "", 3],
	[20.1, 28.9 + 0.85, 0.0, true, "bare", "bench", "", "", 6],
	[20.75, 28.9 - 0.85, PI, true, "helm", "bench", "", "", 5],
	[21.8 + 1.32, 31.8, PI * 0.5, true, "", "chair", "brannoc", "Brannoc Bellwright", -1],
	[16.3, 32.34, PI, false, "hood", "bar", "harrow", "Ostrin Harrow", -1],
]
## Chair sitters who now and then get up for a refill: patron index -> route from beside the chair
## to their spot on the bar's foot step (last point, xz; the step is bz - 2.05 .. bz - 1.66), clear
## of the benches (DwarfNpc walks it, the keep serves them there).
const WANDERERS := {
	0: [Vector2(12.9, 31.0), Vector2(14.1, 33.34 - 1.0)],     # Hesk, north side of the first bench
	2: [Vector2(11.4, 31.3), Vector2(12.7, 33.34 - 1.0)],
	3: [Vector2(16.75, 31.3), Vector2(17.45, 33.34 - 1.0)],
}
const MAX_UP := 2                     ## never more than this many regulars out of their seats at once
const START_WAITS := [20.0, 45.0, 70.0]   ## first outings staggered: seconds from the Keg being built
## The keep's lane on the duckboard: his belly and apron (0.32 m in front of him) clears the counter's back
## edge (bz - 0.92) and his back (0.2 m) clears the shelves (bz - 0.35); zz/story_test checks both.
const KEEP_IN := 0.575


func _patrons() -> void:
	var y := FY
	var bz := Z1 - T
	var npcs: Array[DwarfNpc] = []
	for i in PATRONS.size():
		var pt: Array = PATRONS[i]
		var d := DwarfNpc.new()
		d.wanders = WANDERERS.has(i)
		d.name = "Patron%d" % i
		d.facing = float(pt[2])
		d.seed_n = 911 + i * 37
		d.seated = bool(pt[3])
		d.hat = String(pt[4])
		d.talk_id = String(pt[6])
		d.display_name = String(pt[7]) if String(pt[7]) != "" else "Patron"
		var at := Vector3(float(pt[0]), y + SEAT_Y, float(pt[1]))
		var fwd := Vector3(-sin(d.facing), 0.0, -cos(d.facing))
		match String(pt[5]):
			"chair":
				at += fwd * CHAIR_IN
				d.table_edge = -(1.32 - 0.9 - CHAIR_IN)
				d.table_top = 0.8
				d.tuck = true
			"bench":
				d.table_edge = -0.4
				d.table_top = 0.8
			"bar":
				at.y = y + STEP_Y
				d.lean_bar = true
				d.table_top = 1.08 - STEP_Y
				d.table_edge = -absf((bz - 1.65) - at.z)
		add_child(d)
		d.global_position = at
		npcs.append(d)
	for i in PATRONS.size():
		var pidx := int(PATRONS[i][8])
		if pidx >= 0:
			npcs[i].partner = npcs[pidx]
			npcs[i].leader = i < pidx
	var keep := Bartender.new()
	keep.name = "Keep"
	keep.lane_x = Vector2(12.0, BAR_X1 - 0.25)
	keep.lane_z = bz - KEEP_IN
	keep.bar_y = y + 1.08
	keep.bar_z = bz - 0.92
	keep.keg = Vector3(19.6 - 0.42, y + 0.48, bz - 0.5)
	keep.regular = npcs[8]
	add_child(keep)
	keep.global_position = Vector3(15.0, y + DUCK, bz - KEEP_IN)
	for i: int in WANDERERS:
		var w: Array = WANDERERS[i]
		npcs[i].keep = keep
		npcs[i].bar_top = 1.08 - STEP_Y
		npcs[i].bar_edge = -absf((bz - 1.65) - (bz - 1.91))
		for p: Vector2 in w:
			npcs[i].route.append(Vector3(p.x, y, p.y))
		npcs[i].route[npcs[i].route.size() - 1].y = y + STEP_Y
	_stagger = []
	var n := 0
	for i: int in WANDERERS:
		npcs[i].set("_trip_wait", float(START_WAITS[n % START_WAITS.size()]))
		_stagger.append(npcs[i])
		n += 1
	var gate := Timer.new()
	gate.name = "OutingGate"
	gate.wait_time = 0.5
	gate.autostart = true
	gate.timeout.connect(_gate_outings)
	add_child(gate)
	var story: Node = load("res://core/story/story.gd").new()
	story.name = "Story"
	add_child(story)
	# songs, dice and arguments among the regulars (core/npc/keg_scenes.gd)
	var scenes: Node = load("res://core/npc/keg_scenes.gd").new()
	scenes.name = "KegScenes"
	scenes.set("patrons", npcs)
	scenes.set("keep", keep)
	add_child(scenes)


var _stagger: Array[DwarfNpc] = []


## Staggers the regulars' outings: while MAX_UP of them are away, anyone about to rise waits a little longer.
func _gate_outings() -> void:
	var up := 0
	for d in _stagger:
		if is_instance_valid(d) and d.away:
			up += 1
	if up < MAX_UP:
		return
	for d in _stagger:
		if is_instance_valid(d) and not d.away and float(d.get("_trip_wait")) < 3.0:
			d.set("_trip_wait", 3.0 + randf() * 3.0)


func _barrel(_k: OssKit, at: Vector3, s := 1.0, lying := false) -> void:
	if lying:                                       # on the rack: barrel_tipped.glb lies along x, turned along z
		_prop("barrel_tipped", Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * s), at))
	else:
		_prop("barrel", Transform3D(Basis(Vector3.UP, at.x * 1.7).scaled(Vector3.ONE * s), at))


func _prop(file: String, xf: Transform3D) -> void:
	if not _props.has(file):
		_props[file] = []
	(_props[file] as Array).append(xf)


## One MultiMesh per (model, material set): the whole Keg's furniture is a dozen draws.
func _place_props() -> void:
	for file: String in _props:
		var xfs: Array = _props[file]
		var i := 0
		for part: Dictionary in Props.parts_indoor(file):
			var mmi := OssKit.multimesh(part.mesh, xfs, part.mat, not file.begins_with("bar_shelf"))
			mmi.name = "Prop_%s_%d" % [file, i]
			add_child(mmi)
			i += 1


func _sign(k: OssKit) -> void:
	var at := Vector3(DOOR_X - 1.5, FY + H1 + 0.1, Z0 - JET)
	_prop("inn_sign", Transform3D(Basis.IDENTITY, at))
	k.box("glow", at + Vector3(0, -0.5, -0.95), Vector3(0.2, 0.26, 0.08), Basis(Vector3.UP, PI * 0.5), false, 0.7)   # painted lantern


## The window glass glows warm to the street but is only drawn from outside: from inside, a lit
## window at night was a flat orange card (the kit's glow material is double-sided); now you see the
## night through the leading. Costs one draw call (the panes are their own surface now).
func _panes_one_sided() -> void:
	var mi := get_node_or_null("Mesh_glow_pane") as MeshInstance3D
	if mi == null:
		return
	if mi.material_override is ShaderMaterial:
		var sm := ShaderMaterial.new()
		sm.shader = GLOW_ONE
		mi.material_override = sm
	elif mi.material_override is BaseMaterial3D:
		var m := (mi.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_BACK
		mi.material_override = m
	else:
		return
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The inn's own masonry and boards take firelight: warm albedo (no blue-grey stone), the tables and bar a honey wood,
## the window glass brighter. Copies of the kit's materials: the crypt keeps its cold stone.
const WARM_TINT := {"stone": Color(1.0, 0.9, 0.78), "plaster": Color(1.0, 0.9, 0.76), "floor": Color(1.0, 0.84, 0.66), "wood": Color(1.25, 0.9, 0.62), "slate": Color(0.95, 0.85, 0.78), "brick": Color(1.0, 0.86, 0.72)}


func _warm_materials() -> void:
	for key: String in WARM_TINT:
		var mi := get_node_or_null("Mesh_" + key) as MeshInstance3D
		if mi == null or not (mi.material_override is StandardMaterial3D):
			continue
		var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = m.albedo_color * (WARM_TINT[key] as Color)
		mi.material_override = m
	for gn: String in ["Mesh_glow", "Mesh_glow_pane"]:
		var gl := get_node_or_null(gn) as MeshInstance3D
		if gl != null and gl.material_override is ShaderMaterial:
			var sg := (gl.material_override as ShaderMaterial).duplicate() as ShaderMaterial
			sg.set_shader_parameter("energy", 1.25)
			gl.material_override = sg
		elif gl != null and gl.material_override is StandardMaterial3D:
			var gm := (gl.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			gm.emission_energy_multiplier = 0.16
			gl.material_override = gm


func _lights(lamp: Vector3) -> void:
	var hz := CHIM.get_center().y
	var cy := FY + H1 * 0.5
	Interiors.add("tavern", Vector3((X0 + X1) * 0.5, cy, (Z0 + Z1) * 0.5), 0.0, Vector3((X1 - X0) * 0.5 - T, H1 * 0.5 + 0.1, (Z1 - Z0) * 0.5 - T))
	# the hearth: the room's heart, a soft-shadowed fire (about 1900 K) that throws the tables' shadows across the floor
	Interiors.light(self, "Hearth", Vector3(X1 - T - 0.8, FY + 0.9, hz), Color(1.0, 0.42, 0.12), 3.2, 11.0, true, 0.12).set_meta(&"fire", true)
	Interiors.light(self, "HearthRug", Vector3(X1 - T - 2.2, FY + 0.5, hz), Color(1.0, 0.5, 0.18), 1.0, 5.5, false, 0.12)
	# two iron-ring chandeliers (a ring of wax: 2300 K) with shadows; the rest of the room is candle pools without
	for cx: float in [14.2, 20.6]:
		Interiors.light(self, "Chandelier", Vector3(cx, FY + H1 - 0.55, 30.2), Color(1.0, 0.7, 0.36), 1.55, 7.0, true, 0.06)
	# a table's candles light the faces round it
	for tc: Vector2 in [Vector2(12.6, 28.9), Vector2(15.2, 29.6), Vector2(20.4, 28.9), Vector2(21.8, 31.8)]:
		Interiors.light(self, "Candles", Vector3(tc.x, FY + 1.05, tc.y), Color(1.0, 0.72, 0.38), 0.9, 3.8, false, 0.1)
	for bx: float in [13.0, 16.8]:
		Interiors.light(self, "BarCandles", Vector3(bx, FY + 1.5, Z1 - T - 1.3), Color(1.0, 0.7, 0.36), 0.95, 4.4, false, 0.09)
	# out of the door and the front windows the room spills warm onto the porch and the yard
	Interiors.light(self, "DoorLamp", lamp, Color(1.0, 0.6, 0.28), 1.25, 7.5, false, 0.1)
	Interiors.light(self, "DoorSpill", Vector3(DOOR_X, FY + 1.4, Z0 - 0.8), Color(1.0, 0.62, 0.3), 1.35, 7.5, false, 0.08)
	Interiors.shaft(self, "DoorTrail", Vector3(DOOR_X, FY + 1.55, Z0 - 0.15), Vector3(0.0, -0.35, -1.0), Color(1.0, 0.55, 0.22), 1.05, 12.0, 28.0)
	var warm := Color(1.0, 0.58, 0.24)
	for at: float in [1.8, 4.8, 10.6, 13.6]:
		var wx := X0 + at
		Interiors.light(self, "WindowSpill_%d" % int(wx * 10.0), Vector3(wx, FY + 1.5, Z0 - 0.75), warm, 0.55, 4.2, false, 0.08)
		Interiors.shaft(self, "WindowTrail_%d" % int(wx * 10.0), Vector3(wx, FY + 1.55, Z0 - 0.2), Vector3(0.0, -0.5, -1.0), warm, 0.75, 9.0, 18.0)
	var uy := FY + H1
	for at2: float in [2.4, 5.6, 8.8, 12.0, 14.8]:
		var ux := X0 - JET + at2
		Interiors.shaft(self, "UpperTrail_%d" % int(ux * 10.0), Vector3(ux, uy + 1.67, Z0 - JET - 0.12), Vector3(0.0, -0.65, -1.0), warm, 0.65, 9.5, 16.0)
	var fire := Vfx.emitter(Color(1.0, 0.45, 0.12), {"count": 26, "life": 0.7, "speed": Vector2(0.4, 1.1), "size": 0.2, "gravity": -1.4, "radius": 0.3, "additive": true, "spread": 25.0})
	if fire:
		fire.name = "HearthFire"
		add_child(fire)
		fire.global_position = Vector3(X1 - T - 0.3, FY + 0.42, CHIM.get_center().y)
		fire.emitting = true
