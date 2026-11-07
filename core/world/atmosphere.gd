class_name Atmosphere
extends RefCounted
## Shared lighting, fog, and culling. Traditional fog is far-depth only; volumetric
## carries the night colour. High aerial-perspective and ambient-inject turned the
## mid-ground grey. Visibility ranges for open scenes, occlusion for trunks/ruins,
## light distance fade so off-screen lamps drop.
##
## Image pipeline, measured r35 (zz/lane_a_bench: paired A/B windows, medians, --stress=2):
## - Volumetric froxels stay 24 x 12 (project.godot). 48 x 24 costs ~0-0.7 ms but changes the look:
##   the coarse grid is what spreads brazier and lantern light into warm haze (the Crossing lost its
##   warm pools) and fills the summit backdrop with glowing blue; finer reads cooler and darker.
## - SSIL: +2.8 to +5.6 ms. SSAO quality Low (vs Very Low): +0.5 to +1.5 ms, no visible gain. Both off.
## - Viewport debanding: free, but the grade's grain already dithers; no banding to fix (grade on or off).


static func apply(root: Node, env: Environment, cam: Camera3D, moon: DirectionalLight3D, far_m: float, fog_light: Color, vol_albedo: Color, vol_emit: Color) -> void:
	var t0 := Time.get_ticks_usec()
	cam.near = 0.08
	cam.far = far_m
	_fog(env, fog_light, vol_albedo, vol_emit)
	_moon(moon, far_m)
	_fog_volumes(root)
	LightPolicy.apply_all(root, moon)
	_cull_geometry(root, far_m)
	_occluders(root)
	_aim_sky_moon(env, moon)
	_swirl_vortex(env)
	_sky_flare(root, moon)
	if not _realm_retires(root, "Zone/Forest"):
		_thicken_canopy(root)                     # the Realm hides the old forest: no copy to make
	_thin_particles(root)
	SurfaceDetail.apply()
	apply_quality(env, cam)
	print("ATMOS apply %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))


## True when the Realm is on and `path` (or an ancestor of `n`) is one of the old layers it hides:
## the legacy floor rebucketing, canopy copy and trunk occluders would be work (and, for
## occluders, invisible walls) for geometry that is never shown.
static func _realm_retires(root: Node, path: String) -> bool:
	if not Realm.enabled():
		return false
	for r: String in Realm.RETIRED:
		if path == r or path.begins_with(r + "/"):
			return true
	return false


static func _retired_node(root: Node, n: Node) -> bool:
	if not Realm.enabled():
		return false
	return _realm_retires(root, str(root.get_path_to(n)))


static func _thin_particles(root: Node) -> void:
	for node in root.find_children("*", "GPUParticles3D", true, false):
		var p := node as GPUParticles3D
		var n := String(p.name).to_lower()
		if n.contains("flame"):
			continue
		var keep := 1.0
		if n.contains("rift") or n.contains("spirit"):
			keep = 0.22
		elif n.contains("ember") or n.contains("spore") or n.contains("firefly"):
			keep = 0.30
		elif n.contains("spark"):
			keep = 0.38
		elif p.amount > 80:
			keep = 0.35
		else:
			continue
		p.amount = maxi(int(round(float(p.amount) * keep)), 14)


static func apply_zone_settings(root: Node, env: Environment, cam: Camera3D, moon: DirectionalLight3D) -> void:
	set_fog(env, Settings.fog_enabled)
	apply_quality(env, cam)
	env.ssao_enabled = Settings.ssao_enabled
	env.glow_enabled = Settings.glow_enabled
	LightPolicy.apply_all(root, moon)
	_flora_detail(root)


## The setting is the volumetric fog (the costly part). Plain distance fog is the night's depth
## and always stays on. (The Performance preset used to switch volumetric off behind the toggle's
## back; it now does it through the toggle, which the menu shows.)
static func set_fog(env: Environment, on: bool) -> void:
	env.fog_enabled = true
	env.volumetric_fog_enabled = on


const HAZE_TOP := 4.0            ## world y below which the ground haze thickens (Realm ground sits about 0)
const HAZE_DENSITY := 0.03
const FOG_BEGIN := 36.0          ## m; the clear foreground (weather.gd OFF_BEGIN_* pulls it in for mist and rain)
const FOG_END := 1000.0


static func _fog(env: Environment, fog_light: Color, vol_albedo: Color, vol_emit: Color) -> void:
	env.fog_enabled = true
	env.fog_light_color = fog_light.lerp(Color(0.34, 0.46, 0.68), 0.55)    # silvered blue haze: the distance lightens into layers
	env.fog_light_energy = 0.74
	env.fog_sun_scatter = 0.2                  # the moon side of the haze is the brighter
	# Depth fog, not exponential: the near ~40 m stays clear (roofs, trunks and the player read dark and
	# crisp), then haze builds with distance into near / mid / far layers. fog_density is the ceiling.
	# The weather's mist pulls fog_depth_begin in (weather.gd), as it used to add to the density.
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 0.9
	env.fog_depth_begin = FOG_BEGIN
	env.fog_depth_end = FOG_END
	env.fog_depth_curve = 0.52
	env.fog_aerial_perspective = 0.72         # far land takes the sky's horizon colour, which falls off with height (vortex.gdshader)
	env.fog_sky_affect = 0.2
	# ENS art pass (docs/enshrouded/art.md): low ground haze that pools in hollows (the fen, the
	# rift floor) and thins on high ground. Plain depth fog, so it costs nothing per froxel.
	env.fog_height = HAZE_TOP
	env.fog_height_density = HAZE_DENSITY
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = vol_albedo
	env.volumetric_fog_emission = vol_emit
	env.volumetric_fog_emission_energy = 0.16
	env.volumetric_fog_anisotropy = 0.5           # forward scatter: the moon side of the sky glows through the fog, shafts read
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_detail_spread = 1.15
	env.volumetric_fog_sky_affect = 0.16
	env.volumetric_fog_ambient_inject = 0.08
	env.ambient_light_energy = 0.26
	# ambient mostly a set azure, less from the violet vortex sky (it cast magenta on all stone)
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.36, 0.52, 0.84)
	env.tonemap_exposure = 1.0           # ENS pass: the calmer grade (sat 1.36) turned blue chroma into luma; keep the night as dark
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.25
	env.ssao_light_affect = 0.32
	# (r35) no tonemap_white here: the night is AgX (environment.tres), which ignores it (white 1.0
	# against 6.5 moved nothing, exposure 2.0 moved YAVG 42 -> 70; zz/lane_a_bench env:). AgX has
	# its own tonemap_agx_white / _contrast, left at Godot's defaults: contrast 1.5 darkened the
	# frame 10-15 % and lowered saturation (duller), white 10 changed nothing that read.
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_glow_budget(env)


