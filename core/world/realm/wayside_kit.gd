extends RefCounted
## The wayside's kinds of place (realm_wayside.gd plans them, wayside_themes.gd says which go where): each kind first
## lays itself out as data (layout: pieces in the place's own frame, local -z facing the way it is read from), so the
## planner can register the ground each solid piece stands on before the flora grows, and the same pieces are built
## after the flora (wayside_build.gd) with the lore kit's walls, carts, graves and stones, the in-house prop models
## (art/models/props) and the site props' clutter. Nothing here lights itself: a camp's fire is cold, a lamp unlit.
## Load by path: const Kit := preload("res://core/world/realm/wayside_kit.gd")

const PropModels := preload("res://core/world/realm/prop_models.gd")


# --- layout -------------------------------------------------------------------------------------

## The pieces of a place of `kind` (each a Dictionary with "t", its type, and local points), drawn from `rng`.
static func layout(kind: String, rng: RandomNumberGenerator) -> Array:
	match kind:
		"wall": return _l_wall(rng)
		"fold": return _l_fold(rng)
		"cottage": return _l_cottage(rng)
		"shrine": return _l_shrine(rng)
		"stones": return _l_stones(rng)
		"circle": return _l_circle(rng)
		"cairns": return _l_cairns(rng)
		"cart": return _l_cart(rng)
		"camp": return _l_camp(rng)
		"well": return _l_well(rng)
		"graves": return _l_graves(rng)
		"woodpile": return _l_woodpile(rng)
		"statue": return _l_statue(rng)
		"blocks": return _l_blocks(rng)
		"lookout": return _l_lookout(rng)
		"battle": return _l_battle(rng)
		"debris": return _l_debris(rng)
		"barrow": return _l_barrow(rng)
		"charcoal": return _l_charcoal(rng)
		"farm": return _l_farm(rng)
		"milestone": return _l_milestone(rng)
		"jetty": return _l_jetty(rng)
		"bones": return _l_bones(rng)
		"lowwall": return _l_lowwall(rng)
		"marker": return _l_marker(rng)
		"stele": return _l_stele(rng)
		"pier": return _l_pier(rng)
		"ruinshrine": return _l_ruinshrine(rng)
		"drowned": return [{"t": "glb", "f": "ruin_drowned.glb", "p": _v(0.0, 0.0), "yaw": rng.randf() * TAU, "s": rng.randf_range(0.85, 1.05), "col": true, "tilt": rng.randf_range(-0.08, 0.08)}]
	return []


static func _v(x: float, z: float) -> Vector2:
	return Vector2(x, z)


