extends Node3D
## An open Umbral Well (r28): a black heart over a rift disc. For `life` seconds it drags every foe
## within `radius` toward its heart and slows it, Marks it once a second, then collapses:
## 1 damage + 0.5 per Mark (Marks kept). Rank II (hungry) swallows spit and throws it back as shards
## on the collapse; rank III (horizon) detonates every Mark inside instead (spent, as the Nova).
## `ignite()` (an Ember Lance bursting over it) lights a MAELSTROM: it burns all it holds and
## holds a second longer. In group "umbral_well" so the Lance can find it.

const Afflict := preload("res://core/skills/afflict.gd")
const CombatState := preload("res://core/skills/combat_state.gd")
const Combo := preload("res://core/skills/combo.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const HEART := preload("res://core/skills/well_heart.gdshader")
const PULL := 7.5
const SLOW := 0.5
const OPEN := 0.25

static var _heart_mesh: SphereMesh
static var _heart_mat: ShaderMaterial

var radius := 4.5
var life := 3.0
var power := 1.0
var hungry := false
var horizon := false
var mode: StringName = &""     ## r36 Ash Seed: &"bloom" pushes out (and slows harder), &"wander" drifts
const WANDER := 2.5             ## m/s a wandering well drifts toward the nearest foe
var mark_dmg := 0.0            ## Lisle's Tally and the Oath of the Tally add to each detonated Mark
var by: Node3D
var swallowed := 0
var burning := false
var _t := 0.0
var _tick := 0.0
var _mark_tick := 0.6
var _burn_tick := 0.0
var _heart: MeshInstance3D
var _light: OmniLight3D
var _swirl: GPUParticles3D
var _smoke: GPUParticles3D
var _fire: GPUParticles3D
var _done := false


func _ready() -> void:
	name = "UmbralWell"
	add_to_group(&"umbral_well")
	if _heart_mesh == null:
		_heart_mesh = SphereMesh.new()
		_heart_mesh.radius = 1.0
		_heart_mesh.height = 2.0
		_heart_mesh.radial_segments = 24
		_heart_mesh.rings = 12
		_heart_mat = ShaderMaterial.new()
		_heart_mat.shader = HEART
	_heart = MeshInstance3D.new()
	_heart.mesh = _heart_mesh
	_heart.material_override = _heart_mat
	_heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heart.position = Vector3.UP * 1.1
	_heart.scale = Vector3.ONE * 0.05
	add_child(_heart)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.62, 0.4, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = radius
	_light.shadow_enabled = false
	_light.position = Vector3.UP * 1.2
	_light.set_meta("light_class", "player_orb")
	add_child(_light)
	_swirl = Vfx.emitter(Color(1.3, 0.55, 3.0), {"count": 90, "life": 0.9, "speed": Vector2(0.2, 0.6), "size": 0.06, "ring": radius * 0.95, "radial": -radius * 3.2, "swirl": 7.0, "gravity": 0.9, "damping": 0.5, "trail": 0.1})
	_swirl.position = Vector3.UP * 0.25
	add_child(_swirl)
	_swirl.emitting = true
	_smoke = Vfx.emitter(Color(0.02, 0.0, 0.05, 0.75), {"count": 22, "life": 1.1, "speed": Vector2(0.1, 0.4), "size": 0.5, "ring": radius * 0.7, "radial": -radius * 1.6, "swirl": 3.0, "gravity": 0.6, "additive": false, "turbulence": true})
	_smoke.position = Vector3.UP * 0.4
	add_child(_smoke)
	_smoke.emitting = true
	SpellFx.disc(global_position, radius, 0, SpellFx.VIOLET * 0.32, SpellFx.VIOLET_HOT * 0.42, life + OPEN + 0.3)   # a held field: quieter than a Nova
	SpellFx.implosion(global_position, radius)
	StaffSfx.play("well_open", global_position + Vector3.UP, -2.0)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var open := clampf(_t / OPEN, 0.0, 1.0)
	var left := life + OPEN - _t
	var swell := clampf(1.0 - left / 0.6, 0.0, 1.0)
	_heart.scale = Vector3.ONE * lerpf(0.05, 0.42 + 0.08 * sin(_t * 9.0), open) * (1.0 + swell * 0.5)
	_heart.set_instance_shader_parameter(&"life", swell)
	_light.light_energy = (2.4 if burning else 1.6) * open * (1.0 + 0.1 * sin(_t * 17.0))
	if _t < OPEN:
		return
	_tick -= delta
	_mark_tick -= delta
	if mode == &"wander":
		_wander(delta)
	if _tick <= 0.0:
		_tick = 0.1
		_drag()
	if hungry:
		_swallow()
	if burning:
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			for e in _held():
				Afflict.burn(e, 1.2, Afflict.BURN_DMG * 1.4)
	if left <= 0.0:
		_collapse()


func _held() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null or (e.has_method("is_alive") and not e.call("is_alive")):
			continue
		var d := e.global_position - global_position
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 3.0:
			out.append(e)
	return out


func _drag() -> void:
	var mark := _mark_tick <= 0.0
	if mark:
		_mark_tick = 1.0
	for e in _held():
		var d := global_position - (e as Node3D).global_position
		d.y = 0.0
		var dist := d.length()
		var boss := bool(e.get("boss"))
		if dist > 0.6:
			var pull := d / dist * PULL * (0.45 + 0.55 * dist / radius) * (0.35 if boss else 1.0)
			if mode == &"bloom":
				pull = -d / dist * PULL * 0.8 * (0.35 if boss else 1.0)
			e.set("_knock", pull)
		elif mode == &"bloom":
			e.set("_knock", Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, randf() * TAU) * PULL * 0.8)
		Afflict.slow(e, (0.3 if mode == &"bloom" else SLOW) if not boss else 0.8, 0.25)
		if mark:
			e.call("add_mark", 1)


