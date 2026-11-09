class_name LightPolicy
extends RefCounted
## One table for fade, fog injection, and who may cast shadows.
## Classes: beacon (lit brazier), hero (window spot), hero_fill (window omni),
## fill (crystals, lava, unlit bowl), glimmer, player_lantern, player_orb, moon.

# [energy, range, atten] multiplied onto the authored `base` meta. Idempotent.
const ILLUM := {
	&"beacon": [0.55, 1.05, 0.9],                # braziers: warm pool, not orange flood
	&"fill": [1.35, 1.2, 1.0],
	&"lava": [1.18, 1.12, 1.0],
	&"river": [1.08, 1.05, 1.15],
	&"hero": [0.82, 1.0, 1.0],
	&"hero_fill": [0.72, 1.05, 1.0],
	&"shaft": [0.68, 1.0, 1.0],                  # window/door trail; keep soft, not yard-wash
	&"lamp": [0.62, 1.0, 1.0],                   # tavern/hearth/candles
	&"glimmer": [1.05, 1.05, 1.4],
	&"player_lantern": [0.55, 1.05, 1.0],        # soft personal pool, no robe wash
	# the table is the one place a light's brightness is scaled (Luke, 9 Nov: multipliers had stacked in builders)
	&"kept_lamp": [0.48, 0.9, 1.0],              # a lamp the wanderer kindles on the roads (lamp.gd: was * 0.48 / * 0.9 there)
	&"village": [1.0, 1.05, 1.0],                # cottage, camp and window lights in the villages (village_props.gd)
}


## [energy, range] factors for `kind` from the table (for builders that drive a light's energy themselves: flicker).
static func illum(kind: StringName) -> Vector2:
	var m: Array = ILLUM.get(kind, [1.0, 1.0, 1.0])
	return Vector2(float(m[0]), float(m[1]))


static func classify(light: Light3D) -> StringName:
	if light.has_meta(&"light_class"):
		return StringName(str(light.get_meta(&"light_class")))
	var kind := _classify_raw(light)
	light.set_meta(&"light_class", kind)
	return kind


static func _classify_raw(light: Light3D) -> StringName:
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
			light.light_volumetric_fog_energy = 0.45
		&"hero":
			light.distance_fade_begin = 40.0
			light.distance_fade_shadow = 22.0
			light.distance_fade_length = 10.0
			light.light_volumetric_fog_energy = 1.2
		&"shaft":
			# a cone out of a window or a door. An omni here is a glow sphere; the spot is the trail on the ground.
			light.distance_fade_begin = 40.0
			light.distance_fade_shadow = 0.0
			light.distance_fade_length = 12.0
			light.light_volumetric_fog_energy = 1.05
		&"hero_fill":
			light.distance_fade_begin = 32.0
			light.distance_fade_shadow = 12.0
			light.distance_fade_length = 8.0
			light.light_volumetric_fog_energy = 0.45
		&"lamp":
			# a kindled lamp: comfort light, short range, never a shadow
			light.distance_fade_begin = 26.0
			light.distance_fade_shadow = 0.0
			light.distance_fade_length = 8.0
			light.light_volumetric_fog_energy = 0.22
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
			# a shadowed spot re-renders everything in its cone every frame (the stair-era window
			# rig: ~75k triangles, 11 draws); high world detail only
			light.shadow_enabled = shadows and Settings.shadow_quality > 1 and Settings.detail >= 2
		&"player_lantern":
			# The lantern follows the camera, so its shadow map is redrawn every frame.
			# Moon, windows and braziers still cast. This one does not.
			light.shadow_enabled = false
		&"shaft":
			# The trail is the fog cone. A shadow map on every window would re-render that cone.
			light.shadow_enabled = false
		_:
			light.shadow_enabled = false


