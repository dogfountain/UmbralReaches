extends RefCounted
## Versioned migration and sanitising of the state this build adds to a save (Travel.story and Travel.systems). Called by
## Travel when a slot is loaded: an older save (no `_v`) gains the new keys empty; a damaged key (a number where a list belongs,
## a list with an odd length, a negative count) is replaced by its empty form instead of raising an error later, so the rest of
## the save is kept. Pure and static; it needs nothing but the two dictionaries.
## Versions: 1 (before this round, no key) -> 2: tally, chronicle, chronicle_keys, trail, pins, night_no, night_age,
## danger_warned, courier, opening_seen (a flag); stable: bond, names, left, spirit, tack, groomed, bags.
## Load by path (no class_name): const StateMigrate := preload("res://core/util/state_migrate.gd")

const VERSION := 2
const MAX_TRAIL := 5200            ## ints (two per point)
const MAX_PINS := 24


static func run(story: Dictionary, systems: Dictionary) -> void:
	var v := int(story.get("_v", 1))
	if v > VERSION:
		return                       # a newer save: leave it alone
	_story(story)
	_stable(systems)
	story["_v"] = VERSION


static func _dict(d: Dictionary, k: String) -> Dictionary:
	if not (d.get(k) is Dictionary):
		d[k] = {}
	return d[k] as Dictionary


static func _story(st: Dictionary) -> void:
	_dict(st, "flags")
	var t := _dict(st, "tally")
	for k: String in ["total", "falls", "camps", "places", "night_kills", "photos", "runs"]:
		t[k] = maxi(0, int(t.get(k, 0))) if (t.get(k) is int or t.get(k) is float) else 0
	var kills := _dict(t, "kills")
	for k: Variant in kills.keys():
		if not (kills[k] is int or kills[k] is float) or int(kills[k]) < 0:
			kills.erase(k)
	if not (st.get("chronicle") is Array):
		st["chronicle"] = []
	var clean: Array = []
	for e: Variant in st.chronicle:
		if e is Dictionary and (e as Dictionary).has("t"):
			clean.append({"n": maxi(1, int((e as Dictionary).get("n", 1))), "k": String((e as Dictionary).get("k", "")), "t": String((e as Dictionary).t)})
	st["chronicle"] = clean.slice(maxi(0, clean.size() - 240))
	_dict(st, "chronicle_keys")
	_dict(st, "danger_warned")
	_dict(st, "courier")
	if not (st.get("night_no") is int or st.get("night_no") is float) or int(st.night_no) < 0:
		st["night_no"] = 0
	else:
		st["night_no"] = int(st.night_no)
	if not (st.get("night_age") is int or st.get("night_age") is float) or float(st.night_age) < 0.0:
		st["night_age"] = 0.0
	st["trail"] = _ints(st.get("trail"), MAX_TRAIL)
	st["pins"] = _ints(st.get("pins"), MAX_PINS)
	# a courier run needs a route and a time; anything else is not a run
	var c: Dictionary = st.courier
	if not c.is_empty() and (String(c.get("route", "")) == "" or not (c.get("t") is int or c.get("t") is float)):
		c.clear()


## A flat list of ints of even length, at most `cap` long (the newest kept).
static func _ints(v: Variant, cap: int) -> Array:
	var out: Array = []
	if v is Array:
		for x: Variant in v:
			if x is int or x is float:
				out.append(int(x))
	if out.size() % 2 == 1:
		out.pop_back()
	if out.size() > cap:
		out = out.slice(out.size() - cap)
	return out


static func _stable(sy: Dictionary) -> void:
	var s := _dict(sy, "stable")
	if not (s.get("owned") is Array):
		s["owned"] = []
	for k: String in ["bond", "names", "left", "spirit", "tack", "groomed", "bags"]:
		_dict(s, k)
	var bond: Dictionary = s.bond
	for k: Variant in bond.keys():
		if not (bond[k] is int or bond[k] is float) or float(bond[k]) < 0.0:
			bond.erase(k)
	var bags: Dictionary = s.bags
	for b: Variant in bags.keys():
		if not (bags[b] is Dictionary):
			bags.erase(b)
			continue
		for item: Variant in (bags[b] as Dictionary).keys():
			var n: Variant = (bags[b] as Dictionary)[item]
			if not (n is int or n is float) or int(n) <= 0:
				(bags[b] as Dictionary).erase(item)
