extends Node3D
## Encounters director (docs/LIFE_PLAN.md, system "encounters"): a night that pushes back.
##   tiers     the camps' pawns are scaled and dressed by region and progress (tiers.gd,
##             variants.gd) through EnemySpawner's kind/dress hooks; camps gain a mixed member
##   rest      killed roaming camps stay dead until you rest at a lit fire (stand in it a few
##             seconds, kindle one, or come back from being hollowed): then they refill
##   tide      every few minutes spent away from fires the Gloom tide rises: the sky darkens (an overlay, not
##             the grade), tide-born hunting packs come for you in waves; a lit fire breaks it (or it recedes)
##   ambushes  marked stretches of the roads: walk one and the hollowed rise from the verge ahead
##             and beside you (they take a moment to rise: you see them first)
##   elites    five named hollowed with bounties (elites.gd), notes on stakes and a board at the Crossing's
##             foot; paid once. Deeper Night: after the Ascended Warden the bell at the summit and the
##             Crossing's foot begins NG+ (bosses and seals reset, two tiers deeper, Umbral elites, cold tint)
## Fair: nothing of ours rises in a safe place (the haven, the tavern, the Holds, the towns: SpawnRules.SAFE),
## a building, light, water, on a way, a lip or a slope, or inside a rock (spot_ok); at most CAP enemies near
## the player for anything this adds; every attack keeps its telegraph. Cheap: one 4 Hz tick.
## State: Travel.system_state("encounters") = {ng, slain, looted, trophies, tides, ambushes}.

