class_name OssWorld
extends RefCounted
## The Ossuary's builders work in the Ossuary's own (local) coordinates (OssFrame). The secrets' kit, the
## page readers and the beams place nodes by WORLD position; these wrappers take the local numbers the
## builders already use and hand the world ones on, so a builder never converts by hand.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const Beam := preload("res://core/life/secrets/beam.gd")


static func touch(parent: Node, at: Vector3, prompt: String, fn: Callable, reach := 2.2) -> Node3D:
	return Kit.touch(parent, OssFrame.w(at), prompt, fn, reach)


static func mi(parent: Node, mesh: Mesh, m: Material, xf: Transform3D, vis_end := 0.0, shadows := true) -> MeshInstance3D:
	return Kit.mi(parent, mesh, m, OssFrame.xf() * xf, vis_end, shadows)


static func box_body(parent: Node, c: Vector3, size: Vector3, b := Basis.IDENTITY, layer := Layers.WORLD) -> StaticBody3D:
	return Kit.box_body(parent, OssFrame.w(c), size, OssFrame.xf().basis * b.orthonormalized(), layer)


static func glint(parent: Node, at: Vector3, col := Color(0.55, 0.8, 1.0), size := 0.32, range_end := 24.0) -> MeshInstance3D:
	return Kit.glint(parent, OssFrame.w(at), col, size, range_end)


static func omni(parent: Node, at: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	return Kit.omni(parent, OssFrame.w(at), col, energy, rng)


static func play(kind: String, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	Kit.play(kind, OssFrame.w(at), db, pitch)


static func fx_dust(at: Vector3, col := Color(0.5, 0.46, 0.42, 0.7), n := 30) -> void:
	Kit.fx_dust(OssFrame.w(at), col, n)


static func fx_sparks(at: Vector3, col := Color(1.6, 0.8, 0.3)) -> void:
	Kit.fx_sparks(OssFrame.w(at), col)


static func spawn_elite(host: Node, kind: String, at: Vector3, title: String, hp_min := 0) -> Node3D:
	return Kit.spawn_elite(host, kind, OssFrame.w(at), title, hp_min)


static func reading(parent: Node, page: String, at: Vector3, verb := "Read") -> Node3D:
	return State.reading(parent, page, OssFrame.w(at), verb)


## Beam ribbons: xz points at height y, in the Ossuary's frame.
static func beam_draw(holder: Node3D, pts: Array, y: float, width := 0.22) -> void:
	var out: Array[Vector2] = []
	for p: Vector2 in pts:
		out.append(OssFrame.w2(p))
	Beam.draw(holder, out, y + OssFrame.ORIGIN.y, width)


static func beam_segment(holder: Node3D, a: Vector3, b: Vector3, width := 0.22) -> MeshInstance3D:
	return Beam.segment(holder, OssFrame.w(a), OssFrame.w(b), width)


static func cache(parent: Node, id: String, at: Vector3, what: String, opened: Callable, ready_fn := Callable()) -> Node3D:
	return State.cache(parent, id, OssFrame.w(at), what, opened, ready_fn)


static func take(id: String, at: Vector3) -> bool:
	return State.take(id, OssFrame.w(at))


## A walking route for the secrets' registry (and its tests): `from` is a local point, `pts` local xz waypoints
## (their y is kept: 0 means "stay on the floor"); the route comes out in world coordinates.
static func route(from: Vector3, pts: Array) -> Dictionary:
	var out: Array[Vector3] = []
	for v: Vector3 in pts:
		var q := OssFrame.w(v)
		out.append(Vector3(q.x, v.y, q.z))
	return {"from": OssFrame.w(from), "pts": out}
