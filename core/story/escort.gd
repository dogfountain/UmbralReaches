extends Node3D
## A task step that walks somebody (story; no class_name): kind "escort" with a `path` of points.
## The quest runner (quest_runner.gd) adds one while the step is current and frees it when the step
## moves on. A villager-rig walker follows `path` at a walking pace:
##   - it stops when the wanderer is further than FAR, or while a foe is close (it is under attack),
##   - the foes in reach of it wound it (DPS each); the small frame shows its health,
##   - an `ambush` ({waypoint index: {"kinds": [...], "n": 3}}) puts foes in its way as it reaches a point,
##   - it falls: after a pause it stands again at the last waypoint it reached (the task never
##     dead-ends), the ambush there waiting again,
##   - the last point reached ends the step (`arrived`).
## The checkpoint is kept in the task's save dictionary by the runner, so a reload resumes there.
## Step data: path [Vector2], hp, label (the frame's title), rig (villager_rig options), ambush.

signal arrived
signal fell(checkpoint: int)
signal reached(checkpoint: int)

const Kit := preload("res://core/story/encounter_kit.gd")
const Rig := preload("res://core/life/village/villager_rig.gd")
const Life := preload("res://core/npc/npc_life.gd")

const SPEED := 1.55            ## m/s: a walking pace the wanderer can keep beside
const FAR := 14.0              ## the wanderer further than this: it stops and waits
const GAP := 5.0               ## a foe inside this: it is under attack, it stops
const REACH := 1.9             ## a foe inside this wounds it
const DPS := 1.7               ## hp a second from each foe in reach
const REGEN := 0.6             ## hp a second when nothing is near
const WP_R := 1.1
const DOWN_S := 4.0
const SCAN_S := 0.25
const DEFAULT_RIG := {"seed": 7101, "sex": "m", "age": "adult", "garment": "coat", "hat": "brim", "hair": "short", "beard": "short"}

var quest := ""
var step: Dictionary = {}
var path: Array[Vector2] = []
var next_wp := 1               ## index of the point it walks to
var checkpoint := 0            ## index of the last point reached
var max_hp := 24.0
var hp := 24.0
var down := 0.0                ## seconds until it stands again (> 0 = fallen)
var waiting := false           ## stopped because the wanderer is far
var attacked := 0.0            ## seconds left of "under attack"
var done := false
var falls := 0                 ## times it has fallen (tests)
var walked := 0.0
var foes: Array[Enemy] = []
var rig: Rig
var _frame: Dictionary = {}
var _ambushed := {}
var _scan_t := 0.0
var _gait := 0.0
var _amt := 0.0
var _told_wait := false
var _lantern := false
var _player: Node3D


## Set the step in before adding to the tree. `from` = the checkpoint to stand at.
func setup(qid: String, stp: Dictionary, from := 0) -> void:
	quest = qid
	step = stp
	for p: Variant in stp.get("path", []):
		path.append(p as Vector2)
	max_hp = float(stp.get("hp", 24.0))
	hp = max_hp
	checkpoint = clampi(from, 0, maxi(path.size() - 2, 0))
	next_wp = checkpoint + 1
	name = "Escort_" + qid


func _ready() -> void:
	add_to_group("escort")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var opts: Dictionary = (step.get("rig", DEFAULT_RIG) as Dictionary).duplicate()
	opts["name"] = quest
	rig = Rig.create(opts) as Rig
	add_child(rig)
	_lantern = String(opts.get("l", "")) == "lantern"
	if _lantern:
		var lamp := OmniLight3D.new()
		lamp.name = "LanternLight"
		lamp.light_color = Color(1.0, 0.64, 0.32)
		lamp.light_energy = 0.85
		lamp.omni_range = 5.5
		lamp.omni_attenuation = 1.2
		lamp.shadow_enabled = false
		lamp.position = Vector3(-0.3, 0.9, -0.2)
		lamp.set_meta(&"light_class", &"realm")
		add_child(lamp)
	_frame = Kit.make_frame(String(step.get("label", "Escort")), max_hp)
	add_child(_frame.layer as Node)
	_stand_at(checkpoint)


func _exit_tree() -> void:
	Kit.clear_foes(foes)


func _stand_at(i: int) -> void:
	var p := path[clampi(i, 0, path.size() - 1)]
	global_position = Vector3(p.x, Kit.ground_y(self, p.x, p.y), p.y)
	if i + 1 < path.size():
		var d := path[i + 1] - p
		rotation.y = atan2(-d.x, -d.y)


func ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func _process(delta: float) -> void:
	tick(delta)


## One step of time (the test drives this directly).
func tick(delta: float) -> void:
	if done or path.size() < 2:
		return
	if down > 0.0:
		down -= delta
		if down <= 0.0:
			_revive()
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_S
		_scan(SCAN_S)
	attacked = maxf(attacked - delta, 0.0)
	var pl := _wanderer()
	waiting = pl != null and Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length() > FAR
	if waiting and not _told_wait:
		_told_wait = true
		Events.toast.emit("%s waits for you." % String(step.get("label", "The walker")))
	elif not waiting:
		_told_wait = false
	var moving := not waiting and attacked <= 0.0 and down <= 0.0
	if moving:
		_advance(delta)
	_amt = move_toward(_amt, 1.0 if moving else 0.0, delta * 4.0)
	_pose()
	_show()


func _wanderer() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return _player


func _advance(delta: float) -> void:
	var to := path[next_wp]
	var here := Vector2(global_position.x, global_position.z)
	var d := to - here
	if d.length() <= WP_R:
		_reached(next_wp)
		return
	var sv := d.normalized() * minf(SPEED * delta, d.length())
	var nx := here + sv
	global_position = Vector3(nx.x, Kit.walk_y(self, nx.x, nx.y), nx.y)
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.y), minf(1.0, delta * 6.0))
	walked += sv.length()
	_gait = fposmod(_gait + sv.length() / 1.35, 1.0)


func _reached(i: int) -> void:
	checkpoint = i
	reached.emit(i)
	if i >= path.size() - 1:
		done = true
		Events.toast.emit("%s has come to the end of the road." % String(step.get("label", "The walker")))
		arrived.emit()
		return
	next_wp = i + 1
	var amb: Dictionary = step.get("ambush", {})
	if amb.has(i) and not _ambushed.has(i):
		_ambushed[i] = true
		var a: Dictionary = amb[i]
		var ahead := path[next_wp] - path[i]
		var a0 := atan2(ahead.y, ahead.x) - 0.9
		foes.append_array(Kit.spawn_ring(self, a.get("kinds", ["wretch"]), int(a.get("n", 2)), global_position, 8.0, a0, quest, 1.8))
		Events.toast.emit("Something is in the road ahead.")


func _scan(dt: float) -> void:
	Kit.prune(foes)
	var near := Kit.foes_near(get_tree(), global_position, GAP)
	var hitters := 0
	for e: Enemy in near:
		if Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() < REACH:
			hitters += 1
	if not near.is_empty():
		attacked = 1.5
	if hitters > 0:
		hp = maxf(hp - DPS * dt * float(hitters), 0.0)
	elif near.is_empty():
		hp = minf(hp + REGEN * dt, max_hp)
	if hp <= 0.0:
		_fall()


func _fall() -> void:
	falls += 1
	down = DOWN_S
	rig.visible = false
	Kit.clear_foes(foes)
	_ambushed.erase(checkpoint)
	Events.toast.emit("%s has fallen. They get up again at the last waymark." % String(step.get("label", "The walker")))
	fell.emit(checkpoint)


func _revive() -> void:
	hp = max_hp
	attacked = 0.0
	next_wp = checkpoint + 1
	_stand_at(checkpoint)
	rig.visible = true


func _show() -> void:
	(_frame.bar as ProgressBar).value = hp
	var nm := String(step.get("label", "Escort"))
	(_frame.label as Label).text = nm + ("  (down)" if down > 0.0 else "  (waits)" if waiting else "")


func _pose() -> void:
	var r := rig
	r.reset()
	var drop := Life.walk_legs(r, _gait, _amt, 0.36, 0.88, 0.02 * r.k)
	var sw := cos(TAU * _gait) * _amt * 0.3
	r.q(5, Quaternion(Vector3.RIGHT, -sw))
	r.q(6, Quaternion(Vector3.RIGHT, 0.2))
	if _lantern:
		r.hold(1, Vector3(-0.24, 0.8 + 0.02 * absf(sw), -0.14 + 0.05 * sw) * r.k, Vector3(0, 0, -1), Vector3(0, -1, 0))
	else:
		r.q(8, Quaternion(Vector3.RIGHT, sw))
		r.q(9, Quaternion(Vector3.RIGHT, 0.2))
	if attacked > 0.0:
		r.q(3, Quaternion(Vector3.RIGHT, -0.15))
	rig.position = Vector3(0.0, drop, 0.0)
	r.apply()
	r.update_glow()
