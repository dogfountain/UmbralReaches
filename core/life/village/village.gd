extends Node3D
## Hearthward comes back to life (village system, docs/LIFE_PLAN.md). Realm module "village":
## `build(root)` adds this director ("Village") last-but-three in Realm.build. It owns:
##   - the village clock: a night of CYCLE seconds in four phases (dusk, work, midnight, late);
##     each villager's schedule picks a routine per phase (village_cast.gd)
##   - the walking network (village_nav.gd), checked against the built world: floors, walls,
##     fences, barrels, trunks; villagers only walk its kept edges
##   - the people (villager.gd on villager_rig.gd): Hild at Edda's forge, Old Fennick the
##     lamplighter, Oswin the pilgrim, Nan Wright, Grisel the ash-wife (trader), Wyck the hermit
##     in the Thornwood, Abel the sexton by the Kindlers' Yard; and, as the valley is won back,
##     Col Wright, Bet Reed, Wenna Ashby (out of the Ossuary) and Pell (down from the light)
##   - the lamplighter's lamps (glass and halo per lamp, no lights), the forge's flare, the
##     camps and props (village_props.gd), the conversations (village_talk.gd)
##   - restoration (village_state.gd): checked at load and on boss_slain, seal_broken,
##     brazier_kindled and every trade; what comes true is built at once, announced with a toast
##     and remembered in Travel.system_state("village")
## Lights: forge flare, the lamplighter's lantern, the cart lamp, the hermit's fire, the grave
## lantern, the Wrights' window: six omnis, no shadows, distance-faded (LightPolicy class "realm");
## r34: one more per outpost fire (seven, one per new region, never two in view).
## r34: the doubled world's givers (Gammer Ruan, Jory Quell, Ysolt, Elspeth Fane, Linnet, Sister
## Agathe, Cadoc) camp at outpost fires in their regions (village_cast.gd OUTPOSTS, _outposts()).

const SELF := "res://core/life/village/village.gd"
const Cast := preload("res://core/life/village/village_cast.gd")
const WestCast := preload("res://core/life/village/village_cast_west_marches.gd")      # --- west marches --- Weirford's people
const WanderCast := preload("res://core/life/village/village_cast_wanderer.gd")        # the Late Ringer's walk islands
const Travellers := preload("res://core/life/village/village_cast_travellers.gd")       # the road's walkers (docs/far_reaches.md)
const Towns := preload("res://core/life/village/village_reach_towns.gd")                # --- the towns --- Reedholm, Fallowmere, Lastlight
const VState := preload("res://core/life/village/village_state.gd")
const VNav := preload("res://core/life/village/village_nav.gd")
const Props := preload("res://core/life/village/village_props.gd")
const Talk := preload("res://core/life/village/village_talk.gd")
const VAudio := preload("res://core/life/village/village_audio.gd")
const VillagerScript := preload("res://core/life/village/villager.gd")
const Rig := preload("res://core/life/village/villager_rig.gd")
const Watch := preload("res://core/world/watch/watch.gd")
const RoamEvents := preload("res://core/world/roam/roam_events.gd")
const QuestWorld := preload("res://core/story/quest_world.gd")
const WayfarerDB := preload("res://core/life/wayfarers/wayfarer_db.gd")

const CYCLE := 600.0                  ## one village night (s)
const FORGE := Vector2(11.0, 60.0)
const WELL := Vector2(-10.0, 48.5)
## The Thornwood's far west, clear of the enemy camps (r31: in from -102, where the r30 edge cliffs and
## boulders now stand, so no clear spot was found and Wyck had no camp)
const HERMIT_NEAR := Vector2(-93.0, 9.0)
const SEXTON_NEAR := Vector2(-57.0, 40.6)

var time_scale := 1.0                 ## tests speed the village up
var clock := CYCLE * 0.16
var phase := ""
var nav: RefCounted
var villagers := {}                   ## id -> villager node
var lamps := {}                       ## id -> {pos, glass, halo, lit, want, fuel}
var lamp_spots := {}                  ## id -> node id
var anchors := {}                     ## "@x" -> Vector3
var overlays := {}                    ## restoration id -> Node3D
var lights: Array[OmniLight3D] = []
var talker: Node
var forge_flare: OmniLight3D
var report: Array[String] = []
var build_ms := 0
var _flare := 0.0
var _pending := {}
var _well := {}
var _ready_done := false
var quests: Node                      ## the tasks' world side (core/story/quest_world.gd)
var outpost_at := {}                  ## r34: giver id -> their outpost fire (Vector3)
var mode := ""                        ## "" / "rain" / "danger": what the routines answer to now
var nights := 0                       ## village nights passed this session (the ash-wife restocks)
var _tide := false
var _mode_t := 0.0
var _weather: Node

