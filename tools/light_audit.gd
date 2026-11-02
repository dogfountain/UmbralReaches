extends SceneTree
## Read-only light audit: instantiates a zone, lets startup code run, then prints every light and
## how many cast shadows. NOT YET RUN by its author (no Godot in the authoring environment): run it once
## on the Mac and fix any typo before relying on it.
##   godot --headless --path . -s tools/light_audit.gd -- [--scene=res://world/main.tscn] [--frames=90]
## Output lines start with LIGHT / LIGHTAUDIT so they can be grepped and diffed between runs.

func _initialize() -> void:
	var scene_path := "res://world/main.tscn"
	var frames := 90
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.trim_prefix("--scene=")
		elif a.begins_with("--frames="):
			frames = int(a.trim_prefix("--frames="))
	var zone: Node = load(scene_path).instantiate()
	get_root().add_child(zone)
	for i in frames:
		await process_frame

	var total := 0
	var omni := 0
	var spot := 0
	var directional := 0
	var shadowed := 0
	var shadowed_positional := 0
	var fog_lights := 0
	var Policy = load("res://core/world/light_policy.gd")
	print("LIGHT kind | class | path | energy | range | shadow | fade begin/shadow/length (on?) | fog_energy | meta")
	for node in get_root().find_children("*", "Light3D", true, false):
		var light := node as Light3D
		total += 1
		var kind := "omni"
		var rng := 0.0
		if light is DirectionalLight3D:
			kind = "dir"
			directional += 1
		elif light is SpotLight3D:
			kind = "spot"
			spot += 1
			rng = (light as SpotLight3D).spot_range
		else:
			omni += 1
			rng = (light as OmniLight3D).omni_range
		if light.shadow_enabled:
			shadowed += 1
			if kind != "dir":
				shadowed_positional += 1
		if light.light_volumetric_fog_energy > 0.0:
			fog_lights += 1
		print("LIGHT %s | %s | %s | %.2f | %.1f | %s | %.0f/%.0f/%.0f (%s) | %.2f | %s" % [
			kind, str(Policy.classify(light)), str(light.get_path()), light.light_energy, rng, str(light.shadow_enabled),
			light.distance_fade_begin, light.distance_fade_shadow, light.distance_fade_length,
			str(light.distance_fade_enabled), light.light_volumetric_fog_energy,
			",".join(light.get_meta_list())])
	print("LIGHTAUDIT scene=%s total=%d omni=%d spot=%d dir=%d shadowed=%d shadowed_positional=%d fog_injecting=%d" % [
		scene_path, total, omni, spot, directional, shadowed, shadowed_positional, fog_lights])
	quit()
