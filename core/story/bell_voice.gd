extends RefCounted
## The story's bell: one small tower bell, rendered once on a worker thread (never on the main thread: the great
## bell of the ending is a 24 s synth) and rung at any pitch. It is the night's motif: bells stopped top first and ring
## right from the bottom up, so the braziers ring a rising phrase (kindle_bells.gd), the Founder's bells ring one by one
## as the Warden wakes (warden_peal.gd), and Aurel's every word is tolled under at an octave down (aurel_voice.gd).
##   BellVoice.warm()                              start the render (the story director does, at its first frame)
##   BellVoice.ring(host, semitones, db, delay)    one stroke, non-positional, on the Music bus; silently nothing until warm
## No class_name. Load by path: const BellVoice := preload("res://core/story/bell_voice.gd")

const RATE := 22050
const SECONDS := 5.0
const STRIKE := 196.0              ## G3

static var _bytes := PackedByteArray()
static var _task := -1
static var _stream: AudioStreamWAV = null


static func warm() -> void:
	if _task >= 0 or not _bytes.is_empty():
		return
	_task = WorkerThreadPool.add_task(_render)


static func release() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_bytes = PackedByteArray()
	_stream = null


static func ready() -> bool:
	return _stream != null or (_task >= 0 and WorkerThreadPool.is_task_completed(_task) and not _bytes.is_empty())


static func _render() -> void:
	var n := int(SECONDS * float(RATE))
	var pcm := PackedFloat32Array()
	pcm.resize(n)
	# a tower bell: hum an octave down, prime, minor-third tierce, quint, nominal; each pair a hair apart so it beats
	var parts := [[0.5, 0.55, 3.2], [1.0, 1.0, 2.4], [1.2, 0.5, 1.6], [1.5, 0.38, 1.2], [2.0, 0.42, 0.9], [2.012, 0.2, 0.8], [2.76, 0.12, 0.5], [4.0, 0.08, 0.35]]
	for p: Array in parts:
		var f: float = STRIKE * float(p[0])
		var amp: float = float(p[1])
		var life: float = float(p[2])
		var w := TAU * f / float(RATE)
		for i in n:
			var t := float(i) / float(RATE)
			var env := exp(-t / life) * minf(1.0, t / 0.004)
			if env < 0.0005:
				break
			pcm[i] += sin(w * float(i)) * amp * env
	var peak := 0.0001
	for v in pcm:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(pcm[i] / peak * 0.8, -1.0, 1.0) * 32767.0))
	_bytes = bytes


static func _wav() -> AudioStreamWAV:
	if _stream == null:
		if _task < 0 or not WorkerThreadPool.is_task_completed(_task) or _bytes.is_empty():
			return null
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var s := AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = RATE
		s.stereo = false
		s.data = _bytes
		_stream = s
	return _stream


## One stroke. `semitones` from the strike note (G3), `delay` s from now (a timer, so a paused tree still rings it).
static func ring(host: Node, semitones := 0.0, db := -8.0, delay := 0.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	if delay > 0.0:
		host.get_tree().create_timer(delay, true).timeout.connect(func() -> void: ring(host, semitones, db, 0.0))
		return
	var s := _wav()
	if s == null:
		return
	var a := AudioStreamPlayer.new()
	a.name = "BellStroke"
	a.stream = s
	a.pitch_scale = pow(2.0, semitones / 12.0)
	a.volume_db = db
	a.bus = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(a)
	a.finished.connect(a.queue_free)
	a.play()
