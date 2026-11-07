extends Node
## Play-through CAPTURE harness for the critique panel. It plays the real night (world/main.tscn) by script
## and records evidence: contact-sheet frame strips of motion (two views at once), stills of every region,
## the menus, perf numbers per section, and a list of every file written. It does not fix anything.
##
##   tools/play_capture.sh [--out=<dir>] [section ...]        (windowed, one godot per section, watchdogged)
##   godot --path . res://zz/play_capture.tscn -- --out=<dir> --only=horse,wanderer [--timeout=170] [--nolit]
##
## Sections (each is a separate run, kept under ~3 minutes windowed):
##   horse  wanderer  enemies_a..d  bosses_a..c  villagers  regions_a  regions_b  places  ui
## Output: <out>/<section>/*.png, perf.txt, errors.txt (this harness's own failed steps; the wrapper adds the
## engine's SCRIPT ERROR / warning lines from the run log), index_<section>.md; <out>/index.md lists them all.
##
## A strip is N frames at a fixed interval, shot from a camera that follows the subject at a fixed offset:
## "side" (square on) and "3q" (three-quarter from the front). Both are rendered in the same frame, the 3q
## one through a SubViewport that shares the world and the game's night grade. Frame times are printed on
## each cell. One extra "_LIT" still per strip is lit by an added lamp (labelled: NOT the night grade).
## In memory only: Travel._busy holds the save; encounters/roaming events are switched off for the stage.
## Headless the logic runs but no images are taken (it is the "runs clean" check).
const OUT_ROOT := "/private/tmp/claude-501/-Users-luke-UmbralReaches/968888c4-6238-49b1-a0f8-2ba292b49c0a/scratchpad/play"
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const WIN := Vector2i(1280, 800)
const CELL := Vector2i(480, 300)
const COLS := 4
const SECTIONS := ["horse", "wanderer", "spells", "enemies_a", "enemies_b", "enemies_c", "enemies_d", "bosses_a", "bosses_b", "bosses_c",
	"villagers", "regions_a", "regions_b", "places", "ui", "warmth"]
const ENEMY_SETS := {
	"enemies_a": ["wretch", "husk", "crawler", "leaper"],
	"enemies_b": ["spitter", "ossuant", "shade", "gaunt"],
	"enemies_c": ["bulwark", "chanter", "burrower", "mite"],
	"enemies_d": ["quiller", "tollman", "pilgrim", "cinder_caster"],
}
const ARENA_BOSSES := {"thornwarden": ["thornwarden", "henge"], "ascended_warden": ["ascended_warden", "summit"],
	"bone_abbot": ["bone_abbot", ""], "anchoress": ["r37_anchoress", ""], "hierarch_voice": ["r37_hierarch", ""]}
const BOSS_SETS := {
	"bosses_a": ["bone_abbot", "thornwarden"],
	"bosses_b": ["ascended_warden", "brood_mother", "tally_reliquary"],
	"bosses_c": ["anchoress", "hierarch_voice"],
}
const SCRIPTS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd", "spitter": "res://core/enemy/spitter.gd",
	"crawler": "res://core/enemy/crawler.gd", "leaper": "res://core/enemy/leaper.gd", "ossuant": "res://core/enemy/ossuant.gd",
	"thornwarden": "res://core/enemy/thornwarden.gd", "bone_abbot": "res://core/enemy/bone_abbot.gd",
	"ascended_warden": "res://core/enemy/ascended_warden.gd", "bulwark": "res://core/enemy/bulwark.gd",
	"chanter": "res://core/enemy/chanter.gd", "burrower": "res://core/enemy/burrower.gd", "mite": "res://core/enemy/mite.gd",
	"gaunt": "res://core/enemy/gaunt.gd", "quiller": "res://core/enemy/quiller.gd", "tollman": "res://core/enemy/tollman.gd",
	"brood_mother": "res://core/enemy/brood_mother.gd", "pilgrim": "res://core/enemy/pilgrim.gd",
	"cinder_caster": "res://core/enemy/cinder_caster.gd", "tally_reliquary": "res://core/enemy/tally_reliquary.gd",
	"anchoress": "res://core/enemy/anchoress.gd", "hierarch_voice": "res://core/enemy/hierarch_voice.gd",
}
## Where the foe stands (metres from the wanderer) for the attack strip: the shooters and casters keep their distance.
const RANGED := {"spitter": 9.0, "tollman": 9.0, "cinder_caster": 9.0, "chanter": 9.0, "quiller": 10.0, "burrower": 8.0, "leaper": 7.0}
## Boss signature moves: [label, method, args, seconds to watch, hp ratio to set first (0 = leave), phase note].
const BOSS_MOVES := {
	"thornwarden": [["p1_thornstorm", "_thornstorm", [], 2.6, 0.0], ["p1_thorn_lanes", "_thorn_lanes", [], 2.4, 0.0],
		["p1_snare", "_snare", [], 2.4, 0.0], ["p2_call_stones", "_call_stones", [], 3.0, 0.69], ["p3_bloom", "_bloom", [], 3.0, 0.33]],
	"bone_abbot": [["p1_tolling", "_tolling", [], 3.0, 0.0], ["p1_bone_rain", "_bone_rain", [], 3.0, 0.0],
		["p1_grave_spikes", "_grave_spikes", [], 2.4, 0.0], ["p1_sweep", "_sweep", [], 2.4, 0.0],
		["p2_reckoning", "_reckoning", [3], 3.2, 0.5], ["p2_tithe", "_tithe", [], 2.6, 0.0], ["p3_requiem", "_requiem", [], 3.2, 0.3],
		["p3_cage", "_cage", [], 2.6, 0.0]],
	"ascended_warden": [["p1_fan", "_aim_fan", [false], 2.6, 0.0], ["p1_judgement", "_judgement", [], 2.4, 0.0],
		["p1_blink", "_blink", [], 2.0, 0.0], ["p2_mandorla_flare", "_mandorla_flare", [], 2.6, 0.6],
		["p2_acolytes", "_call_acolytes", [], 2.6, 0.0], ["p2_eclipse", "_eclipse", [], 3.2, 0.0], ["p3_double_fan", "_aim_fan", [true], 2.8, 0.28]],
	"brood_mother": [["lob", "_lob", [], 2.4, 0.0], ["spray", "_spray", [], 2.2, 0.0], ["brood", "_start_brood", [], 3.4, 0.0], ["hatch", "_hatch", [], 2.4, 0.0]],
	"tally_reliquary": [],
	"anchoress": [["p1_anchor_swing", "_swing", [0.0], 2.2, 0.0], ["p1_double_swing", "_double_swing", [], 3.6, 0.0],
		["p1_chain_ring", "_chain_ring", [], 2.6, 0.0], ["p2_toll_of_the_cell", "_toll", [], 3.0, 0.68], ["p2_rockfall", "_rockfall", [], 3.0, 0.0],
		["p2_undertow", "_undertow", [], 3.2, 0.0], ["p3_howl", "_howl", [1.6], 2.4, 0.33]],
	"hierarch_voice": [["p1_edict", "_edict", [1], 3.0, 0.0], ["p1_falling_crown", "_falling_crown", [], 3.0, 0.0],
		["p2_double_edict", "_edict", [2], 3.2, 0.63], ["p2_choir", "_choir", [], 3.0, 0.0], ["p2_toll", "_toll", [], 3.0, 0.0],
		["p3_verdict", "_verdict", [], 3.6, 0.28]],
}
const GLYPHS := {
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"], "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"], "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"], "s": ["00000", "00000", "01111", "10000", "01110", "00001", "11110"],
	"t": ["01000", "01000", "11110", "01000", "01000", "01001", "00110"], "=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
	"#": ["01010", "01010", "11111", "01010", "11111", "01010", "01010"], " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}

var out_root := OUT_ROOT
var only: Array = []
var time_limit := 170.0
var nolit := false
var still_filter: Array = []       ## --filter=a,b: only the _view_still shots whose file name has one of these
var headless := false
var main: Node
var p: Player
var t_start := 0
var realm_s := -1.0
var ready_to_run := false
var started := false
var book: SkillBook
# --- the rigs
var cam1: Camera3D
var cam2: Camera3D
var vp2: SubViewport
var lit_lamp: OmniLight3D
# --- the section being run
var sec := ""
var sec_dir := ""
var fails: Array[String] = []
var index: Array[String] = []
var blank_run := 0
var _hidden_ui: Array[CanvasLayer] = []
# --- perf
var perf_on := false
var perf_skip := 0
var f_ms := PackedFloat32Array()
var f_dc := PackedInt32Array()
var f_pr := PackedInt64Array()
var spike_s := 0.02                     ## a frame over this is listed (the ui section lowers it: a panel's first open should stay under 12 ms)
var spikes: Array = []                 ## [marker, ms] for every frame over 20 ms
var _mark := ""                        ## the step the harness is in (a still or a strip), named in the spike list
var perf_segs: Array = []              ## [label, first frame index, last frame index]
var _seg_label := ""
var _seg_from := 0
# --- the stage
var studio := Vector3.ZERO
var studio_yaw := 0.0                  ## the way the wanderer faces on the stage
var runway := {}                       ## {"from": Vector3, "yaw": float}: a long straight flat course
# --- the follow camera
var f_on := false
var f_a: Node3D
var f_b: Node3D
var f_yaw := 0.0
var f_dist := 4.5
var f_h := 1.4
var f_look := 1.0
var f_lead := 0.0
var f_w := 0.5                           ## where between subject a and b the camera looks (0 = a)
var f_last := Vector3.ZERO                ## the last place the subject was seen (it may free itself: the camera holds)
var f_fov := 44.0
const DIST_K := 0.72                    ## every caller's distance is scaled by this: the subject fills the cell


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	t_start = Time.get_ticks_msec()
	headless = DisplayServer.get_name() == "headless"
	Travel._busy = true
	Travel.bosses_slain.clear()
	Travel.seals_broken.clear()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_root = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = Array(a.trim_prefix("--only=").split(",", false))
		elif a.begins_with("--timeout="):
			time_limit = float(a.trim_prefix("--timeout="))
		elif a.begins_with("--filter="):
			still_filter = Array(a.trim_prefix("--filter=").split(",", false))
		elif a == "--nolit":
			nolit = true
		elif a == "--lightlog":
			get_tree().node_removed.connect(_on_node_removed)
	if only.is_empty():
		only = ["horse"]
	# a new game would hold the spells back and the story's doors shut: stage the progress the panel should see
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 90, "relic_fragment": 2, "ember_shard": 7, "ash_bloom": 4, "grave_iron": 3, "charm_candle": 1, "thorn_heart": 1}
	# the summit opens to a peal: four of the Founder's bells answered for (as zz/raids_r34_shots does)
	var qb := preload("res://core/story/quest_book.gd")
	for bid: String in (preload("res://core/story/quest_chains.gd").BELLS as Array).slice(0, 4):
		qb.start(bid)
		qb.choose(bid, "rung")
	get_window().size = WIN
	DirAccess.make_dir_recursive_absolute(out_root)
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	process_physics_priority = 100              # after the actors, so the follow camera sees this tick's positions
	print("PLAYCAP start sections=", only, " out=", out_root, " headless=", headless)


