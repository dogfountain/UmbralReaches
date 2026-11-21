extends RefCounted
## The wayside's places built (realm_wayside.gd plans them, wayside_kit.gd lays each one out as pieces): a chunk of
## the map at a time, every piece in it drawn as few meshes as the materials allow, so the wayside costs a handful
## of draws per chunk in view, not a handful per place (the integrator's budget, 16 Nov: the doubled world already
## draws ~120 more than master). The lore kit builds the walls, carts, graves and stones into one kit; its stone
## models (lore_*.glb) and the prop models go through PropModels (one mesh per material set, with LODs); the RockKit
## stones and the site props' clutter are merged by material too. Writings, boxes and glide perches stay nodes.
## Load by path: const Build := preload("res://core/world/realm/wayside_build.gd")

const GroundSeat := preload("res://core/world/realm/ground_seat.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Props := preload("res://core/world/realm/site_props.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const PropModels := preload("res://core/world/realm/prop_models.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/realm/wayside_build.gd"
const LOD_TRIS := 4000                ## (Atmosphere's post-build pass would cut a mesh this heavy into 24 m cells)

## Build the planned places `vs` under one holder (a chunk of the map) and draw them as few meshes as their
## materials allow; everything fades out by `view_end` from the chunk's middle. Returns the holder.
static func build(parent: Node3D, name: String, vs: Array, space: PhysicsDirectSpaceState3D, view_end: float) -> Node3D:
	var L: RefCounted = LK.begin(parent, name, int((vs[0] as Dictionary).seed))
	var h: Node3D = L.holder
	var props_kit: OssKit = L.p
	L.p = L.k                               # the small pieces go into the one kit (a draw per material, not two)
	var clutter := {}                       # site-props key -> [Transform3D]
	for v: Dictionary in vs:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(v.seed) + 7
		L.rng = rng
		var spots: Array[Vector3] = []          # where a box may stand
		for e: Dictionary in v.geo:
			_piece(L, e, v.xf as Transform3D, rng, clutter, spots, v, space)
		if String(v.get("box", "")) != "" and not spots.is_empty():
			var c: Node3D = Chest.new()
			c.name = "Chest_" + String(v.box)
			c.set("chest_id", String(v.box))
			c.set("tier", String(v.get("box_tier", "wood")))
			c.set("loot", (v.get("loot", {"grave_ash": 6}) as Dictionary).duplicate())
			h.add_child(c)
			c.global_transform = Transform3D(Basis(Vector3.UP, float(v.yaw) + rng.randf_range(-0.4, 0.4)), spots[0])
	L.p = props_kit                         # (left empty: finish commits nothing for it)
	# the stone and prop models: one mesh per material set for the chunk, with LODs
	var pm := PropModels.new()
	for it: Array in L._props:
		pm.add(String(it[0]), it[1] as Transform3D)
	L._props.clear()
	var merged: Array[MeshInstance3D] = pm.commit(h, "Models", true, true)
	# the RockKit stones and the site props' clutter: merged by material
	var by_mat := {}                        # Material -> [SurfaceTool, shadows (the stones; the clutter is small)]
	for mesh: Mesh in L._rocks:
		for e: Array in L._rocks[mesh]:
			_merge(by_mat, mesh, e[0] as Transform3D, true)
	L._rocks.clear()
	for key: String in clutter:
		var d := Props.get_prop(key)
		if d.is_empty():
			continue
		var parts: Array = (d.variants as Array)[0] if d.has("variants") else [{"mesh": d.mesh, "mat": d.mat}]
		var meshes: Array = []
		for part: Dictionary in parts:
			meshes.append(part.mesh)
		var fpts := GroundSeat.parts_points("wc:" + key, meshes)
		var gfn := GroundSeat.fast_fn()
		for xf: Transform3D in clutter[key]:
			var sxf := GroundSeat.seat_pts(gfn, fpts, xf, 0.5)      # the prop's footing on the ground, one transform for all its parts
			for part: Dictionary in parts:
				_merge(by_mat, part.mesh as Mesh, sxf, false, part.mat as Material)
	var n := 0
	for m: Material in by_mat:
		var mi := MeshInstance3D.new()
		mi.name = "Merged%d" % n
		mi.mesh = (by_mat[m][0] as SurfaceTool).commit()          # (low-poly stones and clutter: no LOD chain worth its build time)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(by_mat[m][1]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not bool(by_mat[m][1]):
			mi.set_meta(&"small", true)
		h.add_child(mi)
		merged.append(mi)
		n += 1
	L.finish()
	# every mesh fades out by the chunk's range (the size rule would draw a chunk-wide mesh to the horizon): the big masses
	# (walls, towers, stones, the stone models) at view_end, the small things (timber, iron, cloth, clutter, carvings) at
	# SMALL_K of it, where they cannot be read at night anyway: a chunk farther off costs only its few big draws
	for g in h.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if _in_interactable(gi, h):
			continue                         # a box, a writing's glint: their own look
		var end := view_end * (SMALL_K if _small(gi) else 1.0)
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = end * 0.15
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gi.add_to_group(Groups.CULL_SKIP)
		gi.set_meta("site_owned", true)
		if gi is MeshInstance3D:
			gi.set_meta("chunked", true)      # a chunk already: Atmosphere's post-build pass leaves it whole (cutting cost draws and load)
			_lods(gi as MeshInstance3D)
	return h


## A heavy merged mesh (the chunk's stones, its kit surfaces) given LOD levels, cached on disk by content (GenCache):
## what Atmosphere's split would have made of it, without the extra draws of 24 m cells.
static func _lods(mi: MeshInstance3D) -> void:
	var m := mi.mesh as ArrayMesh
	if m == null or m.get_surface_count() == 0 or DisplayServer.get_name() == "headless":
		return                               # (nothing is drawn headless: tests skip the work)
	if (RenderingServer.mesh_get_surface(m.get_rid(), 0).get("lods", []) as Array).size() > 0:
		return
	var tris := 0
	for si in m.get_surface_count():
		var n := m.surface_get_array_index_len(si)
		tris += (n if n > 0 else m.surface_get_array_len(si)) / 3
	if tris < LOD_TRIS:
		return
	var hs := 0
	for si in m.get_surface_count():
		var a := m.surface_get_arrays(si)
		hs = hash([hs, hash(a[Mesh.ARRAY_VERTEX]), hash(a[Mesh.ARRAY_INDEX]) if a[Mesh.ARRAY_INDEX] != null else 0])
	var key := "wayside_lods|%d" % hs
	var got := GenCache.load_mesh(key, SELF)
	if got == null:
		got = MeshChunks.with_lods(m) as ArrayMesh
		if got == null:
			return
		GenCache.save_mesh(key, SELF, got)
	for si in mini(got.get_surface_count(), m.get_surface_count()):
		if got.surface_get_material(si) == null:
			got.surface_set_material(si, m.surface_get_material(si))
	mi.mesh = got


const SMALL_K := 0.45                ## (FadeGuard scales ranges by 1.5: the small things end ~75 m off, the big ~165 m)
const BIG_KEYS := ["lore_moss", "lore_tstone", "lore_earth", "lore_bronze", "dark", "stone", "ashlar", "hewn", "slate"]


## A mesh of small things: not one of the big masses' materials (the kit's surfaces are Mesh_<key>, the stone and prop
## models Models_<set>, the merged stones Merged* unless marked small, the carved panels Carved_*).
static func _small(gi: GeometryInstance3D) -> bool:
	var n := String(gi.name)
	if gi.has_meta(&"small"):
		return true
	if n.begins_with("Carved_") or n.begins_with("UV_"):
		return true
	for key: String in BIG_KEYS:
		if n == "Mesh_" + key or n.begins_with("Mesh_" + key + "_") or n.ends_with("_" + key):
			return false
	return n.begins_with("Mesh_") or n.begins_with("Models_")


static func _in_interactable(n: Node, top: Node) -> bool:
	var q := n.get_parent()
	while q != null and q != top:
		if q is Interactable:
			return true
		q = q.get_parent()
	return false


## Append `mesh` at `xf` into the merged surface for its material (the mesh's own, or `mat`).
static func _merge(by_mat: Dictionary, mesh: Mesh, xf: Transform3D, shadows: bool, mat: Material = null) -> void:
	for si in mesh.get_surface_count():
		var m: Material = mat if mat != null else mesh.surface_get_material(si)
		if m == null:
			continue
		if not by_mat.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			by_mat[m] = [st, shadows]
		(by_mat[m][0] as SurfaceTool).append_from(mesh, si, xf)


## Ground point of local q (world, on the ground).
static func _g(L: RefCounted, xf: Transform3D, q: Vector2) -> Vector3:
	var p := xf * Vector3(q.x, 0.0, q.y)
	return L.gv(p.x, p.z)


static func _piece(L: RefCounted, e: Dictionary, xf: Transform3D, rng: RandomNumberGenerator, clutter: Dictionary, spots: Array[Vector3], v: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
	var k: OssKit = L.k
	var b := xf.basis
	var yaw0 := float(v.yaw)
	match String(e.t):
		"wall":
			L.drystone(_g(L, xf, e.a), _g(L, xf, e.b), float(e.h), float(e.ruin), String(e.get("key", "lore_moss")))
		"glb":
			var at := _g(L, xf, e.p)
			var pxf := Transform3D((Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.RIGHT, float(e.get("tilt", 0.0)))).scaled(Vector3.ONE * float(e.s)), at + Vector3.DOWN * 0.04)
			L.prop(String(e.f), pxf, false)
			if bool(e.col):
				var sz := PropModels.size_of(String(e.f)) * float(e.s)
				LK.col_box(k, at + Vector3.UP * sz.y * 0.5, sz * Vector3(0.85, 1.0, 0.85), pxf.basis.orthonormalized())
		"clutter":
			var cat := _g(L, xf, e.p)
			var key := String(e.k)
			if not clutter.has(key):
				clutter[key] = []
			(clutter[key] as Array).append(Transform3D(Basis(Vector3.UP, yaw0 + float(e.yaw)).scaled(Vector3.ONE * float(e.s)), cat + Vector3.DOWN * 0.02))
		"rubble":
			L.rubble(k, _g(L, xf, e.p), float(e.r), int(e.n), String(e.get("key", "lore_tstone")))
		"chimney":
			var cb := _g(L, xf, e.p)
			var ch := float(e.h)
			var y := cb.y - 0.3
			var lean := rng.randf_range(-0.04, 0.04)
			while y < cb.y + ch:
				var step := rng.randf_range(0.28, 0.4)
				k.box("lore_moss", Vector3(cb.x, y + step * 0.5, cb.z), Vector3(1.0, step, 0.9), b * Basis(Vector3.BACK, lean) * Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), true, rng.randf_range(0.75, 0.95))
				y += step
		"beam":
			var a3: Vector3 = e.a
			var b3: Vector3 = e.b
			var wa := xf * Vector3(a3.x, 0.0, a3.z)
			var wb := xf * Vector3(b3.x, 0.0, b3.z)
			wa.y = L.g(wa.x, wa.z) + a3.y
			wb.y = L.g(wb.x, wb.z) + b3.y
			var dd := wb - wa
			k.box("lore_beam", (wa + wb) * 0.5, Vector3(0.18, 0.2, dd.length()), Basis.looking_at(dd.normalized(), Vector3.UP), false, 0.65)
		"saint":
			var sat := _g(L, xf, e.p)
			L.saint(sat, yaw0 + float(e.yaw), int(e.v), float(e.plinth), float(e.s))
		"fallen":
			L.fallen_saint(_g(L, xf, e.p), yaw0 + float(e.yaw), int(e.v), rng.randf() < 0.6)
		"slab":
			_slab(L, _g(L, xf, e.p), yaw0 + float(e.yaw), float(e.h), float(e.w), e.lean as Vector2)
		"lying":
			var lat := _g(L, xf, e.p)
			var m: Mesh = RockKit.slab(rng.randi() % 6, LK.UNIT_SLAB, "mossy", 0.3, true)
			var ln := float(e.len)
			var lb := Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
			L.rock(m, Transform3D(lb * Basis.from_scale(Vector3(0.7, ln, 0.4) / LK.UNIT_SLAB), lat + Vector3.UP * 0.05), false)
			LK.col_box(k, lat + Vector3.UP * 0.18, Vector3(0.65, ln, 0.4), lb)
		"altar":
			var aat := _g(L, xf, e.p)
			var ab := Basis(Vector3.UP, float(e.yaw))
			k.box("lore_tstone", aat + Vector3.UP * 0.18, Vector3(1.5, 0.55, 0.9), ab * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), true, 0.8)
			L.panel(aat + Vector3.UP * 0.46, Vector3.UP, 0.9, 0.5, LK.LA.C_RUNES, true, ab * Vector3.FORWARD)
		"boulder":
			L.stone(k, _g(L, xf, e.p), e.s as Vector3, "lore_moss" if String(e.get("style", "")) == "mossy" else ("lore_char" if String(e.get("style", "")) == "ash" else "lore_tstone"), (e.s as Vector3).y > 0.45)
		"cairn":
			L.cairn(L.p, _g(L, xf, e.p), float(e.h))
		"bigcairn":
			var bat := _g(L, xf, e.p)
			var bh := float(e.h)
			var cm: Mesh = RockKit.cairn(rng.randi() % 3, Vector3(0.95, 1.25, 0.9), "granite")
			var cb2 := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (bh / 1.25))
			L.rock(cm, Transform3D(cb2, bat + Vector3.DOWN * 0.08), false)
			LK.col_box(k, bat + Vector3.UP * bh * 0.4, Vector3(0.7, bh * 0.8, 0.7) * (bh / 1.25), cb2.orthonormalized())
		"block":
			var kat := _g(L, xf, e.p)
			var sz2: Vector3 = e.s
			var on := float(e.get("on", 0.0))
			k.box(String(e.k), kat + Vector3.UP * (on + sz2.y * 0.5 - (0.08 if on == 0.0 else 0.0)), sz2, Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.BACK, rng.randf_range(-0.04, 0.04)), true, rng.randf_range(0.78, 0.95))
		"drum":
			_drum(L, _g(L, xf, e.p), float(e.r), float(e.h), bool(e.lie), yaw0 + float(e.yaw))
		"cart":
			L.cart(_g(L, xf, e.p), yaw0 + float(e.yaw), bool(e.broken), String(e.load))
			var cat2 := _g(L, xf, e.p)
			LK.col_box(k, cat2 + Vector3.UP * 0.5, Vector3(1.4, 1.0, 2.3), Basis(Vector3.UP, yaw0 + float(e.yaw)))
		"fence":
			L.fence(_g(L, xf, e.a), _g(L, xf, e.b), float(e.gaps))
		"headstone":
			var hat := _g(L, xf, e.p)
			L.headstone(hat, 0.0, int(e.style), float(e.h), e.tilt as Vector2, "lore_tstone", bool(e.mound))
		"firering":
			_fire_ring(L, _g(L, xf, e.p), clutter)
		"leanto":
			_leanto(L, _g(L, xf, e.p), yaw0 + float(e.yaw))
		"bedroll":
			var bdat := _g(L, xf, e.p)
			var bcm := CreatureMesh.new(rng.randi())
			bcm.blob(Vector3.ZERO, Vector3(0.36, 0.09, 0.95), Basis.IDENTITY, Color(0.6, 0.5, 0.42), 0.0, 0.3, 0.0, 5, 9)
			LK.organic(L.p, "lore_cloth", bcm.commit(), Transform3D(Basis(Vector3.UP, yaw0 + float(e.yaw)), bdat + Vector3.UP * 0.04))
		"axe":
			var xat := _g(L, xf, e.p) + Vector3.UP * 0.45
			var xb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, 0.5)
			L.p.box("lore_beam", xat + xb * Vector3(0, 0.32, 0), Vector3(0.05, 0.7, 0.05), xb, false, 0.7)
			L.p.box("iron", xat + xb * Vector3(0.08, 0.02, 0), Vector3(0.2, 0.1, 0.03), xb, false, 0.6)
		"sawhorse":
			var sat2 := _g(L, xf, e.p)
			var sb := Basis(Vector3.UP, float(e.yaw))
			for sx: float in [-0.55, 0.55]:
				for lean2: float in [-0.35, 0.35]:
					L.p.box("lore_beam", sat2 + sb * Vector3(sx, 0.38, 0.0), Vector3(0.06, 0.82, 0.06), sb * Basis(Vector3.RIGHT, lean2), false, 0.7)
			L.p.box("lore_beam", sat2 + sb * Vector3(0, 0.72, 0), Vector3(1.4, 0.09, 0.09), sb, true, 0.75)
			L.p.box("lore_beam", sat2 + sb * Vector3(0.1, 0.84, 0), Vector3(1.9, 0.16, 0.16), sb * Basis(Vector3.UP, 0.15), false, 0.68)
		"tower":
			_tower(L, _g(L, xf, e.p), float(e.h), float(e.w), yaw0, rng)
		"steps":
			for st: Array in e.list:
				var sq: Vector2 = st[0]
				var top: float = st[1]
				var gat := _g(L, xf, sq)
				var base := _g(L, xf, Vector2(0.0, 0.6)).y
				var ytop := base + top
				var hh := ytop - (gat.y - 0.4)
				k.box("lore_tstone", Vector3(gat.x, ytop - hh * 0.5, gat.z), Vector3(1.05, hh, 1.05), Basis(Vector3.UP, yaw0 + rng.randf_range(-0.2, 0.2)), true, rng.randf_range(0.8, 0.95))
		"perch":
			# a glide perch (realm_pois.gd GROUP_GLIDE) on the tower's top, facing its longest drop, where there is one
			var top3 := _g(L, xf, e.p) + Vector3.UP * (float(v.get("tower_top", 3.5)) + 0.1)
			var best := Vector3.ZERO
			var drop := 0.0
			for i in 8:
				var a := TAU * float(i) / 8.0
				var f := Vector3(sin(a), 0.0, cos(a))
				var dd := top3.y - maxf(L.g(top3.x + f.x * 6.0, top3.z + f.z * 6.0), -0.9)
				if dd > drop:
					drop = dd
					best = f
			if drop > 5.5:
				var m := Node3D.new()
				m.name = "GlidePerch"
				(L.holder as Node3D).add_child(m)
				m.global_position = top3
				m.add_to_group("glide_perch")
				m.set_meta("facing", best)
				m.set_meta("drop", drop)
		"spear":
			var spat := _g(L, xf, e.p)
			var spb := Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.RIGHT, float(e.tilt))
			var ln2 := float(e.len)
			L.p.box("lore_beam", spat + spb * Vector3(0, ln2 * 0.5 - 0.35, 0), Vector3(0.065, ln2, 0.065), spb, false, 0.6)
			L.p.box("iron", spat + spb * Vector3(0, ln2 - 0.26, 0), Vector3(0.1, 0.36, 0.03), spb, false, 0.55)
		"stake":
			var stat := _g(L, xf, e.p)
			var stb := Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.RIGHT, -float(e.tilt))
			var sl := float(e.len)
			k.box("lore_beam", stat + stb * Vector3(0, sl * 0.5 - 0.4, 0), Vector3(0.17, sl, 0.17), stb * Basis(Vector3.UP, rng.randf() * 0.8), true, rng.randf_range(0.55, 0.72))
			k.box("lore_beam", stat + stb * Vector3(0, sl - 0.32, 0), Vector3(0.1, 0.32, 0.1), stb * Basis(Vector3.UP, 0.785), false, 0.62)
		"wheel":
			var wat := _g(L, xf, e.p) + Vector3.UP * 0.06
			L._wheel(wat, Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.12, 0.12)), 0.55)
		"helm":
			var hat2 := _g(L, xf, e.p)
			var hcm := CreatureMesh.new(rng.randi())
			hcm.blob(Vector3.ZERO, Vector3(0.17, 0.13, 0.19), Basis.IDENTITY, Color(0.55, 0.55, 0.58), 0.0, 0.15, 0.0, 5, 9)
			LK.organic(L.p, "iron", hcm.commit(), Transform3D(Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.9)), hat2 + Vector3.UP * 0.06))
		"shield":
			var shat := _g(L, xf, e.p)
			var shb := Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.RIGHT, -PI * 0.5 + rng.randf_range(-0.35, 0.25))
			LK.half_disc(L.p, "lore_beam", Transform3D(shb, shat + Vector3.UP * 0.12), 0.42, -0.0, 0.05, 6, false, 0.7)
			LK.half_disc(L.p, "lore_beam", Transform3D(shb * Basis(Vector3.BACK, PI), shat + Vector3.UP * 0.12), 0.42, 0.0, 0.05, 6, false, 0.66)
			L.p.box("iron", shat + Vector3.UP * 0.16, Vector3(0.14, 0.06, 0.14), shb, false, 0.6)
		"banner":
			var bnat := _g(L, xf, e.p)
			var bh2 := float(e.h)
			var bnb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.18, 0.18))
			L.p.box("lore_beam", bnat + bnb * Vector3(0, bh2 * 0.5 - 0.3, 0), Vector3(0.08, bh2, 0.08), bnb, true, 0.65)
			L.p.box("lore_beam", bnat + bnb * Vector3(0, bh2 - 0.45, 0), Vector3(0.9, 0.06, 0.06), bnb, false, 0.65)
			var rag := CreatureMesh.new(rng.randi())
			rag.blob(Vector3(0, -0.6, 0), Vector3(0.5, 0.7, 0.03), Basis(Vector3.BACK, 0.06), Color(0.42, 0.24, 0.2), 0.0, 0.5, 0.0, 5, 8)
			LK.organic(L.p, "lore_cloth", rag.commit(), Transform3D(bnb, bnat + bnb * Vector3(0, bh2 - 0.48, 0.05)))
		"shard":
			_shard(L, _g(L, xf, e.p), float(e.yaw), float(e.s))
		"mound":
			var mat := _g(L, xf, e.p)
			var ms: Vector3 = e.s
			var mcm := CreatureMesh.new(rng.randi())
			mcm.blob(Vector3.ZERO, ms, Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.18, 0.0, 9, 16)
			LK.organic(k, "lore_earth", mcm.commit(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), mat + Vector3.DOWN * ms.y * 0.25), true)
		"door":
			var dat := _g(L, xf, e.p)
			var db := Basis(Vector3.UP, yaw0)
			for sx2: float in [-0.65, 0.65]:
				k.box("lore_tstone", dat + db * Vector3(sx2, 0.55, 0.0), Vector3(0.38, 1.5, 0.5), db * Basis(Vector3.BACK, sx2 * -0.06), true, 0.8)
			k.box("lore_tstone", dat + db * Vector3(0, 1.38, 0.05), Vector3(1.9, 0.38, 0.6), db * Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), true, 0.82)
			k.box("dark", dat + db * Vector3(0, 0.5, 0.35), Vector3(0.95, 1.3, 0.1), db, false, 0.2)
		"clamp":
			_clamp(L, _g(L, xf, e.p), float(e.r))
		"rake":
			var rat := _g(L, xf, e.p) + Vector3.UP * 0.04
			var rb := Basis(Vector3.UP, float(e.yaw))
			L.p.box("lore_beam", rat + rb * Vector3(0, 0, 0), Vector3(0.04, 0.04, 1.7), rb, false, 0.7)
			L.p.box("lore_beam", rat + rb * Vector3(0, 0.02, 0.85), Vector3(0.6, 0.05, 0.06), rb, false, 0.65)
		"rick":
			var kat2 := _g(L, xf, e.p)
			var rs := float(e.s)
			var rcm := CreatureMesh.new(rng.randi())
			rcm.blob(Vector3(0, 0.9, 0), Vector3(1.05, 1.0, 1.05) * rs, Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.25, 0.0, 7, 12)
			rcm.blob(Vector3(0, 1.75 * rs, 0), Vector3(0.55, 0.55, 0.55) * rs, Basis.IDENTITY, Color(0.9, 0.9, 0.9), 0.0, 0.3, 0.0, 5, 10)
			LK.organic(k, "lore_thatch", rcm.commit(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), kat2 + Vector3.DOWN * 0.15))
			LK.col_box(k, kat2 + Vector3.UP * 0.9 * rs, Vector3(1.6, 1.8, 1.6) * rs, Basis.IDENTITY)
		"scarecrow":
			L.scarecrow(_g(L, xf, e.p), float(e.yaw))
		"plough":
			var pat := _g(L, xf, e.p) + Vector3.UP * 0.1
			var pb := Basis(Vector3.UP, float(e.yaw)) * Basis(Vector3.BACK, 0.12)
			L.p.box("lore_beam", pat + pb * Vector3(0, 0.2, 0), Vector3(0.12, 0.12, 2.2), pb * Basis(Vector3.RIGHT, -0.18), true, 0.7)
			L.p.box("lore_beam", pat + pb * Vector3(0, 0.55, 0.95), Vector3(0.6, 0.06, 0.06), pb, false, 0.7)
			L.p.box("iron", pat + pb * Vector3(0, -0.02, -0.9), Vector3(0.1, 0.22, 0.4), pb, false, 0.55)
		"jetty":
			_jetty(L, e, xf, yaw0, rng)
		"trap":
			_trap(L, _g(L, xf, e.p), float(e.yaw))
		"boat":
			var bat2 := _g(L, xf, e.p)
			var bcm2 := CreatureMesh.new(rng.randi())
			bcm2.blob(Vector3.ZERO, Vector3(0.65, 0.32, 1.7), Basis.IDENTITY, Color(0.62, 0.52, 0.42), 0.0, 0.12, 0.0, 7, 12)
			LK.organic(k, "wood", bcm2.commit(), Transform3D(Basis(Vector3.UP, yaw0 + float(e.yaw)) * Basis(Vector3.BACK, PI + 0.15), bat2 + Vector3.UP * 0.18), true)
		"rib":
			var rbat := _g(L, xf, e.p)
			var ryaw := yaw0 + float(e.yaw)
			var side := float(e.side)
			var ribm := OssKit.bone_mesh(1)
			var rxb := Basis(Vector3.UP, ryaw + PI * 0.5) * Basis(Vector3.BACK, side * 0.55) * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
			k.append_mesh("bone_cm", ribm, Transform3D(rxb.scaled(Vector3.ONE * float(e.s)), rbat + Vector3.DOWN * 0.15))
			LK.col_box(k, rbat + Vector3.UP * 0.6, Vector3(0.18, 1.2, 0.18), rxb.orthonormalized())
		"bigskull":
			var skat := _g(L, xf, e.p)
			k.skull(skat + Vector3.UP * 0.25, yaw0 + float(e.yaw), 3.2, 0, 0.35)
			LK.col_box(k, skat + Vector3.UP * 0.45, Vector3(0.9, 0.8, 1.0), Basis(Vector3.UP, yaw0 + float(e.yaw)))
		"spot":
			spots.append(_g(L, xf, e.p))
		"spot_top":
			var tq := _g(L, xf, e.p)
			spots.append(Vector3(tq.x, _g(L, xf, Vector2(0.0, 0.6)).y + float(v.get("tower_top", 3.5)), tq.z))
		"lore":
			_lore(L, e, xf, v, rng)


