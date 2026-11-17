extends Node
## The mix. One node (group "mix_director") that owns what the buses do over time, on top of the layout Ambience builds
## (reverb zones, the master compressor and limiter, the voices compressor, the indoor low-pass):
##   buses    "UI" (every interface cue, its own slider) and "Score" (the dynamic stems, its own slider) under SFX / Music; a gentle
##            compressor on SFX (a pack in full cry and a crit land at one loudness), a slow one on Music (stems sit level)
##   ducks    named requests on the Music and Ambience buses, each a dB, a hold and a release: a stinger lowers the bed while it
##            sounds and lets it back slowly; the smallest request wins, so two stingers never stack into silence
##            (duck_music, duck_ambience, stinger). A dialogue box and a paused menu are Ambience's own ducks; these add to them
##   eclipse  the totality hushes the ambience (insects, small life) and the music steps back: the mix's own darkness
## Distance attenuation and occlusion live in Sfx (a ray per one-shot, core/audio/occlusion.gd). No class_name.

const BUS_UI := &"UI"
const ATTACK_DB_S := 36.0              ## how fast a duck bites (dB per second)

var ambience: Ambience                 ## set by the Soundstage
var stage: Node
var _amp := {}                         ## bus -> AudioEffectAmplify this node added
var _reqs := {"Music": [], "Ambience": []}     ## bus -> [[db, until msec, release s], ...]
var _cur := {"Music": 0.0, "Ambience": 0.0}    ## the dB each bus is ducked by now
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"mix_director")
	_ensure_buses()
	for b: String in ["Music", "Ambience"]:
		var bi := AudioServer.get_bus_index(b)
		if bi < 0:
			continue
		var amp := AudioEffectAmplify.new()
		AudioServer.add_bus_effect(bi, amp)
		_amp[b] = amp
	_glue("SFX", -14.0, 3.0, 4000.0, 140.0)
	_glue("Music", -20.0, 2.0, 40000.0, 400.0)


func _exit_tree() -> void:
	for b: String in _amp:
		var bi := AudioServer.get_bus_index(b)
		for i in range(AudioServer.get_bus_effect_count(bi) - 1, -1, -1):
			if AudioServer.get_bus_effect(bi, i) == _amp[b]:
				AudioServer.remove_bus_effect(bi, i)


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS_UI) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS_UI)
		AudioServer.set_bus_send(i, "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master")
	Settings.apply_audio()


## A gentle compressor on a bus, once (a second call finds it and leaves it).
func _glue(bus: String, threshold: float, ratio: float, attack_us: float, release_ms: float) -> void:
	var bi := AudioServer.get_bus_index(bus)
	if bi < 0:
		return
	for i in AudioServer.get_bus_effect_count(bi):
		if AudioServer.get_bus_effect(bi, i) is AudioEffectCompressor:
			return
	var c := AudioEffectCompressor.new()
	c.threshold = threshold
	c.ratio = ratio
	c.attack_us = attack_us
	c.release_ms = release_ms
	AudioServer.add_bus_effect(bi, c)


## Lower the Music bus by `db` (negative) for `hold` seconds, then let it back over `release`.
func duck_music(db: float, hold := 3.0, release := 2.0) -> void:
	_request("Music", db, hold, release)


func duck_ambience(db: float, hold := 3.0, release := 2.0) -> void:
	_request("Ambience", db, hold, release)


## A stinger's room: the music and the beds both step back while it speaks.
func stinger(db_music := -10.0, db_amb := -6.0, hold := 3.0, release := 2.5) -> void:
	_request("Music", db_music, hold, release)
	_request("Ambience", db_amb, hold, release)


func _request(bus: String, db: float, hold: float, release: float) -> void:
	if not _reqs.has(bus):
		return
	(_reqs[bus] as Array).append([db, Time.get_ticks_msec() + int(hold * 1000.0), maxf(release, 0.1)])


func _process(dt: float) -> void:
	var now := Time.get_ticks_msec()
	for b: String in _reqs:
		var list: Array = _reqs[b]
		var goal := 0.0
		var rel := 2.0
		var i := list.size() - 1
		while i >= 0:
			var r: Array = list[i]
			if now > int(r[1]) + int(float(r[2]) * 1000.0):
				list.remove_at(i)
			elif now <= int(r[1]):
				if float(r[0]) < goal:
					goal = float(r[0])
					rel = float(r[2])
			i -= 1
		var cur: float = _cur[b]
		if goal < cur:
			cur = maxf(goal, cur - ATTACK_DB_S * dt)
		else:
			cur = minf(goal if goal < 0.0 else 0.0, cur + (absf(cur) / maxf(rel, 0.1) + 1.0) * dt)
		_cur[b] = cur
		if _amp.has(b):
			(_amp[b] as AudioEffectAmplify).volume_db = cur
