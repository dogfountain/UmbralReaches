extends RefCounted
## Pop-in guard: every GeometryInstance3D that enters the world with a visibility range it crosses with no fade
## (fade off, or a band under MIN_BAND) gets a dither fade (FADE_SELF) over a band sized to its distance, so a
## prop, beast, villager or tree dissolves in and out instead of appearing in one frame. About twenty builders set
## ranges (props, rigs, lamps, the flora's near trees); one guard here covers them and anything spawned later.
## Checked at the end of the frame each node enters (builders set the range just after add_child), and once more
## over the whole tree when the Realm is built (Atmosphere's cull pass sets ranges after the build).
## Left alone:
##   - flora cards that thin plant by plant in their shader (instance uniform fade_end; an engine fade on them drew
##     the chunk alpha-blended, ~6 ms at the hub: flora_emit.gd _set_range);
##   - the forest-floor grass cells (alpha-scissor, ranged past the next cell on purpose: atmosphere.gd).
## zz/pop_audit.tscn counts what still pops.
## Load by path (no class_name).

const MIN_BAND := 2.0                 ## metres: a fade over less reads as a pop at walking speed
const BAND_K := 0.15                  ## the band, as a share of the range
const BAND_MIN := 6.0
const BAND_MAX := 18.0


static func attach(root: Node) -> void:
	var tree := root.get_tree()
	if tree == null or root.has_meta(&"fade_guard"):
		return
	root.set_meta(&"fade_guard", true)
	tree.node_added.connect(func(n: Node) -> void:
		if n is GeometryInstance3D:
			_fix.call_deferred(n))


## Every instance under `root` (the sweep after the Realm's build).
static func sweep(root: Node) -> int:
	var fixed := 0
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		if _fix(n):
			fixed += 1
	return fixed


static func _fix(n: Node) -> bool:
	var g := n as GeometryInstance3D
	if g == null or not is_instance_valid(g) or not g.is_inside_tree():
		return false
	var end := g.visibility_range_end
	var begin := g.visibility_range_begin
	if end <= 0.0 and begin <= 0.0:
		return false
	if g.get_instance_shader_parameter(&"fade_end") != null:
		return false
	var p := g.get_parent()
	if p != null and String(p.name) == "ForestFloor":
		return false
	var fading := g.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var pops_end := end > 0.0 and (not fading or g.visibility_range_end_margin < MIN_BAND)
	var pops_begin := begin > 0.0 and (not fading or g.visibility_range_begin_margin < MIN_BAND)
	if not pops_end and not pops_begin:
		return false
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if end > 0.0:
		g.visibility_range_end_margin = maxf(g.visibility_range_end_margin, clampf(end * BAND_K, BAND_MIN, BAND_MAX))
	if begin > 0.0:
		g.visibility_range_begin_margin = maxf(g.visibility_range_begin_margin, clampf(begin * BAND_K, BAND_MIN, BAND_MAX))
	return true