static func build(root: Node) -> void:
	if root.get_node_or_null("Village") != null:
		return
	var v := new()
	v.name = "Village"
	v.set_meta("site", "village")
	root.add_child(v)
	await v._build()


func _build() -> void:
	var t0 := Time.get_ticks_msec()
	var space := get_world_3d().direct_space_state
	# restorations that came true while the village was not loaded: built, not announced
	VState.refresh(get_tree())
	for id: String in VState.data().restored:
		(VState.data().announced as Dictionary)[id] = true
	# --- props first (the walking network then avoids the solid ones) ---------------------------
	nav = VNav.new()
	nav.call("use_space", space)
	var west_pois: Variant = load("res://core/world/realm/realm_pois_west_marches.gd")      # no preload: a cycle
	var towns_pois: Variant = load("res://core/world/realm/reach_towns.gd")              # --- the towns --- their boards over the meres
	nav.set("decks", west_pois.decks() + towns_pois.decks())
	var node_xz: Dictionary = Cast.nodes().duplicate()
	var edges: Array = Cast.edges().duplicate()
	var spots := {}
	for l: Dictionary in Cast.lamps():
		spots[String(l.spot)] = Cast.nodes().get(String(l.spot), Vector2.ZERO)
		lamp_spots[String(l.id)] = String(l.spot)
	lamps = Props.lamps(self, space, Cast.lamps(), Cast.nodes())
	var cart_xz: Vector2 = Cast.nodes().cart
	var to_b := (Vector2(0, 33) - cart_xz).normalized()
	var cart: Dictionary = Props.cart(self, space, cart_xz + to_b * 1.05, atan2(-to_b.x, -to_b.y))
	anchors["@cart"] = cart.anchor
	lights.append(cart.light)
	var fy := Props.site_y("hw_forge", 0.4)
	anchors["@anvil"] = Vector3(11.8, fy + 0.87, 60.2)
	anchors["@coals"] = Vector3(9.6, fy + 0.95, 61.3)
	anchors["@water"] = Vector3(13.2, fy + 0.58, 60.9)
	anchors["@wheel"] = Vector3(13.4, fy + 0.86, 59.12)
	forge_flare = Props.forge_flare(self, Vector3(11.2, fy + 1.5, 60.3))
	lights.append(forge_flare)
	var chop: Vector2 = Cast.nodes().chop
	anchors["@block_col"] = Props.block(self, space, chop + Vector2(0, 0.85))
	_well = Props.well(self, space, WELL)
	await get_tree().process_frame
	# camps: the hermit's in the Thornwood, the sexton's grave by the Kindlers' Yard
	# the camp's own walks (fire to grave, fire to seat) must be clear too, not just its ring
	# ... and his walk round the fire (h_w1, h_w2, h_w3 below): with bigger trees a stop was walled off wherever the wood shifted
	var hw: Array[Vector2] = [Vector2(0.2, 1.05), Vector2(4.0, -3.0), Vector2(6.0, 2.0), Vector2(2.5, 4.0)]
	var hc := _find_clear(HERMIT_NEAR, 3.0, 3.5, 15.0, [[Vector2.ZERO, Vector2(-2.1, 2.35)], [Vector2.ZERO, Vector2(1.5, 0.3)], [Vector2(-2.1, 2.35), Vector2(1.5, 0.3)],
		[hw[0], hw[1]], [hw[1], hw[2]], [hw[2], hw[3]], [hw[3], hw[0]]], "", true)
	if hc != Vector2.INF:
		var camp: Dictionary = Props.hermit(self, space, hc)
		lights.append(camp.light)
		var f: Vector3 = camp.fire
		var seat: Vector3 = camp.seat
		var g: Vector3 = camp.grave
		anchors["@fire"] = f + Vector3.UP * 0.2
		anchors["@grave"] = g
		anchors["@out"] = f + Vector3(8, 0, 6)
		node_xz["h_fire"] = Vector2(f.x + 0.2, f.z + 1.05)
		node_xz["h_seat"] = Vector2(seat.x, seat.z)
		node_xz["h_grave"] = Vector2(g.x + 0.1, g.z + 0.75)
		# his walk's three stops: each the first of a few spots the network can walk to from the fire (the Thornwood's
		# trees and boulders are big: a fixed stop was walled off wherever the wood shifted)
		var hf := Vector2(f.x + 0.2, f.z + 1.05)
		var stops := {"h_w1": [Vector2(4.0, -3.0), Vector2(3.0, -2.0), Vector2(4.5, -1.2), Vector2(2.2, -3.2)],
			"h_w2": [Vector2(6.0, 2.0), Vector2(5.0, 1.0), Vector2(4.5, 2.6), Vector2(5.5, -0.2)],
			"h_w3": [Vector2(2.5, 4.0), Vector2(3.4, 2.6), Vector2(1.2, 3.4), Vector2(4.0, 3.4), Vector2(2.0, 2.4)]}
		var floor_fn := Callable(nav, &"floor_at")
		var edge_fn := Callable(nav, &"_edge_ok")
		for sid: String in stops:
			var pick: Vector2 = (stops[sid] as Array)[0]
			for o: Vector2 in stops[sid]:
				var q := Vector2(f.x, f.z) + o
				var e0 := Vector3(hf.x, float(floor_fn.call(hf.x, hf.y)), hf.y)
				var e1 := Vector3(q.x, float(floor_fn.call(q.x, q.y)), q.y)
				if String(edge_fn.call(e0, e1)) == "":
					pick = o
					break
			node_xz[sid] = Vector2(f.x, f.z) + pick
		edges.append_array([["h_fire", "h_seat"], ["h_fire", "h_grave"], ["h_fire", "h_w1"], ["h_fire", "h_w2"], ["h_w1", "h_w2"], ["h_w2", "h_w3"], ["h_w3", "h_fire"], ["h_seat", "h_w1"],
			["h_grave", "h_seat"], ["h_grave", "h_w3"]])      # spare ways to the grave: the Thornwood fills up
	else:
		report.append("no clear spot for the hermit's camp")
	var sc := _find_clear(SEXTON_NEAR, 2.2, 0.8, 10.0)
	if sc != Vector2.INF:
		var dig: Dictionary = Props.sexton(self, space, sc, 0.0)
		lights.append(dig.light)
		anchors["@pit"] = dig.pit
		node_xz["s_dig"] = sc + Vector2(-1.0, 0.25)
		node_xz["s_gate_out"] = Vector2(-61.2, 43.7)
		node_xz["s_gate_in"] = Vector2(-66.2, 44.1)
		node_xz["s_yard"] = Vector2(-75.0, 44.2)
		node_xz["s_edda"] = Vector2(-83.6, 44.2)
		edges.append_array([["s_dig", "s_gate_out"], ["s_gate_out", "s_gate_in"], ["s_gate_in", "s_yard"], ["s_yard", "s_edda"]])
	else:
		report.append("no clear spot for the sexton's grave")
	# r34: the outposts of the doubled world, one giver camped in each new region
	_outposts(space, node_xz, edges)
	# --- west marches --- Weirford's walks (its own island of the network; the nav drops what the town stands on)
	node_xz.merge(WestCast.nodes())
	edges.append_array(WestCast.edges())
	node_xz.merge(Travellers.NODES)                 # the road's walkers: two islands on the Pilgrims' Road
	edges.append_array(Travellers.EDGES)
	node_xz.merge(WanderCast.NODES)                 # the Late Ringer: five small islands where he meets the wanderer
	edges.append_array(WanderCast.EDGES)
	node_xz.merge(Towns.NODES)                      # --- the towns --- each its own island
	edges.append_array(Towns.EDGES)
	# --- the east marches ---
	var east_pois: Variant = load("res://core/world/realm/realm_pois_east_marches.gd")    # no preload: a cycle
	east_pois.hamlet(self, space, node_xz, edges)
	await get_tree().process_frame
	# --- the walking network ------------------------------------------------------------------
	nav.call("build", space, node_xz, edges)
	report.append("nav: %d nodes, %d edges kept of %d" % [(nav.get("nodes") as Dictionary).size(), _edge_count(), edges.size()])
	for d: String in nav.get("dropped"):
		report.append("  dropped " + d)
	for m: String in nav.get("moved"):
		report.append("  moved " + m)
	# restorations already true (no toasts, no fades)
	for id: String in VState.data().restored:
		_apply(id)
	(_well.open as Node3D).visible = VState.restored("well")
	(_well.shut as Node3D).visible = not VState.restored("well")
	_lamps_init()
	QuestWorld.prepare(self)
	# --- the people ---------------------------------------------------------------------------
	phase = _phase_name()
	await _prewarm_rigs()
	_spawn_present()
	talker = Talk.new()
	talker.name = "VillageTalk"
	talker.set("director", self)
	add_child(talker)
	quests = QuestWorld.new()
	quests.name = "Quests"
	quests.set("village", self)
	add_child(quests)
	Events.gloom_tide.connect(func(on: bool) -> void:
		_tide = on
		_mode_t = 0.0)
	Events.boss_slain.connect(func(_id: String) -> void: refresh(true))
	Events.seal_broken.connect(func(_id: String) -> void: refresh(true))
	Events.brazier_kindled.connect(func(_b: Node3D) -> void: _later_refresh())
	VAudio.prewarm()
	(load("res://core/npc/npc_voice.gd") as GDScript).call("prewarm")   # every voice family, behind the loading screen
	build_ms = Time.get_ticks_msec() - t0
	_ready_done = true
	set_meta("village_done", true)
	print("REALM_VILLAGE %d villagers, %d lamps (%d lit), %d lights, restored %s in %d ms" % [villagers.size(), lamps.size(), _lit_count(), lights.size(), str((VState.data().restored as Dictionary).keys()), build_ms])
	for line in report:
		print("REALM_VILLAGE ", line)