static func apply_all(root: Node, moon: DirectionalLight3D) -> void:
	_moon(moon)
	if root == null:
		return
	var lights: Array = []
	if root.has_method("cached_lights"):
		lights = root.cached_lights()
	if lights.is_empty():
		lights = root.find_children("*", "Light3D", true, false)
	for node in lights:
		var light := node as Light3D
		if light == null or not is_instance_valid(light):
			continue
		if light.get_meta(&"light_class", &"") == &"realm":
			if light.has_meta(&"realm_shadow"):
				light.shadow_enabled = Settings.shadow_quality > 1 and Settings.detail >= 2
			continue
		apply_fade(light)
		apply_shadows(light)
		apply_illumination(light)


static func energy_mult(kind: StringName) -> float:
	return float(ILLUM.get(kind, [1.0, 1.0, 1.0])[0])


static func _base(light: Light3D) -> Dictionary:
	if not light.has_meta(&"base"):
		var o := light as OmniLight3D
		light.set_meta(&"base", {
			"e": light.light_energy,
			"r": o.omni_range if o else 0.0,
			"a": o.omni_attenuation if o else 1.0,
		})
	return light.get_meta(&"base")


## Colored lamps light the ground, not just themselves. Bloom knobs stay locked.
## Pure function of (authored base, class) — safe to call every slider tick.
static func apply_illumination(light: Light3D) -> void:
	var b: Dictionary = _base(light)
	var m: Array = ILLUM.get(classify(light), [1.0, 1.0, 1.0])
	light.light_energy = float(b.e) * float(m[0])
	var o := light as OmniLight3D
	if o:
		o.omni_range = float(b.r) * float(m[1])
		o.omni_attenuation = float(m[2])
	var s := light as SpotLight3D
	if s and float(b.r) > 0.0:
		s.spot_range = float(b.r) * float(m[1])


## The moon's shadow (r29, the "weird shadow lines"). Under the 34 deg moon the open ground was
## striped with acne: curved bands along every shadow-map texel row, crawling as the camera moved
## (zz/perf_lines --debug=2 shows them plainly; shots/critE_shadowlines_*). Cause: too little bias for
## the soft (angular 2.5 deg) blocker search on 1024-atlas texels (two splits over 30 m at fov 90, the
## far ones ~10 cm): the sloped ground read as its own blocker along every texel row. Now:
##   bias 0.06, normal bias 2.5 (normal bias is in texels): the stripes are gone at every view tried
##   High: the near split is 0.25 x 30 m = 7.5 m, so the wanderer and the ground round him sit in one
##     split (the old 3 m boundary ran right under his feet with its blend band)
## Tried and left out for the frame budget (perf_tour --attrib --reps=6 and hub A/B, 4x pixels):
## 4096 (+1.1-2.3 ms more), soft filter Low 2 (+1.0-2.6 ms; it clears the fine penumbra grain), four
## splits (+355 shadow draws, +560k primitives), a 34 m reach (+34 shadow draws at the hub).
## a 2048 atlas (+0.22-0.31 ms, and more on Windows GPUs; crisper contacts: MOON_ATLAS[2] = 2048 if wanted),
const MOON_ATLAS := [1024, 1024, 1024]        ## by Settings.shadow_quality (0 = off). Luke, 9 Nov: 2048 and an 86 m
                                              ## reach (a Cursor look pass) took a Windows build from 144 to ~90 fps
const MOON_FILTER := [1, 1, 1]                ## RenderingServer.ShadowQuality (1 very low; 2 low costs 1-2.6 ms)
const MOON_BIAS := 0.06
const MOON_NORMAL_BIAS := 2.5
const MOON_FAR := [22.0, 34.0, 64.0]
const MOON_SPLIT_1 := 0.16
static var _atlas := 0
static var _filter := -1


