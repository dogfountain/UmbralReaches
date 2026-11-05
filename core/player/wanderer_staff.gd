extends StaffPiece
## The wanderer's staff (wanderer_gen.gd "staff" + "orb"): carved knotted shaft with glowing rune
## grooves, cord-bound grip, iron bands, a cup and a crown of thorned claws round the orb. The node
## layout CharacterRig and the skills read is StaffPiece's: Head/Orb with OrbLight, Trail, Burst and
## the Starburst flare. In merged mode (WandererPiece.merged) the geometry is baked into the
## wanderer's single skinned body: this builds only the driver nodes, the light and the particles.
## Load by path (no class_name).

const WGen := preload("res://core/player/wanderer_gen.gd")
const WPiece := preload("res://core/player/wanderer_piece.gd")
const ORB_FLARE := preload("res://core/player/orb_flare.gdshader")


func build(socket: Node3D) -> Node3D:
	if not WPiece.merged:
		return _build_pieces(socket)
	var root := ProcMesh.node(socket, node_name if node_name != "Piece" else "Staff", offset)
	root.set_meta("dressed", true)
	root.set_meta("gen_parts", [["staff", Vector4.ZERO]])
	var head := ProcMesh.node(root, "Head", Vector3(0, 1.27, 0))
	var orb := ProcMesh.node(head, "Orb", Vector3(0, 0.17, 0))
	orb.set_meta("gen_parts", [["orb", Vector4.ZERO]])
	var orb_light := OmniLight3D.new()
	orb_light.name = "OrbLight"
	orb_light.light_color = light_color
	orb_light.light_energy = 1.3
	orb_light.omni_range = 4.5
	orb_light.shadow_enabled = false
	orb_light.set_meta("light_class", "player_orb")
	orb.add_child(orb_light)
	var trail := _magic_particles(false)
	trail.amount = 28                         # fewer, slightly bigger motes: same read, half the fill
	(trail.draw_pass_1 as QuadMesh).size = Vector2(0.065, 0.065)
	orb.add_child(trail)
	var burst := _magic_particles(true)
	burst.visible = false                     # shown only while a cast's burst is alive
	orb.add_child(burst)
	var flare := MeshInstance3D.new()
	flare.name = "Starburst"
	var fq := QuadMesh.new()
	fq.size = Vector2(0.7, 0.7)
	var fmat := ShaderMaterial.new()
	fmat.shader = ORB_FLARE                  # no depth texture: see orb_flare.gdshader
	fq.material = fmat
	flare.mesh = fq
	flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(flare)
	return root


## Unmerged (editor previews): StaffPiece's orb and light round the generated shaft as its own mesh.
func _build_pieces(socket: Node3D) -> Node3D:
	var root := super.build(socket)
	var old := root.get_node_or_null("StaffMesh")
	if old:
		old.free()
	var head := root.get_node_or_null("Head")
	if head:
		for n: String in ["ProngL", "ProngR"]:
			var pr := head.get_node_or_null(n)
			if pr:
				pr.free()
	var mi := MeshInstance3D.new()
	mi.name = "StaffMesh"
	mi.mesh = WGen.mesh("staff")
	for s in mi.mesh.get_surface_count():
		mi.set_surface_override_material(s, WPiece.material(mi.mesh.surface_get_name(s)))
	root.add_child(mi)
	root.move_child(mi, 0)
	root.set_meta("dressed", true)
	return root
