extends RefCounted
## Combat lessons (r30): one-line hints the first time a mechanic matters, shown in the HUD's tip
## line and remembered in Travel.story["lessons"], so each is taught once per save, not per launch.
## Preload it where needed (`const Hints := preload("res://ui/hints.gd")`); no class_name.


static func seen(id: StringName) -> bool:
	var l: Variant = Travel.story.get("lessons", {})
	return l is Dictionary and (l as Dictionary).has(String(id))


static func once(id: StringName, text: String) -> void:
	if seen(id):
		return
	var l: Variant = Travel.story.get("lessons", {})
	var d: Dictionary = l if l is Dictionary else {}
	d[String(id)] = true
	Travel.story["lessons"] = d
	var tree := Engine.get_main_loop() as SceneTree
	var hud := tree.get_first_node_in_group(&"hud") if tree else null
	if hud and hud.has_method("lesson"):
		hud.call("lesson", text)
	else:
		Events.toast.emit(text)


## The first key (or pad button, when `pad`) bound to `action`, for a lesson's text.
static func key(action: String, fallback: String, pad := false) -> String:
	return InputSetup.live_label(action, pad, fallback)
