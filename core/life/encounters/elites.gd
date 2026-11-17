extends RefCounted
## Encounters: the named elite hollowed. Each has a haunt (candidate points; the first on clear,
## open ground wins), a base kind it is built on (its script extends that kind by preload), a trait
## (always telegraphed), a bounty note nailed up for the wanderer to read, and a bounty paid once:
## grave ash plus a trophy. Five walk the first night; the Faceless Penitent only comes in the
## Deeper Night, when every elite returns in an Umbral form (cold glow, more health, new title).
##
## Trophy item ids are proposed for the progression system to add to ItemDB (LOOT below has the
## name and texts). Until ItemDB knows an id, the bounty pays ash and the trophy is kept in the
## encounters state (shown on the bounty board), never lost.

const Variants := preload("res://core/life/encounters/variants.gd")
const SELF_PATH := "res://core/life/encounters/elites.gd"
# --- south marches ---
const SouthParts := preload("res://core/life/encounters/elite_south_marches.gd")

## r29: health x1.5 (zz/critA_probe: held Rift Bolt killed the old 8-20 hp in 2-4 s).
const ELITES := {
	"hobb": {
		"title": "Hobb, Who Knocks Thrice", "kind": "wretch", "script": "res://core/life/encounters/elite_hobb.gd",
		"haunt": [Vector2(48, 73), Vector2(56, 74), Vector2(44, 70)], "region": "road",
		"hp": 21, "ash": 20, "scale": 1.28, "glow": Color(1.8, 0.7, 0.2), "loot": "hobbs_knuckles",
		"where": "the Pilgrims' Road, east of Hearthward",
		"note": "BOUNTY. A tall one walks the east road at night in a pilgrim's hood, and knocks. Three slow knocks, door to door, as Maud's boy used to. Do not open. Do not answer. Whoever puts it down: ash at the Keg, and Maud need never know whose hands they were. -- the keep",
		"trait": "Knocks thrice: a three-blow chain, each blow with its own tell.",
	},
	"lisle": {
		"title": "Brother Lisle, the Counted", "kind": "ossuant", "script": "res://core/life/encounters/elite_lisle.gd",
		"haunt": [Vector2(70, -62), Vector2(66, -48), Vector2(74, -56)], "region": "barrows",
		"hp": 18, "ash": 24, "scale": 1.22, "glow": Color(1.2, 0.55, 2.6), "loot": "lisles_tally",
		"where": "the fen descent, by the Tally posts",
		"note": "He went down to count once more and was added to it. Now he counts the living on the fen path, boards of tallies strapped to his ribs. Cut the boards. Break the count. He rose twice for my brother; mark him before he falls or he will rise again. -- a lay brother's hand, unfinished",
		"trait": "Calls the count at half strength: two crawlers answer. Rises from the heap unless marked.",
	},
	"briar_hart": {
		"title": "The Briar Hart", "kind": "leaper", "script": "res://core/life/encounters/elite_briar_hart.gd",
		"haunt": [Vector2(-98, -46), Vector2(-94, -38), Vector2(-100, -54)], "region": "thornwood",
		"hp": 21, "ash": 22, "scale": 1.3, "glow": Color(2.4, 0.5, 0.15), "loot": "briar_antler",
		"where": "deep in the Thornwood, under the Crowns",
		"note": "DO NOT CUT THE THORN. We cut it. Now there is a hart in the deep wood with a crown of briar, and where it lands the ground bleeds thorns. Step off where it comes down. Two of ours did not. -- the woodsmen's camp",
		"trait": "Pounces far; where it lands, a ring of thorns erupts a moment later.",
	},
	"old_sunk": {
		"title": "Old Sunk, Three Stones", "kind": "husk", "script": "res://core/life/encounters/elite_old_sunk.gd",
		"haunt": [Vector2(86, 26), Vector2(94, 22), Vector2(80, 30)], "region": "fen",
		"hp": 30, "ash": 26, "scale": 1.32, "glow": Color(0.35, 1.6, 1.1), "loot": "heart_stone",
		"where": "the Hollow Fen, south pools",
		"note": "We sank him under three stones, eyes, mouth and heart, as the Abbot said. He walked out wearing them. When he raises his arms the water rings round him: get out of the ring. Bring back the heart-stone and Corvin's lamp will burn for you. -- chalked on a drowned marker",
		"trait": "Raises the fen: a wide ring fills under him, then slams.",
	},
	"cinder_cantor": {
		"title": "The Cinder Cantor", "kind": "spitter", "script": "res://core/life/encounters/elite_cinder_cantor.gd",
		"haunt": [Vector2(-37.8, -65.0) + Endgame.O2, Vector2(-37.4, -68.5) + Endgame.O2, Vector2(-38.6, -61.0) + Endgame.O2, Vector2(-33.0, -52.0) + Endgame.O2], "region": "rift",
		"hp": 12, "ash": 20, "scale": 1.24, "glow": Color(2.4, 0.8, 0.2), "loot": "cinder_censer",
		"where": "the Choir House under the Ashen Rift's west berm, beyond Lastlight, in the lava's nave",
		"note": "The choir on the Stair sang to the last bell. One of them is still singing, in the burned hall below the west berm where the lava came in, swinging a censer full of the Rift. It spits three coals at once, wide. Close in. Do not stand at singing distance. -- scratched under the Last Bell",
		"trait": "Spits a fan of three coals; keeps its distance.",
	},
	"penitent": {
		"title": "The Faceless Penitent", "kind": "wretch", "script": "res://core/life/encounters/elite_penitent.gd",
		"haunt": [Vector2(-94, 40), Vector2(-90, 32), Vector2(-96, 46)], "region": "chapel",
		"hp": 24, "ash": 30, "scale": 1.3, "glow": Color(0.9, 0.9, 1.4), "loot": "scraped_face", "ng_only": true,
		"where": "the Kindlers' yard, west of the chapel (the Deeper Night only)",
		"note": "No face should turn from the sky. He scraped the saints and then himself. In the deeper dark he steps through it: a tear opens where he will be. Watch for the tear. -- Brother Ansel's last chisel-note",
		"trait": "Steps through the dark: a tear opens beside you, then he is there.",
	},
	# --- south marches ---
	"root_wife": {
		"title": "The Root-Wife", "kind": "husk", "script": "res://core/life/encounters/elite_root_wife.gd",
		"haunt": [Vector2(-82.0, 203.0), Vector2(-80.0, 211.0), Vector2(-84.0, 198.0), Vector2(-76.0, 216.0)], "region": "oak",
		"hp": 32, "ash": 28, "scale": 1.38, "glow": Color(0.5, 1.5, 0.4), "loot": "oak_heartwood",
		"where": "the roots of the Grandmother Oak, on the southern downs",
		"note": "She keeps the oak. The Rooted sang to it every spring and it sang back; now it sings through her. When she stops and the ground goes soft, three roots are coming up: one where you stand and one at each hand. Walk through the line, do not run along it. Two grubs follow her up when she is hurt. -- scratched in the hollow, in the Rooted's hand",
		"trait": "Three root-snares fill at once, one under you and one at each side. Calls two grubs at half health.",
	},
	"well_answer": {
		"title": "The Answerer", "kind": "spitter", "script": "res://core/life/encounters/elite_answerer.gd",
		"haunt": [Vector2(64.5, 208.0), Vector2(63.0, 207.0), Vector2(66.0, 209.5), Vector2(62.0, 210.0)], "region": "well",
		"hp": 16, "ash": 26, "scale": 1.3, "glow": Color(0.55, 1.1, 1.8), "loot": "echo_bell",
		"where": "the landing at the foot of the Well of Echoes' ledge, by the cave",
		"note": "Whoever drops a stone down the Well is answered. Something at the bottom has been answering for nine winters, and has learned to throw back what it hears. Where you stood when it spat, the ground rings again two breaths later. Do not stand and dodge: keep walking, and close with it. -- cut in the lintel of the Descent",
		"trait": "Spits; the ground where you stood rings again two seconds later. Calls two drowned at half health.",
	},
	# --- west marches ---
	"siege_captain": {
		"title": "Captain Varr, the Wall-Breaker", "kind": "husk", "script": "res://core/life/encounters/elite_siege_captain.gd",
		"haunt": [Vector2(-212, 128), Vector2(-196, 128), Vector2(-188, 134), Vector2(-218, 134)], "region": "siege",
		"hp": 34, "ash": 32, "scale": 1.4, "glow": Color(2.2, 1.4, 0.4), "loot": "varrs_signet",
		"where": "the Siege Lines, between the palisade gate and the giant's mouth",
		"note": "THE MARCHES' WAR-BAND NEVER STOOD DOWN. The captain is still giving the order to go in. He brings the hammer down in front of him, flat and wide, and calls two of his own out of the earthwork when he is alone. Do not stand in the ring. Do not let him be alone. -- scratched on the Weirford watch's tally board",
		"trait": "Siege Hammer: a wide disc fills, then slams. Hold the Line: calls two conscripts.",
	},
	# --- the east marches ---
	"brine_wife": {
		"title": "The Brine-Wife, Bitter Mother", "kind": "husk", "script": "res://core/life/encounters/elite_brine_wife.gd",
		"haunt": [Vector2(232, 172), Vector2(228, 196), Vector2(240, 160), Vector2(222, 204)], "region": "saltpans",
		"hp": 34, "ash": 30, "scale": 1.36, "glow": Color(1.5, 1.7, 2.0), "loot": "brine_censer",
		"where": "the White Pans, among the evaporation pans",
		"note": "BOUNTY. She boiled the pans down for thirty years and has not stopped. Where she stands the brine comes up through the white: a wide ring that fills, then bursts. Past half her strength she grows crystals out of the crust round you. Do not stand in the white. Stand on the timber. -- Marl Pannick, reeve of Saltmarket",
		"trait": "Brine Burst: a wide ring fills, then slams. Past half health, crystals break the crust around you.",
	},
}

