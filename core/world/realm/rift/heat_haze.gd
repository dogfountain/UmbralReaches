extends RefCounted
## The heat shimmer: one flat sheet over the molten lake, the channel and the pool under the Ward Crag (world/zones/heat_haze.gdshader bends the
## screen behind it; from scratch, 21 Nov: the hot heart, not the crusted south). Built with the rift (its host moves to the endgame with it),
## no per-frame work.

const CENTRE := Vector3(4.0, -9.0, -60.0)
const HALF := Vector2(24.0, 32.0)


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
