extends RefCounted
## One way for a named person to say a line out loud (the story seat's channel for the heralds, the ledger-keeper and the vows' lines): a
## subtitle ("Name: ...") through the dialogue box's narrate, with a few syllables of the speaker's babble voice if the speaker stands near. Only while
## no conversation is open; a line that cannot be shown is dropped (it is flavour, never information). No class_name.
##   Spoken.say(tree, id, name, line)     `id` a villager's id (or a Keg patron's talk id) for the babble; "" for a plain subtitle
##   Spoken.plain(tree, line)             a narrated line with no speaker

const DialogueUI := preload("res://ui/dialogue.gd")
const Voice := preload("res://core/npc/npc_voice.gd")


static func _ui(tree: SceneTree) -> DialogueUI:
	var story := tree.get_first_node_in_group("story")
	return story.get("ui") as DialogueUI if story != null else null


static func plain(tree: SceneTree, line: String) -> void:
	var ui := _ui(tree)
	if ui != null and is_instance_valid(ui) and not ui.is_open():
		ui.narrate([line])


static func say(tree: SceneTree, id: String, display: String, line: String) -> void:
	var ui := _ui(tree)
	if ui == null or not is_instance_valid(ui) or ui.is_open():
		return
	ui.narrate(["%s: \"%s\"" % [display, line]])
	var pl := tree.get_first_node_in_group(Groups.PLAYER) as Node3D
	for v: Node in tree.get_nodes_in_group("villager"):
		var n := v as Node3D
		if n != null and String(n.get("id")) == id and pl != null and n.global_position.distance_to(pl.global_position) < 40.0:
			var voice := n.get_node_or_null("Voice")
			if voice == null:
				voice = Voice.speaker3d(n, 24.0)
			Voice.say(voice, Voice.for_node(n), 2 + line.length() / 20, 0.6)
			return