## The night is torn down: the village's static caches (sounds, lamp glass, people's meshes) go.
func _exit_tree() -> void:
	VAudio.release()
	Props.release()
	(load("res://core/life/village/villager_rig.gd") as GDScript).call("release")


func _edge_count() -> int:
	var n := 0
	for a: String in nav.get("edges"):
		n += (nav.get("edges")[a] as Dictionary).size()
	return n / 2


## r34: each OUTPOSTS giver's camp (village_props.gd outpost): a fire, a seat, the style's dressing,
## and a small loop of walks round it. The fire's walks are checked clear before the spot is taken.
## The walks round an outpost's fire: [the fire's spot, w1, w2, w3] (offsets from the fire). A
## compact loop is tried where the full one does not fit (the Holds are packed with the Rooted's
## houses, the quarry's floor with its places).
const OUT_WALKS := [Vector2(0.2, 1.05), Vector2(3.4, -2.4), Vector2(4.8, 1.4), Vector2(2.2, 3.6)]
const OUT_WALKS_SMALL := [Vector2(0.2, 1.05), Vector2(2.4, -1.5), Vector2(3.2, 1.0), Vector2(1.4, 2.5)]
const OUT_SEAT := Vector2(1.5, 0.3)
const OUT_BLOCK := Vector2(-1.9, 2.2)          ## the quarry's dressing spot (the block is 0.85 m on)

