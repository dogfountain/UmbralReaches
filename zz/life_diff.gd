extends SceneTree
## Mean luminance of PNGs (and the mean absolute difference to the first): checks that frame
## sequences really changed. godot --headless -s zz/life_diff.gd -- a.png b.png ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var first: Image = null
	for p in a:
		var im := Image.load_from_file(p)
		im.resize(240, 150)
		var s := 0.0
		var d := 0.0
		for y in 150:
			for x in 240:
				var c := im.get_pixel(x, y)
				s += c.get_luminance()
				if first != null:
					d += absf(c.get_luminance() - first.get_pixel(x, y).get_luminance())
		if first == null:
			first = im
		print("DIFF %s mean %.4f diff_to_first %.5f" % [p.get_file(), s / 36000.0, d / 36000.0])
	quit()
