extends RefCounted
## Rooms the reverb knows about beyond the tavern, the Ossuary and the Rift: any builder that makes a roofed hall, a cave or a crypt
## registers its volume here and the listener standing inside it gets that room's reverb and its outdoor layers muffled
## (Ambience.zone_at asks `at`). Rooms: "hall" (a roofed stone hall: the castellum, a cathedral crossing, a great gate's passage),
## "cave" (a hollow in rock: a barrow, a mine, the Hollow King's throat), "crypt" (a narrow vault). Registered volumes are static
## and cleared with the night (`clear`). No class_name. Load by path: const AcousticZones := preload("res://core/audio/acoustic_zones.gd")
##   AcousticZones.register(aabb, "hall", "tower")   world-space box, its reverb room and (optional) the name of its own bed (interior_beds.gd)
##   AcousticZones.at(p) -> "" | room          AcousticZones.label_at(p) -> "" | the bed's name (the room when none was given)

static var _zones: Array = []


static func register(box: AABB, room: String, label := "") -> void:
	_zones.append([box, room, label if label != "" else room])


static func clear() -> void:
	_zones.clear()


static func at(p: Vector3) -> String:
	for z: Array in _zones:
		if (z[0] as AABB).has_point(p):
			return String(z[1])
	return ""


static func label_at(p: Vector3) -> String:
	for z: Array in _zones:
		if (z[0] as AABB).has_point(p):
			return String(z[2])
	return ""
