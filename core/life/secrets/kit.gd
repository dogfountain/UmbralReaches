extends RefCounted
## Shared helpers for the secrets system (core/life/secrets): ground probes, flora clearance for a
## secret's footprint, procedural materials and textures (Image + FastNoiseLite, cached through
## GenCache), synthesised sounds (bells, stone, chimes), glints, and elite guardians.
## No class_name: const Kit := preload("res://core/life/secrets/kit.gd")

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Touch := preload("res://core/life/secrets/touch.gd")
const SELF := "res://core/life/secrets/kit.gd"
const RATE := 22050

static var _mats := {}
static var _texs := {}
static var _sounds := {}


## Drop every cached material, texture and sound (the director calls this when it leaves the
## tree). Static script vars outlive the RenderingServer at quit: a ShaderMaterial or ImageTexture
## still held here then is freed after the server is gone and Godot aborts (exit 134).
static func release() -> void:
	_mats.clear()
	_texs.clear()
	_sounds.clear()
	_pending.clear()


# --- ground and space ----------------------------------------------------------------------------

static func space(root: Node) -> PhysicsDirectSpaceState3D:
	return (root as Node3D).get_world_3d().direct_space_state


## A site built where it was made and moved after (the rift's rim, built round the chasm under Hearthward, stands
## Endgame.O east): while it builds its ground, its flora clearings and its sites are read and laid that far over.
static var shift := Vector2.ZERO