static func _moon(moon: DirectionalLight3D) -> void:
	if moon == null:
		return
	var q := clampi(Settings.shadow_quality, 0, 2)
	moon.shadow_enabled = q > 0
	_moon_maps(q)
	# r35: no split blending. Godot samples both splits (two PCSS lookups) for every pixel of the near
	# split when blending is on; off, the near 7.5 m keep only their own (sharper) map. perf_tour
	# --attrib --stress=2 --reps=4..6: +0.25..0.7 ms for blending at r_spawn_north, r_rim, r_glade,
	# r_meadow; no seam was visible at the 7.5 m boundary under the soft (2.5 deg) moon (look_shots).
	moon.directional_shadow_blend_splits = false
	moon.directional_shadow_fade_start = 0.8
	moon.shadow_bias = MOON_BIAS
	moon.shadow_normal_bias = MOON_NORMAL_BIAS
	moon.directional_shadow_max_distance = _moon_far(q)
	if q > 1:
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		moon.directional_shadow_split_1 = MOON_SPLIT_1
	else:
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	# soft moon shadows (angular distance) cost a blocker search per shadowed pixel: low world
	# detail draws them hard; the authored softness comes back on medium/high. Atmosphere
	# authors the soft value each apply; keep the last non-zero so a detail-0 pass cannot stick 0.
	var ang := moon.light_angular_distance
	if ang > 0.01:
		moon.set_meta(&"angular", ang)
	elif not moon.has_meta(&"angular"):
		moon.set_meta(&"angular", 0.55)
	moon.light_angular_distance = 0.0 if Settings.detail <= 0 else float(moon.get_meta(&"angular"))


## The directional atlas and soft filter are global renderer state: set only when they change
## (a new atlas size reallocates it). Headless runs have no shadow maps to size.
## MOON_FAR, or `--moon-far=` (A/B in perf runs).
static func _moon_far(q: int) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--moon-far="):
			return float(a.trim_prefix("--moon-far="))
	return MOON_FAR[q]


static func _moon_maps(q: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var size: int = MOON_ATLAS[q]
	if size != _atlas:
		_atlas = size
		RenderingServer.directional_shadow_atlas_set_size(size, true)
	var f: int = MOON_FILTER[q]
	if f != _filter:
		_filter = f
		RenderingServer.directional_soft_shadow_filter_set_quality(f as RenderingServer.ShadowQuality)


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


## Lights the Realm modules add after the zone's first LightPolicy pass (lore windows and candles,
## camps, the rift). Their authored energy and range stay as they are (apply_illumination would
## rescale them); they get a distance fade so the clustered renderer can drop the far ones, and a
## shadowed omni/spot (two to six extra scene renders a frame) keeps its shadow only within
## REALM_SHADOW_FADE m and only on high world detail. Returns [lights, faded, shadows kept, shadows off].
const REALM_FADE_BEGIN := 46.0
const REALM_SHADOW_FADE := 18.0


static func realm_pass(root: Node) -> Array:
	var faded := 0
	var kept := 0
	var off := 0
	var lights := root.find_children("*", "Light3D", true, false)
	for node in lights:
		var light := node as Light3D
		if light == null or light is DirectionalLight3D or _under(light, "Player"):
			continue
		if light.has_meta(&"light_class"):
			# classified by its builder (the Crossing's "prop" lanterns, the summit orb): keep it, but
			# a light with no fade at all is shaded out to the far plane
			if not light.distance_fade_enabled and light.get_meta(&"light_class") != &"moon":
				light.distance_fade_enabled = true
				light.distance_fade_begin = REALM_FADE_BEGIN
				light.distance_fade_length = 10.0
				light.distance_fade_shadow = REALM_SHADOW_FADE
				faded += 1
			continue
		light.set_meta(&"light_class", &"realm")
		if not light.distance_fade_enabled:
			light.distance_fade_enabled = true
			light.distance_fade_begin = REALM_FADE_BEGIN
			light.distance_fade_length = 10.0
			light.distance_fade_shadow = REALM_SHADOW_FADE
			faded += 1
		if light.shadow_enabled:
			light.set_meta(&"realm_shadow", true)
		if light.has_meta(&"realm_shadow"):
			light.shadow_enabled = Settings.shadow_quality > 1 and Settings.detail >= 2
			light.distance_fade_shadow = minf(light.distance_fade_shadow, REALM_SHADOW_FADE)
			if light.shadow_enabled:
				kept += 1
			else:
				off += 1
	return [lights.size(), faded, kept, off]
