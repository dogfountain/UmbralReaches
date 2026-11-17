class_name Courier
extends Node
## Courier runs between the hitching posts. At any post's panel (ui/horse_panel.gd, third page) take a parcel for another
## post: a timed ride with a gold, silver and bronze time worked out from the straight distance, a reward in grave ash and
## ember shards (half if late), and a best-time board per route kept in the profile (core/util/profile.gd, shared by every
## save). One parcel at a time. The clock counts only while the wanderer is free to move; being hollowed loses the parcel; the
## Ember Road is shut while a parcel is carried (fire_road.gd asks `active()`); a reload resumes the run with its elapsed time.
## The destination is a beacon on the compass and the dial, and a small timer shows at the top. Nothing runs per frame but a
## label update once a second, and nothing at all with no parcel. A child of the story director (class Courier).

const Profile := preload("res://core/util/profile.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const Tally := preload("res://core/story/tally.gd")

## id -> [from breed, to breed, name, what is carried]
const ROUTES := {
	"tor": ["palfrey", "garron", "The Tor Parcel", "a tin of lamp-oil, wax-sealed, for Ysolt's fire under the tor"],
	"tor_back": ["garron", "palfrey", "Ysolt's Reply", "a bundle of cut peat-ash, for the Hearthward smith's forge"],
	"pits": ["palfrey", "draught", "The Founder's Ledger", "a ledger of the pits' dead, which the pits want back"],
	"pits_back": ["draught", "palfrey", "Slag for Hild", "a bag of still-warm slag, to be cooled on Hild's anvil"],
	"mere": ["palfrey", "fenpony", "Cadoc's Coins", "nine coins and a note that says only 'not enough'"],
	"mere_back": ["fenpony", "palfrey", "Eel in Salt", "a crock of salted eel for the Keg, which has been promised it for a week"],
	"weir": ["palfrey", "weir_cob", "The Salt Letter", "a letter for the Weirford ferrymen, from a hand that wants it answered"],
	"weir_back": ["weir_cob", "palfrey", "The Marchers' Seal", "a wax seal in a box, pressed from the Order's old die"],
	"ridge": ["garron", "draught", "The Ashen Pledge", "a pledge between the moor and the pits, which neither wants to carry"],
	"long": ["fenpony", "weir_cob", "The Long Way", "a lamp wrapped in a coat, to be set in Weirford's window before it goes out"],
}
const SPEED := 9.0                       ## the pace the par times are worked at (m/s over the straight distance, with a quarter added for roads)
const MAX_S := 1500.0

signal finished(route: String, seconds: float, medal: String)

var _label: Label
var _layer: CanvasLayer
var _tick := 0.0
var _mark: Node3D


static func _st() -> Dictionary:
	var d: Variant = Travel.story.get("courier", null)
	if not (d is Dictionary):
		d = {}
		Travel.story["courier"] = d
	return d as Dictionary


static func active() -> bool:
	return String(_st().get("route", "")) != ""


static func route_name(id: String) -> String:
	return String((ROUTES[id] as Array)[2]) if ROUTES.has(id) else id


## The post node for a breed (group hitching_post, meta "breed"), or null.
static func post_of(tree: SceneTree, breed: String) -> Node3D:
	for n in tree.get_nodes_in_group(&"hitching_post"):
		if String(n.get_meta(&"breed", "")) == breed:
			return n as Node3D
	return null


static func distance(tree: SceneTree, id: String) -> float:
	var r: Array = ROUTES[id]
	var a := post_of(tree, String(r[0]))
	var b := post_of(tree, String(r[1]))
	return a.global_position.distance_to(b.global_position) if a != null and b != null else 0.0


## Gold, silver and bronze limits in seconds.
static func limits(dist: float) -> Array[float]:
	var par := dist * 1.25 / SPEED
	return [par, par * 1.35, par * 1.9]


static func medal_for(dist: float, secs: float) -> String:
	var l := limits(dist)
	if secs <= l[0]:
		return "gold"
	if secs <= l[1]:
		return "silver"
	if secs <= l[2]:
		return "bronze"
	return "late"


static func routes_from(breed: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ROUTES:
		if String((ROUTES[id] as Array)[0]) == breed:
			out.append(id)
	return out


static func fmt(secs: float) -> String:
	return "%d:%02d" % [int(secs) / 60, int(secs) % 60]


func _ready() -> void:
	name = "Courier"
	add_to_group(&"courier")
	Events.hollowed.connect(func() -> void:
		if active():
			_lose("The parcel is lost in the dark."))
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_top = 96.0
	_label.offset_left = -300.0
	_label.offset_right = 300.0
	_layer.add_child(_label)
	_label.visible = false
	set_process(active())
	if active():
		call_deferred("_show_mark")


## Take a parcel at the post of `from` for `id`. "" on success, else why not.
func take(id: String) -> String:
	if active():
		return "You already carry a parcel."
	if not ROUTES.has(id):
		return "No such run."
	if Player.boss_fight_active(get_tree()):
		return "Not in a warden's fight."
	var st := _st()
	st["route"] = id
	st["t"] = 0.0
	set_process(true)
	_show_mark()
	Events.toast.emit("%s taken: %s. Ride." % [route_name(id), String((ROUTES[id] as Array)[3])])
	Travel.save_soon()
	return ""


func abandon() -> void:
	if active():
		_lose("You give the parcel back.")


func _lose(why: String) -> void:
	_st().clear()
	_clear_mark()
	_label.visible = false
	set_process(false)
	Events.toast.emit(why)
	Travel.save_soon()


func _show_mark() -> void:
	_clear_mark()
	if not active():
		return
	var post := post_of(get_tree(), String((ROUTES[String(_st().route)] as Array)[1]))
	if post == null:
		return
	var m := Wayfarer.WayMark.new()
	m.name = "CourierMark"
	get_tree().current_scene.add_child(m)
	m.anchor = post.global_position + Vector3.UP * 3.0
	m.global_position = m.anchor
	m.tint = Color(1.0, 0.8, 0.4)
	m.add_to_group(&"landmark_beacon")
	_mark = m


func _clear_mark() -> void:
	if _mark != null and is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null


func _process(delta: float) -> void:
	if not active():
		set_process(false)
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or get_tree().paused or p.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var st := _st()
	st["t"] = float(st.get("t", 0.0)) + delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	var id := String(st.route)
	var to := post_of(get_tree(), String((ROUTES[id] as Array)[1]))
	if to == null:
		return
	if _mark == null:
		_show_mark()                              # after a reload the posts stand later than this node
	var left := p.global_position.distance_to(to.global_position)
	if left < 7.0:
		_deliver(id)
		return
	if float(st.t) > MAX_S:
		_lose("The parcel is spoilt. You were too long on the road.")
		return
	_label.text = "%s     %s     %d m" % [route_name(id), fmt(float(st.t)), roundi(left)]
	_label.visible = true


func _deliver(id: String) -> void:
	var secs := float(_st().t)
	var dist := distance(get_tree(), id)
	var medal := medal_for(dist, secs)
	var ash := roundi(dist * 0.25)
	var shard := roundi(dist / 70.0)
	match medal:
		"gold":
			ash = roundi(ash * 1.6)
			shard += 3
		"silver":
			ash = roundi(ash * 1.25)
			shard += 1
		"late":
			ash = ash / 2
			shard = 0
	Profile.ensure()
	var old := float(Profile.best.get(id, 0.0))
	var record := old <= 0.0 or secs < old
	if record and medal != "late":
		Profile.best[id] = snappedf(secs, 0.1)
		Profile.save()
	Travel.give("grave_ash", ash, false)
	if shard > 0:
		Travel.give("ember_shard", shard, false)
	var d := Tally.data()
	d["runs"] = int(d.get("runs", 0)) + 1
	_st().clear()
	_clear_mark()
	_label.visible = false
	set_process(false)
	Events.toast.emit("%s delivered in %s (%s)%s. +%d grave ash%s." % [route_name(id), fmt(secs), medal, ", a best" if record and medal != "late" else "", ash, (", +%d ember shard%s" % [shard, "" if shard == 1 else "s"]) if shard > 0 else ""])
	Chronicle.write("courier:" + id, "road", "%s was carried the whole way." % route_name(id))
	Travel.save_soon()
	finished.emit(id, secs, medal)
