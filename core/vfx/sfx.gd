class_name Sfx
extends RefCounted
## Fire-and-forget positional sounds. Streams are loaded once; players free themselves.

static var _streams := {}


static func stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


static func play(path: String, at: Vector3, volume_db := 0.0, pitch := 1.0, jitter := 0.08) -> void:
	var s := stream(path)
	var tree := Engine.get_main_loop() as SceneTree
	if s == null or tree == null or tree.current_scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.max_distance = 34.0
	p.unit_size = 4.0
	tree.current_scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