static func _l_wall(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var a := _v(rng.randf_range(-6.0, -4.5), rng.randf_range(-1.0, 1.0))
	var m := _v(rng.randf_range(-0.5, 1.5), rng.randf_range(-1.6, 1.6))
	var b := _v(rng.randf_range(4.5, 6.0), rng.randf_range(-1.5, 1.5))
	var h := rng.randf_range(0.75, 1.35)
	var ruin := rng.randf_range(0.35, 0.7)
	var gap := rng.randf_range(0.3, 0.7)
	var g0 := a.lerp(m, gap - 0.12)
	var g1 := a.lerp(m, gap + 0.12)
	out.append({"t": "wall", "a": a, "b": g0, "h": h, "ruin": ruin})
	out.append({"t": "wall", "a": g1, "b": m, "h": h * rng.randf_range(0.8, 1.1), "ruin": ruin})
	out.append({"t": "wall", "a": m, "b": b, "h": h * rng.randf_range(0.6, 1.0), "ruin": minf(ruin + 0.2, 0.9)})
	if rng.randf() < 0.55:
		out.append({"t": "glb", "f": "wall_pier.glb", "p": a + (a - m).normalized() * 0.6, "yaw": rng.randf() * 0.3, "s": h / 1.6, "col": true})
	out.append({"t": "rubble", "p": b + (b - m).normalized() * 0.8, "r": 1.4, "n": 7})
	if rng.randf() < 0.4:
		out.append({"t": "clutter", "k": "flag2", "p": (g0 + g1) * 0.5 + _v(0.0, 0.3), "yaw": rng.randf() * TAU, "s": 1.0})
	return out


static func _l_fold(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var r := rng.randf_range(3.4, 4.3)
	var n := 10
	var gate := rng.randi_range(-1, 1)                 # the gap near the front (local -z, toward the way)
	var h := rng.randf_range(0.85, 1.2)
	for i in n:
		if i == 7 + gate:
			continue
		var a0 := TAU * float(i) / float(n) + 0.12
		var a1 := TAU * float(i + 1) / float(n) + 0.12
		out.append({"t": "wall", "a": _v(cos(a0) * r, sin(a0) * r), "b": _v(cos(a1) * r, sin(a1) * r), "h": h * rng.randf_range(0.75, 1.05), "ruin": rng.randf_range(0.2, 0.55)})
	if rng.randf() < 0.6:
		out.append({"t": "glb", "f": "trough.glb", "p": _v(rng.randf_range(-1.0, 1.0), rng.randf_range(0.5, 1.5)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	if rng.randf() < 0.5:
		out.append({"t": "clutter", "k": "hay", "p": _v(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.0)), "yaw": rng.randf() * TAU, "s": 1.2})
	for i in rng.randi_range(0, 3):
		out.append({"t": "clutter", "k": ["bone", "rib", "skull"][rng.randi() % 3], "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.6, 1.6), 1.8)})
	return out


static func _l_cottage(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var w := rng.randf_range(2.1, 2.8)                 # half width (x)
	var d := rng.randf_range(2.8, 3.5)                 # half depth (z); the door is in the front wall (-z)
	var hb := rng.randf_range(1.7, 2.5)
	var door := rng.randf_range(-0.6, 0.6)
	# back wall (the gable that stood), the sides, the front with its door gap
	out.append({"t": "wall", "a": _v(-w, d), "b": _v(w, d), "h": hb, "ruin": rng.randf_range(0.15, 0.4)})
	for sx: float in [-1.0, 1.0]:
		var cut := rng.randf_range(0.25, 0.75)
		out.append({"t": "wall", "a": _v(sx * w, d), "b": _v(sx * w, lerpf(d, -d, cut)), "h": hb * rng.randf_range(0.7, 0.95), "ruin": 0.5})
		out.append({"t": "wall", "a": _v(sx * w, lerpf(d, -d, cut)), "b": _v(sx * w, -d), "h": hb * rng.randf_range(0.3, 0.6), "ruin": 0.75})
	out.append({"t": "wall", "a": _v(-w, -d), "b": _v(door - 0.6, -d), "h": hb * rng.randf_range(0.35, 0.7), "ruin": 0.6})
	out.append({"t": "wall", "a": _v(door + 0.6, -d), "b": _v(w, -d), "h": hb * rng.randf_range(0.3, 0.6), "ruin": 0.7})
	# the chimney stood at one gable end
	var cx := -w + 0.55 if rng.randf() < 0.5 else w - 0.55
	out.append({"t": "chimney", "p": _v(cx, d - 0.45), "h": hb + rng.randf_range(0.6, 1.3)})
	out.append({"t": "clutter", "k": "flag", "p": _v(cx * 0.7, d - 1.3), "yaw": 0.0, "s": 1.0})
	# the roof fell in: a beam or two leaning off the walls, slates and rubble on the floor
	for i in rng.randi_range(1, 2):
		var bx := rng.randf_range(-w * 0.6, w * 0.6)
		out.append({"t": "beam", "a": Vector3(bx, hb * 0.85, d - 0.2), "b": Vector3(bx + rng.randf_range(-0.8, 0.8), 0.1, rng.randf_range(-d * 0.6, d * 0.2))})
	out.append({"t": "rubble", "p": _v(rng.randf_range(-w * 0.5, w * 0.5), rng.randf_range(-d * 0.3, d * 0.5)), "r": 1.3, "n": 8})
	out.append({"t": "rubble", "p": _v(w + 0.8, rng.randf_range(-d, d)), "r": 1.0, "n": 5})
	if rng.randf() < 0.6:
		out.append({"t": "glb", "f": "crate_broken.glb", "p": _v(-cx * 0.6, d - 1.0), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	if rng.randf() < 0.5:
		out.append({"t": "glb", "f": "barrel_tipped.glb", "p": _v(rng.randf_range(-w + 0.8, w - 0.8), rng.randf_range(-d + 1.0, 0.0)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	for i in 4:
		out.append({"t": "clutter", "k": "leaf", "p": _v(rng.randf_range(-w + 0.4, w - 0.4), rng.randf_range(-d + 0.4, d - 0.4)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "spot", "p": _v(-cx * 0.55, d - 0.9)})
	out.append({"t": "lore", "c": "page", "p": _v(cx * 0.4, d - 1.4)})
	return out


static func _l_shrine(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var style := rng.randi() % 3
	match style:
		0:
			out.append({"t": "glb", "f": "ruin_marker.glb", "p": _v(0.0, 0.6), "yaw": PI, "s": rng.randf_range(1.0, 1.25), "col": true})
		1:
			out.append({"t": "glb", "f": "market_cross.glb", "p": _v(0.0, 0.6), "yaw": rng.randf() * 0.4, "s": rng.randf_range(0.5, 0.6), "col": true})
		2:
			out.append({"t": "saint", "p": _v(0.0, 0.7), "yaw": 0.0, "v": rng.randi_range(1, 3), "plinth": 0.45, "s": 0.8})
	out.append({"t": "clutter", "k": "flag", "p": _v(0.0, -0.5), "yaw": rng.randf_range(-0.2, 0.2), "s": 1.0})
	if rng.randf() < 0.5:
		out.append({"t": "clutter", "k": "flag2", "p": _v(rng.randf_range(-0.8, 0.8), -1.2), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "cairn", "p": _v(rng.randf_range(0.7, 1.1), rng.randf_range(-0.3, 0.3)), "h": rng.randf_range(0.35, 0.55)})
	if rng.randf() < 0.5:
		out.append({"t": "cairn", "p": _v(rng.randf_range(-1.1, -0.7), rng.randf_range(-0.2, 0.4)), "h": rng.randf_range(0.25, 0.4)})
	if rng.randf() < 0.35:
		out.append({"t": "glb", "f": "bench.glb", "p": _v(0.0, -1.8), "yaw": 0.0, "s": 1.0, "col": true})
	out.append({"t": "lore", "c": "rune", "p": _v(-1.9, -1.1)})
	return out


static func _l_stones(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n: int = [1, 2, 3, 3, 4][rng.randi() % 5]
	var lean := rng.randf_range(-0.25, 0.25)
	for i in n:
		var x := (float(i) - float(n - 1) * 0.5) * rng.randf_range(1.4, 2.1)
		out.append({"t": "slab", "p": _v(x, rng.randf_range(-0.4, 0.4)), "h": rng.randf_range(1.7, 3.1) * (1.15 if i == n / 2 else 1.0),
			"w": rng.randf_range(0.7, 1.05), "yaw": rng.randf_range(-0.3, 0.3), "lean": Vector2(rng.randf_range(-0.1, 0.1), lean + rng.randf_range(-0.06, 0.06))})
	if rng.randf() < 0.4:
		out.append({"t": "lying", "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(1.2, 2.2)), "len": rng.randf_range(1.8, 2.6), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(2, 4):
		out.append({"t": "boulder", "p": _v(rng.randf_range(-2.4, 2.4), rng.randf_range(-1.6, 1.6)), "s": Vector3(0.5, 0.35, 0.45) * rng.randf_range(0.7, 1.4)})
	out.append({"t": "lore", "c": "rune", "p": _v(-2.8 if rng.randf() < 0.5 else 2.8, -1.3)})
	return out


static func _l_circle(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := rng.randi_range(7, 11)
	var r := rng.randf_range(4.6, 5.8)
	var fallen := [rng.randi() % n, rng.randi() % n]
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.08, 0.08)
		var q := _v(cos(a) * r, sin(a) * r)
		if i in fallen:
			out.append({"t": "lying", "p": q * 1.12, "len": rng.randf_range(1.6, 2.3), "yaw": -a + rng.randf_range(-0.4, 0.4)})
			continue
		out.append({"t": "slab", "p": q, "h": rng.randf_range(1.3, 2.3) * (1.25 if i % 4 == 0 else 1.0), "w": rng.randf_range(0.6, 0.9),
			"yaw": PI * 0.5 - a, "lean": Vector2(rng.randf_range(-0.08, 0.1), rng.randf_range(-0.07, 0.07))})
	out.append({"t": "altar", "p": _v(0.0, 0.0), "yaw": rng.randf() * TAU})
	out.append({"t": "cairn", "p": _v(0.9, 0.4), "h": 0.4})
	out.append({"t": "spot", "p": _v(0.0, -1.0)})
	out.append({"t": "lore", "c": "rune", "p": _v(-1.2, 0.6)})
	return out


static func _l_cairns(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "bigcairn", "p": _v(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.6)), "h": rng.randf_range(1.3, 2.0)})
	for i in rng.randi_range(4, 10):
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.6, 4.0)
		if rng.randf() < 0.3:
			out.append({"t": "bigcairn", "p": _v(cos(a) * d, sin(a) * d), "h": rng.randf_range(0.7, 1.1)})
		else:
			out.append({"t": "cairn", "p": _v(cos(a) * d, sin(a) * d), "h": rng.randf_range(0.3, 0.75)})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.2, 1.2), -1.4)})
	return out


static func _l_cart(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var along := PI * 0.5 + rng.randf_range(-0.5, 0.5)          # the cart lies along the way, run off its edge
	if rng.randf() < 0.4:
		out.append({"t": "glb", "f": "handcart.glb", "p": _v(0.0, 0.3), "yaw": along, "s": 1.0, "col": true, "tilt": rng.randf_range(-0.12, 0.12)})
	else:
		out.append({"t": "cart", "p": _v(0.0, 0.3), "yaw": along, "broken": rng.randf() < 0.75, "load": ["", "hay", "sacks"][rng.randi() % 3]})
	var spill := ["sack.glb", "sack_open.glb", "crate.glb", "crate_broken.glb", "barrel.glb", "barrel_tipped.glb"]
	for i in rng.randi_range(2, 4):
		out.append({"t": "glb", "f": spill[rng.randi() % spill.size()], "p": _v(rng.randf_range(-2.2, 2.2), rng.randf_range(0.8, 2.4)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	if rng.randf() < 0.3:
		out.append({"t": "clutter", "k": "skull", "p": _v(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.8, 0.6)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.0, 1.0), 1.6)})
	out.append({"t": "lore", "c": "page", "p": _v(0.0, 0.3)})
	return out


static func _l_camp(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "firering", "p": _v(0.0, 0.0)})
	out.append({"t": "clutter", "k": "log", "p": _v(rng.randf_range(-0.3, 0.3), -1.5), "yaw": rng.randf_range(-0.3, 0.3), "s": 1.0})
	out.append({"t": "clutter", "k": "log", "p": _v(1.5, rng.randf_range(-0.3, 0.3)), "yaw": PI * 0.5 + rng.randf_range(-0.3, 0.3), "s": 1.0})
	# a lean-to of poles and planks behind the fire, its back to the weather
	var lx := rng.randf_range(-0.8, 0.8)
	out.append({"t": "leanto", "p": _v(lx, 2.6), "yaw": rng.randf_range(-0.25, 0.25)})
	out.append({"t": "bedroll", "p": _v(lx + rng.randf_range(-0.4, 0.4), 2.2), "yaw": PI * 0.5 + rng.randf_range(-0.2, 0.2)})
	var stores := ["sack.glb", "sack_open.glb", "crate.glb", "barrel.glb", "firewood.glb"]
	for i in rng.randi_range(2, 4):
		var a := rng.randf_range(-2.6, 0.4)
		out.append({"t": "glb", "f": stores[rng.randi() % stores.size()], "p": _v(cos(a) * 2.6, sin(a) * 2.6 + 0.4), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	out.append({"t": "clutter", "k": "bucket", "p": _v(-1.2, 0.9), "yaw": 0.0, "s": 1.0})
	out.append({"t": "spot", "p": _v(lx - 1.2, 2.5)})
	out.append({"t": "lore", "c": "page", "p": _v(lx + 2.1, 0.9)})          # (out from under the lean-to's roof)
	return out


static func _l_well(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var f := "works_well.glb" if rng.randf() < 0.6 else "hw_well.glb"
	out.append({"t": "glb", "f": f, "p": _v(0.0, 0.4), "yaw": rng.randf_range(-0.3, 0.3), "s": 0.85 if f == "hw_well.glb" else 1.0, "col": true})
	out.append({"t": "glb", "f": "trough.glb", "p": _v(rng.randf_range(1.6, 2.2), -0.8), "yaw": rng.randf_range(-0.4, 0.4), "s": 1.0, "col": true})
	out.append({"t": "clutter", "k": "bucket", "p": _v(-1.4, -0.6), "yaw": rng.randf() * TAU, "s": 1.0})
	for i in 3:
		out.append({"t": "clutter", "k": "flag2" if i % 2 == 0 else "flag", "p": _v(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.8, -1.1)), "yaw": rng.randf() * TAU, "s": 1.0})
	return out


static func _l_graves(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := rng.randi_range(3, 7)
	var rank := rng.randf() < 0.6               # in a rank (the Order's way) or scattered as they fell
	for i in n:
		var q := _v((float(i % 4) - 1.5) * 1.3 + rng.randf_range(-0.15, 0.15), 1.0 - float(i >> 2) * 2.2 + rng.randf_range(-0.2, 0.2)) if rank \
			else _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.4, 2.4))
		out.append({"t": "headstone", "p": q, "style": rng.randi() % 5, "h": rng.randf_range(0.75, 1.1),
			"tilt": Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.1, 0.1)), "mound": rng.randf() < 0.35})
	if rng.randf() < 0.55:
		out.append({"t": "fence", "a": _v(-3.6, -2.8), "b": _v(3.6, -2.8), "gaps": 0.4})
	out.append({"t": "lore", "c": "grave", "p": _v(rng.randf_range(-2.0, 2.0), -1.6)})
	return out


static func _l_woodpile(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in rng.randi_range(2, 3):
		out.append({"t": "glb", "f": "firewood.glb", "p": _v(-1.6 + float(i) * 1.25, 1.0 + rng.randf_range(-0.2, 0.2)), "yaw": rng.randf_range(-0.2, 0.2), "s": rng.randf_range(0.95, 1.2), "col": true})
	out.append({"t": "block", "p": _v(rng.randf_range(-0.6, 0.6), -0.8), "s": Vector3(0.6, 0.45, 0.6), "k": "lore_beam", "yaw": rng.randf() * TAU})
	out.append({"t": "axe", "p": _v(0.0, -0.8)})
	for i in rng.randi_range(2, 4):
		out.append({"t": "clutter", "k": "log", "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.4, -1.6)), "yaw": rng.randf_range(-0.4, 0.4), "s": 1.0})
	out.append({"t": "clutter", "k": "kindling", "p": _v(rng.randf_range(-0.8, 0.8), -1.4), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "sawhorse", "p": _v(rng.randf_range(1.4, 2.0), -0.6), "yaw": rng.randf() * TAU})
	out.append({"t": "spot", "p": _v(-1.9, -0.6)})
	return out


static func _l_statue(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if rng.randf() < 0.55:
		out.append({"t": "saint", "p": _v(0.0, 0.4), "yaw": 0.0, "v": rng.randi_range(1, 3), "plinth": rng.randf_range(0.6, 0.95), "s": rng.randf_range(0.95, 1.25)})
	else:
		out.append({"t": "block", "p": _v(0.9, 0.6), "s": Vector3(1.0, 0.6, 0.9), "k": "lore_tstone", "yaw": rng.randf_range(-0.3, 0.3)})
		out.append({"t": "fallen", "p": _v(-0.6, -0.2), "yaw": rng.randf() * TAU, "v": rng.randi_range(0, 3)})
	out.append({"t": "rubble", "p": _v(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 1.0)), "r": 1.4, "n": 6})
	out.append({"t": "lore", "c": "tablet", "p": _v(1.8, -0.6)})
	return out


static func _l_blocks(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in rng.randi_range(4, 8):
		var q := _v(rng.randf_range(-3.6, 3.6), rng.randf_range(-2.6, 2.6))
		var sz := Vector3(rng.randf_range(0.9, 1.6), rng.randf_range(0.5, 0.85), rng.randf_range(0.6, 1.0))
		out.append({"t": "block", "p": q, "s": sz, "k": "lore_tstone", "yaw": rng.randf_range(-0.25, 0.25) + (PI * 0.5 if rng.randf() < 0.3 else 0.0)})
		if rng.randf() < 0.3:
			out.append({"t": "block", "p": q, "s": sz * Vector3(0.8, 0.9, 0.8), "k": "lore_tstone", "yaw": rng.randf_range(-0.3, 0.3), "on": sz.y})
	for i in rng.randi_range(1, 3):
		out.append({"t": "drum", "p": _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0)), "r": rng.randf_range(0.45, 0.6), "h": rng.randf_range(0.5, 0.8), "lie": rng.randf() < 0.5, "yaw": rng.randf() * TAU})
	out.append({"t": "glb", "f": "works_quarry.glb", "p": _v(rng.randf_range(-2.0, 2.0), rng.randf_range(2.6, 3.2)), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.0, 1.0), -2.9)})
	return out


static func _l_lookout(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var h := rng.randf_range(3.2, 4.0)
	out.append({"t": "tower", "p": _v(0.0, 0.6), "h": h, "w": 3.2})
	# a stair of fallen blocks up its front and round to the top (rises under the wanderer's step, 0.45 m)
	var steps: Array = []
	var n := int(ceil(h / 0.36))
	for i in n:
		var t := float(i) / float(n - 1)
		var a := lerpf(-PI * 0.95, -PI * 0.25, t)
		steps.append([Vector2(cos(a) * 2.45, 0.6 + sin(a) * 2.45), (float(i) + 1.0) * h / float(n)])
	out.append({"t": "steps", "list": steps})
	# what fell off it: blocks tumbled down the back and sides
	for i in 3:
		var a2 := rng.randf_range(0.1, PI - 0.1) + float(i) * 0.6
		out.append({"t": "rubble", "p": _v(cos(a2) * 3.0, 0.6 + sin(a2) * 3.0), "r": 1.4, "n": 6, "key": "lore_moss"})
	out.append({"t": "block", "p": _v(rng.randf_range(2.6, 3.4), rng.randf_range(1.4, 2.6)), "s": Vector3(0.9, 0.5, 0.6), "k": "lore_moss", "yaw": rng.randf() * TAU})
	out.append({"t": "spot_top", "p": _v(0.4, 0.9)})
	out.append({"t": "perch", "p": _v(0.0, 0.6)})
	return out


static func _l_battle(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# a broken line of sharpened stakes across the ground they held, leaning out at the enemy
	var sa := rng.randf() * TAU
	var sd := Vector2(cos(sa), sin(sa))
	var so := Vector2(-sd.y, sd.x) * rng.randf_range(1.5, 2.5)
	for i in rng.randi_range(5, 8):
		if rng.randf() < 0.2:
			continue
		var q := so + sd * (float(i) - 3.5) * 0.75 + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
		out.append({"t": "stake", "p": q, "yaw": atan2(so.x, so.y) + rng.randf_range(-0.15, 0.15), "tilt": rng.randf_range(0.25, 0.6) * (1.0 if rng.randf() < 0.85 else 2.2), "len": rng.randf_range(1.6, 2.3)})
	out.append({"t": "wheel", "p": _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0)), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(1, 3):
		out.append({"t": "helm", "p": _v(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.4, 2.4)), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(5, 9):
		out.append({"t": "spear", "p": _v(rng.randf_range(-4.0, 4.0), rng.randf_range(-3.0, 3.0)), "yaw": rng.randf() * TAU, "tilt": rng.randf_range(0.1, 0.5), "len": rng.randf_range(1.6, 2.4)})
	for i in rng.randi_range(2, 4):
		out.append({"t": "shield", "p": _v(rng.randf_range(-3.5, 3.5), rng.randf_range(-2.6, 2.6)), "yaw": rng.randf() * TAU})
	for i in rng.randi_range(2, 4):
		out.append({"t": "clutter", "k": ["bone", "rib", "skull"][rng.randi() % 3], "p": _v(rng.randf_range(-3.6, 3.6), rng.randf_range(-2.6, 2.6)), "yaw": rng.randf() * TAU, "s": 1.0})
	out.append({"t": "banner", "p": _v(rng.randf_range(-1.0, 1.0), 2.4), "h": rng.randf_range(2.6, 3.4)})
	if rng.randf() < 0.6:
		out.append({"t": "cairn", "p": _v(rng.randf_range(-2.0, 2.0), -2.2), "h": 0.55})
	out.append({"t": "spot", "p": _v(rng.randf_range(-2.4, 2.4), 1.6)})
	out.append({"t": "lore", "c": "grave", "p": _v(1.4, -1.4)})
	return out


static func _l_debris(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in rng.randi_range(3, 6):
		out.append({"t": "shard", "p": _v(rng.randf_range(-3.6, 3.6), rng.randf_range(-3.0, 3.0)), "yaw": rng.randf() * TAU, "s": rng.randf_range(0.7, 1.6)})
	for i in rng.randi_range(3, 5):
		out.append({"t": "boulder", "p": _v(rng.randf_range(-4.0, 4.0), rng.randf_range(-3.0, 3.0)), "s": Vector3(0.9, 0.55, 0.8) * rng.randf_range(0.6, 1.5), "style": "ash"})
	out.append({"t": "rubble", "p": _v(0.0, 0.0), "r": 3.0, "n": 10, "key": "lore_char"})
	out.append({"t": "spot", "p": _v(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.0))})
	return out


static func _l_barrow(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var r := rng.randf_range(3.0, 3.9)
	out.append({"t": "mound", "p": _v(0.0, 0.2), "s": Vector3(r, rng.randf_range(1.1, 1.7), r * rng.randf_range(0.85, 1.05))})
	var n := 12
	for i in n:
		if rng.randf() < 0.25:
			continue
		var a := TAU * float(i) / float(n)
		out.append({"t": "boulder", "p": _v(cos(a) * (r + 0.4), 0.2 + sin(a) * (r + 0.4)), "s": Vector3(0.5, 0.42, 0.45) * rng.randf_range(0.8, 1.2), "style": "mossy"})
	if rng.randf() < 0.55:
		# its door: two jambs and a lintel at the front, a dark mouth behind
		out.append({"t": "door", "p": _v(0.0, -r + 0.3)})
	else:
		out.append({"t": "slab", "p": _v(0.0, -r - 0.6), "h": rng.randf_range(1.4, 2.0), "w": 0.8, "yaw": 0.0, "lean": Vector2(rng.randf_range(-0.1, 0.1), 0.0)})
	out.append({"t": "spot", "p": _v(1.6, -r - 0.8)})
	out.append({"t": "lore", "c": "rune", "p": _v(-1.4, -r - 0.9)})
	return out


static func _l_charcoal(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "clamp", "p": _v(0.0, 0.8), "r": rng.randf_range(1.6, 2.1)})
	for i in rng.randi_range(2, 3):
		out.append({"t": "glb", "f": "firewood.glb", "p": _v(-2.8 + float(i) * 1.3, -1.6), "yaw": rng.randf_range(-0.3, 0.3), "s": 1.1, "col": true})
	out.append({"t": "rake", "p": _v(2.4, -0.4), "yaw": rng.randf() * TAU})
	out.append({"t": "clutter", "k": "kindling", "p": _v(2.0, 1.6), "yaw": rng.randf() * TAU, "s": 1.2})
	out.append({"t": "glb", "f": "sack_open.glb", "p": _v(-2.4, 0.4), "yaw": rng.randf() * TAU, "s": 1.0, "col": true})
	out.append({"t": "spot", "p": _v(1.4, -1.8)})
	return out


static func _l_farm(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# a field's corner: fence or wall along two sides, a gate gap, the season's last rick and the man who kept the crows off
	var w := rng.randf_range(4.5, 5.8)
	if rng.randf() < 0.5:
		out.append({"t": "fence", "a": _v(-w, -2.6), "b": _v(-0.9, -2.6), "gaps": 0.2})
		out.append({"t": "fence", "a": _v(0.9, -2.6), "b": _v(w, -2.6), "gaps": 0.25})
		out.append({"t": "fence", "a": _v(w, -2.6), "b": _v(w, 3.4), "gaps": 0.3})
	else:
		out.append({"t": "wall", "a": _v(-w, -2.6), "b": _v(-0.9, -2.6), "h": 0.9, "ruin": 0.4})
		out.append({"t": "wall", "a": _v(0.9, -2.6), "b": _v(w, -2.6), "h": 0.9, "ruin": 0.45})
		out.append({"t": "wall", "a": _v(w, -2.6), "b": _v(w, 3.4), "h": 0.8, "ruin": 0.5})
	out.append({"t": "rick", "p": _v(rng.randf_range(-2.4, 0.0), rng.randf_range(0.6, 2.0)), "s": rng.randf_range(0.85, 1.2)})
	if rng.randf() < 0.7:
		out.append({"t": "scarecrow", "p": _v(rng.randf_range(1.0, 3.0), rng.randf_range(0.0, 2.4)), "yaw": rng.randf() * TAU})
	if rng.randf() < 0.5:
		out.append({"t": "glb", "f": "barrel.glb", "p": _v(w - 0.7, -1.9), "yaw": 0.0, "s": 1.0, "col": true})
	out.append({"t": "plough", "p": _v(rng.randf_range(-3.6, -2.4), rng.randf_range(-1.4, 0.0)), "yaw": rng.randf() * TAU})
	return out


static func _l_milestone(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "lore", "c": "waystone", "p": _v(0.0, 0.0)})
	if rng.randf() < 0.3:
		out.append({"t": "cairn", "p": _v(0.75, 0.5), "h": 0.3})
	return out


static func _l_jetty(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# the jetty runs out from the shore (local +z is the land, -z the water)
	var length := rng.randf_range(5.5, 8.0)
	out.append({"t": "jetty", "p": _v(0.0, 1.5), "len": length, "w": rng.randf_range(1.3, 1.7)})
	out.append({"t": "trap", "p": _v(rng.randf_range(1.2, 1.8), 1.5 - length * 0.7), "yaw": rng.randf() * TAU})
	if rng.randf() < 0.6:
		out.append({"t": "trap", "p": _v(rng.randf_range(-1.8, -1.2), 1.5 - length * 0.45), "yaw": rng.randf() * TAU})
	out.append({"t": "boat", "p": _v(rng.randf_range(1.8, 2.6), rng.randf_range(1.4, 2.4)), "yaw": rng.randf_range(-0.6, 0.6) + PI * 0.5})
	out.append({"t": "glb", "f": "crate.glb", "p": _v(-0.9, 2.4), "yaw": rng.randf() * TAU, "s": 0.9, "col": true})
	out.append({"t": "spot", "p": _v(0.0, 1.5 - length + 0.8)})
	return out


static func _l_bones(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	# something very big died here: its ribs stand out of the turf like the frame of a boat
	var n := rng.randi_range(5, 8)
	var yaw := rng.randf() * TAU
	for i in n:
		var t := (float(i) - float(n - 1) * 0.5) * 0.85
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.18:
				continue
			out.append({"t": "rib", "p": Vector2(t, 0.0).rotated(yaw) + Vector2(0.0, s * 0.5).rotated(yaw), "side": s, "yaw": yaw, "s": rng.randf_range(3.2, 4.2) * (1.0 - absf(t) * 0.08)})
	out.append({"t": "bigskull", "p": Vector2(float(n) * 0.5, 0.0).rotated(yaw) + Vector2(0.9, 0.0).rotated(yaw), "yaw": yaw + rng.randf_range(-0.5, 0.5)})
	return out


## Modelled field wall (wall_low.glb) in a broken line: three or four lengths, some leaning, one tumbled.
static func _l_lowwall(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := rng.randi_range(3, 4)
	var x := -float(n - 1) * 1.5
	var z := 0.0
	for i in n:
		if rng.randf() < 0.15 and i > 0:
			x += 3.0
			continue                                     # a length gone
		out.append({"t": "glb", "f": "wall_low.glb", "p": _v(x, z), "yaw": rng.randf_range(-0.15, 0.15), "s": rng.randf_range(0.75, 1.0), "col": true, "tilt": rng.randf_range(-0.16, 0.16) if rng.randf() < 0.5 else 0.0})
		x += 3.0
		z += rng.randf_range(-0.5, 0.5)
	if rng.randf() < 0.6:
		out.append({"t": "glb", "f": "wall_pier.glb", "p": _v(-float(n - 1) * 1.5 - 1.8, 0.0), "yaw": 0.0, "s": rng.randf_range(0.8, 1.0), "col": true, "tilt": rng.randf_range(-0.08, 0.08)})
	out.append({"t": "rubble", "p": _v(x - 1.5, z + 0.8), "r": 1.3, "n": 6})
	return out


## A boundary marker fallen over beside a lone grave.
static func _l_marker(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "glb", "f": "ruin_marker.glb", "p": _v(0.0, 0.0), "yaw": rng.randf() * TAU, "s": 1.0, "col": true, "tilt": rng.randf_range(-0.12, 0.12)})
	out.append({"t": "glb", "f": "lore_headstone_broken.glb", "p": _v(1.8, 1.2), "yaw": rng.randf_range(-0.6, 0.6), "s": 1.0, "col": false, "tilt": rng.randf_range(-0.09, 0.09)})
	if rng.randf() < 0.5:
		out.append({"t": "cairn", "p": _v(-1.0, 0.9), "h": rng.randf_range(0.3, 0.5)})
	return out


## An Order stele, weathered, a tablet leaning against its foot.
static func _l_stele(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "glb", "f": "lore_stele.glb", "p": _v(0.0, 0.0), "yaw": rng.randf_range(-0.3, 0.3), "s": rng.randf_range(0.85, 1.05), "col": true, "tilt": rng.randf_range(-0.1, 0.1)})
	out.append({"t": "glb", "f": "lore_tablet_leaning.glb", "p": _v(-1.6, 0.8), "yaw": rng.randf_range(0.3, 1.1), "s": 1.0, "col": false})
	out.append({"t": "rubble", "p": _v(1.0, 0.6), "r": 0.9, "n": 4})
	return out


## The pier of a wall nobody remembers, a length of the wall still leaning on it.
static func _l_pier(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "glb", "f": "wall_pier.glb", "p": _v(0.0, 0.0), "yaw": rng.randf() * 0.4, "s": rng.randf_range(0.9, 1.15), "col": true, "tilt": rng.randf_range(-0.09, 0.09)})
	out.append({"t": "glb", "f": "wall_low.glb", "p": _v(2.4, 0.2), "yaw": rng.randf_range(-0.2, 0.2), "s": 0.7, "col": true, "tilt": rng.randf_range(-0.21, 0.21)})
	out.append({"t": "rubble", "p": _v(-1.2, 0.8), "r": 1.2, "n": 6})
	return out


## A roofless wayside shrine of the Order (ruin_shrine.glb), rubble round its feet and a carving by its door.
static func _l_ruinshrine(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append({"t": "glb", "f": "ruin_shrine.glb", "p": _v(0.0, 0.4), "yaw": rng.randf_range(-0.2, 0.2), "s": 1.0, "col": true})
	out.append({"t": "rubble", "p": _v(rng.randf_range(-2.6, 2.6), rng.randf_range(1.0, 2.4)), "r": 1.4, "n": 7})
	out.append({"t": "lore", "c": "rune", "p": _v(-2.6, -1.6)})
	return out


# --- footprint ----------------------------------------------------------------------------------

## The solid pieces' ground as world rects (the sites the planner registers): walls along their run in squares,
## props and stones by their size. `xf` maps the place's local xz (as x, z) to the world.
static func footprints(geo: Array, xf: Transform3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for e: Dictionary in geo:
		match String(e.t):
			"wall":
				var a := _w(xf, e.a)
				var b := _w(xf, e.b)
				var n := maxi(1, ceili(a.distance_to(b) / 1.3))
				for i in n:
					var c := a.lerp(b, (float(i) + 0.5) / float(n))
					out.append(Rect2(c - Vector2(0.65, 0.65), Vector2(1.3, 1.3)))
			"glb", "saint", "slab", "altar", "bigcairn", "block", "drum", "chimney", "cart", "leanto", "tower", "mound", "door", "clamp", "rick", "jetty", "fallen", "lying", \
					"headstone", "lore", "firering", "bedroll", "sawhorse", "shard", "rib", "bigskull", "scarecrow", "plough", "boat", "stake":
				if e.t == "lore" and e.c != "waystone":
					continue                     # a writing's carrier claims its ground when one is given (realm_wayside.gd _give_lore)
				var c2 := _w(xf, e.p)
				var r := _foot_r(e)
				out.append(Rect2(c2 - Vector2(r, r), Vector2(r, r) * 2.0))
			"steps":
				for st: Array in e.list:
					var c3 := _w(xf, st[0])
					out.append(Rect2(c3 - Vector2(0.55, 0.55), Vector2(1.1, 1.1)))
	return out


static func _foot_r(e: Dictionary) -> float:
	match String(e.t):
		"glb":
			var sz := PropModels.size_of(String(e.f)) * float(e.s)
			return maxf(sz.x, sz.z) * 0.5 + 0.2
		"saint": return 0.75 * float(e.s)
		"slab": return float(e.w) * 0.6
		"altar": return 1.0
		"bigcairn": return float(e.h) * 0.55
		"block": return maxf((e.s as Vector3).x, (e.s as Vector3).z) * 0.6
		"drum": return float(e.r) * (1.6 if bool(e.lie) else 1.1)
		"chimney": return 0.6
		"cart": return 1.8
		"leanto": return 1.6
		"tower": return float(e.w) * 0.55
		"mound": return (e.s as Vector3).x * 0.9
		"door": return 1.1
		"clamp": return float(e.r) + 0.3
		"rick": return 1.2 * float(e.s)
		"jetty": return 1.2
		"fallen": return 1.1
		"lying": return float(e.len) * 0.5
		"headstone": return 0.45
		"lore": return 0.75
		"firering": return 0.95
		"bedroll": return 0.7
		"sawhorse": return 0.9
		"shard": return 1.1 * float(e.s)
		"rib": return 0.45
		"bigskull": return 0.8
		"scarecrow": return 0.45
		"plough": return 1.0
		"boat": return 1.0
		"stake": return 0.3
	return 0.6


static func _w(xf: Transform3D, q: Vector2) -> Vector2:
	var p := xf * Vector3(q.x, 0.0, q.y)
	return Vector2(p.x, p.z)
