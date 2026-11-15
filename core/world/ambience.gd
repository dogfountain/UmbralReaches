class_name Ambience
extends Node
## The night's soundscape (life system r28). Built by world/main.gd; everything is synthesised
## (core/life/wildlife/scape_synth.gd, cached in GenCache) or one of the two recorded-free beds in
## art/audio. Four layers, all on the Ambience bus so its slider scales them:
##   beds     layered loops per region (village, heath, wood, fen, the Crossing, the summit, the
##            Ossuary, the tavern's room), mixed from RealmLayout's soft region weights: walking from
##            the meadow into the Thornwood crossfades over the 18 m the regions blend over, then eases
##            (FADE). An Area with `ambience` (the Ossuary) takes over completely inside its bounds.
##   spots    one-shot calls placed in 3D round the listener from the region's palette: a bittern
##            booming in the fen, a twig snapping in the wood, stones skittering on the Crossing, drips
##            and bones in the crypt. Rain, the Gloom tide and danger thin them.
##   places   every soundscape has an open-air acoustic (a thin tail on open land, soft and short in the wood, a far echo
##            off rock on the cliffs and the Anchorholds, a long dark one at the Well): blended by the same region weights as the
##            beds, so walking from the heath into the Thornwood lets the reverb change gradually. SFX, the creature voices
##            (the Voices bus: a gentle compressor, then SFX) and the Ambience bus all share it.
##   rooms    indoors the outdoor layers (beds, rain, wind, wildlife: the "AmbOut" bus) are muffled by
##            a low-pass; reverb zones (the tavern, the Ossuary, down in the Ashen Rift) add a room to
##            every sound (SFX and Ambience buses) and ease in and out.
##   music    a subtle generative layer (scape_music.gd) that answers danger and rest.
## Tests: zz/world_sound_test.tscn.  Read-only for others: `scape`, `bed_gain`, `reverb_zone`.

const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")
const Music := preload("res://core/life/wildlife/scape_music.gd")
const Foley := preload("res://core/vfx/foley.gd")
const GloomDrone := preload("res://core/world/gloom_drone.gd")

## dB each bed gives up at full Gloom (core/world/gloom_world.gd): the small living sounds go first
const GLOOM_THIN := {"crickets": 17.0, "meadow": 13.0, "leaves": 8.0, "murmur": 14.0, "fen": 6.0, "night": 2.5}
const GLOOM_DRONE_DB := [-52.0, -19.0]    ## the drone's level at the first sign of Gloom and at full

const FADE := 2.5                 ## seconds for a bed to come fully in or out
const BASE_DB := -6.0
const OUT_BUS := &"AmbOut"        ## outdoor layers: muffled indoors, sends to Ambience
const MUSIC_BUS := &"Music"       ## the generative music (scape_music.gd): its own level, no room reverb
const VOICES_BUS := &"Voices"     ## creature voices (enemy_audio.gd): compressed a little, then into SFX (and its reverb)

## bed -> [source, top dB, outdoor]
const BEDS := {
	"night": ["res://art/audio/amb_night.wav", BASE_DB, true],
	"ossuary": ["res://art/audio/amb_ossuary.wav", BASE_DB, false],
	"crickets": ["life:crickets", -19.0, true],
	"meadow": ["scape:meadow", -21.0, true],
	"leaves": ["scape:leaves", -17.0, true],
	"fen": ["scape:fen", -17.0, true],
	"chasm": ["scape:chasm", -12.0, true],
	"high_wind": ["scape:high_wind", -15.0, true],
	"hearth": ["scape:hearth", -14.0, false],
	"river": ["foley:river", -13.0, true],         # near the Sorrow: gain follows the distance to its bank (_pick)
	"murmur": ["foley:murmur", -16.0, true],       # a settlement's talk, far off
}

