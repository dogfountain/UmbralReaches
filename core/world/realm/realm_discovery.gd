extends Node
## r33 world: zone discovery (WoW's zone and subzone text, adapted). Twice a second the wanderer's
## place is looked up:
##   region   RealmLayout.REGIONS (the most specific place wins, with hysteresis: a new region must
##            be clearly entered and the current one clearly left before the name changes). The first
##            entry ever is a discovery: the big carved banner with the place's line, the Journal's
##            Places page (CodexStore), and Events.region_discovered(id, "region"). Later entries
##            show the name alone, smaller, at most once a minute per place.
##   subzone  named spots inside the regions (SUBZONES below, plus every r31 point of interest in
##            the "world_poi" group and the Watchtower): the Kindled Keg, the Crossing, the Fen Door,
##            the Drowned Belfry, the Almonry... A smaller name under the region's; the first visit
##            is a discovery too: Events.region_discovered("sub_<id>", "subzone").
## Discovery state: regions in CodexStore (codex.cfg, shared with the Journal), subzones in
## Travel.system_state("world_discovery").sub (and the r31 POIs still in world_pois.found).
##
## Reward hook (loot/XP agents): connect Events.region_discovered(id: String, kind: String). It fires
## once per place per save: kind "region" (id = RealmLayout region id) or "subzone" (id "sub_<id>").
## The music answers with a short cue (scape_music.gd `cue_discovery`).
## Built by realm_pois.gd's build (after the flora); group "realm_discovery" (the Journal's own
## region naming stands down while this node exists). Load by path (no class_name).

const LoreDB := preload("res://core/world/realm/lore_db.gd")
const CodexStore := preload("res://core/world/realm/lore/codex_store.gd")
const BannerScript := preload("res://core/world/realm/discovery_banner.gd")
const TextDirector := preload("res://ui/text_director.gd")

const GROUP := "realm_discovery"
const SID := "world_discovery"
const TICK := 0.5
const REVISIT_GAP := 60.0
const ARM_AT := 6.5                      ## the night's own title card first
## Named spots that are not their own region: id -> {name, line, and a shape: "rect" Rect2 (xz),
## "c"+"r" circle, or "seg" [a, b] + "r" capsule}. Found inside 0.8 of the shape, left past it.
const SUBZONES := {
	"keg": {"name": "The Kindled Keg", "line": "the last warm room on the road", "rect": Rect2(10.0, 25.6, 16.0, 9.2)},
	"crossing": {"name": "The Crossing", "line": "what the Stair left standing", "seg": [Vector2(0.0, -10.0), Vector2(0.0, -70.0)], "r": 8.0},
	"fen_door": {"name": "The Fen Door", "line": "the Abbot's back stair", "c": Vector2(36.0, -66.0), "r": 8.0},
	"well": {"name": "Hearth Well", "line": "water drawn for the first fire", "c": Vector2(-10.0, 48.0), "r": 6.0},
	"stair_foot": {"name": "The Stair-foot", "line": "where the pilgrims took off their shoes", "c": Vector2(-3.0, 0.0), "r": 7.0},
}

var region := ""                         ## the region the wanderer is in (id)
var subzone := ""                        ## the named spot, or ""
var banner: CanvasLayer
var found_log: Array[String] = []        ## tests: ids discovered this night, in order
var _t := 0.0
var _clock := 0.0
var _last_named := {}                    ## id -> _clock when its name was last shown
var _spots: Array[Dictionary] = []       ## runtime subzones: {id, name, line, c (Vector2), r} or seg/rect
var _spots_t := 0.0
var _hold: Array[Dictionary] = []        ## banners waiting for the text director's lane: {method, name, line, fresh}


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	CodexStore.ensure()
	banner = BannerScript.new()
	banner.name = "DiscoveryBanner"
	add_child(banner)


func _process(delta: float) -> void:
	_clock += delta
	_pump_holds()
	_t -= delta
	if _t > 0.0 or _clock < ARM_AT:
		return
	_t = TICK
	if get_tree().get_first_node_in_group("fire_flight") != null:
		return                                  # the Ember Road names the place on landing
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if p == null or not p.is_inside_tree():
		return
	_spots_t -= TICK
	if _spots_t <= 0.0:
		_spots_t = 10.0
		_collect_spots()
	visit(p.global_position)


