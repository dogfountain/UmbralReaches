extends RefCounted
## Greybox window light rig. CSG boxes only — not art. Wired from the stair so hero
## spots, gobos and shafts exist. Geometry is a stand-in for lighting, not a kit.

const CYAN := Color(0.48, 0.72, 1.0)
const RUN := 1.1
const RISE := 0.42
const BREAK := 30
const LANDING := 3.0
const STEPS := 60

static var _gobo: Texture2D


static func raise(root: Node) -> void:
	if root.get_node_or_null("WindowRig") != null:
		return
	var rig := Node3D.new()
	rig.name = "WindowRig"
	root.add_child(rig)
	_ensure_gobo()
	# Gate uses the existing lintel as the frame. No visible pane in the player's face.
	_window(rig, "Gate", Vector3(0.0, 4.4, 16.6), Vector3.ZERO, false)
	var ly := float(BREAK) * RISE
	var lz := -float(BREAK - 1) * RUN - (RUN + LANDING) * 0.5
	_window(rig, "Landing", Vector3(1.35, ly + 1.7, lz - 1.15), Vector3(0.0, PI, 0.0), false)
	var sy := float(STEPS) * RISE
	var sz := -float(STEPS - 1) * RUN - LANDING - RUN - 4.5
	_window(rig, "Summit", Vector3(1.45, sy + 1.7, sz - 0.6), Vector3(0.0, PI, 0.0), false)
	_probe(rig, "FootProbe", Vector3(0.0, 3.2, 12.0), Vector3(16.0, 10.0, 22.0))
	_probe(rig, "LandingProbe", Vector3(0.0, ly + 1.6, lz), Vector3(10.0, 8.0, 14.0))
	_probe(rig, "SummitProbe", Vector3(0.0, sy + 1.4, sz), Vector3(12.0, 8.0, 16.0))


static func _window(rig: Node3D, id: String, pos: Vector3, rot: Vector3, _show_glass: bool) -> void:
	var n := Node3D.new()
	n.name = "%sWindow" % id
	n.position = pos
	n.rotation = rot
	rig.add_child(n)

	var spot := SpotLight3D.new()
	spot.name = "HeroSpot"
	spot.position = Vector3(0.0, 0.1, 1.35)
	spot.light_color = CYAN
	spot.light_energy = 4.4
	spot.spot_range = 18.0
	spot.spot_angle = 26.0
	spot.spot_angle_attenuation = 0.7
	spot.shadow_enabled = true
	spot.shadow_bias = 0.03
	spot.shadow_normal_bias = 1.15
	spot.light_projector = _gobo
	spot.light_volumetric_fog_energy = 2.5
	spot.set_meta("hero", true)
	spot.set_meta("light_class", "hero")
	n.add_child(spot)

	var fill := OmniLight3D.new()
	fill.name = "HeroFill"
	fill.position = Vector3(0.0, 0.15, -0.55)
	fill.light_color = CYAN
	fill.light_energy = 0.85
	fill.omni_range = 5.5
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.0
	fill.set_meta("hero", true)
	fill.set_meta("light_class", "hero_fill")
	n.add_child(fill)

	var fog := FogVolume.new()
	fog.name = "ShaftMist"
	fog.size = Vector3(3.2, 3.6, 6.4)
	fog.position = Vector3(0.0, -0.2, -3.0)
	var fmat := FogMaterial.new()
	fmat.density = 0.07
	fmat.albedo = Color(0.36, 0.55, 0.92)
	fmat.emission = Color(0.012, 0.02, 0.045)
	fmat.edge_fade = 0.42
	fog.material = fmat
	n.add_child(fog)


static func _probe(rig: Node3D, id: String, pos: Vector3, size: Vector3) -> void:
	var probe := ReflectionProbe.new()
	probe.name = id
	probe.position = pos
	probe.size = size
	probe.origin_offset = Vector3(0.0, 0.35, 0.0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.box_projection = true
	probe.interior = true
	probe.enable_shadows = false
	probe.max_distance = 28.0
	rig.add_child(probe)


static func _ensure_gobo() -> void:
	if _gobo != null:
		return
	var img := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	for y in 256:
		for x in 128:
			var u := (float(x) + 0.5) / 128.0
			var v := (float(y) + 0.5) / 256.0
			var cx := absf(u - 0.5)
			var open := cx < 0.30 and v > 0.10 and v < 0.90
			if v < 0.30:
				var ey := (v - 0.30) / 0.18
				open = open and (cx * cx / 0.09 + ey * ey) < 1.0
			var bar := absf(u - 0.5) < 0.022 or (v > 0.48 and v < 0.515)
			img.set_pixel(x, y, Color.WHITE if open and not bar else Color.BLACK)
	img.generate_mipmaps()
	_gobo = ImageTexture.create_from_image(img)