## soundscape -> bed mix (linear)
const SCAPES := {
	"village": {"night": 1.0, "crickets": 0.85, "meadow": 0.6, "murmur": 0.8},
	"heath": {"night": 1.0, "meadow": 0.9, "crickets": 0.35},
	"wood": {"night": 0.75, "leaves": 1.0, "crickets": 0.3},
	"fen": {"night": 0.75, "fen": 1.0, "crickets": 0.2},
	"crossing": {"night": 0.55, "chasm": 1.0, "high_wind": 0.3},
	"summit": {"night": 0.45, "high_wind": 1.0, "chasm": 0.2},
	"ossuary": {"ossuary": 1.0},
	"tavern": {"hearth": 1.0, "night": 0.6, "crickets": 0.5},
	# r34 flora: each new region its own mix of the beds (Enshrouded and WoW both let a region be
	# heard before it is seen: wind in the cut stone, the mere's water, the field's crickets)
	"quarry": {"night": 0.6, "high_wind": 0.65, "chasm": 0.12},
	"holds": {"night": 0.8, "leaves": 0.7, "crickets": 0.5, "meadow": 0.3},
	"foundry": {"night": 0.5, "chasm": 0.45, "high_wind": 0.4},
	"moor": {"night": 0.8, "high_wind": 0.5, "meadow": 0.65, "crickets": 0.15},
	"orchard": {"night": 0.9, "meadow": 0.4, "leaves": 0.25, "crickets": 0.2},
	"necropolis": {"night": 0.9, "meadow": 0.45, "crickets": 0.65},
	"mere": {"night": 0.7, "fen": 1.0, "crickets": 0.3, "meadow": 0.2},
	# the Outer Marches and the downs (Foundation): the river's water, the siege's wind, the salt's silence
	"sorrow": {"night": 0.7, "leaves": 0.55, "fen": 0.5, "crickets": 0.2},
	"plinth": {"night": 0.7, "high_wind": 0.4, "leaves": 0.3, "crickets": 0.1},
	"siege": {"night": 0.7, "high_wind": 0.4, "meadow": 0.2, "crickets": 0.15},
	"stillwater": {"night": 0.7, "fen": 0.85, "crickets": 0.2, "high_wind": 0.1},
	"anchorholds": {"night": 0.6, "high_wind": 0.75, "chasm": 0.1},
	"salt": {"night": 0.55, "high_wind": 0.7, "crickets": 0.05},
	"downs": {"night": 0.85, "meadow": 0.6, "high_wind": 0.3, "crickets": 0.2},
	"well": {"night": 0.5, "chasm": 0.7, "high_wind": 0.2},
	# the ossuary: its own ground over the pit (the pit's breath, a draught off the bank, the crickets gone quiet)
	"charnel": {"night": 0.75, "chasm": 0.4, "high_wind": 0.22, "crickets": 0.08},
}

## RealmLayout region id -> soundscape
const REGION_SCAPE := {"hearth": "village", "chapel": "village", "road": "heath", "thornwood": "wood", "henge": "wood",
	"glade": "wood", "fen": "fen", "barrows": "fen", "rift": "crossing", "ossuary": "charnel", "summit": "summit", "crags": "summit",
	# r34 flora: the new ground, each its own scape (SCAPES / SPOTS)
	"quarry": "quarry", "holds": "holds", "foundry": "foundry", "moor": "moor", "orchard": "orchard", "necropolis": "necropolis", "mere": "mere",
	# the Marches
	"weirford": "village", "sorrow": "sorrow", "plinth": "plinth", "siege": "siege", "stillwater": "stillwater",
	"anchorholds": "anchorholds", "saltmarket": "heath", "saltpans": "salt", "downs": "downs", "oak": "wood", "well": "well"}