const MOON_ELEVATION := 29.0          ## degrees above the horizon


static func _moon(moon: DirectionalLight3D, far_m: float) -> void:
	# a lower moon (29 deg, was 34): shadows run long across the ground and the relief reads. The
	# azimuth is the scene's own (the sky moon and the shafts follow it).
	var heading := -moon.global_basis.z
	heading.y = 0.0
	if heading.length() > 0.01:
		heading = heading.normalized() * cos(deg_to_rad(MOON_ELEVATION)) + Vector3.DOWN * sin(deg_to_rad(MOON_ELEVATION))
		moon.global_basis = Basis.looking_at(heading, Vector3.UP)
	# a strong azure key: the moonlit stone and ground read bright blue over cool shadow
	# (it was 0.6 and lavender, so the flat ambient carried everything and the night read grey)
	moon.light_color = Color(0.62, 0.78, 1.0)
	moon.light_energy = maxf(moon.light_energy, 1.2)
	moon.light_volumetric_fog_energy = 1.45
	moon.light_angular_distance = 2.5
	moon.shadow_opacity = maxf(moon.shadow_opacity, 0.84)
	# the shadow map itself (atlas, splits, bias, range) is LightPolicy._moon's alone: it runs right
	# after this and again on every settings change (two copies here had drifted: fade 0.82 vs 0.78)
	moon.directional_shadow_max_distance = minf(moon.directional_shadow_max_distance, far_m * 0.5)


static func _fog_volumes(root: Node) -> void:
	for fv in root.find_children("*", "FogVolume", true, false):
		var mat: FogMaterial = fv.material as FogMaterial
		if mat == null:
			continue
		mat = mat.duplicate()
		fv.material = mat
		var fog_name := String(fv.name).to_lower()
		if fog_name.begins_with("shaft"):
			continue
		mat.edge_fade = maxf(mat.edge_fade, 0.55)
		if fog_name.contains("ground") or fog_name.contains("mist"):
			mat.density = minf(mat.density, 0.028)
			fv.position.y = 0.38
			var s: Vector3 = fv.size
			fv.size = Vector3(s.x, minf(s.y, 2.2), s.z)
		elif fog_name.contains("wood"):
			mat.density = minf(mat.density, 0.016)
		elif fog_name.contains("river") or fog_name.contains("water"):
			mat.density = minf(mat.density, 0.03)
		elif mat.density > 0.1:
			mat.density *= 0.65


## Tight halo only. The wide levels turned every flame into a fog bank.
static func _glow_budget(env: Environment) -> void:
	for i in 7:
		env.set_glow_level(i, i <= 1)


static func apply_quality(env: Environment, cam: Camera3D) -> void:
	env.ssr_enabled = Settings.ssr_enabled
	env.ssr_max_steps = 4
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2
	_glow_budget(env)
	var attrs := cam.attributes as CameraAttributesPractical
	if attrs == null:
		attrs = CameraAttributesPractical.new()
		cam.attributes = attrs
	# The sky is the far plane. Far blur smears the stars, so it stays off.
	attrs.dof_blur_far_enabled = false
	attrs.dof_blur_near_enabled = false
	_detail(cam)


## World detail (Settings.detail, set by the presets): how many pixels a mesh may lose before it
## drops a LOD level, and occlusion culling. Colours, fog and light values are untouched.
const LOD_THRESHOLD := [4.0, 1.6, 1.0]        ## pixels; Godot's default is 1.0


static func _detail(cam: Camera3D) -> void:
	var vp := cam.get_viewport() if cam and cam.is_inside_tree() else null
	if vp == null:
		return
	var d := clampi(Settings.detail, 0, 2)
	vp.mesh_lod_threshold = LOD_THRESHOLD[d]
	vp.use_occlusion_culling = not ("--no-occlusion" in OS.get_cmdline_user_args())


## Undergrowth density and ranges follow the detail level (realm_flora.gd apply_detail).
static func _flora_detail(root: Node) -> void:
	var flora: Node = root.get_node_or_null("RealmFlora") if root else null
	if flora:
		(load("res://core/world/realm/realm_flora.gd") as GDScript).call("apply_detail", flora, clampi(Settings.detail, 0, 2))


static func _cull_geometry(root: Node, far_m: float) -> void:
	var realm := Realm.enabled()
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		if _under_player(gi) or _under_enemy(gi):
			continue
		if realm and _retired_node(root, gi):
			continue
		var n := String(gi.name).to_lower()
		# Visibility range is distance to the *node origin*, not the mesh. The
		# stair is one ArrayMesh at (0,0,0) that runs 75 m to the summit — a
		# 57 m fade hid the treads underfoot, then one step toward origin
		# brought the whole flight back. Same trap as ForestFloor / lava.
		if gi.is_in_group(Groups.CULL_SKIP) or _named_under(gi, "Lava") or _named_under(gi, "ForestFloor"):
			continue
		if gi.is_in_group(Groups.CULL_SPAN) or _is_span_mesh(gi, n):
			if not gi.is_in_group(Groups.CULL_SPAN):
				gi.add_to_group(Groups.CULL_SPAN)
			_pin_span(gi)
			continue
		if _skips_range(n):
			gi.add_to_group(Groups.CULL_SKIP)
			continue
		var end := 0.0
		var margin := 6.0
		var cull := 0.0
		if gi.is_in_group(Groups.CULL_FOLIAGE) or n.begins_with("spore") or n.begins_with("cap") or n.begins_with("night") or n.begins_with("pebble") or n.begins_with("fern") or n.begins_with("grass"):
			gi.add_to_group(Groups.CULL_FOLIAGE)
			end = 32.0
			margin = 10.0
			cull = 8.0
			if n.begins_with("spore"):
				end = 24.0
			elif n.begins_with("pebble"):
				end = 28.0
				margin = 8.0
		elif gi is GPUParticles3D:
			end = 22.0
			margin = 6.0
		elif gi.visibility_range_end > 0.01:
			end = minf(gi.visibility_range_end, far_m * 0.62)
			margin = maxf(gi.visibility_range_end_margin, 6.0)
		else:
			end = far_m * 0.55
			margin = 8.0
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = margin
		gi.visibility_range_fade_mode = (
			GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED if end <= 0.01
			else GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		)
		if cull > 0.0:
			gi.extra_cull_margin = maxf(gi.extra_cull_margin, cull)
	if not _realm_retires(root, "Zone/ForestFloor"):
		_cell_floor(root)
	_pin_named_spans(root)


