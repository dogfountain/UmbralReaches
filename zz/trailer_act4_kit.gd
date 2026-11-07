extends RefCounted
## Act IV's stage hand: finds a boss's real BossArena, warms it, stands the wanderer inside, holds the pull until the
## shot says go (or pre-pulls it), keeps the cast alive past the director's stray-culling, and gives the shots a few
## camera helpers. Nothing here fakes a boss: the arena spawns it, the room reacts, the boss runs its own moves.

const SCRIPTS := {
	"thornwarden": "res://core/enemy/thornwarden.gd",
	"bone_abbot": "res://core/enemy/bone_abbot.gd",
	"ascended_warden": "res://core/enemy/ascended_warden.gd",
	"r37_anchoress": "res://core/enemy/anchoress.gd",
	"r37_hierarch": "res://core/enemy/hierarch_voice.gd",
}
const HOLD: Array[String] = ["__trailer_hold"]

var d
var ar: BossArena
var id := ""
var _hooked := false


func _init(director: Object) -> void:
	d = director


## Every arena stood down (a boss from an earlier shot freed, its room and gate reset).
func reset_arenas() -> void:
	for a in d.get_tree().get_nodes_in_group(&"boss_arena"):
		var b := a as BossArena
		b._reset()
		b._active = false
		b._held = false
		b._boss = null
	d.boss = null
	TimeSlow._reqs.clear()
	Engine.time_scale = 1.0


func arena_of(boss_id: String) -> BossArena:
	for a in d.get_tree().get_nodes_in_group(&"boss_arena"):
		if (a as BossArena).boss_id == boss_id:
			return a as BossArena
	return null


## Setup of a boss shot: stand every arena down, warm `boss_id`, hold its pull, adopt whatever it summons.
func begin(boss_id: String) -> BossArena:
	reset_arenas()
	d.clear_spawned()
	id = boss_id
	ar = arena_of(boss_id)
	if ar == null:
		print("TRAILER no arena ", boss_id)
		return null
	ar.requires_bosses = HOLD.duplicate()
	ar.requires_bells = 0
	ar._warned = true
	ar._warmed = true
	BossKit.warm(d.main, -1, StringName(boss_id))
	BossKit.warm_rig(d.main, load(SCRIPTS[boss_id]) as GDScript)
	hook()
	return ar


func hook() -> void:
	if not _hooked:
		_hooked = true
		d.get_tree().node_added.connect(_adopt)


func unhook() -> void:
	if _hooked:
		_hooked = false
		d.get_tree().node_added.disconnect(_adopt)


func _adopt(n: Node) -> void:
	if n is Enemy:
		_adopt_late.call_deferred(n)


func _adopt_late(n: Node) -> void:
	if is_instance_valid(n) and not d.spawned.has(n):
		d.spawned.append(n)


## The wanderer on the arena floor at `at` (flat), facing `yaw`.
func stand(at: Vector3, yaw: float, pitch := -0.05) -> void:
	d.put_player(floor_at(at), yaw, pitch, false)


## The floor under `at`: a ray down from a little above the arena's own level (so an underground hall finds its
## floor, not the hillside over it).
func floor_at(at: Vector3, up := 0.0) -> Vector3:
	var top := (ar.global_position.y if ar else at.y) + 4.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, top, at.z), Vector3(at.x, top - 14.0, at.z), Layers.WORLD)
	var hit: Dictionary = d.main.get_world_3d().direct_space_state.intersect_ray(q)
	var y: float = (hit.position as Vector3).y if not hit.is_empty() else at.y
	return Vector3(at.x, y + 0.15 + up, at.z)


## The pull: the arena sees the wanderer inside and raises its boss. Returns it (may need a physics frame).
func pull() -> void:
	if ar == null or boss() != null:
		return
	ar.requires_bosses = []
	ar._warned = false
	flags_pulled = true
	ar._begin()
	var b := boss()
	if b:
		d.boss = b


var flags_pulled := false


func boss() -> Enemy:
	if ar != null and is_instance_valid(ar._boss):
		return ar._boss
	return null


## A pull whose intro is already over: it starts the shot ready to fight.
func pre_pull() -> Enemy:
	pull()
	var b := boss()
	if b:
		b._ward_t = 0.0
		b._state_t = 0.0
		b._combo_left = 0
	return b


func boss_pos() -> Vector3:
	var b := boss()
	return b.global_position if b else (ar.boss_at if ar else Vector3.ZERO)


func finish() -> void:
	unhook()
	d.release(&"skill_bolt")
	d._release_inputs()
	d.drive(Vector3.ZERO)
	d.cam.fov = 62.0
	flags_pulled = false
