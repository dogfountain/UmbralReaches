extends Node
## Every smoke, steam and haze source in the built Realm, with what stands under it, so a column with no fire,
## chimney, clamp or warm crust under it shows up. Lists particle emitters (GPU and CPU) and smoke-shaded meshes:
## where, the region, the node path, its look (colour, size, life) and the first collider straight below
## (FLOAT: more than 2.5 m over bare terrain; BARE: on the terrain with nothing built within 3 m).
##   godot --headless --path . res://zz/smoke_census.tscn -- --out=<dir> [--all]
## --all lists every emitter (default: the smoke-like ones). Writes <out>/smoke.txt. Never writes the save.
const Land := preload("res://core/world/realm/realm_land.gd")
const WORDS := ["smoke", "steam", "plume", "haze", "mist", "fume", "breath", "soot", "ash"]
var main: Node
var out := "/tmp"
var all := false


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--all":
			all = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(14.0).timeout            # the lava's falls and the streamed areas come in after
	_census()
	print("SMOKE_CENSUS done")
	get_tree().quit()


func _census() -> void:
	var space := (main as Node3D).get_world_3d().direct_space_state
	var lines := PackedStringArray()
	var n := 0
	var flagged := 0
	for nd: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := nd as GeometryInstance3D
		var look := _look(gi)
		if look.is_empty():
			continue
		var at := gi.global_position
		var path := String(gi.get_path()).trim_prefix("/root/")
		var hay := (path + " " + look).to_lower()
		var smoky := false
		for w: String in WORDS:
			if hay.contains(w):
				smoky = true
		if not smoky and not all and not look.begins_with("P ") :
			continue
		if not smoky and not all and not _greyish(gi):
			continue
		n += 1
		var gy := Land.height_at(at.x, at.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.2, at + Vector3.DOWN * 60.0, Layers.WORLD))
		var below := "nothing"
		var drop := INF
		if not hit.is_empty():
			below = String((hit.collider as Node).name)
			drop = at.y - (hit.position as Vector3).y
		var near := _near_built(space, at)
		var flag := ""
		if below.begins_with("Terrain") and drop > 2.5:
			flag = "FLOAT"
		elif below.begins_with("Terrain") and not near:
			flag = "BARE"
		if not gi.is_visible_in_tree():
			flag += " hidden"
		if flag.begins_with("FLOAT") or flag.begins_with("BARE"):
			flagged += 1
		var reg: Dictionary = RealmLayout.region_at(at.x, at.z)
		lines.append("%-6s (%7.1f, %6.1f, %7.1f) %5.1f m over %-18s ground %6.1f  %-12s %s  | %s" % [
			flag, at.x, at.y, at.z, drop, below.left(18), gy, String(reg.get("id", "-")), look, path])
	lines.sort()
	lines.insert(0, "%d emitters, %d flagged (FLOAT: over bare terrain; BARE: on the ground with nothing built within 3 m)" % [n, flagged])
	var f := FileAccess.open(out.path_join("smoke.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	print("SMOKE_CENSUS %d emitters, %d flagged -> %s" % [n, flagged, out.path_join("smoke.txt")])


## "P <colour> size life amount" for particles, "M <shader>" for a smoke-shaded mesh, "" for anything else.
func _look(gi: GeometryInstance3D) -> String:
	if gi is GPUParticles3D:
		var p := gi as GPUParticles3D
		var col := Color.WHITE
		var grav := 0.0
		if p.process_material is ParticleProcessMaterial:
			col = (p.process_material as ParticleProcessMaterial).color
			grav = (p.process_material as ParticleProcessMaterial).gravity.y
		var sz := 0.0
		if p.draw_pass_1 is QuadMesh:
			sz = (p.draw_pass_1 as QuadMesh).size.x
		return "P %s size %.2f life %.1f n %d g %.2f" % [_c(col), sz, p.lifetime, p.amount, grav]
	if gi is CPUParticles3D:
		var c := gi as CPUParticles3D
		return "P %s cpu life %.1f n %d" % [_c(c.color), c.lifetime, c.amount]
	if gi is MeshInstance3D:
		var m := (gi as MeshInstance3D).material_override
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			var sp := (m as ShaderMaterial).shader.resource_path
			if sp == "":
				sp = "inline"
			for w: String in WORDS:
				if sp.to_lower().contains(w) or String(gi.name).to_lower().contains(w):
					return "M %s" % sp.get_file()
	return ""


func _greyish(gi: GeometryInstance3D) -> bool:
	if not (gi is GPUParticles3D):
		return false
	var p := gi as GPUParticles3D
	if not (p.process_material is ParticleProcessMaterial):
		return false
	var col := (p.process_material as ParticleProcessMaterial).color
	var sz := (p.draw_pass_1 as QuadMesh).size.x if p.draw_pass_1 is QuadMesh else 0.0
	var spread := maxf(maxf(col.r, col.g), col.b) - minf(minf(col.r, col.g), col.b)
	return sz >= 0.4 and spread < 0.2 and maxf(maxf(col.r, col.g), col.b) <= 1.0


## Something other than the terrain within 3 m (a ray fan round the point and a box overlap).
func _near_built(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 3.0
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = Layers.WORLD
	for r: Dictionary in space.intersect_shape(q, 16):
		if not String((r.collider as Node).name).begins_with("Terrain"):
			return true
	return false


func _c(c: Color) -> String:
	return "(%.2f %.2f %.2f %.2f)" % [c.r, c.g, c.b, c.a]
