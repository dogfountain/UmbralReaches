extends Interactable
## One of Hearthward's people (village system; no class_name). A VillagerRig driven by a routine
## from village_cast.gd: the village clock picks the routine for the phase of the night (dusk,
## work, midnight, late), and the routine is a loop of steps:
##   {"go": node}                          walk there (VillageNav path: on floors, round buildings)
##   {"act": a, "at": node, "face": xz|"@anchor", "t": [min, max], "seat"?: h, "if"?: cond}
##   {"hide": node|"@home", "t": [min, max]}  walk there and go indoors for a while
##   {"lamps": true}                       the lamplighter's round (each lamp: walk, raise the pole)
## Walking: the rig's legs stride with the distance covered, the arms swing or carry the tool, the
## body turns into the path. The wanderer in the way stops a villager, who looks at you and then
## steps aside if the side is clear; other villagers are waited for. A capsule on Layers.PROPS
## (the player bumps into it, the camera spring arm ignores it) moves with the body.
## Acts are procedural poses on the rig (IK on the hands): hammer at the anvil (sparks, ring, a
## flare on the forge light), heat in the hearth, quench (steam, hiss), grind, chop, dig, kneel,
## pray, sit (on a seat or the ground), doze, warm hands at the fire, chalk circles, garden, mourn,
## knock (three slow knocks), tend a fire, lean on a spade, sell, sift ash, read a notice.
## Animation runs within ACTIVE_R of the camera; past it only the walking logic runs.

