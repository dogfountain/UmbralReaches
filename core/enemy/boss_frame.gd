class_name BossFrame
extends Node
## the boss intro's camera. For the beat a boss rises (BossKit.INTRO plus the roar), the
## wanderer's view turns to him and settles a little low, so he fills the frame from the third-person
## camera instead of standing somewhere off to one side behind a stone. It only steers yaw and pitch
## (Player.set_view, the same channels as a lock-on); control returns the moment the beat ends, or at once
## if the wanderer locks a target, mounts, or throws the view himself with the stick or mouse.
## Costs one small node for about three seconds per fight, no allocations per frame.

const HOLD := 3.1               ## seconds the frame is held (rise, title, roar)
const EASE_IN := 4.2            ## 1/s: how fast the view comes round
const SIDE := 0.17              ## radians: the boss sits right of the wanderer in frame
const PITCH :=-0.06            ## a touch below the default -0.18: lower camera, taller boss
const LOOK_HEIGHT := 0.55       ## aim at this fraction of his height (head and shoulders, not his feet)

var _boss: Enemy
var _p: Player
var _t := 0.0
var _last_yaw := 0.0
var _last_pitch := 0.0


static func start(host: Node, boss: Enemy) -> void:
	var p := host.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null or boss == null:
		return
	var f := BossFrame.new()
	f.name = "BossFrame"
	f._boss = boss
	f._p = p
	host.add_child(f)


func _ready() -> void:
	_last_yaw = _p._yaw
	_last_pitch = _p._pitch


func _process(delta: float) -> void:
	_t += delta
	if _t > HOLD or not is_instance_valid(_boss) or not is_instance_valid(_p) or not _boss.is_alive():
		queue_free()
		return
	if is_instance_valid(_p._lock):
		queue_free()
		return
	# the wanderer took the view himself (mouse or stick moved it since our last frame): hand it back
	if absf(angle_difference(_p._yaw, _last_yaw)) > 0.06 or absf(_p._pitch - _last_pitch) > 0.06:
		queue_free()
		return
	var to := _boss.global_position - _p.global_position
	to.y = 0.0
	if to.length_squared() < 1.0:
		return
	var fade := minf(1.0, (HOLD - _t) / 0.7)                 # lets go gently
	var k := 1.0 - exp(-EASE_IN * delta)
	# aimed a little to the left of him, so he stands to the right of the wanderer instead of behind his hood
	var yaw := lerp_angle(_p._yaw, atan2(-to.x, -to.z) + SIDE, k * fade)
	var pitch := lerpf(_p._pitch, PITCH, k * fade)
	_p.set_view(yaw, pitch)
	_last_yaw = yaw
	_last_pitch = pitch
