extends RefCounted
## THE WONDERS (Luke, 9 Nov: "add more mystifying places to the game that maek you say wowwwwwwww"): landmarks
## seen from far off, each its own file under core/world/realm/wonders/ with `static func build(root)`. Built
## after the lore and before the terrain stamp and the flora, so a wonder can register its WorldLanes site
## (the trees keep off it) and stamp the ground. A missing file is skipped. --no-wonders turns them all off.

const LIST := [
	"res://core/world/realm/wonders/sky_chain.gd",
	"res://core/world/realm/wonders/upward_falls.gd",
	"res://core/world/realm/wonders/star_crater.gd",
	# the world pass (docs/the world pass/world_landmarks.md): the colossal landmarks, after the older wonders so their sites are already registered
	"res://core/world/realm/wonders/r39/the_sleeper.gd",
	"res://core/world/realm/wonders/r39/hollow_king.gd",
	"res://core/world/realm/wonders/r39/salt_ship.gd",
	"res://core/world/realm/wonders/r39/wardens_line.gd",
	"res://core/world/realm/wonders/r39/chain_span.gd",
	"res://core/world/realm/wonders/r39/titan_gates.gd",
	"res://core/world/realm/wonders/r39/hermit_caches.gd",
	"res://core/world/realm/wonders/r39/terrain_outcrops.gd",
	"res://core/world/realm/wonders/r39/roadside_tableaux.gd",
	"res://core/world/realm/wonders/r39/deep_halls.gd",
	"res://core/world/realm/wonders/r39/caves.gd",
	"res://core/world/realm/wonders/r39/region_dressing.gd",
	"res://core/world/realm/wonders/r39/waterworks.gd",
	"res://core/world/realm/wonders/r39/climbs.gd",
	"res://core/world/realm/wonders/r39/ground_marks.gd",
	"res://core/world/realm/wonders/r39/shorelines.gd",
	"res://core/world/realm/wonders/r39/hidden_finds.gd",
]


static func build(root: Node) -> void:
	preload("res://core/world/realm/wonders/r39/wonder_kit.gd").light_used = 0          # the wonders' light budget starts over with each Realm build
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