func _outposts(space: PhysicsDirectSpaceState3D, node_xz: Dictionary, edges: Array) -> void:
	if "--no-r34-outposts" in OS.get_cmdline_user_args():
		return                                     # perf A/B: the doubled world without its givers
	for id: String in Cast.OUTPOSTS:
		var o: Dictionary = Cast.OUTPOSTS[id]
		var nears: Array = o.near if o.near is Array else [o.near]
		var c := Vector2.INF
		var walks: Array = OUT_WALKS
		for wset: Array in [OUT_WALKS, OUT_WALKS_SMALL]:
			var lines: Array = [[wset[0], OUT_SEAT], [wset[0], wset[1]], [wset[1], wset[2]],
				[wset[2], wset[3]], [wset[3], wset[0]], [OUT_SEAT, wset[1]]]
			if String(o.style) == "quarry":
				lines.append_array([[wset[0], OUT_BLOCK], [OUT_BLOCK, wset[3]]])
			for nv: Variant in nears:
				c = _find_clear(nv as Vector2, 2.9, 3.0, 14.0, lines, String(o.region))
				if c != Vector2.INF:
					break
			if c != Vector2.INF:
				walks = wset
				break
		if c == Vector2.INF:
			report.append("no clear spot for %s's outpost" % id)
			continue
		var camp: Dictionary = Props.outpost(self, space, c, String(o.style))
		lights.append(camp.light)
		var f: Vector3 = camp.fire
		var seat: Vector3 = camp.seat
		anchors["@fire_" + id] = f + Vector3.UP * 0.2
		var look: Vector2 = o.get("look", Vector2(f.x + 8.0, f.z + 6.0))
		var dir := (look - Vector2(f.x, f.z)).normalized()
		anchors["@out_" + id] = f + Vector3(dir.x, 0.0, dir.y) * 12.0 + Vector3.UP * 1.2
		node_xz[id + "_fire"] = Vector2(f.x, f.z) + (walks[0] as Vector2)
		node_xz[id + "_seat"] = Vector2(seat.x, seat.z)
		for i in 3:
			node_xz["%s_w%d" % [id, i + 1]] = Vector2(f.x, f.z) + (walks[i + 1] as Vector2)
		edges.append_array([[id + "_fire", id + "_seat"], [id + "_fire", id + "_w1"], [id + "_w1", id + "_w2"],
			[id + "_w2", id + "_w3"], [id + "_w3", id + "_fire"], [id + "_seat", id + "_w1"]])
		if camp.has("block"):
			var b: Vector3 = camp.block
			anchors["@block_" + id] = b
			node_xz[id + "_block"] = Vector2(b.x, b.z - 0.85)
			edges.append_array([[id + "_fire", id + "_block"], [id + "_block", id + "_w3"]])
		outpost_at[id] = f
		# r34 flora: no grass through the camp wherever it settled (RealmFlora grows before the village;
		# secrets.gd flushes this queue after its own sites)
		(load("res://core/life/secrets/kit.gd") as GDScript).call("clear_flora", null, [Vector3(f.x, f.z, 4.2), Vector3(f.x + 2.4, f.z + 0.6, 4.2)])


