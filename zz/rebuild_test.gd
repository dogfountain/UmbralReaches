extends Node
## The night built twice in one process, as the Deeper Night (encounters/director.gd
## begin_deeper_night -> Travel.go to the same scene) does: does the second Realm come up whole?
## Compares build counts (flora, lore sites, secrets, camps, braziers, seals, arenas) and probes the
## ground at landmarks after the second build; any SCRIPT ERROR in between shows in the log.
##   HOME=<scratch> godot --headless --path . res://zz/rebuild_test.tscn
## Holds Travel._busy except for the travel itself (isolated HOME only); quits itself (150 s cap).
var main: Node
var t := 0.0
var phase := 0
var first := {}
var bad := 0
var _names: Array = []
const PROBES := [Vector3(0, 0, 30), Vector3(0, 0, -2), Vector3(-72, 0, -18), Vector3(34, 0, -66), Vector3(0, 0, -83.5), Vector3(-60, 0, 40), Vector3(80, 0, -20)]


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_make_current.call_deferred()


func _make_current() -> void:
	get_tree().current_scene = main


func _process(d: float) -> void:
	t += d
	if t > 150.0:
		_ok(false, "timed out in phase %d" % phase)
		_finish()
		return
	match phase:
		0:
			Travel._busy = true
			if main and main.has_meta("realm_done") and t > 3.0:
				first = _census(main)
				print("REBUILD first ", first)
				phase = 1
				Travel._busy = false
				var p := get_tree().get_first_node_in_group(Groups.PLAYER)
				Travel.go("res://world/main.tscn", RealmLayout.PLAYER_START, 0.0, p)
		1:
			var cur := get_tree().current_scene
			if cur != null and cur != main and is_instance_valid(cur) and cur.has_meta("realm_done") and not Travel.busy():
				Travel._busy = true
				main = cur
				phase = 2
				t = minf(t, 140.0)
				await get_tree().create_timer(1.0).timeout
				var second := _census(main)
				print("REBUILD second ", second)
				for k: String in first:
					var a: int = first[k]
					var b: int = second.get(k, -1)
					# top-level nodes and multimeshes include transient sound voices and effects: within 2 %
					var loose := k in ["flora", "multimesh", "nodes", "lights"]
					_ok(b == a or (loose and absi(b - a) <= maxi(8 if k == "nodes" else 2, a / 50)), "%s: %d then %d" % [k, a, b])
				var space := (main as Node3D).get_world_3d().direct_space_state
				for v: Vector3 in PROBES:
					var q := PhysicsRayQueryParameters3D.create(v + Vector3.UP * 80.0, v + Vector3.DOWN * 60.0, Layers.WORLD)
					_ok(not space.intersect_ray(q).is_empty(), "ground at %s after the rebuild" % v)
				for nm: String in _names[1]:
					if int(_names[1][nm]) != int(_names[0].get(nm, 0)):
						print("REBUILD top-level %s: %d then %d" % [nm, int(_names[0].get(nm, 0)), int(_names[1][nm])])
				var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
				_ok(p != null and p.global_position.distance_to(RealmLayout.PLAYER_START) < 4.0, "the wanderer is at the start (%s)" % (p.global_position if p else Vector3.ZERO))
				_ok(get_tree().get_nodes_in_group(Groups.PLAYER).size() == 1, "one player")
				_finish()
			else:
				Travel._busy = Travel.busy()


func _census(root: Node) -> Dictionary:
	var out := {"braziers": 0, "seals": 0, "arenas": 0, "lights": 0, "bodies": 0, "multimesh": 0}
	for n in root.find_children("*", "", true, false):
		if n is Brazier:
			out.braziers += 1
		elif n is WardSeal:
			out.seals += 1
		elif n is BossArena:
			out.arenas += 1
		elif n is Light3D:
			out.lights += 1
		elif n is StaticBody3D:
			out.bodies += 1
		elif n is MultiMeshInstance3D:
			out.multimesh += 1
	out["flora"] = (load("res://core/world/realm/realm_flora.gd") as GDScript).instance_list().size()
	out["sites"] = WorldLanes.sites.size()
	out["secrets"] = (load("res://core/life/secrets/state.gd") as GDScript).get("sites").size()
	out["camps"] = EnemySpawner._seal_camps.size()
	# r34 layout: Vfx bursts (core/vfx/vfx.gd, pooled one-shot emitters parented to the scene, meta
	# "burst_token") are transient: the Thornwood's breath vent (core/life/secrets/breath_vent.gd) puffs
	# a new one every ~130 ms in its active phase, so the top-level count swung by 9 with the census'
	# timing (first census 3 s after the build, the second 1 s). They are not part of the built world.
	var kept: Array[Node] = []
	for c in root.get_children():
		if not (c is GPUParticles3D and c.has_meta(&"burst_token")):
			kept.append(c)
	out["nodes"] = kept.size()
	var names := {}
	for c in kept:
		var nm := String(c.name).rstrip("0123456789").trim_suffix("@")
		names[nm] = int(names.get(nm, 0)) + 1
	_names.append(names)
	return out


func _ok(cond: bool, what: String) -> void:
	print(("REBUILD ok   " if cond else "REBUILD FAIL ") + what)
	if not cond:
		bad += 1


func _finish() -> void:
	set_process(false)
	Travel._busy = true
	print("REBUILD done bad=%d" % bad)
	get_tree().quit()