const Rig := preload("res://core/life/village/villager_rig.gd")
const VState := preload("res://core/life/village/village_state.gd")
const VAudio := preload("res://core/life/village/village_audio.gd")
const Life := preload("res://core/npc/npc_life.gd")
const Forge := preload("res://core/life/village/villager_forge.gd")
const Idle := preload("res://core/life/village/villager_idle.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
## Acts that carry speech outside a conversation: [cycle s, talking s per cycle, volume dB]
## (the seller calls her wares, people at a fire murmur, the mourner mutters, idlers talk to themselves)
const CHATTY := {"sell": [7.0, 2.4, -9.0], "warm": [11.0, 2.6, -14.0], "mourn": [13.0, 2.0, -17.0], "idle": [19.0, 1.3, -16.0], "chat": [4.2, 2.6, -13.0]}
const B_LID := 15
## gait by age: [thigh swing (rad), swing-phase knee fold (rad), pelvis bob (m), arm swing (rad)]
const GAITS := {"old": [0.26, 0.6, 0.011, 0.16], "child": [0.44, 1.05, 0.024, 0.42], "teen": [0.4, 0.95, 0.02, 0.34], "adult": [0.36, 0.88, 0.02, 0.3]}
## acts that take the body low: eased in and out slowly (sitting down, kneeling, crouching)
const LOW := ["sit", "doze", "kneel", "garden", "bury", "chalk", "tend"]
const WORK := ["hammer", "chop", "dig", "grind"]

const ACTIVE_R := 45.0
const B_ROOT := 0
const B_SPINE := 1
const B_CHEST := 2
const B_HEAD := 3
const B_JAW := 4
const B_ARM_R := 5
const B_FORE_R := 6
const B_ARM_L := 8
const B_FORE_L := 9
const B_THIGH_R := 11
const B_SHIN_R := 12
const B_THIGH_L := 13
const B_SHIN_L := 14

var id := ""
var data := {}
var display_name := ""
var village: Node                     ## the director (village.gd): nav, clock, anchors, lamps, talk
var rig: Rig
var body: AnimatableBody3D
var lamp_light: OmniLight3D
var attend: Node3D                    ## the wanderer, while talking
var speaking := false
var voice := {}                          ## babble (npc_voice.gd): family by sex and age, own pitch from the seed

var routine := ""
var steps: Array = []
var step_i := -1
var step: Dictionary = {}
var state := "idle"                   ## walk / act / hidden / idle
var act := "idle"
var act_t := 0.0
var act_len := 5.0
var at_node := ""
var goal := ""
var hidden := false
var path := PackedVector3Array()
var path_i := 0
var yaw := 0.0
var face_yaw := 0.0
var speed := 1.0
var gait := 0.0
var walk_amt := 0.0
var lamp_queue: Array[String] = []
var lamp_id := ""
var heat := 0.0                       ## the smith's iron (0 cold .. 1 white)
var looked_at := Vector3.INF
var walked := 0.0                     ## metres walked (tests)
# --- quests and visits (quest_world.gd, village.gd) ---
var follow: Variant = null            ## escort: a Node3D to keep behind, or a Vector3 to walk to (off the network)
var follow_gap := 2.6
var follow_wait_r := 16.0             ## a followed Node3D further than this: stop and wait for it
var waiting := false                  ## the escort is waiting for the wanderer to come back
var pinned := false                   ## held where it is (a quest scene): phase changes wait
var visiting: Node3D                  ## the villager this one stands talking with ("%id" faces)
var visited_by: Node3D                ## who has come to talk with this one
var hurry := 1.0                      ## walking speed multiplier (2 when the village runs for cover)
var _fol_stuck := 0.0
var _fol_best := INF
var acts_done := 0                    ## steps finished (tests)

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _stance_c := {}                       ## per-person stance (see _stance)
var _blocked := 0.0
var _side := 0.0
var _side_to := 0.0
var _look := Vector2.ZERO
var _look_to := Vector2.ZERO
var _look_t := 0.0
var _beat := -1
var _player: Node3D
var _seat := 0.0
var _hide_len := 0.0
var _fade := 1.0
var _was_active := true
var life: Life
var _pose_acc := 0.0
var _dip := 0.0                       ## knee give on a blow (hammer, axe), set by the work poses
var _foot_push := 0.0                 ## the digger's boot on the spade (0..1)
var _gait := [0.36, 0.88, 0.02, 0.3]
var _pdt := 0.0
var _shift_z := 0.0                   ## the body stepped forward (the smith leaning into the barrel)
var _shift_x := 0.0                   ## the hips' sideways shift over the standing foot (villager_idle.gd)
var _turn_on := false                 ## the feet are shuffling round a turn on the spot (npc_life.gd turn_legs)
var _gest := 0.0                      ## which hand has the word: +1 right, -1 left, eased
var _pass_t := 0.0
var _pass := Vector3.INF              ## a villager walking by, whom the eye follows


func setup(vid: String, d: Dictionary, director: Node) -> void:
	id = vid
	data = d.duplicate(true)
	# danger: into the Keg (camped-out and fearless people stay where they are)
	if not data.has("camp") and not bool(data.get("fearless", false)) and not (data.routines as Dictionary).has("flee"):
		(data.routines as Dictionary)["flee"] = [{"hide": "keg_in", "t": [40.0, 70.0]}]
	village = director
	display_name = String(d.get("name", vid))
	name = "Villager_" + vid
	speed = float(d.get("speed", 1.0))
	_rng.seed = hash(vid)
	_t = _rng.randf() * 10.0
	life = Life.new(hash(vid))
	var rd: Dictionary = d.get("rig", {})
	voice = Voice.profile(Voice.family_of(String(rd.get("sex", "m")), String(rd.get("age", "adult"))), int(rd.get("seed", hash(vid))))
	_gait = GAITS.get(String((d.get("rig", {}) as Dictionary).get("age", "adult")), GAITS["adult"])


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # r36 smooth: moved in _process, drawn as set (interpolated, it judders between ticks)
	add_to_group(Groups.INTERACTABLE)
	add_to_group("villager")
	var opts: Dictionary = (data.rig as Dictionary).duplicate()
	opts["name"] = id
	rig = Rig.create(opts) as Rig
	add_child(rig)
	body = AnimatableBody3D.new()
	body.name = "Body"
	body.sync_to_physics = false
	body.collision_layer = Layers.PROPS
	body.collision_mask = 0
	body.set_meta("villager", id)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var tall: float = rig.head_top()
	cap.radius = 0.24 if tall > 1.3 else 0.18
	cap.height = tall
	cs.shape = cap
	cs.position = Vector3(0, tall * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	if bool(data.get("light", false)) and rig.glow != null:
		lamp_light = OmniLight3D.new()
		lamp_light.name = "LanternLight"
		lamp_light.light_color = Color(1.0, 0.64, 0.32)
		lamp_light.light_energy = 2.0
		lamp_light.omni_range = 6.5
		lamp_light.omni_attenuation = 1.2
		lamp_light.shadow_enabled = false
		lamp_light.set_meta(&"light_class", &"realm")
		lamp_light.distance_fade_enabled = true
		lamp_light.distance_fade_begin = 40.0
		lamp_light.distance_fade_length = 10.0
		add_child(lamp_light)


# --- talking ------------------------------------------------------------------------------------

func can_interact() -> bool:
	return not hidden and village != null and village.has_method("talk")


func interact_text() -> String:
	var verb := "Trade with" if bool(data.get("trader", false)) else "Talk to"
	return "[%s]  %s %s" % [Interactable.prompt_key(), verb, display_name]


func interact_reach() -> float:
	return 2.4


func interact(by: Node) -> void:
	if not can_interact():
		return
	if by is Node3D:
		var d := (by as Node3D).global_position - global_position
		if Vector2(d.x, d.z).length() > 0.1:
			yaw = atan2(-d.x, -d.z)
			rotation.y = yaw
	attend = by as Node3D
	_pose(0.0)
	village.call("talk", self, by)


# --- the routine --------------------------------------------------------------------------------

## Start the routine for this phase of the night (called by the director; also on spawn).
func begin(rname: String, place := false) -> void:
	var rs: Dictionary = data.get("routines", {})
	if not rs.has(rname):
		return
	routine = rname
	steps = rs[rname]
	step_i = -1
	if place:
		# spawn straight at the first stop, mid-task
		var first := _first_stop()
		if first != "" and village.nav.has(first):
			_place(first)
	_next_step()
	if place and state == "act":
		act_t = _rng.randf() * act_len * 0.7


func _first_stop() -> String:
	for s: Dictionary in steps:
		if s.has("if") and not VState.test(String(s["if"]), VState.world(get_tree()), get_tree()):
			continue
		if s.has("at"):
			return String(s.at)
		if s.has("go"):
			return String(s.go)
		if s.has("hide"):
			return _resolve(String(s.hide))
		if s.has("lamps"):
			var ls: Array[String] = village.call("round_lamps")
			if not ls.is_empty():
				return String(village.call("lamp_spot", ls[0]))
	return String(data.get("home", ""))


func _place(node: String) -> void:
	var p: Vector3 = village.nav.at(node)
	global_position = p
	at_node = node
	path = PackedVector3Array()
	state = "idle"


func _resolve(node: String) -> String:
	if node == "@home":
		var hw: Dictionary = data.get("home_when", {})
		for cond: String in hw:
			if VState.test(cond, VState.world(get_tree()), get_tree()):
				return String(hw[cond])
		return String(data.get("home", ""))
	return node


func _next_step() -> void:
	_visit_end()
	if steps.is_empty():
		state = "idle"
		return
	for _guard in steps.size() + 1:
		step_i = (step_i + 1) % steps.size()
		step = steps[step_i]
		if step.has("if") and not VState.test(String(step["if"]), VState.world(get_tree()), get_tree()):
			continue
		break
	_start_step()


func _start_step() -> void:
	acts_done += 1
	if step.has("lamps"):
		lamp_queue = village.call("round_lamps")
		_next_lamp()
		return
	if step.has("go"):
		_walk_to(String(step.go))
		return
	if step.has("hide"):
		_walk_to(_resolve(String(step.hide)))
		return
	if step.has("at"):
		_walk_to(String(step.at))


func _next_lamp() -> void:
	while not lamp_queue.is_empty():
		lamp_id = lamp_queue.pop_front()
		if not bool(village.call("lamp_needs", lamp_id)) and _rng.randf() < 0.7:
			continue
		_walk_to(String(village.call("lamp_spot", lamp_id)))
		return
	lamp_id = ""
	# the round is done: rest for what is left of the phase
	var after := String(data.get("schedule", {}).get("late", "rest"))
	if (data.get("routines", {}) as Dictionary).has("rest"):
		after = "rest"
	begin(after)


func _walk_to(node: String) -> void:
	goal = node
	if at_node == node or not village.nav.has(node):
		_arrived()
		return
	var from := at_node if at_node != "" and village.nav.has(at_node) else String(village.nav.nearest(global_position))
	path = village.nav.path(from, node)
	if path.size() < 2:
		# unreachable: jump there unseen rather than walk through a wall
		_place(node)
		_arrived()
		return
	path_i = 1
	state = "walk"
	at_node = ""
	_blocked = 0.0


func _arrived() -> void:
	at_node = goal
	path = PackedVector3Array()
	if step.has("lamps"):
		act = "light"
		act_len = 3.2
		act_t = 0.0
		state = "act"
		face_yaw = _yaw_to(village.call("lamp_pos", lamp_id))
		return
	if step.has("hide"):
		state = "hidden"
		_hide_len = _len(step.get("t", [20.0, 30.0]))
		act_t = 0.0
		_set_hidden(true)
		return
	if step.has("act"):
		act = String(step.act)
		act_len = _len(step.get("t", [5.0, 8.0]))
		act_t = 0.0
		_seat = float(step.get("seat", 0.45))
		state = "act"
		_beat = -1
		var f: Variant = step.get("face", null)
		var target := Vector3.INF
		_visit_end()
		if f is Vector2:
			target = Vector3((f as Vector2).x, global_position.y, (f as Vector2).y)
		elif f is String and String(f).begins_with("%"):
			# a visit: face that villager, and it turns to us while we talk
			var other: Node3D = (village.get("villagers") as Dictionary).get(String(f).substr(1))
			if other and is_instance_valid(other) and not bool(other.get("hidden")) and other.global_position.distance_to(global_position) < 7.0:
				target = other.global_position
				visiting = other
				if other.get("visited_by") == null:
					other.set("visited_by", self)
		elif f is String:
			target = village.call("anchor", String(f))
		if target != Vector3.INF:
			face_yaw = _yaw_to(target)
		else:
			face_yaw = yaw
		return
	_next_step()


func laugh_soon() -> void:
	get_tree().create_timer(randf_range(0.25, 0.6), false).timeout.connect(func() -> void:
		if is_inside_tree() and not hidden:
			Voice.laugh_at(self, voice, -14.0, 16.0))


func _visit_end() -> void:
	if visiting and is_instance_valid(visiting) and visiting.get("visited_by") == self:
		visiting.set("visited_by", null)
	visiting = null


func _len(r: Variant) -> float:
	if r is Array and (r as Array).size() >= 2:
		return _rng.randf_range(float(r[0]), float(r[1]))
	return 6.0


func _yaw_to(p: Vector3) -> float:
	var d := p - global_position
	return atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.05 else yaw


func _set_hidden(on: bool) -> void:
	hidden = on
	visible = not on
	for c in body.get_children():
		(c as CollisionShape3D).disabled = on
	if lamp_light:
		lamp_light.visible = not on


## True while the step must not be cut short by a phase change.
func busy() -> bool:
	return pinned or follow != null or state == "hidden" or (state == "act" and act in ["light", "knock", "quench"])


## Stop where it stands and do `a` (kneel, mourn, idle...) facing `face` until released (quests).
func hold(a: String, face: Vector3, len := 1.0e6) -> void:
	pinned = true
	follow = null
	path = PackedVector3Array()
	at_node = ""
	state = "act"
	act = a
	act_t = 0.0
	act_len = len
	_seat = 0.0
	if face != Vector3.INF:
		face_yaw = _yaw_to(face)


func release() -> void:
	pinned = false
	follow = null
	waiting = false


# --- per frame ----------------------------------------------------------------------------------

var _far_acc := 0.0                ## frame time saved up while stepping every fourth frame (far from the camera)


func _process(delta: float) -> void:
	if village == null:
		return
	# past 55 m a villager is a few pixels: his routine steps every fourth frame with the time saved up (30 a second
	# at 120 fps; a walker moves 4 cm a step). 32 of them were 0.2 ms of every frame of a fight two fields away.
	# A follower too (the roads' travellers walk after their leader): an escort keeps by the wanderer, inside 55 m.
	if attend == null:
		var cam := get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_squared_to(global_position) > 3025.0:
			_far_acc += delta
			if (Engine.get_process_frames() + get_instance_id()) % 4 != 0:
				return
			delta = _far_acc
		_far_acc = 0.0
	var dt := delta * float(village.get("time_scale"))
	_t += dt
	if attend != null:
		_pose(delta)
		return
	if follow != null:
		_follow(dt)
	else:
		_step_state(dt)
	if state != "walk" and follow == null:
		walk_amt = move_toward(walk_amt, 0.0, dt * 3.0)
		yaw = lerp_angle(yaw, face_yaw, minf(1.0, dt * 4.0))
	_after_step(dt)


func _step_state(dt: float) -> void:
	match state:
		"walk":
			_walk(dt)
		"act":
			act_t += dt
			_act_events(dt)
			if act_t >= act_len:
				if act == "light":
					village.call("light_lamp", lamp_id)
					_next_lamp()
				else:
					_next_step()
		"hidden":
			act_t += dt
			if act_t >= _hide_len:
				_set_hidden(false)
				_next_step()


func _after_step(dt: float) -> void:
	rotation.y = yaw
	if lamp_light and rig.glow != null:
		lamp_light.global_position = (rig.glow as Node3D).global_position + Vector3.UP * 0.05
		lamp_light.light_energy = 0.8 + 0.08 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0)
	if hidden:
		return
	# pose at a rate for the distance (npc_life.gd): every frame close by, 30/20/12 Hz further,
	# 2 Hz off screen, frozen past Life.FREEZE_R unless walking (then 5 Hz)
	var cam := get_viewport().get_camera_3d()
	var iv := Life.interval_keg(cam, global_position, false, state == "walk")
	_pose_acc += dt
	var active := iv >= 0.0
	if active and _pose_acc >= iv:
		# r30: each pose is eased in over the interval until the next (npc_life.gd blend_*), so the
		# legs no longer step at 12 Hz under a root that moves every frame
		if life:
			life.blend_from(rig)
		_pose(_pose_acc)
		_pose_acc = 0.0
		if life:
			life.blend_to(rig, iv)
	elif active and life:
		life.blend_step(rig, _pose_acc)
	_was_active = active


func _player_pos() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return _player.global_position if _player else Vector3.INF


func _walk(dt: float) -> void:
	if path_i >= path.size():
		_arrived()
		return
	var target := path[path_i]
	var here := global_position
	var to := target - here
	var flat := Vector2(to.x, to.z)
	var dir := Vector3(to.x, 0, to.z).normalized() if flat.length() > 0.001 else Vector3.FORWARD
	# the wanderer (or another villager) in the way: stop, look, then step aside if it is clear
	var block := _blocker(dir)
	if block != Vector3.INF:
		_blocked += dt
		looked_at = block
		walk_amt = move_toward(walk_amt, 0.0, dt * 4.0)
		if _blocked > 0.9 and _side_to == 0.0:
			var side := dir.cross(Vector3.UP).normalized()
			var rel := block - here
			var s := -signf(side.dot(rel)) if absf(side.dot(rel)) > 0.05 else 1.0
			if village.nav.clear(here + side * s * 0.75):
				_side_to = s * 0.75
		if _side_to == 0.0 or _blocked < 0.9:
			yaw = lerp_angle(yaw, _yaw_to(block), minf(1.0, dt * 3.0))
			return
	else:
		_blocked = 0.0
		looked_at = Vector3.INF
	var v := speed * hurry * (0.55 if walk_amt < 0.5 else 1.0)
	walk_amt = move_toward(walk_amt, 1.0, dt * 2.5)
	var step_len := v * dt if walk_amt >= 0.3 else 0.0         # not before the stride is under him
	walked += step_len
	var stride := Life.calib_stride(rig, float(_gait[0]), float(_gait[1]), float(_gait[2]) * rig.k)
	gait = fposmod(gait + step_len / (stride * maxf(walk_amt, 0.35)), 1.0)
	# along the path; a sidestep offset eases in and back out
	_side = move_toward(_side, _side_to, dt * 1.2)
	if _blocked == 0.0 and _side_to != 0.0:
		var pp := _player_pos()
		if pp == Vector3.INF or pp.distance_to(here) > 2.6 or (pp - here).dot(dir) < -0.3:
			_side_to = 0.0
	var base := here - dir.cross(Vector3.UP).normalized() * _side
	var left := Vector2(target.x - base.x, target.z - base.z).length()
	if step_len >= left:
		base = target
		path_i += 1
	else:
		base += dir * step_len
		base.y = lerpf(base.y, target.y, clampf(step_len / maxf(left, 0.001), 0.0, 1.0))
	var np := base + dir.cross(Vector3.UP).normalized() * _side
	if absf(_side) > 0.05 and (not village.nav.clear_ex(np, [body.get_rid()] as Array[RID]) or absf(float(village.nav.floor_at(np.x, np.z)) - base.y) > 0.3):
		# the sidestep would carry it into something (the ash-wife's cart): back onto the path
		_side_to = 0.0
		_side = move_toward(_side, 0.0, dt * 3.0)
		np = base + dir.cross(Vector3.UP).normalized() * _side
	np = _separated(np, dt)
	global_position = np
	var want := atan2(-dir.x, -dir.z)
	yaw = lerp_angle(yaw, want, minf(1.0, dt * 5.0))
	if path_i >= path.size():
		global_position = path[path.size() - 1]
		_side = 0.0
		_side_to = 0.0
		_arrived()


## Escort / leave-taking: walk after `follow` (a Node3D, kept `follow_gap` behind; or a Vector3)
## over open ground, off the walking network: ground from the floor probe, solid things steered
## round (straight, then 35 and 70 degrees either side). Waits when the followed one runs off; if it
## is stuck out of sight for long, it catches up unseen (never in view of the camera).
func _follow(dt: float) -> void:
	var tgt: Vector3
	var person := follow is Node3D
	if person:
		if not is_instance_valid(follow):
			follow = null
			return
		tgt = (follow as Node3D).global_position
	else:
		tgt = follow
	var here := global_position
	var to := Vector3(tgt.x - here.x, 0.0, tgt.z - here.z)
	var dist := to.length()
	var gap := follow_gap if person else 0.15
	waiting = person and dist > follow_wait_r
	var v := 0.0
	if dist > gap and not waiting:
		v = clampf((dist - gap) * 1.2, 0.35, speed * hurry * (2.0 if dist > gap + 5.0 else 1.2))
	if v > 0.0:
		var dir := to / dist
		var moved := false
		for ang: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
			var d2 := dir.rotated(Vector3.UP, ang)
			var nx := here + d2 * v * dt
			var y: float = village.nav.floor_at(nx.x, nx.z)
			if absf(y - here.y) > 0.6 or not village.nav.clear_ex(Vector3(nx.x, y, nx.z), [body.get_rid()] as Array[RID]):
				continue
			global_position = Vector3(nx.x, y, nx.z)
			yaw = lerp_angle(yaw, atan2(-d2.x, -d2.z), minf(1.0, dt * 5.0))
			walked += v * dt
			var stride := Life.calib_stride(rig, float(_gait[0]), float(_gait[1]), float(_gait[2]) * rig.k)
			gait = fposmod(gait + v * dt / (stride * maxf(walk_amt, 0.35)), 1.0)
			moved = true
			break
		walk_amt = move_toward(walk_amt, 1.0 if moved else 0.0, dt * 2.5)
		state = "walk" if moved else "idle"
		# stuck (a wall, a drop): after a while out of view, catch up unseen
		if dist < _fol_best - 0.3:
			_fol_best = dist
			_fol_stuck = 0.0
		else:
			_fol_stuck += dt
		if _fol_stuck > 4.0 and dist > gap + 3.0:
			var cam := get_viewport().get_camera_3d()
			var behind := tgt - dir * gap
			if cam == null or not cam.is_position_in_frustum(here + Vector3.UP) and not cam.is_position_in_frustum(behind + Vector3.UP):
				global_position = Vector3(behind.x, village.nav.floor_at(behind.x, behind.z), behind.z)
				_fol_stuck = 0.0
				_fol_best = INF
	else:
		walk_amt = move_toward(walk_amt, 0.0, dt * 3.0)
		state = "idle"
		_fol_best = INF
		_fol_stuck = 0.0
		if person:
			yaw = lerp_angle(yaw, _yaw_to(tgt), minf(1.0, dt * 3.0))
	looked_at = tgt + Vector3.UP * 1.5 if person else Vector3.INF


## Separation: a walker eases away from any other villager closer than SEP_R so two people never
## stand inside one another. The push is recomputed at SEP_HZ (a scan of the group, nothing more) and
## applied each frame; a step into something solid is dropped.
const SEP_R := 0.7
const SEP_HZ := 10.0
const SEP_SPEED := 0.9
var _sep := Vector3.ZERO
var _sep_t := 0.0


func _separated(np: Vector3, dt: float) -> Vector3:
	_sep_t -= dt
	if _sep_t <= 0.0:
		_sep_t = 1.0 / SEP_HZ + _rng.randf() * 0.02       # staggered across villagers
		_sep = Vector3.ZERO
		for v: Node in get_tree().get_nodes_in_group("villager"):
			if v == self or not (v is Node3D) or bool(v.get("hidden")):
				continue
			var d := np - (v as Node3D).global_position
			d.y = 0.0
			var l := d.length()
			if l < SEP_R:
				_sep += (d / l if l > 0.01 else Vector3.RIGHT.rotated(Vector3.UP, _rng.randf() * TAU)) * (SEP_R - l) / SEP_R
	if _sep == Vector3.ZERO:
		return np
	var moved := np + _sep.limit_length(1.0) * SEP_SPEED * dt
	var y: float = village.nav.floor_at(moved.x, moved.z)
	if absf(y - np.y) > 0.3 or not village.nav.clear_ex(Vector3(moved.x, y, moved.z), [body.get_rid()] as Array[RID]):
		return np
	moved.y = np.y
	return moved


func _blocker(dir: Vector3) -> Vector3:
	var here := global_position
	var pp := _player_pos()
	if pp != Vector3.INF:
		var rel := pp - here
		rel.y = 0.0
		if rel.length() < 1.45 and rel.normalized().dot(dir) > 0.25:
			return pp
	for v: Node in get_tree().get_nodes_in_group("villager"):
		if v == self or not (v is Node3D) or bool(v.get("hidden")):
			continue
		var r2 := (v as Node3D).global_position - here
		r2.y = 0.0
		if r2.length() < 0.95 and r2.normalized().dot(dir) > 0.5 and String(v.get("state")) != "walk":
			return (v as Node3D).global_position
	return Vector3.INF


func _act_events(dt: float) -> void:
	match act:
		"chat":
			# now and then the talk breaks into a laugh, both of them (camera close only)
			if _rng.randf() < dt / 24.0:
				Voice.laugh_at(self, voice, -13.0, 16.0)
				if visiting and is_instance_valid(visiting) and visiting.has_method("laugh_soon"):
					visiting.call("laugh_soon")
		"hammer":
			var beat := int(act_t / 0.95)
			if beat != _beat and fmod(act_t, 0.95) > 0.62:
				_beat = beat
				village.call("strike", self)
			heat = maxf(heat - 0.07 * dt, 0.25)
		"heat":
			heat = minf(1.0, heat + 0.22 * dt)
		"quench":
			if _beat < 0 and act_t > act_len * 0.35:
				_beat = 0
				heat = 0.0
				village.call("quench", self)
		"grind":
			var b2 := int(act_t / 0.45)
			if b2 != _beat:
				_beat = b2
				if _rng.randf() < 0.6:
					village.call("grind_sparks", self)
		"chop":
			var b3 := int(act_t / 1.7)
			if b3 != _beat and fmod(act_t, 1.7) > 1.0:
				_beat = b3
				village.call("chop", self)
		"dig":
			var b4 := int(act_t / 3.0)
			if b4 != _beat and fmod(act_t, 3.0) > 0.95:
				_beat = b4
				village.call("dig", self)
		"knock":
			var b5 := int((act_t - 1.2) / 1.4)
			if act_t > 1.2 and b5 != _beat and b5 < 3 and fmod(act_t - 1.2, 1.4) > 0.25:
				_beat = b5
				VAudio.play("knock", global_position + _fwd() * 0.8 + Vector3.UP * 1.3, -4.0, 0.92)


## The fire this villager tends: their own outpost's (r34: "@fire_<id>"), else the hermit's.
func _fire_anchor() -> Vector3:
	var own: Vector3 = village.call("anchor", "@fire_" + id)
	return own if own != Vector3.INF else village.call("anchor", "@fire")


func _fwd() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


# =====================================================================================================
# posing
# =====================================================================================================

func _m(world: Vector3) -> Vector3:
	return (rig as Node3D).global_transform.affine_inverse() * world


## Talking to no one in particular (CHATTY acts), never during a conversation with the wanderer:
## the dialogue box voices them then.
func _chatting() -> bool:
	if speaking or state != "act":
		return false
	if visited_by != null and is_instance_valid(visited_by) and String(visited_by.get("act")) == "chat":
		# answering a visitor: talk in the visitor's pauses
		return fmod(_t + float(hash(id) % 97), 4.2) >= 2.6
	if not CHATTY.has(act):
		return false
	var c: Array = CHATTY[act]
	return fmod(_t + float(hash(id) % 97), float(c[0])) < float(c[1])


func _pose(dt: float) -> void:
	var r := rig
	_pdt = dt
	_shift_x = 0.0
	_shift_z = 0.0
	var k: float = r.k
	r.reset()
	var off := 0.0
	var old := String((data.rig as Dictionary).get("age", "")) == "old"
	if life == null:
		life = Life.new(hash(id))
	life.breath_rate = lerpf(life.breath_rate, 1.7 if (state == "act" and act in WORK) else 1.0, minf(1.0, dt * 0.3))
	var chat := _chatting()
	life.step(dt, speaking or chat)
	if chat:
		Voice.chatter(self, life, voice, float((CHATTY.get(act, CHATTY.chat) as Array)[2]))
	_dip = 0.0
	var breath: float = (life.breath() - 0.5) * 0.026 * life.breath_rate
	var stoop := 0.16 if old else 0.0
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -stoop * 0.4))
	r.q(B_CHEST, Quaternion(Vector3.RIGHT, -stoop * 0.6 + breath))
	var head_pitch := stoop * 0.7
	var tool_r := String((data.rig as Dictionary).get("r", ""))
	var tool_l := String((data.rig as Dictionary).get("l", ""))
	var arms_free := [true, true]
	var look_target := looked_at
	var cur := act if state == "act" else ("idle" if state != "walk" else "walk")
	if attend != null:
		cur = "attend"
		look_target = attend.global_position + Vector3.UP * 1.5
	elif visiting != null and is_instance_valid(visiting) and state == "act":
		look_target = visiting.global_position + Vector3.UP * 1.45
	elif visited_by != null and is_instance_valid(visited_by) and looked_at == Vector3.INF:
		look_target = visited_by.global_position + Vector3.UP * 1.45
	match cur:
		"sit", "doze":
			off = _pose_sit(k, _seat, cur == "doze")
			arms_free = [false, false]
			head_pitch += 0.55 if cur == "doze" else 0.12
			head_pitch += Idle.sit_life(self, cur == "doze")
		"kneel", "garden", "bury":
			off = _pose_kneel(k)
			if cur == "kneel":
				_hands_clasped(k, Vector3(0, 1.06, -0.17) * k)
				head_pitch += 0.32 if routine != "pray" else -0.05
				# at prayer the body sways in and out, and now and then bows low (a still kneeler is a stump at 15 m)
				var bow := fposmod(_t * 0.11 + float(hash(id) % 5) * 0.2, 1.0)
				var bowed := smoothstep(0.0, 0.1, bow) * (1.0 - smoothstep(0.16, 0.3, bow))
				r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.1 * sin(_t * 0.9) - 0.5 * bowed))
				r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.RIGHT, -0.06 * sin(_t * 0.9 + 0.5) - 0.25 * bowed))
				head_pitch += 0.3 * bowed
			else:
				var ph := _t * 2.2
				# the back rocks with each stroke of the hands (a gardener bent over a bed reads by his back at 15 m)
				r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.45 - 0.12 * sin(ph)) * Quaternion(Vector3.UP, 0.1 * sin(ph * 0.5)))
				r.q(B_CHEST, Quaternion(Vector3.RIGHT, -0.25 - 0.06 * sin(ph)))
				var g := -off / Rig.SCALE
				r.arm_to("r", Vector3(0.12, g + 0.06 + 0.13 * maxf(0.0, sin(ph)), -0.5 - 0.06 * sin(ph)) * Vector3(1, 1, k), Vector3(0.8, -0.3, 0.4), null)
				r.arm_to("l", Vector3(-0.12, g + 0.06 + 0.13 * maxf(0.0, -sin(ph)), -0.48 - 0.06 * sin(ph)) * Vector3(1, 1, k), Vector3(-0.8, -0.3, 0.4), null)
				head_pitch += 0.45
			arms_free = [false, false]
		"chalk", "tend":
			off = _pose_crouch(k)
			arms_free = [false, true]
			var g2 := -off / Rig.SCALE
			if cur == "chalk":
				var a := _t * 2.6
				r.arm_to("r", Vector3((0.1 + 0.2 * cos(a)) * k, g2 + 0.07, (-0.38 + 0.17 * sin(a)) * k), Vector3(0.8, -0.2, 0.3), null)
				# the whole back draws the circle: the crouched body leans round with the arm
				r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.FORWARD, 0.1 * cos(a)) * Quaternion(Vector3.RIGHT, -0.06 * sin(a)))
				head_pitch += 0.55
			else:
				var fire: Vector3 = _m(_fire_anchor())
				var poke := 0.15 * sin(_t * 2.4)
				r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.14 * sin(_t * 2.4 + 0.6)) * Quaternion(Vector3.UP, 0.08 * sin(_t * 0.8)))     # the whole crouch works the poker
				r.hold(0, Vector3(0.16, g2 + 0.45, -0.22) * Vector3(k, 1, k), (fire - Vector3(0.16, g2 + 0.45, -0.22)).normalized() * -1.0 + Vector3(0, 0, -poke), Vector3(0, 0, -1))
				arms_free = [false, true]
				head_pitch += 0.4
		"warm" when tool_l == "lantern" or tool_r in ["pole", "staff", "crook", "spade", "candle"]:
			head_pitch += 0.12          # hands full: just stands to the fire (the shoulders still turn with the heat)
			Idle.warm_turn(self)
		"warm":
			Idle.warm(self, k, stoop)
			arms_free = [false, false]
			head_pitch += 0.15
		"chat":
			# standing talk: weight on one hip, the free hand opening on the stressed words
			if chat and tool_r in ["", "chalk", "hammer", "axe", "scoop"]:
				var bt0: float = life.beat()
				r.arm_to("l", Vector3(-0.17, 0.96 + 0.1 * bt0, -0.3 - 0.07 * bt0) * k, Vector3(-0.9, -0.6, 0.2), Quaternion(Vector3.FORWARD, -0.6 - 0.5 * bt0) * Quaternion(Vector3.RIGHT, -0.4))
				arms_free[1] = false
				head_pitch += 0.05 * bt0
			r.q(B_SPINE, Quaternion(Vector3.FORWARD, 0.03 * sin(_t * 0.4)) * Quaternion(Vector3.RIGHT, -stoop * 0.4))
		"watch":
			head_pitch += Idle.watch(self)
		"look_up":
			r.q(B_CHEST, Quaternion(Vector3.RIGHT, 0.08))
			head_pitch -= 0.5
			_hands_clasped(k, Vector3(0, 0.88, -0.15) * k)
			arms_free = [false, false]
		"mourn":
			head_pitch += 0.45 + 0.12 * sin(_t * 0.6)
			_hands_clasped(k, Vector3(0, 0.82, -0.14) * k)
			# the grief shows in the back: slow heaves and a sag, a shoulder shuddering now and then
			var heave := sin(_t * 1.1)
			r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -0.12 - 0.05 * heave))
			r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, 0.03 * sin(_t * 8.0) * maxf(0.0, sin(_t * 0.37))) * Quaternion(Vector3.RIGHT, -0.08 * heave))
			arms_free = [false, false]
		"read":
			head_pitch += 0.05
			r.arm_to("r", Vector3(0.14, 1.22 + 0.02 * sin(_t * 0.7), -0.46) * k, Vector3(0.9, -0.5, 0.3), null)
			arms_free[0] = false
		"knock":
			var kt := act_t - 1.2
			var kb := fposmod(kt, 1.4)
			var reach := 0.0
			if kt > 0.0 and kt < 4.2:
				reach = 0.17 * exp(-pow((kb - 0.3) * 9.0, 2.0))
			if kt < 4.6:
				r.arm_to("r", Vector3(0.12, 1.32 + 0.4 * reach, -0.4 - reach) * k, Vector3(0.9, -0.6, 0.3), null)
				r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -1.6 * reach))     # the body goes into each knock
				arms_free[0] = false
			head_pitch += 0.1 if kt < 4.6 else 0.3
		"draw_water":
			var ph2 := _t * 1.4
			var hr := 1.3 - 0.4 * fposmod(ph2, 1.0)
			var hl := 1.3 - 0.4 * fposmod(ph2 + 0.5, 1.0)
			r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.06 + 0.16 * sin(ph2 * TAU)))
			r.arm_to("r", Vector3(0.05, hr, -0.38) * k, Vector3(0.8, -0.5, 0.3), null)
			r.arm_to("l", Vector3(-0.05, hl, -0.36) * k, Vector3(-0.8, -0.5, 0.3), null)
			arms_free = [false, false]
			head_pitch += 0.2
		"hammer":
			_pose_hammer(k)
			arms_free = [false, false]
			head_pitch += 0.35
		"heat":
			Forge.heat(self, k)
			arms_free = [false, true]
			head_pitch += 0.3
		"quench":
			Forge.quench(self, k)
			arms_free = [false, true]
			head_pitch += 0.35
		"grind":
			Forge.grind(self, k)
			arms_free = [false, false]
			head_pitch += 0.35
		"chop":
			_pose_chop(k)
			arms_free = [false, false]
			head_pitch += 0.25
		"dig":
			_pose_dig(k)
			arms_free = [false, false]
			head_pitch += 0.3
		"lean":
			_pose_lean(k)
			arms_free = [false, false]
			head_pitch += 0.25
		"light":
			_pose_light(k)
			arms_free[0] = false
			head_pitch -= 0.45
		"sift", "sell":
			if cur == "sift":
				var a3 := _t * 2.6
				r.hold(0, Vector3(0.12 + 0.1 * cos(a3), 0.9 + 0.03 * sin(a3 * 2.0), -0.4 + 0.08 * sin(a3)) * k, Vector3(0, -0.4, -1), Vector3(0, -1, 0.3))
				r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.22 - 0.06 * sin(a3)))
				arms_free[0] = false
				head_pitch += 0.35
			else:
				# the stall: arranging the wares (bent to the board, a hand moving goods from one side to the other, the other
				# straightening them) for a while, then straightened up and calling the wanderer over with the whole arm
				var pp := _player_pos()
				var near_p := pp != Vector3.INF and pp.distance_to(global_position) < 6.0
				var ph2 := fposmod(act_t, 7.0)
				if near_p and ph2 > 3.6:
					look_target = pp + Vector3.UP * 1.5
					var beck := 0.5 + 0.5 * sin(_t * 3.4)
					r.hold(0, Vector3(0.22 + 0.08 * beck, 1.12 + 0.14 * beck, -0.3) * k, Vector3(0, 0.3, -1), Vector3(0, -1, 0))
					r.q(B_CHEST, Quaternion(Vector3.RIGHT, 0.06))
				else:
					var sw := sin(_t * 1.1)
					r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.3 * (0.6 + 0.4 * sin(_t * 0.8))))
					r.hold(0, Vector3(0.15 + 0.2 * sw, 0.86 + 0.06 * maxf(0.0, sin(_t * 2.2)), -0.44) * k, Vector3(0, -0.6, -1), Vector3(0, -1, 0))
					r.arm_to("l", Vector3(-0.15 - 0.12 * sw, 0.86, -0.4) * k, Vector3(-0.9, -0.5, 0.3), null)
					arms_free[1] = false
					head_pitch += 0.3
				arms_free[0] = false
	# walking legs (and arms that carry nothing in particular)
	if cur in ["walk", "idle", "attend", "watch", "warm", "look_up", "mourn", "read", "knock", "chat", "draw_water", "light", "sell", "sift", "hammer", "heat", "quench", "grind", "chop", "dig", "lean"]:
		off += _legs_walk(k, walk_amt)
	if arms_free[0] or arms_free[1]:
		_arms_carry(k, tool_r, tool_l, arms_free)
	# speaking: the free hands open and rise on the stressed words, the head nods with them, the body leans in to
	# the listener on the beat and the hands trade the word between them (right on one, left on the next)
	_gest = lerpf(_gest, (1.0 if (life.words & 1) == 1 else -1.0) if speaking else 0.0, minf(1.0, dt * 4.0))
	if speaking:
		var bt: float = life.beat()
		head_pitch += 0.1 * bt - 0.02
		var gs := _gest
		var lean_in := 0.035 + 0.05 * bt
		r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.RIGHT, -lean_in * 0.5))
		r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.06 * gs * (0.4 + bt)) * Quaternion(Vector3.RIGHT, -lean_in))
		var free_r: bool = arms_free[0] and tool_r in ["", "chalk"]
		var free_l: bool = arms_free[1] and tool_l == ""
		if free_r:
			r.arm_to("r", Vector3(0.16, 0.98 + 0.1 * bt + (0.06 * gs if free_l else 0.0), -0.3 - 0.08 * bt - (0.04 * gs if free_l else 0.0)) * k, Vector3(0.9, -0.6, 0.2), Quaternion(Vector3.FORWARD, 0.6 + 0.5 * bt) * Quaternion(Vector3.RIGHT, -0.4))
		if free_l:
			r.arm_to("l", Vector3(-0.16, 0.98 + 0.1 * bt - (0.06 * gs if free_r else 0.0), -0.3 - 0.08 * bt + (0.04 * gs if free_r else 0.0)) * k, Vector3(-0.9, -0.6, 0.2), Quaternion(Vector3.FORWARD, -0.6 - 0.5 * bt) * Quaternion(Vector3.RIGHT, -0.4))
	if cur in ["idle", "watch", "attend", "warm", "look_up", "read", "knock", "chat", "sell"] and walk_amt < 0.1 and not _turn_on:
		# standing is never still (villager_idle.gd): the weight from foot to foot, the look-around, and now and then a larger gesture
		head_pitch += Idle.stand(self, k, arms_free[0] and tool_r == "", arms_free[1] and tool_l == "", breath)
	if cur == "warm" and state == "act" and tool_l != "lantern":
		Idle.stamp(self)
	if _foot_push > 0.001 and cur == "dig":
		r.q(B_THIGH_R, Quaternion(Vector3.RIGHT, 0.55 * _foot_push))
		r.q(B_SHIN_R, Quaternion(Vector3.RIGHT, -0.75 * _foot_push))
	_foot_push = 0.0
	if _dip < -0.001:
		var a := sqrt(-_dip / maxf(k, 0.3) * 5.4)
		for bt: int in [B_THIGH_R, B_THIGH_L]:
			r.q(bt, (r.get_q(bt) as Quaternion) * Quaternion(Vector3.RIGHT, a))
			r.q(bt + 1, (r.get_q(bt + 1) as Quaternion) * Quaternion(Vector3.RIGHT, -2.0 * a))
	off += _dip
	# into and out of an act: ease from the standing pose (sitting down, kneeling, raising a tool)
	var bw := _act_blend(cur)
	if bw < 0.999:
		var act_q: Array[Quaternion] = r._q.duplicate()
		var act_off := off
		r.reset()
		r.q(B_SPINE, Quaternion(Vector3.RIGHT, -stoop * 0.4))
		r.q(B_CHEST, Quaternion(Vector3.RIGHT, -stoop * 0.6 + breath))
		var st_off := _legs_walk(k, walk_amt)
		_arms_carry(k, tool_r, tool_l, [true, true])
		for i in act_q.size():
			r._q[i] = r._q[i].slerp(act_q[i], bw)
		off = lerpf(st_off, act_off, bw)
		head_pitch = lerpf(stoop * 0.7, head_pitch, bw)
	# head: toward what it looks at (the wanderer nearby, the work), else a slow wander
	_head(k, look_target, head_pitch, dt)
	# jaw while speaking (syllables, words, pauses), blinks
	if speaking or chat:
		r.q(B_JAW, Quaternion(Vector3.RIGHT, -0.15 * life.jaw()))
	r.q(B_LID, Quaternion(Vector3.RIGHT, life.blink()))
	(rig as Node3D).position = Vector3(_shift_x, off, _shift_z)
	r.apply()
	r.update_glow()
	var gm: StandardMaterial3D = r.glow_mat
	if gm and tool_l == "tongs":
		gm.emission_energy_multiplier = 0.2 + 1.3 * heat * heat      # emissive cap (was 2.6)
		gm.albedo_color = Color(0.35, 0.3, 0.28).lerp(Color(1.0, 0.55, 0.15), heat)
		(r.glow as Node3D).visible = act in ["hammer", "heat", "quench"] and state == "act"


