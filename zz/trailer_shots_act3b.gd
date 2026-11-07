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


## Props a walking wanderer must not step onto (braziers, lamps, lit posts, anything to interact with): their ground
## positions, gathered once per shot.
var _props: Array[Node3D] = []


func gather_props() -> void:
	_props.clear()
	for g in [Groups.BRAZIER, Groups.LIGHT_SOURCE, Lamp.GROUP]:
		for n in d.get_tree().get_nodes_in_group(g):
			var n3 := n as Node3D
			if n3 != null and n3.is_inside_tree() and not _props.has(n3):
				_props.append(n3)


## A stand point moved off any prop it would put the wanderer on (out to 2.8 m from it, along the line from the prop).
func clear_stand(st: Vector2) -> Vector2:
	for _pass in 3:
		for pr in _props:
			if not is_instance_valid(pr):
				continue
			var off := st - Vector2(pr.global_position.x, pr.global_position.z)
			if off.length() < 2.8:
				st = Vector2(pr.global_position.x, pr.global_position.z) + (off.normalized() if off.length() > 0.05 else Vector2.RIGHT) * 2.8
	return st


## `dir` (world, flat, length = pace) bent round any prop within a few metres ahead and a metre and a half either
## side of the line: the stick a player would hold to walk round a brazier. Zero if one stands right in the way.
func steer_clear(dir: Vector3, clear := 1.7) -> Vector3:
	var pace := dir.length()
	if pace < 0.001:
		return dir
	var fw := dir / pace
	var me: Vector3 = d.pp()
	var out := fw
	for pr in _props:
		if not is_instance_valid(pr):
			continue
		var r: Vector3 = pr.global_position - me
		r.y = 0.0
		var ahead := r.dot(fw)
		if ahead < -0.3 or ahead > 4.5:
			continue
		var perp := fw.cross(Vector3.UP)                # the walker's left
		var lat := r.dot(perp)                          # + : the prop is to the left
		if absf(lat) > clear:
			continue
		if r.length() < 1.0:
			return Vector3.ZERO
		var away := -signf(lat) if absf(lat) > 0.05 else 1.0
		out += perp * away * (clear - absf(lat)) / clear * 1.8
	return out.normalized() * pace


## Lens placements tried in order for a trailing shot: [back scale, height scale, sideways offset in metres].
const CAM_TRIES := [[1.0, 1.0, 0.0], [0.85, 1.15, 0.0], [1.0, 1.0, -6.0], [1.0, 1.0, 6.0], [1.0, 1.3, 2.5], [1.0, 1.3, -2.5], [0.7, 1.35, 2.0], [0.7, 1.35, -2.0], [0.55, 1.6, 0.0],
		[0.8, 1.9, 4.0], [0.8, 1.9, -4.0], [1.3, 1.5, 0.0], [0.4, 2.2, 0.0], [0.3, 2.8, 0.0]]
var _try := 0


func _lens_clear(head: Vector3, from: Vector3, at: Vector3) -> bool:
	if from.y < d.gy(from.x, from.z) + 0.9:
		return false
	var space: PhysicsDirectSpaceState3D = d.main.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.45
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = Layers.WORLD | Layers.PROPS
	q.exclude = [d.p.get_rid()]
	q.transform = Transform3D(Basis.IDENTITY, from)
	if not space.intersect_shape(q, 1).is_empty():
		return false                                       # inside or hard against something
	q.transform = Transform3D(Basis.IDENTITY, head)
	q.motion = from - head
	if space.cast_motion(q)[0] < 1.0:
		return false                                       # something between the lens and the wanderer
	var ahead := at - from
	var rq := PhysicsRayQueryParameters3D.create(from, from + ahead.normalized() * minf(ahead.length(), 5.0), Layers.WORLD | Layers.PROPS)
	rq.exclude = [d.p.get_rid()]
	return space.intersect_ray(rq).is_empty()              # nothing across the lens


## The lens spot for a trailing vista with the wanderer at `me` and the shot clock at `k`: candidate `i` of CAM_TRIES.
func _vista_spot(i: int, me: Vector3, look: Vector3, k: float, back: float, h: float, lat: float, rise: float, max_pitch: float) -> Array:
	var dir := Cam.flat(look - me)
	var side := dir.cross(Vector3.UP)
	var c: Array = CAM_TRIES[i]
	var from: Vector3 = me - dir * back * float(c[0]) + side * (lat * (k * 2.0 - 1.0) + float(c[2])) + Vector3.UP * (h + rise * k) * float(c[1])
	var flat_len := Vector2(look.x - from.x, look.z - from.z).length()
	var to_head: Vector3 = me + Vector3.UP * 1.5 - from
	var head_ang := atan2(to_head.y, maxf(Vector2(to_head.x, to_head.z).length(), 0.5))
	var keep := head_ang + deg_to_rad(d.cam.fov) * 0.3                      # the wanderer's head no lower than the lower third
	var pitch := minf(minf(atan2(look.y - from.y, maxf(flat_len, 1.0)) * 0.5, max_pitch), keep)
	return [from, from + (Cam.flat(look - from) * cos(pitch) + Vector3.UP * sin(pitch)) * 20.0]


