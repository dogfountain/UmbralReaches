extends Node
## r33 world checks, in memory only (Travel._busy holds every save; the Journal does not persist):
##   - zone discovery: the first entry into a region fires Events.region_discovered once and puts up
##     the big carved banner once; coming back names it small (or not at all inside a minute) and
##     never discovers it again; a named spot (subzone) inside a region is discovered once too
##   - every fire is a map marker of kind "travel" with an ember-post beside it
##   - the Ember Road: from one lit fire to another the flight lands the wanderer at the far fire's
##     spawn point, gives the camera back, and emits Events.fire_travelled; the menu lists the fires
##   - the road is shut in a boss fight (and for a cold fire)
##   - a world event: a gloom surge is called (map marker), breaks open when reached (foes rise) and
##     pays out when won (Events.world_event "won")
## Run: SCRATCH=<dir> JOBS=1 tools/run_tests.sh world_r33
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const FireRoad := preload("res://core/world/fire_road.gd")

var p: Player
var main: Node
var t := 0
var step := 0
var wait := 0
var _road_tries := 0
var fails := 0
var found: Array[String] = []
var travelled: Array = []
var events: Array[String] = []
var flight: Node
var shrine: Brazier
var landing: Brazier
var t0 := 0


func _ready() -> void:
	Travel._busy = true
	Travel.seals_broken.clear()
	Travel.bosses_slain.clear()
	CodexStore.persist = false
	CodexStore.reset()
	Events.region_discovered.connect(func(id: String, kind: String) -> void: found.append("%s:%s" % [kind, id]))
	Events.fire_travelled.connect(func(a: String, b: String) -> void: travelled.append([a, b]))
	Events.world_event.connect(func(id: String, ph: String, _at: Vector3) -> void: events.append("%s:%s" % [id, ph]))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func check(name: String, ok: bool) -> void:
	print("WORLD33 ", "PASS " if ok else "FAIL ", name)
	if not ok:
		fails += 1