## Ease into an act from standing over its first moments and back out over its last (0..1).
func _act_blend(cur: String) -> float:
	if state != "act" or attend != null or cur in ["idle", "watch", "walk", "attend", "look_up", "mourn", "read", "chat"]:
		return 1.0
	var T := 0.9 if cur in LOW else 0.45
	return smoothstep(0.0, T, act_t) * (1.0 - smoothstep(act_len - T, act_len, act_t))


func _legs_walk(k: float, amt: float) -> float:
	var r := rig
	var sw: float = life.sway() if life else 0.0
	_turn_on = false
	if amt > 0.001 and life:
		life.turn_reset(global_rotation.y)
	if amt <= 0.001 and life:
		var td: float = life.turn_legs(r, global_rotation.y, _pdt)
		if td != INF:
			_turn_on = true
			return td
	if amt <= 0.001:
		# standing: the weight on one leg (that knee locked, the other soft), the hip dropped to it
		r.q(B_THIGH_R, Quaternion(Vector3.BACK, sw * 0.012) * Quaternion(Vector3.RIGHT, 0.04 * maxf(sw, 0.0)))
		r.q(B_THIGH_L, Quaternion(Vector3.BACK, sw * 0.012) * Quaternion(Vector3.RIGHT, 0.04 * maxf(-sw, 0.0)))
		r.q(B_SHIN_R, Quaternion(Vector3.RIGHT, -0.03 - 0.1 * maxf(sw, 0.0)))
		r.q(B_SHIN_L, Quaternion(Vector3.RIGHT, -0.03 - 0.1 * maxf(-sw, 0.0)))
		r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.FORWARD, -sw * 0.025))
		r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.FORWARD, sw * 0.02))
		return -0.006 * absf(sw) * k
	# the shared heel-toe gait (npc_life.gd) at this villager's age: the old shuffle with short
	# low steps, children trot with a bounce
	var drop := Life.walk_legs(r, gait, amt, float(_gait[0]), float(_gait[1]), float(_gait[2]) * k)
	var c := cos(TAU * gait)
	r.q(B_SPINE, (r.get_q(B_SPINE) as Quaternion) * Quaternion(Vector3.UP, -0.06 * c * amt) * Quaternion(Vector3.FORWARD, 0.035 * c * amt))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, 0.1 * c * amt) * Quaternion(Vector3.RIGHT, -0.04 * amt))
	return drop


