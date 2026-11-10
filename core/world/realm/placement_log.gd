extends RefCounted
## Every placement the Realm build could not make, in one place. A builder that skips a thing calls
## skip() next to its own print; zz/placement_test compares keys() with tools/placement_baseline.txt so a
## new skip fails a test instead of scrolling past in the log.

static var entries: Array[Dictionary] = []


static func skip(system: String, id: String, at: Vector3, why: String) -> void:
	entries.append({"system": system, "id": id, "at": at, "why": why})
	print("PLACEMENT skip %s %s at (%.1f, %.1f) (%s)" % [system, id, at.x, at.z, why])


static func reset() -> void:
	entries.clear()


## Sorted unique "<system>/<id>" strings.
static func keys() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in entries:
		var k := "%s/%s" % [e.system, e.id]
		if not out.has(k):
			out.append(k)
	out.sort()
	return out
