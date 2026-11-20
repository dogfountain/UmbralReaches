extends Node3D
## Numbers for the horse's feel: a scripted ride (real Horse under a real Player) over a studio course, sampled every
## RENDERED frame at a fixed 144 fps with 60 Hz physics (the worst case for stepping), and measured:
##   slide   a planted hoof's horizontal speed over the ground (m/s; 0 is a still hoof) per phase
##   sink    how far the fetlock height above the ground under it varies (std, cm) while planted: floating or sinking
##   hoofpop the biggest one-frame jump of a hoof beyond its smooth motion (cm)
##   rider   the pelvis against the barrel bone, in the horse's frame: std (cm) and biggest one-frame jump (cm)
##   cam     camera height: the part that is not the trend (peak of the 0.4 s high-pass, cm); biggest frame jerk
##   pitch   the body's pitch range (deg): how well the horse follows a slope
##   yaw     the horse's yaw rate: biggest one-frame change of it (deg/s per frame): a snap
##   godot --headless --fixed-fps 144 --path . res://zz/horse_feel_probe.tscn -- [--mode=straight|turns|course|dismount] [--breed=palfrey]
## Prints "HFEEL ..." lines and "HFEEL done". Never writes the save.

const HorseScript := preload("res://core/world/mount/horse.gd")
const WORLD := 1
const FPS := 144.0

var mode := "straight"
var breed := "palfrey"
var p: Player
var horse: Node3D
var cam: Camera3D
var t := 0.0
var started := false
var mounted := false
var dismounted := false
var end_t := 20.0
var heading := 0.0                       ## the wish's heading (rad, 0 = -z, + left)
var _ph := ""                            ## the phase label now
var _phases := {}                        ## label -> array of sample dictionaries


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.trim_prefix("--mode=")
		elif a.begins_with("--breed="):
			breed = a.trim_prefix("--breed=")
	Travel._busy = true
	Engine.max_fps = int(FPS)
	_box(Vector3(0, -0.5, -150), Vector3(80, 1, 400), Basis.IDENTITY)
	if mode == "course":
		# a kerb (0.22 m), a rise of 12 degrees up and down, a wall
		_box(Vector3(0, 0.11, -40), Vector3(30, 0.22, 3.0), Basis.IDENTITY)
		_box(Vector3(0, 1.1, -70), Vector3(30, 0.4, 30.0), Basis(Vector3.RIGHT, deg_to_rad(12.0)))
		_box(Vector3(0, 1.1, -108), Vector3(30, 0.4, 30.0), Basis(Vector3.RIGHT, deg_to_rad(-12.0)))
		_box(Vector3(0, 1.5, -150), Vector3(30, 3.0, 1.0), Basis.IDENTITY)
	_spawn_player()
	horse = HorseScript.new()
	horse.breed = breed
	add_child(horse)
	horse.global_position = Vector3.ZERO
	horse.reset_physics_interpolation()
	cam = p.get_node("CameraRig/Pitch/SpringArm/Camera") as Camera3D
	cam.current = true
	end_t = float({"straight": 22.0, "turns": 22.0, "course": 24.0, "dismount": 14.0}.get(mode, 22.0))


func _box(pos: Vector3, size: Vector3, basis: Basis) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	add_child(b)
	b.transform = Transform3D(basis, pos)


func _spawn_player() -> void:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.set_script(load("res://core/player/player.gd"))
	pl.floor_max_angle = 0.80285144
	pl.floor_snap_length = 0.5
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	pl.add_child(col)
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.set_script(load("res://core/player/character_rig.gd"))
	pl.add_child(vis)
	var r := Node3D.new()
	r.name = "CameraRig"
	r.position.y = 1.55
	pl.add_child(r)
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	r.add_child(pitch)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	pitch.add_child(arm)
	var pcam := Camera3D.new()
	pcam.name = "Camera"
	arm.add_child(pcam)
	pl.position = Vector3(-1.4, 0.05, 1.0)
	add_child(pl)
	p = pl as Player


