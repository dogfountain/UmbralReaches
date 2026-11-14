extends RefCounted
## The horse's way round things (horse.gd drives it; this holds the questions and the little state):
##   probe     horizontal rays at the height of a hock-to-knee above the ground, spread across the barrel:
##             what is in the way that the horse cannot step onto (anything lower than `climb` is not an
##             obstacle: the ground ray carries it over, and a hop above a knee-high rise)
##   slide     the way along the face of what it met (steer assist), and how much of the speed it keeps
##   shoulder  grunts are pushed aside, not met (bosses are walls); the rays and the ground ignore them
##   unwedge   no progress for WEDGE_T while driven: a back-and-turn out of it, by itself
## Load by path.

const WEDGE_T := 0.6               ## s of being driven and getting nowhere
const WEDGE_M := 0.2               ## m: less than this in a window is wedged (a start from rest covers more)
const HEAD_ON := 0.8               ## how square to a face counts as head-on (cos of the angle)
const HEAD_MAX := 0.9              ## s a head-on meeting may keep sliding sideways before it stops
const FREE_T := 0.7               ## s the way out lasts
const FREE_CD := 0.8               ## s after one before another may start
const SHOVE_GAP := 0.6             ## s before the same body is pushed again
const FLOOR_N := 0.7               ## a hit whose normal is steeper than this is a wall, flatter is ground
const LAT := [-0.36, -0.18, 0.0, 0.18, 0.36]       ## ray offsets across the barrel (times the horse's scale)

var stuck_t := 0.0                  ## the window being measured
var win_from := Vector3.ZERO        ## where the window began
var head_t := 0.0                   ## time spent sliding head-on, draining when not
var free_t := 0.0
var free_dir := Vector3.ZERO
var free_cd := 0.0
var hop_cd := 0.0
var side := 1.0                     ## which way a head-on meeting turns, kept so it does not dither
var soft: Array[RID] = []           ## the grunts near enough to matter this tick (rays ignore them)
var _shoved := {}                   ## enemy instance id -> msec of the last push


