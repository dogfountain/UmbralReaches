class_name DwarfNpc
extends Interactable
## A tavern patron on a DwarfRig. Seated ones sit on a bench or chair at a table with the mug on the
## tabletop and the other forearm on the board; the one at the bar leans on the counter.
## Each runs its own clock and is alive between beats (npc_life.gd): blinks, breathes (chest and
## shoulders), shifts his weight when standing, and looks at the wanderer when he comes close.
## Beats: drinks (a lean in, the mug up by arm IK, two or three swallows with the head back, an
## "ahh", the mug down, a wipe of the moustache), laughs (a sharp throw back, shaking shoulders that
## die away, slaps on the table on the peaks), talks in words and phrases (jaw by syllable, the
## free hand opening on stressed words, nods), listens (nods on the speaker's stresses), raises a
## toast. Patrons seated across from each other are a pair (`partner`): the leader cues joint beats,
## so they talk TO each other, laugh together, and toast each other and drink together.
## A patron with `wanders` (chair sitters, Tavern sets the route) now and then gets up: swivels out
## of his chair, leans forward over his feet and rises (the seated rig hands over to a standing build
## of the same dwarf at the moment the hips pass over the feet), walks to the bar on a heel-toe gait,
## leans there to be served by the keep, toasts him and drinks, walks back and sits down again.
## A patron with a `talk_id` can be spoken to (ui/dialogue.gd).
## Cost: posed every frame up close, at 30/20/12 Hz with distance, 2 Hz off screen, frozen past
## Life.FREEZE_R (npc_life.gd); one draw (one skinned surface).

@export var facing := 0.0
@export var seed_n := 0
@export var seated := true
@export var hat := ""

const ACTIVE_R := 30.0
const Life := preload("res://core/npc/npc_life.gd")
const Voice := preload("res://core/npc/npc_voice.gd")

var talk_id := ""                ## dialogue id (core/story/dialogue_db.gd), "" = keeps to himself
var display_name := "Patron"
var partner: DwarfNpc            ## who he drinks with (set by Tavern)
var leader := false
var table_top := 0.8             ## local height of the board in front of him
var table_edge := -0.4           ## local z of its near edge (negative: in front)
var lean_bar := false            ## standing at the counter: forearms on it
var tuck := false                ## feet drawn back under the chair (clear of a trestle)
var speaking := false            ## set by the dialogue while his line types
var attend: Node3D               ## someone to face (the wanderer, in a conversation)
# --- the bar trip (Tavern sets these on chair sitters) ---
var wanders := false
var route: Array[Vector3] = []   ## world points from beside the chair to the bar spot (last)
var bar_top := 0.86              ## counter top over the bar spot's floor (local)
var bar_edge := -0.25            ## counter's front edge (local z) from the bar spot
var keep: Node                   ## the keep, who serves him
var away := false                ## out of his seat (the partner talks to no one meanwhile)
# --- the Keg's scenes (core/npc/keg_scenes.gd cues these) ---
var note := 0.0                  ## a sung note just began (1, decays): the jaw opens on it
var slam_hit := false            ## an argument's fist came down this pose (the scenes play the thump)
var dice_out := false            ## the dice left his hand this pose
var _dice_fired := false         ## one throw per cue (edge-detect misses on skipped frames)

var rig: DwarfRig
var life: Life
var voice := {}                  ## his babble (npc_voice.gd): a dwarf voice of his own, from his seed
var _rig_sit: DwarfRig
var _rig_stand: DwarfRig
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _act := "idle"
var _act_t := 0.0
var _act_len := 3.0
var _look := Vector2.ZERO
var _look_to := Vector2.ZERO
var _cue_wait := 0.0
var _acc := 0.0
var _player: Node3D
var _trip := ""                  ## "" seated, rise, out, bar, back, sit
var _trip_t := 0.0
var _trip_wait := 60.0
var _seat_pos := Vector3.ZERO
var _seat_yaw := 0.0
var _out_yaw := 0.0
var _path: Array[Vector3] = []
var _path_i := 0
var _gait := 0.0
var _walk := 0.0
var _yaw := 0.0
var _home_top := 0.8
var _home_edge := -0.4


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # r36 smooth: moved in _process, drawn as set (interpolated, it judders between ticks)
	add_to_group(Groups.INTERACTABLE)
	rig = DwarfRig.make({"seated": seated, "seed": seed_n if seed_n != 0 else hash(name), "hat": hat})
	voice = Voice.profile("dwarf", seed_n if seed_n != 0 else hash(name))
	# a body to bump into (the wanderer used to walk straight through a seated dwarf)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.4
	cs.shape = cap
	cs.position = Vector3(0, 0.7, -0.05)
	body.add_child(cs)
	add_child(body)
	add_child(rig)
	_rig_sit = rig
	if wanders and seated:
		_rig_stand = DwarfRig.make({"seated": false, "seed": seed_n if seed_n != 0 else hash(name), "hat": hat})
		_rig_stand.name = "RigStanding"
		_rig_stand.visible = false
		add_child(_rig_stand)
	rotation.y = facing
	_yaw = facing
	_rng.seed = seed_n if seed_n != 0 else hash(name)
	life = Life.new(_rng.seed)
	_t = _rng.randf() * 20.0
	_trip_wait = _rng.randf_range(25.0, 70.0)
	_home_top = table_top
	_home_edge = table_edge
	_next("idle")
	_act_t = _rng.randf() * _act_len