## A carrier for the place's writing (v.lore: a wayside_texts id): its kind from the piece.
static func _lore(L: RefCounted, e: Dictionary, xf: Transform3D, v: Dictionary, rng: RandomNumberGenerator) -> void:
	var id := String(v.get("lore", ""))
	var at := _g(L, xf, e.p)
	var face := float(v.yaw)
	match String(e.c):
		"waystone":
			if id == "":
				L.waystone(at, face)
				return
			var fp: Vector3 = L.waystone(at, face)
			L.scrap(id, fp, fp + Basis(Vector3.UP, face) * Vector3(0, 0, 0.25))
		"rune":
			if id == "":
				return
			var fp2: Vector3 = L.rune_stone(at, face, rng.randf_range(1.1, 1.4))
			L.scrap(id, fp2, fp2 + Vector3.UP * 0.3)
		"grave":
			if id == "":
				return
			var fp3: Vector3 = L.headstone(at, 0.0, rng.randi() % 3, rng.randf_range(0.9, 1.1), Vector2(rng.randf_range(-0.06, 0.08), 0.0))
			L.scrap(id, fp3 + Vector3(0, -0.3, -0.6), fp3)
		"notice":
			if id == "":
				return
			var k: OssKit = L.k
			var b := Basis(Vector3.UP, face)
			for sx: float in [-0.55, 0.55]:
				k.box("lore_beam", at + b * Vector3(sx, 0.95, 0), Vector3(0.14, 1.9, 0.14), b, true, 0.7)
			k.box("lore_beam", at + b * Vector3(0, 1.45, -0.05), Vector3(1.3, 0.75, 0.06), b, true, 0.85)
			k.box("lore_beam", at + b * Vector3(0, 1.88, -0.12), Vector3(1.5, 0.1, 0.3), b, false, 0.7)
			var fpn := at + b * Vector3(0, 1.45, -0.09)
			L.page(fpn, b * Vector3(0, 0, -1), 0.1)
			L.scrap(id, fpn + b * Vector3(0, -0.4, -0.7), fpn)
		"tablet":
			if id == "":
				return
			var tb := Basis(Vector3.UP, face) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.02))
			var files := ["lore_tablet_weathered.glb", "lore_tablet_cracked.glb", "lore_tablet_leaning.glb"]
			var fpt: Vector3 = L.prop(files[rng.randi() % files.size()], Transform3D(tb.scaled(Vector3.ONE * rng.randf_range(1.2, 1.5)), at))
			L.letters(fpt, -tb.z, 0.32, 3)
			L.scrap(id, fpt - tb.z * 0.6 + Vector3.DOWN * 0.2, fpt)
		"page":
			if id == "":
				return
			var k2: OssKit = L.k
			var pb := Basis(Vector3.UP, rng.randf() * TAU)
			k2.box("lore_beam", at + Vector3.UP * 0.22, Vector3(0.62, 0.44, 0.5), pb, true, 0.75)
			var top := at + Vector3.UP * 0.45
			L.page(top, Vector3.UP)
			L.scrap(id, top + Vector3.UP * 0.25, top)


