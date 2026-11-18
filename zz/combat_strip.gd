extends Node
## Combat strip harness: fights played through the real night (world/main.tscn), the real player camera,
## grade and HUD, by a scripted wanderer, recorded as frame strips and a hit log.
##
##   godot --path . res://zz/combat_strip.tscn -- --out=<dir> --fights=<f1>;<f2>... [--bot=fight] [--secs=10]
##        [--every=6] [--at=x,z] [--yaw=deg] [--perf] [--full=hits]
## A fight is "name=spec", spec is a set name from SETS, or kinds joined by "+" (each kind[@dist[@bearing]]),
## or "boss:<id>" (fought in its own arena: thornwarden bone_abbot ascended_warden anchoress hierarch).
## --bot: stand (takes everything, locked on), dodge (stands, steps out of red), fight (kites with bolts, lances,
##        novas, steps through red), melee (staff chain and heavy, guards on a tell)
## --every: physics frames between captured frames (6 = 10 fps); 0 = no capture (perf runs)
## Output: <out>/<fight>_sNN.jpg contact sheets (12 cells, frame number and time in each), <out>/<fight>_full_*.jpg
## (full size frames on a hurt, a kill and a telegraph's first frame with --full=hits), <out>/<fight>.log (every
## telegraph, state change, hit, hurt and frame spike), and <out>/summary.txt.
const SETS := {
	"pack": "wretch@5.5@-20+husk@6.5@15+crawler@4.5@40+spitter@9@-45+wretch@6@60",
	"warband": "bulwark@5.5@0+chanter@10@8+wretch@6@-50+wretch@6@55+mite@4.5@25+mite@4.8@30+mite@4.2@35",
	"r31": "gaunt@7@-35+quiller@11@10+tollman@9@30+husk@5@-5+gaunt@7.5@50",
	"brood": "brood_mother@8@0",
	"burrow": "burrower@9@0+burrower@10@30",
	"casters": "cinder_caster@9@-20+chanter@10@20+pilgrim@6@0",
}
const SCRIPTS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd", "spitter": "res://core/enemy/spitter.gd",
	"crawler": "res://core/enemy/crawler.gd", "leaper": "res://core/enemy/leaper.gd", "ossuant": "res://core/enemy/ossuant.gd",
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd", "burrower": "res://core/enemy/burrower.gd",
	"mite": "res://core/enemy/mite.gd", "gaunt": "res://core/enemy/gaunt.gd", "quiller": "res://core/enemy/quiller.gd",
	"tollman": "res://core/enemy/tollman.gd", "brood_mother": "res://core/enemy/brood_mother.gd", "pilgrim": "res://core/enemy/pilgrim.gd",
	"cinder_caster": "res://core/enemy/cinder_caster.gd", "tally_reliquary": "res://core/enemy/tally_reliquary.gd",
	"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"ascended_warden": "res://core/enemy/ascended_warden.gd", "anchoress": "res://core/enemy/anchoress.gd",
	"hierarch_voice": "res://core/enemy/hierarch_voice.gd",
}
## boss id -> [arena key (BossArena.boss_id contains it), seal guarding it]
const ARENAS := {"thornwarden": ["thornwarden", "henge"], "ascended_warden": ["ascended_warden", "summit"],
	"bone_abbot": ["bone_abbot", ""], "anchoress": ["r37_anchoress", ""], "hierarch": ["r37_hierarch", ""]}
const STATE_N := ["IDLE", "CHASE", "WINDUP", "STRIKE", "RECOVER", "DEAD", "LEAP_PREP", "AIRBORNE", "FEINT", "SPECIAL", "CALL"]
const CELL := Vector2i(640, 360)
const COLS := 3
const PER_SHEET := 9

var out := "/tmp/combat_strip"
var fights: Array = []
var bot := "fight"
var secs := 10.0
var every := 6
var at2 := Vector2.INF
var yaw := 0.0
var perf := false
var full_hits := false
var full_tells := false
var main: Node
var p: Player
var started := false
var t0 := 0
var realm_at := -1.0

