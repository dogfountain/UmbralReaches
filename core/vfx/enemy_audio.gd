class_name EnemyAudio
extends RefCounted
## What the dark's creatures sound like and how it is mixed.
##
## The takes are rendered by tools/gen_enemy_sfx.py (core/vfx/enemy_bank.gd lists them): per voice set
## (hollow, husk, crawler, shade, the seven great ones ...) idle / alert / windup / attack / hurt /
## stagger / die / flee (bosses: phase), 2-4 takes of each; footsteps by body type and ground; the hit
## materials (flesh, bone, chitin, stone, wood, ether); the wanderer's own parry, block and dodge.
##   say(set, act, at, owner, db, pitch, boss)   one voice, with picking, cooldowns, a cap and priorities
##   step(body, ground, at, owner, db, pitch)    a footfall
##   hit(material, at, dmg)                       what a blow sounds like landing on that body
##   kit(kind) / player(kind)                     a shared take (roar, block ...) / the wanderer's, round-robin
##
## Mix rules, so a big fight stays readable (the dark is the clock; sound makes the night tense, not loud):
##   - a take never plays twice in a row for its set and act; pitch and level drift a little every time
##   - one enemy may not repeat an act before OWNER_GAP, and a voice set not before SET_GAP (a pack never
##     speaks in unison); idle murmurs are capped at MAX_IDLE at once and are dropped far away
##   - a pool of POOL voices: when it is full the new sound takes the lowest-scored one only if it scores
##     higher (score = act priority + boss bonus - distance): a wind-up or a boss always wins, a far murmur never does
##   - 3D voices on the Voices bus (a gentle compressor, then SFX, so the room reverb is theirs too), a
##     distance low-pass so the far ones are muffled, panning that reads in headphones, no doppler
## Nothing runs per frame; nothing is built at runtime but the players; streams load on first use.

const Bank := preload("res://core/vfx/enemy_bank.gd")
const Land := preload("res://core/world/realm/realm_land.gd")

const POOL := 14
const STEP_POOL := 8
const MAX_IDLE := 2
const VOICES_BUS := &"Voices"
const TRIM_DB := 2.0                       ## the takes are RMS-matched around -19 dBFS; the call sites were tuned for hotter synth
const ALIAS := {"tell": "windup", "call": "alert"}
const PRIORITY := {"phase": 7, "windup": 6, "attack": 5, "die": 5, "stagger": 5, "alert": 4, "hurt": 3, "flee": 2, "idle": 0}
const OWNER_GAP := {"idle": 3.0, "alert": 2.0, "windup": 0.15, "attack": 0.1, "hurt": 0.6, "stagger": 0.6, "die": 0.0, "flee": 1.2, "phase": 0.0}
const SET_GAP := {"idle": 0.5, "alert": 0.35, "windup": 0.08, "attack": 0.06, "hurt": 0.09, "stagger": 0.2, "die": 0.05, "flee": 0.4, "phase": 0.0}
## a voice this far from the listener (idle only) is not worth a voice
const IDLE_RANGE := 26.0
const STEP_RANGE := 20.0
## how a body of each voice set walks (enemy.gd step_body() overrides per kind)
const BODY := {"hollow": "bare", "gaunt": "shuffling", "husk": "heavy", "bulwark": "heavy", "gurgle": "bare", "leaper": "bare",
	"chanter": "shuffling", "tollman": "heavy", "quiller": "bony", "ossuant": "bony", "crawler": "skittering", "burrower": "chitin",
	"shade": "", "cinder": "shuffling", "thorn": "heavy", "abbot": "bony", "warden": "heavy", "brood": "chitin",
	"reliquary": "bony", "anchoress": "shuffling", "hierarch": "heavy"}
const SURF_MAP := {&"grass": "grass", &"fen": "water", &"water": "water", &"ash": "grass", &"stone": "stone", &"wood": "wood", &"salt": "stone"}

static var _streams := {}                  ## path -> AudioStream
static var _last := {}                     ## "set/act" -> index of the take played last
static var _voices: Array[AudioStreamPlayer3D] = []
static var _meta: Array = []               ## per voice: [started msec, score, act]
static var _steps: Array[AudioStreamPlayer3D] = []
static var _step_started := PackedInt64Array()
static var _owner_t := {}                  ## "owner/act" -> msec it may speak again
static var _set_t := {}                    ## "set/act" -> msec
static var _surf_cache := {}               ## owner id -> [msec, surface]
static var voices_played := 0              ## tests and --sfx-trace
static var voices_dropped := 0