static func _slab(L: RefCounted, at: Vector3, yaw: float, h: float, w: float, lean: Vector2) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean.x) * Basis(Vector3.BACK, lean.y)
	var m: Mesh = RockKit.slab((L.rng as RandomNumberGenerator).randi() % 6, LK.UNIT_SLAB, "mossy" if (L.rng as RandomNumberGenerator).randf() < 0.5 else "granite", 0.3, true)
	var sz := Vector3(w, h, w * 0.42)
	L.rock(m, Transform3D(b * Basis.from_scale(sz / LK.UNIT_SLAB), at + Vector3.DOWN * 0.3), false)
	LK.col_box(L.k, at + b * Vector3(0, h * 0.5 - 0.3, 0), sz * Vector3(0.85, 1.0, 0.85), b)


static func _drum(L: RefCounted, at: Vector3, r: float, h: float, lie: bool, yaw: float) -> void:
	var k: OssKit = L.k
	var n := 10
	var b := Basis(Vector3.UP, yaw)
	if lie:
		b = b * Basis(Vector3.BACK, PI * 0.5)
	var c := at + (Vector3.UP * r * 0.92 if lie else Vector3.UP * (h * 0.5 - 0.05))
	for i in n:
		var a := TAU * float(i) / float(n)
		var o := b * Vector3(cos(a) * r * 0.93, 0, sin(a) * r * 0.93)
		k.box("lore_tstone", c + o, Vector3(r * 0.62, h, r * 0.2), b * Basis(Vector3.UP, -a + PI * 0.5), false, 0.85)
	k.box("lore_tstone", c, Vector3(r * 1.5, h * 0.98, r * 1.5), b, true, 0.82)


