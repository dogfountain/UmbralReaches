extends CanvasLayer
## The loading screen. Covers the night from the first frame until it is built AND warmed, so the
## first minutes of play meet no stutter:
##   1 build   the Realm's modules (Realm.progress / Realm.stage), the Ossuary (loads at boot now)
##   2 settle  the post-build pass (Atmosphere.post_build sets "post_done" on the zone)
##   3 warm    a camera tour of the Realm under the cover: every world material is drawn once, so the
##             Mac compiles its shaders here, not when you first walk into the wood. At the first
##             stop one of each enemy, the spell effects and the particle kinds are shown too.
##   4 steady  the player's camera again; waits for a run of even frames, then fades out.
## The player is frozen until the cover lifts. Shown only when the night is the running scene (not
## under the zz/ test harnesses); `--loading` forces it, `--no-loading` skips it.
## No class_name: Zone loads it by path.

const VIEWS := [
	# [position (y NAN = stand on the ground there), pitch]
	[Vector3(0.0, NAN, 30.0), -0.12],          # spawn, the green, the cart and the meadow beyond (one stop: the same materials)
	[Vector3(11.4, 1.1, 27.0), -0.1],          # inside the Keg
	[Vector3(-28.0, NAN, 30.0), -0.08],        # thornwood edge
	[Vector3(-39.4, NAN, 8.7), -0.08],         # the west way into the wood
	[Vector3(-75.0, NAN, 20.0), -0.08],        # deep in the wood
	[Vector3(-62.0, 9.8, -12.0), -0.1],        # the henge
	[Vector3(-58.0, NAN, 60.0), -0.1],         # the chapel
	[Vector3(33.8, NAN, 16.2), -0.08],         # the east way
	[Vector3(52.0, NAN, 12.0), -0.1],          # the fen
	[Vector3(70.0, NAN, -34.0), -0.1],         # the barrows
	[Vector3(-40.0, NAN, 147.5), -0.1],        # the Ossuary's Pilgrims' Landing (the Waiting Field's west end)
	[Vector3(12.0, -1.5, 167.0), 0.05],        # the Ossuary pit (on the charnel floor)
	[Vector3(0.0, 2.6, -10.0) + Endgame.O, -0.05],         # the Crossing (the far north-east: Endgame)
	[Vector3(-8.3, 19.8, -43.5) + Endgame.O, -0.2],        # the viaduct by the Spindle
	[Vector3(0.0, 29.7, -92.0) + Endgame.O, -0.1],         # the summit
	# r28: the Lower Count under the Ossuary, the Singing Stones, the Ash-Hermit's perch (agent D)
	[Vector3(12.0, -6.2, 169.0), 0.0],         # inside the Count Drum
	[Vector3(10.0, -6.2, 161.0), 0.0],         # the drum's west landing
	[Vector3(-28.0, NAN, 33.0), -0.1],         # the Singing Stones
	[Vector3(-48.0, NAN, -31.0), -0.05],       # toward the hermit's perch
]
## r28 additions to the combat set (by path: no class_name). Missing files are skipped.
const MORE_KIN := ["res://core/enemy/bulwark.gd", "res://core/enemy/chanter.gd", "res://core/enemy/burrower.gd", "res://core/enemy/mite.gd",
	"res://core/enemy/gaunt.gd", "res://core/enemy/quiller.gd", "res://core/enemy/pilgrim.gd", "res://core/enemy/tollman.gd",
	"res://core/enemy/cinder_caster.gd"]
## The great ones: their own materials (boss_pbr) and parts, shown once so a pull compiles nothing.
const PanelWarm := preload("res://ui/panel_warm.gd")
const NightWarm := preload("res://core/world/night_life/night_warm.gd")
const LootWarm := preload("res://ui/loot_warm.gd")
const Foley := preload("res://core/vfx/foley.gd")
const FOLEY_PER_FRAME := 3
const PauseScope := preload("res://core/world/pause_scope.gd")
const WarmAttackKit := preload("res://core/enemy/attack_kit.gd")
const WarmBossKit := preload("res://core/enemy/boss_kit.gd")
const WarmHorseRig := preload("res://core/world/mount/horse_rig.gd")
const WarmHorseDB := preload("res://core/world/mount/horse_db.gd")
const BOSSES := ["res://core/enemy/thornwarden.gd", "res://core/enemy/bone_abbot.gd", "res://core/enemy/ascended_warden.gd",
	# --- west marches ---
	"res://core/enemy/hierarch_voice.gd",
	# --- the east marches ---
	"res://core/enemy/anchoress.gd"]