## soundscape -> [interval min, max (s), distance min, max (m), palette [[sound, weight, height]]]
## sound "life:x" plays LifeSynth's x; height: metres above the ground, or "lava" (down on the lava)
const SPOTS := {
	"village": [10.0, 22.0, 22.0, 50.0, [["bell_far", 0.25, 6.0], ["life:owl2", 0.3, 5.0], ["vixen", 0.2, 0.3], ["twig", 0.1, 0.2], ["creak", 0.15, 2.0]]],
	"heath": [7.0, 16.0, 18.0, 45.0, [["nightjar", 0.45, 1.0], ["peewit", 0.15, 3.0], ["life:owl2", 0.2, 5.0], ["vixen", 0.15, 0.3]]],
	"wood": [6.0, 14.0, 12.0, 40.0, [["twig", 0.3, 0.2], ["creak", 0.35, 3.0], ["life:owl", 0.2, 6.0], ["life:owl2", 0.12, 6.0], ["bellow", 0.08, 1.0], ["vixen", 0.06, 0.3]]],
	"fen": [6.0, 13.0, 14.0, 42.0, [["bittern", 0.4, 0.3], ["life:plop", 0.3, 0.0], ["life:heron", 0.12, 1.0], ["creak", 0.1, 2.0]]],
	"crossing": [6.0, 13.0, 16.0, 40.0, [["blurp", 0.5, "lava"], ["pebbles", 0.4, 0.0], ["howl", 0.06, 20.0]]],
	"summit": [9.0, 20.0, 20.0, 50.0, [["howl", 0.25, 25.0], ["pebbles", 0.45, 0.0], ["life:crow", 0.15, 8.0]]],
	"ossuary": [4.0, 10.0, 4.0, 14.0, [["drip", 0.5, 2.5], ["bones", 0.25, 0.2], ["whisper", 0.1, 1.5], ["pebbles", 0.1, 0.5]]],
	"tavern": [30.0, 60.0, 20.0, 30.0, []],
	# r34 flora
	"quarry": [8.0, 18.0, 14.0, 40.0, [["pebbles", 0.55, 0.0], ["creak", 0.15, 2.0], ["life:crow", 0.2, 8.0], ["howl", 0.08, 20.0]]],
	"holds": [7.0, 15.0, 12.0, 36.0, [["life:owl", 0.3, 6.0], ["twig", 0.25, 0.2], ["creak", 0.2, 3.0], ["vixen", 0.12, 0.3]]],
	"foundry": [8.0, 18.0, 14.0, 40.0, [["pebbles", 0.4, 0.0], ["creak", 0.25, 2.0], ["life:crow", 0.2, 8.0], ["howl", 0.1, 20.0]]],
	"moor": [8.0, 18.0, 20.0, 50.0, [["peewit", 0.35, 3.0], ["nightjar", 0.25, 1.0], ["howl", 0.12, 20.0], ["life:crow", 0.1, 6.0], ["vixen", 0.1, 0.3]]],
	"orchard": [8.0, 17.0, 14.0, 42.0, [["creak", 0.3, 3.0], ["twig", 0.25, 0.2], ["life:crow", 0.25, 5.0], ["life:owl2", 0.15, 5.0]]],
	"necropolis": [9.0, 20.0, 18.0, 46.0, [["bell_far", 0.3, 6.0], ["life:crow", 0.3, 4.0], ["life:owl2", 0.2, 5.0], ["creak", 0.1, 1.5], ["whisper", 0.06, 1.2]]],
	"mere": [6.0, 13.0, 12.0, 40.0, [["life:plop", 0.35, 0.0], ["bittern", 0.3, 0.3], ["life:heron", 0.2, 1.0], ["peewit", 0.06, 3.0]]],
	# the Marches
	"sorrow": [6.0, 14.0, 12.0, 38.0, [["life:plop", 0.3, 0.0], ["twig", 0.2, 0.2], ["life:owl", 0.2, 6.0], ["bittern", 0.15, 0.3], ["creak", 0.1, 3.0]]],
	"plinth": [8.0, 18.0, 14.0, 42.0, [["life:crow", 0.3, 8.0], ["howl", 0.15, 20.0], ["creak", 0.2, 3.0], ["life:owl", 0.2, 6.0], ["twig", 0.15, 0.2]]],
	"siege": [7.0, 16.0, 14.0, 42.0, [["creak", 0.35, 2.0], ["pebbles", 0.2, 0.0], ["life:crow", 0.25, 6.0], ["howl", 0.1, 20.0], ["bell_far", 0.1, 6.0]]],
	"stillwater": [6.0, 13.0, 12.0, 40.0, [["life:plop", 0.35, 0.0], ["life:heron", 0.2, 1.0], ["bittern", 0.2, 0.3], ["life:owl2", 0.15, 5.0], ["bell_far", 0.1, 8.0]]],
	"anchorholds": [8.0, 18.0, 14.0, 44.0, [["howl", 0.25, 25.0], ["pebbles", 0.3, 0.0], ["bell_far", 0.25, 12.0], ["life:crow", 0.2, 8.0]]],
	"salt": [9.0, 20.0, 18.0, 50.0, [["howl", 0.3, 20.0], ["pebbles", 0.3, 0.0], ["creak", 0.3, 3.0], ["whisper", 0.1, 1.0]]],
	"downs": [8.0, 18.0, 18.0, 50.0, [["peewit", 0.3, 3.0], ["nightjar", 0.25, 1.0], ["life:owl2", 0.2, 5.0], ["vixen", 0.15, 0.3], ["howl", 0.1, 20.0]]],
	"well": [6.0, 13.0, 10.0, 30.0, [["drip", 0.4, 2.0], ["pebbles", 0.3, 0.0], ["howl", 0.15, 15.0], ["whisper", 0.1, 1.5]]],
	"charnel": [8.0, 18.0, 14.0, 40.0, [["bell_far", 0.25, 6.0], ["whisper", 0.16, 1.2], ["bones", 0.2, 0.2], ["life:crow", 0.2, 6.0], ["pebbles", 0.14, 0.0], ["creak", 0.05, 2.0]]],
}

