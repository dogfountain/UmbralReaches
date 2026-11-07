extends Node
## Living-world renders (r28), windowed:
##   godot --path . res://zz/world_shots.tscn -- --tag=after [--only=storm,rain,...]
##   godot --path . res://zz/world_shots.tscn -- --tag=before --scape-off      (the r23 world, same views)
## Writes shots/agentF_<view>_<tag>.png. Views: storm (a near strike), rain (splashes on the road),
## meteors (a shower, 24 frames max-stacked: a long exposure), surge (the vortex flaring), wisp,
## hart (the white hart), owl (an owl over its mouse), fox (a pounce), lapwings (the flock up),
## tracks (prints where the herd ran), mist (banks in the fen).
## Saves are locked (Travel._busy); the HUD is hidden; enemies are cleared.
const RL := preload("res://core/world/realm/realm_land.gd")
const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const LifeGroup := preload("res://core/life/wildlife/life_group.gd")
const OUT := "/private/tmp/claude-501/-Users-luke-UmbralReaches/968888c4-6238-49b1-a0f8-2ba292b49c0a/scratchpad/wave6/game/"

var t := 0.0
var main: Node
var started := false
var cam: Camera3D
var tag := "after"
var only: Array = []
var w: Node3D
var player: CharacterBody3D
var off := false


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.trim_prefix("--tag=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(","))
	off = "--scape-off" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if Time.get_ticks_msec() > 480000:             # WATCHDOG (real time): never outlive a stuck step
		print("WORLD TIMEOUT after %.0f s" % (Time.get_ticks_msec() / 1000.0))
		Engine.time_scale = 1.0
		get_tree().quit(1)
		return
	if cam != null and not cam.current:
		cam.current = true
	if started:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if not (e as Node).is_queued_for_deletion():
				(e as Node).queue_free()
		return
	if main == null or not main.has_meta("realm_done") or main.get_node_or_null("Wildlife") == null or t < 10.0:
		if t > 160.0:
			print("SHOTS realm never finished")
			get_tree().quit()
		return
	started = true
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _put(p: Vector3) -> void:
	var y := RealmLayout.ground(player.get_world_3d().direct_space_state, p.x, p.z)
	player.global_position = Vector3(p.x, maxf(y, p.y) + 0.2, p.z)
	player.velocity = Vector3.ZERO
	await _frames(2)


## A camera spot `dist` m from the subject at eye height h with a clear view: open ground, no canopy,
## nothing solid between (tries round the circle, nearest to `pref` direction first).
func _frame(target: Vector3, dist: float, h: float, aim_h := 0.5, pref := 0.0) -> void:
	var sp := player.get_world_3d().direct_space_state
	var best := Vector3.INF
	for k in 24:
		var a := pref + float((k + 1) / 2) * 0.27 * (1.0 if k % 2 == 0 else -1.0)
		var q := target + Vector3(sin(a), 0, cos(a)) * dist
		var gy := RL.height_at(q.x, q.z)
		var c := Vector3(q.x, gy + h, q.z)
		if RL.in_water(q.x, q.z) or LifePlace.Flora.cover_at(q.x, q.z) > 0.15:
			continue
		var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(c, target + Vector3(0, aim_h, 0)))
		if not hit.is_empty() and (hit.position as Vector3).distance_to(target) > 1.0:
			continue
		best = c
		break
	if best == Vector3.INF:
		best = target + Vector3(0, h, dist)
	cam.global_position = best
	cam.look_at(target + Vector3(0, aim_h, 0))


func _view(at: Vector3, look: Vector3) -> void:
	var gy := RL.height_at(at.x, at.z)
	cam.global_position = Vector3(at.x, gy + at.y, at.z)
	var ly := RL.height_at(look.x, look.z) + look.y
	cam.look_at(Vector3(look.x, ly, look.z))


