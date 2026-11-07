extends RefCounted
## r36 horses (docs/critique/r36_plan.md, step 5): a breed for each place that keeps them, bought
## with grave ash at its hitching post, then ridden anywhere and called with H. Load by path.
##   state: Travel.system_state("stable") = {owned: [breed ids], ride: breed id ("" none)}

## breed -> {name, model (the skinned glb: art/models/horse_<breed>.glb, textures art/textures/horse_<breed>_*.png), walk, trot, gallop (m/s), turn (rad/s), climb (m a step it
## takes), heft (how heavy it moves: >1 slower cadence, deeper nod, lazier tail and mane; <1 quick and light), jump (the leap's height over a plain horse's), cost (ash), where (the post's place), at (xz), face (xz), line (the post's word)}
const BREEDS := {
	"palfrey": {"heft": 1.0, "name": "Pilgrim's Palfrey", "model": "res://art/models/horse_palfrey.glb", "jump": 1.0, "size": 1.0, "seat": 1.502, "stirrup_y": 0.962, "stirrup_x": 0.288, "bw": 0.244, "bc": 1.134, "bl": 0.3, "walk": 2.6, "trot": 6.5, "gallop": 11.0, "turn": 2.6, "climb": 0.75,
		"cost": 40, "where": "Hearthward's stable-yard", "at": Vector2(22.0, 46.0), "face": Vector2(-1.0, 0.0),
		"line": "A bay palfrey, the last of the pilgrims' string. Fennick fed it all winter on the promise somebody would ride it out again."},
	"garron": {"heft": 1.1, "name": "Moor Garron", "model": "res://art/models/horse_garron.glb", "jump": 1.1, "size": 0.935, "seat": 1.405, "stirrup_y": 0.9, "stirrup_x": 0.329, "bw": 0.278, "bc": 1.061, "bl": 0.291, "walk": 2.4, "trot": 6.0, "gallop": 9.5, "turn": 2.9, "climb": 1.05,
		"cost": 60, "where": "Ysolt's fire under the tor", "at": Vector2(128.0, -6.0), "face": Vector2(-1.0, 0.0),
		"line": "A grey hill pony with feathered feet, sure on stone and heather. Ysolt says it knows the cairns better than she does."},
	"draught": {"heft": 1.6, "name": "Pit Draught", "model": "res://art/models/horse_draught.glb", "jump": 0.85, "size": 1.14, "seat": 1.713, "stirrup_y": 1.097, "stirrup_x": 0.391, "bw": 0.331, "bc": 1.293, "bl": 0.33, "walk": 2.2, "trot": 5.5, "gallop": 9.0, "turn": 1.9, "climb": 0.9,
		"cost": 80, "where": "the Founder's Pits", "at": Vector2(112.0, -66.0), "face": Vector2(-0.6, 0.8),
		"line": "A black draught horse that hauled bell-metal out of the pits. Nothing hollowed stands in its way twice.", "trample": true},
	"fenpony": {"heft": 0.75, "name": "Fen Pony", "model": "res://art/models/horse_fenpony.glb", "jump": 0.95, "size": 0.865, "seat": 1.299, "stirrup_y": 0.832, "stirrup_x": 0.316, "bw": 0.267, "bc": 0.981, "bl": 0.27, "walk": 2.4, "trot": 6.2, "gallop": 10.0, "turn": 3.1, "climb": 0.8,
		"cost": 50, "where": "Cadoc's bank on the mere", "at": Vector2(104.0, 90.0), "face": Vector2(-0.7, -0.7),
		"line": "A shaggy dun pony that wades where a big horse sinks. Cadoc rows nobody now, but he kept the pony.", "wade": true},
	# --- west marches: the Weir Cob, kept at Weirford's stables (the garron's frame, a mill-horse's temper)
	"weir_cob": {"heft": 1.25, "name": "Weir Cob", "model": "res://art/models/horse_garron.glb", "size": 0.97, "seat": 1.405, "stirrup_y": 0.9, "stirrup_x": 0.329, "bw": 0.278, "bc": 1.061, "bl": 0.291, "walk": 2.5, "trot": 6.3, "gallop": 10.2, "turn": 2.7, "climb": 0.9,
		"cost": 55, "where": "Weirford's stables", "at": Vector2(-189.0, 92.0), "face": Vector2(-1.0, 0.0),
		"line": "A broad dun cob that walked the mill-wheel's sweep for nine winters and has opinions about hills. It crosses the Sorrow's fords like a lane.", "wade": true},
}
const ORDER := ["palfrey", "garron", "fenpony", "draught",
	"weir_cob"]       # --- west marches ---
