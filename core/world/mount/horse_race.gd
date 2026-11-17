class_name HorseRace
extends Node
## The Hearthward horse race. Begun from the Race page of the stable panel (ui/horse_panel.gd) while mounted on a horse you
## own, within sight of the Hearthward rail. Four courses (horse_race_data.gd), laid on the ground when the ritual starts; three
## rivals wake from where they were parked (horse_race_field.gd), line up beside you, and Fennick calls the start: a herald line,
## Ready, Hold, Now (a sound on each beat). Leaving the line before Now costs two seconds. Gates are passed in order (the next is a
## beacon on the compass and the dial, the one after a dimmer one); the last gate is the line again. Place, medal and a purse
## follow: grave ash by place, ember shards for a medal, a first-win purse for each course and the Hearthward Cup for all four.
## Best times live in the profile (shared by every save) under "race:<course>"; the Count keeps races run and won.
## The race is never saved: a reload or fast travel finds no race. It ends when you are hollowed, leave the saddle for eight
## seconds, ride 600 m from the line, camp or enter a warden's fight. The Ember Road is shut during it (fire_road.gd asks `active()`).
## Cost: nothing at all with no race (processing is off). During a race: the rivals' arithmetic per frame, five short rays each
## fifteen times a second, a ten-Hz check of gates, a label four times a second. No lights, no allocation per frame.
## A child of the story director.

const Data := preload("res://core/world/mount/horse_race_data.gd")
const Field := preload("res://core/world/mount/horse_race_field.gd")
const Rival := preload("res://core/world/mount/horse_race_rival.gd")
const Horse := preload("res://core/world/mount/horse.gd")
const HorseBond := preload("res://core/world/mount/horse_bond.gd")
const Profile := preload("res://core/util/profile.gd")
const Chronicle := preload("res://core/story/chronicle.gd")
const Tally := preload("res://core/story/tally.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const UiSound := preload("res://ui/ui_sound.gd")

signal finished(course: String, place: int, secs: float)

static var _live := false

var _phase := ""                 ## "" | "line" | "run" | "after"
var _course := ""
var _pts: Array[Vector3] = []    ## the gates, the last being the line
var _start := Vector3.ZERO
var _length := 0.0
var _gate := 0
var _t := 0.0
var _pen := 0.0
var _count := 0.0
var _beat := 0
var _line_at := Vector3.ZERO     ## where the player stood as the ritual began (false-start test)
var _false := false
var _mount: Node3D
var _off := 0.0
var _rs: Array[Dictionary] = []
var _rh: Array[Node3D] = []
var _names: Array[String] = []
var _steer := 0.0
var _check := 0.0
var _hud := 0.0
var _after := 0.0
var _results: Array[Array] = []  ## [name, seconds, is_player]
var _marks: Array[Node3D] = []
var _layer: CanvasLayer
var _label: Label
var _big: Label


static func active() -> bool:
	return _live


static func best_key(id: String) -> String:
	return "race:" + id


static func _st() -> Dictionary:
	var d: Variant = Travel.story.get("race", null)
	if not (d is Dictionary):
		d = {}
		Travel.story["race"] = d
	return d as Dictionary


## Courses won at least once (ids).
static func won() -> Array:
	var w: Variant = _st().get("won", null)
	return w as Array if w is Array else []


func _ready() -> void:
	name = "HorseRace"
	add_to_group(&"horse_race")
	_live = false
	Events.hollowed.connect(func() -> void:
		if _live:
			_end("You fall, and the race goes on without you."))
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_label = _mk(20, Color(1.0, 0.82, 0.5), 96.0)
	_big = _mk(54, Color(1.0, 0.9, 0.65), 190.0)
	set_process(false)


func _mk(size: int, col: Color, top: float) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	l.offset_top = top
	l.offset_left = -400.0
	l.offset_right = 400.0
	l.visible = false
	_layer.add_child(l)
	return l


func _stables() -> Node:
	return get_tree().get_first_node_in_group(&"stables")


func _rail() -> Node3D:
	return Courier.post_of(get_tree(), "palfrey")


## Why the race cannot begin now ("" = it can).
func why_not() -> String:
	var rail := _rail()
	var st := _stables()
	if rail == null or st == null or (st.get("rivals") as Array).is_empty():
		return "There is no race here: the stable-yard is closed."
	if _live:
		return "A race is already under way."
	if Courier.active():
		return "You carry a parcel. Deliver it first."
	if Player.boss_fight_active(get_tree()):
		return "Not in a warden's fight."
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		return "No one to ride."
	var h := p.riding as Horse
	if h == null or not h.owned():
		return "Mount a horse of your own first, then come back to the rail."
	if p.global_position.distance_to(rail.global_position) > 36.0:
		return "Take the line at the Hearthward rail."
	return ""


## Begin the ritual for a course. "" on success, else why not.
func begin(id: String) -> String:
	var why := why_not()
	if why != "":
		return why
	if not Data.COURSES.has(id):
		return "No such course."
	var rail := _rail()
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	_start = _line_for(p, rail)
	var pts := _lay(id, _start)
	if pts.size() < 3:
		return "The ground will not make that course from here tonight."
	_course = id
	_pts = pts
	var ring: Array[Vector3] = [_start]
	ring.append_array(pts)
	ring.pop_back()
	_length = Data.length_of(ring)
	_gate = 0
	_t = 0.0
	_pen = 0.0
	_off = 0.0
	_false = false
	_beat = 0
	_count = 0.0
	_after = 0.0
	_results.clear()
	_mount = p.riding
	_line_at = p.global_position
	_phase = "line"
	_live = true
	_line_up(p)
	_marks_update()
	Events.toast.emit("%s. %s" % [String(Data.COURSES[id].name), String(Data.HERALD[randi() % Data.HERALD.size()])])
	UiSound.play(self, "tab")
	set_process(true)
	return ""


## The start line: where the player stands, nudged onto the rail's side of the yard.
func _line_for(p: Player, rail: Node3D) -> Vector3:
	var at := p.global_position
	if at.distance_to(rail.global_position) > 20.0:
		at = rail.global_position
	return at


func _ground(at: Vector3) -> Variant:
	var sp := get_tree().root.get_world_3d().direct_space_state
	var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 60.0, at.z), Vector3(at.x, at.y - 80.0, at.z), Layers.WORLD))
	return hit.position if not hit.is_empty() else null