## Name what is at `at` (tests call it directly with a point). Returns true if anything changed.
func visit(at: Vector3) -> bool:
	var changed := false
	var r := region_for(at)
	if r != "" and r != region:
		region = r
		_enter_region(r)
		changed = true
	var s := subzone_for(at)
	if s != subzone:
		subzone = s
		if s != "":
			_enter_subzone(s)
		changed = true
	return changed


## Region under xz with hysteresis (the Journal's r30 rule, kept): the most specific place wins; a new
## one must be clearly entered (plateau weight >= 0.6) and the current clearly left (< 0.3).
func region_for(at: Vector3) -> String:
	if RealmLayout.OSSUARY_HALL.has_point(at):
		at = Vector3(17.0, at.y, -66.0)      # r34 crypt: the pit hall under the fen and the Crowns is the Ossuary's
	var best := ""
	var best_w := 0.0
	var cur_w := 0.0
	var best_s := 0.0
	for rd: Dictionary in RealmLayout.REGIONS:
		var w := RealmLayout.place_weight(rd, at.x, at.z)
		var sc := RealmLayout.place_score(rd, at.x, at.z)
		if String(rd.id) == region:
			cur_w = w
		if sc > best_s:
			best_s = sc
			best_w = w
			best = String(rd.id)
	if best == region or best_w < 0.6:
		return ""
	var into_place := best_w >= 0.99 and cur_w >= 0.99
	if region != "" and cur_w >= 0.3 and best_w - cur_w < 0.4 and not into_place:
		return ""
	return best


## The named spot at `at`: inside 0.8 of its shape to enter; you stay in it until 1.15 of it.
func subzone_for(at: Vector3) -> String:
	var q := Vector2(at.x, at.z)
	if subzone != "":
		var cur := _spot(subzone)
		if not cur.is_empty() and _inside(cur, q, 1.15):
			return subzone
	var best := ""
	var best_area := INF
	for s in _all_spots():
		if _inside(s, q, 0.8):
			var a := _area(s)
			if a < best_area:
				best_area = a
				best = String(s.id)
	return best


func is_found(id: String, kind := "region") -> bool:
	if kind == "region":
		return CodexStore.discovered(id)
	var st := Travel.system_state(SID)
	return st.get("sub") is Dictionary and (st.sub as Dictionary).has(id)


func spot_ids() -> Array[String]:
	var out: Array[String] = []
	for s in _all_spots():
		out.append(String(s.id))
	return out


# --- inside ---------------------------------------------------------------------------------------

func _enter_region(id: String) -> void:
	var info: Dictionary = LoreDB.PLACE_INFO.get(id, {})
	if info.is_empty():
		return
	var m := _music()
	if m:
		m.call("set_region", id)                # the music plays in the region's key
	var fresh := CodexStore.discover(id)
	if fresh:
		found_log.append(id)
		Events.region_discovered.emit(id, "region")
		_cue(id, true)
	elif _clock - float(_last_named.get(id, -1000.0)) < REVISIT_GAP:
		return
	_last_named[id] = _clock
	_announce("show_region", String(info.name), String(info.line), fresh)


func _enter_subzone(id: String) -> void:
	var s := _spot(id)
	if s.is_empty():
		return
	var st := Travel.system_state(SID)
	if not (st.get("sub") is Dictionary):
		st["sub"] = {}
	var sub: Dictionary = st.sub
	var fresh := not sub.has(id)
	if fresh:
		sub[id] = true
		if s.has("poi"):                        # the r31 places kept their own memory: keep it in step
			var ps := Travel.system_state("world_pois")
			if not (ps.get("found") is Dictionary):
				ps["found"] = {}
			(ps.found as Dictionary)[String(s.poi)] = true
		found_log.append("sub_" + id)
		Events.region_discovered.emit("sub_" + id, "subzone")
		_cue(region, false)
		Travel.save_soon()
	elif _clock - float(_last_named.get("sub_" + id, -1000.0)) < REVISIT_GAP:
		return
	_last_named["sub_" + id] = _clock
	_announce("show_subzone", String(s.name), String(s.line), fresh)


