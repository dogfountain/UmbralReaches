extends RefCounted
## Trailer QC monitor (zz/trailer.gd calls step() every shot frame, report() at each cut). It watches for the
## things that read as unpolished on screen and prints one line each:
##   WALL  <shot> t=..  the wanderer is driven into a solid within 0.7 m of its heading (running at a wall)
##   STUCK <shot> t=..  the wanderer is driven but moves under 25% of the speed it should (pressed against / caught on something)
##   CAMIN <shot> t=..  the lens is inside, or within 0.3 m of, solid collision (a wall plane filling the frame)
##   FALL  <shot> t=..  the wanderer dropped more than 1.5 m under where the shot put them
## report() prints `QC <shot> wall=<frames> stuck=<frames> camin=<frames>` so a render log shows every shot's totals.

var d: Node
var _last := Vector3.ZERO
var _have := false
var _wall := 0
var _stuck := 0
var _camin := 0
var _stuck_run := 0.0
var _y0 := 0.0
var _logged := {}


func _init(director: Node) -> void:
	d = director


func _log_once(kind: String, id: String, t: float, extra: String) -> void:
	var key := "%s%s%d" % [kind, id, int(t * 4.0)]
	if _logged.has(key):
		return
	_logged[key] = true
	print("%s %s t=%.2f %s" % [kind, id, t, extra])


func step(id: String, t: float, dt: float, drive_to: Vector3, sprint: bool) -> void:
	var p: Player = d.p
	if p == null or dt <= 0.0:
		return
	var space: PhysicsDirectSpaceState3D = (d.main as Node3D).get_world_3d().direct_space_state
	var pos: Vector3 = p.global_position
	if not _have or t < 0.05:
		_last = pos
		_have = true
		_y0 = pos.y
		return
	var driven := drive_to.length() > 0.5
	var moved := Vector2(pos.x - _last.x, pos.z - _last.z).length() / dt
	_last = pos
	if driven:
		var dirv := Vector3(drive_to.x, 0.0, drive_to.z).normalized()
		var ball := SphereShape3D.new()
		ball.radius = 0.35
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = ball
		q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 1.0 + dirv * 0.7)
		q.collision_mask = Layers.WORLD | Layers.PROPS
		q.exclude = [p.get_rid()]
		var hits := space.intersect_shape(q, 2)
		if not hits.is_empty():
			_wall += 1
			var col := hits[0].collider as Node
			_log_once("WALL", id, t, "at %s toward %s hits %s" % [pos.snapped(Vector3.ONE * 0.1), dirv.snapped(Vector3.ONE * 0.1), col.get_path() if col else "?"])
		var want := 5.5 if sprint else 3.0
		if moved < want * 0.25:
			_stuck_run += dt
			if _stuck_run > 0.25:
				_stuck += 1
				_log_once("STUCK", id, t, "at %s moved %.1f m/s of ~%.1f" % [pos.snapped(Vector3.ONE * 0.1), moved, want])
		else:
			_stuck_run = 0.0
	if pos.y < _y0 - 1.5:
		_log_once("FALL", id, t, "at %s (shot began at y %.1f)" % [pos.snapped(Vector3.ONE * 0.1), _y0])
	var vc := d.get_viewport().get_camera_3d()
	if vc != null:
		var ball2 := SphereShape3D.new()
		ball2.radius = 0.3
		var q2 := PhysicsShapeQueryParameters3D.new()
		q2.shape = ball2
		q2.transform = Transform3D(Basis.IDENTITY, vc.global_position)
		q2.collision_mask = Layers.WORLD | Layers.PROPS
		q2.exclude = [p.get_rid()]
		var h2 := space.intersect_shape(q2, 2)
		if not h2.is_empty():
			_camin += 1
			var c2 := h2[0].collider as Node
			_log_once("CAMIN", id, t, "cam %s hits %s" % [vc.global_position.snapped(Vector3.ONE * 0.1), c2.get_path() if c2 else "?"])


func report(id: String) -> void:
	print("QC %-14s wall=%d stuck=%d camin=%d" % [id, _wall, _stuck, _camin])
	_wall = 0
	_stuck = 0
	_camin = 0
	_stuck_run = 0.0
	_have = false
	_logged.clear()
