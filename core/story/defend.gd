extends WardTarget
## A task step that holds a spot (story; no class_name): kind "defend" at `at`, for `time` seconds.
## The quest runner (quest_runner.gd) adds one while the step is current and frees it when the step
## moves on. A small standing thing (a graft, a lamp, a ferry post: `prop`) has health, shown in the
## small frame at the top of the screen:
##   - the clock runs only while the wanderer stands within STAY of it,
##   - `waves` ({"at": seconds, "kinds": [...], "n": 3}) put foes from the enemy scripts round it,
##   - the foes sent at it (Enemy.ward) go for it and wound it with their real blows (WardTarget);
##     a foe the wanderer hits, or one she comes close to, turns on her instead; it mends a
##     little when nothing is near,
##   - if it is broken the step resets: the foes are cleared, its health and the clock restart
##     (the task stays where it is; there is no dead end),
##   - the clock out ends the step (`held`).
## Step data: at, time, hp, label (the frame's title), prop, waves.
## The same node keeps a VIGIL (kind "vigil", docs/QUEST_VERBS.md): nothing standing to hurt, only the wanderer who
## keeps a place. The clock runs only while she is within the step's `r` (default 8 m) of `at`; `gloom` (a rate a
## second, Player units; the whole bar is 100) rises while she keeps it; `waves` come as above but go for her, not for
## a ward; the frame's bar fills with the time kept. There is nothing to break: the clock out ends the step.
## Step data: at, r, time, gloom, waves, label, noun, held, away (the toast when she leaves), prop (marks the place).

signal held
signal broken

const Kit := preload("res://core/story/encounter_kit.gd")
const QProps := preload("res://core/story/quest_props.gd")

const STAY := 16.0             ## the wanderer must be this close for the clock to run
const REGEN := 0.35
const WAVE_R := 12.0
const SCAN_S := 0.25
const RESET_S := 3.0

var quest := ""
var step: Dictionary = {}
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
var _vigil := false            ## a vigil: no ward to hurt, the wanderer is what the foes want


func setup(qid: String, stp: Dictionary) -> void:
	quest = qid
	step = stp
	_vigil = String(stp.get("kind", "")) == "vigil"
	max_hp = 1.0 if _vigil else float(stp.get("hp", 30.0))
	hp = max_hp
	time_left = float(stp.get("time", 60.0))
	name = "Defend_" + qid


func _ready() -> void:
	add_to_group("defend")
	var at := _at()
	global_position = Vector3(at.x, Kit.ground_y(self, at.x, at.y), at.y)
	if not _vigil or step.has("prop"):
		QProps.make(self, "Ward", String(step.get("prop", "lantern_lit")), Transform3D(Basis.IDENTITY, global_position))
	if not _vigil:
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
	if _vigil:
		(_frame.bar as ProgressBar).max_value = float(step.get("time", 60.0))
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
	away = pl != null and Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length() > (float(step.get("r", 8.0)) if _vigil else STAY)
	if away and not _told_away:
		_told_away = true
		Events.toast.emit(String(step.get("away", "Stay by the %s. The vigil stops while you are gone." % String(step.get("noun", "spot")))) if _vigil else "Go back to the %s. It cannot hold alone." % String(step.get("noun", "ward")))
	elif not away:
		_told_away = false
	if not away:
		elapsed += delta
		time_left = maxf(float(step.get("time", 60.0)) - elapsed, 0.0)
		_waves()
		if _vigil and pl is Player and float(step.get("gloom", 0.0)) > 0.0:
			(pl as Player).add_gloom(float(step.gloom) * delta)       # the dark leans on whoever keeps the place
	hurt_t += delta
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
		foes.append_array(Kit.spawn_ring(self, w.get("kinds", ["wretch"]), int(w.get("n", 2)), global_position, WAVE_R, a0, quest, TAU, null if _vigil else self))
		Events.toast.emit(String(w.get("say", "Something comes for it.")))


func _scan(dt: float) -> void:
	Kit.prune(foes)
	if Kit.foes_near(get_tree(), global_position, 6.6).is_empty() and hurt_t > 3.0:
		hp = minf(hp + REGEN * dt, max_hp)


## Threat target: while it is broken (the pause) or held out, it draws no foe.
func threat_alive() -> bool:
	return not _vigil and hp > 0.0 and _pause <= 0.0 and not done


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
	(_frame.bar as ProgressBar).value = elapsed if _vigil else hp
	var nm := String(step.get("label", "Hold"))
	(_frame.label as Label).text = nm + ("  (hold it)" if away else "")
	if _light:
		_light.light_energy = 0.15 + 0.7 * ratio()