## The elites (each its own script and parts) and the variant looks (their own materials), shown once too: in play the
## first of each was built cold, 11-21 ms an elite and 4-17 ms a look in one frame (zz/spawn_cost.tscn, 16 Nov);
## warm, every one is 1.4-2.1 ms.
const ELITES_PATH := "res://core/life/encounters/elites.gd"
const VARIANTS_PATH := "res://core/life/encounters/variants.gd"
const Variants := preload("res://core/life/encounters/variants.gd")
const VARIANT_ON := {"drowned": "res://core/enemy/husk.gd", "stonebound": "res://core/enemy/wretch.gd", "tideborn": "res://core/enemy/wretch.gd",
	"deeper": "res://core/enemy/husk.gd", "scarred": "res://core/enemy/ossuant.gd", "ironclad": "res://core/enemy/husk.gd"}
const CORES := ["core_prism", "core_lodestar", "core_cinder", "core_rime"]
const SKIP_AFTER_VIEW := 2        # stops (spawn, the Keg) the tour must have shown before a key may leave the rest
const DIRS := 6                 # headings per stop
const FRAMES_PER_DIR := 2
const FX_HOLD := 14             # frames the warm-up enemies stay in view
const BAR_W := 560.0
const BUILD_SHARE := 0.68       # bar share of the build; the warm tour gets most of the rest
const Med := preload("res://ui/medieval_style.gd")
const UIType := preload("res://ui/type.gd")
const BG := Color(0.03, 0.02, 0.012)
const LILAC := Med.GILT
const QUIET := Med.BONE
const DIM := Color(Med.BONE_DIM, 0.85)

var zone: Node3D
var _player: Node3D
var _phase := "build"
var _t := 0.0
var _phase_t := 0.0
var _shown := 0.0
var _target := 0.0
var _cam: Camera3D
var _view := 0
var _dir := 0
var _frame := 0
var _warm_nodes: Array[Node] = []
var _warm_bolts: Array[Node] = []
var _warm_loot: Array[Node] = []     ## ground bags and drops shown for the loot first-use costs (emptied before they are freed)
const SPELL_LEFTOVERS: Array[StringName] = [&"lantern_ward", &"bound_shade", &"umbral_well"]
var _spell_keep := {}             ## instance ids of spell leftovers that stood before the warm casts
var _warm_saved := {}             ## the wanderer before the warm-up cast every spell
var _warm_life: Node
var _pw: PanelWarm                ## opens each big panel once under the cover
var _fx_frames := -1
var _combat_shown := false
var _sounds_done := false
var _foley_done := false           ## every footfall, hoof, cloth and horse take is built (a few a frame in settle)
var _steady := 0
var _paces: Array[float] = []      ## the last frame times in "steady"


static func _median(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() >> 1]

var _fade := 1.0
var _root: Control
var _fill: ColorRect
var _stage: Label
var _hint: Label
var _space: PhysicsDirectSpaceState3D


static func open(z: Node3D) -> CanvasLayer:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or "--no-loading" in args:
		return null
	var cur := z.get_tree().current_scene
	if not "--loading" in args and cur != null and cur != z:
		return null                                   # under a zz/ harness: tests drive the player
	var ls: CanvasLayer = (load("res://ui/loading_screen.gd") as GDScript).new()
	ls.set("zone", z)
	z.add_child(ls)
	return ls


func _ready() -> void:
	add_to_group(&"loading_screen")
	name = "LoadingScreen"
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	print("LOADING open")