static func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


## A take index for (key, count) that is not the one played last.
static func _pick(key: String, count: int) -> int:
	if count <= 1:
		return 0
	var i := randi() % count
	if i == int(_last.get(key, -1)):
		i = (i + 1 + randi() % (count - 1)) % count
	_last[key] = i
	return i


static func _cam_pos(tree: SceneTree) -> Vector3:
	var cam := tree.root.get_camera_3d()
	return cam.global_position if cam != null else Vector3.INF


## One creature voice. `act`: idle, alert (call), windup (tell), attack, hurt, stagger, die, flee, phase.
## Returns true when a take was started (false: unknown set, on cooldown, too far, or out-prioritised).
static func say(voice_set: String, act: String, at: Vector3, owner_id: int, db := 0.0, pitch := 1.0, boss := false) -> bool:
	act = String(ALIAS.get(act, act))
	var acts: Dictionary = Bank.SETS.get(voice_set, {})
	var count := int(acts.get(act, 0))
	if count <= 0 or not at.is_finite():
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null or not tree.current_scene.is_inside_tree():
		return false
	var now := Time.get_ticks_msec()
	var okey := "%d/%s" % [owner_id, act]
	if now < int(_owner_t.get(okey, 0)):
		return false
	pitch = pow(maxf(pitch, 0.1), 0.35)         # a size factor from the call site, eased: the takes carry their own pitch
	var skey := voice_set + "/" + act
	if now < int(_set_t.get(skey, 0)):
		return false
	var cam := _cam_pos(tree)
	var dist := cam.distance_to(at) if cam.is_finite() else 0.0
	var reach := 70.0 if boss else 40.0
	if dist > reach or (act == "idle" and dist > IDLE_RANGE):
		return false
	var score := float(PRIORITY.get(act, 1)) * 10.0 + (30.0 if boss else 0.0) - dist * 0.5
	var slot := _slot(tree.current_scene, now, score, act)
	if slot < 0:
		voices_dropped += 1
		return false
	_owner_t[okey] = now + int(float(OWNER_GAP.get(act, 0.2)) * 1000.0 * randf_range(0.85, 1.4))
	_set_t[skey] = now + int(float(SET_GAP.get(act, 0.1)) * 1000.0)
	if _owner_t.size() > 512:
		_owner_t.clear()
	var s := _load("res://art/audio/enemy/%s/%s_%d.wav" % [voice_set, act, _pick(skey, count)])
	if s == null:
		return false
	var p := _voices[slot]
	p.stream = s
	p.pitch_scale = maxf(pitch * randf_range(0.9, 1.1), 0.2)
	p.unit_size = 10.0 if boss else 5.5
	p.max_distance = reach
	p.attenuation_filter_cutoff_hz = 6800.0 if boss else 4800.0
	p.global_position = at
	_meta[slot] = [now, score, act]
	_rise(p, db + TRIM_DB + randf_range(-1.2, 0.6))
	p.play()
	voices_played += 1
	return true


## A pool slot for a sound of this score: a free one, else the lowest-scored busy one if it scores lower than
## the newcomer. -1 = drop the newcomer.
static func _slot(host: Node, now: int, score: float, act: String) -> int:
	if not _voices.is_empty():
		for v in _voices:
			if not is_instance_valid(v) or v.get_parent() != host:
				_forget(host)
				break
	while _voices.size() < POOL:
		var p := AudioStreamPlayer3D.new()
		p.name = "EnemyVoice%d" % _voices.size()
		p.bus = VOICES_BUS if AudioServer.get_bus_index(VOICES_BUS) >= 0 else &"SFX"
		p.max_db = 6.0
		p.panning_strength = 1.2
		p.attenuation_filter_db = -20.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.area_mask = 0                             # no Area3D in the game overrides a bus or adds reverb: no area lookup each tick it plays
		host.add_child(p)
		_voices.append(p)
		_meta.append([0, -1000.0, ""])
	var idles := 0
	var worst := -1
	var worst_score := 1.0e9
	for i in POOL:
		var busy := _voices[i].playing
		if not busy:
			return i
		if String((_meta[i] as Array)[2]) == "idle":
			idles += 1
		var sc := float((_meta[i] as Array)[1])
		if sc < worst_score or (sc == worst_score and int((_meta[i] as Array)[0]) < int((_meta[worst] as Array)[0])):
			worst_score = sc
			worst = i
	if act == "idle" and idles >= MAX_IDLE:
		return -1
	return worst if score > worst_score else -1


