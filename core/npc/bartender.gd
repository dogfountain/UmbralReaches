class_name Bartender
extends Interactable
## The Kindled Keg's keep, on a DwarfRig (apron, bar cloth in the left hand, a tankard in the right).
## He works the duckboard behind the counter: walks it (legs swing, a rolling gait), wipes the
## counter in circles with the cloth, polishes the tankard, holds it under the keg's tap (a stream of
## beer), sets fresh ones out on the counter (max 5), leans on the counter to talk with the regular
## at the bar, and turns to face the wanderer when they come to the bar. Talking to him opens the
## story conversation (core/story, ui/dialogue.gd); while his line types he talks with jaw and hands.
## Alive between tasks (npc_life.gd): blinks, breathes, glances about, talks in words and phrases;
## walks the duckboard on the shared heel-toe gait. A patron who comes up to the bar is served:
## `serve_at(x, who)` sends him along the counter to set a tankard in front of them.
## Set `lane_x` (walkable x range), `lane_z`, `bar_y` (counter top), `bar_z` (counter's back edge)
## and `keg` before adding him to the tree (Tavern does).
## Cost: posed every frame up close, slower with distance / off screen, frozen far (Life.interval).

@export var facing := 0.0

var lane_x := Vector2(12.0, 18.0)
var lane_z := 33.6
var bar_y := 0.38                ## counter top, world
var bar_z := 33.33               ## the counter's back (keep-side) edge, world
var keg := Vector3(19.2, 0.1, 33.75)   ## tap of the nearest keg, world
var regular: Node3D              ## the patron leaning on the bar (Tavern sets him)
var speaking := false            ## set by the dialogue while his line types
var voice := {}                  ## his babble (npc_voice.gd)
var attend: Node3D               ## someone to face (the wanderer, in a conversation)
var talk_id := "keep"
var display_name := "The Keep"

const ACTIVE_R := 30.0
const MAX_MUGS := 5
const DwarfMesh := preload("res://core/npc/dwarf_mesh.gd")
const Life := preload("res://core/npc/npc_life.gd")
const Voice := preload("res://core/npc/npc_voice.gd")

var rig: DwarfRig
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _task := "wipe"
var _task_t := 0.0
var _task_len := 4.0
var _goal_x := 15.0
var _walk := 0.0                 ## 0..1 gait blend
var _phase := 0.0                ## gait phase
var _yaw := 0.0
var _mugs: Array[Node3D] = []
var _mug_mesh: Mesh
var _stream: GPUParticles3D
var _look := Vector2.ZERO
var life: Life
var _acc := 0.0
var _pose_dt := 0.0
var _guest: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # r36 smooth: moved in _process, drawn as set (interpolated, it judders between ticks)
	add_to_group(Groups.INTERACTABLE)
	add_to_group("keep")
	rig = DwarfRig.make({"seated": false, "seed": 5150, "apron": true, "hat": "bare", "rag": true})
	add_child(rig)
	_rng.seed = 5150
	life = Life.new(5150)
	voice = Voice.profile("keep", 5150)
	_yaw = facing
	rotation.y = facing
	_goal_x = global_position.x
	_mug_mesh = make_mug()
	_stream = Vfx.emitter(Color(1.0, 0.72, 0.28), {"count": 30, "life": 0.35, "speed": Vector2(0.05, 0.2), "size": 0.035, "gravity": 6.0, "radius": 0.01, "additive": false, "spread": 4.0})
	if _stream:
		_stream.name = "TapStream"
		add_child(_stream)
	_pick()


## A served tankard for the counter (the same build as the one in a dwarf's fist).
static func make_mug() -> Mesh:
	var mb := DwarfMesh.new(77)
	DwarfRig._tankard(mb, Vector3(0, 0.07, 0), Vector3.RIGHT)
	var m := mb.commit_static()
	m.surface_set_material(0, DwarfRig._cloth())
	return m


## A patron has come up to the bar at world x: go and set a tankard in front of him.
func serve_at(x: float, who: Node3D = null) -> void:
	_task = "serve"
	_task_t = 0.0
	_task_len = 2.6
	_goal_x = clampf(x - 0.15, lane_x.x, lane_x.y)
	_guest = who


