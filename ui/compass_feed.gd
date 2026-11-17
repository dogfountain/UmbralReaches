extends RefCounted
## What the compass strip shows, and why (the compass doc (docs, compass.md)). The old strip drew every beacon, the four nearest fires
## and the tracked step all at once: a strip of gold diamonds that said nothing. This is the relevance filter between the
## world and the strip. Static and pure: `gather()` reads the tree once (the compass calls it twice a second) and returns
## the few candidates worth a mark NOW, each with the range it fades out over; `fold()` merges the ones that would
## overlap on the strip. The compass only draws.
##
## Kinds, strongest first (the strip keeps the first of any that would sit on each other):
##   goal      the followed task's step: always, at any range, with its distance
##   danger    a great one's arena not yet fallen, a rare foe awake: a red wedge, near only
##   fire      the nearest fire (two on Full) but only when one is WANTED: Gloom over a third of the bar, wounds
##             under half, or the wanderer's own state asks for a rest; otherwise none (Full: the nearest one near)
##   tasker    a quest giver / turn-in near (Standard 90 m, Full 160 m)
##   mark      the wanderer's own marks (core/story/wayfarer.gd, WayMark nodes): at any sensible range, the nearest 2-4, fading late
##   beacon    a lit far beacon (landmark_beacon group): Full draws a small diamond with a range; Standard a faint tick
##             (the 3 nearest, to 300 m); Minimal none unless there is no goal and it is close
## Every mark fades over the last 40 % of its range; nothing past its range is drawn unless it is the goal.
## No class_name: preload by path.

const MINIMAL := 0
const STANDARD := 1
const FULL := 2

const FIRE_NEED_GLOOM := 0.34
const FIRE_NEED_WOUNDS := 0.5
const MERGE_PX := 17.0

## Per kind and density: [range m, max count]
const RULES := {
	"danger": [[70.0, 1], [140.0, 2], [200.0, 3]],
	"fire": [[0.0, 0], [170.0, 1], [220.0, 2]],
	"fire_idle": [[0.0, 0], [0.0, 0], [60.0, 1]],
	"tasker": [[0.0, 0], [90.0, 2], [160.0, 3]],
	"beacon": [[110.0, 1], [300.0, 3], [380.0, 5]],
	"mark": [[900.0, 2], [1200.0, 3], [2000.0, 4]],
}


