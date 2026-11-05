extends Node
## r36 Lantern Ward's rites from the Kin-Caller's Lamp, a child of the LanternWard (dies with it):
##   hearth  mends the wanderer HEARTH_MEND Wounds a second while she stands in the light (the ward
##           burns HEARTH_SHORT s shorter: ward.gd)
##   cinder  the light's edge burns: a foe that crosses it, in or out, takes CINDER_DMG and a Mark,
##           at most once a CINDER_EVERY s each
## Ticks five times a second over the enemy group, only while the ward stands.

const HEARTH_MEND := 2.0
const HEARTH_SHORT := 2.0
const CINDER_DMG := 0.6
const CINDER_EVERY := 1.0
const TICK := 0.2

var mode: StringName = &""
var player: Player
var power := 1.0
var _tick := 0.0
var _inside := {}               ## enemy instance id -> was inside at the last tick
var _burnt := {}                ## enemy instance id -> seconds of ward time it last burned


func _physics_process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var w := get_parent() as Node3D
	if w == null:
		return
	var c := w.global_position
	var r: float = LanternWard.RADIUS
	match mode:
		&"hearth":
			if is_instance_valid(player):
				var d := player.global_position - c
				if Vector2(d.x, d.z).length() <= r and absf(d.y) < 3.0:
					player.mend(HEARTH_MEND * TICK)
		&"cinder":
			var now := Time.get_ticks_msec() * 0.001
			for node in get_tree().get_nodes_in_group(Groups.ENEMY):
				var e := node as Enemy
				if e == null or not e.is_alive():
					continue
				var d := e.global_position - c
				var inside := Vector2(d.x, d.z).length() <= r and absf(d.y) < 3.0
				var id := e.get_instance_id()
				var was: Variant = _inside.get(id)
				_inside[id] = inside
				if was == null or bool(was) == inside:
					continue
				if now - float(_burnt.get(id, -99.0)) < CINDER_EVERY:
					continue
				_burnt[id] = now
				e.take_hit(CINDER_DMG * power, player)
				e.add_mark(1)
				Vfx.burst(e.global_position + Vector3.UP * 0.8, Color(3.0, 1.4, 0.4), {"count": 12, "life": 0.35, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": -2.0, "trail": 0.05})