## The gates of a course from the line: an ellipse laid on the ground, each point kept on dry, level-enough ground (pulled toward
## the centre a few times if it is not, dropped if it still is not). The last point is the line itself. Empty when too few remain.
func _lay(id: String, s: Vector3) -> Array[Vector3]:
	var d: Dictionary = Data.COURSES[id]
	for flip: int in [0, 1]:
		var ang := float(d.ang) + PI * flip
		var u := Vector3(sin(ang), 0.0, -cos(ang))
		var v := Vector3(-u.z, 0.0, u.x)
		var c := s + u * float(d.a)
		var out: Array[Vector3] = []
		var n := int(d.n)
		for k in range(1, n):
			var t := float(k) * TAU / float(n) * float(d.dir)
			var raw := c + u * (-float(d.a) * cos(t)) + v * (float(d.b) * sin(t))
			var good := Vector3.INF
			for shrink: int in 5:
				var q := c.lerp(raw, 1.0 - 0.12 * shrink)
				var g: Variant = _ground(q)
				if g != null:
					var gv: Vector3 = g
					if not RealmLand.in_water(gv.x, gv.z) and absf(gv.y - s.y) < 22.0:
						good = gv
						break
			if good != Vector3.INF:
				out.append(good)
		if out.size() >= 3:
			out.append(s)
			return out
	var none: Array[Vector3] = []
	return none


## Wake the rivals and line them up beside the player, facing the first gate.
func _line_up(_p: Player) -> void:
	var st := _stables()
	_rh.clear()
	_rs.clear()
	_names.clear()
	for r: Node3D in (st.get("rivals") as Array):
		_rh.append(r)
	var to := _pts[0] - _start
	to.y = 0.0
	var yaw := atan2(-to.x, -to.z)
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var pool_r := range(Data.RIDERS.size())
	pool_r.shuffle()
	var pool_h := range(Data.MOUNTS.size())
	pool_h.shuffle()
	var pace := float(Data.COURSES[_course].pace)
	for i in _rh.size():
		var at := _start + side * (4.0 + 3.6 * float(i)) * (1.0 if i % 2 == 0 else -1.0) + back * 1.5
		var g: Variant = _ground(at)
		Field.wake(_rh[i], g as Vector3 if g != null else at, yaw)
		_rs.append(Rival.start(_rh[i], pace * float(Data.FIELD[i])))
		_names.append("%s on %s" % [String(Data.RIDERS[pool_r[i]]), String(Data.MOUNTS[pool_h[i]])])
	_stop_rivals(true)


func _stop_rivals(stand: bool) -> void:
	for rs in _rs:
		rs["run"] = not stand


func _marks_update() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()
	for k in 2:
		var gi := _gate + k
		if gi >= _pts.size():
			break
		var m := Wayfarer.WayMark.new()
		m.name = "RaceMark%d" % k
		get_tree().current_scene.add_child(m)
		m.anchor = _pts[gi] + Vector3.UP * 3.0
		m.global_position = m.anchor
		m.tint = Color(1.0, 0.8, 0.4) if k == 0 else Color(0.7, 0.55, 0.3)
		m.add_to_group(&"landmark_beacon")
		_marks.append(m)


