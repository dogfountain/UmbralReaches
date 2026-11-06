extends Node
## Encounters: GUARDIANS -- the mini-bosses that hold points of interest (r31, docs/enshrouded/
## enemies.md). Where Enshrouded sets a brute or a queen over each well and root, the Reaches set
## a guardian over a nest, a barrow, a shrine: a named, bigger, harder one of the night's own kinds
## with an escort, a name bar, a turn at half health (it enrages and calls help), and a payment
## of grave ash when it falls. A felled guardian stays down until the Deeper Night.
##
## API for the WORLD (points of interest):
##   - put any Node3D in the group &"guardian_site" (Guardians.GROUP) where a guardian should stand;
##     optional metas: "guardian" (an id from GUARDIANS; default: picked by the site's region) and
##     "site_key" (a stable save key; default: the position, snapped to a metre). Sites are read
##     on every tick, so a site added after the world is built still gets its guardian.
##   - or call Guardians.add_site(at, id, key) (static) before or after the director is up.
## FALLBACK sites below hold the night until the world names its own (one is skipped when any
## other site is within 45 m of it).
## The director owns this node (director.gd adds it as "Guardians" and asks it for the name bar).
## Load by path (no class_name).

const Tiers := preload("res://core/life/encounters/tiers.gd")
const Variants := preload("res://core/life/encounters/variants.gd")
const GROUP := &"guardian_site"
const NEAR := 55.0                 ## the guardian rises when you come this close to its site
const FAR := 95.0                  ## ...and goes back to it, healed, past this
const ESCORT_R := 3.2
const BAR_R := 22.0

## id -> {title, script (own kind) or base (a kind made champion), scale, hp, escort, ash, regions,
##        enrage_call (kind it calls at half health)}
const GUARDIANS := {
	"brood_mother": {"title": "The Brood-Mother", "script": "res://core/enemy/brood_mother.gd", "hp": 44,
		"escort": ["mite", "mite", "mite"], "ash": 14, "regions": ["thornwood", "glade", "fen", "crags", "orchard"]},
	"tithe_knight": {"title": "The Tithe-Knight", "base": "bulwark", "scale": 1.45, "hp": 34,
		"escort": ["chanter", "wretch", "tollman"], "ash": 16, "regions": ["road", "chapel", "rift", "summit", "hearth"], "enrage_call": "wretch"},
	"sexton": {"title": "The Sexton of the Barrows", "base": "ossuant", "scale": 1.4, "hp": 30,
		"escort": ["quiller", "quiller"], "ash": 16, "regions": ["barrows", "fen", "ossuary"], "enrage_call": "ossuant"},
	"pale_stalker": {"title": "The Pale Stalker", "base": "gaunt", "scale": 1.35, "hp": 18,
		"escort": ["gaunt", "gaunt"], "ash": 14, "regions": ["henge", "thornwood", "crags", "moor", "holds"], "enrage_call": "gaunt"},
	# r34: the new ground's own (a champion of the region's roster, its regional look via "variant")
	"stonewright": {"title": "The Stonewright", "base": "husk", "variant": "stonebound", "scale": 1.5, "hp": 40,
		"escort": ["leaper", "leaper"], "ash": 18, "regions": ["quarry"], "enrage_call": "leaper"},
	"bell_founder": {"title": "The Bell-Founder", "base": "bulwark", "scale": 1.5, "hp": 42,
		"escort": ["cinder", "cinder"], "ash": 18, "regions": ["foundry"], "enrage_call": "cinder"},
	"vigil_keeper": {"title": "The Vigil-Keeper", "base": "chanter", "scale": 1.45, "hp": 30,
		"escort": ["pilgrim", "pilgrim", "pilgrim"], "ash": 16, "regions": ["necropolis"], "enrage_call": "pilgrim"},
	"drowned_deacon": {"title": "The Drowned Deacon", "base": "husk", "variant": "drowned", "scale": 1.45, "hp": 36,
		"escort": ["spitter", "spitter"], "ash": 16, "regions": ["mere"], "enrage_call": "wretch"},
	"ash_sow": {"title": "The Ash-Sow", "base": "burrower", "scale": 1.5, "hp": 36,
		"escort": ["burrower", "mite", "mite"], "ash": 16, "regions": ["orchard"], "enrage_call": "mite"},
	"sedge_mother": {"title": "The Sedge-Mother", "base": "spitter", "scale": 1.45, "hp": 22,
		"escort": ["wretch", "wretch"], "ash": 16, "regions": ["mere"], "enrage_call": "spitter"},
}
## r34: no guardian holds a place here (the Rooted Holds' clearing is safe-ish; a site there is left
## empty, and the director spawns nothing in it either).
const NO_GUARDIAN := ["holds"]

