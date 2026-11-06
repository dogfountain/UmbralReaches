extends Node
## Journal (codex) check: godot --headless --path . res://zz/lore_codex_test.tscn -- --realm-modules=land,lore
## Uses its own journal file (user://codex_test.cfg, deleted at the end), never the player's.
## Reads N inscriptions through Inscription.interact, then checks: each is in the journal and
## opened the reading panel, glints go out, reading again closes the panel, every book tab fills
## (Wenna's pages in order with gaps), a region discovery, the file round-trips (persistence),
## item flavour, and that LoreDB series are complete and every entry is placed.
## Ends CODEX TEST PASS / FAIL n.
const LoreDB := preload("res://core/world/realm/lore_db.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const TEST_PATH := "user://codex_test.cfg"
const READ := ["jn_1", "jn_3", "jn_7", "hw_maud_2", "tw_song_1", "br_tally_4", "rd_way_12", "ch_hearth", "gl_shoe", "rim_bell", "fen_rite", "tw_axe"]
var t := 0.0
var fails := 0
var done := false


func _ready() -> void:
	CodexStore.use_path(TEST_PATH, false)
	CodexStore.persist = true
	CodexStore.reset(true)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func fail(msg: String) -> void:
	fails += 1
	print("CODEX FAIL ", msg)


func _process(d: float) -> void:
	t += d
	if done:
		return
	var rl := get_tree().root.find_child("RealmLore", true, false)
	var main := get_tree().root.find_child("Main", true, false)
	# the whole Realm, not just the lore module: the places' own stones (RealmPois) come after it
	if rl == null or not rl.has_meta("scraps") or main == null or not main.has_meta("realm_done"):
		if t > 150.0:
			fail("RealmLore never finished")
			_end()
		return
	done = true
	await get_tree().create_timer(0.5).timeout
	var codex := get_tree().get_first_node_in_group("codex")
	if codex == null:
		fail("no codex in the scene")
		_end()
		return
	# --- data: series complete, every entry has a home --------------------------------------------
	for s: String in LoreDB.SERIES:
		var ids := LoreDB.series_ids(s)
		if ids.size() != int(LoreDB.SERIES[s].count):
			fail("series %s has %d parts, says %d" % [s, ids.size(), LoreDB.SERIES[s].count])
		for i in ids.size():
			if int(LoreDB.entry(ids[i]).part) != i + 1:
				fail("series %s part %d is %s" % [s, i + 1, ids[i]])
	for id: String in LoreDB.TEXTS:
		var e := LoreDB.entry(id)
		if not LoreDB.PLACE_INFO.has(String(e.region)):
			fail("%s region %s has no place info" % [id, e.region])
		if String(e.text).length() > 320:
			fail("%s is %d chars" % [id, String(e.text).length()])
	var scraps := {}
	for s in get_tree().root.find_children("Lore_*", "", true, false):
		scraps[String(s.get("lore_id"))] = s
	# r31: the places' own stones (poi_*) are set by RealmPois, which a --realm-modules run may skip
	var pois_built := get_tree().root.find_child("RealmPois", true, false) != null
	for id: String in LoreDB.TEXTS:
		if id.begins_with("poi_") and not pois_built:
			continue
		if not scraps.has(id):
			fail("entry %s not placed in the world" % id)
	# --- reading ---------------------------------------------------------------------------------
	for id: String in READ:
		var s: Node = scraps.get(id)
		if s == null:
			fail("%s missing" % id)
			continue
		if s.get_node_or_null("Glint") == null:
			fail("%s unread but has no glint" % id)
		(s as Interactable).interact(null)
		if not CodexStore.has_read(id):
			fail("%s not journaled" % id)
		if String(codex.call("reading_id")) != id:
			fail("%s did not open the reading panel (%s)" % [id, codex.call("reading_id")])
		await get_tree().process_frame
		if s.get_node_or_null("Glint") != null:
			fail("%s glint still lit after reading" % id)
	# reading the same stone again puts the panel down; the journal does not double count
	var last: Node = scraps[READ[READ.size() - 1]]
	(last as Interactable).interact(null)
	await get_tree().create_timer(0.5).timeout
	if String(codex.call("reading_id")) != "":
		fail("reading again did not close the panel")
	if CodexStore.read.size() != READ.size():
		fail("journal has %d entries for %d reads" % [CodexStore.read.size(), READ.size()])
	var order := CodexStore.read_in_order()
	if order.is_empty() or order[0] != READ[0]:
		fail("journal order starts %s" % [order.slice(0, 1)])
	# --- places ----------------------------------------------------------------------------------
	codex.call("enter_region", "road")
	codex.call("enter_region", "thornwood")
	if not CodexStore.discovered("road") or not CodexStore.discovered("thornwood"):
		fail("regions not discovered")
	# --- the book --------------------------------------------------------------------------------
	codex.call("open_book", 0)
	await get_tree().process_frame
	if not get_tree().paused or not bool(codex.call("is_open")):
		fail("book did not open / pause")
	var counts := []
	for i in 5:
		codex.call("_show_tab", i)
		await get_tree().process_frame
		var list: VBoxContainer = codex.get("_list")
		var buttons := 0
		var missing := 0
		for c in list.get_children():
			if c is Button and not c.is_queued_for_deletion():
				buttons += 1
				if (c as Button).text.contains("not yet found"):
					missing += 1
		counts.append([buttons, missing])
	print("CODEX tabs (entries, missing): ", counts)
	if counts[0][0] != 9 or counts[0][1] != 6:
		fail("Wenna's tab: %s, want 9 entries with 6 missing" % [counts[0]])
	if counts[1][0] < 20:
		fail("stories tab lists %d" % counts[1][0])
	if counts[2][0] < 3:
		fail("writings tab lists %d" % counts[2][0])
	if counts[3][0] != LoreDB.REGION_ORDER.size():
		fail("places tab lists %d" % counts[3][0])
	var page_title := String((codex.get("_p_title") as Label).text)
	print("CODEX page shown: ", page_title, "  counts: ", (codex.get("_counts") as Label).text)
	codex.call("close_book")
	if get_tree().paused:
		fail("book left the tree paused")
	# --- persistence -----------------------------------------------------------------------------
	if not FileAccess.file_exists(TEST_PATH):
		fail("journal file not written")
	var n_read := CodexStore.read.size()
	var n_places := CodexStore.places.size()
	CodexStore.use_path(TEST_PATH, true)
	if CodexStore.read.size() != n_read or CodexStore.places.size() != n_places:
		fail("reload: %d/%d read, %d/%d places" % [CodexStore.read.size(), n_read, CodexStore.places.size(), n_places])
	if CodexStore.read_in_order() != order:
		fail("reload changed the order")
	print("CODEX persisted %d writings, %d places to %s" % [n_read, n_places, TEST_PATH])
	# --- items -----------------------------------------------------------------------------------
	for id: String in ItemDB.DEFS:
		if String(ItemDB.def(id).get("desc", "")) == "":
			fail("item %s has no desc" % id)
	_end()


func _end() -> void:
	CodexStore.reset(true)                      # deletes user://codex_test.cfg only
	CodexStore.persist = false
	print("CODEX TEST PASS" if fails == 0 else "CODEX TEST FAIL %d" % fails)
	get_tree().quit()