func _process(delta: float) -> void:
	if not _live:
		set_process(false)
		return
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p == null:
		return
	if get_tree().paused:
		return
	if p.process_mode == Node.PROCESS_MODE_DISABLED:
		_end("The race is called off.")                 # a camp, a scene: the player is not free
		return
	for i in _rh.size():
		Rival.move(_rh[i], _rs[i], delta, _near_h(_rh[i]))
	_steer -= delta
	if _steer <= 0.0:
		_steer = Rival.STEER_DT
		_steer_rivals()
	match _phase:
		"line":
			_count += delta
			_countdown(p)
		"run":
			_t += delta
		"after":
			_t += delta                             # the rivals' times still count from the Go
			_after += delta
	_check -= delta
	if _check <= 0.0:
		_check = 0.1
		_check_player(p)
	_hud -= delta
	if _hud <= 0.0:
		_hud = 0.25
		_show(p)


func _near_h(h: Node3D) -> bool:
	var cam := h.get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_squared_to(h.global_position) < 80.0 * 80.0


func _countdown(p: Player) -> void:
	var marks := [2.0, 3.0, 4.0, 5.0]
	if _beat < marks.size() and _count >= float(marks[_beat]):
		if _beat < 3:
			_big.text = String(Data.SET[_beat])
			_big.visible = true
			UiSound.play(self, "tab")
		else:
			_big.text = "GO"
			UiSound.play(self, "quest_new")
			_phase = "run"
			_stop_rivals(false)
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				if is_instance_valid(_big):
					_big.visible = false)
		_beat += 1
	if _phase == "line" and not _false and p.global_position.distance_to(_line_at) > 8.0:
		_false = true
		_pen = 2.0
		Events.toast.emit(String(Data.FALSE_START[randi() % Data.FALSE_START.size()]))


func _steer_rivals() -> void:
	var n := _pts.size()
	for i in _rh.size():
		var rs := _rs[i]
		if bool(rs.done) or not bool(rs.run):
			continue
		var gi := int(rs.gate)
		var pace := float(rs.pace)
		if gi - _gate >= 2:
			pace *= 0.93                        # well clear of the player: it eases
		elif _gate - gi >= 2:
			pace *= 1.05
		Rival.steer(_rh[i], rs, _pts[gi], pace, Rival.STEER_DT)
		var flat := Vector2(_rh[i].global_position.x - _pts[gi].x, _rh[i].global_position.z - _pts[gi].z)
		if flat.length() < Data.GATE_R:
			rs["gate"] = gi + 1
			if gi + 1 >= n:
				rs["done"] = true
				rs["want"] = 0.0
				rs["t"] = _t
				_results.append([_names[i], _t + 0.0, false])


func _check_player(p: Player) -> void:
	var tree := get_tree()
	if Player.boss_fight_active(tree):
		_end("The warden's fight has begun. The race is called off.")
		return
	if _phase == "after":
		if (_after > 20.0 and _rivals_unseen(p)) or _after > 90.0:
			_conclude()
		return
	if p.global_position.distance_to(_start) > 600.0:
		_end("You have ridden out of the race.")
		return
	if p.riding != _mount:
		_off += 0.1
		if _off > 8.0:
			_end(String(Data.OUT[randi() % Data.OUT.size()]))
			return
	else:
		_off = 0.0
	if _phase != "run":
		return
	var gp := _pts[_gate]
	if Vector2(p.global_position.x - gp.x, p.global_position.z - gp.z).length() < Data.GATE_R and absf(p.global_position.y - gp.y) < 8.0:
		_gate += 1
		UiSound.play(self, "confirm")
		if _gate >= _pts.size():
			_finish()
		else:
			_marks_update()


## No rival is where the camera can see it (so parking it cannot be seen).
func _rivals_unseen(p: Player) -> bool:
	var cam := get_viewport().get_camera_3d()
	for r in _rh:
		if cam != null and r.global_position.distance_to(p.global_position) < 70.0 and cam.is_position_in_frustum(r.global_position + Vector3.UP):
			return false
	return true


func _show(p: Player) -> void:
	_label.visible = true
	var c: Dictionary = Data.COURSES[_course]
	match _phase:
		"line":
			_label.text = "%s     take the line     %s" % [String(c.name), "false start" if _false else ""]
		"run":
			var ahead := 0
			var mine := _score(_gate, p.global_position)
			for i in _rs.size():
				if _score(int(_rs[i].gate), _rh[i].global_position) > mine:
					ahead += 1
			_label.text = "%s     gate %d of %d     %s     %s of %d" % [String(c.name), mini(_gate + 1, _pts.size()), _pts.size(), Courier.fmt(_t + _pen), Data.place_word(ahead), _rh.size() + 1]
		"after":
			_label.text = "%s     %s" % [String(c.name), Courier.fmt(float(_results_player_time()))]