## reverb zones: AudioEffectReverb settings
const ROOMS := {
	"tavern": {"room_size": 0.36, "damping": 0.65, "wet": 0.11, "spread": 0.7, "predelay_msec": 14.0, "hipass": 0.15},
	"ossuary": {"room_size": 0.84, "damping": 0.3, "wet": 0.28, "spread": 1.0, "predelay_msec": 48.0, "hipass": 0.1},
	"rift": {"room_size": 0.93, "damping": 0.45, "wet": 0.17, "spread": 1.0, "predelay_msec": 95.0, "hipass": 0.2},
}
## open-air acoustics by kind of place (used when no room is: blended by the soundscape weights)
const PLACES := {
	"open": {"room_size": 0.5, "damping": 0.75, "wet": 0.035, "spread": 0.9, "predelay_msec": 40.0, "hipass": 0.25},
	"wood": {"room_size": 0.45, "damping": 0.85, "wet": 0.07, "spread": 1.0, "predelay_msec": 18.0, "hipass": 0.2},
	"cliff": {"room_size": 0.82, "damping": 0.4, "wet": 0.12, "spread": 1.0, "predelay_msec": 120.0, "hipass": 0.25},
	"well": {"room_size": 0.92, "damping": 0.35, "wet": 0.22, "spread": 1.0, "predelay_msec": 70.0, "hipass": 0.15},
}
const SCAPE_PLACE := {"village": "open", "heath": "open", "wood": "wood", "fen": "open", "crossing": "cliff", "summit": "cliff",
	"quarry": "cliff", "holds": "wood", "foundry": "cliff", "moor": "open", "orchard": "wood", "necropolis": "open", "mere": "open",
	"sorrow": "wood", "plinth": "open", "siege": "open", "stillwater": "open", "anchorholds": "cliff", "salt": "open", "downs": "open",
	"well": "well", "charnel": "cliff"}
const ROOM_KEYS := ["room_size", "damping", "spread", "predelay_msec", "hipass"]
## outdoor layers indoors: [low-pass cutoff Hz, AmbOut volume dB]
const MUFFLE := {"": [20000.0, 0.0], "tavern": [700.0, -4.0], "ossuary": [320.0, -16.0], "rift": [20000.0, 0.0]}

var scape := "village"            ## the dominant soundscape at the listener
var gloom := 0.0                  ## 0..1, set by GloomWorld: thins the small sounds, brings the drone in
var bed_gain := {}                ## bed -> current linear gain (0..1, before its top dB)
var bed_want := {}                ## bed -> target gain
var reverb_zone := ""             ## "", tavern, ossuary, rift
var reverb_wet := 0.0             ## current wet level (eased)
var muffle := 0.0                 ## 0 open .. 1 the zone's full muffle
var spots_played := 0
var last_spot := {}               ## {kind, pos, dist}
var music: Node
var quiet := false                ## tests: no spot calls
var off := false                  ## --scape-off: only the night bed, as before r28 (perf A/B)

var _players: Dictionary = {}     ## bed -> AudioStreamPlayer
var _twins: Dictionary = {}       ## bed -> a second, detuned player of the same loop (the night bed)
var _t := 0.0
var _spot_t := 4.0
var _spot_voices: Array[AudioStreamPlayer3D] = []
var _spot_i := 0
var _rng := RandomNumberGenerator.new()
var _verbs := {}                  ## bus name -> AudioEffectReverb we added
var _lowpass: AudioEffectLowPassFilter
var _room_goal: Dictionary = PLACES["open"]   ## reverb settings the buses ease toward (a room, or the blended place)
var _room_busy := true
var _muffle_to := ""
var _limiter: AudioEffectHardLimiter
var _master_comp: AudioEffectCompressor
var _music_v := -1.0
var _drone: AudioStreamPlayer


## The Music bus level: Settings.music_volume when it exists (the Music slider), else the Ambience
## slider's value, so the music never ignores the player's levels. Checked a few times a second.
func _music_level() -> void:
	var mi := AudioServer.get_bus_index(MUSIC_BUS)
	if mi < 0:
		return
	var v: Variant = Settings.get("music_volume")
	if v == null:
		v = Settings.get("ambience_volume")
	var lin := clampf(float(v) if v != null else 0.7, 0.0, 1.0)
	if lin == _music_v:
		return
	_music_v = lin
	AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(lin, 0.0001)))
	AudioServer.set_bus_mute(mi, lin <= 0.001)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS         # a menu ducks the beds; it does not cut them to silence
	_rng.seed = 5309
	if "--no-ambience" in OS.get_cmdline_user_args():      # debugging: no soundscape at all
		set_process(false)
		return
	off = "--scape-off" in OS.get_cmdline_user_args()
	_make_buses()
	if not off:
		ScapeSynth.prewarm()
	for key: String in BEDS:
		if off and key != "night" and key != "ossuary":
			continue
		var s := _bed_stream(String(BEDS[key][0]))
		if s == null:
			continue
		var p := AudioStreamPlayer.new()
		p.name = "Bed_" + key
		p.stream = s
		p.bus = OUT_BUS if bool(BEDS[key][2]) else &"Ambience"
		p.volume_db = -80.0
		add_child(p)
		_players[key] = p
		if key == "night" and not off:
			var tw := AudioStreamPlayer.new()
			tw.name = "Bed_night_twin"
			tw.stream = s
			tw.bus = p.bus
			tw.pitch_scale = 0.94
			tw.volume_db = -80.0
			add_child(tw)
			_twins[key] = tw
		bed_gain[key] = 0.0
		bed_want[key] = 0.0
	for i in 4:
		var a := AudioStreamPlayer3D.new()
		a.name = "Spot%d" % i
		a.bus = OUT_BUS
		a.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		a.unit_size = 10.0
		a.max_distance = 90.0
		a.panning_strength = 1.0
		a.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(a)
		_spot_voices.append(a)
	if not off:
		music = Music.new()
		music.name = "Music"
		add_child(music)
		# r35: a composed theme for each great one (boss_themes.gd); ScapeMusic ducks under it
		var themes: Node = (load("res://core/life/wildlife/boss_themes.gd") as GDScript).new()
		add_child(themes)
	_pick()