## Arms that are not posed by an act: swing with the stride, or carry the tool the way it is
## carried (the lamplighter's pole and lantern, a staff planted as you walk, the spade on the
## shoulder, the candle cupped at the chest).
## art pass: no two people stand alike. Arm hang (swing offset, how far off the flank, forearm bend,
## left and right not mirrored) and a lean of the chest, fixed per villager from its id.
func _stance() -> Dictionary:
	if _stance_c.is_empty():
		var rs := RandomNumberGenerator.new()
		rs.seed = hash(id) * 31 + 5
		_stance_c = {
			"sw": [rs.randf_range(-0.06, 0.12), rs.randf_range(-0.06, 0.12)],
			"ab": [rs.randf_range(-0.02, 0.2), rs.randf_range(-0.02, 0.2)],
			"fb": [rs.randf_range(0.06, 0.55), rs.randf_range(0.06, 0.55)],
			"lean": rs.randf_range(-0.04, 0.09),
		}
	return _stance_c


func _arms_carry(k: float, tool_r: String, tool_l: String, free: Array) -> void:
	var r := rig
	var st := _stance()
	var sr := cos(TAU * gait) * walk_amt * float(_gait[3]) / 0.32
	var idle: float = sin(_t * 0.9) * 0.03 + ((life.breath() - 0.5) * 0.02 if life else 0.0)
	if free[0]:
		match tool_r:
			"pole":
				var bob := 0.03 * sin(TAU * gait * 2.0) * walk_amt
				r.hold(0, Vector3(0.27, 0.95 + bob, -0.17 - 0.04 * sr) * k, Vector3(0.03, 1.0, -0.1), Vector3(0, 0, -1))
			"staff", "crook":
				var plant := 0.06 * sr
				r.hold(0, Vector3(0.27, 1.0, -0.2 - plant) * k, Vector3(0.04, 1.0, 0.22 - plant), Vector3(0, 0, -1))
			"spade":
				r.hold(0, Vector3(0.17, 1.13, -0.08) * k, Vector3(0.1, 0.5, 0.86), Vector3(0, -1, 0.3))
			"candle":
				r.hold(0, Vector3(0.03, 1.0, -0.22) * k, Vector3(0, 1, 0), Vector3(-1, 0, -0.2))
			_:
				r.q(B_ARM_R, Quaternion(Vector3.RIGHT, -0.32 * sr + idle + float(st["sw"][0])) * Quaternion(Vector3.BACK, 0.02 + float(st["ab"][0])))
				r.q(B_FORE_R, Quaternion(Vector3.RIGHT, float(st["fb"][0]) + 0.15 * maxf(0.0, -sr)))
	if free[1]:
		match tool_l:
			"lantern":
				r.hold(1, Vector3(-0.24, 0.8 + 0.02 * absf(sr), -0.14 + 0.05 * sr) * k, Vector3(0, 0, -1), Vector3(0, -1, 0))
			_:
				if tool_r == "candle" and free[0]:
					r.arm_to("l", Vector3(-0.03, 1.02, -0.25) * k, Vector3(-0.9, -0.6, 0.3), null)
				else:
					r.q(B_ARM_L, Quaternion(Vector3.RIGHT, 0.32 * sr - idle + float(st["sw"][1])) * Quaternion(Vector3.BACK, -0.02 - float(st["ab"][1])))
					r.q(B_FORE_L, Quaternion(Vector3.RIGHT, float(st["fb"][1]) + 0.15 * maxf(0.0, sr)))


