extends RefCounted
## Every readable text of the Realm in one place: lore_db.gd (the r22 corpus) merged with
## lore_more.gd (r28). Inscriptions, the Journal and the lore builders read through this, so new
## writings never need the lead's file. No class_name:
##   const LoreIndex := preload("res://core/world/realm/lore/lore_index.gd")

const LoreDB := preload("res://core/world/realm/lore_db.gd")
const LoreMore := preload("res://core/world/realm/lore/lore_more.gd")
const Wayside := preload("res://core/world/realm/lore/wayside_texts.gd")     ## the wayside's writings (realm_wayside.gd)

static var _texts: Dictionary = {}
static var _series: Dictionary = {}


static func texts() -> Dictionary:
	if _texts.is_empty():
		_texts = LoreDB.TEXTS.duplicate()
		_texts.merge(LoreMore.TEXTS)
		_texts.merge(Wayside.TEXTS)
	return _texts


static func series() -> Dictionary:
	if _series.is_empty():
		_series = LoreDB.SERIES.duplicate()
		_series.merge(LoreMore.SERIES)
	return _series


static func entry(id: String) -> Dictionary:
	return texts().get(id, {})


static func ids_in(region: String) -> Array[String]:
	var out: Array[String] = []
	var t := texts()
	for id: String in t:
		if String(t[id].region) == region:
			out.append(id)
	return out


static func series_ids(s: String) -> Array[String]:
	var out: Array[String] = []
	var t := texts()
	for id: String in t:
		if String(t[id].get("series", "")) == s:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return int(t[a].part) < int(t[b].part))
	return out


## The series `id` belongs to and whether all its parts are now read (CodexStore), or "".
static func completed_series(id: String, has_read: Callable) -> String:
	var s := String(entry(id).get("series", ""))
	if s == "":
		return ""
	for part in series_ids(s):
		if not bool(has_read.call(part)):
			return ""
	return s


static func kind_name(kind: String) -> String:
	return LoreDB.kind_name(kind)


static func place_name(region: String) -> String:
	return LoreDB.place_name(region)
