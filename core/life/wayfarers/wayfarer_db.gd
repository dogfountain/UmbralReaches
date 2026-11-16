extends RefCounted
## Who walks the Realm's ways at night (wayfarers.gd; docs/living_realm.md). Each party has a kind, a home it keeps
## near (a town or a fire: it roams the safe ways within `roam` metres of it) and its people's looks (villager_rig.gd
## options). One of each party carries the lantern; patrols walk a beat between their two ends.
## Load by path: const WayfarerDB := preload("res://core/life/wayfarers/wayfarer_db.gd")

## What a party is like: speed (m/s), the gap they keep in file, what they do at a lit fire and at a dark one,
## whether they turn back from danger or stand, how long they stay inside a town.
const KINDS := {
	"pilgrims": {"speed": 0.95, "gap": 1.5, "rest": "warm", "dark": "kneel", "stand": false, "away": [70.0, 150.0], "rest_t": [45.0, 90.0]},
	"patrol": {"speed": 1.2, "gap": 1.7, "rest": "watch", "dark": "watch", "stand": true, "away": [30.0, 60.0], "rest_t": [18.0, 32.0]},
	"peddler": {"speed": 1.05, "gap": 1.5, "rest": "warm", "dark": "", "stand": false, "away": [60.0, 120.0], "rest_t": [40.0, 80.0]},
	"family": {"speed": 0.85, "gap": 1.2, "rest": "warm", "dark": "", "stand": false, "away": [80.0, 160.0], "rest_t": [40.0, 70.0]},
	"messenger": {"speed": 1.55, "gap": 1.5, "rest": "warm", "dark": "", "stand": false, "away": [40.0, 90.0], "rest_t": [15.0, 30.0]},
	"fishers": {"speed": 1.0, "gap": 1.6, "rest": "chat", "dark": "", "stand": false, "away": [60.0, 120.0], "rest_t": [40.0, 80.0]},
	"mourners": {"speed": 0.8, "gap": 1.4, "rest": "mourn", "dark": "kneel", "stand": false, "away": [80.0, 140.0], "rest_t": [50.0, 90.0]},
	"burners": {"speed": 1.0, "gap": 1.6, "rest": "warm", "dark": "", "stand": false, "away": [60.0, 120.0], "rest_t": [40.0, 80.0]},
	"penitents": {"speed": 0.75, "gap": 1.3, "rest": "kneel", "dark": "kneel", "stand": false, "away": [80.0, 160.0], "rest_t": [50.0, 100.0]},
}

## Pilgrims' and watchmen's cloth (the roam events' pilgrims and the Watch wear the same).
const ROBE := Color(0.4, 0.37, 0.32)
const ROBE2 := Color(0.3, 0.28, 0.25)
const COAT := Color(0.25, 0.21, 0.2)
const COAT2 := Color(0.2, 0.17, 0.16)

