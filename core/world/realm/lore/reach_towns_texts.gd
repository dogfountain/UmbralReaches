extends RefCounted
## The Far Reaches' towns' writings (laid by core/world/realm/reach_towns_dress.gd WRITINGS). Entry shape as lore_db.gd
## TEXTS; the shared table takes these in its `# --- the towns ---` block. House style (docs/LORE.md): terse, concrete,
## dark. No class_name: preload by path.

const TEXTS := {
	# --- Reedholm --------------------------------------------------------------------------------------------------
	"town_rh_board": {"region": "reedmere", "kind": "notice", "title": "Reedholm's landing-board",
		"text": "BOATS IN BY DARK. LAMPS LIT AT THE JETTY. NOBODY PAST THE HERON STONES FOR ANY CATCH, ANY PRICE, ANY REASON. The last line has been cut and re-cut for as long as the board has stood."},
	"town_rh_lampbook": {"region": "reedmere", "kind": "ledger", "title": "Reedholm's lamp book",
		"text": "Lamps burned this month at the jetty: thirty. Lamps kept burning through the night: thirty. Boats not home by dark: one (T. Wade, past the stones). Boats home, and not our own: one. We took it in. It had a lamp on it. It was lit."},
	"town_rh_grave": {"region": "reedmere", "kind": "grave", "title": "A fisher's marker",
		"text": "WIDOW CORLE'S THREE. A plank and three cut notches. The water has taken the plank down to a handspan twice, and the village has put a new one up on the same three notches each time."},
	"town_rh_heron": {"region": "reedmere", "kind": "rune", "title": "The heron pole",
		"text": "A heron carved at the top of a pole by the landing, its beak turned in to the town, not out to the mere. Ropes are tied round the pole, one for every boat. Some are new. Some have been cut through and left hanging."},
	# --- Fallowmere ------------------------------------------------------------------------------------------------
	"town_fm_tithe": {"region": "fallow", "kind": "notice", "title": "The tithe board",
		"text": "Painted in the porch, over eleven winters of tally sticks: OF EVERY TENTH SHEAF, THE ORDER'S. OF EVERY TENTH SOUL, THE STAIR'S. The second line is newer than the first, and in another hand, and someone has tried to scrape it off."},
	"town_fm_strips": {"region": "fallow", "kind": "grave", "title": "Markers in a strip",
		"text": "A row of hazel stakes down the middle of a field, each with a name burned in. MARGERY. OLD HOB. THE TWO FROM THE ROAD. A CHILD, NOT OURS. At the end of the row a stake with no name at all, and fresh earth under it."},
	"town_fm_almanac": {"region": "fallow", "kind": "page", "title": "A page of the farm's almanac",
		"text": "Sow beans when the elm leaf is a mouse's ear. There are no elms. Sow barley when the Order's bell rings for lady day. There is no bell. Sow when you can see your hand at noon. Hesper says we will sow when we're hungry enough, and we are."},
	"town_fm_dovecote": {"region": "fallow", "kind": "notice", "title": "Chalked on the dovecote door",
		"text": "BIRDS 40. BIRDS 22. BIRDS 9. BIRDS 1. Then a child's hand: SHE COMES BACK EVERY NIGHT AND SITS ON THE ROOF AND LOOKS AT THE BARN."},
	# --- Lastlight ------------------------------------------------------------------------------------------------
	"town_ll_plaque": {"region": "lastlight", "kind": "rune", "title": "The East Gate's plaque",
		"text": "Cut over the arch, on the town's side: HERE THE LAST LAMP. HERE THE ROAD TURNS TO THE STAIR. GO UP IN HOPE. Under it, smaller and much newer, scratched with a knife point: OR DON'T."},
	"town_ll_book": {"region": "lastlight", "kind": "ledger", "title": "The Last Lamp's guest book",
		"text": "Three hundred years of names in one hand after another, each with a line: going up. The last page has eleven names and the date of the Night, and against every one of them, in Mother Vell's hand: room kept."},
	"town_ll_shrine": {"region": "lastlight", "kind": "tablet", "title": "The pilgrims' shrine",
		"text": "A niche by the shut gate, black with three hundred years of candle smoke. Scratched in the sill, over and over, in many hands: FOR THE CLIMB. Newer, along the top, in one hand only: FOR THE ONES WHO COME DOWN."},
	"town_ll_bridles": {"region": "lastlight", "kind": "page", "title": "A tag on a bridle",
		"text": "One of forty hung along the stable's back wall, each with a wooden tag. This one: GREY MARE, LAME OFF HIND. OWNER GONE UP. FEED HER TILL I'M BACK. Wat has fed her eleven winters. She is not the same mare."},
	"town_ll_orders": {"region": "lastlight", "kind": "notice", "title": "Standing orders of the east watch",
		"text": "1. The gate stays barred. 2. If it knocks, the gate stays barred. 3. If it knows your name, the gate stays barred. 4. Wake the serjeant. 5. The gate stays barred. Signed, Coyle, and under it, in an older hand, Coyle."},
}
