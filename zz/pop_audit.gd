extends Node
## Pop-in audit: once the Realm is built and has settled, every GeometryInstance3D with a visibility range is checked
## for an edge it crosses with no fade. Such an instance switches on or off in one frame as you walk (pop-in).
##   godot --headless --path . res://zz/pop_audit.tscn [-- --verbose]
## An edge pops when its range is set but its fade is off, or its margin is under MIN_MARGIN. Counted per owner
## (the nearest named ancestor) so the source that set it can be found.

const MIN_MARGIN := 2.0               ## metres: a dither fade over less than this reads as a pop at walking speed

var main: Node
var frames := 0
var verbose := false


func _ready() -> void:
	verbose = "--verbose" in OS.get_cmdline_user_args()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	frames += 1
	if frames == 3600 * 3:
		print("POP FAIL realm never built")
		get_tree().quit(1)
	if main == null or not main.has_meta("realm_built") or frames < 600:
		return
	if frames != 900:
		return
	var by_src := {}
	var total := 0
	var popping := 0
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visibility_range_end <= 0.0 and g.visibility_range_begin <= 0.0:
			continue
		if g.get_instance_shader_parameter(&"fade_end") != null or (g.get_parent() != null and String(g.get_parent().name) == "ForestFloor"):
			continue                  # thinned plant by plant in the shader (fade_guard.gd leaves these too)
		total += 1
		var why := ""
		var fade := g.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if g.visibility_range_end > 0.0 and (not fade or g.visibility_range_end_margin < MIN_MARGIN):
			why = "end %.0f m, margin %.1f, fade %s" % [g.visibility_range_end, g.visibility_range_end_margin, fade]
		elif g.visibility_range_begin > 0.0 and (not fade or g.visibility_range_begin_margin < MIN_MARGIN):
			why = "begin %.0f m, margin %.1f, fade %s" % [g.visibility_range_begin, g.visibility_range_begin_margin, fade]
		if why == "":
			continue
		popping += 1
		var src := _source(g)
		if not by_src.has(src):
			by_src[src] = [0, why, String(g.get_path())]
		by_src[src][0] += 1
	var keys := by_src.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(by_src[a][0]) > int(by_src[b][0]))
	for k: Variant in keys:
		print("POP %5d  %-34s %s   e.g. %s" % [by_src[k][0], k, by_src[k][1], by_src[k][2] if verbose else ""])
	print("POP %d of %d ranged instances pop (no fade, or a margin under %.0f m)" % [popping, total, MIN_MARGIN])
	get_tree().quit(0)


## The nearest ancestor with a script, else the parent's name: where the range was set.
func _source(g: Node) -> String:
	var n := g
	while n != null and n != main:
		var s: Script = n.get_script()
		if s != null and n != g:
			return String(s.resource_path).get_file()
		n = n.get_parent()
	var p := g.get_parent()
	return String(p.name) if p else "-"