static func gy(sp: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(sp, x + shift.x, z + shift.y)


## Lowest ground under a disc (for seating a footprint so nothing floats).
static func low(sp: PhysicsDirectSpaceState3D, c: Vector2, r: float) -> float:
	var y := gy(sp, c.x, c.y)
	for i in 8:
		var a := TAU * float(i) / 8.0
		y = minf(y, gy(sp, c.x + cos(a) * r, c.y + sin(a) * r))
	return y


## Register a structure as a WorldLanes site (props/audits keep off it). Floors are not stamped:
## the secrets module runs after TerrainStamp, so it seats itself on the ground as it is.
## Flora inside the rect (grown by the reach of a plant's footprint) is cleared too.
static func site(root: Node, n: String, rect: Rect2, floor_y: float) -> void:
	rect = _trim(Rect2(rect.position + shift, rect.size))
	WorldLanes.register_site(n, rect, floor_y, floor_y - 0.3, false)
	var c := rect.get_center()
	_pending.append(Vector3(c.x, c.y, rect.size.length() * 0.5 + 2.5))      # (already where it stands)


## A secret's claim never overlaps an earlier site (a lore landmark, the drowned graves): each
## overlap is cut off along the axis where it is smallest, so the secret keeps its core.
static func _trim(r: Rect2) -> Rect2:
	for st: Dictionary in WorldLanes.sites:
		var o: Rect2 = st.rect
		if String(st.name).begins_with("secrets_") or not o.intersects(r):
			continue
		var ox := minf(r.end.x, o.end.x) - maxf(r.position.x, o.position.x)
		var oz := minf(r.end.y, o.end.y) - maxf(r.position.y, o.position.y)
		var c := r.get_center()
		var cut := r
		if ox <= oz:
			if o.get_center().x < c.x:
				cut = Rect2(o.end.x + 0.05, r.position.y, r.end.x - o.end.x - 0.05, r.size.y)
			else:
				cut = Rect2(r.position.x, r.position.y, o.position.x - 0.05 - r.position.x, r.size.y)
		else:
			if o.get_center().y < c.y:
				cut = Rect2(r.position.x, o.end.y + 0.05, r.size.x, r.end.y - o.end.y - 0.05)
			else:
				cut = Rect2(r.position.x, r.position.y, r.size.x, o.position.y - 0.05 - r.position.y)
		# a secret standing inside another site (the brine-clerk's vault in the salt-works' yard) would be
		# cut to nothing, or past it to a negative rect: it keeps its claim and shares the ground instead
		if cut.size.x >= 0.5 and cut.size.y >= 0.5:
			r = cut
	return r


## Remove flora (trees, undergrowth, trunk colliders) inside discs [Vector3(x, z, r)]: the module is
## built after RealmFlora, so a secret's footprint is cleared here, buffer-level (the Metal-safe
## way: the CPU copy in meta cpu_buffer is edited and written back whole). Returns instances hidden.
static var _pending: Array = []


static func clear_flora(_root: Node, discs: Array) -> void:
	for d: Vector3 in discs:
		_pending.append(Vector3(d.x + shift.x, d.y + shift.y, d.z))


## Do the queued clearance in one pass over the flora (secrets.gd calls it once, after every site). The scan of the instance
## buffers (millions of floats; pure data) runs on the worker pool, one task a buffer; the nodes are touched here on the main thread.
static func flush_flora(root: Node) -> int:
	var discs := _pending.duplicate()
	_pending.clear()
	var host := root.get_node_or_null("RealmFlora")
	if host == null or discs.is_empty():
		return 0
	var jobs: Array[Dictionary] = []          ## {mm, buf, stride, count, near, hit, n}
	for ch in host.get_children():
		var c3 := (ch as Node3D).position if ch is Node3D else Vector3.ZERO
		var near: Array = []
		for d: Vector3 in discs:
			if Vector2(c3.x, c3.z).distance_to(Vector2(d.x, d.y)) < d.z + 34.0:
				near.append(Vector3(d.x - c3.x, d.y - c3.z, d.z * d.z))     # chunk-local, radius squared
		if near.is_empty():
			continue
		for mmi_n in ch.get_children():
			if mmi_n is MultiMeshInstance3D:
				var mm := (mmi_n as MultiMeshInstance3D).multimesh
				if mm == null or not mm.has_meta("cpu_buffer"):
					continue
				jobs.append({"mm": mm, "buf": (mm.get_meta("cpu_buffer") as PackedFloat32Array).duplicate(), "stride": 16 if mm.use_colors else 12, "count": mm.instance_count,
					"near": near, "hit": false, "n": 0})
			elif mmi_n is StaticBody3D:
				for cs in (mmi_n as Node).get_children():
					if cs is CollisionShape3D:
						var p := (cs as CollisionShape3D).position
						for d: Vector3 in near:
							var r := sqrt(d.z) + 0.4
							if Vector2(p.x - d.x, p.z - d.y).length_squared() < r * r:
								(cs as CollisionShape3D).disabled = true
	if not jobs.is_empty():
		var gid := WorkerThreadPool.add_group_task(func(i: int) -> void: _clear_buffer(jobs[i]), jobs.size(), -1, true, "secrets flora clearance")
		WorkerThreadPool.wait_for_group_task_completion(gid)
	var n := 0
	for j: Dictionary in jobs:
		if bool(j.hit):
			var mm: MultiMesh = j.mm
			mm.buffer = j.buf
			mm.set_meta("cpu_buffer", j.buf)
			n += int(j.n)
	return n


## One flora buffer: every instance inside a cleared disc is collapsed to nothing and sunk (the work of a worker: it reads and writes
## its own job's buffer only).
static func _clear_buffer(j: Dictionary) -> void:
	var buf: PackedFloat32Array = j.buf
	var stride: int = j.stride
	var near: Array = j.near
	var hit := false
	var n := 0
	for i: int in int(j.count):
		var o := i * stride
		var lx := buf[o + 3]
		var lz := buf[o + 11]
		for d: Vector3 in near:
			var dx := lx - d.x
			var dz := lz - d.y
			if dx * dx + dz * dz < d.z:
				for k: int in [0, 1, 2, 4, 5, 6, 8, 9, 10]:
					buf[o + k] = 0.0
				buf[o + 7] -= 50.0
				hit = true
				n += 1
				break
	j.buf = buf
	j.hit = hit
	j.n = n


## Ground clear of sites, paths, water and steep slope near `want` (spiral search).
static func free_spot(sp: PhysicsDirectSpaceState3D, want: Vector2, pad := 1.4) -> Vector2:
	for k in 60:
		var a := float(k) * 2.4
		var r := 0.0 if k == 0 else 0.6 + float(k) * 0.35
		var p := want + Vector2(cos(a), sin(a)) * r
		if not WorldLanes.site_at(p, pad).is_empty():
			continue
		if RealmLayout.path_dist(p) < pad:
			continue
		var y0 := gy(sp, p.x - 0.8, p.y)
		var y1 := gy(sp, p.x + 0.8, p.y)
		var y2 := gy(sp, p.x, p.y - 0.8)
		var y3 := gy(sp, p.x, p.y + 0.8)
		if maxf(absf(y0 - y1), absf(y2 - y3)) > 0.6:
			continue
		return p
	return want


## A stair cut down a slope from `top` along `dir`: each tread (`tread` long, `width` across) sits
## just above the highest ground under it and drops at most `drop` from the last, so the flight never
## buries itself in a convex slope and never has a riser the wanderer cannot climb. Stops on reaching
## the ground (after `min_steps`) or after `max_steps`. Builds the steps into `k`; returns
## [[centre xz, top y], ...].
static func stair_down(sp: PhysicsDirectSpaceState3D, k: OssKit, top: Vector3, dir: Vector2, tread := 0.5, width := 1.5, drop := 0.36, min_steps := 6, max_steps := 70) -> Array:
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var p := Vector2(top.x, top.z)
	var y := top.y
	var steps: Array = []
	for i in max_steps:
		var hi := -INF
		for o: float in [-width * 0.5, 0.0, width * 0.5]:
			for q: float in [0.0, tread * 0.5, tread]:
				var s2 := p + side * o + dir * q
				hi = maxf(hi, gy(sp, s2.x, s2.y))
		var ny := maxf(y - drop, hi + 0.06)
		steps.append([p + dir * (tread * 0.5), ny])
		y = ny
		p += dir * tread
		if i >= min_steps and y - gy(sp, p.x, p.y) < 0.12:
			break
	var b := Basis(Vector3(side.x, 0, side.y), Vector3.UP, Vector3(dir.x, 0, dir.y)).orthonormalized()
	for i in steps.size():
		var c2: Vector2 = steps[i][0]
		var sy: float = steps[i][1]
		var gl := minf(gy(sp, c2.x + side.x * width * 0.5, c2.y + side.y * width * 0.5), gy(sp, c2.x - side.x * width * 0.5, c2.y - side.y * width * 0.5))
		k.box("stone", Vector3(c2.x, (sy + gl - 0.5) * 0.5, c2.y), Vector3(width, sy - gl + 0.5, tread + 0.03), b, true, 0.84 if i % 2 == 0 else 0.94)
	return steps


## A flagged causeway along a ridge line `pts` (xz): slabs every metre sit just above the highest
## ground under them, smoothed so no rise exceeds 0.34; low kerbs both sides and an invisible rail
## (the crest falls away steeply: nothing slides off it). Returns the slab tops [[xz, y], ...].
static func causeway(sp: PhysicsDirectSpaceState3D, k: OssKit, parent: Node, pts: Array, width := 1.9, open_end := 0) -> Array:
	var cells: Array = []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b)))
		for j in n:
			cells.append([a.lerp(b, (float(j) + 0.5) / float(n)), (b - a).normalized(), a.distance_to(b) / float(n)])
	var ys := PackedFloat32Array()
	for c: Array in cells:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		var side := Vector2(-d.y, d.x)
		var hi := -INF
		for o: float in [-width * 0.5, 0.0, width * 0.5]:
			for q: float in [-0.5, 0.0, 0.5]:
				var s2 := p + side * o + d * q
				hi = maxf(hi, gy(sp, s2.x, s2.y))
		ys.append(hi + 0.1)
	for i in range(1, ys.size()):
		ys[i] = maxf(ys[i], ys[i - 1] - 0.34)
	for i in range(ys.size() - 2, -1, -1):
		ys[i] = maxf(ys[i], ys[i + 1] - 0.34)
	# heights at the cell boundaries: each flag is a gentle ramp between them (no risers at all:
	# a capsule's round foot catches on small ones)
	var hb := PackedFloat32Array()
	hb.resize(ys.size() + 1)
	for j in ys.size() + 1:
		hb[j] = maxf(ys[maxi(j - 1, 0)], ys[mini(j, ys.size() - 1)])
	var out: Array = []
	for i in cells.size():
		var p2: Vector2 = cells[i][0]
		var d2: Vector2 = cells[i][1]
		var ln: float = cells[i][2]
		var side2 := Vector2(-d2.y, d2.x)
		var a2 := p2 - d2 * (ln * 0.5)
		var b2 := p2 + d2 * (ln * 0.5)
		var a3 := Vector3(a2.x, hb[i], a2.y)
		var b3 := Vector3(b2.x, hb[i + 1], b2.y)
		var fwd := (b3 - a3).normalized()
		var s3 := Vector3(side2.x, 0, side2.y)
		var up := fwd.cross(s3).normalized()
		if up.y < 0.0:
			up = -up
		var tb := Basis(s3, up, fwd).orthonormalized()
		var mid := (a3 + b3) * 0.5
		k.box("floor", mid - up * 0.16, Vector3(width, 0.32, a3.distance_to(b3) + 0.06), tb, true, 0.82 + 0.08 * float(i % 3) / 2.0)
		var gl := minf(gy(sp, p2.x + side2.x * width * 0.5, p2.y + side2.y * width * 0.5), gy(sp, p2.x - side2.x * width * 0.5, p2.y - side2.y * width * 0.5))
		var low_y := minf(hb[i], hb[i + 1]) - 0.3
		if low_y > gl - 0.4:
			var fb := Basis(s3, Vector3.UP, Vector3(d2.x, 0, d2.y)).orthonormalized()
			k.box("stone", Vector3(p2.x, (low_y + gl - 0.4) * 0.5, p2.y), Vector3(width - 0.1, low_y - gl + 0.4, ln), fb, true, 0.72)
		for s: float in [-1.0, 1.0]:
			var kc := mid + s3 * (s * (width * 0.5 + 0.1)) + up * 0.12
			k.box("stone", kc, Vector3(0.24, 0.3, a3.distance_to(b3) - 0.06), tb, false, 0.75)
			if i < cells.size() - open_end:
				box_body(parent, kc + Vector3.UP * 0.55, Vector3(0.2, 1.4, a3.distance_to(b3) + 0.1), tb)
		out.append([p2, (hb[i] + hb[i + 1]) * 0.5])
	return out