const TickPhase := preload("res://core/util/tick_phase.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const Elites := preload("res://core/life/encounters/elites.gd")
const EliteKit := preload("res://core/life/encounters/elite_kit.gd")
const Hud := preload("res://core/life/encounters/encounter_hud.gd")
const Post := preload("res://core/life/encounters/bounty_post.gd")
const Bell := preload("res://core/life/encounters/deeper_bell.gd")
const Guardians := preload("res://core/life/encounters/guardians.gd")
const Pilgrim := preload("res://core/enemy/pilgrim.gd")
const Synth := preload("res://core/vfx/synth.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const SpawnRules := preload("res://core/life/encounters/spawn_rules.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const AmbushSites := preload("res://core/life/encounters/ambush_sites.gd")
const Staging := preload("res://core/life/encounters/staging.gd")

const TICK := 0.25
const CAP := 12                    ## most enemies near the player that tides/ambushes/elites add to
const CAP_R := 38.0
const HAVEN_C := Vector2(4.0, 36.0)
const HAVEN_R := 34.0              ## Hearthward and the spawn clearing: nothing of ours spawns in it
## r34: the Rooted Holds' clearing is safe-ish too (no tide, no ambush, nothing of ours rises in it)
const HOLDS_C := Vector2(-165.0, 12.0)
const HOLDS_R := 21.0
## r34: an ambush laid on purpose (as well as the planned ones along every way): Corvin's Mere's
## causeway, half-way over the water, where the drowned climb up out of the mere.
const FIXED_AMBUSHES := [{"at": Vector2(102.6, 113.0), "dir": Vector2(0.23, 0.97), "path": "mere_causeway"}]
const TIDE_EVERY := 330.0          ## seconds away from fires before a tide (fewer as tiers climb)
const TIDE_MIN := 200.0
const TIDE_WARN := 25.0
const TIDE_MAX := 150.0            ## a tide recedes on its own after this
const TIDE_WAVE := 36.0
const TIDE_WAVES := 3
const SAFE_STAND := 1.5            ## seconds in a lit fire that break a tide
const REST_STAND := 3.0            ## seconds in a lit fire that count as a rest
const AMBUSH_R := 6.0
const AMBUSH_CD := 360.0
const AMBUSH_GAP := 75.0           ## at least this long between any two ambushes
const ELITE_NEAR := 72.0
const ELITE_FAR := 95.0
## The bell: beside the Crossing's foot (candidates in order) and on the summit platform (the far north-east: Endgame).
const BELLS := [[Vector3(3.4, 0.0, 2.0) + Endgame.O, Vector3(3.0, 0.0, 0.5) + Endgame.O, Vector3(-3.4, 0.0, 1.5) + Endgame.O],
	[Vector3(-4.5, 27.35, -80.0) + Endgame.O, Vector3(4.5, 27.35, -80.0) + Endgame.O]]
const BOARD := Vector2(3.5, 10.5)  ## the bounty board, beside north_lane on the way out of the village
const BRAZIER_NAMES := ["StairFoot", "Shrine", "Landing", "Threshold"]

var root: Node3D
var spawner: EnemySpawner
var hud: Hud
var state: Dictionary
var ready_done := false

var tide_clock := 0.0              ## seconds spent away from fires since the last tide/rest
var tide_on := false
var tide_age := 0.0
var _waves := 0
var _warned := false
var hunters: Array = []           ## Enemy (may hold freed ones until _prune)
var _motes: GPUParticles3D

var _lit_t := 0.0
var _rest_armed := false
var _rest_at := Vector3.INF

var ambushes: Array[Dictionary] = []
var ambushers: Array = []
var _ambush_gap := 30.0

var haunts: Dictionary = {}        ## elite id -> Vector3 (on the ground)
var elite_nodes: Dictionary = {}   ## elite id -> Enemy
var posts: Array[Node3D] = []
var bells: Array[Node3D] = []

var _acc := 0.0
var _player: Player
var _space: PhysicsDirectSpaceState3D
var guardians: Guardians                ## r31: the mini-bosses at points of interest (guardians.gd)
var _cap: CapsuleShape3D


func _ready() -> void:
	name = "Encounters"
	_acc = TickPhase.first(self, TICK)     # its 4 Hz step on frames of its own (tick_phase.gd)
	Synth.prewarm()   # combat sounds built behind the load screen, not on the first hit
	# the root leaves the tree only when the app closes (after every scene node's _exit_tree):
	# drop the combat sound caches then, not on a scene change (they would be rebuilt)
	var rel := Callable(Synth, &"release")
	if not get_tree().root.tree_exiting.is_connected(rel):
		get_tree().root.tree_exiting.connect(rel)
		get_tree().root.tree_exiting.connect(Callable(load("res://core/vfx/staff_sfx.gd"), &"release"))
	state = Travel.system_state("encounters")
	for k: String in ["slain", "looted", "trophies"]:
		if not (state.get(k) is Dictionary):
			state[k] = {}
	if not state.has("ng"):
		state["ng"] = 0
	hud = Hud.new()
	add_child(hud)
	hud.set_deeper(ng())
	Events.enemy_killed.connect(_on_killed)
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: rest("kindled"))
	Events.respawned.connect(func(_at: Vector3) -> void: rest("hollowed"))
	Events.boss_engaged.connect(_on_boss)


func ng() -> int:
	return int(state.get("ng", 0))


## Called by encounters.gd once the Realm's ground exists (may also be called by tests).
func setup(world: Node3D) -> void:
	root = world
	_space = get_world_3d().direct_space_state
	spawner = root.get_node_or_null("EnemySpawner") as EnemySpawner
	EnemySpawner.kind_hook = _kind_hook
	EnemySpawner.dress_hook = _dress_hook
	EnemySpawner.hold_for_rest = true
	_place_bells()
	guardians = Guardians.new()
	guardians.director = self
	add_child(guardians)
	_motes = _make_motes()
	add_child(_motes)
	if spawner:
		if spawner.planted_done:
			_after_planted()
		else:
			spawner.planted.connect(_after_planted, CONNECT_ONE_SHOT)
	# the ambushes, the elites' haunts and their notices go on the ground as it ends up (TerrainStamp.settle and the
	# places built after this module move it and claim it)
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and root.is_inside_tree() and not root.has_meta("realm_done") and Time.get_ticks_msec() - t0 < 180000:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	_plan_ambushes()
	_place_elites()
	_place_posts()
	ready_done = true
	print("ENCOUNTERS ready: ng %d, depth %d, %d ambush sites, %d elites (%s), %d posts" % [ng(), Tiers.night_depth(),
		ambushes.size(), haunts.size(), ", ".join(haunts.keys()), posts.size()])


func _exit_tree() -> void:
	EnemySpawner.hold_for_rest = false


# --- tiers through the spawner hooks ------------------------------------------------------------

func _kind_hook(slot: Dictionary) -> Variant:
	if String(slot.get("seal", "")) != "" or String(slot.get("key", "")).begins_with("enc"):
		return null
	var at: Vector3 = slot.at
	var tier := Tiers.tier_at(at)
	if tier < 3:
		return null
	var key := String(slot.key)
	var n := int(slot.get("enc_n", 0))
	if Tiers.roll(key, 61 + n) < 0.12 * float(tier - 2):
		return Tiers.script_for(Tiers.extra_kind(at, key + str(n)))
	return null


func _dress_hook(pawn: Node, slot: Dictionary) -> void:
	var at: Vector3 = slot.at
	var n := int(slot.get("enc_n", 0))
	slot["enc_n"] = n + 1
	var tier := Tiers.tier_at(at)
	Tiers.scale_stats(pawn, tier)
	var v := String(slot.get("variant", ""))      # r34: a camp's (or its region's) own look wins
	if v == "":
		v = Tiers.pick_variant(at, String(slot.key), n)
	if v != "":
		Variants.pre(pawn, v)
		pawn.ready.connect(Variants.dress.bind(pawn, v), CONNECT_ONE_SHOT)


## Camps planted before this module loaded: scale and dress the live pawns, then add mixed members.
func _after_planted() -> void:
	if spawner == null or not is_instance_valid(spawner):
		return
	var slots: Array = spawner.slots()
	var camps := {}
	for slot: Dictionary in slots:
		var pawn: Variant = slot.pawn
		if is_instance_valid(pawn) and not (pawn as Node).has_meta(&"enc_tier"):
			var tier := Tiers.tier_at(slot.at)
			Tiers.scale_live(pawn, tier)
			# r34: a pawn the spawner already dressed in its camp's regional look keeps it
			var v := "" if (pawn as Node).has_meta(&"enc_variant") else Tiers.pick_variant(slot.at, String(slot.key), 0)
			if v != "":
				Variants.pre(pawn, v)
				Variants.dress(pawn, v)
				var hp_bar: MeshInstance3D = (pawn as Enemy)._hp_bar
				if hp_bar != null:
					hp_bar.set_instance_shader_parameter(&"segments", Enemy.hp_segments((pawn as Enemy).max_hp))
			slot["enc_n"] = 1
		var ck := String(slot.key).get_slice("#", 0)
		if String(slot.get("seal", "")) == "" and not ck.begins_with("enc") and not camps.has(ck):
			camps[ck] = slot.at
	var added := 0
	var rolled := 0
	for ck: String in camps:
		var at: Vector3 = camps[ck]
		var t := Tiers.info(Tiers.tier_at(at))
		if Tiers.roll(ck, 7 + ng()) >= float(t.extra):
			continue
		rolled += 1
		var spot := _ground_near(at, 3.0)
		if spot == Vector3.INF:
			continue
		var kind := Tiers.extra_kind(at, ck)
		spawner.add_slot(spot, Tiers.script_for(kind), "enc_mix_%s#0" % ck)
		added += 1
	print("ENCOUNTERS camps: %d slots in %d roaming camps; %d drew a mixed member, %d placed" % [slots.size(), camps.size(), rolled, added])


# --- the tick -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not ready_done:
		return
	_acc += delta
	if _acc < TICK:
		return
	step(_acc)
	_acc = 0.0


## One director step of `dt` seconds (tests call this directly with large steps).
func step(dt: float) -> void:
	_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if _player == null:
		return
	var pos := _player.global_position
	var lit := LightGrid.is_lit(pos)
	_rest_tick(dt, pos, LightGrid.is_fire(pos))      # r30: only a fire rests or breaks a tide, not a ward
	_tide_tick(dt, pos, lit)
	_ambush_tick(dt, pos, lit)
	var may_build := guardians == null or not guardians.tick(pos)     # one guardian or elite built a tick at most
	_elite_tick(pos, may_build)
	_prune(pos)
	if _motes:
		_motes.global_position = pos + Vector3.UP * 2.0
		_motes.emitting = tide_on or ng() > 0
		_motes.amount_ratio = 1.0 if tide_on else 0.3


func _busy_fight() -> bool:
	return get_tree().get_nodes_in_group(&"boss_arena").any(func(a: Node) -> bool: return (a as BossArena)._active)


## Hearthward, its tavern, the Rooted Holds and the towns: no tide gathers here and nothing of ours rises in them.
func _in_haven(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(HAVEN_C) < HAVEN_R or SpawnRules.safe_at(Vector2(p.x, p.z)) != ""


# --- rest ---------------------------------------------------------------------------------------

func _rest_tick(dt: float, pos: Vector3, lit: bool) -> void:
	if lit:
		_lit_t += dt
		if _rest_armed and _lit_t >= REST_STAND:
			rest("stood")
		if tide_on and _lit_t >= SAFE_STAND:
			end_tide(true)
	else:
		_lit_t = 0.0
		if not _rest_armed and (_rest_at == Vector3.INF or pos.distance_to(_rest_at) > 25.0):
			_rest_armed = true


## A rest at a fire: the camps refill, any tide breaks, the tide clock starts over, and (standing
## in it) the fire becomes the checkpoint.
func rest(why: String) -> int:
	if why == "stood" and _player:
		var b := Brazier.lit_at(get_tree(), _player.global_position)
		if b:
			b.remember(_player)
	_rest_armed = false
	_rest_at = _player.global_position if _player else Vector3.INF
	tide_clock = 0.0
	_warned = false
	if tide_on:
		end_tide(true)
	var n := 0
	if spawner and is_instance_valid(spawner):
		n = spawner.refill(24.0)
	if n > 0 and why != "hollowed":
		Events.toast.emit("You rest by the fire. Out in the dark, the hollowed gather again.")
	return n


# --- the Gloom tide -----------------------------------------------------------------------------

func tide_period() -> float:
	return maxf(TIDE_MIN, TIDE_EVERY - 22.0 * float(Tiers.night_depth()))


func _tide_tick(dt: float, pos: Vector3, lit: bool) -> void:
	if tide_on:
		tide_age += dt
		hud.status("THE GLOOM TIDE  ·  reach a lit fire")
		for h in hunters:
			if is_instance_valid(h) and h.is_alive():
				h.home = pos                     # they track you: their leash is wherever you are
		if _waves < TIDE_WAVES and tide_age >= float(_waves) * TIDE_WAVE:
			_wave(pos)
		if tide_age >= TIDE_MAX:
			end_tide(false)
		return
	if lit or _busy_fight() or _in_haven(pos) or RealmLayout.in_ossuary(pos):
		return
	tide_clock += dt
	var left := tide_period() - tide_clock
	if left <= TIDE_WARN and not _warned:
		_warned = true
		Events.toast.emit("The dark thickens. A Gloom tide is coming: find a fire.")
		hud.set_tide(0.25)
	if left <= 0.0:
		start_tide()


func start_tide() -> void:
	if tide_on:
		return
	tide_on = true
	tide_age = 0.0
	_waves = 0
	state["tides"] = int(state.get("tides", 0)) + 1
	hud.set_tide(1.0)
	hud.banner("THE GLOOM TIDE RISES", "They are hunting you. Reach a lit fire.")
	if _player:
		Sfx.play_stream(Synth.get_stream("roar"), _player.global_position + Vector3(0, 6, -18), 2.0, 0.42)
		Sfx.play_stream(Synth.get_stream("roar"), _player.global_position + Vector3(14, 6, 12), -2.0, 0.36)
	Events.gloom_tide.emit(true)


## `safe`: broken at a fire (the hunters burn away); else it recedes (they melt into the dark).
func end_tide(safe: bool) -> void:
	if not tide_on:
		return
	tide_on = false
	tide_clock = 0.0
	_warned = false
	hud.set_tide(0.0)
	hud.status("")
	hud.banner("THE TIDE BREAKS ON THE FIRE" if safe else "THE TIDE RECEDES", "" if safe else "For now.")
	for h in hunters:
		if is_instance_valid(h) and h.is_alive():
			_unmake(h)
	hunters.clear()
	Events.gloom_tide.emit(false)
	Travel.save_soon()


func _wave(pos: Vector3) -> void:
	_waves += 1
	var tier := clampi(Tiers.tier_at(pos) + 1, 0, Tiers.TIERS.size() - 1)
	var want := mini(2 + (1 if tier >= 2 else 0) + (1 if _waves >= 2 and tier >= 3 else 0), room(pos))
	var pool: Array = Tiers.REGION_POOL.get(Tiers.region_id(pos), ["wretch", "crawler"])
	var base := randf() * TAU
	var spots: Array[Vector3] = []
	for i in want * 10:                     # (water, ways, lips, rocks and sites refuse many tries: a pack still comes)
		if spots.size() >= want:
			break
		var a := base + randf_range(-0.9, 0.9) + float(i % 2) * PI
		var d := randf_range(19.0, 28.0)
		var spot := _ground_at(pos + Vector3(cos(a) * d, 0.0, sin(a) * d), pos.y + 30.0)
		if spot != Vector3.INF and spot_ok(spot):
			spots.append(spot)
	if not spots.is_empty() and _waves == 1:
		Events.toast.emit("Something is coming through the dark.")
	var wave := _waves                      # one hunter a frame, as the ambushes rise (2-5 in one frame was an 8-15 ms hitch)
	for k in spots.size():
		if k > 0:
			await get_tree().process_frame
			if not is_inside_tree() or not tide_on:
				return
		var e := _make(String(pool[(k + wave) % pool.size()]), spots[k], tier, "deeper" if ng() > 0 else "tideborn")
		if e == null:
			continue
		e.set_meta(&"enc_hunter", true)
		e.set_meta(&"enc_spawn", spots[k])      # where it rose (tests judge that ground: it is walking at you by now)
		e.chase_range = 70.0
		e.hunt_leash = 999.0
		e.sleep_range = 90.0
		e.home = pos
		hunters.append(e)


# --- ambushes -----------------------------------------------------------------------------------

## The road ambushes: where the land suggests one (AmbushSites: fords, causeways, cuttings, ruins, woods, blind
## bends and crests), clear of the fires and the safe places, plus the ones laid on purpose (FIXED_AMBUSHES).
func _plan_ambushes() -> void:
	var keep_off: Array[Vector2] = [Vector2(RealmLayout.SPAWN.x, RealmLayout.SPAWN.z), Vector2(RealmLayout.OSSUARY_GATE.x, RealmLayout.OSSUARY_GATE.z),
		RealmLayout.HENGE_STAIR_FOOT]
	for n: String in BRAZIER_NAMES:
		keep_off.append(n_at(n))
	for b in get_tree().get_nodes_in_group(Groups.BRAZIER):
		keep_off.append(Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z))
	for rid: String in RealmLayout.SLOTS:                 # r34: the new regions' fires
		for sl: Dictionary in RealmLayout.SLOTS[rid]:
			if String(sl.kind) == "fire":
				keep_off.append(sl.at)
	keep_off.append(HOLDS_C)
	# where people walk (the village's networks: the towns, the outposts, the travellers on the road)
	var village := root.get_node_or_null("Village")
	var vnav: Variant = village.get("nav") if village != null else null
	if vnav is Object and (vnav as Object).get("nodes") is Dictionary:
		for q: Variant in ((vnav as Object).get("nodes") as Dictionary).values():
			if q is Vector3 and SpawnRules.safe_at(Vector2((q as Vector3).x, (q as Vector3).z)) == "":
				keep_off.append(Vector2((q as Vector3).x, (q as Vector3).z))
	ambushes = AmbushSites.plan_stored(_space, keep_off, _ground_at, spot_ok)
	for f: Dictionary in FIXED_AMBUSHES:
		var c: Vector2 = f.at
		var g := _ground_at(Vector3(c.x, 0, c.y), 90.0)
		if g == Vector3.INF:
			push_warning("Encounters: no ground for the fixed ambush on %s" % f.path)
			continue
		ambushes = ambushes.filter(func(s: Dictionary) -> bool: return Vector2(s.at.x, s.at.z).distance_to(c) > 30.0)
		ambushes.append({"at": g, "dir": f.dir, "cd": 0.0, "path": String(f.path), "why": String(f.get("why", "causeway"))})


func n_at(n: String) -> Vector2:
	var b := root.get_node_or_null("Zone/Braziers/" + n) as Node3D if root else null
	return Vector2(b.global_position.x, b.global_position.z) if b else Vector2(1e6, 1e6)


func _ambush_tick(dt: float, pos: Vector3, lit: bool) -> void:
	_ambush_gap = maxf(0.0, _ambush_gap - dt)
	for s: Dictionary in ambushes:
		s.cd = maxf(0.0, float(s.cd) - dt)
	if tide_on or lit or _ambush_gap > 0.0 or _busy_fight():
		return
	# a horse's gallop covers the trigger ring in a breath: the ring reaches as far as the headlight
	# a rider would have had on foot (it grows with the pace past a jog)
	var pace := Vector2(_player.velocity.x, _player.velocity.z).length() if _player else 0.0
	var reach := AMBUSH_R + maxf(0.0, pace - 5.0)
	for s: Dictionary in ambushes:
		if float(s.cd) > 0.0:
			continue
		var at: Vector3 = s.at
		if Vector2(pos.x - at.x, pos.z - at.z).length() < reach and absf(pos.y - at.y) < 4.0:
			trigger_ambush(s)
			return


func trigger_ambush(s: Dictionary) -> int:
	s.cd = AMBUSH_CD
	_ambush_gap = AMBUSH_GAP
	var pos := _player.global_position if _player else (s.at as Vector3)
	var tier := Tiers.tier_at(pos)
	var want := mini(2 + (1 if tier >= 2 else 0) + (1 if tier >= 4 else 0), room(pos))
	if want <= 0:
		return 0
	var fwd := Vector3(_player.velocity.x, 0, _player.velocity.z) if _player else Vector3.ZERO
	if fwd.length() < 0.5:
		fwd = Vector3((s.dir as Vector2).x, 0, (s.dir as Vector2).y)
	fwd = fwd.normalized()
	var lead := maxf(1.0, (Vector2(_player.velocity.x, _player.velocity.z).length() if _player else 0.0) / 5.0)   # a gallop is met further on
	var pool: Array = AmbushSites.kinds(Tiers.REGION_POOL.get(Tiers.region_id(pos), ["wretch"]))
	var made := 0
	var later: Array = []                    # [kind, spot, variant] of the ones that rise in the next frames
	for spot in AmbushSites.rise_spots(pos + Vector3(fwd.x, 0.0, fwd.z) * 10.0 * (lead - 1.0), Vector2(fwd.x, fwd.z), _ground_at, spot_ok):
		if made + later.size() >= want:
			break
		var n := made + later.size()
		var kind := String(pool[n % pool.size()])
		var rv := Tiers.region_variant(spot, kind)     # r34: the mere's drowned climb out drowned
		var look := rv if rv != "" else Tiers.pick_variant(spot, "amb%d" % n, int(state.get("ambushes", 0)))
		if made > 0:
			later.append([kind, spot, look])     # one a frame (frame pacing, 16 Nov: 2-4 foes built at once, ~2-3 ms each)
			continue
		if _rise(kind, spot, tier, look) != null:
			made += 1
	if not later.is_empty():
		_rise_later(later, tier)
		made += later.size()
	if made > 0:
		state["ambushes"] = int(state.get("ambushes", 0)) + 1
		hud.banner("AMBUSH", AmbushSites.line(String(s.path), String(s.get("why", ""))), Color(1.0, 0.55, 0.4))
		Sfx.play_stream(Synth.get_stream("growl"), pos + fwd * 8.0, 2.0, 0.6)
	return made


## One of an ambush: it rises asleep (a breath to see it), wakes 0.9 s later.
func _rise(kind: String, spot: Vector3, tier: int, look: String) -> Enemy:
	var e := _make(kind, spot, tier, look)
	if e == null:
		return null
	e.set_meta(&"enc_ambush", true)
	e.sleep()                            # they rise first: a breath to see them
	var eid := e.get_instance_id()
	get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
		var e2 := instance_from_id(eid) as Enemy
		if e2 != null:
			e2.wake())
	Vfx.burst(spot + Vector3.UP * 0.2, Color(0.12, 0.09, 0.08, 0.9), {"count": 22, "life": 0.9, "speed": Vector2(1.0, 3.0), "size": 0.12, "gravity": -6.0, "additive": false, "radius": 0.5})
	ambushers.append(e)
	return e


