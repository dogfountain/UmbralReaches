extends Node
## Pop-in guard and draw distance: every ranged mesh's range is pushed out by RANGE_K, and every GeometryInstance3D that enters the world with a visibility range it crosses with no fade
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
const RANGE_K := 1.5                  ## every range pushed out this far (Luke, 7 Nov: things should show sooner). A
                                      ## near mesh's end and its far stand-in's begin move together, so swaps line up
const FAR_CAP := 400.0                ## no range past the camera's far plane (FarDetail.VIEW_FAR 420)
const BAND_K := 0.15                  ## the band, as a share of the range
const BAND_MIN := 6.0
const BAND_MAX := 18.0


var _tracked: Array[GeometryInstance3D] = []
var _i := 0
const CHECK_PER_FRAME := 400          ## tracked meshes re-checked a frame (~8k ranged: each about every 20 frames)


static func attach(root: Node) -> void:
	var tree := root.get_tree()
	if tree == null or root.has_meta(&"fade_guard"):
		return
	root.set_meta(&"fade_guard", true)
	var guard := (load("res://core/world/fade_guard.gd") as GDScript).new() as Node
	guard.name = "FadeGuard"
	root.add_child(guard)


func _ready() -> void:
	get_tree().node_added.connect(_on_added)


func _on_added(n: Node) -> void:
	if n is GeometryInstance3D:
		_tracked.append(n as GeometryInstance3D)
		_fix.call_deferred(n)


## A builder may set a range after the mesh entered (FarDetail.near_ends runs once the far stand-in exists): every
## tracked mesh is re-checked in turn, and one whose range is no longer what was applied is scaled from its new value.
## Both halves of a near / far swap so always end up on the same scale.
func _process(_dt: float) -> void:
	var n := _tracked.size()
	if n == 0:
		return
	var k := mini(CHECK_PER_FRAME, n)
	var j := 0
	while j < k and not _tracked.is_empty():
		if _i >= _tracked.size():
			_i = 0
		var g := _tracked[_i]
		if not is_instance_valid(g):
			_tracked.remove_at(_i)
		else:
			if g.is_inside_tree():
				_fix(g)
			_i += 1
		j += 1


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
	# scale from the builder's value: the range this guard last applied is remembered, so a range still equal to it is
	# already scaled, and any other value is the builder's (new or changed) and is scaled now
	if begin > 0.0 and p != null:
		p.set_meta(&"fade_standin", true)
	var applied: Variant = g.get_meta(&"range_k", null)
	if not (applied is Vector2 and is_equal_approx((applied as Vector2).x, begin) and is_equal_approx((applied as Vector2).y, end)):
		if end > 0.0:
			end = minf(end * RANGE_K, FAR_CAP)
			g.visibility_range_end = end
		if begin > 0.0:
			begin = minf(begin * RANGE_K, FAR_CAP - 20.0)
			g.visibility_range_begin = begin
		g.set_meta(&"range_k", Vector2(begin, end))
	# the near half of a swap (its stand-in is a sibling that begins) keeps its own cut: two meshes dithering over the
	# same band punch the same holes, so the pair flickered out and back in as you walked through it
	if begin <= 0.0 and p != null and _has_standin(p):
		var orig: Variant = g.get_meta(&"fade_orig", null)
		if orig is Array:                             # faded here before its stand-in arrived: put the builder's cut back
			g.visibility_range_fade_mode = int(orig[0])
			g.visibility_range_end_margin = float(orig[1])
			g.remove_meta(&"fade_orig")
		return true
	var fading := g.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var pops_end := end > 0.0 and (not fading or g.visibility_range_end_margin < MIN_BAND)
	var pops_begin := begin > 0.0 and (not fading or g.visibility_range_begin_margin < MIN_BAND)
	if not pops_end and not pops_begin:
		return true
	if not g.has_meta(&"fade_orig"):
		g.set_meta(&"fade_orig", [g.visibility_range_fade_mode, g.visibility_range_end_margin])
	g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if end > 0.0:
		g.visibility_range_end_margin = maxf(g.visibility_range_end_margin, clampf(end * BAND_K, BAND_MIN, BAND_MAX))
	if begin > 0.0:
		g.visibility_range_begin_margin = maxf(g.visibility_range_begin_margin, clampf(begin * BAND_K, BAND_MIN, BAND_MAX))
	return true


## Does `p` hold a stand-in (a mesh whose range begins)? Cached on the parent; a parent that later gains one is seen
## when that one is fixed (it marks its parent).
static func _has_standin(p: Node) -> bool:
	var v: Variant = p.get_meta(&"fade_standin", null)
	if v != null:
		return bool(v)
	var has := false
	for c in p.get_children():
		var cg := c as GeometryInstance3D
		if cg != null and cg.visibility_range_begin > 0.0:
			has = true
			break
	p.set_meta(&"fade_standin", has)
	return has
