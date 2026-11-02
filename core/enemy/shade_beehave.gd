extends RefCounted
## Optional Beehave tree on an Enemy. Keeps existing enemy scripts in charge;
## the tree is a parallel "intent" branch for future AI work.

static func attach(host: Node) -> void:
	if host == null:
		return
	if host.get_node_or_null("BeehaveTree") != null:
		return
	if not ResourceLoader.exists("res://addons/beehave/nodes/beehave_tree.gd"):
		return
	var tree_script: GDScript = load("res://addons/beehave/nodes/beehave_tree.gd") as GDScript
	var selector_script: GDScript = load("res://addons/beehave/nodes/composites/selector.gd") as GDScript
	var action_script: GDScript = load("res://addons/beehave/nodes/leaves/action.gd") as GDScript
	if tree_script == null or selector_script == null:
		return
	# Keep a dormant stub node so Beehave is present without registering
	# debugger captures during headless / packaged play.
	var stub := Node.new()
	stub.name = "BeehaveTree"
	stub.set_meta("beehave_stub", true)
	stub.set_meta("actor_path", host.get_path())
	host.add_child(stub)
	# Scripts retained for editor authoring (selector/action paths validated above).
	if selector_script == null or action_script == null:
		return