static func _fire_ring(L: RefCounted, at: Vector3, clutter: Dictionary) -> void:
	var rng: RandomNumberGenerator = L.rng
	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf_range(-0.1, 0.1)
		L.stone(L.p, at + Vector3(cos(a) * 0.62, 0.0, sin(a) * 0.62), Vector3(0.26, 0.18, 0.22) * rng.randf_range(0.85, 1.2), "lore_tstone", false, 0.3)
	if not clutter.has("kindling"):
		clutter["kindling"] = []
	(clutter["kindling"] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3.UP * 0.01))
	var ash := CreatureMesh.new(rng.randi())
	ash.blob(Vector3.ZERO, Vector3(0.42, 0.04, 0.42), Basis.IDENTITY, Color(0.3, 0.3, 0.3), 0.0, 0.3, 0.0, 3, 9)
	LK.organic(L.p, "lore_char", ash.commit(), Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.01))


static func _leanto(L: RefCounted, at: Vector3, yaw: float) -> void:
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw)
	for sx: float in [-1.1, 1.1]:
		k.box("lore_beam", at + b * Vector3(sx, 0.75, -0.6), Vector3(0.1, 1.6, 0.1), b, true, 0.7)
	k.box("lore_beam", at + b * Vector3(0, 1.52, -0.6), Vector3(2.5, 0.1, 0.1), b, false, 0.7)
	var slope := Basis(Vector3.RIGHT, -0.72)
	for i in 6:
		var x := -1.0 + float(i) * 0.4
		k.box("lore_beam", at + b * Vector3(x, 0.82, 0.05), Vector3(0.34, 0.05, 1.9), b * slope * Basis(Vector3.UP, (L.rng as RandomNumberGenerator).randf_range(-0.04, 0.04)), true, (L.rng as RandomNumberGenerator).randf_range(0.62, 0.8))


