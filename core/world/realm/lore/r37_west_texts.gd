extends RefCounted
## West Marches: the written lore of Weirford, the Sorrow's Banks, the Fallen Hierarch and the Siege Lines
## (entry shape: lore_db.gd; the shared tables take these in their west-marches blocks). The poi_*-style
## ids (r37w_*) stand in realm_pois_r37_west.gd's places; the rest are placed by r37_west_places.gd.
## House style (docs/LORE.md): terse, concrete, dark; warm but wary at Weirford.

const TEXTS := {
	# --- Weirford -------------------------------------------------------------------------------
	"r37w_bridge": {"region": "weirford", "kind": "plaque", "title": "Weirford Bridge",
		"text": "BUILT BY THE WEIR-REEVES IN THE YEAR OF THE LOW WATER, FOR THE ROAD'S SAKE. Two arches and a pier in the river, and no gate at either end. The Order asked for one for forty years. The reeves paid the toll in flour, and left it open."},
	"r37w_mill": {"region": "weirford", "kind": "plaque", "title": "The Weir Mill",
		"text": "The first race was cut by Osk's grandfather's grandfather. The wheel has turned every night since but one: the night the sky went, when the river ran backward the length of a breath and the wheel turned with it."},
	"r37w_inn": {"region": "weirford", "kind": "plaque", "title": "The Grey Heron",
		"text": "Cut under the sign: THREE NIGHTS FREE FOR ANYONE WHO GIVES A NAME. Most give their own. Some give a different one each night. The keeper writes every one in the ledger, and has never crossed one out."},
	"r37w_notice": {"region": "weirford", "kind": "notice", "title": "Notice",
		"text": "BY THE WATCH: no light on the bridge after the fourth bell but the Sister's. Nobody south of the second gate. Nobody answers the voice from the hill, whoever it sounds like."},
	"r37w_smith": {"region": "weirford", "kind": "plaque", "title": "The smith's door",
		"text": "Cut on the lintel, and cut again: HINGES, NOT BLADES. Under it, in a different hand, and newer: BOTH, THEN."},
	"wf_grave": {"region": "weirford", "kind": "grave", "title": "A ferryman's grave",
		"text": "ASHER, WHO RAN THE FORD BEFORE THE BRIDGE. The pole is planted at the head instead of a cross. Somebody keeps it oiled."},
	# --- the Sorrow's Banks -------------------------------------------------------------------------
	"r37w_shrine": {"region": "sorrow", "kind": "plaque", "title": "The Drowned Shrine",
		"text": "SAINT ALDITH OF THE FORD, who carried pilgrims over on her back and was paid, in the end, by the river. The roof went first, then the saint. The altar still stands in the shallows, and some nights someone sets a lit boat on it."},
	"sr_ford": {"region": "sorrow", "kind": "notice", "title": "Ford-board",
		"text": "FORD OPEN WHILE THE POSTS ARE DRY. The posts are never dry. Somebody has chalked under it, very small: it is shallower than it looks, and colder than it ought to be."},
	"sr_reeve": {"region": "sorrow", "kind": "grave", "title": "The Reeve's marker",
		"text": "HERE LIES THE WEIR-REEVE, who took the river's tolls honest for thirty years. He is not here. The marker has been dragged four times up the bank, and put back."},
	"sr_boats": {"region": "sorrow", "kind": "page", "title": "A boat-maker's tally",
		"text": "Votive boats made: thirty. Candle-ends supplied: thirty. Names cut in the keels: twenty-nine. I could not bring myself to ask whose the last was, and I have not been asked."},
	# --- the Fallen Hierarch ------------------------------------------------------------------------
	"r37w_statue": {"region": "hierarch", "kind": "plaque", "title": "The Fallen Hierarch",
		"text": "On the plinth, now a ridge in the moss: AUREL, FIRST AND LAST VOICE OF THE ORDER. His head was cut hollow, that one voice might speak the Edicts across the Marches. It fell the night the sky turned. The voice was never given leave to stop."},
	"r37w_hand": {"region": "hierarch", "kind": "rune", "title": "In the heel of the palm",
		"text": "Cut small, by someone who could just reach it: I MADE THE HAND. THE PALM WAS TO FACE DOWN. -- the mason's cousin. (He is wrong. It has always faced up, and nothing has ever been put in it.)"},
	"hr_warning": {"region": "hierarch", "kind": "notice", "title": "Watch notice",
		"text": "THE HEAD IS NOT TO BE CLIMBED. THE HEAD IS NOT TO BE ANSWERED. If it asks you your name, give Weirford's. They are not particular, and the voice has never once been polite."},
	"hr_mason": {"region": "hierarch", "kind": "grave", "title": "A mason's grave",
		"text": "THE THUMB TOOK FOUR YEARS. A chisel is laid across the stone. The edge has been turned, kindly, so that nobody cuts themselves on it."},
	"hr_boy": {"region": "hierarch", "kind": "page", "title": "A choirmaster's note",
		"text": "Elias is to hold the A. Not sing it, hold it. He is twelve. The mason says the hollow will give it a body, and the Hierarch says a body is the least of it. He is to be relieved at dawn. There is no later note."},
	# --- the Siege Lines -------------------------------------------------------------------------------
	"r37w_siege_line": {"region": "siege", "kind": "notice", "title": "The Outer Earthwork",
		"text": "THE MARCHES' ORDER OF THE DAY: hold the ring. If the ring is lost, hold the next. If there is no next, dig one. There are nine rings. The ninth was never finished, and it is the only one that faces the right way."},
	"r37w_trebs": {"region": "siege", "kind": "ledger", "title": "The engine-master's tally",
		"text": "Stones thrown: four hundred and ten. Gates struck: none. The arms are cocked and the cords cut. It is a long way to the East Gate, and the Order built its walls to be struck from exactly here."},
	"r37w_tower": {"region": "siege", "kind": "tablet", "title": "The Tower",
		"text": "RAISED BY TOLLIVER AND ONE HUNDRED HANDS IN NINE NIGHTS. Four floors, and a drawbridge to the wall. Under it, in the engineer's own cut: the wall was not where the plans said, by eleven yards. It was never the wall's habit to move."},
	"sg_roll_1": {"region": "siege", "kind": "page", "title": "A conscript's letter, i", "series": "marches", "part": 1,
		"text": "Mam. They gave us a spade and a number and told us the Order would come to us. It did not. We dug in anyway. The captain says that is the point of digging in."},
	"sg_roll_2": {"region": "siege", "kind": "page", "title": "A conscript's letter, ii", "series": "marches", "part": 2,
		"text": "Mam. The engines are up. Nobody has been told which way they are to face. The captain says: toward the wall. The engineer says: the wall has moved. Nobody laughs."},
	"sg_roll_3": {"region": "siege", "kind": "page", "title": "A conscript's letter, iii", "series": "marches", "part": 3,
		"text": "Mam. I am going to put this under the third stake and not post it. The captain has not slept since the order to go in. He says he will give the order again tonight. He says he is sure it will be heard this time."},
	"sg_grave": {"region": "siege", "kind": "grave", "title": "A war-band's grave",
		"text": "ONE HUNDRED AND TWO, AND THE CAPTAIN. The captain's name is cut last, and over: VARR. The cut is deeper than the others. Somebody dug him up and put him back, more than once."},
}

