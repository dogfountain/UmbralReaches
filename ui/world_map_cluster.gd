extends RefCounted
## Pins that crowd one another on the sheet become one pin with a count. A hamlet's six task marks, a ridge of lamps, the
## rares of one country: at the whole-map zoom each group is drawn once (its first mark, with a small badge of how many),
## and the hover finds the group's first; zoom in and the pixels between marks grow, so the group comes apart by itself.
## The wanderer, bosses and the followed task are never folded in.
## Load by path (no class_name): const MapCluster := preload("res://ui/world_map_cluster.gd")

const NEVER := ["you", "boss", "boss_down", "quest_target"]
const RADIUS := 17.0                       ## screen px within which two marks of one kind are one pin


## For each mark: 0 drawn, 1 folded into an earlier one. `count[i]` is how many marks the pin at i stands for (1 = just itself).
static func fold(marks: Array[Dictionary], to_screen: Callable, view: Rect2) -> Dictionary:
	var hide := PackedByteArray()
	hide.resize(marks.size())
	var count := PackedInt32Array()
	count.resize(marks.size())
	var leaders: Dictionary = {}                 # kind -> Array of [index, screen pos]
	for i in marks.size():
		count[i] = 1
		var kind := String(marks[i].kind)
		if kind in NEVER or float(marks[i].get("radius", 0.0)) > 0.0:
			continue
		var p: Vector2 = to_screen.call(marks[i].at)
		if not view.has_point(p):
			continue
		var list: Array = leaders.get(kind, [])
		var joined := false
		for l: Array in list:
			if (l[1] as Vector2).distance_to(p) < RADIUS:
				hide[i] = 1
				count[int(l[0])] += 1
				joined = true
				break
		if not joined:
			list.append([i, p])
			leaders[kind] = list
	return {"hide": hide, "count": count}


## A small round badge with the group's size, at the pin's upper right.
static func badge(c: Control, at: Vector2, n: int, font: Font) -> void:
	if n < 2:
		return
	var o := at + Vector2(9.0, -9.0)
	c.draw_circle(o, 8.5, Color(0.14, 0.08, 0.05, 0.96))
	c.draw_arc(o, 8.5, 0.0, TAU, 20, Color(1.0, 0.76, 0.28, 0.95), 1.4, true)
	var s := str(n) if n < 100 else "99"
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	c.draw_string(font, o + Vector2(-w * 0.5, 4.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.92, 0.7))
