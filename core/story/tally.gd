extends Node
## The Count: what the night has cost, kept for the player to read (ui/tally_panel.gd, the B key, and at the end of a camp).
## Every hollowed thing put down is counted and given a pilgrim's name, the way the Bearers of the Ossuary count the dead:
## the fire remembers who they were, and the list of the latest names is read from it. Kept in Travel.story["tally"]:
##   kills {kind: n}   total n   falls n (times hollowed)   camps n   places n   night_kills n (since the last camp)
## A child of the story director (it needs no wiring: it listens to Events). The names are made, not stored: the i-th
## name is a pure function of i, so the save holds only the numbers.
## Load by path (no class_name): const Tally := preload("res://core/story/tally.gd")

const FIRST := ["Maud", "Edric", "Wystan", "Isolde", "Hale", "Tamsin", "Corvin", "Ansel", "Briar", "Odo", "Mabel", "Jory", "Sedge", "Orrin",
	"Hesper", "Gwen", "Piers", "Alys", "Burl", "Nan", "Tobin", "Eudo", "Rosamund", "Wat", "Ysolt", "Aldous", "Cobb", "Edda", "Fenn", "Lisle",
	"Marl", "Ostrin", "Penn", "Ruan", "Siany", "Teasel", "Wren", "Abel", "Dorrit", "Hobb", "Gorse", "Vell", "Brannoc", "Cadoc", "Dilly", "Ebba"]
const LAST := ["Tarrow", "Reed", "Vail", "Harrow", "Wick", "Sallow", "Tansy", "Lark", "Wade", "Coyle", "Thorn", "Ashby", "Fallow", "Marsh",
	"Cooper", "Carter", "Fuller", "Mason", "Tolliver", "Bellman", "Ferryman", "Saltwife", "Draper", "Hollis", "Pike", "Warden", "Kettle",
	"Sexton", "Ringer", "Chandler", "Weir", "Cairn", "Fenner", "Hurdle", "Shaw", "Tiller", "Ostler", "Lantern", "Underhill", "Greaves"]
const TITLES := ["", "", "", "", "Brother ", "Sister ", "Old ", "Goodwife ", "Reeve ", "Ringer "]
const MIN_NIGHT_S := 600.0

signal counted(name: String, total: int)


static func data() -> Dictionary:
	var d: Variant = Travel.story.get("tally", null)
	if not (d is Dictionary):
		d = {"kills": {}, "total": 0, "falls": 0, "camps": 0, "places": 0, "night_kills": 0}
		Travel.story["tally"] = d
	return d as Dictionary


static func total() -> int:
	return int(data().get("total", 0))


## The i-th name the fire has counted (1-based, stable).
static func name_of(i: int) -> String:
	var h := absi(hash("count#%d" % i))
	return "%s%s %s" % [TITLES[h % TITLES.size()], FIRST[(h / 7) % FIRST.size()], LAST[(h / 331) % LAST.size()]]


## The latest `n` names, newest first.
static func latest(n: int) -> PackedStringArray:
	var out := PackedStringArray()
	var t := total()
	for i in range(t, maxi(0, t - n), -1):
		out.append(name_of(i))
	return out


## "husk" -> "Husk"; the kinds the script files name.
static func kind_name(kind: String) -> String:
	return kind.replace("_", " ").capitalize()


## Foes by kind, most numerous first: [[kind, n], ...].
static func by_kind() -> Array:
	var kills: Dictionary = data().get("kills", {})
	var rows: Array = []
	for k: String in kills:
		rows.append([k, int(kills[k])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	return rows


func _ready() -> void:
	name = "Tally"
	add_to_group(&"tally")
	Events.enemy_killed.connect(_on_killed)
	Events.hollowed.connect(func() -> void:
		var d := data()
		d["falls"] = int(d.get("falls", 0)) + 1)
	Events.region_discovered.connect(func(_id: String, _kind: String) -> void:
		var d := data()
		d["places"] = int(d.get("places", 0)) + 1)


func _on_killed(e: Node) -> void:
	if e == null:
		return
	var scr: Script = e.get_script()
	var kind := "hollowed"
	if scr != null:
		kind = scr.resource_path.get_file().get_basename()
	var d := data()
	var kills: Dictionary = d.get("kills", {})
	kills[kind] = int(kills.get(kind, 0)) + 1
	d["kills"] = kills
	d["total"] = int(d.get("total", 0)) + 1
	d["night_kills"] = int(d.get("night_kills", 0)) + 1
	counted.emit(name_of(int(d.total)), int(d.total))