## [label, from, to, w (stick length), sprint, heading deg]
func _script() -> Array:
	match mode:
		"turns":
			return [["stand", 0.0, 2.0, 0.0, false, 0.0], ["walk", 2.0, 4.0, 0.5, false, 0.0], ["trot", 4.0, 7.0, 1.0, false, 0.0],
				["trot_turn90", 7.0, 9.0, 1.0, false, 90.0], ["gallop", 9.0, 12.0, 1.0, true, 90.0], ["gallop_turn90", 12.0, 14.0, 1.0, true, 0.0],
				["gallop_turn180", 14.0, 17.0, 1.0, true, 180.0], ["halt", 17.0, 22.0, 0.0, false, 180.0]]
		"course":
			return [["stand", 0.0, 2.0, 0.0, false, 0.0], ["walk", 2.0, 3.0, 0.5, false, 0.0], ["canter", 3.0, 24.0, 1.0, true, 0.0]]
		"dismount":
			return [["stand", 0.0, 2.0, 0.0, false, 0.0], ["gallop", 2.0, 7.0, 1.0, true, 0.0], ["halt", 7.0, 14.0, 0.0, false, 0.0]]
	return [["stand", 0.0, 2.0, 0.0, false, 0.0], ["walk", 2.0, 5.0, 0.5, false, 0.0], ["trot", 5.0, 8.0, 1.0, false, 0.0], ["gallop", 8.0, 12.0, 1.0, true, 0.0],
		["hardstop", 12.0, 14.0, 0.0, false, 0.0], ["gallop2", 14.0, 17.0, 1.0, true, 0.0], ["to_walk", 17.0, 19.0, 0.5, false, 0.0], ["halt", 19.0, 22.0, 0.0, false, 0.0]]


func _physics_process(delta: float) -> void:
	if p == null:
		return
	p.gloom = 0.0
	p.wounds = 0.0
	if not started:
		t += delta
		if t > 0.5:
			started = true
			t = 0.0
		return
	t += delta
	if not mounted:
		mounted = true
		horse.mount(p)
	var w := Vector3.ZERO
	var sprint := false
	_ph = ""
	for s: Array in _script():
		if t >= float(s[1]) and t < float(s[2]):
			_ph = String(s[0])
			heading = deg_to_rad(float(s[5]))
			w = Vector3(-sin(heading), 0, -cos(heading)) * float(s[3])
			sprint = bool(s[4])
	p.debug_drive(w, sprint)
	if mode == "dismount" and t > 8.0 and not dismounted:
		dismounted = true
		horse.dismount()
	if t > end_t:
		_finish()


func _ground_y(at: Vector3) -> float:
	var sp := get_world_3d().direct_space_state
	var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 8.0, WORLD))
	return (hit.position as Vector3).y if not hit.is_empty() else at.y


func _process(dt: float) -> void:
	if p == null or not started or not mounted or dt <= 0.0:
		return
	var rig: Node3D = horse.get("_rig")
	var skel: Skeleton3D = rig.get("skel")
	if skel == null:
		return
	var s := {"t": t, "dt": dt}
	var xf := rig.global_transform
	s["root"] = xf.origin
	s["yaw"] = atan2(xf.basis.z.x, xf.basis.z.z)
	s["pitch"] = xf.basis.get_euler().x
	var hoof := []
	for l: String in ["fl", "fr", "hl", "hr"]:
		var bp := skel.get_bone_global_pose(skel.find_bone(l + "_fet")).origin
		var wp := skel.global_transform * bp
		hoof.append([wp, wp.y - _ground_y(wp)])
	s["hoof"] = hoof
	var vis: Node3D = horse.get("_vis")
	if vis != null:
		var barrel := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("barrel")).origin
		s["rider"] = xf.basis.inverse() * (vis.global_position - barrel)
	s["rider_w"] = p.get_node("Visual").global_position
	s["cam"] = cam.global_position
	s["speed"] = float(horse.get("speed"))
	var key := _ph
	if mode == "dismount" and dismounted:
		key = "dismount"
	if key == "":
		return
	if not _phases.has(key):
		_phases[key] = []
	(_phases[key] as Array).append(s)


