extends Node
## Immersion mode (Settings > Display > "HUD rests while exploring"): the gauges (the wanderer's frame, the hotbar, the XP strip,
## the minimap) fade out while the night is quiet and come back at once when it is not. What guides stays: the objective,
## the waypoint, the prompts and the lesson lane; the compass dims to a third. "Quiet" means: no foe awake near, no great one's
## fight, no lock, nothing cast or struck in the last seconds, Gloom and Wounds low, no menu or talk. A sudden need (a blow, a
## cast, a lock, a low bar) brings it back in a quarter second; it goes again over a few seconds of quiet. Off by default.
## Added by ui/hud.gd with the group of widgets it fades. Load by path (no class_name).

const HudPrefs := preload("res://ui/hud_prefs.gd")
const FireRoad := preload("res://core/world/fire_road.gd")

const QUIET_S := 7.0                       ## seconds of calm before the gauges leave
const LOW := 0.35                          ## Wounds or Gloom above this fraction of the bar: they stay

var _gauges: Control
var _compass: Control
var _a := 1.0
var _calm := 0.0
var _poll := 0.0
var _threat := false
var _need := 0.0
var _applied := -1.0


func setup(gauges: Control, compass: Control) -> void:
	_gauges = gauges
	_compass = compass
	Events.player_hurt.connect(func(_x: float, _p: Vector3) -> void: _need = QUIET_S)
	Events.skill_cast.connect(func(_id: StringName) -> void: _need = QUIET_S * 0.6)
	Events.target_changed.connect(func(t: Node) -> void:
		if t != null:
			_need = QUIET_S)
	Events.boss_engaged.connect(func(_b: Node, _t: String) -> void: _need = QUIET_S * 2.0)


func _process(delta: float) -> void:
	if _gauges == null:
		return
	HudPrefs.ensure()
	if not HudPrefs.immersion:
		_apply(1.0, delta, 8.0)
		return
	_need = maxf(0.0, _need - delta)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.6
		_threat = _danger()
	var shown := _threat or _need > 0.0 or get_tree().paused
	_calm = 0.0 if shown else _calm + delta
	var want := 1.0 if _calm < QUIET_S else 0.0
	_apply(want, delta, 8.0 if want > _a else 0.9)


func _danger() -> bool:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		return true
	if p.wounds > p.wounds_max * LOW or p.gloom > p.gloom_max * LOW or p.is_hollowing():
		return true
	return FireRoad.blocked_reason(get_tree()) != ""


func _apply(want: float, delta: float, rate: float) -> void:
	if is_equal_approx(_a, want) and _applied == _a:
		return                                    # at rest: nothing to set
	_a = move_toward(_a, want, delta * rate)
	_applied = _a
	_gauges.modulate.a = _a
	_gauges.visible = _a > 0.01
	if _compass != null and is_instance_valid(_compass):
		_compass.modulate.a = lerpf(0.33, 1.0, _a)