## The text director (ui/text_director.gd) decides when a banner may draw: not over narration, a dialogue
## box or a lock-on fight, and one per 90 s. A discovery past that limit leaves a quiet line in the
## corner instead (the Journal and Events.region_discovered have it regardless).
func _announce(method: String, title: String, line: String, fresh: bool) -> void:
	var td := TextDirector.of(self)
	if td == null:
		banner.call(method, title, line, fresh)
		return
	_hold.append({"method": method, "kind": method.trim_prefix("show_"), "name": title, "line": line, "fresh": fresh})
	while _hold.size() > 3:
		var gone: Dictionary = _hold.pop_front()
		td.quiet(("Discovered: " if gone.fresh else "") + String(gone.name))
	_pump_holds()


func _pump_holds() -> void:
	if _hold.is_empty():
		return
	var td := TextDirector.of(self)
	if td == null:
		return
	while not _hold.is_empty() and td.can_begin(&"discovery"):
		var h: Dictionary = _hold.pop_front()
		if not td.discovery_ok():
			td.quiet(("Discovered: " if h.fresh else "") + String(h.name))
			continue
		td.begin(&"discovery", 7.4 if h.fresh else 4.8)
		banner.call(String(h.method), String(h.name), String(h.line), bool(h.fresh))
		return


func _cue(id: String, big: bool) -> void:
	var m := _music()
	if m:
		m.call("cue_discovery", id, big)


func _music() -> Node:
	var amb := get_parent().get_node_or_null("Ambience") if get_parent() else null
	var m: Variant = amb.get("music") if amb else null
	if m is Node and is_instance_valid(m) and (m as Node).has_method("cue_discovery"):
		return m
	return null


func _collect_spots() -> void:
	_spots.clear()
	for n in get_tree().get_nodes_in_group("world_poi"):
		if not n.has_meta("centre"):
			continue
		var c: Vector3 = n.get_meta("centre")
		_spots.append({"id": "poi_" + String(n.get_meta("poi")), "poi": String(n.get_meta("poi")), "name": String(n.get_meta("title")),
			"line": String(n.get_meta("line")), "c": Vector2(c.x, c.z), "r": float(n.get_meta("radius")) * 0.75})
	# r34 places: named spots of the new ground that are not buildings (realm_pois_r34.gd EXTRA)
	if get_parent() and get_parent().get_node_or_null("RealmPois") != null:
		var extra: Dictionary = (load("res://core/world/realm/realm_pois_r34.gd") as GDScript).get("EXTRA")
		for id: String in extra:
			var e: Array = extra[id]
			_spots.append({"id": id, "name": String(e[1]), "line": String(e[2]), "c": e[0], "r": float(e[3])})
	if get_parent() and get_parent().get_node_or_null("RealmWayfinding/Watchtower") != null:
		_spots.append({"id": "watchtower", "name": "The Old Watchtower", "line": "a stump of the wall that kept the road",
			"c": Vector2(19.0, 10.4), "r": 7.0})          # RealmWayfinding.TOWER_AT


func _all_spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in SUBZONES:
		var d: Dictionary = (SUBZONES[id] as Dictionary).duplicate()
		d["id"] = id
		out.append(d)
	out.append_array(_spots)
	return out


func _spot(id: String) -> Dictionary:
	for s in _all_spots():
		if String(s.id) == id:
			return s
	return {}


static func _inside(s: Dictionary, q: Vector2, k: float) -> bool:
	if s.has("rect"):
		var r: Rect2 = s.rect
		var c := r.get_center()
		var hs := r.size * 0.5 * k
		return absf(q.x - c.x) <= hs.x and absf(q.y - c.y) <= hs.y
	if s.has("seg"):
		var a: Vector2 = s.seg[0]
		var b: Vector2 = s.seg[1]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		return q.distance_to(a + ab * t) <= float(s.r) * k
	return q.distance_to(s.c) <= float(s.r) * k


static func _area(s: Dictionary) -> float:
	if s.has("rect"):
		return (s.rect as Rect2).get_area()
	if s.has("seg"):
		return float(s.r) * 2.0 * ((s.seg[1] as Vector2) - (s.seg[0] as Vector2)).length()
	return PI * float(s.r) * float(s.r)
