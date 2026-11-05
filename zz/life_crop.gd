extends SceneTree
## Crop a region of a PNG (and scale it up): godot --headless -s zz/life_crop.gd -- in.png out.png x y w h scale
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var im := Image.load_from_file(a[0])
	var r := Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5]))
	var c := im.get_region(r)
	var s := float(a[6])
	c.resize(int(r.size.x * s), int(r.size.y * s), Image.INTERPOLATE_NEAREST)
	c.save_png(a[1])
	quit()