static func _tower(L: RefCounted, at: Vector3, h: float, w: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw)
	# a squat round stump of a watch-tower: courses of blocks round a solid core, its crown broken
	var r := w * 0.5
	var y := at.y - 0.5
	var course := 0
	while y < at.y + h:
		var ch := rng.randf_range(0.36, 0.48)
		var n := 12
		for i in n:
			var a := TAU * float(i) / float(n) + float(course % 2) * 0.26
			var top_cut := y > at.y + h - 1.0 and sin(a * 2.0 + 1.3) > 0.3
			if top_cut:
				continue
			var o := b * Vector3(cos(a) * r, 0, sin(a) * r)
			k.box("lore_moss", Vector3(at.x, y + ch * 0.5, at.z) + o, Vector3(r * 0.56, ch, 0.5), b * Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.04, 0.04)), false, rng.randf_range(0.72, 0.95))
		y += ch
		course += 1
	k.box("lore_tstone", at + Vector3.UP * (h * 0.5 - 0.25), Vector3(w * 0.92, h + 0.5, w * 0.92), b, true, 0.8)
	LK.col_box(k, at + Vector3.UP * (h * 0.5 - 0.25), Vector3(w * 1.12, h + 0.5, w * 1.12), b)      # the courses' outer face, walked against
	k.box("lore_tstone", at + Vector3.UP * (h + 0.02), Vector3(w * 0.88, 0.1, w * 0.88), b * Basis(Vector3.UP, 0.4), false, 0.9)


