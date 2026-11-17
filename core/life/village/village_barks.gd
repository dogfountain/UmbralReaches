extends Node
## Barks and small scenes: the valley's people comment, unprompted, on what the wanderer has done and how the wanderer looks, and a few
## pairs talk to each other when they are in earshot (village_bark_db.gd has the lines). Everything is evaluated on a two-second tick, never
## per frame, only over the villagers within 14 m of the wanderer, and only while nothing else is being said (no conversation, no subtitle
## up, no pause); one bark every ~18 s at most, a bark's own ten-minute memory, a scene once a night. A line is shown as a subtitle
## ("Name: ...") with a few syllables of the speaker's babble voice (the kept voices). Added by the story director. No class_name.

const BarkDB := preload("res://core/life/village/village_bark_db.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Reg := preload("res://core/world/night_life/night_registry.gd")
const Soundstage := preload("res://core/audio/soundstage.gd")
const DialogueUI := preload("res://ui/dialogue.gd")

const NEAR := 14.0
const GAP_MS := 18000
const MEMORY_MS := 600000

var _t := 8.0
var _last := 0
var _heard := {}                ## bark key -> msec
var _scenes := {}               ## scene index -> true (this night)
var _wounds := 0.0              ## wounds / max, from the HUD's signal
var _gloom := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Events.wounds_changed.connect(func(v: float, m: float) -> void: _wounds = v / maxf(m, 0.001))
	Events.gloom_changed.connect(func(v: float, m: float) -> void: _gloom = v / maxf(m, 0.001))


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 2.0
	_tick()


func _ui() -> DialogueUI:
	var story := get_parent()
	return story.get("ui") as DialogueUI if story != null else null


func _quiet(ui: DialogueUI) -> bool:
	return ui != null and is_instance_valid(ui) and not ui.is_open() and not ui.narrating()


func _tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last < GAP_MS or get_tree().paused:
		return
	if not _quiet(_ui()):
		return
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if pl == null:
		return
	var near: Dictionary = {}                  # id -> villager node
	for v: Node in get_tree().get_nodes_in_group("villager"):
		var n := v as Node3D
		if n == null or not n.is_inside_tree() or not n.is_visible_in_tree() or not ("display_name" in n):
			continue
		if n.global_position.distance_to(pl.global_position) <= NEAR and n.get("attend") == null:
			near[String(n.get("id"))] = n
	if near.is_empty():
		return
	var ws := VState.world(get_tree())
	# a scene first: two of them close to each other, once a night
	for i in BarkDB.SCENES.size():
		var sc: Dictionary = BarkDB.SCENES[i]
		if _scenes.has(i) or not near.has(String(sc.a)) or not near.has(String(sc.b)):
			continue
		if (near[String(sc.a)] as Node3D).global_position.distance_to((near[String(sc.b)] as Node3D).global_position) > 9.0:
			continue
		if String(sc["if"]) != "" and not VState.test(String(sc["if"]), ws, get_tree()):
			continue
		_scenes[i] = true
		_last = now
		var delay := 0.0
		for ln: Array in sc.lines:
			var who: Node3D = near.get(String(ln[0]), near[String(sc.a)])
			get_tree().create_timer(delay, false).timeout.connect(_say.bind(who, String(ln[1])))
			delay += 3.4 + float(String(ln[1]).length()) * 0.04
		return
	# else one bark: every line that holds for someone near, one chosen at random
	var pool: Array = []
	for i in BarkDB.BARKS.size():
		var b: Dictionary = BarkDB.BARKS[i]
		var who := String(b.who)
		if who != "*" and not near.has(who):
			continue
		if now - int(_heard.get(i, -MEMORY_MS)) < MEMORY_MS:
			continue
		if b.has("when") and not _when(String(b.when)):
			continue
		if b.has("if") and not VState.test(String(b["if"]), ws, get_tree()):
			continue
		pool.append(i)
	if pool.is_empty():
		return
	var pick: int = pool[randi() % pool.size()]
	var bk: Dictionary = BarkDB.BARKS[pick]
	var speaker: Node3D
	if String(bk.who) == "*":
		var ids := near.keys()
		speaker = near[ids[randi() % ids.size()]]
	else:
		speaker = near[String(bk.who)]
	_heard[pick] = now
	_last = now
	_say(speaker, String(bk.say))


## The reads the barker tracks itself.
func _when(tok: String) -> bool:
	var c := Reg.clock
	match tok:
		"@eclipse":
			return Soundstage.eclipse_amount(c) > 0.3
		"@dawn":
			return c > 0.9
		"@late":
			return c > 0.6 and c < 0.88
		"@wounded":
			return _wounds > 0.6
		"@gloom":
			return _gloom > 0.7
		"@horse":
			return not _horse_name().is_empty()
	return false


func _horse_name() -> String:
	var st := Travel.system_state("stable")
	var names: Variant = st.get("names", {})
	if names is Dictionary and not (names as Dictionary).is_empty():
		return String((names as Dictionary).values()[0])
	return ""


func _say(n: Node3D, line: String) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var ui := _ui()
	if ui == null or not is_instance_valid(ui):
		return
	var text := line.replace("{horse}", _horse_name())
	ui.narrate(["%s: \"%s\"" % [String(n.get("display_name")), text]])
	var voice := n.get_node_or_null("Voice")
	if voice == null:
		voice = Voice.speaker3d(n, 18.0)
	Voice.say(voice, Voice.for_node(n), 3 + text.length() / 24, 0.6)
