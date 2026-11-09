extends Node
## The Star-Fall Crater (core/world/realm/wonders/star_crater.gd), headless, in the built Realm:
##   build    the crater node, its marker and its solid pieces exist; the glass floor holds a ray
##   climb    the ridge's plates rise by no more than a jump from the floor to the shelf under the heart and
##            overlap in plan (a walk of jumps), the shelf carries the marker
##   secret   core/life/secrets/site_star_crater.gd builds on the marker; its case opens once and is remembered
##   quest    core/story/quest_chains_star_crater.gd: the giver exists, the visit point is on the crater, the
##            stake-book lies on clear glass
## Never writes the player's save (Travel._busy). Ends: STAR CRATER TEST PASS  /  STAR CRATER TEST FAIL n

const State := preload("res://core/life/secrets/state.gd")
const Site := preload("res://core/life/secrets/site_star_crater.gd")
const Quest := preload("res://core/story/quest_chains_star_crater.gd")
const Cast := preload("res://core/life/village/village_cast.gd")

var main: Node
var fails := 0


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if main == null or not main.has_meta("realm_done"):
		return
	set_process(false)
	await get_tree().create_timer(3.0).timeout
	_run()


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("STAR CRATER FAIL ", what)


func _run() -> void:
	var sp: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var crater := main.get_node_or_null("StarCrater") as Node3D
	_check(crater != null, "the crater node exists")
	if crater == null:
		_finish()
		return
	var marker := crater.get_node_or_null("HeartPlatform") as Node3D
	_check(marker != null, "the platform marker exists")
	var top: Vector3 = marker.get_meta("top")
	var floor_y: float = marker.get_meta("floor")
	# the glass floor holds a ray at the centre-ish of the bowl
	var h := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(172.0, 40.0, 148.0), Vector3(172.0, -10.0, 148.0), Layers.WORLD))
	_check(not h.is_empty() and (h.collider as Node).name == "GlassBody", "the glass floor is solid at (172,148)")
	# the ridge: plates (by body) sorted by the height of their walking face
	var plates: Array = []
	for n in crater.get_children():
		if n is StaticBody3D and (String(n.name).begins_with("ridge_") or n.name == &"shelf_Body") and String(n.name).ends_with("_Body"):
			plates.append(n)
	_check(plates.size() >= 8, "the ridge stands (%d plates and the shelf)" % plates.size())
	plates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.y < b.position.y)
	var last_y := floor_y
	var last_xz := Vector2.ZERO
	for i in plates.size():
		var p := plates[i] as Node3D
		var rise := p.position.y - last_y
		_check(rise <= 0.9, "plate %d rises %.2f m (a single jump is 0.85)" % [i, rise])
		if i > 0:
			var d := Vector2(p.position.x, p.position.z).distance_to(last_xz)
			_check(d <= (3.6 if i < plates.size() - 1 else 5.8), "plate %d is %.1f m along from the last (they overlap in plan)" % [i, d])
		last_y = p.position.y
		last_xz = Vector2(p.position.x, p.position.z)
	_check(absf(last_y - top.y) < 0.05, "the last body is the shelf under the heart (%.2f vs %.2f)" % [last_y, top.y])
	# the secret
	Site.build(main, State.host)
	var cache := State.host.find_child("Cache_star_crater", true, false)
	_check(cache != null, "the surveyors' case exists")
	if cache != null:
		_check(not State.has("looted", "star_crater"), "the case starts shut")
		(cache.get("action") as Callable).call(null)
		_check(State.has("looted", "star_crater"), "opening the case is remembered")
	_check(Site.STAR_REWARD.size() > 0 and String(Site.STAR_PAGE.text).length() > 40, "the secret's reward and page are written")
	# the quest
	var q: Dictionary = Quest.STAR_LAMP
	_check(Cast.CAST.has(String(q.giver)) or Cast.OUTPOSTS.has(String(q.giver)), "the giver %s exists" % q.giver)
	var visit: Dictionary = q.steps[0]
	_check((visit.at as Vector2).distance_to(Vector2(178.0, 146.0)) < 4.0, "the visit point is the crater")
	var pk: Dictionary = Quest.STAR_BOOK
	var near: Vector2 = pk.near
	var g := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(near.x, 40.0, near.y), Vector3(near.x, -10.0, near.y), Layers.WORLD))
	_check(not g.is_empty() and (g.collider as Node).name == "GlassBody" and (g.position as Vector3).y < floor_y + 1.0, "the stake-book lies on open glass")
	_finish()


func _finish() -> void:
	print("STAR CRATER TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	get_tree().quit()