func _exit_tree() -> void:
	# stop what we play and let go of the synthesised streams (static caches outlived the engine:
	# "AudioStreamWAV leaked at exit"); the next zone's _ready prewarms them again from GenCache
	for p in _players.values() + _twins.values():
		if is_instance_valid(p):
			(p as AudioStreamPlayer).stop()
	for a in _spot_voices:
		if is_instance_valid(a):
			a.stop()
	ScapeSynth._cache.clear()
	LifeSynth._cache.clear()
	Sfx.release()
	# leave the buses as Settings made them
	for bus: String in _verbs:
		var bi := AudioServer.get_bus_index(bus)
		if bi < 0:
			continue
		for i in range(AudioServer.get_bus_effect_count(bi) - 1, -1, -1):
			if AudioServer.get_bus_effect(bi, i) == _verbs[bus]:
				AudioServer.remove_bus_effect(bi, i)
	_verbs.clear()
	if _limiter != null:
		var mi := AudioServer.get_bus_index("Master")
		for i in range(AudioServer.get_bus_effect_count(mi) - 1, -1, -1):
			if AudioServer.get_bus_effect(mi, i) == _limiter:
				AudioServer.remove_bus_effect(mi, i)
		_limiter = null
	if _master_comp != null:
		var ci := AudioServer.get_bus_index("Master")
		for i in range(AudioServer.get_bus_effect_count(ci) - 1, -1, -1):
			if AudioServer.get_bus_effect(ci, i) == _master_comp:
				AudioServer.remove_bus_effect(ci, i)
		_master_comp = null


static func _bed_stream(src: String) -> AudioStreamWAV:
	var s: AudioStreamWAV
	if src.begins_with("scape:"):
		return ScapeSynth.stream(src.trim_prefix("scape:"))
	if src.begins_with("life:"):
		return LifeSynth.stream(src.trim_prefix("life:"))
	if src.begins_with("foley:"):
		return Foley.bed(src.trim_prefix("foley:"))
	s = load(src) as AudioStreamWAV
	if s == null:
		return null
	s = s.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * float(s.mix_rate))
	return s


## AmbOut (outdoor layers, a low-pass for indoors) -> Ambience; Music -> Master (its own level: the
## Music slider when Settings has one, else it follows Ambience); a reverb on SFX and Ambience, off
## until a room asks for it; a hard limiter last on Master, so a pile-up (a storm's crack over a
## fight) is held under 0 dBFS instead of clipping.
func _make_buses() -> void:
	if AudioServer.get_bus_index("Ambience") < 0:
		return                                    # Settings makes the buses; without them, stay plain
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		AudioServer.add_bus()
		var mi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(mi, MUSIC_BUS)
		AudioServer.set_bus_send(mi, "Master")
	_music_level()
	var master := AudioServer.get_bus_index("Master")
	if master >= 0 and not off:
		for i in AudioServer.get_bus_effect_count(master):
			if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
				_limiter = AudioServer.get_bus_effect(master, i)
		if _limiter == null:
			_limiter = AudioEffectHardLimiter.new()
			_limiter.ceiling_db = -0.5
			_limiter.pre_gain_db = 0.0
			_limiter.release = 0.12
			# a gentle glue first (2:1 from -12 dB, slow attack so the transients of a blow stay), the limiter last
			_master_comp = AudioEffectCompressor.new()
			_master_comp.threshold = -12.0
			_master_comp.ratio = 2.0
			_master_comp.attack_us = 25000.0
			_master_comp.release_ms = 320.0
			_master_comp.gain = 0.0
			AudioServer.add_bus_effect(master, _master_comp)
			AudioServer.add_bus_effect(master, _limiter)
	if AudioServer.get_bus_index(VOICES_BUS) < 0 and AudioServer.get_bus_index("SFX") >= 0:
		AudioServer.add_bus()
		var vi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(vi, VOICES_BUS)
		AudioServer.set_bus_send(vi, "SFX")
		var vc := AudioEffectCompressor.new()      # a pack in full cry sits level; a lone wind-up keeps its edge
		vc.threshold = -16.0
		vc.ratio = 2.5
		vc.attack_us = 8000.0
		vc.release_ms = 180.0
		vc.gain = 1.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(VOICES_BUS), vc)
	if AudioServer.get_bus_index(OUT_BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, OUT_BUS)
		AudioServer.set_bus_send(i, "Ambience")
	var oi := AudioServer.get_bus_index(OUT_BUS)
	_lowpass = null
	for k in AudioServer.get_bus_effect_count(oi):
		if AudioServer.get_bus_effect(oi, k) is AudioEffectLowPassFilter:
			_lowpass = AudioServer.get_bus_effect(oi, k)
	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(oi, _lowpass)
	AudioServer.set_bus_effect_enabled(oi, AudioServer.get_bus_effect_count(oi) - 1, false)
	if off:
		return
	for bus: String in ["SFX", "Ambience"]:
		var bi := AudioServer.get_bus_index(bus)
		if bi < 0:
			continue
		var rv := AudioEffectReverb.new()
		rv.wet = 0.0
		rv.dry = 1.0
		AudioServer.add_bus_effect(bi, rv)
		AudioServer.set_bus_effect_enabled(bi, AudioServer.get_bus_effect_count(bi) - 1, false)
		_verbs[bus] = rv
	_room_busy = true


