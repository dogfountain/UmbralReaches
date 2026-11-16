extends Node
## The Realm's terrain drawn in tiles (perf critique, 16 Nov). RealmLand builds Zone/Terrain as ONE mesh over the
## whole 740 x 548 m Realm (a 2 m grid, ~200k triangles): one mesh cannot be culled in part, so every frame the
## main pass drew all of it and the moon's shadow drew it again for each of its two splits, though the moon's
## shadow reaches only tens of metres (perf_tour census: Zone ~450-600k shadow primitives at every view, ~160-270k
## in the main pass). Here the same vertices are cut into TILE x TILE m tiles that draw and cast the moon shadow;
## the frustum and each shadow split keep only the tiles they touch. The ground looks and shadows the same: the
## tiles are the terrain's own triangles, under its own transform, with its own material, layers and flags.
##
## Zone/Terrain itself stays (TerrainStamp, the Ossuary's cut, the scorch map, its occluder child and the probes
## all find it by name and read or write its mesh): it keeps its data, casts no shadow and is on no render layer.
## Any later edit of its mesh (clear_surfaces + add_surface_from_arrays, e.g. the Ossuary's counting-door cut after
## the build) emits the mesh's `changed`, and the tiles are cut again from the new arrays (once a frame at most).
## Off in headless runs (nothing is drawn) and with --no-terrain-tiles (A/B).
## Load by path (no class_name).

const TILE_CELLS := 32                    ## grid cells a tile side (the Realm's grid is 2 m: 64 m tiles)

var terrain: MeshInstance3D
var _layers := 1
var _queued := false


## Once the Realm is built (realm.gd). Safe to call again: a second call finds the tiles already there.
static func attach(root: Node) -> void:
	if DisplayServer.get_name() == "headless" or "--no-terrain-tiles" in OS.get_cmdline_user_args():
		return
	var t := root.get_node_or_null("Zone/Terrain") as MeshInstance3D
	if t == null or not (t.mesh is ArrayMesh) or t.get_node_or_null("TerrainTiles") != null:
		return
	var n: Node = (load("res://core/world/realm/terrain_tiles.gd") as GDScript).new()
	n.name = "TerrainTiles"
	n.set("terrain", t)
	t.add_child(n)


func _ready() -> void:
	_layers = terrain.layers
	terrain.mesh.changed.connect(_queue)
	_cut()


func _queue() -> void:
	if not _queued:
		_queued = true
		_cut.call_deferred()


