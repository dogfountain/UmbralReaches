extends Node
## The dynamic score. ScapeMusic (the generative lyre, pads and bell) stays the night's melody; this layer is its orchestra and its
## memory. It reads what the night is doing and cross-fades stems (score_stems.gd) on its own "Score" bus under the Music bus:
##   explore   the act's bed (Hearthward's warm D minor; the peal's bells rising; Aurel's tritone and his count) at a whisper, and
##             now and then a motif: the region's (village, wood, fen, heights, crypt) or the act's bell motif
##   tension   a hostile thing within 45 m (a minor second beating, a thin tremolo), rising as it nears
##   combat    blows dealt or taken in the last five seconds: the war drum, then, as the exchange heats, the snares and the sixteenths
##   aftermath the last foe falls: a slow choir and one bell falling every five seconds for twenty-two seconds, the act's bed gone
##   rest      by a lit fire the act's bed comes up and nothing else plays
##   silence   after a great one falls, in the eclipse's totality, after being hollowed: every stem steps back and the Music bus is
##             ducked (mix_director.gd); silence is a thing the score does on purpose
## A boss's own theme (boss_themes.gd) takes the whole floor while it plays. Nothing here renders on the main thread; a stem not
## yet rendered is simply not played. `Settings.score_intensity` scales the bus. No class_name.

const Stems := preload("res://core/audio/score_stems.gd")
const Reg := preload("res://core/world/night_life/night_registry.gd")
const MixDirector := preload("res://core/audio/mix_director.gd")

const BUS := &"Score"
const DB := {"tension": -22.0, "combat_lo": -15.0, "combat_hi": -18.0, "aftermath": -20.0, "act1": -26.0, "act2": -26.0, "act3": -26.0,
	"hour_dusk": -28.0, "hour_late": -28.0, "hour_dawn": -27.0, "ending": -25.0}
const NEAR_FAR := 45.0
const NEAR_CLOSE := 14.0
const SCAPE_FAMILY := {"village": "village", "chapel": "village", "heath": "village", "tavern": "village", "fields": "village", "downs": "village", "moor": "village", "salt": "village",
	"wood": "wood", "ring": "wood", "holds": "wood", "orchard": "wood", "lanternwood": "wood", "southwood": "wood", "sorrow": "wood",
	"fen": "fen", "tally": "fen", "mere": "fen", "reedmere": "fen", "stillwater": "fen", "nave": "fen", "barrowheath": "fen",
	"crossing": "heights", "summit": "heights", "quarry": "heights", "foundry": "heights", "anchorholds": "heights", "fell": "heights", "cairns": "heights", "bellfall": "heights", "arches": "heights", "plinth": "heights", "siege": "heights", "well": "heights",
	"ossuary": "crypt", "necropolis": "crypt", "charnel": "crypt"}

var ambience: Ambience
var stage: Node
var tension := 0.0
var combat := 0.0
var hot := 0.0
var aftermath := 0.0
var rest := 0.0
var act := 1
var quiet_k := 1.0                  ## 1 the score plays .. 0 silence (eased)
var silence_until := 0              ## msec
var state := "explore"              ## for tests and the debug overlay

var _players := {}                  ## stem id -> AudioStreamPlayer
var _motif: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _hits: Array[int] = []          ## msec of each blow dealt or taken, last six seconds
var _near_d := 999.0
var _sense_t := 0.0
var _after_until := 0
var _was_fight := false
var _motif_t := 75.0
var _themes: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"score_director")
	_rng.seed = 6113
	_ensure_bus()
	Stems.warm()
	for id: String in Stems.LOOPS:
		var p := AudioStreamPlayer.new()
		p.name = "Stem_" + id
		p.bus = BUS
		p.volume_db = -80.0
		add_child(p)
		_players[id] = p
	_motif = AudioStreamPlayer.new()
	_motif.name = "Motif"
	_motif.bus = BUS
	_motif.volume_db = -17.0
	add_child(_motif)
	Events.combat_damage.connect(func(_t: Node, _a: float, _c: bool, _s: StringName, _at: Vector3) -> void: _hit())
	Events.player_hurt.connect(func(_a: float, _f: Vector3) -> void: _hit())
	Events.boss_slain.connect(func(_id: String) -> void: silence(7.0))
	Events.hollowed.connect(func() -> void: silence(6.0))
	_refresh_act()


func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players.values():
		if is_instance_valid(p):
			p.stop()
	Stems.release()


## The Score bus: a child of Music, so the Music slider and every Music duck reach it, with its own slider (score_intensity).
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master")
	var v := float(Settings.get("score_intensity")) if Settings.get("score_intensity") != null else 0.8
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)


## Step every stem back for `sec` seconds (eased) and duck the Music bus under it.
func silence(sec: float) -> void:
	silence_until = maxi(silence_until, Time.get_ticks_msec() + int(sec * 1000.0))
	var md := get_tree().get_first_node_in_group(&"mix_director") as MixDirector if is_inside_tree() else null
	if md != null:
		md.duck_music(-14.0, sec, 1.2)


func _hit() -> void:
	_hits.append(Time.get_ticks_msec())