static func _forget(host: Node) -> void:
	for v in _voices:
		if is_instance_valid(v) and v.get_parent() == host:
			v.queue_free()
	_voices.clear()
	_meta.clear()
	for v in _steps:
		if is_instance_valid(v) and v.get_parent() == host:
			v.queue_free()
	_steps.clear()
	_step_started.clear()


## A footfall. `body`: bare / bony / chitin / heavy / shuffling / skittering. `surface` is the Player's
## ground vocabulary (grass, fen, water, ash, stone, wood, salt).
static func step(body: String, surface: StringName, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	if body == "" or not at.is_finite():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null or not tree.current_scene.is_inside_tree():
		return
	var cam := _cam_pos(tree)
	if cam.is_finite() and cam.distance_squared_to(at) > STEP_RANGE * STEP_RANGE:
		return
	var surf := String(SURF_MAP.get(surface, "grass"))
	var takes: Dictionary = Bank.STEPS.get(body, {})
	var count := int(takes.get(surf, 0))
	if count <= 0:
		return
	var host := tree.current_scene
	while _steps.size() < STEP_POOL:
		var p := AudioStreamPlayer3D.new()
		p.name = "EnemyStep%d" % _steps.size()
		p.bus = VOICES_BUS if AudioServer.get_bus_index(VOICES_BUS) >= 0 else &"SFX"
		p.unit_size = 3.2
		p.max_distance = STEP_RANGE
		p.max_db = 3.0
		p.panning_strength = 1.2
		p.attenuation_filter_cutoff_hz = 3600.0
		p.attenuation_filter_db = -22.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		p.area_mask = 0                             # no Area3D in the game overrides a bus or adds reverb: no area lookup each tick it plays
		host.add_child(p)
		_steps.append(p)
		_step_started.append(0)
	var now := Time.get_ticks_msec()
	var slot := 0
	var oldest := now + 1
	for i in STEP_POOL:
		if not is_instance_valid(_steps[i]) or _steps[i].get_parent() != host:
			_forget(host)
			return
		if not _steps[i].playing:
			slot = i
			break
		if _step_started[i] < oldest:
			oldest = _step_started[i]
			slot = i
	var s := _load("res://art/audio/enemy/step/%s_%s_%d.wav" % [body, surf, _pick("step/%s/%s" % [body, surf], count)])
	if s == null:
		return
	var pl := _steps[slot]
	pl.stream = s
	pl.pitch_scale = pitch * randf_range(0.9, 1.1)
	pl.global_position = at
	_step_started[slot] = now
	_rise(pl, db + randf_range(-1.2, 0.6))
	pl.play()


## Footfalls for a CharacterBody3D that walks: call every physics frame with the metres walked so far; returns the new
## count. Stride and loudness follow the body type; nothing when it is far, airborne, or glides (a body type of "").
static func walk(e: CharacterBody3D, voice_set: String, stride: float, delta: float, dist: float, boss := false) -> float:
	var body := String(BODY.get(voice_set, "bare"))
	if body == "" or dist > STEP_RANGE or not e.is_on_floor():
		return stride
	var sp := Vector2(e.velocity.x, e.velocity.z).length()
	if sp < 0.7:
		return stride
	stride += sp * delta
	var len_m: float = float({"bare": 1.05, "bony": 0.9, "chitin": 0.7, "heavy": 1.7, "shuffling": 0.8, "skittering": 0.5}.get(body, 1.0)) * (1.4 if boss else 1.0)
	if stride < len_m:
		return stride
	step(body, surface_at(e), e.global_position, 2.0 if boss else -2.0 + clampf(sp - 3.0, 0.0, 3.0) * 0.8, 0.85 if boss else 1.0)
	return fmod(stride, len_m)


## What the ground under a creature is (the Player's vocabulary), cached 0.5 s per creature.
static func surface_at(node: Node3D) -> StringName:
	var now := Time.get_ticks_msec()
	var id := node.get_instance_id()
	var c: Variant = _surf_cache.get(id)
	if c != null and now - int((c as Array)[0]) < 500:
		return (c as Array)[1]
	var gp := node.global_position
	var surf: StringName = &"grass"
	var space := node.get_world_3d().direct_space_state if node.is_inside_tree() else null
	var hit := {}
	if space != null:
		var from := gp + Vector3.UP * 0.4
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.2, Layers.WORLD | Layers.PROPS))
	var on_terrain := hit.is_empty() or (hit.collider is Node and String((hit.collider as Node).name).begins_with("Terrain"))
	if on_terrain:
		if Land.in_water(gp.x, gp.z):
			surf = &"water"
		else:
			var biome := RealmLayout.biome_at(gp.x, gp.z)
			surf = &"fen" if biome == "fen" else (&"ash" if biome == "ash" else (&"salt" if biome == "salt" else &"grass"))
	else:
		var nm := String((hit.collider as Node).name).to_lower() if hit.collider is Node else ""
		surf = &"wood" if (nm.contains("board") or nm.contains("deck") or nm.contains("floor") or nm.contains("dock") or nm.contains("bridge")) else &"stone"
	if _surf_cache.size() > 256:
		_surf_cache.clear()
	_surf_cache[id] = [now, surf]
	return surf