func _build_ui() -> void:
	var font: Font = load("res://ui/fonts/Cinzel.ttf")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_root.add_child(col)
	var crown := Med.rule(Med.GILT_DEEP)
	crown.custom_minimum_size = Vector2(BAR_W, 18)
	crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(crown)
	var title := _label(font, "UMBRAL REACHES", 58, LILAC)
	Med.gilt(title, 58, Color(1.0, 0.84, 0.46))
	col.add_child(title)
	_stage = _label(font, "", 22, Color(0.96, 0.9, 0.76))
	col.add_child(_stage)
	var trough := PanelContainer.new()                  # the progress bar: a bronze bar filling an iron-rimmed trough
	trough.add_theme_stylebox_override("panel", Med.frame(8))
	trough.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(trough)
	var bar := ColorRect.new()
	bar.color = Color(0.03, 0.02, 0.012)
	bar.custom_minimum_size = Vector2(BAR_W, 10)
	trough.add_child(bar)
	_fill = ColorRect.new()
	_fill.color = Med.GILT
	_fill.size = Vector2(0, 10)
	bar.add_child(_fill)
	_hint = _label(UIType.body(), "", 18, Color(Med.BONE_DIM, 0.95))
	_hint.custom_minimum_size = Vector2(BAR_W + 60.0, 0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)


func _label(font: Font, text: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func _input(event: InputEvent) -> void:
	if _phase != "done" and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		# after the build, the first stops are compiled: one key may leave the rest of the tour for the fade
		if _phase == "warm" and _view >= SKIP_AFTER_VIEW and event.is_pressed() and not event.is_echo():
			_next("steady")


func _process(delta: float) -> void:
	_t += delta
	_phase_t += delta
	_hold_player()
	match _phase:
		"build":
			_stage.text = Realm.stage if Realm.stage != "" else "Gathering the night"
			_hint.text = ""
			_target = Realm.progress * BUILD_SHARE
			if zone.has_meta("realm_done"):
				_next("settle")
		"settle":
			if _phase_t == 0.0 or not _sounds_done:
				_sounds_done = true
				# the staff's sounds and the combat sounds are synthesised (or read from cache) here
				(load("res://core/vfx/staff_sfx.gd") as GDScript).call("prewarm")
				(load("res://core/vfx/synth.gd") as GDScript).call("prewarm")
			_stage.text = "Settling the night"
			_target = BUILD_SHARE + 0.04
			if not _foley_done:
				_foley_done = Foley.prewarm(FOLEY_PER_FRAME)       # spread over frames: the screen keeps animating
			# (the render pass and the merge go on beside the tour: "post_done" is waited for in "steady")
			if (zone.has_meta("post_ready") and _foley_done) or _phase_t > 8.0:
				_next("warm")
		"warm":
			_stage.text = "Warming the world"
			_hint.text = "Every stone, flame and shade is shown to the renderer once, so it never stops to prepare one mid-play." \
				+ ("\nPress any key to go in." if _view >= SKIP_AFTER_VIEW else "")
			_warm_step()
		"panels":
			_stage.text = "Laying out the Journal"
			_hint.text = ""
			_target = 0.98
			if _pw == null or _pw.done or _phase_t > 20.0:
				_next("steady")
		"steady":
			_stage.text = "Almost there"
			_target = 1.0
			# the cover lifts on a run of even frames once the work that follows the build is done (the lava's bank
			# map): "even" is near this machine's own pace, not a fixed 33 fps (a slower PC timed out after 3 s
			# into a world still busy, ~20 fps for its first seconds). 12 s at most.
			_paces.append(delta)
			if _paces.size() > 30:
				_paces.remove_at(0)
			var pace := _median(_paces)
			var lw := get_tree().get_first_node_in_group(&"lava_works") as LavaWorks
			var busy := (lw != null and lw.mapping > 0) or (not zone.has_meta("post_done") and _phase_t < 25.0)
			_steady = _steady + 1 if not busy and _paces.size() >= 10 and delta < maxf(pace * 1.35, 0.012) and delta < 0.05 else 0
			if _steady >= 20 or _phase_t > 12.0:
				_next("fade")
		"fade":
			_fade = maxf(0.0, _fade - delta / 0.4)
			_root.modulate.a = _fade
			if _fade <= 0.0:
				_finish()
				return
	# the bar is the work done (stops completed), not a crawl behind it: it arrives with the cover
	_shown = move_toward(_shown, _target, delta * (1.2 if _phase == "build" else 6.0))
	_fill.size.x = BAR_W * _shown


func _next(p: String) -> void:
	print("LOADING %s -> %s at %.2f s (wall %.2f s)" % [_phase, p, _t, Time.get_ticks_msec() * 0.001])
	_phase = p
	_phase_t = 0.0
	if p == "warm":
		_start_tour()
	elif p == "panels":
		_end_tour()
		PauseScope.mark(zone)                 # scenery branches skip the pause's notification walk
		_pw = PanelWarm.new()
		_pw.zone = zone
		add_child(_pw)
		_pw.run()
	elif p == "steady":
		_end_tour()


## Freeze the wanderer under the cover (input is swallowed too); restored in _finish.
func _hold_player() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if _player:
			_player.process_mode = Node.PROCESS_MODE_DISABLED


# --- the warm-up tour ------------------------------------------------------------------------------

func _start_tour() -> void:
	_space = zone.get_world_3d().direct_space_state
	_cam = Camera3D.new()
	_cam.name = "WarmCam"
	_cam.fov = Settings.fov
	_cam.far = 400.0
	var pc := get_viewport().get_camera_3d()
	if pc:
		_cam.attributes = pc.attributes
		_cam.environment = pc.environment
		_cam.far = pc.far
	zone.add_child(_cam)
	_cam.current = true
	_view = 0
	_dir = 0
	_frame = 0
	_place()


func _place() -> void:
	var v: Array = VIEWS[_view]
	var at: Vector3 = v[0]
	if is_nan(at.y):
		at.y = _ground(at) + 1.8
	_cam.global_position = at
	_cam.rotation = Vector3(float(v[1]), TAU * float(_dir) / float(DIRS), 0.0)


func _ground(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80.0, at.z), Vector3(at.x, -40.0, at.z), Layers.WORLD)
	var hit := _space.intersect_ray(q)
	return float((hit.position as Vector3).y) if not hit.is_empty() else 0.0


