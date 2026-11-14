extends Crawler
## Burrower: a big crawler with shovel claws and a domed, earth-crusted back. At 4.5-14 m it
## digs in (a spray of earth, a grinding rumble) and comes for you under the ground: a furrow of
## churned earth runs toward you. Where it stops a disc fills for 0.75 s -- step off it -- then it
## bursts up and is left exposed on the surface (the punish window). Underground it cannot be hit
## and does not count as a target. It will not tunnel into light.
## No class_name (project rule): the spawner preloads it.

const EARTH := Color(1.7, 1.05, 0.5)     ## the eruption throws dirt: its warning is earth ochre, not claw red
const KinLook := preload("res://core/enemy/kin_look.gd")
const DIVE := 0.45
const TUNNEL_SPEED := 7.0
const TUNNEL_MAX := 2.6
const TELL := 0.75
const ERUPT_R := 1.7
const SINK := 1.1

var _burrow_cd := 1.2
var _phase := 0           ## 0 dig in, 1 tunnel, 2 tell, 3 up
var _under := false
var _tell_at := 0.0
var _trail_t := 0.0
var _dig_tw: Tween


func _init() -> void:
	super._init()
	max_hp = 3
	hp = 3.0
	walk_speed = 3.0
	chase_range = 14.0
	hunt_leash = 18.0
	strike_gloom = 18.0
	leaper = false              # it burrows instead of pouncing
	crawler = false             # and walks (a digger, not a skitterer) until it does
	walk_speed = 3.2
	hp_bar_y = 1.05
	mass = 0.9
	role = &""


func _build() -> void:
	name = "Burrower"
	var rig := QuadRig.new()
	rig.body_height = 0.36
	rig.body_len = 1.05
	rig.hip_spread = 0.22
	rig.upper_len = 0.24
	rig.stride_len = 0.55                   # (the legs sweep ~0.27 m a half cycle: 0.75 had them skating)
	attach_rig(rig)
	rig.scale = Vector3.ONE * 1.18
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := col.shape as CapsuleShape3D
		cap.height = 0.8
		cap.radius = 0.38
		col.position.y = 0.4
	set_flesh(KinLook.dress(self, "burrower"))


func is_burrowed() -> bool:
	return _under


func _try_special(d: float) -> bool:
	_burrow_cd = maxf(0.0, _burrow_cd - 1.0 / think_hz)
	if _burrow_cd > 0.0 or d < 4.5 or d > 14.0 or _ballistic or _lit_t > 0.0 or _p == null:
		return false
	if LightGrid.is_lit(_p.global_position) or not _take_token():
		return false
	_burrow_cd = 7.0
	_phase = 0
	_drive = Vector3.ZERO
	_set_state(SPECIAL)
	if _rig and _rig.has_method("telegraph"):
		_rig.call("telegraph", DIVE)
	Sfx.play_stream(Synth.get_stream("burrow"), global_position, -2.0, 1.0)
	say("windup", global_position + Vector3.UP * 0.5, -2.0, _voice_pitch() * 0.8)
	_dirt(global_position, 30)
	if _visual:
		_dig_tw = create_tween()
		_dig_tw.tween_interval(DIVE * 0.3)
		_dig_tw.tween_property(_visual, "position:y", -SINK, DIVE * 0.7).set_ease(Tween.EASE_IN)
	return true


func _special_breakable() -> bool:
	return _phase == 0


## Anything that takes it out of the dig (a fall reset, a leash, a stray state change) brings it up
## first: never left invisible and unhittable under the ground.
func _on_state(next: int) -> void:
	if _under and next != SPECIAL:
		_surface()
	super._on_state(next)


func _special_think() -> void:
	match _phase:
		0:
			if _state_t >= DIVE:
				_go_under()
				_phase = 1
		1:
			var to := _p.global_position - global_position if _p else Vector3.ZERO
			to.y = 0.0
			if _p == null or to.length() < 0.9 or _state_t >= DIVE + TUNNEL_MAX or LightGrid.is_lit(global_position + to.normalized() * 1.2):
				_phase = 2
				_drive = Vector3.ZERO
				_tell_at = _state_t
				AttackKit.zone(self, global_position, TELL, strike_gloom * 1.2, {"radius": ERUPT_R, "fx": "dirt", "color": EARTH, "h": 1.8})
		2:
			if _state_t >= _tell_at + TELL:
				_surface()
				_set_state(RECOVER)
				_state_t = -0.75
		_:
			_set_state(RECOVER)


func _special_frame(delta: float) -> void:
	if _phase == 1 and _p != null:
		var to := _p.global_position - global_position
		to.y = 0.0
		_drive = to.normalized() * TUNNEL_SPEED if to.length() > 0.05 else Vector3.ZERO
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.09
			Vfx.scorch(global_position, 0.45, Color(0.05, 0.03, 0.02), 0.4)       # the path is a seam in the ground
			Vfx.burst(global_position + Vector3.UP * 0.05, Color(0.2, 0.15, 0.11, 0.9), {"count": 5, "life": 0.7, "speed": Vector2(0.6, 2.2), "size": 0.1, "gravity": -7.0, "additive": false, "radius": 0.25})
	elif _phase == 2:
		_drive = Vector3.ZERO
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.15
			Vfx.burst(global_position + Vector3.UP * 0.05, Color(0.2, 0.15, 0.11, 0.9), {"count": 4, "life": 0.5, "speed": Vector2(0.3, 1.2), "size": 0.09, "gravity": -6.0, "additive": false, "radius": ERUPT_R * 0.6})


func _go_under() -> void:
	_under = true
	collision_layer = 0
	remove_from_group(Groups.ENEMY)
	add_to_group(&"burrowed")                    # still a living foe for the pack's last-blow beat
	if _visual:
		_visual.visible = false
	if _hp_bar:
		_hp_bar.visible = false
	for pip in _pips:
		pip.visible = false


func _surface() -> void:
	_under = false
	collision_layer = Layers.HURTBOX | Layers.PROPS
	add_to_group(Groups.ENEMY)
	remove_from_group(&"burrowed")
	if _visual:
		_visual.visible = true
		var tw := create_tween()
		tw.tween_property(_visual, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	velocity.y = 4.0
	_refresh_pips()
	if _rig and _rig.has_method("strike"):
		_rig.call("strike")
	_dirt(global_position, 40)
	say("alert", global_position + Vector3.UP * 0.5, -4.0, _voice_pitch())


func _dirt(at: Vector3, n: int) -> void:
	Vfx.burst(at + Vector3.UP * 0.2, Color(0.2, 0.15, 0.11, 0.95), {"count": n, "life": 0.9, "speed": Vector2(2.0, 5.5), "size": 0.12, "gravity": -11.0, "additive": false, "radius": 0.4})


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _under and _hp_bar:
		_hp_bar.visible = false
	elif not _under and _state != SPECIAL and _visual and _visual.position.y < -0.001 and not (_dig_tw and _dig_tw.is_running()):
		_visual.position.y = move_toward(_visual.position.y, 0.0, delta * 5.0)    # broken off mid-dig: climb back out


## Staggered or riposted mid-dig (only the dig-in can be broken): it climbs back out.
func stagger(extra_time := 0.0) -> void:
	if _under:
		return
	if _dig_tw:
		_dig_tw.kill()
	super.stagger(extra_time)


func riposted() -> void:
	if _under:
		return
	if _dig_tw:
		_dig_tw.kill()
	super.riposted()


func voice_family() -> String:
	return "burrower"


func _hit_sound() -> String:
	return "chitin"
