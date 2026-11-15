extends Node
## Bisects the exit-time leaks ("N ObjectDB instances were leaked at exit", "ParticlesShaderRD were never freed"):
## builds the night, lists the night's children, frees the ones named in --drop=A,B (by node name) and quits.
## The leak lines of the run (headless counts ObjectDB; a windowed run also shows the shader leak) say which piece
## holds the objects.
##   godot --headless --path . res://zz/leak_probe.tscn -- --realm-modules=none [--drop=Player,HUD] [--list]
## Never writes the save.
var t := 0.0
var done_t := -1.0
var main: Node
var dropped := false


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--make="):              # not the night: just these scripts / scenes, each made and added to the root
			for path in a.trim_prefix("--make=").split(","):
				var r := load(path)
				var o: Variant = (r as PackedScene).instantiate() if r is PackedScene else (r as GDScript).new()
				print("LEAKPROBE made %s -> %s" % [path, o])
				if o is Node:
					get_tree().root.add_child.call_deferred(o)
			main = self
			set_meta("realm_done", true)
			return
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if main and main.has_meta("realm_done") and done_t < 0.0:
		done_t = t
	if done_t >= 0.0 and not dropped and t > done_t + 2.0 and main != self:
		dropped = true
		var drop := []
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--drop="):
				drop = a.trim_prefix("--drop=").split(",")
		if "--list" in OS.get_cmdline_user_args():
			for c in main.get_children():
				print("LEAKPROBE child %s (%s) %d nodes" % [c.name, c.get_class(), 1 + c.find_children("*", "", true, false).size()])
		for c in main.get_children():
			if String(c.name) in drop:
				c.queue_free()
		if "--free-main" in OS.get_cmdline_user_args():       # the whole night freed, five frames, then quit: what is still held is a static or the engine
			main.queue_free()
		if "--release" in OS.get_cmdline_user_args():
			Vfx.release()
			MagicBolt.release_shared()
		if "--statics" in OS.get_cmdline_user_args():         # which class statics still hold a particle material
			for gc: Dictionary in ProjectSettings.get_global_class_list():
				var sc := load(String(gc.path)) as GDScript
				if sc == null:
					continue
				for pr: Dictionary in sc.get_property_list():
					if int(pr.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
						if _holds(sc.get(String(pr.name)), 0):
							print("LEAKPROBE static %s.%s holds a ParticleProcessMaterial" % [gc["class"], pr.name])
		print("LEAKPROBE dropped %s" % [drop])
	if (dropped and t > done_t + 5.0) or t > 90.0 or (main == self and t > 3.0):
		print("LEAKPROBE quitting")
		get_tree().quit()


func _holds(v: Variant, depth: int) -> bool:
	if v is Object and not is_instance_valid(v as Object):
		return false
	if v is ParticleProcessMaterial:
		return true
	if v is GPUParticles3D:
		return (v as GPUParticles3D).process_material != null
	if depth > 4:
		return false
	if v is Dictionary:
		for k: Variant in v:
			if _holds(v[k], depth + 1):
				return true
	elif v is Array:
		for e: Variant in v:
			if _holds(e, depth + 1):
				return true
	return false