## Proposed ItemDB entries for the progression system (kind "trophy": unique, kept in the satchel).
const LOOT := {
	"hobbs_knuckles": {"name": "Hobb's Iron Knuckles", "shape": "fist", "tint": Color(0.55, 0.5, 0.48),
		"desc": "Iron rings a pilgrim wore to knock on doors along the road, begging. They are worn bright on one side.",
		"text": "Bounty of Hobb, Who Knocks Thrice. Maud's son came down."},
	"lisles_tally": {"name": "Lisle's Tally Board", "shape": "tablet", "tint": Color(0.7, 0.6, 0.45),
		"desc": "A lay brother's board of fives, scored through. The last group is three, then a fourth stroke begun and never finished.",
		"text": "Bounty of Brother Lisle, the Counted. The count stops here."},
	"briar_antler": {"name": "Briar Antler", "shape": "branch", "tint": Color(0.45, 0.22, 0.16),
		"desc": "A tine of the hart's thorn crown. It is still trying to root in your hand.",
		"text": "Bounty of the Briar Hart, from the deep Thornwood."},
	"heart_stone": {"name": "The Heart-Stone", "shape": "stone", "tint": Color(0.4, 0.55, 0.5),
		"desc": "One of the three stones the fen dead are sunk under: the heart's. Rope-worn, and warm on one face.",
		"text": "Bounty of Old Sunk, Three Stones. Corvin's rite would have lit this instead."},
	"cinder_censer": {"name": "Cinder Censer", "shape": "lantern", "tint": Color(0.9, 0.45, 0.2),
		"desc": "A choir censer packed with Rift coal. It never goes out and it never warms anyone.",
		"text": "Bounty of the Cinder Cantor, last voice of the Stair's choir."},
	"scraped_face": {"name": "The Scraped Face", "shape": "mask", "tint": Color(0.85, 0.82, 0.8),
		"desc": "A penitent's face-plate, chiselled blank. On the inside, someone carved a small fire.",
		"text": "Bounty of the Faceless Penitent (the Deeper Night)."},
	# --- south marches ---
	"oak_heartwood": {"name": "Heartwood of the Grandmother Oak", "shape": "branch", "tint": Color(0.5, 0.36, 0.22),
		"desc": "A split of the oak's dead heart, still warm on one face. The Rooted say their first fire was carried out of this tree; the grain remembers it.",
		"text": "Bounty of the Root-Wife, from the roots of the Grandmother Oak."},
	"echo_bell": {"name": "The Echo Bell", "shape": "lantern", "tint": Color(0.5, 0.42, 0.26),
		"desc": "A small struck-bronze bell from the Answerer's halos. It rings once when you lift it, and again, softer, from somewhere below you.",
		"text": "Bounty of the Answerer, from the landing of the Well of Echoes."},
	# --- west marches ---
	"varrs_signet": {"name": "Varr's Signet", "shape": "ring", "tint": Color(0.7, 0.58, 0.32),
		"desc": "A captain's signet, the Marches' wall-and-tower stamped in it, worn flat on one side from being pressed into wax for orders nobody took.",
		"text": "Bounty of Captain Varr, the Wall-Breaker. The order to go in is rescinded."},
	# --- the east marches ---
	"brine_censer": {"name": "The Brine-Wife's Censer", "shape": "lantern", "tint": Color(0.82, 0.88, 0.92),
		"desc": "An iron pan-ladle with a handle worn to a groove. Everything it ever held has crystallised on it, in layers, like a tree's rings.",
		"text": "Bounty of the Brine-Wife, Bitter Mother. The pans give back what they were given."},
}

