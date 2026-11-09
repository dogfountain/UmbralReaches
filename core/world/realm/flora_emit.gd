extends RefCounted
## Nodes of the Realm flora: the placement's final buffers (kind -> chunk -> 16 floats per plant,
## origin relative to the chunk node) become one MultiMeshInstance3D per (kind, mesh part, chunk),
## the trunks' colliders and the far canopy shells. Split from realm_flora.gd, which places.
##
## One chunk node per 24 m (undergrowth and the stones in the turf) or 32 m (tall trees); the stones
## share the undergrowth's chunk node and its StaticBody (they used to open a Node3D of their own
## for every stone variant in every chunk).

const TreeGen := preload("res://core/world/realm/tree_gen.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")

const CHUNK := 24.0                    ## undergrowth chunks
const TREE_CHUNK := 32.0               ## tree chunks
const FAR_UNDER := 12.0                ## far mesh begins this much nearer than the near tree's end (underlap for crossfade)
const FAR_FADE := 12.0                 ## metres the far / near stand-in dissolves over
const NEAR_END := 48.0                 ## keep near crowns longer before the @far swap (was 38)
const STONE_RANGE := 56.0
const STONE_SIZES := [Vector3(0.55, 0.34, 0.48), Vector3(0.9, 0.5, 0.75)]

## species groups: visibility range end (0 = none: the camera far plane ends them),
## shadows, keep-off path distance (m from the path edge), clearance from sites
const STYLE := {
	"grass": [52.0, false, 1.0, 0.6], "tallgrass": [56.0, false, 3.0, 0.8], "flowers": [48.0, false, 3.0, 0.6],
	"heather": [52.0, false, 3.0, 0.6], "fern": [60.0, false, 3.0, 1.0], "shrub": [72.0, false, 3.5, 1.5],
	"bramble": [72.0, false, 3.5, 2.0], "litter": [44.0, false, 3.0, 0.8], "moss": [46.0, false, 3.0, 0.8],
	"mushroom": [36.0, false, 3.0, 0.8], "glowcap": [58.0, false, 3.0, 0.8], "reeds": [64.0, false, 3.0, 0.8],
	"cattail": [64.0, false, 3.0, 0.8], "log": [80.0, true, 3.5, 3.0], "stump": [70.0, false, 3.0, 1.5],
	"roots": [62.0, false, 3.0, 1.5],
	"stone": [56.0, false, 1.2, 1.0],                                  # stones in the turf (_place_stones)
	"oak": [0.0, true, 3.5, 0.0], "birch": [0.0, true, 3.0, 0.0], "pine": [0.0, true, 3.0, 0.0],
	"willow": [0.0, true, 3.0, 0.0], "snag": [0.0, true, 3.0, 0.0], "sapling": [72.0, false, 3.0, 1.5],
	"fruit": [0.0, true, 3.0, 0.0], "cypress": [0.0, true, 3.0, 0.0], "yew": [0.0, true, 3.5, 0.0], "windtree": [0.0, true, 3.0, 0.0],
	"gorse": [64.0, false, 3.0, 1.2], "deadbush": [60.0, false, 3.0, 1.2], "ashdrift": [44.0, false, 2.0, 0.8],
	"cinders": [40.0, false, 2.5, 0.8], "lily": [58.0, false, 1.0, 0.5], "scaffold": [64.0, false, 3.0, 2.0],
}

## The regions' own stone (LOOKS props), per m2 at full look weight. [mesh, size, style
## override ("" = the look's), sink fraction, visibility range, collides]
const PROPS := {
	"rubble": ["boulder", Vector3(0.42, 0.26, 0.36), "", 0.3, 40.0, false],
	"block": ["slab", Vector3(1.15, 0.6, 0.72), "granite", 0.12, 64.0, true],
	"slag": ["boulder", Vector3(0.95, 0.5, 0.8), "ash", 0.35, 56.0, false],
	"headstone": ["slab", Vector3(0.55, 0.78, 0.16), "granite", 0.1, 48.0, false],
	"cairn": ["cairn", Vector3(0.95, 1.25, 0.9), "granite", 0.05, 72.0, true],
}

const FADE_BAND := 10.0                ## realm_foliage.gdshader thins over fade_end .. fade_end + band

## Undergrowth share kept and range scale per detail level (0 low, 1 medium, 2 high). Medium is the
## look as built. Low keeps more cover than before (0.6 read as bald patches when turning).
const DETAIL_DENSITY := [0.78, 1.0, 1.0]
const DETAIL_RANGE := [0.88, 1.0, 1.12]


