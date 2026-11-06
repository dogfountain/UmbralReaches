extends Skill
## Rift Tether (learned at the Kindling, r28). A rift chain thrown at the foe nearest the
## crosshair: it is Marked, takes a pinch of damage and is dragged through the air to land in
## front of you. A boss is too heavy: the chain drags you to it instead. A miss costs a second.
## Ranks (UpgradeDB.live "tether"): I reach 24 m and the foe arrives staggered; II the chain forks
## to a second foe within 6 m of the first; III Reel: a foe that had Marks before the hook bursts
## them on arrival (1 per Mark, within 2.5 m). Ferryman's Hook (charm): every foe along the chain
## is Marked too (and the runtime takes 2 s off the recovery).
## Preload by path (no class_name).

const DB := preload("res://core/life/progression/upgrade_db.gd")
const Aim := preload("res://core/skills/aim.gd")
const Chain := preload("res://core/skills/tether_chain.gd")
const Drag := preload("res://core/skills/tether_drag.gd")
const CombatState := preload("res://core/skills/combat_state.gd")
const Combo := preload("res://core/skills/combo.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")

const RANGE := 18.0
const RANGE_LONG := 24.0
const CONE := 0.955            ## ~17 degrees either side of the crosshair
const FORK_R := 6.0
const REEL_R := 2.5
const HOOK_DMG := 0.5
const LAND := 2.3              ## metres in front of you the foe lands
const MISS_CD := 1.0
const DRAG_SPEED := 22.0       ## m/s a hooked foe is hauled in

var hooked := 0                ## foes hooked by the last cast (tests)


func _init() -> void:
	id = &"tether"
	title = "Rift Tether"
	blurb = "Chain the foe nearest your aim and drag it to you. Bosses drag you to them."
	action = &"skill_step"
	cooldown = 6.0
	gloom_cost = 3.0
	color = Color("#5FE3D0")
	glyph = &"tether"
	pose = &"lance"


func rank() -> int:
	return int(DB.get_mod("tether", 0))


func reach() -> float:
	return (RANGE_LONG if rank() >= 1 else RANGE) + float(DB.get_mod("tether_reach", 0.0))


func cast(book: SkillBook, _charge: float) -> bool:
	var p := book.player
	var r := rank()
	var power := float(DB.get_mod("power", 1.0))
	var from := Aim.muzzle(p)
	var first := Aim.pick(p, reach(), CONE)
	hooked = 0
	if first == null:
		# a miss: the chain flies out to the crosshair and snaps back; costs only a second
		var to := from + Aim.forward(p) * reach()
		var space := p.get_world_3d().direct_space_state
		if space:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.PROPS, [p.get_rid()]))
			if not hit.is_empty():
				to = hit.position
		Chain.throw(p, null, 0.1, to)
		StaffSfx.play("tether", from, -4.0, 1.1)
		var i := book.slots.find(self)
		(func() -> void: book.refund(i, cooldown - MISS_CD)).call_deferred()
		return true
	var targets: Array[Node3D] = [first]
	if r >= 2:
		var second := Aim.nearest(p.get_tree(), first.global_position, FORK_R, {first.get_instance_id(): true})
		if second:
			targets.append(second)
	StaffSfx.play("tether", from, -1.0)
	p.kick(0.3)
	for k in targets.size():
		_hook(p, targets[k], k, r, power, from)
	return true


