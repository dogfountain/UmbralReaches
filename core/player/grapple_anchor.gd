extends Node3D
## A tether anchor (r31): a rift-iron ring the wanderer's Tether line can bite into and haul the
## body up to. The WORLD places these; the mechanic lives in core/player/grapple.gd. Any Node3D in
## the "grapple_anchor" group works (this script only adds a look and a faint glow), so a baked
## prop can opt in with add_to_group("grapple_anchor") alone.
##
## Optional metadata on the node (any anchor):
##   "reach"  float  how far away it can be bitten (default Grapple.REACH, 24 m)
##   "land"   Vector3  local offset of the spot the haul ends at (default: 1.2 m below and 0.9 m out
##            toward the wanderer, so you arrive under the ring and pop up past it)
## Placing one (no class_name):
##   const GrappleAnchor := preload("res://core/player/grapple_anchor.gd")
##   GrappleAnchor.make(parent, world_pos)

const GROUP := "grapple_anchor"
const COL := Color(1.2, 0.55, 2.8)

var bare := false                ## no mesh or light: the caller dresses it


static func make(parent: Node, at: Vector3, reach := -1.0) -> Node3D:
	var a: Node3D = (load("res://core/player/grapple_anchor.gd") as GDScript).new()
	a.name = "GrappleAnchor"
	if reach > 0.0:
		a.set_meta("reach", reach)
	parent.add_child(a)
	a.global_position = at
	return a


func _ready() -> void:
	add_to_group(GROUP)
	if bare:
		return
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.22
	tor.outer_radius = 0.3
	tor.rings = 16
	tor.ring_segments = 6
	ring.mesh = tor
	ring.rotation.x = PI * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.08, 0.11)
	m.metallic = 0.8
	m.roughness = 0.45
	m.emission_enabled = true
	m.emission = Color(COL.r, COL.g, COL.b) * 0.35
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.08
	sph.height = 0.16
	sph.radial_segments = 8
	sph.rings = 4
	core.mesh = sph
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.albedo_color = COL
	core.material_override = cm
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.45, 1.0)
	l.light_energy = 0.6
	l.omni_range = 3.0
	l.shadow_enabled = false
	add_child(l)
