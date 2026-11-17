extends Node
## LIVING WINDOWS: the village keeps hours. Every cottage with a window trail (Interiors.shaft "WindowTrail_n")
## has a bedtime of its own: lamps are lit at dusk one house after another, a few put out late in the night (the
## flame gutters three times, then goes), the warm panes dim with their light, and the far card (night registry,
## kind WINDOW) goes out with them, so a village thins to its last lit windows as the night wears on. At the late
## hours a dark house stirs when the wanderer walks by: a window lights as you pass and stays lit while you are near.
## It reads the night clock (Reg.clock) so it follows the Moon Course and the eclipse; no node per window, one pass
## four times a second over the houses (about forty).

const Reg := preload("res://core/world/night_life/night_registry.gd")

const TICK := 0.25
const STIR_RANGE := 9.0
const STIR_HOLD := 34.0

class House:
	var key := ""
	var host: Node3D
	var lights: Array[Light3D] = []
	var body: MeshInstance3D
	var mats: Array[StandardMaterial3D] = []
	var base: PackedFloat32Array = PackedFloat32Array()
	var open := 0.1                         ## clock time its lamp is lit
	var close := 2.0                        ## clock time it is put out (> 1: lit all night)
	var centre := Vector3.ZERO
	var lit := true
	var level := 1.0                        ## the pane's glow, eased
	var stirred := 0.0

var _houses: Array[House] = []
var _tick := 0.0
var _t := 0.0
var _waited := 0.0
var _built := false
static var _centres := PackedVector3Array()   ## each house's window centre (the folk's cats look for roofs above them)


func _process(delta: float) -> void:
	_t += delta
	if not _built:
		_waited += delta
		if _waited > 5.0:
			_waited = 0.0
			_build()
		return
	if not Reg.enabled:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	var dt := TICK - _tick
	_tick = TICK
	_step(dt)


func _build() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var lights := root.find_children("WindowTrail_*", "Light3D", true, false)
	if lights.is_empty():
		_built = _waited_out()
		return
	var by_host := {}
	for n: Node in lights:
		var h := n.get_parent() as Node3D
		if h == null:
			continue
		var id := h.get_instance_id()
		if not by_host.has(id):
			var hs := House.new()
			hs.host = h
			hs.key = "win_%d" % hash(h.get_path())
			by_host[id] = hs
		(by_host[id] as House).lights.append(n as Light3D)
	for hs: House in by_host.values():
		var sum := Vector3.ZERO
		for l: Light3D in hs.lights:
			sum += l.global_position
		hs.centre = sum / float(maxi(hs.lights.size(), 1))
		var hv := absi(hash(hs.key))
		hs.open = 0.02 + 0.2 * float(hv % 100) / 100.0
		var kv := float((hv >> 7) % 100) / 100.0
		# a third keep their lamp lit till the grey, the rest go out between 55 % and 95 % of the night
		hs.close = 2.0 if kv < 0.33 else 0.55 + 0.4 * (kv - 0.33) / 0.67
		var body := hs.host.get_node_or_null("LitBody") as MeshInstance3D
		if body != null and body.mesh != null:
			hs.body = body
			for s in body.mesh.get_surface_count():
				var m := body.get_active_material(s) as StandardMaterial3D
				if m != null and m.emission_enabled:
					var dup := m.duplicate() as StandardMaterial3D
					body.set_surface_override_material(s, dup)
					hs.mats.append(dup)
					hs.base.append(dup.emission_energy_multiplier)
		hs.lit = lamp_on(hs.open, hs.close, Reg.clock, 0.0)
		hs.level = 1.0 if hs.lit else 0.0
		for i in hs.mats.size():
			hs.mats[i].emission_energy_multiplier = hs.base[i] * lerpf(0.04, 1.0, hs.level)
		for l: Light3D in hs.lights:
			l.visible = hs.lit
		_houses.append(hs)
		_centres.append(hs.centre)
		var gy := hs.centre.y - 1.4
		Reg.put(hs.key, hs.centre, Reg.Kind.WINDOW, minf(0.45 + 0.12 * float(hs.lights.size()), 0.95), gy, false, hs.lit)
	_built = true


func _waited_out() -> bool:
	return _t > 60.0


## The houses' window centres, once the village is found (empty before).
static func centres() -> PackedVector3Array:
	return _centres


## Is the house's lamp lit at clock time `c`? (before it opens: dark; between open and close: lit, with the last
## stretch before the close a gutter of three flickers)
static func lamp_on(open: float, close: float, c: float, t: float) -> bool:
	if c < open or c >= close:
		return false
	var left := close - c
	if left < 0.012:
		return sin(t * 17.0) + sin(t * 29.0) > -0.2 and left > 0.003 * (1.0 + sin(t * 5.0))
	return true


func _step(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam != null else Vector3(1e6, 0, 1e6)
	var c := Reg.clock
	for hs: House in _houses:
		if not is_instance_valid(hs.host):
			continue
		var near := hs.centre.distance_to(cp)
		var want := lamp_on(hs.open, hs.close, c, _t)
		# late and dark: a house stirs when the wanderer passes, and keeps its lamp while he is near
		if not want and c > 0.7 and near < STIR_RANGE and (absi(hash(hs.key)) % 3) == 0:
			hs.stirred = STIR_HOLD
		if hs.stirred > 0.0:
			hs.stirred -= dt if near < 40.0 else dt * 3.0
			want = want or hs.stirred > 0.0
		if want != hs.lit or absf(hs.level - (1.0 if want else 0.0)) > 0.01:
			hs.lit = want
			hs.level = move_toward(hs.level, 1.0 if want else 0.0, dt * 0.8)
			for i in hs.mats.size():
				hs.mats[i].emission_energy_multiplier = hs.base[i] * lerpf(0.04, 1.0, hs.level)
		for l: Light3D in hs.lights:
			if is_instance_valid(l):
				l.visible = hs.lit and hs.level > 0.15
		Reg.set_on(hs.key, hs.lit and hs.level > 0.15)