# --- talking to the wanderer ----------------------------------------------------------------

func can_interact() -> bool:
	return talk_id != ""


func interact_text() -> String:
	return "[%s]  Talk to %s" % [Interactable.prompt_key(), display_name]


func interact_reach() -> float:
	return 2.4


func interact(by: Node) -> void:
	var story := get_tree().get_first_node_in_group("story")
	if story and story.has_method("talk"):
		story.talk(talk_id, self, by)


# --- behaviour --------------------------------------------------------------------------------

## A joint beat from the partner: start `act` now for `length` seconds.
func cue(act: String, length: float) -> void:
	_dice_fired = false
	_act = act
	_act_t = 0.0
	_act_len = length
	if act == "laugh":
		Voice.laugh_at(self, voice, -11.0)


func _mate() -> DwarfNpc:
	return partner if partner and not partner.away and not away else null


func _next(after: String) -> void:
	_act_t = 0.0
	if after != "idle":
		_act = "idle"
		_act_len = _rng.randf_range(2.0, 5.0)
		return
	var r := _rng.randf()
	var mate := _mate()
	if mate and leader and r < 0.45 and mate._act in ["idle", "listen"]:
		# a joint beat: a conversation turn, a shared laugh, or a toast to each other
		var j := _rng.randf()
		if j < 0.55:
			var who_talks: DwarfNpc = self if _rng.randf() < 0.5 else mate
			var other: DwarfNpc = mate if who_talks == self else self
			var ln := _rng.randf_range(3.0, 5.5)
			who_talks.cue("talk", ln)
			other.cue("listen", ln)
		elif j < 0.75:
			var ln2 := _rng.randf_range(1.8, 2.6)
			cue("laugh", ln2)
			mate.cue("laugh", ln2 + 0.3)
		else:
			cue("toast", 4.2)
			mate.cue("toast", 4.2)
		return
	if r < 0.5:
		_act = "drink"
		_act_len = _rng.randf_range(4.0, 5.2)
	elif r < 0.66:
		_act = "laugh"
		_act_len = _rng.randf_range(1.6, 2.6)
		Voice.laugh_at(self, voice, -11.0)
	elif r < 0.76:
		_act = "toast"
		_act_len = 3.4
	elif r < 0.9:
		_act = "talk"
		_act_len = _rng.randf_range(2.5, 4.0)
	else:
		_act = "look"
		_act_len = _rng.randf_range(2.0, 3.5)


func _player_node() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return _player


func _process(delta: float) -> void:
	_t += delta
	_act_t += delta
	if speaking or attend:
		_act = "attend"
	elif _act == "attend":
		_next("talk")
	elif _act_t >= _act_len:
		_next(_act)
	if wanders and _rig_stand:
		_trip_step(delta)
	var cam := get_viewport().get_camera_3d()
	var iv := Life.interval_keg(cam, global_position, true, _trip in ["out", "back"])
	if iv < 0.0:
		return
	_acc += delta
	if _acc < iv:
		return
	var dt := _acc
	_acc = 0.0
	animate(dt)


## Pose the rig for the current beat (also driven by the tests and the studio shots).
var _pose_step := 0.016                ## the time this pose covers (turn_legs steps its shuffle by it)