## Which chunk size and tag a plant kind sits in: [chunk size, tag (1 = tall tree chunk)].
static func chunk_of(id: String) -> Vector2:
	var tall := bool(TreeGen.kind(id).tall)
	return Vector2(TREE_CHUNK if tall else CHUNK, 1.0 if tall else 0.0)


static func _chunk(host: Node3D, chunks: Dictionary, key: Vector3i, csize: float, ground: Callable) -> Node3D:
	var ch: Node3D = chunks.get(key)
	if ch == null:
		ch = Node3D.new()
		ch.name = "%s_%d_%d" % ["Trees" if key.z == 1 else "Chunk", key.x, key.y]
		host.add_child(ch)
		var cx := (key.x + 0.5) * csize
		var cz := (key.y + 0.5) * csize
		ch.position = Vector3(cx, ground.call(cx, cz), cz)
		chunks[key] = ch
	return ch


static func _basis_at(buf: PackedFloat32Array, o: int) -> Basis:
	return Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]), Vector3(buf[o + 2], buf[o + 6], buf[o + 10]))


static var _lod_ready := {}            ## kind key -> mesh with LODs made for this emit


## LODs for every [kind key, solid mesh] pair, generated at once on the worker pool
## (ImporterMesh.generate_lods is native and independent per mesh -- about 40 ms for all of them on
## eight cores, against ~3 ms a mesh to read them back from disk); the arrays are read and the
## mesh built on the main thread.
static func _prefetch_lods(pairs: Array) -> void:
	var todo: Array = []
	for p: Array in pairs:
		if not _lod_ready.has(p[0]):
			todo.append([p[0], p[1], _importer(p[1])])
	if todo.is_empty():
		return
	var tl := Time.get_ticks_usec()
	# Preserve shape in mid LODs (merge 20°): with lod_bias/threshold softened, switches stay late and look like the same tree.
	var task := WorkerThreadPool.add_group_task(func(i: int) -> void: (todo[i][2] as ImporterMesh).generate_lods(20.0, 60.0, []), todo.size())
	WorkerThreadPool.wait_for_group_task_completion(task)
	for t: Array in todo:
		_lod_ready[t[0]] = _with_materials((t[2] as ImporterMesh).get_mesh(), t[1])
	Realm.prof_add("gen: with_lods", tl)


static func _importer(m: Mesh) -> ImporterMesh:
	var im := ImporterMesh.new()
	for s in m.get_surface_count():
		var arrays := m.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_INDEX] == null:
			# LOD generation needs an index buffer
			var idx := PackedInt32Array()
			idx.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
			for i in idx.size():
				idx[i] = i
			arrays[Mesh.ARRAY_INDEX] = idx
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, m.surface_get_material(s))
	return im


static func _with_materials(m: Mesh, solid: Mesh) -> Mesh:
	for i in m.get_surface_count():
		if m.surface_get_material(i) == null:
			m.surface_set_material(i, solid.surface_get_material(i))
	return m


