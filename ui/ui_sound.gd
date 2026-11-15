extends RefCounted
## Quiet interface sounds for any menu (no class_name: preload it). Synthesised once per host and
## kept on the host's players (as meta), not in statics, so nothing outlives the menu at quit.
##   const UiSound := preload("res://ui/ui_sound.gd")
##   UiSound.play(self, "move")      # focus / hover moved      "tab"      a page or tab changed
##   UiSound.play(self, "confirm")   # a toggle, a pick, a buy  "back"     a menu closed
##   "quest_new" / "quest_done"      # a task taken up / finished (ui/quest_log.gd banners)
## Plays on the SFX bus and while the tree is paused (menus pause the world).

const RATE := 44100
const KINDS := {
	# [length s, start Hz, end Hz, second partial ratio (0 = none), decay per s, volume dB]
	"move": [0.022, 2300.0, 2100.0, 0.0, 190.0, -21.0],
	"tab": [0.040, 1250.0, 1180.0, 1.5, 95.0, -19.0],
	"confirm": [0.085, 660.0, 700.0, 1.5, 42.0, -16.0],
	"back": [0.075, 560.0, 400.0, 0.0, 48.0, -18.0],
	"tick": [0.012, 3200.0, 3200.0, 0.0, 320.0, -25.0],
	a task taken up, and a task done, were silent (a banner and a toast only). A spec's seventh entry is
	# further notes as [start s, Hz]: the first note's contour is not bent for them. Rising fifth; then a rising triad
	"quest_new": [0.30, 523.0, 523.0, 2.0, 11.0, -15.0, [[0.09, 784.0]]],
	"quest_done": [0.62, 523.0, 523.0, 2.0, 7.5, -11.0, [[0.12, 659.0], [0.24, 784.0], [0.38, 1047.0]]],
}


static var muted := false              ## set while the loading screen opens every panel once


static func play(host: Node, kind: String) -> void:
	if muted or host == null or not host.is_inside_tree() or not KINDS.has(kind):
		return
	var pname := "UiSound_" + kind
	var pl := host.get_node_or_null(pname) as AudioStreamPlayer
	if pl == null:
		pl = AudioStreamPlayer.new()
		pl.name = pname
		pl.bus = &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
		pl.process_mode = Node.PROCESS_MODE_ALWAYS
		pl.stream = _make(KINDS[kind])
		pl.volume_db = float(KINDS[kind][5])
		host.add_child(pl)
	pl.play()


static func _make(spec: Array) -> AudioStreamWAV:
	var more: Array = spec[6] if spec.size() > 6 else []
	var n := int(float(spec[0]) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var ph2 := 0.0
	var extra_ph := PackedFloat64Array()
	extra_ph.resize(more.size())
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / float(maxi(n - 1, 1))
		var f := lerpf(float(spec[1]), float(spec[2]), k)
		ph += TAU * f / RATE
		ph2 += TAU * f * float(spec[3]) / RATE
		var env := exp(-float(spec[4]) * t) * minf(1.0, t * 2000.0)      # 0.5 ms attack: no click
		var v := sin(ph) + (0.35 * sin(ph2) if float(spec[3]) > 0.0 else 0.0)
		v *= env
		for j in more.size():
			var t0 := float((more[j] as Array)[0])
			if t < t0:
				continue
			extra_ph[j] += TAU * float((more[j] as Array)[1]) / RATE
			var e2 := exp(-float(spec[4]) * (t - t0)) * minf(1.0, (t - t0) * 2000.0)
			v += (sin(extra_ph[j]) + (0.35 * sin(extra_ph[j] * float(spec[3])) if float(spec[3]) > 0.0 else 0.0)) * e2
		v /= 1.0 + 0.5 * float(more.size())
		data.encode_s16(i * 2, int(clampf(v * 0.6, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
