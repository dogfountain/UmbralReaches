extends RefCounted
## The pipeline sweep behind the loading cover (ui/loading_screen.gd: collected over the tour's frames, drawn beside the
## panels).
##
## The renderer compiles a pipeline the first time it draws a shader on a vertex format, in a pass, under a state: as a
## mesh or a MultiMesh (with or without colours and custom data), opaque or blended (a fade-self node while it crosses its
## fade band, a body fading out at its death), mirrored or not, into the moon's map, a fire's dual-paraboloid map or a
## shadowed omni's cube; and in the colour pass under each light state of the lights touching it: one with a size (the
## wanderer's lantern, so nearly everything near the wanderer), a projector (the windows' gobo), both, neither
## (zz/spec_probe.tscn: each state is a pipeline of its own for every material it touches).
## The tour's views draw what stands near them; this draws everything else once. Each distinct combination the world holds
## is drawn by a stand-in, the world's own mesh and materials as a bare RenderingServer instance (no node, nothing
## processes), a few hundred a frame in a lab far below the land, one frame per light state. Sprites and labels are drawn
## by a copy of the node. A batch is freed as the next goes up; the lights and the lab at the end.
## No class_name: the loading screen loads it by path.

const LightPolicy := preload("res://core/world/light_policy.gd")
const GOBO := preload("res://art/textures/window_gobo.png")
const LAB := Vector3(0.0, -1400.0, 0.0)  ## far under the land and the Ossuary: no world light reaches it
const EYE := 5.0                         ## the camera looks straight down from this far above the grid
const CELL := 0.42                       ## a stand-in's cell (it is scaled to fit)
const GRID := 18                         ## cells a row: GRID * GRID stand-ins a batch
const COLLECT_BUDGET := 1200             ## nodes looked at a frame while collecting (the tour has ~250 frames)
const FADED := 0.5                       ## a fading stand-in's blended twin: its instance transparency

enum Kind { MESH, MULTIMESH, NODE }

var _stack: Array = []                   ## nodes still to look at (untyped: one may be freed before its turn)
var _under: Array[bool] = []             ## beside _stack: the node is a creature's (an Enemy's subtree), whose death fades it
var _seen := {}                          ## pipeline key -> true
var _recs: Array[Dictionary] = []        ## one per distinct key set: what a stand-in needs
var _collected := false
var _capture: Array = []                 ## (untyped, as the lists below: an entry may be freed before it is read)
var _tree: SceneTree
var _host: Node3D                        ## holds the lab's lights and node copies
var _scenario: RID
var _live_rids: Array[RID] = []          ## this batch's instances and MultiMeshes
var _live_nodes: Array = []
var _states: Array[StringName] = []
var _lights := {}                        ## state -> [Light3D]
var _batch := 0
var _state := -1
var _started := false
var done := false
var stand_ins := 0
var frames := 0


func _init(tree: SceneTree) -> void:
	_tree = tree
	_stack.append(tree.root)
	_under.append(false)
	_tree.node_added.connect(_on_added)          # from the tour's start until the sweep draws (end_capture)


# --- collecting -------------------------------------------------------------------------------------------------

## Every geometry node added while the sweep listens (from the tour's start: the combat set, the post-build merge's new
## meshes, spawns, swaps) is keyed by `flush` (the loading screen flushes when it clears the combat set, before the set is
## freed) or at the latest when the sweep draws (`end_capture`, which stops listening).
func flush() -> void:
	for o: Variant in _capture:
		if is_instance_valid(o) and (o as Node).is_inside_tree():
			_consider(o as GeometryInstance3D, _in_creature(o as Node))
	_capture.clear()


func end_capture() -> void:
	if _tree.node_added.is_connected(_on_added):
		_tree.node_added.disconnect(_on_added)
	flush()


## Part of a foe or a boss (whose death fades the body out): an Enemy among its ancestors.
static func _in_creature(n: Node) -> bool:
	var p := n
	while p != null:
		if p is Enemy:
			return true
		p = p.get_parent()
	return false


