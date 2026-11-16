class_name Interiors
extends RefCounted
## The rooms you can walk into. A room is an oriented box (the taproom, a cottage, the inn); while the
## camera is inside one the weather's Environment offsets give way: the outdoor night's blue ambient and the
## ground haze are swapped for a warm low fill (Weather._apply_env reads `at()`), so a room with a fire in it
## reads as the warmest place there is (docs/PILLARS.md: warmth is earned) against the cold night outside.
## A cold room (`warm` false: a crypt, a cellar) keeps its cold ambient and only loses the haze.
## Also builds a room's lights, so every interior is lit the same way (a hearth glow, candle pools, a soft fill).

const Hearth := preload("res://core/world/realm/cottage_hearth.gd")

const FILL := Color(0.80, 0.72, 0.64)       ## the indoor ambient: a soft warm-neutral bounce; the fire and lamps carry the colour (a hot fill turned plaster flat orange)
const FIRE := Color(1.0, 0.7, 0.4)
const CANDLE := Color(1.0, 0.8, 0.52)

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
	LightPolicy.apply_illumination(l)
	l.light_volumetric_fog_energy = 0.0       # a near-camera omni lights a froxel into a floating glow sphere
	l.shadow_enabled = shadow and Settings.shadow_quality > 0
	if shadow:
		l.distance_fade_shadow = 14.0
	if flick > 0.0:
		Flicker.on(l, l.light_energy, flick)
	return l


## A warm cone out of an opening: the trail on the ground and in the fog. `out_dir` points out of the
## room, slightly downward so the cone meets the yard. Not an omni (that reads as a floating sphere).
## Enshrouded read: soft ground pool + volumetric cone + bright-pane gobo (a dark-field gobo killed the trail).
static func shaft(host: Node3D, n: String, at_world: Vector3, out_dir: Vector3, col: Color, e: float, r: float, angle := 26.0, gobo: bool = true) -> SpotLight3D:
	if host == null:
		return null
	var dir := out_dir
	dir.y = minf(dir.y, -0.05)
	if dir.length() < 0.05:
		return null
	dir = dir.normalized()
	var l := SpotLight3D.new()
	l.name = n
	l.light_color = col
	l.light_energy = e
	l.spot_range = r
	l.spot_angle = angle
	l.spot_attenuation = 0.45
	l.spot_angle_attenuation = 0.75
	l.light_specular = 0.3
	l.light_size = 0.28
	l.shadow_enabled = false
	if gobo:
		l.light_projector = preload("res://art/textures/window_gobo.png")
	l.set_meta(&"light_class", &"shaft")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.0})
	host.add_child(l)
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	if host.is_inside_tree():
		l.global_position = at_world
		l.look_at(at_world + dir, up)
	else:
		l.set_meta(&"shaft_world", at_world)
		l.set_meta(&"shaft_dir", dir)
		l.position = Vector3.ZERO
		l.basis = Basis.looking_at(dir, up)
		l.ready.connect(_shaft_snap.bind(l), CONNECT_ONE_SHOT)
	LightPolicy.apply_fade(l)
	LightPolicy.apply_shadows(l)
	LightPolicy.apply_illumination(l)
	# (Luke, 9 Nov: no fog volume and no rim / spill omnis per pane: four lights and a fog box on every
	# window of the village cost the frame. The spot's own volumetric energy draws the cone.)
	Flicker.on(l, l.light_energy, 0.06)        # (the energy after apply_illumination)
	return l


## The window light for a lit pane inside a model (a glTF house whose `window_glass` surface is lit): every
## separate pane in surface `surf` (its triangles grouped within PANE_GAP) gets the same warm cone as the kit-built
## windows (shaft), pointing away from the building's middle. The one window light every builder uses: kit
## windows call shaft() per pane, model windows call this. Returns the panes lit.
const PANE_GAP := 0.9
static func pane_lights(mi: MeshInstance3D, surf: int, col: Color, e := 0.55, r := 8.0, angle := 14.0) -> int:
	if mi == null or mi.mesh == null or surf >= mi.mesh.get_surface_count() or not mi.is_inside_tree():
		return 0
	var a: Array = mi.mesh.surface_get_arrays(surf)
	if a.size() <= Mesh.ARRAY_INDEX or a[Mesh.ARRAY_VERTEX] == null:
		return 0                                 # no CPU copy of the surface (seen once under a loaded test run)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var tri := ix.size() / 3 if not ix.is_empty() else v.size() / 3
	var groups: Array = []                       # [sum of centres, count]
	for t in tri:
		var c := Vector3.ZERO
		for j in 3:
			c += v[ix[t * 3 + j] if not ix.is_empty() else t * 3 + j]
		c /= 3.0
		var found := false
		for g: Array in groups:
			if ((g[0] as Vector3) / float(g[1])).distance_to(c) < PANE_GAP:
				g[0] = (g[0] as Vector3) + c
				g[1] = int(g[1]) + 1
				found = true
				break
		if not found:
			groups.append([c, 1])
	var mid := mi.global_transform * mi.mesh.get_aabb().get_center()
	var n := 0
	for g: Array in groups:
		var at: Vector3 = mi.global_transform * ((g[0] as Vector3) / float(g[1]))
		var out := at - mid
		out.y = 0.0
		if out.length() < 0.1:
			continue
		var l := shaft(mi.get_parent() as Node3D, "%s_Pane%d" % [mi.name, n], at + out.normalized() * 0.05,
			out.normalized() + Vector3(0.0, -0.55, 0.0), col, e, r, angle)
		if l:
			n += 1
	return n


