extends Node
## The story director (docs/STORY.md). One per night, added by Tavern (the story lives at the
## Kindled Keg). Group "story".
##   - state: Travel.story = {"flags": {id: true}, "picked": {choice key: true}} (saved with the game)
##   - talk(conv_id, npc, player): runs a conversation from core/story/dialogue_db.gd in the
##     dialogue box (ui/dialogue.gd): resolves the start node and say_if lines against the world,
##     applies `do` flags, hides `once` choices already picked; the speaking NPC faces the wanderer
##     and moves his jaw while his line types
##   - objectives(): the lines for the HUD (core/story/objective_line.gd), from QuestDB
##   - opening narration on the first arrival at Hearthward; ending narration after the Ascended
##     Warden falls (both non-blocking subtitles), and the title card after the last conversation
## World state comes from Travel (seals_broken, bosses_slain, items) and the four braziers.

const QuestDB := preload("res://core/story/quest_db.gd")
const DialogueDB := preload("res://core/story/dialogue_db.gd")
const DialogueUI := preload("res://ui/dialogue.gd")
const HudUI := preload("res://ui/hud.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const ShopUI := preload("res://ui/shop.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const QuestGiver := preload("res://core/story/quest_giver.gd")
const QuestRunner := preload("res://core/story/quest_runner.gd")
const QuestMarkers := preload("res://core/story/quest_markers.gd")
const QuestOfferUI := preload("res://ui/quest_offer.gd")
const Guide := preload("res://core/story/guide.gd")
const QuestTrack := preload("res://core/story/quest_track.gd")
const QuestTrail := preload("res://core/story/quest_trail.gd")
const GuideLines := preload("res://core/story/guide_lines.gd")
const Hints := preload("res://ui/hints.gd")
const OpeningShot := preload("res://core/story/opening_shot.gd")
const DangerWatch := preload("res://core/life/encounters/danger_watch.gd")
const Tally := preload("res://core/story/tally.gd")
const Days := preload("res://core/story/days.gd")
const TallyPanel := preload("res://ui/tally_panel.gd")
const FirstHour := preload("res://core/story/first_hour.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const Profile := preload("res://core/util/profile.gd")
const HorsePanel := preload("res://ui/horse_panel.gd")
const EmberTrace := preload("res://core/story/ember_trace.gd")
const HudPrefsOpen := preload("res://ui/hud_prefs.gd")
const BellVoice := preload("res://core/story/bell_voice.gd")
const DrainBeat := preload("res://core/story/drain_beat.gd")

signal objectives_changed

var ui: CanvasLayer
var log_ui: CanvasLayer           ## the tasks' banner and ledger (ui/quest_log.gd)
var offer_ui: CanvasLayer         ## r33: the accept / turn-in screens (ui/quest_offer.gd)
var runner: Node                  ## r33: counts kills, seals, places for the tasks (quest_runner.gd)
var markers: Node3D               ## r33: the marks over the givers' heads, the map pins (quest_markers.gd)
var guide: Guide                  ## a new player's way through the first act (guide.gd): the lessons, the next step's banner and place
var track: Node                   ## the tracked task and where its step is (quest_track.gd): what the waypoint, compass, objective line and trail follow
var trail: Node                   ## where the one waypoint hangs on the way to it (quest_trail.gd)
var _quest_after := ""            ## "offer:id" / "turnin:id" chosen in a conversation
var _conv := ""
var _node := ""
var _npc: Node3D
var _player: Node3D
var _lit: Dictionary = {}          ## brazier name -> true, as seen this session (plus the save)
var opening_delay := 6.0           ## after the zone title card


func _ready() -> void:
	add_to_group("story")
	process_mode = Node.PROCESS_MODE_ALWAYS      # the dialogue pauses the tree; the portrait lives on
	_state()
	ui = DialogueUI.new()
	ui.name = "Dialogue"
	get_tree().root.add_child.call_deferred(ui)      # last in the tree: first to see input
	log_ui = (load("res://ui/quest_log.gd") as GDScript).new()
	log_ui.name = "QuestLog"
	get_tree().root.add_child.call_deferred(log_ui)
	offer_ui = QuestOfferUI.new()
	offer_ui.name = "QuestOffer"
	get_tree().root.add_child.call_deferred(offer_ui)
	runner = QuestRunner.new()
	runner.name = "QuestRunner"
	add_child(runner)
	markers = QuestMarkers.new()
	add_child(markers)
	guide = Guide.new()
	add_child(guide)
	add_child(DangerWatch.new())
	add_child(Tally.new())
	add_child(Days.new())
	add_child(TallyPanel.new())
	add_child(FirstHour.new())
	add_child(Chronicle.new())
	add_child(Wayfarer.new())
	add_child(Courier.new())
	add_child(EmberTrace.new())
	add_child(HorsePanel.new())
	add_child(PhotoMode.new())
	track = QuestTrack.new()
	add_child(track)
	trail = QuestTrail.new()
	add_child(trail)
	BellVoice.warm()                              # the one small bell, rendered on a worker thread
	add_child((load("res://core/story/kindle_bells.gd") as GDScript).new())      # the fires ring a rising phrase
	add_child((load("res://core/story/aurel_voice.gd") as GDScript).new())       # the Hierarch, through the night
	ui.advanced.connect(_on_advanced)
	ui.chosen.connect(_on_chosen)
	ui.closed.connect(_on_closed)
	Events.brazier_kindled.connect(func(b: Node3D) -> void:
		if String(b.name) in QuestDB.BRAZIERS:
			_lit[String(b.name)] = true
		objectives_changed.emit())
	Events.seal_broken.connect(func(_id: String) -> void: objectives_changed.emit())
	Events.boss_slain.connect(_on_boss)
	Events.item_gained.connect(func(_id: String, _a: int, _t: int) -> void: objectives_changed.emit())
	# an older save with progress already made: the arrival has happened
	if not flag("arrived") and (not Travel.bosses_slain.is_empty() or not Travel.seals_broken.is_empty()):
		set_flag("arrived")
		set_flag("met_keep")
	if not flag("arrived"):
		_after_cover(_opening)
	elif Travel.bosses_slain.has("ascended_warden") and not flag("ending_seen"):
		# the game was left in the seconds between the Warden's fall and the ending's words
		_after_cover(_ending)


## Run `fn` opening_delay seconds after the loading screen lifts (ui/loading_screen.gd is a child of
## Main while it covers the night): before, the timer ran under the cover and the opening line
## landed on the zone's title card.
func _after_cover(fn: Callable) -> void:
	var t := 0.0
	while is_inside_tree() and get_tree().root.get_node_or_null("Main/LoadingScreen") != null and t < 60.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	if not is_inside_tree():
		return
	await get_tree().create_timer(opening_delay if _staged_hud() == null else 1.2).timeout
	if is_inside_tree():
		fn.call()


func _exit_tree() -> void:
	BellVoice.release()
	if is_instance_valid(ui):
		ui.queue_free()
	if is_instance_valid(shop):
		shop.queue_free()
	if is_instance_valid(log_ui):
		log_ui.queue_free()
	if is_instance_valid(offer_ui):
		offer_ui.queue_free()


# --- state ----------------------------------------------------------------------------------

func _state() -> Dictionary:
	if not Travel.story.has("flags"):
		Travel.story["flags"] = {}
	if not Travel.story.has("picked"):
		Travel.story["picked"] = {}
	return Travel.story


func flag(id: String) -> bool:
	return bool((_state().flags as Dictionary).get(id, false))


func set_flag(id: String, on := true) -> void:
	var f: Dictionary = _state().flags
	if on:
		f[id] = true
	else:
		f.erase(id)
	objectives_changed.emit()
	Travel.save_soon()


## Run a node's or choice's actions: story flags here, tasks / attitudes / ash in QuestBook.
## Returns QuestBook.run's result (poor: a payment failed; shop: a merchant to open after).
func _do(actions: String) -> Dictionary:
	var r := QuestBook.run(actions)
	for a: String in r.rest:
		if a.begins_with("flag:-"):
			set_flag(a.trim_prefix("flag:-"), false)
		elif a.begins_with("flag:"):
			set_flag(a.trim_prefix("flag:"))
	if String(r.scene) != "":
		var ks := get_tree().get_first_node_in_group("keg_scenes")
		if ks and ks.has_method("play"):
			ks.call_deferred("play", String(r.scene))
	return r


## How many of the valley's four braziers burn (live nodes, else the save's kindle memory).
func kindled() -> int:
	var names := {}
	for n: String in _lit:
		names[n] = true
	var scene := get_tree().current_scene
	if scene:
		for n: String in QuestDB.BRAZIERS:
			var b := scene.get_node_or_null("Zone/Braziers/" + n)
			if b and bool(b.get("lit")):
				names[n] = true
		var saved: PackedStringArray = Travel.lit_by_path.get(scene.scene_file_path, PackedStringArray())
		for n: String in QuestDB.BRAZIERS:
			if n in saved:
				names[n] = true
	return names.size()


func world() -> Dictionary:
	return {"flags": _state().flags, "kindled": kindled(), "seals": Travel.seals_broken,
		"bosses": Travel.bosses_slain, "items": Travel.items, "bells": QuestBook.bells()}


## The HUD's lines: what is tracked (docs/quest_trail.md). The story's way (the default while the guide is on, or when
## picked in the ledger): the spine (at most 2) and the kindling. A task picked (or the newest): its one block, with
## its name and count (QuestBook.lines). Before the keep has spoken, only the tutorial spine line shows: no side noise
## at spawn.
func objectives() -> Array:
	var ws := world()
	var all := QuestDB.active(ws, 9)
	var out: Array = []
	for o: Dictionary in all:
		if bool(o.main) and out.size() < 2:
			out.append(o)
	if not QuestDB.test("flag:met_keep", ws):
		return out.slice(0, 1)
	var task := QuestBook.lines(1)
	if not task.is_empty():
		return task
	for o2: Dictionary in all:
		if not bool(o2.main) and out.size() < 3:
			out.append(o2)
	return out.slice(0, 3)


# --- conversations ---------------------------------------------------------------------------

func talk(conv_id: String, npc: Node3D = null, player: Node3D = null) -> bool:
	if not DialogueDB.CONV.has(conv_id) or not is_instance_valid(ui) or ui.is_open():
		return false
	var start := DialogueDB.start_node(conv_id, world())
	if start == "":
		return false
	_conv = conv_id
	_npc = npc if is_instance_valid(npc) else null
	_player = player
	_plife = null                     # each speaker's portrait breathes and blinks in its own rhythm
	if _npc and "attend" in _npc:
		_npc.set("attend", _player)
	var c: Dictionary = DialogueDB.CONV[conv_id]
	ui.open(String(c.name), c.get("portrait", {}))
	ui.set_voice(Voice.for_node(_npc) if _npc else {}, String(c.name))   # each NPC speaks in his own voice
	ui.call("set_mood", QuestBook.att(conv_id))
	_show(start)
	return true


var _syn := {}                    ## a line made on the spot (a failed payment), shown as node "#syn"
var _shop_after := ""


func _show(node_id: String) -> void:
	_node = node_id
	var n := _syn if node_id == "#syn" else (_guide_node() if node_id == "#guide" else DialogueDB.node(_conv, node_id))
	if n.is_empty():
		_end()
		return
	if n.has("do"):
		var r := _do(String(n["do"]))
		if String(r.shop) != "":
			_shop_after = String(r.shop)
	var ws := world()
	var choices := DialogueDB.choices_of(_conv, node_id, n, ws, _state().picked)
	if node_id == "hub":
		choices = QuestGiver.merge(choices, _conv, get_tree())      # r33: the offered tasks' lines
		if is_instance_valid(guide) and guide.answer() != "" and not _conv in ["keep", "brannoc"]:
			choices.insert(maxi(0, choices.size() - 1), {"text": GuideLines.ASK, "to": "#guide", "key": "guide:ask"})
	var labels: Array[String] = []
	var marks: Array[String] = []
	for ch: Dictionary in choices:
		labels.append(QuestBook.label(String(ch.text), String(ch.get("do", ""))))
		marks.append(QuestBook.task_mark(ch))
	ui.set_meta("choices", choices)
	ui.call("set_mood", QuestBook.att(_conv))
	ui.line(String(n.get("who", (DialogueDB.CONV[_conv] as Dictionary).name)), DialogueDB.text_of(n, ws), labels, marks)
	_speaking(true)


## "Which way?" asked of a patron in a guided first act: the guide's answer, then back to the hub.
func _guide_node() -> Dictionary:
	return {"who": String((DialogueDB.CONV.get(_conv, {}) as Dictionary).get("name", "")), "say": guide.answer() if is_instance_valid(guide) else "", "next": "hub"}


func _on_advanced() -> void:
	if _conv == "":
		return
	var n := _syn if _node == "#syn" else (_guide_node() if _node == "#guide" else DialogueDB.node(_conv, _node))
	if n.has("choices"):
		return
	var nx := String(n.get("next", ""))
	if nx == "":
		_end()
	else:
		_show(nx)


func _on_chosen(i: int) -> void:
	if _conv == "":
		return
	var choices: Array = ui.get_meta("choices", [])
	if i < 0 or i >= choices.size():
		return
	var ch: Dictionary = choices[i]
	if ch.has("quest_ui"):
		_quest_after = String(ch.quest_ui)
		_end()
		return
	if String(ch.get("do", "")) != "":
		var r := _do(String(ch["do"]))
		if bool(r.poor):
			_syn = {"who": String((DialogueDB.CONV[_conv] as Dictionary).name), "say": "You haven't the ash for that. (%d in your satchel.)" % Travel.count("grave_ash"), "next": _node}
			_show("#syn")
			return
		if String(r.shop) != "":
			_shop_after = String(r.shop)
	_state().picked[ch.key] = true
	var to := String(ch.to)
	if to == "":
		_end()
	else:
		_show(to)


func _end() -> void:
	var was := _conv
	_conv = ""
	_speaking(false)
	if is_instance_valid(_npc) and "attend" in _npc:
		_npc.set("attend", null)
	_npc = null
	if is_instance_valid(ui) and ui.is_open():
		ui.close()
	Travel.save_soon()
	objectives_changed.emit()
	if _quest_after != "":
		var qa := _quest_after
		_quest_after = ""
		open_quest.call_deferred(qa, String((DialogueDB.CONV.get(was, {}) as Dictionary).get("name", "")))
	if is_instance_valid(guide):
		guide.talked(was)
	if _shop_after != "":
		var who := _shop_after
		_shop_after = ""
		open_shop.call_deferred(who)
	if was == "keep" and flag("ending_told") and not flag("ending_card"):
		set_flag("ending_card")
		Events.zone_entered.emit("THE DOOR IS SHUT", "Hearthward keeps its fire")
	# r36 Act III: the epilogue's card, by what was done with the latch
	elif was == "keep" and flag("epilogue_told") and not flag("epilogue_card"):
		set_flag("epilogue_card")
		match QuestBook.pick("the_latch"):
			"latched":
				Events.zone_entered.emit("THE DOOR IS LATCHED", "Nothing climbs. Nothing comes down.")
			"broken":
				Events.zone_entered.emit("THE DOOR IS GONE", "Only the sky, and the fire under it")
			_:
				Events.zone_entered.emit("THE DOOR IS ON THE LATCH", "The ones above may come home")


func _on_closed() -> void:
	# the box was closed from the UI (Esc): end the conversation where it stands
	if _conv != "":
		_shop_after = ""
		_end()


## r33: the accept ("offer:id") or turn-in ("turnin:id") screen, after a conversation.
func open_quest(what: String, giver_name := "") -> bool:
	if not is_instance_valid(offer_ui) or not offer_ui.is_inside_tree():
		return false
	var p := what.split(":", true, 1)
	if p.size() < 2:
		return false
	if p[0] == "offer":
		return bool(offer_ui.call("open_offer", p[1], giver_name))
	if p[0] == "turnin":
		return bool(offer_ui.call("open_turnin", p[1], giver_name))
	return false


## The merchants' shop (ui/shop.gd): "keep" (the Keg's slate) or "grisel" (the ash-wife).
var shop: CanvasLayer


func open_shop(who: String, npc: Node3D = null) -> bool:
	if not is_instance_valid(shop):
		shop = ShopUI.new()
		shop.name = "Shop"
		get_tree().root.add_child(shop)
	if (is_instance_valid(ui) and ui.is_open()) or shop.call("is_open"):
		return false
	shop.call("open", who, npc)
	return true


func _speaking(on: bool) -> void:
	if is_instance_valid(_npc) and "speaking" in _npc:
		_npc.set("speaking", on)


func _process(d: float) -> void:
	if _end_step > 0:
		_ending_tick(d)
	# the NPC's jaw moves while his line types, and stops when it has
	if _conv != "" and is_instance_valid(ui):
		_speaking(ui.typing())
		_portrait_live(d)


## The box's portrait bust lives: breathes, blinks, glances, talks by syllable (npc_life.gd).
var _plife: RefCounted

func _portrait_live(d: float) -> void:
	var r: Variant = ui.get("_rig")
	if not (r is DwarfRig) or not is_instance_valid(r):
		return
	var rig := r as DwarfRig
	if _plife == null:
		_plife = (load("res://core/npc/npc_life.gd") as GDScript).new(hash(_conv))
	rig.set_meta("live", true)        # the box's own idle sway stands aside (ui/dialogue.gd)
	rig.reset()
	_plife.call("portrait", rig, d, ui.typing(), 0.085)
	rig.apply()


# --- beats ---------------------------------------------------------------------------------

## The HUD, if it is holding a new game's opening (black, no HUD): see ui/hud.gd hold_opening.
func _staged_hud() -> Node:
	var hud := get_tree().get_first_node_in_group(&"hud") if is_inside_tree() else null
	return hud if hud != null and hud.has_method("hold_opening") and bool(hud.get("_opening_hold")) else null


func _opening() -> void:
	if flag("arrived"):
		return
	set_flag("arrived")
	if not is_instance_valid(ui):
		return
	var hud := _staged_hud()
	if hud == null:
		ui.narrate(DialogueDB.OPENING)          # a harness, an older save: the three lines at once, as before
		return
	set_flag("guide")                           # a real new game: the guide walks the first act with it (guide.gd)
	_stage_opening(hud)


## a new game opens in beats, one message at a time. The black lifts over the world and the zone's title
## card plays on it; when the card is gone the first line is spoken; when the wanderer first moves the HUD
## arrives and the rest is spoken; the place banner (the region's name) waits for all of it (the text
## director holds banners while the HUD's opening is staged and while narration is up). The Gloom bar
## waits for Gloom, the compass and minimap for the Keep, the hotbar's slots for the spells taught.
func _stage_opening(hud_node: Node) -> void:
	var hud := hud_node as HudUI
	hud.fade_in_opening(3.0)
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var start := p.global_position if p else Vector3.ZERO
	await get_tree().create_timer(0.6).timeout
	var c := 0.0
	while is_inside_tree() and is_instance_valid(hud) and hud.title_busy() and c < 12.0:
		await get_tree().create_timer(0.2).timeout
		c += 0.2
	if not is_inside_tree() or not is_instance_valid(hud) or not is_instance_valid(ui):
		return
	if HudPrefsOpen.opening and not flag("opening_seen"):
		set_flag("opening_seen")
		if await _play_opening(hud, p):
			return
	ui.narrate([DialogueDB.OPENING[0]])
	if Guide.on():
		# guided (guide.gd): the HUD comes with the first line, so the first objective, its mark and the compass are up
		# as soon as the card has gone; the move prompt takes the lesson lane when the line is read, and the rest is
		# said once the wanderer is on the move and the prompt has had its turn (one message at a time, still)
		hud.hold_opening(false)
		var w := 0.0
		while is_inside_tree() and w < 60.0:
			if (not is_instance_valid(p) or p.global_position.distance_to(start) >= 2.5) and Hints.seen(&"tip_move"):
				break
			await get_tree().create_timer(0.25).timeout
			w += 0.25
		w = 0.0
		while is_inside_tree() and is_instance_valid(hud) and hud.lesson_busy() and w < 7.0:
			await get_tree().create_timer(0.25).timeout       # the move prompt's turn (not every lesson queued behind it)
			w += 0.25
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(ui):
			ui.narrate([DialogueDB.OPENING[1]])
			DrainBeat.play(self, ui.narrate)             # the cold arrives: the green's people go in, the Keg looks at its door
		# the last line is the first objective in words: said only while it still is (a quick wanderer has met the keep)
		w = 0.0
		while is_inside_tree() and is_instance_valid(ui) and ui.narrating() and w < 60.0:
			await get_tree().create_timer(0.25).timeout
			w += 0.25
		if is_instance_valid(ui) and not flag("met_keep"):
			ui.narrate([DialogueDB.OPENING[2]])
		return
	await get_tree().create_timer(1.0).timeout
	var t := 0.0
	while is_inside_tree() and is_instance_valid(p) and p.global_position.distance_to(start) < 2.5 and t < 150.0:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
	if not is_inside_tree() or not is_instance_valid(hud):
		return
	if is_instance_valid(ui):
		ui.narrate(DialogueDB.OPENING.slice(1))      # queued before the HUD's hold lifts: no banner slips in between
	hud.hold_opening(false)


## The Last Lantern (opening_shot.gd): the three lines are spoken at the shot's beats, the HUD arrives when the lens
## is given back. True when it played (or was skipped); false when there was nothing to shoot and the old beats run.
func _play_opening(hud: HudUI, p: Node3D) -> bool:
	Profile.ensure()
	var again := Profile.endings > 0                  # a New Game after an ending: the second night's opening
	var lines: Array = DialogueDB.OPENING_AGAIN if again else DialogueDB.OPENING
	var shot: OpeningShot = OpeningShot.new()
	add_child(shot)
	if not shot.begin(p, again):
		shot.queue_free()
		return false
	var said := [false]
	shot.beat.connect(func(i: int) -> void:
		match i:
			0:
				BellVoice.ring(self, -26.0 if not again else -22.0, -14.0)          # the sky's low stroke under the black
			1, 2, 3:
				if not is_instance_valid(ui) or (i == 3 and flag("met_keep")):
					return
				said[0] = said[0] or i == 3
				ui.narrate([lines[i - 1]])
				if i == 2:
					DrainBeat.play(self, ui.narrate)          # the cold arrives while the lens is over the green
			4:
				BellVoice.ring(self, 0.0, -17.0)             # the lantern's chime: a fifth, then the octave
				BellVoice.ring(self, 7.0, -19.0, 0.35)
				BellVoice.ring(self, 12.0, -21.0, 0.7))
	var skipped: bool = await shot.finished
	if not is_inside_tree() or not is_instance_valid(hud):
		return true
	if skipped and is_instance_valid(ui) and not said[0] and not flag("met_keep"):
		ui.narrate([lines[2]])                           # a skipped shot still says where to go
	hud.hold_opening(false)
	return true


func _on_boss(id: String) -> void:
	objectives_changed.emit()
	if id == "ascended_warden" and not flag("ending_seen"):
		get_tree().create_timer(9.5).timeout.connect(_ending)      # after the 9 s spin tween, the bar dropped; a breath of silence


## The ending, staged as one beat (r30): no toasts (boss_arena, summit_dress and reactivity keep
## quiet for the Warden); the sky's spin is already easing to still (reactivity.gd, ~9 s) when
## "The sky stops turning." is said; once it has been read, one deep bell (Brannoc's: low, long,
## once, everywhere at once); then the last two lines. The flag is set when the beat starts, not when
## the Warden falls, so leaving the game in between still lets it play on the next load (_ready).
func _ending() -> void:
	if flag("ending_seen") or not is_instance_valid(ui):
		return
	set_flag("ending_seen")
	Profile.note_ending()                         # the profile remembers: a later New Game opens as the second night
	ui.narrate([DialogueDB.ENDING[0]])
	_end_step = 1
	_end_t = 0.0


var _end_step := 0                ## the ending beat: 1 = first line showing, 2 = the bell ringing
var _end_t := 0.0

func _ending_tick(d: float) -> void:
	_end_t += d
	if not is_instance_valid(ui):
		_end_step = 0
	elif _end_step == 1 and (not ui.narrating() or _end_t > 30.0):
		ring_bell()
		_end_step = 2
		_end_t = 0.0
	elif _end_step == 2 and _end_t >= 2.4:
		ui.narrate(DialogueDB.ENDING.slice(1))
		_end_step = 0


## The one bell. r35: a great bell of its own (boss_themes.gd great_bell: a tower bell's partials on
## A2, the hum swelling in after the strike, ~24 s), not the scape's small bell pitched two octaves
## down. Not positional: it is heard over the whole valley. The explore music keeps its bell out until now.
func ring_bell() -> void:
	var a := AudioStreamPlayer.new()
	a.name = "EndingBell"
	a.stream = (load("res://core/life/wildlife/boss_themes.gd") as GDScript).call("great_bell")
	a.pitch_scale = 1.0
	a.volume_db = -3.0
	a.bus = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()
