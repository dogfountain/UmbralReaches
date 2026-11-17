extends RefCounted
## The generator for the four door complexes (deep_halls.gd): a descending stair cut into a hillside and a string of rooms
## under it (WorldLanes.register_flight cuts the ground over the stair; the rooms lie below the natural ground, each with
## its own floor, walls and ceiling slab, so the hill above is never seen through). Local frame: `u` across, `v` along the
## way in (v = 0 where the stair arrives), `y` up from the floor. One OssKit per complex (a handful of meshes), with
## collision from the same faces; lights are unshadowed with distance fades; chests are loot_chest.gd.
## Build-time only; the complex is faded out beyond 200 m.
## No class_name: preload by path.

const WK := preload("res://core/world/realm/wonders/r39/wonder_kit.gd")
const Dress := preload("res://core/world/realm/wonders/r39/wonder_dress.gd")

const T := 0.8                          ## wall thickness
const DOOR_W := 2.6
const DOOR_H := 3.4

var k: WK
var o := Vector3.ZERO                   ## the stair's top: on the surface
var fwd := Vector3.FORWARD
var side := Vector3.RIGHT
var yf := 0.0
var run := 30.0
var wall := "stone_big"
var trim := "ruin_big"
var floor_key := "floor"
var ceil_key := "stone_big"
var light := Color(1.0, 0.66, 0.36)
var water_y := NAN
var count := {"rooms": 0}


func p(u: float, y: float, v: float) -> Vector3:
	var q := o + fwd * (run + v) + side * u
	return Vector3(q.x, yf + y, q.z)


func basis() -> Basis:
	return Basis(side, Vector3.UP, fwd)


## A box in the local frame: u0..u1, v0..v1, y0..y1.
func blk(key: String, u0: float, u1: float, v0: float, v1: float, y0: float, y1: float, shade := 1.0, solid := true) -> void:
	k.kit.box(key, p((u0 + u1) * 0.5, (y0 + y1) * 0.5, (v0 + v1) * 0.5), Vector3(u1 - u0, y1 - y0, v1 - v0), basis(), solid, shade)


## A wall running along u at depth v..v+T, with doorways centred on `gaps` (u values); lintels over them.
func wall_u(v: float, u0: float, u1: float, gaps: Array, h: float, key := "") -> void:
	var key2 := wall if key == "" else key
	var cuts: Array = [u0]
	for g: Variant in gaps:
		cuts.append(float(g) - DOOR_W * 0.5)
		cuts.append(float(g) + DOOR_W * 0.5)
	cuts.append(u1)
	for i in range(0, cuts.size(), 2):
		if float(cuts[i + 1]) - float(cuts[i]) > 0.05:
			blk(key2, float(cuts[i]), float(cuts[i + 1]), v, v + T, 0.0, h, 0.96)
	for g: Variant in gaps:
		blk(trim, float(g) - DOOR_W * 0.5 - 0.15, float(g) + DOOR_W * 0.5 + 0.15, v - 0.05, v + T + 0.05, DOOR_H, DOOR_H + 0.35, 0.86)
		blk(trim, float(g) - DOOR_W * 0.5 - 0.3, float(g) - DOOR_W * 0.5, v - 0.08, v + T + 0.08, 0.0, DOOR_H, 0.88)
		blk(trim, float(g) + DOOR_W * 0.5, float(g) + DOOR_W * 0.5 + 0.3, v - 0.08, v + T + 0.08, 0.0, DOOR_H, 0.88)
		if DOOR_H + 0.35 < h:
			blk(key2, float(g) - DOOR_W * 0.5 - 0.15, float(g) + DOOR_W * 0.5 + 0.15, v, v + T, DOOR_H + 0.35, h, 0.96)


