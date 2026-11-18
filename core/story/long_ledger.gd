class_name LongLedger
extends Node
## The endgame after the Warden: the Long Ledger. Once the door is shut (the ending seen, or any Deeper Night rung), Hearthward posts
## three bounties each night (a fourth from the first ringing of the cracked bell), drawn from core/story/long_ledger_data.gd and
## seeded by the night's number, so a night's list is the same on every reload. A bounty is progress against what the Count already
## keeps: nothing is hooked, nothing is counted twice; its progress is the counter now less the counter when it was posted. A
## finished bounty pays at once (grave ash and ember shards, more with each Deeper Night and each rank) and earns marks; marks make
## ranks (ten, from Unlisted to The Last Lantern), a rank gained pays shards and writes the Chronicle. "Clean" bounties fail on a
## fall. The list renews when a camp turns the night. Every Deeper Night makes the ledger ask more (x 1 + 0.35 each) and pay more,
## which is the reason to ring the bell again. The Count's fourth page shows it (ui/tally_ledger.gd). Saved in Travel.story["ledger"].
## Cost: a two-second timer that reads a few dictionary entries; with the door still open it returns on the first line. A child of
## the story director (class LongLedger).

const Data := preload("res://core/story/long_ledger_data.gd")
const Tally := preload("res://core/story/tally.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const UiSound := preload("res://ui/ui_sound.gd")
const LedgerVoice := preload("res://core/story/ledger_voice.gd")
const Days := preload("res://core/story/days.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")

signal rank_gained(rank: int)


static func unlocked() -> bool:
	var fl: Variant = Travel.story.get("flags", null)
	if fl is Dictionary and (bool((fl as Dictionary).get("ending_seen", false)) or bool((fl as Dictionary).get("deeper", false))):
		return true
	return Tiers.ng_level() > 0


static func ng() -> int:
	return Tiers.ng_level()


static func st() -> Dictionary:
	var d: Variant = Travel.story.get("ledger", null)
	if not (d is Dictionary):
		d = {}
		Travel.story["ledger"] = d
	var s := d as Dictionary
	if not (s.get("list") is Array):
		s["list"] = []
	if not s.has("marks"):
		s["marks"] = 0
		s["night"] = -1
		s["done"] = 0
	return s


static func marks() -> int:
	return int(st().get("marks", 0))


static func rank() -> int:
	return Data.rank_of(marks())


static func rank_name() -> String:
	return String((Data.RANKS[rank()] as Array)[1])


## What the Count keeps for a counter name.
static func counter(kind: String) -> int:
	var d := Tally.data()
	if kind == "kills" or kind == "clean":
		return int(d.get("total", 0))
	if kind.begins_with("kind:"):
		return int((d.get("kills", {}) as Dictionary).get(kind.substr(5), 0))
	match kind:
		"great":
			return int(d.get("great", 0))
		"camps":
			return int(d.get("camps", 0))
		"places":
			return int(d.get("places", 0))
		"runs":
			return int(d.get("runs", 0))
		"races":
			return int(d.get("races", 0))
		"wins":
			return int(d.get("race_wins", 0))
	return 0


static func progress(b: Dictionary) -> int:
	return maxi(0, counter(String(Data.POOL[String(b.t)][0])) - int(b.base))


static func text_of(b: Dictionary) -> String:
	return String(Data.POOL[String(b.t)][2]).replace("{n}", str(int(b.n)))


## The ground for a bounty's n and purse: the Deeper Nights rung so far.
static func _target(tpl: Array) -> int:
	return maxi(1, roundi(float(tpl[1]) * Data.scale(ng())))


## Pick tonight's list: seeded by the night's number and the ringings, so a reload keeps it. Distinct counters where it can.
func post() -> void:
	var s := st()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ledger_%d_%d" % [Days.current(), ng()])
	var ids: Array = Data.POOL.keys()
	ids.sort()
	var pool: Array = []
	for id: String in ids:
		if int((Data.POOL[id] as Array)[4]) <= ng():
			pool.append(id)
	var list: Array = []
	var used: Array = []
	var want := Data.POSTED + (1 if ng() > 0 else 0)
	var tries := 0
	while list.size() < want and tries < 60 and not pool.is_empty():
		tries += 1
		var id := String(pool[rng.randi() % pool.size()])
		var tpl: Array = Data.POOL[id]
		var key := String(tpl[0])
		if used.has(id) or (used.has(key) and tries < 40):
			continue
		used.append(id)
		used.append(key)
		var hard := int(tpl[3]) == 1
		if list.size() == want - 1 and ng() > 0 and int(tpl[4]) == 0 and tries < 55:
			continue                                          # the last posting of a Deeper Night is a Deeper one
		list.append({"t": id, "n": _target(tpl), "base": counter(key), "fb": int(Tally.data().get("falls", 0)), "s": 0, "hard": hard})
	s["list"] = list
	s["night"] = Days.current()
	Travel.save_soon()
	if not list.is_empty():
		Events.toast.emit("The Long Ledger is posted at the Keg: %d bounties for tonight." % list.size())
		LedgerVoice.posted(self, list.size(), ng())


func _ready() -> void:
	name = "LongLedger"
	add_to_group(&"long_ledger")
	var t := Timer.new()
	t.wait_time = 2.0
	t.timeout.connect(_check)
	t.autostart = true
	add_child(t)
	Events.boss_slain.connect(func(_id: String) -> void:
		var d := Tally.data()
		d["great"] = int(d.get("great", 0)) + 1)


## What a finished bounty pays now: Vector2i(grave ash, ember shards).
static func reward(b: Dictionary) -> Vector2i:
	var hard := int(Data.POOL[String(b.t)][3]) == 1
	var mult := Data.scale(ng()) * (1.0 + 0.05 * float(rank()))
	return Vector2i(roundi((30.0 + (30.0 if hard else 0.0)) * mult), roundi((2.0 + (2.0 if hard else 0.0)) * mult))


func _check() -> void:
	if not unlocked():
		return
	var s := st()
	if int(s.night) != Days.current() or (s.list as Array).is_empty():
		post()
	var falls := int(Tally.data().get("falls", 0))
	for b: Dictionary in (s.list as Array):
		if int(b.s) != 0:
			continue
		if String(Data.POOL[String(b.t)][0]) == "clean" and falls > int(b.fb):
			b["s"] = 2
			Events.toast.emit("The ledger strikes a bounty: you fell.")
			continue
		if progress(b) >= int(b.n):
			_pay(b, s)


func _pay(b: Dictionary, s: Dictionary) -> void:
	b["s"] = 1
	var tpl: Array = Data.POOL[String(b.t)]
	var hard := int(tpl[3]) == 1
	var rw := reward(b)
	var ash := rw.x
	var shard := rw.y
	Travel.give("grave_ash", ash, false)
	Travel.give("ember_shard", shard, false)
	var before := rank()
	s["marks"] = int(s.marks) + (2 if hard else 1)
	s["done"] = int(s.done) + 1
	Events.toast.emit("Ledger: %s  +%d grave ash, +%d ember shards, %d mark%s." % [text_of(b), ash, shard, 2 if hard else 1, "s" if hard else ""])
	LedgerVoice.paid(self, String(tpl[0]), hard)
	var tally := Tally.data()
	tally["ledger"] = int(s.done)
	if rank() > before:
		var r := rank()
		Travel.give("ember_shard", 5 * r, false)
		Events.toast.emit("Rank: %s. %s  +%d ember shards." % [rank_name(), String(Data.RANK_LINES[r]), 5 * r])
		Chronicle.write("ledger_rank:%d" % r, "road", "The Long Ledger named the wanderer %s." % rank_name())
		LedgerVoice.rank(self, r, String(Data.RANK_LINES[r]), ng())
		rank_gained.emit(r)
	Travel.save_soon()