func _hands_clasped(k: float, at: Vector3) -> void:
	rig.arm_to("r", at + Vector3(0.03, 0, 0) * k, Vector3(0.9, -0.6, 0.3), null)
	rig.arm_to("l", at + Vector3(-0.03, 0, 0) * k, Vector3(-0.9, -0.6, 0.3), null)


func _head(k: float, target: Vector3, pitch: float, dt: float) -> void:
	var r := rig
	if target == Vector3.INF:
		# the wanderer within 5 m in front draws the eye: held while idle or walking, a glance now
		# and then from the work (between blows)
		var pp := _player_pos()
		if pp != Vector3.INF and pp.distance_to(global_position) < 5.0 and (pp - global_position).normalized().dot(_fwd()) > -0.25:
			var glance := state != "act" or fmod(_t + float(hash(id) % 5), 8.0) < (1.6 if act in WORK else 3.0)
			if glance:
				target = pp + Vector3.UP * 1.5
	if target == Vector3.INF and state != "walk":
		_pass_t -= dt
		if _pass_t <= 0.0:
			_pass_t = 0.4 + _rng.randf() * 0.2
			_pass = Vector3.INF
			for o: Node in get_tree().get_nodes_in_group("villager"):
				if o != self and o is Node3D and not bool(o.get("hidden")) and String(o.get("state")) == "walk":
					var dd := (o as Node3D).global_position - global_position
					if dd.length() < 5.0 and dd.normalized().dot(_fwd()) > -0.3:
						_pass = (o as Node3D).global_position + Vector3.UP * 1.45
						break
		target = _pass
	if target != Vector3.INF:
		var m := _m(target)
		var hc: Vector3 = r.hc
		var d := m - hc
		var yw := clampf(atan2(-d.x, -d.z), -1.1, 1.1)
		var pt := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.45)
		_look_to = Vector2(yw, -pt)
	else:
		_look_t -= dt
		if _look_t <= 0.0:
			_look_t = _rng.randf_range(2.0, 5.0)
			_look_to = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.1, 0.15)) if _rng.randf() < 0.6 else Vector2.ZERO
	_look = life.gaze(_look_to, dt, 3.0) if life else _look.lerp(_look_to, minf(1.0, dt * 3.0))
	r.q(B_CHEST, (r.get_q(B_CHEST) as Quaternion) * Quaternion(Vector3.UP, _look.x * 0.25) * Quaternion(Vector3.RIGHT, float(_stance()["lean"])))
	r.q(B_HEAD, Quaternion(Vector3.UP, _look.x * 0.75) * Quaternion(Vector3.RIGHT, -(pitch + _look.y)))