## A wall running along v at u..u+T, doorways centred on `gaps` (v values).
func wall_v(u: float, v0: float, v1: float, gaps: Array, h: float, key := "") -> void:
	var key2 := wall if key == "" else key
	var cuts: Array = [v0]
	for g: Variant in gaps:
		cuts.append(float(g) - DOOR_W * 0.5)
		cuts.append(float(g) + DOOR_W * 0.5)
	cuts.append(v1)
	for i in range(0, cuts.size(), 2):
		if float(cuts[i + 1]) - float(cuts[i]) > 0.05:
			blk(key2, u, u + T, float(cuts[i]), float(cuts[i + 1]), 0.0, h, 0.96)
	for g: Variant in gaps:
		blk(trim, u - 0.05, u + T + 0.05, float(g) - DOOR_W * 0.5 - 0.15, float(g) + DOOR_W * 0.5 + 0.15, DOOR_H, DOOR_H + 0.35, 0.86)
		blk(trim, u - 0.08, u + T + 0.08, float(g) - DOOR_W * 0.5 - 0.3, float(g) - DOOR_W * 0.5, 0.0, DOOR_H, 0.88)
		blk(trim, u - 0.08, u + T + 0.08, float(g) + DOOR_W * 0.5, float(g) + DOOR_W * 0.5 + 0.3, 0.0, DOOR_H, 0.88)
		if DOOR_H + 0.35 < h:
			blk(key2, u, u + T, float(g) - DOOR_W * 0.5 - 0.15, float(g) + DOOR_W * 0.5 + 0.15, DOOR_H + 0.35, h, 0.96)


## A room u0..u1 x v0..v1 (interior), h high. `r` = {front, gaps_front, gaps_back, gaps_left, gaps_right, no_left, no_right, key}.
func room(u0: float, u1: float, v0: float, v1: float, h: float, r := {}) -> void:
	count.rooms += 1
	blk(floor_key, u0 - T, u1 + T, v0 - T, v1 + T, -0.6, 0.0, 0.9)
	blk(ceil_key, u0 - T, u1 + T, v0 - T, v1 + T, h, h + 0.9, 0.8)
	if bool(r.get("front", false)):
		wall_u(v0 - T, u0 - T, u1 + T, r.get("gaps_front", []), h)
	wall_u(v1, u0 - T, u1 + T, r.get("gaps_back", []), h)
	if not bool(r.get("no_left", false)):
		wall_v(u0 - T, v0, v1, r.get("gaps_left", []), h)
	if not bool(r.get("no_right", false)):
		wall_v(u1, v0, v1, r.get("gaps_right", []), h)


func lamp(u: float, y: float, v: float, e := 1.0, rng_m := 8.0) -> void:
	k.lamp(p(u, y, v), light, e, rng_m)


## A wall sconce: an iron bracket, a lit glass and a small light.
func sconce(u: float, y: float, v: float, face: float, e := 0.9) -> void:
	var q := p(u, y, v)
	k.kit.box("iron", q, Vector3(0.1, 0.1, 0.3), basis(), false, 0.6)
	k.kit.box("glow", q + side * face * 0.0 + Vector3.UP * 0.2, Vector3(0.2, 0.3, 0.2), basis(), false, 1.0)
	k.lamp(q + Vector3.UP * 0.3 + side * face * 0.4, light, e, 7.0)


func column(u: float, v: float, h: float, r := 0.5) -> void:
	k.tube(wall, p(u, 0.0, v), p(u, h, v), r, r * 0.9, 8, true, 0.95, Vector2(1.0, -1.0), false)
	k.kit.box(trim, p(u, 0.2, v), Vector3(r * 2.6, 0.4, r * 2.6), basis(), true, 0.85)
	k.kit.box(trim, p(u, h - 0.25, v), Vector3(r * 2.6, 0.5, r * 2.6), basis(), true, 0.85)


## A sarcophagus: a plinth, a chest-like body, a slightly slid lid.
func sarcophagus(u: float, v: float, yaw: float, slid := 0.0, key := "") -> void:
	var key2 := wall if key == "" else key
	var b := Basis(Vector3.UP, yaw) * basis()
	k.kit.box(key2, p(u, 0.2, v), Vector3(1.3, 0.4, 2.7), b, true, 0.86)
	k.kit.box(key2, p(u, 0.75, v), Vector3(1.1, 0.7, 2.4), b, true, 0.96)
	var lid := p(u, 1.2, v) + (b * Vector3(0.0, 0.0, 1.0)) * slid
	k.kit.box(trim, lid, Vector3(1.25, 0.22, 2.55), Basis(Vector3.UP, 0.0) * b * Basis(Vector3.UP, slid * 0.15), false, 0.9)


