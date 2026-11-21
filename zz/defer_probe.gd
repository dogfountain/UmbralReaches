extends Node
## --defer-probe (zz/perf_tour.gd): who spends a frame's deferred flush. The tour's --hitches splits a slow frame into
## scripts, the deferred flush ("def"), the pre-draw and the draw; the flush is where every queued redraw runs its
## _draw (the HUD, the minimap, the baked layers' art), every Skeleton3D posed this frame updates, and every call_deferred
## runs. This stamps each CanvasItem's `draw` signal and each Skeleton3D's `skeleton_updated`, and on a frame whose flush
## ran over --defer-ms (default 8) prints the widest gaps between consecutive stamps:
##   "DEFER t <s> flush <ms>: <A> -> <B> <ms>, ..."   (a draw signal fires before its item's own _draw and after the
##   handlers connected before this probe: a baked layer's art lands in the gap that ends at its canvas's stamp)
## plus how many items redrew and skeletons updated, and their share. Load by path.

var tour: Node
var _st: Array = []                      ## [usec, label, kind] this frame's stamps
var _hooked := {}
var _ms := 8.0
var _left := 300
var _scan_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--defer-ms="):
			_ms = float(a.trim_prefix("--defer-ms="))
	_hook_all()


## Every CanvasItem and Skeleton3D in the tree, and every one added later.
func _hook_all() -> void:
	for n in get_tree().root.find_children("*", "", true, false):
		_hook(n)
	get_tree().node_added.connect(_hook)


func _hook(n: Node) -> void:
	var id := n.get_instance_id()
	if _hooked.has(id):
		return
	if n is Container:
		_hooked[id] = true
		(n as Container).pre_sort_children.connect(_stamp.bind(n, 2))      # a container's layout pass (sorting its children)
		(n as CanvasItem).draw.connect(_stamp.bind(n, 0))
	elif n is CanvasItem:
		_hooked[id] = true
		(n as CanvasItem).draw.connect(_stamp.bind(n, 0))
	elif n is Skeleton3D:
		_hooked[id] = true
		(n as Skeleton3D).skeleton_updated.connect(_stamp.bind(n, 1))


func _stamp(n: Node, kind: int) -> void:
	_st.append([Time.get_ticks_usec(), n, kind])


func _label(n: Variant) -> String:
	if not is_instance_valid(n):
		return "(freed)"
	var nd := n as Node
	var p := nd.get_parent()
	var sc: Script = nd.get_script()
	return "%s/%s%s" % [p.name if p else "?", nd.name, ("(" + sc.resource_path.get_file() + ")") if sc else ""]


## Called by the tour once a frame with the flush's ends (usec): the process's end and the deferred mark.
func frame(t_from: int, t_to: int, now_s: float) -> void:
	var st := _st
	_st = []
	if t_to <= t_from or float(t_to - t_from) / 1000.0 < _ms or _left <= 0:
		return
	_left -= 1
	var gaps: Array = []
	var prev_t := t_from
	var prev_l := "(flush start)"
	var draws := 0
	var skels := 0
	var skel_us := 0
	var sorts := 0
	for s: Array in st:
		var t := int(s[0])
		if t < t_from or t > t_to:
			continue
		var l := _label(s[1])
		gaps.append([t - prev_t, prev_l + " -> " + l])
		if int(s[2]) == 1:
			skels += 1
			skel_us += t - prev_t
		elif int(s[2]) == 2:
			sorts += 1
			l = "sort:" + l
		else:
			draws += 1
		prev_t = t
		prev_l = l
	gaps.append([t_to - prev_t, prev_l + " -> (flush end)"])
	gaps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var txt := PackedStringArray()
	for g: Array in gaps.slice(0, 5):
		txt.append("%s %.1f" % [g[1], g[0] / 1000.0])
	print("DEFER t %.2f flush %.1f ms: %d redraws, %d container sorts, %d skeletons (gaps ending at a skeleton %.1f ms) | %s" % [now_s,
		(t_to - t_from) / 1000.0, draws, sorts, skels, skel_us / 1000.0, ", ".join(txt)])
