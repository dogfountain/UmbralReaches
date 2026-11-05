class_name ChainLift
extends Node3D
## Counterweighted cage lift: an AnimatableBody3D deck that waits, rises, waits, falls, forever.
## sync_to_physics carries a standing CharacterBody with it (platform velocity), so the player
## rides without code on their side. The deck is 2.6 m square; its west edge is the way off.

@export var bottom := Vector3.ZERO      ## deck top at the low stop (world)
@export var top_y := 10.0               ## deck top at the high stop (world y)
@export var travel_time := 7.0
@export var dwell := 3.0

var _deck: AnimatableBody3D
var _t := 0.0
const DECK := Vector3(2.6, 0.3, 2.6)


func _ready() -> void:
	top_level = true
	global_position = Vector3.ZERO
	_build()


func _build() -> void:
	var iron := OssKit.mat("iron")
	var wood := OssKit.mat("wood")
	_deck = AnimatableBody3D.new()
	_deck.name = "Deck"
	_deck.sync_to_physics = true
	_deck.collision_layer = Layers.WORLD
	_deck.collision_mask = 0
	add_child(_deck)
	_deck.global_position = bottom
	var slab := _box(_deck, Vector3(0, -DECK.y * 0.5, 0), DECK, wood)
	slab.name = "Slab"
	for s: float in [-1.0, 1.0]:           # rails north and south, open east (column) and west (exit)
		_box(_deck, Vector3(0, 0.55, s * (DECK.z * 0.5 - 0.05)), Vector3(DECK.x, 0.08, 0.08), iron)
		for x: float in [-1.25, 0.0, 1.25]:
			_box(_deck, Vector3(x, 0.28, s * (DECK.z * 0.5 - 0.05)), Vector3(0.07, 0.56, 0.07), iron)
		_box(_deck, Vector3(0, 0.0, s * (DECK.z * 0.5 - 0.05)), Vector3(DECK.x, 0.12, 0.12), iron)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = DECK
	cs.shape = shape
	cs.position = Vector3(0, -DECK.y * 0.5, 0)
	_deck.add_child(cs)
	# column on the east side from the lava to above the top stop, with a beam and pulley
	var col_x := bottom.x + DECK.x * 0.5 + 0.55
	var base_y := -16.5
	var top := top_y + 3.6
	var column := StaticBody3D.new()
	column.collision_layer = Layers.WORLD
	add_child(column)
	_box(column, Vector3(col_x, (base_y + top) * 0.5, bottom.z), Vector3(0.9, top - base_y, 0.9), OssKit.mat("stone"))
	var ccs := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = Vector3(0.9, top - base_y, 0.9)
	ccs.shape = cshape
	ccs.position = Vector3(col_x, (base_y + top) * 0.5, bottom.z)
	column.add_child(ccs)
	_box(self, Vector3(bottom.x + 0.2, top, bottom.z), Vector3(2.4, 0.35, 0.5), iron)
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 0.25
	wheel.mesh = cyl
	wheel.material_override = iron
	wheel.rotation.x = PI * 0.5
	add_child(wheel)
	wheel.global_position = Vector3(bottom.x, top - 0.45, bottom.z)
	# chains: thin boxes from the pulley to the deck corners, rescaled every frame
	for s: float in [-1.0, 1.0]:
		var ch := _box(self, Vector3.ZERO, Vector3(0.05, 1.0, 0.05), iron)
		ch.name = "Chain%d" % int(s)
	# a lantern hook on the column so the lift reads from the summit
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.omni_range = 6.0
	l.light_energy = 1.2
	l.set_meta(&"light_class", "fill")
	add_child(l)
	l.global_position = Vector3(col_x - 0.6, top - 1.2, bottom.z)
	_place(0.0)


func _box(parent: Node3D, at: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	parent.add_child(mi)
	mi.position = at
	return mi


## Held at the bottom stop (r30: the Ossuary lift ran through the Abbot's fight, an escape from it
## and a ride past the summit ward). Set false and it resumes its round from the bottom.
var hold := false
var _held_u := 0.0


func _physics_process(delta: float) -> void:
	if hold:
		_held_u = move_toward(_held_u, 0.0, delta / maxf(travel_time, 0.1))
		_t = 0.0
		_place(smoothstep(0.0, 1.0, _held_u))
		return
	_t = fmod(_t + delta, (travel_time + dwell) * 2.0)
	var u := 0.0
	if _t < dwell:
		u = 0.0
	elif _t < dwell + travel_time:
		u = smoothstep(0.0, 1.0, (_t - dwell) / travel_time)
	elif _t < dwell * 2.0 + travel_time:
		u = 1.0
	else:
		u = 1.0 - smoothstep(0.0, 1.0, (_t - dwell * 2.0 - travel_time) / travel_time)
	_held_u = u
	_place(u)


func _place(u: float) -> void:
	var y := lerpf(bottom.y, top_y, u)
	_deck.global_position = Vector3(bottom.x, y, bottom.z)
	var top := top_y + 3.6 - 0.45
	for s: float in [-1.0, 1.0]:
		var ch := get_node_or_null("Chain%d" % int(s)) as MeshInstance3D
		if ch == null:
			continue
		var a := Vector3(bottom.x, top, bottom.z + s * 0.35)
		var b := Vector3(bottom.x, y + 0.55, bottom.z + s * (DECK.z * 0.5 - 0.05))
		ch.global_position = (a + b) * 0.5
		var d := b - a
		ch.global_basis = Basis(Vector3.RIGHT, d.normalized().cross(Vector3.RIGHT).normalized(), Vector3.ZERO).orthonormalized() if false else Basis(Quaternion(Vector3.UP, d.normalized())).scaled(Vector3(1.0, d.length(), 1.0))
