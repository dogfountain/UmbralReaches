extends "res://core/enemy/husk.gd"
## The Root-Wife (encounters elite, the Grandmother Oak's lair). A husk grown through with oak root:
## antlers of bark, moss for a shawl, a heartwood knot in her chest. Every few seconds she stops and
## the ground opens under you: three root-snares fill (1 s), then burst in thorn; the middle one is
## where you stand, the other two flank it, so a step sideways is not enough. At half health she calls
## two root-grubs up out of the floor. Move through the snare line, not away along it.

const ID := "root_wife"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
const Guardians := preload("res://core/life/encounters/guardians.gd")
const SNARE_EVERY := 6.5
const SNARE_TELL := 1.0
const SNARE_R := 1.9
const SNARE_GLOW := Color(0.5, 1.6, 0.4)
var _snare_cd := 3.5
var _called := false


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	can_charge = false           # her own move is the snare line (the Husk's charge would crowd it)


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _think() -> void:
	_snare_cd -= 1.0 / think_hz
	if _snare_cd <= 0.0 and _state == CHASE and _p != null and _dist > 1.8 and _dist < 13.0 and is_on_floor():
		_snare_cd = SNARE_EVERY
		_set_state(RECOVER)
		_state_t = -SNARE_TELL                 # stands still through the tell
		begin_cast("Root Snare", SNARE_TELL, false)
		_glint = 1.0
		Sfx.play_stream(Kit.Synth.get_stream("roar"), global_position + Vector3.UP * 1.5, -2.0, 0.6)
		var at := _p.global_position
		var side := Vector3(-_to.z, 0.0, _to.x).normalized()
		for off: Vector3 in [Vector3.ZERO, side * 2.7, -side * 2.7]:
			BossKit.zone(get_parent(), at + off, SNARE_TELL, strike_gloom * 0.8, {"by": self, "radius": SNARE_R, "spikes": "thorn", "color": SNARE_GLOW})
		return
	super._think()


func take_hit(dmg: float, from: Node = null) -> void:
	super.take_hit(dmg, from)
	if not _called and _state != DEAD and hp <= float(max_hp) * 0.5 and is_inside_tree():
		_called = true
		BossKit.roar(self, "The Root-Wife calls the grubs up.", SNARE_GLOW)
		var mite := load("res://core/enemy/mite.gd") as GDScript
		var tier := int(get_meta(&"enc_tier", 0))
		BossKit.summon_spread(get_parent(), mite, global_position, 2, 2.8, "elite_" + ID, func(m: Enemy) -> void:     # one a frame
			Guardians.scale_summoned([m], tier, "mite"))
