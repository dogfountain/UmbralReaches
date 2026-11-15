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

var _boss: Node3D = null
var _far: Array = []                ## [GeometryInstance3D, end as found] the @far trees and cards
var _shells: Array = []             ## [MeshInstance3D, begin as found]


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
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var alive := _boss != null and is_instance_valid(_boss) and _boss.is_inside_tree() and not _boss.is_queued_for_deletion()
	if not alive or p == null or _boss.global_position.distance_to(p.global_position) > REACH:
		thin(false)


func thin(on: bool) -> void:
	if not on:
		_boss = null
	set_process(on)
	var host := get_parent()
	if host == null or bool(host.get_meta(&"fight", false)) == on:
		return
	host.set_meta(&"fight", on)
	Emit.apply_detail(host, clampi(Settings.detail, 0, 2))
	if _far.is_empty() and _shells.is_empty():
		_collect(host)
	for e: Array in _far:
		if is_instance_valid(e[0]):
			var g := e[0] as GeometryInstance3D
			g.visibility_range_end = float(e[1]) * (FAR_K if on else 1.0)
			_applied(g)
	for e: Array in _shells:
		if is_instance_valid(e[0]):
			var g := e[0] as GeometryInstance3D
			g.visibility_range_begin = float(e[1]) * (SHELL_K if on else 1.0)
			_applied(g)


## fade_guard.gd scales any range it did not set itself: these are already on its scale, so mark them as applied.
static func _applied(g: GeometryInstance3D) -> void:
	if g.has_meta(&"range_k"):
		g.set_meta(&"range_k", Vector2(g.visibility_range_begin, g.visibility_range_end))


func _collect(host: Node) -> void:
	for n in host.find_children("Flora_*", "MultiMeshInstance3D", true, false):
		var f: Array = n.get_meta(&"flora", [])
		if f.size() > 1 and (f[1] == "fs" or f[1] == "fc") and (n as GeometryInstance3D).visibility_range_end > 0.0:
			_far.append([n, (n as GeometryInstance3D).visibility_range_end])
	for n in host.find_children("Canopy_*", "MeshInstance3D", true, false):
		if (n as GeometryInstance3D).visibility_range_begin > 0.0:
			_shells.append([n, (n as GeometryInstance3D).visibility_range_begin])