## A spot near `near` whose `r`-metre disc is clear floor, `path_off` off every Realm path and out
## of every registered site.
func _find_clear(near: Vector2, r: float, path_off: float, camp_r := 15.0, lines: Array = [], region := "", strict := false) -> Vector2:
	var fallback := Vector2.INF            # the first spot whose ring is clear, if none has clear walks too
	var flat := 0.9 if region == "" else 2.2      # r34 outposts: each piece sits on its own ground (the walks are checked step by step)
	var rings: Array = [0.0, 1.5, 3.0, 4.5, 6.0, 8.0, 10.0, 12.0, 15.0, 18.0]
	if region != "" or strict:
		rings.append_array([21.0, 24.0, 28.0])      # r34 outposts: a region's ground can be broken (the hermit: the Thornwood's trees are big)
	for ring: float in rings:
		var n := 1 if ring == 0.0 else (10 if ring < 19.0 else 16)
		for i in n:
			var a := TAU * float(i) / float(n) + ring
			var p := near + Vector2(cos(a), sin(a)) * ring
			if RealmLayout.path_dist(p) < path_off or not WorldLanes.site_at(p, r).is_empty() or _near_camp(p, camp_r):
				continue
			if region != "" and (not RealmLayout.BOUNDS.grow(-6.0).has_point(p) or String(RealmLayout.region_at(p.x, p.y).get("id", "")) != region or _near_slot(p)):
				continue
			var ok := true
			var lo := INF
			var hi := -INF
			for j in 9:
				var q := p if j == 0 else p + Vector2(cos(TAU * float(j) / 8.0), sin(TAU * float(j) / 8.0)) * r
				var y: float = nav.call("floor_at", q.x, q.y)
				lo = minf(lo, y)
				hi = maxf(hi, y)
				if not bool(nav.call("clear", Vector3(q.x, y, q.y))) or y < -0.8:
					ok = false
					break
			if ok and hi - lo < flat:
				if fallback == Vector2.INF:
					fallback = p
				for ln: Array in lines:
					var a0: Vector2 = p + (ln[0] as Vector2)
					var a1: Vector2 = p + (ln[1] as Vector2)
					if region != "" or strict:
						# r34 outposts (and the hermit's camp): the walk must pass the network's own test (steps, water, props)
						var e0 := Vector3(a0.x, float(nav.call("floor_at", a0.x, a0.y)), a0.y)
						var e1 := Vector3(a1.x, float(nav.call("floor_at", a1.x, a1.y)), a1.y)
						if String(nav.call("_edge_ok", e0, e1)) != "":
							ok = false
							break
					var nseg := maxi(2, ceili(a0.distance_to(a1) / 0.35))
					for k in nseg + 1:
						var q2 := a0.lerp(a1, float(k) / float(nseg))
						if not bool(nav.call("clear", Vector3(q2.x, float(nav.call("floor_at", q2.x, q2.y)), q2.y))):
							ok = false
							break
					if not ok:
						break
			if ok and hi - lo < flat:
				return p
	if strict:
		print("REALM_VILLAGE camp near %s: no spot with clear walks, fallback %s" % [near, fallback])
	return fallback if region == "" else Vector2.INF       # r34 outposts: walks that hold, or none