func _rise_later(plan: Array, tier: int) -> void:
	for r: Array in plan:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_rise(String(r[0]), r[1] as Vector3, tier, String(r[2]))


# --- elites -------------------------------------------------------------------------------------

func _place_elites() -> void:
	haunts.clear()
	for id: String in Elites.ids(ng()):
		for c: Vector2 in Elites.ELITES[id].haunt:
			var g := _ground_at(Vector3(c.x, 0, c.y), 90.0)
			if g != Vector3.INF and spot_ok(g, true):
				haunts[id] = g
				break
		if not haunts.has(id):
			var g := _search(Elites.ELITES[id].haunt[0], 21.0, true)
			if g != Vector3.INF:
				haunts[id] = g
		if not haunts.has(id):
			push_warning("Encounters: no clear haunt for elite %s" % id)
			var hc: Vector2 = Elites.ELITES[id].haunt[0]
			PlacementLog.skip("encounters", "haunt_" + id, Vector3(hc.x, 0, hc.y), "no clear haunt")


func slain(id: String) -> bool:
	return (state.slain as Dictionary).has(id)


func _elite_tick(pos: Vector3, may_build := true) -> void:
	var near: Enemy = null
	var near_d := 18.0
	for id: String in haunts:
		var at: Vector3 = haunts[id]
		var ev: Variant = elite_nodes.get(id)
		var e: Enemy = null
		if ev != null and is_instance_valid(ev):
			e = ev as Enemy
		elif ev != null:
			elite_nodes.erase(id)
		var d := pos.distance_to(at)
		var rise := d < ELITE_NEAR and not LightGrid.is_lit(at) and not _busy_fight()
		if e == null:      # built where the old rule did (near), or again asleep well out of reach (staging.gd)
			if may_build and not slain(id) and (rise or Staging.ahead(d, ELITE_FAR) and not LightGrid.is_lit(at)):
				Staging.built(spawn_elite(id), not rise, d)
				may_build = false
			continue
		if Staging.waits(e, rise, d):
			continue
		var de := pos.distance_to(e.global_position)
		if d > ELITE_FAR and de > ELITE_FAR:
			if not Staging.stand_down([e], d):   # untouched: asleep where it stands; else back to its haunt, healed
				_unmake(e, false)
				elite_nodes.erase(id)
			continue
		if de > e.sleep_range:
			e.sleep()
		else:
			e.wake()
		if e.is_alive() and de < near_d and (e._state != Enemy.IDLE or e.hp < float(e.max_hp)):
			near = e
			near_d = de
	var guard: Enemy = guardians.shown(pos) if guardians and near == null else null
	if near:
		hud.show_elite(Elites.title(String(near.get_meta(&"elite_id")), near.has_meta(&"enc_umbral")), near.hp, float(near.max_hp))
	elif guard:
		hud.show_elite(Guardians.title(guard), guard.hp, float(guard.max_hp))
	elif hud.elite_shown():
		hud.hide_elite()