func animate(delta: float) -> void:
	_pose_step = delta
	if life == null:
		life = Life.new(seed_n)
	life.step(delta, _act in ["talk", "argue"] or (_act == "attend" and speaking))
	if not speaking and _act != "attend":
		Voice.chatter(self, life, voice, -8.0 if _act == "argue" else -13.0)   # the dialogue box voices him in a conversation
	note = maxf(0.0, note - delta * 3.5)
	if _trip in ["out", "back"]:
		_animate_walk(delta)
		return
	if _trip in ["rise", "sit"]:
		_animate_rise()
		return
	if _rng.randf() < delta * 0.3:
		_look_to = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.12, 0.15))
	var want := _look_to
	var mate := _mate()
	if mate and _act in ["talk", "listen", "laugh", "toast", "idle", "argue", "cheer", "groan", "dice"]:
		want = _look_at_local(mate.global_position + Vector3.UP * 1.25) * (0.85 if _act != "idle" else 0.35) + _look_to * (0.15 if _act != "idle" else 0.65)
	elif _trip == "bar" and keep is Node3D:
		want = _look_at_local((keep as Node3D).global_position + Vector3.UP * 1.3) * 0.7 + _look_to * 0.3
	# the wanderer close by draws the eye (unless the mug is at his lips)
	var pl := _player_node()
	if pl and _act in ["idle", "listen", "look", "laugh", "talk"]:
		var to := pl.global_position - global_position
		if to.length() < 3.6 and to.normalized().dot(Vector3(-sin(_yaw), 0, -cos(_yaw))) > -0.3:
			want = want.lerp(_look_at_local(pl.global_position + Vector3.UP * 1.45), 0.75 if _act in ["idle", "look"] else 0.4)
	if attend:
		want = _look_at_local(attend.global_position + Vector3.UP * 1.4)
	_look = life.gaze(want, delta, 2.5)
	var k := clampf(_act_t / maxf(_act_len, 0.01), 0.0, 1.0)
	var br: float = life.breath()
	var breathe := (br - 0.5) * 0.04
	var lean := -0.1 if seated else -0.06
	# read at 15 m: the weight shift is a whole-body move (a hip, a lean, a rolled shoulder), and a seated one rocks too
	var sway_raw: float = life.sway()
	var sway: float = sway_raw if not seated else 0.0
	var rock := sway_raw * 0.045 if seated else sway * 0.075
	var spine := Quaternion(Vector3.FORWARD, rock) * Quaternion(Vector3.RIGHT, lean * 0.5 + breathe * 1.6)
	var chest := Quaternion(Vector3.FORWARD, -rock * 0.8) * Quaternion(Vector3.RIGHT, lean * 0.5 + breathe * 2.5)
	rig.position = Vector3(sway * 0.035, 0, 0) if not seated else Vector3.ZERO
	var head_yaw := _look.x
	var head_pitch := _look.y
	var jaw := 0.0
	var mug_goal := _mug_rest()
	var mug_q := Quaternion.IDENTITY
	var left := _left_rest() + Vector3(0, 0.006 * br, 0)
	var left_q: Variant = null
	match _act:
		"drink":
			# lean in (0-0.08), raise (to 0.24), swallow two or three times with the head going back
			# (0.24-0.7), lower (0.7-0.86) with an "ahh", then a wipe of the moustache
			var lean_in := smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.2, 0.3, k))
			var up := smoothstep(0.04, 0.24, k) * (1.0 - smoothstep(0.68, 0.86, k))
			var gulp := smoothstep(0.24, 0.36, k) * (1.0 - smoothstep(0.6, 0.72, k))
			var sw := maxf(0.0, sin((k - 0.26) / 0.4 * TAU * 2.5)) * gulp
			var ahh := smoothstep(0.76, 0.82, k) * (1.0 - smoothstep(0.86, 0.94, k))
			head_yaw *= 1.0 - up
			head_pitch = lerpf(head_pitch, 0.3 * gulp + 0.05 * up + 0.04 * sw, up) + 0.12 * ahh
			chest = chest * Quaternion(Vector3.RIGHT, 0.06 * gulp - 0.08 * lean_in - 0.05 * ahh)
			jaw = -0.05 * gulp - 0.1 * ahh
			mug_q = Quaternion(Vector3.UP, 0.5 * up) * Quaternion(Vector3.RIGHT, (1.15 + 0.08 * sw) * gulp + 0.25 * up)
			rig.q(DwarfRig.B_SPINE, spine)
			rig.q(DwarfRig.B_CHEST, chest)
			rig.q(DwarfRig.B_HEAD, _head_q(head_yaw, head_pitch))
			rig.fk_all()
			var lip := rig.lips() + Vector3(0.0, -0.012, -0.018)
			var at := rig.wrist_for("r", rig.mug_rim, lip, mug_q)
			var hold := rig.wrist_for("r", rig.mug_base, mug_goal, Quaternion.IDENTITY)
			_pose(spine, chest, head_yaw, head_pitch, jaw, hold.lerp(at, up), mug_q, left, left_q)
			var wipe := smoothstep(0.84, 0.9, k) * (1.0 - smoothstep(0.95, 1.0, k))
			if wipe > 0.0:
				var mo := rig.lips() + Vector3(-0.06 + 0.12 * smoothstep(0.86, 0.96, k), 0.02, -0.07)
				rig.arm_to("l", left.lerp(mo, wipe), Vector3(-0.6, -0.6, 0.4))
			rig.apply()
			return
		"toast":
			# mug up toward the partner (or the room), a clink, hold, a swig together
			var up2 := smoothstep(0.0, 0.16, k) * (1.0 - smoothstep(0.5, 0.62, k))
			var bump := sin(clampf((k - 0.22) / 0.16, 0.0, 1.0) * PI) * 0.06
			var aim := Vector3(0.16, rig.H + 0.72 + bump, -0.42)
			if mate:
				var pl2 := to_local(mate.global_position)
				aim = Vector3(0.12 + clampf(pl2.x * 0.15, -0.1, 0.1), rig.H + 0.7 + bump, -0.42)
			elif _trip == "bar":
				aim = Vector3(0.1, bar_top + 0.42 + bump, bar_edge - 0.12)
			mug_goal = mug_goal.lerp(aim, up2)
			mug_q = Quaternion(Vector3.RIGHT, -0.2 * up2)
			head_pitch += 0.12 * up2
			jaw = -0.1 * up2 * life.jaw() - 0.04 * up2
			chest = chest * Quaternion(Vector3.RIGHT, 0.05 * up2)
			if k > 0.6:
				var d := smoothstep(0.6, 0.7, k) * (1.0 - smoothstep(0.88, 1.0, k))
				rig.q(DwarfRig.B_HEAD, _head_q(0.0, 0.3 * d))
				rig.q(DwarfRig.B_SPINE, spine)
				rig.q(DwarfRig.B_CHEST, chest)
				rig.fk_all()
				var lip2 := rig.lips() + Vector3(0.0, -0.012, -0.018)
				var tq := Quaternion(Vector3.UP, 0.5 * d) * Quaternion(Vector3.RIGHT, 1.3 * d)
				var hold2 := rig.wrist_for("r", rig.mug_base, _mug_rest(), Quaternion.IDENTITY)
				_pose(spine, chest, head_yaw * (1.0 - d), lerpf(head_pitch, 0.3, d), -0.05 * d, hold2.lerp(rig.wrist_for("r", rig.mug_rim, lip2, tq), d), tq, left, left_q)
				rig.apply()
				return
		"laugh":
			# a sharp throw back, then shaking shoulders that die away; slaps on the peaks
			var throw := smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.15, 0.5, k))
			var env := smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.55, 1.0, k))
			var shake := sin(_act_t * 21.0) * 0.045 * env
			chest = chest * Quaternion(Vector3.RIGHT, 0.14 * throw + 0.06 * env + shake)
			spine = spine * Quaternion(Vector3.RIGHT, 0.05 * throw)
			head_pitch += 0.32 * throw + 0.12 * env + shake
			jaw = -(0.1 + 0.08 * throw) * env * (0.7 + 0.3 * sin(_act_t * 17.0))
			var slap := pow(maxf(sin(_act_t * 6.5), 0.0), 3.0) * env * (1.0 - throw)
			left = left + Vector3(0.0, 0.08 * slap, 0.0)
		"talk":
			var bt: float = life.beat()
			jaw = -0.085 * life.jaw()
			var g := 0.5 + 0.5 * sin(_act_t * 1.9)
			left = left.lerp(Vector3(-0.2 + 0.05 * sin(_act_t * 1.3), rig.H + 0.4 + 0.06 * g + 0.08 * bt, -0.4 - 0.05 * bt), 0.85)
			left_q = Quaternion(Vector3.FORWARD, -0.6 * g - 0.5 * bt) * Quaternion(Vector3.RIGHT, -0.5)
			head_pitch += 0.17 * bt - 0.03
			head_yaw += sin(_act_t * 1.1) * 0.2
			chest = chest * Quaternion(Vector3.UP, sin(_act_t * 1.1) * 0.16) * Quaternion(Vector3.RIGHT, -0.1 * bt)
			spine = spine * Quaternion(Vector3.RIGHT, -0.05 * bt)
		"listen":
			var nod := 0.0
			if mate and mate.life:
				nod = maxf(float(mate.life.beat()) - 0.45, 0.0) * 0.55
			head_pitch += nod + 0.07 * sin(_act_t * 0.7)
			head_yaw += 0.12 * sin(_act_t * 0.5)
			chest = chest * Quaternion(Vector3.RIGHT, nod * 0.3)
		"look":
			head_yaw = _look_to.x * 1.3
			chest = chest * Quaternion(Vector3.UP, _look_to.x * 0.35)
		"sing":
			# swaying in time, the mug lifted, the head back a little; the jaw opens on each note
			var env_s := smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.92, 1.0, k))
			var sw2 := sin(_act_t * 2.6 + float(seed_n % 7))
			mug_goal = mug_goal.lerp(Vector3(0.17 + 0.05 * sw2, rig.H + 0.5 + 0.03 * absf(sw2), -0.38), 0.75 * env_s)
			mug_q = Quaternion(Vector3.FORWARD, 0.12 * sw2 * env_s)
			head_pitch += (0.12 + 0.04 * sw2) * env_s
			head_yaw = lerpf(head_yaw, 0.2 * sw2, env_s)
			jaw = -(0.04 + 0.13 * note) * env_s
			chest = chest * Quaternion(Vector3.FORWARD, 0.06 * sw2 * env_s) * Quaternion(Vector3.RIGHT, 0.04 * env_s)
			spine = spine * Quaternion(Vector3.FORWARD, 0.03 * sw2 * env_s)
		"argue":
			# leaning in, jabbing, and now and then a fist on the board
			var bt3: float = life.beat()
			jaw = -0.11 * life.jaw()
			var cyc := fposmod(_act_t * 0.55 + float(seed_n % 5) * 0.2, 1.0)
			var slam := smoothstep(0.62, 0.7, cyc) * (1.0 - smoothstep(0.74, 0.86, cyc))
			if cyc >= 0.7 and cyc - delta * 0.55 < 0.7:
				slam_hit = true
			var jab := Vector3(-0.22 + 0.04 * sin(_act_t * 3.1), rig.H + 0.42 + 0.1 * bt3, -0.46 - 0.1 * bt3)
			left = left.lerp(jab, 0.9 * (1.0 - slam)).lerp(_left_rest() + Vector3(0.02, 0.02, -0.04), slam)
			left_q = Quaternion(Vector3.RIGHT, -0.9 * slam) * Quaternion(Vector3.FORWARD, -0.3 * (1.0 - slam))
			head_pitch += 0.08 * bt3 - 0.1 - 0.06 * slam
			head_yaw += 0.1 * sin(_act_t * 1.7)
			chest = chest * Quaternion(Vector3.RIGHT, -0.1 - 0.05 * bt3 - 0.06 * slam)
		"dice":
			# shake them by the ear, throw across the board, watch them roll
			var shake := 1.0 - smoothstep(0.5, 0.58, k)
			var thrown := smoothstep(0.52, 0.62, k)
			if k >= 0.58 and not _dice_fired:
				_dice_fired = true
				dice_out = true
			var cup := Vector3(-0.16, rig.H + 0.52 + 0.035 * sin(_act_t * 31.0) * shake, -0.3)
			var throw_to := Vector3(-0.04, table_top + 0.08, table_edge - 0.3)
			left = left.lerp(cup, shake).lerp(throw_to, thrown * (1.0 - smoothstep(0.75, 0.95, k)))
			left_q = Quaternion(Vector3.RIGHT, -0.6 * shake)
			head_pitch += -0.22 * thrown + 0.05 * shake
			head_yaw *= 1.0 - thrown
			jaw = -0.05 * shake * absf(sin(_act_t * 9.0))
		"cheer":
			var up3 := smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.7, 0.95, k))
			mug_goal = mug_goal.lerp(Vector3(0.2, rig.H + 0.86, -0.28), up3)
			mug_q = Quaternion(Vector3.RIGHT, -0.25 * up3)
			head_pitch += 0.28 * up3
			jaw = -0.16 * up3 * (0.7 + 0.3 * sin(_act_t * 13.0))
			chest = chest * Quaternion(Vector3.RIGHT, 0.08 * up3)
			left = left + Vector3(0.0, 0.06 * up3 * maxf(sin(_act_t * 7.0), 0.0), 0.0)
		"groan":
			var dn := smoothstep(0.0, 0.2, k) * (1.0 - smoothstep(0.75, 1.0, k))
			head_pitch -= 0.28 * dn
			head_yaw *= 1.0 - dn
			left = left.lerp(Vector3(-0.07, rig.H + 0.66, -0.22), dn)
			left_q = Quaternion(Vector3.RIGHT, -1.1 * dn)
			chest = chest * Quaternion(Vector3.RIGHT, -0.1 * dn)
			jaw = -0.04 * dn
		"attend":
			if speaking:
				var bt2: float = life.beat()
				var g2 := 0.5 + 0.5 * sin(_t * 1.8)
				jaw = -0.085 * life.jaw()
				left = left.lerp(Vector3(-0.2, rig.H + 0.4 + 0.06 * g2 + 0.08 * bt2, -0.4 - 0.04 * bt2), 0.7)
				left_q = Quaternion(Vector3.FORWARD, -0.6 * g2 - 0.4 * bt2) * Quaternion(Vector3.RIGHT, -0.5)
				head_pitch += 0.15 * bt2
				head_yaw += sin(_t * 1.1) * 0.18
				chest = chest * Quaternion(Vector3.UP, sin(_t * 1.1) * 0.14) * Quaternion(Vector3.RIGHT, -0.09 * bt2)
	_pose(spine, chest, head_yaw, head_pitch, jaw, rig.wrist_for("r", rig.mug_base, mug_goal, mug_q), mug_q, left, left_q)
	rig.apply()