## Visibility range is distance to the *node origin*. Baked floor chunks sat at (0,0,0)
## with world-space instance transforms, so they could not cull. Rebucket into 16 m cells
## with the node at the cell centre and instances relative — no main.tscn rebake.
static func _cell_floor(root: Node) -> void:
	var floor := root.find_child("ForestFloor", true, false) as Node3D
	if floor == null:
		return
	const CELL := 16.0
	var vis := {
		"grass": 72.0, "fern": 88.0, "cap": 96.0, "nightcap": 96.0,
		"pebble": 72.0, "spore": 64.0,
	}
	var buckets := {}
	var old: Array[Node] = []
	for node in floor.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mm: MultiMesh = mmi.multimesh
		if mm == null or mm.instance_count < 1:
			continue
		var kind := "grass"
		var nm := String(mmi.name).to_lower()
		for k in vis.keys():
			if nm.begins_with(String(k)):
				kind = String(k)
				break
		old.append(mmi)
		for i in mm.instance_count:
			var world: Transform3D = mmi.global_transform * mm.get_instance_transform(i)
			var key := Vector2i(floori(world.origin.x / CELL), floori(world.origin.z / CELL))
			var cell_key := "%s_%d_%d" % [kind, key.x, key.y]
			if not buckets.has(cell_key):
				buckets[cell_key] = {
					"kind": kind, "key": key, "mesh": mm.mesh, "mat": mmi.material_override,
					"colors": mm.use_colors, "xfs": [], "cols": [],
				}
			var b: Dictionary = buckets[cell_key]
			b.xfs.append(world)
			if mm.use_colors:
				b.cols.append(mm.get_instance_color(i))
	for n in old:
		floor.remove_child(n)
		n.free()
	for cell_key in buckets:
		var b: Dictionary = buckets[cell_key]
		var xfs: Array = b.xfs
		var y_sum := 0.0
		for xf in xfs:
			y_sum += xf.origin.y
		var centre := Vector3(
			(float(b.key.x) + 0.5) * CELL,
			y_sum / float(xfs.size()),
			(float(b.key.y) + 0.5) * CELL)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = b.colors
		mm.mesh = MeshChunks.with_lods(b.mesh)      # caps and spheres are 48-300 tris each, thousands of them
		mm.instance_count = xfs.size()
		var box := AABB()
		for i in xfs.size():
			var local := Transform3D(xfs[i].basis, xfs[i].origin - centre)
			mm.set_instance_transform(i, local)
			if i == 0:
				box = AABB(local.origin, Vector3.ZERO)
			else:
				box = box.expand(local.origin)
			if mm.use_colors:
				mm.set_instance_color(i, b.cols[i])
		mm.custom_aabb = box.grow(8.0)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = cell_key
		mmi.multimesh = mm
		mmi.material_override = b.mat
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Vis-range is camera-to-cell-centre. Keep it well past one 16 m cell so the next
		# patch is already drawn; FADE_SELF on alpha-scissor grass reads as a pop.
		mmi.visibility_range_end = float(vis.get(b.kind, 72.0))
		mmi.visibility_range_end_margin = 24.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mmi.extra_cull_margin = 16.0
		mmi.ignore_occlusion_culling = true
		floor.add_child(mmi)


static func _skips_range(n: String) -> bool:
	const SKIP := [
		"terrain", "water", "river", "glass", "mirror", "nave", "window",
		"masonry", "starburst", "flare", "flame", "fire", "coals", "lava", "ember",
	]
	for key in SKIP:
		if n.contains(key):
			return true
	return false


## Walkable / unique world meshes sit at the zone origin with vertices tens of
## metres away. A visibility_range on those is a close-range vanish.
static func _is_span_mesh(gi: GeometryInstance3D, n: String) -> bool:
	const KEEP := [
		"stair", "sanctuary", "ruin", "boulder", "bridge", "dock",
		"walk", "approach", "path", "deck", "arch", "gate", "column",
		"pillar", "wall", "canopy", "leaf", "trunk", "bark", "tree",
		"haven", "grotto", "cave", "tablet", "lore", "forest",
		"tavern", "keg", "dwarf", "landmark", "cairn", "watch",
	]
	for key in KEEP:
		if n.contains(key):
			return true
	var mi := gi as MeshInstance3D
	if mi != null and mi.mesh != null:
		if mi.mesh.get_aabb().size.length() > 22.0:
			return true
	return false


static func _pin_span(gi: GeometryInstance3D) -> void:
	gi.visibility_range_end = 0.0
	gi.visibility_range_end_margin = 0.0
	gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	gi.extra_cull_margin = maxf(gi.extra_cull_margin, 40.0)
	gi.ignore_occlusion_culling = true
	var mi := gi as MeshInstance3D
	if mi != null and mi.mesh != null and mi.custom_aabb.size.length() < 1.0:
		mi.custom_aabb = mi.mesh.get_aabb().grow(8.0)


static func _pin_named_spans(root: Node) -> void:
	for mesh_name in ["Stair", "Sanctuary", "Ruins", "DeadTrees", "GiantTrunks", "Boulders", "Terrain", "TerrainHeart"]:
		var mi := root.find_child(mesh_name, true, false) as MeshInstance3D
		if mi == null:
			continue
		_pin_span(mi)