func spawn_elite(id: String) -> Enemy:
	if not haunts.has(id) or slain(id):
		return null
	var d: Dictionary = Elites.ELITES[id]
	var e := (load(String(d.script)) as GDScript).new() as Enemy
	EliteKit.scale(e, Tiers.tier_at(haunts[id]), ng() > 0)
	e.set_meta(&"display_name", Elites.title(id, ng() > 0))   # r33: Enemy.display_name()
	root.add_child(e)
	e.global_position = haunts[id] + Vector3.UP * 0.05
	e.home = haunts[id]
	elite_nodes[id] = e
	return e


func _on_killed(e: Node) -> void:
	if e == null or not e.has_meta(&"elite_id"):
		return
	var id := String(e.get_meta(&"elite_id"))
	if slain(id):
		return
	(state.slain as Dictionary)[id] = true
	var d: Dictionary = Elites.ELITES.get(id, {})
	var ash := int(d.get("ash", 20)) * (2 if ng() > 0 else 1)
	Travel.give("grave_ash", ash, false)
	var loot := String(d.get("loot", ""))
	var got := ""
	if loot != "" and not (state.looted as Dictionary).has(loot):
		(state.looted as Dictionary)[loot] = true
		if ItemDB.DEFS.has(loot):
			Travel.give(loot, 1, false)
		else:
			(state.trophies as Dictionary)[loot] = true      # kept until ItemDB knows it (see elites.gd LOOT)
		got = String(Elites.LOOT.get(loot, {}).get("name", loot))
	hud.banner("BOUNTY: " + Elites.title(id, e.has_meta(&"enc_umbral")).to_upper(),
		"%d grave ash%s" % [ash, ("  ·  " + got) if got != "" else ""], Color(1.0, 0.75, 0.45))
	hud.hide_elite()
	for m in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (m as Node).get_meta(&"summoned_by", "") == "elite_" + id:
			_unmake(m as Enemy)
	Travel.save_next()                         # a breath after the kill, not in its frame


