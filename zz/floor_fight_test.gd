extends Node
## Floors vs ground. Every registered building site (WorldLanes.sites: huts, ruins, plazas, terraces,
## yards, landings) has its floor sampled on a 0.5 m grid inside the footprint; wherever a walkable
## surface other than the terrain stands at the site's floor height, the terrain (collision, which the
## stamp shifts in step with the mesh) must lie at least MIN_GAP under it. Terrain at or above the
## floor is z-fighting or pokes through the floor. Offenders are listed.
## Run: HOME=<scratch> godot --headless --path . res://zz/floor_fight_test.tscn [-- --verbose]
const MIN_GAP := 0.02
const STEP := 0.5
const BAND := 0.35            ## a surface within this of the site's floor counts as that site's floor
const MAX_LIST := 80
const BURIED := 0.02         ## terrain this far over a floor or less is the ground fighting it
const SEAM := 20             ## fewer overlapping samples than this (5 m2) is a seam or a decal, a warning; more is a floor
const COPLANAR := 0.012       ## two walkable tops this close, from different bodies, z-fight

var main: Node
var frames := 0
var first_co := ""
var warns := 0
var done := false


func _ready() -> void:
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	frames += 1
	if done:
		return
	if frames > 3600 * 3 and not main.has_meta("realm_built"):
		print("FLOOR FAIL realm never built")
		get_tree().quit(1)
		return
	if frames < 900 or not main.has_meta("realm_built") or main.get_node_or_null("Zone/Terrain") == null:
		return                      # let the stamp, the streams and the dress settle
	done = true
	var bad := _run()
	print("FLOOR_FIGHT DONE bad=", bad)
	get_tree().quit(1 if bad > 0 else 0)


## Ground height under (x, z) and the floor that meets it: TerrainStamp.walk_surface.
func _probe(x: float, z: float, fy: float) -> Array:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var s := TerrainStamp.walk_surface(space, Vector2(x, z), fy)
	return [s.x, s.y]


## Up-facing triangles of every visible mesh (never the terrain) over `r` within BAND of `fy`:
## [a, b, c] world-space Vector3 each.
func _tops_near(r: Rect2, fy: float) -> Array:
	var out: Array = []
	var box := AABB(Vector3(r.position.x, fy - BAND, r.position.y), Vector3(r.size.x, BAND * 2.0 + 0.5, r.size.y))
	for n in main.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or String(mi.name) == "Terrain" or String(mi.name).begins_with("Canopy") or String(mi.name) == "FarMesh":
			continue
		var wb := mi.global_transform * mi.get_aabb()
		if not wb.intersects(box):
			continue
		var faces := mi.mesh.get_faces()
		var xf := mi.global_transform
		var i := 0
		while i + 2 < faces.size():
			var a := xf * faces[i]
			var b := xf * faces[i + 1]
			var c := xf * faces[i + 2]
			i += 3
			var nrm := (b - a).cross(c - a)
			if -nrm.y < nrm.length() * 0.99:         # Godot's front faces wind clockwise
				continue
			if absf(a.y - fy) > BAND:
				continue
			if not Rect2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)), 0.0, 0.0).expand(Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))).intersects(r):
				continue
			out.append([a, b, c, String(mi.get_path())])
	return out


## How many pairs of up-facing triangles cover XZ point `p` within COPLANAR of each other in height.
func _overlaps(tris: Array, p: Vector2) -> int:
	var ys: Array[float] = []
	var who: Array[String] = []
	var q := p + Vector2(0.0037, 0.0029)
	for t: Array in tris:
		var a := Vector2((t[0] as Vector3).x, (t[0] as Vector3).z)
		var b := Vector2((t[1] as Vector3).x, (t[1] as Vector3).z)
		var c := Vector2((t[2] as Vector3).x, (t[2] as Vector3).z)
		var d1 := (b - a).cross(q - a)
		var d2 := (c - b).cross(q - b)
		var d3 := (a - c).cross(q - c)
		if (d1 >= 0.0 and d2 >= 0.0 and d3 >= 0.0) or (d1 <= 0.0 and d2 <= 0.0 and d3 <= 0.0):
			ys.append((t[0] as Vector3).y)
			who.append(String(t[3]))
	var n := 0
	for i in ys.size():
		for j in range(i + 1, ys.size()):
			if absf(ys[i] - ys[j]) < COPLANAR:
				if who[i].to_lower().contains("floor") == who[j].to_lower().contains("floor"):
					warns += 1             # stone on stone, floor on floor, decals: the same look either way
					continue
				n += 1
				if first_co == "":
					first_co = "at %.1f, %.1f y %.3f: %s / %s" % [p.x, p.y, ys[i], who[i].get_slice("/", who[i].get_slice_count("/") - 1), who[j].get_slice("/", who[j].get_slice_count("/") - 1)]
	return n


