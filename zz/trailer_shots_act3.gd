extends RefCounted
## Act III shots (the realm widens): places, horses, the Marches, bells, escort and defend. PLACES is the data-driven
## pattern (a shot per entry, no per-shot method); write a bespoke shot as _s_<id>, _u_<id>(t), _e_<id>() instead.
## A place shot puts the wanderer on `stand` walking toward `look`; the lens trails them (trailer_cam.vista).

const Cam := preload("res://zz/trailer_cam.gd")
## id -> [stand xz, look xz, look height above ground, lens back, lens height, fov, lateral drift, rise, walk pace]
const PLACES := {
	"thornwood": [Vector2(-60, 20), Vector2(-110, -20), 6.0, 4.5, 2.2, 62.0, 1.2, 0.8, 0.5],
	"necropolis": [Vector2(-10, 108), Vector2(0, 147), 4.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"mere": [Vector2(103, 98), Vector2(84, 112), 1.5, 4.5, 2.0, 60.0, 1.5, 0.6, 0.4],
	"foundry": [Vector2(123, -76), Vector2(135, -105), 6.0, 4.5, 2.2, 60.0, 1.5, 0.8, 0.5],
	"orchard": [Vector2(-99, 104), Vector2(-128, 132), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"quarry": [Vector2(-120, -83), Vector2(-128, -104), 4.0, 4.5, 2.4, 60.0, 1.5, 0.8, 0.5],
	"moor": [Vector2(126, -8), Vector2(142, -24), 5.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"holds": [Vector2(-125, 15), Vector2(-139, 11), 2.5, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"crowns": [Vector2(0, 66), Vector2(0, -110), 30.0, 5.0, 2.4, 60.0, 1.5, 1.2, 0.6],
	"stillwater": [Vector2(220, 52), Vector2(242, 6), 14.0, 5.0, 2.2, 60.0, 1.5, 0.8, 0.5],
	"anchorholds": [Vector2(204, -84), Vector2(214, -132), 18.0, 5.0, 2.4, 60.0, 1.5, 0.8, 0.5],
	"hierarch": [Vector2(-196, -76), Vector2(-236, -84), 10.0, 5.0, 2.4, 60.0, 1.5, 0.8, 0.5],
	"siege": [Vector2(-214, 128), Vector2(-236, 170), 8.0, 5.0, 2.2, 60.0, 1.5, 0.8, 0.5],
	"saltmarket": [Vector2(200, 90), Vector2(214, 95), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"pans": [Vector2(200, 150), Vector2(232, 168), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
	"oak": [Vector2(-44, 192), Vector2(-70, 206), 12.0, 5.0, 2.2, 60.0, 1.5, 0.8, 0.5],
	"well": [Vector2(44, 192), Vector2(72, 204), 0.0, 5.0, 2.4, 60.0, 1.5, 0.8, 0.5],
	"downs": [Vector2(-10, 190), Vector2(0, 196), 3.0, 4.5, 2.0, 60.0, 1.5, 0.6, 0.5],
}

var d
var cam


func _init(director: Object) -> void:
	d = director
	cam = Cam.new(director)


func handles(id: String) -> bool:
	return PLACES.has(id)


func _look(id: String) -> Vector3:
	var pl: Array = PLACES[id]
	var v: Vector2 = pl[1]
	return Vector3(v.x, d.gy(v.x, v.y) + float(pl[2]), v.y)


func _s_any(id: String) -> void:
	var pl: Array = PLACES[id]
	var st: Vector2 = pl[0]
	var look := _look(id)
	d.put_player(Vector3(st.x, 0.0, st.y), Cam.yaw_dir(look - Vector3(st.x, look.y, st.y)), -0.05)
	d.use_free_cam()
	d.cam.fov = float(pl[5])
	d.aim_at(look)
	d.drive(Cam.flat(look - d.pp()) * float(pl[8]))


func _u_any(tt: float, id: String) -> void:
	var pl: Array = PLACES[id]
	var k: float = d.sm(clampf(tt / float(d.SHOTS[d.si][1]), 0.0, 1.0))
	cam.vista(_look(id), k, float(pl[3]), float(pl[4]), float(pl[6]), float(pl[7]))
	d.light_at(d.pp(), 3.0)


func _e_any(_id: String) -> void:
	d.drive(Vector3.ZERO)
	d.cam.fov = 62.0