# --- the fight being recorded
var fname := ""
var log_lines := PackedStringArray()
var frames: Array = []          ## [Image, physics frame, t]
var sheet_i := 0
var f0 := 0
var foes: Array = []            ## Enemy
var last_state := {}            ## instance id -> state
var last_hp := {}
var zones := {}                 ## mesh id -> {mi, f, full, shape, half, at, size, by}
var hurts := 0
var hurt_total := 0.0
var dealt := 0.0
var kills := 0
var want_full: Array = []       ## labels for full-size frames to grab on the next draw
var spikes: Array = []
var ft := PackedFloat32Array()
var summary := PackedStringArray()
var boss: Enemy
var recording := false
var phase_at: Array[float] = []
var _pipes := 0
var _added := 0
var _nav_us := 0
var _nav_q := 0        ## boss:<id>^r2^r3: the life set to each ratio at equal slices of the fight
var arena_c := Vector3.ZERO
var arena_r := 0.0
# --- the bot
var bot_hold := false
var bot_t := 0.0
var bot_heat := 0.0
var lance_t := 0.0
var step_cd := 0.0
var strafe := 1.0
var strafe_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		var k := a.get_slice("=", 0)
		var v := a.substr(k.length() + 1)
		match k:
			"--out": out = v
			"--fights":
				for f: String in v.split(";", false):
					fights.append(f)
			"--bot": bot = v
			"--secs": secs = float(v)
			"--every": every = int(v)
			"--at": at2 = Vector2(float(v.get_slice(",", 0)), float(v.get_slice(",", 1)))
			"--yaw": yaw = deg_to_rad(float(v))
			"--perf": perf = true
			"--full":
				full_hits = v == "hits" or v == "hurts"
				full_tells = v == "hits"
	DirAccess.make_dir_recursive_absolute(out)
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	var qb := preload("res://core/story/quest_book.gd")
	for bid: String in (preload("res://core/story/quest_chains.gd").BELLS as Array).slice(0, 4):
		qb.start(bid)
		qb.choose(bid, "rung")
	get_window().size = Vector2i(1280, 720)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	get_tree().node_added.connect(_on_node_added)
	Events.player_hurt.connect(_on_hurt)
	Events.combat_damage.connect(_on_damage)
	Events.enemy_killed.connect(_on_killed)
	Events.enemy_cast_started.connect(func(e: Node, n: String, tm: float, intr: bool) -> void:
		_log("CAST %s '%s' %.2fs%s" % [_who(e), n, tm, " (interruptible)" if intr else ""]))
	Events.enemy_cast_ended.connect(func(e: Node, n: String, intr: bool) -> void:
		_log("CAST END %s '%s'%s" % [_who(e), n, " INTERRUPTED" if intr else ""]))
	print("STRIP start ", fights, " out=", out)


func _process(delta: float) -> void:
	Travel._busy = true
	var el := float(Time.get_ticks_msec() - t0) / 1000.0
	if el > 420.0:
		print("STRIP watchdog")
		_quit(2)
		return
	if fname != "":
		ft.append(delta * 1000.0)
		var pc := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))
		if delta > 0.025:
			spikes.append([Engine.get_physics_frames() - f0, snappedf(delta * 1000.0, 0.1)])
			_log("SPIKE %.1f ms (process %.1f ms, physics %.1f ms, pipelines compiled %d, nodes added %d, nav %.1f ms in %d queries)" % [delta * 1000.0,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				pc - _pipes, _added, float(NavAssist.query_usec - _nav_us) / 1000.0, NavAssist.queries - _nav_q])
		if pc > _pipes and delta <= 0.025:
			_log("PIPE %d compiled (surface %d draw %d spec %d mesh %d), %.1f ms" % [pc - _pipes, int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
				int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)), int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
				int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)), delta * 1000.0])
		_pipes = pc
		_added = 0
		_nav_us = NavAssist.query_usec
		_nav_q = NavAssist.queries
	if not started and is_instance_valid(main) and main.has_meta("realm_done"):
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p == null:
			return
		if realm_at < 0.0:
			realm_at = el
			print("STRIP realm built at %.1f s" % el)
		if el - realm_at > 4.0:
			started = true
			_run.call_deferred()


func _physics_process(_d: float) -> void:
	if recording and p != null:
		_track()
		_bot(1.0 / 60.0)


func _quit(code: int) -> void:
	print("STRIP quit ", code)
	get_tree().quit(code)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))


func _space() -> PhysicsDirectSpaceState3D:
	return p.get_world_3d().direct_space_state


func _gp(x: float, z: float) -> Vector3:
	return Vector3(x, RealmLayout.ground(_space(), x, z), z)


static func _dir(y: float) -> Vector3:
	return Vector3(-sin(y), 0.0, -cos(y))


static func _yaw_of(v: Vector3) -> float:
	return atan2(-v.x, -v.z)


