extends "res://zz/trailer_shots_act3c.gd"
## Act III shots (the realm widens): places, horses, the Marches, bells, escort and defend. PLACES is the data-driven
## pattern (a shot per entry, no per-shot method); write a bespoke shot as _s_<id>, _u_<id>(t), _e_<id>() instead.
## A place shot puts the wanderer on `stand` walking toward `look`; the lens trails them (trailer_cam.vista).

## id -> [stand xz, look xz, look height above ground, lens back, lens height, fov, lateral drift, rise, walk pace]
const PLACES := {
	"thornwood": [Vector2(-60, 20), Vector2(-110, -20), 6.0, 4.5, 2.2, 62.0, 1.2, 0.8, 0.5],
	"necropolis": [Vector2(-10, 108), Vector2(0, 147), 4.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"mere": [Vector2(103, 98), Vector2(84, 112), 1.5, 4.5, 2.0, 60.0, 1.5, 0.6, 0.4],
	"foundry": [Vector2(123, -76), Vector2(135, -105), 6.0, 4.5, 2.2, 60.0, 1.5, 0.8, 0.5],
	"orchard": [Vector2(-99, 104), Vector2(-128, 132), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"quarry": [Vector2(-120, -83), Vector2(-128, -104), 4.0, 4.5, 2.4, 60.0, 1.5, 0.8, 0.5],
	"moor": [Vector2(126, -8), Vector2(142, -24), 5.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"holds": [Vector2(-125, 15), Vector2(-139, 11), 2.5, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"crowns": [Vector2(0, 66), Vector2(0, -110), 30.0, 5.0, 2.4, 60.0, 1.5, 1.2, 0.6],
	"stillwater": [Vector2(220, 52), Vector2(242, 6), 14.0, 5.0, 2.2, 60.0, 1.5, 0.8, 0.5],
	"anchorholds": [Vector2(200, -62), Vector2(214, -132), 24.0, 8.0, 3.5, 62.0, 1.5, 1.0, 0.5],
	"hierarch": [Vector2(-190, -56), Vector2(-214, -104), 18.0, 8.0, 3.5, 62.0, 1.5, 1.0, 0.5],
	"siege": [Vector2(-216, 132), Vector2(-236, 170), 8.0, 5.0, 2.2, 60.0, 1.5, 0.8, 0.5],
	"saltmarket": [Vector2(200, 90), Vector2(214, 95), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"pans": [Vector2(200, 150), Vector2(232, 168), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"oak": [Vector2(-40, 186), Vector2(-70, 206), 20.0, 9.0, 4.5, 62.0, 1.5, 1.0, 0.4],
	"well": [Vector2(36, 196), Vector2(72, 204), -4.0, 7.0, 6.0, 62.0, 1.5, 1.0, 0.0],
	"weirford": [Vector2(-190, 66), Vector2(-226, 62), 5.0, 4.5, 2.2, 60.0, 1.5, 0.8, 0.5],
	"downs": [Vector2(-10, 190), Vector2(0, 196), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
}

## id -> [centre xz, radius 0, radius 1, angle 0, angle 1, height 0, height 1 (above ground), look up]: places the
## trailing lens would end up inside a statue, a cliff or a pool are shot as a slow orbit from open ground instead.
const ORBITS := {
	"hierarch": [Vector2(-214, -104), 80.0, 70.0, 0.9, 0.5, 40.0, 44.0, 10.0],
	"anchorholds": [Vector2(214, -132), 46.0, 40.0, -0.3, 0.2, 18.0, 22.0, 14.0],
	"well": [Vector2(72, 204), 34.0, 28.0, -1.9, -1.5, 12.0, 10.0, -8.0],
}


func handles(id: String) -> bool:
	return PLACES.has(id)


func _look(id: String) -> Vector3:
	var pl: Array = PLACES[id]
	var v: Vector2 = pl[1]
	return Vector3(v.x, d.gy(v.x, v.y) + float(pl[2]), v.y)


func _s_any(id: String) -> void:
	var pl: Array = PLACES[id]
	var st: Vector2 = pl[0]
	var look := _look(id)
	d.put_player(Vector3(st.x, 0.0, st.y), Cam.yaw_dir(look - Vector3(st.x, look.y, st.y)), -0.05)
	d.use_free_cam()
	d.cam.fov = float(pl[5])
	d.aim_at(look)
	d.drive(Cam.flat(look - d.pp()) * float(pl[8]))


func _u_any(tt: float, id: String) -> void:
	var pl: Array = PLACES[id]
	var k: float = d.sm(clampf(tt / float(d.SHOTS[d.si][1]), 0.0, 1.0))
	if ORBITS.has(id):
		var o: Array = ORBITS[id]
		var c2: Vector2 = o[0]
		cam.orbit(Vector3(c2.x, maxf(d.gy(c2.x, c2.y), d.gy(c2.x - float(o[1]), c2.y)), c2.y), k, float(o[1]), float(o[2]), float(o[3]), float(o[4]), float(o[5]), float(o[6]), float(o[7]))
		return
	cam.vista(_look(id), k, float(pl[3]), float(pl[4]), float(pl[6]), float(pl[7]))
	d.light_at(d.pp(), 3.0)
	for e in d.get_tree().get_nodes_in_group(Groups.ENEMY):          # a stray foe's floating health bar must not hang in a place shot
		(e as Node3D).visible = false
	# the wanderer halts a couple of metres short of anything solid (never walks into a wall, a tower foot or a rock)
	if not d.flags.has("pl_halt") and d._drive_to.length() > 0.1:
		var space: PhysicsDirectSpaceState3D = d.main.get_world_3d().direct_space_state
		var ball := SphereShape3D.new()
		ball.radius = 0.45
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = ball
		q.transform = Transform3D(Basis.IDENTITY, d.pp() + Vector3.UP * 1.0)
		q.motion = d._drive_to.normalized() * 3.0
		q.collision_mask = Layers.WORLD | Layers.PROPS
		q.exclude = [d.p.get_rid()]
		if space.cast_motion(q)[0] < 1.0:
			d.flags["pl_halt"] = true
			d.drive(Vector3.ZERO)


func _e_any(_id: String) -> void:
	d.drive(Vector3.ZERO)
	d.cam.fov = 62.0


# --- bespoke shots ------------------------------------------------------------------------------------------

var _lamp_node: Lamp


func _lamp(id: String) -> Lamp:
	for n in d.get_tree().get_nodes_in_group(Lamp.GROUP):
		var l := n as Lamp
		if l != null and l.lamp_id == id:
			return l
	return null


func _s_lamp_kindle() -> void:
	d.clear_spawned()
	_lamp_node = _lamp("wf_lantern_0")
	if _lamp_node == null:
		print("TRAILER no lamp wf_bank_e")
		return
	_lamp_node.douse()                                   # not yet lit: the wanderer lights it in the shot
	var at := _lamp_node.global_position
	wake_villagers(at, 40.0)
	var from := Vector3(at.x + 5.0, 0.0, at.z + 1.0)
	d.put_player(from, Cam.yaw_dir(at - from), -0.05)
	d.drive(Cam.flat(at - from) * 0.45)
	d.use_free_cam()
	d.cam.fov = 48.0


func _u_lamp_kindle(tt: float) -> void:
	if _lamp_node == null:
		return
	var at := _lamp_node.global_position
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	d.aim_at(at)
	two_shot(d.pp(), Vector3(at.x, d.pp().y, at.z), k, 5.0, 2.0, -1.0, 0.5, 1.7)
	d.light_at(d.pp(), 3.0)
	if Vector2(d.pp().x - at.x, d.pp().z - at.z).length() < 2.0:
		d.drive(Vector3.ZERO)
	if tt > 0.95 and d.once("lk_pose"):
		d.p._visual.cast_pose(&"reach")
	if tt > 1.1 and d.once("lk_light"):
		_lamp_node.interact(d.p)                         # the real kindling: flame, sparks, a chime, the ash


func _e_lamp_kindle() -> void:
	d.drive(Vector3.ZERO)
	d.cam.fov = 62.0


func _s_weirford_life() -> void:
	d.clear_spawned()
	var c: Vector3 = d.on_ground(Vector3(-196.0, 0.0, 73.0))
	var n := wake_villagers(c, 45.0)
	print("TRAILER weirford villagers woken: %d" % n)
	d.put_player(c + Vector3(5.0, 0.0, -6.0), Cam.yaw_dir(Vector3(-1.0, 0.0, 1.0)), -0.05)
	d.drive(Cam.flat(c - d.pp()) * 0.4)
	d.use_free_cam()
	d.cam.fov = 52.0


func _u_weirford_life(tt: float) -> void:
	var c: Vector3 = d.on_ground(Vector3(-196.0, 0.0, 73.0))
	var k: float = d.sm(clampf(tt / 2.4, 0.0, 1.0))
	cam.orbit(c, k, 12.0, 10.0, 1.3, 1.9, 3.4, 3.6, 1.2)
	d.light_at(c, 4.0)
	d.aim_at(c)
	if d.pp().distance_to(c) < 5.0:
		d.drive(Vector3.ZERO)


func _e_weirford_life() -> void:
	d.drive(Vector3.ZERO)
	d.cam.fov = 62.0


func _s_saltmarket_life() -> void:
	d.clear_spawned()
	var c: Vector3 = d.on_ground(Vector3(218.0, 0.0, 98.0))
	var n := wake_villagers(c, 45.0)
	print("TRAILER saltmarket villagers woken: %d" % n)
	d.put_player(c + Vector3(-6.0, 0.0, 4.0), Cam.yaw_dir(Vector3(1.0, 0.0, -0.5)), -0.05)
	d.drive(Cam.flat(c - d.pp()) * 0.4)
	d.use_free_cam()
	d.cam.fov = 52.0


func _u_saltmarket_life(tt: float) -> void:
	var c: Vector3 = d.on_ground(Vector3(218.0, 0.0, 98.0))
	var k: float = d.sm(clampf(tt / 2.2, 0.0, 1.0))
	cam.orbit(c, k, 10.0, 8.0, 3.6, 4.3, 2.4, 2.8, 1.2)
	d.light_at(c, 4.0)
	d.aim_at(c)
	if d.pp().distance_to(c) < 4.5:
		d.drive(Vector3.ZERO)


func _e_saltmarket_life() -> void:
	d.drive(Vector3.ZERO)
	d.cam.fov = 62.0


func _s_pans_wide() -> void:
	d.clear_spawned()
	var s: Dictionary = R37E.spots
	var wc: Vector3 = (s.saltworks as Dictionary).at
	d.put_player(Vector3(wc.x - 8.0, 0.0, wc.z - 6.0), Cam.yaw_dir(Vector3(1.0, 0.0, 1.0)), -0.05)
	d.drive(Cam.flat(Vector3(1.0, 0.0, 1.0)) * 0.45)
	d.use_free_cam()
	d.cam.fov = 58.0


func _u_pans_wide(tt: float) -> void:
	var s: Dictionary = R37E.spots
	var wc: Vector3 = (s.saltworks as Dictionary).at
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	# high on the works' edge, the white pans laid out below, the wanderer walking the rim
	var a: Vector3 = d.on_ground(Vector3(wc.x - 24.0, 0.0, wc.z - 20.0), 8.0)
	var b: Vector3 = d.on_ground(Vector3(wc.x - 14.0, 0.0, wc.z - 26.0), 9.0)
	cam.dolly(a, b, d.pp() + Vector3(8.0, -1.0, 10.0), k)
	d.light_at(d.pp(), 4.0)
	fill_follow(d.pp() + Vector3(2.0, 3.0, 2.0))


func _e_pans_wide() -> void:
	d.drive(Vector3.ZERO)
	clear_fills()
	d.cam.fov = 62.0


var _fl: OmniLight3D


func fill_follow(at: Vector3) -> void:
	if _fl == null or not is_instance_valid(_fl):
		_fl = fill(at, 3.0, 16.0, Color(1.0, 0.8, 0.55))
	_fl.global_position = at


var _spire_xf := Transform3D.IDENTITY
const SPIRE_WAY := [Vector3(1.95, 6.73, 1.4), Vector3(-1.4, 8.57, 1.95), Vector3(-1.95, 10.41, -1.4), Vector3(1.4, 12.26, -1.95), Vector3(1.95, 14.1, 1.4), Vector3(-1.4, 15.94, 1.95)]
var _spire_i := 0


func _s_lamp_spire() -> void:
	d.clear_spawned()
	var sp: Dictionary = R37E.spots.lamp_spire
	_spire_xf = Transform3D(Basis(Vector3.UP, float(sp.yaw)), sp.at)
	_spire_i = 0
	var st := _spire_xf * Vector3(1.95, 4.95, -1.4)
	d.put_player(st, Cam.yaw_dir(_spire_xf.basis * Vector3(0.0, 0.0, 1.0)), 0.05, false)
	(d.p.get_node("Visual") as Node3D).visible = false
	d.use_free_cam()
	d.cam.fov = 84.0


func _u_lamp_spire(tt: float) -> void:
	if _spire_i < SPIRE_WAY.size():
		var w: Vector3 = _spire_xf * (SPIRE_WAY[_spire_i] as Vector3)
		var to: Vector3 = w - d.pp()
		to.y = 0.0
		if to.length() < 0.9:
			_spire_i += 1
		else:
			d.aim_at(w)
			d.drive(to.normalized() * 0.8)
	var h: Vector3 = d.head()
	var f: Vector3 = d.fwd_of(float(d.p.get("_yaw")))
	d.hold_cam(h + f * 0.25, h + f * 8.0 + Vector3.UP * (1.6 + sin(tt * 9.0) * 0.06))
	d._snap = true
	d.light_at(h, 1.5)


func _e_lamp_spire() -> void:
	(d.p.get_node("Visual") as Node3D).visible = true
	d.drive(Vector3.ZERO)
	clear_fills()
	d.cam.fov = 62.0
