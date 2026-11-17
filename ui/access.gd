extends RefCounted
## Accessibility choices (kept in hud.cfg through ui/hud_prefs.gd, so they are per player, not per save) and the one place
## everything reads them:
##   shake()         0 or 1: camera kicks, shakes and impulses scale by it ("Reduce Camera Shake")
##   flash()         1 or 0.25: the brightest screen flashes scale by it ("Reduce Flashes"; photo mode's shutter, level-up and hit flashes
##                   should multiply their alpha by it)
##   subtitle(l)     restyles the narration label: Standard, High Contrast (a solid dark plate, brighter ink) or Large
##   safe(kind)      a colour-blind-safe colour for the game's good/danger scale and the telegraph reds: `kind` is "good", "even", "warn",
##                   "bad" or "telegraph"; with the option off the original colours are returned unchanged
##   telegraph(c)    the same for a telegraph colour an enemy attack draws (core/enemy and the VFX seat read it): hue-shifted away from
##                   the red/green axis, brightness kept
## Pure and static; reads HudPrefs only. Load by path (no class_name): const Access := preload("res://ui/access.gd")

const HudPrefs := preload("res://ui/hud_prefs.gd")
const TextDirector := preload("res://ui/text_director.gd")

const SAFE := {
	"good": Color(0.55, 0.78, 1.0), "even": Color(0.96, 0.9, 0.55), "warn": Color(1.0, 0.68, 0.22), "bad": Color(0.92, 0.36, 0.82),
	"telegraph": Color(0.98, 0.35, 0.85),
}
const STYLES := ["Standard", "High Contrast", "Large"]
const PALETTES := ["Original", "Colour-Blind Safe"]


static func shake() -> float:
	HudPrefs.ensure()
	return 0.0 if HudPrefs.reduce_shake else 1.0


static func flash() -> float:
	HudPrefs.ensure()
	return 0.25 if HudPrefs.reduce_flash else 1.0


static func safe(kind: String, original: Color) -> Color:
	HudPrefs.ensure()
	return original if HudPrefs.palette == 0 else (SAFE.get(kind, original) as Color)


## A telegraph colour made safe: the hue moves to magenta-violet when the colour is red or orange, keeping value and alpha.
static func telegraph(c: Color) -> Color:
	HudPrefs.ensure()
	if HudPrefs.palette == 0 or c.h > 0.12 and c.h < 0.9:
		return c
	var out := Color.from_hsv(0.85, clampf(c.s, 0.5, 0.9), c.v)
	out.a = c.a
	return out


static func subtitle(l: Label) -> void:
	HudPrefs.ensure()
	var size := 28
	match HudPrefs.subtitle_style:
		1:
			var b := StyleBoxFlat.new()
			b.bg_color = Color(0, 0, 0, 0.88)
			b.set_content_margin_all(12)
			b.set_corner_radius_all(6)
			l.add_theme_stylebox_override("normal", b)
			l.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
		2:
			size = 38
			l.add_theme_stylebox_override("normal", TextDirector.backing(size, 14))
			l.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85))
		_:
			l.add_theme_stylebox_override("normal", TextDirector.backing(size, 12))
			l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	l.add_theme_font_size_override("font_size", TextDirector.px(size))