# --- notes, the board, the bell -----------------------------------------------------------------

func _place_posts() -> void:
	for p in posts:
		if is_instance_valid(p):
			p.queue_free()
	posts.clear()
	var board := _post("", Vector3(BOARD.x, 0, BOARD.y))
	if board:
		board.rotation.y = -PI * 0.5               # facing the path
	for id: String in haunts:
		var at: Vector3 = haunts[id]
		# the nearest point of a path, then a step off it towards the haunt
		var best := Vector2(at.x, at.z)
		var bd := INF
		for path: Dictionary in RealmLayout.PATHS:
			var pts: Array = path.pts
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var ab := b - a
				var t := clampf((Vector2(at.x, at.z) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				var q := a + ab * t
				var dd := q.distance_to(Vector2(at.x, at.z))
				if dd < bd:
					bd = dd
					best = q + (Vector2(at.x, at.z) - q).normalized() * minf(3.5, dd * 0.5) if dd > 0.01 else q
		if bd > 40.0:
			best = Vector2(at.x, at.z) + (Vector2(0, 0) - Vector2(at.x, at.z)).normalized() * 12.0
		var post := _post(id, Vector3(best.x, 0, best.y))
		var f := 0.25
		while post == null and f < 0.8:                # the path's spot is built over or lit (a works, a market): further along the way in
			var q2 := best.lerp(Vector2(at.x, at.z), f)
			post = _post(id, Vector3(q2.x, 0, q2.y))
			f += 0.25
		if post == null:
			push_warning("Encounters: no clear spot for the %s post near %s" % [id, Vector3(best.x, 0, best.y).snapped(Vector3.ONE * 0.1)])
			PlacementLog.skip("encounters", "post_" + (id if id != "" else "board"), Vector3(best.x, 0, best.y), "no clear spot for the post")
		if post and Vector2(post.global_position.x - at.x, post.global_position.z - at.z).length() > 0.2:
			post.look_at(Vector3(at.x, post.global_position.y, at.z), Vector3.UP)     # notice (+Z) faces the path


func _post(id: String, at: Vector3) -> Node3D:
	var spot := Vector3.INF
	for k in 20:                                  # rings out to about 9 m: a new site (a pan field, a wonder) may sit on the first spot
		var a := float(k) * 0.9
		var r := 0.0 if k == 0 else 1.2 + 0.4 * float(k)
		var g := _ground_at(at + Vector3(cos(a) * r, 0, sin(a) * r), 90.0)
		if g == Vector3.INF or LightGrid.is_lit(g) and id != "":
			continue
		if not WorldLanes.site_at(Vector2(g.x, g.z), 0.6).is_empty():
			continue
		spot = g
		break
	if spot == Vector3.INF:
		return null
	var p := Post.new()
	p.director = self
	p.elite_id = id
	p.name = "Bounty_" + (id if id != "" else "board")
	root.add_child(p)
	p.global_position = spot - Vector3.UP * 0.08
	posts.append(p)
	return p


func _place_bells() -> void:
	for cands: Array in BELLS:
		var spot := Vector3.INF
		for at: Vector3 in cands:
			var g := _ground_at(at, 90.0) if at.y == 0.0 else _ground_at(at, at.y + 6.0)
			if g != Vector3.INF and WorldLanes.site_at(Vector2(g.x, g.z), 1.4).is_empty() and _clear_box(g, Vector3(2.6, 2.6, 0.8)):
				spot = g
				break
		if spot == Vector3.INF:                   # every listed spot is taken (the gate's landing grew): look round the first one
			var c0: Vector3 = cands[0]
			for k in 36:
				var a := float(k) * 0.7
				var r := 3.0 + 0.25 * float(k)
				var at2 := Vector3(c0.x + cos(a) * r, c0.y, c0.z + sin(a) * r)
				var g2 := _ground_at(at2, 90.0) if at2.y == 0.0 else _ground_at(at2, at2.y + 6.0)
				if g2 != Vector3.INF and WorldLanes.site_at(Vector2(g2.x, g2.z), 1.4).is_empty() and _clear_box(g2, Vector3(2.6, 2.6, 0.8)):
					spot = g2
					break
		if spot == Vector3.INF:
			push_warning("Encounters: no clear spot for a bell near %s" % cands[0])
			PlacementLog.skip("encounters", "bell_%d" % BELLS.find(cands), cands[0], "no clear spot for a bell")
			continue
		var b := Bell.new()
		b.director = self
		b.name = "DeeperBell"
		root.add_child(b)
		b.global_position = spot - Vector3.UP * 0.05
		bells.append(b)


## [E] on a post: returns the next page (the board turns pages; a stake shows its one notice).
func read_post(post: Node3D, page: int) -> int:
	var id := (post as Post).elite_id if post is Post else ""
	if id != "":
		_show_notice(id, post, "")
		return 0
	var ids := Elites.ids(ng())
	if page == 0:
		var lines := PackedStringArray()
		for e: String in ids:
			var d: Dictionary = Elites.ELITES[e]
			lines.append("%s  —  %s" % [Elites.title(e, ng() > 0), "ended" if slain(e) else "at large, " + String(d.where)])
		var claimed := (state.trophies as Dictionary).keys()
		var foot := "[%s] next notice" % Interactable.prompt_key()
		if not claimed.is_empty():
			var names := PackedStringArray()
			for c in claimed:
				names.append(String(Elites.LOOT.get(c, {}).get("name", c)))
			foot = "Kept for you at the Keg: " + ", ".join(names) + "\n" + foot
		hud.show_note("Bounties of the Kindled Keg" + ("  ·  the Deeper Night" if ng() > 0 else ""), "\n".join(lines), foot, post)
		return 1
	if page > ids.size():
		hud.close_note()
		return 0
	_show_notice(ids[page - 1], post, "notice %d of %d  ·  [%s] next" % [page, ids.size(), Interactable.prompt_key()])
	return page + 1


func _show_notice(id: String, post: Node3D, foot: String) -> void:
	var d: Dictionary = Elites.ELITES[id]
	var status := "ENDED" if slain(id) else "AT LARGE"
	var f := "%s  ·  %s  ·  %d grave ash%s" % [status, String(d.trait), int(d.ash) * (2 if ng() > 0 else 1), ("\n" + foot) if foot != "" else ""]
	hud.show_note(Elites.title(id, ng() > 0), String(d.note), f, post)


func bell_note(bell: Node3D, awake: bool) -> void:
	if not awake:
		hud.show_note("A silent bell", "Cracked iron on a black frame. It will not move. Above the Crowns the sky is still turning.", "", bell)
		return
	var fl: Variant = Travel.story.get("flags", {})
	var told: bool = fl is Dictionary and bool((fl as Dictionary).get("ending_told", false))
	hud.show_note("The Bell of the Deeper Night",
		"Cracked iron, hung mouth up. The keep told it to you plainly once: ring it top first, the way the Stair's bells stopped, and the door comes ajar. The three who hold the valley rise, their seals close, the hollowed come back harder. Your items, your fires, your journal and your story you keep. It is not a punishment. It is the valley asking whether you would walk it again. "
		+ ("He will not stop you. He will pour for you either way." if told
		else "Not yet: the keeper is pouring at the keg, and the last mug is his to give first. Then ring it."),
		"[%s] again to ring it" % Interactable.prompt_key() if told else "", bell)


## NG+: the bosses and seals reset (Travel progress for them only), the night deepens two tiers,
## elites come back Umbral. Items, relics, kindled fires, the journal and the story are kept.
## `reload`: carry the wanderer back to Hearthward and rebuild the world for it.
func begin_deeper_night(reload: bool) -> void:
	state["ng"] = ng() + 1
	state["slain"] = {}
	state["cycles"] = int(state.get("cycles", 0)) + 1
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	EnemySpawner._seal_kills.clear()
	# the story's side (r30): this cycle's ending is filed away (ending_seen_ng1 ...) so the next
	# Warden gets his own narration, last talk and card, and the keep greets the wrong-way bell
	if not Travel.story.has("flags"):
		Travel.story["flags"] = {}
	var fl: Dictionary = Travel.story.flags
	for k: String in ["ending_seen", "ending_told", "ending_card", "deeper_met"]:
		if fl.has(k):
			fl["%s_ng%d" % [k, ng()]] = true
			fl.erase(k)
	fl["deeper"] = true
	Travel.save_game()
	hud.set_deeper(ng())
	hud.close_note()
	hud.banner("THE DEEPER NIGHT", "The cracked bell rings top first. Something holds the door again.", Hud.COLD)
	if reload and _player and is_inside_tree():
		var path := get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		if path != "":
			await get_tree().create_timer(2.5).timeout
			if is_inside_tree() and get_tree().get_first_node_in_group(Groups.PLAYER) != null:   # re-found after the wait
				Travel.go(path, RealmLayout.PLAYER_START, RealmLayout.start_yaw(), get_tree().get_first_node_in_group(Groups.PLAYER))


func _on_boss(boss: Node, _title: String) -> void:
	if ng() <= 0 or not (boss is Enemy):
		return
	var e := boss as Enemy
	var mult := 1.0 + 0.3 * float(ng())
	e.max_hp = roundi(float(e.max_hp) * mult)
	e.hp = float(e.max_hp)
	e.strike_gloom *= 1.0 + 0.15 * float(ng())
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var arena := a as BossArena
		if arena._boss == e:
			var bar := arena._bar
			if bar != null:
				bar.max_value = float(e.max_hp)
				bar.value = e.hp


# --- spawning helpers ---------------------------------------------------------------------------

## How many more enemies may come near `pos` (CAP alive within CAP_R).
func room(pos: Vector3) -> int:
	return maxi(0, CAP - near_count(pos))


func near_count(pos: Vector3, r := CAP_R) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e is Enemy and (e as Enemy).is_alive() and (e as Node3D).global_position.distance_to(pos) < r:
			n += 1
	return n


## Ground a foe may appear on, for every spawner: out of the havens and the towns (SpawnRules.SAFE), in bounds, never
## on a way (nothing at all within HUB_ROAD_R of Hearthward's ways), never in water, lava or the Ossuary. on_way_ok: a
## procession may walk a way. Static and cheap (no physics): spot_ok adds the floor itself (slope, lips, rocks).
const HUB_ROAD_R := SpawnRules.HUB_ROADS_R


static func fair_ground(p: Vector3, on_way_ok := false) -> bool:
	var q := Vector2(p.x, p.z)
	if q.distance_to(HAVEN_C) < HAVEN_R or SpawnRules.safe_at(q) != "":
		return false
	if not RealmLayout.BOUNDS.grow(-4.0).has_point(q):
		return false
	var pd := RealmLayout.path_dist(q)
	if (q.distance_to(HAVEN_C) < HUB_ROAD_R and (pd < SpawnRules.HUB_BERTH or on_way_ok)) or (pd < SpawnRules.WAY_BERTH and not on_way_ok):
		return false
	if p.y < RealmLayout.LAVA_Y + 3.0 or RealmLayout.in_ossuary(p):
		return false
	var wl := RealmLayout.water_level_at(p.x, p.z)
	return not RealmLand.in_water(p.x, p.z) and (is_nan(wl) or p.y > wl + 0.15)


## A fair place for something of ours to stand now: fair ground (above), not in or near light, not in a building
## (a site), on a floor a body stands on (SpawnRules: no slope past ~39 degrees, no lip, no rock), not in a boss's ring.
func spot_ok(p: Vector3, ignore_light := false) -> bool:
	if not fair_ground(p):
		return false
	if not ignore_light and LightGrid.repel(p, 4.0) != Vector3.ZERO:
		return false
	if not WorldLanes.site_at(Vector2(p.x, p.z), 0.8).is_empty():
		return false
	if not SpawnRules.ok(_space, p):
		return false
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var r := (a as BossArena).radius + 4.0
		var c := (a as Node3D).global_position
		if Vector2(p.x - c.x, p.z - c.z).length() < r and absf(p.y - c.y) < 12.0:
			return false
	return true


## Open ground under xz (a ray from `from_y` down; walkable slope; a body fits). INF if none.
func _ground_at(p: Vector3, from_y: float) -> Vector3:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, from_y, p.z), Vector3(p.x, from_y - 140.0, p.z), Layers.WORLD)
	var hit := _space.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.72:
		return Vector3.INF
	var at: Vector3 = hit.position
	if _cap == null:
		_cap = CapsuleShape3D.new()
		_cap.radius = 0.4
		_cap.height = 1.7
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = _cap
	sq.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.95, 0))
	sq.collision_mask = Layers.WORLD
	if not _space.intersect_shape(sq, 1).is_empty():
		return Vector3.INF
	return at


