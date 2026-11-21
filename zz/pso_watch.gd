extends Node
## Pipeline compiles in play, frame by frame (zz/perf_tour.gd adds this node; `tour.where()` names the window).
## Always on in the tour: the five RenderingServer pipeline counters every frame. Once `live` (the start of play), a
## frame that compiled prints "PSO+ <where> t <s> frame <ms> <kind>+n ... cam (x, y, z)", and every frame over 16 ms is
## counted as a compile frame (compiles in it or in the frame before) or not. `report()` prints the "PSOPLAY" summary.
## --psolog also names the suspects: geometry in the camera's frustum, or within NEAR m (shadow casters behind the
## lens), whose pipeline key (shader or material features, vertex format, instance kind, shadow casting) was never in
## view before; and the render state behind the frame: directional lights, the fog mode, the ambient and reflection
## sources, the omni / spot lights in view (shadowed or not). A frame that compiled re-keys everything in view too, so a
## material swapped on a node already seen is caught ("late").

const NEAR := 30.0
const SLOW_MS := 16.0
const KINDS := ["canvas", "mesh", "surface", "draw", "spec"]
const _PSO := [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
	RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]

var tour: Node
var live := false
var suspects := false
var _prev: PackedInt64Array = [0, 0, 0, 0, 0]
var _at_live: PackedInt64Array = [0, 0, 0, 0, 0]
var _t := 0.0
var _compiled_last := false
var _slow := 0
var _slow_compile := 0
var _frames := 0
var _worst_compile := 0.0
var _lines := 0
var _by_where := {}                       ## where -> [compiles, slow compile frames, worst ms]
# --psolog
var _node_seen := {}                      ## instance object id -> kind (0 geometry keyed, 1 omni, 2 spot, 3 other)
var _key_seen := {}
var _fading := {}                         ## id -> [node, keys] of fade-self nodes (their blended draws while fading)
var _fresh: Array = []                    ## [frame, key, what] seen for the first time in the last two frames
var _dir_n := 0
var _dir_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = (1 << 30) - 1
	suspects = "--psolog" in OS.get_cmdline_user_args()
	_prev = _counts()


static func _counts() -> PackedInt64Array:
	var out: PackedInt64Array = []
	for k in _PSO:
		out.append(int(RenderingServer.get_rendering_info(k)))
	return out


static func totals_text(c: PackedInt64Array) -> String:
	var s := 0
	for v in c:
		s += v
	return "%s = %d" % ["/".join(Array(c).map(func(v: int) -> String: return str(v))), s]


func go_live() -> void:
	live = true
	_at_live = _counts()
	print("PSOWATCH live: canvas/mesh/surface/draw/spec %s%s" % [totals_text(_at_live), " (suspects on)" if suspects else ""])
	if suspects:
		_census()


## Every geometry node in the tree and its pipeline keys: how many distinct ones the world holds, by node class.
func _census() -> void:
	var t0 := Time.get_ticks_msec()
	var keys := {}
	var by := {}
	var n := 0
	for o in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		n += 1
		for e: Array in _keys(o as GeometryInstance3D):
			if not keys.has(e[0]):
				keys[e[0]] = true
				by[o.get_class()] = int(by.get(o.get_class(), 0)) + 1
	print("PSOKEYS %d geometry nodes, %d distinct keys %s (%d ms)" % [n, keys.size(), str(by), Time.get_ticks_msec() - t0])


func _process(d: float) -> void:
	_t += d
	var now := _counts()
	var delta: PackedInt64Array = []
	var any := 0
	for k in now.size():
		delta.append(now[k] - _prev[k])
		any += delta[k]
	_prev = now
	var ms := d * 1000.0
	if suspects:
		_scan(any > 0)
	if not live:
		return
	_frames += 1
	var where := String(tour.call("where")) if tour != null else ""
	var slow := ms > SLOW_MS
	if slow:
		_slow += 1
	if slow and (any > 0 or _compiled_last):
		_slow_compile += 1
		_worst_compile = maxf(_worst_compile, ms)
	if any > 0 or (slow and _compiled_last):
		var w: Array = _by_where.get(where, [0, 0, 0.0])
		w[0] = int(w[0]) + any
		if slow:
			w[1] = int(w[1]) + 1
			w[2] = maxf(float(w[2]), ms)
		_by_where[where] = w
	if any > 0 and _lines < 600:
		_lines += 1
		var parts := PackedStringArray()
		for k in delta.size():
			if delta[k] > 0:
				parts.append("%s+%d" % [KINDS[k], delta[k]])
		var cam := get_viewport().get_camera_3d()
		print("PSO+ %s t %.2f frame %.1f ms%s %s cam %s%s" % [where, _t, ms, " SLOW" if slow else "", " ".join(parts),
			cam.global_position.snapped(Vector3.ONE * 0.1) if cam else Vector3.ZERO, _state() if suspects else ""])
		if suspects:
			_print_fresh()
	elif slow and _compiled_last and _lines < 600:
		_lines += 1
		print("PSO. %s t %.2f frame %.1f ms SLOW (the frame after a compile)" % [where, _t, ms])
	_compiled_last = any > 0


