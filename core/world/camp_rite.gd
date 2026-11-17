class_name CampRite
extends Node
## Making camp: the rite at a lit fire. The wanderer sits down and the world goes quiet for about eleven seconds: the lens
## circles the fire from low down under black bars, the HUD steps back, and three lines are said (what the fire does, what
## the Count stands at, and what the night's road asks next). At the end the wanderer is whole (Gloom gone, Wounds mended),
## the fire remembers her (checkpoint), the Count is read, the game is saved, and if enough of the night has gone (days.gd) the
## night turns: the dailies are open again.
##   Any blow, or a foe waking near, breaks the camp off (no rest granted). The interact key after the first second finishes
##   it at once with the rest granted. Never in a boss's fight, on a horse, with a foe awake close, or on the Ember Road.
## Like the opening shot it uses its own Camera3D (no mesh, material or light is made: nothing to compile). Load by path.

const FireRoad := preload("res://core/world/fire_road.gd")
const Days := preload("res://core/story/days.gd")
const Tally := preload("res://core/story/tally.gd")
const TallyPanel := preload("res://ui/tally_panel.gd")
const StoryScript := preload("res://core/story/story.gd")

const LEN := 11.0
const SKIP_AFTER := 1.0
const BARS := 0.1
const OPENERS := [
	"You set the staff down and give the fire your hands. The dark keeps to the edge of the light, where it belongs.",
	"The fire takes the cold out of your fingers first, then the rest. Nothing out there comes closer than the glow.",
	"You sit. Someone, once, laid these stones so a stranger could do this. You do it for them.",
	"The coals tick. The sky turns on, far above the smoke, and for a while it is not your business.",
]

signal ended(rested: bool)

var _fire: Brazier
var _player: Player
var _cam: Camera3D
var _pcam: Camera3D
var _hud: CanvasLayer
var _layer: CanvasLayer
var _top: ColorRect
var _bot: ColorRect
var _glow: ColorRect
var _t := 0.0
var _poll := 0.0
var _beat := 0
var _on := false
var _was_night := 0
var _new_night := false


static func running(tree: SceneTree) -> bool:
	var scene := tree.current_scene
	var r := scene.get_node_or_null("CampRite") as CampRite if scene else null
	return r != null and r._on


static func begin(b: Brazier, p: Player) -> void:
	if b == null or p == null:
		return
	var tree := b.get_tree()
	var host := tree.current_scene
	var r := host.get_node_or_null("CampRite") as CampRite
	if r == null:
		r = CampRite.new()
		r.name = "CampRite"
		host.add_child(r)
	r.start(b, p)


func start(b: Brazier, p: Player) -> void:
	if _on:
		return
	var why := ""
	if p.riding != null:
		why = "Get down from the horse to sit by the fire."
	else:
		why = FireRoad.blocked_reason(get_tree())
		if why.begins_with("You are already"):
			why = "You cannot sit down now."
		elif why.begins_with("Something hunts"):
			why = "Something hunts you. You cannot make camp with it near."
		elif why.begins_with("The fires"):
			why = "You cannot make camp in a warden's fight."
	if why != "":
		Events.toast.emit(why)
		return
	_pcam = p.get_node_or_null("CameraRig/Pitch/SpringArm/Camera") as Camera3D
	if _pcam == null:
		return
	_fire = b
	_player = p
	_on = true
	_t = 0.0
	_beat = 0
	_was_night = Days.current()
	_new_night = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = Camera3D.new()
	_cam.name = "CampCam"
	_cam.fov = Settings.fov * 0.92
	_cam.far = _pcam.far
	_cam.attributes = _pcam.attributes
	_cam.environment = _pcam.environment
	get_tree().current_scene.add_child(_cam)
	_cam.global_transform = _pcam.global_transform
	_cam.current = true
	_hud = get_tree().get_first_node_in_group(&"hud") as CanvasLayer
	if _hud != null:
		_hud.visible = false
	Events.player_hurt.connect(_on_hurt)
	_bars()
	set_process(true)
	set_process_unhandled_input(true)


func _bars() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 66
	add_child(_layer)
	_glow = ColorRect.new()
	_glow.color = Color(0.1, 0.035, 0.0, 0.0)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_glow)
	_top = ColorRect.new()
	_bot = ColorRect.new()
	for r: ColorRect in [_top, _bot]:
		r.color = Color(0, 0, 0, 1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if r == _top else Control.PRESET_BOTTOM_WIDE)
		_layer.add_child(r)
	_size(0.0)


func _size(k: float) -> void:
	var h := get_viewport().get_visible_rect().size.y * BARS * k
	_top.offset_bottom = h
	_bot.offset_top = -h