func _stats(arr: Array) -> Dictionary:
	var n := arr.size()
	var out := {}
	if n < 6:
		return out
	var slide_sum := 0.0
	var slide_max := 0.0
	var slide_n := 0
	var hop_max := 0.0
	var sink_acc: Array[float] = []
	for li in 4:
		var lo := INF
		for s: Dictionary in arr:
			lo = minf(lo, float((s.hoof[li] as Array)[1]))
		for i in range(2, n):
			var a: Dictionary = arr[i - 1]
			var b: Dictionary = arr[i]
			var ha: Array = a.hoof[li]
			var hb: Array = b.hoof[li]
			if float(hb[1]) < lo + 0.035 and float(ha[1]) < lo + 0.035:
				var d: Vector3 = (hb[0] as Vector3) - (ha[0] as Vector3)
				d.y = 0.0
				var v := d.length() / float(b.dt)
				slide_sum += v
				slide_max = maxf(slide_max, v)
				slide_n += 1
				sink_acc.append(float(hb[1]))
			var c: Dictionary = arr[i - 2]
			var hc: Array = c.hoof[li]
			var d1: Vector3 = (hb[0] as Vector3) - (ha[0] as Vector3)
			var d0: Vector3 = (ha[0] as Vector3) - (hc[0] as Vector3)
			hop_max = maxf(hop_max, (d1 - d0).length())
	out["slide_mean"] = slide_sum / maxf(slide_n, 1)
	out["slide_max"] = slide_max
	out["hoofpop_cm"] = hop_max * 100.0
	var mean := 0.0
	for v in sink_acc:
		mean += v
	mean /= maxf(sink_acc.size(), 1)
	var var_s := 0.0
	for v in sink_acc:
		var_s += (v - mean) * (v - mean)
	out["sink_std_cm"] = sqrt(var_s / maxf(sink_acc.size(), 1)) * 100.0
	if (arr[0] as Dictionary).has("rider"):
		var m := Vector3.ZERO
		var rn := 0
		for s: Dictionary in arr:
			if s.has("rider"):
				m += s.rider
				rn += 1
		m /= maxf(rn, 1)
		var sd := Vector3.ZERO
		var jump := 0.0
		var jump_i := 0
		for i in n:
			if not (arr[i] as Dictionary).has("rider"):
				continue
			var r: Vector3 = (arr[i] as Dictionary).rider
			sd += (r - m) * (r - m)
			if i > 0 and (arr[i - 1] as Dictionary).has("rider"):
				var jd := (r - ((arr[i - 1] as Dictionary).rider as Vector3)).length()
				if jd > jump:
					jump = jd
					jump_i = i
		out["rider_std_cm"] = Vector3(sqrt(sd.x / rn), sqrt(sd.y / rn), sqrt(sd.z / rn)) * 100.0
		out["rider_jump_cm"] = jump * 100.0
		var around := []
		for k in range(maxi(jump_i - 3, 0), mini(jump_i + 3, n)):
			around.append(snappedf(((arr[k] as Dictionary).rider as Vector3).y * 100.0, 0.1))
		out["rider_y_around_jump_cm"] = str(around)
	var win := int(0.4 * FPS)
	var pp := 0.0
	var pp_root := 0.0
	var cjerk := 0.0
	for i in range(win, n):
		var avg := 0.0
		var avg_r := 0.0
		for j in range(i - win, i):
			avg += (arr[j].cam as Vector3).y
			avg_r += (arr[j].root as Vector3).y
		avg /= win
		avg_r /= win
		pp = maxf(pp, absf((arr[i].cam as Vector3).y - avg))
		pp_root = maxf(pp_root, absf((arr[i].root as Vector3).y - avg_r))
	for i in range(2, n):
		var c0: Vector3 = arr[i - 2].cam
		var c1: Vector3 = arr[i - 1].cam
		var c2: Vector3 = arr[i].cam
		cjerk = maxf(cjerk, ((c2 - c1) - (c1 - c0)).length())
	out["cam_hp_cm"] = pp * 100.0
	out["root_hp_cm"] = pp_root * 100.0
	out["cam_jerk_cm"] = cjerk * 100.0
	var ysnap := 0.0
	var pmax := -999.0
	var pmin := 999.0
	var rj := 0.0
	for i in range(2, n):
		var y0: float = arr[i - 2].yaw
		var y1: float = arr[i - 1].yaw
		var y2: float = arr[i].yaw
		var r1 := angle_difference(y1, y2) / float((arr[i] as Dictionary).dt)
		var r0 := angle_difference(y0, y1) / float((arr[i - 1] as Dictionary).dt)
		ysnap = maxf(ysnap, absf(rad_to_deg(r1 - r0)))
		pmax = maxf(pmax, rad_to_deg((arr[i] as Dictionary).pitch))
		pmin = minf(pmin, rad_to_deg((arr[i] as Dictionary).pitch))
		var q0: Vector3 = arr[i - 2].root
		var q1: Vector3 = arr[i - 1].root
		var q2: Vector3 = arr[i].root
		rj = maxf(rj, ((q2 - q1) - (q1 - q0)).length())
	out["yaw_snap"] = ysnap
	out["pitch_min"] = pmin
	out["pitch_max"] = pmax
	out["root_jerk_cm"] = rj * 100.0
	return out


func _finish() -> void:
	set_physics_process(false)
	set_process(false)
	for k: String in _phases:
		var st := _stats(_phases[k])
		var line := "HFEEL %s %-14s n=%4d" % [breed, k, (_phases[k] as Array).size()]
		for f: String in st:
			var v: Variant = st[f]
			line += "  %s=%s" % [f, ("%.2f" % v) if v is float else str(v)]
		print(line)
	if mode == "dismount" and _phases.has("dismount"):
		var arr: Array = _phases["dismount"]
		var worst := 0.0
		var cw := 0.0
		for i in range(1, arr.size()):
			worst = maxf(worst, ((arr[i].rider_w as Vector3) - (arr[i - 1].rider_w as Vector3)).length())
			cw = maxf(cw, ((arr[i].cam as Vector3) - (arr[i - 1].cam as Vector3)).length())
		print("HFEEL dismount: biggest one-frame move of the rider %.1f cm, of the camera %.1f cm (frames %d)" % [worst * 100.0, cw * 100.0, arr.size()])
	print("HFEEL done")
	get_tree().quit()