## r34: too near a region's fire (RealmLayout.SLOTS "fire": the places agent's brazier; its built
## places are WorldLanes sites, the camps really planted are _near_camp's).
func _near_slot(p: Vector2) -> bool:
	for rid: String in RealmLayout.SLOTS:
		for sl: Dictionary in RealmLayout.SLOTS[rid]:
			if String(sl.kind) == "fire" and (sl.at as Vector2).distance_to(p) < 7.0:
				return true
	return false


## Near one of the encounter camps (EnemySpawner.REALM_CAMPS): a hermit there would be in the
## middle of a fight, and a site there would stop the camp from being placed.
func _near_camp(p: Vector2, r: float) -> bool:
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var at: Vector3 = c.get("at", Vector3.INF)
		if Vector2(at.x, at.z).distance_to(p) < r:
			return true
	return false


# --- people -------------------------------------------------------------------------------------

## Hearthward's cast and the outposts' and Weirford's (west marches: village_cast_west_marches.gd), as one table.
static var _cast_all: Dictionary = {}


static func cast_all() -> Dictionary:
	if _cast_all.is_empty():
		_cast_all = Cast.cast().duplicate()
		_cast_all.merge(WestCast.cast())
		_cast_all.merge(Travellers.CAST)
		_cast_all.merge(WanderCast.CAST)           # the Late Ringer: present by his task's step
		_cast_all.merge(Towns.cast())
	return _cast_all


func _present(id: String) -> bool:
	var d: Dictionary = cast_all()[id]
	var when := String(d.get("when", ""))
	if when == "":
		return true
	return VState.test(when, VState.world(get_tree()), get_tree())


## Start making the meshes of the people who are always there (and the Watch's and the pilgrims'
## looks) on worker threads; the Realm starts it with the load and _prewarm_rigs() collects it.
static func warm_start() -> Dictionary:
	var warm: Array = []
	var everyone := cast_all()
	for id: String in everyone:
		var rd: Variant = (everyone[id] as Dictionary).get("rig")
		if rd is Dictionary and String((everyone[id] as Dictionary).get("when", "")) == "":
			var o: Dictionary = (rd as Dictionary).duplicate()
			o["name"] = id
			warm.append(o)
	for look: Dictionary in Watch.LOOKS:
		warm.append(look.duplicate())
	for look: Dictionary in RoamEvents.PILGRIMS:
		warm.append(look.duplicate())
	warm.append_array(WayfarerDB.rig_looks())         # the roads' people (core/life/wayfarers)
	return DwarfRig.warm_begin(warm, func() -> Node: return Rig.new(), Rig.SELF_V)


func _prewarm_rigs() -> void:
	var h: Dictionary = DwarfRig.warm_batches.get("village", {})
	if h.is_empty():
		h = warm_start()
	await DwarfRig.warm_finish(h, get_tree())


func _spawn_present() -> void:
	var everyone := cast_all()
	for id: String in everyone:
		if villagers.has(id) or not _present(id):
			continue
		var d: Dictionary = QuestWorld.override(id, everyone[id])
		if d.is_empty():
			continue
		if d.has("camp") and not nav.call("has", String(d.home)):
			report.append("%s: camp not built, not spawned" % id)
			continue
		var v: Node3D = VillagerScript.new()
		v.call("setup", id, d, self)
		add_child(v)
		villagers[id] = v
		v.call("begin", routine_for(id), true)


func _phase_name() -> String:
	var f := clock / CYCLE
	var name_now := String(Cast.PHASES[0][1])
	for p: Array in Cast.PHASES:
		if f >= float(p[0]):
			name_now = String(p[1])
	return name_now


