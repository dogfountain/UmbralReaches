extends RefCounted
## r28 writings (agent D), kept beside lore_db.gd (the lead's) rather than in it: the Ninth
## Company's story told across three places in the Thornwood (a fallen camp, a burial under an oak,
## a ritual ring), and what is cut and left at each. Same entry shape as LoreDB (region, kind,
## title, text, series/part). Read everything through lore_index.gd, which merges both.
## No class_name: const LoreMore := preload("res://core/world/realm/lore/lore_more.gd")

const TEXTS := {
	"nc_company_1": {"region": "thornwood", "kind": "letter", "title": "The Ninth Company, i", "series": "company", "part": 1,
		"text": "We came late, the Ninth Company, forty days behind the blessing. The Stair was gone when we reached the rim. Brother Aldo says we camp in the wood and wait for it to grow back."},
	"nc_company_2": {"region": "thornwood", "kind": "letter", "title": "The Ninth Company, ii", "series": "company", "part": 2,
		"text": "Aldo did not wake. We laid him facing the Stair, as he asked, under oak and not stone. Mother Seren cut his name in the root so the wood would remember what we could not carry."},
	"nc_company_3": {"region": "thornwood", "kind": "letter", "title": "The Ninth Company, iii", "series": "company", "part": 3,
		"text": "Seren drew the ring and we stood in it and burned our tokens. If we cannot go up, we will not go hollow. If you have come this far behind us, our offering is under the ninth stone."},
	"nc_camp_token": {"region": "thornwood", "kind": "plaque", "title": "A pilgrim's token",
		"text": "A tin Open Door on a cord, hammered flat on the fire-stones. Someone did it slowly, and carefully, all the way round."},
	"nc_burial_root": {"region": "thornwood", "kind": "rune", "title": "Cut in the root",
		"text": "ALDO OF THE NINTH. HE WALKED THE WHOLE ROAD. Under it, smaller, newer: the wood remembers."},
	"nc_ring_ash": {"region": "thornwood", "kind": "tablet", "title": "The ring's hearth-stone",
		"text": "Nine stones, nine names scratched off. In the ash at the centre, a child's hand pressed flat, and a tenth name nobody finished."},
	# --- r30 (storyteller): the boss spaces speak. No stone of their own: the place is the carrier,
	# set by its builder with place() (thorn_henge.gd, ossuary.gd, summit_dress.gd).
	"bs_henge_keeper": {"region": "henge", "kind": "rune", "title": "Cut at the hedge's mouth",
		"text": "In the Rooted's hand, half under thorn: Keeper, keep. If one comes up the hill with fire, let them by. We were wrong about fire."},
	"bs_wenna_niche": {"region": "ossuary", "kind": "plaque", "title": "A candle-stub in a niche",
		"text": "Scratched on the sill, beside a stub of candle still soft from burning: She counted me. I let her. Then I said her name back, and she stopped. W."},
	"bs_last_step": {"region": "rift", "kind": "tablet", "title": "The last step",
		"text": "A pilgrim's tally, scratched in fives with a nail: 3,998. Bells stopped. Going on anyway."},
	"bs_ward": {"region": "summit", "kind": "plaque", "title": "The summit ward",
		"text": "Let none climb to the door but by the leave of the two who keep the valley down: the root, and the count. A."},
	"bs_dais": {"region": "summit", "kind": "plaque", "title": "The dais stone",
		"text": "HERE THE HIERARCH AUREL OPENED THE DOOR. THE NAMES OF THE FAITHFUL WHO WENT THROUGH: Below, the stone is dressed smooth for a long list. Nothing is cut there."},
}

## Put a writing at `at` (parent-local) under `parent`: an Inscription with no stone of its own (the
## ward, the niche, the paving it stands on is the carrier). Loaded, not preloaded: inscription.gd
## reads this file through lore_index.gd.
static func place(parent: Node, id: String, at: Vector3) -> Node3D:
	var s: Node3D = (load("res://core/world/realm/lore/inscription.gd") as GDScript).call("make", id)
	s.position = at
	parent.add_child(s)
	return s


const SERIES := {
	"company": {"title": "The Ninth Company", "count": 3,
		"blurb": "Letters of the last pilgrims, who came after the Stair broke and stayed in the Thornwood."},
}
