extends RefCounted
## More variants for the clutter families (the deeper-models pass): site_props.gd's crate, barrel, bench, cart, sack and
## firewood each had one or two modelled variants, so every yard drew the same few shapes in a row. Each family now has
## three to five (stacks, lids and ropes, tipped and broken ones, loaded carts), built from the OssKit's boxes once and cached,
## drawn like the modelled ones (one MultiMesh per variant and material, chosen by instance index). Foot at y = 0, middle at
## the origin in xz, like the rest. Load by path: preload("res://core/world/realm/site_props_more.gd").

const KINDS := ["crate", "barrel", "bench", "cart", "sack", "firewood"]
static var _cache := {}


## Extra variants of `key` as [[{mesh, mat}]]: each variant is a list of parts (one per material).
static func extra(key: String) -> Array:
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	match key:
		"crate":
			out = [_parts(_crate_stack())]
		"barrel":
			out = [_parts(_barrel_pair())]
		"bench":
			out = [_parts(_bench_pot())]
		"cart":
			out = [_parts(_cart_loaded())]
		"sack":
			out = [_parts(_sack_pile())]
		"firewood":
			out = [_parts(_chopping_block())]
	_cache[key] = out
	return out


static func _parts(k: OssKit) -> Array:
	var out: Array = []
	for key: String in k._st:
		var am := ArrayMesh.new()
		(k._st[key] as SurfaceTool).commit(am)
		out.append({"mesh": am, "mat": OssKit.mat(key)})
	return out


static func _crate(k: OssKit, c: Vector3, s: float, yaw: float, tint := 0.85) -> void:
	var b := Basis(Vector3.UP, yaw)
	k.box("wood", c + Vector3.UP * s * 0.5, Vector3(s, s, s), b, false, tint)
	k.box("iron", c + Vector3.UP * s * 0.5, Vector3(s * 1.03, 0.05, s * 1.03), b, false, 0.6)
	for sx: float in [-1.0, 1.0]:
		k.box("wood", c + b * Vector3(sx * s * 0.5, s * 0.5, 0.0), Vector3(0.06, s * 1.02, 0.1), b, false, tint * 0.8)


static func _crate_stack() -> OssKit:
	var k := OssKit.new()
	_crate(k, Vector3(-0.2, 0.0, 0.0), 0.8, 0.1)
	_crate(k, Vector3(0.55, 0.0, 0.1), 0.65, -0.3)
	_crate(k, Vector3(0.0, 0.8, 0.0), 0.62, 0.5, 0.78)
	return k


static func _crate_ropes() -> OssKit:
	var k := OssKit.new()
	_crate(k, Vector3.ZERO, 0.85, 0.0)
	for i in 2:
		k.box("wood", Vector3(0.0, 0.42 + 0.25 * float(i), 0.0), Vector3(0.9, 0.04, 0.9), Basis(Vector3.UP, 0.0), false, 0.55)
	k.box("wood", Vector3(0.0, 0.87, 0.0), Vector3(0.9, 0.08, 0.9), Basis(Vector3.UP, 0.15), false, 0.75)       # a lid slid half off
	return k


static func _crate_tipped() -> OssKit:
	var k := OssKit.new()
	var b := Basis(Vector3.BACK, 0.5)
	k.box("wood", Vector3(0.0, 0.42, 0.0), Vector3(0.8, 0.8, 0.8), b, false, 0.8)
	k.box("iron", Vector3(0.0, 0.42, 0.0), Vector3(0.83, 0.05, 0.83), b, false, 0.55)
	k.box("wood", Vector3(0.7, 0.07, 0.2), Vector3(0.5, 0.12, 0.08), Basis(Vector3.UP, 0.8), false, 0.7)         # a splinter of plank
	return k


static func _barrel(k: OssKit, c: Vector3, h: float, yaw := 0.0) -> void:
	for i in 8:
		var a := TAU * float(i) / 8.0 + yaw
		var r := 0.36 + 0.05 * sin(PI * 0.5)
		k.box("wood", c + Vector3(cos(a) * r, h * 0.5, sin(a) * r), Vector3(0.28, h, 0.07), Basis(Vector3.UP, -a + PI * 0.5), false, 0.82)
	for y: float in [0.2, 0.8]:
		for i in 8:
			var a := TAU * float(i) / 8.0 + yaw
			k.box("iron", c + Vector3(cos(a) * 0.42, h * y, sin(a) * 0.42), Vector3(0.3, 0.05, 0.09), Basis(Vector3.UP, -a + PI * 0.5), false, 0.55)
	k.box("wood", c + Vector3(0.0, h, 0.0), Vector3(0.7, 0.05, 0.7), Basis(Vector3.UP, yaw + PI / 8.0), false, 0.75)