func _pick() -> void:
	_guest = null
	_task_t = 0.0
	var r := _rng.randf()
	if regular and r < 0.18:
		_task = "chat"
		_task_len = _rng.randf_range(5.0, 8.0)
		_goal_x = clampf(regular.global_position.x, lane_x.x, lane_x.y)
	elif r < 0.42:
		_task = "wipe"
		_task_len = _rng.randf_range(4.0, 7.0)
		_goal_x = _rng.randf_range(lane_x.x, lane_x.y)
	elif r < 0.6:
		_task = "polish"
		_task_len = _rng.randf_range(4.0, 6.0)
		_goal_x = _rng.randf_range(lane_x.x, lane_x.y)
	elif r < 0.82:
		_task = "fill"
		_task_len = 4.5
		_goal_x = minf(keg.x - 0.55, lane_x.y + 0.3)
	else:
		_task = "serve"
		_task_len = 2.4
		_goal_x = _rng.randf_range(lane_x.x, lane_x.y - 1.0)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_squared_to(global_position) > ACTIVE_R * ACTIVE_R:
		return
	_t += delta
	_pose_dt += delta
	var pl := _player()
	var near := attend != null or (pl != null and pl.global_position.distance_to(global_position) < 3.2 and pl.global_position.z < bar_z - 0.3)
	var face_who: Node3D = attend if attend else pl
	# walk to the task's spot first (stays on the duckboard: lane_z is fixed)
	var dx := _goal_x - global_position.x
	var walking := absf(dx) > 0.05 and not near
	if walking:
		global_position.x += signf(dx) * minf(absf(dx), 1.0 * delta)
		_phase += delta * TAU / Life.stride_len(0.44, 0.38)
	_walk = move_toward(_walk, 1.0 if walking else 0.0, delta * 4.0)
	# face: along the walk, the kegs (+x) when filling, the wanderer when greeting, else the room (-z)
	var want := facing
	if walking:
		want = -PI * 0.5 if dx > 0.0 else PI * 0.5
	elif near and face_who:
		var to := face_who.global_position - global_position
		want = atan2(-to.x, -to.z)
	elif _task == "fill":
		want = -PI * 0.5
	_yaw = lerp_angle(_yaw, want, 1.0 - exp(-delta * 6.0))
	rotation.y = _yaw
	if not walking and not near:
		_task_t += delta
		if _task_t >= _task_len:
			if _task == "serve":
				_set_mug()
			_pick()
	var iv := Life.interval_keg(cam, global_position, true, walking)
	if iv < 0.0 or _pose_dt < iv:
		return
	var dt := _pose_dt
	_pose_dt = 0.0
	animate(dt, walking, near, face_who)


