extends "res://zz/free_shots.gd"
## Vista stills: free_shots' views (--view= / --stand= / --kindle), with the free camera kept current every
## frame (a discovery or region camera could take the view over after a few shots, and every later still
## came out the same), an optional field of view (--fov=deg) and --light-beacons (every March beacon's lamp lit
## as its leader would light it: no save, no ash; realm_vistas.gd).
##   godot --path . res://zz/vista_shots.tscn -- --out=<dir> --tag=a --view=name:cx:cy:cz:tx:ty:tz ...

var _beacons_lit := false


func _hold() -> void:
	super._hold()
	if cam != null and not cam.current:
		cam.make_current()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fov=") and cam != null:
			cam.fov = float(a.trim_prefix("--fov="))
		elif a == "--light-beacons" and not _beacons_lit:
			_beacons_lit = true
			for b in get_tree().get_nodes_in_group(&"vista_beacon"):
				var lamp: Variant = b.get("lamp")
				if lamp != null:
					(lamp as Lamp).light_from_leader(false)
