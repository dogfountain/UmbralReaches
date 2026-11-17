extends RefCounted
## Small marks for BBCode text (the item card's tier pips, "Raised" pips, the gear compare's up / down deltas), in
## place of glyph characters: white shapes with soft edges in ui/icons/hud/ (pip_full, pip_hollow, delta_up,
## delta_down), tinted by the `[img color=]` tag. Use `BbArt.mark("disc", 14, colour)` inside a BBCode string.
## (They were drawn at runtime and registered under a made-up path once; `[img]` loads by path from disk and never
## found them, so they are files now.) Preload it; no class_name.

const PATHS := {
	"disc": "res://ui/icons/hud/pip_full.png",
	"ring": "res://ui/icons/hud/pip_hollow.png",
	"up": "res://ui/icons/hud/delta_up.png",
	"down": "res://ui/icons/hud/delta_down.png",
}


## The BBCode for one mark: kind "disc" (a filled pip), "ring" (a hollow one), "up" or "down" (a delta triangle).
static func mark(kind: String, px: int, col: Color) -> String:
	return "[img width=%d height=%d color=#%s]%s[/img]" % [px, px, col.to_html(true), String(PATHS[kind])]


## `n` marks side by side (nothing for 0).
static func row(kind: String, n: int, px: int, col: Color) -> String:
	return mark(kind, px, col).repeat(maxi(n, 0))


static func texture(kind: String) -> Texture2D:
	return load(String(PATHS[kind])) as Texture2D