func water(u0: float, u1: float, v0: float, v1: float, y: float) -> void:
	water_y = yf + y
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(u1 - u0, v1 - v0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.13, 0.17, 0.72)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04
	m.metallic = 0.2
	m.emission_enabled = true
	m.emission = Color(0.02, 0.06, 0.08)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.host.add_child(mi)
	var c := p((u0 + u1) * 0.5, y, (v0 + v1) * 0.5)
	mi.global_transform = Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)), c)
	mi.visibility_range_end = 120.0


## The stair from the surface down to the floor, with walls up each side to the ground.
func stair(width := 3.2) -> void:
	var top := o
	var bot := p(0.0, 0.0, 0.0) - fwd * 0.0
	bot = Vector3(o.x + fwd.x * run, yf, o.z + fwd.z * run)
	var rise := top.y - yf
	var steps := maxi(8, int(ceilf(rise / 0.4)))
	k.kit.stairs(wall, top, bot, width, steps, yf - 0.6)
	var n := 10
	for j in n:
		var t0 := float(j) / float(n)
		var t1 := float(j + 1) / float(n)
		var v0 := run * t0
		var v1 := run * t1
		var mid := o + fwd * ((v0 + v1) * 0.5)
		var gy := WK.h(mid.x, mid.z)
		var ytop := maxf(gy, lerpf(top.y, yf, (t0 + t1) * 0.5)) + 0.9
		var ybot := lerpf(top.y, yf, t1) - 0.8
		for s: float in [-1.0, 1.0]:
			var c := mid + side * (s * (width * 0.5 + 0.5))
			k.kit.box(wall, Vector3(c.x, (ytop + ybot) * 0.5, c.z), Vector3(0.9, ytop - ybot, (v1 - v0) + 0.05), basis(), true, 0.9)
		if j % 3 == 1:
			var lp := mid + side * (width * 0.5 - 0.1) + Vector3.UP * (lerpf(top.y, yf, (t0 + t1) * 0.5) + 2.4)
			k.kit.box("iron", lp, Vector3(0.1, 0.1, 0.1), basis(), false, 0.6)
			k.lamp(lp, light, 0.8, 6.5)


## The gate on the surface: two pylons and a lintel across the stair's head, a fire on each, a banner.
func gate() -> void:
	var g := WK.h(o.x, o.z)
	for s: float in [-1.0, 1.0]:
		var c := o + side * (s * 3.0) + fwd * 0.6
		var gg := WK.h(c.x, c.z) - 0.6
		k.kit.box(wall, Vector3(c.x, (gg + g + 4.5) * 0.5, c.z), Vector3(1.6, g + 4.5 - gg, 1.6), basis(), true, 0.96)
		k.kit.box(trim, Vector3(c.x, g + 4.7, c.z), Vector3(2.1, 0.4, 2.1), basis(), true, 0.86)
		k.kit.box("iron", Vector3(c.x, g + 5.05, c.z), Vector3(0.9, 0.3, 0.9), basis(), false, 0.7)
		k.fire(Vector3(c.x, g + 5.25, c.z), 1.1, 2.4)
	k.kit.box(wall, o + fwd * 0.6 + Vector3.UP * 4.1, Vector3(6.4, 0.8, 1.2), basis(), true, 0.94)
	Dress.banner(k, o + fwd * -0.1 + Vector3.UP * 3.8 - side * 1.4, side, 2.8, 2.6, -fwd)
	Dress.rubble(k, o - fwd * 2.5 + side * 4.0, 3.0, 10, "ruin_big")
	Dress.rubble(k, o - fwd * 2.0 - side * 4.4, 3.0, 8, "ruin_big")
