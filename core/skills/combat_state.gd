extends Node
## CombatState (r33 combat): crits, the damage feed, buffs/debuffs with stacks and durations, the
## Resonance builder -> spender loop, the Rift Surge proc and the remembered target. One per player:
## a child of the SkillBook named "Combat" (Player.combat()). Preload by path (no class_name):
##   const CombatState := preload("res://core/skills/combat_state.gd")
##
## ============================== HUD CONTRACT (read-only; the UI only listens) ==============================
## Find:   var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
##         var book := p.skills()            # SkillBook        var cs := p.combat()    # this node
##
## Per hotbar slot i (0..4), SkillBook:
##   book.cooldown_left(i) -> float          seconds left on the slot's own recovery (or an interrupt lockout)
##   book.cooldown_total(i) -> float         the recovery that started it (sweep = left / total)
##   book.on_gcd(i) / gcd_left() / gcd_total()   legacy: there is no shared cooldown now (false / 0 / 0)
##   book.slot_lit(i) -> bool                light the slot: its own primed() or a Rift Surge it would spend
##   book.queued_slot() -> int               legacy: there is no spell queue now (always -1)
##   book.cast_info() -> Dictionary          {} when idle, else {id, name, t, total, kind (&"cast" | &"charge"),
##                                           moving_ok (bool), slot (int), color (Color)} for the cast bar
## Status (buffs/debuffs) on the player or any enemy, this node:
##   cs.statuses_of(node) -> Array[Dictionary]   each {id, name, stacks, max_stacks, time_left, duration,
##                                           icon (StringName hint), kind (&"buff" | &"debuff"), color}
##                                           time_left -1 = no timer (an enemy's Umbral Marks)
##   cs.stacks(node, id) / cs.time_left(node, id)
##   cs.get_target() -> Node3D               the current target, remembered after the camera lock lets go
##                                           (null when none; Player.current_target() is the same)
##   cs.crit_chance (0..1) / CombatState.CRIT_MULT
## Events (autoload/events.gd), emitted from here or the SkillBook:
##   combat_damage(target, amount, crit, school, at)   a hit the wanderer dealt (amount = hp it really
##                                           took when readable). school: &"umbral" | &"ember" | &"physical"
##   status_changed(target, id, stacks, time_left)       applied / refreshed / stacked / expired (stacks 0)
##   proc_triggered(id, reason)                          &"surge" lit (reason &"crit" | &"parry" | &"dodge" | &"riposte")
##   cast_started(id, total) / cast_stopped(id, reason)  reason &"done" | &"moved" | &"interrupted" | &"cancel"
##   spell_queued(id)                                     legacy, no longer emitted (no spell queue)
##   target_changed(target)                               null = cleared
##   skill_cast(id) (existing)                            a spell went off
##
## ============================== DESIGN (adapted from the WoW combat feel) ==============================
## - Cast lock (SkillBook): each spell has its own cooldown; a cast also holds a 0.15 s lock so two
##   buttons on one frame do not double-cast, and a dodge roll cancels it. No shared cooldown, no queue.
## - Cast times: Umbral Well 0.6 s and Bound Shade 1.0 s are rooted casts (moving cancels after a short
##   grace); a hard blow (>= HARD_HIT Gloom after the guard) interrupts a cast or a Lance charge and
##   locks that slot for LOCKOUT (the player is SHAKEN); a lighter blow pushes the cast back.
## - Resonance (builder -> spender): each Rift Bolt that lands (+2 for a Lash) and each staff blow
##   builds a stack (max 5, 8 s, refreshed). Ember Lance and Umbral Nova spend them all: +10 % damage a
##   stack, 1.5 Gloom pushed back a stack, the staff's heat vented, and at 3+ stacks Breath back and a
##   stronger debuff (Ember Scar x2 / Sundered).
## - Debuffs on foes: EMBER SCAR (Lance; a burn that stacks to 3, 6 s), SUNDERED (Nova; +15 % damage
##   taken from the wanderer, 6 s).
## - Rift Surge (proc, "clearcasting"): a crit (40 %, 3 s internal cooldown) or any parry / perfect
##   dodge / riposte lights it. The next Lance throws at full charge on the press (x1.25), the next Nova
##   bursts double, the next cast-time spell is instant.
## - Crits: CRIT_BASE 8 % (+1 % per Resonance stack), x1.6.