func _run() -> void:
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)
	p.skills().set("using_pad", true)
	var ground := Vector3.ZERO
	if at2 == Vector2.INF:
		at2 = _find_flat()
	ground = _gp(at2.x, at2.y)
	for f: String in fights:
		var nm := f.get_slice("=", 0)
		var spec := f.substr(nm.length() + 1) if f.contains("=") else nm
		await _fight(nm, spec, ground)
	_write(out.path_join("summary.txt"), "\n".join(summary) + "\n")
	print("STRIP done")
	_quit(0)


func _find_flat() -> Vector2:
	var best := Vector2(58.0, 18.0)
	var best_s := 1.0e9
	for c: Vector2 in [Vector2(58, 18), Vector2(70, 30), Vector2(45, 60), Vector2(95, 10), Vector2(30, -10), Vector2(110, 40),
			Vector2(20, 95), Vector2(150, 60), Vector2(-40, 30), Vector2(-100, 70), Vector2(60, 140), Vector2(-60, 110)]:
		var lo := 1.0e9
		var hi := -1.0e9
		var pen := 0.0
		for ring: float in [0.0, 7.0, 14.0]:
			for k in (1 if ring == 0.0 else 12):
				var a := TAU * float(k) / 12.0
				var q := c + Vector2(cos(a), sin(a)) * ring
				var y := RealmLayout.ground(_space(), q.x, q.y)
				lo = minf(lo, y)
				hi = maxf(hi, y)
				if LightGrid.is_lit(Vector3(q.x, y, q.y), true):
					pen += 30.0
		if hi - lo + pen < best_s:
			best_s = hi - lo + pen
			best = c
	print("STRIP flat ground at ", best, " score ", snappedf(best_s, 0.01))
	return best


func _clear() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for n in get_tree().get_nodes_in_group(Groups.ENEMY_SHOT):
		(n as Node).queue_free()
	_release()
	await _frames(4)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _release() -> void:
	for a: String in ["skill_bolt", "skill_lance", "skill_nova", "skill_ward", "skill_step", "staff_strike", "guard", "dodge",
			"move_left", "move_right", "move_forward", "move_back", "sprint"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)
	if p != null:
		p.debug_drive(Vector3.ZERO)


func _stand(at: Vector3, y: float) -> void:
	_release()
	p.teleport(at + Vector3.UP * 0.12)
	p.velocity = Vector3.ZERO
	p.set_view(y, -0.12)
	p._face_now(_dir(y))
	p.reset_physics_interpolation()
	p.gloom = 0.0
	p.wounds = 0.0
	p._hurt_grace_until = 0.0


func _spawn(kind: String, at: Vector3, face: Vector3) -> Enemy:
	var path: String = kind if kind.begins_with("res://") else String(SCRIPTS.get(kind, ""))
	if path == "" and ResourceLoader.exists("res://core/life/encounters/elite_%s.gd" % kind):
		path = "res://core/life/encounters/elite_%s.gd" % kind
	var e := (load(path) as GDScript).new() as Enemy
	if path.contains("/elite_") and not e.has_meta(&"elite_id"):
		e.set_meta(&"elite_id", path.get_file().get_basename().trim_prefix("elite_"))
	if "dormant" in e:
		e.set("dormant", false)
	main.add_child(e)
	var hq := _space().intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 20.0, Layers.WORLD))
	if hq:
		at = hq.position
	e.global_position = at + Vector3.UP * 0.1
	e.home = e.global_position
	var d := face - at
	d.y = 0.0
	if d.length() > 0.1:
		e._face_dir = d.normalized()
	if e.has_method("on_engaged"):
		e.call("on_engaged", p)
	e.wake()
	return e