static func emit(host: Node3D, items: Dictionary, stones: Dictionary, canopy: Dictionary, ground: Callable, prop_mesh: Callable) -> Vector2i:
	var chunks := {}                    # Vector3i(x, z, tall) -> Node3D
	var bodies := {}                    # Vector3i -> StaticBody3D
	var counts := Vector2i.ZERO
	var hide_args: Array = []
	for a in OS.get_cmdline_user_args():           # perf probes: --flora-hide=oak,grass,s,c
		if a.begins_with("--flora-hide="):
			hide_args.append(a.trim_prefix("--flora-hide=").split(","))
	var lods: Array = []
	for id: String in items:
		var kd: Dictionary = TreeGen.kind(id)
		if kd.solid != null:
			lods.append([id, kd.solid])
		if bool(kd.tall) and id.substr(0, id.rfind("_")) in TreeGen.FAR:
			var fk: Dictionary = TreeGen.kind(id + "@far")
			if fk.solid != null:
				lods.append([id + "@far", fk.solid])
	_prefetch_lods(lods)
	for id: String in items:
		var d: Dictionary = TreeGen.kind(id)
		var sp := id.substr(0, id.rfind("_"))
		var st: Array = STYLE[sp]
		var tall := bool(d.tall)
		var csize := TREE_CHUNK if tall else CHUNK
		var meshes: Array = []          # [mesh, tag, range begin, range end]
		var swap := tall and sp in TreeGen.FAR
		var near_end := NEAR_END if swap else float(st[0])
		if d.solid != null:
			meshes.append([_lod_ready[id], "s", 0.0, near_end])
		if d.cards != null:
			meshes.append([d.cards, "c", 0.0, near_end])
		if swap:
			var fd: Dictionary = TreeGen.kind(id + "@far")
			if fd.solid != null:
				meshes.append([_lod_ready[id + "@far"], "fs", NEAR_END, 0.0])
			if fd.cards != null:
				meshes.append([fd.cards, "fc", NEAR_END, 0.0])
		var per: Dictionary = items[id]
		for key: Vector3i in per:
			# (packed arrays are shared on assignment: the editors rewrite this copy in place -- the
			# clearings, the withering -- and the placement's own buffers stay as placed)
			var buf: PackedFloat32Array = (per[key] as PackedFloat32Array).duplicate()
			var ch := _chunk(host, chunks, key, csize, ground)
			var n := buf.size() / 16
			for m: Array in meshes:
				counts.x += 1
				_batch(ch, buf, n, "Flora_%s_%s" % [id, m[1]], m[0], m[1], m[2], m[3], [sp, m[1], tall, m[3], n], st, swap, hide_args)
			# collision: tall trunks, logs, stumps
			var solid_r: float = d.r
			if solid_r > 0.0 and ((tall and float(d.h) > 4.0) or sp == "log" or sp == "stump"):
				var body := _body(ch, bodies, key)
				for i in n:
					var o := i * 16
					var sc := Vector3(buf[o], buf[o + 4], buf[o + 8]).length()
					var org := Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
					var cs := CollisionShape3D.new()
					if sp == "log":
						var bx := BoxShape3D.new()
						bx.size = Vector3(float(d.spread) * 2.0 * sc, solid_r * 1.6 * sc, solid_r * 1.6 * sc)
						cs.shape = bx
						var bas := _basis_at(buf, o)
						cs.transform = Transform3D(bas.orthonormalized(), org + bas.y.normalized() * solid_r * 0.55 * sc)
					else:
						var cy := CylinderShape3D.new()
						var hh := 3.5 if sp != "stump" else float(d.h) * sc
						cy.radius = solid_r * sc * (0.95 if sp != "stump" else 1.0)
						cy.height = hh
						cs.shape = cy
						cs.position = org + Vector3(0, hh * 0.5, 0)
					body.add_child(cs)
					counts.y += 1
	for key: String in stones:
		var mesh: Mesh = prop_mesh.call(key)
		var kind := key.split("|")[0]
		var pr: Array = PROPS.get(kind, ["", STONE_SIZES[0], "", 0.0, STONE_RANGE, false])
		var per: Dictionary = stones[key]
		for ck: Vector3i in per:
			var buf: PackedFloat32Array = per[ck]
			var ch := _chunk(host, chunks, ck, CHUNK, ground)
			var n := buf.size() / 16
			counts.x += 1
			var mmi := _batch(ch, buf, n, "Flora_%s_s" % key.replace("|", "_"), mesh, "stone", 0.0, float(pr[4]), ["stone", "s", false, float(pr[4]), n], STYLE["stone"], false, hide_args)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind != "cairn" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if bool(pr[5]):
				# cairns and cut blocks are knee-high or more: the walker goes round them
				var body := _body(ch, bodies, ck)
				var sz: Vector3 = pr[1]
				for i in n:
					var o := i * 16
					var bas := _basis_at(buf, o)
					var sc := bas.get_scale().x
					var cs := CollisionShape3D.new()
					var bx := BoxShape3D.new()
					bx.size = Vector3(sz.x * (0.75 if kind == "cairn" else 0.95), sz.y, sz.z * (0.75 if kind == "cairn" else 0.95)) * sc
					cs.shape = bx
					cs.transform = Transform3D(bas.orthonormalized(), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]) + bas.y.normalized() * sz.y * sc * 0.5)
					body.add_child(cs)
	counts.x += FarDetail.shells(host, canopy, TREE_CHUNK, ground)
	_lod_ready.clear()
	return counts


static func _body(ch: Node3D, bodies: Dictionary, key: Vector3i) -> StaticBody3D:
	var body: StaticBody3D = bodies.get(key)
	if body == null:
		body = StaticBody3D.new()
		body.name = "FloraBody"
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		ch.add_child(body)
		bodies[key] = body
	return body