func _process(delta: float) -> void:
	if not _ready_done:
		return
	var dt := delta * time_scale
	if clock + dt >= CYCLE:
		nights += 1
	clock = fposmod(clock + dt, CYCLE)
	var ph := _phase_name()
	if ph != phase:
		phase = ph
		for id: String in villagers:
			_pending[id] = true
	_mode_t -= delta
	if _mode_t <= 0.0:
		_mode_t = 1.0
		var m := _mode_now()
		if m != mode:
			mode = m
			for id2: String in villagers:
				if routine_for(id2) != String((villagers[id2] as Node).get("routine")):
					_pending[id2] = true
				(villagers[id2] as Node).set("hurry", 1.9 if m == "danger" else 1.0)
	for id: String in _pending.keys():
		var v: Node3D = villagers.get(id)
		if v == null:
			_pending.erase(id)
			continue
		if bool(v.call("busy")) or v.get("attend") != null:
			continue
		_pending.erase(id)
		v.call("begin", routine_for(id))
	# lamps burn down and ease toward lit / out
	for lid: String in lamps:
		var l: Dictionary = lamps[lid]
		if float(l.want) > 0.5:
			l.fuel = float(l.fuel) - dt / (CYCLE * 0.95)
			if float(l.fuel) <= 0.0:
				l.want = 0.0
		var target := float(l.want) * (0.55 + 0.45 * clampf(float(l.fuel) * 4.0, 0.0, 1.0))
		if absf(float(l.lit) - target) > 0.002:
			l.lit = move_toward(float(l.lit), target, delta * 0.8)
			Props.set_lit(l, float(l.lit))
	# the forge flare dies back after each strike
	if forge_flare:
		_flare = maxf(0.0, _flare - delta * 4.0)
		# the hearth keeps the forge warm between blows (it read near black under the grade)
		forge_flare.light_energy = 0.22 + 1.1 * _flare
		forge_flare.visible = true


## The routine a villager follows now: the phase's, unless it rains (a "rain" routine) or the
## village is in danger ("flee": into the Keg).
func routine_for(id: String) -> String:
	var v: Node = villagers.get(id)
	var d: Dictionary = v.get("data") if v else cast_all().get(id, {})
	var sch: Dictionary = d.get("schedule", {})
	var base := String(sch.get(phase, ""))
	if mode == "danger" and (d.get("routines", {}) as Dictionary).has("flee"):
		return "flee"
	if mode == "rain" and sch.has("rain") and not base in d.get("all_weather", []):
		return String(sch.rain)
	return base


## "danger" while the Gloom tide is up or hollowed walk in the village; "rain" in a wet front.
func _mode_now() -> String:
	if _tide:
		return "danger"
	var c := Vector3(4.0, 0.0, 40.0)
	for e: Node in get_tree().get_nodes_in_group(Groups.ENEMY):
		if e is Node3D and is_instance_valid(e) and not e.is_queued_for_deletion():
			var p := (e as Node3D).global_position
			if Vector2(p.x - c.x, p.z - c.z).length_squared() < 30.0 * 30.0 and bool(e.get("visible")):
				return "danger"
	if _weather == null or not is_instance_valid(_weather):
		var w := get_parent().get_node_or_null("Wildlife") if get_parent() else null
		_weather = w.get_meta("weather") if w and w.has_meta("weather") else null
	if _weather:
		var st: Variant = _weather.get("state")
		if st is Dictionary and float((st as Dictionary).get("rain", 0.0)) > 0.5:
			return "rain"
	return ""


# --- lamps ------------------------------------------------------------------------------------------

func _lamps_init() -> void:
	var on := VState.lamps()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for lid: String in lamps:
		var l: Dictionary = lamps[lid]
		if lid in on:
			l.want = 1.0
			l.fuel = rng.randf_range(0.35, 1.0)
			l.lit = 1.0
		Props.set_lit(l, float(l.lit))


func round_lamps() -> Array[String]:
	return VState.lamps()


func lamp_spot(lid: String) -> String:
	return String(lamp_spots.get(lid, ""))


func lamp_pos(lid: String) -> Vector3:
	return (lamps[lid] as Dictionary).pos if lamps.has(lid) else Vector3.INF


func lamp_needs(lid: String) -> bool:
	return lamps.has(lid) and (float(lamps[lid].want) < 0.5 or float(lamps[lid].fuel) < 0.5)


func light_lamp(lid: String) -> void:
	if not lamps.has(lid):
		return
	var l: Dictionary = lamps[lid]
	l.want = 1.0
	l.fuel = 1.0
	Vfx.burst(l.pos, Color(1.0, 0.65, 0.3), {"count": 8, "life": 0.5, "speed": Vector2(0.3, 1.2), "size": 0.03, "gravity": -2.0, "spread": 90.0})


func _lit_count() -> int:
	var n := 0
	for lid: String in lamps:
		if float(lamps[lid].want) > 0.5:
			n += 1
	return n


# --- anchors and work events -----------------------------------------------------------------------

func anchor(key: String) -> Vector3:
	return anchors.get(key, Vector3.INF)


