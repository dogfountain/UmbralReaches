class_name DeepdiveRec
extends RefCounted
## Shared deepdive frame dumper. Attach from a Zone with start(), call tick() in _process.

var dir := ""
var hz := 12.0
var _acc := 0.0
var _i := 0
var _root: Node
var active := false


static func from_args(args: PackedStringArray) -> RefCounted:
	var rec = new()
	for a in args:
		if a.begins_with("--deepdive-rec="):
			rec.dir = a.trim_prefix("--deepdive-rec=")
		elif a.begins_with("--deepdive-hz="):
			rec.hz = maxf(4.0, float(a.trim_prefix("--deepdive-hz=")))
	if rec.dir == "":
		return null
	return rec


func start(root: Node) -> void:
	_root = root
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	active = true
	_acc = 0.0
	_i = 0
	print("DEEPDIVE start dir=", dir, " hz=", hz)


func tick(delta: float) -> void:
	if not active:
		return
	_acc += delta
	var step := 1.0 / hz
	if _acc < step:
		return
	_acc = 0.0
	var img := _root.get_viewport().get_texture().get_image()
	img.save_jpg(dir.path_join("frame_%05d.jpg" % _i), 0.82)
	_i += 1


func stop() -> void:
	if not active:
		return
	active = false
	print("DEEPDIVE stop frames=", _i, " dir=", dir)