## Hungry Dark: spit that comes near is swallowed (thrown back on the collapse).
func _swallow() -> void:
	for node in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		var shot := node as Node3D
		if shot == null or not shot.has_method("pop"):
			continue
		if shot.global_position.distance_to(global_position + Vector3.UP) > radius * 1.25:
			continue
		Vfx.arc(shot.global_position, global_position + Vector3.UP * 1.1, Color(1.4, 0.6, 3.0), 0.25, 0.2)
		shot.call("pop")
		swallowed += 1


## A Lance burst over the well: MAELSTROM.
func ignite() -> void:
	if burning or _done:
		return
	burning = true
	life += 1.0
	_heart.set_instance_shader_parameter(&"heat", 1.0)
	_light.light_color = Color(1.0, 0.5, 0.2)
	_fire = Vfx.emitter(Color(2.8, 1.0, 0.3), {"count": 80, "life": 0.8, "speed": Vector2(0.3, 1.2), "size": 0.055, "ring": radius * 0.9, "radial": -radius * 2.8, "swirl": 9.0, "gravity": 3.0, "trail": 0.1})
	_fire.position = Vector3.UP * 0.2
	add_child(_fire)
	_fire.emitting = true
	SpellFx.column(global_position, radius * 0.35, 4.5, 1.2)
	SpellFx.disc(global_position, radius, 1, SpellFx.EMBER * 0.4, SpellFx.EMBER_HOT * 0.55, life - (_t - OPEN) + 0.3)
	StaffSfx.play("maelstrom", global_position + Vector3.UP, 0.0)
	Combo.note("MAELSTROM", global_position + Vector3.UP * 2.6, Color(1.0, 0.6, 0.35), "the well burns")
	_burn_tick = 0.0


