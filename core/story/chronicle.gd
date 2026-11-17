extends Node
const CueBank := preload("res://core/audio/cue_bank.gd")
## The Chronicle: the run told as it happened. Every turning point is written down once, with the night it fell on, in the
## game's own voice: a seal broken, a great one fallen, a bell answered, a country first walked, a level of Remembrance, a
## fall into the dark, a horse bought, the first ride on the Ember Road, a night turned at camp. Kept in Travel.story["chronicle"]
## as [{n: night, k: kind, t: text}] (the newest 240). Read on the Chronicle page of the Count (B, then E), and the title screen's
## slot list quotes the last line of each save, so a returning player is told where they stopped.
## A child of the story director; it listens to Events and polls a few numbers every two seconds (no per-frame work).
## Load by path (no class_name): const Chronicle := preload("res://core/story/chronicle.gd")

const Days := preload("res://core/story/days.gd")
const Tally := preload("res://core/story/tally.gd")
const Danger := preload("res://core/life/encounters/danger.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const LoreDB := preload("res://core/world/realm/lore_db.gd")

const KEEP := 240
const SEALS := {"henge": "The thorn seal broke.", "oss_gallery": "The gallery seal broke.", "summit": "The summit ward answered."}

var _poll := 2.0
var _level := -1
var _bells := -1
var _horses := -1
var _falls := -1
var _night := -1


static func entries() -> Array:
	var c: Variant = Travel.story.get("chronicle", null)
	if not (c is Array):
		c = []
		Travel.story["chronicle"] = c
	return c as Array


## Write a line (once per `key`, so a reloaded night does not repeat itself).
static func write(key: String, kind: String, text: String) -> void:
	var seen: Variant = Travel.story.get("chronicle_keys", null)
	if not (seen is Dictionary):
		seen = {}
		Travel.story["chronicle_keys"] = seen
	if (seen as Dictionary).has(key):
		return
	(seen as Dictionary)[key] = true
	var list := entries()
	list.append({"n": Days.current() + 1, "k": kind, "t": text})
	while list.size() > KEEP:
		list.pop_front()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.current_scene != null and key != "begin":
		CueBank.play(tree.current_scene, "ui_chronicle", -3.0)       # a quill's scratch and one small bell: the night wrote a line
	Travel.save_soon()


func _ready() -> void:
	name = "Chronicle"
	add_to_group(&"chronicle")
	if entries().is_empty():
		write("begin", "start", "You came down the road to Hearthward with a staff and a lantern. The sky was already turning.")
	Events.seal_broken.connect(func(id: String) -> void:
		write("seal:" + id, "seal", String(SEALS.get(id, "A seal broke: %s." % Tally.kind_name(id)))))
	Events.boss_slain.connect(func(id: String) -> void:
		write("boss:" + id, "boss", "%s fell." % Tally.kind_name(id)))
	Events.region_discovered.connect(func(id: String, kind: String) -> void:
		if kind == "region":
			write("region:" + id, "place", "First walked %s." % LoreDB.place_name(id)))
	Events.brazier_kindled.connect(func(_b: Node3D) -> void:
		write("firstfire", "fire", "The first fire kindled at your hand burned."))
	Events.fire_travelled.connect(func(_a: String, _b: String) -> void:
		write("firstroad", "road", "The Ember Road carried you between two fires for the first time."))


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 2.0
	var lv := Danger.player_level()
	if _level >= 0 and lv > _level and lv % 5 == 0:
		write("level:%d" % lv, "level", "Remembrance %d: the Paths grew." % lv)
	_level = lv
	var b := QuestBook.bells()
	if _bells >= 0 and b > _bells:
		write("bell:%d" % b, "bell", "A bell was answered: %d of eight." % b)
	_bells = b
	var owned: Array = Travel.system_state("stable").get("owned", [])
	if _horses >= 0 and owned.size() > _horses:
		write("horse:%d" % owned.size(), "horse", "A horse was bought.")
	_horses = owned.size()
	var falls := int(Tally.data().get("falls", 0))
	if _falls >= 0 and falls > _falls and (falls == 1 or falls % 5 == 0):
		write("fall:%d" % falls, "fall", "The dark took you%s." % (" for the first time" if falls == 1 else " again (%d times)" % falls))
	_falls = falls
	var n := Days.current()
	if _night >= 0 and n > _night:
		write("night:%d" % n, "night", "Night %d began at the fire." % (n + 1))
	_night = n
