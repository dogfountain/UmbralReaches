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

const MIN_BAND := 3.0                 ## metres: a fade over less reads as a pop at walking speed
const RANGE_K := 1.35                 ## push ranges out (was 1.5); still early, less mid-distance double-draw
const FAR_CAP := 400.0                ## no range past the camera's far plane (FarDetail.VIEW_FAR 420)
const BAND_K := 0.18                  ## the band, as a share of the range
const BAND_MIN := 8.0
const BAND_MAX := 24.0


var _tracked: Array[GeometryInstance3D] = []
var _i := 0
const CHECK_PER_FRAME := 40           ## tracked meshes re-checked a frame (~8k ranged: each about every 3 s; 400 cost 0.37 ms)


static func attach(root: Node) -> void:
	var tree := root.get_tree()
	if tree == null or root.has_meta(&"fade_guard"):
		return
	root.set_meta(&"fade_guard", true)
	if "--no-fade-guard" in OS.get_cmdline_user_args():
		return                                         # A/B: perf tours
	var guard := (load("res://core/world/fade_guard.gd") as GDScript).new() as Node
	guard.name = "FadeGuard"
	root.add_child(guard)


func _ready() -> void:
	get_tree().node_added.connect(_on_added)


func _on_added(n: Node) -> void:
	if n is GeometryInstance3D:
		_tracked.append(n as GeometryInstance3D)
		_fix_later.call_deferred(weakref(n))


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


func _fix_later(w: WeakRef) -> void:
	var n: Object = w.get_ref()
	if n != null:
		_fix(n as Node)                             # (a mesh freed in the frame it entered passes nothing)


## Every instance under `root` (the sweep after the Realm's build).
static func sweep(root: Node) -> int:
	if "--no-fade-guard" in OS.get_cmdline_user_args():
		return 0
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
	var applied: Variant = g.get_meta(&"range_k") if g.has_meta(&"range_k") else null   # (a null default errors)
	if not (applied is Vector2 and is_equal_approx((applied as Vector2).x, begin) and is_equal_approx((applied as Vector2).y, end)):
		var rk := _range_k()
		if end > 0.0:
			end = minf(end * rk, FAR_CAP)
			g.visibility_range_end = end
		if begin > 0.0:
			begin = minf(begin * rk, FAR_CAP - 20.0)
			g.visibility_range_begin = begin
		g.set_meta(&"range_k", Vector2(begin, end))
	# Near half of a near/far swap: still needs its end to dissolve (a hard cut here was a canopy pop).
	# Do not strip an existing end fade just because a stand-in sibling exists.
	if begin <= 0.0 and p != null and _has_standin(p):
		var fading_near := g.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if end > 0.0 and (not fading_near or g.visibility_range_end_margin < MIN_BAND):
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			g.visibility_range_end_margin = maxf(g.visibility_range_end_margin, clampf(end * BAND_K, BAND_MIN, BAND_MAX))
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
	if p.has_meta(&"fade_standin"):
		return bool(p.get_meta(&"fade_standin"))
	var has := false
	for c in p.get_children():
		var cg := c as GeometryInstance3D
		if cg != null and cg.visibility_range_begin > 0.0:
			has = true
			break
	p.set_meta(&"fade_standin", has)
	return has


static var _rk := -1.0


## RANGE_K, or `--range-k=` (A/B in perf tours).
static func _range_k() -> float:
	if _rk < 0.0:
		_rk = RANGE_K
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--range-k="):
				_rk = float(a.trim_prefix("--range-k="))
	return _rk
