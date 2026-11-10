extends Zone
## Stair of Ascension: the night's root script (the Realm round Hearthward). The test, demo and
## benchmark flags live in core/debug/main_harness.gd, created in _ready only when one is on the command line.

const MainHarness := preload("res://core/debug/main_harness.gd")
const SessionState := preload("res://core/world/session_state.gd")
const FadeGuard := preload("res://core/world/fade_guard.gd")
const LightDirector := preload("res://core/world/light_director.gd")

## Streamed areas (docs/ZONE_PLAN.md). Anchors are area centres; radii in metres (horizontal).
const AREAS: Array[Dictionary] = [
	# load_r covers the whole Realm: the Ossuary loads at boot under the loading screen instead of a
	# ~265 ms freeze when a player first walks within 110 m of it (from the far west)
	{"id": "ossuary", "source": "res://world/areas/ossuary/ossuary.gd", "anchor": Vector3(19.0, 4.0, -36.0), "load_r": 400.0, "unload_r": 500.0},
]


func _ready() -> void:
	FadeGuard.attach(self)              # every ranged mesh dissolves in and out instead of popping (fade_guard.gd)
	LightDirector.attach(self)          # every light governed by LightPolicy, a budget of local lights, one fire shadow
	super._ready()
	# r30: there is no stair under the Realm any more; the card names the land
	Events.zone_entered.emit("THE UMBRAL REACHES", "where the sky turns inward")
	# Summit glass removed with the Crimson Vale — next night TBD.
	var dress_path := "res://world/zones/ascension/dress.tscn"
	if ResourceLoader.exists(dress_path):
		add_child((load(dress_path) as PackedScene).instantiate())
	Atmosphere.apply(self, _env, _cam, _moon, 82.0, Color("#12183A"), Color("#060A1C"), Color("#1E4AA0"))   # fog glows azure, not violet
	_cam.far = FarDetail.VIEW_FAR       # the world is loaded to the horizon (far detail); the culling above is still sized to 82 m
	_spawn_glimmers()
	EnemySpawner.seed_realm(self)     # camps of the redesigned zone (RealmBosses)
	AreaStreamer.attach(self, AREAS)
	var pw := PerfWatch.new()
	pw.name = "PerfWatch"
	add_child(pw)
	LavaWorks.attach(self)
	var satchel := Satchel.new()
	satchel.name = "Satchel"
	add_child(satchel)
	# r35: the one character screen (Wanderer, Kindling, Pack, Journal) over the old panels
	var cscreen: CanvasLayer = (load("res://ui/character_screen.gd") as GDScript).new()
	cscreen.name = "CharacterScreen"
	add_child(cscreen)
	var wmap: CanvasLayer = (load("res://ui/world_map.gd") as GDScript).new()
	wmap.name = "WorldMap"
	add_child(wmap)
	var amb := Ambience.new()
	amb.name = "Ambience"
	add_child(amb)
	finish_zone_setup()
	if _player.get_node_or_null("CameraRig/Pitch/SpringArm") is SpringArm3D:
		(_player.get_node("CameraRig/Pitch/SpringArm") as SpringArm3D).spring_length = 3.7
	var args := OS.get_cmdline_user_args()
	if MainHarness.wanted(args):
		var h := MainHarness.new()
		h.name = "MainHarness"
		h.night = self
		add_child(h)
		h.start(args)


## Torn down (quit, or the Deeper Night rebuilding the night in this process): the night's static
## state belongs to this build only. The list lives in core/world/session_state.gd.
func _exit_tree() -> void:
	SessionState.reset_night()


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	# r36 hardening (r35 critique, #7): the autopilot (F9) and the benchmark (F8) are for development;
	# the shipped game (an export template) ignores them unless started with -- --dev
	if not _dev_keys():
		return
	if event.is_action_pressed("demo") and not _player.autopilot:
		_harness().start_demo()
	elif event.is_action_pressed("benchmark"):
		_harness().start_benchmark()


## The harness node, made on first use by a dev key when no flag created it.
func _harness() -> Node:
	var h := get_node_or_null("MainHarness")
	if h == null:
		h = MainHarness.new()
		h.name = "MainHarness"
		h.night = self
		add_child(h)
		h.start(OS.get_cmdline_user_args())
	return h


static func _dev_keys() -> bool:
	return OS.has_feature("editor") or "--dev" in OS.get_cmdline_user_args()


func _spawn_glimmers() -> void:
	var g := Glimmers.new()
	g.name = "Glimmers"
	g.seed_n = 11
	g.half = 30.0
	g.z_min = -72.0
	g.z_max = 40.0
	g.skip_corridor = true
	g.skip_river = false
	g.skip_shards = true
	g.palettes = PackedColorArray([
		Color(0.55, 0.85, 2.6),
		Color(1.55, 0.55, 3.3),
		Color(0.45, 1.05, 3.1),
		Color(0.85, 0.6, 2.4),
	])
	add_child(g)