## A blow landing on a body of this material ("flesh", "bone", "chitin", "stone", "wood", "ether"); heavy blows
## (dmg >= 3) get the heavy takes. Plays through the shared pool (stacked hits are turned down by Sfx).
static func hit(material: String, at: Vector3, dmg: float, db := 0.0) -> bool:
	var spec: Variant = Bank.HITS.get(material)
	if spec == null:
		return false
	var heavy := dmg >= 3.0 and int((spec as Array)[1]) > 0
	var count := int((spec as Array)[1]) if heavy else int((spec as Array)[0])
	var key := "hit/%s/%s" % [material, heavy]
	var path := "res://art/audio/kit/hit_%s%s_%d.wav" % [material, "_heavy" if heavy else "", _pick(key, count)]
	var s := _load(path)
	if s == null:
		return false
	Sfx.play_stream(s, at, db - 1.0 + minf(dmg, 4.0) * 0.8, 1.08 - minf(dmg, 4.0) * 0.05, 0.05)
	return true


## A shared take by kind, round-robin without immediate repeats: "roar", "stagger", "block", "spike", "burrow", "chant".
static func kit(kind: String) -> AudioStream:
	var count := int(Bank.KIT.get(kind, 0))
	if count <= 0:
		return null
	return _load("res://art/audio/kit/%s_%d.wav" % [kind, _pick("kit/" + kind, count)])


## One of the wanderer's own combat takes: "hurt", "dodge", "parry", "block", "thwack".
static func player(kind: String, at: Vector3, db := 0.0, pitch := 1.0) -> bool:
	var count := int(Bank.PLAYER.get(kind, 0))
	if count <= 0:
		return false
	var s := _load("res://art/audio/player/%s_%d.wav" % [kind, _pick("player/" + kind, count)])
	if s == null:
		return false
	Sfx.play_stream(s, at, db, pitch, 0.04)
	return true


## Per-creature state for idle breaths and footfalls (one per Enemy; tick it every physics frame).
class Voicebox extends RefCounted:
	var idle_t := randf_range(1.5, 9.0)       ## seconds to its next breath or murmur
	var stride := 0.0                          ## metres walked since the last footfall

	func tick(e: CharacterBody3D, voice_set: String, delta: float, dist: float, boss: bool, idling: bool, size: float) -> void:
		idle_t -= delta
		if idle_t <= 0.0:
			idle_t = randf_range(7.0, 15.0) if boss else randf_range(4.5, 11.0)
			if idling and dist < IDLE_RANGE:
				EnemyAudio.say(voice_set, "idle", e.global_position + Vector3.UP * 1.2, e.get_instance_id(), -2.0, size, boss)
		stride = EnemyAudio.walk(e, voice_set, stride, delta, dist, boss)


## The scene is leaving the tree: let the streams and players go before the audio server does.
static func _rise(p: AudioStreamPlayer3D, db: float) -> void:
	var old: Variant = p.get_meta(&"rise") if p.has_meta(&"rise") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	p.volume_db = db - 7.0
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", db, 0.016).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	p.set_meta(&"rise", tw)


static func release() -> void:
	for v in _voices:
		if is_instance_valid(v):
			v.stop()
	for v in _steps:
		if is_instance_valid(v):
			v.stop()
	_voices.clear()
	_meta.clear()
	_steps.clear()
	_step_started.clear()
	_streams.clear()
	_last.clear()
	_owner_t.clear()
	_set_t.clear()
	_surf_cache.clear()
