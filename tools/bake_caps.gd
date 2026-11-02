extends SceneTree
## Writes lathed glowcap / nightcap meshes for the stair without rebaking main.tscn.


func _initialize() -> void:
	var Mush := load("res://core/util/mushroom_mesh.gd")
	var glow: ArrayMesh = Mush.build(2, 0.22, 0, Color("#2BD99A"))
	var night: ArrayMesh = Mush.build(1, 0.28, 0, Color("#9B6BFF"))
	var agaric: ArrayMesh = Mush.build(0, 1.0, 0, Color("#C41E3A"))
	var wine: ArrayMesh = Mush.build(1, 1.0, 0, Color("#6B1C2A"))
	var vale_glow: ArrayMesh = Mush.build(2, 1.0, 0, Color("#1A7A68"))
	var paths := {
		glow: "res://world/zones/ascension/glowcap_mesh.res",
		night: "res://world/zones/ascension/nightcap_mesh.res",
		agaric: "res://world/zones/vale/agaric_mesh.res",
		wine: "res://world/zones/vale/nightcap_mesh.res",
		vale_glow: "res://world/zones/vale/glowcap_mesh.res",
	}
	for mesh in paths:
		var err := ResourceSaver.save(mesh, paths[mesh], ResourceSaver.FLAG_COMPRESS)
		mesh.take_over_path(paths[mesh])
		print("BAKE cap ", paths[mesh], " ", err)
	quit()