## Until the world places its own: a nest in the deep Thornwood, a barrow-keeper on the Barrow
## Field's far side, a knight on the west of the Pilgrims' Road, a stalker on the Crowns.
const FALLBACK := [
	{"at": Vector2(-62.0, -44.0), "id": "brood_mother", "key": "fb_thornwood_nest"},
	{"at": Vector2(92.0, -54.0), "id": "sexton", "key": "fb_barrow_keeper"},
	{"at": Vector2(-80.0, 74.0), "id": "tithe_knight", "key": "fb_west_road"},
	{"at": Vector2(-70.0, -118.0), "id": "pale_stalker", "key": "fb_crowns"},
	# r34: one for each new region (skipped where the places pass set a site within 45 m)
	{"at": Vector2(-128.0, -104.0), "id": "stonewright", "key": "fb_quarry_floor", "r34": true},
	{"at": Vector2(132.0, -90.0), "id": "bell_founder", "key": "fb_casting_pits", "r34": true},
	{"at": Vector2(140.0, -30.0), "id": "pale_stalker", "key": "fb_moor_tor", "r34": true},
	{"at": Vector2(-90.0, 124.0), "id": "ash_sow", "key": "fb_orchard_heart", "r34": true},
	{"at": Vector2(0.0, 142.0), "id": "vigil_keeper", "key": "fb_mausoleum", "r34": true},
	{"at": Vector2(128.0, 122.0), "id": "drowned_deacon", "key": "fb_mere_landing", "r34": true},
]

static var _extra: Array[Dictionary] = []

var director: Node                 ## the encounters director (spot_ok, _search, hud, state)
var sites: Array[Dictionary] = []  ## {at: Vector3, id, key, from: "group"|"api"|"fallback"}
var nodes: Dictionary = {}         ## key -> Enemy (the guardian)
var escorts: Dictionary = {}       ## key -> Array[Enemy]
var _fallback_done := false


## Register a site by code (the world's builders may call this any time).
static func add_site(at: Vector3, id := "", key := "") -> void:
	for s: Dictionary in _extra:
		if (s.at as Vector3).distance_to(at) < 1.0:
			return
	_extra.append({"at": at, "id": id, "key": key})


static func reset_sites() -> void:
	_extra.clear()


func _ready() -> void:
	name = "Guardians"
	if not Events.enemy_killed.is_connected(_on_killed):
		Events.enemy_killed.connect(_on_killed)


func _state() -> Dictionary:
	var st: Variant = director.get("state") if director else null
	if st is Dictionary:
		if not ((st as Dictionary).get("slain") is Dictionary):
			(st as Dictionary)["slain"] = {}
		return st
	return {"slain": {}}


func slain(key: String) -> bool:
	return (_state().slain as Dictionary).has("g:" + key)


static func pick_id(at: Vector3, key: String, taken: Array = []) -> String:
	var region := Tiers.region_id(at)
	var fits: Array[String] = []
	for id: String in GUARDIANS:
		if region in (GUARDIANS[id].regions as Array):
			fits.append(id)
	if fits.is_empty():
		return "tithe_knight"
	# r34: a region's own first (a new region's champion before an old kind that also roams there),
	# and a second site in the same region draws a different one while one is left
	var own: Array[String] = []
	for id in fits:
		if (GUARDIANS[id].regions as Array).size() == 1 and not (id in taken):
			own.append(id)
	if not own.is_empty():
		return own[absi(hash(key)) % own.size()]
	var free: Array[String] = []
	for id in fits:
		if not (id in taken):
			free.append(id)
	if not free.is_empty():
		return free[absi(hash(key)) % free.size()]
	return fits[absi(hash(key)) % fits.size()]


