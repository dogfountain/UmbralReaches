extends "res://core/enemy/wretch.gd"
## Hobb, Who Knocks Thrice (encounters elite). Maud's son, come down from the Stair: a tall wretch
## in a pilgrim's hood. Three knocks (audible) open a chain of up to three blows; every blow has
## its own full windup and cone. A stagger or riposte breaks the chain.

const ID := "hobb"
const Elites := preload("res://core/life/encounters/elites.gd")
const Kit := preload("res://core/life/encounters/elite_kit.gd")
var _combo := 0


func _init() -> void:
	super._init()
	Kit.stats(self, ID)
	strike_range = 1.7
	windup_time = 0.45
	lunge = 5.5
	combo_max = 0              # Hobb's chain is his own three knocks
	feint_chance = 0.0


func _build() -> void:
	super._build()
	Elites.dress(self, ID)


func _think() -> void:
	if _state == RECOVER and _combo > 0 and _combo < 3 and _state_t >= 0.1 and _p != null and _dist <= strike_range + 1.0 and _take_token():
		_combo += 1
		_face_dir = _to / maxf(_dist, 0.001)
		_set_state(WINDUP)
		return
	if _state == CHASE or _state == IDLE:
		_combo = 0
	super._think()


func _on_state(next: int) -> void:
	if next == WINDUP and _combo == 0:
		_combo = 1
		Kit.knock(self, 3, 0.13, 0.75)
	super._on_state(next)


func stagger(extra_time := 0.0) -> void:
	_combo = 9
	super.stagger(extra_time)


func riposted() -> void:
	_combo = 9
	super.riposted()