func _clear_box(at: Vector3, size: Vector3) -> bool:
	var sq := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	sq.shape = bs
	sq.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, size.y * 0.5 + 0.25, 0))
	sq.collision_mask = Layers.WORLD | Layers.PROPS
	return _space.intersect_shape(sq, 1).is_empty()


func _ground_near(at: Vector3, r: float) -> Vector3:
	for rr: float in [r, r * 1.5, r * 2.2]:
		for k in 8:
			var a := float(k) * TAU / 8.0 + 0.4
			var g := _ground_at(at + Vector3(cos(a) * rr, 0, sin(a) * rr), at.y + 8.0)
			if g != Vector3.INF and spot_ok(g) and absf(g.y - at.y) < 3.0:
				return g
	return Vector3.INF


## The first clear, fair point near `c` (the point itself, then rings out to `reach` metres).
func _search(c: Vector2, reach: float, ignore_light := false) -> Vector3:
	var r := 0.0
	while r <= reach:
		var n := 1 if r == 0.0 else int(r * 1.5) + 6
		for k in n:
			var a := TAU * float(k) / float(n)
			var g := _ground_at(Vector3(c.x + cos(a) * r, 0, c.y + sin(a) * r), 90.0)
			if g != Vector3.INF and spot_ok(g, ignore_light):
				return g
		r += 3.0
	return Vector3.INF