func _warm_step() -> void:
	if _fx_frames >= 0:                  # the combat set is on show: hold this heading
		_fx_frames += 1
		if _fx_frames > FX_HOLD:
			_clear_combat()
		return
	if not _combat_shown and _view == 0 and _frame == 1:
		_combat_shown = true
		_show_combat()
		return
	_frame += 1
	if _frame < FRAMES_PER_DIR:
		return
	_frame = 0
	_dir += 1
	if _dir >= DIRS:
		_dir = 0
		_view += 1
	_target = BUILD_SHARE + 0.04 + (1.0 - BUILD_SHARE - 0.07) * float(_view) / float(VIEWS.size())
	if _view >= VIEWS.size():
		_next("panels")
		return
	_place()


## One of each enemy, the spell effects and the particle kinds, a few metres in front of the warm
## camera: their meshes are generated (GenCache) and their shaders compiled behind the cover.
func _show_combat() -> void:
	_fx_frames = 0
	var fwd := -_cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var c := _cam.global_position + fwd * 6.0
	c.y = _ground(c)
	var kinds: Array = [Wretch, Husk, Crawler, Leaper, Spitter, Ossuant, Shade]
	for path: String in MORE_KIN:
		if ResourceLoader.exists(path):
			kinds.append(load(path))
	for k in kinds.size():
		var script: GDScript = kinds[k]
		if script == null:
			continue
		var e: Node3D = script.new()
		e.process_mode = Node.PROCESS_MODE_DISABLED
		zone.add_child(e)
		e.remove_from_group(Groups.ENEMY)               # nothing counts or targets these
		e.global_position = c + right * (float(k) - 5.0) * 1.1 + fwd * 1.5
		_warm_nodes.append(e)
		if e is Enemy:
			for _i in 3:                                # three of each kind's death bursts into the pool
				(e as Enemy).death_bursts(e.global_position + Vector3.UP * 0.8)
	var col := Color(0.55, 0.65, 1.0)
	var hot := Color(1.0, 0.75, 0.4)
	var at := c + Vector3.UP * 0.6
	SpellFx.nova(c, 2.5)
	SpellFx.lance_impact(at, Vector3.UP, 1.5, false)
	SpellFx.lance_impact(at, Vector3.UP, 1.5, true)
	SpellFx.implosion(c, 2.0)
	SpellFx.rift_out(at)
	SpellFx.rift_in(at)
	SpellFx.rift_seam(at - right, at + right)
	for style in 3:
		SpellFx.disc(c + right * (float(style) - 1.0), 1.0, style, col, hot, 0.6)
	SpellFx.shell(at, 0.3, 1.5, col, 0.6)
	SpellFx.column(c, 0.8, 3.0, 0.6)
	SpellFx.tear(at, 2.0, 0.6)
	var d := SpellFx.danger(c, 0.6, {})
	if d:
		_warm_nodes.append(d)
	Vfx.burst(at, hot, {})
	Vfx.burst(at, col, {"additive": false})
	Vfx.burst(at, hot, {"trail": 0.2})
	Vfx.burst(at, col, {"trail": 0.2, "additive": false})
	Vfx.burst(at, col, {"grow": 2.0, "additive": false})
	Vfx.ring(at, 1.0, col)
	Vfx.light(at, hot, 2.0, 4.0)
	Vfx.scorch(c, 1.0, hot)
	Vfx.ribbon(PackedVector3Array([at - right, at, at + right + Vector3.UP]), 0.2, 0.05, col)
	Vfx.ribbon(PackedVector3Array([at - right, at, at + right]), 0.2, 0.05, hot, 0.25, false)
	Vfx.arc(at - right, at + right, col)
	_show_r28(c, at, right, fwd, col)
	_show_more(c, at, right, fwd, col, hot)
	_warm_nodes.append_array(NightWarm.show(zone, c, right, fwd))      # the living night: its cards, pools, mist, glints, creatures and every burst preset
	_cast_every_spell(c, fwd)
	_warm_loot = LootWarm.show(zone, c, right, fwd)
	_keep_resident()
	print("LOADING combat set on show: %d nodes, %d resources kept resident" % [_warm_nodes.size(),
		(zone.get_meta(&"warm_resident") as Array).size() if zone.has_meta(&"warm_resident") else 0])