func strike(_v: Node3D) -> void:
	var at: Vector3 = anchors["@anvil"] + Vector3.UP * 0.03
	Vfx.burst(at, Color(1.0, 0.62, 0.22), {"count": 16, "life": 0.55, "speed": Vector2(1.5, 4.2), "size": 0.022, "gravity": -9.0, "spread": 75.0, "dir": Vector3.UP, "damping": 0.6})
	VAudio.play("anvil", at, -7.0, randf_range(0.96, 1.04))
	_flare = 1.0


func quench(_v: Node3D) -> void:
	var at: Vector3 = anchors["@water"]
	Vfx.burst(at + Vector3.UP * 0.05, Color(0.82, 0.84, 0.9, 0.45), {"count": 22, "life": 1.8, "speed": Vector2(0.3, 1.1), "size": 0.28, "gravity": 0.5, "spread": 25.0, "dir": Vector3.UP, "additive": false, "grow": 2.0})
	VAudio.play("quench", at, -8.0)


func grind_sparks(_v: Node3D) -> void:
	var at: Vector3 = anchors["@wheel"]
	Vfx.burst(at, Color(1.0, 0.75, 0.35), {"count": 10, "life": 0.4, "speed": Vector2(2.0, 4.0), "size": 0.015, "gravity": -9.0, "spread": 25.0, "dir": Vector3(0, 0.3, -1).normalized()})


func chop(v: Node3D) -> void:
	var at: Vector3 = anchors.get("@block_" + String(v.get("id")), v.global_position)
	Vfx.burst(at, Color(0.6, 0.47, 0.32), {"count": 8, "life": 0.7, "speed": Vector2(1.0, 3.0), "size": 0.04, "gravity": -9.0, "spread": 60.0, "additive": false})
	VAudio.play("chop", at, -6.0, randf_range(0.92, 1.06))


func dig(v: Node3D) -> void:
	var at: Vector3 = anchors.get("@pit", v.global_position)
	Vfx.burst(at + Vector3.UP * 0.1, Color(0.38, 0.31, 0.24), {"count": 10, "life": 0.8, "speed": Vector2(0.8, 2.2), "size": 0.05, "gravity": -9.0, "spread": 40.0, "dir": Vector3(1, 1, 0).normalized(), "additive": false})
	VAudio.play("dig", at, -8.0, randf_range(0.9, 1.05))


# --- talking ----------------------------------------------------------------------------------------

func talk(v: Node3D, by: Node) -> void:
	if talker == null or not bool(talker.call("start", v, by)):
		v.set("attend", null)


# --- restoration ------------------------------------------------------------------------------------

func _later_refresh() -> void:
	# the story director counts the brazier on the same signal: look once it has
	await get_tree().process_frame
	refresh(true)


## Check the world against what can come back; build and announce what just did.
func refresh(announce := true) -> void:
	var fresh := VState.refresh(get_tree())
	for id: String in fresh:
		_apply(id, true)
		var ann: Dictionary = VState.data().announced
		if announce and not ann.has(id):
			ann[id] = true
			for r: Dictionary in Cast.RESTORE:
				if String(r.id) == id:
					Events.toast.emit(String(r.toast))
	if not fresh.is_empty():
		VState.save()
	_spawn_present()


func _apply(id: String, live := false) -> void:
	if overlays.has(id):
		return
	var space := get_world_3d().direct_space_state
	match id:
		"wrights_home":
			var h := Props.windows(self, "south")
			var xf := Props.cottage_xf("south")
			var c: Dictionary = Props.COTTAGES.south
			var l := Props.light(h, "WrightsWindow", xf * Vector3(-float(c.w) * 0.5 + float(c.w) * 0.72, 1.35, -float(c.d) * 0.5 - 0.7), Color(1.0, 0.58, 0.27), 0.55, 4.0)
			lights.append(l)
			overlays[id] = h
		"reed_home":
			overlays[id] = Props.windows(self, "reed")
		"reed_roof":
			overlays[id] = Props.reed_roof(self, space)
		"well":
			if _well.has("open"):
				(_well.shut as Node3D).visible = false
				overlays[id] = _well.open
		"harrow_frame":
			overlays[id] = Props.harrow_frame(self)
		"harrow_roof":
			overlays[id] = Props.harrow_roof(self)
		"lamps_more", "lamps_all":
			overlays[id] = self
			if live:
				for lid: String in VState.lamps():
					var l2: Dictionary = lamps.get(lid, {})
					if not l2.is_empty() and float(l2.want) < 0.5:
						light_lamp(lid)
		_:
			overlays[id] = self
	if _well.has("open"):
		(_well.open as Node3D).visible = VState.restored("well")
		(_well.shut as Node3D).visible = not VState.restored("well")
