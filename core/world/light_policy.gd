extends RefCounted
## One table for fade, fog injection, and who may cast shadows.
## Classes: beacon (lit brazier), hero (window spot), hero_fill (window omni),
## fill (crystals, lava, unlit bowl), glimmer, player_lantern, player_orb, moon.


static func classify(light: Light3D) -> StringName:
	if light.has_meta("light_class"):
		return StringName(str(light.get_meta("light_class")))
	if light.has_meta("hero"):
		return &"hero" if light is SpotLight3D else &"hero_fill"
	if light.has_meta("glimmer"):
		return &"glimmer"
	if light is DirectionalLight3D:
		return &"moon"
	if _under(light, "Player"):
		var n := String(light.name).to_lower()
		if n.contains("lantern"):
			return &"player_lantern"
		return &"player_orb"
	var brazier := _brazier_of(light)
	if brazier != null:
		return &"beacon" if brazier.lit else &"fill"
	var path := str(light.get_path()).to_lower()
	if path.contains("lava") or _under(light, "Lava"):
		return &"lava"
	if path.contains("river") or _under(light, "RiverGlow"):
		return &"river"
	if path.contains("crystal") or path.contains("glow"):
		return &"fill"
	return &"fill"


static func apply_fade(light: Light3D) -> void:
	var kind := classify(light)
	if kind == &"moon" or kind == &"player_lantern" or kind == &"player_orb":
		light.distance_fade_enabled = false
		if kind == &"player_orb":
			light.light_volumetric_fog_energy = 0.0
		elif kind == &"player_lantern":
			# Near-camera omnis light a froxel slice that reads as a streak that walks with you.
			light.light_volumetric_fog_energy = 0.0
		return
	light.distance_fade_enabled = true
	match kind:
		&"beacon":
			light.distance_fade_begin = 52.0
			light.distance_fade_shadow = 22.0
			light.distance_fade_length = 12.0
			light.light_volumetric_fog_energy = 2.2
		&"hero":
			light.distance_fade_begin = 40.0
			light.distance_fade_shadow = 22.0
			light.distance_fade_length = 10.0
			light.light_volumetric_fog_energy = 2.8
		&"hero_fill":
			light.distance_fade_begin = 32.0
			light.distance_fade_shadow = 12.0
			light.distance_fade_length = 8.0
			light.light_volumetric_fog_energy = 0.8
		&"glimmer":
			light.distance_fade_begin = 16.0
			light.distance_fade_shadow = 8.0
			light.distance_fade_length = 6.0
			light.light_volumetric_fog_energy = 0.28
		&"lava":
			light.distance_fade_begin = 78.0
			light.distance_fade_shadow = 40.0
			light.distance_fade_length = 18.0
			light.light_volumetric_fog_energy = 2.9
		&"river":
			light.distance_fade_begin = 28.0
			light.distance_fade_shadow = 12.0
			light.distance_fade_length = 8.0
			light.light_volumetric_fog_energy = 0.9
		_:
			light.distance_fade_begin = 28.0
			light.distance_fade_shadow = 12.0
			light.distance_fade_length = 8.0
			light.light_volumetric_fog_energy = 1.15


static func apply_shadows(light: Light3D) -> void:
	if light is DirectionalLight3D:
		light.shadow_enabled = Settings.shadow_quality > 0
		return
	var kind := classify(light)
	var shadows := Settings.shadow_quality > 0
	match kind:
		&"beacon":
			# A lit brazier is a dual-paraboloid shadow, two full scene renders.
			# The flame still lights the ground. The moon carries the shadow.
			light.shadow_enabled = false
		&"hero":
			light.shadow_enabled = shadows and Settings.shadow_quality > 1
		&"player_lantern":
			# The lantern follows the camera, so its shadow map is redrawn every frame.
			# Moon, windows and braziers still cast. This one does not.
			light.shadow_enabled = false
		_:
			light.shadow_enabled = false


static func apply_all(root: Node, moon: DirectionalLight3D) -> void:
	_moon(moon)
	for node in root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		apply_fade(light)
		apply_shadows(light)
		apply_illumination(light)


## Colored lamps light the ground, not just themselves. Bloom knobs stay locked.
static func apply_illumination(light: Light3D) -> void:
	if light.has_meta("_illum"):
		return
	light.set_meta("_illum", true)
	var kind := classify(light)
	match kind:
		&"beacon":
			_grow_omni(light, 1.22, 1.05)
		&"fill":
			light.light_energy *= 1.55
			_grow_omni(light, 1.35, 1.0)
		&"lava":
			light.light_energy *= 1.18
			_grow_omni(light, 1.12, 1.0)
		&"river":
			light.light_energy *= 1.08
			_grow_omni(light, 1.05, 1.15)
		&"hero":
			light.light_energy *= 1.18
		&"hero_fill":
			light.light_energy *= 1.4
			_grow_omni(light, 1.25, 1.0)
		&"glimmer":
			light.light_energy *= 1.15
			_grow_omni(light, 1.08, 1.4)
		&"player_lantern":
			_grow_omni(light, 1.25, 1.05)
		_:
			pass


static func _grow_omni(light: Light3D, range_mul: float, atten: float) -> void:
	var o := light as OmniLight3D
	if o == null:
		return
	o.omni_range *= range_mul
	o.omni_attenuation = atten


static func _moon(moon: DirectionalLight3D) -> void:
	if moon == null:
		return
	var shadows := Settings.shadow_quality > 0
	moon.shadow_enabled = shadows
	moon.directional_shadow_blend_splits = true
	moon.directional_shadow_fade_start = 0.78
	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.9
	if Settings.shadow_quality > 1:
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		moon.directional_shadow_max_distance = 30.0
	else:
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		moon.directional_shadow_max_distance = 22.0


static func _brazier_of(light: Light3D) -> Brazier:
	var n: Node = light
	while n:
		if n is Brazier:
			return n as Brazier
		n = n.get_parent()
	return null


static func _under(node: Node, type_name: String) -> bool:
	var n := node
	while n:
		if n.get_class() == type_name or n.name == type_name:
			return true
		if type_name == "Player" and n is Player:
			return true
		n = n.get_parent()
	return false