func _hook(p: Player, e: Node3D, k: int, r: int, power: float, from: Vector3) -> void:
	hooked += 1
	var had := int(e.get("marks")) if e.get("marks") != null else 0
	var at := Aim.chest(e)
	if bool(DB.get_mod("hook", false)):
		_mark_line(p, from, at, e)
	e.call("add_mark", 2 if bool(DB.get_mod("chalk", false)) else 1)
	e.call("take_hit", HOOK_DMG * power, null)
	StaffSfx.play("tether_hit", at, -2.0)
	Vfx.burst(at, Chain.TEAL_HOT, {"count": 22, "life": 0.35, "speed": Vector2(2.0, 5.0), "size": 0.045, "gravity": -3.0, "trail": 0.06})
	if bool(e.get("boss")):
		if k == 0:
			_drag_self(p, e)
		return
	# r36 Unpaid Fare: Anchor pins the foe where it stands; Haul drags you to it instead
	match Reliquary.variant("coin"):
		&"anchor":
			Chain.throw(p, e, 0.15)
			_anchor(e)
			return
		&"haul":
			if k == 0:
				_drag_self(p, e)
				var pid := p.get_instance_id()
				p.get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
					var p2 := instance_from_id(pid) as Player
					if p2 != null and p2.is_inside_tree():
						_haul_shock(p2, power))
			return
	var flat := Vector3(p.global_position.x - e.global_position.x, 0.0, p.global_position.z - e.global_position.z)
	if flat.length() < LAND + 0.4:
		Chain.throw(p, e, 0.15)
		_arrive(p, e, r, had, power)
		return
	var fwd := -flat.normalized()
	var side := fwd.cross(Vector3.UP) * (0.0 if k == 0 else (1.1 if k == 1 else -1.1))
	var land := p.global_position + fwd * LAND + side
	var space := p.get_world_3d().direct_space_state
	if space:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(land + Vector3.UP * 2.5, land + Vector3.DOWN * 4.0, Layers.WORLD | Layers.PROPS, [p.get_rid()]))
		if not hit.is_empty():
			land = (hit.position as Vector3) + Vector3.UP * 0.05
	var t := clampf(e.global_position.distance_to(land) / DRAG_SPEED, 0.22, 0.6)
	Chain.throw(p, e, t)
	Drag.start(e, land, t, func() -> void:
		if is_instance_valid(e) and is_instance_valid(p):
			_arrive(p, e, r, had, power))


## The foe has landed at your feet.
func _arrive(p: Player, e: Node3D, r: int, had: int, power: float) -> void:
	if e.has_method("is_alive") and not e.call("is_alive"):
		return
	var at := e.global_position
	Vfx.ring(at + Vector3.UP * 0.06, 1.1, Chain.TEAL, 0.3, 0.08, Vector3.UP, 1.0)
	Vfx.burst(at + Vector3.UP * 0.2, Color(0.12, 0.1, 0.1, 0.8), {"count": 10, "life": 0.6, "speed": Vector2(0.6, 1.8), "size": 0.25, "gravity": 0.5, "additive": false})
	if r >= 1 and e.has_method("stagger"):
		e.call("stagger")
	if r >= 3 and had > 0 and e.has_method("take_marks"):
		var m := int(e.call("take_marks"))
		var hurt := 0
		for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
			var o := node as Node3D
			if o == null or (o.has_method("is_alive") and not o.call("is_alive")):
				continue
			if o.global_position.distance_to(at) <= REEL_R:
				CombatState.strike(o, float(m) * power, &"umbral", p)
				hurt += 1
		SpellFx.disc(at, REEL_R, 0, Color(0.4, 1.8, 1.6), Chain.TEAL_HOT, 0.5)
		SpellFx.shell(at + Vector3.UP, 0.3, REEL_R, Color(0.4, 1.6, 1.5), 0.3)
		Vfx.burst(at + Vector3.UP, Chain.TEAL_HOT, {"count": 40, "life": 0.45, "speed": Vector2(3.0, 7.0), "size": 0.05, "gravity": -4.0, "trail": 0.08})
		Vfx.light(at + Vector3.UP, Color(0.3, 1.0, 0.9), 4.0, REEL_R * 2.5, 0.3)
		StaffSfx.play("nova", at, -6.0, 1.35)
		Combo.note("REEL", at + Vector3.UP * (float(e.get("hp_bar_y")) if e.get("hp_bar_y") != null else 2.0), Color(0.45, 1.0, 0.9), "%d Marks" % m)