const SERIES := {
	"marches": {"title": "A Conscript's Letters", "count": 3,
		"blurb": "Three letters left under a stake in the Siege Lines, never posted."},
}

const REGIONS := ["weirford", "sorrow", "hierarch", "siege"]

const PLACE_INFO := {
	"weirford": {"name": "Weirford", "line": "warm, and wary",
		"text": "The last town the Order did not burn. A bridge, a weir, a mill and an inn on the river the road crosses at the Marches' edge. It ground the abbey's flour, kept its head down, and fed anyone the road sent. The Watch holds four men now."},
	"sorrow": {"name": "The Sorrow's Banks", "line": "grey with ash until the weir",
		"text": "The river down from the Crowns, and the alder banks along it. It runs grey with ash and does not clear until Weirford's weir. A saint's shrine stands half-drowned in the shallows, and the fords are watched by the drowned."},
	"hierarch": {"name": "The Fallen Hierarch", "line": "he was raised taller than the Stair",
		"text": "A colossus of the Order's first Hierarch lies on its back in the moss under the Crowns, one hand open, palm up. The head was cut hollow, so that one voice could be heard across the Marches. It split when he fell. Something is still speaking in it."},
	"siege": {"name": "The Siege Lines", "line": "the gates held, and the Marches did not",
		"text": "Nine rings of earthwork and palisade dug by the Marches against the Order's gates. Rotted trebuchets point east, and a four-storey siege tower stands where it was left. The war-band has not stood down."},
}
