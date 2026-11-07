class_name Interiors
extends RefCounted
## The rooms you can walk into. A room is an oriented box (the taproom, a cottage, the inn); while the
## camera is inside one the weather's Environment offsets give way: the outdoor night's blue ambient and the
## ground haze are swapped for a warm low fill (Weather._apply_env reads `at()`), so a room with a fire in it
## reads as the warmest place there is (docs/PILLARS.md: warmth is earned) against the cold night outside.
## A cold room (`warm` false: a crypt, a cellar) keeps its cold ambient and only loses the haze.
## Also builds a room's lights, so every interior is lit the same way (a hearth glow, candle pools, a soft fill).

const FILL := Color(1.0, 0.62, 0.32)       ## the indoor ambient: a banked fire's bounce (about 2200 K)
const FIRE := Color(1.0, 0.5, 0.18)
const CANDLE := Color(1.0, 0.68, 0.34)

static var _rooms: Dictionary = {}          ## id -> {inv: Transform3D, half: Vector3, warm: bool}


static func clear() -> void:
	_rooms.clear()


## Register (or replace) a room: `centre` and `yaw` place it, `half` is its half extents (inside the walls).
static func add(id: String, centre: Vector3, yaw: float, half: Vector3, warm := true) -> void:
	_rooms[id] = {"inv": Transform3D(Basis(Vector3.UP, yaw), centre).affine_inverse(), "half": half, "warm": warm}


## 1.0 inside a warm room, 0.5 inside a cold one, else 0.0.
static func at(pos: Vector3) -> float:
	for id: String in _rooms:
		var r: Dictionary = _rooms[id]
		var l: Vector3 = (r.inv as Transform3D) * pos
		var h: Vector3 = r.half
		if absf(l.x) <= h.x and absf(l.y) <= h.y and absf(l.z) <= h.z:
			return 1.0 if bool(r.warm) else 0.5
	return 0.0


## In a warm room the Environment's ambient colour eases to the fire's bounce and its sky share to nothing (the
## blue sky otherwise washes every stone); outside it eases back. `keep` holds the Environment's own values.
static func warm_ambient(env: Environment, indoor: float, keep: Dictionary) -> void:
	if keep.is_empty():
		keep["col"] = env.ambient_light_color
		keep["sky"] = env.ambient_light_sky_contribution
	var col: Color = keep.col
	if indoor == 0.0 and env.ambient_light_color.is_equal_approx(col):
		return
	env.ambient_light_color = col.lerp(FILL, indoor)
	env.ambient_light_sky_contribution = lerpf(float(keep.sky), 0.0, indoor)


## A warm light that flickers. `host` owns it; `shadow` gives it a soft shadow (keep these to a few).
static func light(host: Node3D, n: String, at_world: Vector3, col: Color, e: float, r: float, shadow := false, flick := 0.08) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.light_color = col
	l.omni_range = r
	l.omni_attenuation = 1.5
	l.light_energy = e
	l.light_specular = 0.45
	l.shadow_enabled = false
	l.shadow_blur = 1.6
	l.set_meta(&"light_class", &"lamp")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.5})
	host.add_child(l)
	l.global_position = at_world
	LightPolicy.apply_fade(l)
	l.light_volumetric_fog_energy = 0.4
	l.shadow_enabled = shadow and Settings.shadow_quality > 0
	if shadow:
		l.distance_fade_shadow = 14.0
	if flick > 0.0:
		var f := Flicker.new()
		f.light = l
		f.base = e
		f.amount = flick
		l.add_child(f)
	return l


## A room's warm fill: a long soft pool and, in a big room lit by its people, two more along its length.
static func room_lights(host: Node3D, id: String, centre: Vector3, yaw: float, half: Vector3, lit: bool) -> void:
	add(id, centre, yaw, half, true)
	var b := Basis(Vector3.UP, yaw)
	var r := maxf(half.x, half.z) * 1.7
	var up := Vector3(0, half.y * 0.45, 0)
	if lit:                                                  # a banked hearth on the back wall: embers the glow comes from
		var em := MeshInstance3D.new()
		em.name = id + "Embers"
		var bm := BoxMesh.new()
		bm.size = Vector3(minf(half.x * 0.5, 1.0), 0.32, 0.1)
		em.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.45, 0.14)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.4, 0.1)
		m.emission_energy_multiplier = 1.3
		em.material_override = m
		em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(em)
		em.global_transform = Transform3D(b, centre + b * Vector3(half.x * 0.5, -half.y + 0.3, -half.z + 0.06))
	light(host, id + "Glow", centre + up, FIRE.lerp(CANDLE, 0.4), 1.6 if lit else 0.55, r, false, 0.07)
	if lit and half.x > 3.0:
		light(host, id + "GlowB", centre + b * Vector3(half.x * 0.5, 0.0, 0.0) + up, CANDLE, 0.9, r * 0.8, false, 0.06)
		light(host, id + "GlowC", centre - b * Vector3(half.x * 0.5, 0.0, 0.0) + up, CANDLE, 0.9, r * 0.8, false, 0.06)


## Eases a light's energy about its authored value: the shimmer of a flame.
class Flicker extends Node:
	var light: OmniLight3D
	var base := 1.0
	var amount := 0.08
	var _t := randf() * 40.0

	func _process(delta: float) -> void:
		if light == null or not light.is_visible_in_tree():
			return
		_t += delta
		light.light_energy = base * (1.0 + amount * (sin(_t * 9.1) * 0.6 + sin(_t * 23.7 + 1.3) * 0.4) + amount * 0.5 * sin(_t * 3.3))