## The parties: kind, home (a town's name in wayfarers.gd TOWNS, or a point), how far they roam, and the people
## (rig options; "lamp": true carries the lantern in the left hand). Seeds 9100+ are the roads' own.
const PARTIES := [
	{"kind": "pilgrims", "home": "Lastlight", "roam": 330.0, "people": [
		{"seed": 9101, "sex": "m", "age": "old", "garment": "robe", "hood": true, "beard": "long", "r": "staff", "lamp": true, "cloth": ROBE, "cloth2": ROBE2},
		{"seed": 9102, "sex": "f", "age": "adult", "garment": "robe", "hood": true, "hair": "long", "r": "staff", "satchel": true, "cloth": Color(0.36, 0.33, 0.3), "cloth2": ROBE2},
		{"seed": 9103, "sex": "m", "age": "teen", "garment": "robe", "hood": false, "hair": "short", "r": "staff", "barefoot": true, "cloth": Color(0.42, 0.38, 0.33), "cloth2": ROBE2}]},
	{"kind": "pilgrims", "home": "Hearthward", "roam": 300.0, "people": [
		{"seed": 9111, "sex": "f", "age": "old", "garment": "robe", "hood": true, "hair": "bun", "r": "staff", "lamp": true, "cloth": Color(0.38, 0.35, 0.33), "cloth2": ROBE2},
		{"seed": 9112, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "beard": "short", "r": "staff", "cloth": ROBE, "cloth2": ROBE2}]},
	{"kind": "patrol", "home": "Lastlight", "roam": 260.0, "people": [
		{"seed": 9121, "sex": "m", "age": "adult", "garment": "coat", "hood": true, "beard": "short", "r": "sword", "lamp": true, "girth": 1.04, "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)},
		{"seed": 9122, "sex": "m", "age": "adult", "garment": "coat", "hat": "cap", "r": "sword", "girth": 1.0, "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)},
		{"seed": 9123, "sex": "f", "age": "adult", "garment": "coat", "hood": true, "hair": "braids", "r": "sword", "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)}]},
	{"kind": "patrol", "home": "Weirford", "roam": 260.0, "people": [
		{"seed": 9131, "sex": "m", "age": "adult", "garment": "coat", "hat": "cap", "beard": "short", "r": "sword", "lamp": true, "girth": 1.06, "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)},
		{"seed": 9132, "sex": "m", "age": "adult", "garment": "coat", "hood": true, "r": "sword", "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)}]},
	{"kind": "peddler", "home": "Saltmarket", "roam": 320.0, "people": [
		{"seed": 9141, "sex": "m", "age": "adult", "garment": "coat", "hat": "brim", "beard": "long", "r": "staff", "lamp": true, "satchel": true, "girth": 1.1, "cloth": Color(0.34, 0.27, 0.2), "cloth2": Color(0.28, 0.24, 0.2)}]},
	{"kind": "family", "home": "Fallowmere", "roam": 260.0, "people": [
		{"seed": 9151, "sex": "f", "age": "adult", "garment": "dress", "apron": "linen", "shawl": true, "hair": "bun", "lamp": true, "cloth": Color(0.32, 0.28, 0.36), "cloth2": Color(0.3, 0.27, 0.24)},
		{"seed": 9152, "sex": "m", "age": "child", "garment": "coat", "hair": "short", "cloth": Color(0.3, 0.32, 0.26), "cloth2": Color(0.28, 0.25, 0.22)}]},
	{"kind": "fishers", "home": "Reedholm", "roam": 260.0, "people": [
		{"seed": 9161, "sex": "m", "age": "adult", "garment": "coat", "hat": "brim", "beard": "short", "r": "pole", "lamp": true, "cloth": Color(0.26, 0.3, 0.28), "cloth2": Color(0.3, 0.27, 0.22)},
		{"seed": 9162, "sex": "f", "age": "adult", "garment": "dress", "apron": "linen", "hair": "braids", "r": "crook", "cloth": Color(0.3, 0.32, 0.3), "cloth2": Color(0.3, 0.27, 0.24)}]},
	{"kind": "messenger", "home": "Weirford", "roam": 420.0, "people": [
		{"seed": 9171, "sex": "f", "age": "teen", "garment": "coat", "hood": true, "hair": "long", "lamp": true, "satchel": true, "cloth": Color(0.24, 0.28, 0.36), "cloth2": Color(0.26, 0.24, 0.22)}]},
	{"kind": "mourners", "home": "Kings' Barrows", "roam": 220.0, "people": [
		{"seed": 9181, "sex": "f", "age": "old", "garment": "robe", "hood": true, "hair": "long", "r": "candle", "lamp": true, "cloth": Color(0.2, 0.2, 0.22), "cloth2": Color(0.18, 0.17, 0.18)},
		{"seed": 9182, "sex": "f", "age": "adult", "garment": "robe", "hood": true, "hair": "bun", "cloth": Color(0.22, 0.21, 0.23), "cloth2": Color(0.18, 0.17, 0.18)}]},
	{"kind": "pilgrims", "home": "the Cairns", "roam": 300.0, "people": [
		{"seed": 9191, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "beard": "long", "r": "staff", "lamp": true, "cloth": Color(0.36, 0.34, 0.31), "cloth2": ROBE2},
		{"seed": 9192, "sex": "m", "age": "old", "garment": "robe", "hood": true, "beard": "long", "r": "staff", "barefoot": true, "cloth": ROBE, "cloth2": ROBE2}]},
	{"kind": "peddler", "home": "Fallowmere", "roam": 340.0, "people": [
		{"seed": 9201, "sex": "f", "age": "old", "garment": "dress", "shawl": true, "hair": "bun", "r": "staff", "lamp": true, "satchel": true, "cloth": Color(0.36, 0.3, 0.26), "cloth2": Color(0.3, 0.27, 0.24)}]},
	{"kind": "patrol", "home": "the Siege Lines", "roam": 240.0, "people": [
		{"seed": 9211, "sex": "m", "age": "adult", "garment": "coat", "hood": true, "beard": "short", "r": "sword", "lamp": true, "girth": 1.02, "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)},
		{"seed": 9212, "sex": "m", "age": "adult", "garment": "coat", "hat": "cap", "r": "sword", "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)}]},
	# --- the Far Reaches' own roads ---
	{"kind": "pilgrims", "home": "Reedholm", "roam": 300.0, "people": [
		{"seed": 9221, "sex": "f", "age": "adult", "garment": "robe", "hood": true, "hair": "braids", "r": "staff", "lamp": true, "cloth": ROBE, "cloth2": ROBE2},
		{"seed": 9222, "sex": "m", "age": "old", "garment": "robe", "hood": true, "beard": "long", "r": "staff", "cloth": Color(0.38, 0.36, 0.32), "cloth2": ROBE2},
		{"seed": 9223, "sex": "f", "age": "teen", "garment": "robe", "hood": false, "hair": "long", "barefoot": true, "cloth": Color(0.42, 0.38, 0.34), "cloth2": ROBE2}]},
	{"kind": "burners", "home": "the Southwood", "roam": 280.0, "people": [
		{"seed": 9231, "sex": "m", "age": "adult", "garment": "coat", "hat": "cap", "beard": "short", "r": "axe", "lamp": true, "girth": 1.1, "cloth": Color(0.22, 0.2, 0.18), "cloth2": Color(0.2, 0.18, 0.16)},
		{"seed": 9232, "sex": "m", "age": "teen", "garment": "coat", "hair": "short", "r": "spade", "cloth": Color(0.24, 0.22, 0.19), "cloth2": Color(0.2, 0.18, 0.16)}]},
	{"kind": "patrol", "home": "Fallowmere", "roam": 260.0, "people": [
		{"seed": 9241, "sex": "m", "age": "adult", "garment": "coat", "hood": true, "beard": "short", "r": "sword", "lamp": true, "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)},
		{"seed": 9242, "sex": "f", "age": "adult", "garment": "coat", "hat": "cap", "hair": "bun", "r": "sword", "cloth": COAT, "cloth2": COAT2, "leather": Color(0.3, 0.2, 0.12)}]},
	{"kind": "pilgrims", "home": "Saltmarket", "roam": 360.0, "people": [
		{"seed": 9251, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "beard": "short", "r": "staff", "lamp": true, "satchel": true, "cloth": Color(0.4, 0.38, 0.34), "cloth2": ROBE2},
		{"seed": 9252, "sex": "f", "age": "old", "garment": "robe", "hood": true, "hair": "bun", "r": "staff", "cloth": ROBE, "cloth2": ROBE2}]},
	{"kind": "peddler", "home": "Lastlight", "roam": 320.0, "people": [
		{"seed": 9261, "sex": "m", "age": "old", "garment": "coat", "hat": "brim", "beard": "long", "r": "staff", "lamp": true, "satchel": true, "cloth": Color(0.3, 0.26, 0.22), "cloth2": Color(0.26, 0.23, 0.2)}]},
	{"kind": "mourners", "home": "the Long Arches", "roam": 240.0, "people": [
		{"seed": 9271, "sex": "m", "age": "old", "garment": "robe", "hood": true, "beard": "long", "r": "candle", "lamp": true, "cloth": Color(0.2, 0.2, 0.21), "cloth2": Color(0.18, 0.17, 0.18)},
		{"seed": 9272, "sex": "f", "age": "adult", "garment": "robe", "hood": true, "hair": "long", "cloth": Color(0.22, 0.21, 0.22), "cloth2": Color(0.18, 0.17, 0.18)}]},
	{"kind": "messenger", "home": "Hearthward", "roam": 420.0, "people": [
		{"seed": 9281, "sex": "m", "age": "teen", "garment": "coat", "hood": true, "hair": "short", "lamp": true, "satchel": true, "cloth": Color(0.3, 0.24, 0.2), "cloth2": Color(0.26, 0.24, 0.22)}]},
	{"kind": "family", "home": "Weirford", "roam": 240.0, "people": [
		{"seed": 9291, "sex": "m", "age": "adult", "garment": "coat", "hat": "brim", "beard": "short", "r": "staff", "lamp": true, "cloth": Color(0.3, 0.3, 0.26), "cloth2": Color(0.28, 0.25, 0.22)},
		{"seed": 9292, "sex": "f", "age": "child", "garment": "dress", "hair": "braids", "cloth": Color(0.36, 0.28, 0.3), "cloth2": Color(0.3, 0.27, 0.24)}]},
	{"kind": "penitents", "home": "the Greyfell", "roam": 260.0, "people": [
		{"seed": 9301, "sex": "m", "age": "adult", "garment": "robe", "hood": true, "beard": "long", "r": "candle", "lamp": true, "barefoot": true, "cloth": Color(0.3, 0.28, 0.26), "cloth2": Color(0.24, 0.22, 0.2)},
		{"seed": 9302, "sex": "m", "age": "old", "garment": "robe", "hood": true, "beard": "long", "r": "staff", "barefoot": true, "cloth": Color(0.32, 0.3, 0.27), "cloth2": Color(0.24, 0.22, 0.2)},
		{"seed": 9303, "sex": "f", "age": "adult", "garment": "robe", "hood": true, "hair": "long", "barefoot": true, "cloth": Color(0.3, 0.28, 0.26), "cloth2": Color(0.24, 0.22, 0.2)}]},
]


## A person's look as the villager rig takes it ("lamp" becomes the lantern in the left hand).
static func rig_look(look: Dictionary) -> Dictionary:
	var rig: Dictionary = look.duplicate()
	if bool(rig.get("lamp", false)):
		rig["l"] = "lantern"
	rig.erase("lamp")
	return rig


## Every wayfarer's look (the village warms them on worker threads with its own: village.gd warm_start()).
static func rig_looks() -> Array:
	var out: Array = []
	for p: Dictionary in PARTIES:
		for look: Dictionary in p.people:
			out.append(rig_look(look))
	return out
