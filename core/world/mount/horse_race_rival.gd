extends RefCounted
## A rival's riding in the Hearthward race, cheaply. The rival is one of three horses built behind the loading screen and parked
## (horse_race_field.gd); during a race it is driven from here and nowhere else (its own physics and paddock code stay off).
## `steer` runs about fifteen times a second: it picks a heading round whatever lies ahead (five short rays, as the whistle does),
## reads the ground a couple of metres on, and notices being stuck. `move` runs each rendered frame and is arithmetic only: it
## eases speed and yaw, advances the horse and its gait. A rival more than 110 m from the camera is not posed (Horse._process
## already skips it) and makes no hoof sounds. Static; `h` is the Horse, `rs` its state dictionary.
const TURNS := [0.0, 0.55, -0.55, 1.1, -1.1]
const STEER_DT := 0.066


## Fresh state for a rival that runs `pace` m/s.
static func start(h: Variant, pace: float) -> Dictionary:
	var node := h as Node3D
	return {"pace": pace, "gate": 0, "done": false, "t": 0.0, "acc": 0.0, "pick": Vector3.ZERO, "free": true,
		"gy": node.global_position.y, "stuck": 0.0, "last": node.global_position, "yaw": node.global_rotation.y, "want": 0.0,
		"hoof": 0.0, "run": true}


static func _flat(a: Vector3, b: Vector3) -> Vector3:
	var v := b - a
	v.y = 0.0
	return v


## Pick the heading and the target speed. `goal` is the gate's point; `pace` may be eased by the race to keep the field close.
static func steer(h: Variant, rs: Dictionary, goal: Vector3, pace: float, dt: float) -> void:
	var node := h as Node3D
	var pos: Vector3 = node.global_position
	var to := _flat(pos, goal)
	var dist := to.length()
	if dist < 0.01:
		return
	var dir := to / dist
	var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
	var base := pos + Vector3.UP * 0.9
	var free := false
	var pick := dir
	for turn: float in TURNS:
		var d := dir.rotated(Vector3.UP, turn)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(base, base + d * 3.2, Layers.WORLD | Layers.PROPS)).is_empty():
			pick = d
			free = true
			break
	rs["pick"] = pick
	rs["free"] = free
	# the ground a little ahead: a wall of earth is not climbed
	var ahead := pos + pick * 2.2
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 3.0, ahead + Vector3.DOWN * 6.0, Layers.WORLD))
	var gy := pos.y
	if not hit.is_empty():
		gy = (hit.position as Vector3).y
		if gy - pos.y > float(h._d.climb) + 0.5:
			free = false
			rs["free"] = false
	rs["gy"] = gy
	var want := pace if free else 0.0
	if dist < 22.0:
		want = minf(want, pace * 0.9)             # into the turn a little slower, as a rider would
	rs["want"] = want
	# stuck: no ground gained for a second
	var moved := _flat(rs.last as Vector3, pos).length()
	rs["acc"] = float(rs.acc) + dt
	if float(rs.acc) >= 1.0:
		rs["stuck"] = float(rs.stuck) + 1.0 if moved < 1.5 else 0.0
		rs["last"] = pos
		rs["acc"] = 0.0
		if float(rs.stuck) >= 3.0:                 # hop it forward past what it is wedged on, on to ground that is there
			var np := pos + dir * 6.0
			var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(np + Vector3.UP * 4.0, np + Vector3.DOWN * 8.0, Layers.WORLD))
			if not g.is_empty():
				node.global_position = g.position
			rs["stuck"] = 0.0


## Each rendered frame: ease the speed and heading, step forward, advance the gait. No rays, no allocation.
static func move(h: Variant, rs: Dictionary, dt: float, hear: bool) -> void:
	var node := h as Node3D
	var want := float(rs.want) if bool(rs.run) else 0.0
	var sp: float = h.speed
	sp = move_toward(sp, want, 6.0 * dt)
	h.speed = sp
	var pick: Vector3 = rs.pick
	if pick != Vector3.ZERO:
		rs["yaw"] = lerp_angle(float(rs.yaw), atan2(-pick.x, -pick.z), 1.0 - exp(-6.0 * dt))
	node.global_basis = Basis(Vector3.UP, float(rs.yaw))
	if sp > 0.01:
		var fwd := Vector3(-sin(float(rs.yaw)), 0.0, -cos(float(rs.yaw)))
		var p := node.global_position + fwd * sp * dt
		p.y = lerpf(node.global_position.y, float(rs.gy), 1.0 - exp(-10.0 * dt))
		node.global_position = p
		h._phase_prev = h._phase
		h._phase += TAU * h._rig.freq(sp) * dt
		if hear:
			h._hooves(dt)
