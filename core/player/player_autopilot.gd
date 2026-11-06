class_name PlayerAutopilot
extends Node
## Demo and test drive: the waypoint walker. Only built when start_autopilot() runs.
## Part of Player (core/player/player.gd): Player owns this node and keeps its public surface;
## the state lives on Player unless declared here.

var player: Player

var _waypoints: Array[Marker3D] = []
var _wp := 0


func _init(p: Player) -> void:
	player = p


func start_autopilot(markers: Array[Marker3D]) -> void:
	_waypoints = markers
	_wp = 0
	player._waiting = false
	player.autopilot = true


# --- Autopilot (demo recording and smoke tests) -----------------------------
# Each Marker3D may carry metadata: wait (s), kindle (bool), sprint (bool), pitch (rad), shot (bool).

func _autopilot(delta: float) -> Array:
	if _wp >= _waypoints.size():
		if player.autopilot:
			player.autopilot = false
			Events.autopilot_finished.emit()
		return [Vector3.ZERO, false]
	var m := _waypoints[_wp]
	player._pitch = lerpf(player._pitch, float(m.get_meta("pitch", -0.12)), 1.0 - exp(-1.5 * delta))
	if player._waiting:
		if m.get_meta("kindle", false) and player._interact_target != null:
			player._try_interact()   # keep trying while waiting: arrival can land a few cm outside interact range
		if m.has_meta("yaw"):
			player._yaw = lerp_angle(player._yaw, float(m.get_meta("yaw")), 1.0 - exp(-1.5 * delta))
		player._wait -= delta
		if player._wait <= 0.0:
			player._waiting = false
			_wp += 1
		return [Vector3.ZERO, false]
	var to := m.global_position - player.global_position
	to.y = 0.0
	if to.length() < 0.6:
		Events.autopilot_reached.emit(m.name)
		if m.get_meta("kindle", false):
			player._try_interact()
		var w := float(m.get_meta("wait", 0.0))
		if w > 0.0:
			player._waiting = true
			player._wait = w
		else:
			_wp += 1
		return [Vector3.ZERO, false]
	var dir := to.normalized()
	player._yaw = lerp_angle(player._yaw, atan2(-dir.x, -dir.z), 1.0 - exp(-2.0 * delta))
	return [dir, bool(m.get_meta("sprint", false))]