## A boss: the chain hauls the wanderer to it, landing just short.
func _drag_self(p: Player, e: Node3D) -> void:
	Chain.throw(p, e, 0.22)
	var pid := p.get_instance_id()
	var eid := e.get_instance_id()
	p.get_tree().create_timer(0.16, false).timeout.connect(func() -> void:
		_haul_self(instance_from_id(pid) as Player, instance_from_id(eid) as Node3D))


func _haul_self(p: Player, e: Node3D) -> void:
	if p == null or e == null or not p.is_inside_tree():
		return
	var from := p.global_position
	var d := Vector3(from.x - e.global_position.x, 0.0, from.z - e.global_position.z)
	if d.length() < 3.2:
		return
	var to := e.global_position + d.normalized() * 2.8
	var space := p.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * 2.0, to + Vector3.DOWN * 4.0, Layers.WORLD | Layers.PROPS, [p.get_rid()])) if space else {}
	if not hit.is_empty():
		to = (hit.position as Vector3) + Vector3.UP * 0.05
	if not Aim.clear(p, from + Vector3.UP, to + Vector3.UP):
		return
	SpellFx.rift_seam(from, to)
	p.teleport(to)
	Vfx.burst(to + Vector3.UP, Chain.TEAL_HOT, {"count": 30, "life": 0.4, "speed": Vector2(2.0, 5.0), "size": 0.045, "gravity": -3.0, "trail": 0.07})
	StaffSfx.play("step_shock", to, -4.0, 1.2)


## Ferryman's Hook: every other foe within 1.2 m of the chain's line is Marked.
func _mark_line(p: Player, a: Vector3, b: Vector3, skip: Node3D) -> void:
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var o := node as Node3D
		if o == null or o == skip or (o.has_method("is_alive") and not o.call("is_alive")):
			continue
		var c := Aim.chest(o)
		if c.distance_to(Geometry3D.get_closest_point_to_segment(c, a, b)) < 1.2:
			o.call("add_mark", 1)
			Vfx.burst(c, Chain.TEAL_HOT, {"count": 10, "life": 0.3, "speed": Vector2(1.5, 3.5), "size": 0.04, "gravity": -3.0, "trail": 0.05})


const ANCHOR_SECS := 2.5
const HAUL_R := 2.5


## r36 Anchor: pinned where it stands for ANCHOR_SECS (the Briar's walk_speed metas, so slows never
## fight), and a second Mark.
func _anchor(e: Node3D) -> void:
	var en := e as Enemy
	if en == null:
		return
	en.add_mark(1)
	if not en.has_meta(&"briar_base"):
		en.set_meta(&"briar_base", en.walk_speed)
	en.walk_speed = 0.0
	var until := Time.get_ticks_msec() + int(ANCHOR_SECS * 1000.0)
	en.set_meta(&"briar_until", until)
	Vfx.ring(en.global_position + Vector3.UP * 0.06, 1.0, Chain.TEAL_HOT, ANCHOR_SECS, 0.08, Vector3.UP, 1.0)
	var eid := en.get_instance_id()
	en.get_tree().create_timer(ANCHOR_SECS + 0.05, false).timeout.connect(func() -> void:
		var e2 := instance_from_id(eid) as Enemy
		if e2 != null and int(e2.get_meta(&"briar_until", 0)) <= Time.get_ticks_msec():
			e2.walk_speed = float(e2.get_meta(&"briar_base", e2.walk_speed)))


## r36 Haul: you land with a shock that throws back what stands within HAUL_R.
func _haul_shock(p: Player, power: float) -> void:
	var at := p.global_position
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - at
		d.y = 0.0
		if d.length() > HAUL_R:
			continue
		e.take_hit(0.5 * power, p)
		if not e.boss:
			e.shove((d.normalized() if d.length() > 0.1 else -p.global_basis.z) * 8.0)
	Vfx.ring(at + Vector3.UP * 0.08, HAUL_R, Chain.TEAL_HOT, 0.3, 0.1, Vector3.UP, 1.2)
