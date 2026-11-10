extends Node
## NPC voices in the running night (windowed): the wanderer stands in the Keg while a patron pair is
## cued to talk and laugh, then a patron conversation is opened and typed through, then the wanderer
## visits Hearthward's cart seller. Prints whether each voice fired. Never writes the save.
##   godot --path . res://zz/voice_live.tscn
var p: Player
var t := 0.0
var phase := "load"
var results := {}
var npc: Node3D
var story: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Settings.fullscreen = false
	Settings.monitor = -1
	get_window().size = Vector2i(1280, 720)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _voices(group_nodes: Array) -> int:
	var n := 0
	for g in group_nodes:
		if is_instance_valid(g) and (g as Node).get_node_or_null("Voice") != null:
			n += 1
	return n


func _process(d: float) -> void:
	t += d
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	match phase:
		"load":
			if not p.get_parent().has_meta("realm_done"):
				return
			for e in get_tree().get_nodes_in_group(Groups.ENEMY):
				(e as Node).queue_free()
			phase = "keg"
			t = 0.0
		"keg":
			if t < 3.0:
				return
			p.teleport(Vector3(11.4, -0.6, 27.0))
			p.set_view(-0.9, -0.08)
			var pats: Array = get_tree().root.find_children("*", "DwarfNpc", true, false)
			for x in pats:
				var dn := x as DwarfNpc
				if dn.leader and dn.partner and not dn.away:
					dn.cue("talk", 6.0)
					dn.partner.cue("listen", 6.0)
					dn.partner.call_deferred("cue", "laugh", 2.0)
				if npc == null and dn.talk_id != "":
					npc = dn
			results["patrons"] = pats.size()
			phase = "listen"
			t = 0.0
		"listen":
			if t < 8.0:
				return
			var pats: Array = get_tree().root.find_children("*", "DwarfNpc", true, false)
			results["patrons voiced (chatter or laugh)"] = _voices(pats)
			var keep := get_tree().get_first_node_in_group("keep")
			results["keep voiced"] = keep != null and keep.get_node_or_null("Voice") != null
			story = get_tree().get_first_node_in_group("story")
			if story and npc:
				results["dialogue opened"] = story.call("talk", npc.talk_id, npc, p)
			phase = "dialogue"
			t = 0.0
		"dialogue":
			if t < 1.4:
				return
			var ui: Node = story.get("ui") if story else null
			if ui:
				var syl: Array = ui.get("_syl")
				results["dialogue syllables planned"] = syl.size()
				results["dialogue syllables voiced so far"] = int(ui.get("_syl_i"))
				var vp := ui.get("_voice_p") as AudioStreamPlayer
				results["dialogue voice playing"] = vp != null and vp.playing
				results["dialogue speaker voice"] = str((ui.get("_cur_voice") as Dictionary).get("family", "?")) + " pitch %.2f" % float((ui.get("_cur_voice") as Dictionary).get("pitch", 0.0))
				ui.call("close")
			phase = "village"
			t = 0.0
		"village":
			if t < 0.5:
				return
			p.teleport(Vector3(-7.0, 0.6, 33.0))
			p.set_view(2.6, -0.1)
			phase = "village_listen"
			t = 0.0
		"village_listen":
			if t < 14.0:
				return
			var vs: Array = get_tree().get_nodes_in_group("villager")
			results["villagers"] = vs.size()
			results["villagers voiced"] = _voices(vs)
			var acts := []
			for v in vs:
				if (v as Node3D).global_position.distance_to(p.global_position) < 16.0:
					acts.append("%s:%s" % [v.get("id"), v.get("act")])
			results["villagers near"] = acts
			for k: String in results:
				print("VOICE_LIVE %s = %s" % [k, str(results[k])])
			print("VOICE_LIVE done")
			get_tree().quit()
