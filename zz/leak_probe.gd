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
		if "--particles" in OS.get_cmdline_user_args():       # every emitter in the night: what kind of material it carries
			var kinds := {}
			for g in main.find_children("*", "GPUParticles3D", true, false):
				var gp := g as GPUParticles3D
				var pm := gp.process_material as ParticleProcessMaterial
				var key := "trail=%s one_shot=%s local=%s draw=%s pm=%s" % [gp.trail_enabled, gp.one_shot, gp.local_coords, gp.draw_pass_1.get_class() if gp.draw_pass_1 else "-", pm.get_class() if pm else str(gp.process_material)]
				if pm:
					key += " turb=%s ring=%s ramp=%s scale=%s emis=%d anim=%s" % [pm.turbulence_enabled, pm.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_RING, pm.color_ramp != null, pm.scale_curve != null, pm.emission_shape, pm.anim_speed_min != 0.0]
				kinds[key] = int(kinds.get(key, 0)) + 1
				for a in OS.get_cmdline_user_args():            # --free=trail=true: free the emitters whose line holds that text
					if a.begins_with("--free=") and key.contains(a.trim_prefix("--free=")):
						gp.free()
						break
			for k: String in kinds:
				print("LEAKPROBE emitters %3d  %s" % [kinds[k], k])
		if "--statics" in OS.get_cmdline_user_args():         # which script statics (every .gd: the project avoids class_name) hold a particle material
			var seen := 0
			for path: String in _scripts("res://"):
				var sc := load(path) as GDScript
				if sc == null:
					continue
				for pr: Dictionary in sc.get_property_list():
					if int(pr.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
						seen += 1
						if _holds(sc.get(String(pr.name)), 0):
							print("LEAKPROBE static %s.%s holds a particle material" % [path, pr.name])
			print("LEAKPROBE scanned %d script variables" % seen)
		print("LEAKPROBE dropped %s" % [drop])
	if (dropped and t > done_t + 5.0) or t > 90.0 or (main == self and t > 3.0):
		if "--sync" in OS.get_cmdline_user_args():
			RenderingServer.force_sync()
		if "--frames" in OS.get_cmdline_user_args() and not has_meta("waited"):
			set_meta("waited", true)
			RenderingServer.force_sync()
			for i in 10:
				await get_tree().process_frame
			RenderingServer.force_sync()
		print("LEAKPROBE quitting")
		get_tree().quit()


func _holds(v: Variant, depth: int) -> bool:
	if typeof(v) == TYPE_OBJECT and not is_instance_valid(v):
		return false
	if v is ParticleProcessMaterial:
		return true
	if v is GPUParticles3D:
		return (v as GPUParticles3D).process_material != null
	if depth > 5:
		return false
	if v is Object and not (v is Node) and not (v is Script):          # a RefCounted / Resource holding one in a member
		for pr: Dictionary in (v as Object).get_property_list():
			if int(pr.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				if _holds((v as Object).get(String(pr.name)), depth + 1):
					return true
		return false
	if v is Callable:
		for b: Variant in (v as Callable).get_bound_arguments():
			if _holds(b, depth + 1):
				return true
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


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if dir.begins_with("res://zz") or dir.begins_with("res://tools") or dir.begins_with("res://art") or dir.begins_with("res://docs") or dir.begins_with("res://.godot"):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
