extends Node
## The progression runtime (docs/LIFE_PLAN.md, system "progression"). One per Realm, added by
## progression.gd. It owns nothing of the player's: it reads Travel.system_state("progression"),
## turns it into modifiers (UpgradeDB.mods -> UpgradeDB.live) and applies them from outside:
##   - player exports: gloom_max, gloom_rate_dark/rift, gloom_drain_lit, step_range, step_evade
##   - the SkillBook's slots are swapped for the subclasses under skills/ (same ids, same hotbar)
##     once anything is owned; their cooldown / max_charge are set here
##   - the loadout: slot 0 is Rift Bolt, slots 1..4 hold any known spell (the stock four by
##     default; Rift Tether, Umbral Well and Bound Shade once learned), swapped at a fire
##   - the staff core: the orb's look (orb_core.gd) and every Rift Bolt (MagicBolt.core)
##   - Events.enemy_killed -> extra Gloom relief (Oath of the Hollow, Lisle's Tally-Bead)
## It also puts a "Tend the fire" spot on every kindled brazier (fire_spot.gd), lays the six
## charms in the world (charm_pickup.gd), and spends ash for the Kindling menu (ui/growth.gd).

const DB := preload("res://core/life/progression/upgrade_db.gd")
const PathsDB := preload("res://core/life/progression/paths_db.gd")
const HearthDB := preload("res://core/life/progression/hearth_db.gd")
const FireSpot := preload("res://core/life/progression/fire_spot.gd")
const CharmPickup := preload("res://core/life/progression/charm_pickup.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const SealedSkill := preload("res://core/skills/skill_sealed.gd")
const SKILLS := {
	&"bolt": preload("res://core/life/progression/skills/bolt.gd"),
	&"lance": preload("res://core/life/progression/skills/lance.gd"),
	&"nova": preload("res://core/life/progression/skills/nova.gd"),
	&"ward": preload("res://core/life/progression/skills/ward.gd"),
	&"step": preload("res://core/life/progression/skills/step.gd"),
}
## Spells learned at the Kindling (no stock version; always their own script).
const LEARNED := {
	&"tether": preload("res://core/skills/skill_tether.gd"),
	&"well": preload("res://core/skills/skill_well.gd"),
	&"familiar": preload("res://core/skills/skill_familiar.gd"),
}
const OrbCore := preload("res://core/skills/orb_core.gd")
const CorePickup := preload("res://core/life/progression/core_pickup.gd")
const FIRE_REACH := 5.0            ## metres from a lit brazier that count as "at the fire"
const SID := "progression"

var _player: Player
var _base := {}                    ## the player's own numbers, read once per player
var _vanilla := {}                 ## skill id -> {cooldown, max_charge} of the stock skill
var _spots := {}                   ## brazier instance id -> FireSpot
var _scan := 0.0
var _charms_laid := false
var _pending_fx: Node3D = null     ## brazier to flare when the Kindling closes after a purchase
var _orb_core := "?"               ## the core last shown on the orb


func _ready() -> void:
	name = "Progression"
	add_to_group(SID)
	_ensure_state()
	refresh()
	if not InputMap.has_action("kindling"):
		InputMap.add_action("kindling")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_K
		InputMap.action_add_event("kindling", k)
	Events.enemy_killed.connect(_on_killed)
	Events.boss_slain.connect(_on_boss)
	Events.seal_broken.connect(func(_id: String) -> void: teach("step"))      # r35: the first seal
	Events.item_gained.connect(_on_item)
	for c: Script in SKILLS.values():
		var stock: Skill = (c.get_base_script() as GDScript).new()
		_vanilla[stock.id] = {"cooldown": stock.cooldown, "max_charge": stock.max_charge}
	for c: Script in LEARNED.values():
		var sk: Skill = (c as GDScript).new()
		_vanilla[sk.id] = {"cooldown": sk.cooldown, "max_charge": sk.max_charge}


func _process(delta: float) -> void:
	_scan -= delta
	if _scan > 0.0:
		return
	_scan = 0.5
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	if p != _player and p != null and p.skills() != null and not p.skills().slots.is_empty():
		_player = p
		_base.clear()
		_orb_core = "?"
		apply()
	_place_spots()
	if not _charms_laid and _realm_ready():
		_charms_laid = true
		_lay_charms()


# --- state ------------------------------------------------------------------------------------

func state() -> Dictionary:
	return Travel.system_state(SID)


func _ensure_state() -> void:
	var st := state()
	if not st.has("taught"):
		# r35: a new game starts with Rift Bolt; a save from before staging keeps all five
		var fresh := st.is_empty() and Travel.bosses_slain.is_empty() and Travel.seals_broken.is_empty() \
				and not ((Travel.story.get("flags", {}) as Dictionary).has("arrived") if Travel.story.get("flags", {}) is Dictionary else false)
		st["taught"] = [] if fresh else DB.TAUGHT_LATER.duplicate()
	for k: String in ["ranks", "oaths"]:
		if not (st.get(k) is Dictionary):
			st[k] = {}
	for k: String in ["worn", "known"]:
		if not (st.get(k) is Array):
			st[k] = []
	st["spent"] = int(st.get("spent", 0))
	st["tier"] = DB.tier_of(st)


## Recompute the live modifiers from the save and push them onto the player.
func refresh() -> void:
	_ensure_state()
	var m := DB.mods(state())
	# the Paths (Remembrances), the Hearthfire, Hild's works, meals and Rested (hearth.gd)
	PathsDB.apply(m, state())
	HearthDB.apply(m, Travel.system_state("hearth"))
	DB.live = m
	apply()


func ash() -> int:
	return Travel.count("grave_ash")


func bosses() -> int:
	return Travel.bosses_slain.size()


# --- applying ---------------------------------------------------------------------------------

func apply() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var p := _player
	if _base.is_empty():
		for k: String in ["gloom_max", "gloom_rate_dark", "gloom_rate_rift", "gloom_drain_lit", "wounds_mend_lit", "step_range", "step_evade",
				"walk_speed", "sprint_speed", "jump_velocity"]:
			_base[k] = float(p.get(k))
	var m := DB.live
	p.gloom_max = _base.gloom_max + float(m.get("gloom_add", 0.0))
	p.gloom_rate_dark = _base.gloom_rate_dark * float(m.get("dark_mult", 1.0))
	p.gloom_rate_rift = _base.gloom_rate_rift * float(m.get("dark_mult", 1.0))
	p.gloom_drain_lit = _base.gloom_drain_lit * float(m.get("lit_mult", 1.0))
	p.wounds_mend_lit = _base.wounds_mend_lit * float(m.get("lit_mult", 1.0))   # r35: a fire's relief mends Wounds too
	p.step_range = _base.step_range + (2.0 if int(m.get("step", 0)) >= 1 else 0.0) + float(m.get("step_range", 0.0))
	p.step_evade = (0.6 if int(m.get("step", 0)) >= 2 else _base.step_evade) + float(m.get("step_evade_add", 0.0))
	# the Road (paths_db.gd): pace and spring
	p.walk_speed = _base.walk_speed * float(m.get("move_mult", 1.0))
	p.sprint_speed = _base.sprint_speed * float(m.get("move_mult", 1.0))
	p.jump_velocity = _base.jump_velocity * float(m.get("jump_mult", 1.0))
	if p.gloom > p.gloom_max:
		p.gloom = p.gloom_max
	p.add_gloom(0.0)                                  # the HUD redraws the bar at the new size
	_apply_skills(p.skills())
	var core := String(m.get("core", ""))
	if core != _orb_core:
		_orb_core = core
		OrbCore.apply(p, core)


## Fill the five slots from the loadout (Rift Bolt, then the four chosen spells). A stock spell is
## swapped for its progression subclass once anything is owned (and back if the save is wiped);
## then the numbers that live on the Skill resource are set. An instance whose script is already
## right is kept (its chain, its shades).
func _apply_skills(book: SkillBook) -> void:
	if book == null:
		return
	var st := state()
	var owned := int(st.get("tier", 0)) > 0 or not DB.worn(st).is_empty() or DB.core_of(st) != "" or DB.GearStats.any_worn()   # gear: worn gear needs the tuned skills too
	var m := DB.live
	var ids: Array = ["bolt"] + DB.loadout(st)
	for i in mini(book.slots.size(), ids.size()):
		if String(ids[i]) == "":
			# r35: nothing taught for this slot yet: it stays sealed (empty, casts nothing)
			if book.slots[i] == null or book.slots[i].id != &"sealed":
				var sealed: Skill = SealedSkill.new()
				book.set_slot(i, sealed)
			continue
		var sid := StringName(String(ids[i]))
		var want := _script_for(sid, owned)
		if want == null:
			continue
		var s := book.slots[i]
		if s == null or s.get_script() != want:
			s = want.new()
			book.set_slot(i, s)
		else:
			s.action = SkillBook.SLOT_ACTIONS[i]
		var tuned: bool = LEARNED.has(sid) or (SKILLS.has(sid) and s.get_script() == SKILLS[sid])
		if not tuned:
			continue
		var v: Dictionary = _vanilla.get(s.id, {})
		var cd := float(v.get("cooldown", s.cooldown))
		match s.id:
			&"nova":
				if int(m.get("nova", 0)) >= 2:
					cd = 5.5
			&"ward":
				if int(m.get("ward", 0)) >= 2:
					cd = 17.0
			&"step":
				if bool(m.get("door", false)):
					cd *= 0.5
				cd *= float(m.get("step_cd", 1.0))
			&"tether":
				if bool(m.get("hook", false)):
					cd -= 2.0
			&"lance":
				var ch := float(v.get("max_charge", s.max_charge))
				if int(m.get("lance", 0)) >= 1:
					ch *= 0.75
				s.max_charge = ch * float(m.get("lance_charge", 1.0))
		s.cooldown = cd * maxf(0.4, float(m.get("cd", 1.0)))
		var r := int(m.get(String(s.id), 0))
		var sp := DB.spell(String(s.id))
		if r > 0 and not sp.is_empty():
			s.blurb = "%s  [%s: %s]" % [s.blurb.split("  [")[0], ["I", "II", "III"][r - 1], String(sp.ranks[r - 1][0])]


func _script_for(id: StringName, owned: bool) -> Script:
	if LEARNED.has(id):
		return LEARNED[id]
	if not SKILLS.has(id):
		return null
	var mine: Script = SKILLS[id]
	return mine if owned else mine.get_base_script()


func _on_killed(e: Node) -> void:
	teach("lance")                                    # r35: the first kill
	var relief := float(DB.live.get("kill_relief", 0.0))
	if relief <= 0.0 or _player == null or not is_instance_valid(_player) or not (e is Node3D):
		return
	if (e as Node3D).global_position.distance_to(_player.global_position) <= 28.0:
		_player.mend(relief)                          # r35: a kill's relief mends Wounds (Gloom is the dark's alone)


func _on_boss(_id: String) -> void:
	teach("nova")                                     # r35: the first great one
	get_tree().create_timer(7.0, false).timeout.connect(func() -> void:
		Events.toast.emit("The fires will take more of your ash now. Feed them at the Kindling."))


func _on_item(id: String, _amount: int, _total: int) -> void:
	var st := state()
	if String(ItemDB.def(id).kind) == "core":
		# a found core goes in the orb at once if the orb holds the Hollow Core
		if DB.core_of(st) == "":
			st["core"] = id
			Events.toast.emit("%s. It settles into the orb: every Rift Bolt is changed." % ItemDB.def(id).name)
		refresh()
	elif String(ItemDB.def(id).kind) == "charm":
		# a found charm goes on at once if a slot is free
		var w := DB.worn(st)
		if not w.has(id) and w.size() < DB.slots(st):
			w.append(id)
			st["worn"] = w
		refresh()
	elif id == "grave_ash" and not st.has("told") and ash() >= 6:
		st["told"] = true
		Events.toast.emit("Grave ash. Feed it to a kindled fire [%s] to grow stronger." % Interactable.prompt_key())


# --- spending ---------------------------------------------------------------------------------

## Why `id` (ember, spell or rite) can't be bought now, or "" if it can.
func why_not(id: String, at_fire: bool) -> String:
	var st := state()
	if DB.TAUGHT_LATER.has(id) and not DB.knows(st, id):
		return "Not yet taught."
	if DB.learnable(id) and not DB.knows(st, id):
		return "Learn %s first." % String(DB.spell(id).name)
	var nx := DB.next_of(st, id)
	if nx.is_empty():
		return "Complete."
	if nx.has("needs") and Travel.count(String(nx.needs)) <= 0:
		return "Needs the %s." % ItemDB.def(String(nx.needs)).name
	if bosses() < int(nx.gate):
		return "The fire will take this once %s of the three %s fallen." % [["", "one", "two", "all"][int(nx.gate)], "has" if int(nx.gate) == 1 else "have"]
	if ash() < int(nx.cost):
		return "Needs %d grave ash (you carry %d)." % [nx.cost, ash()]
	if not at_fire:
		return "Only at a kindled fire."
	return ""


func buy(id: String, at_fire: bool) -> String:
	var why := why_not(id, at_fire)
	if why != "":
		return why
	var st := state()
	var nx := DB.next_of(st, id)
	_spend(int(nx.cost))
	(st.ranks as Dictionary)[id] = int(nx.rank)
	_commit()
	return ""


func why_not_oath(tier: int, at_fire: bool) -> String:
	var o := DB.oath_tier(tier)
	if o.is_empty():
		return "?"
	if DB.oath(state(), tier) != "":
		return "Sworn."
	if bosses() < int(o.gate):
		return "This vow can be made once %s of the three %s fallen." % [["", "one", "two"][int(o.gate)], "has" if int(o.gate) == 1 else "have"]
	if ash() < int(o.cost):
		return "Needs %d grave ash (you carry %d)." % [o.cost, ash()]
	if not at_fire:
		return "Only at a kindled fire."
	return ""


func swear(tier: int, pick: String, at_fire: bool) -> String:
	var why := why_not_oath(tier, at_fire)
	if why != "":
		return why
	_spend(int(DB.oath_tier(tier).cost))
	(state().oaths as Dictionary)[str(tier)] = pick
	_commit()
	return ""


## Break a vow: the tier is free to swear again (the ash is not returned).
func forswear(tier: int, at_fire: bool) -> String:
	if not at_fire:
		return "Only at a kindled fire."
	(state().oaths as Dictionary).erase(str(tier))
	_commit()
	return ""


## Put a charm on or take it off. Allowed anywhere (they hang on a cord, not in the fire).
func toggle_charm(id: String) -> String:
	if Travel.count(id) <= 0:
		return "Not found yet."
	var st := state()
	var w := DB.worn(st)
	if w.has(id):
		w.erase(id)
	elif w.size() >= DB.slots(st):
		return "Every cord is full (%d). Take one off first." % DB.slots(st)
	else:
		w.append(id)
	st["worn"] = w
	_commit(false)
	return ""


# --- learning, the loadout and the staff core -----------------------------------------------

func _gate_text(gate: int, verb: String) -> String:
	return "The fire will %s this once %s of the three %s fallen." % [verb, ["", "one", "two", "all"][gate], "has" if gate == 1 else "have"]


func why_not_learn(id: String, at_fire: bool) -> String:
	var sp := DB.spell(id)
	if not sp.has("learn"):
		return "?"
	if DB.knows(state(), id):
		return "Learned."
	var l: Dictionary = sp.learn
	if bosses() < int(l.gate):
		return _gate_text(int(l.gate), "teach")
	if ash() < int(l.cost):
		return "Needs %d grave ash (you carry %d)." % [int(l.cost), ash()]
	if not at_fire:
		return "Only at a kindled fire."
	return ""


func learn(id: String, at_fire: bool) -> String:
	var why := why_not_learn(id, at_fire)
	if why != "":
		return why
	_spend(int((DB.spell(id).learn as Dictionary).cost))
	var st := state()
	var k: Array = st.get("known", [])
	k.append(id)
	st["known"] = k
	_commit()
	return ""


## Put spell `id` in hotbar slot `slot` (1..4); if it sits in another slot the two trade places.
func set_loadout(slot: int, id: String, at_fire: bool) -> String:
	if not at_fire:
		return "Only at a kindled fire."
	if slot < 1 or slot > 4 or id == "bolt":
		return "Rift Bolt keeps the first slot."
	var st := state()
	if not DB.knows(st, id):
		return "Not learned yet."
	var lo := DB.loadout(st)
	var cur := lo.find(id)
	if cur == slot - 1:
		return ""
	if cur >= 0:
		lo[cur] = lo[slot - 1]
	lo[slot - 1] = id
	st["loadout"] = lo
	_commit(false)
	return ""


## The next known spell (not Rift Bolt) for slot `slot`, after the one in it now.
func cycle_slot(slot: int, at_fire: bool) -> String:
	var st := state()
	var k := DB.known(st)
	k.erase("bolt")
	if k.is_empty():
		return "Not yet taught."                      # r35: only Rift Bolt known so far
	var lo := DB.loadout(st)
	var i := k.find(lo[clampi(slot - 1, 0, 3)])
	return set_loadout(slot, String(k[(i + 1) % k.size()]), at_fire)


func why_not_forge(core_id: String, at_fire: bool) -> String:
	var c := DB.core(core_id)
	if c.is_empty() or core_id == "":
		return "?"
	if Travel.count(core_id) > 0:
		return "Forged."
	if not c.has("forge"):
		return "Not forged: it lies in %s." % String(DB.CORE_SPOTS.get(core_id, {}).get("where", "the valley"))
	var f: Dictionary = c.forge
	if Travel.count("relic_fragment") < int(f.frag):
		return "Needs %d relic fragments (you carry %d). The valley's hidden places hold them." % [int(f.frag), Travel.count("relic_fragment")]
	if ash() < int(f.ash):
		return "Needs %d grave ash (you carry %d)." % [int(f.ash), ash()]
	if not at_fire:
		return "Only at a kindled fire."
	return ""


func forge(core_id: String, at_fire: bool) -> String:
	var why := why_not_forge(core_id, at_fire)
	if why != "":
		return why
	var f: Dictionary = DB.core(core_id).forge
	Travel.items["relic_fragment"] = maxi(0, Travel.count("relic_fragment") - int(f.frag))
	_spend(int(f.ash))
	state()["core"] = core_id
	Travel.give(core_id, 1, false)
	_commit()
	return ""


## Set an owned core in the orb ("" = the Hollow Core). Only at a fire.
func set_core(core_id: String, at_fire: bool) -> String:
	if not at_fire:
		return "Only at a kindled fire."
	if core_id != "" and Travel.count(core_id) <= 0:
		return "Not yours yet."
	state()["core"] = core_id
	_commit()
	return ""


func _spend(n: int) -> void:
	Travel.items["grave_ash"] = maxi(0, ash() - n)
	var st := state()
	st["spent"] = int(st.get("spent", 0)) + n


func _commit(flare := true) -> void:
	refresh()
	Travel.save_game()
	if flare:
		_pending_fx = _nearest_fire()


## The Kindling closed: if something was bought, the fire flares and its embers stream into you.
func celebrate() -> void:
	var b := _pending_fx
	_pending_fx = null
	if b == null or not is_instance_valid(b) or _player == null or not is_instance_valid(_player):
		return
	var from := b.global_position + Vector3.UP * 1.0
	var to := _player.global_position + Vector3.UP * 1.0
	SpellFx.column(b.global_position, 0.6, 3.2, 0.9)
	Vfx.burst(from, Color(2.8, 1.2, 0.35), {"count": 60, "life": 0.9, "speed": Vector2(2.0, 6.0), "size": 0.05, "gravity": -2.0, "trail": 0.1, "dir": Vector3.UP, "spread": 40.0})
	for k in 3:
		Vfx.arc(from, to, Color(2.6, 1.1, 0.4), 0.35 + 0.1 * float(k), 0.35)
	SpellFx.shell(to, 0.2, 1.6, Color(2.4, 1.0, 0.35), 0.4)
	Vfx.burst(to, Color(2.6, 1.3, 0.5), {"count": 40, "life": 0.8, "speed": Vector2(0.3, 1.4), "size": 0.045, "gravity": -1.5, "radius": 0.5, "swirl": 3.0, "turbulence": true})
	Vfx.light(to, Color(1.0, 0.55, 0.25), 3.0, 6.0, 0.6)
	Sfx.play("res://art/audio/ward_chime.wav", to, -2.0, 0.8)


# --- fires ------------------------------------------------------------------------------------

## The kindled brazier within FIRE_REACH of the wanderer, or null.
func _nearest_fire() -> Node3D:
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null:
		return null
	var best: Node3D = null
	var best_d := FIRE_REACH
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier and (n as Brazier).lit:
			var d := (n as Node3D).global_position.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


func at_fire() -> Node3D:
	return _nearest_fire()


## Every brazier (the Realm's, and the Ossuary's as it streams in) gets a "Tend the fire" spot.
func _place_spots() -> void:
	for id in _spots.keys():
		if not is_instance_valid(_spots[id]) or not is_instance_valid(instance_from_id(id)):
			if is_instance_valid(_spots[id]):
				(_spots[id] as Node).queue_free()
			_spots.erase(id)
	for n in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if n is Brazier and not _spots.has(n.get_instance_id()):
			var s := FireSpot.new()
			s.name = "FireSpot_" + String(n.name)
			s.brazier = n
			add_child(s)
			s.global_position = (n as Node3D).global_position
			_spots[n.get_instance_id()] = s


# --- charms in the world ----------------------------------------------------------------------

func _realm_ready() -> bool:
	var root := get_parent()
	return root != null and (root.has_meta("realm_done") or not Realm.enabled())


func _lay_charms() -> void:
	if not Realm.enabled():
		return
	var space := get_viewport().world_3d.direct_space_state if get_viewport() else null
	if space == null:
		return
	for id: String in DB.CHARM_SPOTS:
		if Travel.count(id) > 0:
			continue
		var at := ground_spot(space, DB.CHARM_SPOTS[id].at)
		if at == Vector3.INF:
			push_warning("PROGRESSION: no ground for %s" % id)
			continue
		var c := CharmPickup.new()
		c.item_id = id
		c.name = "Charm_" + id
		add_child(c)
		c.global_position = at
	for id: String in DB.CORE_SPOTS:
		if Travel.count(id) > 0:
			continue
		var at := ground_spot(space, DB.CORE_SPOTS[id].at)
		if at == Vector3.INF:
			push_warning("PROGRESSION: no ground for %s" % id)
			continue
		var cp := CorePickup.new()
		cp.item_id = id
		cp.name = "Core_" + id
		add_child(cp)
		cp.global_position = at


## Open, level, dry ground near `xz` (terrain, not a roof): a spiral of probes, first that fits.
## Fen pools count when the probe lands on a bank or stone above the water line. Registered
## sites (buildings, barrows, graves) and lanes are kept clear, as zz/realm_audit expects.
static func ground_spot(space: PhysicsDirectSpaceState3D, xz: Vector2) -> Vector3:
	for ring in 34:
		var n := 1 if ring == 0 else 6 + ring
		for k in n:
			var a := TAU * float(k) / float(n) + float(ring) * 0.7
			var p := xz + Vector2(cos(a), sin(a)) * float(ring) * 0.9
			var top := RealmLand.height_at(p.x, p.y)
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, top + 12.0, p.y), Vector3(p.x, top - 4.0, p.y), Layers.WORLD | Layers.PROPS)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or (hit.normal as Vector3).y < 0.85:
				continue
			var y := (hit.position as Vector3).y
			if absf(y - top) > 2.5:
				continue                     # a roof, a wall top, a tree: not the ground
			if RealmLand.in_water(p.x, p.y) and y < RealmLand.WATER_Y + 0.25:
				continue                     # under the fen's water
			if WorldLanes.intrudes(space, AABB(Vector3(p.x - 0.4, y, p.y - 0.4), Vector3(0.8, 1.0, 0.8)), 0.4) != "":
				continue                     # keep out of buildings' sites and off the lanes
			return hit.position
	return Vector3.INF