## Progress along the course: gates passed, less the distance still to the next (for ranking, not for timing).
func _score(gate: int, at: Vector3) -> float:
	if gate >= _pts.size():
		return 1.0e6
	return float(gate) * 1000.0 - Vector2(at.x - _pts[gate].x, at.z - _pts[gate].z).length()


func _results_player_time() -> float:
	for r in _results:
		if bool(r[2]):
			return float(r[1])
	return _t + _pen


func _finish() -> void:
	var secs := _t + _pen
	_results.append(["You", secs, true])
	var place := 0
	for r in _results:
		if not bool(r[2]):
			place += 1
	_phase = "after"
	_after = 0.0
	_clear_marks()
	_reward(place, secs)
	finished.emit(_course, place, secs)


func _reward(place: int, secs: float) -> void:
	var c: Dictionary = Data.COURSES[_course]
	var medal := Data.medal(_length, secs)
	var ash := roundi(_length * float(c.pay) * float(Data.PLACE_PAY[mini(place, 3)]))
	var shard := 0
	match medal:
		"gold":
			ash = roundi(ash * 1.4)
			shard = 3
		"silver":
			shard = 1
	var st := _st()
	var w: Array = won()
	var first := place == 0 and not w.has(_course)
	if place == 0:
		if first:
			w.append(_course)
			st["won"] = w
			shard += 6
			ash += roundi(_length * 0.1)
	if Vows.has("luck"):
		ash = roundi(ash * 1.4)
		shard = roundi(shard * 1.4)
	Profile.ensure()
	var key := best_key(_course)
	var old := float(Profile.best.get(key, 0.0))
	var record := old <= 0.0 or secs < old
	if record:
		Profile.best[key] = snappedf(secs, 0.1)
		Profile.save()
	Travel.give("grave_ash", ash, false)
	if shard > 0:
		Travel.give("ember_shard", shard, false)
	var d := Tally.data()
	d["races"] = int(d.get("races", 0)) + 1
	if place == 0:
		d["race_wins"] = int(d.get("race_wins", 0)) + 1
	var h := _mount as Horse
	if h != null:
		HorseBond.add(h.breed, 40.0)
		HorseBond.set_spirit(h.breed, HorseBond.spirit(h.breed) - 8.0)
	var line: String
	if place == 0:
		line = String(Data.WON[randi() % Data.WON.size()])
	elif place < 3:
		line = String(Data.PLACED[place - 1])
	else:
		line = String(Data.LATE[randi() % Data.LATE.size()])
	Events.toast.emit("%s  %s in %s (%s)%s. +%d grave ash%s." % [line, Data.place_word(place), Courier.fmt(secs), medal, ", a best" if record else "", ash, (", +%d ember shard%s" % [shard, "" if shard == 1 else "s"]) if shard > 0 else ""])
	if first:
		Chronicle.write("race:" + _course, "road", "%s was won, with all Hearthward on the green." % String(c.name))
	if place == 0 and won().size() >= Data.ORDER.size() and not bool(st.get("cup", false)):
		st["cup"] = true
		Travel.give("ember_shard", 10, false)
		Events.toast.emit("All four courses won: the Hearthward Cup is yours. Fennick has had it polished for a year. +10 ember shards.")
		Chronicle.write("race:cup", "road", "The Hearthward Cup went to the wanderer, who had four courses and one horse.")
	Travel.save_soon()


## The after-run settles: the rivals who finished are walked off, the others are given up on.
func _conclude() -> void:
	var lines: PackedStringArray = []
	var rs_sorted := _results.duplicate()
	rs_sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	for i in rs_sorted.size():
		lines.append("%s %s  %s" % [Data.place_word(i), String((rs_sorted[i] as Array)[0]), Courier.fmt(float((rs_sorted[i] as Array)[1]))])
	Events.toast.emit("  ".join(lines))
	_end("")


func _clear_marks() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()


## Stop it: park the rivals, clear the beacons and the labels. `why` is said if not empty.
func _end(why: String) -> void:
	_live = false
	_phase = ""
	set_process(false)
	_clear_marks()
	_label.visible = false
	_big.visible = false
	for r in _rh:
		if is_instance_valid(r):
			Field.park(r)
	_rh.clear()
	_rs.clear()
	if why != "":
		Events.toast.emit(why)
