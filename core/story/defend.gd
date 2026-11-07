extends Node3D
## A task step that holds a spot (story; no class_name): kind "defend" at `at`, for `time` seconds.
## The quest runner (quest_runner.gd) adds one while the step is current and frees it when the step
## moves on. A small standing thing (a graft, a lamp, a ferry post: `prop`) has health, shown in the
## small frame at the top of the screen:
##   - the clock runs only while the wanderer stands within STAY of it,
##   - `waves` ({"at": seconds, "kinds": [...], "n": 3}) put foes from the enemy scripts round it,
##   - foes in reach of it wound it (DPS each); it mends a little when nothing is near,
##   - if it is broken the step resets: the foes are cleared, its health and the clock restart
##     (the task stays where it is; there is no dead end),
##   - the clock out ends the step (`held`).
## Step data: at, time, hp, label (the frame's title), prop, waves.

signal held
signal broken

const Kit := preload("res://core/story/encounter_kit.gd")
const QProps := preload("res://core/story/quest_props.gd")

const STAY := 16.0             ## the wanderer must be this close for the clock to run
const REACH := 2.6             ## a foe inside this wounds it
const DPS := 1.5               ## hp a second from each foe in reach
const REGEN := 0.35
const WAVE_R := 12.0
const SCAN_S := 0.25
const RESET_S := 3.0

var quest := ""
var step: Dictionary = {}
var max_hp := 30.0
var hp := 30.0
var time_left := 60.0
var elapsed := 0.0
var away := false              ## the clock is stopped: the wanderer has left it
var resets := 0                ## times it has broken (tests)
var done := false
var foes: Array[Enemy] = []
var _wave_i := 0
var _scan_t := 0.0
var _pause := 0.0
var _told_away := false
var _frame: Dictionary = {}
var _light: OmniLight3D
var _player: Node3D


func setup(qid: String, stp: Dictionary) -> void:
	quest = qid
	step = stp
	max_hp = float(stp.get("hp", 30.0))
	hp = max_hp
	time_left = float(stp.get("time", 60.0))
	name = "Defend_" + qid


func _ready() -> void:
	add_to_group("defend")
	var at := _at()
	global_position = Vector3(at.x, Kit.ground_y(self, at.x, at.y), at.y)
	QProps.make(self, "Ward", String(step.get("prop", "lantern_lit")), Transform3D(Basis.IDENTITY, global_position))
	_light = OmniLight3D.new()
	_light.name = "WardLight"
	_light.light_color = Color(1.0, 0.64, 0.32)
	_light.omni_range = 5.0
	_light.omni_attenuation = 1.3
	_light.position = Vector3(0.0, 1.0, 0.0)
	_light.shadow_enabled = false
	_light.set_meta(&"light_class", &"realm")
	add_child(_light)
	_frame = Kit.make_frame(String(step.get("label", "Hold")), max_hp)
	add_child(_frame.layer as Node)
	_show()


func _exit_tree() -> void:
	Kit.clear_foes(foes)


func _at() -> Vector2:
	return step.get("at", Vector2.ZERO) as Vector2


func ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func _process(delta: float) -> void:
	tick(delta)


## One step of time (the test drives this directly).
func tick(delta: float) -> void:
	if done:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var pl := _wanderer()
	away = pl != null and Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length() > STAY
	if away and not _told_away:
		_told_away = true
		Events.toast.emit("Go back to the %s. It cannot hold alone." % String(step.get("noun", "ward")))
	elif not away:
		_told_away = false
	if not away:
		elapsed += delta
		time_left = maxf(float(step.get("time", 60.0)) - elapsed, 0.0)
		_waves()
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = SCAN_S
		_scan(SCAN_S)
	_show()
	if hp <= 0.0:
		_break()
	elif time_left <= 0.0:
		done = true
		Kit.clear_foes(foes)
		Events.toast.emit(String(step.get("held", "It has held.")))
		held.emit()


func _wanderer() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return _player


func _waves() -> void:
	var waves: Array = step.get("waves", [])
	while _wave_i < waves.size() and elapsed >= float((waves[_wave_i] as Dictionary).get("at", 0.0)):
		var w: Dictionary = waves[_wave_i]
		_wave_i += 1
		var a0 := float(hash("%s%d%d" % [quest, _wave_i, resets]) % 628) * 0.01
		foes.append_array(Kit.spawn_ring(self, w.get("kinds", ["wretch"]), int(w.get("n", 2)), global_position, WAVE_R, a0, quest))
		Events.toast.emit(String(w.get("say", "Something comes for it.")))


func _scan(dt: float) -> void:
	Kit.prune(foes)
	var near := Kit.foes_near(get_tree(), global_position, REACH + 4.0)
	var hitters := 0
	for e: Enemy in near:
		if Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length() < REACH:
			hitters += 1
	if hitters > 0:
		hp = maxf(hp - DPS * dt * float(hitters), 0.0)
	elif near.is_empty():
		hp = minf(hp + REGEN * dt, max_hp)


func _break() -> void:
	resets += 1
	Kit.clear_foes(foes)
	Events.toast.emit(String(step.get("lost", "It is broken. Begin again.")))
	hp = max_hp
	elapsed = 0.0
	time_left = float(step.get("time", 60.0))
	_wave_i = 0
	_pause = RESET_S
	_show()
	broken.emit()


func _show() -> void:
	(_frame.bar as ProgressBar).value = hp
	var nm := String(step.get("label", "Hold"))
	(_frame.label as Label).text = nm + ("  (hold it)" if away else "")
	if _light:
		_light.light_energy = 0.15 + 0.7 * ratio()
