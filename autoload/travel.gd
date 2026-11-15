extends Node
## Cross-zone travel. Mirrors hand off spawn, facing, and Gloom; this autoload
## keeps them across change_scene_to_file and fades the glass between nights.

var pending := false
var returning := false
var gloom := 0.0
var wounds := 0.0                    ## r35: carried across a scene change with the Gloom
var hollow_count := 0
var spawn := Vector3.ZERO
var yaw := 0.0
var lit_by_path: Dictionary = {}
var area_lit: Dictionary = {}      ## "area_id/brazier" -> true; survives streaming and travel
var relics: Dictionary = {}        ## reliquary id -> chosen variant (StringName)
var seals_broken: Dictionary = {}  ## seal id -> true (WardSeal / EnemySpawner camps)
var bosses_slain: Dictionary = {}  ## boss id -> true (BossArena)
var items: Dictionary = {}         ## ItemDB id -> count (the Satchel)
var checkpoints: Dictionary = {}   ## scene path -> Vector3 (last kindled brazier's spawn point)
var saved_hollows := 0
## Loot bags still on the ground (core/items/loot_bag.gd): [{pos: Vector3, title, entries}]. Written with the
## save so a quit does not leave the piece in a bag that is gone, and Continue lays each one back.
var loot_bags: Array = []
var leaving := false               ## the game is closing: a bag the save kept is not poured on the way out
var _bag_restore_t := 0.0
var _to_lay: Array = []             ## bags read from the save, laid back once (not the live record)
var _wrote_ok := false             ## a write has succeeded this session: the .bak (the night before) is not copied again
var _warned_rename := false
## Per-system saved state for the living-world systems (docs/LIFE_PLAN.md): one sub-dictionary
## per system id ("progression", "village", "life", "secrets", "encounters"), saved in its own
## [systems] section. Each system reads/writes ONLY its own key; call save_game() after changing it.
var systems: Dictionary = {}
var story: Dictionary = {}         ## story state (core/story/story.gd): {"flags": {}, "picked": {}}; own [story] section

## Progress save (user://slot_<n>/savegame.cfg, see use_slot): kindles (hub + areas), relics, checkpoint, hollow count.
## Written ~0.6 s after any change (kill ash: ~10 s, see save_lazy); read once at boot. Launch with
## `-- --fresh` to ignore it, `-- --save-dir=/scratch` to keep every save file there (tests).
const HudPrefs := preload("res://ui/hud_prefs.gd")
const SaveDir := preload("res://core/util/save_dir.gd")
const SLOTS := 3                     ## save slots: <dir>/slot_<n>/savegame.cfg
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
var slot := 1                        ## the slot in play (use_slot); the last one used is remembered in slots.cfg
var forced_title := false            ## set by to_title(): ui/title_boot.gd shows the title even under a harness flag
var SAVE_PATH: String = SaveDir.path("savegame.cfg")
## Format version written to [progress] version. Readers take what they know from any version and
## carry the rest along: keys this build doesn't know (a newer build's, or a section another system
## adds) survive a save. Writes go to SAVE_PATH.tmp, then are renamed over the save; the previous
## good save is kept as SAVE_PATH.bak and loaded if the main file is ever unreadable.
## Cost (r30): a save runs on the main thread mid-combat, so it never walks the scene tree (lit
## braziers come from the Groups.BRAZIER registry) and never re-parses a file: _loaded_cfg is the
## one canonical ConfigFile, and whether the main file is a good save is remembered, not re-read.
const SAVE_VERSION := 1
const LAZY_S := 10.0                 ## kill ash: rides the next save, or this long at most
var _save_queued := false
var _save_missed := false            ## a save was asked for during a scene change: written when it ends
var _lazy_queued := false
var _saves := 0                      ## save_game() count; a lazy timer skips if one ran since it was set
var _loaded_cfg: ConfigFile = null   ## the save as read at boot (unknown keys ride along); updated in place
var from_save := false               ## this session continues a save read from disk (not a new game)
var _main_ok: Variant = null         ## SAVE_PATH holds a good save: true/false once known, null = not checked
## Set by erase_save(): the running night still holds the old progress in its nodes (lit fires,
## systems, the story), so nothing more is written this session; the next launch starts clean.
var erased := false