func animate(delta: float, walking: bool, near: bool, face_who: Node3D) -> void:
	if life == null:
		life = Life.new(5150)
	life.step(delta, speaking or (_task == "chat" and fmod(_task_t, 4.0) < 2.0))
	if not speaking:
		Voice.chatter(self, life, voice, -12.0)   # chatting at the bar; the dialogue box voices him otherwise
	var k := clampf(_task_t / _task_len, 0.0, 1.0) if not walking else 0.0
	var H := rig.H
	var w := _walk
	var gp := fposmod(_phase / TAU, 1.0)
	var step := cos(TAU * gp)        # +1 when the right heel strikes
	var br: float = life.breath()
	var sway: float = life.sway() * (1.0 - w)
	var spine := Quaternion(Vector3.UP, -0.06 * step * w) * Quaternion(Vector3.FORWARD, step * 0.04 * w + sway * 0.03) * Quaternion(Vector3.RIGHT, (br - 0.5) * 0.02)
	var chest := Quaternion(Vector3.UP, 0.1 * step * w) * Quaternion(Vector3.RIGHT, (br - 0.5) * 0.035) * Quaternion(Vector3.FORWARD, -sway * 0.02)
	var yaw := 0.0
	var pitch := -0.05
	var jaw := 0.0
	# legs: the shared heel-toe gait while walking; a weight shift at rest
	rig.reset()
	var drop := Life.walk_legs(rig, gp, w, 0.38, 0.95, 0.022)
	rig.position = Vector3(sway * 0.012 * (1.0 - w), drop, 0)
	if w < 0.5:
		rig.q(DwarfRig.B_SHIN_R, Quaternion(Vector3.RIGHT, -0.1 * maxf(-sway, 0.0) - 0.03))
		rig.q(DwarfRig.B_SHIN_L, Quaternion(Vector3.RIGHT, -0.1 * maxf(sway, 0.0) - 0.03))
	# arms: hang and swing while walking (forearms a little forward), else per task
	var hang_r := Vector3(0.3, H + 0.04, -0.12 + step * 0.12 * w)
	var hang_l := Vector3(-0.3, H + 0.06, -0.1 - step * 0.12 * w)
	var r_at := hang_r
	var l_at := hang_l
	var r_q: Variant = Quaternion.IDENTITY
	var l_q: Variant = null
	var counter := Vector3(0, bar_y - global_position.y, -(lane_z - bar_z) - 0.12)   # local, counter top in front
	var pour := false
	if near and not walking:
		# talk across the counter: lean on it with the mug hand, gesture with the cloth hand
		var g := sin(_t * 2.6) * 0.5 + 0.5
		var look := _look_at(face_who)
		yaw = look.x
		pitch = look.y
		r_at = rig.wrist_for("r", rig.mug_base, Vector3(0.18, counter.y + 0.003, counter.z - 0.08), Quaternion.IDENTITY)
		l_at = Vector3(-0.22, H + 0.4 + 0.08 * g, -0.36)
		l_q = Quaternion(Vector3.FORWARD, -0.7 * g) * Quaternion(Vector3.RIGHT, -0.4)
		chest = chest * Quaternion(Vector3.RIGHT, -0.12)
		if speaking or attend == null:
			jaw = -0.085 * life.jaw() * (1.0 if speaking or fmod(_t, 5.0) < 2.5 else 0.0)
			pitch += 0.06 * life.beat()
			l_at += Vector3(0, 0.06 * life.beat(), -0.03 * life.beat())
	elif not walking:
		var into := smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.85, 1.0, k))
		match _task:
			"wipe":
				# circles on the counter top with the cloth, leaning over it
				var a := _t * 3.2
				spine = spine * Quaternion(Vector3.RIGHT, -0.04 * into)
				chest = chest * Quaternion(Vector3.RIGHT, -0.24 * into)
				l_at = l_at.lerp(Vector3(-0.15 + cos(a) * 0.12, counter.y + 0.06, counter.z - 0.08 + sin(a) * 0.07), into)
				r_at = r_at.lerp(rig.wrist_for("r", rig.mug_base, Vector3(0.22, counter.y + 0.003, counter.z), Quaternion.IDENTITY), into)
				pitch = -0.3 * into
			"polish":
				# tankard in front of the chest, the cloth fist circling it
				var held := Vector3(0.02, H + 0.36, -0.34)
				var a2 := _t * 5.0
				r_q = Quaternion(Vector3.UP, sin(_t * 1.3) * 0.6 * into)
				r_at = r_at.lerp(rig.wrist_for("r", rig.mug_base, held, r_q), into)
				l_at = l_at.lerp(held + Vector3(-0.08 + cos(a2) * 0.035, 0.08 + sin(a2) * 0.04, -0.02), into)
				pitch = -0.32 * into
			"fill":
				# tankard held under the keg's tap, then topped and lifted away
				chest = chest * Quaternion(Vector3.RIGHT, -0.26 * into)
				var tap := to_local(keg) - rig.position
				r_q = Quaternion(Vector3.FORWARD, 0.25 * into)
				r_at = r_at.lerp(rig.wrist_for("r", rig.mug_rim, tap + Vector3(0, -0.04, 0), r_q), into)
				l_at = l_at.lerp(tap + Vector3(-0.1, 0.12, 0.0), into)
				pitch = -0.32 * into
				pour = k > 0.25 and k < 0.75
			"serve":
				# sets a fresh tankard down on the counter in front of him
				var into4 := sin(k * PI)
				chest = chest * Quaternion(Vector3.RIGHT, -0.2 * into4)
				r_at = r_at.lerp(rig.wrist_for("r", rig.mug_base, Vector3(0.18, counter.y + 0.003, counter.z - 0.05), Quaternion.IDENTITY), into4)
				pitch = -0.2 * into4
				if _guest:
					var lg := _look_at(_guest)
					yaw = lg.x * (1.0 - into4 * 0.5)
					pitch = lerpf(lg.y, pitch, into4)
			"chat":
				# leans on the counter by the regular and trades words with him
				var look2 := _look_at(regular)
				yaw = look2.x * into
				pitch = look2.y * into
				chest = chest * Quaternion(Vector3.RIGHT, -0.18 * into)
				r_at = r_at.lerp(rig.wrist_for("r", rig.mug_base, Vector3(0.16, counter.y + 0.003, counter.z - 0.02), Quaternion.IDENTITY), into)
				l_at = l_at.lerp(Vector3(-0.2, counter.y + 0.05, counter.z - 0.02), into)
				var talking := fmod(_task_t, 4.0) < 2.0
				jaw = -0.085 * life.jaw() * (1.0 if talking else 0.0) * into
				pitch += 0.05 * life.beat() * into
				if regular is DwarfNpc and into > 0.5:
					var reg := regular as DwarfNpc
					if reg._act in ["idle", "listen", "talk"]:
						reg._act = "listen" if talking else "talk"
						reg._act_t = fmod(_task_t, 2.0)
						reg._act_len = 2.5
	var g: Vector2 = life.gaze(Vector2(yaw, pitch), delta, 4.0)
	rig.q(DwarfRig.B_SPINE, spine)
	rig.q(DwarfRig.B_CHEST, chest)
	rig.q(DwarfRig.B_HEAD, Quaternion(Vector3.UP, clampf(g.x, -1.0, 1.0)) * Quaternion(Vector3.RIGHT, clampf(g.y, -0.4, 0.4)))
	rig.q(DwarfRig.B_JAW, Quaternion(Vector3.RIGHT, jaw))
	rig.q(DwarfRig.B_LID, Quaternion(Vector3.RIGHT, life.blink()))
	rig.fk_all()
	rig.arm_to("r", r_at, Vector3(0.8, -0.4, 0.4), r_q)
	rig.arm_to("l", l_at, Vector3(-0.8, -0.4, 0.4), l_q)
	rig.apply()
	if _stream:
		_stream.emitting = pour
		if pour:
			_stream.global_position = keg + Vector3(0.0, -0.03, 0.0)


