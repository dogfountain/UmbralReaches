extends "res://core/enemy/husk.gd"
## Captain Varr, the Wall-Breaker (West Marches elite, the Siege Lines' named mini-boss). The Marches'
## siege-captain, still giving the order to go in. A tall husk in the rotted remains of a rampart coat, a
## captain's gorget, a broken ram-beam slung across his back. Two moves, both told on the ground first:
##   Siege Hammer   he plants a foot and brings both fists down: a wide disc in front of him fills for a full
##                  second, then slams. Walk out of it (or through it).
##   Hold the Line  his cry (a gold ring, nothing hurts) calls two conscripts out of the earthwork; once he has
##                  none alive he calls again, never more than two at once. Cut them down, or cut him.
## Haunt: the outer earthwork, between the tower and the palisade (Elites.ELITES "siege_captain").

const ID := "siege_captain"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
const HAMMER_EVERY := 6.0
const HAMMER_TELL := 1.0
const HAMMER_R := 3.4
const CRY_EVERY := 18.0
const CONSCRIPT := preload("res://core/enemy/wretch.gd")
var _hammer_cd := 3.0
var _cry_cd := 6.0


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	can_slam = false                      # his own hammer replaces the husk's fist slam


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _conscripts() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e != self and e is Enemy and (e as Enemy).is_alive() and (e as Node).get_meta(&"summoned_by", "") == "siege_captain" and (e as Node).has_meta(&"conscript_of") and int((e as Node).get_meta(&"conscript_of")) == get_instance_id():
			n += 1
	return n


func _think() -> void:
	_hammer_cd -= 1.0 / think_hz
	_cry_cd -= 1.0 / think_hz
	if _state == CHASE and _p != null and is_on_floor():
		if _cry_cd <= 0.0 and _dist < 22.0 and _conscripts() == 0:
			_cry_cd = CRY_EVERY
			_set_state(RECOVER)
			_state_t = -1.4
			begin_cast("Hold the Line", 1.4, false)
			_glint = 1.0
			Vfx.ring(global_position + Vector3.UP * 0.15, 5.0, Color(2.4, 1.8, 0.7), 1.0, 0.08, Vector3.UP, 1.2)
			Sfx.play_stream(Kit.Synth.get_stream("roar"), global_position + Vector3.UP * 1.5, -2.0, 0.8)
			var eid := get_instance_id()
			get_tree().create_timer(1.4, false).timeout.connect(func() -> void:
				var me := instance_from_id(eid) as Enemy
				if me == null or not me.is_alive():
					return
				for a in BossKit.summon(me.get_parent(), CONSCRIPT, me.global_position, 2, 3.5, "siege_captain"):
					a.set_meta(&"display_name", "Conscript")
					a.set_meta(&"conscript_of", eid))
			return
		if _hammer_cd <= 0.0 and _dist < HAMMER_R + 1.2:
			_hammer_cd = HAMMER_EVERY
			_set_state(RECOVER)
			_state_t = -HAMMER_TELL
			begin_cast("Siege Hammer", HAMMER_TELL, false)
			if _rig is HunchRig:
				(_rig as HunchRig).telegraph(HAMMER_TELL)
			_glint = 1.0
			var fwd := _to / maxf(_dist, 0.001)
			var at := global_position + fwd * 2.2
			BossKit.zone(get_parent(), at, HAMMER_TELL, strike_gloom * 0.95, {"by": self, "radius": HAMMER_R, "color": Color(2.2, 1.5, 0.5)})
			return
	super._think()
