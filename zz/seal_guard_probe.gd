extends Node
## Where the seal guards actually stand: each guard slot of every seal, its ground, the distance
## to its seal, to the nearest path, the region, and where the pawn is a few seconds later.
## Run: HOME=<scratch> godot --headless --path . res://zz/seal_guard_probe.tscn
const RL := preload("res://core/world/realm/realm_layout.gd")
var t := 0
var main: Node


func _ready() -> void:
	Travel._busy = true
	Travel.seals_broken.clear()
	Travel.bosses_slain.clear()
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _physics_process(_d: float) -> void:
	t += 1
	if t == 60 * 40:
		var seals := {}
		for s in get_tree().get_nodes_in_group(&"ward_seal"):
			seals[(s as WardSeal).seal_id] = (s as Node3D).global_position
		for id in seals:
			print("SEAL ", id, " at ", seals[id], " total ", EnemySpawner.seal_total(id))
		var sp := main.find_child("EnemySpawner", true, false)
		if sp == null:
			sp = get_tree().root.find_child("EnemySpawner", true, false)
		for slot: Dictionary in sp.get("_slots"):
			var sid := String(slot.get("seal", ""))
			if sid == "":
				continue
			var at: Vector3 = slot.at
			var pawn: Variant = slot.pawn
			var now := "dead/none"
			if is_instance_valid(pawn):
				now = str((pawn as Node3D).global_position)
			var reg: Dictionary = RL.region_at(at.x, at.z)
			print("GUARD %s %s at (%.1f,%.1f,%.1f) to_seal %.1f path %.1f region %s now %s" % [sid, slot.key, at.x, at.y, at.z,
				Vector2(at.x, at.z).distance_to(Vector2(seals.get(sid, at).x, seals.get(sid, at).z)), RL.path_dist(Vector2(at.x, at.z)), reg.get("id", "?"), now])
		print("HENGE stair ", ThornHenge.stair_pts)
		for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
			print("FIRE ", (b as Node).name, " ", (b as Node3D).global_position)
		print("SEALPROBE done")
		get_tree().quit(0)