## The bosses, and the effect helpers the first set never drew (so a fight compiles none of them).
func _show_more(c: Vector3, at: Vector3, right: Vector3, fwd: Vector3, col: Color, hot: Color) -> void:
	for k in BOSSES.size():
		if not ResourceLoader.exists(BOSSES[k]):
			continue
		var b: Node3D = (load(BOSSES[k]) as GDScript).new()
		b.process_mode = Node.PROCESS_MODE_DISABLED
		zone.add_child(b)
		b.remove_from_group(Groups.ENEMY)
		b.global_position = c + fwd * 5.0 + right * (float(k) - 1.0) * 4.0
		_warm_nodes.append(b)
	_show_elites(c, right, fwd)
	# the skinned horses (one material per breed): a stable or the first ride compiles none of them
	var bi := 0
	for breed: String in WarmHorseDB.BREEDS:
		var h: Node3D = WarmHorseRig.new()
		zone.add_child(h)
		h.setup(breed, WarmHorseDB.BREEDS[breed] as Dictionary)
		h.global_position = c - fwd * 4.0 + right * (float(bi) - 1.0) * 2.5
		_warm_nodes.append(h)
		bi += 1
	Vfx.impact(at, hot, fwd, false)
	Vfx.impact(at, col, fwd, true)
	var em := Vfx.emitter(col, {})
	if em:
		zone.add_child(em)
		em.global_position = at
		_warm_nodes.append(em)
	var ring := SpellFx.target_ring()
	if ring:
		zone.add_child(ring)
		SpellFx.place_ring(ring, c, Vector3.UP, 1.5, 1.0)
		_warm_nodes.append(ring)
	var spear := MeshInstance3D.new()
	spear.mesh = SpellFx.spear_mesh()
	zone.add_child(spear)
	spear.global_position = at + right
	_warm_nodes.append(spear)
	var foes: Array = _warm_nodes.filter(func(n: Node) -> bool: return n is Enemy)
	if not foes.is_empty():
		var z := WarmAttackKit.zone(foes[0] as Enemy, c + right * 3.0, 9.0, 0.0, {})
		if z:
			_warm_nodes.append(z)
	WarmBossKit.lee_marks(c - fwd * 2.0, [c + right * 2.0, c - right * 2.0], 0.6)
	# a boss zone landing (BossKit._land): thorn and bone spikes, the ring burst and the turbulent
	# dust. The first Briar Snare compiled these mid-fight: a 74 ms frame.
	WarmBossKit.spikes(zone, c + right * 1.5, {"radius": 1.0}, "thorn")
	WarmBossKit.spikes(zone, c - right * 1.5, {"radius": 1.0}, "bone")
	Vfx.burst(at, hot, {"count": 40, "life": 0.6, "speed": Vector2(2.0, 6.0), "size": 0.06, "gravity": -6.0, "ring": 1.0})
	Vfx.burst(c + Vector3.UP * 0.2, Color(0.08, 0.06, 0.06, 0.8), {"count": 16, "life": 1.0, "speed": Vector2(0.5, 2.0), "size": 0.45, "gravity": 0.6, "radius": 0.5, "additive": false, "turbulence": true})


