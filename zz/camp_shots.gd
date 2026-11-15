extends Node
## Stills of the camps as planted (windowed): for each chosen camp an overhead view (16 m up, 12 m out, from the
## clearest bearing) and a walk
## view (eye height, WALK m out along the way it is met from, looking at it). The pawns are frozen where they stand;
## a survey light hangs over each camp (--dark: the game's own night only). Guardians and rares within 40 m of a camp
## are raised for its views. Saves held (Travel._busy).
##   godot --path . res://zz/camp_shots.tscn -- --out=<dir> [--camps=keep,crater,camp12] [--reaches] [--dark] [--views=top,walk] [--walk=16]
## --camps: substrings of a camp's "name" or "campNN" (its index in EnemySpawner.REALM_CAMPS, from 1, as the audit
## numbers them); --reaches: every Far Reaches camp (core/enemy/realm_camps_reaches.gd).
const ReachCamps := preload("res://core/enemy/realm_camps_reaches.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const SETTLE := 14
var walk := 16.0                 ## --walk=m: how far out the walk view stands
var main: Node
var out := "/tmp"
var picks: Array[String] = []
var reaches := false
var dark := false
var want := ["top", "walk"]
var shots: Array = []            ## [file, eye, target, centre]
var cam: Camera3D
var light: OmniLight3D
var p: Player
var i := -1
var wait := 0
var ready_go := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true
	Travel.bosses_slain.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--camps="):
			for c in a.trim_prefix("--camps=").split(","):
				picks.append(c)
		elif a == "--reaches":
			reaches = true
		elif a == "--dark":
			dark = true
		elif a.begins_with("--walk="):
			walk = float(a.trim_prefix("--walk="))
		elif a.begins_with("--views="):
			want = Array(a.trim_prefix("--views=").split(","))
	get_window().size = Vector2i(1024, 640)
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	if not ready_go:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		var sp := main.get_node_or_null("EnemySpawner") as EnemySpawner
		if p == null or sp == null or not sp.settled or not main.has_meta("realm_done"):
			return
		ready_go = true
		_plan(sp)
		return
	if i >= 0 and i < shots.size():
		_hold(shots[i])
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := out.path_join(String(shots[i][0]))
		get_viewport().get_texture().get_image().save_png(path)
		print("CAMPSHOT ", path)
	i += 1
	if i >= shots.size():
		print("CAMPSHOTS done (%d)" % shots.size())
		get_tree().quit()
		return
	_hold(shots[i])
	_raise_near(shots[i][3])
	wait = SETTLE


func _plan(sp: EnemySpawner) -> void:
	(p.get_node("Visual") as Node3D).visible = false
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	for n: String in ["Encounters", "Rares", "RoamEvents", "WorldEvents"]:
		var node := main.get_node_or_null(n)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	sp.process_mode = Node.PROCESS_MODE_DISABLED
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e is Enemy:
			(e as Enemy).sleep()                      # frozen, still drawn
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.08
	add_child(cam)
	cam.make_current()
	if not dark:
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.95, 0.88)
		light.light_energy = 2.2
		light.omni_range = 46.0
		light.omni_attenuation = 0.6
		add_child(light)
	var centres := {}
	for slot: Dictionary in sp.slots():
		var ck := String(slot.key).get_slice("#", 0)
		if not centres.has(ck) and slot.has("center"):
			centres[ck] = slot.center
	var reach_keys := {}
	for c: Dictionary in ReachCamps.CAMPS:
		reach_keys[str(c.at)] = true
	var space := (main as Node3D).get_world_3d().direct_space_state
	var n := 0
	for cp: Dictionary in EnemySpawner.REALM_CAMPS:
		n += 1
		var nm := String(cp.get("name", ""))
		var tag := "camp%02d" % n
		var hit := reaches and reach_keys.has(str(cp.at))
		for pk in picks:
			if tag == pk or (nm != "" and nm.contains(pk)):
				hit = true
		if not hit or not centres.has(str(cp.at)):
			continue
		var c: Vector3 = centres[str(cp.at)]
		var file := "%s_%s" % [tag, nm.replace(" ", "_").replace("'", "")]
		if "top" in want:
			shots.append(["%s_top.png" % file, _overhead(c), c, c])
		if "walk" in want:
			var from := _approach(Vector2(c.x, c.z))
			var e2 := Vector2(c.x, c.z) + from * walk
			var gy := RealmLayout.ground(space, e2.x, e2.y)
			shots.append(["%s_walk.png" % file, Vector3(e2.x, gy + 1.7, e2.y), c + Vector3.UP * 1.0, c])
	print("CAMPSHOTS planned %d views" % shots.size())


## The overhead eye: 16 m up and 12 m out (a 53 degree look down), from whichever of eight bearings has the fewest
## trees (RealmFlora.trees) near the line of sight, so a pine's crown does not fill the view.
func _overhead(c: Vector3) -> Vector3:
	var best := Vector3.INF
	var fewest := 1 << 30
	for k in 8:
		var a := TAU * float(k) / 8.0
		var eye := c + Vector3(cos(a) * 12.0, 16.0, sin(a) * 12.0)
		var n := 0
		for tr: Array in Flora.trees:
			var tp: Vector3 = tr[0]
			var q := Vector2(tp.x, tp.z)
			var a2 := Vector2(c.x, c.z)
			var b2 := Vector2(eye.x, eye.z)
			var ab := b2 - a2
			var t := clampf((q - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if q.distance_to(a2 + ab * t) < 5.0 + float(tr[2]):
				n += 1
		if n < fewest:
			fewest = n
			best = eye
	return best


## The bearing (unit xz, from the camp) a walker comes from: the nearest way's nearest point, else the south.
func _approach(c: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var bd := INF
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var ab := b - a
			var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var q := a + ab * t
			if q.distance_to(c) < bd:
				bd = q.distance_to(c)
				best = q
	if bd > 60.0 or bd < 0.5:
		return Vector2(0.0, 1.0)
	return (best - c).normalized()


func _hold(s: Array) -> void:
	var eye: Vector3 = s[1]
	var tgt: Vector3 = s[2]
	cam.global_position = eye
	cam.look_at(tgt, Vector3.UP if absf((tgt - eye).normalized().y) < 0.98 else Vector3.FORWARD)
	if light:
		light.global_position = (s[3] as Vector3) + Vector3(0.0, 14.0, 0.0)
	p.global_position = (s[3] as Vector3) + Vector3(0.0, 40.0, 0.0)        # the streaming follows the view, out of the frame
	p.velocity = Vector3.ZERO


## The guardian and the rares whose ground is near the camp rise for its views (frozen like the rest).
func _raise_near(c: Vector3) -> void:
	var enc := main.get_node_or_null("Encounters")
	if enc:
		var g := enc.get("guardians") as Node
		if g:
			g.call("refresh_sites")
			for s: Dictionary in g.get("sites"):
				if (s.at as Vector3).distance_to(c) < 40.0 and not (g.get("nodes") as Dictionary).has(s.key):
					var e: Variant = g.call("spawn", s)
					if e is Enemy:
						(e as Enemy).sleep()
	var rr := main.get_node_or_null("Rares")
	if rr:
		var haunts: Dictionary = rr.get("haunts")
		for id: String in haunts:
			if (haunts[id] as Vector3).distance_to(c) < 40.0:
				var e2: Variant = rr.call("spawn_rare", id)
				if e2 is Enemy:
					(e2 as Enemy).sleep()
