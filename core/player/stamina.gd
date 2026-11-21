extends Node
## Breath (r31): the wanderer's stamina. Gloom is how far the dark has got in; Breath is how much the
## body has left for the next move. A roll, a staff strike, a guarded blow, the cloak-glide and the
## tether all spend it; it comes back fast once you stop spending (BREATH_DELAY), never while you
## hold a guard or glide. Run it to nothing and the wanderer is WINDED until it is back over
## WINDED_UNTIL: no sprint, no roll, the glide folds.
##
## Sprinting only spends Breath with a foe awake nearby (a hunted run): the Realm is crossed at a
## sprint, and a stamina tax on plain travel would only slow exploring down.
## Child of Player, named "Stamina". Load by path (no class_name):
##   const Stamina := preload("res://core/player/stamina.gd")

const Access := preload("res://ui/access.gd")
const FoeIndex := preload("res://core/enemy/foe_index.gd")

const MAX := 100.0
const REGEN := 34.0              ## per second once recovering
const BREATH_DELAY := 0.55       ## seconds after a spend before it starts to come back
const WINDED_UNTIL := 40.0       ## winded until Breath is back over this
const SPRINT_COST := 8.0         ## per second, only with an awake foe within FIGHT_R
const FIGHT_R := 18.0
# what the moves cost (the Player and StaffArts read these)
const ROLL := 22.0
const HOP := 14.0
const AIR_JUMP := 8.0
const WALL_KICK := 8.0
const STRIKE := 9.0
const FINISHER := 12.0
const HEAVY := 26.0
const GLIDE := 8.0               ## per second
const GRAPPLE := 24.0
const PERFECT_REFUND := 18.0     ## a perfect dodge or a parry gives this back

var breath := MAX
var breath_max := MAX            ## gear may raise it (the equipment hook)
var regen_scale := 1.0           ## gear may raise it
var winded := false
var holding := false             ## a guard or a glide is held: no recovery this tick
var _delay := 0.0
var _flash := 0.0                ## 0..1: a refused move or a perfect refund, for the meter
var _flash_good := false
var _fight_t := 0.0
var _fight := false
var _player: Node3D


func _ready() -> void:
	_player = get_parent() as Node3D


func ratio() -> float:
	return clampf(breath / maxf(breath_max, 1.0), 0.0, 1.0)


## Is there enough for a move costing `cost`? Half of it is enough to start (the rest is borrowed and
## the meter drops to empty), so a last roll is never refused for a sliver.
func can(cost: float) -> bool:
	return not winded and breath >= cost * 0.5


## Spend `cost` if the move may go ahead; false (and a red flash) otherwise.
func spend(cost: float) -> bool:
	if not can(cost):
		_flash = 1.0
		_flash_good = false
		return false
	drain(cost)
	return true


## Take `amount` whatever is left (a guarded blow, the glide): empty means winded.
func drain(amount: float) -> void:
	if amount <= 0.0:
		return
	breath = maxf(0.0, breath - amount)
	_delay = BREATH_DELAY
	if breath <= 0.0 and not winded:
		winded = true
		_flash = 1.0
		_flash_good = false
		var pl := _player as Player
		if pl != null:                               # the body stumbles: a short heavy step
			pl._land_slow = maxf(pl._land_slow, 0.35)
			pl._visual.hurt_react(Vector3.INF, 6.0)
		var at := _player.global_position + Vector3.UP * 2.2 if _player else Vector3.INF
		if at != Vector3.INF:
			HitText.pop(at, "winded", Color(0.75, 0.8, 0.95))


## `clears_winded`: a perfect dodge or a parry catches the breath back, so the stumble goes with it.
func refund(amount: float, clears_winded := false) -> void:
	breath = minf(breath_max, breath + amount)
	_flash = 1.0
	_flash_good = true
	if winded and (clears_winded or breath >= WINDED_UNTIL):
		winded = false


func refill() -> void:
	breath = breath_max
	winded = false
	_delay = 0.0


## A foe is awake within FIGHT_R (checked four times a second): sprinting costs Breath.
func in_fight() -> bool:
	return _fight


func flash() -> float:
	return _flash * Access.flash()


func flash_good() -> bool:
	return _flash_good


func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.5)
	_fight_t -= delta
	if _fight_t <= 0.0:
		_fight_t = 0.25
		_fight = _foe_awake()
	if holding:
		_delay = maxf(_delay, 0.2)
	elif _delay > 0.0:
		_delay -= delta
	elif breath < breath_max:
		breath = minf(breath_max, breath + REGEN * regen_scale * delta)
	if winded and breath >= WINDED_UNTIL:
		winded = false
	holding = false                         # set again every tick by whoever holds


func _foe_awake() -> bool:
	if _player == null or not _player.is_inside_tree():
		return false
	var at := _player.global_position
	for node in FoeIndex.around(get_tree(), at, FIGHT_R):         # (4 Hz: not the whole group)
		var e := node as Enemy
		if e == null or not e.is_alive() or e._state == Enemy.IDLE:
			continue
		if e.global_position.distance_squared_to(at) < FIGHT_R * FIGHT_R:
			return true
	return false