var _duck := 0.0                                ## dB the beds sit lower while the game is paused


func _process(delta: float) -> void:
	_duck = move_toward(_duck, -9.0 if get_tree().paused else 0.0, delta * 30.0)
	_t -= delta
	if _t <= 0.0:
		_t = 0.25
		_pick()
		_music_level()
	for key: String in _players:
		var g := move_toward(float(bed_gain[key]), float(bed_want[key]), delta / FADE)
		bed_gain[key] = g
		var p := _players[key] as AudioStreamPlayer
		if g <= 0.001:
			if p.playing:
				p.stop()
			continue
		p.volume_db = float(BEDS[key][1]) + linear_to_db(sin(g * PI * 0.5)) + _duck - float(GLOOM_THIN.get(key, 0.0)) * gloom      # equal-power
		if not p.playing:
			p.play(_rng.randf() * p.stream.get_length())
		var tw := _twins.get(key) as AudioStreamPlayer
		if tw != null:
			# the twin plays the same loop half a cycle on and a little slower: the two drift, so the
			# loop's swells no longer come round every 18 s; each at -3 dB keeps the bed's level
			tw.volume_db = p.volume_db - 3.0
			p.volume_db -= 3.0
			if not tw.playing:
				tw.play(fmod(p.get_playback_position() + p.stream.get_length() * 0.5, p.stream.get_length()))
	for key: String in _twins:
		var tw := _twins[key] as AudioStreamPlayer
		if tw.playing and float(bed_gain[key]) <= 0.001:
			tw.stop()
	_rooms(delta)
	_gloom_drone()
	if not off:
		_spots(delta)


## The drone under the night: silent until the Gloom is real, then a level that climbs with it. It rides the
## outdoor bus, so a roof muffles it with the rest.
func _gloom_drone() -> void:
	if gloom < 0.04:
		if _drone != null and _drone.playing:
			_drone.stop()
		return
	if _drone == null:
		if off or AudioServer.get_bus_index(OUT_BUS) < 0:
			return
		_drone = AudioStreamPlayer.new()
		_drone.name = "GloomDrone"
		_drone.stream = GloomDrone.make()
		_drone.bus = OUT_BUS
		add_child(_drone)
	_drone.volume_db = lerpf(GLOOM_DRONE_DB[0], GLOOM_DRONE_DB[1], sqrt(gloom)) + _duck
	if not _drone.playing:
		_drone.play()


# --- where the listener is ---------------------------------------------------------------------------

func _listener() -> Vector3:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p != null:
		return p.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


## The soundscape mix at a point: {scape: weight} (sums to 1) and the zone override, if any.
static func mix_at(p: Vector3, area_scape := "") -> Dictionary:
	if area_scape != "":
		return {area_scape: 1.0}
	if RealmLayout.TAVERN.grow(0.3).has_point(Vector2(p.x, p.z)) and p.y < 6.0:
		return {"tavern": 1.0}
	var w := {}
	var sum := 0.0
	for r: Dictionary in RealmLayout.REGIONS:
		var sc: String = REGION_SCAPE.get(String(r.id), "")
		if sc == "":
			continue
		var x := RealmLayout.region_weight(r, p.x, p.z)
		if x <= 0.001:
			continue
		# up on the Crossing and the summit the wind takes over from the lava
		if sc == "crossing" and p.y > 12.0:
			var k := clampf((p.y - 12.0) / 10.0, 0.0, 1.0)
			w["summit"] = float(w.get("summit", 0.0)) + x * k
			x *= 1.0 - k
		w[sc] = float(w.get(sc, 0.0)) + x
		sum += x
	if sum <= 0.001:
		return {"heath": 1.0}
	for k: String in w:
		w[k] = float(w[k]) / sum
	return w


