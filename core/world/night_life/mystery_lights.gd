extends Node
## MYSTERY LIGHTS: every secret of the Realm that the wanderer has not yet found shows a strange light, cold teal
## and slow, that breathes in the dark and is seen from far across the land (a card in the night registry, a lent
## real light up close). It sits ON the secret, so following it always leads somewhere: a hidden stair, a barrow, a
## reward, a story beat. Nearer than 70 m it sheds motes now and then. The moment the secret is found (core/life/
## secrets/director.gd marks it) the light flares, throws a ring and a burst of sparks, and goes out for good:
## a solved mystery stops calling. Rows come from the secrets registry (State.sites), re-read every few seconds so the
## sites built late are picked up; found state is the save's (Travel.system_state("secrets")).

const Reg := preload("res://core/world/night_life/night_registry.gd")
const NightFx := preload("res://core/world/night_life/night_fx.gd")
const State := preload("res://core/life/secrets/state.gd")

const POLL := 3.0
const MOTE_RANGE := 70.0

var _poll := 0.0
var _mote := 0.0
var _known := {}                       ## id -> true: found already when first seen (no flare for those)
var _live := {}                        ## id -> world position of the unfound ones


func _process(delta: float) -> void:
	if not Reg.enabled:
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		_sync()
	_mote -= delta
	if _mote <= 0.0:
		_mote = 2.6
		_motes()


func _sync() -> void:
	for s: Dictionary in State.sites:
		var id := String(s.get("id", ""))
		if id == "":
			continue
		var at: Variant = s.get("at", null)
		if not (at is Vector3):
			continue
		var key := "sec_" + id
		var found := State.has("found", id)
		if found:
			if _live.has(id):
				_flare(_live[id] as Vector3)
				_live.erase(id)
			_known[id] = true
			Reg.set_on(key, false)
			continue
		var p: Vector3 = at
		_live[id] = p
		Reg.put(key, p + Vector3(0.0, 1.4, 0.0), Reg.Kind.MYSTERY, 1.0, p.y)


## The unfound secrets near the wanderer let a few motes drift up.
func _motes() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	for id: String in _live:
		var p: Vector3 = _live[id]
		if cp.distance_to(p) > MOTE_RANGE:
			continue
		NightFx.burst(p + Vector3(0.0, 0.8, 0.0), Color(0.5, 0.9, 1.6), "mote", Vector3.UP)


## The moment of finding: a ring, a burst and a flash of the cold light.
func _flare(p: Vector3) -> void:
	var c := Color(0.5, 0.9, 1.7)
	Vfx.ring(p, 3.2, c, 0.9, 0.12)
	NightFx.burst(p + Vector3(0.0, 1.0, 0.0), c, "found")
	Vfx.light(p + Vector3(0.0, 1.4, 0.0), c, 3.4, 9.0, 1.6, 2)
