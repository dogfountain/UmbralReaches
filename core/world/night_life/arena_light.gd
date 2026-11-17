extends Node3D
## THE BOSS ARENAS' LIGHT AND AIR (one node for all five). When a boss is engaged (Events.boss_engaged) the arena takes the palette of
## its boss, and each phase of the fight changes it:
##   the Thornwarden   sickly green mist, then thorn-crimson creeping in, then blood-red pulses;
##   the Bone Abbot    candle gold, then cold bone-blue, then the reliquary's ember red;
##   the Ascended Warden  ivory and gold, then white-blue, then a blinding white (the moon given up);
##   the Anchoress     drowned teal, then deep sea-blue, then a cold white lantern light;
##   the Speaking Crown  brass and ember, then violet, then a furnace red.
## What changes: the fog's colour and its emission (never its density: the weather owns that), the moon dims to two thirds while
## it lasts (night_registry arena_dim), and a ring of unshadowed set-piece lights (two, three or four by the detail setting, class
## "player_orb": outside the lamps' budget, gone when the fight is) stands on the arena's rim in the phase's colour, flickering and
## turning slowly. A change of phase is marked: a ring and a burst at the boss, a flash, every landmark card flaring (the registry
## pulse), the lights surging. All of it eased with dt (colours at 1.2 to 2 per second): nothing snaps in or out; a wipe, a kill, a
## fast travel or the Living Night off eases it back to the night's own fog. Cost: up to four lights while a boss is up, a
## handful of colour writes a frame; nothing otherwise.

const Reg := preload("res://core/world/night_life/night_registry.gd")
const Access := preload("res://ui/access.gd")
const NightFx := preload("res://core/world/night_life/night_fx.gd")

## [fog colour, fog emission, light colour, light energy] per phase (1, 2, 3).
const PAL := {
	"thorn": [[Color(0.10, 0.28, 0.12), Color(0.2, 0.6, 0.25), Color(0.45, 0.95, 0.4), 1.6], [Color(0.3, 0.14, 0.08), Color(0.8, 0.3, 0.12), Color(1.0, 0.5, 0.2), 1.9], [Color(0.45, 0.05, 0.07), Color(1.0, 0.12, 0.14), Color(1.0, 0.2, 0.2), 2.3]],
	"abbot": [[Color(0.35, 0.24, 0.1), Color(1.0, 0.7, 0.3), Color(1.0, 0.72, 0.35), 1.8], [Color(0.12, 0.18, 0.32), Color(0.5, 0.7, 1.0), Color(0.7, 0.82, 1.0), 1.9], [Color(0.4, 0.1, 0.05), Color(1.0, 0.3, 0.1), Color(1.0, 0.4, 0.15), 2.4]],
	"warden": [[Color(0.3, 0.26, 0.14), Color(1.0, 0.9, 0.6), Color(1.0, 0.92, 0.7), 2.0], [Color(0.2, 0.24, 0.34), Color(0.8, 0.9, 1.0), Color(0.85, 0.92, 1.0), 2.3], [Color(0.5, 0.5, 0.55), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0), 3.0]],
	"anchoress": [[Color(0.05, 0.2, 0.24), Color(0.2, 0.65, 0.75), Color(0.3, 0.8, 0.9), 1.7], [Color(0.04, 0.08, 0.22), Color(0.15, 0.3, 0.8), Color(0.25, 0.4, 1.0), 1.9], [Color(0.2, 0.26, 0.3), Color(0.8, 0.95, 1.0), Color(0.9, 1.0, 1.0), 2.4]],
	"crown": [[Color(0.3, 0.16, 0.06), Color(1.0, 0.5, 0.2), Color(1.0, 0.55, 0.22), 1.9], [Color(0.22, 0.1, 0.28), Color(0.65, 0.3, 0.9), Color(0.75, 0.4, 1.0), 2.0], [Color(0.45, 0.08, 0.04), Color(1.0, 0.25, 0.1), Color(1.0, 0.3, 0.12), 2.5]],
}