var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false
var _awaiting_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_legacy()
	slot = clampi(int(_slots_cfg().get_value("slots", "last", 1)), 1, SLOTS)
	SaveDir.slot = slot
	SAVE_PATH = SaveDir.path("savegame.cfg")
	if not "--fresh" in OS.get_cmdline_user_args():
		load_game()
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: save_soon())
	Events.seal_broken.connect(func(id: String) -> void:
		seals_broken[id] = true
		save_game())
	Events.boss_slain.connect(func(id: String) -> void:
		bosses_slain[id] = true
		save_game())
	_fade_layer = CanvasLayer.new()
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer.layer = 80
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.06, 0.01, 0.03, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)
	add_child(_fade_layer)


func busy() -> bool:
	return _busy


func consume() -> void:
	pending = false


func go(path: String, at: Vector3, facing: float, player: Node) -> void:
	if _busy:
		return
	_busy = true
	pending = true
	returning = true
	spawn = at
	yaw = facing
	_awaiting_path = path
	_remember_kindles()
	if player and is_instance_valid(player):
		gloom = player.gloom
		wounds = player.wounds
		hollow_count = player.hollow_count
	Events.interact_hint.emit("")

	# Hold black through the whole swap — Vale dress can take seconds.
	ResourceLoader.load_threaded_request(path)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	await tw.finished

	var keep_mouse := Input.mouse_mode
	LightGrid.clear()
	var packed := await _threaded_scene(path)
	if packed == null:
		_fail_open("missing packed scene %s" % path)
		Input.mouse_mode = keep_mouse
		return

	var old_scene := get_tree().current_scene
	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		_fail_open("change_scene err=%s path=%s" % [err, path])
		Input.mouse_mode = keep_mouse
		return

	var arrived := await _wait_for_new_scene(old_scene, 30.0)
	if not arrived:
		_fail_open("timeout waiting for %s" % path)
		Input.mouse_mode = keep_mouse
		return

	# Let the new Zone finish its first deferred dress ticks before revealing.
	await get_tree().create_timer(0.35).timeout
	Input.mouse_mode = keep_mouse
	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.tween_property(_fade, "color:a", 0.0, 0.75)
	await out.finished
	_awaiting_path = ""
	_busy = false
	_flush_missed()
	call_deferred("restore_kindles", get_tree().current_scene)
	print("Travel arrived ", path)


func _threaded_scene(path: String) -> PackedScene:
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return load(path) as PackedScene
		await get_tree().process_frame
	return load(path) as PackedScene


