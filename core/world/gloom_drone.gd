extends RefCounted
## The low drone that comes into the night as the Gloom rises (Ambience.gloom, core/world/gloom_world.gd): a
## twelve-second loop of a low fifth-less cluster, two close pitches that beat against each other, a hollow
## octave above and a slow swell. Every partial completes whole cycles in the loop, so it seams silently.
## Synthesised once at 11 kHz (nothing in it sits above 300 Hz): about 130,000 samples, a few milliseconds.

const RATE := 11025
const LEN_S := 12.0


static func make() -> AudioStreamWAV:
	var n := int(RATE * LEN_S)
	var data := PackedByteArray()
	data.resize(n * 2)
	# [frequency Hz (a multiple of 1/12), amplitude]
	var parts := [[73.0, 0.34], [73.75, 0.3], [109.5, 0.16], [146.0, 0.1], [219.25, 0.05]]
	var swell_hz := 2.0 / LEN_S
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for pt: Array in parts:
			v += sin(TAU * float(pt[0]) * t) * float(pt[1])
		v *= 0.72 + 0.28 * sin(TAU * swell_hz * t)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 0.9 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
