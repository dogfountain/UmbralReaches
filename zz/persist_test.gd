extends Node
var t := 0
func _ready() -> void:
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
func _physics_process(_d: float) -> void:
	t += 1
	if t != 260: return
	var open := 0
	for s in get_tree().get_nodes_in_group(&"ward_seal"):
		if (s as WardSeal).is_open(): open += 1
	var guards := 0
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false):
		for slot in sp._slots:
			if slot.get("seal", "") != "": guards += 1
	print("PERSIST seals open=", open, "/", get_tree().get_nodes_in_group(&"ward_seal").size(), " seal guards spawned=", guards, " bosses=", Travel.bosses_slain.keys(), " relic=", Travel.relics, " reliquary_in_world=", get_tree().root.find_child("BoneReliquary", true, false) != null)
	get_tree().quit()