## --lightlog: every light that leaves the tree, with where it was (tracks down the engine's "did not unpair" BUG).
func _on_node_removed(n: Node) -> void:
	if n is Light3D and n.is_inside_tree():
		var l := n as Light3D
		print("LIGHTFREE ", l.get_path(), " class ", l.get_class(), " at ", l.global_position, " scale ", l.global_basis.get_scale(), " vis ", l.visible, " shadow ", l.shadow_enabled)


func _process(delta: float) -> void:
	Travel._busy = true
	var el := float(Time.get_ticks_msec() - t_start) / 1000.0
	if el > time_limit + (60.0 if realm_s < 0.0 else 0.0) and started:
		print("PLAYCAP watchdog: ", sec, " ran out of time at ", snappedf(el, 0.1), " s")
		_fail("watchdog: the section ran out of time")
		_finish_section()
		_quit(2)
		return
	if el > 300.0:
		print("PLAYCAP never got a world")
		_quit(3)
		return
	if perf_on:
		if perf_skip > 0:
			perf_skip -= 1
		else:
			f_ms.append(delta * 1000.0)
			if delta > spike_s:
				spikes.append([_mark, snappedf(delta * 1000.0, 0.1)])
			f_dc.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
			f_pr.append(int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
	if not started and is_instance_valid(main) and main.has_meta("realm_done"):
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		if p == null:
			return
		if realm_s < 0.0:
			realm_s = el
			print("PLAYCAP realm built at ", snappedf(realm_s, 0.1), " s")
		if el - realm_s > 4.0:
			started = true
			_run.call_deferred()


func _physics_process(_d: float) -> void:
	if p != null and is_instance_valid(p):
		p.gloom = 0.0
		p.wounds = 0.0
	if f_on and cam1 != null:
		_place_cams()


func _quit(code: int) -> void:
	print("PLAYCAP quit ", code)
	if headless:
		get_tree().quit(code)
		return
	get_tree().quit(code)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void: OS.kill(OS.get_process_id()))


# ------------------------------------------------------------------------------------------------------
# the runner

func _run() -> void:
	_stage_world()
	_rigs()
	_find_studio()
	for s: Variant in only:
		sec = String(s)
		sec_dir = out_root.path_join(sec)
		DirAccess.make_dir_recursive_absolute(sec_dir)
		for old: String in DirAccess.get_files_at(sec_dir):          # a rerun leaves nothing stale behind
			if old.ends_with(".png"):
				DirAccess.remove_absolute(sec_dir.path_join(old))
		fails.clear()
		index.clear()
		f_ms.clear()
		f_dc.clear()
		f_pr.clear()
		perf_segs.clear()
		perf_on = true
		print("PLAYCAP section ", sec)
		match sec:
			"horse":
				await _s_horse()
			"wanderer":
				await _s_wanderer()
			"spells":
				await _s_spells()
			"villagers":
				await _s_villagers()
			"regions_a":
				await _s_regions(0, 16)
			"regions_b":
				await _s_regions(16, 99)
			"places":
				await _s_places()
			"ui":
				await _s_ui()
			"warmth":
				await _s_warmth()
			_:
				if ENEMY_SETS.has(sec):
					for kind: String in ENEMY_SETS[sec]:
						await _enemy_family(kind)
				elif BOSS_SETS.has(sec):
					for kind2: String in BOSS_SETS[sec]:
						await _boss_family(kind2)
				else:
					_fail("unknown section " + sec)
		_finish_section()
	_write_master_index()
	print("PLAYCAP done")
	_quit(0)


func _finish_section() -> void:
	perf_on = false
	_ui_show()
	_f_off()
	_release_inputs()
	_write_perf()
	var lines := PackedStringArray()
	lines.append("# harness-level failed steps for section %s (%d)" % [sec, fails.size()])
	lines.append_array(PackedStringArray(fails))
	_write_text(sec_dir.path_join("errors.txt"), "\n".join(lines) + "\n")
	var idx := PackedStringArray()
	idx.append("## %s" % sec)
	idx.append("")
	idx.append_array(PackedStringArray(index))
	_write_text(out_root.path_join("index_%s.md" % sec), "\n".join(idx) + "\n")
	print("PLAYCAP section ", sec, " done: ", index.size(), " files, ", fails.size(), " failed steps")


func _write_master_index() -> void:
	var parts := PackedStringArray()
	parts.append("# Play-through capture index")
	parts.append("")
	parts.append("Output root: `%s`. Every strip is a contact sheet: frames left to right, top to bottom, the time since the strip began printed small in each cell." % out_root)
	parts.append("`_side` is square-on, `_3q` is three-quarter from the front; both are the night grade. `_LIT` files are single stills with an ADDED lamp (not the game's lighting).")
	parts.append("")
	for s: String in SECTIONS:
		var f := out_root.path_join("index_%s.md" % s)
		if FileAccess.file_exists(f):
			parts.append(FileAccess.get_file_as_string(f))
	_write_text(out_root.path_join("index.md"), "\n".join(parts) + "\n")


func _fail(msg: String) -> void:
	var line := "[%s] %s" % [sec, msg]
	fails.append(line)
	print("PLAYCAP FAIL ", line)


func _idx(file: String, what: String) -> void:
	index.append("- `%s/%s` : %s" % [sec, file, what])


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("PLAYCAP cannot write ", path)
		return
	f.store_string(text)
	f.close()


# ------------------------------------------------------------------------------------------------------
# perf

func _perf_begin(label: String) -> void:
	_seg_label = label
	_seg_from = f_ms.size()


func _perf_end() -> void:
	if _seg_label != "":
		perf_segs.append([_seg_label, _seg_from, f_ms.size()])
	_seg_label = ""


static func _stats(ms: PackedFloat32Array, dc: PackedInt32Array, pr: PackedInt64Array, a: int, b: int) -> String:
	var n := b - a
	if n < 3:
		return "frames %d (too few)" % n
	var v := PackedFloat32Array()
	var dsum := 0.0
	var dmax := 0
	var psum := 0.0
	var pmax := 0
	for i in range(a, b):
		v.append(ms[i])
		dsum += float(dc[i])
		dmax = maxi(dmax, dc[i])
		psum += float(pr[i])
		pmax = maxi(pmax, pr[i])
	var sum := 0.0
	for x in v:
		sum += x
	var avg := sum / float(n)
	v.sort()
	var p99 := v[mini(n - 1, int(floor(float(n) * 0.99)))]
	return "frames %d  avg %.2f ms (%.0f fps)  1%%low %.2f ms (%.0f fps)  worst %.2f ms  draw calls avg %.0f max %d  primitives avg %.0f max %d" % [
		n, avg, 1000.0 / maxf(avg, 0.001), p99, 1000.0 / maxf(p99, 0.001), v[n - 1], dsum / float(n), dmax, psum / float(n), pmax]


func _write_perf() -> void:
	var s := PackedStringArray()
	s.append("section %s   (frames taken while a capture was in flight are left out)" % sec)
	s.append("(the display is vsynced: a floor of one refresh, 8.3 ms at 120 Hz)")
	s.append("realm build: world ready %.1f s after the process started (the engine's own 'REALM built in N ms' line is in the run log)" % realm_s)
	s.append("whole section: " + _stats(f_ms, f_dc, f_pr, 0, f_ms.size()))
	s.append("")
	for seg: Array in perf_segs:
		s.append("%-34s %s" % [seg[0], _stats(f_ms, f_dc, f_pr, int(seg[1]), int(seg[2]))])
	s.append("")
	s.append("frames over 20 ms (%d), by the last still or strip taken before them (a panel opened after a still shows under that still):" % spikes.size())
	var by := {}
	for sp: Array in spikes:
		var arr: Array = by.get(sp[0], [])
		arr.append(sp[1])
		by[sp[0]] = arr
	for k: String in by:
		s.append("  %-40s %s" % [k, str(by[k])])
	_write_text(sec_dir.path_join("perf.txt"), "\n".join(s) + "\n")


# ------------------------------------------------------------------------------------------------------
# stage and rigs

func _stage_world() -> void:
	for n: String in ["Encounters", "RoamEvents", "WorldEvents", "Rares"]:
		var x := main.find_child(n, true, false)
		if x:
			x.process_mode = Node.PROCESS_MODE_DISABLED
	book = p.skills()
	book.set("using_pad", true)                     # the book listens to keys only with the mouse captured or a pad
	_clear_enemies()
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		(a as Node).set_physics_process(false)      # no arena pulls a boss or shuts a gate while the stage is used elsewhere


func _clear_enemies() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not (n as Node).has_meta(&"cap"):
			(n as Node).queue_free()


func _clear_mine() -> void:
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (n as Node).has_meta(&"cap"):
			(n as Node).queue_free()
	for n in get_tree().get_nodes_in_group(&"cap_extra"):
		(n as Node).queue_free()


func _rigs() -> void:
	cam1 = Camera3D.new()
	cam1.fov = f_fov
	cam1.far = 700.0
	get_tree().root.add_child(cam1)
	cam1.make_current()
	lit_lamp = OmniLight3D.new()
	lit_lamp.light_color = Color(1.0, 0.9, 0.78)
	lit_lamp.light_energy = 5.0
	lit_lamp.omni_range = 40.0
	lit_lamp.shadow_enabled = false
	lit_lamp.visible = false
	get_tree().root.add_child(lit_lamp)
	vp2 = SubViewport.new()
	vp2.size = get_window().size
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp2.msaa_3d = get_viewport().msaa_3d
	vp2.scaling_3d_mode = get_viewport().scaling_3d_mode
	vp2.scaling_3d_scale = get_viewport().scaling_3d_scale
	get_tree().root.add_child(vp2)
	cam2 = Camera3D.new()
	cam2.fov = f_fov
	cam2.far = 700.0
	vp2.add_child(cam2)
	cam2.make_current()
	# the same grade on the second view (the Grade rect's own material: the zone keeps feeding it)
	var g := main.get_node_or_null("Grade/Rect") as ColorRect
	if g != null:
		var cl := CanvasLayer.new()
		cl.name = "GradeView2"
		var r := ColorRect.new()
		r.material = g.material
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(r)
		vp2.add_child(cl)
	else:
		_fail("no Grade rect found: the 3q view has no night grade")
	p.reset_physics_interpolation()


func _ui_hide() -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := c as CanvasLayer
		if String(cl.name).begins_with("Grade") or not cl.visible:
			continue
		_hidden_ui.append(cl)
		cl.visible = false


## The game's own camera (UI stills, talking) and our rig camera (strips, region stills).
func _cam_game() -> void:
	var gc := p.get("_cam") as Camera3D
	if gc != null:
		gc.make_current()


func _ui_show() -> void:
	for cl in _hidden_ui:
		if is_instance_valid(cl):
			cl.visible = true
	_hidden_ui.clear()


func _release_inputs() -> void:
	for a: String in ["jump", "dodge", "guard", "staff_strike", "slide", "sprint", "interact", "skill_bolt", "skill_lance", "skill_nova", "skill_ward", "skill_step"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)
	if p != null and is_instance_valid(p):
		p.debug_drive(Vector3.ZERO)


static func _dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func _yaw_of(v: Vector3) -> float:
	return atan2(-v.x, -v.z)


