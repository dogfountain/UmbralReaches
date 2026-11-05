extends Node
## core/world/session_state.gd: a night teardown leaves no Node / Callable static behind, and the
## Realm registries are empty. No world is built (fast):
##   godot --headless --path . res://zz/session_state_test.tscn
## Ends: SESSION STATE PASS  /  SESSION STATE FAIL n

const SessionState := preload("res://core/world/session_state.gd")
const SecretsState := preload("res://core/life/secrets/state.gd")
const Reactivity := preload("res://core/life/secrets/reactivity.gd")

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	var fake := Node3D.new()
	add_child(fake)
	SecretsState.host = fake
	SecretsState.sites.append({"id": "x"})
	Reactivity._host = fake
	EnemySpawner.kind_hook = _hook
	EnemySpawner.dress_hook = _hook
	EnemySpawner.hold_for_rest = true
	WorldLanes.sites.append({"id": "x"})
	ok(SessionState.dangling().size() == 4, "dangling() sees the planted refs (%s)" % [SessionState.dangling()])
	SessionState.reset_night()
	ok(SessionState.dangling().is_empty(), "nothing dangles after reset_night (%s)" % [SessionState.dangling()])
	ok(SecretsState.sites.is_empty(), "secrets site registry empty")
	ok(not EnemySpawner.hold_for_rest, "spawner rest hold off")
	ok(WorldLanes.sites.is_empty(), "WorldLanes.sites empty")
	SessionState.reset_night()   # idempotent
	ok(SessionState.dangling().is_empty(), "second reset is a no-op")
	print("SESSION STATE %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func _hook(_a: Variant = null, _b: Variant = null) -> Variant:
	return null
