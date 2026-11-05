extends RefCounted
## The staff core shows in the orb (r28): `apply(player, core)` tints the orb's swirl (the merged
## body's orb surface), its light and starburst flare, and hangs a small mote emitter on the orb
## for the core (prism glints, lodestar sparks, cinder embers, rime frost). The Hollow Core ("")
## puts back the wanderer's own violet. Called by the progression runtime when the core changes.

const WBody := preload("res://core/player/wanderer_body.gd")

## [orb shell, swirl, core, light, flare idle, flare cast, motes (Color, alpha = 0 for none)]
const LOOK := {
	"": [Vector3(0.55, 0.3, 2.0), Vector3(0.8, 0.5, 2.6), Vector3(1.0, 0.75, 3.0), Color("#A98BFF"), Vector3(0.45, 0.4, 1.5), Vector3(1.0, 0.75, 2.6), Color(0, 0, 0, 0)],
	"core_prism": [Vector3(0.75, 0.9, 1.7), Vector3(1.7, 2.0, 2.7), Vector3(2.4, 2.6, 3.1), Color("#CFF4FF"), Vector3(0.7, 0.85, 1.5), Vector3(1.8, 2.1, 2.8), Color(2.4, 2.8, 3.6, 1)],
	"core_lodestar": [Vector3(1.3, 0.85, 0.3), Vector3(2.4, 1.7, 0.6), Vector3(3.0, 2.4, 1.2), Color("#FFD86A"), Vector3(1.2, 0.85, 0.35), Vector3(2.6, 1.9, 0.8), Color(3.0, 2.3, 0.8, 1)],
	"core_cinder": [Vector3(1.15, 0.32, 0.8), Vector3(2.6, 0.9, 0.4), Vector3(3.0, 1.6, 0.7), Color("#FF7A3A"), Vector3(1.3, 0.45, 0.4), Vector3(2.8, 1.1, 0.5), Color(2.8, 1.0, 0.3, 1)],
	"core_rime": [Vector3(0.35, 0.75, 1.9), Vector3(0.8, 1.6, 2.8), Vector3(1.6, 2.4, 3.4), Color("#8FD0FF"), Vector3(0.4, 0.7, 1.6), Vector3(1.1, 1.9, 2.9), Color(1.5, 2.4, 3.4, 1)],
}


static func apply(p: Node, core: String) -> void:
	if p == null or not is_instance_valid(p):
		return
	var look: Array = LOOK.get(core, LOOK[""])
	var m := WBody.material("orb") as ShaderMaterial
	if m:
		m.set_shader_parameter("shell_color", look[0])
		m.set_shader_parameter("swirl_color", look[1])
		m.set_shader_parameter("core_color", look[2])
	var orb := p.find_child("Orb", true, false) as Node3D
	if orb == null:
		return
	var light := orb.get_node_or_null("OrbLight") as OmniLight3D
	if light:
		light.light_color = look[3]
	var flare := orb.get_node_or_null("Starburst") as MeshInstance3D
	if flare and flare.mesh is QuadMesh and (flare.mesh as QuadMesh).material is ShaderMaterial:
		var fm := (flare.mesh as QuadMesh).material as ShaderMaterial
		fm.set_shader_parameter("idle_color", look[4])
		fm.set_shader_parameter("cast_color", look[5])
	var old := orb.get_node_or_null("CoreMotes")
	if old:
		old.queue_free()
	var mc: Color = look[6]
	if mc.a <= 0.0:
		return
	var opts := {"count": 14, "life": 0.9, "speed": Vector2(0.05, 0.3), "size": 0.03, "gravity": 0.4, "radius": 0.1, "turbulence": true}
	match core:
		"core_rime":
			opts.gravity = -0.5
		"core_cinder":
			opts.gravity = 1.2
			opts.trail = 0.05
		"core_lodestar":
			opts.speed = Vector2(0.3, 0.8)
			opts.trail = 0.06
	var motes := Vfx.emitter(Color(mc.r, mc.g, mc.b), opts)
	motes.name = "CoreMotes"
	orb.add_child(motes)
	motes.emitting = true
