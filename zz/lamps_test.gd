extends Node
## The lamps (core/world/realm/lamps), in memory only (saves held, state restored):
##   - 40..110 lamps the wanderer can kindle (the Far Reaches' towns add their porches and gates), kept lights beside them, none in LightGrid (no gameplay light)
##   - a lamp is unlit, then lit by interact; it is saved (State "lamps") and a fresh lamp of the same id wakes lit
##   - a leader lights its followers (a tower's crown); the tally counts leaders only
##   - ground lamps never stand on a way; every lamp that lights makes at most one shadowless light
##   - the worst view (every lamp within 40 m of the densest lamp, all lit) stays inside the light budget
## Run: HOME=<scratch> godot --headless --path . res://zz/lamps_test.tscn
const State := preload("res://core/life/secrets/state.gd")
const MAX_NEAR := 14                    ## lights in one 40 m disc, everything lit
var main: Node
var t := 0
var fails := 0
var items_before := {}
var systems_before := {}


func _ready() -> void:
	Travel._busy = true
	State.quiet = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool) -> void:
	print("LAMPS ", "PASS " if ok else "FAIL ", name)
	if not ok:
		fails += 1


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 300:
		print("LAMPS FAIL timeout")
		get_tree().quit(1)
		return
	if not main.has_meta("realm_done") or main.get_node_or_null("Lamps") == null:
		return
	items_before = Travel.items.duplicate(true)
	systems_before = Travel.systems.duplicate(true)
	_run()
	Travel.items = items_before
	Travel.systems = systems_before
	print("LAMPS done, %d fails" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _run() -> void:
	var lamps := get_tree().get_nodes_in_group(&"lamp")
	check("40..110 kindleable lamps (%d)" % lamps.size(), lamps.size() >= 40 and lamps.size() <= 110)
	var looks := {}
	for n in lamps:
		looks[(n as Lamp).look] = true
	check("all four looks stand (%s)" % [looks.keys()], looks.has("hang") and looks.has("niche") and looks.has("post") and looks.has("cresset") or (looks.has("pane") and looks.has("hang") and looks.has("niche") and looks.has("post")))
	var in_grid := 0
	for n in get_tree().get_nodes_in_group(Groups.LIGHT_SOURCE):
		if n is Lamp:
			in_grid += 1
	check("no lamp is a gameplay light source", in_grid == 0)
	var kept := 0
	for l in main.get_node("Lamps").find_children("*", "Lamp", true, false):
		if (l as Lamp).kept:
			kept += 1
			check("kept %s burns" % l.name, (l as Lamp).lit and not (l as Lamp).is_in_group(&"lamp"))
	check("a few lights others keep (%d)" % kept, kept >= 3)
	# not on a way
	var on_way := 0
	for n in lamps:
		var l := n as Lamp
		if l.look in ["post", "cresset"] and RealmLayout.path_dist(Vector2(l.global_position.x, l.global_position.z)) < 0.5:
			on_way += 1
	check("no standing lamp on a way (%d)" % on_way, on_way == 0)
	# kindle one with a follower, if any, else the first
	var lead: Lamp = null
	for n in lamps:
		if not (n as Lamp).followers.is_empty():
			lead = n as Lamp
			break
	if lead == null:
		lead = lamps[0] as Lamp
	check("%s starts cold" % lead.lamp_id, not lead.lit and lead.can_interact() and not State.has("lamps", lead.lamp_id))
	var before := Lamp.tally(get_tree())
	lead.interact(null)
	check("interact lights it", lead.lit and not lead.can_interact())
	check("its light is small and shadowless", lead.get_node_or_null("LampLight") == null or not (lead.get_node("LampLight") as OmniLight3D).shadow_enabled and (lead.get_node("LampLight") as OmniLight3D).omni_range <= 9.0)
	check("it is saved", State.has("lamps", lead.lamp_id))
	check("the tally counts it", Lamp.tally(get_tree()).x == before.x + 1)
	for f in lead.followers:
		check("follower %s lights with its leader" % f.lamp_id, f.lit)
	check("a lit lamp is no gameplay light (LightGrid)", not LightGrid.is_lit(lead.global_position) or Brazier.lit_at(get_tree(), lead.global_position) != null)
	check("a lit lamp is not a rest", not LightGrid.is_fire(lead.global_position) or Brazier.lit_at(get_tree(), lead.global_position) != null)
	# a lamp of the same id wakes lit (the save)
	var again := Lamp.new()
	again.lamp_id = lead.lamp_id
	again.look = lead.look
	main.get_node("Lamps").add_child(again)
	check("a fresh lamp of that id wakes lit", again.lit)
	again.free()
	# the worst view: light everything, count the lights in the densest 40 m disc
	for n in lamps:
		if not (n as Lamp).lit:
			(n as Lamp).interact(null)
	var lights: Array[Vector3] = []
	var shadowed := 0
	for l in main.get_node("Lamps").find_children("LampLight", "OmniLight3D", true, false):
		lights.append((l as Node3D).global_position)
		shadowed += 1 if (l as OmniLight3D).shadow_enabled else 0
	check("no lamp light casts a shadow (%d)" % shadowed, shadowed == 0)
	var worst := 0
	var at := Vector3.ZERO
	for a in lights:
		var n := 0
		for b in lights:
			if Vector2(a.x - b.x, a.z - b.z).length() < 40.0:
				n += 1
		if n > worst:
			worst = n
			at = a
	print("LAMPS lights: %d in all, %d in the densest 40 m disc (at %s)" % [lights.size(), worst, at.snapped(Vector3.ONE)])
	check("the worst view keeps %d lights or fewer (%d)" % [MAX_NEAR, worst], worst <= MAX_NEAR)
	var tl := Lamp.tally(get_tree())
	check("every lamp lit: %d of %d" % [tl.x, tl.y], tl.x == tl.y)
	# put out again, nothing left burning that the save did not mean
	for n in lamps:
		(n as Lamp).douse()
	var sys: Dictionary = Travel.system_state("secrets")
	sys["lamps"] = {}