static func _occluders(root: Node) -> void:
	if root.get_node_or_null("Occluders") != null:
		return
	var group := Node3D.new()
	group.name = "Occluders"
	root.add_child(group)
	for col in root.find_children("*", "CollisionShape3D", true, false):
		# Only trunks. Architecture boxes ate the stair when you stood on it,
		# and spawning an occluder per rock is more raster work than it saves.
		if not col.is_in_group(Groups.OCCLUDER_TRUNK) and not String(col.name).begins_with("Trunk"):
			continue
		if not col.is_in_group(Groups.OCCLUDER_TRUNK):
			col.add_to_group(Groups.OCCLUDER_TRUNK)
		if _under_player(col) or _skip_occluder(col) or _retired_node(root, col):
			continue
		var shape: Shape3D = (col as CollisionShape3D).shape
		if shape == null:
			continue
		var size := Vector3.ZERO
		if shape is BoxShape3D:
			size = (shape as BoxShape3D).size
		elif shape is CylinderShape3D:
			var c := shape as CylinderShape3D
			size = Vector3(c.radius * 1.7, c.height, c.radius * 1.7)
		elif shape is CapsuleShape3D:
			var k := shape as CapsuleShape3D
			size = Vector3(k.radius * 1.7, k.height, k.radius * 1.7)
		else:
			continue
		if size.x > 14.0 or size.y > 16.0 or size.z > 14.0:
			continue
		if size.x < 0.35 or size.y < 0.8:
			continue
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = size
		occ.occluder = box
		group.add_child(occ)
		occ.global_transform = (col as CollisionShape3D).global_transform


# --- occlusion culling (r22) ----------------------------------------------------------------------
## The viewport's occlusion culling is switched on in apply_quality (it was never on: the old trunk
## occluders did nothing). Occluders must sit *inside* what they stand for, or things behind an
## occluder vanish while the real surface would have shown them; everything below is built shrunk.

const OCC_SHRINK := 0.07          ## OssKit bevels every arris by up to 4.5 cm: stay inside that
const OCC_MIN_FACE := 1.2         ## a kit box must be at least this wide and tall to occlude
const OCC_MIN_THICK := 0.14


## Builders' solid boxes (OssKit.commit hands them over): one ArrayOccluder3D per kit commit, in the
## parent's space, from the boxes big enough to hide something (walls, piers, floors, towers).
## Thin rails, bars and trim stay out. Returns how many boxes went in.
static func kit_occluder(parent: Node3D, solids: Array) -> int:
	if parent == null or solids.is_empty() or "--no-occluders" in OS.get_cmdline_user_args():
		return 0
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for sb: Array in solids:
		var c: Vector3 = sb[0]
		var b: Basis = sb[1]
		var h: Vector3 = (sb[2] as Vector3).abs()
		var dims := [h.x * 2.0, h.y * 2.0, h.z * 2.0]
		dims.sort()
		if dims[0] < OCC_MIN_THICK or dims[1] < OCC_MIN_FACE:
			continue
		h = (h - Vector3.ONE * OCC_SHRINK).max(Vector3.ONE * 0.02)
		var base := verts.size()
		for k in 8:
			verts.append(c + b.x * (h.x if k & 1 else -h.x) + b.y * (h.y if k & 2 else -h.y) + b.z * (h.z if k & 4 else -h.z))
		for f: Array in _BOX_TRIS:
			idx.append(base + int(f[0]))
			idx.append(base + int(f[1]))
			idx.append(base + int(f[2]))
	if idx.is_empty():
		return 0
	var occ := OccluderInstance3D.new()
	occ.name = "KitOccluder"
	var ao := ArrayOccluder3D.new()
	ao.set_arrays(verts, idx)
	occ.occluder = ao
	parent.add_child(occ)
	return verts.size() / 8


const _BOX_TRIS := [[0, 1, 3], [0, 3, 2], [4, 6, 7], [4, 7, 5], [0, 4, 5], [0, 5, 1],
	[2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3]]