func _fight(nm: String, spec: String, ground: Vector3) -> void:
	await _clear()
	fname = nm
	log_lines.clear()
	frames.clear()
	zones.clear()
	last_state.clear()
	last_hp.clear()
	foes.clear()
	spikes.clear()
	ft.clear()
	hurts = 0
	hurt_total = 0.0
	dealt = 0.0
	kills = 0
	sheet_i = 0
	boss = null
	bot_t = 0.0
	lance_t = 0.0
	step_cd = 0.0
	if spec.begins_with("boss:"):
		var bid := spec.trim_prefix("boss:").get_slice("@", 0).get_slice("^", 0)
		phase_at.clear()
		for r: String in spec.split("^").slice(1):
			phase_at.append(float(r))
		boss = await _arena_boss(bid)
		if boss != null and spec.contains("@"):
			# a later phase: the life set below its mark, the floor's signature count met, and the change let play out
			var ratio := float(spec.get_slice("@", 1))
			await get_tree().create_timer(2.6).timeout
			boss.set("_sig", 2)
			boss._ward_t = 0.0
			boss.hp = float(boss.max_hp) * ratio
			boss._refresh_hp(false)
		if boss == null:
			_log("FAIL: the arena never pulled " + bid)
			summary.append("%s: the arena never pulled the boss" % nm)
			return
		foes.append(boss)
		if boss._rig != null and boss._rig.get("clip_rate") != null:
			_log("BOSS rig clip_rate %.3f" % float(boss._rig.get("clip_rate")))
	else:
		_stand(ground, yaw)
		await _frames(30)
		var fwd := _dir(yaw)
		if SETS.has(spec):
			spec = SETS[spec]
		for row: String in spec.split("+", false):
			var parts := row.split("@")
			var kind := parts[0]
			var dist := float(parts[1]) if parts.size() > 1 else 7.0
			var brg := float(parts[2]) if parts.size() > 2 else 0.0
			var spot := ground + fwd.rotated(Vector3.UP, deg_to_rad(brg)) * dist
			var e := _spawn(kind, spot, ground)
			e.chase_range = maxf(e.chase_range, 30.0)
			foes.append(e)
	for e: Enemy in foes:
		last_state[e.get_instance_id()] = e._state
		last_hp[e.get_instance_id()] = e.hp
	f0 = Engine.get_physics_frames()
	_pipes = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))
	_log("FIGHT %s spec=%s bot=%s player at %s" % [nm, spec, bot, p.global_position.snapped(Vector3.ONE * 0.1)])
	for e: Enemy in foes:
		_log("  %s hp %.1f poise %.1f windup %.2f strike_range %.2f arc %.0f dmg %.1f x%.2f lvl %d at %.1f m" % [_who(e), e.hp, e.poise,
			e.windup_time, e.strike_range, e.strike_arc, e.strike_gloom, e.dmg_mult, e.level(), e.global_position.distance_to(p.global_position)])
	var end := secs
	var t := 0.0
	var next_cap := 0
	recording = true
	while t < end:
		await get_tree().physics_frame
		t = float(Engine.get_physics_frames() - f0) / 60.0
		if every > 0 and Engine.get_physics_frames() - f0 >= next_cap:
			next_cap += every
			await _cap("")
		if is_instance_valid(boss) and Engine.get_physics_frames() % 60 == 0:
			var ar: BossArena = null
			for a in get_tree().get_nodes_in_group(&"boss_arena"):
				if String(boss.get_meta(&"boss_id", "")) == (a as BossArena).boss_id:
					ar = a as BossArena
			_log("STATUS boss hp %.0f state %s st %.2f cast '%s' %.2f/%.2f proc %d floor %s ward %.1f | arena active %s held %s | player %s %.1f m from centre, %.1f m from boss" % [
				boss.hp, STATE_N[boss._state], boss._state_t, boss.cast_name, boss.cast_elapsed, boss.cast_time, boss.process_mode, boss.is_on_floor(),
				boss._ward_t, ar._active if ar else false, ar.is_held() if ar else false, p.global_position.snapped(Vector3.ONE * 0.1),
				Vector2(p.global_position.x - arena_c.x, p.global_position.z - arena_c.z).length(), boss.global_position.distance_to(p.global_position)])
		if is_instance_valid(boss) and boss.is_alive() and not phase_at.is_empty():
			var k := phase_at.size()
			for j in k:
				var at_t := secs * float(j + 1) / float(k + 1)
				if t >= at_t and t - 1.0 / 60.0 < at_t:
					boss.set("_sig", 2)
					boss._ward_t = 0.0
					boss.hp = minf(boss.hp, float(boss.max_hp) * phase_at[j])
					boss._refresh_hp(false)
					_log("HARNESS boss life set to %.0f%% (phase step %d)" % [phase_at[j] * 100.0, j + 2])
		if not want_full.is_empty() and every > 0:
			var lab: String = want_full.pop_front()
			await _cap(lab)
		var alive := 0
		for v: Variant in foes:
			if is_instance_valid(v) and (v as Enemy).is_alive():
				alive += 1
		if alive == 0 and t > 1.0:
			_log("ALL DOWN at %.2f s" % t)
			end = minf(end, t + 1.5)
	recording = false
	_release()
	_flush_sheets(true)
	var ms := Array(ft)
	ms.sort()
	var p99: float = ms[int(ms.size() * 0.99)] if not ms.is_empty() else 0.0
	var avg := 0.0
	for m: float in ms:
		avg += m
	avg /= maxf(float(ms.size()), 1.0)
	var line := "%s: %.1f s, hurts %d (%.0f wounds), dealt %.1f, kills %d/%d, frame avg %.1f ms p99 %.1f ms worst %.1f ms, spikes %d" % [
		nm, t, hurts, hurt_total, dealt, kills, foes.size(), avg, p99, (ms[-1] if not ms.is_empty() else 0.0), spikes.size()]
	_log("SUMMARY " + line)
	summary.append(line)
	_write(out.path_join(nm + ".log"), "\n".join(log_lines) + "\n")
	fname = ""
	print("STRIP fight ", line)