## Gather every site: the group, the API, then the fallbacks (once, on clear ground, if nothing
## else is near them).
func refresh_sites() -> void:
	var have := {}
	for s: Dictionary in sites:
		have[s.key] = true
	var add := func(at: Vector3, id: String, key: String, from: String) -> void:
		if key == "":
			key = "%d_%d_%d" % [roundi(at.x), roundi(at.y), roundi(at.z)]
		if have.has(key):
			return
		if Tiers.region_id(at) in NO_GUARDIAN:
			return
		if id == "" or not GUARDIANS.has(id):
			var taken: Array = []
			var reg := Tiers.region_id(at)
			for s2: Dictionary in sites:
				if Tiers.region_id(s2.at) == reg:
					taken.append(String(s2.id))
			id = pick_id(at, key, taken)
		have[key] = true
		sites.append({"at": at, "id": id, "key": key, "from": from})
	for n in get_tree().get_nodes_in_group(GROUP):
		if n is Node3D and (n as Node3D).is_inside_tree():
			var g := n as Node3D
			add.call(g.global_position, String(g.get_meta("guardian", "")), String(g.get_meta("site_key", "")), "group")
	for s: Dictionary in _extra:
		add.call(s.at, String(s.id), String(s.key), "api")
	if _fallback_done or director == null:
		return
	_fallback_done = true
	for f: Dictionary in FALLBACK:
		var c: Vector2 = f.at
		var crowded := false
		var reg := Tiers.region_id(Vector3(c.x, 0.0, c.y))
		for s: Dictionary in sites:
			var dd := Vector2((s.at as Vector3).x - c.x, (s.at as Vector3).z - c.y).length()
			# r34: for a new region's fallback, a site nearby whose guardian is not this region's own does
			# not stand in for it (the Charcoal Hollow's Brood-Mother sits by the quarry since the henge moved)
			if dd < 45.0 and (not f.get("r34", false) or reg in (GUARDIANS[s.id].regions as Array)):
				crowded = true
		if crowded:
			continue
		var g: Vector3 = director.call("_search", c, 18.0, false)
		if g == Vector3.INF:
			push_warning("Guardians: no clear ground for fallback site %s" % f.key)
			continue
		add.call(g, String(f.id), String(f.key), "fallback")


func tick(pos: Vector3) -> void:
	refresh_sites()
	for s: Dictionary in sites:
		var key: String = s.key
		var at: Vector3 = s.at
		var e: Enemy = nodes.get(key) as Enemy if is_instance_valid(nodes.get(key)) else null
		var d := pos.distance_to(at)
		if e == null:
			nodes.erase(key)
			if not slain(key) and d < NEAR and not LightGrid.is_lit(at) and not bool(director.call("_busy_fight")):
				spawn(s)
			continue
		var de := pos.distance_to(e.global_position)
		if d > FAR and de > FAR:
			_dismiss(key)
			continue
		if e.is_alive():
			if de > e.sleep_range:
				e.sleep()
			else:
				e.wake()
			if not bool(e.get_meta(&"guardian_enraged", false)) and e.hp <= float(e.max_hp) * 0.5:
				enrage(e)


## The guardian nearest the wanderer worth a name bar (fighting, or hurt), or null.
func shown(pos: Vector3) -> Enemy:
	var best: Enemy = null
	var bd := BAR_R
	for key: String in nodes:
		var e := nodes[key] as Enemy if is_instance_valid(nodes[key]) else null
		if e == null or not e.is_alive():
			continue
		var d := pos.distance_to(e.global_position)
		if d < bd and (e.get("_state") != Enemy.IDLE or e.hp < float(e.max_hp)):
			best = e
			bd = d
	return best


static func title(e: Enemy) -> String:
	var id := String(e.get_meta(&"guardian_id", ""))
	return String(GUARDIANS.get(id, {}).get("title", "Guardian"))


