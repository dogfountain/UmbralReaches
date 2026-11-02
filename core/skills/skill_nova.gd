class_name SkillNova
extends Skill
## Umbral Nova: point-blank ring. 1 damage plus 1 per Umbral Mark consumed, hard knockback,
## unmakes shades and pops enemy spit in range. The panic button and the payoff for marking.

const RADIUS := 4.6
const SHOVE := 10.0


func _init() -> void:
	id = &"nova"
	title = "Umbral Nova"
	blurb = "Ring blast. +1 damage per Mark consumed. Pops spit, unmakes shades."
	action = &"skill_nova"
	cooldown = 7.0
	gloom_cost = 6.0
	color = Color("#C04DFF")
	glyph = &"nova"


func cast(book: SkillBook, _charge: float) -> bool:
	var p := book.player
	var at := p.global_position + Vector3.UP * 0.9
	var tree := p.get_tree()
	var r2 := RADIUS * RADIUS
	for node in tree.get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - p.global_position
		d.y = 0.0
		if d.length_squared() > r2:
			continue
		var dist := d.length()
		var away := d / dist if dist > 0.05 else -p.global_basis.z
		var marks := e.take_marks()
		e.take_hit(1.0 + float(marks), p)
		e.shove(away * SHOVE * (1.0 - dist / RADIUS * 0.5))
	for node in tree.get_nodes_in_group(Groups.SHADE):
		var s := node as Node3D
		if s and s.global_position.distance_squared_to(at) <= r2 * 1.4 and s.has_method("take_hit"):
			s.take_hit(1.0, p)
	for node in tree.get_nodes_in_group(Groups.ENEMY_SHOT):
		var shot := node as Node3D
		if shot and shot.global_position.distance_squared_to(at) <= r2 * 1.6 and shot.has_method("pop"):
			shot.pop()
	p.nova_fx(RADIUS)
	p.kick(1.0)
	return true
