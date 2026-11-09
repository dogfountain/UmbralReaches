extends Node
## The Sky Chain's quest (core/story/quest_chains_sky_chain.gd), static checks: the giver is in the cast, the zone is a
## region, step kinds are runner kinds, every pickup names a step of its own quest, and the points are near the anchor.
## Ends: SKY CHAIN QUEST TEST PASS / FAIL n

const Q := preload("res://core/story/quest_chains_sky_chain.gd")
const Cast := preload("res://core/life/village/village_cast.gd")
const KINDS := ["find", "reach", "gather", "talk", "slay", "collect", "seal", "cond", "visit", "carry", "turnin", "place", "kill", "escort"]
const ANCHOR := Vector2(76.0, -131.0)


func _ready() -> void:
	var fails := 0
	var zones: Array = []
	for r: Dictionary in RealmLayout.REGIONS:
		zones.append(String(r.id))
	var q: Dictionary = Q.CHAIN_COUNT
	if not Cast.CAST.has(q.giver):
		fails += 1
		print("FAIL giver ", q.giver)
	if not String(q.zone) in zones:
		fails += 1
		print("FAIL zone ", q.zone)
	for s: Dictionary in q.steps:
		if not String(s.kind) in KINDS:
			fails += 1
			print("FAIL kind ", s.kind)
		if s.has("at") and (s.at as Vector2).distance_to(ANCHOR) > 40.0:
			fails += 1
			print("FAIL far ", s.at)
	for key: String in Q.PICKUPS:
		var p: Dictionary = Q.PICKUPS[key]
		if p.quest != "chain_count" or int(p.step) != 1 or (p.near as Vector2).distance_to(ANCHOR) > 40.0:
			fails += 1
			print("FAIL pickup ", key)
	print("SKY CHAIN QUEST TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	get_tree().quit()
