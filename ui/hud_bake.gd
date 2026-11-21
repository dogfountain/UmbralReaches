extends Control
## Still HUD art drawn once into a texture and shown as one draw call (the fps pass, 20 Nov: the HUD issued 430-456
## canvas draw calls a frame; every drawn arc, circle, polyline, polygon and rounded box is a draw call of its own,
## only text and plain rects batch).
##
## The art is drawn by the owner's own function (`art`, given the CanvasItem to draw on, in this node's local units)
## into a transparent SubViewport at the screen's own pixel scale, once, and again only when the owner says the
## picture changed (`refresh(sig)`), the window is resized or the HUD's scale changes. The texture holds the art's
## colours premultiplied by its coverage (what a transparent target accumulates) and is drawn with premultiplied-alpha
## blending at a whole-pixel position, texel for pixel: the same pixels as drawing the art directly, to an 8-bit
## rounding and at most half a pixel's shift.
##
## Use: var b := HudBake.new(); b.art = _draw_bezel; owner.add_child(b); b.position / b.size = the art's box (owner
## units; the art draws in b's units, so a box at the owner's origin keeps the owner's coordinates); b.refresh(sig)
## whenever what the art shows may have changed. `show_behind_parent` puts it under the owner's own drawing.
## Load by path (no class_name): const HudBake := preload("res://ui/hud_bake.gd")

var art: Callable                       ## func(ci: CanvasItem) -> void: draws the still picture on ci
var _vp: SubViewport
var _canvas: Control
var _sig: Variant = null
var _scale := 0.0
var _frac := Vector2.ZERO               ## where this node's origin fell inside a screen pixel when baked
var _baked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST         # texel for pixel: no resampling of the baked art
	material = _premul()
	_vp = SubViewport.new()
	_vp.name = "Bake"
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.canvas_item_default_texture_filter = get_viewport().canvas_item_default_texture_filter
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_art)
	_vp.add_child(_canvas)
	add_child(_vp)
	get_viewport().size_changed.connect(_rescale)
	resized.connect(_rescale)


## The owner's word on what the art shows (any value: a string, an array): a different one bakes it again.
func refresh(sig: Variant) -> void:
	if not _baked or sig != _sig:
		_sig = sig
		_bake()


## Bake again now (the owner knows the picture changed but keeps no signature of it).
func rebake() -> void:
	_bake()


func _rescale() -> void:
	if _baked:
		_bake()


## This node's local units -> the window's pixels (the canvas layer, the HUD's stretch to the window).
func _to_px() -> Transform2D:
	return get_viewport().get_final_transform() * get_global_transform_with_canvas()


func _bake() -> void:
	if not is_inside_tree() or size.x <= 0.0 or size.y <= 0.0:
		return
	var s := _to_px().get_scale().x
	if s <= 0.0:
		return
	_scale = s
	# rasterised on the same sub-pixel grid as the screen: thin unsmoothed lines land on the same pixels (or miss them)
	# as they did drawn directly. A pixel of margin round the box: antialiased edges reach half a pixel past it
	var p0 := _to_px().origin
	_frac = p0 - p0.floor()
	_vp.size = Vector2i(ceili(size.x * s + _frac.x) + 2, ceili(size.y * s + _frac.y) + 2)
	_vp.canvas_transform = Transform2D(0.0, Vector2(s, s), 0.0, Vector2(1.0, 1.0) + _frac)
	_vp.oversampling_override = s                             # text rasterised at the screen's scale, as it is drawn there
	_canvas.size = size
	_canvas.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_baked = true
	queue_redraw()


func _draw_art() -> void:
	if art.is_valid():
		art.call(_canvas)


func _draw() -> void:
	if not _baked or _scale <= 0.0:
		return
	# the texture's corner on the whole pixel one up and left of the pixel holding this node's origin: texel for pixel,
	# each where it was baked (a node moved by part of a pixel since then is off by that part, at most half a pixel)
	var xf := _to_px()
	var px := (xf.origin - _frac).round() - Vector2(1.0, 1.0)
	draw_texture_rect(_vp.get_texture(), Rect2((px - xf.origin) / _scale, Vector2(_vp.size) / _scale), false)


static var _mat: ShaderMaterial


## Premultiplied-alpha drawing of the baked texture (the vertex colour carries the item's modulate: a fade of the owner
## scales the whole picture).
static func _premul() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
render_mode blend_premul_alpha;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(t.rgb * tint.rgb * tint.a, t.a * tint.a);
}
"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat
