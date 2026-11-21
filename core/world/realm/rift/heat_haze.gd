extends RefCounted
## The pit's heat shimmer: one flat sheet over the lava basin (world/zones/heat_haze.gdshader bends the screen behind it). Built with the rift
## (its host moves to the endgame with it), no per-frame work.

const CENTRE := Vector3(0.0, -3.0, -78.0)
const HALF := Vector2(34.0, 42.0)


static func build(host: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "HeatHaze"
	var pm := PlaneMesh.new()
	pm.size = HALF * 2.0
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://world/zones/heat_haze.gdshader") as Shader
	m.set_shader_parameter("half_size", HALF)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 20.0
	host.add_child(mi)
	mi.position = CENTRE