## Picks (and locks) the lens placement for a trailing vista that is clear at the start, the middle and the end of the
## walk (the wanderer goes `walk` metres toward `look`): never behind a wall, a roof, a sign or a headstone at any point.
func pick_vista(look: Vector3, back: float, h: float, lat: float, rise: float, max_pitch: float, walk: float) -> void:
	var me: Vector3 = d.pp()
	var dir := Cam.flat(look - me)
	_try = CAM_TRIES.size() - 1
	for i in CAM_TRIES.size():
		var ok := true
		for k in [0.0, 0.5, 1.0]:
			var m: Vector3 = d.on_ground(me + dir * walk * k)
			var sp := _vista_spot(i, m, look, k, back, h, lat, rise, max_pitch)
			if not _lens_clear(m + Vector3.UP * 1.5, sp[0], sp[1]):
				ok = false
				break
		if ok:
			_try = i
			break
	print("TRAILER lens locked: try %d" % _try)


## A trailing vista like Cam.vista from the placement pick_vista locked.
func vista_clear(look: Vector3, k: float, back: float, h: float, lat: float, rise: float, max_pitch := 0.22) -> void:
	var sp := _vista_spot(_try, d.pp(), look, k, back, h, lat, rise, max_pitch)
	d.hold_cam(sp[0], sp[1])


## A fixed yaw for the lens: direction (flat) from a to b.
func flat_dir(a: Vector3, b: Vector3) -> Vector3:
	return Cam.flat(b - a)


## A two-shot: the lens off to one side of the line a -> b, `dist` out and `h` up, looking at the midpoint, swinging a
## little over the shot (k 0..1). side is +1 or -1; swing in radians.
func two_shot(a: Vector3, b: Vector3, k: float, dist: float, h: float, side := 1.0, swing := 0.4, look_up := 1.3) -> void:
	var mid := a.lerp(b, 0.5)
	var perp: Vector3 = Cam.flat(b - a).cross(Vector3.UP) * side
	perp = perp.rotated(Vector3.UP, swing * (k - 0.5))
	d.frame_cam(mid + perp * dist + Vector3.UP * h, mid + Vector3.UP * look_up)


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
	d.cam.fov = 56.0
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


var _hb_base := Vector3.ZERO


## Open flat ground for the line-up: the first spot on rings round `c` where a box 18 m along the line, 13 m deep
## (the lens's side) holds no wall, house, lamp or stone and the ground is level.
func _open_line(c: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = (d.main as Node3D).get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(18.0, 3.4, 17.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = Layers.WORLD | Layers.PROPS
	for r: float in [0.0, 12.0, 24.0, 36.0, 48.0, 64.0, 80.0]:
		for k in 12:
			var a := TAU * float(k) / 12.0
			var p := c + Vector3(cos(a), 0.0, sin(a)) * r
			var ys: Array[float] = []
			for off: Vector2 in [Vector2(-2, -14), Vector2(14, -14), Vector2(-2, 2), Vector2(16, 2), Vector2(7, -4)]:
				ys.append(d.gy(p.x + off.x, p.z + off.y))
			if ys.max() - ys.min() > 0.7:
				continue
			var base := Vector3(p.x, ys[4], p.z)
			q.transform = Transform3D(Basis(), base + Vector3(5.5, 2.2, -6.5))
			if space.intersect_shape(q, 1).is_empty():
				return d.on_ground(base)
	print("TRAILER no open line-up spot")
	return d.on_ground(c)


func _s_horse_breeds() -> void:
	_line.clear()
	d.clear_spawned()
	_hb_base = _open_line(d.ARENA)
	var base: Vector3 = _hb_base
	var i := 0
	for b in ["palfrey", "garron", "fenpony", "draught", "weir_cob"]:
		var h := horse(b)
		if h == null:
			continue
		# a hitching line along the road, each facing south, the lens passing along it
		place_horse(h, base + Vector3(float(i) * 2.7, 0.0, 0.0), 0.0)
		_line.append(h)
		i += 1
	d.put_player(base + Vector3(-14.0, 0.0, -18.0), Cam.yaw_dir(Vector3(1.0, 0.0, -1.0)))
	d.use_free_cam()
	d.cam.fov = 56.0


func _u_horse_breeds(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	var base: Vector3 = _hb_base
	var x := lerpf(4.0, 6.8, k)
	var at := base + Vector3(x, 1.2, 0.0)
	d.frame_cam(at + Vector3(0.0, 0.3, -10.0), at - Vector3(0.0, 0.1, 0.0))
	d.light_at(base + Vector3(x, 0.0, -2.0), 3.5)
	if d.once("hb_fill"):
		fill(base + Vector3(6.8, 3.4, -3.0), 4.0, 16.0, Color(1.0, 0.78, 0.5))


func _e_horse_breeds() -> void:
	clear_fills()
	restore_horses()
	d.cam.fov = 62.0