## Height of a causeway at its first point (where a stair joins it).
static func causeway_start(slabs: Array) -> float:
	return float(slabs[0][1]) if not slabs.is_empty() else 0.0


# --- interaction ------------------------------------------------------------------------------------

static func touch(parent: Node, at: Vector3, prompt: String, fn: Callable, reach := 2.2) -> Node3D:
	var t: Node3D = Touch.new()
	t.set("prompt", prompt)
	t.set("action", fn)
	t.call("set_reach", reach)
	parent.add_child(t)
	t.global_position = at
	return t


# --- materials ---------------------------------------------------------------------------------

static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"bronze":
			m.albedo_texture = tex("bronze_albedo")
			m.metallic = 0.55
			m.metallic_specular = 0.7
			m.roughness_texture = tex("bronze_rough")
			m.roughness = 1.0
			m.normal_enabled = true
			m.normal_texture = tex("bronze_normal")
			m.normal_scale = 0.8
			m.uv1_triplanar = true
			m.uv1_world_triplanar = false
			m.uv1_scale = Vector3.ONE * 0.9
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.rim_enabled = true
			m.rim = 0.45
			m.rim_tint = 0.7
		"rope":
			m.albedo_texture = tex("rope_albedo")
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.95
			m.uv1_scale = Vector3(6.0, 8.0, 1.0)
		"earth":
			m.albedo_texture = tex("earth_albedo")
			m.normal_enabled = true
			m.normal_texture = tex("earth_normal")
			m.roughness = 0.97
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * 0.35
			m.vertex_color_use_as_albedo = true
		"bark":
			var b := load("res://art/materials/bark_giant.tres") as StandardMaterial3D
			m = b.duplicate() as StandardMaterial3D
			m.vertex_color_use_as_albedo = true
			m.emission_energy_multiplier = 0.12
		"thorn":
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.9
			m.rim_enabled = true
			m.rim = 0.3
			m.emission_enabled = true
			m.emission = Color(0.35, 0.03, 0.05)
			m.emission_energy_multiplier = 0.35
		"thorn_dead":
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.62, 0.6, 0.58)
			m.roughness = 1.0
		"ember":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.5, 0.2)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.45, 0.15)
			m.emission_energy_multiplier = 1.0
		"ember_off":
			m.albedo_color = Color(0.1, 0.08, 0.08)
			m.roughness = 0.9
		"rune_lit":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.55, 0.85, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.4, 0.75, 1.0)
		"cloth_red":
			m.albedo_color = Color(0.55, 0.08, 0.06)
			m.roughness = 0.95
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_texture = tex("rope_albedo")
			m.uv1_scale = Vector3(3.0, 3.0, 1.0)
		"lamp_glass":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.6, 0.28)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.55, 0.2)
			m.emission_energy_multiplier = 1.1
		"lamp_dark":
			m.albedo_color = Color(0.07, 0.06, 0.06)
			m.roughness = 0.4
			m.metallic = 0.5
	_mats[key] = m
	return m