func _space() -> PhysicsDirectSpaceState3D:
	return p.get_world_3d().direct_space_state


func _gy(x: float, z: float) -> float:
	return RealmLayout.ground(_space(), x, z)


func _gp(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, _gy(x, z) + up, z)


func _flat_score(c: Vector2, rad: float) -> float:
	var lo := 1.0e9
	var hi := -1.0e9
	var pen := 0.0
	for ring: float in [0.0, rad * 0.5, rad]:
		for k in (1 if ring == 0.0 else 12):
			var a := TAU * float(k) / 12.0
			var q := c + Vector2(cos(a), sin(a)) * ring
			var y := _gy(q.x, q.y)
			lo = minf(lo, y)
			hi = maxf(hi, y)
			if RealmLand.in_water(q.x, q.y):
				pen += 40.0
			if LightGrid.is_lit(Vector3(q.x, y, q.y), true):
				pen += 30.0
			if not RealmLayout.BOUNDS.grow(-10.0).has_point(q):
				pen += 100.0
	return (hi - lo) + pen


func _find_studio() -> void:
	var best := Vector2(58.0, 18.0)
	var best_s := 1.0e9
	for c: Vector2 in [Vector2(58, 18), Vector2(70, 30), Vector2(45, 60), Vector2(95, 10), Vector2(30, -10), Vector2(110, 40), Vector2(20, 95),
			Vector2(150, 60), Vector2(-40, 30), Vector2(-100, 70), Vector2(60, 140), Vector2(-60, 110)]:
		var s := _flat_score(c, 14.0)
		if s < best_s:
			best_s = s
			best = c
	studio = _gp(best.x, best.y)
	studio_yaw = 0.0
	print("PLAYCAP studio at ", studio, " flat score ", snappedf(best_s, 0.01))
	if best_s > 2.5:
		_fail("studio %s is not flat/dark (score %.2f)" % [studio, best_s])
	# a long straight course for the horses
	var rbest := 1.0e9
	for c2: Vector2 in [Vector2(40, 20), Vector2(30, 60), Vector2(60, 15), Vector2(-20, 45), Vector2(20, 100), Vector2(-60, 70), Vector2(110, 30), Vector2(40, 130), Vector2(-90, 40)]:
		for k in 8:
			var yaw := TAU * float(k) / 8.0
			var d := _dir(yaw)
			var lo := 1.0e9
			var hi := -1.0e9
			var pen := 0.0
			for step in 21:
				var q := c2 + Vector2(d.x, d.z) * 4.0 * float(step)
				var y := _gy(q.x, q.y)
				lo = minf(lo, y)
				hi = maxf(hi, y)
				if RealmLand.in_water(q.x, q.y) or not RealmLayout.BOUNDS.grow(-10.0).has_point(q):
					pen += 40.0
				var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, y + 1.2, q.y), Vector3(q.x, y + 1.2, q.y) + d * 4.0, Layers.WORLD | Layers.PROPS))
				if not hit.is_empty():
					pen += 25.0
			var sc := (hi - lo) + pen
			if sc < rbest:
				rbest = sc
				runway = {"from": _gp(c2.x, c2.y), "yaw": yaw}
	print("PLAYCAP runway ", runway, " score ", snappedf(rbest, 0.01))
	if rbest > 6.0:
		_fail("no clean 80 m runway for the horses (best score %.1f)" % rbest)


# ------------------------------------------------------------------------------------------------------
# the follow camera and the capture

func _f_on(a: Node3D, yaw: float, dist: float, h: float, look: float, lead := 0.0, b: Node3D = null) -> void:
	f_a = a
	f_b = b
	f_yaw = yaw
	f_dist = dist * DIST_K
	f_h = h
	f_look = look
	f_lead = lead
	f_w = 0.5
	f_on = true
	cam1.make_current()
	f_last = a.global_position if is_instance_valid(a) else f_last
	_ui_hide()
	_place_cams()
	cam1.reset_physics_interpolation()
	cam2.reset_physics_interpolation()


func _f_off() -> void:
	f_on = false
	f_a = null
	f_b = null


func _centre() -> Vector3:
	var c := f_last
	if is_instance_valid(f_a) and is_instance_valid(f_b):
		c = f_a.global_position.lerp(f_b.global_position, f_w)
	elif is_instance_valid(f_a):
		c = f_a.global_position
	f_last = c
	return c + _dir(f_yaw) * f_lead


func _place_cams() -> void:
	var c := _centre()
	var b := Basis(Vector3.UP, f_yaw)
	var look := c + Vector3(0.0, f_look, 0.0)
	cam1.global_position = _unblocked(look, c + b * Vector3(f_dist, f_h, 0.0))
	cam1.look_at(look)
	cam2.global_position = _unblocked(look, c + b * Vector3(f_dist * 0.62, f_h * 1.05, -f_dist * 0.78))
	cam2.look_at(look)
	if absf(cam1.fov - f_fov) > 0.01:
		cam1.fov = f_fov
		cam2.fov = f_fov
	# keep the (hidden-from-nobody) player node near the camera so streaming and culling follow
	lit_lamp.global_position = c + Vector3(0.0, f_look + f_dist * 0.4, 0.0) + b * Vector3(f_dist * 0.8, 0.0, -f_dist * 0.3)


## A camera spot for `to` as seen from `from` (the look point): `to` itself if nothing stands between, else the same
## spot swung round the look point (up to 80 degrees either way) to the first clear line; failing that, pulled in
## front of the nearest wall, trunk or standing stone (walls and props both count).
func _unblocked(from: Vector3, to: Vector3) -> Vector3:
	var best := to
	var best_d := -1.0
	for deg: float in [0.0, 22.0, -22.0, 45.0, -45.0, 70.0, -70.0]:
		var q := from + (to - from).rotated(Vector3.UP, deg_to_rad(deg))
		# the middle line and one 1.4 m either side of the camera, so a trunk or stone beside the lens counts too
		var side := (q - from).cross(Vector3.UP).normalized() * 1.4
		var d := 1.0e9
		for off: Vector3 in [Vector3.ZERO, side, -side]:
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(from, q + off, Layers.WORLD | Layers.PROPS))
			if not hit.is_empty():
				d = minf(d, from.distance_to(hit.position))
		if d > 1.0e8:
			return q
		if d > best_d:
			best_d = d
			best = (from + (q - from).normalized() * (d - 0.5)) if d >= 2.0 else to
	return best


## Both views at once. Returns [side, 3q] images (null images headless).
func _grab() -> Array:
	if headless:
		await get_tree().process_frame
		return [null, null]
	vp2.render_target_update_mode = SubViewport.UPDATE_ONCE
	perf_skip = 3
	await RenderingServer.frame_post_draw
	var a: Image = get_viewport().get_texture().get_image()
	var b: Image = vp2.get_texture().get_image()
	return [a, b]


func _blank(img: Image) -> bool:
	if img == null:
		return false
	var lo := 1.0
	var hi := 0.0
	var w := img.get_width()
	var h := img.get_height()
	for iy in 6:
		for ix in 6:
			var l := img.get_pixel(int(float(w) * (0.1 + 0.16 * float(ix))), int(float(h) * (0.1 + 0.16 * float(iy)))).get_luminance()
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return hi - lo < 0.004


func _draw_text(img: Image, text: String, at: Vector2i, scale := 2) -> void:
	var w := text.length() * 6 * scale + 4
	var h := 7 * scale + 4
	for y in h:
		for x in w:
			var q := Vector2i(at.x + x, at.y + y)
			if q.x < img.get_width() and q.y < img.get_height():
				img.set_pixelv(q, img.get_pixelv(q) * 0.25)
	var x0 := at.x + 2
	for ch in text:
		var g: Array = GLYPHS.get(String(ch), GLYPHS[" "])
		for row in 7:
			var bits: String = g[row]
			for col in 5:
				if bits[col] == "1":
					for sy in scale:
						for sx in scale:
							var q2 := Vector2i(x0 + col * scale + sx, at.y + 2 + row * scale + sy)
							if q2.x < img.get_width() and q2.y < img.get_height():
								img.set_pixelv(q2, Color(1.0, 0.95, 0.75))
		x0 += 6 * scale


func _save_sheet(stem: String, frames: Array, times: Array, desc: String) -> void:
	if headless or frames.is_empty():
		return
	var n := frames.size()
	var rows := ceili(float(n) / float(COLS))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color.BLACK)
	for i in n:
		var im: Image = (frames[i] as Image).duplicate()
		im.convert(Image.FORMAT_RGB8)
		im.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		_draw_text(im, "#%d t=%.2fs" % [i, float(times[i])], Vector2i(4, 4))
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
	var file := stem + ".png"
	sheet.save_png(sec_dir.path_join(file))
	_idx(file, desc)


## N frames, `dt` apart, from now. `acts` is [[frame index, Callable], ...] run just before that frame is shot.
## Writes <stem>_side.png / <stem>_3q.png (the contact sheets) and one lit still of each view at mid strip.
func _strip(stem: String, n: int, dt: float, desc: String, acts: Array = []) -> void:
	_mark = stem
	_perf_begin(stem)
	var fs: Array = []
	var fq: Array = []
	var ts: Array = []
	var start := Time.get_ticks_msec()
	var lit_s: Image = null
	var lit_q: Image = null
	for k in n:
		var due := start + int(float(k) * dt * 1000.0)
		while Time.get_ticks_msec() < due:
			await get_tree().process_frame
		for a: Array in acts:
			if int(a[0]) == k:
				(a[1] as Callable).call()
		var g: Array = await _grab()
		ts.append(float(Time.get_ticks_msec() - start) / 1000.0)
		if g[0] != null:
			if _blank(g[0]):
				blank_run += 1
				if blank_run >= 4:
					_fail("blank frames: nothing is rendering; aborting the run")
					_finish_section()
					_quit(4)
					return
			else:
				blank_run = 0
			fs.append(g[0])
			fq.append(g[1])
		if k == n / 2 and not nolit and not headless:
			lit_lamp.visible = true
			var g2: Array = await _grab()
			lit_lamp.visible = false
			lit_s = g2[0]
			lit_q = g2[1]
	_perf_end()
	_save_sheet(stem + "_side", fs, ts, desc + " (side view, %d frames, %.2f s apart)" % [n, dt])
	_save_sheet(stem + "_3q", fq, ts, desc + " (three-quarter view, %d frames, %.2f s apart)" % [n, dt])
	if lit_s != null:
		lit_s.save_png(sec_dir.path_join(stem + "_side_LIT.png"))
		lit_q.save_png(sec_dir.path_join(stem + "_3q_LIT.png"))
		_idx(stem + "_side_LIT.png", desc + ": mid-strip still with an ADDED lamp (not the night grade)")
		_idx(stem + "_3q_LIT.png", desc + ": mid-strip three-quarter still with an ADDED lamp (not the night grade)")


## One still of the main view (HUD and all if the UI is showing).
func _still(file: String, desc: String, settle := 8) -> void:
	for i in settle:
		await get_tree().process_frame
		_mark = file
	if headless:
		return
	perf_skip = 3
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if _blank(img):
		blank_run += 1
		if blank_run >= 4:
			_fail("blank frames: nothing is rendering; aborting the run")
			_finish_section()
			_quit(4)
			return
		_fail("blank still " + file)
	else:
		blank_run = 0
	img.save_png(sec_dir.path_join(file))
	_idx(file, desc)


