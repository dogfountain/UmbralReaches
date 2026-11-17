extends RefCounted
## The Long Ledger's pool: the bounties Hearthward posts once the door is shut, and the ranks they earn. Data only; the logic is
## core/story/long_ledger.gd and the page is ui/tally_ledger.gd. Load by path (no class_name).
##
## A bounty: id -> [counter, n at the first night, text with {n}, hard (0 or 1), the Deeper Night it needs (0 = from the first)].
## Counters read what the Count already keeps: "kills" (all put down), "kind:<kind>" (one kind), "clean" (put down with no fall
## since it was posted), "camps", "places", "runs" (parcels), "races", "wins" (races won). The n grows with each ringing of the
## cracked bell (x 1 + 0.35 per Deeper Night), and so does the purse.
const POOL := {
	"k_small": ["kills", 30, "Put down {n} of the hollowed, of any kind, before the night turns.", 0, 0],
	"k_big": ["kills", 70, "Put down {n} of the hollowed. A long night's work, and the ledger has room for it.", 1, 0],
	"k_husk": ["kind:husk", 12, "Put down {n} husks. They keep their old shapes and none of their old manners.", 0, 0],
	"k_wretch": ["kind:wretch", 16, "Put down {n} wretches. The kindest thing the night allows.", 0, 0],
	"k_crawler": ["kind:crawler", 14, "Put down {n} crawlers, which come at the ankles and expect to be forgiven.", 0, 0],
	"k_leaper": ["kind:leaper", 10, "Put down {n} leapers before they find your back.", 0, 0],
	"k_gaunt": ["kind:gaunt", 8, "Put down {n} of the gaunt on the moor road.", 0, 0],
	"k_spitter": ["kind:spitter", 10, "Put down {n} spitters, and mind your face.", 0, 0],
	"k_bulwark": ["kind:bulwark", 5, "Put down {n} bulwarks. Go round the shield or through it, but go.", 1, 0],
	"k_chanter": ["kind:chanter", 6, "Silence {n} chanters. The ledger would like a quiet night.", 1, 0],
	"k_quiller": ["kind:quiller", 6, "Put down {n} quillers, and count your own bones after.", 1, 0],
	"k_ossuant": ["kind:ossuant", 8, "Put down {n} ossuants. The mere gives them back; put them down again.", 0, 0],
	"k_burrower": ["kind:burrower", 8, "Put down {n} burrowers before they undermine anything that matters.", 0, 0],
	"k_pilgrim": ["kind:pilgrim", 6, "Put down {n} of the hollow pilgrims. Say the old word first, if you can.", 1, 0],
	"c_clean": ["clean", 20, "Put down {n} with no fall in between. A clean score, or the ledger forgets it.", 1, 0],
	"c_clean2": ["clean", 35, "Put down {n} without once falling. The Keg will pour for it.", 1, 1],
	"camp": ["camps", 1, "Make camp at a lit fire and let the night turn.", 0, 0],
	"camp2": ["camps", 2, "Make {n} camps at lit fires. The seat beside the fire is there to be used.", 0, 0],
	"places": ["places", 2, "Find {n} places you have not seen. The map has room.", 0, 0],
	"places2": ["places", 4, "Find {n} new places. Take the map, a fire and a horse.", 1, 0],
	"runs": ["runs", 2, "Carry {n} parcels between the posts. Hearthward does not get its post by itself.", 0, 0],
	"races": ["races", 2, "Run {n} races at Hearthward. Fennick will take the entry as a compliment.", 0, 0],
	"wins": ["wins", 1, "Win a race at the Hearthward rail.", 1, 0],
	"wins2": ["wins", 3, "Win {n} races at Hearthward. The Cup is polished and waiting.", 1, 1],
	"d_kills": ["kills", 110, "Put down {n} of the hollowed. They come back harder since the bell, and so must you.", 1, 1],
	"d_camps": ["camps", 3, "Make {n} camps. The cold stays; the fires have to outlast it.", 1, 1],
}
## Rank: marks needed, and its name. A mark is a posted bounty done (two if hard); marks also come as a purse for each rank gained.
const RANKS := [
	[0, "Unlisted"], [3, "Lamp-Bearer"], [8, "Wick-Trimmer"], [15, "Door-Warden"], [25, "Night-Walker"], [40, "Deep Walker"],
	[60, "Keeper of the Cracked Bell"], [85, "Umbral Reader"], [115, "Hearth's Own"], [150, "The Last Lantern"],
]
const POSTED := 3                          ## bounties a night (a fourth, a Deeper one, from the first ringing)
const RANK_LINES := [
	"", "The ledger writes your name once and does not cross it out.", "Hild says you trim a wick the way she tempers iron: once, and well.",
	"Fennick has had your name cut into the door-post. He will not say where.", "The night knows your step and gives way a little. A very little.",
	"There is a hook by the Keg's door with your coat on it now.", "The cracked bell knows your hand. You are not sure that is a comfort.",
	"The Count is read to you in the evening, as it is read to the dead.", "Hearthward sets a place for you that nobody else is allowed.",
	"The lantern is yours, and so is the dark about it, and the two are on speaking terms.",
]


static func rank_of(marks: int) -> int:
	var r := 0
	for i in RANKS.size():
		if marks >= int((RANKS[i] as Array)[0]):
			r = i
	return r


static func scale(ng: int) -> float:
	return 1.0 + 0.35 * float(ng)
