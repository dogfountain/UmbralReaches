extends Node3D
## Plants enemies on a zone. Packs are several pawns around one camp.

const RESPAWN := 10.0
const RETRY := 1.5
const KEEP_CLEAR := 7.0
const HAVEN := Vector3(-3.4, 0.0, -8.5)
const HAVEN_R := 12.0

const STAIR_SITES: Array[Vector3] = [
	Vector3(-5.5, 5.0, 12.0),
	Vector3(5.5, 5.0, 12.0),
	Vector3(-5.0, 4.0, 6.0),
]


static func seed_stair(root: Node) -> void:
	var camps: Array = []
	for at in STAIR_SITES:
		camps.append({"at": at, "kinds": ["wretch"]})
	_seed(root, camps)


static func _seed(root: Node, camps: Array) -> void:
	if root == null or root.get_node_or_null("EnemySpawner") != null:
		return
	var n := new()
	n.name = "EnemySpawner"
	n._camps = camps
	root.add_child(n)


var _camps: Array = []
var _slots: Array[Dictionary] = []
var _tick := 0.0
var _scripts: Dictionary = {}


func _ready() -> void:
	_scripts["wretch"] = load("res://core/enemy/wretch.gd")
	_scripts["husk"] = load("res://core/enemy/husk.gd")
	_scripts["crawler"] = load("res://core/enemy/crawler.gd")
	_scripts["leaper"] = load("res://core/enemy/leaper.gd")
	if Events.enemy_killed.is_connected(_on_killed) == false:
		Events.enemy_killed.connect(_on_killed)
	_plant()


func _plant() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for camp in _camps:
		var center := _ground(space, camp.at)
		if Vector2(center.x - HAVEN.x, center.z - HAVEN.z).length() < HAVEN_R:
			continue
		if Vector2(center.x, center.z + 10.0).length() < 12.0:
			continue
		var kinds: Array = camp.kinds
		var n := kinds.size()
		for i in n:
			var a := TAU * float(i) / float(maxi(n, 1)) + 0.15
			var probe := center + Vector3(cos(a) * 2.5, 0.0, sin(a) * 2.5)
			var at := _ground(space, probe)
			var key := String(kinds[i])
			var kind: GDScript = _scripts.get(key, _scripts.get("wretch"))
			if kind == null:
				continue
			_slots.append({"at": at, "pawn": null, "pending": false, "kind": kind})
	for slot in _slots:
		_spawn(slot)


func _process(delta: float) -> void:
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0
	for slot in _slots:
		var pawn: Variant = slot.pawn
		if not is_instance_valid(pawn) and not slot.pending:
			_schedule(slot, RESPAWN)


func _on_killed(enemy: Node) -> void:
	for slot in _slots:
		if slot.pawn == enemy:
			_schedule(slot, RESPAWN)
			return


func _schedule(slot: Dictionary, delay: float) -> void:
	if slot.pending:
		return
	slot.pending = true
	get_tree().create_timer(delay, false).timeout.connect(_respawn.bind(slot))


func _respawn(slot: Dictionary) -> void:
	slot.pending = false
	var player := _player()
	var near_player := player != null and player.global_position.distance_to(slot.at) < KEEP_CLEAR
	if near_player or LightGrid.is_lit(slot.at):
		_schedule(slot, RETRY)
		return
	_spawn(slot)


func _spawn(slot: Dictionary) -> void:
	var kind: GDScript = slot.kind
	if kind == null:
		kind = _scripts.get("wretch")
	if kind == null:
		return
	var host := get_parent()
	if host == null:
		return
	var pawn: Node = kind.new()
	host.add_child(pawn)
	if pawn.has_method("station"):
		pawn.station(slot.at)
	else:
		pawn.global_position = slot.at + Vector3(0.0, 0.05, 0.0)
	slot.pawn = pawn


func _ground(space: PhysicsDirectSpaceState3D, from: Vector3) -> Vector3:
	if space == null:
		return Vector3(from.x, 0.6, from.z)
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(2.2, 0.0, 0.0), Vector3(-2.2, 0.0, 0.0),
		Vector3(0.0, 0.0, 2.2), Vector3(0.0, 0.0, -2.2),
		Vector3(3.4, 0.0, 2.0), Vector3(-3.4, 0.0, 2.0),
		Vector3(2.0, 0.0, -3.0), Vector3(-2.0, 0.0, -3.0),
	]
	var fallback := Vector3(from.x, 0.6, from.z)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	for off in offsets:
		var probe := from + off
		var q := PhysicsRayQueryParameters3D.create(
			probe + Vector3(0.0, 24.0, 0.0),
			probe + Vector3(0.0, -80.0, 0.0)
		)
		q.collision_mask = Layers.WORLD
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var n: Vector3 = hit.get("normal", Vector3.UP)
		if n.y < 0.55:
			continue
		var at: Vector3 = hit.position
		fallback = at
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = cap
		sq.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.86, 0.0))
		sq.collision_mask = Layers.WORLD
		if space.intersect_shape(sq, 1).is_empty():
			return at
	return fallback


func _player() -> Player:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Player