## The grunts (not bosses) within `radius` of `at`: gathered once a tick; their bodies are skipped by every ray.
func gather(tree: SceneTree, at: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	soft.clear()
	var r2 := radius * radius
	for n in tree.get_nodes_in_group(Groups.ENEMY):
		var e := n as Enemy
		if e == null or e.boss or not e.is_alive():
			continue
		var d := e.global_position - at
		if d.x * d.x + d.z * d.z < r2:
			out.append(e)
			soft.append(e.get_rid())
	return out


## The nearest thing in the way: {n (flat normal), dist, lat (the ray's offset, + right), open (which way is
## clearer: + right)} or {} when the way is clear. `h_low` is the ray height above the hooves, `h_hi` the
## chest's (an overhang); `reach` is measured from the origin.
func probe(space: PhysicsDirectSpaceState3D, skip: Array[RID], origin: Vector3, fwd: Vector3, right: Vector3, reach: float, h_low: float, h_hi: float, sc: float) -> Dictionary:
	var ex: Array[RID] = skip.duplicate()
	ex.append_array(soft)
	var best := {}
	var bd := INF
	var open_r := 0.0
	var open_l := 0.0
	for h in [h_low, h_hi]:
		for k in LAT.size():
			var lat: float = LAT[k] * sc
			var from: Vector3 = origin + Vector3.UP * float(h) + right * lat
			var q := PhysicsRayQueryParameters3D.create(from, from + fwd * reach, Layers.WORLD | Layers.PROPS, ex)
			var hit := space.intersect_ray(q)
			var dist := reach
			if not hit.is_empty():
				var nn: Vector3 = hit.normal
				if nn.y > FLOOR_N:
					continue                         # a slope the ground ray carries it up
				dist = from.distance_to(hit.position)
				if dist < bd:
					bd = dist
					best = {"n": Vector3(nn.x, 0.0, nn.z).normalized() if Vector2(nn.x, nn.z).length() > 0.01 else -fwd, "dist": dist, "lat": lat}
			if lat > 0.0:
				open_r += dist
			elif lat < 0.0:
				open_l += dist
	if best.is_empty():
		return best
	best["open"] = 1.0 if open_r > open_l + 0.05 else (-1.0 if open_l > open_r + 0.05 else 0.0)
	return best


## The direction to go along the face `n` (flat, out of the wall) given heading `fwd` and the wish: the tangent
## the heading already leans to; a head-on meeting goes the way the wish leans, else the clearer side, else the
## side it last chose. Returns {dir, keep (the share of the speed kept 0..1), head (1 head-on .. 0 glancing)}.
func slide(hit: Dictionary, fwd: Vector3, wish: Vector3, dt: float) -> Dictionary:
	var n: Vector3 = hit.n
	var into := clampf(-fwd.dot(n), 0.0, 1.0)        # 1 head-on, 0 grazing: the heading's, or the stick's if it is squarer
	if wish.length() > 0.1:
		into = maxf(into, clampf(-wish.normalized().dot(n), 0.0, 1.0))
	var tan_a := Vector3.UP.cross(n)
	var right := fwd.cross(Vector3.UP)
	var lean := fwd.dot(tan_a)
	var dir := tan_a * signf(lean) if absf(lean) >= 0.25 else Vector3.ZERO
	if dir == Vector3.ZERO:                          # near head-on: the wish's side, else the clearer, else as before
		var pref := side
		if absf(wish.dot(right)) > 0.15:
			pref = signf(wish.dot(right))
		elif float(hit.get("open", 0.0)) != 0.0:
			pref = float(hit.open)
		side = pref
		var o := signf(tan_a.dot(right))
		dir = tan_a * (o if o != 0.0 else 1.0) * pref
	var keep := lerpf(1.0, 0.3, into * into)
	if into > HEAD_ON:                               # square on to it: a little way along it, then it is a wall
		head_t += dt * 2.0
		if head_t > HEAD_MAX:
			keep = 0.0
	return {"dir": dir.normalized(), "keep": keep, "head": into}


## Push the grunts that are in the horse's way aside: a knock off the line, a little forward, no wound.
func shoulder(foes: Array[Enemy], at: Vector3, fwd: Vector3, speed: float, sc: float) -> void:
	if speed < 2.5:
		return
	var now := Time.get_ticks_msec()
	var right := fwd.cross(Vector3.UP)
	for e in foes:
		var d := e.global_position - at
		d.y = 0.0
		var ahead := d.dot(fwd)
		var lat := d.dot(right)
		if ahead < -0.4 * sc or ahead > 1.1 * sc + speed * 0.07 or absf(lat) > 0.95 * sc:
			continue
		var id := e.get_instance_id()
		if now - int(_shoved.get(id, -9999)) < int(SHOVE_GAP * 1000.0):
			continue
		_shoved[id] = now
		var away := right * (signf(lat) if absf(lat) > 0.05 else side)
		e.shove((away * 0.85 + fwd * 0.5).normalized() * (3.2 + speed * 0.4))


## Called each driven tick: `driven` (the rider asks to go), `at` where the horse is. True when a whole window
## of WEDGE_T has gone by with no net progress (a start from rest covers more than WEDGE_M).
func wedged(driven: bool, at: Vector3, dt: float, airborne: bool) -> bool:
	free_cd = maxf(0.0, free_cd - dt)
	hop_cd = maxf(0.0, hop_cd - dt)
	head_t = maxf(0.0, head_t - dt)
	if free_t > 0.0:
		free_t -= dt
		stuck_t = 0.0
		return false
	if airborne or not driven:
		stuck_t = 0.0
		return false
	if stuck_t <= 0.0:
		win_from = at
	stuck_t += dt
	if stuck_t < WEDGE_T:
		return false
	stuck_t = 0.0
	var net := Vector2(at.x - win_from.x, at.z - win_from.z).length()      # net, so a jiggle in a corner is no progress
	return net < WEDGE_M and free_cd <= 0.0


## Choose the way out: the clearest of sideways (the wish's side first), back-and-aside and straight back.
func way_out(space: PhysicsDirectSpaceState3D, skip: Array[RID], origin: Vector3, fwd: Vector3, wish: Vector3, sc: float) -> void:
	var right := fwd.cross(Vector3.UP)
	var first := signf(wish.dot(right))
	if first == 0.0:
		first = side
	var cands: Array[Vector3] = [right * first, right * -first, (right * first - fwd).normalized(), (right * -first - fwd).normalized(), -fwd]
	var pick := cands[cands.size() - 1]
	var ex: Array[RID] = skip.duplicate()
	ex.append_array(soft)
	for c in cands:
		var clear := true
		for h in [0.5 * sc, 1.2 * sc]:
			var from: Vector3 = origin + Vector3.UP * float(h)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + c * 1.8 * sc, Layers.WORLD | Layers.PROPS, ex))
			if not hit.is_empty() and (hit.normal as Vector3).y <= FLOOR_N:
				clear = false
				break
		if clear:
			pick = c
			break
	free_dir = pick
	free_t = FREE_T
	free_cd = FREE_T + FREE_CD
	head_t = 0.0
	stuck_t = 0.0
	side = -side
