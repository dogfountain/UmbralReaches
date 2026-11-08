extends Node
## The trailer's one continuous score, from the game's own composed music (boss_themes.gd): each act scored by a theme's
## two stems, crossfaded at the act cuts, the great bell over the cold open and the title. The shots are rendered with
## the Music bus muted (tools/trailer.sh, TRAILER_NO_MUSIC) and this is laid under the whole cut, so the music never
## restarts at a cut.
##   godot --headless --path . res://zz/trailer_score.tscn -- --out=/abs/score.wav --acts=0,20.57,58.85,137.69,175.47,179.94

const Themes := preload("res://core/life/wildlife/boss_themes.gd")
const RATE := Themes.RATE
const XF := 2.5                       ## crossfade at each act cut, seconds

## per act: [theme id, base gain, high gain at the act's start, high gain at its end]
const PLAN := [
	["ascended_warden", 0.55, 0.0, 0.0],      # I     the cold open and the village: the lydian choir, quiet
	["bone_abbot", 0.85, 0.0, 0.5],           # II    the fight: the organ and the tolls, held back for act IV (Luke, 8 Nov: the
	                                          #       Thornwarden's plucked ostinato read as a guitar over the shots)
	["ascended_warden", 0.85, 0.35, 1.0],     # III   the Realm widens: the full choir and its bells
	["bone_abbot", 1.25, 0.6, 1.3],           # IV    the great ones: organ, tolls, the chant (lifted: the darker theme sat 4 dB under III)
]


func _ready() -> void:
	var out := ""
	var acts: Array[float] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--acts="):
			for v in a.substr(7).split(","):
				acts.append(float(v))
	if out == "" or acts.size() != PLAN.size() + 2:
		push_error("usage: -- --out=<wav> --acts=<I,II,III,IV,V,end> (seconds)")
		get_tree().quit(1)
		return
	var total := int(acts[acts.size() - 1] * RATE)
	var mix := PackedFloat32Array()
	mix.resize(total)
	var stems := {}
	for i in PLAN.size():
		var p: Array = PLAN[i]
		var id: String = p[0]
		for layer: String in ["base", "high"]:
			var key := id + ":" + layer
			if not stems.has(key):
				stems[key] = _norm(Themes.build(id, layer))
		var t0 := acts[i]
		var t1 := acts[i + 1]
		var s0 := maxi(0, int((t0 - XF * 0.5) * RATE))
		var s1 := mini(total, int((t1 + XF * 0.5) * RATE)) if i < PLAN.size() - 1 else mini(total, int((t1 + 3.0) * RATE))
		var base: PackedFloat32Array = stems[id + ":base"]
		var high: PackedFloat32Array = stems[id + ":high"]
		for s in range(s0, s1):
			var t := float(s) / RATE
			var w := 1.0
			if i > 0:
				w = minf(w, smoothstep(t0 - XF * 0.5, t0 + XF * 0.5, t))
			if i < PLAN.size() - 1:
				w = minf(w, 1.0 - smoothstep(t1 - XF * 0.5, t1 + XF * 0.5, t))
			else:
				w = minf(w, 1.0 - smoothstep(t1 - 0.5, t1 + 3.0, t))      # the bosses' theme gives way to the bell
			var k := clampf((t - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
			var hg := lerpf(float(p[2]), float(p[3]), k)
			var j := s - s0                                                 # each act starts its theme on the downbeat
			mix[s] += w * (float(p[1]) * base[j % base.size()] + hg * high[j % high.size()])
	# the great bell: once under the cold open's card, once under the title
	var bell := _norm(Themes._great_bell(110.0, 24.0))
	for at: float in [0.3, acts[acts.size() - 2] + 0.2]:
		var s0 := int(at * RATE)
		for j in bell.size():
			if s0 + j < total:
				mix[s0 + j] += 0.75 * bell[j]
	# a short fade in, and out on the last two seconds
	for s in total:
		var t := float(s) / RATE
		mix[s] *= smoothstep(0.0, 1.2, t) * (1.0 - smoothstep(acts[acts.size() - 1] - 2.5, acts[acts.size() - 1], t))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = Themes._encode(mix)
	var err := wav.save_to_wav(out)
	print("SCORE %s: %.1f s, %d acts, err %d" % [out, float(total) / RATE, PLAN.size(), err])
	get_tree().quit(0 if err == OK else 1)


static func _norm(pcm: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	var out := pcm.duplicate()
	for i in out.size():
		out[i] /= peak
	return out