func _on_added(n: Node) -> void:
	if n is GeometryInstance3D:
		_capture.append(n)


## A slice of the walk over the whole tree (its own sub-viewports' worlds and the 2D layers are skipped). True when done.
func collect() -> bool:
	if _collected:
		return true
	var k := 0
	while not _stack.is_empty() and k < COLLECT_BUDGET:
		var o: Variant = _stack.pop_back()
		var parent_under: bool = _under.pop_back()
		if not is_instance_valid(o):
			continue                                # freed since it was stacked (the walk spans many frames)
		var n := o as Node
		var under := parent_under or n is Enemy
		k += 1
		if n is GeometryInstance3D:
			_consider(n as GeometryInstance3D, under)
		for c in n.get_children():
			if c is SubViewport or c is CanvasLayer:
				continue
			_stack.append(c)
			_under.append(under)
	_collected = _stack.is_empty()
	if _collected:
		print("PIPEWARM collected %d stand-ins (%d keys)" % [_recs.size(), _seen.size()])
	return _collected


## `creature`: a foe's or a boss's part (a death fades a body out through its instance transparency, which draws it
## blended: the blended stand-in is drawn too). The keys are made first; the record only when one is new.
func _consider(g: GeometryInstance3D, creature := false) -> void:
	if g == null:
		return
	var fades := creature or g.transparency > 0.0 or (g.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF \
		and (g.visibility_range_end > 0.0 or g.visibility_range_begin > 0.0))
	var mirror := g.global_basis.determinant() < 0.0        # a mirrored instance culls the other face: its own pipelines
	var bones := 0                                          # a skinned mesh is drawn from its skinned copy: a format of its own
	if g is MeshInstance3D and (g as MeshInstance3D).get_skin_reference() != null:
		var sk := (g as MeshInstance3D).get_skin_reference().get_skin()
		bones = maxi(1, sk.get_bind_count() if sk != null else 1)
	var flags := "%d%d%d%d%d" % [g.cast_shadow, int(fades), int(g.transparency > 0.0), int(mirror), int(bones > 0)]
	var keys: PackedStringArray = []
	var extra := {}
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		if mi.mesh == null:
			return
		extra["bones"] = bones
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			keys.append("m|%s|%s" % [_surface_key(mi.mesh, s, g.material_override if g.material_override else (m if m else mi.mesh.surface_get_material(s))), flags])
		extra.merge({"kind": Kind.MESH, "mesh": mi.mesh})
	elif g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			return
		_mm_keys(keys, mm.mesh, g.material_override, "mm%d%d%d" % [mm.transform_format, int(mm.use_colors), int(mm.use_custom_data)], flags)
		extra = {"kind": Kind.MULTIMESH, "mesh": mm.mesh, "tf": mm.transform_format, "col": mm.use_colors, "cust": mm.use_custom_data}
	elif g is CPUParticles3D:
		var cp := g as CPUParticles3D
		if cp.mesh == null:
			return
		_mm_keys(keys, cp.mesh, g.material_override, "mm111", flags)
		extra = {"kind": Kind.MULTIMESH, "mesh": cp.mesh, "tf": MultiMesh.TRANSFORM_3D, "col": true, "cust": true}
	elif g is GPUParticles3D:
		var gp := g as GPUParticles3D
		for p in gp.draw_passes:
			var dm := gp.get_draw_pass_mesh(p)
			if dm == null:
				continue
			var pk: PackedStringArray = []
			_mm_keys(pk, dm, g.material_override, "mm111", flags)
			if _fresh(pk):
				_recs.append(_rec(g, fades, mirror, {"kind": Kind.MULTIMESH, "mesh": dm, "tf": MultiMesh.TRANSFORM_3D, "col": true, "cust": true}))
		return
	elif g is SpriteBase3D or g is Label3D:
		keys.append("n|%s|%s|%s" % [g.get_class(), _node_flags(g), flags])
		extra = {"kind": Kind.NODE, "node": g}
	else:
		return
	if g.material_overlay != null:
		keys.append("ov|%s|%s" % [_mat_key(g.material_overlay), flags])
	if not _fresh(keys):
		return
	if extra.kind == Kind.NODE:
		extra["node"] = g.duplicate(0)          # copied now: a combat set's label is freed before the sweep draws
	if g is MeshInstance3D:
		var mats: Array[Material] = []
		for s in (g as MeshInstance3D).mesh.get_surface_count():
			mats.append((g as MeshInstance3D).get_surface_override_material(s))
		extra["mats"] = mats
	_recs.append(_rec(g, fades, mirror, extra))