func _look_at(n: Node3D) -> Vector2:
	if n == null:
		return Vector2.ZERO
	var l := to_local(n.global_position + Vector3.UP * (1.3 if n is DwarfNpc else 1.5)) - rig.rest_of("head")
	return Vector2(clampf(atan2(-l.x, -l.z), -1.0, 1.0), clampf(atan2(l.y - 0.15, Vector2(l.x, l.z).length()), -0.3, 0.3))


func _set_mug() -> void:
	if _mug_mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "ServedMug"
	mi.mesh = _mug_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 30.0
	get_parent().add_child(mi)
	mi.global_position = to_global(Vector3(0.18, 0, -(lane_z - bar_z) - 0.17))
	mi.global_position.y = bar_y
	mi.rotation.y = _rng.randf() * TAU
	_mugs.append(mi)
	if _mugs.size() > MAX_MUGS:
		var old: Node3D = _mugs.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func can_interact() -> bool:
	return true


func interact_text() -> String:
	return "[%s]  Talk to the keep" % Interactable.prompt_key()


func interact_reach() -> float:
	return 2.8


func interact(by: Node) -> void:
	var story := get_tree().get_first_node_in_group("story")
	if story and story.has_method("talk"):
		story.talk(talk_id, self, by)
	else:
		Events.toast.emit("The Kindled Keg. Fire stays. Hollows do not.")
