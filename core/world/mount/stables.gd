extends Node
## r36 horses: the hitching posts (one per breed, each where that breed is kept: horse_db.gd), the
## horses themselves, and the call: [H] brings the horse you last rode to your side (not in a boss's
## fight, not underground). Built with the watch once the Realm's camps are planted.

const DB := preload("res://core/world/mount/horse_db.gd")
const ScalePilot := preload("res://core/world/realm/scale_pilot.gd")
const Horse := preload("res://core/world/mount/horse.gd")
const HorseBond := preload("res://core/world/mount/horse_bond.gd")

var horses := {}                 ## breed -> horse node


static func build(host: Node3D) -> void:
	if not Slice.full():                     # the 30-minute slice hides horses (--full restores them)
		return
	if host == null or host.get_node_or_null("Stables") != null:
		return
	var s: Node = (load("res://core/world/mount/stables.gd") as GDScript).new()
	s.name = "Stables"
	host.add_child(s)


func _ready() -> void:
	add_to_group(&"stables")
	var host := get_parent() as Node3D
	var space := host.get_world_3d().direct_space_state
	for b: String in DB.ORDER:
		var d: Dictionary = DB.BREEDS[b]
		var at: Vector2 = ScalePilot.hw_xz(ScalePilot.xz(d.at))      # Weirford's stables stand on a new plot under the scale pilot; Hearthward's post stays south of the Reeds' wider house
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 90.0, at.y), Vector3(at.x, -40.0, at.y), Layers.WORLD))
		var g: Vector3 = (hit.position as Vector3) if not hit.is_empty() else Vector3(at.x, 0.0, at.y)
		var f: Vector2 = ScalePilot.dir(d.at, d.face)
		var yaw := atan2(-f.x, -f.y)
		_post(host, g, yaw, String(d.name))
		var h: Node3D = Horse.new()
		h.name = "Horse_" + b
		h.set("breed", b)
		h.position = g + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 1.3)   # alongside the rail, tied to it
		h.rotation.y = yaw + PI * 0.5
		host.add_child(h)
		horses[b] = h
		_restore_left(h, b, space)


## A hitching rail: two posts and a bar, and a pin on the map.
func _post(host: Node3D, at: Vector3, yaw: float, label: String) -> void:
	var n := Node3D.new()
	n.name = "HitchingPost"
	host.add_child(n)
	n.global_position = at
	n.rotation.y = yaw
	var k := OssKit.new()
	k.keep_lanes = false
	for sx: float in [-0.9, 0.9]:
		k.box("wood", Vector3(sx, 0.6, 0.0), Vector3(0.14, 1.2, 0.14), Basis.IDENTITY, false, 0.7)
	k.box("wood", Vector3(0.0, 1.05, 0.0), Vector3(2.0, 0.1, 0.1), Basis.IDENTITY, false, 0.7)
	k.commit(n, "Rail")
	n.set_meta(&"map_kind", "vendor")
	n.set_meta(&"map_label", label)
	n.add_to_group("map_marker")
	n.add_to_group(&"hitching_post")


func _unhandled_input(ev: InputEvent) -> void:
	if not ev.is_action_pressed("mount"):
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null or p.riding != null:
		return
	var st: Dictionary = Horse.state()
	var b := String(st.get("ride", ""))
	if b == "" or not (st.owned as Array).has(b):
		Events.toast.emit("You have no horse to call. The stables sell them: Hearthward, the moor, the pits, the mere.")
		return
	if Player.boss_fight_active(get_tree()):
		Events.toast.emit("No horse will come here.")
		return
	var h: Node3D = horses.get(b)
	if h == null:
		return
	var back := -p.global_basis.z
	back.y = 0.0
	var to := p.global_position - back.normalized() * 3.0
	var space := p.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * 4.0, to + Vector3.DOWN * 8.0, Layers.WORLD))
	if hit.is_empty() or absf((hit.position as Vector3).y - p.global_position.y) > 2.5:
		Events.toast.emit("You whistle. Nothing can reach you here.")
		return
	h.global_position = hit.position
	h.rotation.y = p.rotation.y
	h.set("at_post", false)
	Events.toast.emit("Hooves in the dark. %s comes." % HorseBond.name_of(b))
	get_viewport().set_input_as_handled()


## A horse ridden before is where its rider got down (the save keeps it): back at that spot on the ground, not at its post.
func _restore_left(h: Node3D, b: String, space: PhysicsDirectSpaceState3D) -> void:
	var left: Variant = Horse.state().get("left", null)
	if not (left is Dictionary) or not (left as Dictionary).has(b) or not (Horse.state().owned as Array).has(b):
		return
	var v: Array = (left as Dictionary)[b]
	if v.size() < 3:
		return
	var at := Vector2(float(v[0]), float(v[1]))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 90.0, at.y), Vector3(at.x, -40.0, at.y), Layers.WORLD))
	if hit.is_empty():
		return
	h.global_position = hit.position
	h.rotation.y = float(v[2])
	h.set("at_post", false)