func _secs(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## True when `pred` came true within `timeout` seconds.
func _wait_until(pred: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if pred.call():
			return true
		await get_tree().process_frame
	return false


## The wanderer on the stage (or `at`), facing `yaw`, standing.
func _stand(at: Vector3, yaw: float) -> void:
	_release_inputs()
	p.teleport(at + Vector3.UP * 0.12)
	p.velocity = Vector3.ZERO
	p.set_view(yaw, -0.08)
	p._face_now(_dir(yaw))
	p.reset_physics_interpolation()
	if p.riding != null:
		p.riding.call("dismount")
	p.visible = true


func _spawn(kind: String, at: Vector3, face_to: Vector3) -> Enemy:
	var e := (load(SCRIPTS[kind]) as GDScript).new() as Enemy
	main.add_child(e)
	e.set_meta(&"cap", true)
	e.global_position = at + Vector3.UP * 0.1
	e.home = e.global_position
	var d := face_to - at
	d.y = 0.0
	if d.length() > 0.1:
		e.rotation.y = _yaw_of(d.normalized())
		e._face_dir = d.normalized()
	e.wake()
	return e


# ------------------------------------------------------------------------------------------------------
# HORSE

func _horse_of(breed: String) -> Node3D:
	for h in get_tree().get_nodes_in_group(&"horse"):
		if String(h.get("breed")) == breed:
			return h as Node3D
	return null


func _s_horse() -> void:
	_clear_enemies()
	var DB := preload("res://core/world/mount/horse_db.gd")
	var start: Vector3 = runway.get("from", studio)
	var ryaw: float = runway.get("yaw", 0.0)
	var fwd := _dir(ryaw)
	var first := true
	for breed: String in DB.ORDER:
		var h := _horse_of(breed)
		if h == null:
			_fail("no horse node for breed " + breed)
			continue
		var side := Vector3(fwd.z, 0.0, -fwd.x)
		h.global_position = start
		h.global_basis = Basis(Vector3.UP, ryaw)
		h.set("_yaw", ryaw)
		h.set("speed", 0.0)
		_stand(start - side * 1.1 + fwd * 0.2, ryaw)
		await _frames(30)
		h.global_position = start
		var sz: float = float(DB.BREEDS[breed].get("size", 1.0))
		_f_on(h, ryaw, 5.6 * sz, 1.6 * sz, 1.25 * sz, 0.9)
		if first:
			# mount: the step up, the foot in the stirrup, the swing over
			_strip("horse_%s_mount" % breed, 14, 0.1, "%s: mounting (step, stirrup, swing over, settle)" % breed, [[0, func() -> void: h.call("mount", p)]])
			await _secs(0.6)
			# walk, trot, gallop
			p.debug_drive(fwd * 0.5)
			await _secs(1.0)
			await _strip("horse_%s_walk" % breed, 12, 0.14, "%s: walk" % breed)
			p.debug_drive(fwd)
			await _secs(1.0)
			await _strip("horse_%s_trot" % breed, 14, 0.1, "%s: trot" % breed)
			p.debug_drive(fwd, true)
			await _secs(1.4)
			await _strip("horse_%s_gallop" % breed, 14, 0.07, "%s: gallop (stride cycle)" % breed)
			# a turn at a gallop: the wish swings 90 degrees to the left
			p.debug_drive(fwd.rotated(Vector3.UP, deg_to_rad(90.0)), true)
			await _strip("horse_%s_gallop_turn" % breed, 16, 0.1, "%s: turning left at a gallop (lean, hind legs, rider)" % breed)
			# back to the start for the jumps
			p.debug_drive(Vector3.ZERO)
			await _secs(1.2)
			h.global_position = start
			h.global_basis = Basis(Vector3.UP, ryaw)
			h.set("_yaw", ryaw)
			h.set("speed", 0.0)
			p.debug_drive(fwd)
			await _secs(1.2)
			await _strip("horse_%s_jump_trot" % breed, 12, 0.07, "%s: jump from a trot (gather, push-off, air, landing)" % breed, [[1, func() -> void: h.call("try_jump")]])
			await _secs(0.8)
			p.debug_drive(fwd, true)
			await _secs(1.5)
			await _strip("horse_%s_jump_gallop" % breed, 14, 0.07, "%s: jump from a gallop" % breed, [[1, func() -> void: h.call("try_jump")]])
			await _secs(0.8)
			# the landing on its own, finer: wait for the descent of a fresh leap
			p.debug_drive(fwd, true)
			await _secs(0.9)
			h.call("try_jump")
			var fell: bool = await _wait_until(func() -> bool: return bool(h.get("_air")) and float(h.get("_vy")) < -1.0, 2.0)
			if not fell:
				_fail("%s: the leap never reached its descent; landing strip taken anyway" % breed)
			await _strip("horse_%s_landing" % breed, 12, 0.05, "%s: the landing from a gallop leap (squat, dust)" % breed)
			p.debug_drive(Vector3.ZERO)
			await _secs(1.6)
			# dismount
			await _strip("horse_%s_dismount" % breed, 10, 0.1, "%s: getting down" % breed, [[1, func() -> void: p.mount.get_down()]])
			first = false
		else:
			h.call("mount", p)
			await _secs(1.4)
			p.debug_drive(fwd, true)
			await _secs(1.6)
			await _strip("horse_%s_gallop" % breed, 14, 0.07, "%s: gallop (stride cycle)" % breed)
			p.debug_drive(Vector3.ZERO)
			await _secs(1.0)
			h.call("dismount")
		p.debug_drive(Vector3.ZERO)
		if p.riding != null:
			h.call("dismount")
		await _secs(0.4)
	_f_off()


# ------------------------------------------------------------------------------------------------------
# WANDERER

const SKILLS := {
	"bolt": "res://core/skills/skill_bolt.gd", "lance": "res://core/skills/skill_lance.gd", "nova": "res://core/skills/skill_nova.gd",
	"ward": "res://core/skills/skill_ward.gd", "step": "res://core/skills/skill_step.gd", "tether": "res://core/skills/skill_tether.gd",
	"well": "res://core/skills/skill_well.gd", "familiar": "res://core/skills/skill_familiar.gd", "peal": "res://core/skills/skill_peal.gd",
}


func _s_wanderer() -> void:
	_clear_enemies()
	var fwd := _dir(studio_yaw)
	_stand(studio, studio_yaw)
	_f_on(p, studio_yaw, 5.4, 1.3, 0.95)
	await _secs(1.5)
	await _strip("wanderer_idle", 16, 0.3, "the wanderer standing (idle, breathing, idle gestures)")
	_stand(studio, studio_yaw)
	p.debug_drive(fwd * 0.99)
	await _secs(0.8)
	await _strip("wanderer_walk", 16, 0.07, "the wanderer walking (stride cycle)")
	p.debug_drive(fwd, true)
	await _secs(0.8)
	await _strip("wanderer_sprint", 16, 0.06, "the wanderer sprinting (stride, lean, staff trail)")
	# jump from a stand, then a double jump
	_stand(studio, studio_yaw)
	await _secs(0.6)
	await _strip("wanderer_jump", 16, 0.06, "jump from a stand: crouch, rise, apex, fall, landing", [[1, func() -> void: Input.action_press("jump")], [3, func() -> void: Input.action_release("jump")]])
	_stand(studio, studio_yaw)
	p.debug_drive(fwd)
	await _secs(0.6)
	await _strip("wanderer_jump_run", 16, 0.06, "running jump, and a second (air) jump at frame 7", [[1, func() -> void: Input.action_press("jump")], [2, func() -> void: Input.action_release("jump")],
		[7, func() -> void: Input.action_press("jump")], [8, func() -> void: Input.action_release("jump")]])
	_stand(studio, studio_yaw)
	p.debug_drive(fwd)
	await _secs(0.6)
	await _strip("wanderer_dodge", 14, 0.06, "dodge roll while moving", [[1, func() -> void: Input.action_press("dodge")], [2, func() -> void: Input.action_release("dodge")]])
	_stand(studio, studio_yaw)
	await _secs(0.8)
	# the staff: a light chain (two taps) then a heavy
	var dummy := _dummy(studio + fwd * 2.0)
	_stand(studio, studio_yaw)
	await _secs(0.6)
	await _strip("wanderer_staff_light", 16, 0.07, "staff strike, light chain (taps at frames 1 and 6) on a standing target", [
		[1, func() -> void: Input.action_press("staff_strike")], [2, func() -> void: Input.action_release("staff_strike")],
		[6, func() -> void: Input.action_press("staff_strike")], [7, func() -> void: Input.action_release("staff_strike")]])
	await _secs(1.0)
	await _strip("wanderer_staff_heavy", 18, 0.1, "staff strike, heavy: draw (held 1.1 s from frame 1) then the blow", [
		[1, func() -> void: Input.action_press("staff_strike")], [11, func() -> void: Input.action_release("staff_strike")]])
	if is_instance_valid(dummy):
		dummy.queue_free()
	# the parry: a wretch rears up, the guard goes up as it does
	_stand(studio, studio_yaw)
	var w := _spawn("wretch", studio + fwd * 2.2, studio)
	w.max_hp = 9999
	w.hp = 9999.0
	if w.has_method("on_engaged"):
		w.call("on_engaged", p)
	await _wait_until(func() -> bool: return is_instance_valid(w) and int(w.get("_state")) == Enemy.WINDUP, 8.0)
	_f_on(p, studio_yaw, 6.0, 1.35, 1.0, 1.0)
	await _strip("wanderer_guard_parry", 14, 0.07, "guard raised as a wretch winds up (first instant parries); the foe's blow", [
		[0, func() -> void: Input.action_press("guard")], [10, func() -> void: Input.action_release("guard")]])
	_clear_mine()
	# a wound: what the hit looks like on the wanderer
	_stand(studio, studio_yaw)
	_f_on(p, studio_yaw, 5.4, 1.3, 0.95)
	await _secs(0.8)
	await _strip("wanderer_hurt", 14, 0.07, "taking a wound from the front (hurt reaction)", [[1, func() -> void: p.take_wound(8.0, p.global_position + fwd * 2.0)]])
	_f_off()
	_stand(studio, studio_yaw)


func _s_spells() -> void:
	_clear_enemies()
	await _spells(_dir(studio_yaw))
	# kindling a brazier, lighting a lamp
	await _kindle()
	await _lamp()
	_f_off()
	_stand(studio, studio_yaw)


func _dummy(at: Vector3) -> Enemy:
	var t := Husk.new()
	main.add_child(t)
	t.set_meta(&"cap", true)
	t.global_position = at + Vector3.UP * 0.1
	t.set("max_hp", 99999)
	t.set("hp", 99999.0)
	t.set_physics_process(false)
	t.set_process(false)
	return t


func _slot(i: int, id: String) -> void:
	var sk := (load(SKILLS[id]) as GDScript).new() as Skill
	book.set_slot(i, sk)
	book.reset_cooldowns()


func _spells(fwd: Vector3) -> void:
	var tgt := _dummy(studio + fwd * 9.0)
	var cases := [
		["bolt", 0, "Rift Bolt", 14, 0.06, 4.8, 0.0, "tap"], ["lance_tap", 1, "Ember Lance, tapped (uncharged)", 14, 0.07, 4.8, 0.0, "tap"],
		["lance_full", 1, "Ember Lance, held to full charge then released", 20, 0.1, 4.8, 0.0, "hold"], ["nova", 2, "Nova", 14, 0.07, 5.5, 0.0, "tap"],
		["ward", 3, "Lantern Ward", 14, 0.1, 5.0, 0.0, "tap"], ["step", 4, "Shadowstep", 12, 0.05, 5.8, 3.0, "tap"],
		["tether", 1, "Tether", 14, 0.07, 5.5, 0.0, "tap"], ["well", 2, "Umbral Well", 16, 0.15, 6.0, 4.0, "tap"],
		["familiar", 3, "Bound Shade (familiar)", 16, 0.15, 5.0, 0.0, "tap"], ["peal", 3, "Founder's Peal", 14, 0.07, 5.5, 0.0, "tap"]]
	for c: Array in cases:
		var id := String(c[0]).split("_")[0]
		var slot := int(c[1])
		_stand(studio, studio_yaw)
		for n in get_tree().get_nodes_in_group(&"bound_shade"):
			(n as Node).queue_free()
		_slot(slot, id)
		_f_on(p, studio_yaw, float(c[5]) * 1.3, 1.6, 1.4, 1.8 + float(c[6]) * 0.3)
		await _secs(0.7)
		var act: String = (book.slots[slot] as Skill).action
		var acts: Array = []
		if String(c[7]) == "hold":
			acts = [[1, func() -> void: Input.action_press(act)], [14, func() -> void: Input.action_release(act)]]
		elif id == "lance":
			acts = [[1, func() -> void: Input.action_press(act)], [2, func() -> void: Input.action_release(act)]]
		else:
			acts = [[1, func() -> void: _cast(slot)]]
		await _strip("wanderer_cast_%s" % String(c[0]), int(c[3]), float(c[4]), "casting " + String(c[2]), acts)
		await _secs(0.5)
		if book.get("_charging") != null and int(book.get("_charging")) >= 0:
			book.call("_cancel_charge")
	if is_instance_valid(tgt):
		tgt.queue_free()
	for n2 in get_tree().get_nodes_in_group(&"bound_shade"):
		(n2 as Node).queue_free()


func _cast(slot: int) -> void:
	book.reset_cooldowns()
	if not book.try_cast(slot, 0.0, false):
		_fail("the spell in slot %d would not cast (%s)" % [slot, (book.slots[slot] as Skill).id])


func _nearest(group: StringName, pred: Callable) -> Node3D:
	var best: Node3D = null
	var bd := 1.0e9
	for n in get_tree().get_nodes_in_group(group):
		var q := n as Node3D
		if q == null or not pred.call(q):
			continue
		var d := q.global_position.distance_to(studio)
		if d < bd:
			bd = d
			best = q
	return best


func _kindle() -> void:
	var b: Node3D = null
	var bd := 1.0e9
	for n in main.find_children("*", "Brazier", true, false):
		var q := n as Brazier
		if q != null and not q.lit and q.visible:
			var d := q.global_position.distance_to(studio)
			if d < bd:
				bd = d
				b = q
	if b == null:
		_fail("no unlit brazier to kindle")
		return
	var away := Vector3(1.0, 0.0, 0.3).normalized()
	var at := b.global_position + away * 1.9
	var yaw := _yaw_of(-away)
	_stand(_gp(at.x, at.z), yaw)
	_f_on(p, yaw, 4.4, 1.5, 1.0, 1.2)
	await _secs(2.0)
	await _strip("wanderer_kindle_brazier", 16, 0.12, "kindling an unlit brazier (reach, cast, the flame catches)", [[2, func() -> void:
		p._visual.cast()
		(b as Brazier).interact(p)]])


func _lamp() -> void:
	var l: Node3D = null
	var bd := 1.0e9
	for n in get_tree().get_nodes_in_group(&"lamp"):
		var q := n as Lamp
		if q != null and not q.lit and q.visible and String(q.look) in ["post", "niche", "hang"]:
			var d := q.global_position.distance_to(studio)
			if d < bd:
				bd = d
				l = q
	if l == null:
		_fail("no unlit lamp to light")
		return
	var away := Vector3(0.0, 0.0, 1.0)
	var at := l.global_position + away * 1.7
	var yaw := _yaw_of(-away)
	_stand(_gp(at.x, at.z), yaw)
	_f_on(p, yaw, 4.0, 1.5, 1.2, 1.0)
	await _secs(2.0)
	await _strip("wanderer_light_lamp", 14, 0.12, "lighting a lamp (look: %s)" % String((l as Lamp).look), [[2, func() -> void:
		p._visual.cast()
		(l as Lamp).interact(p)]])


# ------------------------------------------------------------------------------------------------------
# ENEMIES

func _enemy_family(kind: String) -> void:
	_clear_enemies()
	_clear_mine()
	var fwd := _dir(studio_yaw)
	var dist: float = float(RANGED.get(kind, 3.6))
	if kind == "shade":
		await _shade_family()
		return
	_stand(studio, studio_yaw)
	var epos := studio + fwd * dist
	# --- idle: awake, not hunting
	var e := _spawn(kind, epos, studio)
	e.chase_range = 0.0
	e.can_call = false
	await _frames(20)
	var h: float = maxf(e.hp_bar_y, 1.0)
	var toward := _yaw_of(studio - epos)
	_f_on(e, toward, clampf(h * 2.7, 4.0, 14.0), h * 0.55, h * 0.45)
	await _secs(0.6)
	await _strip("%s_idle" % kind, 14, 0.25, "%s awake and idle (not hunting)" % kind)
	e.queue_free()
	await _frames(6)
	# --- chase / walk: from 9 m in
	var start := studio + fwd * 9.5
	e = _spawn(kind, start, studio)
	e.max_hp = 9999
	e.hp = 9999.0
	e.chase_range = 40.0
	if e.has_method("on_engaged"):
		e.call("on_engaged", p)
	_f_on(e, _yaw_of(studio - start), clampf(h * 2.9, 4.5, 15.0), h * 0.55, h * 0.45, 1.5)
	var dur := clampf(8.0 / maxf(e.walk_speed, 1.0), 1.4, 3.2)
	await _strip("%s_chase" % kind, 14, dur / 14.0, "%s hunting the wanderer (walk/run toward, 9 m start)" % kind)
	e.queue_free()
	await _frames(6)
	# --- attack: the wind-up and the strike (or the cast / pounce / volley)
	_stand(studio, studio_yaw)
	e = _spawn(kind, epos, studio)
	e.max_hp = 9999
	e.hp = 9999.0
	e.chase_range = 40.0
	if e.has_method("on_engaged"):
		e.call("on_engaged", p)
	var pivot_d := clampf(h * 2.2 + dist * 0.75, 6.0, 20.0)
	_f_on(e, _yaw_of(studio - epos), pivot_d, 1.6 + h * 0.3, 1.0, 0.0, p)
	if dist > 6.0:
		f_w = 0.3                                    # a shooter: it fills the frame, the shot and the wanderer still in it
		f_dist = clampf(h * 1.6 + 7.0, 8.0, 14.0) * DIST_K
	var got: bool = await _wait_until(func() -> bool: return is_instance_valid(e) and _attacking(e), 9.0)
	if not got:
		_fail("%s never started an attack in 9 s (state %s); strip taken from here" % [kind, str(e.get("_state"))])
	await _strip("%s_attack" % kind, 16, 0.07, "%s attack: wind-up telegraph then the strike / cast, and the recovery" % kind)
	e.queue_free()
	await _frames(6)
	# --- hit reaction and stagger
	_stand(studio, studio_yaw)
	e = _spawn(kind, epos, studio)
	e.max_hp = 9999
	e.hp = 9999.0
	e.chase_range = 0.0
	e.can_call = false
	e.can_flee = false
	await _frames(20)
	_f_on(e, _yaw_of(studio - epos), clampf(h * 2.7, 4.0, 14.0), h * 0.55, h * 0.45, 0.0, p if dist < 5.0 else null)
	await _strip("%s_hit_stagger" % kind, 16, 0.1, "%s: a light hit (frame 2) then a staggering blow (frame 7)" % kind, [
		[2, func() -> void: if is_instance_valid(e): e.take_hit(0.8, p)],
		[7, func() -> void: if is_instance_valid(e): e.take_hit(e.poise + 1.5, p)]])
	e.queue_free()
	await _frames(6)
	# --- death
	e = _spawn(kind, epos, studio)
	e.chase_range = 0.0
	e.can_call = false
	await _frames(20)
	_f_on(e, _yaw_of(studio - epos), clampf(h * 2.7, 4.0, 14.0), h * 0.55, h * 0.45, 0.0)
	await _strip("%s_death" % kind, 18, 0.14, "%s dying (collapse, dissolve)" % kind, [[2, func() -> void: if is_instance_valid(e): e.take_hit(99999.0, p)]])
	_clear_mine()
	_f_off()


func _attacking(e: Enemy) -> bool:
	var s: int = e._state
	return s in [Enemy.WINDUP, Enemy.LEAP_PREP, Enemy.AIRBORNE, Enemy.FEINT, Enemy.SPECIAL, Enemy.CALL, Enemy.STRIKE] or e.cast_name != ""


## The Shade is not an Enemy: a six-metre shroud that drifts at you and is unmade by light.
func _shade_family() -> void:
	var fwd := _dir(studio_yaw)
	for take in [true, false]:
		_stand(studio, studio_yaw)
		await _secs(0.5)
		var s := Shade.new()
		main.add_child(s)
		s.set_meta(&"cap", true)
		s.add_to_group(&"cap_extra")
		s.target = p
		s.global_position = studio + fwd * (16.0 if take else 12.0) + Vector3.UP * Shade.HOVER
		p._shade = s
		_f_on(s, _yaw_of(studio - s.global_position), 12.0, 3.5, 3.2, 3.0, p)
		await _secs(0.6)
		if take:
			await _strip("shade_approach_and_take", 20, 0.14, "the Hollow Shade arriving from 16 m (drift, presence, tremble) and taking the wanderer (hollowing)")
			await _wait_until(func() -> bool: return not bool(p.get("_hollowing")), 10.0)
			await _secs(1.0)
		else:
			await _strip("shade_unmade_by_light", 16, 0.12, "the Shade unmade by light (called off at frame 3)", [[3, func() -> void: if is_instance_valid(s): s.unmake_by_light()]])
		_clear_mine()
		p._shade = null
	_f_off()
	index.append("- (shade) : no separate idle/hit/attack strips: it only drifts, takes and is unmade by light; bolts pass through it")


# ------------------------------------------------------------------------------------------------------
# BOSSES

func _boss_family(kind: String) -> void:
	_clear_enemies()
	_clear_mine()
	var fwd := _dir(studio_yaw)
	_stand(studio, studio_yaw)
	var b: Enemy = null
	if ARENA_BOSSES.has(kind):
		# the real arena (its room gives the body its rise and the fight its floor), as zz/raids_r34_shots does it
		b = await _arena_boss(String(ARENA_BOSSES[kind][0]), String(ARENA_BOSSES[kind][1]))
		if b == null:
			_fail("%s: the arena never started the fight; staged in the open instead" % kind)
	if b == null:
		var bpos0 := studio + fwd * 6.5
		var stub := Node3D.new()
		main.add_child(stub)
		stub.add_to_group(&"cap_extra")
		stub.global_position = studio + fwd * 5.0
		b = _spawn(kind, bpos0, studio)
		if kind != "tally_reliquary":
			b.set_meta(&"boss_id", kind)
		b.set_meta(&"display_name", kind)
		if b.has_method("on_engaged"):
			b.call("on_engaged", stub)
	var stand_at := p.global_position
	await _frames(20)
	if not is_instance_valid(b):
		_fail("%s: the boss was gone 20 frames after the pull (the arena reset it?)" % kind)
		return
	var h: float = maxf(b.hp_bar_y, 2.0)
	print("PLAYCAP boss ", kind, " at ", b.global_position, " hp_bar_y ", snappedf(h, 0.1), " visible ", b.visible, " arena ", ARENA_BOSSES.has(kind))
	var d := clampf(h * 2.2 + (8.0 if ARENA_BOSSES.has(kind) else 3.0), 8.0, 40.0)
	_f_on(b, _yaw_of(p.global_position - b.global_position), d, h * 0.55, h * 0.45, 0.0, p)
	f_w = 0.28 if ARENA_BOSSES.has(kind) else 0.12   # the boss fills the frame; the wanderer stays at its edge
	# idle / intro
	await _strip("%s_intro_idle" % kind, 16, 0.2, "%s: the intro (shelled, rising) and standing idle" % kind)
	var moves: Array = BOSS_MOVES.get(kind, [])
	if moves.is_empty():
		await _strip("%s_natural" % kind, 16, 0.25, "%s: its own behaviour for 4 s (no scripted signature move: it has none)" % kind)
	for m: Array in moves:
		if not is_instance_valid(b) or not b.is_alive():
			_fail("%s died or vanished before %s" % [kind, m[0]])
			break
		var ratio := float(m[4])
		var move := String(m[1])
		var args: Array = m[2]
		if ratio > 0.0:
			# the phase change: set the life below the mark and watch the transition play
			b.set("_sig", 2)
			b.hp = float(b.max_hp) * ratio
			b._ward_t = 0.0
			await _strip("%s_%s_phase_change" % [kind, String(m[0]).split("_")[0]], 18, 0.25, "%s: phase change (life set to %d%%), the transition and what it does" % [kind, int(ratio * 100.0)])
			await _secs(1.0)
		b._ward_t = 0.0
		b._broken_t = 0.0
		b.cancel_moves()                          # the last move's zones must not bleed into this strip
		if p != null and not ARENA_BOSSES.has(kind):
			p.global_position = stand_at
		if not b.has_method(move):
			_fail("%s has no method %s" % [kind, move])
			continue
		var n := 16
		var dt := maxf(float(m[3]) / float(n), 0.06)
		await _strip("%s_%s" % [kind, String(m[0])], n, dt, "%s: %s (telegraph and landing)" % [kind, String(m[0]).replace("_", " ")],
			[[0, func() -> void: if is_instance_valid(b): b.callv(move, args)]])
		await _secs(0.6)
	_clear_mine()
	_f_off()
	# the boss arenas as built (stills; the fights are staged in the open above)
	if kind in ["thornwarden", "bone_abbot", "ascended_warden", "anchoress", "hierarch_voice"]:
		await _arena_stills(kind)


## The boss of arena `key` fought in its own arena: the seal guards go down, the wanderer walks in, the arena pulls
## the boss (null if it never does).
func _arena_boss(key: String, seal: String) -> Enemy:
	if key == "bone_abbot":
		Travel.bosses_slain.erase("bone_abbot")
	else:
		Travel.bosses_slain["bone_abbot"] = true
	if key == "ascended_warden":
		Travel.bosses_slain["thornwarden"] = true
	for sp in get_tree().root.find_children("EnemySpawner", "", true, false) if seal != "" else []:
		for slot: Variant in sp._slots:
			var pawn: Variant = slot.get("pawn")
			if String(slot.get("seal", "")) == seal and is_instance_valid(pawn) and pawn is Enemy:
				(pawn as Enemy).take_hit(999.0)
	var arena: BossArena = null
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id.contains(key):
			arena = a as BossArena
	if arena == null:
		return null
	arena.set_physics_process(true)
	var c := arena.global_position
	var gout := Vector3(0.0, 0.0, 1.0)
	var gate := arena.gate as Node3D
	if gate != null:
		gout = gate.global_position - c
		gout.y = 0.0
		gout = gout.normalized()
	var at := c + gout * 12.0
	if key == "bone_abbot":
		at = Ossuary.abbot_pull_at()               # on the pit hall's floor, past the raid door
	var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 8.0, Layers.WORLD, [p.get_rid()]))
	if not hit.is_empty():
		at = hit.position
	# as in play, the arena warms the boss's moves and rig as the wanderer nears, a while before the pull
	var far := c + gout * (arena.radius + 14.0)
	far.y = c.y + 0.5
	_mark = "approach " + key
	_stand(far, _yaw_of(c - far))
	await _secs(2.0)
	_mark = "pull " + key
	_stand(at, _yaw_of(c - at))
	var box: Array = []
	await _wait_until(func() -> bool:
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if String((e as Node).get_meta(&"boss_id", "")) == arena.boss_id and (e as Enemy).is_alive() and not (e as Node).is_queued_for_deletion():
				box.append(e)
				return true
		return false, 8.0)
	return (box[0] as Enemy) if not box.is_empty() else null


