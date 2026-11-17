extends RefCounted
## The data side of the task verbs (docs/QUEST_VERBS.md): clues, tracks, lantern_walk, order, vigil. Statics over
## step dictionaries and a task's saved state `d`; no Book or Chains here (quest_chains.gd preloads this, so it
## must not preload them back). The world side is verb_world.gd (clues, tracks, order, outcome props), the live
## nodes are verb_lantern.gd and defend.gd (vigil), the runner stands them up (quest_runner.gd).
## Load by path: const VerbKit := preload("res://core/story/verb_kit.gd")

const KINDS := ["clues", "tracks", "lantern_walk", "order", "vigil"]
## Verbs whose step counts up (the tracker shows n/of; the text may use {n} and {of}).
const COUNTED := ["clues", "tracks"]
const AREA_R := 16.0          ## a search area's radius (m) unless the step says `r`
const TRAIL_R := 14.0         ## the same for a trail's next mark
const MARK_R := 4.0           ## a trail's mark is found this close (m, flat)
const CLUE_PREFIX := "c:"     ## a found clue's key in the task's `f` ("c:" + key; the qc: condition reads it)


static func is_verb(kind: String) -> bool:
	return kind in KINDS


## The saved key of a clue.
static func clue_key(key: String) -> String:
	return CLUE_PREFIX + key


## How many clues of step `stp` are found, in state `d`, and how many are wanted (`need`).
static func clue_count(stp: Dictionary, d: Dictionary) -> Array:
	var clues: Array = stp.get("clues", [])
	var f: Variant = d.get("f", {})
	var n := 0
	for c: Dictionary in clues:
		if f is Dictionary and (f as Dictionary).has(clue_key(String(c.key))):
			n += 1
	var need := int(stp.get("need", clues.size()))
	return [mini(n, need), need]


## [have, wanted] for a counted verb step ([0, 0] for the others).
static func count(stp: Dictionary, d: Dictionary) -> Array:
	match String(stp.get("kind", "")):
		"clues":
			return clue_count(stp, d)
		"tracks":
			var total := (stp.get("marks", []) as Array).size()
			return [mini(int(d.get("n", 0)), total), total]
	return [0, 0]


## Where a step sends the wanderer to look rather than to go: {} for a step with an exact place, else
## {"c": Vector2 (the centre), "r": radius, "i": which (a trail's next mark)}. A clues step searches round its
## `at`. A trail points at the area of its next mark: the centre is the mark moved a fixed way (the same every
## time: from the task and the mark's number) by under half the radius, so the mark is inside the circle and
## never at its middle.
static func area(id: String, stp: Dictionary, d: Dictionary) -> Dictionary:
	match String(stp.get("kind", "")):
		"clues":
			if stp.get("at") is Vector2:
				return {"c": stp.at as Vector2, "r": float(stp.get("r", AREA_R)), "i": 0}
		"tracks":
			var marks: Array = stp.get("marks", [])
			var i := int(d.get("n", 0))
			if i >= 0 and i < marks.size():
				var r := float(stp.get("r", TRAIL_R))
				var a := float(hash("%s|%d" % [id, i]) % 628) * 0.01
				var at: Vector2 = (marks[i] as Dictionary).at
				return {"c": at + Vector2(cos(a), sin(a)) * r * 0.45, "r": r, "i": i}
	return {}


## The data's integrity for Chains.audit(): [] = fine.
static func audit(id: String, si: int, stp: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var kind := String(stp.get("kind", ""))
	if not is_verb(kind):
		return bad
	var tag := "%s step %d (%s)" % [id, si, kind]
	match kind:
		"clues":
			var clues: Array = stp.get("clues", [])
			var seen := {}
			if clues.is_empty() or not (stp.get("at") is Vector2):
				bad.append("%s: needs clues and an `at` (the search area's centre)" % tag)
			for c: Dictionary in clues:
				var k := String(c.get("key", ""))
				if k == "" or k.contains(":") or k.contains(",") or seen.has(k):
					bad.append("%s: clue key '%s' is empty, repeated or has a : or ," % [tag, k])
				seen[k] = true
				if not (c.get("at") is Vector2) or String(c.get("text", "")) == "":
					bad.append("%s: clue '%s' needs an `at` and its `text`" % [tag, k])
			var need := int(stp.get("need", clues.size()))
			if need < 1 or need > clues.size():
				bad.append("%s: `need` %d of %d clues" % [tag, need, clues.size()])
		"tracks":
			var marks: Array = stp.get("marks", [])
			if marks.is_empty():
				bad.append("%s: no marks" % tag)
			for m: Dictionary in marks:
				if not (m.get("at") is Vector2) or String(m.get("text", "")) == "":
					bad.append("%s: a mark needs an `at` and its `text`" % tag)
		"lantern_walk":
			if not (stp.get("to") is Vector2) or si == 0:
				bad.append("%s: needs a `to` and a step before it (taking the light)" % tag)
		"order":
			var things: Array = stp.get("things", [])
			var keys := {}
			for t: Dictionary in things:
				keys[String(t.get("key", ""))] = true
				if not (t.get("at") is Vector2) or String(t.get("key", "")) == "" or String(t.key).contains(":"):
					bad.append("%s: a thing needs a `key` (no :) and an `at`" % tag)
			var order: Array = stp.get("order", [])
			if things.size() < 2 or order.size() < 2 or not (stp.get("at") is Vector2):
				bad.append("%s: needs `at`, two or more `things`, and an `order` of their keys" % tag)
			for k2: Variant in order:
				if not keys.has(String(k2)):
					bad.append("%s: `order` names '%s', which is no thing" % [tag, k2])
		"vigil":
			if not (stp.get("at") is Vector2) or float(stp.get("time", 0.0)) <= 0.0:
				bad.append("%s: needs `at` and a `time` to keep" % tag)
	return bad
