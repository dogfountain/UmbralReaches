class_name Wayfarer
extends Node
## The wanderer's own hand on the map. Two things, both saved:
##   The trail: where she has walked, a dotted charcoal line across the world map (a point every 9 m, the newest 2,600, a
##   break where she was carried by the Ember Road or a fall). Travel.story["trail"] = flat ints [x, z, x, z ...], a
##   break is (-99999, -99999).
##   Marks: up to twelve cairns set by hand on the map (right-click on bare parchment, or Y on a pad at the reticle; the
##   same on one of them lifts it). Each stands in the world as a beacon on the compass and the minimap, so a mark is
##   something to walk to. Travel.story["pins"] = flat ints [x, z, ...].
## A child of the story director (class Wayfarer).

const MAX_TRAIL := 2600
const MAX_PINS := 12
const STEP := 9.0
const BREAK := -99999
const TINT := Color(0.86, 0.92, 1.0)

## What the compass and the minimap read of a beacon (core/world/realm/landmark_beacon.gd): an `anchor` and a `tint`.
class WayMark extends Node3D:
	var anchor := Vector3.ZERO
	var tint := Color(0.86, 0.92, 1.0)

var _t := 1.0
var _last := Vector2.INF
var _marks: Array[Node3D] = []


static func _arr(key: String) -> Array:
	var a: Variant = Travel.story.get(key, null)
	if not (a is Array):
		a = []
		Travel.story[key] = a
	return a as Array


static func pins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a := _arr("pins")
	for i in range(0, a.size() - 1, 2):
		out.append(Vector2(float(a[i]), float(a[i + 1])))
	return out


## The pins as marks for the world map: kind "beacon" (its painted medallion), with the index to lift it by.
static func pin_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ps := pins()
	for i in ps.size():
		out.append({"at": ps[i], "kind": "beacon", "name": "Your mark %d" % (i + 1), "note": "Right-click (or Y) to lift it", "pin": i})
	return out


## Set a mark at world `at`, or lift the one under the pointer (`hovered`: the map's mark there, or {}). True when the
## marks changed (the map collects again).
static func toggle_pin(tree: SceneTree, at: Vector2, hovered: Dictionary) -> bool:
	var a := _arr("pins")
	if hovered.has("pin"):
		var i := int(hovered.pin)
		if i * 2 + 1 < a.size():
			a.remove_at(i * 2)
			a.remove_at(i * 2)
			Events.toast.emit("The mark is lifted.")
			_sync(tree)
			Travel.save_soon()
			return true
		return false
	if not hovered.is_empty() and String(hovered.get("kind", "")) != "you":
		return false                                           # a mark of the world's own: not here
	if a.size() >= MAX_PINS * 2:
		Events.toast.emit("Twelve marks are set. Lift one to set another.")
		return true
	if not RealmLayout.BOUNDS.has_point(at):
		return false
	a.append(roundi(at.x))
	a.append(roundi(at.y))
	Events.toast.emit("A mark is set. It shows on the compass and the dial.")
	_sync(tree)
	Travel.save_soon()
	return true


static func _sync(tree: SceneTree) -> void:
	var w := tree.get_first_node_in_group(&"wayfarer") as Wayfarer
	if w != null:
		w.rebuild.call_deferred()


## The trail as a dotted charcoal line on the map's overlay: `to_screen` maps a world xz to the screen, `view` is the sheet's
## visible rectangle. One short dash between each pair of points; the oldest are the palest.
static func paint_trail(c: Control, to_screen: Callable, view: Rect2) -> void:
	var a := _arr("trail")
	var n := a.size() / 2
	var prev := Vector2.INF
	for i in n:
		var x := int(a[i * 2])
		if x == BREAK:
			prev = Vector2.INF
			continue
		var p: Vector2 = to_screen.call(Vector2(float(x), float(a[i * 2 + 1])))
		if prev != Vector2.INF and (view.has_point(p) or view.has_point(prev)) and prev.distance_to(p) < 120.0:
			var age := 0.35 + 0.5 * float(i) / float(maxi(1, n))
			c.draw_line(prev.lerp(p, 0.12), prev.lerp(p, 0.62), Color(0.12, 0.08, 0.06, age), 2.0, true)
		prev = p


func _ready() -> void:
	name = "Wayfarer"
	add_to_group(&"wayfarer")
	rebuild()


## The marks stand in the world again (after a load, or a mark set or lifted).
func rebuild() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()
	var host := get_tree().current_scene
	if host == null:
		return
	for at in pins():
		var m := WayMark.new()
		m.name = "WayMark"
		host.add_child(m)
		m.anchor = Vector3(at.x, RealmLayout.macro_height(at.x, at.y) + 2.0, at.y)
		m.global_position = m.anchor
		m.tint = TINT
		m.add_to_group(&"landmark_beacon")
		_marks.append(m)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or p.process_mode == Node.PROCESS_MODE_DISABLED or get_tree().paused:
		return
	var at := Vector2(p.global_position.x, p.global_position.z)
	if _last != Vector2.INF and at.distance_to(_last) < STEP:
		return
	var a := _arr("trail")
	if _last != Vector2.INF and at.distance_to(_last) > 70.0 and not a.is_empty() and int(a[a.size() - 2]) != BREAK:
		a.append(BREAK)
		a.append(BREAK)                                        # carried, not walked: the line does not cross the gap
	a.append(roundi(at.x))
	a.append(roundi(at.y))
	while a.size() > MAX_TRAIL * 2:
		a.remove_at(0)
		a.remove_at(0)
	_last = at
