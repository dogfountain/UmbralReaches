extends RefCounted
## What the frame draws, counted (measurement only; load-independent, so it can be taken on a busy machine).
## The fight bench runs it after its report with `--render-census`:
##   - the viewport's own counts by pass (main, shadow, canvas): objects, primitives, draw calls
##   - the local lights the camera can see (by kind, shadowed, in the fog) and the particles emitting in view
##   - the shadow casters near enough for the moon's map, by top-level part
## then PerfWatch's draw list (every mesh in view, by part and host).


static func run(tree: SceneTree, frames := 30) -> void:
	var vp := tree.root.get_viewport_rid()
	var cam := tree.root.get_camera_3d()
	var acc := {}
	var types := {"main": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, "shadow": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
		"canvas": RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS}
	var infos := {"objects": RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME, "prims": RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME,
		"draws": RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME}
	for _i in frames:
		await tree.process_frame
		for t: String in types:
			for k: String in infos:
				acc[t + k] = float(acc.get(t + k, 0.0)) + float(RenderingServer.viewport_get_render_info(vp, types[t], infos[k]))
	for t: String in types:
		print("RCOUNT %-6s objects %6.0f  prims %7.0fk  draws %6.0f" % [t, acc[t + "objects"] / frames, acc[t + "prims"] / frames / 1000.0, acc[t + "draws"] / frames])
	if cam == null:
		return
	var planes := cam.get_frustum()
	var at := cam.global_position
	var kinds := {}
	for n in tree.root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree():
			continue
		var r: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
		var d := at.distance_to(l.global_position)
		if l.distance_fade_enabled and d > l.distance_fade_begin + l.distance_fade_length:
			continue
		if not _sphere_in(planes, l.global_position, r):
			continue
		var k := "%s%s%s" % [l.get_class(), " shadow" if l.shadow_enabled else "", " fog" if l.light_volumetric_fog_energy > 0.0 else ""]
		var row: Array = kinds.get(k, [0, 0.0, 0.0])
		kinds[k] = [int(row[0]) + 1, float(row[1]) + r, float(row[2]) + d]
	for k: String in kinds:
		var row: Array = kinds[k]
		print("RLIGHTS %3d  %-32s mean range %5.1f m, mean distance %5.1f m" % [row[0], k, float(row[1]) / row[0], float(row[2]) / row[0]])
	var parts := 0
	var amount := 0
	var pk := {}
	for n in tree.root.find_children("*", "GPUParticles3D", true, false):
		var p := n as GPUParticles3D
		if not p.is_visible_in_tree() or not p.emitting:
			continue
		var ab := p.global_transform * p.visibility_aabb
		var d := at.distance_to(ab.get_center())
		if p.visibility_range_end > 0.0 and d > p.visibility_range_end + p.visibility_range_end_margin:
			continue
		if not _sphere_in(planes, ab.get_center(), ab.size.length() * 0.5):
			continue
		parts += 1
		amount += p.amount
		var key := "%s/%s" % [String(p.get_parent().name).rstrip("0123456789_-@"), String(p.name).rstrip("0123456789_-@")]
		var row: Array = pk.get(key, [0, 0, 0.0])
		pk[key] = [int(row[0]) + 1, int(row[1]) + p.amount, float(row[2]) + d]
	print("RPARTICLES %d emitting in view, %d particles" % [parts, amount])
	var pks := pk.keys()
	pks.sort_custom(func(a: String, b: String) -> bool: return int(pk[a][0]) > int(pk[b][0]))
	for k: String in pks.slice(0, 20):
		print("RPARTICLES %4d systems  %5d particles  mean %5.1f m  %s" % [pk[k][0], pk[k][1], float(pk[k][2]) / int(pk[k][0]), k])
	var moon: DirectionalLight3D = null
	for n in tree.root.find_children("*", "DirectionalLight3D", true, false):
		if (n as DirectionalLight3D).shadow_enabled and (n as Node3D).is_visible_in_tree():
			moon = n
	if moon == null:
		return
	var reach := moon.directional_shadow_max_distance
	var by := {}
	for n in tree.root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not g.is_visible_in_tree():
			continue
		var ab := g.global_transform * g.get_aabb()
		if ab.get_center().distance_to(at) > reach + ab.size.length() * 0.5:
			continue
		var d := at.distance_to(ab.get_center())
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin:
			continue
		var top: Node = g
		while top.get_parent() != null and top.get_parent().get_parent() != null and String(top.get_parent().name) not in ["Main", "Zone", "root"]:
			top = top.get_parent()
		var key := "%s%s" % [top.name, " (mm)" if g is MultiMeshInstance3D else ""]
		by[key] = int(by.get(key, 0)) + 1
	var ks := by.keys()
	ks.sort_custom(func(a: String, b: String) -> bool: return int(by[a]) > int(by[b]))
	var tot := 0
	for k: String in ks:
		tot += int(by[k])
	print("RSHADOW %d casters within the moon's %.0f m" % [tot, reach])
	for k: String in ks.slice(0, 16):
		print("RSHADOW %5d  %s" % [by[k], k])
	_by_name(tree, planes, at, cam.cull_mask)
	_foes(tree, planes, at)
	_big_canvas(tree)
	var pw := tree.root.find_child("PerfWatch", true, false) as PerfWatch
	if pw:
		pw._drawlist()