func _make(kind: String, at: Vector3, tier: int, variant: String) -> Enemy:
	var e := Tiers.script_for(kind).new() as Enemy
	if e == null:
		return null
	if e is Pilgrim:
		(e as Pilgrim).dormant = false                 # r34: a Pilgrim the night sends is already up
	Tiers.scale_stats(e, tier)
	if variant != "":
		Variants.pre(e, variant)
	root.add_child(e)
	if variant != "":
		Variants.dress(e, variant)
	e.global_position = at + Vector3.UP * 0.05
	e.home = at
	SpellFx.rift_in(at)
	return e


## Take one of ours out of the world without a kill (no ash): it burns away into the dark.
func _unmake(e: Enemy, fx := true) -> void:
	if not is_instance_valid(e):
		return
	if fx:
		var at := e.global_position + Vector3.UP
		Vfx.burst(at, Color(0.04, 0.02, 0.06, 0.85), {"count": 18, "life": 1.0, "speed": Vector2(0.3, 1.2), "size": 0.3, "gravity": 0.8, "additive": false, "turbulence": true})
		SpellFx.rift_out(e.global_position)
	e.remove_from_group(Groups.ENEMY)
	e.queue_free()


func _prune(pos: Vector3) -> void:
	var keep: Array = []
	for e in ambushers:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if e.global_position.distance_to(pos) > 75.0:
			_unmake(e, false)
			continue
		keep.append(e)
	ambushers = keep
	var hk: Array = []
	for e in hunters:
		if is_instance_valid(e) and e.is_alive():
			hk.append(e)
	hunters = hk


func _make_motes() -> GPUParticles3D:
	var col := Color(0.45, 0.62, 1.0, 0.55) if ng() > 0 else Color(0.08, 0.05, 0.1, 0.7)
	var p := Vfx.emitter(col, {"count": 90, "life": 6.0, "size": 0.07, "radius": 14.0, "speed": Vector2(0.05, 0.35), "gravity": -0.15, "additive": ng() > 0, "turbulence": true})
	p.name = "TideMotes"
	p.visibility_aabb = AABB(Vector3(-20, -8, -20), Vector3(40, 20, 40))
	p.emitting = false
	return p
