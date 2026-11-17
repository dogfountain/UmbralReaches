class_name Vows
extends Node
## Vows: at level 5, 10, 15, 20, 25 and 30 the wanderer swears one of three vows. Each changes how the night is played;
## none is a flat number. Eighteen in all, three to a tier, drawn from the Hearth (fire and rest), the Road (travel, horse, courier)
## and the Rift (the dark and the dead). A vow is chosen once, at the panel (ui/vow_panel.gd), which opens by itself when the
## wanderer is safe after a tier is reached (and again every two minutes until a choice is made); the choice is saved
## (Travel.story["vows"] = {"5": id, ...}) and the Count lists them. The Paths' point-per-level tree is unchanged.
## Effects are signals and a 2 Hz tick that does nothing unless a vow needs it. Other systems ask `Vows.has(id)`.
## A child of the story director (class Vows).

const Danger := preload("res://core/life/encounters/danger.gd")
const Tally := preload("res://core/story/tally.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const Hearth := preload("res://core/life/progression/hearth.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const FireRoad := preload("res://core/world/fire_road.gd")

const TIERS := [5, 10, 15, 20, 25, 30]
## id -> [tier index, path, name, text]
const DEFS := {
	"tithe": [0, "Hearth", "Tithe of Embers", "Every foe that falls within 28 m of a lit fire leaves a grave ash more. Fight where you can see your fire."],
	"roads": [0, "Road", "Pilgrim's Appetite", "Every country you walk for the first time gives you 12 memory. The map is a thing to fill."],
	"banked": [0, "Rift", "Banked Fire", "For 90 seconds after you kindle or rest at a fire, the Gloom gathers a third slower. Go out while it burns."],
	"lore": [1, "Hearth", "Fireside Lore", "A camp also gives you Rested. Sit more often."],
	"horse": [1, "Road", "Horse-Lord", "Your horse tires a third as fast and learns you half again as fast."],
	"coin": [1, "Rift", "The Bearers' Coin", "Every twelfth foe you put down leaves an ember shard, paid by the Bearers who count them."],
	"waiver": [2, "Hearth", "Light Step", "The fire asks no toll when it takes you back."],
	"luck": [2, "Road", "Courier's Luck", "Parcels pay forty percent more, and the gold time is kinder by a seventh."],
	"hand": [2, "Rift", "Scavenger's Hand", "What you gather, you gather one more of."],
	"lantern": [3, "Hearth", "Lantern-Bearer", "While you ride or carry a parcel, the Gloom gathers two fifths slower."],
	"emberroad": [3, "Road", "Kin of the Ember Road", "The Ember Road sets you down clean: Gloom gone, Wounds mended."],
	"unburdened": [3, "Rift", "The Unburdened Dead", "Every twenty-fifth foe you put down mends all your Wounds."],
	"spoils": [4, "Hearth", "Keeper's Spoils", "For three minutes after a great one falls, every kill gives twice the memory."],
	"cartographer": [4, "Road", "Cartographer's Eye", "A country walked for the first time also gives you ten grave ash."],
	"hardened": [4, "Rift", "Night-Hardened", "In Perilous and Deadly country the Gloom gathers a third slower."],
	"count": [5, "Hearth", "The Count's Lantern", "Every foe you put down mends a Wound. The fire remembers them, and gives something back."],
	"longnight": [5, "Road", "The Long Night's End", "A camp turns the night after five minutes of play, not ten: the dailies open sooner."],
	"keeper": [5, "Rift", "Keeper of the Door", "Every bell you answer clears the dark from you and gives sixty memory. The door remembers who rang."],
}

var _poll := 2.0
var _slow_until := 0.0
var _spoils_until := 0.0
var _offer_cd := 20.0
var _hearth: Hearth
var _bells := -1
var _gather := false


static func _st() -> Dictionary:
	var d: Variant = Travel.story.get("vows", null)
	if not (d is Dictionary):
		d = {}
		Travel.story["vows"] = d
	return d as Dictionary


static func chosen() -> Array[String]:
	var out: Array[String] = []
	for t: Variant in _st().values():
		out.append(String(t))
	return out


static func has(id: String) -> bool:
	return _st().values().has(id)


static func tier_for(level: int) -> int:
	var n := 0
	for i in TIERS.size():
		if level >= int(TIERS[i]):
			n = i + 1
	return n


## The tier index (0..5) a vow is waiting for, or -1.
static func pending() -> int:
	var reached := tier_for(Danger.player_level())
	for i in reached:
		if not _st().has(str(TIERS[i])):
			return i
	return -1


static func options(tier: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS:
		if int((DEFS[id] as Array)[0]) == tier:
			out.append(id)
	return out


static func choose(tier: int, id: String) -> void:
	if tier < 0 or tier >= TIERS.size() or not DEFS.has(id) or int((DEFS[id] as Array)[0]) != tier or _st().has(str(TIERS[tier])):
		return
	_st()[str(TIERS[tier])] = id
	Events.toast.emit("A vow is sworn: %s." % String((DEFS[id] as Array)[2]))
	Chronicle.write("vow:" + id, "level", "Sworn at level %d: %s." % [int(TIERS[tier]), String((DEFS[id] as Array)[2])])
	Travel.save_soon()


func _ready() -> void:
	name = "Vows"
	add_to_group(&"vows")
	Events.enemy_killed.connect(_on_kill)
	Events.region_discovered.connect(func(_id: String, kind: String) -> void:
		if kind != "region":
			return
		if has("roads"):
			_memory(12, "discover")
		if has("cartographer"):
			Travel.give("grave_ash", 10, false))
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: banked())
	Events.fire_travelled.connect(func(_a: String, _b: String) -> void:
		if has("emberroad"):
			_clean.call_deferred())
	Events.item_gained.connect(func(id: String, amount: int, _t: int) -> void:
		if has("hand") and not _gather and amount == 1 and id in ["ash_bloom", "grave_iron"]:
			_gather = true
			Travel.give(id, 1, false)
			_gather = false)
	Events.boss_slain.connect(func(_id: String) -> void:
		_spoils_until = Time.get_ticks_msec() / 1000.0 + 180.0)


## Called by the camp rite and by a lit fire.
func banked() -> void:
	if has("banked"):
		_slow_until = Time.get_ticks_msec() / 1000.0 + 90.0


func on_camp() -> void:
	banked()
	if has("lore"):
		var h := _find_hearth()
		if h != null:
			h.rest_here()


func _find_hearth() -> Hearth:
	if _hearth == null or not is_instance_valid(_hearth):
		_hearth = get_tree().get_first_node_in_group("hearth") as Hearth
	return _hearth


func _memory(n: int, why: String) -> void:
	var h := _find_hearth()
	if h != null:
		h.give_memory(n, why)


func _clean() -> void:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p != null:
		p.add_gloom(-p.gloom_max)
		p.mend(p.wounds_max)


func _on_kill(e: Node) -> void:
	var tree := get_tree()
	var n3 := e as Node3D
	var total := Tally.total()
	if has("tithe") and n3 != null:
		for b in tree.get_nodes_in_group(Groups.BRAZIER):
			var br := b as Brazier
			if br != null and br.lit and br.global_position.distance_to(n3.global_position) < 28.0:
				Travel.give("grave_ash", 1, false)
				break
	if has("coin") and total > 0 and total % 12 == 0:
		Travel.give("ember_shard", 1, false)
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Player
	if p != null:
		if has("unburdened") and total > 0 and total % 25 == 0:
			p.mend(p.wounds_max)
		if has("count"):
			p.mend(1.0)
	if has("spoils") and Time.get_ticks_msec() / 1000.0 < _spoils_until:
		_memory(3, "kill")


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	var tree := get_tree()
	var p := tree.get_first_node_in_group(Groups.PLAYER) as Player
	if p != null and p.gloom > 0.0 and not tree.paused:
		var rate := 0.0
		if Time.get_ticks_msec() / 1000.0 < _slow_until:
			rate += 0.25
		if has("lantern") and (p.riding != null or Courier.active()):
			rate += 0.3
		if has("hardened") and Danger.band(p.global_position) >= 3:
			rate += 0.25
		if rate > 0.0:
			p.add_gloom(-rate * 0.5)
	var b := QuestBook.bells()
	if _bells >= 0 and b > _bells and has("keeper"):
		_memory(60 * (b - _bells), "quest")
		_clean()
	_bells = b
	_offer_cd -= 0.5
	if _offer_cd <= 0.0 and pending() >= 0 and p != null and not tree.paused and FireRoad.blocked_reason(tree) == "" and not CampRite.running(tree):
		_offer_cd = 120.0
		var panel := tree.get_first_node_in_group(&"vow_panel") as VowPanel
		if panel != null:
			panel.open_for(pending())
