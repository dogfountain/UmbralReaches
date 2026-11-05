class_name TimeSlow
extends RefCounted
## The one owner of Engine.time_scale. Hitstop, a perfect dodge's slow-mo and a pack's last-foe
## slow all ask here; the slowest live request wins, each ends on its own real-time timer, and an
## ending request never restores normal speed while another is still running.

static var _reqs: Array[Dictionary] = []     ## {token, scale, until (real ms)}
static var _token := 0


## Hold the world at `scale` for `sec` real seconds (stacks with other requests).
static func request(tree: SceneTree, scale: float, sec: float) -> void:
	if tree == null:
		return
	_token += 1
	var tok := _token
	_reqs.append({"token": tok, "scale": scale, "until": Time.get_ticks_msec() + int(sec * 1000.0)})
	_apply()
	tree.create_timer(sec, true, false, true).timeout.connect(func() -> void: _end(tok))


## True while any request is slowing the world.
static func active() -> bool:
	_prune()
	return not _reqs.is_empty()


static func _end(tok: int) -> void:
	for i in range(_reqs.size() - 1, -1, -1):
		if int(_reqs[i]["token"]) == tok:
			_reqs.remove_at(i)
	_apply()


static func _prune() -> void:
	var now := Time.get_ticks_msec()
	for i in range(_reqs.size() - 1, -1, -1):
		if int(_reqs[i]["until"]) < now - 250:     # its timer was lost (scene change): drop it
			_reqs.remove_at(i)


static func _apply() -> void:
	_prune()
	var s := 1.0
	for r in _reqs:
		s = minf(s, float(r["scale"]))
	Engine.time_scale = s
