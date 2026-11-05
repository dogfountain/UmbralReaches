extends Node
## r30 game design loop: only fires rest; the Lantern Ward drains slowly (capped) and does not bar
## bosses; bolts drive the Shade back, Nova unmakes it; blows at full Gloom hollow; hollowing
## drops the carried ash; resting at a lit fire moves the checkpoint; bosses hold each phase until
## their signature move has shown twice, take 0.7x from plain bolts and stand through an intro.
## Run: HOME=<scratch> godot --headless --path . res://zz/r30_design_test.tscn
const AT := Vector3(-24.0, 0.0, 60.0)     ## open ground outside every sanctuary light
var p: Player
var t := 0
var phase := 0
var t0 := 0
var fails := 0
var main: Node
var ward: Node3D
var shade: Shade
var g0 := 0.0
var d0 := 0.0
var started3 := false


func _ready() -> void:
	Travel._busy = true
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _gy(x: float, z: float) -> float:
	return RealmLayout.ground(p.get_world_3d().direct_space_state, x, z)


func check(name: String, ok: bool, detail := "") -> void:
	print("R30DESIGN %s %s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		fails += 1


func _here() -> Vector3:
	return Vector3(AT.x, _gy(AT.x, AT.z) + 0.3, AT.z)


func _physics_process(_d: float) -> void:
	t += 1
	if t > 60 * 300:
		print("R30DESIGN FAIL timeout")
		get_tree().quit(1)
		return
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	var m := p.owner if p.owner else p.get_parent()
	if not m.has_meta("summit_dressed"):
		return
	if phase >= 2:
		p.set("_shade_lock", 999.0)          # only the shades this test makes
	match phase:
		0:
			var enc := m.find_child("Encounters", true, false)
			if enc:
				enc.process_mode = Node.PROCESS_MODE_DISABLED
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()
			p.teleport(_here())
			phase = 1
			t0 = t
		1:
			if t - t0 == 10:
				check("open ground is dark", not LightGrid.is_lit(p.global_position))
				ward = LanternWard.plant(p)
				p.gloom = 80.0
				g0 = p.gloom
			if t - t0 == 12:
				check("a ward is light", LightGrid.is_lit(p.global_position))
				check("a ward is not a fire", not LightGrid.is_fire(p.global_position))
				check("bosses ignore a ward", not LightGrid.is_lit(p.global_position, true))
			if t - t0 == 10 + 60 * 3:
				var drained := g0 - p.gloom
				check("ward drains ~4/s, not 12", drained > 9.0 and drained < 14.0, "%.1f in 3 s" % drained)
			if t - t0 == 10 + 60 * 7:
				var drained := g0 - p.gloom
				check("ward drain capped at 25 a cast", drained <= LanternWard.DRAIN_CAP + 0.5, "%.1f" % drained)
				if is_instance_valid(ward):
					ward.queue_free()
				phase = 2
				t0 = t
		2:
			if t - t0 == 5:
				# a Shade at 8 m
				p.gloom = p.gloom_max
				shade = Shade.new()
				m.add_child(shade)
				shade.target = p
				shade.global_position = p.global_position + Vector3(8.0, Shade.HOVER, 0.0)
			if t - t0 == 70:
				d0 = Vector2(shade.global_position.x - p.global_position.x, shade.global_position.z - p.global_position.z).length()
				var bolt := Node3D.new()
				m.add_child(bolt)
				bolt.global_position = p.global_position
				shade.take_hit(1.0, bolt)
				bolt.queue_free()
				check("a bolt does not unmake the shade", is_instance_valid(shade) and not shade._dying)
				check("a bolt drives it (1 of 3)", shade.drives == 1)
				shade.take_hit(1.0, null)
				check("a second bolt while it reels passes through", shade.drives == 1)
			if t - t0 == 70 + 50:
				var d := Vector2(shade.global_position.x - p.global_position.x, shade.global_position.z - p.global_position.z).length()
				check("driven back several metres", d > d0 + 4.0, "%.1f -> %.1f m" % [d0, d])
				check("it comes back faster", shade.speed > 5.5, "%.1f m/s" % shade.speed)
				shade.take_hit(1.0, p)               # the Umbral Nova passes the Player
				check("Nova unmakes it", shade._dying)
			if t - t0 == 70 + 120:
				phase = 3
				t0 = t
		3:
			if not started3:
				if bool(p.get("_hollowing")):
					t0 = t                           # wait out any hollowing first
					return
				started3 = true
			for n in get_tree().get_nodes_in_group(Groups.ENEMY):
				(n as Node).queue_free()             # nothing else may strike during this leg
			if t - t0 == 2 and bool(p.get("_hollowing")):
				t0 = t - 1                           # a hollow from the last leg is still resolving
				return
			if t - t0 == 2:
				for s in get_tree().get_nodes_in_group(Groups.SHADE):
					(s as Node).queue_free()
				Travel.give("grave_ash", 7, false)
				p.set("_ash_banked", Travel.count("grave_ash") - 7)
				p.gloom = p.gloom_max
				p.set("_hurt_grace_until", 0.0)
				p.add_gloom_from_enemy(10.0)
				check("a blow at full Gloom counts", int(p.get("_overcap_hits")) == 1, "ash %d banked %d" % [Travel.count("grave_ash"), int(p.get("_ash_banked"))])
			if t - t0 == 40:
				print("R30DESIGN info ash %d overcap %d hollowing %s" % [Travel.count("grave_ash"), int(p.get("_overcap_hits")), p.get("_hollowing")])
				p.set("_hurt_grace_until", 0.0)
				p.add_gloom_from_enemy(10.0)
			if t - t0 == 80:
				var before := Travel.count("grave_ash")
				p.set("_hurt_grace_until", 0.0)
				p.add_gloom_from_enemy(10.0)
				check("the third blow at full Gloom hollows", bool(p.get("_hollowing")))
				check("the carried ash is dropped", Travel.count("grave_ash") == int(p.get("_ash_banked")) and before - Travel.count("grave_ash") == 7, "%d -> %d" % [before, Travel.count("grave_ash")])
				var mounds := get_tree().get_nodes_in_group(&"ash_mound")
				check("an ash mound marks the spot", mounds.size() == 1 and int((mounds[0] as Node).get("amount")) == 7)
			if t - t0 == 200:
				var mounds := get_tree().get_nodes_in_group(&"ash_mound")
				if mounds.size() == 1:
					var before := Travel.count("grave_ash")
					(mounds[0] as Node).call("take")
					check("walking back takes the ash up", Travel.count("grave_ash") == before + 7)
				phase = 4
				t0 = t
		4:
			if t - t0 == 2:
				var fire: Brazier = null
				for n in get_tree().get_nodes_in_group(Groups.LIGHT_SOURCE):
					if n is Brazier and (n as Brazier).lit:
						fire = n
						break
				check("a lit fire exists", fire != null)
				if fire:
					check("a fire is a fire", LightGrid.is_fire(fire.global_position))
					p.checkpoint = Vector3(999, 0, 999)
					fire.remember(p)
					check("resting at a lit fire sets the checkpoint", p.checkpoint.distance_to(fire.spawn_point()) < 0.5)
				phase = 5
				t0 = t
		5:
			if t - t0 == 2:
				p.teleport(_here())
			if t - t0 == 5:
				var b := Thornwarden.new()
				m.add_child(b)
				b.global_position = p.global_position + Vector3(10.0, 0.0, 0.0)
				b.on_engaged(null)
				check("boss stands through an intro", b._ward_t > 1.5 and b._state == Enemy.RECOVER)
				check("thornwarden hp 110", b.max_hp == 110)
				b._ward_t = 0.0
				b.take_hit(500.0, null)
				check("phase I holds until two pounces", absf(b.hp - 55.5) < 0.01, "hp %.1f" % b.hp)
				b._sig = 2
				var before := b.hp
				var bolt := (load("res://core/player/magic_bolt.tscn") as PackedScene).instantiate() as MagicBolt
				m.add_child(bolt)
				bolt.global_position = p.global_position
				bolt.heavy = false
				b.take_hit(1.0, bolt)
				check("a plain bolt chips a boss at 0.7", absf(before - b.hp - 0.7) < 0.01, "%.2f" % (before - b.hp))
				bolt.heavy = true
				before = b.hp
				b.take_hit(1.0, bolt)
				check("a heavy hit is full", absf(before - b.hp - 1.0) < 0.01, "%.2f" % (before - b.hp))
				bolt.queue_free()
				b.queue_free()
				var a := BoneAbbot.new()
				m.add_child(a)
				check("abbot hp 160", a.max_hp == 160)
				a.queue_free()
				var w := AscendedWarden.new()
				m.add_child(w)
				check("warden hp 220", w.max_hp == 220)
				w.queue_free()
			if t - t0 == 10:
				var lance := SkillLance.new()
				check("lance: 1.0 s, no Gloom", is_equal_approx(lance.cooldown, 1.0) and lance.gloom_cost == 0.0)
				print("R30DESIGN %s" % ("PASS" if fails == 0 else "FAIL"))
				get_tree().quit(0 if fails == 0 else 1)