## The play summary: what compiled since go_live, and the frames over 16 ms with and without a compile.
func report() -> void:
	var now := _counts()
	var d: PackedInt64Array = []
	for k in now.size():
		d.append(now[k] - _at_live[k])
	print("PSOPLAY in-play delta canvas/mesh/surface/draw/spec %s | frames %d, over %.0f ms %d, of them with a compile %d (worst %.1f ms)" % [
		totals_text(d), _frames, SLOW_MS, _slow, _slow_compile, _worst_compile])
	var keys := _by_where.keys()
	keys.sort()
	for w: String in keys:
		var r: Array = _by_where[w]
		print("PSOPLAY   %-22s compiles %3d  slow frames %d  worst %.1f ms" % [w, int(r[0]), int(r[1]), float(r[2])])


# --- suspects (--psolog) ----------------------------------------------------------------------------------------

func _scan(compiled: bool) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not cam.is_inside_tree():
		return
	var f := Engine.get_process_frames()
	_fresh = _fresh.filter(func(e: Array) -> bool: return int(e[0]) >= f - 2)
	var scen := cam.get_world_3d().scenario
	var ids := RenderingServer.instances_cull_convex(cam.get_frustum(), scen)
	var near := RenderingServer.instances_cull_aabb(AABB(cam.global_position - Vector3.ONE * NEAR, Vector3.ONE * NEAR * 2.0), scen)
	for id in ids:
		if not _node_seen.has(id):
			_look(id, cam, f, "")
		elif _fading.has(id):
			_fade_band(id, cam, f)
	for id in near:
		if not _node_seen.has(id):
			_look(id, cam, f, " near")
	if compiled:                                     # a swapped material on a node already seen
		for id in ids:
			var o := instance_from_id(id)
			if o is GeometryInstance3D and _drawn(o as GeometryInstance3D, cam):
				for e: Array in _keys(o as GeometryInstance3D):
					if not _key_seen.has(e[0]):
						_key_seen[e[0]] = true
						_fresh.append([f, e[0], "late " + String(e[1])])


func _look(id: int, cam: Camera3D, f: int, tag: String) -> void:
	var o := instance_from_id(id)
	if o == null:
		return
	if o is OmniLight3D:
		_node_seen[id] = 1
		return
	if o is SpotLight3D:
		_node_seen[id] = 2
		return
	if not (o is GeometryInstance3D):
		_node_seen[id] = 3
		return
	var g := o as GeometryInstance3D
	if not _drawn(g, cam):
		return                                       # not drawn yet (hidden, out of its range): looked at again later
	_node_seen[id] = 0
	var ks := _keys(g)
	if g.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF and (g.visibility_range_end > 0.0 or g.visibility_range_begin > 0.0):
		_fading[id] = [g, ks]                        # drawn in the alpha pass while it crosses its fade band
	for e: Array in ks:
		if not _key_seen.has(e[0]):
			_key_seen[e[0]] = true
			_fresh.append([f, e[0], String(e[1]) + tag])


## A fade-self node inside its fade band is drawn blended: its keys again, "|fade".
func _fade_band(id: int, cam: Camera3D, f: int) -> void:
	var e: Array = _fading[id]
	if not is_instance_valid(e[0]):
		_fading.erase(id)
		return
	var g := e[0] as GeometryInstance3D
	if not g.is_visible_in_tree():
		return
	var dist := cam.global_position.distance_to(g.global_position)
	var inb := (g.visibility_range_end > 0.0 and absf(dist - g.visibility_range_end) < g.visibility_range_end_margin) \
		or (g.visibility_range_begin > 0.0 and absf(dist - g.visibility_range_begin) < g.visibility_range_begin_margin)
	if not inb:
		return
	for k: Array in e[1]:
		var fk := String(k[0]) + "|fade"
		if not _key_seen.has(fk):
			_key_seen[fk] = true
			_fresh.append([f, fk, "fading " + String(k[1])])