## Two-bone leg IK in the sagittal plane: foot to `foot` (model space), knee forward.
func _leg_ik(side: int, foot: Vector3) -> void:
	var r := rig
	var bt := B_THIGH_R if side == 0 else B_THIGH_L
	var rests: Array = r.rests
	var hip: Vector3 = rests[bt]
	var knee: Vector3 = rests[bt + 1]
	var ank: Vector3 = r.ankle(1.0 if side == 0 else -1.0)
	var a := hip.distance_to(knee)
	var b := knee.distance_to(ank)
	var t := foot - hip
	var f := -t.z
	var d := -t.y
	var L := clampf(Vector2(f, d).length(), 0.05, a + b - 0.002)
	var phi := atan2(f, d)
	var alpha := acos(clampf((a * a + L * L - b * b) / (2.0 * a * L), -1.0, 1.0))
	var beta := acos(clampf((a * a + b * b - L * L) / (2.0 * a * b), -1.0, 1.0))
	r.q(bt, Quaternion(Vector3.RIGHT, phi + alpha))
	r.q(bt + 1, Quaternion(Vector3.RIGHT, -(PI - beta)))


## Sitting: on a seat of world height `seat` (0 = the ground, knees up, arms round them).
func _pose_sit(k: float, seat: float, doze: bool) -> float:
	var r := rig
	var rests: Array = r.rests
	var hip_y: float = (rests[B_THIGH_R] as Vector3).y
	var off := 0.0
	if seat > 0.1:
		off = (seat + 0.07) - hip_y * Rig.SCALE
		var g := -off / Rig.SCALE
		for side in 2:
			var s := 1.0 if side == 0 else -1.0
			_leg_ik(side, Vector3(s * 0.11, g + 0.08 * k, -0.42 * k))
		r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.08 - (0.2 if doze else 0.0)))
		var kn := Vector3(0, hip_y + 0.02, -0.32 * k)
		r.arm_to("r", kn + Vector3(0.13, 0.04, 0.0) * k, Vector3(0.9, -0.3, 0.4), null)
		r.arm_to("l", kn + Vector3(-0.13, 0.04, 0.0) * k, Vector3(-0.9, -0.3, 0.4), null)
	else:
		off = 0.07 - hip_y * Rig.SCALE
		var g2 := -off / Rig.SCALE
		for side in 2:
			var s2 := 1.0 if side == 0 else -1.0
			_leg_ik(side, Vector3(s2 * 0.12, g2 + 0.07 * k, -0.4 * k))
		r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.32 - (0.15 if doze else 0.0)))
		r.q(B_CHEST, Quaternion(Vector3.RIGHT, -0.12))
		var knee_y := g2 + 0.36 * k
		r.arm_to("r", Vector3(0.07, knee_y - 0.02 * k, -0.4 * k), Vector3(0.9, -0.2, 0.5), null)
		r.arm_to("l", Vector3(-0.07, knee_y - 0.02 * k, -0.4 * k), Vector3(-0.9, -0.2, 0.5), null)
	return off


