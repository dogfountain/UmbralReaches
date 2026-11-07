extends Node
## Planted-hoof slide per breed and gait: the rig is posed at a steady speed with the phase advanced
## by freq(); each fetlock's ground position (its pose plus the horse's travel) is tracked through
## its stance, and the spread fore-aft must stay under a centimetre.
##   godot --headless --path . res://zz/horse_slide_test.tscn

const HorseRig := preload("res://core/world/mount/horse_rig.gd")
const DB := preload("res://core/world/mount/horse_db.gd")
const LIMIT := 0.01
const DT := 1.0 / 120.0

var bad := 0


func _ready() -> void:
	for b: String in DB.ORDER:
		var d: Dictionary = DB.BREEDS[b]
		var gaits := {
			"walk": float(d.walk), "trot": float(d.trot),
			"canter": (float(d.trot) + float(d.gallop)) * 0.5, "gallop": float(d.gallop),
		}
		var line := "%-9s" % b
		for gn: String in gaits:
			var s: float = _slide(b, d, float(gaits[gn]))
			line += "  %s %.1f cm" % [gn, s * 100.0]
			if s > LIMIT:
				bad += 1
				line += " FAIL"
		print("SLIDE ", line)
	print("horse_slide_test: ", "FAIL %d" % bad if bad > 0 else "PASS")
	get_tree().quit(1 if bad > 0 else 0)


func _slide(b: String, d: Dictionary, speed: float) -> float:
	var rig := HorseRig.new()
	rig.setup(b, d)
	add_child(rig)
	var ph := 0.0
	for i in 240:
		rig.pose(ph, speed, 0.0, DT)
		ph += TAU * rig.freq(speed) * DT
	var worst := 0.0
	var lo := {}
	var hi := {}
	var was := {}
	var travel := 0.0
	for i in int(6.0 / DT):
		rig.pose(ph, speed, 0.0, DT)
		var cyc := ph / TAU
		var g: Dictionary = rig._blend(speed)
		for li in 4:
			var l: String = rig.LEGS[li]
			var u := fposmod(cyc + float(g.off[li]), 1.0)
			var planted := u < float(g.duty) - 0.02 and u > 0.02
			if planted:
				var p := rig.skel.get_bone_global_pose(rig.skel.find_bone(l + "_fet")).origin
				var z := p.z + travel                       # the horse runs toward -z: this is the hoof's z on the ground
				if not was.get(l, false):
					lo[l] = z
					hi[l] = z
				lo[l] = minf(lo[l], z)
				hi[l] = maxf(hi[l], z)
				worst = maxf(worst, hi[l] - lo[l])
			was[l] = planted
		ph += TAU * rig.freq(speed) * DT
		travel -= speed * DT
	rig.queue_free()
	return worst