func _arena_stills(kind: String) -> void:
	_ui_hide()
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var ar := a as BossArena
		if ar == null or not ar.boss_id.contains(kind.split("_")[0]):
			continue
		var c := ar.global_position
		var r := maxf(ar.radius, 12.0)
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.visible = false
		var k := 0
		for v: Array in [[Vector3(r * 1.3, r * 0.9, r * 1.3), Vector3(0, 2, 0)], [Vector3(-r * 1.5, 3.0, 0), Vector3(0, 3, 0)]]:
			cam1.global_position = c + (v[0] as Vector3)
			cam1.look_at(c + (v[1] as Vector3))
			p.global_position = cam1.global_position - Vector3.UP * 1.5
			p.reset_physics_interpolation()
			await _secs(1.4)
			await _still("%s_arena_%d.png" % [kind, k], "%s: its arena as built (%s view)" % [kind, "high" if k == 0 else "floor"])
			k += 1
		p.process_mode = Node.PROCESS_MODE_INHERIT
		p.visible = true
		return
	var ids: Array[String] = []
	for a2 in get_tree().get_nodes_in_group(&"boss_arena"):
		ids.append(String((a2 as BossArena).boss_id))
	_fail("no BossArena found for %s (have %s)" % [kind, ids])


# ------------------------------------------------------------------------------------------------------
# VILLAGERS