func _area_scape(p: Vector3) -> String:
	for node in get_tree().get_nodes_in_group(&"ambience_area"):
		var a := node as Area
		if a and a.ambience != "" and a.ambience_bounds.has_point(a.to_local(p)):
			return a.ambience
	return ""


func _pick() -> void:
	var p := _listener()
	var area := _area_scape(p)
	if off:
		for key: String in bed_want:
			bed_want[key] = 1.0 if key == (area if area != "" and _players.has(area) else "night") else 0.0
		scape = area if area != "" else "night"
		return
	var mix := mix_at(p, area)
	var best := ""
	var bw := -1.0
	for key: String in bed_want:
		bed_want[key] = 0.0
	for sc: String in mix:
		var w: float = mix[sc]
		if w > bw:
			bw = w
			best = sc
		var beds: Dictionary = SCAPES.get(sc, {})
		for key: String in beds:
			if bed_want.has(key):
				bed_want[key] = float(bed_want[key]) + w * float(beds[key])
	# a river is heard from its bank: the water bed swells over the last 26 m
	if bed_want.has("river") and area == "":
		var nr := RealmLayout.river_near(p.x, p.z)
		if nr.x < INF:
			bed_want["river"] = 1.0 - smoothstep(2.0, 26.0, nr.x - RealmLayout.river_w(nr.z))
	# rain hushes the insects and thins the meadow's chirrup (the rain beds take over)
	var rain := float(_weather_state().get("rain", 0.0))
	if rain > 0.0:
		if bed_want.has("crickets"):
			bed_want["crickets"] = float(bed_want["crickets"]) * (1.0 - 0.85 * rain)
		if bed_want.has("meadow"):
			bed_want["meadow"] = float(bed_want["meadow"]) * (1.0 - 0.5 * rain)
	for key: String in bed_want:
		bed_want[key] = clampf(float(bed_want[key]), 0.0, 1.0)
	scape = best
	reverb_zone = zone_at(p, area, best)
	_set_room_goal(room_goal(reverb_zone, mix))


## The reverb room at p: the tavern, the Ossuary, down in the Ashen Rift below its rim, or "".
static func zone_at(p: Vector3, area: String, best: String) -> String:
	if best == "tavern":
		return "tavern"
	if area == "ossuary":
		return "ossuary"
	if Rect2(-26, -112, 52, 100).has_point(Vector2(p.x, p.z)) and p.y < -2.5 and RealmLayout.biome_at(p.x, p.z) == "ash":
		return "rift"
	return ""


## The reverb the listener stands in: the room if there is one (tavern, Ossuary, the Rift), else the open-air acoustics
## of the soundscapes round them, weighted like the beds (so it changes gradually across a region's blend).
static func room_goal(zone: String, mix: Dictionary) -> Dictionary:
	if ROOMS.has(zone):
		return ROOMS[zone]
	var out := {}
	var total := 0.0
	for sc: String in mix:
		var place: Dictionary = PLACES[String(SCAPE_PLACE.get(sc, "open"))]
		var w := float(mix[sc])
		total += w
		for k: String in place:
			out[k] = float(out.get(k, 0.0)) + float(place[k]) * w
	if total <= 0.001:
		return PLACES["open"]
	for k: String in out:
		out[k] = float(out[k]) / total
	return out


func _set_room_goal(g: Dictionary) -> void:
	for k: String in g:
		if absf(float(g[k]) - float(_room_goal.get(k, -1000.0))) > 0.003 * maxf(1.0, absf(float(g[k])) * 0.1):
			_room_busy = true
	_room_goal = g