static func _barrel_pair() -> OssKit:
	var k := OssKit.new()
	_barrel(k, Vector3(-0.4, 0.0, 0.0), 0.95)
	_barrel(k, Vector3(0.45, 0.0, 0.15), 0.85, 0.3)
	return k


static func _barrel_lying() -> OssKit:
	var k := OssKit.new()
	var b := Basis(Vector3.BACK, PI * 0.5)
	for i in 8:
		var a := TAU * float(i) / 8.0
		k.box("wood", Vector3(0.0, 0.38 + sin(a) * 0.4, cos(a) * 0.4), Vector3(0.95, 0.07, 0.28), Basis(Vector3.RIGHT, a + PI * 0.5), false, 0.8)
	for x: float in [-0.3, 0.3]:
		k.box("iron", Vector3(x, 0.38, 0.0), Vector3(0.05, 0.82, 0.82), Basis.IDENTITY, false, 0.55)
	k.box("wood", Vector3(0.5, 0.38, 0.0), Vector3(0.05, 0.74, 0.74), Basis.IDENTITY, false, 0.7)
	var _bb := b
	return k


static func _barrel_lid() -> OssKit:
	var k := OssKit.new()
	_barrel(k, Vector3.ZERO, 0.95)
	k.box("wood", Vector3(0.55, 0.04, 0.2), Vector3(0.7, 0.05, 0.7), Basis(Vector3.UP, 0.4), false, 0.75)      # its lid on the ground
	k.box("iron", Vector3(0.2, 1.0, 0.1), Vector3(0.05, 0.3, 0.05), Basis(Vector3.BACK, 0.4), false, 0.55)    # a ladle in it
	return k


static func _bench_pot() -> OssKit:
	var k := OssKit.new()
	k.box("wood", Vector3(0.0, 0.45, 0.0), Vector3(1.6, 0.08, 0.4), Basis.IDENTITY, false, 0.8)
	for sx: float in [-0.65, 0.65]:
		k.box("wood", Vector3(sx, 0.22, 0.0), Vector3(0.1, 0.45, 0.34), Basis.IDENTITY, false, 0.7)
	k.box("iron", Vector3(0.3, 0.6, 0.0), Vector3(0.22, 0.22, 0.22), Basis.IDENTITY, false, 0.55)             # a pot
	k.box("wood", Vector3(-0.4, 0.52, 0.05), Vector3(0.14, 0.14, 0.14), Basis(Vector3.UP, 0.4), false, 0.7)   # a cup
	return k


static func _stool() -> OssKit:
	var k := OssKit.new()
	k.box("wood", Vector3(0.0, 0.42, 0.0), Vector3(0.42, 0.07, 0.42), Basis(Vector3.UP, 0.3), false, 0.8)
	for i in 3:
		var a := TAU * float(i) / 3.0
		k.box("wood", Vector3(cos(a) * 0.14, 0.2, sin(a) * 0.14), Vector3(0.06, 0.42, 0.06), Basis(Vector3.UP, 0.0) * Basis(Vector3(cos(a + 1.57), 0.0, sin(a + 1.57)), 0.15), false, 0.7)
	return k


static func _cart_loaded() -> OssKit:
	var k := OssKit.new()
	k.box("wood", Vector3(0.0, 0.55, 0.0), Vector3(1.5, 0.08, 0.9), Basis.IDENTITY, false, 0.85)
	for sz: float in [-0.42, 0.42]:
		k.box("wood", Vector3(0.0, 0.75, sz), Vector3(1.5, 0.32, 0.06), Basis.IDENTITY, false, 0.9)
	k.box("wood", Vector3(-0.72, 0.75, 0.0), Vector3(0.06, 0.32, 0.9), Basis.IDENTITY, false, 0.9)
	_crate(k, Vector3(-0.2, 0.59, 0.0), 0.55, 0.2)
	_crate(k, Vector3(0.4, 0.59, 0.1), 0.45, -0.3)
	for sz: float in [-0.52, 0.52]:
		k.box("wood", Vector3(0.0, 0.36, sz), Vector3(0.72, 0.72, 0.05), Basis.IDENTITY, false, 0.7)
		k.box("iron", Vector3(0.0, 0.36, sz), Vector3(0.78, 0.06, 0.06), Basis.IDENTITY, false, 0.55)
	k.box("wood", Vector3(1.2, 0.34, 0.0), Vector3(1.2, 0.06, 0.06), Basis(Vector3.BACK, -0.28), false, 0.8)
	return k