# ------------------------------------------------------------------------------------------------------
# tracking

func _who(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return "?"
	var s := n.get_script() as Script
	var k := s.resource_path.get_file().get_basename() if s else n.get_class()
	return "%s#%d" % [k, n.get_instance_id() % 1000]


func _ff() -> int:
	return Engine.get_physics_frames() - f0


func _log(s: String) -> void:
	if fname == "":
		return
	log_lines.append("f%04d t%6.2f %s" % [_ff(), float(_ff()) / 60.0, s])


func _on_node_added(n: Node) -> void:
	if fname != "":
		_added += 1
	if fname == "" or not (n is MeshInstance3D):
		return
	var mi := n as MeshInstance3D
	var sm := mi.material_override as ShaderMaterial
	if sm == null or sm.shader != SpellFx.DANGER:
		return
	(func() -> void:
		if not is_instance_valid(mi) or not mi.is_inside_tree():
			return
		var sz: Vector2 = mi.get_instance_shader_parameter(&"size_m")
		var shape := int(sm.get_shader_parameter("shape"))
		var half := float(sm.get_shader_parameter("half_angle"))
		var col: Vector3 = sm.get_shader_parameter("color")
		var near := _nearest_foe(mi.global_position)
		zones[mi.get_instance_id()] = {"mi": mi, "f": _ff(), "full": -1, "shape": shape, "half": half, "size": sz,
			"at": mi.global_position, "by": near}
		var d := mi.global_position.distance_to(p.global_position)
		_log("TELL zone#%d %s %s r=%.2f x %.2f half=%.0f deg col=%s at %.1f m from player, by~%s, player inside=%s" % [
			mi.get_instance_id() % 10000, "rect" if shape == 1 else ("cone" if half < 3.1 else "disc"), "", sz.x, sz.y, rad_to_deg(half),
			Color(col.x, col.y, col.z).to_html(false), d, _who(near), _inside(mi, p.global_position)])
		if full_tells and zones.size() <= 400:
			want_full.append("tell%d" % (mi.get_instance_id() % 10000))
	).call_deferred()


func _nearest_foe(at: Vector3) -> Enemy:
	var best: Enemy = null
	var bd := 1.0e9
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		var en := e as Enemy
		if en == null:
			continue
		var d := en.global_position.distance_to(at)
		if d < bd:
			bd = d
			best = en
	return best


## Is `pos` inside the zone as DRAWN (the quad's transform and the shader's shape)?
func _inside(mi: MeshInstance3D, pos: Vector3) -> bool:
	var sm := mi.material_override as ShaderMaterial
	var loc := mi.global_transform.affine_inverse() * pos
	var px := loc.x
	var pz := loc.z
	if int(sm.get_shader_parameter("shape")) == 1:
		return absf(px) <= 1.0 and absf(pz) <= 1.0
	if Vector2(px, pz).length() > 1.0:
		return false
	var half := float(sm.get_shader_parameter("half_angle"))
	return absf(atan2(px, -pz)) <= half


func _track() -> void:
	for id: int in zones.keys():
		var z: Dictionary = zones[id]
		if not is_instance_valid(z.mi):
			if int(z.full) < 0:
				_log("TELL zone#%d GONE before full (cancelled), shown %d frames" % [id % 10000, _ff() - int(z.f)])
			zones.erase(id)
			continue
		var mi := z.mi as MeshInstance3D
		var pr := float(mi.get_instance_shader_parameter(&"progress"))
		if int(z.full) < 0 and pr >= 0.999:
			z.full = _ff()
			_log("TELL zone#%d FULL after %d frames (%.2f s), player inside=%s" % [id % 10000, _ff() - int(z.f), float(_ff() - int(z.f)) / 60.0, _inside(mi, p.global_position)])
	var all := get_tree().get_nodes_in_group(Groups.ENEMY)
	for n in all:
		var e := n as Enemy
		if e == null:
			continue
		var id := e.get_instance_id()
		if not last_state.has(id) and e.global_position.distance_to(p.global_position) > 45.0:
			continue                              # a camp elsewhere in the Realm (respawned after the clear)
		if not last_state.has(id):
			last_state[id] = e._state
			last_hp[id] = e.hp
			_log("ADD %s (hp %.1f) at %.1f m" % [_who(e), e.hp, e.global_position.distance_to(p.global_position)])
			if not foes.has(e):
				foes.append(e)
			continue
		if int(last_state[id]) != e._state:
			var extra := ""
			if e._state == Enemy.WINDUP or e._state == Enemy.LEAP_PREP or e._state == Enemy.SPECIAL:
				extra = " windup %.2f s dist %.2f %s" % [e._cur_windup, e._dist, _onscreen(e)]
			elif e._state == Enemy.STRIKE:
				extra = " dist %.2f facing-err %.0f deg" % [e._dist, _face_err(e)]
			_log("STATE %s %s -> %s%s" % [_who(e), STATE_N[int(last_state[id])], STATE_N[e._state], extra])
			last_state[id] = e._state
		if absf(float(last_hp[id]) - e.hp) > 0.001:
			_log("HP %s %.1f -> %.1f (%.1f)%s" % [_who(e), float(last_hp[id]), e.hp, float(last_hp[id]) - e.hp, " broken" if e.is_broken() else ""])
			last_hp[id] = e.hp


## Where the foe is on the player's screen: "onscreen", "edge" (within 8 % of a side) or "OFFSCREEN" (behind or out).
func _onscreen(e: Node3D) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "?"
	var c := e.global_position + Vector3.UP * 1.0
	if cam.is_position_behind(c):
		return "OFFSCREEN(behind)"
	var sp := cam.unproject_position(c)
	var sz := get_viewport().get_visible_rect().size
	if sp.x < 0.0 or sp.y < 0.0 or sp.x > sz.x or sp.y > sz.y:
		return "OFFSCREEN"
	if sp.x < sz.x * 0.08 or sp.x > sz.x * 0.92:
		return "edge"
	return "onscreen"


## Degrees between where the enemy's body faces (as drawn) and where its strike aims (_face_dir).
func _face_err(e: Enemy) -> float:
	if e._face == null:
		return 0.0
	var drawn := -e._face.global_basis.z
	drawn.y = 0.0
	var aim := e._face_dir
	aim.y = 0.0
	if drawn.length() < 0.01 or aim.length() < 0.01:
		return 0.0
	return rad_to_deg(drawn.normalized().angle_to(aim.normalized()))


func _on_hurt(amount: float, from: Vector3) -> void:
	if fname == "":
		return
	hurts += 1
	hurt_total += amount
	var near := _nearest_foe(from) if from != Vector3.INF else null
	var zs := ""
	for id: int in zones.keys():
		var z: Dictionary = zones[id]
		if not is_instance_valid(z.mi):
			continue
		var mi := z.mi as MeshInstance3D
		var full := int(z.full)
		zs += " zone#%d(full %s, inside_drawn=%s, prog %.2f fade %.2f)" % [id % 10000, ("%+df" % (_ff() - full)) if full >= 0 else "NOT YET",
			_inside(mi, p.global_position), float(mi.get_instance_shader_parameter(&"progress")), float(mi.get_instance_shader_parameter(&"fade"))]
	var st := ""
	if near != null:
		st = " %s state %s st %.2f dist %.2f %s" % [_who(near), STATE_N[near._state], near._state_t, near.global_position.distance_to(p.global_position), _onscreen(near)]
	_log("HURT %.1f wounds now %.0f/%.0f from %s%s%s%s" % [amount, p.wounds, p.wounds_max, from.snapped(Vector3.ONE * 0.1) if from != Vector3.INF else "?",
		st, zs if zs != "" else " NO ZONE DRAWN", " (evading)" if p.is_evading() else ""])
	if full_hits:
		want_full.append("hurt%d" % hurts)
	if p.wounds > p.wounds_max - 30.0:
		p.wounds = 0.0
		_log("(harness: wounds reset; the wanderer would have been near hollowed)")


func _on_damage(target: Node, amount: float, crit: bool, school: StringName, _at: Vector3) -> void:
	if fname == "":
		return
	dealt += amount
	_log("DEALT %s %.2f%s school %s" % [_who(target), amount, " CRIT" if crit else "", school])


func _on_killed(e: Node) -> void:
	if fname == "":
		return
	kills += 1
	_log("KILL %s" % _who(e))
	if full_hits:
		want_full.append("kill%d" % kills)


# ------------------------------------------------------------------------------------------------------
# the bot

func _target() -> Enemy:
	var best: Enemy = null
	var bd := 1.0e9
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := n as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position.distance_to(p.global_position) - (8.0 if e.boss else 0.0)
		if d < bd:
			bd = d
			best = e
	return best


## The red zone the wanderer stands in that lands soonest (null if none).
func _danger_here() -> MeshInstance3D:
	var best: MeshInstance3D = null
	var bp := -1.0
	for id: int in zones.keys():
		if not is_instance_valid((zones[id] as Dictionary).mi):
			continue
		var mi := (zones[id] as Dictionary).mi as MeshInstance3D
		var pr := float(mi.get_instance_shader_parameter(&"progress"))
		if pr < 0.999 and _inside(mi, p.global_position) and pr > bp:
			bp = pr
			best = mi
	return best


func _bot(dt: float) -> void:
	p.gloom = 0.0
	bot_t += dt
	step_cd = maxf(0.0, step_cd - dt)
	var tg := _target()
	if tg == null:
		_release()
		return
	if p.lock_target() != tg and tg.global_position.distance_to(p.global_position) < 40.0:
		p._set_lock(tg)
	if bot == "stand":
		p.debug_drive(Vector3.ZERO)
		return
	var to := tg.global_position - p.global_position
	to.y = 0.0
	var d := to.length()
	var dir := to / maxf(d, 0.01)
	var side := Vector3(-dir.z, 0.0, dir.x)
	var z := _danger_here()
	if z != null:
		var pr := float(z.get_instance_shader_parameter(&"progress"))
		var away := p.global_position - z.global_position
		away.y = 0.0
		if away.length() < 0.3:
			away = side
		if bot == "fight" and pr > 0.6 and step_cd <= 0.0 and p.can_shadowstep():
			# a Rift Step out the near side, along the camera-relative stick
			var loc := Basis(Vector3.UP, p._yaw).inverse() * away.normalized()
			_stick(Vector2(loc.x, loc.z))
			Input.action_press("skill_step")
			step_cd = 1.2
			_log("BOT step (zone prog %.2f)" % pr)
			get_tree().create_timer(0.08).timeout.connect(func() -> void:
				Input.action_release("skill_step")
				_stick(Vector2.ZERO))
			return
		if bot != "stand":
			p.debug_drive(away.normalized(), true)
			if Input.is_action_pressed("skill_bolt"):
				Input.action_release("skill_bolt")
			return
	if bot == "dodge":
		p.debug_drive(Vector3.ZERO)
		return
	var want := 3.0 if bot == "melee" else (7.0 if not tg.boss else 11.0)
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.5, 3.0)
		strafe = -strafe
	var wish := side * strafe * 0.6
	if d > want + 1.5:
		wish += dir
	elif d < want - 1.5:
		wish -= dir
	if bot == "melee":
		p.debug_drive(dir if d > 2.2 else Vector3.ZERO)
		if d < 3.2 and fmod(bot_t, 0.4) < dt * 1.5:
			Input.action_press("staff_strike")
			get_tree().create_timer(0.05).timeout.connect(func() -> void: Input.action_release("staff_strike"))
		return
	p.debug_drive(wish.limit_length(1.0))
	# the bolt held in bursts (the heat rule), a Lance every ~5 s, a Nova on three Marks near
	lance_t += dt
	var burst := fmod(bot_t, 2.2) < 1.8
	if lance_t > 5.0:
		if Input.is_action_pressed("skill_bolt"):
			Input.action_release("skill_bolt")
		if not Input.is_action_pressed("skill_lance"):
			Input.action_press("skill_lance")
		if lance_t > 5.9:
			Input.action_release("skill_lance")
			lance_t = 0.0
		return
	if burst and not Input.is_action_pressed("skill_bolt"):
		Input.action_press("skill_bolt")
	elif not burst and Input.is_action_pressed("skill_bolt"):
		Input.action_release("skill_bolt")
	if tg.marks >= 3 and d < 5.0:
		Input.action_press("skill_nova")
		get_tree().create_timer(0.05).timeout.connect(func() -> void: Input.action_release("skill_nova"))