static func _drawn(g: GeometryInstance3D, cam: Camera3D) -> bool:
	if not g.is_visible_in_tree():
		return false
	var dist := cam.global_position.distance_to(g.global_position)
	if g.visibility_range_end > 0.0 and dist > g.visibility_range_end + g.visibility_range_end_margin:
		return false
	if g.visibility_range_begin > 0.0 and dist < g.visibility_range_begin - g.visibility_range_begin_margin:
		return false
	return true


## [key, readable] per pipeline this instance needs: its shader (or the material's features), the surface's vertex
## format, the instance kind, shadow casting, and each next pass / overlay.
static func _keys(g: GeometryInstance3D) -> Array:
	var out: Array = []
	var kind := g.get_class()
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
		if (g as MeshInstance3D).skin != null or String((g as MeshInstance3D).skeleton) != "":
			kind += "+skin"
	elif g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm != null:
			mesh = mm.mesh
			kind += "%s%s" % ["+col" if mm.use_colors else "", "+cust" if mm.use_custom_data else ""]
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	elif g is GPUParticles3D:
		var gp := g as GPUParticles3D
		for k in gp.draw_passes:
			var dm := gp.get_draw_pass_mesh(k)
			if dm != null:
				_mesh_keys(out, g, dm, kind, gp.material_override)
		return out
	else:
		var m := g.material_override
		out.append(["%s|%s" % [kind, _mat_key(m)], "%s %s (%s)" % [kind, _mat_name(m), g.name]])
		return out
	if mesh != null:
		_mesh_keys(out, g, mesh, kind, g.material_override)
	return out


static func _mesh_keys(out: Array, g: GeometryInstance3D, mesh: Mesh, kind: String, over: Material) -> void:
	var sh := "c" if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else ""
	for s in mesh.get_surface_count():
		var m: Material = over
		if m == null and g is MeshInstance3D:
			m = (g as MeshInstance3D).get_active_material(s)
		if m == null:
			m = mesh.surface_get_material(s)
		var fmt := 0
		var prim := 3
		if mesh is ArrayMesh:
			fmt = (mesh as ArrayMesh).surface_get_format(s)
			prim = (mesh as ArrayMesh).surface_get_primitive_type(s)
		else:
			fmt = mesh.get_class().hash() & 0xffff        # a PrimitiveMesh: its format is its class's
		var mk := _mat_key(m)
		while m != null:
			out.append(["%s|%s|%x|%d|%s" % [kind, mk, fmt, prim, sh], "%s %s fmt %x%s (%s)" % [kind, _mat_name(m), fmt, " shadow" if sh != "" else "", g.name]])
			m = m.next_pass
			mk = _mat_key(m)
	if g.material_overlay != null:
		out.append(["%s|ov|%s" % [kind, _mat_key(g.material_overlay)], "%s overlay %s (%s)" % [kind, _mat_name(g.material_overlay), g.name]])


static func _mat_key(m: Material) -> String:
	if m == null:
		return "default"
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		if sh == null:
			return "S:none"
		return "S:" + (sh.resource_path if sh.resource_path != "" else str(sh.get_instance_id()))
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		var flags := PackedInt32Array()
		for f in BaseMaterial3D.FLAG_MAX:
			flags.append(int(b.get_flag(f)))
		var feats := PackedInt32Array()
		for f in BaseMaterial3D.FEATURE_MAX:
			feats.append(int(b.get_feature(f)))
		var tex := PackedInt32Array()
		for t in BaseMaterial3D.TEXTURE_MAX:
			tex.append(int(b.get_texture(t) != null))
		return "B:%s:%d%d%d%d%d%d%d%d%d%d%d%d:%s:%s:%s" % [b.get_class(), b.transparency, b.blend_mode, b.cull_mode, b.depth_draw_mode,
			b.shading_mode, b.diffuse_mode, b.specular_mode, b.billboard_mode, b.texture_filter, b.distance_fade_mode,
			b.alpha_antialiasing_mode, int(b.proximity_fade_enabled), "".join(Array(flags).map(func(v: int) -> String: return str(v))),
			"".join(Array(feats).map(func(v: int) -> String: return str(v))), "".join(Array(tex).map(func(v: int) -> String: return str(v)))]
	return m.get_class()


