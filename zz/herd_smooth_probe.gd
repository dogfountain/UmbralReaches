extends Node
## How smooth a fleeing herd is drawn: alarms the deer herd nearest the player, then every rendered
## frame reads each deer's drawn position from its MultiMesh and measures the frame-to-frame change
## in its step (a pop shows as a step far from its neighbours). Run at the player's refresh:
##   HOME=<scratch> godot --path . --fixed-fps 120 res://zz/herd_smooth_probe.tscn
## Prints HERD max_jerk (m per frame, change of step between frames) and mean step, then quits.
var p: Player
var t := 0
var herd: Node3D
var mm: MultiMesh
var last := {}
var last_step := {}
var max_jerk := 0.0
var max_rel := 0.0
var sum_step := 0.0
var n_step := 0
var frames := 0
var n_dbg := 0


func _ready() -> void:
	Travel._busy = true
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	t += 1
	if t > 120 * 300:
		print("HERD FAIL timeout")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	var main := p.owner if p.owner else p.get_parent()
	if not main.has_meta("summit_dressed"):
		return
	var life := main.find_child("Wildlife", true, false)
	if herd == null:
		if life == null:
			return
		var best := INF
		for g in (life.get("groups") as Array):
			if is_instance_valid(g) and String(g.get("kind")) == "deer":
				var c: Vector3 = (g as Node3D).global_position
				if c.distance_to(p.global_position) < best:
					best = c.distance_to(p.global_position)
					herd = g
		if herd == null:
			print("HERD FAIL no deer")
			get_tree().quit(1)
			return
		var mmis: Dictionary = herd.get("mmis")
		mm = (mmis["deer"] as MultiMeshInstance3D).multimesh
		# stand 14 m off, looking at it, so it is in view and near (the director glides it)
		var hp := herd.global_position
		var away := (p.global_position - hp)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.BACK
		p.teleport(hp + away * 14.0 + Vector3.UP * 2.0)
		p.set_view(atan2(away.x, away.z), -0.1)
		return
	frames += 1
	if frames == 30:
		herd.call("alarm", p.global_position, 1.0)
	if frames < 32:
		return
	var o := herd.global_position
	for i in mm.instance_count:
		var buf: PackedFloat32Array = (herd.get("_bufs") as Dictionary)["deer"]
		var w := o + Vector3(buf[i * 16 + 3], buf[i * 16 + 7], buf[i * 16 + 11])   # what is sent to the GPU
		if last.has(i):
			var st: Vector3 = w - last[i]
			st.y = st.y
			if last_step.has(i):
				var j: float = (st - (last_step[i] as Vector3)).length()
				if j > 0.2 and n_dbg < 12:
					n_dbg += 1
					print("HERD pop f%d i%d jerk %.3f step %s prev %s node %s state %s" % [frames, i, j, st.snapped(Vector3.ONE * 0.001), (last_step[i] as Vector3).snapped(Vector3.ONE * 0.001), o.snapped(Vector3.ONE * 0.01), "%s pos %s tick_dt %.3f" % [(herd.get("animals") as Array)[i].state, ((herd.get("animals") as Array)[i].pos as Vector3).snapped(Vector3.ONE * 0.01), float(herd.get("_tick_dt"))]])
				max_jerk = maxf(max_jerk, j)
				if st.length() > 0.01:
					max_rel = maxf(max_rel, j / st.length())
			last_step[i] = st
			sum_step += st.length()
			n_step += 1
		last[i] = w
	if frames > 32 + 120 * 3:
		print("HERD frames %d  mean step %.4f m  max jerk %.4f m  max jerk/step %.2f  fleeing %d" % [frames - 32, sum_step / maxf(n_step, 1), max_jerk, max_rel, int(herd.call("fleeing"))])
		get_tree().quit(0)
