extends RefCounted
## The Gloom meter of the wanderer's frame: the night's one clock (docs/PILLARS.md, pillar 1), so it is a first-class
## meter and not a footnote to the Wounds. A painted coin (category "hud", id "gloom", tools/icon_kit/gloom_hud.py)
## on the left end of a bar as tall as the Wounds. No words and no numbers: the world teaches, and the bar reads by
## its state. Three states with a hard change of colour between them (it does not blend its way up unnoticed):
##   calm      violet                      the dark is not yet on you
##   dusk      from half, a rose           the dark is gathering; the trough's last half is tinted to say so
##   ember     from three quarters, ember  a Shade is near: the bar and the coin pulse, the trough burns round its rim
## Static and stateless: the caller (ui/unit_frames.gd, its "bars" layer) passes the ratio and the clock, and
## already redraws that layer only when the Gloom changes or, above three quarters, for the pulse.
## Load by path (no class_name): const GloomMeter := preload("res://ui/gloom_meter.gd")

const Forge := preload("res://ui/hud_forge.gd")
const Med := preload("res://ui/medieval_style.gd")

const CALM := Color(0.58, 0.44, 0.96)
const DUSK := Color(0.92, 0.38, 0.6)
const EMBER := Color(1.0, 0.4, 0.14)
const DUSK_AT := 0.5
const EMBER_AT := 0.75
const ROW_H := 36.0                 ## the meter's row, in the frame (the coin stands a little proud of the bar)
const BAR_H := 24.0                 ## as tall as the Wounds bar
const COIN := 46.0


## The state's colour: stepped, so that crossing a threshold is seen.
static func tone(gr: float) -> Color:
	if gr >= EMBER_AT:
		return EMBER
	if gr >= DUSK_AT:
		return DUSK
	return CALM


## 0 below the ember threshold, else a pulse in 0..1 that quickens as the bar fills.
static func pulse(gr: float, t: float) -> float:
	if gr < EMBER_AT:
		return 0.0
	return 0.5 + 0.5 * sin(t * (7.0 + 6.0 * smoothstep(EMBER_AT, 1.0, gr)))


## Draw the meter in `r` (a ROW_H-tall row) on `ci`. `gr` is Gloom / Gloom max, 0..1; `t` is the HUD clock.
static func draw(ci: CanvasItem, r: Rect2, gr: float, t: float) -> void:
	gr = clampf(gr, 0.0, 1.0)
	var col := tone(gr)
	var p := pulse(gr, t)
	var bar := Rect2(r.position + Vector2(COIN * 0.5, (r.size.y - BAR_H) * 0.5), Vector2(r.size.x - COIN * 0.5, BAR_H))
	if p > 0.0 or gr >= EMBER_AT:                                 # the rim burns
		for k in 3:
			ci.draw_rect(bar.grow(2.0 + k * 2.5), Color(EMBER, (0.2 - 0.06 * k) * (0.35 + 0.65 * p)))
	Forge.trough(ci, bar)
	var inner := bar.grow(-2.0)
	for z: Array in [[DUSK_AT, EMBER_AT, DUSK, 0.16], [EMBER_AT, 1.0, EMBER, 0.24]]:   # the zones still to come, faint in the trough
		ci.draw_rect(Rect2(inner.position + Vector2(inner.size.x * float(z[0]), 0.0), Vector2(inner.size.x * (float(z[1]) - float(z[0])), inner.size.y)), Color(z[2], float(z[3])))
	var fill := col.lerp(Color.WHITE, 0.18 * p).darkened(0.1)
	Forge.fill(ci, Rect2(inner.position, Vector2(inner.size.x * gr, inner.size.y)), fill)
	for n: float in [DUSK_AT, EMBER_AT]:                            # the two thresholds: a cut and a gilt pip
		var x := inner.position.x + inner.size.x * n
		ci.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(0.01, 0.005, 0.005, 0.95), 2.0)
		ci.draw_line(Vector2(x + 1.5, inner.position.y), Vector2(x + 1.5, inner.end.y), Color(Med.GILT, 0.35), 1.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5, bar.end.y + 1.0), Vector2(x + 3.5, bar.end.y + 1.0), Vector2(x, bar.end.y - 3.5)]), Color(Med.GILT, 0.7))
	Forge.rivet(ci, bar.position + Vector2(bar.size.x - 3.5, bar.size.y * 0.5), 1.9)
	# the coin: backed by an iron ring, tinted as the bar is, swelling with the pulse
	var c := r.position + Vector2(COIN * 0.5, r.size.y * 0.5)
	var sz := COIN * (1.0 + 0.09 * p)
	ci.draw_circle(c + Vector2(0.0, 1.5), sz * 0.5 + 1.5, Color(0, 0, 0, 0.55))
	if p > 0.0:
		ci.draw_circle(c, sz * 0.5 + 5.0, Color(EMBER, 0.16 + 0.22 * p))
	var tint := Color.WHITE
	if gr >= EMBER_AT:
		tint = Color(1.45, 0.78, 0.5)
	elif gr >= DUSK_AT:
		tint = Color(1.3, 0.8, 0.95)
	if not IconArt.draw_mark(ci, "hud", "gloom", c, sz, tint):
		ci.draw_circle(c, sz * 0.5, Color(col, 0.9))
