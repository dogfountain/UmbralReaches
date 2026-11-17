extends Node
## Falling, and what the dark keeps. Three things round the existing ash mound (core/player/player_vitals.gd: the ash carried
## since the last fire is left where you fell; a second fall first and it is gone):
##   The embers' trace: the heap is a beacon on the compass and the dial, and a pin on the world map ("Your embers"), so it can
##   be walked back to. Followed here from the mound's own saved record (system "ash_mound"), checked every two seconds.
##   The return: the fire takes you back with a few quiet seconds: black bars, one line out of forty chosen by how often you have
##   fallen and how deep the ground was, and then the fire's toll.
##   The toll: the first two falls are free ("the fire asks nothing of the new"); after that the fire keeps a twelfth of what
##   you carry (at least 2, at most 40 grave ash), written in the Count (`tolls`, `embers_lost`) and the Chronicle. Ash in the
##   saddlebags is not touched.
## A child of the story director. Costs nothing per frame (a two-second poll and signals). Load by path (no class_name).

const Tally := preload("res://core/story/tally.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const Danger := preload("res://core/life/encounters/danger.gd")

const FIRST := [
	"The fire has your name before you have it back. The cold lets go slowly.",
	"You come up out of the dark the way a coal comes up out of ash: late, and warm on the wrong side.",
	"Hands you do not see have laid you by the fire. Nobody says whose.",
]
const NEW := "The fire asks nothing of the new."
const LATER := [
	"The dark let you go again. It keeps a count, too.",
	"The fire knows your weight by now.",
	"You wake with the staff already in your hand. That is the worst of it.",
	"Somewhere out there your embers lie in the cold. Somewhere is a long way.",
	"The ash on your sleeve is not yours. It will be.",
	"Back again. The fire does not say it, but it is glad of the company.",
	"The Count has you by your own name now.",
	"Gloom is only a long evening, the keep said. This one was longer.",
]
const DEEP := [
	"You fell in country that was not made for the living. The fire takes you back anyway.",
	"A long way down, and the fire a long way up. You come the whole of it in a breath.",
	"The deep ground keeps what it is given. You were not given.",
]
const TOLL := "The fire takes its tithe: %d grave ash. It does not ask twice."
const EMPTY := "The fire asks nothing of an empty hand."

var _poll := 2.0
var _mark: Node3D
var _last_at := Vector3.INF
var _last_amount := 0
var _layer: CanvasLayer
var _top: ColorRect
var _bot: ColorRect


func _ready() -> void:
	name = "EmberTrace"
	add_to_group(&"ember_trace")
	_layer = CanvasLayer.new()
	_layer.layer = 61
	_layer.visible = false
	add_child(_layer)
	_top = ColorRect.new()
	_bot = ColorRect.new()
	for r: ColorRect in [_top, _bot]:
		r.color = Color(0, 0, 0, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if r == _top else Control.PRESET_BOTTOM_WIDE)
		_layer.add_child(r)
	Events.hollowed.connect(_on_hollowed)
	Events.respawned.connect(func(_at: Vector3) -> void: _return.call_deferred())


## The mound's saved place, or Vector3.INF.
static func mound_at() -> Vector3:
	var rec := Travel.system_state("ash_mound")
	var at: Variant = rec.get("at", null)
	return at as Vector3 if at is Vector3 and int(rec.get("amount", 0)) > 0 else Vector3.INF


## The world map's pin for the embers (kind "beacon"), or [].
static func map_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := mound_at()
	if at != Vector3.INF:
		out.append({"at": Vector2(at.x, at.z), "kind": "beacon", "name": "Your embers", "note": "%d grave ash, where you fell. The next fall takes it." % int(Travel.system_state("ash_mound").get("amount", 0))})
	return out


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 2.0
	var at := mound_at()
	if at == _last_at:
		return
	_last_at = at
	_last_amount = int(Travel.system_state("ash_mound").get("amount", 0))
	if is_instance_valid(_mark):
		_mark.queue_free()
	_mark = null
	if at != Vector3.INF:
		var m := Wayfarer.WayMark.new()
		m.name = "EmberMark"
		get_tree().current_scene.add_child(m)
		m.anchor = at + Vector3.UP * 2.5
		m.global_position = m.anchor
		m.tint = Color(1.0, 0.45, 0.2)
		m.add_to_group(&"landmark_beacon")
		_mark = m


## Hollowed while embers lay elsewhere: the old heap is gone (the vitals code replaced the record).
func _on_hollowed() -> void:
	if _last_at != Vector3.INF and _last_amount > 0:
		var now := mound_at()
		if now == Vector3.INF or now.distance_to(_last_at) > 1.0:
			var d := Tally.data()
			d["embers_lost"] = int(d.get("embers_lost", 0)) + _last_amount
			Events.toast.emit("The embers you left are gone.")
	_poll = 0.0                                   # re-read the record at once


func _return() -> void:
	var falls := int(Tally.data().get("falls", 0))
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var deep := p != null and Danger.band(p.global_position) >= 4
	var line := ""
	if falls <= 1:
		line = FIRST[absi(hash(str(Travel.story.get("night_no", 0)))) % FIRST.size()]
	elif deep and falls % 2 == 0:
		line = DEEP[falls % DEEP.size()]
	else:
		line = LATER[falls % LATER.size()]
	_bars(true)
	var story := get_tree().get_first_node_in_group("story")
	var ui: Variant = story.get("ui") if story != null else null
	if ui is CanvasLayer and is_instance_valid(ui):
		(ui as CanvasLayer).narrate([line])
	await get_tree().create_timer(3.2).timeout
	if not is_inside_tree():
		return
	_toll(falls)
	_bars(false)


func _toll(falls: int) -> void:
	if falls <= 2:
		Events.toast.emit(NEW)
		return
	if Vows.has("waiver"):
		Events.toast.emit("The fire asks no toll of you. Your step is light.")
		return
	var have := Travel.count("grave_ash")
	var n := clampi(have / 12, 2, 40)
	if have < n:
		Events.toast.emit(EMPTY)
		return
	Travel.items["grave_ash"] = have - n
	var d := Tally.data()
	d["tolls"] = int(d.get("tolls", 0)) + n
	Events.toast.emit(TOLL % n)
	Chronicle.write("toll:%d" % falls, "fall", "The fire took a tithe of %d grave ash on the way back." % n)
	Travel.save_soon()


func _bars(on: bool) -> void:
	_layer.visible = true
	var h := get_viewport().get_visible_rect().size.y * 0.11
	_top.offset_bottom = h if on else 0.0
	_bot.offset_top = -h if on else 0.0
	if not on:
		_layer.visible = false