func _s_villagers() -> void:
	_clear_enemies()
	var v := main.find_child("Village", true, false)
	if v == null:
		_fail("no Village node")
		return
	_stand(Vector3(6.0, _gy(6.0, 40.0), 40.0), 0.0)
	p.visible = true
	await _secs(2.5)
	# a villager on a route: scan the night's phases for one walking, then follow it
	var walker: Node3D = null
	for ph in [0.16, 0.3, 0.45, 0.6, 0.75, 0.9]:
		v.set("clock", float(ph) * 600.0)
		await _secs(2.5)
		for n in get_tree().get_nodes_in_group("villager"):
			if String(n.get("state")) == "walk" and (n as Node3D).global_position.distance_to(p.global_position) < 40.0:
				walker = n as Node3D
				break
		if walker != null:
			break
	if walker != null:
		var wv := walker
		var d := p.global_position.distance_to(wv.global_position)
		_stand(wv.global_position + Vector3(4.0, 0.0, 6.0), 0.0)
		var heading: Vector3 = Vector3(wv.get("path")[mini(int(wv.get("path_i")), (wv.get("path") as PackedVector3Array).size() - 1)]) - wv.global_position if (wv.get("path") as PackedVector3Array).size() > 0 else Vector3.FORWARD
		heading.y = 0.0
		_f_on(wv, _yaw_of(heading.normalized()) if heading.length() > 0.1 else 0.0, 4.6, 1.4, 1.0, 0.8)
		await _strip("villager_walk_%s" % String(wv.get("id")), 16, 0.3, "villager %s walking its route (%.0f m from the wanderer at the start)" % [String(wv.get("id")), d])
	else:
		_fail("no villager was walking in any phase of the night")
	# one at a routine stop: hammer / chop / dig / grind
	var worker: Node3D = null
	for ph2 in [0.3, 0.45, 0.6, 0.16, 0.75]:
		v.set("clock", float(ph2) * 600.0)
		await _secs(3.0)
		for n2 in get_tree().get_nodes_in_group("villager"):
			if String(n2.get("act")) in ["hammer", "chop", "dig", "grind", "tend", "garden", "bury", "chalk"] and String(n2.get("state")) == "act":
				worker = n2 as Node3D
				break
		if worker != null:
			break
	if worker != null:
		var wk := worker
		_stand(wk.global_position + Vector3(2.0, 0.0, 6.0), 0.0)
		await _secs(1.0)
		_f_on(wk, _yaw_of(p.global_position - wk.global_position), 4.0, 1.4, 1.0)
		await _strip("villager_work_%s_%s" % [String(wk.get("id")), String(wk.get("act"))], 16, 0.25, "villager %s working at a routine stop (%s)" % [String(wk.get("id")), String(wk.get("act"))])
	else:
		_fail("no villager was at a working stop in any phase")
	# talking: the dialogue box with its portrait, typing
	_f_off()
	_ui_show()
	_cam_game()
	var story := get_tree().get_first_node_in_group("story")
	var shot := 0
	for n3 in get_tree().get_nodes_in_group("villager"):
		if shot >= 3:
			break
		if not bool(n3.call("can_interact")):
			continue
		_stand((n3 as Node3D).global_position + Vector3(0.0, 0.0, 2.2), 0.0)
		p.set_view(_yaw_of((n3 as Node3D).global_position - p.global_position), -0.05)
		n3.call("interact", p)
		await _secs(1.2)
		await _still("villager_talk_%d_%s_a.png" % [shot, String(n3.get("id"))], "dialogue box and portrait, line typing (%s)" % String(n3.get("id")))
		await _secs(0.4)
		await _still("villager_talk_%d_%s_b.png" % [shot, String(n3.get("id"))], "same, a moment later (mouth moves while the line types)")
		var ui: Variant = story.get("ui") if story != null else null
		if ui != null:
			(ui as CanvasLayer).call("close")
		await _frames(8)
		shot += 1
	if shot == 0:
		_fail("no villager could be talked to")
	_ui_hide()
	# a watchman fighting: assault a watch post
	await _watchman()