## [{pos, kind, col, art, d (flat metres), range, name}] for the strip, nearest first within a kind.
static func gather(tree: SceneTree, eye: Vector3, density: int, goal: Dictionary, player: Node, you: Vector3) -> Array[Dictionary]:
	density = clampi(density, 0, 2)
	var out: Array[Dictionary] = []
	var flat := func(p: Vector3) -> float: return Vector2(p.x - you.x, p.z - you.z).length()
	var have_goal := false
	if goal.get("target", Vector3.INF) != Vector3.INF:
		have_goal = true
		var tg: Vector3 = goal.target
		out.append({"pos": tg, "kind": "goal", "col": Color("#FFB347"), "art": String(goal.get("art", "followed")), "d": float(flat.call(tg)), "range": INF})
	# danger: arenas of great ones not yet fallen, rare foes
	var dr: Array = RULES.danger[density]
	var dng: Array[Dictionary] = []
	for a in tree.get_nodes_in_group(&"boss_arena"):
		var n := a as Node3D
		if n == null or not n.is_inside_tree() or not ("boss_id" in n) or Travel.bosses_slain.has(String(n.get("boss_id"))):
			continue
		var d: float = flat.call(n.global_position)
		if d <= float(dr[0]):
			dng.append({"pos": n.global_position, "kind": "danger", "col": Color(0.92, 0.32, 0.26), "d": d, "range": float(dr[0])})
	for m in tree.get_nodes_in_group(&"map_marker"):
		var n3 := m as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.has_meta(&"map_kind"):
			continue
		var kind := String(n3.get_meta(&"map_kind"))
		var d3: float = flat.call(n3.global_position)
		if kind == "rare" and n3.is_visible_in_tree() and d3 <= float(dr[0]):
			dng.append({"pos": n3.global_position, "kind": "danger", "col": Color(0.82, 0.86, 1.0), "d": d3, "range": float(dr[0])})
	_take(out, dng, int(dr[1]))
	# fires: only when one is wanted
	var wanted := false
	if player != null:
		var gm := float(player.get("gloom_max")) if "gloom_max" in player else 0.0
		var wm := float(player.get("wounds_max")) if "wounds_max" in player else 0.0
		if gm > 0.0 and float(player.get("gloom")) > gm * FIRE_NEED_GLOOM:
			wanted = true
		if wm > 0.0 and float(player.get("wounds")) < wm * FIRE_NEED_WOUNDS:
			wanted = true
	var fr: Array = RULES.fire[density] if wanted else RULES.fire_idle[density]
	if int(fr[1]) > 0:
		var fires: Array[Dictionary] = []
		for n in tree.get_nodes_in_group(Groups.BRAZIER):
			var b3 := n as Node3D
			if b3 == null or not b3.is_inside_tree():
				continue
			var d4: float = flat.call(b3.global_position)
			if d4 <= float(fr[0]):
				var lit := bool(b3.get("lit")) if "lit" in b3 else false
				fires.append({"pos": b3.global_position, "kind": "fire", "col": Color("#FFB347") if lit else Color("#FF6A2A"), "lit": lit, "d": d4, "range": float(fr[0]), "need": wanted})
		_take(out, fires, int(fr[1]))
	# taskers
	var tk: Array = RULES.tasker[density]
	if int(tk[1]) > 0:
		var ts: Array[Dictionary] = []
		for m in tree.get_nodes_in_group(&"map_marker"):
			var n5 := m as Node3D
			if n5 == null or not n5.is_inside_tree() or not n5.has_meta(&"map_kind"):
				continue
			var k5 := String(n5.get_meta(&"map_kind"))
			if k5 != "quest_available" and k5 != "quest_turnin":
				continue
			var d5: float = flat.call(n5.global_position)
			if d5 <= float(tk[0]):
				ts.append({"pos": n5.global_position, "kind": "tasker", "turnin": k5 == "quest_turnin", "col": Color("#FFD27A"), "d": d5, "range": float(tk[0])})
		_take(out, ts, int(tk[1]))
	# far beacons
	var bk: Array = RULES.beacon[density]
	var bs: Array[Dictionary] = []
	var mk: Array = RULES.mark[density]
	var mine: Array[Dictionary] = []
	for b in tree.get_nodes_in_group(&"landmark_beacon"):
		if not is_instance_valid(b) or b.is_queued_for_deletion() or not ("anchor" in b):
			continue
		var ap: Vector3 = b.get("anchor")
		var d6: float = flat.call(ap)
		if String(b.name).begins_with("WayMark"):
			if d6 > 8.0 and d6 <= float(mk[0]):
				mine.append({"pos": ap, "kind": "mark", "col": (b.get("tint") as Color) if "tint" in b else Color(0.86, 0.92, 1.0), "d": d6, "range": float(mk[0])})
			continue
		if d6 < 14.0 or d6 > float(bk[0]):
			continue
		if density == MINIMAL and have_goal:
			continue
		bs.append({"pos": ap, "kind": "beacon", "col": (b.get("tint") as Color) if "tint" in b else Color("#FFB347"), "d": d6, "range": float(bk[0])})
	_take(out, bs, int(bk[1]))
	_take(out, mine, int(mk[1]))
	return out


static func _take(out: Array[Dictionary], list: Array[Dictionary], n: int) -> void:
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.d) < float(b.d))
	for i in mini(n, list.size()):
		out.append(list[i])


## Fade by distance: full inside 60 % of the range, to nothing at the range; the goal never fades.
static func fade(m: Dictionary) -> float:
	var r := float(m.range)
	if r == INF:
		return 1.0
	return 1.0 - smoothstep(r * 0.6, r, float(m.d))


## Merge marks that would overlap: `shown` = [{x, kind, d, ...}] sorted by priority; a mark within MERGE_PX of a stronger
## one of the same kind folds into it (count + 1) and a weaker kind on a stronger one gives way. Returns the kept ones.
static func fold(shown: Array[Dictionary], px: float = MERGE_PX) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for m: Dictionary in shown:
		var hit := false
		for k: Dictionary in kept:
			if absf(float(k.x) - float(m.x)) < px:
				if String(k.kind) == String(m.kind):
					k["count"] = int(k.get("count", 1)) + 1
				hit = true
				break
		if not hit:
			m["count"] = int(m.get("count", 1))
			kept.append(m)
	return kept
