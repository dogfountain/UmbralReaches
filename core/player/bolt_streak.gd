extends MeshInstance3D
## The ribbon behind a bolt: two layers (a wide soft glow, a thin white-hot core inside it) through the bolt's last
## positions, turned to the camera. Drawn every rendered frame from the bolt's interpolated head.
## It was an ImmediateMesh cleared and rebuilt each frame: two new mesh surfaces (their vertex buffers, formats and the
## instance's surface caches) for every bolt in flight, every frame. Now one mesh with a fixed set of vertices, made
## once; a frame writes the new positions and colours into its buffers. The same vertices and the same colours
## (8 bits a channel, as an ImmediateMesh stores them), so the same picture.
## Load by path (no class_name): const BoltStreak := preload("res://core/player/bolt_streak.gd")

const POINTS := 12                    ## MagicBolt.STREAK_POINTS
const VERTS := POINTS * 4             ## two layers, two sides
var _pos := PackedFloat32Array()
var _col := PackedByteArray()
var _rid: RID
var _empty := true


func _init() -> void:
	name = "Streak"
	top_level = true                  # world-space ribbon behind the bolt
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0
	var verts := PackedVector3Array()
	verts.resize(VERTS)
	var cols := PackedColorArray()
	cols.resize(VERTS)
	var idx := PackedInt32Array()
	for layer in 2:
		for i in POINTS - 1:
			var a := layer * POINTS * 2 + i * 2
			idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = m
	_rid = m.get_rid()
	_pos.resize(VERTS * 3)
	_col.resize(VERTS * 4)


## Nothing to draw (a bolt just armed, or back in the pool): every vertex on one point.
func clear() -> void:
	if _empty:
		return
	_empty = true
	_pos.fill(0.0)
	RenderingServer.mesh_surface_update_vertex_region(_rid, 0, 0, _pos.to_byte_array())


## `pts`: the head first, then the tail (world space). The core layer is 0.6 of the glow's length.
func draw(pts: PackedVector3Array, eye: Vector3, outer: Color, inner: Color, w_out: float, w_in: float) -> void:
	var n := pts.size()
	if n < 2:
		clear()
		return
	_empty = false
	var lo := pts[0]
	var hi := pts[0]
	for layer in 2:
		var w := w_out if layer == 0 else w_in
		var col := outer if layer == 0 else inner
		var last := maxi(1, int(round(float(n - 1) * (1.0 if layer == 0 else 0.6))))
		var o := layer * POINTS * 6
		var c := layer * POINTS * 8
		for i in POINTS:
			if i > last:                                 # past the ribbon's end: on its last pair (no area)
				for k in 6:
					_pos[o + k] = _pos[o + k - 6]
				o += 6
				c += 8
				continue
			var at := pts[i]
			var t := float(i) / float(last)
			var fwd := (pts[maxi(i - 1, 0)] - pts[mini(i + 1, n - 1)]).normalized()
			var side := fwd.cross(eye - at).normalized() * w * (1.0 - t * 0.85) * 0.5
			_pos[o] = at.x + side.x
			_pos[o + 1] = at.y + side.y
			_pos[o + 2] = at.z + side.z
			_pos[o + 3] = at.x - side.x
			_pos[o + 4] = at.y - side.y
			_pos[o + 5] = at.z - side.z
			o += 6
			var r := int(clampf(col.r * 255.0, 0.0, 255.0))
			var g := int(clampf(col.g * 255.0, 0.0, 255.0))
			var b := int(clampf(col.b * 255.0, 0.0, 255.0))
			var a := int(clampf(col.a * pow(1.0 - t, 1.4) * 255.0, 0.0, 255.0))
			for k in 2:
				_col[c] = r
				_col[c + 1] = g
				_col[c + 2] = b
				_col[c + 3] = a
				c += 4
			lo = lo.min(at)
			hi = hi.max(at)
	custom_aabb = AABB(lo, hi - lo).grow(w_out)
	RenderingServer.mesh_surface_update_vertex_region(_rid, 0, 0, _pos.to_byte_array())
	RenderingServer.mesh_surface_update_attribute_region(_rid, 0, 0, _col)