var env: Environment
var _boss: Node3D
var _arena: Variant                       ## the BossArena node (its `radius`), or null
var _pal: Array = []
var _phase := 1
var _key := "crown"
var _goal := 0.0
var _k := 0.0                             ## 0 the night's own air .. 1 the fight's
var _lights: Array[OmniLight3D] = []
var _base := {}
var _fog := Color(0, 0, 0)
var _emit := Color(0, 0, 0)
var _lc := Color(1, 1, 1)
var _le := 0.0
var _t := 0.0
var _gone := 0.0


func _ready() -> void:
	for i in 4:
		var l := OmniLight3D.new()
		l.name = "ArenaLight%d" % i
		l.shadow_enabled = false
		l.omni_range = 9.0
		l.omni_attenuation = 1.2
		l.light_energy = 0.0
		l.light_volumetric_fog_energy = 0.8
		l.set_meta("light_class", "player_orb")
		l.visible = false
		add_child(l)
		_lights.append(l)
	if env != null:
		_base = {"fog": env.fog_light_color, "emit": env.volumetric_fog_emission, "emit_e": env.volumetric_fog_emission_energy}
	Events.boss_engaged.connect(_on_engaged)
	Events.boss_slain.connect(func(_id: String) -> void: _goal = 0.0)
	Events.hollowed.connect(func() -> void: _goal = 0.0)
	Events.respawned.connect(func(_at: Vector3) -> void: _goal = 0.0)


static func key_for(title: String) -> String:
	var t := title.to_lower()
	if t.contains("thorn"):
		return "thorn"
	if t.contains("abbot"):
		return "abbot"
	if t.contains("warden") or t.contains("ascended"):
		return "warden"
	if t.contains("anchor"):
		return "anchoress"
	return "crown"


static func palette_for(title: String) -> Array:
	return PAL[key_for(title)]


func _on_engaged(boss: Node, title: String) -> void:
	if not (boss is Node3D) or not Reg.enabled:
		return
	_boss = boss as Node3D
	_pal = palette_for(title)
	_key = key_for(title)
	_phase = 1
	_goal = 1.0
	# the arena the boss stands in: the nearest of the arenas
	var best := 1e12
	_arena = null
	for a: Node in get_tree().get_nodes_in_group(&"boss_arena"):
		var n3 := a as Node3D
		if n3 == null:
			continue
		var d := n3.global_position.distance_squared_to(_boss.global_position)
		if d < best:
			best = d
			_arena = a
	var first: Array = _pal[0]
	_fog = first[0]
	_emit = first[1]
	_lc = first[2]
	_le = float(first[3])


func _process(delta: float) -> void:
	_t += delta
	if not Reg.enabled:
		_goal = 0.0
	if _goal > 0.0 and (_boss == null or not is_instance_valid(_boss) or not _boss.is_inside_tree()):
		_goal = 0.0
	if _goal > 0.0 and _boss is Enemy and not (_boss as Enemy).is_alive():
		_goal = 0.0
	_k = lerpf(_k, _goal, 1.0 - exp(-(1.2 if _goal > 0.0 else 0.9) * delta))
	if _k < 0.003 and _goal <= 0.0:
		if _k > 0.0:
			_k = 0.0
			_apply(0.0)
			Reg.arena_dim = 1.0
			for l in _lights:
				l.visible = false
		return
	if _goal > 0.0:
		_watch_phase()
		var pal: Array = _pal[clampi(_phase, 1, 3) - 1]
		_fog = _fog.lerp(pal[0], 1.0 - exp(-1.5 * delta))
		_emit = _emit.lerp(pal[1], 1.0 - exp(-1.5 * delta))
		_lc = _lc.lerp(pal[2], 1.0 - exp(-2.0 * delta))
		_le = lerpf(_le, float(pal[3]), 1.0 - exp(-2.0 * delta))
	_apply(_k)
	Reg.arena_dim = lerpf(1.0, 0.66, _k)
	_lights_step(delta)