func _collapse() -> void:
	_done = true
	var at := global_position + Vector3.UP * 1.1
	var total := 0
	for e in _held():
		var marks := int(e.get("marks")) if e.get("marks") != null else 0
		var dmg := 1.0
		if horizon:
			marks = int(e.call("take_marks"))
			dmg += float(marks) * (1.0 + mark_dmg)
			if marks > 0:
				Vfx.arc(at, _chest(e), Color(1.8, 1.0, 3.2), 0.28, 0.3)
		else:
			dmg += 0.5 * float(marks)
		total += marks
		CombatState.strike(e, dmg * power * (Afflict.shatter(e) if horizon else 1.0), &"umbral", self)
		var away := (e as Node3D).global_position - global_position
		away.y = 0.0
		if away.length() > 0.1:
			e.call("shove", away.normalized() * 5.0)
	if swallowed > 0:
		var skip := {}
		for k in mini(swallowed, 6):
			var t := _nearest(at, 14.0, skip)
			if t == null:
				break
			skip[t.get_instance_id()] = true
			var to := _chest(t)
			Vfx.arc(at, to, Color(2.0, 0.9, 3.4), 0.3, 0.25)
			Vfx.burst(to, Color(2.0, 1.0, 3.4), {"count": 16, "life": 0.35, "speed": Vector2(2.0, 5.0), "size": 0.045, "gravity": -4.0, "trail": 0.06})
			t.call("add_mark", 1)
			CombatState.strike(t, 1.0 * power, &"umbral", self)
	if horizon and total >= 3:
		Combo.note("DETONATION", at + Vector3.UP * 1.5, Color(0.85, 0.55, 1.0), "%d Marks" % total)
	_heart.visible = false
	_swirl.emitting = false
	_smoke.emitting = false
	if _fire:
		_fire.emitting = false
	var col := Color(2.6, 0.9, 0.3) if burning else Color(1.0, 0.4, 2.6)
	SpellFx.shell(at, radius * 0.9, 0.2, col, 0.18)
	SpellFx.shell(at, 0.2, radius, col, 0.35)
	SpellFx.disc(global_position, radius, 0 if not burning else 1, SpellFx.VIOLET if not burning else SpellFx.EMBER, SpellFx.VIOLET_HOT if not burning else SpellFx.EMBER_HOT, 0.6)
	Vfx.burst(at, col, {"count": 60, "life": 0.5, "speed": Vector2(4.0, 9.0), "size": 0.05, "gravity": -4.0, "trail": 0.09})
	Vfx.burst(at, Color(0.03, 0.0, 0.06, 0.85), {"count": 24, "life": 0.7, "speed": Vector2(3.0, 6.0), "size": 0.35, "gravity": 0.0, "damping": 5.0, "additive": false})
	Vfx.light(at, Color(col.r, col.g, col.b) * 0.35, 5.0, radius * 2.6, 0.4)
	StaffSfx.play("well_collapse", at, 0.0)
	if by and is_instance_valid(by) and by.global_position.distance_to(at) < 12.0 and by.has_method("kick"):
		by.call("kick", 0.6)
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 0.0, 0.4)
	get_tree().create_timer(1.3, false).timeout.connect(queue_free)


func _nearest(at: Vector3, r: float, skip: Dictionary) -> Node3D:
	var best: Node3D = null
	var best_d := r
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null or skip.has(e.get_instance_id()) or (e.has_method("is_alive") and not e.call("is_alive")):
			continue
		var d := e.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = e
	return best


static func _chest(e: Node3D) -> Vector3:
	var h: Variant = e.get("hp_bar_y")
	return e.global_position + Vector3.UP * (float(h) * 0.55 if h != null else 1.0)


## r36 Wander: drift toward the nearest living foe (within twice the radius), keeping to the ground.
func _wander(delta: float) -> void:
	var best: Node3D = null
	var bd := radius * 2.0
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null or (e.has_method("is_alive") and not e.call("is_alive")):
			continue
		var dd := e.global_position.distance_to(global_position)
		if dd < bd:
			bd = dd
			best = e
	if best == null or bd < 0.8:
		return
	var step := best.global_position - global_position
	step.y = 0.0
	global_position += step.normalized() * minf(WANDER * delta, step.length())
