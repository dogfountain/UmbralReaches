extends SceneTree
## Packs deterministic runtime dress into world/zones/ascension/dress.tscn.
## Does NOT save main.tscn. Run with a GPU context (not --headless):
##   godot --path . -s tools/bake_dress.gd

const OUT := "res://world/zones/ascension/dress.tscn"


func _initialize() -> void:
	var packed := load("res://world/main.tscn") as PackedScene
	if packed == null:
		push_error("bake_dress: main.tscn missing")
		quit()
		return
	var main := packed.instantiate() as Node
	main.set_script(null)
	root.add_child(main)
	Gothic.raise(main)
	var env_node := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var cam := main.get_node_or_null("Player/CameraRig/Pitch/SpringArm/Camera") as Camera3D
	var moon := main.get_node_or_null("Moon") as DirectionalLight3D
	if env_node and cam and moon:
		Atmosphere.apply(main, env_node.environment, cam, moon, 82.0, Color("#12183A"), Color("#060A1C"), Color("#3A2480"))
	DressedProps.dress_zone(main)
	var dress := Node3D.new()
	dress.name = "Dress"
	for id in ["WindowRig", "Occluders"]:
		var n := main.get_node_or_null(id)
		if n == null:
			continue
		main.remove_child(n)
		dress.add_child(n)
		_own(n, dress)
	var ps := PackedScene.new()
	var err := ps.pack(dress)
	if err != OK:
		push_error("bake_dress pack failed %s" % err)
		quit()
		return
	err = ResourceSaver.save(ps, OUT)
	print("BAKE_DRESS saved ", OUT, " err=", err)
	main.free()
	dress.free()
	quit()


func _own(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		_own(c, owner)
