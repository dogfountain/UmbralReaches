extends Node
## r34 places: ground maps round points (after the Realm, or `--realm-modules=land`):
##   HOME=<scratch> godot --headless --path . res://zz/places_r34_probe.tscn -- --realm-modules=land --pts=x,z;x,z [--r=16 --step=2]
## Prints one row per z: each cell the ground height rounded (water '~' under -0.75).
var main: Node
var t := 0.0
var done := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if done or main == null:
		return
	var ready := main.has_meta("realm_done") or (t > 8.0 and main.get_node_or_null("RealmTerrain") != null) or t > 30.0
	if not ready:
		return
	done = true
	await get_tree().create_timer(1.0).timeout
	var space := (main as Node3D).get_world_3d().direct_space_state
	var r := 16.0
	var step := 2.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--r="):
			r = float(a.trim_prefix("--r="))
		elif a.begins_with("--step="):
			step = float(a.trim_prefix("--step="))
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--pts="):
			continue
		for s: String in a.trim_prefix("--pts=").split(";"):
			var v := s.split(",")
			var cx := float(v[0])
			var cz := float(v[1])
			print("MAP at %s,%s (x %d..%d, step %.1f)" % [v[0], v[1], int(cx - r), int(cx + r), step])
			var z := cz - r
			while z <= cz + r + 0.01:
				var line := "%5d " % int(z)
				var x := cx - r
				while x <= cx + r + 0.01:
					var gy := RealmLayout.ground(space, x, z)
					line += "  ~" if gy < -0.75 else "%3d" % roundi(gy)
					x += step
				print("MAP ", line)
				z += step
	get_tree().quit(0)
