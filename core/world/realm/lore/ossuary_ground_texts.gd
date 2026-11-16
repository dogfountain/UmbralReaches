extends RefCounted
## The Ossuary's own ground: the writings of the Lych Way, the lych gate, the Bearers' Yard and the sorting ground
## (entry shape: lore_db.gd; the shared tables take these in their `# --- the ossuary ---` blocks). Placed by
## ossuary_ground.gd on its own stones. House style (docs/LORE.md): terse, concrete, dark. The bearers were the
## Order's lay brothers who carried the dead from the road down to the count; nobody counts them.

const TEXTS := {
	"oss_g_cross": {"region": "ossuary", "kind": "rune", "title": "The Lych Cross",
		"text": "THE LYCH WAY. FROM THE ROAD TO THE COUNT. BEARERS ONLY, AND THE BORNE. Under it, scratched later and deep: the borne do not need telling."},
	"oss_g_stone_1": {"region": "ossuary", "kind": "tablet", "title": "The first coffin stone", "series": "bearers", "part": 1,
		"text": "ONE FOR THE ROAD THAT WAS WALKED. Set them down here and say the name. If there is no name, say the road."},
	"oss_g_stone_2": {"region": "ossuary", "kind": "tablet", "title": "The second coffin stone", "series": "bearers", "part": 2,
		"text": "TWO FOR THE DOOR THAT WAS OPEN. Set them down here and say what they carried. If they carried nothing, say that."},
	"oss_g_stone_3": {"region": "ossuary", "kind": "tablet", "title": "The third coffin stone", "series": "bearers", "part": 3,
		"text": "THREE FOR THE COUNT THAT IS KEPT. Set them down here and do not say the number. The Abbot says the number."},
	"oss_g_grave": {"region": "ossuary", "kind": "grave", "title": "A bearer's grave",
		"text": "PIRAN, BEARER, WHO CARRIED FOUR THOUSAND AND WAS NOT CARRIED. They laid him by the third stone face down, so he would not be counted. Somebody has turned the stone over him face up."},
	"oss_g_niche": {"region": "ossuary", "kind": "page", "title": "A bearer's tally",
		"text": "Bore today four from the road, one from the field (re-dug: the stone was wanted). Rested at the three stones, said the verses. Piran says the third stone is warm in the mornings. I said it is the sun. He said: what sun."},
	"oss_g_gate": {"region": "ossuary", "kind": "plaque", "title": "The lych gate",
		"text": "HERE THE BORNE WAIT FOR THE COUNT. The bell in the gable was rung once for each of them as they passed under. It still rings for whoever passes. There is no rope."},
	"oss_g_lantern": {"region": "ossuary", "kind": "plaque", "title": "The Lantern of the Dead",
		"text": "RAISED BY ABBOT OSRIC, YA 241, THAT THE DEAD MIGHT FIND THE COUNT BY NIGHT. Brother Clement fed it tallow from the rendering-house. It burns now without Clement and without tallow, and its light is not warm."},
	"oss_g_table": {"region": "ossuary", "kind": "rune", "title": "The bearers' table",
		"text": "THE LAST REST. Here they lay one night under the lantern before they went down to be counted. Somebody has left a cup of water on the stone. It has not been drunk, and it has not dried."},
	"oss_g_sorting": {"region": "ossuary", "kind": "ledger", "title": "The sorters' slate",
		"text": "Skulls to the gallery, long bones to the piers, the small bones to the pool. Teeth to the Abbot, in a bag, by the hundred. Nine bags this week. Clement asks what the Abbot wants with teeth. I have stopped asking."},
	"oss_g_rule": {"region": "ossuary", "kind": "notice", "title": "The Rule of the Bearers",
		"text": "NO BORNE TO BE SET DOWN BUT AT THE STONES. NONE TO PASS THE GATE UNRUNG. NO BEARER TO LOOK INTO THE PIT WHILE BEARING. NO BEARER TO COUNT. Counting is the Abbot's."},
}

const SERIES := {
	"bearers": {"title": "The Bearers' Count", "count": 3,
		"blurb": "The verses cut in the coffin stones of the Lych Way, one to each place the bearers set the dead down."},
}

const PLACE_INFO := {
	"ossuary": {"name": "The Ossuary", "line": "the Abbot is still counting",
		"text": "The Waiting Field's charnel house: a bone pit quarried into the slope, where Abbot Osric stacked and numbered the dead to wait for the sky's call. The Lych Way brings them down from the road between walls of skulls, and the Lantern of the Dead still burns over the Bearers' Yard. Its light is not warm."},
}