## Umbral forms in the Deeper Night (NG+): every elite returns colder and harder.
const UMBRAL_GLOW := Color(0.55, 1.2, 2.9)
const UMBRAL_HP := 1.6

static var _parts := {}
static var _mats := {}


static func ids(ng: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in ELITES:
		if bool(ELITES[id].get("ng_only", false)) and ng <= 0:
			continue
		out.append(id)
	return out


static func title(id: String, umbral: bool) -> String:
	var t := String(ELITES.get(id, {}).get("title", id))
	return ("Umbral " + t.trim_prefix("The ")) if umbral else t


## Dress an elite: its own pieces on the rig, its material (kind flesh, own glow), a title over it.
static func dress(e: Enemy, id: String) -> void:
	var d: Dictionary = ELITES.get(id, {})
	if d.is_empty() or e._rig == null:
		return
	var umbral := e.has_meta(&"enc_umbral")
	var kind := String(d.kind)
	var mat := material(id, kind, umbral)
	var flesh: Array[MeshInstance3D] = []
	for mi in e._flesh:
		if is_instance_valid(mi):
			mi.material_override = mat
			flesh.append(mi)
	var parts := parts_for(id, e._rig)
	for sock: String in parts:
		var at := e._rig.socket(sock)
		if at == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Elite_" + sock
		mi.mesh = parts[sock]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sock == "chest" or sock == "body" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(mi)
		flesh.append(mi)
	e.set_flesh(flesh)
	var s: float = float(d.get("scale", 1.25))
	e._rig.scale *= s
	e.hp_bar_y *= s
	var col := e.get_node_or_null("Collision") as CollisionShape3D
	if col and col.shape is CapsuleShape3D:
		var cap := (col.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		cap.radius = minf(cap.radius * s, 0.55)
		cap.height = cap.height * s
		col.shape = cap
		col.position.y = cap.height * 0.5
	var lbl := Label3D.new()
	lbl.name = "EliteTitle"
	lbl.text = title(id, umbral)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.fixed_size = false
	lbl.pixel_size = 0.0042
	lbl.font_size = 44
	lbl.outline_size = 10
	lbl.modulate = Color(0.75, 0.9, 1.0) if umbral else Color(1.0, 0.82, 0.6)
	lbl.outline_modulate = Color(0.03, 0.02, 0.05, 0.85)
	lbl.position = Vector3(0, e.hp_bar_y + 0.42, 0)
	lbl.visibility_range_end = 26.0
	lbl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.add_child(lbl)


static func material(id: String, kind: String, umbral: bool) -> ShaderMaterial:
	var key := id + ("/u" if umbral else "")
	if _mats.has(key):
		return _mats[key]
	var d: Dictionary = ELITES.get(id, {})
	var m := EnemyBody.material(StringName(kind)).duplicate() as ShaderMaterial
	m.set_shader_parameter("eye_col", UMBRAL_GLOW if umbral else d.get("glow", Color(1.6, 0.6, 0.2)))
	m.set_shader_parameter("rim_col", Color(0.35, 0.6, 1.1) if umbral else Color(0.7, 0.35, 0.6))
	m.set_shader_parameter("rim_amount", 0.75)
	if umbral:
		var skin: Color = m.get_shader_parameter("skin")
		m.set_shader_parameter("skin", skin.lerp(Color(0.62, 0.68, 0.78), 0.35))
	_mats[key] = m
	return m


static func parts_for(id: String, rig: CharacterRig) -> Dictionary:
	if _parts.has(id):
		return _parts[id]
	var shape := "h"
	if rig is QuadRig:
		shape = "q%.2f" % (rig as QuadRig).body_len
	var parts := Variants.cached("enc_elite_%s_%s" % [id, shape], func() -> Dictionary: return _build(id, rig), SELF_PATH)
	_parts[id] = parts
	return parts


# --- the pieces -------------------------------------------------------------------------------

const RAG := Color(0.62, 0.55, 0.5)
const WOOD := Color(0.5, 0.36, 0.24)
const IRON := Color(0.3, 0.29, 0.32)
const STONE := Color(0.42, 0.44, 0.42)
const BONE := Color(0.95, 0.92, 0.84)


static func _build(id: String, rig: CharacterRig) -> Dictionary:
	var parts := {}
	var sd := hash(id) % 991
	match id:
		"hobb":
			# a pilgrim's hood and shoulder cape, a hand-bell on a cord, iron-ringed knuckles
			var h: CreatureMesh = Variants.cm(sd)
			h.blob(Vector3(0, 0.04, 0.02), Vector3(0.15, 0.15, 0.16), Basis.IDENTITY, RAG, 0.0, 0.18, 0.0, 7, 12, 1.0)
			h.tube(PackedVector3Array([Vector3(0, 0.14, 0.06), Vector3(0, 0.12, 0.17), Vector3(0, 0.0, 0.22), Vector3(0, -0.12, 0.2)]),
				PackedFloat32Array([0.06, 0.05, 0.035, 0.0]), 6, RAG, 0.0, 0.15, 0.0, Vector2(1.0, 0.5), 1.0)
			for k in 3:      # three nails through the hood
				var a := -0.5 + 0.5 * float(k)
				h.claw(Vector3(sin(a) * 0.13, 0.12, -cos(a) * 0.08), Vector3(sin(a) * 0.3, 1.0, -0.4).normalized(), 0.07, 0.009, Vector3.ZERO, IRON)
			parts["head"] = h.commit()
			var c: CreatureMesh = Variants.cm(sd + 1)
			for k in 14:
				var ang := TAU * float(k) / 14.0
				var o := Vector3(cos(ang) * 0.2, 0.2, sin(ang) * 0.15 + 0.02)
				c.strand(o, Vector3(cos(ang) * 0.35, -1.0, sin(ang) * 0.3).normalized(), 0.34 + 0.08 * float(k % 3), 0.06, 0.03, RAG, 1.0, 0.25, 5)
			c.tube(PackedVector3Array([Vector3(-0.1, 0.2, -0.1), Vector3(0, -0.02, -0.16), Vector3(0.1, 0.2, -0.1)]), PackedFloat32Array([0.006, 0.006, 0.006]), 4, WOOD, 1.0, 0.0)
			c.blob(Vector3(0, -0.07, -0.17), Vector3(0.045, 0.06, 0.045), Basis.IDENTITY, Color(0.6, 0.48, 0.3), 1.0, 0.04, 0.0, 6, 9)
			c.blob(Vector3(0, -0.13, -0.17), Vector3(0.014, 0.014, 0.014), Basis.IDENTITY, Color(0.6, 0.4, 0.2), 1.0, 0.0, 0.7, 4, 6)
			parts["chest"] = c.commit()
			for side: String in ["l", "r"]:
				var a: CreatureMesh = Variants.cm(sd + (2 if side == "l" else 3))
				for k in 3:
					Variants._ring(a, Vector3(0, -0.02 - 0.025 * float(k), -0.01), 0.05, 0.011, IRON, 0.35 if k == 1 else 0.0, 1.0)
				parts["hand_" + side] = a.commit()
		"lisle":
			# tally boards strapped to the ribs (glowing strokes in fives), a cowl, a ledger chain
			var c: CreatureMesh = Variants.cm(sd)
			var f := Variants.chest_front("ossuant") + 0.05
			for b in 2:
				var x0 := -0.11 + 0.15 * float(b)
				c.plate(Vector3(x0 + 0.04, -0.02, -f), Vector3(0.07, 0.11, 0.012), Vector3(0, 0.1, -1.0), WOOD, 1.0, 0.04)
				for g in 2:
					var gy := 0.04 - 0.1 * float(g)
					for k in 4:
						var x := x0 + 0.012 + 0.017 * float(k)
						c.tube(PackedVector3Array([Vector3(x, gy + 0.03, -f - 0.014), Vector3(x, gy - 0.03, -f - 0.014)]), PackedFloat32Array([0.0035, 0.0035]), 3, Color(0.2, 0.1, 0.25), 0.0, 0.0, 0.8)
					if not (b == 1 and g == 1):
						c.tube(PackedVector3Array([Vector3(x0 + 0.004, gy - 0.03, -f - 0.016), Vector3(x0 + 0.072, gy + 0.03, -f - 0.016)]), PackedFloat32Array([0.0035, 0.0035]), 3, Color(0.2, 0.1, 0.25), 0.0, 0.0, 0.8)
			c.tube(PackedVector3Array([Vector3(-0.26, 0.1, 0.0), Vector3(-0.1, 0.06, -f - 0.01), Vector3(0.1, 0.06, -f - 0.01), Vector3(0.26, 0.1, 0.0)]),
				PackedFloat32Array([0.014, 0.014, 0.014, 0.014]), 4, Color(0.28, 0.18, 0.12), 0.0, 0.05, 0.0, Vector2(0.35, 1.0), 0.6)
			for k in 10:
				var t := float(k) / 9.0
				c.blob(Vector3(0.18 + 0.02 * sin(t * 6.0), -0.05 - t * 0.38, -0.12 + 0.03 * t), Vector3(0.012, 0.016, 0.006), Basis(Vector3.UP, float(k % 2) * 1.57), IRON, 1.0, 0.0, 0.0, 3, 6)
			c.plate(Vector3(0.18, -0.46, -0.1), Vector3(0.06, 0.08, 0.02), Vector3(0, 0, -1), WOOD, 1.0, 0.05)
			parts["chest"] = c.commit()
			var h: CreatureMesh = Variants.cm(sd + 1)
			h.blob(Vector3(0, 0.05, 0.03), Vector3(0.16, 0.16, 0.17), Basis.IDENTITY, Color(0.32, 0.26, 0.24), 0.0, 0.2, 0.0, 7, 12, 1.0)
			h.tube(PackedVector3Array([Vector3(0, 0.15, 0.08), Vector3(0, 0.08, 0.2), Vector3(0, -0.06, 0.22)]), PackedFloat32Array([0.07, 0.05, 0.0]), 6, Color(0.32, 0.26, 0.24), 0.0, 0.15, 0.0, Vector2(1.0, 0.5), 1.0)
			parts["head"] = h.commit()
		"briar_hart":
			# a crown of branching thorn antlers, bramble wrapped round the body, ember along the spine
			var q := rig as QuadRig
			var L := q.body_len if q else 1.15
			var h: CreatureMesh = Variants.cm(sd)
			for side: float in [-1.0, 1.0]:
				var base := Vector3(side * 0.05, 0.08, 0.0)
				var tip := base + Vector3(side * 0.3, 0.55, 0.2)
				h.tube(PackedVector3Array([base, base.lerp(tip, 0.4) + Vector3(side * 0.05, 0, 0), tip]), PackedFloat32Array([0.03, 0.022, 0.0]), 6, Color(0.42, 0.26, 0.18), 1.0, 0.08)
				for k in 5:
					var t := 0.25 + 0.15 * float(k)
					var p := base.lerp(tip, t)
					h.claw(p, Vector3(side * (0.4 + 0.25 * float(k % 2)), 0.8, -0.35 + 0.22 * float(k)).normalized(), 0.17 - 0.02 * float(k), 0.014, Vector3(0, 0.06, 0), Color(0.42, 0.26, 0.18))
					h.blob(p + Vector3(0, 0.01, 0), Vector3(0.012, 0.012, 0.012), Basis.IDENTITY, Color(0.5, 0.1, 0.05), 0.0, 0.0, 0.7, 3, 5)
			parts["head"] = h.commit()
			var b: CreatureMesh = Variants.cm(sd + 1)
			for k in 3:
				b.wrap(Vector3(0.0, 0.0, L * (0.32 - 0.05 * float(k))), Vector3(0.0, 0.01, -L * (0.3 - 0.04 * float(k))), 0.2 + 0.015 * float(k), 1.6 + 0.4 * float(k), 0.012, Color(0.22, 0.14, 0.1))
			for k in 12:
				var z := lerpf(L * 0.38, -L * 0.38, float(k) / 11.0)
				var sx := 0.2 if k % 2 == 0 else -0.2
				b.claw(Vector3(sx, 0.02 + 0.06 * float(k % 3), z), Vector3(signf(sx), 0.4, 0.2).normalized(), 0.06, 0.01, Vector3(0, 0.02, 0), Color(0.3, 0.18, 0.12))
			var sp := PackedVector3Array()
			var rr := PackedFloat32Array()
			for i in 8:
				sp.append(Vector3(0.0, 0.215, L * 0.36 - L * 0.72 * float(i) / 7.0))
				rr.append(0.008)
			b.tube(sp, rr, 4, Color(0.4, 0.1, 0.05), 0.0, 0.0, 0.65)
			parts["body"] = b.commit()
		"old_sunk":
			# three stones: over the eyes, in the mouth, roped to the heart; fen weed hanging off him
			var h: CreatureMesh = Variants.cm(sd)
			h.blob(Vector3(0, 0.04, -0.1), Vector3(0.1, 0.045, 0.04), Basis(Vector3.RIGHT, 0.2), STONE, 1.0, 0.12, 0.0, 6, 10)
			h.blob(Vector3(0, -0.05, -0.105), Vector3(0.04, 0.035, 0.035), Basis.IDENTITY, STONE, 1.0, 0.12, 0.0, 5, 8)
			for k in 5:
				h.strand(Vector3(-0.08 + 0.04 * float(k), 0.1, -0.02), Vector3(0.1 * (float(k) - 2.0), -1.0, 0.1).normalized(), 0.26 + 0.05 * float(k % 2), 0.02, 0.02, Color(0.2, 0.3, 0.2), 1.0, 0.3, 5)
			parts["head"] = h.commit()
			var c: CreatureMesh = Variants.cm(sd + 1)
			var f := Variants.chest_front("husk")
			c.blob(Vector3(0.0, -0.02, -f - 0.04), Vector3(0.1, 0.09, 0.06), Basis.IDENTITY, STONE, 1.0, 0.14, 0.0, 6, 10)
			c.wrap(Vector3(-0.26, 0.12, -0.02), Vector3(0.26, -0.18, -0.02), 0.23, 0.5, 0.016, Color(0.4, 0.33, 0.24))
			c.wrap(Vector3(0.26, 0.12, -0.02), Vector3(-0.26, -0.18, -0.02), 0.23, 0.5, 0.016, Color(0.4, 0.33, 0.24))
			c.blob(Vector3(0.0, -0.02, -f - 0.1), Vector3(0.02, 0.02, 0.012), Basis.IDENTITY, Color(0.2, 0.4, 0.35), 0.0, 0.0, 0.6, 4, 6)
			for k in 12:
				var ang := TAU * float(k) / 12.0
				var o := Vector3(cos(ang) * 0.24, 0.1 - 0.12 * float(k % 3), sin(ang) * 0.22)
				c.strand(o, Vector3(cos(ang) * 0.2, -1.0, sin(ang) * 0.2).normalized(), 0.3 + 0.1 * float(k % 3), 0.03, 0.02, Color(0.18, 0.28, 0.18), 1.0, 0.3, 5)
			parts["chest"] = c.commit()
		"cinder_cantor":
			# a choir ruff, a halo of coals, a censer swinging from the right hand
			var c: CreatureMesh = Variants.cm(sd)
			for k in 16:
				var ang := TAU * float(k) / 16.0
				var o := Vector3(cos(ang) * 0.07, 0.24, sin(ang) * 0.07)
				c.tube(PackedVector3Array([o, o + Vector3(cos(ang) * 0.09, -0.02 + 0.02 * float(k % 2), sin(ang) * 0.09)]), PackedFloat32Array([0.025, 0.012]), 5, Color(0.85, 0.82, 0.78), 0.0, 0.1, 0.0, Vector2(1.0, 0.35), 1.0)
			for k in 10:
				var t := float(k) / 9.0
				c.strand(Vector3(-0.1 + 0.2 * t, 0.15, 0.1), Vector3(0, -1, 0.15).normalized(), 0.5 + 0.1 * float(k % 3), 0.05, 0.02, Color(0.25, 0.2, 0.22), 1.0, 0.25, 5)
			parts["chest"] = c.commit()
			var h: CreatureMesh = Variants.cm(sd + 1)
			for k in 9:
				var ang := -2.2 + 4.4 * float(k) / 8.0
				h.blob(Vector3(sin(ang) * 0.17, 0.14 + cos(ang) * 0.12, 0.1), Vector3(0.018, 0.018, 0.018), Basis.IDENTITY, Color(0.4, 0.15, 0.05), 0.0, 0.1, 0.9, 4, 6)
			Variants._ring(h, Vector3(0, 0.14, 0.1), 0.15, 0.005, Color(0.3, 0.2, 0.15), 0.25, 1.0)
			parts["head"] = h.commit()
			var r: CreatureMesh = Variants.cm(sd + 2)
			r.tube(PackedVector3Array([Vector3(0, -0.02, 0), Vector3(0.01, -0.14, -0.01), Vector3(0.0, -0.26, 0.0)]), PackedFloat32Array([0.004, 0.004, 0.004]), 4, IRON, 1.0, 0.0)
			r.blob(Vector3(0, -0.3, 0), Vector3(0.05, 0.045, 0.05), Basis.IDENTITY, IRON, 1.0, 0.05, 0.0, 6, 9)
			r.blob(Vector3(0, -0.29, 0), Vector3(0.035, 0.03, 0.035), Basis.IDENTITY, Color(0.5, 0.2, 0.05), 0.0, 0.1, 1.0, 5, 8)
			parts["hand_r"] = r.commit()
		"penitent":
			# a hood over a face scraped to a blank plate, scourges from both hands, chains
			var h: CreatureMesh = Variants.cm(sd)
			h.blob(Vector3(0, 0.02, -0.075), Vector3(0.085, 0.1, 0.04), Basis.IDENTITY, BONE, 1.0, 0.03, 0.0, 6, 10)
			for k in 4:
				h.tube(PackedVector3Array([Vector3(-0.05 + 0.03 * float(k), 0.09, -0.11), Vector3(-0.04 + 0.03 * float(k), -0.05, -0.112)]), PackedFloat32Array([0.003, 0.002]), 3, Color(0.3, 0.25, 0.25), 1.0, 0.0)
			h.blob(Vector3(0, 0.06, 0.03), Vector3(0.16, 0.17, 0.17), Basis.IDENTITY, Color(0.22, 0.2, 0.24), 0.0, 0.2, 0.0, 7, 12, 1.0)
			parts["head"] = h.commit()
			for side: String in ["l", "r"]:
				var a: CreatureMesh = Variants.cm(sd + (1 if side == "l" else 2))
				for k in 3:
					a.strand(Vector3(0, -0.04, 0), Vector3(0.2 * (float(k) - 1.0), -1.0, 0.15).normalized(), 0.45, 0.012, 0.05, Color(0.3, 0.22, 0.18), 0.8, 1.0, 6)
					a.claw(Vector3(0.2 * (float(k) - 1.0) * 0.45, -0.48, 0.07), Vector3(0, -1, 0.2).normalized(), 0.05, 0.01, Vector3.ZERO, IRON)
				parts["hand_" + side] = a.commit()
			var c: CreatureMesh = Variants.cm(sd + 3)
			for k in 12:
				var t := float(k) / 11.0
				c.blob(Vector3(lerpf(-0.18, 0.16, t), 0.18 - t * 0.42, -0.14 - 0.03 * sin(t * PI)), Vector3(0.014, 0.01, 0.006), Basis(Vector3.FORWARD, float(k % 2) * 1.57), IRON, 1.0, 0.0, 0.0, 3, 6)
			parts["chest"] = c.commit()
		# --- south marches ---
		"root_wife", "well_answer":
			parts = SouthParts.build(id, rig, sd)
		# --- west marches ---
		"siege_captain":
			# a kettle helm and gorget, a rampart coat in rags, a broken ram-beam slung across the back, iron-shod fists
			var h: CreatureMesh = Variants.cm(sd)
			h.blob(Vector3(0, 0.07, 0.01), Vector3(0.17, 0.12, 0.18), Basis.IDENTITY, IRON, 1.0, 0.1, 0.0, 7, 12, 1.0)
			h.tube(PackedVector3Array([Vector3(-0.2, 0.0, 0.0), Vector3(0, 0.0, -0.17), Vector3(0.2, 0.0, 0.0)]), PackedFloat32Array([0.02, 0.02, 0.02]), 4, IRON, 1.0, 0.05)
			h.blob(Vector3(0, -0.12, -0.04), Vector3(0.14, 0.05, 0.12), Basis.IDENTITY, IRON, 1.0, 0.08, 0.0, 6, 10)
			parts["head"] = h.commit()
			var c: CreatureMesh = Variants.cm(sd + 1)
			var f := Variants.chest_front("husk") + 0.04
			c.plate(Vector3(0, 0.0, -f), Vector3(0.17, 0.15, 0.012), Vector3(0, 0.1, -1.0), IRON, 1.0, 0.04)
			for k in 12:
				var ang := TAU * float(k) / 12.0
				c.strand(Vector3(cos(ang) * 0.22, 0.12, sin(ang) * 0.17), Vector3(cos(ang) * 0.3, -1.0, sin(ang) * 0.3).normalized(), 0.3 + 0.09 * float(k % 3), 0.05, 0.03, RAG, 1.0, 0.25, 5)
			c.tube(PackedVector3Array([Vector3(-0.34, 0.3, 0.14), Vector3(-0.1, 0.12, 0.2), Vector3(0.14, -0.06, 0.22), Vector3(0.38, -0.26, 0.18)]),
				PackedFloat32Array([0.045, 0.05, 0.05, 0.04]), 6, WOOD, 1.0, 0.1)
			for k in 3:
				Variants._ring(c, Vector3(-0.14 + 0.16 * float(k), 0.1 - 0.07 * float(k), 0.21), 0.058, 0.011, IRON, 0.0, 1.0)
			parts["chest"] = c.commit()
			for side: String in ["l", "r"]:
				var a: CreatureMesh = Variants.cm(sd + (2 if side == "l" else 3))
				for k in 3:
					Variants._ring(a, Vector3(0, -0.03 - 0.025 * float(k), -0.01), 0.055, 0.012, IRON, 0.35 if k == 1 else 0.0, 1.0)
				parts["hand_" + side] = a.commit()
		# --- the east marches ---
		"brine_wife":
			# salt crust grown in spikes over the shoulders and brow, a pan-ladle in the right hand
			var c: CreatureMesh = Variants.cm(sd)
			for k in 9:
				var ang := TAU * float(k) / 9.0
				var o := Vector3(cos(ang) * 0.2, 0.2 + 0.03 * float(k % 3), sin(ang) * 0.14)
				c.claw(o, Vector3(cos(ang) * 0.5, 1.0, sin(ang) * 0.4).normalized(), 0.13 + 0.04 * float(k % 3), 0.035, Vector3.ZERO, BONE)
			parts["chest"] = c.commit()
			var h: CreatureMesh = Variants.cm(sd + 1)
			for k in 5:
				var ang2 := -1.0 + 0.5 * float(k)
				h.claw(Vector3(sin(ang2) * 0.1, 0.13, -cos(ang2) * 0.05), Vector3(sin(ang2) * 0.4, 1.0, -0.3).normalized(), 0.1, 0.022, Vector3.ZERO, BONE)
			parts["head"] = h.commit()
			var r: CreatureMesh = Variants.cm(sd + 2)
			r.tube(PackedVector3Array([Vector3(0, -0.02, 0), Vector3(0.0, -0.3, 0.0), Vector3(0.0, -0.6, 0.0)]), PackedFloat32Array([0.012, 0.012, 0.012]), 4, WOOD, 1.0, 0.0)
			r.blob(Vector3(0, -0.66, 0), Vector3(0.08, 0.05, 0.08), Basis.IDENTITY, IRON, 1.0, 0.05, 0.0, 6, 9)
			r.blob(Vector3(0, -0.64, 0), Vector3(0.06, 0.03, 0.06), Basis.IDENTITY, BONE, 1.0, 0.08, 0.0, 5, 8)
			parts["hand_r"] = r.commit()
	return parts