## Cut the terrain's current arrays into tiles. The grid is row-major (RealmLand's GNX x GNZ, its meta "grid");
## each triangle goes to the tile of its cell's lowest corner, so a tile's vertices are one (TILE_CELLS + 1)^2 block.
## Cells an edit took out (missing triangles) stay out.
func _cut() -> void:
	_queued = false
	if not is_instance_valid(terrain) or terrain.mesh == null:
		return
	var g: Variant = terrain.get_meta(&"grid") if terrain.has_meta(&"grid") else null
	if not (g is Array) or (g as Array).size() < 5:
		return
	var nx := int(g[3])
	var nz := int(g[4])
	var a: Array = terrain.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	if verts.size() != nx * nz:
		return
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var tx := ceili(float(nx - 1) / TILE_CELLS)
	var tz := ceili(float(nz - 1) / TILE_CELLS)
	# a counting sort: each triangle's tile, the tiles' counts and offsets, then the indices grouped by tile
	var ntri := idx.size() / 3
	var tid := PackedInt32Array()
	tid.resize(ntri)
	var cnt := PackedInt32Array()
	cnt.resize(tx * tz)
	cnt.fill(0)
	for t in ntri:
		var p := t * 3
		var lo := mini(idx[p], mini(idx[p + 1], idx[p + 2]))
		var hi_i := maxi(idx[p] % nx, maxi(idx[p + 1] % nx, idx[p + 2] % nx))
		var ci := hi_i - 1                                   # the cell's column (its corners are ci and ci + 1)
		var cj := lo / nx                                    # its row (the lowest index is on the cell's top row)
		var ti := mini(cj / TILE_CELLS, tz - 1) * tx + mini(ci / TILE_CELLS, tx - 1)
		tid[t] = ti
		cnt[ti] += 1
	var off := PackedInt32Array()
	off.resize(tx * tz + 1)
	off[0] = 0
	for k in tx * tz:
		off[k + 1] = off[k] + cnt[k] * 3
	var fill := off.duplicate()
	var grouped := PackedInt32Array()
	grouped.resize(idx.size())
	for t in ntri:
		var w := fill[tid[t]]
		grouped[w] = idx[t * 3]
		grouped[w + 1] = idx[t * 3 + 1]
		grouped[w + 2] = idx[t * 3 + 2]
		fill[tid[t]] = w + 3
	for c in get_children():
		c.free()
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var col: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2] if a[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	for tj in tz:
		for tl in tx:
			var k := tj * tx + tl
			if cnt[k] == 0:
				continue
			var list := grouped.slice(off[k], off[k + 1])
			var i0 := tl * TILE_CELLS
			var j0 := tj * TILE_CELLS
			var bw := mini(TILE_CELLS, nx - 1 - i0) + 1
			var bh := mini(TILE_CELLS, nz - 1 - j0) + 1
			_tile(tl, tj, i0, j0, bw, bh, nx, list, verts, nrm, col, uv, uv2)
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain.layers = 0                                       # drawn by the tiles; still in the tree for its readers


func _tile(tl: int, tj: int, i0: int, j0: int, bw: int, bh: int, nx: int, list: PackedInt32Array,
		verts: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, uv: PackedVector2Array,
		uv2: PackedVector2Array) -> void:
	var bv := PackedVector3Array()
	bv.resize(bw * bh)
	var bn := PackedVector3Array()
	var bc := PackedColorArray()
	var bu := PackedVector2Array()
	var bu2 := PackedVector2Array()
	if not nrm.is_empty():
		bn.resize(bw * bh)
	if not col.is_empty():
		bc.resize(bw * bh)
	if not uv.is_empty():
		bu.resize(bw * bh)
	if not uv2.is_empty():
		bu2.resize(bw * bh)
	for j in bh:
		for i in bw:
			var src := (j0 + j) * nx + i0 + i
			var dst := j * bw + i
			bv[dst] = verts[src]
			if not bn.is_empty():
				bn[dst] = nrm[src]
			if not bc.is_empty():
				bc[dst] = col[src]
			if not bu.is_empty():
				bu[dst] = uv[src]
			if not bu2.is_empty():
				bu2[dst] = uv2[src]
	var li := PackedInt32Array()
	li.resize(list.size())
	for k in list.size():
		var v := list[k]
		li[k] = (v / nx - j0) * bw + (v % nx - i0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = bv
	arr[Mesh.ARRAY_INDEX] = li
	if not bn.is_empty():
		arr[Mesh.ARRAY_NORMAL] = bn
	if not bc.is_empty():
		arr[Mesh.ARRAY_COLOR] = bc
	if not bu.is_empty():
		arr[Mesh.ARRAY_TEX_UV] = bu
	if not bu2.is_empty():
		arr[Mesh.ARRAY_TEX_UV2] = bu2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "TerrainTile_%d_%d" % [tl, tj]                # "Terrain*": Atmosphere's cull pass and FadeGuard leave it unranged
	mi.mesh = m
	mi.material_override = terrain.material_override
	mi.layers = _layers
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.gi_mode = terrain.gi_mode
	mi.extra_cull_margin = terrain.extra_cull_margin
	mi.ignore_occlusion_culling = terrain.ignore_occlusion_culling
	mi.lod_bias = terrain.lod_bias
	add_child(mi)
