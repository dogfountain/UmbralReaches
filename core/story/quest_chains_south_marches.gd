extends RefCounted
## The South pass's three task chains (data only; quest_chains.gd lists each one at the end of its
## tables, in a block marked south marches, so the ledger, the audit and the world find them). No class_name.
##   shepherd_strays  Dunstan Pike, the shepherd who stayed (a camp at the fold on the southern downs):
##                    raise the flock's three fallen marker-cairns, put down the Bell-Wether who still leads
##                    them, tell him the road is marked
##   oak_song         Gammer Ruan of the Rooted Holds: go and look at the Grandmother Oak, put down the
##                    Root-Wife who keeps its roots, climb to the crown for what the Rooted hid there
##   well_answer      Cadoc the ferryman, whose mere lies north of the Well: stand on the rim, put down the
##                    Answerer on the landing, find the listener's cairn behind the falls
## Steps use the existing kinds (gather, slay with a named rare, visit, cond on an elite or a secret,
## turnin); the cairns are ground pickups on the open downs.

const DeepB := preload("res://core/story/quest_chains_deepen_b.gd")   ## the deepened tasks (docs/QUEST_DEPTH.md)
const ZONES := [["downs", "The Southern Downs"], ["oak", "The Grandmother Oak"], ["well", "The Well of Echoes"]]

const ORDER := ["shepherd_strays", "oak_song", "well_answer"]

const GIVERS := {"dunstan": "Dunstan Pike"}

const RARE_IDS := ["bell_wether", "flint_hound"]

const QUESTS := {
	"shepherd_strays": DeepB.SHEPHERD_STRAYS,
	"oak_song": DeepB.OAK_SONG,
	"well_answer": DeepB.WELL_ANSWER,
}

const PICKUPS := {
}