func _run() -> int:
	var bad := 0
	var sites_n := 0
	var floors_n := 0
	var samples := 0
	var verbose := "--verbose" in OS.get_cmdline_user_args()
	var listed := 0
	for st: Dictionary in WorldLanes.sites:
		if not WorldLanes.is_floor_site(st):
			continue                # flights are ramps; waymarks, graves and low walls stand on the land as it is
		var r: Rect2 = st.rect
		sites_n += 1
		first_co = ""
		var tris := _tops_near(r, float(st.floor_y))
		var worst := -99.0
		var n_bad := 0
		var n_co := 0
		var n_floor := 0
		var at := Vector2.ZERO
		var x := r.position.x + STEP * 0.5
		while x < r.end.x:
			var z := r.position.y + STEP * 0.5
			while z < r.end.y:
				var p := Vector2(x, z)
				z += STEP
				if is_nan(WorldLanes.site_floor(st, p)):
					continue
				n_co += _overlaps(tris, p)
				var pr := _probe(p.x, p.y, float(st.floor_y))
				if is_nan(pr[0]) or is_nan(pr[1]):
					continue        # no ground here, or no floor surface at this site's height
				n_floor += 1
				var gap: float = float(pr[1]) - float(pr[0])
				if gap < MIN_GAP and -gap <= BURIED:     # deeper is a floor in the hillside (settle leaves it), not a fight
					n_bad += 1
					if -gap > worst:
						worst = -gap
						at = p
			x += STEP
		samples += n_floor
		if n_floor > 0:
			floors_n += 1
		if n_bad > 0:
			bad += 1
			if listed < MAX_LIST:
				listed += 1
				if verbose:
					var space := (main as Node3D).get_world_3d().direct_space_state
					var y0 := float(st.floor_y) + 1.0
					for k in 8:
						var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x + 0.0037, y0, at.y + 0.0029), Vector3(at.x, float(st.floor_y) - 4.0, at.y), Layers.WORLD))
						if h.is_empty():
							break
						print("   hit %s y %.3f n.y %.2f" % [(h.collider as Node).get_path(), (h.position as Vector3).y, (h.normal as Vector3).y])
						y0 = (h.position as Vector3).y - 0.002
				print("FLOOR FAIL %s: %d of %d floor samples have terrain within %.0f cm of the floor (worst: ground %.2f m above the floor at %.1f, %.1f; floor_y %.2f)" % [
					st.name, n_bad, n_floor, MIN_GAP * 100.0, worst, at.x, at.y, float(st.floor_y)])
		if n_co > 0 and n_co < SEAM:
			print("FLOOR warn %s: %d samples (a seam or a decal) where a floor and other masonry share a height, first %s" % [st.name, n_co, first_co])
		elif n_co >= SEAM:
			bad += 1
			print("FLOOR FAIL %s: %d floor samples have overlapping upward faces within %.0f mm (z-fight), first %s" % [st.name, n_co, COPLANAR * 1000.0, first_co])
		if n_bad == 0 and n_co < SEAM and verbose and n_floor > 0:
			print("FLOOR ok %s (%d samples)" % [st.name, n_floor])
	print("FLOOR note: %d overlapping like-for-like upward faces (stone/stone, floor/floor, decals) not counted" % warns)
	print("FLOOR sites %d, with a sampled floor %d, samples %d, offending sites %d" % [sites_n, floors_n, samples, bad])
	if floors_n < 10:
		print("FLOOR FAIL too few floors found: the probe is blind")
		bad += 1
	return bad
