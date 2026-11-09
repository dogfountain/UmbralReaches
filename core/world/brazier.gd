class_name Brazier
extends Interactable
## A kindle-able light: checkpoint, Gloom cleanse, and the warm accent that marks gameplay.

@export var start_lit := false
@export var light_radius := 11.0
@export var lit_energy := 8.5        ## warm pool on dark ground; 20 washed yards orange
@export var lit_range := 11.5

var lit := false
var _spawn_at := Vector3(INF, 0.0, 0.0)           ## spawn_point(), found once for the 'already resting here' test
var _t := 0.0
var _energy := 0.0

@onready var _light: OmniLight3D = $Light
@onready var _flame: GPUParticles3D = $Flame
@onready var _coals: MeshInstance3D = $Coals
var _coal_mat: StandardMaterial3D
var _crackle: AudioStreamPlayer3D


## r33 world: the fires' names (the Ember Road's menu, the map). Any other fire is named for its place.
const FIRE_NAMES := {"Sanctuary": "Hearthward's fire", "StairFoot": "The Stair-foot fire", "Shrine": "The glade's fire",
	"Landing": "The Barrow Field fire", "Threshold": "The fen fire", "HengeFire": "The henge-stair fire", "SummitFire": "The summit fire",
	"OssuaryGate": "The Ossuary's gate fire"}
const FIRE_LIGHT := Color(1.0, 0.52, 0.18)         ## a kindled fire throws a deep orange (about 1900 K) on the dark ground
const MAP_LIT := Color(1.0, 0.62, 0.3)
const MAP_COLD := Color(0.5, 0.48, 0.52)
## Emissive caps: lit coals peak at 1.6 (were 4.0), so they stay gold-orange under AgX, not a white blob
const COAL_GLOW := 0.85


func _ready() -> void:
	DressedProps.dress_brazier(self)
	add_to_group(Groups.INTERACTABLE)
	add_to_group(Groups.BRAZIER)
	# r33 world: every fire is a stop on the Ember Road (fire_road.gd): a map marker, and an ember-post
	# beside it to travel from once it is lit
	add_to_group(&"map_marker")
	set_meta(&"map_kind", "travel")
	set_meta(&"map_label", display_name())
	var dup := get_node_or_null("EmberPost")
	if dup != null and dup.get("brazier") != self:
		dup.name = "EmberPostCopy"               # Area.make_brazier duplicates a dressed fire: a fresh post
		dup.queue_free()
	if get_node_or_null("EmberPost") == null:
		var post: Node3D = (load("res://core/world/ember_post.gd") as GDScript).new()
		post.name = "EmberPost"
		post.set("brazier", self)
		add_child(post)
	_t = randf() * 10.0
	# Each shadowed point light re-renders scene geometry into both faces of a dual-paraboloid map.
	# Past ~22 m the shadow is not readable anyway, so drop it there and keep the light itself.
	_light.set_meta("light_class", "beacon")
	LightPolicy.apply_fade(_light)
	_coal_mat = (_coals.material_override as StandardMaterial3D).duplicate()
	_coals.material_override = _coal_mat
	_set_lit(start_lit, false)
	_crackle = AudioStreamPlayer3D.new()
	_crackle.bus = &"Ambience"
	_crackle.name = "Crackle"
	var loop := (load("res://art/audio/brazier_loop.wav") as AudioStreamWAV).duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_crackle.stream = loop
	_crackle.max_distance = 22.0
	add_child(_crackle)
	if lit:
		_crackle.play()


func can_interact() -> bool:
	return not lit                         # lit: the fire's FireSpot speaks for it ("Rest · Kindling")


## Already the wanderer's checkpoint (FireSpot then offers "Tend the fire", not "Rest").
func is_checkpoint() -> bool:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player if is_inside_tree() else null
	if p == null:
		return false
	if _spawn_at.x == INF:
		_spawn_at = spawn_point()
	return p.checkpoint.distance_to(_spawn_at) < 1.0


func interact_text() -> String:
	if lit:
		return "[%s]  Rest" % Interactable.prompt_key()
	return "[%s]  Kindle the brazier" % Interactable.prompt_key()


func interact_feel() -> StringName:
	return &"cast"


func interact(by: Node) -> void:
	if lit:
		remember(by)                         # resting at any lit fire moves the checkpoint here (relics swap in the satchel)
		return
	_set_lit(true, true)
	if by.has_method("set_checkpoint"):
		by.set_checkpoint(spawn_point())
	Events.brazier_kindled.emit(self)
	# the valley's four have names in the keep's mouth (r30 story); any other is just a brazier
	var named: String = {"StairFoot": "The Stair-foot fire", "Shrine": "The glade's fire", "Landing": "The Barrow Field fire",
		"Threshold": "The fen fire"}.get(String(name), "")
	Events.toast.emit(("%s burns. Stand in it; the dark leaves slowly." % named) if named != "" else "Brazier kindled. Stand in the fire. The dark leaves slowly.")


## r33: what the Ember Road and the map call this fire.
func display_name() -> String:
	if FIRE_NAMES.has(String(name)):
		return String(FIRE_NAMES[String(name)])
	if not is_inside_tree():
		return "A brazier"
	var r := RealmLayout.region_at(global_position.x, global_position.z)
	return ("The %s fire" % String(r.name).trim_prefix("The ")) if r.has("name") else "A brazier"