## After the Realm is built (PerfWatch calls this once `realm_done` is set; skipped headless):
## flora detail, LightPolicy.realm_pass, _realm_render_pass (below, spread over frames) and the
## terrain as an occluder. Hills hide whole tree chunks behind them in the Thornwood and on the crags. Built at
## 4 m from the final terrain grid (after TerrainStamp), each vertex lowered to the lowest ground in
## its 4 m neighbourhood (so every occluder triangle stays under the real surface) and a little
## more; the Ossuary (a crypt under the ground) and its fen cut are left out.
static func post_build(root: Node) -> void:
	if root == null or root.has_meta("post_built") or DisplayServer.get_name() == "headless":
		return                                      # nothing is drawn headless: tests keep the built tree
	root.set_meta("post_built", true)
	var t := Time.get_ticks_usec()
	var tris := _terrain_occluder(root)
	var t_occ := Time.get_ticks_usec() - t
	_flora_detail(root)
	var lp: Array = LightPolicy.realm_pass(root)
	print("ATMOS realm lights %d: %d given a distance fade, shadows kept %d, off %d" % lp)
	var st: Vector4i = await _realm_render_pass(root)
	if not is_instance_valid(root):
		return
	print("ATMOS post-build: terrain occluder %d triangles (%.1f ms); %d spread meshes -> %d chunks; %d tiny shadow casters off; %d particle ranges; %.1f ms over %d frames" % [
		tris, t_occ / 1000.0, st.x, st.y, st.z, st.w, (Time.get_ticks_usec() - t) / 1000.0, _pass_frames])
	root.set_meta("post_done", true)                # the loading screen waits for this


static var _pass_frames := 0
const PASS_BUDGET_US := 6000        ## per frame: the pass runs during the first second of play


## One pass over what the Realm modules built (they run after Atmosphere.apply, so _cull_geometry
## never saw them):
##  - MultiMeshes spread over more than SPREAD_M are split into cells (MeshChunks.split_multimesh):
##    per-cell LOD and frustum culling, and a visibility range measured from each cell
##  - meshes smaller than TINY_SHADOW_M stop casting moon shadows (candles, bones, pebbles: a few
##    pixels of shadow, a full draw in every shadow split each)
##  - particles get a visibility range (GPU particles are simulated only while visible), except
##    flames, lava, embers and the other always-seen kinds
const SPREAD_M := 48.0
const TINY_SHADOW_M := 0.45
const PARTICLE_END := 48.0