const Hints := preload("res://ui/hints.gd")
const RES_MAX := 5
const RES_PER := 0.10           ## spender damage per Resonance stack spent
const RES_GLOOM := 1.5          ## Gloom pushed back per stack spent
const RES_BREATH := 4.0         ## Breath back per stack spent, at 3+
const CRIT_BASE := 0.08
const CRIT_PER_RES := 0.01
const CRIT_MULT := 1.6
const SURGE_ON_CRIT := 0.4
const SURGE_ICD := 3.0
const SURGE_LANCE := 1.25
const NOVA_BURST := 0.35        ## Resonant burst per stack spent (Nova), per foe in the ring
const SUNDER_VULN := 0.15
const TARGET_KEEP := 52.0       ## a remembered target further than this is forgotten

const DEFS := {
	&"resonance": {"name": "Resonance", "kind": &"buff", "max": RES_MAX, "dur": 8.0, "icon": &"resonance", "color": Color(1.2, 0.6, 2.6)},
	&"surge": {"name": "Rift Surge", "kind": &"buff", "max": 1, "dur": 10.0, "icon": &"surge", "color": Color(2.4, 1.6, 0.8)},
	&"shaken": {"name": "Shaken", "kind": &"debuff", "max": 1, "dur": 1.5, "icon": &"shaken", "color": Color(1.4, 0.4, 0.35)},
	&"ember_scar": {"name": "Ember Scar", "kind": &"debuff", "max": 3, "dur": 6.0, "icon": &"ember_scar", "color": Color(2.6, 0.9, 0.3),
		"tick": 1.0, "tick_dmg": 0.25, "school": &"ember"},
	&"sundered": {"name": "Sundered", "kind": &"debuff", "max": 1, "dur": 6.0, "icon": &"sundered", "color": Color(0.9, 0.6, 1.4)},
}
const MARK_DEF := {"name": "Umbral Mark", "kind": &"debuff", "icon": &"mark", "color": Color(1.4, 0.6, 3.0)}

var player: Node3D
var crit_chance := CRIT_BASE    ## base chance; tests set 0 for exact numbers
var rng := RandomNumberGenerator.new()
var target: Node3D              ## the current (remembered) target
var crits := 0                  ## tests
var procs := 0                  ## tests

var _recs := {}                 ## instance id -> {"node": Node, "st": {id -> rec}}
var _surge_icd := 0.0
var _target_t := 0.0


func _ready() -> void:
	rng.randomize()
	var book := get_parent()
	player = book.get_parent() as Node3D if book else null


static func of(n: Node) -> Node:
	if n == null or not n.is_inside_tree():
		return null
	var p := n.get_tree().get_first_node_in_group(Groups.PLAYER)
	if p == null or not p.has_method("combat"):
		return null
	return p.call("combat") as Node


# --- statuses ----------------------------------------------------------------------------------------

## Apply `stacks` of status `id` to `node`: a fresh one starts, an existing one refreshes its timer and
## adds stacks up to the max. `dur` < 0 uses the definition's. Returns the stacks now held.
func apply(node: Node, id: StringName, stacks := 1, dur := -1.0) -> int:
	if node == null or not is_instance_valid(node) or not DEFS.has(id):
		return 0
	var d: Dictionary = DEFS[id]
	var key := node.get_instance_id()
	if not _recs.has(key):
		_recs[key] = {"node": node, "st": {}}
	var st: Dictionary = _recs[key]["st"]
	var full := float(d["dur"]) if dur < 0.0 else dur
	var r: Dictionary = st.get(id, {})
	if r.is_empty():
		r = {"id": id, "stacks": 0, "left": full, "dur": full, "tick": float(d.get("tick", 0.0))}
		st[id] = r
	r["stacks"] = mini(int(d["max"]), int(r["stacks"]) + maxi(stacks, 1))
	r["left"] = full
	r["dur"] = full
	Events.status_changed.emit(node, id, int(r["stacks"]), full)
	return int(r["stacks"])