func _rec(g: GeometryInstance3D, fades: bool, mirror: bool, extra: Dictionary) -> Dictionary:
	var rec := {"layers": g.layers, "cast": g.cast_shadow, "fades": fades, "alpha": g.transparency, "over": g.material_override,
		"overlay": g.material_overlay, "mirror": mirror}
	rec.merge(extra)
	return rec


func _mm_keys(keys: PackedStringArray, mesh: Mesh, over: Material, kind: String, flags: String) -> void:
	for s in mesh.get_surface_count():
		keys.append("%s|%s|%s" % [kind, _surface_key(mesh, s, over if over else mesh.surface_get_material(s)), flags])


## True when any of the keys is new (the stand-in then draws them all); every key is marked seen.
func _fresh(keys: PackedStringArray) -> bool:
	var fresh := false
	for k in keys:
		if not _seen.has(k):
			_seen[k] = true
			fresh = true
	return fresh


func _surface_key(mesh: Mesh, s: int, m: Material) -> String:
	var fmt := 0
	var prim := 3
	if mesh is ArrayMesh:
		fmt = (mesh as ArrayMesh).surface_get_format(s)
		prim = (mesh as ArrayMesh).surface_get_primitive_type(s)
	else:
		fmt = mesh.get_class().hash()           # a PrimitiveMesh: its class's own format
	var out := "%x/%d/%s" % [fmt, prim, _mat_key(m)]
	var np := m.next_pass if m != null else null
	while np != null:
		out += "+" + _mat_key(np)
		np = np.next_pass
	return out


## A material's pipeline identity: its shader (a shader material), or the material itself (a standard material's shader
## is made from its features, which a script cannot read back whole: two that look alike may still differ).
static func _mat_key(m: Material) -> String:
	if m == null:
		return "-"
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		return "S" + (str(sh.get_instance_id()) if sh != null else "0")
	return "M" + str(m.get_instance_id())


static func _node_flags(g: GeometryInstance3D) -> String:
	if g is SpriteBase3D:
		var sp := g as SpriteBase3D
		return "%d%d%d%d%d%d%d%d%d" % [sp.billboard, int(sp.transparent), int(sp.shaded), int(sp.double_sided), int(sp.no_depth_test),
			int(sp.fixed_size), sp.alpha_cut, sp.texture_filter, int(sp.get_draw_flag(SpriteBase3D.FLAG_DISABLE_DEPTH_TEST))]
	var l := g as Label3D
	return "%d%d%d%d%d%d%d%d" % [l.billboard, int(l.shaded), int(l.double_sided), int(l.no_depth_test), int(l.fixed_size),
		l.alpha_cut, l.texture_filter, int(l.outline_size > 0)]


# --- drawing ----------------------------------------------------------------------------------------------------

## One frame of the sweep, the camera `cam` its eye. Each batch of stand-ins is drawn once under each light state. True
## when every batch has been drawn and the lab is cleared.
func draw_step(host: Node3D, cam: Camera3D) -> bool:
	if done:
		return true
	if not _started:
		end_capture()                            # the last nodes added before the lab goes up
		print("PIPEWARM %d records after the nodes added during the tour" % _recs.size())
		_start(host, cam)
		_build_batch()
		_state = 0
	else:
		_state += 1
		if _state >= _states.size():
			_free_batch()
			if _batch * GRID * GRID >= _recs.size():
				clear()
				print("PIPEWARM drew %d stand-ins in %d frames (%d states)" % [stand_ins, frames, _states.size()])
				return true
			_build_batch()
			_state = 0
	frames += 1
	for s: StringName in _lights:
		for l: Light3D in _lights[s]:
			l.visible = s == _states[_state] or (s == &"shadows")
	return false


