extends Node3D
## r36 a horse (core/world/mount): one creature-shader MultiMesh instance (life_kit's horse_* meshes:
## legs and head animated on the GPU from the gait phase), a state, and the ride. Stands at its
## hitching post (or where it was left) grazing; [E] buys it there, rides it once owned; [E] while
## riding gets down. Player.riding hands the drive to `drive()` every physics frame.
##   walk / trot / gallop by the move stick and sprint; turns toward the move direction at the
##   breed's rate; follows the ground with a ray (refuses a step taller than `climb`); stops at a
##   wall; slows to a walk in water unless it wades; a draught throws the hollowed aside (trample).

const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const DB := preload("res://core/world/mount/horse_db.gd")
const VAudio := preload("res://core/life/village/village_audio.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")

var breed := "palfrey"
var at_post := true              ## standing at its hitching post (for sale until owned)
var rider: Node3D = null
var speed := 0.0
var _mmi: MultiMeshInstance3D
var _d: Dictionary
var _yaw := 0.0
var _phase := 0.0
var _head := 0.0                 ## head pitch (grazing lowers it)
var _graze_t := 0.0
var _sfx_t := 0.0
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	_d = DB.BREEDS.get(breed, DB.BREEDS["palfrey"])
	add_to_group(Groups.INTERACTABLE)
	add_to_group(&"horse")
	_mmi = LifeKit.group(String(_d.mesh), 1)
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mmi.visibility_range_end = 120.0
	add_child(_mmi)
	_yaw = global_basis.get_euler().y
	_write()


func can_interact() -> bool:
	return true


func interact_text() -> String:
	var k := Interactable.prompt_key()
	if rider != null:
		return "[%s]  Get down" % k
	if not owned():
		return "[%s]  Buy the %s  (%d grave ash)" % [k, String(_d.name), int(_d.cost)]
	return "[%s]  Ride the %s" % [k, String(_d.name)]


func interact_reach() -> float:
	return 2.6


func interact_feel() -> StringName:
	return &"cast"


func interact(by: Node) -> void:
	var p := by as Player
	if p == null:
		return
	if rider != null:
		dismount()
		return
	if not owned():
		if Travel.count("grave_ash") < int(_d.cost):
			Events.toast.emit("%s  It wants %d grave ash; you carry %d." % [String(_d.line), int(_d.cost), Travel.count("grave_ash")])
			return
		Travel.items["grave_ash"] = Travel.count("grave_ash") - int(_d.cost)
		var st := state()
		(st.owned as Array).append(breed)
		st["ride"] = breed
		Travel.save_soon()
		Events.toast.emit("The %s is yours. Ride it, or call it with [H] wherever you are." % String(_d.name))
		return
	mount(p)


func owned() -> bool:
	return (state().owned as Array).has(breed)


static func state() -> Dictionary:
	var st := Travel.system_state("stable")
	if not (st.get("owned") is Array):
		st["owned"] = []
	if not st.has("ride"):
		st["ride"] = ""
	return st


func mount(p: Player) -> void:
	rider = p
	at_post = false
	state()["ride"] = breed
	p.riding = self
	Sfx.play("res://art/audio/ward_chime.wav", global_position, -14.0, 0.6)


func dismount() -> void:
	var p := rider as Player
	rider = null
	speed = 0.0
	if p != null and is_instance_valid(p):
		p.riding = null
		var side := global_basis.x.normalized()
		var to := global_position + side * 1.1
		p.teleport(_ground(to) + Vector3.UP * 0.1)


## Player.riding: move the horse from the rider's wish (world xz) and sprint; seat the rider.
func drive(p: Player, wish: Vector3, sprint: bool, dt: float) -> void:
	_space = get_world_3d().direct_space_state
	if Player.boss_fight_active(get_tree()):
		dismount()
		Events.toast.emit("The horse will go no nearer. You get down.")
		return
	var want := 0.0
	var w := Vector3(wish.x, 0.0, wish.z)
	if w.length() > 0.1:
		want = float(_d.gallop) if sprint else (float(_d.trot) if w.length() > 0.7 else float(_d.walk))
		var target_yaw := atan2(-w.x, -w.z)
		_yaw = rotate_toward(_yaw, target_yaw, float(_d.turn) * dt * (0.6 if speed > 8.0 else 1.0))
	var wading := RealmLand.in_water(global_position.x, global_position.z)
	if wading and not bool(_d.get("wade", false)):
		want = minf(want, float(_d.walk))
	speed = move_toward(speed, want, (6.0 if want > speed else 9.0) * dt)
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	if speed > 0.05:
		var step := fwd * speed * dt
		var next := global_position + step
		var g := _ground(next)
		var chest := global_position + Vector3.UP * 1.2 * _scale()
		var wall := _space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + fwd * (0.9 * _scale() + speed * dt), Layers.WORLD | Layers.PROPS, [p.get_rid()]))
		if not wall.is_empty() or g.y - global_position.y > float(_d.climb) or g.y - global_position.y < -6.0:
			speed = 0.0
		else:
			global_position = Vector3(next.x, lerpf(global_position.y, g.y, 0.5), next.z)
			_phase = fposmod(_phase + speed * dt * 2.6 / _scale(), TAU)
	if bool(_d.get("trample", false)) and speed > 6.0:
		_trample(fwd)
	global_basis = Basis(Vector3.UP, _yaw)
	_head = lerpf(_head, -0.15 if speed > 7.0 else 0.0, 1.0 - exp(-4.0 * dt))
	_write()
	_hooves(dt)
	# the rider sits the saddle, facing where the horse faces
	p.global_position = global_position + Vector3.UP * (1.26 * _scale() - 0.62) + fwd * 0.04
	p.velocity = fwd * speed


func _process(dt: float) -> void:
	# a rider that died, was hollowed or was moved off (a respawn, travel) is no longer riding
	if rider != null and (not is_instance_valid(rider) or rider.get("riding") != self):
		rider = null
		speed = 0.0
	if rider != null:
		return
	# standing: graze now and then, flick the head up
	_graze_t -= dt
	if _graze_t <= 0.0:
		_graze_t = randf_range(4.0, 9.0)
	var down := _graze_t > 2.0
	_head = lerpf(_head, 0.7 if down else 0.0, 1.0 - exp(-1.5 * dt))
	if speed > 0.0:
		speed = move_toward(speed, 0.0, 9.0 * dt)
	_write()


func _write() -> void:
	if _mmi == null:
		return
	var mm := _mmi.multimesh
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_custom_data(0, Color(0.0, 0.0, _phase if speed > 0.05 else 0.0, _head))


func _scale() -> float:
	return float((LifeKit.RIG.get(String(_d.mesh), {}) as Dictionary).get("head_pivot", Vector3(0, 1.42, 0)).y)


func _hooves(dt: float) -> void:
	if speed < 1.0:
		return
	_sfx_t -= dt
	if _sfx_t <= 0.0:
		_sfx_t = clampf(1.6 / speed, 0.12, 0.5)
		VAudio.play("dig", global_position, -16.0 + minf(speed, 10.0) * 0.6, randf_range(0.7, 0.85))


func _trample(fwd: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive() or e.boss:
			continue
		var d := e.global_position - global_position
		if d.length() < 1.6 * _scale() and d.dot(fwd) > 0.0:
			e.take_hit(1.0, rider)
			e.shove((fwd + d.normalized()).normalized() * 9.0)


func _ground(at: Vector3) -> Vector3:
	var sp := _space if _space else get_world_3d().direct_space_state
	var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 8.0, Layers.WORLD))
	return (hit.position as Vector3) if not hit.is_empty() else at
