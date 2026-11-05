extends Node3D
## r33 world: world events (WoW's public events / world quests, in our own night). Now and then the
## Gloom wells up at one of the valley's places: a violet shaft stands over it (seen from across the
## valley, drawn inside the far plane like the landmark beacons), the map marks it, the carved banner
## and a toast call it. Go there within CALL_FOR seconds and the surge breaks open: WAVES waves of
## tide-born hollowed climb out of the ground round it; kill them all and the surge is broken (the
## shaft collapses, ash and sometimes a relic fragment). Walk away (LEAVE_R) or be hollowed and it
## is lost; ignore it and it fades. Never during a boss fight or the Gloom tide, never in Hearthward.
##
## Sites: the r31 places (group "world_poi") plus the chapel and the barrows; chosen 30-150 m from the
## wanderer. Timing: the first one FIRST seconds into the night, then every EVERY.
## Hooks for other systems (connect, do not call in):
##   Events.world_event(id, phase, at)   phase "warn" (called), "start" (the wanderer came), "wave" (a
##                                        wave rose), "won" (reward hook: XP/loot agents give here),
##                                        "lost", "faded". id = "surge_<site>".
## State: Travel.system_state("world_events") = {won: int, sites: {site: wins}}.
## Tests/debug: start_event(site_id), arrive(), win_now(). Load by path (no class_name).

const Tiers := preload("res://core/life/encounters/tiers.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")

const FIRST := Vector2(200.0, 320.0)
const EVERY := Vector2(420.0, 660.0)
const CALL_FOR := 180.0
const ARRIVE_R := 15.0
const LEAVE_R := 46.0
const WAVES := 3
const WAVE_GAP := 32.0                  ## a wave comes anyway after this long
const HAVEN_C := Vector2(4.0, 36.0)     ## encounters' haven: no events in Hearthward
const HAVEN_R := 40.0
const SURGE := Color(0.62, 0.42, 1.0)
const SID := "world_events"
const REWARD_ASH := 24
## Extra sites (the POIs join from their group): id -> [xz, name]
const EXTRA_SITES := {"chapel": [Vector2(-72.0, 52.0), "the Chapel of the First Kindling"], "barrows": [Vector2(78.0, -42.0), "the Barrow Field"]}

var phase := "idle"                     ## idle, warn, active
var site := ""
var site_name := ""
var at := Vector3.ZERO
var wave := 0
var foes: Array = []                    ## Enemy (may hold freed ones until pruned)
var clock := 0.0                        ## seconds until the next event (idle) / left to answer (warn)
var events_run := 0                     ## tests
var auto := true                        ## tests switch the timer off
var _t := 0.0
var _wave_t := 0.0
var _pillar: Node3D
var _motes: GPUParticles3D
var _light: OmniLight3D
var _marker: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "WorldEvents"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	clock = _rng.randf_range(FIRST.x, FIRST.y)
	Events.enemy_killed.connect(_on_killed)
	Events.hollowed.connect(func() -> void:
		if phase == "active":
			_end("lost"))


## Every place a surge can rise: [{id, name, at (Vector3 on the ground)}].
func sites() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	for n in get_tree().get_nodes_in_group("world_poi"):
		if n.has_meta("centre"):
			out.append({"id": String(n.get_meta("poi")), "name": String(n.get_meta("title")), "at": n.get_meta("centre")})
	for id: String in EXTRA_SITES:
		var xz: Vector2 = EXTRA_SITES[id][0]
		out.append({"id": id, "name": String(EXTRA_SITES[id][1]), "at": Vector3(xz.x, RealmLayout.ground(space, xz.x, xz.y), xz.y)})
	return out


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return
	var pp := p.global_position
	match phase:
		"idle":
			if not auto:
				return
			clock -= 0.5
			if clock <= 0.0:
				if _quiet_time():
					_pick_and_start(pp)
				else:
					clock = 30.0
		"warn":
			clock -= 0.5
			if _flat(pp, at) < ARRIVE_R:
				arrive()
			elif clock <= 0.0:
				_end("faded")
		"active":
			_prune()
			if _flat(pp, at) > LEAVE_R:
				_end("lost")
				return
			_wave_t -= 0.5
			if foes.is_empty() or (_wave_t <= 0.0 and wave < WAVES):
				if wave >= WAVES:
					_end("won")
				else:
					_spawn_wave()


