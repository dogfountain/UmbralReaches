extends "res://zz/audit.gd"
## zz/audit (lanes, portals, sites vs solids, seals, arenas) for the Realm: the same checks, run once
## the Realm has finished building (it builds over many frames; audit.gd runs at frame 24).
##   godot --headless --path . res://zz/realm_audit.tscn -- --realm [--realm-modules=...]
var _held := 0
var _ready_at := -1


func _physics_process(d: float) -> void:
	if _ready_at < 0:
		_held += 1
		var main := get_tree().root.get_node_or_null("Main")
		var built := false
		for n in get_tree().root.get_children():
			if n.has_meta("summit_dressed"):
				built = true
		if not built and _held < 60 * 120:
			return
		_ready_at = _held
		print("REALM_AUDIT realm ready at frame ", _held, "" if built else " (timed out)")
		t = 0
	super._physics_process(d)
