extends "res://zz/trailer_shots_act3c.gd"
## Act III shots (the realm widens): places, horses, the Marches, bells, escort and defend. PLACES is the data-driven
## pattern (a shot per entry, no per-shot method); write a bespoke shot as _s_<id>, _u_<id>(t), _e_<id>() instead.
## A place shot puts the wanderer on `stand` walking toward `look`; the lens trails them (trailer_cam.vista).

## id -> [stand xz, look xz, look height above ground, lens back, lens height, fov, lateral drift, rise, walk pace, (max lens pitch up, radians)]
const PLACES := {
	"thornwood": [Vector2(-60, 20), Vector2(-110, -20), 6.0, 4.5, 2.2, 62.0, 1.2, 0.8, 0.5],
	"necropolis": [Vector2(-18, 112), Vector2(-8, 140), 4.0, 8.0, 6.0, 58.0, 1.5, 1.0, 0.5],
	"mere": [Vector2(103, 98), Vector2(84, 112), 1.5, 4.5, 2.0, 60.0, 1.5, 0.6, 0.4],
	"foundry": [Vector2(123, -76), Vector2(135, -105), 6.0, 4.5, 2.2, 60.0, 1.5, 0.8, 0.5],
	"orchard": [Vector2(-99, 104), Vector2(-128, 132), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"quarry": [Vector2(-120, -83), Vector2(-128, -104), 4.0, 4.5, 2.4, 60.0, 1.5, 0.8, 0.5],
	"moor": [Vector2(125, -15), Vector2(142, -24), 4.0, 8.0, 6.0, 58.0, 1.5, 1.0, 0.5],
	"holds": [Vector2(-133, 13), Vector2(-121, 11), 3.0, 4.2, 4.8, 58.0, 0.5, 1.0, 0.4],
	"crowns": [Vector2(0, 66), Vector2(0, -110), 30.0, 5.0, 2.4, 60.0, 1.5, 1.2, 0.6],
	"stillwater": [Vector2(232, 26), Vector2(241, 8), 24.0, 20.0, 12.0, 80.0, 0.5, 1.0, 0.0, 1.0],
	"anchorholds": [Vector2(204, -112), Vector2(215, -135), 5.0, 7.0, 6.0, 62.0, 1.0, 1.0, 0.3, 0.3],
	"hierarch": [Vector2(-190, -74), Vector2(-214, -103), 3.0, 14.0, 14.0, 62.0, 1.0, 1.0, 0.0, 0.3],
	"siege": [Vector2(-216, 132), Vector2(-236, 170), 8.0, 8.0, 6.0, 58.0, 1.5, 1.0, 0.5],
	"saltmarket": [Vector2(214, 105), Vector2(220, 90), 3.0, 6.0, 6.0, 58.0, 1.0, 1.0, 0.5],
	"pans": [Vector2(200, 150), Vector2(232, 168), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"oak": [Vector2(-40, 186), Vector2(-70, 206), 20.0, 9.0, 4.5, 62.0, 1.5, 1.0, 0.4],
	"well": [Vector2(48, 193), Vector2(70, 204), -1.0, 8.0, 7.0, 62.0, 1.0, 1.0, 0.25, 0.1],
	"weirford": [Vector2(-190, 66), Vector2(-226, 62), 5.0, 4.5, 2.2, 60.0, 1.5, 0.8, 0.5],
	"downs": [Vector2(-10, 190), Vector2(0, 196), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
}

## The places whose lens is picked by the clear-lens solver (vista_clear: never behind a wall, a roof, a sign or a headstone,
## the wanderer kept in the lower third); the rest trail the wanderer with the plain Cam.vista.
## id -> a fixed sideways shift of the lens (+ = right of the walk), to slide it past something in the foreground.
const LENS_SIDE := {"moor": 4.5}
const CLEAR_LENS := ["quarry", "holds", "stillwater", "moor", "necropolis", "siege", "saltmarket", "well", "anchorholds", "hierarch"]


func handles(id: String) -> bool:
	return PLACES.has(id)


func _look(id: String) -> Vector3:
	var pl: Array = PLACES[id]
	var v: Vector2 = pl[1]
	return Vector3(v.x, d.gy(v.x, v.y) + float(pl[2]), v.y)


func _s_any(id: String) -> void:
	var pl: Array = PLACES[id]
	gather_props()
	_try = 0
	_side_off = float(LENS_SIDE.get(id, 0.0))
	var st: Vector2 = clear_stand(pl[0])
	var look := _look(id)
	d.put_player(Vector3(st.x, 0.0, st.y), Cam.yaw_dir(look - Vector3(st.x, look.y, st.y)), -0.05)
	d.use_free_cam()
	d.cam.fov = float(pl[5])
	d.aim_at(look)
	d.drive(Cam.flat(look - d.pp()) * float(pl[8]))
	if id in CLEAR_LENS:
		pick_vista(look, float(pl[3]), float(pl[4]), float(pl[6]), float(pl[7]), float(pl[9]) if pl.size() > 9 else 0.22, 4.0 * float(pl[8]) * float(d.SHOTS[d.si][1]))


func _u_any(tt: float, id: String) -> void:
	var pl: Array = PLACES[id]
	var k: float = d.sm(clampf(tt / float(d.SHOTS[d.si][1]), 0.0, 1.0))
	if id in CLEAR_LENS:
		vista_clear(_look(id), k, float(pl[3]), float(pl[4]), float(pl[6]), float(pl[7]), float(pl[9]) if pl.size() > 9 else 0.22)
	else:
		cam.vista(_look(id), k, float(pl[3]), float(pl[4]), float(pl[6]), float(pl[7]))
	d.light_at(d.pp(), 3.0)
	for e in d.get_tree().get_nodes_in_group(Groups.ENEMY):          # a stray foe's floating health bar must not hang in a place shot
		(e as Node3D).visible = false
	if int(round(tt * 60.0)) % 4 == 0:
		for hb in d.main.find_children("HealthBar", "MeshInstance3D", true, false):
			(hb as Node3D).visible = false
	if d.flags.has("pl_halt"):
		d.drive(Vector3.ZERO)
		return
	var way := Cam.flat(_look(id) - d.pp()) * float(pl[8])
	d.drive(steer_clear(way))                       # round braziers, lamps and posts, not onto them
	d.aim_at(d.pp() + (d._drive_to if d._drive_to.length() > 0.05 else way) * 6.0)
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
	d.cam.fov = 56.0
	gather_props()
	pick_vista(c + Vector3.UP * 2.0, 7.0, 5.0, 1.0, 0.5, 0.3, 4.0)


func _u_weirford_life(tt: float) -> void:
	var c: Vector3 = d.on_ground(Vector3(-196.0, 0.0, 73.0))
	var k: float = d.sm(clampf(tt / 2.4, 0.0, 1.0))
	vista_clear(c + Vector3.UP * 2.0, k, 7.0, 5.0, 1.0, 0.5, 0.3)
	d.light_at(c, 4.0)
	d.aim_at(c)
	if d.pp().distance_to(c) < 6.5:
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


func fill_follow(at: Vector3, energy := 3.0, rng := 16.0) -> void:
	if _fl == null or not is_instance_valid(_fl):
		_fl = fill(at, energy, rng, Color(1.0, 0.8, 0.55))
	_fl.global_position = at


var _spire_xf := Transform3D.IDENTITY


## The Spire from outside: the lens starts low at the foot (the wanderer at the door) and cranes up the stone to the lamp
## room, where the great lamp is kindled as the lens arrives.
func _s_lamp_spire() -> void:
	d.clear_spawned()
	var sp: Dictionary = R37E.spots.lamp_spire
	_spire_xf = Transform3D(Basis(Vector3.UP, float(sp.yaw)), sp.at)
	var lamp := R37E.lamp_node as Lamp
	if lamp != null:
		lamp.douse()
	var st: Vector3 = _spire_xf * Vector3(2.5, 0.0, 7.5)
	d.put_player(st, Cam.yaw_dir(_spire_xf.basis * Vector3(0.0, 0.0, -1.0)), -0.05)
	d.drive(Vector3.ZERO)
	d.use_free_cam()
	d.cam.fov = 58.0
	fill(st + Vector3(0.0, 3.0, 2.0), 3.0, 12.0)


func _u_lamp_spire(tt: float) -> void:
	var c: Vector3 = _spire_xf.origin
	var k: float = d.sm(clampf(tt / 1.8, 0.0, 1.0))
	var a := lerpf(0.5, 0.15, k)                                    # round from the door side
	var r := lerpf(15.0, 12.0, k)
	var from: Vector3 = c + Vector3(sin(a) * r, lerpf(1.8, 27.5, k), cos(a) * r)
	var at: Vector3 = c + Vector3(0.0, lerpf(3.5, 27.5, k), 0.0)
	d.hold_cam(from, at)
	d.light_at(c, lerpf(4.0, 22.0, k))
	if tt > 1.3 and d.once("ls_kindle"):
		var lamp := R37E.lamp_node as Lamp
		if lamp != null and not lamp.lit:
			lamp.interact(d.p)
		fill(c + Vector3(0.0, 28.5, 1.5), 9.0, 14.0, Color(1.0, 0.75, 0.4))      # the great lamp's glow on the gallery


func _e_lamp_spire() -> void:
	d.drive(Vector3.ZERO)
	clear_fills()
	d.cam.fov = 62.0