static func _cart_tipped() -> OssKit:
	var k := OssKit.new()
	var b := Basis(Vector3.RIGHT, 0.55)
	k.box("wood", Vector3(0.0, 0.5, 0.0), Vector3(1.5, 0.08, 0.9), b, false, 0.85)
	k.box("wood", Vector3(0.0, 0.7, 0.4), Vector3(1.5, 0.32, 0.06), b, false, 0.9)
	k.box("wood", Vector3(0.0, 0.05, -0.95), Vector3(0.7, 0.05, 0.7), Basis(Vector3.UP, 0.3), false, 0.7)
	for sz: float in [-0.52, 0.52]:
		k.box("wood", Vector3(0.0, 0.36, sz * 0.8 + 0.4), Vector3(0.72, 0.72, 0.05), Basis.IDENTITY, false, 0.7)
	return k


static func _sack_pile() -> OssKit:
	var k := OssKit.new()
	for e: Array in [[-0.3, 0.0, 0.0], [0.25, 0.1, 0.4], [0.0, 0.0, -0.4], [-0.1, 0.3, 0.1]]:
		var p := Vector3(float(e[0]), 0.0, float(e[2]))
		var y := float(e[1])
		k.box("wood", p + Vector3(0.0, y + 0.2, 0.0), Vector3(0.5, 0.4, 0.34), Basis(Vector3.UP, p.x * 3.0), false, 0.95)
		k.box("wood", p + Vector3(0.0, y + 0.42, 0.0), Vector3(0.2, 0.08, 0.2), Basis(Vector3.UP, p.z * 3.0), false, 0.8)
	return k


static func _chopping_block() -> OssKit:
	var k := OssKit.new()
	for i in 8:
		var a := TAU * float(i) / 8.0
		k.box("wood", Vector3(cos(a) * 0.17, 0.2, sin(a) * 0.17), Vector3(0.18, 0.4, 0.1), Basis(Vector3.UP, -a), false, 0.7)
	k.box("wood", Vector3(0.0, 0.41, 0.0), Vector3(0.4, 0.04, 0.4), Basis(Vector3.UP, 0.4), false, 0.6)
	k.box("iron", Vector3(0.1, 0.55, 0.0), Vector3(0.22, 0.12, 0.03), Basis(Vector3.BACK, -0.3), false, 0.55)     # an axe head in it
	k.box("wood", Vector3(0.3, 0.7, 0.0), Vector3(0.6, 0.04, 0.04), Basis(Vector3.BACK, -0.6), false, 0.75)
	for e: Array in [[0.7, 0.0, 0.2], [0.85, 0.1, -0.1], [0.6, 0.0, -0.3]]:
		k.box("wood", Vector3(float(e[0]), 0.1 + float(e[1]), float(e[2])), Vector3(0.3, 0.16, 0.16), Basis(Vector3.UP, float(e[2]) * 4.0), false, 0.75)
	return k


static func _firewood_rack() -> OssKit:
	var k := OssKit.new()
	for sx: float in [-0.8, 0.8]:
		k.box("wood", Vector3(sx, 0.55, 0.0), Vector3(0.08, 1.1, 0.4), Basis.IDENTITY, false, 0.7)
	for r in 4:
		for c in 7:
			k.box("wood", Vector3(-0.66 + 0.22 * float(c), 0.14 + 0.24 * float(r), 0.0), Vector3(0.18, 0.2, 0.34), Basis(Vector3.UP, 0.0), false, 0.72 + 0.1 * float((r + c) % 2))
	k.box("wood", Vector3(0.0, 1.12, 0.0), Vector3(1.8, 0.05, 0.5), Basis(Vector3.RIGHT, 0.1), false, 0.65)
	return k