func _quiet_time() -> bool:
	if Player.boss_fight_active(get_tree()):
		return false
	var enc := get_parent().get_node_or_null("Encounters") if get_parent() else null
	if enc and bool(enc.get("tide_on")):
		return false
	return get_tree().get_first_node_in_group("fire_flight") == null


func _pick_and_start(pp: Vector3) -> void:
	var cands: Array[Dictionary] = []
	for s in sites():
		var d := _flat(pp, s.at)
		if d > 30.0 and d < 150.0 and Vector2(s.at.x, s.at.z).distance_to(HAVEN_C) > HAVEN_R:
			cands.append(s)
	if cands.is_empty():
		clock = 60.0
		return
	var s: Dictionary = cands[_rng.randi() % cands.size()]
	start_event(String(s.id))


## Call a surge at `site_id` now (any phase but active). Returns false if there is no such place.
func start_event(site_id: String) -> bool:
	if phase == "active":
		return false
	_clear_fx()
	for s in sites():
		if String(s.id) == site_id:
			site = site_id
			site_name = String(s.name)
			at = s.at
			phase = "warn"
			clock = CALL_FOR
			wave = 0
			foes.clear()
			events_run += 1
			_make_fx()
			Events.world_event.emit(event_id(), "warn", at)
			Events.toast.emit("The Gloom is welling up at %s. Go, and break it before it spills." % _bare(site_name))
			_banner("Gloom Surge", "at %s" % _bare(site_name))
			return true
	return false


func event_id() -> String:
	return "surge_" + site


## The wanderer reached the surge: it breaks open (tests call it directly).
func arrive() -> void:
	if phase != "warn":
		return
	phase = "active"
	Events.world_event.emit(event_id(), "start", at)
	Events.toast.emit("The surge breaks open. Hold the ground until it is spent.")
	_spawn_wave()


## Tests: end the surge as if every wave had fallen.
func win_now() -> void:
	if phase == "idle":
		return
	for e in foes:
		if is_instance_valid(e):
			(e as Node).remove_from_group(Groups.ENEMY)
			(e as Node).queue_free()
	foes.clear()
	wave = WAVES
	_end("won")


func _spawn_wave() -> void:
	wave += 1
	_wave_t = WAVE_GAP
	var tier := clampi(Tiers.tier_at(at) + 1, 0, Tiers.TIERS.size() - 1)
	var want := 1 + wave + (1 if tier >= 3 else 0)
	var enc := get_parent().get_node_or_null("Encounters") if get_parent() else null
	if enc and enc.has_method("room"):
		want = mini(want, maxi(1, int(enc.call("room", at))))
	var pool: Array = Tiers.REGION_POOL.get(Tiers.region_id(at), ["wretch", "crawler"])
	var base := _rng.randf() * TAU
	var made := 0
	var space := get_world_3d().direct_space_state
	for i in want * 6:
		if made >= want:
			break
		var a := base + TAU * float(i) / float(maxi(want, 1)) + _rng.randf_range(-0.4, 0.4)
		var d := _rng.randf_range(9.0, 15.0) + float(i / (want * 2)) * 3.0
		var q := at + Vector3(cos(a) * d, 0.0, sin(a) * d)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3.UP * 25.0, q + Vector3.DOWN * 25.0, Layers.WORLD))
		if hit.is_empty() or (hit.normal as Vector3).y < 0.75:
			continue
		var spot: Vector3 = hit.position
		if enc and enc.has_method("spot_ok") and not bool(enc.call("spot_ok", spot, true)) and i < want * 4:
			continue
		var e := _make(String(pool[(made + wave) % pool.size()]), spot, tier)
		if e:
			foes.append(e)
			made += 1
	if _pillar:
		var k := 1.0 - 0.22 * float(wave)
		create_tween().tween_property(_pillar, "scale", Vector3(k, 1.0, k), 0.8)
	Events.world_event.emit(event_id(), "wave", at)