## Remove status `id`; returns the stacks it had.
func consume(node: Node, id: StringName) -> int:
	if node == null:
		return 0
	var key := node.get_instance_id()
	if not _recs.has(key):
		return 0
	var st: Dictionary = _recs[key]["st"]
	if not st.has(id):
		return 0
	var n := int((st[id] as Dictionary)["stacks"])
	st.erase(id)
	if is_instance_valid(node):
		Events.status_changed.emit(node, id, 0, 0.0)
	return n


func has(node: Node, id: StringName) -> bool:
	return stacks(node, id) > 0


func stacks(node: Node, id: StringName) -> int:
	var r := _rec(node, id)
	return int(r.get("stacks", 0))


func time_left(node: Node, id: StringName) -> float:
	var r := _rec(node, id)
	return float(r.get("left", 0.0))


func _rec(node: Node, id: StringName) -> Dictionary:
	if node == null:
		return {}
	var e: Dictionary = _recs.get(node.get_instance_id(), {})
	if e.is_empty():
		return {}
	return (e["st"] as Dictionary).get(id, {})


## Everything on `node` for a buff row / target frame (a snapshot; cheap, a handful of entries).
func statuses_of(node: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if node == null or not is_instance_valid(node):
		return out
	var e: Dictionary = _recs.get(node.get_instance_id(), {})
	if not e.is_empty():
		for id: StringName in (e["st"] as Dictionary):
			var r: Dictionary = e["st"][id]
			var d: Dictionary = DEFS[id]
			out.append({"id": id, "name": d["name"], "stacks": r["stacks"], "max_stacks": d["max"], "time_left": r["left"],
				"duration": r["dur"], "icon": d["icon"], "kind": d["kind"], "color": d["color"]})
	var mk: Variant = node.get("marks")
	if mk is int and int(mk) > 0:
		out.append({"id": &"mark", "name": MARK_DEF["name"], "stacks": int(mk), "max_stacks": Enemy.MARK_MAX,
			"time_left": -1.0, "duration": -1.0, "icon": MARK_DEF["icon"], "kind": MARK_DEF["kind"], "color": MARK_DEF["color"]})
	return out


func clear(node: Node) -> void:
	if node == null:
		return
	var e: Dictionary = _recs.get(node.get_instance_id(), {})
	if e.is_empty():
		return
	for id: StringName in (e["st"] as Dictionary).keys():
		consume(node, id)


func _physics_process(delta: float) -> void:
	_surge_icd = maxf(0.0, _surge_icd - delta)
	_target_t -= delta
	if _target_t <= 0.0:
		_target_t = 0.5
		_check_target()
	if _recs.is_empty():
		return
	for key: int in _recs.keys():
		var e: Dictionary = _recs[key]
		var nv: Variant = e["node"]
		if not is_instance_valid(nv):
			_recs.erase(key)
			continue
		var node := nv as Node
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			_recs.erase(key)
			continue
		var st: Dictionary = e["st"]
		for id: StringName in st.keys():
			var r: Dictionary = st[id]
			r["left"] = float(r["left"]) - delta
			var d: Dictionary = DEFS[id]
			if d.has("tick"):
				r["tick"] = float(r["tick"]) - delta
				if float(r["tick"]) <= 0.0:
					r["tick"] = float(d["tick"])
					deal(node, float(d["tick_dmg"]) * float(r["stacks"]), d["school"], null, {"dot": true})
					if not is_instance_valid(node):
						break
			if float(r["left"]) <= 0.0:
				st.erase(id)
				if is_instance_valid(node):
					Events.status_changed.emit(node, id, 0, 0.0)
		if st.is_empty():
			_recs.erase(key)


# --- damage ------------------------------------------------------------------------------------------

## Every hit the wanderer's spells and staff land goes through here: Sundered, the crit roll, the
## hit itself, the damage event and the crit proc. opts: "crit" (bool, false = never), "dot" (bool:
## no proc), "at" (Vector3). Returns {amount, crit}.
func deal(node: Node, dmg: float, school: StringName, from: Node = null, opts := {}) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.has_method("take_hit") or dmg <= 0.0:
		return {}
	var amount := dmg
	if has(node, &"sundered"):
		amount *= 1.0 + SUNDER_VULN
	var crit := false
	if bool(opts.get("crit", true)):
		var chance := crit_chance + CRIT_PER_RES * float(stacks(player, &"resonance")) if crit_chance > 0.0 else 0.0
		crit = rng.randf() < chance
	if crit:
		amount *= CRIT_MULT
		crits += 1
	var before: Variant = node.get("hp")
	var at: Vector3 = opts.get("at", Vector3.INF)
	if at == Vector3.INF and node is Node3D:
		var hb: Variant = node.get("hp_bar_y")
		at = (node as Node3D).global_position + Vector3.UP * (float(hb) + 0.35 if hb != null else 1.6)
	node.take_hit(amount, from)
	var dealt := amount
	if before is float and is_instance_valid(node):
		var after: Variant = node.get("hp")
		if after is float:
			dealt = maxf(0.0, float(before) - float(after))
	Events.combat_damage.emit(node, dealt, crit, school, at)
	var tv: Variant = target
	if node is Enemy and (node as Enemy).is_alive() and not _target_ok(tv):
		set_target(node as Node3D)
	if crit and not bool(opts.get("dot", false)):
		if _surge_icd <= 0.0 and rng.randf() < SURGE_ON_CRIT:
			proc_surge(&"crit")
	return {"amount": dealt, "crit": crit}


## Light Rift Surge (a crit, a parry, a perfect dodge, a riposte).
func proc_surge(reason: StringName) -> void:
	if player == null:
		return
	_surge_icd = SURGE_ICD
	procs += 1
	var fresh := not has(player, &"surge")
	apply(player, &"surge")
	Events.proc_triggered.emit(&"surge", reason)
	if fresh and player.is_inside_tree():
		var at := player.global_position + Vector3.UP * 2.5
		HitText.pop(at, "RIFT SURGE", Color(2.4, 1.6, 0.8), true)
		Vfx.burst(player.global_position + Vector3.UP * 1.2, Color(2.4, 1.5, 0.7), {"count": 20, "life": 0.45, "speed": Vector2(1.0, 3.0), "size": 0.045, "gravity": -1.0, "radius": 0.4, "trail": 0.06})
		Hints.once(&"rift_surge", "RIFT SURGE: a crit or a parry lights it. Your next Lance throws at full charge, your next Nova bursts double, your next cast is instant.")


## A builder landed: `n` Resonance on the wanderer.
func build(n := 1) -> void:
	if player != null and n > 0:
		apply(player, &"resonance", n)


## Umbral Nova's spend: a Resonant burst on every foe in the ring (NOVA_BURST a stack, doubled by a
## Surge), and Sundered on each. Called by the SkillBook after the Nova went off.
func nova_burst(radius: float, spent: int, surged: bool) -> int:
	if player == null or not player.is_inside_tree():
		return 0
	var hit := 0
	var dmg := NOVA_BURST * float(spent) * (2.0 if surged else 1.0) + (1.0 if surged else 0.0)
	var r2 := radius * radius
	for node in player.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e == null or not e.is_alive():
			continue
		var d := e.global_position - player.global_position
		if absf(d.y) > 3.0 or Vector2(d.x, d.z).length_squared() > r2:
			continue
		apply(e, &"sundered")
		if dmg > 0.0:
			deal(e, dmg, &"umbral", player)
		hit += 1
	return hit


# --- target ------------------------------------------------------------------------------------------

func set_target(t: Node3D) -> void:
	var tv: Variant = target
	if is_instance_valid(tv) and t == target:
		return
	target = t
	Events.target_changed.emit(t)


func _target_ok(tv: Variant) -> bool:
	if tv == null or not is_instance_valid(tv):
		return false
	var t := tv as Node3D
	if t == null or not t.is_inside_tree():
		return false
	if t.has_method("is_alive") and not bool(t.call("is_alive")):
		return false
	return player == null or player.global_position.distance_to(t.global_position) <= TARGET_KEEP


func _check_target() -> void:
	var tv: Variant = target
	if tv != null and not _target_ok(tv):
		target = null
		Events.target_changed.emit(null)


## The current target, or null (never a freed one).
func get_target() -> Node3D:
	var tv: Variant = target
	return target if _target_ok(tv) else null