## Every mesh in view (frustum and draw range; occlusion not counted) by parent and node name without digits:
## surfaces, instances, triangles (LOD 0), shadow casters.
static func _by_name(tree: SceneTree, planes: Array[Plane], at: Vector3, mask: int) -> void:
	var rows := {}
	for n in tree.root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree() or (g.layers & mask) == 0:
			continue
		var ab := g.global_transform * g.get_aabb()
		var d := at.distance_to(ab.get_center())
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin:
			continue
		if g.visibility_range_begin > 0.0 and d < g.visibility_range_begin - g.visibility_range_begin_margin:
			continue
		if not _sphere_in(planes, ab.get_center(), ab.size.length() * 0.5):
			continue
		var mesh: Mesh = null
		var inst := 1
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
			var mm := (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			inst = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		var surf := mesh.get_surface_count() if mesh else 1
		var tris := 0
		if mesh is ArrayMesh:
			for si in surf:
				var c := (mesh as ArrayMesh).surface_get_array_index_len(si)
				tris += (c if c > 0 else (mesh as ArrayMesh).surface_get_array_len(si)) / 3
		var par := g.get_parent()
		var key := "%s/%s %s%s" % [String(par.get_parent().name).rstrip("0123456789_-") if par.get_parent() else "", String(par.name).rstrip("0123456789_-"),
			String(g.name).rstrip("0123456789_-"), " (mm)" if g is MultiMeshInstance3D else ""]
		var row: Array = rows.get(key, [0, 0, 0, 0])
		rows[key] = [int(row[0]) + surf, int(row[1]) + inst, int(row[2]) + tris * inst, int(row[3]) + (1 if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0)]
	var ks := rows.keys()
	ks.sort_custom(func(a: String, b: String) -> bool: return int(rows[a][0]) > int(rows[b][0]))
	for k: String in ks.slice(0, 45):
		var r: Array = rows[k]
		print("RNAME %4d surf  %6d inst  %6dk tris  %3d shadow  %s" % [r[0], r[1], int(r[2]) / 1000, r[3], k])


## The foes' meshes in view by distance band: foes, surfaces, shadow casters, and how many carry a draw range.
static func _foes(tree: SceneTree, planes: Array[Plane], at: Vector3) -> void:
	var bands := [30.0, 60.0, 120.0, 1.0e9]
	var rows := []
	for b in bands:
		rows.append([0, 0, 0, 0])
	for e in tree.get_nodes_in_group(Groups.ENEMY):
		var e3 := e as Node3D
		if e3 == null or not e3.is_visible_in_tree():
			continue
		var d := at.distance_to(e3.global_position)
		var bi := 0
		while d > float(bands[bi]):
			bi += 1
		var row: Array = rows[bi]
		var seen := false
		for n in e3.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			var ab := g.global_transform * g.get_aabb()
			if g.visibility_range_end > 0.0 and at.distance_to(ab.get_center()) > g.visibility_range_end + g.visibility_range_end_margin:
				continue
			if not _sphere_in(planes, ab.get_center(), ab.size.length() * 0.5):
				continue
			seen = true
			row[1] = int(row[1]) + ((g as MeshInstance3D).mesh.get_surface_count() if g is MeshInstance3D and (g as MeshInstance3D).mesh else 1)
			row[2] = int(row[2]) + (1 if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0)
			row[3] = int(row[3]) + (1 if g.visibility_range_end > 0.0 else 0)
		row[0] = int(row[0]) + (1 if seen else 0)
	for i in bands.size():
		var r: Array = rows[i]
		print("RFOES under %4.0f m: %3d foes in view, %4d surfaces, %3d shadow casters, %3d with a draw range" % [minf(float(bands[i]), 9999.0), r[0], r[1], r[2], r[3]])


## Visible canvas items covering a fifth of the screen or more (each a full-size fill or blend in the canvas pass),
## with what they draw: a ColorRect's colour alpha, a material, the modulate down the tree.
static func _big_canvas(tree: SceneTree) -> void:
	var vs := tree.root.get_visible_rect().size
	for n in tree.root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if r.size.x * r.size.y < vs.x * vs.y * 0.2:
			continue
		var what := c.get_class()
		if c is ColorRect:
			what += " colour a %.2f" % (c as ColorRect).color.a
		if c.material:
			what += " material %s" % (c.material.resource_path.get_file() if c.material.resource_path else c.material.get_class())
		var drawn := c is ColorRect or c is TextureRect or c is Panel or c is PanelContainer or c.material != null or (c.get_script() != null)
		print("RCANVAS %-5s %5.0f%% screen  modulate a %.2f  %s  %s" % ["DRAWS" if drawn else "", 100.0 * r.size.x * r.size.y / (vs.x * vs.y),
			c.modulate.a * c.self_modulate.a, what, String(tree.root.get_path_to(c)).right(60)])


## GPU time by pass (the renderer's timestamps; run with `--rendering-driver vulkan --gpu-profile`: Metal gives none),
## summed over the frames of a window: {pass name: ms, "total": ms, "frames": n}.
static func gpu_window(tree: SceneTree, frames: int, into: Dictionary) -> void:
	var rd := RenderingServer.get_rendering_device()
	var last := -1
	var got := 0
	while got < frames:
		await tree.process_frame
		var fr := rd.get_captured_timestamps_frame()
		var n := rd.get_captured_timestamps_count()
		if fr == last or n < 2:
			continue
		last = fr
		got += 1
		for i in n - 1:
			var nm := rd.get_captured_timestamp_name(i)
			if nm.begins_with("<") or nm.begins_with(">"):
				continue
			into[nm] = float(into.get(nm, 0.0)) + float(rd.get_captured_timestamp_gpu_time(i + 1) - rd.get_captured_timestamp_gpu_time(i)) / 1.0e6
		into["total"] = float(into.get("total", 0.0)) + float(rd.get_captured_timestamp_gpu_time(n - 1) - rd.get_captured_timestamp_gpu_time(0)) / 1.0e6
	into["frames"] = int(into.get("frames", 0)) + got


## One toggle measured on the GPU: 4 pairs of 90-frame windows, on and off; the total and the passes that moved most.
static func gpu_ab(tree: SceneTree, label: String, f: Callable) -> void:
	var on := {}
	var off := {}
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_frames_drawn()
	for i in 4:
		await gpu_window(tree, 60, on)
		f.call(true)
		await gpu_window(tree, 8, {})
		await gpu_window(tree, 60, off)
		f.call(false)
		await gpu_window(tree, 8, {})
	var d := {}
	for k: String in on:
		if k != "frames":
			d[k] = float(off.get(k, 0.0)) / float(off.frames) - float(on[k]) / float(on.frames)
	var ks := d.keys().filter(func(k: String) -> bool: return k != "total")
	ks.sort_custom(func(a: String, b: String) -> bool: return absf(d[a]) > absf(d[b]))
	var top := PackedStringArray()
	for k: String in ks.slice(0, 4):
		top.append("%s %+.3f" % [k, d[k]])
	print("GPUAB %-28s total %+.3f ms (%.3f -> %.3f)  |  %s  [%d frames, %.1f s]" % [label, d.total, float(on.total) / float(on.frames), float(off.total) / float(off.frames), ", ".join(top),
		Engine.get_frames_drawn() - f0, float(Time.get_ticks_msec() - t0) / 1000.0])


## The GPU's passes over a window, heaviest first (the base line for gpu_ab).
static func gpu_passes(tree: SceneTree, frames := 240) -> void:
	var acc := {}
	await gpu_window(tree, frames, acc)
	var ks := acc.keys().filter(func(k: String) -> bool: return k != "frames")
	ks.sort_custom(func(a: String, b: String) -> bool: return float(acc[a]) > float(acc[b]))
	for k: String in ks:
		if float(acc[k]) / float(acc.frames) > 0.01:
			print("GPUPASS %7.3f ms  %s" % [float(acc[k]) / float(acc.frames), k])


static func _sphere_in(planes: Array[Plane], c: Vector3, r: float) -> bool:
	for pl in planes:
		if pl.distance_to(c) > r:
			return false
	return true