## A heavy mesh spanning more than SPREAD_M with no LODs and no chunking yet.
static func _span_heavy(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or not mi.visible or mi.has_meta("chunked") or mi.mesh.get_surface_count() == 0:
		return false
	if String(mi.name).begins_with("Terrain") or mi.is_in_group(Groups.CULL_SPAN) or _skips_range(String(mi.name).to_lower()):
		return false
	var box := mi.global_transform * mi.mesh.get_aabb()
	if maxf(box.size.x, box.size.z) < SPREAD_M:
		return false
	if (RenderingServer.mesh_get_surface(mi.mesh.get_rid(), 0).get("lods", []) as Array).size() > 0:
		return false
	var am := mi.mesh as ArrayMesh
	if am == null:
		return false
	var tris := 0
	for si in am.get_surface_count():
		var n := am.surface_get_array_index_len(si)
		tris += (n if n > 0 else am.surface_get_array_len(si)) / 3
	return tris >= 4000


static func _realm_render_pass(root: Node) -> Vector4i:
	var split := 0
	var cells := 0
	var shadows := 0
	var parts := 0
	var skip_flora := root.get_node_or_null("RealmFlora")
	var tree := root.get_tree()
	var slice := Time.get_ticks_usec()
	_pass_frames = 1
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		if Time.get_ticks_usec() - slice > PASS_BUDGET_US:
			await tree.process_frame
			slice = Time.get_ticks_usec()
			_pass_frames += 1
		if not is_instance_valid(n):
			continue
		var gi := n as GeometryInstance3D
		if _under_player(gi) or _under_enemy(gi) or (skip_flora and skip_flora.is_ancestor_of(gi)):
			continue
		if _retired_node(root, gi):
			continue
		if gi is GPUParticles3D:
			var gp := gi as GPUParticles3D
			if gp.visibility_range_end <= 0.0 and not _skips_range(String(gp.name).to_lower()) and not _named_under(gp, "Lava"):
				gp.visibility_range_end = PARTICLE_END
				gp.visibility_range_end_margin = 8.0
				gp.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				parts += 1
			continue
		var mesh: Mesh = null
		var mmi := gi as MultiMeshInstance3D
		if mmi != null and mmi.multimesh != null and mmi.visible and not mmi.has_meta("chunked"):
			mesh = mmi.multimesh.mesh
			var box := mmi.multimesh.get_aabb()
			if maxf(box.size.x, box.size.z) > SPREAD_M and mmi.multimesh.instance_count >= 8:
				var made := MeshChunks.split_multimesh(mmi)
				if made > 0:
					split += 1
					cells += made
					continue
		elif gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			mesh = mi.mesh
			if _span_heavy(mi):
				# one mesh over a whole village or road: never culled, never LOD'd, in every shadow
				# split. 24 m chunks with LODs (cached on disk by content), like the Crossing's.
				var leafy := String(mi.name).to_lower().contains("leaf") or String(mi.name).to_lower().contains("card")
				var made := MeshChunks.split(mi, not leafy)
				if made > 0:
					split += 1
					cells += made
					continue
			# far detail: what the Realm built ends by its size with a dither fade (landmarks never end);
			# the camera sees FarDetail.VIEW_FAR now. Only meshes whose node origin is near the mesh (the
			# range is measured to the origin, and a baked-in-world-coordinates mesh sits far from it).
			if mi.mesh != null and mi.visible:
				var ab := mi.mesh.get_aabb()
				var gs := mi.global_basis.get_scale()
				var ext := maxf(ab.size.x * gs.x, maxf(ab.size.y * gs.y, ab.size.z * gs.z))
				if ab.get_center().length() <= maxf(ext, 3.0) + 1.0:
					FarDetail.generic_range(mi, ext)
		if mesh != null and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var sz := mesh.get_aabb().size
			var sc := gi.global_basis.get_scale()
			if mmi != null and mmi.multimesh.instance_count > 0 and DisplayServer.get_name() != "headless":
				sc *= mmi.multimesh.get_instance_transform(0).basis.get_scale()
			if maxf(sz.x * sc.x, maxf(sz.y * sc.y, sz.z * sc.z)) < TINY_SHADOW_M:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				shadows += 1
	# the chunks split_multimesh added are new nodes: they inherit the original's settings
	return Vector4i(split, cells, shadows, parts)


static func _terrain_occluder(root: Node) -> int:
	if "--no-occluders" in OS.get_cmdline_user_args():
		return 0
	var terrain := root.get_node_or_null("Zone/Terrain") as MeshInstance3D
	if terrain == null or terrain.mesh == null or terrain.get_node_or_null("TerrainOccluder") != null:
		return 0
	var verts: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# the Realm terrain is a regular grid: find its row length from the first row's x
	var nx := 1
	while nx < verts.size() and is_equal_approx(verts[nx].z, verts[0].z):
		nx += 1
	if nx < 3 or verts.size() % nx != 0:
		return 0
	var nz := verts.size() / nx
	const S := 2                                   # 2 m grid -> 4 m occluder grid
	const DROP := 0.35
	var ob := RealmLayout.OSSUARY
	var skip := Rect2(ob.position.x - 10.0, ob.position.z - 8.0, ob.size.x + 20.0, ob.size.z + 16.0)
	var cx := (nx - 1) / S + 1
	var cz := (nz - 1) / S + 1
	var ov := PackedVector3Array()
	ov.resize(cx * cz)
	var keep := PackedByteArray()
	keep.resize(cx * cz)
	for j in cz:
		for i in cx:
			var fi := mini(i * S, nx - 1)
			var fj := mini(j * S, nz - 1)
			var lo := INF
			for dj in range(-S, S + 1):
				for di in range(-S, S + 1):
					var a := clampi(fi + di, 0, nx - 1)
					var b := clampi(fj + dj, 0, nz - 1)
					lo = minf(lo, verts[b * nx + a].y)
			var v := verts[fj * nx + fi]
			ov[j * cx + i] = Vector3(v.x, lo - DROP, v.z)
			keep[j * cx + i] = 0 if skip.has_point(Vector2(v.x, v.z)) else 1
	var idx := PackedInt32Array()
	for j in cz - 1:
		for i in cx - 1:
			var a := j * cx + i
			var b := a + 1
			var c := a + cx
			var d := c + 1
			if keep[a] == 0 or keep[b] == 0 or keep[c] == 0 or keep[d] == 0:
				continue
			idx.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var occ := OccluderInstance3D.new()
	occ.name = "TerrainOccluder"
	var ao := ArrayOccluder3D.new()
	ao.set_arrays(ov, idx)
	occ.occluder = ao
	terrain.add_child(occ)
	return idx.size() / 3


static func _skip_occluder(n: Node) -> bool:
	var p := n
	while p:
		if p is Brazier:
			return true
		var nm := String(p.name)
		if nm in ["Bridge", "Dock", "Braziers", "Flame", "Walk", "Approach", "Stair", "StairBody", "Sanctuary", "SanctuaryBody", "Ruins", "RuinsBody", "Terrain", "TerrainBody", "Boulders", "BouldersBody"]:
			return true
		p = p.get_parent()
	return false


static func _named_under(n: Node, ancestor: String) -> bool:
	var p := n
	while p:
		if String(p.name) == ancestor:
			return true
		p = p.get_parent()
	return false


static func _under_player(n: Node) -> bool:
	var p := n
	while p:
		if p.is_in_group("player") or p.has_method("hollow"):
			return true
		p = p.get_parent()
	return false


static func _under_enemy(n: Node) -> bool:
	var p := n
	while p:
		if p.is_in_group(Groups.ENEMY):
			return true
		p = p.get_parent()
	return false


static func _swirl_vortex(env: Environment) -> void:
	if env == null or env.sky == null:
		return
	var mat := env.sky.sky_material as ShaderMaterial
	if mat == null or mat.shader == null:
		return
	if not String(mat.shader.resource_path).ends_with("vortex.gdshader"):
		return
	# Radiance cubemap is TIME-less (vortex.gdshader AT_CUBEMAP_PASS). REALTIME re-rendered
	# six identical faces every frame; QUALITY bakes once and on property change.
	env.sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky.radiance_size = Sky.RADIANCE_SIZE_256


static func _aim_sky_moon(env: Environment, moon: DirectionalLight3D) -> void:
	if env == null or env.sky == null or moon == null:
		return
	var mat := env.sky.sky_material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("moon_dir", moon.global_basis.z)


static func _sky_flare(root: Node, moon: DirectionalLight3D) -> void:
	if moon == null:
		return
	var flare := root.get_node_or_null("SkyFlare") as MeshInstance3D
	if flare == null:
		flare = MeshInstance3D.new()
		flare.name = "SkyFlare"
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var q := QuadMesh.new()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://world/sky_flare.gdshader")
		mat.set_shader_parameter("color", Color(0.58, 0.78, 1.12, 1.0))
		q.material = mat
		flare.mesh = q
		root.add_child(flare)
		flare.set_script(load("res://world/sky_flare.gd"))
		flare.set("moon", moon)
	if flare.mesh is QuadMesh:
		(flare.mesh as QuadMesh).size = Vector2(8.0, 8.0)


static func _thicken_canopy(root: Node) -> void:
	var canopy := root.find_child("Canopy", true, false) as MeshInstance3D
	if canopy == null or canopy.has_meta("thickened") or canopy.mesh == null:
		return
	canopy.set_meta("thickened", true)
	_canopy_fill(canopy, "CanopyFill", Vector3(1.16, 1.12, 1.16), 0.55, 0.37)


## A second, slightly larger and turned copy of every crown, about that crown's own centre, so
## the canopy reads dense. (It used to scale and rotate the whole Canopy node about the world
## origin, which threw every copy 5-15 m off its tree: a second forest of crowns with no trunks.)
static func _canopy_fill(canopy: MeshInstance3D, fill_name: String, sc: Vector3, lift: float, yaw: float) -> void:
	var old := canopy.get_parent().get_node_or_null(fill_name)
	if old:
		old.get_parent().remove_child(old)
		old.free()
	var fill := canopy.duplicate() as MeshInstance3D
	fill.name = fill_name
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var src := canopy.mesh
	var out := ArrayMesh.new()
	var turn := Basis(Vector3.UP, yaw).scaled(sc)
	for si in src.get_surface_count():
		var arrays := src.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var comp := SeatProps.island_of(verts, idx)
		var sum := {}
		for vi in verts.size():
			if comp[vi] >= 0:
				var acc: Array = sum.get(comp[vi], [Vector3.ZERO, 0])
				sum[comp[vi]] = [acc[0] + verts[vi], int(acc[1]) + 1]
		var rot := Basis(Vector3.UP, yaw)
		for vi in verts.size():
			if comp[vi] < 0:
				continue
			var acc: Array = sum[comp[vi]]
			var c: Vector3 = acc[0] / float(acc[1])
			verts[vi] = c + turn * (verts[vi] - c) + Vector3.UP * lift
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for vi in nrm.size():
				nrm[vi] = rot * nrm[vi]
			arrays[Mesh.ARRAY_NORMAL] = nrm
		arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, src.surface_get_material(si))
	fill.mesh = out
	fill.custom_aabb = AABB()
	canopy.get_parent().add_child(fill)


## Rebuild the fill from the canopy as it is now: after site clearance removed crowns and the
## terraces moved them (SeatProps.follow_terrain), the old copy would hang where they used to be.
static func refresh_canopy_fill(root: Node) -> void:
	var canopy := root.find_child("Canopy", true, false) as MeshInstance3D
	if canopy == null or canopy.mesh == null or not canopy.has_meta("thickened"):
		return
	_canopy_fill(canopy, "CanopyFill", Vector3(1.16, 1.12, 1.16), 0.55, 0.37)