func spawn(s: Dictionary) -> Enemy:
	var key: String = s.key
	var id: String = s.id
	var d: Dictionary = GUARDIANS[id]
	var at: Vector3 = s.at
	var tier := Tiers.tier_at(at)
	var e: Enemy
	if d.has("script"):
		e = (load(String(d.script)) as GDScript).new() as Enemy
	else:
		e = Tiers.script_for(String(d.base)).new() as Enemy
		champion(e, d)
	if "dormant" in e:
		e.set("dormant", false)                      # r34: a Pilgrim champion stands waiting
	_scale(e, tier, int(d.get("hp", e.max_hp)))
	var look := String(d.get("variant", ""))
	if look != "":
		Variants.pre(e, look)                        # r34: the region's own look (stone-bound, drowned)
	e.set_meta(&"guardian_id", id)
	e.set_meta(&"display_name", String(d.get("title", "Guardian")))   # r33: Enemy.display_name()
	e.set_meta(&"guardian_key", key)
	director.get("root").add_child(e)
	if look != "":
		Variants.dress(e, look)
	e.global_position = at + Vector3.UP * 0.05
	e.home = at
	if d.has("scale"):
		_grow(e, float(d.scale))
	nodes[key] = e
	var esc: Array[Enemy] = []
	var kinds: Array = d.get("escort", [])
	for i in kinds.size():
		var a := TAU * float(i) / float(maxi(kinds.size(), 1)) + 0.4
		var p := at + Vector3(cos(a), 0.0, sin(a)) * ESCORT_R
		var g: Vector3 = director.call("_ground_at", p, at.y + 6.0)
		if g == Vector3.INF or absf(g.y - at.y) > 2.5:
			g = at + Vector3(cos(a), 0.0, sin(a)) * 1.2
		var m := Tiers.script_for(String(kinds[i])).new() as Enemy
		Tiers.scale_stats(m, tier)
		var rv := Tiers.region_variant(g, String(kinds[i]))
		if rv != "":
			Variants.pre(m, rv)
		m.set_meta(&"guardian_escort", key)
		director.get("root").add_child(m)
		if rv != "":
			Variants.dress(m, rv)
		m.global_position = g + Vector3.UP * 0.05
		m.home = g
		esc.append(m)
	escorts[key] = esc
	return e


## A base kind made a champion: more of everything but its tells (never a shorter telegraph).
static func champion(e: Enemy, d: Dictionary) -> void:
	e.max_hp = int(d.get("hp", 24))
	e.hp = float(e.max_hp)
	e.poise += 4.0
	e.strike_gloom *= 1.3
	e.chase_range = maxf(e.chase_range, 15.0)
	e.hunt_leash = 16.0
	e.sleep_range = 60.0
	e.can_flee = false
	e.can_call = false
	e.mass *= 1.8
	e.feint_chance = maxf(e.feint_chance, 0.12)


## The rig and capsule at `s` (after _ready built them), the bar raised to match.
static func _grow(e: Enemy, s: float) -> void:
	if e._rig:
		e._rig.scale *= s
	var col := e.get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		cap.radius *= minf(s, 1.4)
		cap.height *= s
		col.shape = cap
		col.position.y = cap.height * 0.5
	e.hp_bar_y *= s
	e.strike_range *= minf(s, 1.35)
	if e._hp_bar:
		e._hp_bar.position.y = e.hp_bar_y
		e._hp_bar.set_instance_shader_parameter(&"segments", Enemy.hp_segments(e.max_hp))
	for pip in e._pips:
		pip.position.y = e.hp_bar_y + 0.16


## Region tier: health climbs half as fast as a camp pawn's (as the named elites'), damage the same.
static func _scale(e: Enemy, tier: int, base_hp: int) -> void:
	var t := Tiers.info(tier)
	e.max_hp = roundi(float(base_hp) * (0.5 + 0.5 * float(t.hp)))
	e.hp = float(e.max_hp)
	e.strike_gloom *= float(t.dmg)
	if "spit_gloom" in e:
		e.set("spit_gloom", float(e.get("spit_gloom")) * float(t.dmg))
	e.set_meta(&"enc_tier", tier)