## One of each elite and each variant look, a row behind the kinds (see ELITES_PATH).
func _show_elites(c: Vector3, right: Vector3, fwd: Vector3) -> void:
	var slots: Array = []                              # [script, look]
	if ResourceLoader.exists(ELITES_PATH):
		var elites: Dictionary = (load(ELITES_PATH) as GDScript).get_script_constant_map().get("ELITES", {})
		for id: String in elites:
			var sp := String((elites[id] as Dictionary).get("script", ""))
			if sp != "" and ResourceLoader.exists(sp):
				slots.append([load(sp), ""])
	var variants: GDScript = load(VARIANTS_PATH) if ResourceLoader.exists(VARIANTS_PATH) else null
	if variants != null:
		for look: String in VARIANT_ON:
			if (variants.get_script_constant_map().get("VARIANTS", {}) as Dictionary).has(look) and ResourceLoader.exists(VARIANT_ON[look]):
				slots.append([load(VARIANT_ON[look]), look])
	for k in slots.size():
		var script: GDScript = slots[k][0]
		var look: String = slots[k][1]
		var e: Node3D = script.new()
		if e == null:
			continue
		e.process_mode = Node.PROCESS_MODE_DISABLED
		if look != "":
			Variants.pre(e, look)
		zone.add_child(e)
		if look != "":
			Variants.dress(e, look)
		e.remove_from_group(Groups.ENEMY)
		e.global_position = c + fwd * 3.2 + right * (float(k) - float(slots.size()) * 0.5) * 0.9
		_warm_nodes.append(e)


## What the warm foes loaded and nothing else holds stays loaded for the night: a boss's model (ClipRig loads its
## glTF by path and keeps nothing) was read again at every build once the warm one was freed, 4-8 ms of each pull
## and approach warm-up (zz/spawn_cost.tscn: a boss rebuilt 5-10 ms, with its model held 1.4-2.2 ms).
func _keep_resident() -> void:
	var keep: Array[Resource] = []
	if zone.has_meta(&"warm_resident"):
		keep = zone.get_meta(&"warm_resident")
	for n in _warm_nodes:
		if not (n is Enemy) or not is_instance_valid(n):
			continue
		if n.get_script() != null and not keep.has(n.get_script()):
			keep.append(n.get_script())
		for m in n.find_children("*", "", true, false):
			var path := m.scene_file_path
			if path != "" and ResourceLoader.exists(path):
				var ps := load(path)
				if ps != null and not keep.has(ps):
					keep.append(ps)
	zone.set_meta(&"warm_resident", keep)


## Every spell the wanderer knows, cast once from in front of the warm camera with its real code
## (its own bursts, rings and variant), so the first fight compiles nothing. The wanderer, Gloom,
## Wounds and the cooldowns are put back when the set is cleared.
func _cast_every_spell(c: Vector3, fwd: Vector3) -> void:
	var pl := _player as Player
	if pl == null or pl.skills() == null:
		return
	var sb := pl.skills()
	_warm_saved = {"pos": _player.global_position, "gloom": _player.get("gloom"), "wounds": _player.get("wounds")}
	_player.global_position = c - fwd * 1.5
	_spell_keep.clear()
	for g: StringName in SPELL_LEFTOVERS:
		for n in get_tree().get_nodes_in_group(g):
			_spell_keep[n.get_instance_id()] = true
	for i in sb.slots.size():
		if sb.slots[i] == null:
			continue
		sb.reset_cooldowns()
		sb.try_cast(i, 1.0, true)
	sb.reset_cooldowns()


