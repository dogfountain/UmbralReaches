extends Node
## A task step that carries a light (story; no class_name): kind "lantern_walk", from the pickup of the step before
## (`from`, a lit lamp taken at A) to `to` within `r`. The quest runner (quest_runner.gd) adds one while the step is
## current and frees it when the step moves on, as it does for a coal (`carry`). The light is a warm flame in the
## wanderer's own lantern (a second light on it). It goes out when the wanderer
##   - sprints (Player.is_sprinting),
##   - rolls or dodges (Player.is_evading, which a parry also counts as),
##   - is hurt (Events.player_hurt) or hollowed (Events.hollowed),
##   - wades in water deeper than WADE (about the knee),
##   - or, with a step `time`, runs out of seconds.
## Out: the task falls back to the step before, where the lamp is lit again (the `carry` pattern: a step back, never
## a failure). One check a frame of a few Player state reads; nothing is searched. Not saved: a lamp carried across
## a reload comes back lit (the step is saved, not the flame).
## Step data: from, to, r, label, text; optional time, lost / relight (the toasts), arrive (the toast at B).

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const QProps := preload("res://core/story/quest_props.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")

const WADE := 0.55             ## water over the feet deeper than this puts the flame out (m)
const GRACE := 0.6             ## a step's grace after the lamp is taken: no blow or roll in the first moments counts

var quest := ""
var step: Dictionary = {}
var _pl: Player
var _lamp: Node3D
var _age := 0.0
var _done := false


func setup(qid: String, stp: Dictionary) -> void:
	quest = qid
	step = stp
	name = "LanternWalk_" + qid


func _ready() -> void:
	add_to_group("lantern_walk")
	Events.player_hurt.connect(func(_a: float, _p: Vector3) -> void: _out("The blow knocked the flame out."))
	Events.hollowed.connect(func() -> void: _out("The flame went out with you."))
	_attach()


func _exit_tree() -> void:
	if is_instance_valid(_lamp):
		_lamp.queue_free()


func _attach() -> void:
	_pl = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if _pl == null or is_instance_valid(_lamp):
		return
	# the flame rides in the wanderer's own lantern (a lamp pinned at the hip was hidden by the body and the
	# staff, and stiff when seen): the lantern burns warmer and brighter while it carries, and goes back when it is lost
	var ll := _pl.find_child("LanternLight", true, false) as OmniLight3D
	if ll != null:
		var glow := OmniLight3D.new()
		glow.name = "CarriedFlame"
		glow.light_color = Color(1.0, 0.6, 0.26)
		glow.light_energy = 1.7
		glow.omni_range = 5.0
		glow.shadow_enabled = false
		ll.get_parent().add_child(glow)
		_lamp = glow
	else:
		_lamp = QProps.make(_pl, "CarriedLamp", "lantern_lit", Transform3D.IDENTITY)
		_lamp.position = Vector3(0.36, 0.95, -0.12)
		_lamp.scale = Vector3.ONE * 0.85


func _process(delta: float) -> void:
	if _done:
		return
	if _pl == null or not is_instance_valid(_pl):
		_attach()
		return
	_age += delta
	var why := _why()
	if why != "":
		_out(why)
		return
	var to: Vector2 = step.to
	if Vector2(_pl.global_position.x - to.x, _pl.global_position.z - to.y).length() < float(step.get("r", 5.0)):
		_done = true
		Book.progress(String(step.get("arrive", "%s: delivered" % String(step.get("label", "Lamp")))), true)
		Book.advance(quest)
		return
	if step.has("time"):
		var d := Book.q(quest)
		var left := float(d.get("left", float(step.time))) - delta
		d["left"] = left
		if left <= 0.0:
			_out(String(step.get("lost", "The lamp burned down.")))


## Why the flame is out now, or "".
func _why() -> String:
	if _age < GRACE:
		return ""
	if _pl.is_sprinting():
		return "A flame cannot take a run. It went out."
	if _pl.is_evading():
		return "You threw yourself clear, and the flame did not come with you."
	if RealmLand.in_water(_pl.global_position.x, _pl.global_position.z) \
			and RealmLand.water_y_at(_pl.global_position.x, _pl.global_position.z) - _pl.global_position.y > WADE:
		return "The water took the flame."
	return ""


## The flame is out: the task goes back a step, to light it again.
func _out(why: String) -> void:
	if _done or _age < GRACE or not Book.active(quest) or String(Chains.step(quest, Book.step(quest)).get("kind", "")) != "lantern_walk":
		return
	_done = true
	Book.progress("%s  %s" % [String(step.get("lost", why)), String(step.get("relight", "Light it again."))], false)
	Book.advance(quest, Book.step(quest) - 1)