func _pose(spine: Quaternion, chest: Quaternion, yaw: float, pitch: float, jaw: float, wrist_r: Vector3, mug_q: Quaternion, wrist_l: Vector3, left_q: Variant) -> void:
	rig.q(DwarfRig.B_SPINE, spine)
	rig.q(DwarfRig.B_CHEST, chest)
	rig.q(DwarfRig.B_HEAD, _head_q(yaw, pitch))
	rig.q(DwarfRig.B_JAW, Quaternion(Vector3.RIGHT, jaw))
	rig.q(DwarfRig.B_LID, Quaternion(Vector3.RIGHT, life.blink() if life else 0.0))
	if tuck and seated:
		rig.q(DwarfRig.B_SHIN_R, Quaternion(Vector3.RIGHT, -0.24))
		rig.q(DwarfRig.B_SHIN_L, Quaternion(Vector3.RIGHT, -0.2))
	elif not seated:
		# standing: the weight-bearing knee locks, the other softens
		var sw: float = life.sway() if life else 0.0
		# turning on the spot: shuffle steps with the planted feet kept where they stand (npc_life.gd turn_legs)
		var td: float = life.turn_legs(rig, global_rotation.y, _pose_step) if life else INF
		if td != INF:
			rig.position.y = td
		else:
			rig.q(DwarfRig.B_THIGH_R, Quaternion(Vector3.RIGHT, 0.04 * maxf(-sw, 0.0)))
			rig.q(DwarfRig.B_THIGH_L, Quaternion(Vector3.RIGHT, 0.04 * maxf(sw, 0.0)))
			rig.q(DwarfRig.B_SHIN_R, Quaternion(Vector3.RIGHT, -0.1 * maxf(-sw, 0.0)))
			rig.q(DwarfRig.B_SHIN_L, Quaternion(Vector3.RIGHT, -0.1 * maxf(sw, 0.0)))
	rig.fk_all()
	rig.arm_to("r", wrist_r, Vector3(0.8, -0.5, 0.3), mug_q)
	rig.arm_to("l", wrist_l, Vector3(-0.8, -0.5, 0.3), left_q)