# --- r35: the story teaches the spells -----------------------------------------------------------
## Start with Rift Bolt. The Keep teaches Lantern Ward (dialogue "teach:ward"), the first kill Ember
## Lance, the first seal Rift Step, the first great one Umbral Nova. Each is said once, with its key.
const TEACH_LINES := {
	"ward": "The Keep's fire takes to your lantern. Lantern Ward: %s.",
	"lance": "The first of them falls, and the staff drinks its ember. Ember Lance: %s.",
	"step": "The seal breaks, and the Rift pulls at your feet. Rift Step: %s.",
	"nova": "The great one's dark comes apart round you, and you keep some. Umbral Nova: %s.",
}


## Teach `id` (one of DB.TAUGHT_LATER) if it is not known yet. True if it was taught now.
func teach(id: String) -> bool:
	var st := state()
	if not DB.TAUGHT_LATER.has(id) or DB.knows(st, id):
		return false
	var t: Array = st.get("taught", []) if st.get("taught", []) is Array else []
	t.append(id)
	st["taught"] = t
	refresh()
	Travel.save_soon()
	var slot := DB.loadout(st).find(id) + 1
	var key := String(DB.SLOT_KEYS[slot]) if slot >= 1 and slot < DB.SLOT_KEYS.size() else "the Loadout"
	Events.toast.emit(String(TEACH_LINES.get(id, "%s")) % key)
	return true
