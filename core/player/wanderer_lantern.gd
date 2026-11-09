extends LanternPiece
## The wanderer's hand lantern, generated (wanderer_gen.gd "lantern": bail, pierced cap, glowing
## horn-glass drum in a six-bar cage, foot). In merged mode the geometry is part of the wanderer's
## skinned body and this builds only the driver node and the warm light; otherwise it falls back to
## LanternPiece (hand_lantern.glb). Load by path (no class_name).

const WPiece := preload("res://core/player/wanderer_piece.gd")


func build(socket: Node3D) -> Node3D:
	if not WPiece.merged:
		return super.build(socket)
	var root := ProcMesh.node(socket, node_name if node_name != "Piece" else "Lantern", offset)
	root.rotation_degrees = rotation_deg
	root.set_meta("dressed", true)
	root.set_meta("gen_parts", [["lantern", Vector4.ZERO]])
	var light := OmniLight3D.new()
	light.name = "LanternLight"
	light.light_color = light_color
	light.light_energy = 1.2
	light.omni_range = 4.5
	light.omni_attenuation = 1.25
	light.light_size = 0.35
	light.light_specular = 0.28
	light.shadow_enabled = false
	light.shadow_bias = 0.15
	light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	light.set_meta("light_class", "player_lantern")
	light.set_meta("base", {"e": 1.2, "r": 4.5, "a": 1.25})
	light.position = Vector3(0, -0.22, 0)
	root.add_child(light)
	return root
