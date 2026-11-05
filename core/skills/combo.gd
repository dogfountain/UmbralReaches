extends RefCounted
## Combo feed (skills, r28): every synergy between spells calls `note()` once when it lands. The
## feed is read by the combo readout (ui/combo_readout.gd) and by tests; a big word pops over the
## spot and a bright chime plays, pitched up as a chain of combos builds. Combos named here:
##   KINDLED RIFT   Ember Lance burst on a Marked foe: the Marks flare (+0.5 each) and it burns
##   SHATTER        Ember Lance or Umbral Nova on a frozen foe (Rime Core): double damage
##   MAELSTROM      Ember Lance burst over an Umbral Well: the well catches fire
##   DETONATION     three or more Marks detonated at once (Nova, Event Horizon, Last Breath)
##   REEL           Rift Tether III drags a Marked foe in and bursts its Marks
##   RIPOSTE LASH   a bolt loosed off a riposte (a strike passed through a Rift Step)
##   SLIP LASH      Rift Step II: the first bolt after a step is a Lash
## Load by path (no class_name): const Combo := preload("res://core/skills/combo.gd")

const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const WINDOW := 5.0           ## combos closer together than this build one chain
const KEEP := 5

static var feed: Array = []   ## newest first: {name, detail, col, t}
static var chain := 0
static var count := {}        ## name -> times noted (tests, the Kindling's build sheet)
static var _chain_until := 0.0


static func now() -> float:
	return Time.get_ticks_msec() * 0.001


static func note(combo: String, at: Vector3, col: Color, detail := "") -> void:
	var t := now()
	chain = chain + 1 if t < _chain_until else 1
	_chain_until = t + WINDOW
	feed.push_front({"name": combo, "detail": detail, "col": col, "t": t})
	if feed.size() > KEEP:
		feed.resize(KEEP)
	count[combo] = int(count.get(combo, 0)) + 1
	if at != Vector3.INF:
		HitText.pop(at + Vector3.UP * 0.7, combo, col)
		StaffSfx.play("combo", at, -5.0, 1.0 + 0.06 * float(mini(chain - 1, 6)), 0.0)


## Seconds left on the current chain (0 when it has lapsed).
static func chain_left() -> float:
	return maxf(0.0, _chain_until - now())


static func reset() -> void:
	feed.clear()
	count.clear()
	chain = 0
	_chain_until = 0.0
