extends RefCounted
## Combat lessons (r30): one-line hints the first time a mechanic matters, shown in the HUD's tip
## line and remembered in Travel.story["lessons"], so each is taught once per save, not per launch.
## Preload it where needed (`const Hints := preload("res://ui/hints.gd")`); no class_name.


static func seen(id: StringName) -> bool:
	var l: Variant = Travel.story.get("lessons", {})
	return l is Dictionary and (l as Dictionary).has(String(id))


## The lesson is learned without being shown (the player did the thing already).
static func mark(id: StringName) -> void:
	var l: Variant = Travel.story.get("lessons", {})
	var d: Dictionary = l if l is Dictionary else {}
	d[String(id)] = true
	Travel.story["lessons"] = d


## `basic`: a control lesson (move, jump): the HUD retires it when a fight starts.
static func once(id: StringName, text: String, basic := false) -> void:
	if seen(id):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene and tree.current_scene.get_node_or_null("LoadingScreen") != null:
		return            # the loading screen's warm-up freezes and casts on stand-ins: nothing is learned under the cover
	mark(id)
	var hud := tree.get_first_node_in_group(&"hud") if tree else null
	if hud and hud.has_method("lesson"):
		hud.call("lesson", text, basic)
	else:
		Events.toast.emit(text)


## The first key (or pad button, when `pad`) bound to `action`, for a lesson's text.
static func key(action: String, fallback: String, pad := false) -> String:
	return InputSetup.live_label(action, pad, fallback)