func _make(kind: String, spot: Vector3, tier: int) -> Enemy:
	var scr := Tiers.script_for(kind)
	if scr == null:
		return null
	var e := scr.new() as Enemy
	if e == null:
		return null
	Tiers.scale_stats(e, tier)
	Variants.pre(e, "tideborn")
	get_parent().add_child(e)
	Variants.dress(e, "tideborn")
	e.global_position = spot + Vector3.UP * 0.05
	e.home = at
	e.set("chase_range", 40.0)
	e.set("hunt_leash", 60.0)
	e.set("sleep_range", 90.0)
	e.set_meta(&"world_event", event_id())
	SpellFx.rift_in(spot)
	return e


func _on_killed(e: Node) -> void:
	if phase == "active" and foes.has(e):
		foes.erase(e)


func _prune() -> void:
	var keep: Array = []
	for e in foes:
		if is_instance_valid(e) and not (e as Node).is_queued_for_deletion() and (e as Enemy).is_alive():
			keep.append(e)
	foes = keep


func _end(how: String) -> void:
	var was := site_name
	var id := event_id()
	phase = "idle"
	clock = _rng.randf_range(EVERY.x, EVERY.y)
	match how:
		"won":
			var st := Travel.system_state(SID)
			st["won"] = int(st.get("won", 0)) + 1
			if not (st.get("sites") is Dictionary):
				st["sites"] = {}
			(st.sites as Dictionary)[site] = int((st.sites as Dictionary).get(site, 0)) + 1
			Travel.give("grave_ash", REWARD_ASH, false)
			var extra := ""
			if _rng.randf() < 0.5:
				Travel.give("relic_fragment", 1, false)
				extra = " and a relic fragment"
			Travel.save_soon()
			Vfx.burst(at + Vector3.UP * 1.5, Color(2.4, 1.6, 3.2), {"count": 60, "life": 1.4, "speed": Vector2(1.0, 4.0), "size": 0.1, "gravity": -1.0, "spread": 180.0, "turbulence": true})
			Events.toast.emit("The surge is broken. You gather %d grave ash%s from where it rose." % [REWARD_ASH, extra])
			_banner("Surge Broken", "the ground at %s is quiet again" % _bare(was))
		"lost":
			for e in foes:
				if is_instance_valid(e):
					(e as Enemy).set("hunt_leash", 14.0)
			Events.toast.emit("The surge at %s spills into the night." % _bare(was))
		"faded":
			Events.toast.emit("The Gloom at %s sinks back into the ground, unbroken." % _bare(was))
	Events.world_event.emit(id, how, at)
	foes.clear()
	_clear_fx()


func _banner(title: String, line: String) -> void:
	var d := get_parent().get_node_or_null("Discovery") if get_parent() else null
	var b: Variant = d.get("banner") if d else null
	if b is Node:
		(b as Node).call("show_event", title, line)


## "The Drowned Belfry" -> "the Drowned Belfry" (inside a sentence).
static func _bare(n: String) -> String:
	return "the " + n.substr(4) if n.begins_with("The ") else n


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _make_fx() -> void:
	_pillar = Wayfinding.beacon(self, at, "", Color(1.6, 0.6, 2.3), 60.0, 1.3, 2.0)   # HDR: it blooms, read across the valley
	if _pillar:
		_pillar.name = "SurgePillar"
	_motes = Vfx.emitter(Color(1.4, 0.9, 2.6), {"count": 60, "life": 2.6, "speed": Vector2(0.5, 1.8), "size": 0.08, "gravity": 0.9,
		"spread": 30.0, "dir": Vector3.UP, "radius": 2.2, "turbulence": true})
	add_child(_motes)
	_motes.global_position = at + Vector3.UP * 0.3
	_motes.emitting = true
	_light = OmniLight3D.new()
	_light.light_color = SURGE
	_light.light_energy = 2.5
	_light.omni_range = 12.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.global_position = at + Vector3.UP * 2.5
	# the map: a marker the minimap draws (r33 contract)
	_marker = Node3D.new()
	_marker.name = "SurgeMarker"
	_marker.add_to_group(&"map_marker")
	_marker.set_meta(&"map_kind", "quest_target")
	_marker.set_meta(&"map_label", "Gloom Surge")
	_marker.set_meta(&"map_color", SURGE)
	add_child(_marker)
	_marker.global_position = at


func _clear_fx() -> void:
	for n: Node in [_pillar, _motes, _light, _marker]:
		if n and is_instance_valid(n):
			n.queue_free()
	_pillar = null
	_motes = null
	_light = null
	_marker = null
