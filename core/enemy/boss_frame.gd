class_name BossFrame
extends Node
## the boss intro's camera. For the beat a boss rises (BossKit.INTRO plus the roar), the
## wanderer's view turns to him and settles a little low, so he fills the frame from the third-person
## camera instead of standing somewhere off to one side behind a stone. It only steers yaw and pitch
## (Player.set_view, the same channels as a lock-on); control returns the moment the beat ends, or at once
## if the wanderer locks a target, mounts, or throws the view himself with the stick or mouse.
## Costs one small node for about three seconds per fight, no allocations per frame.

const HOLD := 4.2               ## seconds the frame is held (rise, title, roar)
const EASE_IN := 4.2            ## 1/s: how fast the view comes round
const SIDE := 0.17              ## radians: the boss sits right of the wanderer in frame
const PITCH :=-0.06            ## a touch below the default -0.18: lower camera, taller boss
const LOOK_HEIGHT := 0.7        ## aim at this fraction of his height (head and shoulders, not his feet)
const PITCH_MAX := 0.42         ## the view never tips further up than this to find a tall boss's face
const LIGHT_E := 7.0            ## the rise light: the boss stands in his own pool for the beat, whatever the hall is
const LIGHT_COL := Color(1.0, 0.8, 0.58)
const MIN_FILL := 0.40          ## he must fill this much of the frame's height; a boss that would not is zoomed in on
const FILL_TO := 0.47           ## ... to this much (the field of view narrows; it widens again when the frame lets go)
const TOP_LIMIT := 0.375        ## the top of his head stays below this much of the screen: the name card (title and epithet) is above it

var _boss: Enemy
var _look := LOOK_HEIGHT        ## where in his height the view aims (a higher value seats him lower in the frame, under the title)
var _height := 3.0              ## his top above his feet, measured from his meshes once
var _light: OmniLight3D
var _p: Player
var _t := 0.0
var _last_yaw := 0.0
var _last_pitch := 0.0
var _turn := false              ## he rises with his back to the wanderer and turns to face him inside the title's time (the Abbot)
var _remeasure := 0.0


static func start(host: Node, boss: Enemy, look := LOOK_HEIGHT, turn := false) -> void:
	var p := host.get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null or boss == null:
		return
	var f := BossFrame.new()
	f.name = "BossFrame"
	f._boss = boss
	f._look = look
	f._turn = turn
	f._p = p
	f._height = clampf(_measure(boss), 1.6, 9.0)
	host.add_child(f)


## The boss's height from the tops of its meshes (the rig is built by now).
static func _measure(boss: Node3D) -> float:
	var top := boss.global_position.y + 1.6
	for n: Node in boss.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box := mi.global_transform * mi.get_aabb()
		top = maxf(top, box.end.y)
	return top - boss.global_position.y


func _exit_tree() -> void:
	if is_instance_valid(_p):
		_p.fov_zoom_want = 1.0


func _ready() -> void:
	process_priority = 1000          # after the boss's own turning: the facing below is the last word
	_last_yaw = _p._yaw
	_last_pitch = _p._pitch
	# he rises facing the wanderer (he stood with his back to the camera in the Ossuary), in a light of his own
	var to := _p.global_position - _boss.global_position
	to.y = 0.0
	if _boss._face != null and to.length_squared() > 0.01:
		_boss._face.global_rotation.y = atan2(-to.x, -to.z)
	_light = OmniLight3D.new()
	_light.name = "RiseLight"
	_light.light_color = LIGHT_COL
	_light.light_energy = 0.0
	_light.omni_range = clampf(_height * 3.4, 12.0, 26.0)
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_light.light_specular = 0.4
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_remeasure -= delta
	if _remeasure <= 0.0 and is_instance_valid(_boss):
		_remeasure = 0.2
		_height = clampf(_measure(_boss), 1.6, 9.0)       # a crown or horn that grows with the rise is counted as it grows
	if is_instance_valid(_boss) and is_instance_valid(_p) and _boss._face != null:
		var tw := _p.global_position - _boss.global_position
		tw.y = 0.0
		if tw.length_squared() > 0.01:
			var yw := atan2(-tw.x, -tw.z)
			if _turn:
				yw += PI * (1.0 - smoothstep(0.4, 1.6, _t))
			_boss._face.global_rotation.y = yw
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
	_lit(to)
	if to.length_squared() < 1.0:
		return
	var fade := minf(1.0, (HOLD - _t) / 0.7)                 # lets go gently
	var k := 1.0 - exp(-EASE_IN * delta)
	# aimed a little to the left of him, so he stands to the right of the wanderer instead of behind his hood
	var yaw := lerp_angle(_p._yaw, atan2(-to.x, -to.z) + SIDE, k * fade)
	var rise := atan2(_boss.global_position.y + _height * _look - (_p.global_position.y + 1.7), to.length() + _p.ARM_LEN * 0.8)
	# the zoom: framed at the player's own field of view he would fill less than MIN_FILL of the height: narrow it
	var cam := _p._cam
	var d := maxf(cam.global_position.distance_to(_boss.global_position + Vector3.UP * _height * 0.5), 1.0)
	var fill := _height / (2.0 * d * tan(deg_to_rad(Settings.fov) * 0.5))
	_p.fov_zoom_want = clampf(2.0 * atan(_height / (2.0 * d * FILL_TO)) / deg_to_rad(Settings.fov), 0.3, 1.0) if fill < MIN_FILL else 1.0
	# the head clear of the name card: the view is never lower than the one that seats the top of him TOP_LIMIT down the screen
	# (computed from the camera's own pose, not chased: a chase winds up against the view's own ease and overshoots)
	var fwd := -cam.global_basis.z
	var off := asin(clampf(fwd.y, -1.0, 1.0)) - _p._pitch                   # the camera's lift over the view's pitch
	var top := _boss.global_position + Vector3.UP * _height
	var hd := Vector2(top.x - cam.global_position.x, top.z - cam.global_position.z).length()
	var e_top := atan2(top.y - cam.global_position.y, maxf(hd, 0.5))
	var half := atan((0.5 - TOP_LIMIT) * 2.0 * tan(deg_to_rad(Settings.fov * _p.fov_zoom_want) * 0.5))
	var need := e_top - half - off
	var want := clampf(maxf(rise, need), PITCH, PITCH_MAX + 0.6)
	var pitch := lerpf(_p._pitch, want, k * fade)
	_p.set_view(yaw, pitch)
	_last_yaw = yaw
	_last_pitch = pitch


## Ramp the rise light in, hold it, let it go with the frame; it stands before him, at his face.
func _lit(to: Vector3) -> void:
	if _light == null:
		return
	var up := smoothstep(0.0, 0.5, _t) * (1.0 - smoothstep(HOLD - 1.2, HOLD, _t))
	_light.light_energy = LIGHT_E * up
	var front := -to.normalized() if to.length_squared() > 0.01 else Vector3.ZERO
	_light.global_position = _boss.global_position + Vector3.UP * _height * 0.78 + front * _height * 0.5