func _stick(v: Vector2) -> void:
	for a: String in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)
	if v.x < -0.2: Input.action_press("move_left", -v.x)
	if v.x > 0.2: Input.action_press("move_right", v.x)
	if v.y < -0.2: Input.action_press("move_forward", -v.y)
	if v.y > 0.2: Input.action_press("move_back", v.y)


# ------------------------------------------------------------------------------------------------------
# bosses in their arenas

func _arena_boss(key: String) -> Enemy:
	var row: Array = ARENAS.get(key, [key, ""])
	var akey := String(row[0])
	var seal := String(row[1])
	if akey == "bone_abbot":
		Travel.bosses_slain.erase("bone_abbot")
	else:
		Travel.bosses_slain["bone_abbot"] = true
	if akey == "ascended_warden":
		Travel.bosses_slain["thornwarden"] = true
	if seal != "":
		for sp: Variant in get_tree().root.find_children("EnemySpawner", "", true, false):
			for slot: Variant in (sp as Object).get("_slots"):
				var pawn: Variant = slot.get("pawn")
				if String(slot.get("seal", "")) == seal and is_instance_valid(pawn) and pawn is Enemy:
					(pawn as Enemy).take_hit(999.0)
	var arena: BossArena = null
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id.contains(akey):
			arena = a as BossArena
	if arena == null:
		return null
	arena.set_physics_process(true)
	arena_c = arena.global_position
	arena_r = arena.radius
	var c := arena.global_position
	var gout := Vector3(0.0, 0.0, 1.0)
	var gate := arena.gate as Node3D
	if gate != null:
		gout = gate.global_position - c
		gout.y = 0.0
		gout = gout.normalized()
	var at := c + gout * minf(12.0, arena.radius * 0.6)
	if akey == "bone_abbot":
		at = Ossuary.abbot_pull_at()
	var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 8.0, Layers.WORLD, [p.get_rid()]))
	if not hit.is_empty():
		at = hit.position
	var far := c + gout * (arena.radius + 14.0)
	far.y = c.y + 0.5
	_stand(far, _yaw_of(c - far))
	await get_tree().create_timer(2.0).timeout
	# walk in, as a wanderer would (a teleport to the pull streamed the place in on the pull's own frames)
	var walk_end := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < walk_end:
		var to_at := at - p.global_position
		to_at.y = 0.0
		if to_at.length() < 1.5:
			break
		p.debug_drive(to_at.normalized())
		p.set_view(_yaw_of(to_at), -0.1)
		await get_tree().physics_frame
	p.debug_drive(Vector3.ZERO)
	if Vector2(at.x - p.global_position.x, at.z - p.global_position.z).length() > 3.0:
		_stand(at, _yaw_of(c - at))          # the walk was blocked: put the wanderer there
	var found: Enemy = null
	var end := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < end and found == null:
		await get_tree().physics_frame
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if String((e as Node).get_meta(&"boss_id", "")) == arena.boss_id and (e as Enemy).is_alive() and not (e as Node).is_queued_for_deletion():
				found = e as Enemy
	print("STRIP arena ", akey, " centre ", c, " r ", arena.radius, " boss ", found)
	return found