func _save(view: String, img: Image = null) -> void:
	if img == null:
		img = get_viewport().get_texture().get_image()
	var path := OUT + "%s_%s.png" % [view, tag]
	DirAccess.make_dir_recursive_absolute(OUT)
	img.save_png(path)
	print("SHOTS saved ", path)


func _want(v: String) -> bool:
	return only.is_empty() or v in only


func _look(at: Vector3, from: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)


func _setup() -> void:
	w = main.get_node("Wildlife")
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as CharacterBody3D
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	player.visible = false
	var pc := get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.fov = pc.fov if pc != null else 70.0
	cam.far = pc.far if pc != null else 82.0
	cam.near = 0.08
	if pc != null and pc.attributes != null:
		cam.attributes = pc.attributes
	get_tree().root.add_child(cam)
	cam.current = true


func _herd_view(kinds: Array, dist: float, tagn: String) -> void:
	var best: Node3D = null
	var n := 0
	for g in w.groups:
		if String(g.kind) in kinds and (g.positions() as Array).size() > n:
			n = (g.positions() as Array).size()
			best = g
	if best == null:
		print("ART no group ", kinds)
		return
	var p: Vector3 = best.positions()[0]
	await _put(p + Vector3(20, 0, 0))
	_frame(p, dist, 1.6, 0.9, 0.5)
	await _frames(8)
	p = best.positions()[0]
	_frame(p, dist, 1.3, 0.9, 0.5)
	await _frames(2)
	_save(tagn)