func _pose_kneel(k: float) -> float:
	var r := rig
	var rests: Array = r.rests
	var knee_y: float = (rests[B_SHIN_R] as Vector3).y
	var off := -(knee_y - 0.05 * k) * Rig.SCALE
	for side in 2:
		var bt := B_THIGH_R if side == 0 else B_THIGH_L
		r.q(bt, Quaternion(Vector3.RIGHT, 0.1))
		r.q(bt + 1, Quaternion(Vector3.RIGHT, -1.52))
	return off


func _pose_crouch(k: float) -> float:
	var r := rig
	var rests: Array = r.rests
	var hip_y: float = (rests[B_THIGH_R] as Vector3).y
	var off := -(hip_y * 0.55) * Rig.SCALE
	var g := -off / Rig.SCALE
	for side in 2:
		var s := 1.0 if side == 0 else -1.0
		_leg_ik(side, Vector3(s * 0.13, g + 0.075 * k, -0.08 * k))
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.5))
	r.q(B_CHEST, Quaternion(Vector3.RIGHT, -0.15))
	return off


# --- the forge ----------------------------------------------------------------------------------

func _anvil_m() -> Vector3:
	return _m(village.call("anchor", "@anvil"))


func _pose_hammer(k: float) -> void:
	var r := rig
	var anv := _anvil_m()
	var cyc := fposmod(act_t, 0.95) / 0.95
	var to_a := Vector3(anv.x, 0, anv.z).normalized()
	# raise 0..0.55, strike 0.55..0.66, rebound 0.66..1
	var up_g := Vector3(0.2, 1.52, -0.1) * k
	var up_d := Vector3(0.0, 0.7, 0.72).normalized()
	var up_u := Vector3(0, 0.7, -0.7)
	var face := anv + Vector3.UP * 0.02
	var hit_d := (to_a + Vector3.DOWN * 0.15).normalized()
	var hit_u := Vector3.DOWN
	var tips: Array = r.tips
	var grips: Array = r.grip
	var reach_v: Vector3 = (tips[0] as Vector3) - (grips[0] as Vector3)
	var hit_g := face - hit_d * reach_v.length() * 0.98 + Vector3(0.05, 0.03, 0.0) * k
	var g: Vector3
	var d: Vector3
	var u: Vector3
	if cyc < 0.55:
		var e := smoothstep(0.0, 0.55, cyc)
		g = hit_g.lerp(up_g, e)
		d = hit_d.slerp(up_d, e)
		u = hit_u.slerp(up_u.normalized(), e)
	elif cyc < 0.66:
		var e2 := pow((cyc - 0.55) / 0.11, 2.0)
		g = up_g.lerp(hit_g, e2)
		d = up_d.slerp(hit_d, e2)
		u = up_u.normalized().slerp(hit_u, e2)
	else:
		var e3 := (cyc - 0.66) / 0.34
		g = hit_g + Vector3.UP * 0.05 * sin(e3 * PI) * k
		d = hit_d
		u = hit_u
	# the body throws the blow: the chest winds back and up with the raise (held a beat at the top),
	# drives forward and down through the strike, the knees give on impact and come back
	var wind := smoothstep(0.0, 0.5, cyc) * (1.0 - smoothstep(0.55, 0.64, cyc))
	var hit := exp(-pow((cyc - 0.68) / 0.07, 2.0))
	var lean := 0.1 - 0.06 * wind + 0.18 * smoothstep(0.55, 0.66, cyc) * (1.0 - smoothstep(0.72, 1.0, cyc))
	r.q(B_SPINE, Quaternion(Vector3.UP, 0.08 * wind - 0.04 * hit) * Quaternion(Vector3.RIGHT, -lean))
	r.q(B_CHEST, Quaternion(Vector3.UP, 0.12 + 0.18 * wind - 0.08 * hit) * Quaternion(Vector3.RIGHT, -0.1 + 0.08 * wind - 0.1 * hit))
	_dip = -0.028 * hit * k
	r.hold(0, g, d, u, Vector3(0.7, -0.7, 0.2))
	# tongs hold the iron on the anvil
	var tong_tip := anv + Vector3(-0.04, 0.03, 0.06) * k
	var td := (to_a + Vector3(-0.35, -0.25, 0)).normalized()
	var tl: Vector3 = (tips[1] as Vector3) - (grips[1] as Vector3)
	r.hold(1, tong_tip - td * tl.length(), td, Vector3.DOWN, Vector3(-0.9, -0.4, 0.3))