static func _shard(L: RefCounted, at: Vector3, yaw: float, s: float) -> void:
	# a piece of the bell's skirt: bronze bent on a tight arc and flaring toward the lip, half buried, the lip band thick
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, rng.randf_range(0.35, 1.05))
	var r := 0.95 * s
	var n := 7
	var span := rng.randf_range(1.2, 1.9)
	for i in n:
		var a := lerpf(-span * 0.5, span * 0.5, float(i) / float(n - 1))
		for row in 2:
			var flare := 1.0 + float(row) * 0.14
			var o := b * Vector3(sin(a) * r * flare, (0.25 + 0.5 * float(row)) * s, (cos(a) - 1.0) * r * flare)
			k.box("lore_bronze", at + o, Vector3(r * span / float(n) * 1.15 * flare, 0.52 * s, 0.07 * s), b * Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, -0.12 * float(row)), row == 0, rng.randf_range(0.55, 0.8))
	for i in n - 1:
		var a2 := lerpf(-span * 0.5, span * 0.5, (float(i) + 0.5) / float(n - 1))
		var o2 := b * Vector3(sin(a2) * r * 1.2, 1.02 * s, (cos(a2) - 1.0) * r * 1.2)
		k.box("lore_bronze", at + o2, Vector3(r * span / float(n - 1) * 1.25, 0.15 * s, 0.17 * s), b * Basis(Vector3.UP, -a2), false, 0.72)
	if rng.randf() < 0.6:
		var pat := CreatureMesh.new(rng.randi())
		pat.blob(Vector3.ZERO, Vector3(0.35, 0.05, 0.25) * s, Basis.IDENTITY, Color(0.45, 0.62, 0.52), 0.0, 0.4, 0.0, 4, 7)
		LK.organic(k, "lore_moss", pat.commit(), Transform3D(b, at + b * Vector3(0.0, 0.55 * s, -0.04 * s)))


