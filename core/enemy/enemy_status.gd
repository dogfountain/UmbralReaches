class_name EnemyStatus
extends RefCounted

const Tiers := preload("res://core/life/encounters/tiers.gd")
## The buffs and debuffs an enemy shows on its plate (Enemy.debuffs): statics only.


static func list(e: Enemy) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if e.marks > 0:
		out.append({"id": "umbral_mark", "name": "Umbral Mark", "left": maxf(e._mark_t, 0.0), "stacks": e.marks, "harmful": true})
	if e._broken_t > 0.0:
		out.append({"id": "broken", "name": "Broken", "left": e._broken_t, "stacks": 1, "harmful": true})
	var rec := _affliction(e)
	if not rec.is_empty():
		if float(rec.get("burn", 0.0)) > 0.0:
			out.append({"id": "burning", "name": "Burning", "left": float(rec.burn), "stacks": 1, "harmful": true})
		if float(rec.get("frozen", 0.0)) > 0.0:
			out.append({"id": "frozen", "name": "Frozen", "left": float(rec.frozen), "stacks": 1, "harmful": true})
		elif float(rec.get("chill", 0.0)) > 0.0:
			out.append({"id": "chilled", "name": "Chilled", "left": float(rec.chill), "stacks": maxi(int(rec.get("stacks", 1)), 1), "harmful": true})
		if float(rec.get("slow", 0.0)) > 0.0:
			out.append({"id": "slowed", "name": "Slowed", "left": float(rec.slow), "stacks": 1, "harmful": true})
	if e._silence_t > 0.0:
		out.append({"id": "silenced", "name": "Interrupted", "left": e._silence_t, "stacks": 1, "harmful": true})
	if e._shroud_t > 0.0:
		out.append({"id": "shrouded", "name": "Shrouded", "left": e._shroud_t, "stacks": 1, "harmful": false})
	if e._ward_t > 0.0:
		out.append({"id": "warded", "name": "Warded", "left": e._ward_t, "stacks": 1, "harmful": false})
	if e.dmg_mult > 1.001:
		out.append({"id": "enraged", "name": "Enraged", "left": -1.0, "stacks": 1, "harmful": false})
	var extra: Variant = e.get_meta(&"statuses") if e.has_meta(&"statuses") else null
	if extra is Array:
		for d: Variant in extra:
			if d is Dictionary:
				out.append(d)
	return out


## What core/skills/afflict.gd keeps for `e` ({} when none). Loaded by path on first use (no class_name there).
static var _afflict: Variant = null


static func _affliction(e: Enemy) -> Dictionary:
	if _afflict == null:
		_afflict = load("res://core/skills/afflict.gd")
	return _afflict.record_of(e) as Dictionary


static func level(e: Enemy) -> int:
	if e.boss:
		return -1
	if e.has_meta(&"level"):
		return int(e.get_meta(&"level"))
	# the tier's band and how far out the pawn was set down (its home: a hunter's follows the wanderer, so the
	# first read is kept); see Tiers.level_for
	if not e.has_meta(&"enc_at"):
		e.set_meta(&"enc_at", e.home if e.home != Vector3.ZERO else e.global_position)
	var lv := Tiers.level_for(int(e.get_meta(&"enc_tier", 0)), e.get_meta(&"enc_at"), 1 if e.max_hp >= 4 else 0)
	match e.rank():
		"elite":
			lv += 2
		"rare":
			lv += 3
	return lv
