extends "res://zz/free_shots.gd"
## Vista stills: free_shots' views (--view= / --stand= / --kindle), with the free camera kept current every
## frame (a discovery or region camera could take the view over after a few shots, and every later still
## came out the same) and an optional field of view (--fov=deg).
##   godot --path . res://zz/vista_shots.tscn -- --out=<dir> --tag=a --view=name:cx:cy:cz:tx:ty:tz ...


func _hold() -> void:
	super._hold()
	if cam != null and not cam.current:
		cam.make_current()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fov=") and cam != null:
			cam.fov = float(a.trim_prefix("--fov="))