func _head_q(yaw: float, pitch: float) -> Quaternion:
	return Quaternion(Vector3.UP, clampf(yaw, -1.0, 1.0)) * Quaternion(Vector3.RIGHT, clampf(pitch, -0.3, 0.5))


## Where the mug stands when he isn't drinking: on the table (seated), on the counter (bar).
func _mug_rest() -> Vector3:
	if lean_bar or seated:
		return Vector3(0.2, table_top + 0.003, table_edge - 0.1)
	return rig.mug_base


## The free (left) wrist at rest: forearm on the board.
func _left_rest() -> Vector3:
	if lean_bar or seated:
		return Vector3(-0.2, table_top + 0.045, table_edge - 0.06)
	return rig.rest_of("hand_l")


## Head yaw / pitch (rig space, the head's own frame at rest) to look at world point p.
func _look_at_local(p: Vector3) -> Vector2:
	var l := to_local(p) - rig.rest_of("head")
	var yaw := atan2(-l.x, -l.z)
	var pitch := atan2(l.y - 0.15, Vector2(l.x, l.z).length())
	return Vector2(clampf(yaw, -1.0, 1.0), clampf(pitch, -0.25, 0.3))


# =====================================================================================================
# the bar trip: rise, walk out, lean at the bar, walk back, sit
# =====================================================================================================

