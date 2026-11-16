class_name Sway
extends Node3D
## r36: a thing that hangs, turns or rings, posed every drawn frame (not on the physics tick).
## Its children are built around its origin, the pivot: a lantern's hook, a crane's sheave, a
## wheel's axle, a bell's headstock. The wind (Weather's gusts, `Sway.wind`) swings the hanging
## things harder; a bell can be rung (`ring()`). Past FAR from the camera it holds its pose and
## costs nothing but a distance check every half second.
##   var s := Sway.hang(parent, pivot_world, yaw, 0.05, 2.4)  # then add children around (0, 0, 0)

enum { HANG, SPIN, BELL, FLAG }

## Weather (core/life/wildlife/weather.gd) writes its gust here, 0 (still) .. ~1.6 (a storm).
static var wind := 0.3

var mode := HANG
var amp := 0.05                 ## HANG/BELL: radians of swing at calm air
var period := 2.4               ## HANG/BELL: seconds per swing
var spin := 0.0                 ## SPIN: radians per second about `axis`
var axis := Vector3.RIGHT       ## SPIN: local axis
var wind_k := 1.0               ## how much the wind adds (a heavy block barely, a lantern a lot)
const FAR := 45.0

var _base := Basis.IDENTITY
var _t := 0.0
var _ring := 0.0
var _far := false
var _check := 0.0


static func hang(parent: Node, at: Vector3, yaw := 0.0, a := 0.05, per := 2.4, wk := 1.0) -> Sway:
	var s := Sway.new()
	s.mode = HANG
	s.amp = a
	s.period = per
	s.wind_k = wk
	return _place(s, parent, at, yaw)


static func turner(parent: Node, at: Vector3, yaw: float, ax: Vector3, rate: float) -> Sway:
	var s := Sway.new()
	s.mode = SPIN
	s.axis = ax.normalized()
	s.spin = rate
	return _place(s, parent, at, yaw)


static func bell(parent: Node, at: Vector3, yaw := 0.0, per := 2.0) -> Sway:
	var s := Sway.new()
	s.mode = BELL
	s.amp = 0.012
	s.period = per
	s.wind_k = 0.3
	return _place(s, parent, at, yaw)


## A cloth banner on a pole: `segs` strips chained edge to edge, each turning a little about the
## one before it with a lag, so a wave runs out along the cloth (stronger in the gusts). One shared
## strip mesh; returns the root at the pole.
static func flag(parent: Node, at: Vector3, yaw: float, key: String, size: Vector2, segs := 6) -> Sway:
	var w := size.x / float(segs)
	var kt := OssKit.new()
	kt.keep_lanes = false
	kt.box(key, Vector3(w * 0.5, 0, 0), Vector3(w * 1.04, size.y, 0.025), Basis.IDENTITY, false, 0.45)
	var tmp := Node3D.new()
	kt.commit(tmp, "x")
	var strip: MeshInstance3D = null
	for c in tmp.get_children():
		if c is MeshInstance3D:
			strip = c
	var root: Sway = null
	var prev: Node = parent
	for i in segs:
		var s := Sway.new()
		s.mode = FLAG
		s.amp = 0.1 + 0.03 * float(i)
		s.period = 1.6
		s.name = "Flag%d" % i
		prev.add_child(s)
		if i == 0:
			s.global_position = at
			s.global_basis = Basis(Vector3.UP, yaw)
		else:
			s.position = Vector3(w, 0, 0)
		s._base = s.basis
		s._t = 0.55 * float(segs - i) + fposmod(at.x * 1.7 + at.z, 9.0)   # the wave runs outward
		var m := MeshInstance3D.new()
		m.mesh = strip.mesh
		m.material_override = strip.material_override
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visibility_range_end = 110.0
		s.add_child(m)
		if root == null:
			root = s
		prev = s
	tmp.free()
	return root


static func _place(s: Sway, parent: Node, at: Vector3, yaw: float) -> Sway:
	s.name = "Sway"
	parent.add_child(s)
	s.global_position = at
	s.global_basis = Basis(Vector3.UP, yaw)
	s._base = s.basis
	# each one on its own beat: the phase from where it stands
	s._t = fposmod(at.x * 1.731 + at.z * 2.417, 37.0)
	return s


## Builds `k` (an OssKit filled around (0, 0, 0)) as meshes under this pivot, so they swing with it.
func take(k: OssKit, far := 70.0) -> void:
	k.commit(self, "SwayBody")
	for c in get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = far
			(c as GeometryInstance3D).visibility_range_end_margin = 8.0
		elif c is StaticBody3D:
			c.queue_free()                       # nothing that moves keeps a static collider


## A bell: a swing that dies away over ~12 s (k 1 = a full peal).
func ring(k := 1.0) -> void:
	_ring = maxf(_ring, k)
	_far = false
	_wake()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


var _nap: SceneTreeTimer = null  ## while far: the engine timer that wakes it for its next look


## Back from a nap (its timer, or a ring): its clock takes the game time it slept, so the swing's phase is as if
## it had run, and it looks again at once.
func _wake(tm: SceneTreeTimer = null) -> void:
	if _nap == null or (tm != null and tm != _nap):
		return
	_t += _nap.get_meta(&"len", 0.0) - maxf(_nap.time_left, 0.0)
	_nap = null
	_check = 0.0
	set_process(true)


func _process(dt: float) -> void:
	_t += dt
	_check -= dt
	if _check <= 0.0:
		_check = 0.5
		var cam := get_viewport().get_camera_3d()
		_far = cam != null and cam.global_position.distance_squared_to(global_position) > FAR * FAR and _ring <= 0.0
	if _far:
		# no script call a frame till the next look (an engine timer wakes it): 83 of them, nearly all far
		set_process(false)
		_nap = get_tree().create_timer(_check, false)
		_nap.set_meta(&"len", _check)
		_nap.timeout.connect(_wake.bind(_nap))
		return
	var w := TAU / period
	match mode:
		HANG:
			var g := amp * (0.6 + wind * 1.4 * wind_k)
			var ax := sin(_t * w) * g + sin(_t * w * 0.37 + 1.3) * g * 0.35
			var az := sin(_t * w * 0.88 + 0.7) * g * 0.6
			basis = _base * Basis.from_euler(Vector3(ax, 0.0, az))
		SPIN:
			basis = _base * Basis(axis, fposmod(_t * spin, TAU))
		FLAG:
			var f := amp * (0.35 + wind * 1.5)
			basis = _base * Basis(Vector3.UP, sin(_t * w) * f + sin(_t * w * 2.3 + 0.9) * f * 0.3)
		BELL:
			_ring = maxf(0.0, _ring - dt * 0.08)
			var a := amp * (0.6 + wind * 1.4 * wind_k) + 0.55 * _ring * _ring
			basis = _base * Basis(Vector3.RIGHT, sin(_t * w) * a)
