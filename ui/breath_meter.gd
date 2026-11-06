extends Control
## Breath meter (r31): a thin arc left of the crosshair, drawn only while Breath is not full (and a
## moment after). Grey-violet when fine, pale blue while winded, a flash on a refused move (red) or a
## perfect dodge / parry (gold). A heavy's draw shows as an inner ember arc. Built by the Player.

var player: Node
const R := 34.0
const W := 3.0
const A0 := PI * 0.62              ## the arc spans the left side of the crosshair
const A1 := PI * 1.38
var _alpha := 0.0
var _shown := 0.0
var _was_on := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var st: Node = player.call("stamina") if player and is_instance_valid(player) else null
	if st == null:
		return
	var r: float = st.call("ratio")
	var arts: Node = player.call("arts")
	var draw_c: float = arts.call("heavy_charge") if arts else 0.0
	var want := 1.0 if r < 0.995 or float(st.call("flash")) > 0.0 or draw_c > 0.0 else 0.0
	_shown = lerpf(_shown, r, 1.0 - exp(-14.0 * delta))
	_alpha = move_toward(_alpha, want, delta * (6.0 if want > 0.0 else 1.2))
	visible = _alpha > 0.01
	# redraw across the fade and while on screen; a full bar that is invisible is not a picture
	if want > 0.0 or _alpha > 0.0 or _was_on:
		queue_redraw()
	_was_on = _alpha > 0.0 or want > 0.0


func _draw() -> void:
	var st: Node = player.call("stamina") if player and is_instance_valid(player) else null
	if st == null:
		return
	var c := size * 0.5
	var winded: bool = st.get("winded")
	var fl: float = st.call("flash")
	var good: bool = st.call("flash_good")
	var base := Color(0.62, 0.68, 0.95) if winded else Color(0.82, 0.74, 1.0)
	if fl > 0.0:
		base = base.lerp(Color(1.0, 0.85, 0.4) if good else Color(1.0, 0.35, 0.3), fl)
	draw_arc(c, R, A0, A1, 40, Color(0.05, 0.04, 0.08, 0.45 * _alpha), W + 2.0, true)
	var end := lerpf(A1, A0, clampf(_shown, 0.0, 1.0))
	if _shown > 0.005:
		draw_arc(c, R, end, A1, 40, Color(base.r, base.g, base.b, 0.9 * _alpha), W, true)
	var arts: Node = player.call("arts")
	var dc: float = arts.call("heavy_charge") if arts else 0.0
	if dc > 0.0:
		var col := Color(1.0, 0.55, 0.25, 0.95) if dc < 0.99 else Color(1.0, 0.9, 0.5, 1.0)
		draw_arc(c, R - 6.0, lerpf(A1, A0, dc), A1, 32, col, W, true)