## One MultiMeshInstance3D for a kind's part in a chunk: `buf` is written whole (Metal reads
## incremental writes back stale), kept as meta cpu_buffer for the editors (clearings, withering).
static func _batch(ch: Node3D, buf: PackedFloat32Array, n: int, nm: String, mesh: Mesh, tag: String, rb: float, re: float, info: Array, st: Array, swap: bool, hide_args: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.buffer = buf
	if tag != "stone":
		mm.set_meta("cpu_buffer", buf)      # (the stones in the turf are not cleared by the editors)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.set_meta("site_owned", true)        # placed clear of sites already: cull_scatter skips it
	var sp: String = info[0]
	var tall: bool = info[2]
	if tag == "stone":
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 4.0
		mmi.lod_bias = 1.0
		mmi.visibility_range_end = re
		mmi.visibility_range_end_margin = FAR_FADE
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.add_to_group(Groups.CULL_SKIP)
		mmi.set_meta(&"flora", info + [0])
		ch.add_child(mmi)
		return mmi
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(st[1]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tag == "c" and bool(st[1]):
		# Near crown cards must cast: trunks alone are thin poles; leaf gaps are what put moonlight
		# on the ground between the shadows. Alpha-scissor in realm_foliage.gdshader keeps holes open.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if tag == "fc":
		# far leaf cards are a solid stand-in past ~30 m. Their trunks (fs) still cast, so a
		# grove keeps a shadow under each tree. The cards themselves are the expensive part
		# of both shadow splits, and at that distance the gaps would not resolve.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for h: PackedStringArray in hide_args:
		if sp in h or tag in h:
			mmi.visible = false
	mmi.extra_cull_margin = 5.0            # was 1.5: turning the camera frustum-popped chunk edges
	if tag == "s" or tag == "fs":
		mmi.lod_bias = 1.15                # delay mesh LOD swaps until smaller on screen
	elif tag == "c" or tag == "fc":
		mmi.lod_bias = 2.0                 # cards must not simplify (collapse = vanish)
	if swap:
		# Near dissolves out; far dissolves in over FAR_FADE under the near band (FAR_UNDER).
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if rb <= 0.0:
			mmi.visibility_range_end = re
			mmi.visibility_range_end_margin = FAR_FADE
		else:
			mmi.visibility_range_begin = maxf(1.0, rb - FAR_UNDER)
			mmi.visibility_range_begin_margin = FAR_FADE
			mmi.visibility_range_end = re if re > 0.0 else (FarDetail.FAR_CARD_END if tag == "fc" else FarDetail.FAR_TREE_END)
			mmi.visibility_range_end_margin = FAR_FADE if re > 0.0 else 28.0
	elif re > 0.0:
		_set_range(mmi, tag, re)
	elif tall:
		mmi.visibility_range_end = FarDetail.FAR_TREE_END       # dead trees, cypresses... fade out at the horizon's edge
		mmi.visibility_range_end_margin = 36.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.add_to_group(Groups.CULL_SKIP)
	mmi.set_meta(&"flora", info + [int(mmi.cast_shadow)])
	ch.add_child(mmi)
	return mmi


## Undergrowth range `re` (chunk-origin distance where it starts to fade). Cards (`c`) fade by
## thinning out plant by plant over the next 6 m (realm_foliage.gdshader, instance uniform
## fade_end) and the chunk is culled at re + 6 m with no engine fade. The engine's FADE_SELF drew a
## fading chunk alpha-blended (transparent pass, no depth prepass, every overlapping card shaded):
## standing where dense grass chunks sat in their fade band cost up to ~6 ms at 4x pixels at the hub.
## Solid pieces (stumps, logs, caps) are sparse and keep the engine fade.
## Ground cards (realm_foliage_ground.tres) also thin per plant from thin_from (16 m) to fade_end
## down to thin_keep (60 %) with the survivors widened to keep the cover: a density LOD in the
## same hash order, so the fade band continues it without anything popping back.
static func _set_range(mmi: MultiMeshInstance3D, tag: String, re: float) -> void:
	if tag == "c":
		mmi.set_instance_shader_parameter(&"fade_end", re)
		mmi.visibility_range_end = re + FADE_BAND
		mmi.visibility_range_end_margin = 0.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	else:
		mmi.visibility_range_end = re
		mmi.visibility_range_end_margin = FAR_FADE
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func apply_detail(host: Node, d: int) -> void:
	if host == null:
		return
	d = clampi(d, 0, 2)
	if int(host.get_meta(&"detail", -1)) == d:
		return
	host.set_meta(&"detail", d)
	for n in host.find_children("Flora_*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var f: Array = mmi.get_meta(&"flora", [])
		if f.is_empty() or mmi.multimesh == null:
			continue
		var tall: bool = f[2]
		var re: float = f[3]
		if not tall:
			mmi.multimesh.visible_instance_count = -1 if d >= 1 else maxi(1, int(round(float(f[4]) * DETAIL_DENSITY[d])))
			if re > 0.0:
				_set_range(mmi, String(f[1]), re * DETAIL_RANGE[d])
		elif f[1] == "c" or f[1] == "fc":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if d == 0 else (f[5] as int)
