extends Node
## The first hour, taught by being in it. Each lesson waits for the moment it matters and is said once per save, in the
## lesson lane, in the game's own words: the first fire (what a fire does, and the seat beside it), the first Gloom, the
## Ember Road when two fires burn, the hitching post and the walk a horse would save, the Count after the first kills, and the
## Bells when both keepers are down. Nothing here draws a marker or opens a menu: the player is told once what a thing is when
## it is under their hand. Quiet while the opening plays, a foe hunts, a boss fights, or the guide's own lesson is up.
## A child of the story director. Load by path (no class_name).

const Hints := preload("res://ui/hints.gd")
const FireRoad := preload("res://core/world/fire_road.gd")
const Tally := preload("res://core/story/tally.gd")

var _t := 4.0
var _gloom_seen := false


func _ready() -> void:
	name = "FirstHour"
	Events.brazier_kindled.connect(func(_b: Node3D) -> void:
		_say("fire", "A kindled fire is the night's one safe place: its light lifts the Gloom, closes your wounds and remembers you. {interact} at the seat beside it to make camp."))
	Events.region_discovered.connect(func(_id: String, kind: String) -> void:
		if kind == "region" and Tally.total() >= 3:
			_say("photo", "A place worth keeping. {photo} Photo mode: the night holds still and the lens is yours."))
	Events.gloom_changed.connect(func(v: float, m: float) -> void:
		if m > 0.0 and v / m >= 0.3 and not _gloom_seen:
			_gloom_seen = true
			_say("gloom", "Gloom gathers wherever there is no light. A fire, a lamp's town or a ward lets it go; at the top of the bar the dark takes you."))


func _say(id: String, text: String) -> void:
	Hints.once(StringName("tip_h_" + id), text, false)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.5
	var scene := get_tree().current_scene
	if scene == null or scene.get_node_or_null("OpeningCam") != null or scene.get_node_or_null("CampCam") != null:
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or p.process_mode == Node.PROCESS_MODE_DISABLED or get_tree().paused:
		return
	if FireRoad.blocked_reason(get_tree()) != "":
		return
	var lit := 0
	var near_lit := false
	for n in get_tree().get_nodes_in_group(Groups.BRAZIER):
		var b := n as Brazier
		if b != null and b.lit:
			lit += 1
			if b.global_position.distance_to(p.global_position) < 7.0:
				near_lit = true
	if lit >= 2 and near_lit:
		_say("road", "Two fires burn now. The iron post beside each is a road: use it, or open {world_map} beside a lit fire and click another.")
	var owned: Array = Travel.system_state("stable").get("owned", [])
	for h in get_tree().get_nodes_in_group(&"hitching_post"):
		if (h as Node3D).global_position.distance_to(p.global_position) < 10.0:
			_say("post", "A hitching post. Horses are sold here for grave ash. A horse gallops half as fast again as you sprint, and {mount} calls yours wherever you stand.")
			break
	if owned.is_empty() and Travel.count("grave_ash") >= 40 and p.global_position.distance_to(Vector3(0.0, 0.0, 33.0)) > 160.0:
		_say("far", "A long way from home. A horse would carry this road for you: the stables of Hearthward, the moor, the pits and the mere sell them.")
	if Tally.total() >= 6:
		_say("count", "{tally} The Count: every hollowed thing you put down is given a name and kept. Read it when you rest.")
	if Travel.bosses_slain.has("thornwarden") and Travel.bosses_slain.has("bone_abbot"):
		_say("bells", "The summit door hears a peal, not a crown. Eight bells hang in the far countries; answer four. Ring one where it hangs, or carry its tongue home. The objective counts them.")