static func _mat_name(m: Material) -> String:
	if m == null:
		return "<default>"
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		var p := (m as ShaderMaterial).shader.resource_path
		return p.get_file() if p != "" else "shader#%d" % (m as ShaderMaterial).shader.get_instance_id()
	if m.resource_path != "":
		return m.resource_path.get_file()
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return "%s(%s%s%s%s)" % [b.get_class(), ["opaque", "alpha", "scissor", "hash", "prepass"][b.transparency],
			" unshaded" if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else "",
			" billboard" if b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED else "",
			" fade" if b.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED else ""]
	return m.get_class()


## The scene state the frame was drawn under (what the specialisation constants and the passes read).
func _state() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return ""
	if Time.get_ticks_msec() * 0.001 > _dir_t:
		_dir_t = Time.get_ticks_msec() * 0.001 + 2.0
		_dir_n = 0
		for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			var dl := n as DirectionalLight3D
			if dl.is_visible_in_tree() and dl.get_viewport() == get_viewport() and dl.sky_mode != DirectionalLight3D.SKY_MODE_SKY_ONLY:
				_dir_n += 1
	var env := cam.environment if cam.environment != null else get_viewport().find_world_3d().environment
	var omni := 0
	var omni_sh := 0
	var spot := 0
	var spot_sh := 0
	var dp := 0
	var proj := 0
	var soft := 0
	var soft_sh := 0
	for id in RenderingServer.instances_cull_convex(cam.get_frustum(), cam.get_world_3d().scenario):
		var k := int(_node_seen.get(id, 3))
		if k == 1 or k == 2:
			var l := instance_from_id(id) as Light3D
			if l == null or not l.is_visible_in_tree():
				continue
			if k == 1:
				omni += 1
				omni_sh += int(l.shadow_enabled)
				dp += int(l.shadow_enabled and (l as OmniLight3D).omni_shadow_mode == OmniLight3D.SHADOW_DUAL_PARABOLOID)
			else:
				spot += 1
				spot_sh += int(l.shadow_enabled)
			proj += int(l.light_projector != null)
			soft += int(l.light_size > 0.0)
			soft_sh += int(l.light_size > 0.0 and l.shadow_enabled)
	return " | dir %d fog %s vol %s amb %s refl %s | omni %d (%d shadowed, %d dp) spot %d (%d shadowed) projector %d soft %d (%d shadowed)" % [_dir_n,
		("depth" if env.fog_mode == Environment.FOG_MODE_DEPTH else "exp") if env != null and env.fog_enabled else "off",
		str(env.volumetric_fog_enabled) if env != null else "-", str(env.ambient_light_source) if env != null else "-",
		str(env.reflected_light_source) if env != null else "-", omni, omni_sh, dp, spot, spot_sh, proj, soft, soft_sh]


func _print_fresh() -> void:
	_print_lantern()
	var n := 0
	for e: Array in _fresh:
		if n >= 10:
			print("PSO?   ... %d more" % (_fresh.size() - n))
			break
		print("PSO?   new in view: %s" % e[2])
		n += 1
	if _fresh.is_empty():
		print("PSO?   nothing new in view (a state change, a pass, or a canvas item)")
	_fresh.clear()


## What the wanderer's lantern touches (a light with a size: every material it touches is drawn in the soft state): the
## geometry within 5 m of the wanderer, by key, once per key a compile frame names.
var _lantern_seen := {}


func _print_lantern() -> void:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var cam := get_viewport().get_camera_3d()
	if p == null or cam == null:
		return
	var ids := RenderingServer.instances_cull_aabb(AABB(p.global_position - Vector3.ONE * 5.0, Vector3.ONE * 10.0), cam.get_world_3d().scenario)
	var n := 0
	for id in ids:
		var g := instance_from_id(id) as GeometryInstance3D
		if g == null or not g.is_visible_in_tree():
			continue
		for e: Array in _keys(g):
			if _lantern_seen.has(e[0]):
				continue
			_lantern_seen[e[0]] = true
			if n < 8:
				print("PSO?   by the lantern: %s%s" % [e[1], " (skinned)" if g is MeshInstance3D and (g as MeshInstance3D).get_skin_reference() != null else ""])
			n += 1
