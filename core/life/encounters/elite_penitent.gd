extends "res://core/enemy/wretch.gd"
## The Faceless Penitent (encounters elite, the Deeper Night only). A hooded wretch with a face
## scraped blank and a scourge in each hand. Now and then it steps through the dark: a tear opens
## beside you and a red disc fills there for 0.8 s; then it is there, already rearing to strike.

const ID := "penitent"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
const STEP_EVERY := 8.0
const STEP_TELL := 0.8
var _step_cd := 4.0
var _stepping := false


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	strike_range = 1.6


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _think() -> void:
	_step_cd -= 1.0 / think_hz
	if not _stepping and _step_cd <= 0.0 and _state == CHASE and _p != null and _dist > 5.0 and _dist < 14.0 \
			and not LightGrid.is_lit(_p.global_position):
		_step_cd = STEP_EVERY
		_begin_step()
		return
	super._think()


func _begin_step() -> void:
	var side := Vector3(-_to.z, 0.0, _to.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var spot := _p.global_position + side * 2.4
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 5.0, Layers.WORLD))
	if hit.is_empty() or LightGrid.is_lit(hit.position):
		return
	spot = hit.position
	_stepping = true
	_set_state(RECOVER)
	_state_t = -STEP_TELL
	SpellFx.tear(spot, 2.2, STEP_TELL + 0.3)
	SpellFx.danger(spot, STEP_TELL, {"radius": 1.2, "color": Color(1.0, 1.0, 1.6)})
	get_tree().create_timer(STEP_TELL, false).timeout.connect(func() -> void:
		_stepping = false
		if not is_instance_valid(self) or _state == DEAD or not is_inside_tree():
			return
		SpellFx.rift_out(global_position)
		global_position = spot + Vector3.UP * 0.05
		velocity = Vector3.ZERO
		reset_physics_interpolation()
		SpellFx.rift_in(spot)
		_cache_player()
		if _p and _dist <= strike_range + 1.2 and _take_token():
			_face_dir = _to / maxf(_dist, 0.001)
			_set_state(WINDUP)
		else:
			_set_state(CHASE))