## The r28 expansion's spells, afflictions, enemy attacks, staff cores and sky effects.
func _show_r28(c: Vector3, at: Vector3, right: Vector3, fwd: Vector3, col: Color) -> void:
	var foes: Array = _warm_nodes.filter(func(n: Node) -> bool: return n is Enemy)
	var aff := "res://core/skills/afflict.gd"
	if ResourceLoader.exists(aff) and foes.size() >= 2:
		var A: GDScript = load(aff)
		for i in 3:
			A.call("chill", foes[0], 1.0)              # the third chill builds the ice crust
		A.call("burn", foes[1], 1.0, 0.0)
	if ResourceLoader.exists("res://core/skills/umbral_well.gd"):
		var w: Node3D = (load("res://core/skills/umbral_well.gd") as GDScript).new()
		w.set("life", 0.6)
		w.set("by", _player)
		zone.add_child(w)
		w.global_position = c - right * 2.0
		if w.has_method("ignite"):
			w.call("ignite")
		_warm_nodes.append(w)
	if ResourceLoader.exists("res://core/skills/bound_shade.gd"):
		var sh: Node3D = (load("res://core/skills/bound_shade.gd") as GDScript).new()
		sh.set("owner_p", _cam)
		sh.set("life", 0.6)
		zone.add_child(sh)
		sh.global_position = at + right
		_warm_nodes.append(sh)
	if ResourceLoader.exists("res://core/skills/tether_chain.gd") and not foes.is_empty() and _player:
		(load("res://core/skills/tether_chain.gd") as GDScript).call("throw", _player, foes[foes.size() - 1], 0.3)
	if ResourceLoader.exists("res://core/life/progression/fx/ember_cinders.gd"):
		(load("res://core/life/progression/fx/ember_cinders.gd") as GDScript).call("throw", at, 1.0, fwd)
	if ResourceLoader.exists("res://core/enemy/attack_kit.gd"):
		var K: GDScript = load("res://core/enemy/attack_kit.gd")
		K.call("lob", at, c + right * 2.0, 0.5, Color(0.5, 1.2, 0.4))
		var pool_mi: Variant = K.call("linger", c + right * 2.0, 1.0, 0.6, 0.0, 1.0, Color(0.5, 1.2, 0.4))
		if pool_mi is Node:
			_warm_nodes.append(pool_mi)
	# a bolt dressed in each staff core, held still in view
	var pool := get_tree().get_first_node_in_group("bolt_pool")
	if pool and pool.has_method("take"):
		for i in CORES.size():
			var b: Node3D = pool.call("take")
			if b == null:
				continue
			b.call("arm_with", {"core": CORES[i]})
			b.process_mode = Node.PROCESS_MODE_DISABLED
			b.global_position = at + right * (float(i) - 1.5) * 0.8 + Vector3.UP * 0.6
			_warm_bolts.append(b)
	var life := zone.find_child("Wildlife", true, false)
	if life and life.has_method("warm_show"):
		life.call("warm_show", true, c)
		_warm_life = life


func _clear_combat() -> void:
	LootWarm.clear(_warm_loot)
	_warm_loot.clear()
	for n in _warm_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_warm_nodes.clear()
	var pool := get_tree().get_first_node_in_group("bolt_pool")
	for b in _warm_bolts:
		if is_instance_valid(b) and pool and pool.has_method("release"):
			pool.call("release", b)
	_warm_bolts.clear()
	# what the warm-up's own casts left standing (a Lantern Ward's light, a bound shade, a well): gone
	# before the cover lifts, or the wanderer loads in beside a spell nobody cast
	for g: StringName in SPELL_LEFTOVERS:
		for n in get_tree().get_nodes_in_group(g):
			if not _spell_keep.has(n.get_instance_id()):
				n.queue_free()
	_spell_keep.clear()
	if not _warm_saved.is_empty() and is_instance_valid(_player):
		_player.global_position = _warm_saved.pos
		_player.set("gloom", _warm_saved.gloom)
		_player.set("wounds", _warm_saved.wounds)
		if _player is Player and (_player as Player).skills() != null:
			(_player as Player).skills().reset_cooldowns()
		_warm_saved = {}
	if is_instance_valid(_warm_life):
		_warm_life.call("warm_show", false)
	_warm_life = null
	_fx_frames = -1


func _end_tour() -> void:
	_clear_combat()
	if is_instance_valid(_cam):
		_cam.queue_free()
	if _player:
		var pc := _player.get_node_or_null("CameraRig/Pitch/SpringArm/Camera") as Camera3D
		if pc:
			pc.current = true


func _finish() -> void:
	remove_from_group(&"loading_screen")
	_phase = "done"
	if is_instance_valid(_player):
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		if _player.has_method("reset_physics_interpolation"):
			_player.reset_physics_interpolation()
	print("LOADING done at %.2f s (wall %.2f s: control)" % [_t, Time.get_ticks_msec() * 0.001])
	queue_free()