const RISE := 1.7
const WALK_SPEED := 0.75
const SWING := 0.38


func _busy_room() -> bool:
	return attend != null or speaking or (partner != null and (partner.attend != null or partner.speaking))


func _trip_step(delta: float) -> void:
	_trip_t += delta
	match _trip:
		"":
			_trip_wait -= delta
			if _trip_wait <= 0.0 and _act in ["idle", "look"] and not _busy_room() and route.size() >= 1:
				_seat_pos = global_position
				_seat_yaw = rotation.y
				var first: Vector3 = route[0]
				var to := first - global_position
				_out_yaw = atan2(-to.x, -to.z)
				_trip = "rise"
				_trip_t = 0.0
				away = true
		"rise":
			if _trip_t >= RISE:
				_trip = "out"
				_trip_t = 0.0
				_path = route.duplicate()
				_path_i = 0
		"out", "back":
			_walk_path(delta)
		"bar":
			if _trip_t > 1.0 and _act == "idle" and _act_t > 0.5 and _trip_t < 2.0:
				cue("toast", 3.4)
			if _trip_t >= 11.0 and _act in ["idle", "look"]:
				_trip = "back"
				_trip_t = 0.0
				lean_bar = false
				table_top = _home_top
				table_edge = _home_edge
				_path = route.duplicate()
				_path.reverse()
				_path.remove_at(0)
				_path.append(_seat_pos + Vector3(-sin(_out_yaw), 0, -cos(_out_yaw)) * 0.3)
				_path_i = 0
		"sit":
			if _trip_t >= RISE:
				_trip = ""
				_trip_t = 0.0
				_trip_wait = _rng.randf_range(50.0, 110.0)
				away = false
				_swap(true)
				global_position = _seat_pos
				rotation.y = _seat_yaw
				_yaw = _seat_yaw
				_next("idle")


