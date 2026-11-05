extends Control
## Screen-space floating combat text (r33, after WoW's scrolling combat text). In-world hit numbers on
## foes stay core/vfx/hit_text.gd's (3D, pooled); this adds the wanderer's own side of a fight, at
## his shoulder: the Gloom a blow put on him (left, red; a heavy blow bigger) and the Gloom a kill or
## a fire took off (right, lantern gold, like a heal).
##
## r33: a critical hit you deal (Events.combat_damage, crit) bursts as a big gold number at the foe,
## WoW-style, over the small in-world number its take_hit already shows; ordinary hits stay in-world.
##
## Anyone can pop text here too (group "combat_text"):
##   get_tree().get_first_node_in_group(&"combat_text").call("pop", world_pos, "Parry", "parry")
## kinds: damage, crit (bigger, punches in), heal, hurt, parry, dodge, immune, miss, info.
## Added by ui/hud.gd. Off with HudPrefs.combat_text (settings menu, Controls tab).

const HudPrefs := preload("res://ui/hud_prefs.gd")
const LIFE := 1.15
const MAX := 14

const KINDS := {
	"damage": {"col": Color(1.0, 0.95, 0.88), "pt": 22, "drift": Vector2(0, -70)},
	"crit": {"col": Color(1.0, 0.72, 0.3), "pt": 34, "drift": Vector2(0, -80), "punch": true},
	"heal": {"col": Color(1.0, 0.84, 0.42), "pt": 20, "drift": Vector2(36, -64)},
	"hurt": {"col": Color(1.0, 0.36, 0.28), "pt": 22, "drift": Vector2(-40, -64)},
	"hurt_big": {"col": Color(1.0, 0.28, 0.2), "pt": 30, "drift": Vector2(-46, -72), "punch": true},
	"parry": {"col": Color(1.0, 0.86, 0.5), "pt": 22, "drift": Vector2(0, -56), "punch": true},
	"dodge": {"col": Color(0.7, 0.82, 1.0), "pt": 22, "drift": Vector2(0, -56)},
	"immune": {"col": Color(0.85, 0.78, 1.0), "pt": 20, "drift": Vector2(0, -50)},
	"miss": {"col": Color(0.8, 0.8, 0.85), "pt": 18, "drift": Vector2(0, -50)},
	"info": {"col": Color(0.9, 0.88, 1.0), "pt": 18, "drift": Vector2(0, -50)},
}

var _font: Font
var _pops: Array = []          ## {pos (world), text, kind, t, jitter}
var _last_gloom := -1.0
var _player: Node3D


func _ready() -> void:
	name = "CombatText"
	add_to_group(&"combat_text")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://ui/fonts/Cinzel.ttf")
	HudPrefs.ensure()
	if Events.has_signal("player_hurt"):
		Events.player_hurt.connect(_on_hurt)
	if Events.has_signal("combat_damage"):
		Events.connect("combat_damage", _on_damage)


func _on_damage(_target: Node, amount: float, crit: bool, _school: StringName, at: Vector3) -> void:
	if not crit or amount <= 0.0 or at == Vector3.INF:
		return
	var t := str(roundi(amount)) if amount >= 10.0 or is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	pop(at + Vector3.UP * 0.45, t + "!", "crit")


## Pop `text` at `at` (world), styled by `kind` (KINDS).
func pop(at: Vector3, text: String, kind := "damage") -> void:
	if not HudPrefs.combat_text or text == "":
		return
	if _pops.size() >= MAX:
		_pops.pop_front()
	_pops.append({"pos": at, "text": text, "kind": kind if KINDS.has(kind) else "info", "t": 0.0,
		"jitter": Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 6.0))})


func _on_hurt(amount: float, _from: Vector3) -> void:
	if amount < 0.5 or _player == null:
		return
	pop(_player.global_position + Vector3.UP * 1.9, "+%d Gloom" % roundi(amount), "hurt_big" if amount >= 20.0 else "hurt")
	_last_gloom = float(_player.get("gloom")) if "gloom" in _player else -1.0


func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if _player and "gloom" in _player:
		var g := float(_player.get("gloom"))
		if _last_gloom >= 0.0 and g <= _last_gloom - 2.0:
			pop(_player.global_position + Vector3.UP * 1.7, "−%d Gloom" % roundi(_last_gloom - g), "heal")
		_last_gloom = g
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i].t = float(_pops[i].t) + delta
		if float(_pops[i].t) > LIFE:
			_pops.remove_at(i)
	visible = not get_tree().paused
	if not _pops.is_empty() or visible:
		queue_redraw()


func _draw() -> void:
	if _pops.is_empty() or _font == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var cam_vp := Vector2(cam.get_viewport().get_visible_rect().size)
	var k := vp / cam_vp if cam_vp.x > 0.0 else Vector2.ONE
	for p: Dictionary in _pops:
		var at: Vector3 = p.pos
		if cam.is_position_behind(at):
			continue
		var spec: Dictionary = KINDS[p.kind]
		var t := float(p.t)
		var u := t / LIFE
		var base := cam.unproject_position(at) * k + (p.jitter as Vector2)
		var drift: Vector2 = spec.drift
		var pos := base + drift * (1.0 - pow(1.0 - u, 2.2))
		var pt := int(spec.pt)
		if spec.get("punch", false):
			pt = int(float(pt) * (1.0 + 0.55 * clampf(1.0 - t * 7.0, 0.0, 1.0)))
		var a := clampf((LIFE - t) / (LIFE * 0.4), 0.0, 1.0)
		var col: Color = spec.col
		var txt := String(p.text)
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, pt).x
		var o := pos - Vector2(w * 0.5, 0.0)
		draw_string_outline(_font, o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, 6, Color(0.02, 0.01, 0.03, 0.85 * a))
		draw_string(_font, o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, pt, Color(col, a))