func _watchman() -> void:
	var post: Node3D = null
	for n in get_tree().get_nodes_in_group(&"watch_post"):
		post = n as Node3D
		break
	if post == null:
		_fail("no watch post")
		return
	var base := post.global_position
	var side := (post.get("face") as Vector3).cross(Vector3.UP).normalized()
	_stand(_gp(base.x + side.x * 8.0, base.z + side.z * 8.0), studio_yaw)
	var ok: bool = await _wait_until(func() -> bool: return not (post.get("men") as Array).is_empty(), 8.0)
	if not ok:
		_fail("the watch post never woke its men")
		return
	await _secs(1.5)
	var man: Node3D = (post.get("men") as Array)[0]
	post.call("_assault")
	_f_on(man, _yaw_of(post.get("face") as Vector3) + PI * 0.5, 7.0, 2.2, 1.0, 3.0)
	await _secs(3.5)
	await _strip("watchman_fight", 18, 0.3, "the Kindled Watch at %s: watchmen meeting an assault blade to blade (the dark comes from the front of the post)" % String(post.get("id")))
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if (e as Node).has_meta(&"watch"):
			(e as Node).queue_free()
	_f_off()


# ------------------------------------------------------------------------------------------------------
# STILLS: regions, vistas, settlements, arenas

func _park_at(cam_pos: Vector3, target: Vector3) -> void:
	cam1.make_current()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.visible = false
	cam1.global_position = cam_pos
	cam1.look_at(target)
	p.global_position = Vector3(cam_pos.x, _gy(cam_pos.x, cam_pos.z) + 0.1, cam_pos.z)
	p.reset_physics_interpolation()


func _unpark() -> void:
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.visible = true


func _view_still(file: String, desc: String, cam_pos: Vector3, target: Vector3) -> void:
	if not still_filter.is_empty() and not still_filter.any(func(f: Variant) -> bool: return file.contains(String(f))):
		return
	_park_at(cam_pos, target)
	await _secs(1.3)
	_park_at(cam_pos, target)
	var beams := ""
	for b in get_tree().get_nodes_in_group(&"landmark_beacon"):
		var gl := b.get_node_or_null("FarGlow") as MeshInstance3D
		if gl != null and gl.is_visible_in_tree():
			beams += " %s@%.0f(a%.2f s%.1f vr%.0f lay%d at %s)" % [b.name, cam_pos.distance_to(b.get("anchor")), (gl.material_override as StandardMaterial3D).albedo_color.a, gl.scale.x, gl.visibility_range_end, gl.layers, gl.global_position]
	print("PLAYCAP far glows in %s:%s" % [file, beams if beams != "" else " none"])
	await _still(file, desc, 4)


## The two clearest night views of a region: eye height, from a ring around its centre looking in.
func _region_views(r: Dictionary) -> Array:
	var c: Vector2
	var rad: float
	if r.has("rect"):
		var rc: Rect2 = r.rect
		c = rc.get_center()
		rad = clampf(maxf(rc.size.x, rc.size.y) * 0.22, 14.0, 42.0)
	else:
		c = r.c
		rad = clampf(float(r.r) * 0.8, 12.0, 34.0)
	var tg := _gp(c.x, c.y, 3.0)
	var cand: Array = []
	for k in 12:
		var a := TAU * float(k) / 12.0
		for mult in [1.0, 1.5]:
			var q := c + Vector2(cos(a), sin(a)) * rad * float(mult)
			if not RealmLayout.BOUNDS.grow(-6.0).has_point(q):
				continue
			var pos := _gp(q.x, q.y, 2.6)
			if _eye_buried(pos):
				continue
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(pos, tg, Layers.WORLD))
			var clear := 1.0
			if not hit.is_empty():
				clear = pos.distance_to(hit.position) / maxf(pos.distance_to(tg), 0.1)
			var sc := clear - absf(pos.y - tg.y) * 0.02 - (0.3 if RealmLand.in_water(q.x, q.y) else 0.0)
			cand.append([sc, pos, a])
	cand.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out: Array = []
	for cd: Array in cand:
		var ok := true
		for o: Array in out:
			if absf(angle_difference(float(cd[2]), float(o[2]))) < deg_to_rad(80.0):
				ok = false
		if ok:
			out.append(cd)
		if out.size() == 2:
			break
	var res: Array = []
	for o2: Array in out:
		res.append([o2[1], tg])
	return res


## True when a camera at `pos` would sit inside a wall, a rail, a roof or a trunk (anything but the terrain).
func _eye_buried(pos: Vector3) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = 0.7
	var bq := PhysicsShapeQueryParameters3D.new()
	bq.shape = ball
	bq.collision_mask = Layers.WORLD | Layers.PROPS
	bq.transform = Transform3D(Basis.IDENTITY, pos)
	for h in _space().intersect_shape(bq, 6):
		var cn := h.collider as Node
		if cn != null and not String(cn.name).begins_with("Terrain"):
			return true
	return false


func _s_regions(from: int, to: int) -> void:
	_clear_enemies()
	_ui_hide()
	var regs: Array = RealmLayout.REGIONS
	for i in range(from, mini(to, regs.size())):
		var r: Dictionary = regs[i]
		var views := _region_views(r)
		if views.is_empty():
			_fail("no usable camera spot for region " + String(r.id))
			continue
		var k := 0
		_perf_begin("region_" + String(r.id))
		for v: Array in views:
			await _view_still("region_%s_%d.png" % [String(r.id), k], "%s (%s): night view %d from eye height" % [String(r.name), String(r.biome), k + 1], v[0], v[1])
			k += 1
		_perf_end()
		if k < 2:
			_fail("region %s: only %d usable view(s)" % [String(r.id), k])
	_unpark()


## Stills only: is a fire, a lamp and a lit room warm against the night? (tavern, a cottage, the Hearth, a lamp post, a kindled brazier)
func _s_warmth() -> void:
	_clear_enemies()
	_ui_hide()
	var g := func(x: float, z: float) -> float: return _gy(x, z)
	# the clearest eye 5.5 m round a point (the open side of a fire on a slope)
	var ring := func(c: Vector3) -> Vector3:
		var best := Vector3(c.x, c.y + 2.0, c.z + 5.5)
		var best_d := -1.0
		for k in 12:
			var a := TAU * float(k) / 12.0
			var q := Vector3(c.x + cos(a) * 5.5, 0.0, c.z + sin(a) * 5.5)
			q.y = _gy(q.x, q.z) + 1.7
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(q, c + Vector3(0, 0.8, 0), Layers.WORLD))
			var d := q.distance_to(c) if hit.is_empty() else q.distance_to(hit.position)
			if not _space().intersect_ray(PhysicsRayQueryParameters3D.create(q, q + Vector3(0, 6.0, 0), Layers.WORLD | Layers.PROPS)).is_empty():
				d = 0.0               # under a roof
			if d > best_d:
				best_d = d
				best = q
		return best
	await _view_still("w_tavern_a.png", "tavern interior from the west end looking at the hearth", Vector3(12.0, -0.7 + 1.7, 27.0), Vector3(24.0, -0.7 + 0.9, 30.4))
	if OS.get_environment("WARMTH_DBG") != "":
		for n in get_tree().root.find_children("*", "Light3D", true, false):
			var lt := n as Light3D
			if lt.is_visible_in_tree() and lt.global_position.distance_to(cam1.global_position) < 7.0:
				print("WARMTH light: ", lt.get_path(), " e ", lt.light_energy, " vol ", lt.light_volumetric_fog_energy, " d ", lt.global_position.distance_to(cam1.global_position))
	await _view_still("w_tavern_b.png", "tavern interior from the hearth looking at the door and the bar", Vector3(23.0, -0.7 + 1.7, 28.0), Vector3(14.0, -0.7 + 1.0, 31.0))
	await _view_still("w_tavern_out.png", "the tavern from the porch, outside looking in", Vector3(17.6, g.call(17.6, 20.6) + 1.7, 20.6), Vector3(17.6, -0.7 + 1.3, 27.0))
	var cy: float = g.call(-165.0, 59.0) + 0.66
	await _view_still("w_house_a.png", "a Weirford cottage from inside", Vector3(-167.4, cy + 1.6, 60.9), Vector3(-162.8, cy + 1.0, 57.2))
	await _view_still("w_house_out.png", "the cottage from outside, its lit window", Vector3(-165.0, g.call(-165.0, 70.0) + 1.7, 70.0), Vector3(-165.0, cy + 1.5, 61.5))
	var sanc: Brazier = null
	for n in main.find_children("Sanctuary", "Brazier", true, false):
		sanc = n as Brazier
	if sanc != null:
		sanc.kindle_quiet()
		var sp := sanc.global_position
		await _view_still("w_hearth_fire.png", "the Hearth's fire at night", ring.call(sp), sp + Vector3(0, 0.8, 0))
	var hearth_at := sanc.global_position if sanc != null else studio
	var lamp_best: Lamp = null
	var lamp_d := 1.0e9
	for n in get_tree().get_nodes_in_group(&"lamp"):
		var lq := n as Lamp
		if lq != null and lq.look == "post" and lq.global_position.distance_to(hearth_at) < lamp_d:
			lamp_d = lq.global_position.distance_to(hearth_at)
			lamp_best = lq
	if lamp_best != null:
		lamp_best.light_from_leader(false)
		await _secs(0.5)
		var lp := lamp_best.global_position
		# a low eye 4.5 m out, looking at the ground a metre from the post's foot: the pool, the post and the wall
		var lcam := ring.call(lp) as Vector3
		var ldir := (lcam - lp) * Vector3(1, 0, 1)
		lcam = lp + ldir.normalized() * 4.5
		lcam.y = _gy(lcam.x, lcam.z) + 1.9
		await _view_still("w_lamp_post.png", "a lamp post at night: its pool on the ground", lcam, Vector3(lp.x, _gy(lp.x, lp.z) + 0.5, lp.z))
	var wild: Brazier = null
	var bd := 1.0e9
	for n in main.find_children("*", "Brazier", true, false):
		var q := n as Brazier
		if q != null and not q.lit and q.visible and q.global_position.distance_to(studio) < bd:
			bd = q.global_position.distance_to(studio)
			wild = q
	if wild != null:
		wild.kindle_quiet()
		var wl := wild.get_node("Light") as OmniLight3D
		print("WARMTH wild light: e %.2f r %.1f col %s vis %s shadow %s atten %.2f fade %s/%.0f cull %d pos %s" % [wl.light_energy, wl.omni_range, wl.light_color, wl.is_visible_in_tree(), wl.shadow_enabled, wl.omni_attenuation, wl.distance_fade_enabled, wl.distance_fade_begin, wl.light_cull_mask, wl.global_position])
		var bp := wild.global_position
		await _secs(1.0)
		await _view_still("w_brazier_wild.png", "a kindled brazier in the wild", ring.call(bp), bp + Vector3(0, 0.8, 0))


