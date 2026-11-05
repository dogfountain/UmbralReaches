extends SceneTree
## Tile PNGs into a contact sheet: godot --headless -s zz/tile.gd -- out.png cols w in1.png in2.png ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	var cols := int(a[1])
	var tw := int(a[2])
	var ims: Array[Image] = []
	for i in range(3, a.size()):
		var im := Image.load_from_file(a[i])
		if im: ims.append(im)
	var th := int(float(tw) * float(ims[0].get_height()) / float(ims[0].get_width()))
	var rows := ceili(float(ims.size()) / float(cols))
	var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in ims.size():
		var im := ims[i]
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	sheet.save_png(out)
	quit()
