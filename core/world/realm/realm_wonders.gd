extends RefCounted
## THE WONDERS (Luke, 9 Nov: "add more mystifying places to the game that maek you say wowwwwwwww"): landmarks
## seen from far off, each its own file under core/world/realm/wonders/ with `static func build(root)`. Built
## after the lore and before the terrain stamp and the flora, so a wonder can register its WorldLanes site
## (the trees keep off it) and stamp the ground. A missing file is skipped. --no-wonders turns them all off.

const LIST := [
	"res://core/world/realm/wonders/sky_chain.gd",
	"res://core/world/realm/wonders/upward_falls.gd",
	"res://core/world/realm/wonders/star_crater.gd",
]


static func build(root: Node) -> void:
	if "--no-wonders" in OS.get_cmdline_user_args():
		return
	for path: String in LIST:
		if not ResourceLoader.exists(path):
			continue
		var s: Variant = load(path)
		if s == null or not (s as GDScript).can_instantiate():
			push_error("WONDER %s failed to load" % path)
			continue
		var t := Time.get_ticks_usec()
		await s.build(root)
		print("WONDER %s in %d ms" % [path.get_file().get_basename(), (Time.get_ticks_usec() - t) / 1000])