func _s_places() -> void:
	_clear_enemies()
	_ui_hide()
	# vistas from heights
	var vistas := [
		["vista_hearth_from_south", Vector3(6, 34, 150), Vector3(6, 4, 38)], ["vista_realm_from_sw", Vector3(-240, 95, 225), Vector3(0, 0, 20)],
		["vista_realm_from_se", Vector3(240, 80, 225), Vector3(0, 0, 20)], ["vista_crowns_from_road", Vector3(0, 45, 70), Vector3(0, 15, -125)],
		["vista_east_marches", Vector3(150, 40, 40), Vector3(235, 5, 20)], ["vista_west_marches", Vector3(-150, 40, 40), Vector3(-235, 5, 40)],
		["vista_rift_summit", Vector3(40, 60, -30), Vector3(0, 20, -105)]]
	for v: Array in vistas:
		_perf_begin(String(v[0]))
		var pos: Vector3 = v[1]
		pos.y += _gy(pos.x, pos.z) if pos.y < 200.0 else 0.0
		await _view_still(String(v[0]) + ".png", "vista from a height: " + String(v[0]).replace("vista_", "").replace("_", " "), pos, v[2])
		_perf_end()
	# settlements close up: villages, hearth, camps, posts, stables
	var spots: Array = []
	for rid: String in ["hearth", "weirford", "saltmarket", "holds", "chapel", "oak", "well", "stillwater"]:
		for r: Dictionary in RealmLayout.REGIONS:
			if String(r.id) == rid:
				var c: Vector2 = (r.rect as Rect2).get_center() if r.has("rect") else (r.c as Vector2)
				spots.append([rid, c])
	for hz in get_tree().get_nodes_in_group(&"horse"):
		spots.append(["stable_" + String(hz.get("breed")), Vector2((hz as Node3D).global_position.x, (hz as Node3D).global_position.z)])
	var wi := 0
	for wp in get_tree().get_nodes_in_group(&"watch_post"):
		if wi < 2:
			spots.append(["watch_" + String(wp.get("id")), Vector2((wp as Node3D).global_position.x, (wp as Node3D).global_position.z)])
		wi += 1
	for sp: Array in spots:
		var c2: Vector2 = sp[1]
		var tg := _gp(c2.x, c2.y, 2.0)
		var best_pos := Vector3.ZERO
		var best_clear := -1.0
		var ball := SphereShape3D.new()
		ball.radius = 0.7
		var bq := PhysicsShapeQueryParameters3D.new()
		bq.shape = ball
		bq.collision_mask = Layers.WORLD | Layers.PROPS
		for k in 16:
			var a := TAU * float(k) / 16.0 + 0.3
			var dist := 11.0 if k % 2 == 0 else 15.0
			var pos2 := _gp(c2.x + cos(a) * dist, c2.y + sin(a) * dist, 2.0)
			bq.transform = Transform3D(Basis.IDENTITY, pos2)
			var inside := false
			for h2 in _space().intersect_shape(bq, 6):
				var cn := h2.collider as Node
				if cn != null and not String(cn.name).begins_with("Terrain"):
					inside = true          # the eye would sit in a wall, a rail or a roof
			if inside:
				continue
			var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(pos2, tg, Layers.WORLD))
			var cl := 1.0 if hit.is_empty() else pos2.distance_to(hit.position) / maxf(pos2.distance_to(tg), 0.1)
			if cl > best_clear:
				best_clear = cl
				best_pos = pos2
		_perf_begin("close_" + String(sp[0]))
		await _view_still("close_%s.png" % String(sp[0]), "close-up of %s at night (11 m, eye height)" % String(sp[0]).replace("_", " "), best_pos, tg)
		_perf_end()
		if String(sp[0]) in ["hearth", "weirford", "saltmarket"]:
			# the square as a whole, from a roof's height on the side opposite the close-up: is it a market or a plane
			var back := Vector3(c2.x - (best_pos.x - c2.x), 0.0, c2.y - (best_pos.z - c2.y))
			var hi := _gp(back.x, back.z, 7.5)
			await _view_still("over_%s.png" % String(sp[0]), "the square of %s from 7 m up" % String(sp[0]), hi, tg)
	# boss arenas as built: every BossArena from its edge
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var ar := a as BossArena
		if ar == null:
			continue
		var c3 := ar.global_position
		var r3 := maxf(ar.radius, 14.0)
		_perf_begin("arena_" + ar.boss_id)
		await _view_still("arena_%s.png" % ar.boss_id, "boss arena %s from its edge, high" % ar.boss_id, c3 + Vector3(r3 * 1.2, r3 * 0.8, r3 * 1.2), c3 + Vector3(0, 2, 0))
		_perf_end()
	_unpark()


# ------------------------------------------------------------------------------------------------------
# UI

func _layer(script_end: String) -> Node:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.get_script() and String((c.get_script() as Script).resource_path).ends_with(script_end):
			return c
	return null


## Times the pause itself (the notification walk over every node), before and after PauseScope.mark.
func _pause_probe() -> void:
	var n := 1
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for c in nd.get_children():
			n += 1
			stack.append(c)
	var best := 99.0
	for i in 5:
		var t0 := Time.get_ticks_usec()
		get_tree().paused = true
		best = minf(best, float(Time.get_ticks_usec() - t0) / 1000.0)
		get_tree().paused = false
	print("PAUSE_PROBE nodes %d  best of 5 pause %.2f ms" % [n, best])


const PauseScope := preload("res://core/world/pause_scope.gd")


func _s_ui() -> void:
	_clear_enemies()
	_stand(studio, studio_yaw)
	cam1.global_position = studio + Vector3(0.0, 2.0, 0.0)
	_f_off()
	p.visible = true
	# the game's own camera back for the UI stills
	_cam_game()
	_ui_show()
	_pause_probe()
	PauseScope.mark(main)
	_pause_probe()
	# what the loading screen does before the cover lifts: every big panel opened once
	var pw: Node = preload("res://ui/panel_warm.gd").new()
	pw.set("zone", main)
	add_child(pw)
	pw.call("run")
	await _wait_until(func() -> bool: return bool(pw.get("done")), 60.0)
	print("PANEL_WARM second pass")
	pw.set("done", false)
	pw.call("run")
	await _wait_until(func() -> bool: return bool(pw.get("done")), 60.0)
	pw.queue_free()
	await _frames(10)
	spike_s = 0.012
	await _secs(2.0)
	await _still("hud_exploring.png", "HUD while exploring (bars, hotbar, minimap, compass, objective)")
	# HUD in combat: a pack comes at the wanderer
	for k in 3:
		var e := _spawn("wretch" if k < 2 else "husk", studio + _dir(studio_yaw + (float(k) - 1.0) * 0.5) * 6.0, studio)
		e.chase_range = 40.0
		if e.has_method("on_engaged"):
			e.call("on_engaged", p)
	await _secs(2.6)
	await _still("hud_in_combat.png", "HUD in combat: unit frames, target marks, hotbar, combat text")
	await _secs(0.8)
	await _still("hud_in_combat_2.png", "HUD in combat, a moment later")
	_clear_mine()
	_clear_enemies()
	# title screen
	_mark = "open title"
	var TitleScreen := preload("res://ui/title_screen.gd")
	var ts := TitleScreen.new()
	get_tree().root.add_child(ts)
	await _still("title_screen.png", "title screen over the night", 70)
	ts.queue_free()
	await _frames(4)
	# settings
	var sm := _layer("settings_menu.gd")
	if sm != null:
		for i in 4:
			if not sm.get("_root").visible:
				sm.call("open")
			sm.call("_show_tab", i)
			await _still("settings_%d.png" % i, "settings menu, tab %d" % i, 10)
		sm.call("close")
		await _frames(4)
	else:
		_fail("no settings menu layer")
	# gear to show: a few pieces
	const GearDB := preload("res://core/items/gear_db.gd")
	const GearRuntime := preload("res://core/items/gear_runtime.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	GearRuntime.store(GearDB.make(rng, {"rarity": 1, "slot": "focus", "set": "kindler"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 2, "slot": "lantern", "set": "kindler"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 3, "slot": "focus"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 3, "slot": "vestment", "set": "kindler"}))
	GearRuntime.store(GearDB.make(rng, {"rarity": 4, "slot": "girdle"}))
	Travel.give("thorn_heart", 1, false)
	Travel.give("grave_ash", 30, false)
	var cs := get_tree().get_first_node_in_group(&"character_screen")
	if cs != null:
		const PAGES := [["wanderer", "gear"], ["wanderer", "charms"], ["wanderer", "relics"], ["wanderer", "staff"], ["kindling", "embers"],
			["kindling", "spells"], ["kindling", "loadout"], ["kindling", "oaths"], ["kindling", "paths"], ["kindling", "hearth"], ["pack", ""],
			["journal", "journal"], ["journal", "stories"], ["journal", "writings"], ["journal", "places"], ["journal", "map"], ["journal", "lore"], ["journal", "tasks"]]
		for pg: Array in PAGES:
			_mark = "open char %s/%s" % [pg[0], pg[1]]
			cs.call("open_at", pg[0], pg[1])
			await _still("char_%s_%s.png" % [pg[0], pg[1] if pg[1] != "" else "all"], "character screen: %s / %s" % [pg[0], pg[1] if pg[1] != "" else "pack"], 12)
		cs.call("close")
		await _frames(4)
	else:
		_fail("no character screen")
	# the world map (M)
	var wm := get_tree().get_first_node_in_group(&"world_map")
	if wm != null:
		await _wait_until(func() -> bool: return bool(wm.call("is_baked")), 20.0)
		wm.call("open")
		await _still("world_map.png", "the world map (M), opening view", 30)
		wm.set("_zoom", 0.1)
		wm.call("_layout")
		await _still("world_map_whole.png", "the world map zoomed out to the whole Realm", 20)
		wm.call("close")
		await _frames(4)
		# every region found: the lettering at the whole-sheet zoom, and at two closer ones
		const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
		for r: Dictionary in RealmLayout.REGIONS:
			CodexStore.discover(String(r.id))
		wm.call("open")
		for zf: float in [1.0, 1.6, 2.6]:
			wm.set("_zoom", float(wm.get("_zoom_min")) * zf)
			wm.call("_layout")
			wm.call("_pick_hover")
			wm.get("_labels").call("reset")
			await _still("world_map_all_%d.png" % int(zf * 10.0), "world map, every region found, zoom x%.1f of the whole sheet" % zf, 20)
		wm.call("close")
		await _frames(4)
	else:
		_fail("no world map")
	# loot window, quest offer, shop, dialogue
	Events.boss_slain.emit("bone_abbot")
	await _secs(1.2)
	var bag := get_tree().get_first_node_in_group("loot_bag")
	if bag:
		bag.call("open_window")
		await _still("loot_window.png", "loot window over a boss's bag", 10)
		get_tree().get_first_node_in_group("loot_window").call("take_all")
	else:
		_fail("no loot bag after boss_slain")
	await _frames(6)
	var qo := get_tree().get_first_node_in_group("quest_offer")
	if qo:
		_mark = "open quest offer"
		qo.call("open_offer", "edda_tongs", "Edda")
		await _still("quest_offer.png", "quest offer screen", 10)
		qo.call("close")
	else:
		_fail("no quest offer layer")
	var story := get_tree().get_first_node_in_group("story")
	if story:
		_mark = "open shop"
		story.call("open_shop", "grisel")
		await _secs(0.6)
		await _still("shop_buy.png", "shop, buy tab (Grisel)", 6)
		var shop: Node = story.get("shop")
		shop.call("set_tab", 1)
		await _still("shop_sell.png", "shop, sell tab", 6)
		shop.call("close")
	else:
		_fail("no story director for the shop")
	await _frames(6)
	# the satchel / kindling by key actions are covered by the character screen pages above
	_ui_show()


