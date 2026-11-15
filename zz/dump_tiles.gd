extends SceneTree
## Writes the wanderer's gear tiles (wanderer_tex.gd, generated at run time) to art/blender/tiles/<name>.png so the
## Blender bake (tools/blender/bake_kind.py) can paint the same weave and relief into the enemies' baked maps.
##   godot --headless --path . -s res://zz/dump_tiles.gd

const WTex := preload("res://core/player/wanderer_tex.gd")


func _init() -> void:
	for n: String in ["wool", "trim", "leather", "iron", "wood"]:
		for suf: String in ["", "_n"]:
			var im := (WTex.img(n + suf)).duplicate() as Image
			if im.is_compressed():
				im.decompress()
			im.clear_mipmaps()
			im.convert(Image.FORMAT_RGBA8)
			im.save_png(ProjectSettings.globalize_path("res://art/blender/tiles/%s%s.png" % [n, suf]))
			print("TILE ", n + suf, " ", im.get_size())
	quit()