func _wait_for_new_scene(old_scene: Node, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur != null and cur != old_scene:
			return true
	return false


func _fail_open(why: String) -> void:
	pending = false
	_awaiting_path = ""
	push_error("Travel.go failed: ", why)
	Events.toast.emit("The glass would not open.")
	var out := create_tween()
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out.tween_property(_fade, "color:a", 0.0, 0.5)
	await out.finished
	_busy = false
	_flush_missed()


func _remember_kindles() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if path.is_empty():
		return
	var names := PackedStringArray()
	for node in _braziers(scene):
		if (node as Brazier).lit:
			names.append(node.name)
	lit_by_path[path] = names


## The braziers under `root`, in tree order, from the registry (Brazier joins Groups.BRAZIER in
## _ready) instead of walking ~9,500 nodes: that walk was 2 ms of every save.
func _braziers(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for node in get_tree().get_nodes_in_group(Groups.BRAZIER):
		if node is Brazier and root.is_ancestor_of(node):
			out.append(node)
	return out


func was_lit(b_name: String) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var names: PackedStringArray = lit_by_path.get(scene.scene_file_path, PackedStringArray())
	return b_name in names


func restore_kindles(root: Node) -> void:
	if root == null:
		return
	var path := root.scene_file_path
	var names: PackedStringArray = lit_by_path.get(path, PackedStringArray())
	if names.is_empty():
		return
	for node in _braziers(root):
		if node.name in names:
			(node as Brazier).kindle_quiet()


# --- progress save ---------------------------------------------------------------------------

## Put something in the Satchel. Unique kinds (relics, trophies) never stack past 1.
## `save` = write the save now (key items); else it rides the next save (`soon`: within 0.6 s;
## false = the caller schedules it, e.g. kill ash via save_lazy).
func give(id: String, amount := 1, save := true, soon := true) -> void:
	var kind := String(ItemDB.def(id).kind)
	var have := int(items.get(id, 0))
	var total := mini(have + amount, 1) if kind != "material" else have + amount
	if total == have:
		return
	items[id] = total
	Events.item_gained.emit(id, total - have, total)
	if save:
		save_game()
	elif soon:
		save_soon()


func count(id: String) -> int:
	return int(items.get(id, 0))


## Older saves knew relics and bosses but had no Satchel: fill it from what they did record.
func _migrate_items() -> void:
	if relics.has("bone"):
		items["bone_reliquary"] = 1
	for b in bosses_slain:
		if ItemDB.BOSS_TROPHY.has(b):
			items[ItemDB.BOSS_TROPHY[b]] = 1
	if bosses_slain.has("thornwarden") and not relics.has("thorn"):
		relics["thorn"] = &"splinter"


## Progress you can lose by quitting is progress lost: save on the way out too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		leaving = true
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE or what == NOTIFICATION_APPLICATION_PAUSED:
		if not _busy and is_inside_tree():
			save_game()


## Every loot bag still standing: where it is and what is in it. Each is marked `kept` (its _exit_tree
## does not pour it while the game closes). When the game is closing and the bags are already freed,
## the last record stands.
func _collect_bags() -> Array:
	if not is_inside_tree():
		return loot_bags
	var out: Array = []
	for b: Node in get_tree().get_nodes_in_group("loot_bag"):
		if not is_instance_valid(b) or not b.is_inside_tree() or not (b is Node3D):
			continue
		var bag: Variant = b                   # loot_bag.gd (no class_name; it reads Travel, so no preload here)
		if not bag.can_interact():
			continue
		bag.kept = true
		out.append({"pos": (b as Node3D).global_position, "title": String(bag.title), "entries": (bag.entries as Array).duplicate(true)})
	out.append_array(_to_lay)                  # read from the save but not laid back yet: still owed
	if out.is_empty() and leaving:
		return loot_bags
	loot_bags = out
	return out


func _process(delta: float) -> void:
	if _to_lay.is_empty() or _busy:
		return
	_bag_restore_t -= delta
	if _bag_restore_t > 0.0:
		return
	_bag_restore_t = 0.5
	# Continue: lay each saved bag back once the night has a wanderer and a gear service to lay it
	var gear: Variant = get_tree().get_first_node_in_group("gear")        # gear_runtime.gd (no class_name)
	if gear == null or get_tree().get_first_node_in_group(Groups.PLAYER) == null or get_tree().current_scene == null:
		return
	# once only: each laid bag joins the "loot_bag" group, which is what the next save records
	var saved := _to_lay
	_to_lay = []
	for r: Variant in saved:
		var b: Variant = gear.drop_bag((r as Dictionary).entries, (r as Dictionary).pos - Vector3(0, 0.05, 0), String((r as Dictionary).title))
		if b is Node:
			(b as Node).set("kept", true)


## Save now (relics, seals, bosses): no 0.6 s window to quit inside.
func save_now() -> void:
	save_game()


func save_soon() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(0.6, true, false, true).timeout.connect(func() -> void:
		_save_queued = false
		save_game())


## Low-stakes changes (kill ash): ride whatever save comes next (kindle, rest, area change, quit),
## or LAZY_S at most, so a fight is not interrupted by a save 0.6 s after every kill.
func save_lazy() -> void:
	if _lazy_queued:
		return
	_lazy_queued = true
	var at := _saves
	get_tree().create_timer(LAZY_S, true, false, true).timeout.connect(func() -> void:
		_lazy_queued = false
		if _saves == at:
			save_game())


func note_checkpoint(scene_path: String, at: Vector3) -> void:
	if scene_path != "":
		checkpoints[scene_path] = at
		save_soon()


func checkpoint_for(scene_path: String) -> Vector3:
	return checkpoints.get(scene_path, Vector3.INF)


func save_game() -> void:
	if erased:
		return
	if _busy:
		_save_missed = true
		return
	_saves += 1
	var t_save := Time.get_ticks_usec()
	_remember_kindles()
	var cfg := _base_cfg()
	cfg.set_value("progress", "version", SAVE_VERSION)
	cfg.set_value("progress", "lit_by_path", _compact_kindles())
	cfg.set_value("progress", "area_lit", area_lit)
	var rel := {}
	for k in relics:
		rel[k] = String(relics[k])
	cfg.set_value("progress", "relics", rel)
	cfg.set_value("progress", "checkpoints", checkpoints)
	cfg.set_value("progress", "seals", seals_broken)
	cfg.set_value("progress", "bosses", bosses_slain)
	cfg.set_value("progress", "items", items)
	cfg.set_value("progress", "loot_bags", _collect_bags())
	var p := get_tree().get_first_node_in_group(Groups.PLAYER)
	if p and "hollow_count" in p:
		saved_hollows = int(p.hollow_count)
	cfg.set_value("progress", "hollows", saved_hollows)
	cfg.set_value("story", "state", story)        # story agent: its own section (older saves lack it)
	cfg.set_value("systems", "state", systems)
	var t_built := Time.get_ticks_usec()
	_write_save(cfg)
	var t_done := Time.get_ticks_usec()
	if t_done - t_save > 8000:
		print("SAVE slow: build %.1f ms, write %.1f ms" % [float(t_built - t_save) / 1000.0, float(t_done - t_built) / 1000.0])


func load_game() -> void:
	var cfg := _read_save()
	if cfg == null:
		return
	_loaded_cfg = cfg
	from_save = true
	if int(cfg.get_value("progress", "version", 1)) > SAVE_VERSION:
		push_warning("Travel: save is format %s (this build writes %d); unknown keys are kept" % [cfg.get_value("progress", "version"), SAVE_VERSION])
	# every value is checked as it comes in: a hand-edited or damaged save loads what it can and
	# drops the rest, instead of a script error the first time something reads a wrong-typed entry
	lit_by_path = {}
	var lit := _dict(cfg, "lit_by_path")
	for k in lit:
		var names: Variant = lit[k]
		if (k is String or k is StringName) and (names is PackedStringArray or names is Array):
			var clean := PackedStringArray()
			for n: Variant in names:
				if n is String or n is StringName:
					clean.append(String(n))
			lit_by_path[String(k)] = clean
	area_lit = _flags(_dict(cfg, "area_lit"))
	relics.clear()
	var rel := _dict(cfg, "relics")
	for k in rel:
		if (k is String or k is StringName) and (rel[k] is String or rel[k] is StringName):
			relics[String(k)] = StringName(String(rel[k]))
	checkpoints = {}
	var cps := _dict(cfg, "checkpoints")
	for k in cps:
		if (k is String or k is StringName) and _sane_point(cps[k]):
			checkpoints[String(k)] = cps[k]
	seals_broken = _flags(_dict(cfg, "seals"))
	bosses_slain = _flags(_dict(cfg, "bosses"))
	items = {}
	var its := _dict(cfg, "items")
	for k in its:
		var n: Variant = its[k]
		if (k is String or k is StringName) and (n is int or n is float or (n is String and String(n).is_valid_int())):
			var c := clampi(int(n), 0, 999999)
			if c > 0:
				items[String(k)] = c
	_migrate_items()
	loot_bags = []
	var lb: Variant = cfg.get_value("progress", "loot_bags", [])
	if lb is Array:
		for r: Variant in lb:
			if r is Dictionary and (r as Dictionary).get("pos") is Vector3 and _sane_point((r as Dictionary).pos) and (r as Dictionary).get("entries") is Array:
				var ents: Array = []
				for e: Variant in (r.entries as Array):
					if e is Dictionary:          # a bag entry the bag code reads as a Dictionary: anything else is dropped, not a script error
						ents.append((e as Dictionary).duplicate(true))
				if not ents.is_empty():
					loot_bags.append({"pos": r.pos, "title": String(r.get("title", "the remains")), "entries": ents})
	_to_lay = loot_bags.duplicate(true)
	var hv: Variant = cfg.get_value("progress", "hollows", 0)
	saved_hollows = maxi(0, int(hv)) if (hv is int or hv is float) else 0
	var st: Variant = cfg.get_value("story", "state", {})
	story = (st as Dictionary).duplicate(true) if st is Dictionary else {}
	var sy: Variant = cfg.get_value("systems", "state", {})
	systems = (sy as Dictionary).duplicate(true) if sy is Dictionary else {}
	print("SAVE loaded: %d scenes with kindles, %d area fires, %d relics" % [lit_by_path.size(), area_lit.size(), relics.size()])


## Wipe this slot's progress (settings menu). The running night keeps its state, so nothing more is
## written this session (`erased`); the settings menu then returns to the title screen (to_title), where
## the next use_slot starts clean and saving works again (r35 B10: the session used to go on, never saving).
func erase_save() -> void:
	_reset_progress()
	HudPrefs.forget()
	erased = true
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
	# the Journal keeps its own file: a full erase clears it too
	CodexStore.reset(true)


## Writes the save that was asked for while a scene change held the door.
func _flush_missed() -> void:
	if _save_missed:
		_save_missed = false
		save_game()


## Forget everything held in memory (not the files).
func _reset_progress() -> void:
	lit_by_path.clear()
	area_lit.clear()
	relics.clear()
	checkpoints.clear()
	seals_broken.clear()
	bosses_slain.clear()
	items.clear()
	loot_bags.clear()
	_to_lay.clear()
	saved_hollows = 0
	story.clear()
	systems.clear()
	_loaded_cfg = null
	from_save = false
	_main_ok = null
	_save_queued = false
	_save_missed = false
	_lazy_queued = false


# --- save slots ---------------------------------------------------------------------------------

## Play slot `n` (1..SLOTS). `fresh`: a New Game: whatever the slot held is wiped first. Otherwise its save
## is loaded. Saving works again afterwards (an erased session is over).
func use_slot(n: int, fresh := false) -> void:
	slot = clampi(n, 1, SLOTS)
	SaveDir.slot = slot
	SAVE_PATH = SaveDir.path("savegame.cfg")
	_reset_progress()
	erased = false
	hollow_count = 0
	pending = false
	returning = false
	# the Journal follows the slot
	CodexStore.use_path(SaveDir.path("codex.cfg"), not fresh)
	if fresh:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(SAVE_PATH + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
		if FileAccess.file_exists(CodexStore.path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CodexStore.path))
	else:
		load_game()
	var c := _slots_cfg()
	c.set_value("slots", "last", slot)
	SaveDir.save_atomic(c, SaveDir.dir() + "slots.cfg")


## The title screen's line about slot `n`: {exists, text, fires, bosses, hollows}.
func slot_summary(n: int) -> Dictionary:
	var out := {"exists": false, "text": "", "fires": 0, "bosses": 0, "hollows": 0}
	var path := SaveDir.slot_path(n, "savegame.cfg")
	for p: String in [path, path + ".tmp", path + ".bak"]:
		var from_bak := p.ends_with(".bak")
		if not FileAccess.file_exists(p):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(p) != OK or not cfg.has_section("progress"):
			continue
		var fires := 0
		var lit: Variant = cfg.get_value("progress", "lit_by_path", {})
		if lit is Dictionary:
			for k in lit:
				if lit[k] is Array or lit[k] is PackedStringArray:
					fires += (lit[k] as Variant).size()
		var al: Variant = cfg.get_value("progress", "area_lit", {})
		if al is Dictionary:
			# an area fire (the ossuary gate) is also a lit brazier by name under its scene: count it once
			var named := {}
			if lit is Dictionary:
				for k2 in lit:
					if lit[k2] is Array or lit[k2] is PackedStringArray:
						for nm: Variant in lit[k2]:
							named[String(nm)] = true
			for ak in al:
				if not named.has(String(ak).get_file()):
					fires += 1
		var bs: Variant = cfg.get_value("progress", "bosses", {})
		var bosses: int = (bs as Dictionary).size() if bs is Dictionary else 0
		var hv: Variant = cfg.get_value("progress", "hollows", 0)
		var hollows := int(hv) if (hv is int or hv is float) else 0
		var when := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(p)).substr(0, 10)
		out.exists = true
		out.fires = fires
		out.bosses = bosses
		out.hollows = hollows
		out.text = "%d fire%s kindled  ·  %d keeper%s slain  ·  %s%s" % [fires, "" if fires == 1 else "s", bosses, "" if bosses == 1 else "s", when, "  ·  from the backup" if from_bak else ""]
		out["backup"] = from_bak
		return out
	return out


func _slots_cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(SaveDir.dir() + "slots.cfg")
	return c


## Before slots there was one <dir>/savegame.cfg. The first launch with slots copies it into slot 1,
## keeping its .bak, and renames the old files to *.migrated: nothing is lost, and an erased slot 1 is
## not refilled from it. (The Journal's codex.cfg stays where it was: it is slot 1's.)
func _migrate_legacy() -> void:
	var legacy := SaveDir.dir() + "savegame.cfg"
	var s1 := SaveDir.slot_path(1, "savegame.cfg")
	if FileAccess.file_exists(legacy) and not FileAccess.file_exists(s1):
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(legacy + suffix):
				DirAccess.copy_absolute(ProjectSettings.globalize_path(legacy + suffix), ProjectSettings.globalize_path(s1 + suffix))
				DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy + suffix), ProjectSettings.globalize_path(legacy + suffix + ".migrated"))