# ------------------------------------------------------------------------------------------------------
# capture

func _cap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	if label != "":
		img.save_jpg(out.path_join("%s_full_f%04d_%s.jpg" % [fname, _ff(), label]), 0.88)
		return
	frames.append([img, _ff()])
	if frames.size() >= PER_SHEET:
		_flush_sheets(false)


func _flush_sheets(last: bool) -> void:
	if frames.is_empty() or (not last and frames.size() < PER_SHEET):
		return
	var n := frames.size()
	var rows := ceili(float(n) / float(COLS))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color.BLACK)
	for i in n:
		var im: Image = (frames[i][0] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		_label(im, "f%d" % int(frames[i][1]))
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
	sheet.save_jpg(out.path_join("%s_s%02d.jpg" % [fname, sheet_i]), 0.85)
	sheet_i += 1
	frames.clear()


const GLYPH := {"0": "01110100011001110101110011000101110", "1": "00100011000010000100001000010001110",
	"2": "01110100010000100010001000100011111", "3": "11110000010000101110000010000111110",
	"4": "00010001100101010010111110001000010", "5": "11111100001111000001000011000101110",
	"6": "00110010001000011110100011000101110", "7": "11111000010001000100010000100001000",
	"8": "01110100011000101110100011000101110", "9": "01110100011000101111000010001001100",
	"f": "00110010000100011100010000100001000"}


func _label(img: Image, text: String) -> void:
	var s := 3
	for y in 7 * s + 6:
		for x in text.length() * 6 * s + 6:
			img.set_pixel(x, y, img.get_pixel(x, y) * 0.2)
	var x0 := 3
	for ch in text:
		var g: String = GLYPH.get(ch, "")
		if g != "":
			for row in 7:
				for col in 5:
					if g[row * 5 + col] == "1":
						img.fill_rect(Rect2i(x0 + col * s, 3 + row * s, s, s), Color(1.0, 0.95, 0.6))
		x0 += 6 * s


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