static func _clamp(L: RefCounted, at: Vector3, r: float) -> void:
	# a charcoal clamp: a turfed dome over a stack of billets, its vents black
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var cm := CreatureMesh.new(rng.randi())
	cm.blob(Vector3.ZERO, Vector3(r, r * 0.62, r), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.2, 0.0, 8, 14)
	LK.organic(k, "lore_earth", cm.commit(), Transform3D(Basis.IDENTITY, at + Vector3.DOWN * 0.2), true)
	for i in 5:
		var a := TAU * float(i) / 5.0 + rng.randf_range(-0.2, 0.2)
		var o := Vector3(cos(a) * r * 0.62, r * 0.38, sin(a) * r * 0.62)
		k.box("lore_char", at + o, Vector3(0.24, 0.12, 0.24), Basis(Vector3.UP, a), false, 0.4)
	k.box("lore_char", at + Vector3.UP * (r * 0.62 - 0.25), Vector3(0.36, 0.14, 0.36), Basis.IDENTITY, false, 0.35)


static func _jetty(L: RefCounted, e: Dictionary, xf: Transform3D, yaw: float, rng: RandomNumberGenerator) -> void:
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw)
	var start := _g(L, xf, e.p)
	var deck_y := maxf(start.y, -0.9) + 0.45
	var length := float(e.len)
	var w := float(e.w)
	var n := int(length / 0.42)
	for i in n:
		if rng.randf() < 0.07 and i > 2:
			continue                                     # a board gone
		var q := start + b * Vector3(0, 0, -0.21 - float(i) * 0.42)
		k.box("lore_beam", Vector3(q.x, deck_y, q.z), Vector3(w * rng.randf_range(0.92, 1.0), 0.07, 0.38), b * Basis(Vector3.UP, rng.randf_range(-0.04, 0.04)), true, rng.randf_range(0.62, 0.82))
	for i in int(length / 1.8) + 1:
		for sx: float in [-1.0, 1.0]:
			var pq := start + b * Vector3(sx * (w * 0.5 + 0.05), 0, -float(i) * 1.8)
			var gy := minf(L.g(pq.x, pq.z), deck_y - 0.3)
			var top := deck_y + (0.4 if i == int(length / 1.8) else 0.05)
			k.box("lore_beam", Vector3(pq.x, (top + gy - 0.6) * 0.5, pq.z), Vector3(0.14, top - gy + 0.6, 0.14), b * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05)), true, 0.6)
	for sx2: float in [-1.0, 1.0]:
		k.box("lore_beam", start + b * Vector3(sx2 * (w * 0.5 - 0.05), 0, -length * 0.5) + Vector3.UP * (deck_y - start.y - 0.08), Vector3(0.12, 0.1, length), b, false, 0.6)


static func _trap(L: RefCounted, at: Vector3, yaw: float) -> void:
	# an eel trap: a wicker cone on its side, half in the water, staked
	var k: OssKit = L.k
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	var c := Vector3(at.x, maxf(at.y, -0.9) + 0.12, at.z)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var o := b * Vector3(cos(a) * 0.22, 0, sin(a) * 0.22)
		k.box("lore_beam", c + o, Vector3(0.025, 1.1, 0.025), b * Basis(Vector3.BACK, cos(a) * 0.12) * Basis(Vector3.RIGHT, sin(a) * 0.12), false, 0.75)
	for ry: float in [-0.4, 0.0, 0.4]:
		k.box("lore_beam", c + b * Vector3(0, ry, 0), Vector3(0.5 - ry * 0.15, 0.03, 0.5 - ry * 0.15), b, false, 0.7)
	k.box("lore_beam", c + Vector3.UP * 0.5, Vector3(0.05, 1.3, 0.05), Basis(Vector3.BACK, 0.15), false, 0.6)
