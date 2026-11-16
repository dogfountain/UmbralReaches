extends RefCounted
## An enemy at rest and up again (Enemy.sleep / Enemy.wake: the spawner, the encounter director, rares and
## guardians call them as the wanderer leaves or comes inside its sleep_range). Asleep it does not process,
## and its body's meshes are drawn to REST_DRAW from the camera, fading out over REST_FADE; awake it is drawn
## as far as the camera sees. Luke, 16 Nov: camp foes across the doubled Realm were drawn to 420 m (30 of the
## 34 foes in view at the fight bench's spot stood past 60 m, ~90 draws). Bosses keep their full range; the
## health plate and its beads keep BAR_RANGE. A grunt skin past its body's end parks (grunt_skin.gd).
## FadeGuard pushes every range out by its RANGE_K (1.5) and widens the band, so on screen a resting foe ends at
## ~112 m and is gone by ~130 m. Fight bench census at its spot: foes in view past 120 m 24 -> 5 (the awake ones),
## their surfaces 71 -> 22, shadow casters 25 -> 1, the main pass's primitives 1,889k -> 1,739k.
## Load by path (no class_name).

const REST_DRAW := 75.0                ## before FadeGuard's push (~112 m on screen)
const REST_FADE := 10.0


static func wake(e: Enemy, bar: Node, pips: Array) -> void:
	e.visible = true
	e.process_mode = Node.PROCESS_MODE_INHERIT
	_draw_range(e, false, bar, pips)


static func sleep(e: Enemy, bar: Node, pips: Array) -> void:
	e.visible = true
	e.process_mode = Node.PROCESS_MODE_DISABLED
	_draw_range(e, true, bar, pips)


## On: each body mesh ends at REST_DRAW (or its own nearer end) and fades; off: its own range back. The
## meshes and their own ranges are looked up once, at the first call, and kept on the enemy's meta.
static func _draw_range(e: Enemy, on: bool, bar: Node, pips: Array) -> void:
	on = on and not e.boss                    # (an enemy made a boss after its first sleep gets its range back)
	if on == bool(e.get_meta(&"rest_capped", false)):
		return
	e.set_meta(&"rest_capped", on)
	var meshes: Array = e.get_meta(&"rest_meshes", [])
	if meshes.is_empty():
		for n in e.find_children("*", "GeometryInstance3D", true, false):
			if n == bar or (n is MeshInstance3D and pips.has(n)):    # (pips are typed: a particle system errors there)
				continue
			var g := n as GeometryInstance3D
			meshes.append([g, g.visibility_range_end, g.visibility_range_end_margin, g.visibility_range_fade_mode])
		e.set_meta(&"rest_meshes", meshes)
	for r: Array in meshes:
		if not is_instance_valid(r[0]):
			continue
		var g := r[0] as GeometryInstance3D
		if on:
			var own := float(r[1])
			g.visibility_range_end = REST_DRAW if own <= 0.0 else minf(own, REST_DRAW)
			g.visibility_range_end_margin = REST_FADE
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		else:
			g.visibility_range_end = float(r[1])
			g.visibility_range_end_margin = float(r[2])
			g.visibility_range_fade_mode = r[3]