# --- chopping, digging, the lamps -----------------------------------------------------------------

func _pose_chop(k: float) -> void:
	var r := rig
	var cyc := fposmod(act_t, 1.7) / 1.7
	var block := _m(village.call("anchor", "@block_" + id)) + Vector3.UP * 0.05
	var tips: Array = r.tips
	var grips: Array = r.grip
	var reach_v: Vector3 = (tips[0] as Vector3) - (grips[0] as Vector3)
	var hit_d := (Vector3(block.x, 0, block.z).normalized() + Vector3.DOWN * 0.55).normalized()
	var hit_g := block - hit_d * reach_v.length()
	var up_g := Vector3(0.06, 1.42, -0.02) * k
	var up_d := Vector3(0, 0.9, 0.45).normalized()
	var g: Vector3
	var d: Vector3
	if cyc < 0.55:
		var e := smoothstep(0.0, 0.55, cyc)
		g = hit_g.lerp(up_g, e)
		d = hit_d.slerp(up_d, e)
	elif cyc < 0.62:
		var e2 := pow((cyc - 0.55) / 0.07, 2.0)
		g = up_g.lerp(hit_g, e2)
		d = up_d.slerp(hit_d, e2)
	else:
		g = hit_g
		d = hit_d
	var u := Vector3.DOWN.slide(d).normalized() if absf(d.y) < 0.95 else Vector3(0, 0, -1)
	if cyc < 0.55:
		u = Vector3(0, 0, -1).slide(d).normalized()
	var wind2 := smoothstep(0.0, 0.5, cyc) * (1.0 - smoothstep(0.55, 0.6, cyc))
	var hit2 := exp(-pow((cyc - 0.63) / 0.06, 2.0))
	var bend := 0.1 - 0.08 * wind2 + 0.32 * smoothstep(0.55, 0.62, cyc) * (1.0 - smoothstep(0.75, 1.0, cyc))
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -bend))
	r.q(B_CHEST, Quaternion(Vector3.RIGHT, 0.1 * wind2 - 0.1 * hit2))
	_dip = -0.035 * hit2 * k
	r.hold(0, g, d, u, Vector3(0.9, -0.3, 0.4))
	r.hold(1, g - d * 0.1 * k, d, u, Vector3(-0.9, -0.3, 0.4))


func _pose_dig(k: float) -> void:
	var r := rig
	var cyc := fposmod(act_t, 3.0)
	var hole := _m(village.call("anchor", "@pit"))
	var tips: Array = r.tips
	var grips: Array = r.grip
	var reach := ((tips[0] as Vector3) - (grips[0] as Vector3)).length()
	var blade := Vector3(0.05, hole.y + 0.02, -0.55 * k)
	var d := Vector3(0.0, -1.0, -0.2).normalized()
	var push := 0.0
	var toss := 0.0
	if cyc < 0.9:
		push = 0.0
	elif cyc < 1.4:
		push = smoothstep(0.9, 1.4, cyc)
	elif cyc < 2.2:
		push = 1.0
		d = d.slerp(Vector3(0.0, -0.55, -0.85).normalized(), smoothstep(1.4, 2.2, cyc))
	elif cyc < 2.7:
		push = 1.0
		toss = smoothstep(2.2, 2.6, cyc)
		d = Vector3(0.0, -0.55, -0.85).normalized().slerp(Vector3(0.7, -0.2, -0.7).normalized(), toss)
	else:
		d = Vector3(0.7, -0.2, -0.7).normalized().slerp(Vector3(0.0, -1.0, -0.2).normalized(), smoothstep(2.7, 3.0, cyc))
	var tip := blade + Vector3.DOWN * 0.12 * push
	if cyc >= 2.2:
		tip = blade + Vector3(0.25 * toss, 0.3 * toss, 0.05)
	var g := tip - d * reach
	r.q(B_SPINE, Quaternion(Vector3.UP, -0.25 * toss) * Quaternion(Vector3.RIGHT, -0.25 - 0.12 * push))
	r.hold(0, g, d, Vector3(0, 0, -1).slide(d).normalized(), Vector3(0.9, -0.3, 0.4))
	# the right boot on the blade's shoulder drives it in
	var foot := smoothstep(0.85, 1.05, cyc) * (1.0 - smoothstep(1.35, 1.6, cyc))
	_foot_push = foot
	r.hold(1, g + d * 0.42 * k, d, Vector3(-1, 0, 0).slide(d).normalized(), Vector3(-0.9, -0.3, 0.4))


func _pose_lean(k: float) -> void:
	var r := rig
	var d := Vector3(0, -1, -0.05).normalized()
	var g := Vector3(0.0, 1.0, -0.32) * k
	# leaning is not stillness: the weight rolls from hip to hip, and every few seconds he straightens, rolls his shoulders and
	# sinks back onto the handle (read from the silhouette at 15 m)
	var ph := float(hash(id) % 9)
	var up := smoothstep(0.0, 0.08, fposmod(_t + ph * 2.0, 7.0) / 7.0) * (1.0 - smoothstep(0.2, 0.3, fposmod(_t + ph * 2.0, 7.0) / 7.0))
	r.q(B_SPINE, Quaternion(Vector3.RIGHT, -0.12 + 0.2 * up + 0.04 * sin(_t * 0.7)) * Quaternion(Vector3.FORWARD, 0.06 * sin(_t * 0.45 + ph)))
	r.q(B_CHEST, Quaternion(Vector3.UP, 0.12 * sin(_t * 0.31 + ph)) * Quaternion(Vector3.RIGHT, 0.08 * up))
	_shift_x = 0.03 * sin(_t * 0.45 + ph)
	r.hold(0, g, d, Vector3(0, 0, -1).slide(d).normalized(), Vector3(0.9, -0.5, 0.3))
	r.arm_to("l", g + Vector3(-0.04, 0.06, 0.02) * k, Vector3(-0.9, -0.5, 0.3), null)


func _pose_light(k: float) -> void:
	var r := rig
	var lamp: Vector3 = _m(village.call("lamp_pos", lamp_id))
	var e := smoothstep(0.0, 0.35, act_t / act_len) * (1.0 - smoothstep(0.8, 1.0, act_t / act_len))
	var tips: Array = r.tips
	var grips: Array = r.grip
	var reach := ((tips[0] as Vector3) - (grips[0] as Vector3)).length()
	var g := Vector3(0.22, 1.2, -0.22) * k
	var d := (lamp + Vector3.DOWN * 0.06 - g).normalized()
	var rest_d := Vector3(0.03, 1.0, -0.1).normalized()
	d = rest_d.slerp(d, e)
	g = Vector3(0.27, 0.95, -0.17) * k
	g = g.lerp(lamp + Vector3.DOWN * 0.06 - d * reach, e)
	var u := Vector3(0, 0, -1).slide(d).normalized()
	if u.length() < 0.1:
		u = Vector3.RIGHT
	r.hold(0, g, d, u, Vector3(0.9, -0.5, 0.2))


# --- for the director and the tests ----------------------------------------------------------

func info() -> Dictionary:
	return {"id": id, "routine": routine, "state": state, "act": act, "at": at_node, "goal": goal,
		"pos": global_position, "hidden": hidden, "walked": walked, "steps": acts_done}
