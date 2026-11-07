extends Node3D
## Rift Step rank III, Rend (progression): the tear you leave behind holds open for DELAY, then
## bursts: damage x spell power and a Mark to every enemy within RADIUS.

const CombatState := preload("res://core/skills/combat_state.gd")
const DELAY := 0.4
const RADIUS := 3.0
const DMG := 1.5

var power := 1.0
var _t := 0.0
var _done := false


static func open(by: Node3D, at: Vector3, spell_power: float) -> void:
	var host := by.get_tree().current_scene
	if host == null:
		return
	var r := new()
	r.name = "RiftRend"
	r.power = spell_power
	host.add_child(r)
	r.global_position = at


func _ready() -> void:
	SpellFx.disc(global_position, RADIUS, 0, SpellFx.VIOLET * 0.6, SpellFx.VIOLET_HOT, DELAY + 0.2)
	Vfx.burst(global_position + Vector3.UP, SpellFx.VIOLET_HOT, {"count": 30, "life": DELAY, "speed": Vector2(0.0, 0.4), "size": 0.04, "radius": RADIUS * 0.9, "radial": -RADIUS * 5.0, "gravity": 0.0, "trail": 0.08})


func _physics_process(delta: float) -> void:
	_t += delta
	if _done or _t < DELAY:
		return
	_done = true
	var at := global_position + Vector3.UP * 0.9
	for node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - global_position
		if Vector2(d.x, d.z).length() <= RADIUS and absf(d.y) < 2.5:
			e.add_mark(1)
			CombatState.strike(e, DMG * power, &"umbral", self)
			var dir := Vector3(d.x, 0.0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.1 else Vector3.FORWARD
			e.shove(dir * 6.0)
			Vfx.arc(at, e.global_position + Vector3.UP, Color(1.6, 0.8, 3.2), 0.25, 0.25)
	SpellFx.shell(at, 0.3, RADIUS, Color(1.2, 0.5, 2.8), 0.3)
	SpellFx.tear(global_position, 2.2, 0.35)
	Vfx.burst(at, SpellFx.VIOLET_HOT, {"count": 40, "life": 0.4, "speed": Vector2(3.0, 7.0), "size": 0.045, "gravity": -3.0, "trail": 0.08})
	Vfx.light(at, SpellFx.VIOLET, 4.0, RADIUS * 2.2, 0.3, 2)
	Sfx.play("res://art/audio/step_blink.wav", at, -4.0, 0.7)
	get_tree().create_timer(0.5, false).timeout.connect(queue_free)