## Shader materials (lava curtain, moon shaft, glint, scorch ring).
static func shader_mat(key: String) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var sh := Shader.new()
	match key:
		"curtain":
			sh.code = CURTAIN_SHADER
		"shaft":
			sh.code = SHAFT_SHADER
		"glint":
			sh.code = GLINT_SHADER
		"scorch":
			sh.code = SCORCH_SHADER
		"mote":
			sh.code = MOTE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_mats[key] = m
	return m


# --- procedural textures (Image + FastNoiseLite, cached) -------------------------------------------

static func tex(key: String) -> Texture2D:
	if _texs.has(key):
		return _texs[key]
	var ck := "secrets_tex2_" + key
	var img: Image = null
	var cached: Variant = GenCache.load_var(ck, SELF)
	if cached is Dictionary:
		var d: Dictionary = cached
		img = Image.create_from_data(int(d.w), int(d.h), true, int(d.f), d.data)
	if img == null:
		img = _make_tex(key)
		img.generate_mipmaps()
		GenCache.save_var(ck, SELF, {"w": img.get_width(), "h": img.get_height(), "f": img.get_format(), "data": img.get_data()})
	var t := ImageTexture.create_from_image(img)
	_texs[key] = t
	return t


static func _noise(seed_v: int, freq: float, oct := 4, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = oct
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	return n


static func _make_tex(key: String) -> Image:
	var S := 256
	match key:
		"bronze_albedo", "bronze_rough":
			var a := _noise(11, 0.012, 5).get_seamless_image(S, S)
			var b := _noise(23, 0.05, 3, FastNoiseLite.TYPE_CELLULAR).get_seamless_image(S, S)
			var img := Image.create(S, S, false, Image.FORMAT_RGB8)
			for y in S:
				for x in S:
					var v := a.get_pixel(x, y).r
					var c := b.get_pixel(x, y).r
					var verd := smoothstep(0.52, 0.72, v + c * 0.25)
					if key == "bronze_albedo":
						var bronze := Color(0.42, 0.27, 0.13).lerp(Color(0.52, 0.36, 0.18), c)
						var green := Color(0.18, 0.36, 0.3).lerp(Color(0.3, 0.48, 0.4), v)
						var col := bronze.lerp(green, verd)
						col = col.darkened(0.25 * (1.0 - c))
						img.set_pixel(x, y, col)
					else:
						var r := lerpf(0.38, 0.85, verd) + (c - 0.5) * 0.12
						img.set_pixel(x, y, Color(r, r, r))
			return img
		"bronze_normal", "earth_normal":
			var h := _noise(31 if key == "bronze_normal" else 47, 0.03 if key == "bronze_normal" else 0.06, 5).get_seamless_image(S, S)
			h.convert(Image.FORMAT_RGBA8)
			h.bump_map_to_normal_map(2.0 if key == "bronze_normal" else 5.0)
			h.convert(Image.FORMAT_RGB8)
			return h
		"rope_albedo":
			var n := _noise(5, 0.08, 2).get_seamless_image(S, S)
			var img2 := Image.create(S, S, false, Image.FORMAT_RGB8)
			for y in S:
				for x in S:
					# twisted strands: diagonal bands with fibre noise
					var band := 0.5 + 0.5 * sin(float(x + y) * TAU / 32.0)
					var f := n.get_pixel(x, y).r
					var v := 0.35 + band * 0.4 + (f - 0.5) * 0.3
					img2.set_pixel(x, y, Color(v * 0.78, v * 0.66, v * 0.48))
			return img2
		"earth_albedo":
			var g := _noise(61, 0.02, 5).get_seamless_image(S, S)
			var s := _noise(73, 0.09, 3, FastNoiseLite.TYPE_CELLULAR).get_seamless_image(S, S)
			var img3 := Image.create(S, S, false, Image.FORMAT_RGB8)
			for y in S:
				for x in S:
					var v := g.get_pixel(x, y).r
					var st := s.get_pixel(x, y).r
					var turf := Color(0.16, 0.2, 0.12).lerp(Color(0.24, 0.27, 0.16), v)
					var soil := Color(0.2, 0.16, 0.12).lerp(Color(0.28, 0.22, 0.16), st)
					img3.set_pixel(x, y, turf.lerp(soil, smoothstep(0.55, 0.75, v + st * 0.3)))
			return img3
	return Image.create(4, 4, false, Image.FORMAT_RGB8)


# --- meshes ------------------------------------------------------------------------------------------

## A cached generated mesh: `make` builds it (CreatureMesh / SurfaceTool) the first time.
## `gen` is the script whose source generates it (its salt: editing that script rebuilds the entry).
static func cached_mesh(key: String, make: Callable, lods := false, gen := SELF) -> ArrayMesh:
	var m := GenCache.load_mesh("secrets_" + key + ("@lod" if lods else ""), gen)
	if m == null:
		m = make.call()
		if lods:
			m = OssKit.with_lods(m)
		GenCache.save_mesh("secrets_" + key + ("@lod" if lods else ""), gen, m)
	return m


## A bell as a surface of revolution (outer wall, lip, inner wall), axis +Y from the crown.
static func bell_mesh(size: float, seed_v: int) -> ArrayMesh:
	return cached_mesh("bell_%d_%d" % [int(size * 100.0), seed_v], func() -> ArrayMesh:
		var cm := CreatureMesh.new(seed_v)
		var prof := [[0.0, 0.0], [0.04, 0.2], [0.1, 0.3], [0.3, 0.33], [0.55, 0.38], [0.75, 0.47], [0.88, 0.6], [0.97, 0.7], [1.0, 0.72]]
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		# outer, crown -> lip; inner, lip -> crown (the bell is open)
		for p: Array in prof:
			pts.append(Vector3(0, -float(p[0]) * size, 0))
			rad.append(maxf(float(p[1]) * size, 0.001))
		for i in range(prof.size() - 1, 0, -1):
			var p2: Array = prof[i]
			pts.append(Vector3(0, -float(p2[0]) * size + 0.06 * size, 0))
			rad.append(maxf(float(p2[1]) * size - 0.05 * size, 0.001))
		cm.tube(pts, rad, 22, Color.WHITE, 0.0, 0.015)
		# the crown's canons (hanging loop) and a sound bow ring
		var loop := PackedVector3Array()
		var lr := PackedFloat32Array()
		for k in 9:
			var a := PI * float(k) / 8.0
			loop.append(Vector3(cos(a) * 0.12 * size, sin(a) * 0.14 * size + 0.02 * size, 0))
			lr.append(0.03 * size)
		cm.tube(loop, lr, 6, Color(0.85, 0.85, 0.85), 0.0, 0.05)
		return cm.commit())


static func mi(parent: Node, mesh: Mesh, m: Material, xf: Transform3D, vis_end := 0.0, shadows := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		n.visibility_range_end = vis_end
		n.visibility_range_end_margin = vis_end * 0.12
		n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(n)
	n.global_transform = xf
	return n


## Box collision under `parent` (world transform).
static func box_body(parent: Node, c: Vector3, size: Vector3, b := Basis.IDENTITY, layer := Layers.WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	body.global_transform = Transform3D(b.orthonormalized(), c)
	return body


static func set_body(body: CollisionObject3D, on: bool) -> void:
	if body == null:
		return
	body.collision_layer = Layers.WORLD if on else 0
	for cs in body.get_children():
		if cs is CollisionShape3D:
			(cs as CollisionShape3D).disabled = not on


static func glint(parent: Node, at: Vector3, col := Color(0.55, 0.8, 1.0), size := 0.32, range_end := 24.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var n := MeshInstance3D.new()
	n.name = "Glint"
	n.mesh = q
	n.material_override = shader_mat("glint")
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.set_instance_shader_parameter(&"tint", col)
	n.set_instance_shader_parameter(&"phase", fmod(at.x * 0.37 + at.z * 0.11, 1.0))
	n.visibility_range_end = range_end
	n.visibility_range_end_margin = 4.0
	n.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(n)
	n.global_position = at
	return n


static func omni(parent: Node, at: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 36.0
	l.distance_fade_length = 10.0
	l.set_meta(&"base", {"e": energy, "r": rng, "a": 1.0})   # LightPolicy._base format
	parent.add_child(l)
	l.global_position = at
	return l


static func fx_dust(at: Vector3, col := Color(0.5, 0.46, 0.42, 0.7), n := 30) -> void:
	Vfx.burst(at, col, {"count": n, "life": 1.6, "speed": Vector2(0.3, 1.6), "size": 0.22, "gravity": 0.4, "radius": 0.9, "additive": false, "turbulence": true})


static func fx_sparks(at: Vector3, col := Color(1.6, 0.8, 0.3)) -> void:
	Vfx.burst(at, col, {"count": 26, "life": 1.2, "speed": Vector2(0.4, 2.2), "size": 0.05, "gravity": -0.6, "radius": 0.4, "turbulence": true})


# --- sound (synthesised once, no assets) -----------------------------------------------------------

static func play(kind: String, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Sfx.play_stream(sound(kind), at, db, pitch, 0.0)


static func sound(kind: String) -> AudioStreamWAV:
	if _sounds.has(kind):
		return _sounds[kind]
	# synthesising is 10-40 ms of GDScript per sound: cached on disk, prewarmed at build (prewarm())
	var ck := "secrets_snd_" + kind
	var cached: Variant = GenCache.load_var(ck, SELF)
	if cached is PackedByteArray and not (cached as PackedByteArray).is_empty():
		var cw := AudioStreamWAV.new()
		cw.format = AudioStreamWAV.FORMAT_16_BITS
		cw.mix_rate = RATE
		cw.stereo = false
		cw.data = cached
		_sounds[kind] = cw
		return cw
	var pcm := PackedFloat32Array()
	match kind:
		"bell_great": pcm = _bell(98.0, 5.0)
		"bell_middle": pcm = _bell(146.8, 4.2)
		"bell_treble": pcm = _bell(220.0, 3.4)
		"bell_chord":
			var a := _bell(98.0, 6.0)
			var b := _bell(146.8, 6.0)
			var c := _bell(220.0, 6.0)
			pcm.resize(a.size())
			for i in a.size():
				pcm[i] = (a[i] + (b[i] if i < b.size() else 0.0) + (c[i] if i < c.size() else 0.0)) * 0.45
		"clank": pcm = _clank()
		"grind": pcm = _grind(2.6)
		"chime": pcm = _chime()
		"hum": pcm = _hum()
		"creak": pcm = _creak()
		"stone0": pcm = _stone_tone(196.0)
		"stone1": pcm = _stone_tone(233.08)
		"stone2": pcm = _stone_tone(261.63)
		"stone3": pcm = _stone_tone(311.13)
		"thud": pcm = _thud()
		"breath": pcm = _breath()
	var w := _wav(pcm)
	_sounds[kind] = w
	GenCache.save_var(ck, SELF, w.data)
	return w


const SOUNDS := ["bell_great", "bell_middle", "bell_treble", "bell_chord", "clank", "grind", "chime", "hum", "creak",
	"stone0", "stone1", "stone2", "stone3", "thud", "breath"]


## Make every secrets sound now (from the disk cache after the first run): no synthesis mid-play.
static func prewarm() -> void:
	for k: String in SOUNDS:
		sound(k)


static func _wav(pcm: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(pcm.size() * 2)
	for i in pcm.size():
		data.encode_s16(i * 2, int(clampf(pcm[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## A struck bell: inharmonic partials (hum, prime, tierce, quint, nominal...), each decaying at
## its own rate, with a short metallic strike transient.
static func _bell(f: float, dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var parts := [[0.5, 0.5, 0.35], [1.0, 1.0, 0.5], [1.19, 0.6, 0.7], [1.5, 0.45, 0.9], [2.0, 0.55, 1.1], [2.52, 0.3, 1.6], [3.0, 0.22, 2.0], [4.17, 0.12, 2.8]]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for p: Array in parts:
			s += sin(TAU * f * float(p[0]) * t) * float(p[1]) * exp(-t * float(p[2]) * 0.9)
		var strike := (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.4
		out[i] = (s * 0.32 + strike) * minf(t * 400.0, 1.0)
	return out


static func _clank() -> PackedFloat32Array:
	var n := int(0.9 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := sin(TAU * 311.0 * t) * 0.5 + sin(TAU * 467.0 * t) * 0.4 + sin(TAU * 523.0 * t * (1.0 + 0.02 * sin(t * 40.0))) * 0.35
		out[i] = s * exp(-t * 9.0) * 0.4 + (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.3
	return out


static func _grind(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.3, t) * smoothstep(dur, dur - 0.6, t)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.08)
		var judder := 0.6 + 0.4 * sin(t * TAU * 11.0) * sin(t * TAU * 2.3)
		out[i] = (lp * 2.2 * judder + sin(TAU * 52.0 * t) * 0.15) * env * 0.6
	return out


static func _chime() -> PackedFloat32Array:
	var n := int(2.2 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in 3:
			var st := float(k) * 0.16
			if t > st:
				var tt := t - st
				s += sin(TAU * [523.25, 659.26, 783.99][k] * tt) * exp(-tt * 2.6)
		out[i] = s * 0.22
	return out


static func _hum() -> PackedFloat32Array:
	var n := int(1.4 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.15, t) * exp(-t * 1.6)
		out[i] = (sin(TAU * 110.0 * t) + 0.5 * sin(TAU * 165.0 * t) + 0.25 * sin(TAU * 220.5 * t)) * env * 0.25
	return out


static func _creak() -> PackedFloat32Array:
	var n := int(1.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 90.0 + 60.0 * sin(t * 3.0) + 30.0 * sin(t * 17.0)
		ph += f / RATE
		var pulse := 1.0 if fmod(ph, 1.0) < 0.12 else 0.0
		out[i] = (pulse * 0.6 + (randf() - 0.5) * 0.15) * smoothstep(0.0, 0.1, t) * smoothstep(1.3, 0.9, t) * 0.5
	return out


## A hollow standing stone sung into: a soft breathy ocarina note (fundamental + octave + a little
## twelfth), a slow swell, air noise on the attack. Rooted, not churchly: no bell partials.
static func _stone_tone(f: float) -> PackedFloat32Array:
	var dur := 2.4
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.18, t) * exp(-t * 1.3)
		var vib := 1.0 + 0.004 * sin(t * TAU * 5.2) * smoothstep(0.2, 0.6, t)
		var s := sin(TAU * f * vib * t) + 0.32 * sin(TAU * 2.0 * f * vib * t) + 0.08 * sin(TAU * 3.0 * f * t)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.12)
		out[i] = (s * 0.26 + lp * 0.35 * exp(-t * 6.0)) * env
	return out


## A stone sung wrong: a short dull knock.
static func _thud() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.05)
		out[i] = (sin(TAU * 70.0 * t) * 0.5 + lp * 1.5) * exp(-t * 14.0) * 0.5
	return out


## The rift breathing out: a rising roar of hot air, low rumble under it.
static func _breath() -> PackedFloat32Array:
	var dur := 2.6
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := smoothstep(0.0, 0.35, t) * smoothstep(dur, dur - 0.9, t)
		var w := randf() * 2.0 - 1.0
		lp = lerpf(lp, w, 0.06 + 0.1 * smoothstep(0.0, 1.0, t))
		lp2 = lerpf(lp2, w, 0.01)
		out[i] = (lp * 1.3 + lp2 * 3.0 + sin(TAU * 41.0 * t) * 0.12) * env * 0.5
	return out


# --- elite guardians ------------------------------------------------------------------------------

## An elite guardian: an existing enemy kind, tougher at runtime (hp x5, harder strikes, more poise),
## a little larger, its own name. The caller tracks its death through Events.enemy_killed.
## `hp_min`: a floor on the elite's health (the Sexton is a hidden arena's master, not a big wretch).
static func spawn_elite(host: Node, kind: String, at: Vector3, title: String, hp_min := 0) -> Node3D:
	var e: Enemy
	match kind:
		"ossuant": e = Ossuant.new()
		"husk": e = Husk.new()
		"leaper": e = Leaper.new()
		"spitter": e = Spitter.new()
		_: e = Wretch.new()
	e.max_hp = maxi(e.max_hp * 5, hp_min)
	e.hp = float(e.max_hp)
	e.strike_gloom *= 1.35
	e.poise *= 2.2
	e.walk_speed *= 1.08
	e.hunt_leash = 22.0
	e.chase_range = 14.0
	e.light_averse = false
	e.set_meta("elite", title)
	host.add_child(e)
	e.name = "Elite_" + title.replace(" ", "")
	e.station(at)
	var rig: Variant = e.get("_rig")
	if rig is Node3D:
		(rig as Node3D).scale *= 1.28
	e.hp_bar_y *= 1.25
	return e


# --- shaders --------------------------------------------------------------------------------------

const GLINT_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
instance uniform vec4 tint : source_color = vec4(0.55, 0.8, 1.0, 1.0);
instance uniform float phase = 0.0;
varying float pulse;
void vertex() {
	float t = TIME * 0.8 + phase * 6.2831;
	pulse = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(t), 3.0);
	vec3 drift = vec3(sin(t * 0.7) * 0.04, sin(t * 0.5 + 1.3) * 0.08, 0.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3] + vec4(drift, 0.0));
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float core = smoothstep(0.2, 0.0, d);
	float halo = smoothstep(1.0, 0.1, d) * 0.2;
	ALBEDO = tint.rgb * (core * 1.2 + halo) * pulse;
	ALPHA = clamp(core + halo, 0.0, 1.0);
}
"""

## A sheet of molten rock poured over a lip: UV.y runs down the sheet. Crust bands slide down,
## hot seams between them; edges thin out. Peak emission stays near the lava's own.
const CURTAIN_SHADER := """
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, shadows_disabled;
uniform float speed = 0.55;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 uv = UV;
	float flow = uv.y * 6.0 - TIME * speed * 3.0;
	float a = n(vec2(uv.x * 7.0, flow)) * 0.6 + n(vec2(uv.x * 19.0, flow * 2.3)) * 0.4;
	float seam = smoothstep(0.55, 0.72, a) * mix(1.0, 0.55, smoothstep(0.2, 0.6, uv.y));      // hot threads in a dark crust, cooling as it falls
	// ragged sides that shift as it pours, and below the spout the sheet parts into rivulets (a flat panel of even
	// orange stood on edge read as a door of light)
	float rag = 0.12 + 0.22 * n(vec2(uv.y * 4.0 - TIME * speed * 2.0, floor(uv.x + 0.5) * 7.3));
	float edge = smoothstep(0.0, rag, uv.x) * smoothstep(1.0, 1.0 - rag, uv.x);
	float strands = smoothstep(0.3, 0.6, n(vec2(uv.x * 6.0, flow * 0.25)));
	float part = mix(1.0, strands, smoothstep(0.05, 0.45, uv.y));
	vec3 crust = vec3(0.09, 0.03, 0.02);
	vec3 hot = vec3(1.0, 0.36, 0.08);
	ALBEDO = mix(crust, hot * 0.4, seam);
	EMISSION = hot * (0.04 + seam * 1.1) * edge * (0.85 + 0.15 * sin(TIME * 3.0 + uv.y * 9.0));
	ROUGHNESS = 0.6;
	ALPHA = edge * part * (0.75 + 0.25 * a);
	ALPHA_SCISSOR_THRESHOLD = 0.25;
}
"""

## A soft shaft of moonlight (a cone card set): additive, faint, fading at the top and bottom and
## at grazing angles; dust drifts through it. Peak stays well under the glow threshold.
const SHAFT_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform float strength = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	float across = sin(UV.x * 3.14159);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float facing = abs(dot(NORMAL, VIEW));
	float dust = 0.75 + 0.25 * n(vec2(UV.x * 9.0, UV.y * 4.0 - TIME * 0.08));
	float a = across * across * along * facing * dust * 0.1 * strength;
	ALBEDO = vec3(0.55, 0.72, 1.0) * a;
}
"""

const SCORCH_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform vec4 tint : source_color = vec4(0.4, 0.2, 0.9, 1.0);
instance uniform float glow = 0.3;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float ragged = 0.78 + 0.18 * n(vec2(ang * 3.0, 1.7)) + 0.06 * n(vec2(ang * 11.0, 4.1));
	float burn = smoothstep(ragged, ragged - 0.35, r);
	float cracks = smoothstep(0.88, 0.97, n(vec2(ang * 7.0, r * 6.0))) * smoothstep(ragged, 0.2, r);
	ALBEDO = mix(vec3(0.05, 0.045, 0.05), tint.rgb * 0.2, cracks);
	EMISSION = tint.rgb * cracks * glow;
	ROUGHNESS = 1.0;
	ALPHA = burn * 0.82;
}
"""

const MOTE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.6, 0.78, 1.0) * smoothstep(1.0, 0.0, d) * 0.5 * COLOR.a;
}
"""
