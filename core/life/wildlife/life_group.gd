extends Node3D
## Base for a wildlife group (a roost, a herd, a pool's frogs): the director ticks it only while
## the camera is within `active_r` of `center`, passing a shared context:
##   cam, player (Vector3), player_speed (m/s), enemies (Array[Vector3]), time (s), dt,
##   weather {mist, rain, wind, thunder}, quiet (bool: the director wants silence, e.g. tests)
## Subclasses: life_birds.gd, life_beasts.gd, life_pond.gd. Load by path (no class_name).

const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const LifeSynth := preload("res://core/life/wildlife/life_synth.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const RL := preload("res://core/world/realm/realm_land.gd")

var center := Vector3.ZERO
var active_r := 90.0
var kind := ""
var rng := RandomNumberGenerator.new()
var space: PhysicsDirectSpaceState3D
var alarms := 0                 ## times this group took fright (tests, debug)
var tracks: Node3D              ## the director's tracks.gd (prints and signs), or null


func tick(_dt: float, _ctx: Dictionary) -> void:
	pass


## Something frightening happened at `at` (a spell, thunder, a kill). strength 0..1.
func alarm(_at: Vector3, _strength: float) -> void:
	pass


## Nobody is watching any more (the camera left): settle back to rest (birds on their perches,
## frogs on the bank). Cheap "despawn": far groups are hidden and frozen in a calm state.
func rest() -> void:
	pass


## Something is moving (flying, running, leaping): the director then ticks it every frame.
func busy() -> bool:
	return false


## Redraw `ahead` seconds into the span until the next tick, which the director will run `span`
## seconds after the last one (the interval it uses NOW, so a change of rate never stalls or skips:
## r30). Moving groups between ticks; nothing by default.
func glide(_ahead: float, _span: float) -> void:
	pass


# --- two-tick interpolation for one instance buffer (birds, flocks; herds keep their own, r30) ----
# A tick writes its pose into the group's buffer (the newer tick); lerp_shift() then keeps the one
# before it (the older) and hands back what to draw now: the older. Between ticks lerp_draw() draws
# `al` of the way from the older to the newer, so motion is continuous at any frame rate and a turn
# or a climb is never guessed: one tick behind (66 ms near), never a kink when the next tick lands.
var _lo := PackedFloat32Array()     ## older tick's rows (16 floats each: TRANSFORM_3D + custom)
var _lc := PackedFloat32Array()     ## newer tick's rows (a copy of the group's buffer)
var _ld := PackedFloat32Array()     ## what is drawn
var _lrows := PackedInt32Array()    ## rows whose two ticks differ
var _lidx := PackedInt32Array()     ## the entries (row * 16 + column) that differ: all a glide touches


## After a tick wrote `newer`: returns the buffer to draw at the tick (the older pose). `snap` (setup,
## rest) puts both ticks at the new pose. A row that jumped more than 3 m is not crossed either.
func lerp_shift(newer: PackedFloat32Array, snap := false) -> PackedFloat32Array:
	if snap or _lc.size() != newer.size():
		_lo = newer.duplicate()
	else:
		_lo = _lc
	_lc = newer.duplicate()
	_lrows.clear()
	_lidx.clear()
	for i in newer.size() / 16:
		var j := i * 16
		var dx := _lc[j + 3] - _lo[j + 3]
		var dy := _lc[j + 7] - _lo[j + 7]
		var dz := _lc[j + 11] - _lo[j + 11]
		if dx * dx + dy * dy + dz * dz > 9.0 or absf(_lc[j + 14] - _lo[j + 14]) > PI * 8.0:
			for c in 16:
				_lo[j + c] = _lc[j + c]      # a jump, or the stride counter wrapped: no sweep
			continue
		var moved := false
		for c in 16:
			if _lo[j + c] != _lc[j + c]:
				_lidx.append(j + c)
				moved = true
		if moved:
			_lrows.append(i)
	_ld = _lo.duplicate()
	return _ld


## The drawn buffer `al` (0..1) of the way from the older tick to the newer. Only the entries that
## differ are touched (a perched bird turning its head is one float). Bases are lerped entry by
## entry: between two ticks a yaw turns a few degrees, so they stay rotations to a fraction of a %.
func lerp_draw(al: float) -> PackedFloat32Array:
	al = clampf(al, 0.0, 1.0)
	for e in _lidx:
		_ld[e] = lerpf(_lo[e], _lc[e], al)
	return _ld


## True when glide() is cheap (packed copies, only moving rows): the director then lets an idle
## group further out tick slowly and glide between (birds, flocks). Herds redraw from dictionaries.
var cheap_glide := false


## Seconds between logic ticks in view near the camera (the glide draws every frame in between).
func near_interval(moving: bool) -> float:
	return 1.0 / 15.0 if moving else 0.1


## Where each creature is, for tests (world positions).
func positions() -> Array[Vector3]:
	return []


## Nearest threat (player or enemy) to p and its distance.
func threat(p: Vector3, ctx: Dictionary, enemy_scale := 1.0) -> Array:
	var best: Vector3 = ctx.player
	var bd := p.distance_to(best)
	for e: Vector3 in ctx.enemies:
		var d := p.distance_to(e) / enemy_scale
		if d < bd:
			bd = d
			best = e
	return [best, bd]


## A sound by name: LifeSynth's kinds, or "scape:<kind>" for scape_synth.gd's.
static func sound(kind: String) -> AudioStreamWAV:
	if kind.begins_with("scape:"):
		return ScapeSynth.stream(kind.trim_prefix("scape:"))
	return LifeSynth.stream(kind)


func voice(snd: String, db: float, unit := 8.0, max_d := 70.0) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = sound(snd)
	# outdoor calls go through Ambience's AmbOut bus (muffled when you are indoors); the crypt's own
	# creatures stay on Ambience
	a.bus = &"AmbOut" if kind != "rat" and AudioServer.get_bus_index("AmbOut") >= 0 else &"Ambience"
	a.volume_db = db
	a.unit_size = unit
	a.max_distance = max_d
	a.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	a.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	a.panning_strength = 0.8
	add_child(a)
	return a


func say(a: AudioStreamPlayer3D, at: Vector3, snd := "", pitch := 1.0) -> void:
	if a == null:
		return
	if snd != "":
		a.stream = sound(snd)
	a.global_position = at
	a.pitch_scale = pitch
	a.play()


## Nearest threat to p, cheaper than threat() (no Array per call): returns its position and
## leaves its distance (scaled for enemies) in `_td`.
var _td := 0.0


func threat_at(p: Vector3, ctx: Dictionary, enemy_scale := 1.0) -> Vector3:
	var best: Vector3 = ctx.player
	var bd := p.distance_to(best)
	var es: Array = ctx.enemies
	if not es.is_empty():
		var inv := 1.0 / enemy_scale
		for e: Vector3 in es:
			var d := p.distance_to(e) * inv
			if d < bd:
				bd = d
				best = e
	_td = bd
	return best


## Write instance i's 16 floats (TRANSFORM_3D rows + custom data) into buf in place. Groups fill a
## buffer they keep (sized 16 per instance) and hand it to commit(): no allocation per row.
static func put(buf: PackedFloat32Array, i: int, b: Basis, o: Vector3, c: Color) -> void:
	var j := i * 16
	buf[j] = b.x.x
	buf[j + 1] = b.y.x
	buf[j + 2] = b.z.x
	buf[j + 3] = o.x
	buf[j + 4] = b.x.y
	buf[j + 5] = b.y.y
	buf[j + 6] = b.z.y
	buf[j + 7] = o.y
	buf[j + 8] = b.x.z
	buf[j + 9] = b.y.z
	buf[j + 10] = b.z.z
	buf[j + 11] = o.z
	buf[j + 12] = c.r
	buf[j + 13] = c.g
	buf[j + 14] = c.b
	buf[j + 15] = c.a


## put() for the common case, a turn about Y and a uniform scale: no Basis built (the rows of
## Basis(UP, yaw).scaled(s) written straight in).
static func put_yaw(buf: PackedFloat32Array, i: int, yaw: float, s: float, o: Vector3, c: Color) -> void:
	var j := i * 16
	var cy := cos(yaw) * s
	var sy := sin(yaw) * s
	buf[j] = cy
	buf[j + 1] = 0.0
	buf[j + 2] = sy
	buf[j + 3] = o.x
	buf[j + 4] = 0.0
	buf[j + 5] = s
	buf[j + 6] = 0.0
	buf[j + 7] = o.y
	buf[j + 8] = -sy
	buf[j + 9] = 0.0
	buf[j + 10] = cy
	buf[j + 11] = o.z
	buf[j + 12] = c.r
	buf[j + 13] = c.g
	buf[j + 14] = c.b
	buf[j + 15] = c.a


var _sent := {}                 ## MultiMesh -> [buffer last sent, box last set]


## Send a whole buffer (and our own box) to a MultiMesh, but only what changed since the last tick:
## a perched roost or a grazing herd that holds still re-sends nothing. On Metal the buffer must go
## as one write (per-instance setters can be lost or read back stale), which this keeps.
func commit(mm: MultiMesh, buf: PackedFloat32Array, box: AABB) -> void:
	if mm == null:
		return
	var last: Array = _sent.get(mm, [])
	if last.is_empty():
		last = [PackedFloat32Array(), AABB()]
		_sent[mm] = last
	if last[1] != box:
		mm.custom_aabb = box
		last[1] = box
	if last[0] != buf:
		mm.buffer = buf
		last[0] = buf.duplicate()


## A glide redraw: the buffer goes straight out (it changed, by construction) and the copy kept
## for commit() is dropped, so the next tick sends its own. The box was padded at the tick for the
## distance a glide can carry anything before the next one, so it is not touched here.
func send(mm: MultiMesh, buf: PackedFloat32Array) -> void:
	mm.buffer = buf
	var last: Array = _sent.get(mm, [])
	if not last.is_empty():
		last[0] = PackedFloat32Array()


## One instance's 16 floats for MultiMesh.buffer (TRANSFORM_3D rows + custom data). Groups write
## their whole buffer once per tick: on Metal, per-instance setters can be lost or read back stale.
static func row(xf: Transform3D, c: Color) -> PackedFloat32Array:
	var b := xf.basis
	var o := xf.origin
	return PackedFloat32Array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, c.r, c.g, c.b, c.a])


static func yaw_to(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


static func wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)


static func turn(a: float, to: float, rate: float) -> float:
	return a + clampf(wrap_angle(to - a), -rate, rate)
