extends Node
## Palette gate: the night must stay blue-violet. Renders the look sheet's eight views (the real
## player camera, grade on, HUD off; the positions are zz/look_shots.gd's VIEWS) and measures the
## share of coloured pixels (saturation > 0.15) whose hue lies in 200-290 degrees.
## FAILs under 85 % (README's v0.1 table had 91-99.9 %). Headless cannot render, so there it
## prints "PALETTE SKIP headless" and passes. Windowed runs write nothing; run it with a scratch
## HOME so user:// is not the owner's profile:
##   HOME=/tmp/umbral_palette godot --path . res://zz/palette_test.tscn
const MIN_SHARE := 0.85
const HUE_LO := 200.0
const HUE_HI := 290.0
const SAT_MIN := 0.15
const SETTLE := 40
const SAMPLE := Vector2i(320, 200)
var VIEWS: Array = []
var p: Player
var i := -1
var wait := 0
var coloured := 0
var in_band := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		print("PALETTE SKIP headless")
		get_tree().quit(0)
		return
	Travel._busy = true   # never write the owner's save from a capture run
	var sheet: Node = (load("res://zz/look_shots.gd") as GDScript).new()
	VIEWS = sheet.get("VIEWS")    # the look sheet's eight positions
	sheet.free()
	get_window().size = Vector2i(1280, 800)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if VIEWS.is_empty():
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not p.get_parent().has_meta("realm_done"):
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if i >= 0 and i < VIEWS.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		_measure(String(VIEWS[i][0]), get_viewport().get_texture().get_image())
	i += 1
	if i >= VIEWS.size():
		_finish()
		return
	_hold()
	p.set_view(float(VIEWS[i][2]), float(VIEWS[i][3]))
	wait = SETTLE


func _hold() -> void:
	p.global_position = VIEWS[i][1]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _measure(view: String, img: Image) -> void:
	img.convert(Image.FORMAT_RGB8)
	img.resize(SAMPLE.x, SAMPLE.y, Image.INTERPOLATE_BILINEAR)
	var c := 0
	var b := 0
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.s <= SAT_MIN:
				continue
			c += 1
			var h := px.h * 360.0
			if h >= HUE_LO and h <= HUE_HI:
				b += 1
	coloured += c
	in_band += b
	print("PALETTE view %s coloured %d in %d-%d deg %.1f %%" % [view, c, HUE_LO, HUE_HI, 100.0 * float(b) / maxf(float(c), 1.0)])


func _finish() -> void:
	var share := float(in_band) / maxf(float(coloured), 1.0)
	if coloured == 0 or share < MIN_SHARE:
		print("PALETTE FAIL share %.1f %% of %d coloured pixels in hue %d-%d (need %.0f %%)" % [100.0 * share, coloured, HUE_LO, HUE_HI, 100.0 * MIN_SHARE])
		get_tree().quit(1)
		return
	print("PALETTE PASS share %.1f %% of %d coloured pixels in hue %d-%d" % [100.0 * share, coloured, HUE_LO, HUE_HI])
	get_tree().quit(0)