func _walk_path(delta: float) -> void:
	if _path_i >= _path.size():
		# arrived: settle the feet and turn to the counter (out) or away from the chair (back)
		var face := PI if _trip == "out" else _out_yaw
		_walk = move_toward(_walk, 0.0, delta * 3.0)
		_yaw = rotate_toward(_yaw, face, delta * 3.5)
		rotation.y = _yaw
		if absf(angle_difference(_yaw, face)) > 0.05 or _walk > 0.05:
			_gait = fposmod(_gait + delta * 0.6 * _walk, 1.0)
			return
		_walk = 0.0
		if _trip == "out":
			_trip = "bar"
			_trip_t = 0.0
			lean_bar = true
			table_top = bar_top
			table_edge = bar_edge
			cue("idle", 1.0)
			if keep and keep.has_method("serve_at"):
				keep.call("serve_at", global_position.x, self)
		else:
			_trip = "sit"
			_trip_t = 0.0
		return
	var target := _path[_path_i]
	var here := global_position
	var flat := Vector3(target.x - here.x, 0.0, target.z - here.z)
	var d := flat.length()
	var want := atan2(-flat.x, -flat.z) if d > 0.05 else _yaw
	_yaw = lerp_angle(_yaw, want, 1.0 - exp(-delta * 6.0))
	rotation.y = _yaw
	# turn on the spot before setting off
	var facing_ok := absf(angle_difference(_yaw, want)) < 0.15       # he sets off facing the way he goes (the feet are not dragged round)
	_walk = move_toward(_walk, 1.0 if facing_ok else 0.0, delta * 3.0)
	var step := WALK_SPEED * _walk * delta if _walk >= 0.3 else 0.0
	_gait = fposmod(_gait + step / (Life.calib_stride(rig, SWING, 0.95, 0.022) * maxf(_walk, 0.35)), 1.0)
	if step >= d:
		global_position = Vector3(target.x, target.y, target.z)
		_path_i += 1
	else:
		var p := here + flat / d * step
		p.y = lerpf(here.y, target.y, clampf(step / maxf(d, 0.001) * 1.5, 0.0, 1.0))
		global_position = p


func _swap(sit: bool) -> void:
	_rig_sit.visible = sit
	_rig_stand.visible = not sit
	rig = _rig_sit if sit else _rig_stand
	seated = sit
	rig.position = Vector3.ZERO


func _animate_walk(_delta: float) -> void:
	rig.reset()
	if life:
		life.turn_reset(global_rotation.y)
	var w := _walk
	var drop := Life.walk_legs(rig, _gait, w, SWING, 0.95, 0.022)
	var s := cos(TAU * _gait)          # +1 when the right heel strikes
	rig.position = Vector3(0, drop + 0.006, 0)
	rig.q(DwarfRig.B_SPINE, Quaternion(Vector3.UP, -0.07 * s * w) * Quaternion(Vector3.FORWARD, 0.04 * s * w) * Quaternion(Vector3.RIGHT, -0.06 * w))
	rig.q(DwarfRig.B_CHEST, Quaternion(Vector3.UP, 0.11 * s * w) * Quaternion(Vector3.RIGHT, 0.02))
	var yaw := sin(_t * 0.6) * 0.15
	rig.q(DwarfRig.B_HEAD, _head_q(yaw, 0.04 + 0.02 * cos(TAU * 2.0 * _gait)))
	rig.q(DwarfRig.B_LID, Quaternion(Vector3.RIGHT, life.blink()))
	rig.fk_all()
	# mug carried at the belly; the free arm swings against the legs, elbow trailing
	var H := rig.H
	var mug := Vector3(0.2, H + 0.12 + 0.01 * cos(TAU * 2.0 * _gait), -0.3)
	rig.arm_to("r", rig.wrist_for("r", rig.mug_base, mug, Quaternion.IDENTITY), Vector3(0.8, -0.5, 0.3), Quaternion.IDENTITY)
	rig.arm_to("l", Vector3(-0.3, H + 0.04, -0.06 - 0.14 * s * w), Vector3(-0.8, -0.4, 0.3), null)
	rig.apply()


## Seated <-> standing: swivel out of the chair, lean over the feet, hand over to the standing rig
## as the hips pass over them, straighten (and the reverse to sit).
func _animate_rise() -> void:
	var k := clampf(_trip_t / RISE, 0.0, 1.0)
	if _trip == "sit":
		k = 1.0 - k
	var swivel := smoothstep(0.0, 0.32, k)
	var stand_at := _seat_pos + Vector3(-sin(_out_yaw), 0, -cos(_out_yaw)) * 0.3
	var y := lerp_angle(_seat_yaw, _out_yaw, swivel)
	rotation.y = y
	_yaw = y
	if k < 0.62:
		if rig != _rig_sit:
			_swap(true)
		global_position = _seat_pos
		rig.reset()
		var lean := smoothstep(0.3, 0.62, k)
		rig.q(DwarfRig.B_SPINE, Quaternion(Vector3.RIGHT, -0.05 - 0.45 * lean))
		rig.q(DwarfRig.B_CHEST, Quaternion(Vector3.RIGHT, -0.05 - 0.2 * lean))
		rig.q(DwarfRig.B_HEAD, _head_q(0.0, 0.25 * lean))
		rig.q(DwarfRig.B_LID, Quaternion(Vector3.RIGHT, life.blink()))
		rig.position = Vector3(0, 0.02 * lean, -0.08 * lean)
		rig.fk_all()
		var H := rig.H
		rig.arm_to("r", rig.wrist_for("r", rig.mug_base, Vector3(0.2, H + 0.05, -0.3), Quaternion.IDENTITY), Vector3(0.8, -0.5, 0.3), Quaternion.IDENTITY)
		rig.arm_to("l", Vector3(-0.16, H + 0.02, -0.3), Vector3(-0.8, -0.4, 0.3), null)
		rig.apply()
		return
	if rig != _rig_stand:
		_swap(false)
	global_position = stand_at
	rig.reset()
	# crouched over the feet, straightening: knees and hips unfold, the body comes upright
	var u := smoothstep(0.62, 1.0, k)
	var bend := 1.0 - u
	for side in 2:
		var bt := DwarfRig.B_THIGH_R if side == 0 else DwarfRig.B_THIGH_L
		rig.q(bt, Quaternion(Vector3.RIGHT, 0.85 * bend))
		rig.q(bt + 1, Quaternion(Vector3.RIGHT, -1.25 * bend))
	rig.position = Vector3(0, -0.075 * bend, 0.04 * bend)
	rig.q(DwarfRig.B_SPINE, Quaternion(Vector3.RIGHT, -0.5 * bend))
	rig.q(DwarfRig.B_CHEST, Quaternion(Vector3.RIGHT, -0.2 * bend))
	rig.q(DwarfRig.B_HEAD, _head_q(0.0, 0.25 * bend))
	rig.q(DwarfRig.B_LID, Quaternion(Vector3.RIGHT, life.blink()))
	rig.fk_all()
	var H2 := rig.H
	rig.arm_to("r", rig.wrist_for("r", rig.mug_base, Vector3(0.2, H2 + 0.12, -0.3), Quaternion.IDENTITY), Vector3(0.8, -0.5, 0.3), Quaternion.IDENTITY)
	rig.arm_to("l", Vector3(-0.28, H2 + 0.04 - 0.05 * bend, -0.1 - 0.12 * bend), Vector3(-0.8, -0.4, 0.3), null)
	rig.apply()