func _count(s: String) -> int:
	return found.count(s)


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 300:
		print("WORLD33 FAIL timeout at step ", step)
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if wait > 0:
		wait -= 1
		return
	var disc := main.get_node_or_null("Discovery")
	var we := main.get_node_or_null("WorldEvents")
	match step:
		0:
			if not main.has_meta("realm_done") or disc == null or we == null:
				return
			p.set_physics_process(true)
			we.set("auto", false)
			# --- discovery ---
			var banner: Node = disc.get("banner")
			disc.call("visit", Vector3(-72.0, 2.0, 52.0))           # the chapel's heart
			check("chapel discovered once on entry (%s)" % [found], _count("region:chapel") == 1)
			check("chapel journaled", CodexStore.discovered("chapel"))
			disc.call("visit", Vector3(-40.0, 1.0, 64.0))           # out onto the road
			disc.call("visit", Vector3(-72.0, 2.0, 52.0))           # and back
			check("chapel not discovered again", _count("region:chapel") == 1)
			var shown: Array = banner.get("shown")
			var big := 0
			for b: Dictionary in banner.get("_queue") + shown + (disc.get("_hold") as Array):
				if String(b.kind) == "region" and String(b.name) == "Chapel of the First Kindling" and bool(b.fresh):
					big += 1
			check("one big carved banner for the chapel (got %d)" % big, big == 1)
			# a named spot inside a region
			disc.call("visit", Vector3(0.0, 10.0, -40.0))           # over the Crossing
			check("the Crossing found as a subzone", _count("subzone:sub_crossing") == 1 and String(disc.get("subzone")) == "crossing")
			disc.call("visit", Vector3(-40.0, 1.0, 64.0))
			disc.call("visit", Vector3(0.0, 10.0, -40.0))
			check("the Crossing found once", _count("subzone:sub_crossing") == 1)
			# --- fires on the map ---
			var fires := FireRoad.fires(get_tree(), p.global_position)
			print("WORLD33 fires: ", fires.map(func(f: Brazier) -> String: return "%s (%s) at %s" % [f.name, f.display_name(), f.global_position]))
			var marked := 0
			var posts := 0
			for f in fires:
				if f.is_in_group(&"map_marker") and String(f.get_meta(&"map_kind", "")) == "travel":
					marked += 1
				if f.get_node_or_null("EmberPost") != null:
					posts += 1
			check("every fire a travel marker (%d/%d)" % [marked, fires.size()], fires.size() >= 5 and marked == fires.size())
			check("every fire has an ember-post", posts == fires.size())
			shrine = main.get_node_or_null("Zone/Braziers/Shrine") as Brazier
			landing = main.get_node_or_null("Zone/Braziers/Landing") as Brazier
			check("shrine and landing fires exist", shrine != null and landing != null)
			if shrine == null or landing == null:
				step = 99
				return
			# a cold fire is no destination
			check("no road to a cold fire", landing.lit or FireRoad.travel(shrine, landing) == null)
			shrine.kindle_quiet()
			landing.kindle_quiet()
			check("a lit fire's map colour is warm", landing.get_meta(&"map_color") == Brazier.MAP_LIT)
			p.teleport(shrine.spawn_point())
			step = 1
			wait = 20
		1:
			# --- the road is shut in a boss fight ---
			var arena: Node = get_tree().get_first_node_in_group(&"boss_arena")
			if arena:
				arena.set("_active", true)
				var why := FireRoad.blocked_reason(get_tree())
				var f := FireRoad.travel(shrine, landing)
				arena.set("_active", false)
				check("blocked in a boss fight (%s)" % why, why != "" and f == null)
			else:
				check("a boss arena to test against", false)
			var post := shrine.get_node("EmberPost")
			check("the ember-post offers the road at a lit fire", bool(post.call("can_interact")))
			# --- the menu ---
			var m := FireRoad.open(shrine)
			var rows: Array = (m.get("_list") as Node).get_children()
			check("the menu lists the other fires (%d rows)" % rows.size(), rows.size() >= 4)
			check("the menu pauses the night", get_tree().paused)
			m.call("close")
			check("closing the menu unpauses", not get_tree().paused)
			var why2 := FireRoad.blocked_reason(get_tree())
			if why2 != "":
				print("WORLD33 note: road blocked at the shrine (%s): clearing nearby foes" % why2)
			step = 2
			wait = 2
		2:
			# "something hunts you" is any foe on the wanderer, however far: clear them all (a busy
			# machine gives a distant one time to notice), and try again until the road is clear
			for e in get_tree().get_nodes_in_group(Groups.ENEMY):
				(e as Node).remove_from_group(Groups.ENEMY)
				(e as Node).queue_free()
			if FireRoad.blocked_reason(get_tree()) != "" and _road_tries < 30:
				_road_tries += 1
				wait = 2
				return
			flight = FireRoad.travel(shrine, landing)
			check("the flight starts", flight != null)
			if flight == null:
				step = 4
				return
			check("the wanderer is hidden in flight", not p.visible)
			check("a second road is shut while flying", FireRoad.blocked_reason(get_tree()) != "")
			t0 = t
			step = 3
		3:
			if is_instance_valid(flight) and not bool(flight.get("landed")):
				return
			var at := landing.spawn_point()
			check("landed at the barrow fire (%.1f m off, %.1f s)" % [p.global_position.distance_to(at), float(t - t0) / 60.0], p.global_position.distance_to(at) < 2.0)
			check("the wanderer is back", p.visible and p.process_mode != Node.PROCESS_MODE_DISABLED)
			var cam := get_viewport().get_camera_3d()
			check("the camera is the wanderer's again", cam != null and p.is_ancestor_of(cam))
			check("fire_travelled Shrine -> Landing", travelled.size() == 1 and travelled[0] == ["Shrine", "Landing"])
			check("the far fire is the checkpoint", p.checkpoint.distance_to(at) < 1.0)
			step = 4
			wait = 30
		4:
			# --- a world event ---
			check("a surge can be called at the Almonry", bool(we.call("start_event", "almonry")))
			var marker := false
			for n in get_tree().get_nodes_in_group(&"map_marker"):
				if String(n.get_meta(&"map_label", "")) == "Gloom Surge":
					marker = true
			check("the surge is on the map", marker)
			check("warned", events.has("surge_almonry:warn"))
			we.call("arrive")
			check("it breaks open when reached (%d foes)" % (we.get("foes") as Array).size(), String(we.get("phase")) == "active" and (we.get("foes") as Array).size() > 0)
			var ash := Travel.count("grave_ash")
			we.call("win_now")
			check("won: the reward hook fires", events.has("surge_almonry:won"))
			check("won: ash given", Travel.count("grave_ash") >= ash + 24)
			check("the surge's pillar is gone", String(we.get("phase")) == "idle")
			step = 99
		99:
			print("WORLD33 done, %d FAIL" % fails if fails > 0 else "WORLD33 ALL PASS")
			get_tree().quit(1 if fails > 0 else 0)