func _run() -> void:
	_setup()
	var wx: Node3D = w.weather
	var ph: Node3D = w.get("phenomena")
	if ph != null:
		ph.quiet = true
	wx.force("clear", true)
	await _secs(1.0)
	var home := player.global_position
	print("ART home ", home)
	if _want("herd"):
		await _herd_view(["deer", "elk", "stag"], 7.0, "herd")
		await _herd_view(["deer", "elk", "stag"], 3.5, "herd_close")
	if _want("beasts"):
		for k: String in ["fox", "hare", "boar"]:
			await _herd_view([k], 3.0, "beast_" + k)
	if _want("wisp"):
		var holders: Array = []
		for l in get_tree().root.find_children("*", "OmniLight3D", true, false):
			if l.has_meta("glimmer") and l.get_parent() is Node3D and not (l.get_parent() is Glimmers):
				holders.append(l.get_parent())
		print("ART wisps ", holders.size())
		if holders.size() > 0:
			var hp: Vector3 = (holders[0] as Node3D).global_position
			await _put(hp + Vector3(8, 0, 0))
			for d in [6.0, 2.5, 1.0]:
				_look(hp, hp + Vector3(d, 0.3, 0.2))
				await _secs(0.6)
				_save("wisp_%d" % int(d * 10))
	if _want("rain"):
		wx.force("drizzle", true)
		await _secs(4.0)
		for i in 4:
			var a := float(i) * PI * 0.5
			_look(home + Vector3(0, 1.6, 0) + Vector3(sin(a), 0, cos(a)) * 6.0, home + Vector3(0, 1.6, 0) + Vector3(-sin(a), 0, -cos(a)) * 1.5)
			await _secs(0.8)
			_save("rain_%d" % i)
		wx.force("clear", true)
	if _want("charm"):
		for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
			var sc := (n as Node).get_script() as Script
			if sc != null and sc.resource_path.ends_with("charm_pickup.gd"):
				var cp: Vector3 = (n as Node3D).global_position
				await _put(cp + Vector3(0, 0, 8))
				_look(cp + Vector3(0, 0.3, 0), cp + Vector3(1.2, 0.9, 1.6))
				await _secs(1.0)
				_save("charm")
				_look(cp + Vector3(0, 0.3, 0), cp + Vector3(0.3, 0.5, 0.9))
				await _secs(0.4)
				_save("charm_close")
				break
	if _want("lamps"):
		var seen := {}
		for n in get_tree().get_nodes_in_group(&"lamp"):
			var lk := String(n.get("look"))
			if seen.has(lk):
				continue
			seen[lk] = true
			var lp: Vector3 = (n as Node3D).global_position
			await _put(lp + Vector3(6, 0, 0))
			_look(lp + Vector3(0, 1.3, 0), lp + Vector3(3.2, 1.6, 1.8))
			await _secs(0.8)
			_save("lamp_" + lk)
	if _want("escort"):
		var Sig := load("res://core/story/quest_chains_signature.gd")
		var stp: Dictionary = (Sig.MERE_FERRY.steps as Array)[2]
		var pth: Array = stp.path
		var a: Vector2 = pth[0]
		var b: Vector2 = pth[1]
		var mid := (a + b) * 0.5
		await _put(Vector3(a.x, 0, a.y))
		var ap := Vector3(a.x, RL.height_at(a.x, a.y), a.y)
		for n in get_tree().root.find_children("*", "Node3D", true, false):
			if (n as Node3D).global_position.distance_to(ap) < 9.0 and (n is Lamp or String(n.name).to_lower().contains("lamp") or String(n.name).to_lower().contains("lantern")):
				print("ART near ", n.get_path(), " ", n.get_class(), " ", (n as Node3D).global_position.distance_to(ap))
		for i in 3:
			var an := float(i) * 2.1
			_look(ap + Vector3(0, 0.6, 0), ap + Vector3(sin(an) * 5.0, 2.2, cos(an) * 5.0))
			await _secs(0.8)
			_save("escort_%d" % i)
	if _want("ferry"):
		var fl := get_tree().root.find_child("Lamp_ferry_lamp", true, false) as Node3D
		if fl != null:
			var fp := fl.global_position
			await _put(fp + Vector3(5, 0, 0))
			_look(fp + Vector3(0, 2.2, 0), fp + Vector3(2.6, 1.9, 1.4))
			await _secs(1.0)
			_save("ferry_lamp")
		var QP := load("res://core/story/quest_props.gd")
		var holder := Node3D.new()
		get_tree().root.add_child(holder)
		var xf := Transform3D(Basis.IDENTITY, home + Vector3(3, 0, 0))
		xf.origin.y = RL.height_at(xf.origin.x, xf.origin.z)
		QP.make(holder, "Lan", "lantern_lit", xf)
		await _put(home + Vector3(3, 0, 3))
		_look(xf.origin + Vector3(0, 0.15, 0), xf.origin + Vector3(0.6, 0.5, 0.9))
		await _secs(0.8)
		_save("quest_lantern")
	if _want("rainwall"):
		wx.force("drizzle", true)
		await _secs(4.0)
		var sp := player.get_world_3d().direct_space_state
		var found := 0
		for i in 16:
			var ang := float(i) * TAU / 16.0
			var o := home + Vector3(0, 1.5, 0)
			var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + Vector3(sin(ang), 0, cos(ang)) * 14.0))
			if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
				continue
			var hp2: Vector3 = hit.position
			_look(hp2, hp2 + (hit.normal as Vector3) * 2.4 + Vector3(0, 0.2, 0))
			await _secs(0.8)
			_save("rainwall_%d" % found)
			found += 1
			if found >= 3:
				break
		wx.force("clear", true)
	if _want("bone"):
		var AK := load("res://core/enemy/attack_kit.gd")
		var bp := home + Vector3(6, 0, 0)
		bp.y = RL.height_at(bp.x, bp.z)
		await _put(bp + Vector3(0, 0, 6))
		_look(bp + Vector3(0, 3.5, 0), bp + Vector3(-1.5, 1.8, 3.5))
		for i in 3:
			AK.lob(bp + Vector3(i - 1, 8.0, 0), bp + Vector3(i - 1, 0.3, 0), 2.0, Color(2.2, 1.9, 1.4))
		await _secs(1.3)
		_save("bone")
	print("ART done")
	get_tree().quit()