## Make this fire the wanderer's respawn (a rest here, r30). The checkpoint used to move only on
## the first kindle, so a death went back to the last fire LIT, not the last fire rested at.
## Says so once per change; returns true when it moved.
func remember(by: Node) -> bool:
	if not lit or by == null or not by.has_method("set_checkpoint"):
		return false
	var at := spawn_point()
	var was: Variant = by.get("checkpoint")
	if was is Vector3 and (was as Vector3).distance_to(at) < 1.0:
		return false
	by.call("set_checkpoint", at)
	Events.toast.emit("The fire will remember you.")
	return true


## The lit brazier whose light covers `pos` (the nearest), or null.
static func lit_at(tree: SceneTree, pos: Vector3) -> Brazier:
	var best: Brazier = null
	var best_d := INF
	for n in tree.get_nodes_in_group(Groups.LIGHT_SOURCE):
		var b := n as Brazier
		if b == null or not b.lit:
			continue
		var d := b.global_position.distance_to(pos)
		if d <= b.light_radius and d < best_d:
			best_d = d
			best = b
	return best


## The Hearthfire (core/life/progression/hearth.gd) widens every fire's sanctuary: `r` is the new
## LightGrid radius. The light's own range grows with it so the warm circle reads as far as it
## holds (the pool equals the sanctuary).
func set_reach(r: float) -> void:
	if not has_meta(&"reach_base"):
		set_meta(&"reach_base", Vector2(light_radius, lit_range))      # the hearth reads this as the base
	if is_equal_approx(r, light_radius):
		return
	light_radius = r
	lit_range = _pool_range()
	if lit:
		LightGrid.register(self, light_radius)
		var b: Variant = _light.get_meta(&"base", {})
		if b is Dictionary:
			(b as Dictionary)["r"] = lit_range
			_light.set_meta(&"base", b)
			LightPolicy.apply_fade(_light)
			LightPolicy.apply_illumination(_light)


## The authored range that, after the beacon class widens it, ends exactly where the sanctuary ends.
func _pool_range() -> float:
	return light_radius / float((LightPolicy.ILLUM[&"beacon"] as Array)[1])


func kindle_quiet() -> void:
	if not lit:
		_set_lit(true, false)


## Where a kindle sends you back: 1.8 m in front of the bowl, ON the ground there. The fixed +0.3 m
## put the Threshold's point 0.6 m under the fen's rising slope (a respawn inside the terrain);
## now the point is dropped onto whatever is below it, trying the other sides if the front is bad.
func spawn_point() -> Vector3:
	var front := global_position + global_basis * Vector3(0.0, 0.3, 1.8)
	if not is_inside_tree():
		return front
	var space := get_world_3d().direct_space_state
	var excl: Array[RID] = []
	for c in find_children("*", "CollisionObject3D", true, false):
		excl.append((c as CollisionObject3D).get_rid())
	for side: Vector3 in [Vector3(0, 0, 1.8), Vector3(1.8, 0, 0), Vector3(-1.8, 0, 0), Vector3(0, 0, -1.8)]:
		var p := global_position + global_basis * side
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.5, p + Vector3.DOWN * 3.0, Layers.WORLD | Layers.PROPS, excl)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue                             # nothing under it, or a wall / steep face
		return (hit.position as Vector3) + Vector3.UP * 0.15
	return front


func _set_lit(on: bool, animate: bool) -> void:
	lit = on
	set_meta(&"map_color", MAP_LIT if on else MAP_COLD)       # r33: the map shows which fires can carry you
	_flame.emitting = on
	var cards := _flame.get_node_or_null("Cards")
	if cards:
		cards.visible = on
	_light.set_meta("light_class", "beacon" if on else "fill")
	var target_energy := lit_energy if on else 0.25
	_light.set_meta(&"base", {
		"e": target_energy,
		"r": _pool_range() * 1.25 if on else 2.5,      # the glow reaches a little past the sanctuary's edge
		"a": 1.0,
	})
	LightPolicy.apply_fade(_light)
	LightPolicy.apply_shadows(_light)
	LightPolicy.apply_illumination(_light)
	_light.light_color = FIRE_LIGHT if on else _light.light_color
	if on:
		LightGrid.register(self, light_radius)
	else:
		LightGrid.unregister(self)
	if animate:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "_energy", target_energy, 0.8).from(0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(_coal_mat, "emission_energy_multiplier", COAL_GLOW, 0.8).from(0.35)
	else:
		_energy = target_energy
		_coal_mat.emission_energy_multiplier = COAL_GLOW if on else 0.35
	if _crackle:
		if on:
			_crackle.play()
		else:
			_crackle.stop()


var _kind_src: Variant = &""
var _kind_mult := 1.0
var _far_t := 0.0
var _far := false


func _process(delta: float) -> void:
	_t += delta
	# perf: past its distance fade the light is not drawn, so its flicker is not set (checked twice
	# a second); the class multiplier is looked up only when the class meta changes
	_far_t -= delta
	if _far_t <= 0.0:
		_far_t = 0.5
		var cam := get_viewport().get_camera_3d()
		var gone := _light.distance_fade_begin + _light.distance_fade_length + 6.0
		_far = cam != null and _light.distance_fade_enabled and cam.global_position.distance_squared_to(_light.global_position) > gone * gone
	if _far:
		return
	var flicker := 1.0 + (sin(_t * 11.0) * 0.06 + sin(_t * 17.3) * 0.04 if lit else sin(_t * 2.0) * 0.2)
	var src: Variant = _light.get_meta(&"light_class")
	if src != _kind_src:
		_kind_src = src
		_kind_mult = LightPolicy.energy_mult(StringName(str(src)))
	_light.light_energy = _energy * _kind_mult * flicker