## The settings menu's "Erase Saved Progress", and anything else that ends a run: back to the title screen.
func to_title() -> void:
	forced_title = true
	pending = false
	returning = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://ui/title_boot.tscn")


## A [progress] dictionary from the save, or {} if it is missing or the wrong type.
func _dict(cfg: ConfigFile, key: String) -> Dictionary:
	var v: Variant = cfg.get_value("progress", key, {})
	return v if v is Dictionary else {}


## An id -> true set (seals, bosses, area fires): string keys whose value is set; anything else dropped.
func _flags(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v: Variant = d[k]
		var on := bool(v) if (v is bool or v is int or v is float) else v != null
		if (k is String or k is StringName) and on:
			out[String(k)] = true
	return out


## A checkpoint the player can stand at: a finite Vector3 inside any world this game builds.
func _sane_point(v: Variant) -> bool:
	if not v is Vector3:
		return false
	var p: Vector3 = v
	return p.is_finite() and absf(p.x) < 5000.0 and absf(p.z) < 5000.0 and p.y > -200.0 and p.y < 2000.0


## Kindle memory without the scenes that have none lit (every test scene visited used to add one).
func _compact_kindles() -> Dictionary:
	var out := {}
	for k in lit_by_path:
		var names: Variant = lit_by_path[k]
		if not ((names is PackedStringArray or names is Array) and names.is_empty()):
			out[k] = names
	return out


## What the next save is built on: the loaded save (so keys this build doesn't write survive), or new.
## The same object every time: save_game() overwrites every key it owns, so no copy is needed.
func _base_cfg() -> ConfigFile:
	if _loaded_cfg == null:
		_loaded_cfg = ConfigFile.new()
	return _loaded_cfg


## The newest readable save: the main file, else the unfinished one beside it, else the backup. null if there is none.
func _read_save() -> ConfigFile:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(path) == OK and cfg.has_section("progress"):
			_main_ok = path == SAVE_PATH
			if path.ends_with(".tmp"):
				push_warning("Travel: %s was unreadable; loaded the unfinished save beside it" % SAVE_PATH)
			elif path != SAVE_PATH:
				push_warning("Travel: %s was unreadable; loaded the backup" % SAVE_PATH)
			return cfg
		if path.ends_with(".tmp"):
			continue                    # half-written: skipped quietly
		if path == SAVE_PATH:
			_main_ok = false
		push_warning("Travel: %s is unreadable" % path)
	return null


## Atomic save: write a temp file, keep the current good save as .bak, then rename the temp over
## the save (a crash mid-write leaves the old save, never half a file). Nothing is parsed back:
## ConfigFile.save reports a failed write, and whether the main file is good is tracked in _main_ok
## (set when it was loaded or last written); only a main file this run never saw is checked, once.
func _write_save(cfg: ConfigFile) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	var tmp := SAVE_PATH + ".tmp"
	var err := cfg.save(tmp)
	if err != OK or not FileAccess.file_exists(tmp):
		push_warning("Travel.save_game failed: %s" % str(err))
		return
	var main := ProjectSettings.globalize_path(SAVE_PATH)
	var exists := FileAccess.file_exists(SAVE_PATH)
	if exists and _main_ok == null:
		var prev := ConfigFile.new()           # e.g. a --fresh run: the file on disk was never read
		_main_ok = prev.load(SAVE_PATH) == OK and prev.has_section("progress")
	if exists and _main_ok and (not _wrote_ok or not FileAccess.file_exists(main + ".bak")):
		DirAccess.copy_absolute(main, main + ".bak")        # once a session: the night before it started
	err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), main)
	if err != OK:
		# the previous main file is untouched (rename is all-or-nothing); say so once, not every save
		if not _warned_rename:
			_warned_rename = true
			push_warning("Travel.save_game rename failed: %s; the previous save stands" % err)
		return
	_main_ok = true
	_wrote_ok = true
	_loaded_cfg = cfg



## A system's saved state (created empty on first use). Mutate the returned dictionary in place.
func system_state(id: String) -> Dictionary:
	if not systems.has(id) or not (systems[id] is Dictionary):
		systems[id] = {}
	return systems[id]