func _start(host: Node3D, cam: Camera3D) -> void:
	_started = true
	_host = Node3D.new()
	_host.name = "PipelineLab"
	host.add_child(_host)
	_host.global_position = LAB
	_scenario = host.get_world_3d().scenario
	cam.global_position = LAB + Vector3.UP * EYE
	cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	# the shadowed lights play reaches, all in every frame: a fire's dual-paraboloid map (the nearest lit brazier on High
	# shadows: its casters only), a shadowed omni's cube, a shadowed spot (the hero lights, the windows, the Ossuary)
	var sh: Array[Light3D] = []
	if Settings.shadow_quality > 1:
		var fire := OmniLight3D.new()
		fire.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		fire.shadow_caster_mask = LightPolicy.FIRE_CASTERS
		sh.append(fire)
		var cube := OmniLight3D.new()
		cube.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		sh.append(cube)
	if Settings.shadow_quality > 0:
		var spot := SpotLight3D.new()
		spot.spot_angle = 70.0
		sh.append(spot)
	for l in sh:
		l.shadow_enabled = true
	_lights[&"shadows"] = sh
	# the colour pass's light states (spec_probe: each flips every material in the frame to another pipeline): a light
	# with a size (the wanderer's lantern, 0.35 m: nearly every frame of play), a projector (the windows' gobo light),
	# both, and neither (a flight, a frame without the wanderer)
	var soft := OmniLight3D.new()
	soft.light_size = 0.35
	var proj := SpotLight3D.new()
	proj.spot_angle = 70.0
	proj.light_projector = GOBO
	var soft2 := soft.duplicate() as OmniLight3D
	var proj2 := proj.duplicate() as SpotLight3D
	_lights[&"soft"] = [soft]
	_lights[&"projector"] = [proj]
	_lights[&"soft+projector"] = [soft2, proj2]
	_states = [&"soft", &"plain", &"projector", &"soft+projector"]
	var i := 0
	for s: StringName in _lights:
		for l: Light3D in _lights[s]:
			l.set_meta(&"ld_gov", true)             # LightDirector leaves it as it is (its shadow policy would take the maps away)
			l.light_energy = 0.6
			l.visible = false
			if l is OmniLight3D:
				(l as OmniLight3D).omni_range = 14.0
			elif l is SpotLight3D:
				(l as SpotLight3D).spot_range = 16.0
			_host.add_child(l)
			l.position = Vector3(float(i % 3 - 1) * 1.5, EYE - 1.0 if l is SpotLight3D else 1.6, floorf(float(i) / 3.0) * 1.5)
			if l is SpotLight3D:
				l.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			i += 1


func _build_batch() -> void:
	var first := _batch * GRID * GRID
	var last := mini(first + GRID * GRID, _recs.size())
	var half := float(GRID - 1) * 0.5 * CELL
	for k in range(first, last):
		var c := k - first
		var at := LAB + Vector3(float(c % GRID) * CELL - half, 0.0, floorf(float(c) / float(GRID)) * CELL - half)
		var rec := _recs[k]
		_stand_in(rec, at, rec.alpha)
		if bool(rec.fades):
			_stand_in(rec, at + Vector3(CELL * 0.25, 0.05, CELL * 0.25), FADED)
	_batch += 1


