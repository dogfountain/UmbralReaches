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
const Kit := preload("res://core/life/secrets/kit.gd")

const CHUNK := 24.0                    ## undergrowth chunks
const TREE_CHUNK := 32.0               ## tree chunks
const FAR_UNDER := 8.0                 ## the far mesh begins this much nearer than the near tree's end (solid under its fade)
const NEAR_END := 38.0                 ## chunk-origin distance where big trees swap to their @far meshes
const STONE_RANGE := 80.0
const STONE_SIZES := [Vector3(0.55, 0.34, 0.48), Vector3(0.9, 0.5, 0.75)]

## species groups: visibility range end (0 = none: the camera far plane, 82 m, ends them),
## shadows, keep-off path distance (m from the path edge), clearance from sites
const STYLE := {
	"grass": [46.0, false, 1.0, 0.6], "tallgrass": [62.0, false, 3.0, 0.8], "flowers": [44.0, false, 3.0, 0.6],
	"heather": [60.0, false, 3.0, 0.6], "fern": [78.0, false, 3.0, 1.0], "shrub": [120.0, false, 3.5, 1.5],
	"bramble": [100.0, false, 3.5, 2.0], "litter": [32.0, false, 3.0, 0.8], "moss": [34.0, false, 3.0, 0.8],
	"mushroom": [26.0, false, 3.0, 0.8], "glowcap": [60.0, false, 3.0, 0.8], "reeds": [90.0, false, 3.0, 0.8],
	"cattail": [90.0, false, 3.0, 0.8], "log": [110.0, true, 3.5, 3.0], "stump": [96.0, false, 3.0, 1.5],
	"roots": [80.0, false, 3.0, 1.5],
	"stone": [80.0, false, 1.2, 1.0],                                  # stones in the turf (_place_stones)
	"oak": [0.0, true, 3.5, 0.0], "birch": [0.0, true, 3.0, 0.0], "pine": [0.0, true, 3.0, 0.0],
	"willow": [0.0, true, 3.0, 0.0], "snag": [0.0, true, 3.0, 0.0], "sapling": [140.0, false, 3.0, 1.5],
	"fruit": [0.0, true, 3.0, 0.0], "cypress": [0.0, true, 3.0, 0.0], "yew": [0.0, true, 3.5, 0.0], "windtree": [0.0, true, 3.0, 0.0],
	"gorse": [110.0, false, 3.0, 1.2], "deadbush": [100.0, false, 3.0, 1.2], "ashdrift": [34.0, false, 2.0, 0.8],
	"cinders": [30.0, false, 2.5, 0.8], "lily": [70.0, false, 1.0, 0.5], "scaffold": [90.0, false, 3.0, 2.0],
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

const FADE_BAND := 6.0                 ## realm_foliage.gdshader thins over fade_end .. fade_end + 6

## Undergrowth share kept and range scale per detail level (0 low, 1 medium, 2 high). Medium is the
## look as built. Low keeps 60 % of the undergrowth (evenly: instance order is shuffled per chunk)
## and pulls its ranges in by a fifth; trees keep every instance, their leaf cards stop casting.
const DETAIL_DENSITY := [0.6, 1.0, 1.0]
const DETAIL_RANGE := [0.8, 1.0, 1.12]
const FIGHT_DENSITY := 0.6             ## boss fights: share of the undergrowth drawn
const FIGHT_RANGE := 0.5               ## boss fights: undergrowth draw range scale


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
	var task := WorkerThreadPool.add_group_task(func(i: int) -> void: (todo[i][2] as ImporterMesh).generate_lods(25.0, 60.0, []), todo.size())
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


## The flora nodes, built from the placement's final buffers. Without a stream (headless, the tests: build all now) every piece
## is built here, in the order it always was. With one (realm_stream.gd) the pieces inside the build ring are built here and
## the rest, one job per (kind, chunk), per stone batch and per canopy shell, are queued for the stream, nearest first:
## the placement buffers stay global (`items`, `stones`, `canopy` are kept until the last job has run).
static func emit(host: Node3D, items: Dictionary, stones: Dictionary, canopy: Dictionary, ground: Callable, prop_mesh: Callable) -> Vector2i:
	var em := Emitter.new()
	em.host = host
	em.root = host.get_parent()
	em.items = items
	em.stones = stones
	em.canopy = canopy
	em.ground = ground
	em.prop_mesh = prop_mesh
	for a in OS.get_cmdline_user_args():           # perf probes: --flora-hide=oak,grass,s,c
		if a.begins_with("--flora-hide="):
			em.hide_args.append(a.trim_prefix("--flora-hide=").split(","))
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
		em.kinds[id] = _kind_plan(id)
	_lod_ready.clear()                              # (the plans hold the meshes now)
	host.set_meta(&"trunks", _trunk_records(items, em.kinds, ground))
	# the pieces, in the order the build always made them
	var streamed := RealmStream.of(em.root) != null
	var jobs: Array = []                            # [pos, kind of piece, a, b, part]
	for id: String in items:
		var csize := TREE_CHUNK if bool((em.kinds[id] as Dictionary).tall) else CHUNK
		for key: Vector3i in items[id]:
			# one piece a mesh (the first also makes the colliders): an add to the scene costs ~2.4 ms while the GPU is
			# busy, and a frame should take one
			var at := Vector2((key.x + 0.5) * csize, (key.y + 0.5) * csize)
			if streamed:
				for part in maxi(1, ((em.kinds[id] as Dictionary).meshes as Array).size()):
					jobs.append([at, 0, id, key, part])
			else:
				jobs.append([at, 0, id, key, -1])          # all of the kind's meshes at once, as the build always made it
	for key: String in stones:
		for ck: Vector3i in stones[key]:
			jobs.append([Vector2((ck.x + 0.5) * CHUNK, (ck.y + 0.5) * CHUNK), 1, key, ck])
	for key: Vector3i in canopy:
		jobs.append([Vector2((key.x + 0.5) * TREE_CHUNK, (key.y + 0.5) * TREE_CHUNK), 2, "", key])
	em.left = jobs.size()
	var stream := RealmStream.of(em.root)
	for j: Array in jobs:
		var piece := _piece.bind(em, int(j[1]), j[2], j[3], int(j[4]) if j.size() > 4 else 0)
		if stream == null:
			piece.call()
		else:
			RealmStream.submit(em.root, j[0], piece, -1 if (int(j[1]) == 2 or (int(j[1]) == 0 and bool((em.kinds[j[2]] as Dictionary).tall))) else 1)
	return em.counts


## The collision cylinders the emit will make, read from the placement so the builders that need them (the owls' trees,
## LifePlace.trunks) need no flora nodes: [[base (world), radius, height]] in the order the nodes come in a full build.
static func _trunk_records(items: Dictionary, kinds: Dictionary, ground: Callable) -> Array:
	var by_chunk := {}                  # chunk key -> its records (insertion order = the chunk nodes' order)
	var order: Array = []
	for id: String in items:
		var k: Dictionary = kinds[id]
		var d: Dictionary = k.d
		var sp: String = k.sp
		var csize := TREE_CHUNK if bool(k.tall) else CHUNK
		for key: Vector3i in items[id]:
			if not by_chunk.has(key):
				by_chunk[key] = []
				order.append(key)
			var solid_r: float = d.r
			if solid_r <= 0.0 or not ((bool(k.tall) and float(d.h) > 4.0) or sp == "stump"):
				continue                # (logs are boxes: no cylinder)
			var buf: PackedFloat32Array = (items[id] as Dictionary)[key]
			var cx := (key.x + 0.5) * csize
			var cz := (key.y + 0.5) * csize
			var base := Vector3(cx, ground.call(cx, cz), cz)
			for i in buf.size() / 16:
				var o := i * 16
				var sc := Vector3(buf[o], buf[o + 4], buf[o + 8]).length()
				var org := Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
				var hh := 3.5 if sp != "stump" else float(d.h) * sc
				(by_chunk[key] as Array).append([base + org, solid_r * sc * (0.95 if sp != "stump" else 1.0), hh])
	var out: Array = []
	for key: Vector3i in order:
		out.append_array(by_chunk[key])
	return out


## One kind's meshes, as the pieces of a chunk make them: [{mesh, tag, begin, end}], the style row, the swap flag.
static func _kind_plan(id: String) -> Dictionary:
	var d: Dictionary = TreeGen.kind(id)
	var sp := id.substr(0, id.rfind("_"))
	var tall := bool(d.tall)
	var meshes: Array = []          # [mesh, tag, range begin, range end]
	var swap := tall and sp in TreeGen.FAR
	var fade_end := float(d.get("fade_end", NEAR_END))   # per crown (TreeGen): a wide crown holds its near mesh longer, so it does not pop whole
	var near_end := fade_end if swap else float((STYLE[sp] as Array)[0])
	if d.solid != null:
		meshes.append([_lod_ready[id], "s", 0.0, near_end])
	if d.cards != null:
		meshes.append([d.cards, "c", 0.0, near_end])
	if swap:
		var fd: Dictionary = TreeGen.kind(id + "@far")
		if fd.solid != null:
			meshes.append([_lod_ready[id + "@far"], "fs", fade_end, 0.0])
		if fd.cards != null:
			meshes.append([fd.cards, "fc", fade_end, 0.0])
	return {"d": d, "sp": sp, "st": STYLE[sp], "tall": tall, "swap": swap, "meshes": meshes}


## The state of one emit (its pieces share the chunk nodes and bodies).
class Emitter:
	var host: Node3D
	var root: Node
	var items: Dictionary
	var stones: Dictionary
	var canopy: Dictionary
	var ground: Callable
	var prop_mesh: Callable
	var hide_args: Array = []
	var kinds := {}                     # id -> Emit._kind_plan
	var chunks := {}                    # Vector3i(x, z, tall) -> Node3D
	var bodies := {}                    # Vector3i -> StaticBody3D
	var counts := Vector2i.ZERO
	var left := 0
	var us := {}                        # build time by kind of piece (usec), and how many
	var n := {}
	var mx := {}                        # the dearest piece of each kind (usec) and which
	var mx_at := {}


## Build one piece: 0 a kind's plants in a chunk (a = id, b = key), 1 a stone batch in a chunk, 2 a canopy shell.
static func _piece(em: Emitter, what: int, a: Variant, b: Vector3i, part: int) -> void:
	var t0 := Time.get_ticks_usec()

	var made: Array = []
	match what:
		0:
			made = flora_piece(em, String(a), b, part)
		1:
			made = stone_piece(em, String(a), b)
		2:
			if FarDetail.shells_one(em.host, em.canopy, TREE_CHUNK, em.ground, b) != null:
				em.counts.x += 1
	em.left -= 1
	if not made.is_empty():
		late(em, made)
	var cat := "shell" if what == 2 else ("stone" if what == 1 else ("tall" if bool((em.kinds[a] as Dictionary).tall) else "under"))
	em.us[cat] = int(em.us.get(cat, 0)) + Time.get_ticks_usec() - t0
	em.n[cat] = int(em.n.get(cat, 0)) + 1
	var took := Time.get_ticks_usec() - t0
	if took > int(em.mx.get(cat, 0)):
		em.mx[cat] = took
		em.mx_at[cat] = str(a) + str(b)
	if em.left == 0:
		finished(em)


## A kind's plants in one chunk: the batches of its meshes and, for tall trunks, logs and stumps, the colliders.
static func flora_piece(em: Emitter, id: String, key: Vector3i, part: int) -> Array:
	var made: Array = []
	var k: Dictionary = em.kinds[id]
	var d: Dictionary = k.d
	var sp: String = k.sp
	var tall: bool = k.tall
	var st: Array = k.st
	var swap: bool = k.swap
	var csize := TREE_CHUNK if tall else CHUNK
	# (packed arrays are shared on assignment: the editors rewrite this copy in place -- the
	# clearings, the withering -- and the placement's own buffers stay as placed)
	var buf: PackedFloat32Array = ((em.items[id] as Dictionary)[key] as PackedFloat32Array).duplicate()
	var ch := _chunk(em.host, em.chunks, key, csize, em.ground)
	var n := buf.size() / 16
	for mi in (k.meshes as Array).size():
		if part >= 0 and mi != part:
			continue
		var m: Array = (k.meshes as Array)[mi]
		em.counts.x += 1
		made.append(_batch(ch, buf, n, "Flora_%s_%s" % [id, m[1]], m[0], m[1], m[2], m[3], [sp, m[1], tall, m[3], n], st, swap, em.hide_args))
	# collision: tall trunks, logs, stumps
	var solid_r: float = d.r
	if part <= 0 and solid_r > 0.0 and ((tall and float(d.h) > 4.0) or sp == "log" or sp == "stump"):
		var body := _body(ch, em.bodies, key)
		made.append(body)
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
				# (its flat top is in the hands' reach from a jump: the body is in Groups.NO_LEDGE, so it is never
				# caught as a ledge. Kept short: the wildlife's ground rays would land birds on a taller one.)
				var hh := 3.5 if sp != "stump" else float(d.h) * sc
				cy.radius = solid_r * sc * (0.95 if sp != "stump" else 1.0)
				cy.height = hh
				cs.shape = cy
				cs.position = org + Vector3(0, hh * 0.5, 0)
			body.add_child(cs)
			em.counts.y += 1
	return made


## A stone batch (key = kind|variant) in one chunk, and its colliders for the cut blocks and cairns.
static func stone_piece(em: Emitter, key: String, ck: Vector3i) -> Array:
	var made: Array = []
	var mesh: Mesh = em.prop_mesh.call(key)
	var kind := key.split("|")[0]
	var pr: Array = PROPS.get(kind, ["", STONE_SIZES[0], "", 0.0, STONE_RANGE, false])
	var buf: PackedFloat32Array = (em.stones[key] as Dictionary)[ck]
	var ch := _chunk(em.host, em.chunks, ck, CHUNK, em.ground)
	var n := buf.size() / 16
	em.counts.x += 1
	var mmi := _batch(ch, buf, n, "Flora_%s_s" % key.replace("|", "_"), mesh, "stone", 0.0, float(pr[4]), ["stone", "s", false, float(pr[4]), n], STYLE["stone"], false, em.hide_args)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind != "cairn" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	made.append(mmi)
	if bool(pr[5]):
		# cairns and cut blocks are knee-high or more: the walker goes round them
		var body := _body(ch, em.bodies, ck)
		made.append(body)
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
	return made


## What a piece built after the post-build passes (or while a boss thins the wood) must still be given: the detail level
## the host is at, and the plants the secrets cleared (`clear_discs`, kept on the host by Kit.clear_flora).
static func late(em: Emitter, made: Array) -> void:
	var host := em.host
	host.set_meta(&"flora_serial", int(host.get_meta(&"flora_serial", 0)) + 1)
	var dk := int(host.get_meta(&"detail", -1))
	if dk >= 0:
		var d := dk % 10
		var dr := detail_args(d, dk >= 10)
		for n: Variant in made:
			if n is MultiMeshInstance3D:
				detail_one(n as MultiMeshInstance3D, d, dr.x, dr.y)
	var discs: Array = host.get_meta(&"clear_discs", [])
	if not discs.is_empty() and not made.is_empty():
		var ch := (made[0] as Node).get_parent() as Node3D
		Kit.clear_in_chunk(ch, discs, made)


## The last piece is built: the placement's buffers are no longer read by the emit.
static func finished(em: Emitter) -> void:
	if not preload("res://core/world/realm/gen_cache.gd").dev():
		# the placement buffers (RealmFlora's: about 570,000 instances, ~37 MB) live in the MultiMeshes now; past this
		# only the tests read them (instance_list, built_digest), and a packed game has none
		em.items.clear()
		em.stones.clear()
		em.canopy.clear()
	em.host.set_meta(&"flora_emitted", true)
	em.host.set_meta(&"flora_counts", em.counts)
	var line := ""
	for k: String in em.us:
		line += "%s %d x %.1f ms (worst %.1f ms %s)  " % [k, em.n[k], float(em.us[k]) / 1000.0, float(em.mx[k]) / 1000.0, em.mx_at[k]]
	print("FLORA pieces: ", line)


static func _body(ch: Node3D, bodies: Dictionary, key: Vector3i) -> StaticBody3D:
	var body: StaticBody3D = bodies.get(key)
	if body == null:
		body = StaticBody3D.new()
		body.name = "FloraBody"
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		body.add_to_group(Groups.NO_LEDGE)
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
		mmi.extra_cull_margin = 1.0
		mmi.lod_bias = 0.5
		mmi.visibility_range_end = re
		mmi.visibility_range_end_margin = 6.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mmi.add_to_group(Groups.CULL_SKIP)
		mmi.set_meta(&"flora", info + [0])
		ch.add_child(mmi)
		return mmi
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(st[1]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tag == "fs" or tag == "fc":
		# far trees start 38 m from their chunk centre; moon shadows fade out from ~23 m
		# and end at 30 m (LightPolicy), so a far tree's shadow is never seen, but it was
		# drawn into both shadow splits every frame
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for h: PackedStringArray in hide_args:
		if sp in h or tag in h:
			mmi.visible = false
	mmi.extra_cull_margin = 1.5
	if tag == "s" or tag == "fs":
		mmi.lod_bias = 0.45                # trunks and branches simplify early; cards never do
	if swap:
		# Luke, 8 Nov: the near tree dissolves in over its far mesh (it switched in whole at NEAR_END while the far
		# one dithered out). The far mesh stays solid under it from FAR_UNDER metres inside the near tree's fade and
		# goes in one step where the near tree is already whole, so the dissolve never shows a hole (two dithers over
		# one band punch the same holes); the far meshes still fade out at the horizon's end (canopy shell beyond)
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if rb <= 0.0:
			mmi.visibility_range_end = re
			mmi.visibility_range_end_margin = 6.0
		else:
			mmi.visibility_range_begin = maxf(1.0, rb - FAR_UNDER)
			mmi.visibility_range_begin_margin = 0.0
			mmi.set_meta(&"cut_begin", true)             # fade_guard.gd leaves this edge a cut
			mmi.visibility_range_end = re if re > 0.0 else (FarDetail.FAR_CARD_END if tag == "fc" else FarDetail.FAR_TREE_END)
			mmi.visibility_range_end_margin = 6.0 if re > 0.0 else 20.0
	elif re > 0.0:
		_set_range(mmi, tag, re)
	elif tall:
		mmi.visibility_range_end = FarDetail.FAR_TREE_END       # dead trees, cypresses... fade out at the horizon's edge
		mmi.visibility_range_end_margin = 30.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if not tall:
		mmi.layers = LightPolicy.NO_FIRE_LAYER     # undergrowth: seen and lit as before, left out of the fire shadow
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
		mmi.set_meta(&"fade_end", true)          # (read by the fade guard: asking the renderer for the parameter syncs it)
		mmi.visibility_range_end = re + FADE_BAND
		mmi.visibility_range_end_margin = 0.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	else:
		mmi.visibility_range_end = re
		mmi.visibility_range_end_margin = 6.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## In a boss fight (flora_fight.gd) the undergrowth draws nearer and thinner, for 120 fps (Luke).
static func apply_detail(host: Node, d: int) -> void:
	if host == null:
		return
	d = clampi(d, 0, 2)
	var fight := bool(host.get_meta(&"fight", false))
	var key := d + (10 if fight else 0)
	if int(host.get_meta(&"detail", -1)) == key:
		return
	host.set_meta(&"detail", key)
	var dr := detail_args(d, fight)
	for n in host.find_children("Flora_*", "MultiMeshInstance3D", true, false):
		detail_one(n as MultiMeshInstance3D, d, dr.x, dr.y)


## [density, range scale] for detail `d`, in a boss fight or not.
static func detail_args(d: int, fight: bool) -> Vector2:
	return Vector2(DETAIL_DENSITY[d] * (FIGHT_DENSITY if fight else 1.0), DETAIL_RANGE[d] * (FIGHT_RANGE if fight else 1.0))


## One flora MultiMesh set to a detail level (apply_detail's body; flora_fight.gd runs it over a cached list, a slice
## a frame).
static func detail_one(mmi: MultiMeshInstance3D, d: int, dens: float, rng: float) -> void:
	if mmi == null or not is_instance_valid(mmi):
		return
	var f: Array = mmi.get_meta(&"flora", [])
	if f.is_empty() or mmi.multimesh == null:
		return
	var tall: bool = f[2]
	var re: float = f[3]
	if not tall:
		mmi.multimesh.visible_instance_count = -1 if dens >= 1.0 else mini(mmi.multimesh.instance_count, maxi(1, int(round(float(f[4]) * dens))))
		if re > 0.0:
			_set_range(mmi, String(f[1]), re * rng)
	elif f[1] == "c" or f[1] == "fc":
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if d == 0 else (f[5] as int)
