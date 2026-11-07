extends RefCounted
## The play bot's notebook: the log, the counted findings, the screenshots, the frame-time record and the
## contact strips of fights. Windowed only for images (headless draws nothing).

const SPIKE_MS := 33.0
const MAX_SHOTS_PER_KIND := 6

var host: Node
var out: String
var headless: bool
var game_s := 0.0                         ## game seconds the bot has played (set by the brain each tick)
var pos := Vector3.ZERO
var lines: PackedStringArray = []
var counts: Dictionary = {}               ## kind -> count
var firsts: Dictionary = {}               ## kind -> first few messages
var shots: Array[String] = []
var shot_kinds: Dictionary = {}
var spikes: Array = []                    ## [game clock, ms, activity]
var spike_by_act: Dictionary = {}
var frames := 0
var ms_sum := 0.0
var ms_max := 0.0
var _shooting := false
var _log: FileAccess


func _init(h: Node, o: String, hl: bool) -> void:
	host = h
	out = o
	headless = hl
	_log = FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)


func clock() -> String:
	return "%02d:%02d" % [int(game_s) / 60, int(game_s) % 60]


func note(kind: String, msg: String) -> void:
	var line := "[%s] %-14s (%5.0f,%5.0f) %s" % [clock(), kind, pos.x, pos.z, msg]
	lines.append(line)
	if _log != null:
		_log.store_line(line)
		_log.flush()
	print("BOT ", line)


## A thing a player would hit: counted, listed in the summary, and (windowed) photographed.
func problem(kind: String, msg: String, snap := true) -> void:
	counts[kind] = int(counts.get(kind, 0)) + 1
	var f: Array = firsts.get(kind, [])
	if f.size() < 8:
		f.append("[%s] (%.0f,%.0f) %s" % [clock(), pos.x, pos.z, msg])
		firsts[kind] = f
	note("PROBLEM " + kind, msg)
	if snap and int(shot_kinds.get(kind, 0)) < MAX_SHOTS_PER_KIND:
		shot_kinds[kind] = int(shot_kinds.get(kind, 0)) + 1
		shot("problem_%s_%02d" % [kind.to_lower(), int(shot_kinds[kind])])


func frame(ms: float, activity: String) -> void:
	frames += 1
	ms_sum += ms
	ms_max = maxf(ms_max, ms)
	if ms > SPIKE_MS:
		spike_by_act[activity] = int(spike_by_act.get(activity, 0)) + 1
		if spikes.size() < 60:
			spikes.append([clock(), snappedf(ms, 0.1), activity])
		counts["FRAME_OVER_33MS"] = int(counts.get("FRAME_OVER_33MS", 0)) + 1


## Screenshot of the window (no-op headless). Returns when saved.
func shot(name: String) -> void:
	if headless or _shooting:
		return
	_shooting = true
	await RenderingServer.frame_post_draw
	var img := host.get_viewport().get_texture().get_image()
	var path := out.path_join("%s.png" % name)
	if img != null and not img.is_empty():
		img.save_png(path)
		shots.append(path)
	_shooting = false


## One downscaled frame for a fight strip (null headless).
func grab() -> Image:
	if headless or _shooting:
		return null
	_shooting = true
	await RenderingServer.frame_post_draw
	var img := host.get_viewport().get_texture().get_image()
	_shooting = false
	if img == null or img.is_empty():
		return null
	img.resize(400, 250, Image.INTERPOLATE_BILINEAR)
	return img


func strip(frames_in: Array, name: String) -> void:
	if frames_in.size() < 2:
		return
	var cols := 3
	var rows := ceili(frames_in.size() / float(cols))
	var sheet := Image.create(400 * cols, 250 * rows, false, Image.FORMAT_RGB8)
	for i in frames_in.size():
		var im: Image = frames_in[i]
		im.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(im, Rect2i(0, 0, 400, 250), Vector2i((i % cols) * 400, (i / cols) * 250))
	var path := out.path_join("%s.png" % name)
	sheet.save_png(path)
	shots.append(path)


func write_summary(brain: Object) -> void:
	var f := FileAccess.open(out.path_join("summary.txt"), FileAccess.WRITE)
	if f == null:
		return
	f.store_line("play bot summary: game time %s" % clock())
	if brain != null:
		for l: String in brain.stats_lines():
			f.store_line(l)
	f.store_line("")
	f.store_line("frames %d, mean %.1f ms, max %.1f ms, over 33 ms: %d" % [frames, ms_sum / maxf(1.0, frames), ms_max, int(counts.get("FRAME_OVER_33MS", 0))])
	for a: String in spike_by_act:
		f.store_line("  spikes while %s: %d" % [a, int(spike_by_act[a])])
	f.store_line("")
	f.store_line("findings (kind: count)")
	for k: String in counts:
		f.store_line("%s: %d" % [k, int(counts[k])])
		for m: String in firsts.get(k, []):
			f.store_line("    " + m)
	f.store_line("")
	f.store_line("worst frames")
	for s: Array in spikes:
		f.store_line("  %s %s ms %s" % [s[0], s[1], s[2]])
	f.store_line("")
	f.store_line("screenshots")
	for s: String in shots:
		f.store_line("  " + s)
	f.close()