func _process(delta: float) -> void:
	if not _on:
		return
	if not is_instance_valid(_fire) or not is_instance_valid(_player) or not _fire.lit:
		_end(false, "The fire has gone out.")
		return
	_t += delta
	var k := smoothstep(0.0, 1.2, _t) * (1.0 - smoothstep(LEN - 1.2, LEN, _t))
	_size(k)
	_glow.color.a = 0.28 * k
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.4
		var why := FireRoad.blocked_reason(get_tree())
		if why.begins_with("Something hunts"):
			_end(false, "Something stirs. The camp breaks.")
			return
	_lines()
	_pose()
	if _t >= LEN:
		_end(true, "")


func _unhandled_input(event: InputEvent) -> void:
	if _on and _t > SKIP_AFTER and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_end(true, "")


func _on_hurt(_amount: float, _from: Vector3) -> void:
	if _on:
		_end(false, "A blow breaks the camp.")


## The three lines, at their moments.
func _lines() -> void:
	var story := get_tree().get_first_node_in_group("story") as StoryScript
	var ui: CanvasLayer = story.ui if story else null
	if ui == null or not is_instance_valid(ui):
		return
	if _beat == 0 and _t >= 1.2:
		_beat = 1
		ui.narrate([OPENERS[absi(hash(str(Tally.total()) + str(_fire.name))) % OPENERS.size()]])
	elif _beat == 1 and _t >= 4.8:
		_beat = 2
		var d := Tally.data()
		var nk := int(d.get("night_kills", 0))
		var total := Tally.total()
		var line := "The Count stands at %d. The Bearers will want the names." % total if total > 0 else "Nothing is counted yet. The Bearers can wait."
		if nk > 0:
			line = "%d put down since the last fire: %s, and %d more behind them. %s" % [nk, Tally.latest(1)[0], maxi(0, nk - 1), line]
		ui.narrate([line])
	elif _beat == 2 and _t >= 8.3:
		_beat = 3
		_new_night = Days.due()
		var next := "Tomorrow the road is where it was."
		var objs: Array = story.objectives()
		if not objs.is_empty():
			next = "Then the road: %s." % String((objs[0] as Dictionary).get("text", "")).rstrip(".")
		ui.narrate([("The night turns. " if _new_night else "") + next])


## The lens circles the fire low, drifting a little inward and up, and looks at the flame's heart.
func _pose() -> void:
	var c := _fire.global_position
	var k := _t / LEN
	var a0 := atan2(_pcam.global_position.x - c.x, _pcam.global_position.z - c.z)
	var ang := a0 + lerpf(0.0, 1.25, smoothstep(0.0, 1.0, k))
	var r := lerpf(4.4, 3.3, k)
	var h := lerpf(1.7, 1.15, k)
	var from := c + Vector3(sin(ang) * r, h, cos(ang) * r)
	var q := PhysicsRayQueryParameters3D.create(c + Vector3.UP * 1.2, from, Layers.WORLD)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		from = hp + (c + Vector3.UP * 1.2 - hp).normalized() * 0.4
	_cam.global_position = from
	_cam.look_at(c + Vector3.UP * lerpf(1.1, 1.6, k), Vector3.UP)


func _end(rested: bool, why: String) -> void:
	if not _on:
		return
	_on = false
	if Events.player_hurt.is_connected(_on_hurt):
		Events.player_hurt.disconnect(_on_hurt)
	if is_instance_valid(_pcam):
		_pcam.current = true
	if is_instance_valid(_cam):
		_cam.queue_free()
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	if _layer != null:
		_layer.queue_free()
		_layer = null
	if is_instance_valid(_player):
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		_player.reset_physics_interpolation()
		if rested:
			_rest()
	if why != "":
		Events.toast.emit(why)
	set_process(false)
	set_process_unhandled_input(false)
	ended.emit(rested)


## The camp's gifts: whole again, remembered by the fire, the night turned if it is time, the Count read, a save.
func _rest() -> void:
	_player.add_gloom(-_player.gloom_max)
	_player.mend(_player.wounds_max)
	_fire.remember(_player)
	var d := Tally.data()
	d["camps"] = int(d.get("camps", 0)) + 1
	d["night_kills"] = 0
	var vows := get_tree().get_first_node_in_group(&"vows") as Vows
	if vows != null:
		vows.on_camp()
	var turned := Days.advance()
	if turned:
		Events.toast.emit("Night %d. The ledger's daily work is open again." % (Days.current() + 1))
	Events.toast.emit("Rested. Press [%s] to read the Count." % InputSetup.live_label("interact", false, "E"))
	TallyPanel.arm_after_camp(get_tree())
	Travel.save_soon()