## Ease the reverb toward the goal, and the indoor muffle toward the current zone.
func _rooms(dt: float) -> void:
	if _room_busy:
		var k := 1.0 - exp(-dt / 0.45)
		var still := true
		for bus: String in _verbs:
			var rv: AudioEffectReverb = _verbs[bus]
			for key: String in ROOM_KEYS:
				var now := float(rv.get(key))
				var to := float(_room_goal.get(key, now))
				if absf(to - now) > 0.0005 * maxf(1.0, absf(to)):
					still = false
				rv.set(key, lerpf(now, to, k))
			var wet := float(_room_goal.get("wet", 0.0)) * (0.6 if bus == "Ambience" else 1.0)
			if absf(wet - rv.wet) > 0.0004:
				still = false
			rv.wet = lerpf(rv.wet, wet, k)
			var bi := AudioServer.get_bus_index(bus)
			for i in AudioServer.get_bus_effect_count(bi):
				if AudioServer.get_bus_effect(bi, i) == rv:
					AudioServer.set_bus_effect_enabled(bi, i, rv.wet > 0.004)
		if still:
			_room_busy = false
		if not _verbs.is_empty():
			reverb_wet = (_verbs.values()[0] as AudioEffectReverb).wet
	# muffle the outdoors
	var m: Array = MUFFLE.get(reverb_zone, MUFFLE[""])
	var tgt := 1.0 if float(m[0]) < 19000.0 else 0.0
	if reverb_zone != _muffle_to and tgt > 0.0:
		_muffle_to = reverb_zone
	muffle = move_toward(muffle, tgt, dt / 0.8)
	var oi := AudioServer.get_bus_index(OUT_BUS)
	if oi < 0 or _lowpass == null:
		return
	var mm: Array = MUFFLE.get(_muffle_to, MUFFLE[""])
	var cut := exp(lerpf(log(20000.0), log(float(mm[0])), muffle))
	_lowpass.cutoff_hz = cut
	AudioServer.set_bus_volume_db(oi, float(mm[1]) * muffle)
	for i in AudioServer.get_bus_effect_count(oi):
		if AudioServer.get_bus_effect(oi, i) == _lowpass:
			AudioServer.set_bus_effect_enabled(oi, i, muffle > 0.01)


# --- spot calls ----------------------------------------------------------------------------------------

func _spots(dt: float) -> void:
	_spot_t -= dt
	if _spot_t > 0.0:
		return
	var spec: Array = SPOTS.get(scape, SPOTS["heath"])
	var wx := _weather_state()
	var rain := float(wx.get("rain", 0.0))
	var danger := float(music.get("intensity")) if music != null else 0.0
	var k := (1.0 + rain * 1.5) * (1.0 + danger * 1.5) * (1.0 + gloom * 3.0)
	_spot_t = _rng.randf_range(float(spec[0]), float(spec[1])) * k
	if quiet or (spec[4] as Array).is_empty():
		return
	var wild := get_parent().get_node_or_null("Wildlife") if get_parent() != null else null
	var tide := wild != null and bool(wild.get("tide"))
	if tide and scape not in ["ossuary", "crossing"]:
		return
	var palette: Array = spec[4]
	var total := 0.0
	for e: Array in palette:
		total += float(e[1])
	var pick := _rng.randf() * total
	var entry: Array = palette[0]
	for e: Array in palette:
		pick -= float(e[1])
		if pick <= 0.0:
			entry = e
			break
	var snd := String(entry[0])
	if rain > 0.5 and snd.begins_with("life:") and snd != "life:plop":
		return                                         # birds keep quiet in the rain
	play_spot(snd, entry[2], float(spec[2]), float(spec[3]))


## Play a spot call somewhere round the listener (tests call it directly).
func play_spot(snd: String, height: Variant, dmin: float, dmax: float) -> AudioStreamPlayer3D:
	var stream: AudioStreamWAV = LifeSynth.stream(snd.trim_prefix("life:")) if snd.begins_with("life:") else ScapeSynth.stream(snd)
	if stream == null:
		return null
	var cam := get_viewport().get_camera_3d()
	var lp := cam.global_position if cam != null else _listener()
	var p := _listener()
	var ang := _rng.randf_range(0.0, TAU)
	var d := _rng.randf_range(dmin, dmax)
	var at := p + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
	if height is String and String(height) == "lava":
		at.y = RealmLayout.LAVA_Y + 0.5
	elif scape == "ossuary":
		at.y = p.y + float(height)
	else:
		at.y = RealmLayout.ground(get_viewport().world_3d.direct_space_state, at.x, at.z) + float(height) if get_viewport().world_3d != null else p.y
	var a := _spot_voices[_spot_i]
	_spot_i = (_spot_i + 1) % _spot_voices.size()
	a.stream = stream
	a.bus = &"Ambience" if scape == "ossuary" else OUT_BUS
	a.global_position = at
	a.pitch_scale = _rng.randf_range(0.92, 1.08)
	a.volume_db = _rng.randf_range(-9.0, -4.0) + (3.0 if snd in ["bittern", "howl", "bell_far", "bellow"] else 0.0)
	a.play()
	spots_played += 1
	last_spot = {"kind": snd, "pos": at, "dist": at.distance_to(lp)}
	return a


func _weather_state() -> Dictionary:
	var w := get_parent().get_node_or_null("Wildlife/Weather") if get_parent() != null else null
	if w == null or not is_instance_valid(w):
		return {}
	var st: Variant = w.get("state")
	return st if st is Dictionary else {}
