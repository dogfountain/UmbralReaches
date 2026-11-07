extends RefCounted
## Act IV shots (descend) and the finale: the bosses (reveal, a signature move, a phase change each) and the killing blow.
## Pattern: `d` is the director (zz/trailer.gd). Write _s_<id>() setup, _u_<id>(t) every frame, _e_<id>() teardown;
## the director finds the file by the method name. Cameras: d.frame_cam / d.hold_cam / d.top_down / d.solve_cam and the
## helpers in trailer_cam.gd. Real systems only (spawn the real boss, call its real moves). Example: the summit dais.

const Cam := preload("res://zz/trailer_cam.gd")
const SUMMIT_DAIS := Vector3(0.0, 27.35, -103.9)

var d
var cam


func _init(director: Object) -> void:
	d = director
	cam = Cam.new(director)


func _s_warden() -> void:
	d.put_player(SUMMIT_DAIS + Vector3(0.0, 0.0, 9.0), 0.0, -0.05, false)
	d.use_free_cam()
	d.cam.fov = 55.0


func _u_warden(tt: float) -> void:
	var k: float = d.sm(clampf(tt / 2.0, 0.0, 1.0))
	cam.orbit(SUMMIT_DAIS, k, 12.0, 9.0, -0.6, 0.4, 2.5, 3.5, 3.0)
	d.light_at(SUMMIT_DAIS, 6.0)