func _refresh_act() -> void:
	var f: Variant = Travel.story.get("flags", {})
	if f is Dictionary and bool((f as Dictionary).get("ending_seen", false)):
		act = 0                                   # the door is shut: the ending's bed replaces the acts'
		return
	var n := 0
	for id: String in ["thornwarden", "bone_abbot", "ascended_warden"]:
		if Travel.bosses_slain.has(id):
			n += 1
	act = clampi(n + 1, 1, 3)


func _theme_playing() -> bool:
	if _themes == null or not is_instance_valid(_themes):
		_themes = get_tree().get_first_node_in_group(&"boss_themes")
	return _themes != null and float(_themes.get("theme_k")) > 0.15


func _process(dt: float) -> void:
	var now := Time.get_ticks_msec()
	_sense_t -= dt
	if _sense_t <= 0.0:
		_sense_t = 1.0
		_sense(now)
	while not _hits.is_empty() and now - _hits[0] > 6000:
		_hits.pop_front()
	var fight: bool = not _hits.is_empty() and now - int(_hits.back()) < 5000
	var heat := clampf(float(_hits.size()) / 9.0, 0.0, 1.0)
	var themed := _theme_playing()
	var quiet := now < silence_until or themed
	if _was_fight and not fight and _near_d > 22.0 and not themed:
		_after_until = now + 22000
	_was_fight = fight
	var restful := ambience != null and ambience.music != null and String(ambience.music.get("state")) == "rest"
	quiet_k = move_toward(quiet_k, 0.0 if now < silence_until else 1.0, dt / (1.5 if now < silence_until else 4.0))
	var tens_t := clampf((NEAR_FAR - _near_d) / (NEAR_FAR - NEAR_CLOSE), 0.0, 1.0)
	tension = move_toward(tension, 0.0 if (quiet or restful or fight) else tens_t, dt / (2.5 if tens_t > tension else 5.0))
	combat = move_toward(combat, 0.0 if themed or now < silence_until else (1.0 if fight else 0.0), dt / (1.0 if fight else 5.0))
	hot = move_toward(hot, heat if fight and not themed else 0.0, dt / 2.0)
	aftermath = move_toward(aftermath, 1.0 if now < _after_until and not fight and not quiet else 0.0, dt / 3.0)
	rest = move_toward(rest, 1.0 if restful and not quiet else 0.0, dt / 4.0)
	state = "boss" if themed else ("combat" if combat > 0.3 else ("tension" if tension > 0.3 else ("aftermath" if aftermath > 0.3 else ("rest" if rest > 0.5 else "explore"))))
	var bed := (1.0 - combat) * (1.0 - tension * 0.6) * (1.0 - aftermath) * quiet_k * (0.0 if themed else 1.0)
	_level("tension", tension * quiet_k)
	_level("combat_lo", combat * quiet_k)
	_level("combat_hi", hot * combat * quiet_k)
	_level("aftermath", aftermath * quiet_k)
	var c := Reg.clock
	var dusk := 1.0 - smoothstep(0.1, 0.3, c)
	var late := smoothstep(0.5, 0.62, c) * (1.0 - smoothstep(0.84, 0.92, c))
	var dawn := smoothstep(0.88, 0.97, c)
	var hour := maxf(dusk, maxf(late, dawn))
	_level("hour_dusk", bed * dusk)
	_level("hour_late", bed * late)
	_level("hour_dawn", bed * dawn)
	for a in 3:
		var id := "act%d" % (a + 1)
		_level(id, bed * (1.0 + rest * 0.5) * (1.0 - 0.5 * hour) if act == a + 1 else 0.0)
	_level("ending", bed * (1.0 + rest * 0.5) if act == 0 else 0.0)
	_motifs(dt, now, quiet)


func _level(id: String, k: float) -> void:
	var p: AudioStreamPlayer = _players[id]
	if k <= 0.012:
		if p.playing:
			p.stop()
		return
	if p.stream == null:
		var s := Stems.stream(id)
		if s == null:
			return
		p.stream = s
	p.volume_db = float(DB[id]) + linear_to_db(k)
	if not p.playing:
		p.play(_rng.randf() * p.stream.get_length())


## The nearest awake hostile, and the act (after a fight or a boss the act may have turned).
func _sense(now: int) -> void:
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if pl == null:
		return
	var p := pl.global_position
	var best := 999.0
	for e: Node in get_tree().get_nodes_in_group(Groups.ENEMY):
		var n3 := e as Node3D
		if n3 == null or not n3.is_inside_tree() or not n3.can_process() or n3.is_queued_for_deletion():
			continue
		best = minf(best, n3.global_position.distance_to(p))
	_near_d = best
	if now % 5000 < 600:
		_refresh_act()


func _family() -> String:
	var sc := ambience.scape if ambience != null else "village"
	return String(SCAPE_FAMILY.get(sc, "village"))


func _motifs(dt: float, _now: int, quiet: bool) -> void:
	if quiet or tension > 0.15 or combat > 0.05 or aftermath > 0.1 or _motif.playing:
		return
	_motif_t -= dt
	if _motif_t > 0.0:
		return
	_motif_t = _rng.randf_range(70.0, 120.0)
	var id := "motif_" + _family() if (_rng.randf() < 0.55 or act == 0) else "motif_act%d" % act
	var s := Stems.stream(id)
	if s == null:
		return
	_motif.stream = s
	_motif.play()
