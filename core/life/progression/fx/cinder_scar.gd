extends Node3D
## Ember Lance rank III (progression): where a full charge bursts, the ground keeps burning for
## LIFE seconds. Every TICK it scorches whatever stands in it (damage x spell power) and Marks it
## every other tick. `follow(bolt)` rides along with a fired lance and lights where it bursts.

const LIFE := 3.0
const RADIUS := 2.6
const TICK := 0.5
const DMG := 0.5
const DB := preload("res://core/life/progression/upgrade_db.gd")

var _bolt: Node3D
var _wait := 0.0
var _lit := false
var _t := 0.0
var _tick := 0.0
var _n := 0
var _light: OmniLight3D
var _embers: GPUParticles3D


## Wait for `bolt` (a MagicBolt) to burst, then light a scar on the ground under the burst.
static func follow(bolt: Node3D) -> void:
	var host := bolt.get_tree().current_scene
	if host == null:
		return
	var s := new()
	s.name = "CinderScar"
	s._bolt = bolt
	host.add_child(s)


## Light one directly (tests, renders): `at` is on the ground.
static func light_at(host: Node, at: Vector3) -> Node3D:
	var s := new()
	s.name = "CinderScar"
	host.add_child(s)
	s.global_position = at
	s._lit = true
	s._light_up()
	return s


func _physics_process(delta: float) -> void:
	if not _lit:
		_await_burst(delta)
		return
	_t += delta
	_tick -= delta
	_light.light_energy = 2.2 * clampf((LIFE - _t) / 0.8, 0.0, 1.0) * (1.0 + sin(_t * 19.0) * 0.08)
	if _tick <= 0.0 and _t < LIFE:
		_tick = TICK
		_n += 1
		_scorch()
	if _t >= LIFE:
		_embers.emitting = false
		if _t >= LIFE + 1.2:
			queue_free()


## Phase one: ride along until the lance bursts, then find the ground under the burst.
func _await_burst(delta: float) -> void:
	_wait += delta
	if not is_instance_valid(_bolt) or _wait > 4.0:
		queue_free()
		return
	if not bool(_bolt.get("_spent")):
		return
	var at := _bolt.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at + Vector3.DOWN * 3.5, Layers.WORLD | Layers.PROPS)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.55:
		queue_free()
		return
	global_position = hit.position
	_lit = true
	_light_up()


func _light_up() -> void:
	SpellFx.disc(global_position, RADIUS, 1, SpellFx.EMBER * 0.5, SpellFx.EMBER_HOT * 0.7, LIFE + 0.4)
	Vfx.scorch(global_position + Vector3.UP * 0.3, RADIUS * 1.1, Color(2.4, 0.8, 0.25), LIFE + 1.5)
	_embers = Vfx.emitter(Color(2.4, 0.85, 0.25), {"count": 50, "life": 1.1, "speed": Vector2(0.4, 1.6), "size": 0.05, "gravity": -1.2, "ring": RADIUS * 0.85, "turbulence": true, "trail": 0.06})
	add_child(_embers)
	_embers.emitting = true
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = 2.2
	_light.omni_range = RADIUS   # the light ends where the burn does
	_light.distance_fade_enabled = true   # a scar walked away from fades with distance
	_light.distance_fade_begin = 24.0
	_light.distance_fade_length = 8.0
	_light.shadow_enabled = false
	_light.position = Vector3.UP * 0.6
	_light.set_meta("light_class", "player_orb")
	add_child(_light)


func _scorch() -> void:
	var hurt := false
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - global_position
		if Vector2(d.x, d.z).length() <= RADIUS and absf(d.y) < 2.2:
			if _n % 2 == 1:
				e.add_mark(1)
			e.take_hit(DMG * float(DB.get_mod("power", 1.0)), self)
			Vfx.burst(e.global_position + Vector3.UP * 0.4, Color(2.6, 1.0, 0.3), {"count": 10, "life": 0.4, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": -3.0, "dir": Vector3.UP, "spread": 40.0})
			hurt = true
	if hurt:
		Vfx.ring(global_position + Vector3.UP * 0.05, RADIUS, Color(2.4, 0.8, 0.25), 0.3, 0.06)
