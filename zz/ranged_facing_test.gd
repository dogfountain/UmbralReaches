extends Node
## Every ranged foe fires toward you whichever way it started facing: the shot leaves from the front
## of the body (the mouth, sac or staff on your side), travels at you (dot > 0.9), and the rig
## faces you when it lets go (its head and its forward are on your side of the body).
## Run: SCRATCH=<dir> tools/run_tests.sh ranged_facing
const AT := Vector3(-24.0, 0.0, 60.0)     ## open ground outside every sanctuary light
const KINDS := {
	"spitter": "res://core/enemy/spitter.gd",
	"cinder": "res://core/enemy/cinder_caster.gd",
	"quiller": "res://core/enemy/quiller.gd",
	"brood": "res://core/enemy/brood_mother.gd",
	"cantor": "res://core/life/encounters/elite_cinder_cantor.gd",
	"answerer": "res://core/life/encounters/elite_answerer.gd",
}
const BEARINGS := [0.0, 45.0, 90.0, 135.0, 180.0, -90.0, -150.0]    ## where you stand, from the way it first faces
const DIST := 9.0
var p: Player
var main: Node
var fails := 0
var started := false


func _ready() -> void:
	Travel._busy = true
	Travel.bosses_slain.clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool, detail := "") -> void:
	print("RANGED %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _physics_process(_d: float) -> void:
	if started:
		return
	if Engine.get_physics_frames() > 60 * 240:
		print("RANGED FAIL timeout waiting for the world")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not main.has_meta("summit_dressed") or main.find_child("Encounters", true, false) == null or main.find_child("Rares", true, false) == null:
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ground(v: Vector3) -> Vector3:
	return Vector3(v.x, RealmLayout.ground(p.get_world_3d().direct_space_state, v.x, v.z), v.z)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _clear() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for n in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		(n as Node).queue_free()


func _run() -> void:
	main.find_child("Encounters", true, false).process_mode = Node.PROCESS_MODE_DISABLED
	var sp := main.find_child("EnemySpawner", true, false)
	if sp:
		sp.process_mode = Node.PROCESS_MODE_DISABLED
	main.find_child("Rares", true, false).process_mode = Node.PROCESS_MODE_DISABLED
	_clear()
	await _frames(3)
	for k: String in KINDS:
		for b: float in BEARINGS:
			await _case(k, b)
	await _warden()
	print("RANGED %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(0 if fails == 0 else 1)


## One foe, you at `bearing` degrees from the way it first faces (-Z); watch until its first shot.
func _case(kind: String, bearing: float) -> void:
	var e := (load(KINDS[kind]) as GDScript).new() as Enemy
	main.add_child(e)
	e.global_position = _ground(AT) + Vector3.UP * 0.1
	e.home = e.global_position
	var dir := Basis(Vector3.UP, deg_to_rad(bearing)) * Vector3.FORWARD
	p.teleport(_ground(AT + dir * DIST) + Vector3.UP * 0.3)
	p.velocity = Vector3.ZERO
	p.gloom = 0.0
	p.wounds = 0.0
	e.wake()
	if e._face:
		e._face.rotation.y = 0.0
	e.walk_speed = 0.0            # hold its ground: the bearing is the test
	var tag := "%s @%d" % [kind, int(bearing)]
	var seen := false
	var spawn := Vector3.ZERO
	var vel := Vector3.ZERO
	var facing := -2.0
	var head := -2.0
	var flat_aim := false
	var h := Vfx.host()
	var host_kids := h.get_child_count() if h else 0
	for f in 60 * 7:
		await get_tree().physics_frame
		if not is_instance_valid(e):
			break
		if kind == "quiller":                 # its shard flies down the drawn lane: judge the lane
			if e._state == Enemy.WINDUP and e._state_t > 0.6:
				var lane := Basis(Vector3.UP, e._aim_yaw) * Vector3.FORWARD
				spawn = e.global_position + lane * 0.4
				vel = lane * 10.0
				seen = true
				flat_aim = true
		var orb: SpitOrb = null
		for n in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
			if n is SpitOrb:
				orb = n
				break
		if orb != null:
			spawn = orb.global_position - orb.velocity * get_physics_process_delta_time()
			vel = orb.velocity
			seen = true
		elif h != null and not seen:
			for i in range(host_kids, h.get_child_count()):
				var mi := h.get_child(i) as MeshInstance3D
				if mi != null and mi.mesh is SphereMesh and absf((mi.mesh as SphereMesh).radius - 0.16) < 0.001:
					spawn = mi.global_position
					seen = true
					break
			host_kids = h.get_child_count()
		if seen:
			var to := _flat(p.global_position - e.global_position).normalized()
			var fwd := _flat(-e._face.global_basis.z).normalized()
			facing = fwd.dot(to)
			var hd: Node3D = e._rig.socket("head") if e._rig else null
			if hd != null:
				head = _flat(hd.global_position - e.global_position).normalized().dot(to)
			var ch: Node3D = e._rig.socket("chest") if e._rig else null
			if ch != null and hd != null:
				var inv := e._face.global_transform.affine_inverse()
				print("RANGED DIAG %s head_local %s chest_local %s" % [tag, inv * hd.global_position, inv * ch.global_position])
			break
	if not seen:
		check(tag + " fires", false, "no shot in 7 s (state %d)" % e._state)
	else:
		var to2 := _flat(p.global_position - e.global_position).normalized()
		var at := _flat(spawn - e.global_position).dot(to2)
		check(tag + " spawn is on your side", at > 0.0, "%.2f m" % at)
		if vel != Vector3.ZERO:
			var want := p.global_position + Vector3.UP * 1.05 - spawn
			if flat_aim:
				want.y = 0.0
			var aim := want.normalized().dot(vel.normalized())
			check(tag + " flies at you", aim > 0.9, "dot %.2f" % aim)
		check(tag + " faces you at release", facing > 0.9, "fwd %.2f head %.2f" % [facing, head])
	if is_instance_valid(e):
		e.queue_free()
	_clear()
	await _frames(2)


## The Ascended Warden's fan: orbs leave along the cone toward you.
func _warden() -> void:
	for b: float in [0.0, 180.0, 90.0]:
		var w := (load("res://core/enemy/ascended_warden.gd") as GDScript).new() as Enemy
		main.add_child(w)
		w.global_position = _ground(AT) + Vector3.UP * 0.1
		w.home = w.global_position
		var dir := Basis(Vector3.UP, deg_to_rad(b)) * Vector3.FORWARD
		p.teleport(_ground(AT + dir * 10.0) + Vector3.UP * 0.3)
		p.velocity = Vector3.ZERO
		w.wake()
		await _frames(2)
		w._aim_fan(false)
		var best := -2.0
		var front := -2.0
		for f in 60 * 3:
			await get_tree().physics_frame
			for n in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
				var o := n as SpitOrb
				if o != null:
					var to := _flat(p.global_position - w.global_position).normalized()
					best = maxf(best, _flat(o.velocity).normalized().dot(to))
					front = _flat(o.global_position - w.global_position).normalized().dot(to)
			if best > -2.0:
				break
		check("warden fan @%d flies toward you" % int(b), best > 0.8, "dot %.2f spawn %.2f" % [best, front])
		_clear()
		await _frames(2)
