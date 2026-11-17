extends RefCounted
## Rooms the reverb knows about beyond the tavern, the Ossuary and the Rift: any builder that makes a roofed hall, a cave or a crypt
## registers its volume here and the listener standing inside it gets that room's reverb and its outdoor layers muffled
## (Ambience.zone_at asks `at`). Rooms: "hall" (a roofed stone hall: the castellum, a cathedral crossing, a great gate's passage),
## "cave" (a hollow in rock: a barrow, a mine, the Hollow King's throat), "crypt" (a narrow vault). Registered volumes are static
## and cleared with the night (`clear`). No class_name. Load by path: const AcousticZones := preload("res://core/audio/acoustic_zones.gd")
##   AcousticZones.register(aabb, "hall")     world-space box
##   AcousticZones.at(p) -> "" | room

static var _zones: Array = []


static func register(box: AABB, room: String) -> void:
	_zones.append([box, room])


static func clear() -> void:
	_zones.clear()


static func at(p: Vector3) -> String:
	for z: Array in _zones:
		if (z[0] as AABB).has_point(p):
			return String(z[1])
	return ""