static func _shaft_snap(l: SpotLight3D) -> void:
	if l == null or not is_instance_valid(l) or not l.has_meta(&"shaft_world"):
		return
	var at_world: Vector3 = l.get_meta(&"shaft_world")
	var dir: Vector3 = l.get_meta(&"shaft_dir")
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	l.global_position = at_world
	l.look_at(at_world + dir, up)


## A room's warm fill: a long soft pool and, in a big room lit by its people, two more along its length.
static func room_lights(host: Node3D, id: String, centre: Vector3, yaw: float, half: Vector3, lit: bool, y_pad := 0.0) -> void:
	add(id, centre, yaw, half + Vector3(0, y_pad, 0), true)       # y_pad: a gabled roof and a floor that follows the ground
	var b := Basis(Vector3.UP, yaw)
	var r := maxf(half.x, half.z) * 1.7
	var up := Vector3(0, half.y * 0.45, 0)
	var lan := Hearth.lantern()                              # a hung lantern: the visible source of the room's light
	lan.name = id + "Lantern"
	host.add_child(lan)
	lan.global_position = centre + Vector3(0, half.y * 0.55, 0) - b * Vector3(half.x * 0.25, 0.0, 0.0)
	light(host, id + "Glow", lan.global_position - Vector3(0, 0.2, 0), FIRE.lerp(CANDLE, 0.4), 1.6 if lit else 0.55, r, false, 0.07)
	if lit and half.x > 3.0:
		light(host, id + "GlowB", centre + b * Vector3(half.x * 0.5, 0.0, 0.0) + up, CANDLE, 0.9, r * 0.8, false, 0.06)
		light(host, id + "GlowC", centre - b * Vector3(half.x * 0.5, 0.0, 0.0) + up, CANDLE, 0.9, r * 0.8, false, 0.06)


## Eases lights' energy about their authored values: the shimmer of a flame. One per night drives every
## flickering light (a node each, 74 of them, cost ~0.15 ms a frame); a light past its fade distance from
## the camera is not drawn, so it waits (its flame's clock with it) until the camera comes back in reach.
class Flicker extends Node:
	var lights: Array = []                    ## Light3D (untyped: a freed one is tested, not assigned)
	var base := PackedFloat64Array()
	var amount := PackedFloat64Array()
	var clock := PackedFloat64Array()
	var reach2 := PackedFloat64Array()        ## the light's fade end (+ a margin), squared; INF: never fades
	var _near := PackedInt32Array()           ## the lights within reach of the camera, looked for 4 times a second
	var _scan := 0.0

	## Flicker `l` about `b` by `amount`, driven by the one driver of the scene the light is in (the
	## top node under the root that holds it: it goes when that scene goes).
	static func on(l: Light3D, b: float, amt: float) -> void:
		if l.is_inside_tree():
			_register(l, b, amt)
		else:
			l.tree_entered.connect(_register.bind(l, b, amt), CONNECT_ONE_SHOT)

	static func _register(l: Light3D, b: float, amt: float) -> void:
		var root := l.get_tree().root
		var host: Node = l
		while host.get_parent() != null and host.get_parent() != root:
			host = host.get_parent()
		var d: Variant = host.get_meta(&"flicker_driver") if host.has_meta(&"flicker_driver") else null
		if not (d is Flicker and is_instance_valid(d)):
			d = Flicker.new()
			(d as Node).name = "InteriorFlicker"
			host.set_meta(&"flicker_driver", d)
			host.add_child.call_deferred(d)
		(d as Flicker).add(l, b, amt)

	func add(l: Light3D, b: float, amt: float) -> void:
		lights.append(l)
		base.append(b)
		amount.append(amt)
		clock.append(randf() * 40.0)
		var r := INF
		if l.distance_fade_enabled:
			r = l.distance_fade_begin + l.distance_fade_length + 4.0
			r *= r
		reach2.append(r)
		_scan = 0.0

	func _rescan() -> void:
		_near.clear()
		var cam := get_viewport().get_camera_3d()
		var cp := cam.global_position if cam != null else Vector3.ZERO
		var i := 0
		while i < lights.size():
			var l: Variant = lights[i]
			if not is_instance_valid(l):
				lights.remove_at(i)
				base.remove_at(i)
				amount.remove_at(i)
				clock.remove_at(i)
				reach2.remove_at(i)
				continue
			var lt := l as Light3D
			if cam == null or not lt.is_inside_tree() or cp.distance_squared_to(lt.global_position) <= reach2[i]:
				_near.append(i)
			i += 1

	func _process(delta: float) -> void:
		_scan -= delta
		if _scan <= 0.0:
			_scan = 0.25
			_rescan()
		for i in _near:
			var l: Variant = lights[i]
			if not is_instance_valid(l) or not (l as Light3D).is_visible_in_tree():
				continue
			var t := clock[i] + delta
			clock[i] = t
			var amt := amount[i]
			(l as Light3D).light_energy = base[i] * (1.0 + amt * (sin(t * 9.1) * 0.6 + sin(t * 23.7 + 1.3) * 0.4) + amt * 0.5 * sin(t * 3.3))