func _stand_in(rec: Dictionary, at: Vector3, alpha: float) -> void:
	stand_ins += 1
	if rec.kind == Kind.NODE:
		var cp := rec.node as Node3D
		if cp == null or cp.is_inside_tree():
			return                                  # (its blended twin: a copy is drawn once)
		cp.visible = true                       # (a hidden source: its copy is drawn all the same)
		_host.add_child(cp)
		cp.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.05), at)
		_live_nodes.append(cp)
		return
	var mesh := rec.mesh as Mesh
	if mesh == null:
		return
	var aabb := mesh.get_aabb()
	var sc := CELL * 0.8 / maxf(aabb.get_longest_axis_size(), 0.01)
	var scale := Vector3(-sc if bool(rec.mirror) else sc, sc, sc)
	var xf := Transform3D(Basis.IDENTITY.scaled(scale), at - aabb.get_center() * scale)
	var base := mesh.get_rid()
	if rec.kind == Kind.MULTIMESH:
		var mm := RenderingServer.multimesh_create()
		RenderingServer.multimesh_set_mesh(mm, base)
		RenderingServer.multimesh_allocate_data(mm, 1, rec.tf as RenderingServer.MultimeshTransformFormat, bool(rec.col), bool(rec.cust))
		if int(rec.tf) == MultiMesh.TRANSFORM_2D:
			RenderingServer.multimesh_instance_set_transform_2d(mm, 0, Transform2D.IDENTITY)
		else:
			RenderingServer.multimesh_instance_set_transform(mm, 0, Transform3D.IDENTITY)
		if bool(rec.col):
			RenderingServer.multimesh_instance_set_color(mm, 0, Color.WHITE)
		_live_rids.append(mm)
		base = mm
	var inst := RenderingServer.instance_create2(base, _scenario)
	_live_rids.append(inst)
	if int(rec.get("bones", 0)) > 0:                # a skeleton of rest bones: the skinned copy's format, as in play
		var sk := RenderingServer.skeleton_create()
		RenderingServer.skeleton_allocate_data(sk, int(rec.bones))
		for b in int(rec.bones):
			RenderingServer.skeleton_bone_set_transform(sk, b, Transform3D.IDENTITY)
		RenderingServer.instance_attach_skeleton(inst, sk)
		_live_rids.insert(_live_rids.size() - 1, sk)    # freed after the instance (the list is freed back to front)
	RenderingServer.instance_set_transform(inst, xf)
	RenderingServer.instance_set_layer_mask(inst, int(rec.layers))
	RenderingServer.instance_geometry_set_cast_shadows_setting(inst, rec.cast as RenderingServer.ShadowCastingSetting)
	if alpha > 0.0:
		RenderingServer.instance_geometry_set_transparency(inst, alpha)
	var over := rec.over as Material
	if over != null:
		RenderingServer.instance_geometry_set_material_override(inst, over.get_rid())
	elif rec.has("mats"):
		var mats: Array[Material] = rec.mats
		for s in mats.size():
			if mats[s] != null:
				RenderingServer.instance_set_surface_override_material(inst, s, mats[s].get_rid())
	var ov := rec.overlay as Material
	if ov != null:
		RenderingServer.instance_geometry_set_material_overlay(inst, ov.get_rid())


func _free_batch() -> void:
	for k in range(_live_rids.size() - 1, -1, -1):       # each instance before the MultiMesh under it
		RenderingServer.free_rid(_live_rids[k])
	_live_rids.clear()
	for o: Variant in _live_nodes:
		if is_instance_valid(o):
			(o as Node).queue_free()
	_live_nodes.clear()


## Everything the sweep made goes (also when the loading screen is left early).
func clear() -> void:
	if _tree.node_added.is_connected(_on_added):
		_tree.node_added.disconnect(_on_added)
	_capture.clear()
	_free_batch()
	if is_instance_valid(_host):
		_host.queue_free()
	_host = null
	_lights.clear()
	for rec in _recs:
		if rec.kind == Kind.NODE and is_instance_valid(rec.node) and not (rec.node as Node).is_inside_tree():
			(rec.node as Node).free()               # a copy no batch drew (the sweep was left early)
	_recs.clear()
	done = true
