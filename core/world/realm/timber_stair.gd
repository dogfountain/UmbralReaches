extends RefCounted
## Timber scaffold stairs for the places (no class_name; preload by path).


## A timber scaffold stair (world points): a flight from `foot` (on the ground) up to `top` (a floor), built in short
## runs so the underside steps with it instead of filling the slope, with a post under every run, a handrail on each
## side. Returns the stand points up the flight (on its collision ramp).
static func build(k: OssKit, space: PhysicsDirectSpaceState3D, foot: Vector3, top: Vector3, width := 1.3, run_steps := 4) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var flat := Vector3(top.x - foot.x, 0.0, top.z - foot.z)
	var dir := flat.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var total := flat.length()
	var rise_total := top.y - foot.y
	var n := maxi(int(ceilf(rise_total / 0.4)), 4)
	n = int(ceilf(float(n) / float(run_steps))) * run_steps
	var runs := n / run_steps
	var tread := total / float(n)
	var rise := rise_total / float(n)
	for j in runs:
		var s0 := tread * float(j * run_steps)
		var s1 := tread * float((j + 1) * run_steps)
		var lo := foot + dir * s0 + Vector3.UP * rise * float(j * run_steps)
		var hi := foot + dir * s1 + Vector3.UP * rise * float((j + 1) * run_steps)
		k.stairs("wood", lo, hi, width, run_steps, lo.y - 0.3)
		# the post under the run's head, down to whatever ground is there
		var g := RealmLayout.ground(space, hi.x, hi.z)
		for sd: float in [-1.0, 1.0]:
			var q := hi + side * (sd * (width * 0.5 - 0.1))
			var qg := RealmLayout.ground(space, q.x, q.z)
			if q.y - qg > 0.6:
				k.box("wood", Vector3(q.x, (q.y - 0.3 + qg - 0.3) * 0.5, q.z), Vector3(0.16, q.y - 0.3 - qg + 0.3, 0.16), Basis.IDENTITY, false, 0.8)
		if g < hi.y - 1.2 and j % 2 == 1:
			var qa := hi - dir * (tread * 2.0)
			k.box("wood", (hi + qa) * 0.5 + Vector3.DOWN * 0.4, Vector3(width - 0.1, 0.12, 0.12), Basis(side, Vector3.UP, dir), false, 0.7)
		# a point on this run's ramp, for the climb route (the ramp runs half a tread behind the treads' tops)
		var sm := (s0 + s1) * 0.5
		out.append(foot + dir * sm + Vector3.UP * (rise / tread * (sm + tread * 0.5) - 0.0))
	# the handrails: a post every second tread and a rail along each side
	for sd: float in [-1.0, 1.0]:
		var a := foot + side * (sd * (width * 0.5 + 0.02)) + Vector3.UP * 1.0
		var b := top + side * (sd * (width * 0.5 + 0.02)) + Vector3.UP * 1.0
		k.box("wood", (a + b) * 0.5, Vector3(0.07, 0.07, a.distance_to(b)), Basis.looking_at(b - a, Vector3.UP), false, 0.75)
		for i in range(0, n + 1, 2):
			var q := foot + dir * (tread * float(i)) + Vector3.UP * (rise * float(i)) + side * (sd * (width * 0.5 + 0.02))
			k.box("wood", q + Vector3.UP * 0.5, Vector3(0.07, 1.0, 0.07), Basis.IDENTITY, false, 0.75)
	return out
