extends RefCounted
## Act III kit and the horse shots (the realm widens). The base of the Act III provider chain
## (trailer_shots_act3.gd extends trailer_shots_act3c.gd extends this): helpers every Act III shot shares (temporary
## fill lights, waking the villagers the shoot stood down, finding the stables' horses) and the ridden shots, which
## use the real horses (core/world/mount/horse.gd) and the real rig and gaits, steered by the same input a player gives.

const Cam := preload("res://zz/trailer_cam.gd")
const HorseS := preload("res://core/world/mount/horse.gd")

var d
var cam
var _fills: Array[Light3D] = []
var _held: Dictionary = {}                ## horse -> [position, yaw] it stood at before the shoot moved it


func _init(director: Object) -> void:
	d = director
	cam = Cam.new(director)


# --- kit ----------------------------------------------------------------------------------------------

## A temporary warm or cool fill light: freed by clear_fills() when the shot ends.
func fill(at: Vector3, energy := 3.0, rng := 12.0, col := Color(1.0, 0.72, 0.45)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	d.main.add_child(l)
	l.global_position = at
	_fills.append(l)
	return l


func clear_fills() -> void:
	for l in _fills:
		if is_instance_valid(l):
			l.queue_free()
	_fills.clear()


## The people the shoot stood down, brought back within `r` metres of `c`; returns how many.
func wake_villagers(c: Vector3, r: float) -> int:
	var n := 0
	for v in d._by_script("villager.gd"):
		var v3 := v as Node3D
		if v3 == null or v3.global_position.distance_to(c) > r:
			continue
		v3.visible = true
		v3.process_mode = Node.PROCESS_MODE_INHERIT
		n += 1
	return n


## A fixed yaw for the lens: direction (flat) from a to b.
func flat_dir(a: Vector3, b: Vector3) -> Vector3:
	return Cam.flat(b - a)


## Frees a spawned foe list entry that the director would otherwise cull (real systems spawn their own foes).
func adopt(foes: Array) -> void:
	for f in foes:
		if is_instance_valid(f) and not d.spawned.has(f):
			d.spawned.append(f)


func stables() -> Node:
	return d.main.find_child("Stables", true, false)


func horse(breed: String) -> HorseS:
	var st := stables()
	if st == null:
		print("TRAILER no stables")
		return null
	var hs: Dictionary = st.get("horses")
	var h := hs.get(breed) as HorseS
	if h != null and not _held.has(h):
		_held[h] = [h.global_position, h.rotation.y]
	return h


## Stand a horse at `at` facing `yaw` (the world's own yaw convention: forward is (-sin, 0, -cos)).
func place_horse(h: HorseS, at: Vector3, yaw: float) -> void:
	h.global_position = d.on_ground(at, 0.05)
	h.rotation.y = yaw
	h._yaw = yaw
	h.at_post = false
	h.speed = 0.0


## Put the horses back at their posts.
func restore_horses() -> void:
	for k in _held:
		var h := k as HorseS
		if is_instance_valid(h):
			var v: Array = _held[k]
			h.global_position = v[0]
			h.rotation.y = float(v[1])
			h._yaw = float(v[1])
			h.at_post = true
			h.speed = 0.0
	_held.clear()


## The wanderer already in the saddle, the horse already moving (the shot opens mid-stride).
func seat_rider(h: HorseS, speed: float) -> void:
	h.mount(d.p)
	h._mount_t = 9.0
	h.speed = speed
	h._speed_prev = speed
	d.p._visual.ride = 1.0


func get_down(h: HorseS) -> void:
	if h != null and h.rider != null:
		h.dismount()
	d.drive(Vector3.ZERO)
	d.p._visual.ride = 0.0


## Ride toward `dir` (world, flat) at the gallop; the stick has been held since before the cut.
func gallop_toward(dir: Vector3) -> void:
	d.drive(dir, true)
	d._drive = d._drive_to


# --- the card ---------------------------------------------------------------------------------------------

func _s_card_realm() -> void:
	d.drive(Vector3.ZERO)
	d._card("THE REALM WIDENS", 1.0)
	d.boom("lance_hit", -3.0)


func _u_card_realm(tt: float) -> void:
	d.title.modulate.a = clampf(tt / 0.25, 0.0, 1.0)


# --- horses ------------------------------------------------------------------------------------------------

var _hz: HorseS


func _s_horse_mount() -> void:
	_hz = horse("palfrey")
	d.clear_spawned()
	var at: Vector3 = d.ARENA + Vector3(-6.0, 0.0, 0.0)
	place_horse(_hz, at, d.WEST)
	var fwd: Vector3 = d.fwd_of(d.WEST)
	var left := -_hz.global_basis.x.normalized()
	d.put_player(_hz.global_position + left * 2.4 + fwd * 0.15, Cam.yaw_dir(-left))
	d.use_free_cam()
	d.cam.fov = 48.0


func _u_horse_mount(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	var hp := _hz.global_position
	var fwd: Vector3 = d.fwd_of(d.WEST)
	var left := -_hz.global_basis.x.normalized()
	# front-left quarter, low, drifting round toward the head as she swings up
	var from := hp + left * lerpf(3.3, 3.8, k) + fwd * lerpf(2.6, 3.4, k) + Vector3.UP * lerpf(1.1, 1.6, k)
	d.frame_cam(from, hp + Vector3.UP * 1.25 + fwd * 0.2)
	d.light_at(hp, 3.2)
	if tt > 0.15 and d.once("hm_mount"):
		_hz.mount(d.p)


func _e_horse_mount() -> void:
	get_down(_hz)
	restore_horses()
	d.cam.fov = 62.0


func _s_horse_gallop() -> void:
	_hz = horse("palfrey")
	d.clear_spawned()
	var at: Vector3 = d.ARENA + Vector3(-12.0, 0.0, 0.0)
	place_horse(_hz, at, d.WEST)
	d.put_player(at, d.WEST, -0.12)
	seat_rider(_hz, 4.0)
	gallop_toward(d.fwd_of(d.WEST))
	d.use_player_cam()


func _u_horse_gallop(tt: float) -> void:
	d.light_at(d.pp() + d.fwd_of(d.WEST) * 4.0, 4.0)
	# the game's own camera follows; steer the view down the road a little either way
	d.p.set_view(d.WEST + sin(tt * 1.3) * 0.12, -0.14)


func _e_horse_gallop() -> void:
	get_down(_hz)
	restore_horses()


func _s_horse_jump() -> void:
	_hz = horse("palfrey")
	d.clear_spawned()
	var at: Vector3 = d.ARENA + Vector3(-10.0, 0.0, 0.0)
	place_horse(_hz, at, d.WEST)
	d.put_player(at, d.WEST, -0.12)
	seat_rider(_hz, float(_hz._d.gallop))
	gallop_toward(d.fwd_of(d.WEST))
	d.use_free_cam()
	d.cam.fov = 50.0
	d.aim_at(d.pp() + d.fwd_of(d.WEST) * 20.0)


func _u_horse_jump(tt: float) -> void:
	var hp := _hz.global_position
	var fwd: Vector3 = d.fwd_of(d.WEST)
	var side := fwd.cross(Vector3.UP)            # the rider's left (south)
	# square to the run, a little ahead, tracking: the leap in profile
	var from := hp + side * -6.0 + fwd * (2.0 - tt * 0.6) + Vector3.UP * 1.3
	d.hold_cam(from, hp + fwd * 0.6 + Vector3.UP * (1.3 + clampf(hp.y - d.gy(hp.x, hp.z), 0.0, 2.0) * 0.6))
	d.light_at(hp, 4.0)
	if tt > 0.35 and d.once("hj_jump"):
		d.press("jump")
	if tt > 0.45 and d.once("hj_jump_up"):
		d.release("jump")


func _e_horse_jump() -> void:
	d.release("jump")
	get_down(_hz)
	restore_horses()
	d.cam.fov = 62.0


func _s_horse_fp() -> void:
	_hz = horse("palfrey")
	d.clear_spawned()
	var at: Vector3 = d.ARENA + Vector3(-10.0, 0.0, 0.0)
	place_horse(_hz, at, d.WEST)
	d.put_player(at, d.WEST, -0.1)
	seat_rider(_hz, 7.0)
	gallop_toward(d.fwd_of(d.WEST))
	(d.p.get_node("Visual") as Node3D).visible = false
	d.use_free_cam()
	d.cam.fov = 82.0


func _u_horse_fp(tt: float) -> void:
	var f: Vector3 = d.fwd_of(d.WEST)
	var h: Vector3 = d.head()
	d.hold_cam(h + f * 0.3, h + f * 14.0 + Vector3.UP * (-0.5 + sin(tt * 2.0) * 0.1))
	d._snap = true                                       # first person rides the head exactly
	d.light_at(h + f * 6.0, 3.5)
	d.p.set_view(d.WEST, -0.1)


func _e_horse_fp() -> void:
	(d.p.get_node("Visual") as Node3D).visible = true
	get_down(_hz)
	restore_horses()
	d.cam.fov = 62.0


func _s_horse_gallop_b() -> void:
	_hz = horse("garron")
	d.clear_spawned()
	var at := Vector3(150.0, 0.0, 40.0)               # the moor's south, heading west along the heather
	var yaw := Cam.yaw_dir(Vector3(-1.0, 0.0, 0.0))
	place_horse(_hz, at, yaw)
	d.put_player(at, yaw, -0.12)
	seat_rider(_hz, 5.0)
	gallop_toward(d.fwd_of(yaw))
	d.use_player_cam()


func _u_horse_gallop_b(tt: float) -> void:
	var yaw := Cam.yaw_dir(Vector3(-1.0, 0.0, 0.0))
	d.light_at(d.pp() + d.fwd_of(yaw) * 4.0, 4.0)
	d.p.set_view(yaw + sin(tt * 1.2) * 0.15, -0.12)


func _e_horse_gallop_b() -> void:
	get_down(_hz)
	restore_horses()


var _line: Array[HorseS] = []


func _s_horse_breeds() -> void:
	_line.clear()
	d.clear_spawned()
	var base: Vector3 = d.ARENA + Vector3(-14.0, 0.0, 0.0)
	var i := 0
	for b in ["palfrey", "garron", "fenpony", "draught", "weir_cob"]:
		var h := horse(b)
		if h == null:
			continue
		# a hitching line along the road, each facing south, the lens passing along it
		place_horse(h, base + Vector3(float(i) * 3.4, 0.0, 0.0), 0.0)
		_line.append(h)
		i += 1
	d.put_player(base + Vector3(-6.0, 0.0, 6.0), Cam.yaw_dir(Vector3(1.0, 0.0, -1.0)))
	d.use_free_cam()
	d.cam.fov = 44.0


func _u_horse_breeds(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	var base: Vector3 = d.ARENA + Vector3(-14.0, 0.0, 0.0)
	var x := lerpf(-1.0, 4.0 * 3.4 + 1.0, k)
	var at := base + Vector3(x, 1.2, 0.0)
	d.frame_cam(at + Vector3(0.6, 0.2, -7.2), at)
	d.light_at(base + Vector3(x, 0.0, -2.0), 3.5)
	if d.once("hb_fill"):
		fill(base + Vector3(6.8, 3.4, -3.0), 4.0, 16.0, Color(1.0, 0.78, 0.5))


func _e_horse_breeds() -> void:
	clear_fills()
	restore_horses()
	d.cam.fov = 62.0
