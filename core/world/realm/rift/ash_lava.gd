extends RefCounted
## The Ashen Rift's lava, out in the far north-east (rift/scorch.gd's gash along the Crowns' foot above the Bellfall):
## the sheet (the rift's own lava material), the kill volume under it (core/world/lava.gd: a burn and a throw back to
## the last ground stood on), two glow lights low over it, and LavaWorks over the sheet (the crust shelf along its real
## banks, its embers). Built by rift_rim.gd (REACH_POIS). The old chasm by Hearthward holds starwater (realm_rift.gd).

const Scorch := preload("res://core/world/realm/rift/scorch.gd")
const MAT := "res://art/materials/lava.tres"
## The glow lights over the lava: [x, z] (two: OmniLights are dear; the sheet's own emission carries the rest).
const GLOWS := [Vector2(299.0, -139.0), Vector2(338.0, -138.5)]


static func build(host: Node3D) -> Node3D:
	var lava := Node3D.new()
	lava.name = "Lava"                           # (the culling passes leave a "Lava" subtree's ranges alone: umbral-culling)
	host.add_child(lava)
	var sh := Scorch.SHEET
	var c := sh.get_center()
	var surf := MeshInstance3D.new()
	surf.name = "Surface"
	var pm := PlaneMesh.new()
	pm.size = sh.size
	surf.mesh = pm
	surf.material_override = load(MAT)
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surf.extra_cull_margin = 20.0
	lava.add_child(surf)
	surf.global_position = Vector3(c.x, Scorch.LAVA_Y, c.y)
	for k in GLOWS.size():
		var g: Vector2 = GLOWS[k]
		var l := OmniLight3D.new()
		l.name = "Glow%d" % k
		l.light_color = Color(1.0, 0.35, 0.12)
		lava.add_child(l)
		l.global_position = Vector3(g.x, Scorch.LAVA_Y + 2.5, g.y)
	# the kill volume: its top 1.2 m over the sheet (Lava lifts its shape), under every lip (Scorch.SHEET_CLEAR)
	var kill := Lava.new()
	kill.name = "KillVolume"
	kill.star_mode = -1                          # all fire here (the starwater is the old chasm's)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(sh.size.x, 20.0, sh.size.y)
	cs.shape = box
	cs.position = Vector3(c.x, Scorch.LAVA_Y - 10.0, c.y)      # (the holder stands at the origin; Lava._ready adds its 1.2 m)
	kill.add_child(cs)
	lava.add_child(kill)
	# Lava._ready lit the lights for the old chasm's width: these are closer to their walls
	for k in GLOWS.size():
		var l := lava.get_node("Glow%d" % k) as OmniLight3D
		l.light_energy = 3.4
		l.omni_range = 26.0
	LavaWorks.over(surf)
	return lava
