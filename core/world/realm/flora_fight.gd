extends Node3D
## Lives under RealmFlora. While a great one is fought (Events.boss_engaged, until it falls, the
## wanderer dies or walks REACH away) the undergrowth draws nearer and thinner (flora_emit
## FIGHT_DENSITY / FIGHT_RANGE), and the far woods come in: the @far trees and far leaf cards end at
## FAR_K of their range and the canopy shell begins at SHELL_K of its own (the overlap kept), so boss
## fights hold 120 fps (Luke, 15 Nov). Other fights keep the full look. Load by path.

const Emit := preload("res://core/world/realm/flora_emit.gd")
const REACH := 70.0
const FAR_K := 0.5
const SHELL_K := 0.55

const SLICE_US := 3000               ## per frame: the change is spread over a few frames (frame pacing, 16 Nov: in one
                                    ## frame it walked ~12k flora MultiMeshes, a 58 ms frame at the pull and at the fall)

var _boss: Node3D = null
var _far: Array = []                ## [GeometryInstance3D, end as found] the @far trees and cards
var _shells: Array = []             ## [MeshInstance3D, begin as found]
var _mmis: Array = []               ## every Flora_* MultiMesh (collected once with the lists above)
var _job := -1                      ## next item of the change under way (-1: none): _mmis, then _far, then _shells
var _job_on := false
var _job_args := Vector2.ONE        ## Emit.detail_args for the change under way
var _job_d := 2


func _ready() -> void:
	name = "FloraFight"
	Events.boss_engaged.connect(_on_engaged)
	Events.boss_slain.connect(func(_id: String) -> void: thin(false))
	Events.respawned.connect(func(_at: Vector3) -> void: thin(false))
	set_process(false)


func _on_engaged(b: Node, _title: String) -> void:
	if b is Node3D and not ("--no-fight-thin" in OS.get_cmdline_user_args()):   # (A/B in perf runs)
		_boss = b as Node3D
		thin(true)


func _process(_dt: float) -> void:
	if _job >= 0:
		_job_step()
	if _boss == null:
		if _job < 0:
			set_process(false)
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var alive := is_instance_valid(_boss) and _boss.is_inside_tree() and not _boss.is_queued_for_deletion()
	if not alive or p == null or _boss.global_position.distance_to(p.global_position) > REACH:
		thin(false)


## On (a boss engaged) or off. The host's metas change at once (Emit.apply_detail and the settings read them); the
## meshes follow over the next few frames, SLICE_US of work a frame.
func thin(on: bool) -> void:
	if not on:
		_boss = null
	var host := get_parent()
	if host == null or bool(host.get_meta(&"fight", false)) == on:
		set_process(on or _job >= 0)
		return
	host.set_meta(&"fight", on)
	var d := clampi(Settings.detail, 0, 2)
	host.set_meta(&"detail", d + (10 if on else 0))   # what Emit.apply_detail would note (a settings change re-applies all)
	if _mmis.is_empty() and _far.is_empty() and _shells.is_empty():
		_collect(host)
	_job_on = on
	_job_d = d
	_job_args = Emit.detail_args(d, on)
	_job = 0
	set_process(true)
	_job_step()                          # the first slice now


func _job_step() -> void:
	if clampi(Settings.detail, 0, 2) != _job_d:      # the detail setting changed under way: start over at the new level
		_job_d = clampi(Settings.detail, 0, 2)
		_job_args = Emit.detail_args(_job_d, _job_on)
		_job = 0
	var t0 := Time.get_ticks_usec()
	var n_m := _mmis.size()
	var n_f := _far.size()
	var n_s := _shells.size()
	while _job >= 0 and _job < n_m + n_f + n_s:
		if _job < n_m:
			Emit.detail_one(_mmis[_job] as MultiMeshInstance3D, _job_d, _job_args.x, _job_args.y)
		elif _job < n_m + n_f:
			var e: Array = _far[_job - n_m]
			if is_instance_valid(e[0]):
				var g := e[0] as GeometryInstance3D
				g.visibility_range_end = float(e[1]) * (FAR_K if _job_on else 1.0)
				_applied(g)
		else:
			var e: Array = _shells[_job - n_m - n_f]
			if is_instance_valid(e[0]):
				var g := e[0] as GeometryInstance3D
				g.visibility_range_begin = float(e[1]) * (SHELL_K if _job_on else 1.0)
				_applied(g)
		_job += 1
		if (_job & 63) == 0 and Time.get_ticks_usec() - t0 > SLICE_US:
			return
	_job = -1


## fade_guard.gd scales any range it did not set itself: these are already on its scale, so mark them as applied.
static func _applied(g: GeometryInstance3D) -> void:
	if g.has_meta(&"range_k"):
		g.set_meta(&"range_k", Vector2(g.visibility_range_begin, g.visibility_range_end))


func _collect(host: Node) -> void:
	for n in host.find_children("Flora_*", "MultiMeshInstance3D", true, false):
		_mmis.append(n)
		var f: Array = n.get_meta(&"flora", [])
		if f.size() > 1 and (f[1] == "fs" or f[1] == "fc") and (n as GeometryInstance3D).visibility_range_end > 0.0:
			_far.append([n, (n as GeometryInstance3D).visibility_range_end])
	for n in host.find_children("Canopy_*", "MeshInstance3D", true, false):
		if (n as GeometryInstance3D).visibility_range_begin > 0.0:
			_shells.append([n, (n as GeometryInstance3D).visibility_range_begin])