## Half health: it shrieks, the escort is called again (two of `enrage_call`), and it comes on
## harder -- chains and feints, never shorter tells. (The Brood-Mother has her own enrage.)
func enrage(e: Enemy) -> void:
	e.set_meta(&"guardian_enraged", true)
	var id := String(e.get_meta(&"guardian_id", ""))
	var d: Dictionary = GUARDIANS.get(id, {})
	if not d.has("enrage_call"):
		return
	e.walk_speed *= 1.12
	e.combo_max = maxi(e.combo_max, 1)
	e.combo_chance = maxf(e.combo_chance, 0.4)
	e.feint_chance = maxf(e.feint_chance, 0.2)
	e._glint = 1.0
	BossKit.roar(e, "", Color(1.8, 0.7, 0.25))
	HitText.pop(e.global_position + Vector3.UP * (e.hp_bar_y + 0.9), "it calls its kin", Color(1.2, 0.6, 0.3), true)
	var got := BossKit.summon(e.get_parent(), Tiers.script_for(String(d.enrage_call)), e.global_position, 2, 3.5, "guardian_" + String(e.get_meta(&"guardian_key", "")))
	scale_summoned(got, int(e.get_meta(&"enc_tier", 0)), String(d.enrage_call))
	for m in got:
		m.alerted(e)


## Kin that rose in the tree (a summon) take the same two calls the escort loop makes: the
## tier's stats (scale_live also raises the bar) and the region's own look at the spot.
static func scale_summoned(got: Array, tier: int, kind: String) -> void:
	for m: Enemy in got:
		if not is_instance_valid(m):
			continue
		Tiers.scale_live(m, tier)
		var rv := Tiers.region_variant(m.global_position, kind)
		if rv != "":
			Variants.pre(m, rv)
			Variants.dress(m, rv)
			if m._hp_bar:
				m._hp_bar.set_instance_shader_parameter(&"segments", Enemy.hp_segments(m.max_hp))
			m._refresh_hp(false)


func _on_killed(e: Node) -> void:
	if e == null or not e.has_meta(&"guardian_id") or not e.has_meta(&"guardian_key"):
		return
	var key := String(e.get_meta(&"guardian_key"))
	if slain(key):
		return
	(_state().slain as Dictionary)["g:" + key] = true
	var d: Dictionary = GUARDIANS.get(String(e.get_meta(&"guardian_id")), {})
	var ng := int(director.call("ng")) if director else 0
	var ash := int(d.get("ash", 12)) * (2 if ng > 0 else 1)
	Travel.give("grave_ash", ash, false)
	var hud: Variant = director.get("hud") if director else null
	if hud is Object:
		(hud as Object).call("banner", "GUARDIAN FELLED", "%s  ·  %d grave ash" % [title(e as Enemy), ash], Color(1.0, 0.75, 0.45))
		(hud as Object).call("hide_elite")
	# what it bred or called goes back into the dark with it; the escort stays to be dealt with
	for m in get_tree().get_nodes_in_group(Groups.ENEMY):
		var tag := String((m as Node).get_meta(&"summoned_by", ""))
		if tag == "guardian_" + key:
			_unmake(m as Enemy)
	Travel.save_game()


## Out of reach: the guardian and its escort go back into the dark (healed when it rises again).
func _dismiss(key: String) -> void:
	_unmake(nodes.get(key) as Enemy if is_instance_valid(nodes.get(key)) else null)
	for m in escorts.get(key, []):
		if is_instance_valid(m):
			_unmake(m as Enemy)
	for m in get_tree().get_nodes_in_group(Groups.ENEMY):
		if String((m as Node).get_meta(&"summoned_by", "")) == "guardian_" + key:
			_unmake(m as Enemy)
	nodes.erase(key)
	escorts.erase(key)


func _unmake(e: Enemy) -> void:
	if e == null or not is_instance_valid(e):
		return
	if director and director.has_method("_unmake"):
		director.call("_unmake", e, false)
	else:
		e.queue_free()