## The phase: the boss's own `phase` if it keeps one, else its health in thirds.
func _watch_phase() -> void:
	var p := 1
	var ph: Variant = _boss.get("phase")
	if ph is int:
		p = clampi(int(ph), 1, 3)
	elif _boss is Enemy:
		var e := _boss as Enemy
		var r := float(e.hp) / maxf(float(e.max_hp), 1.0)
		p = 1 if r > 0.66 else (2 if r > 0.33 else 3)
	if p != _phase:
		_phase = p
		_mark(p)


## A change of phase: a ring and a burst at the boss, a flash, every landmark flaring, the lights surging.
func _mark(p: int) -> void:
	var pal: Array = _pal[clampi(p, 1, 3) - 1]
	var c: Color = pal[2]
	var at := _boss.global_position
	var hot := Color(c.r * 2.2, c.g * 2.2, c.b * 2.2)
	Vfx.ring(at, 7.0, hot, 0.9, 0.16, Vector3.UP, Access.flash())
	Vfx.ring(at, 3.5, hot, 0.6, 0.1, Vector3.UP, Access.flash())
	NightFx.burst(at + Vector3(0.0, 1.5, 0.0), hot, "arena_mark")
	Vfx.light(at + Vector3(0.0, 2.0, 0.0), c, 4.5, 16.0, 0.8, 3)
	# each boss's phase has its own gesture in the air: thorns lift embers, the Abbot's candles gutter up gold, the Warden's white ring is a great
	# one, the Anchoress's bubbles rise, the Crown's brass sparks fall
	var hot2 := Color(c.r * 2.0, c.g * 2.0, c.b * 2.0)
	match _key:
		"thorn":
			NightFx.burst(at, hot2, "kindle", Vector3.UP, 0.6)
		"abbot":
			NightFx.burst(at + Vector3(0.0, 1.0, 0.0), hot2, "mote", Vector3.UP)
		"warden":
			Vfx.ring(at, 12.0, hot2, 1.3, 0.2)
		"anchoress":
			NightFx.burst(at, hot2, "mote", Vector3.UP)
		_:
			NightFx.burst(at + Vector3(0.0, 4.0, 0.0), hot2, "kindle", Vector3.DOWN, 0.6)
	Reg.pulse = 0.8 * Access.flash()
	_le += 1.5


func _apply(k: float) -> void:
	if env == null or _base.is_empty():
		return
	env.fog_light_color = (_base.fog as Color).lerp(_fog, k * 0.7)
	env.volumetric_fog_emission = (_base.emit as Color).lerp(_emit, k)
	env.volumetric_fog_emission_energy = lerpf(float(_base.emit_e), float(_base.emit_e) * 2.2, k)


## The ring of set-piece lights on the arena's rim.
func _lights_step(delta: float) -> void:
	var count: int = [2, 3, 4][clampi(Settings.detail, 0, 2)]
	var centre := Vector3.ZERO
	if _arena != null and is_instance_valid(_arena):
		centre = (_arena as Node3D).global_position
	elif _boss != null and is_instance_valid(_boss):
		centre = _boss.global_position
	var radius := 7.0
	if _arena != null and "radius" in _arena:
		radius = float(_arena.radius)
	for i in _lights.size():
		var l := _lights[i]
		if i >= count or _goal <= 0.0 and _k < 0.05:
			l.light_energy = move_toward(l.light_energy, 0.0, delta * 4.0)
			l.visible = l.light_energy > 0.02
			continue
		var a := TAU * float(i) / float(count) + _t * 0.08 + float(_phase) * 0.7
		var p := centre + Vector3(cos(a), 0.0, sin(a)) * radius * 0.85 + Vector3(0.0, 2.4, 0.0)
		l.global_position = p
		l.light_color = _lc
		l.omni_range = radius * 1.1
		var flick := 1.0 + 0.12 * sin(_t * 7.0 + float(i) * 2.0) + 0.06 * sin(_t * 17.0 + float(i))
		l.light_energy = _le * _k * flick * (0.6 + 0.4 * sin(_t * 0.7 + float(i)))
		l.visible = l.light_energy > 0.02
