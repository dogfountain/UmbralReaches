extends RefCounted
## Small drawn marks for BBCode text (the item card's tier pips, "Raised" pips, the gear compare's up / down
## deltas), in place of glyph characters. Each is a white shape with soft edges, painted once into an ImageTexture
## and registered under a res:// name (take_over_path), so a `[img]` tag in any RichTextLabel finds it by path and
## tints it (`color=`). Use `BbArt.mark("disc", 14, colour)` inside a BBCode string. Preload it; no class_name.

const PATHS := {
	"disc": "res://ui/icons/_drawn/pip_full",
	"ring": "res://ui/icons/_drawn/pip_hollow",
	"up": "res://ui/icons/_drawn/delta_up",
	"down": "res://ui/icons/_drawn/delta_down",
}
const SIZE := 32

static var _built := false


## The BBCode for one mark: kind "disc" (a filled pip), "ring" (a hollow one), "up" or "down" (a delta triangle).
static func mark(kind: String, px: int, col: Color) -> String:
	_make()
	return "[img width=%d height=%d color=#%s]%s[/img]" % [px, px, col.to_html(true), String(PATHS[kind])]


## `n` marks side by side (nothing for 0).
static func row(kind: String, n: int, px: int, col: Color) -> String:
	return mark(kind, px, col).repeat(maxi(n, 0))


static func texture(kind: String) -> Texture2D:
	_make()
	return ResourceLoader.load(String(PATHS[kind])) as Texture2D


static func _make() -> void:
	if _built:
		return
	_built = true
	for kind: String in PATHS:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		var c := (SIZE - 1) * 0.5
		for y in SIZE:
			for x in SIZE:
				img.set_pixel(x, y, Color(1, 1, 1, _cover(kind, Vector2(x - c, y - c) / (SIZE * 0.5))))
		var tex := ImageTexture.create_from_image(img)
		tex.take_over_path(String(PATHS[kind]))


## Coverage 0..1 of a point `p` (the square's centre is 0, its edge 1) by the shape, soft over about a pixel.
static func _cover(kind: String, p: Vector2) -> float:
	var soft := 2.0 / SIZE
	match kind:
		"disc":
			return clampf((0.62 - p.length()) / soft, 0.0, 1.0)
		"ring":
			var d := absf(p.length() - 0.5)
			return clampf((0.13 - d) / soft, 0.0, 1.0)
		_:
			# a triangle: apex at the top (up) or the bottom (down), base across the other side
			var q := p if kind == "up" else Vector2(p.x, -p.y)
			var h := (q.y + 0.6) / 1.2                    # 0 at the apex, 1 at the base
			if h < 0.0 or h > 1.0:
				return 0.0
			var half := 0.62 * h
			return clampf((half - absf(q.x)) / soft, 0.0, 1.0)
