extends RefCounted
## The flora's data tables (rates per biome, the regions' looks), split from realm_flora.gd, which
## places. Read through `RealmFlora.UNDER` / `RealmFlora.LOOKS`.

## undergrowth: instances per m2 by biome
## (docs/enshrouded/world.md) layered like an Enshrouded wood -- a grass floor even under the
## oaks, bracken and shrubs thickest at the forest's edges (_under_mod), tall-grass and flower drifts
## on the open ground, and stones in the turf (STONES). Measured with zz/perf_tour --stress=2.
const UNDER := {
	"grass": {"meadow": 6.5, "heath": 3.2, "glade": 3.8, "oldforest": 1.3, "ruin": 3.2, "fen": 1.6, "crag": 1.1, "ash": 0.03, "salt": 0.02},
	"tallgrass": {"meadow": 0.2, "heath": 0.32, "fen": 0.28, "ruin": 0.2, "glade": 0.09, "oldforest": 0.05},
	"flowers": {"meadow": 0.45, "heath": 0.2, "glade": 0.48, "ruin": 0.14, "oldforest": 0.015},
	"heather": {"heath": 0.42, "crag": 0.2, "meadow": 0.012, "ruin": 0.03},
	"fern": {"oldforest": 0.42, "glade": 0.16, "fen": 0.04, "ruin": 0.07, "meadow": 0.006},
	"shrub": {"oldforest": 0.075, "meadow": 0.01, "heath": 0.018, "ruin": 0.035, "glade": 0.022, "fen": 0.016, "crag": 0.016},
	"bramble": {"oldforest": 0.022, "ruin": 0.03, "fen": 0.005},
	"litter": {"oldforest": 0.22, "glade": 0.025, "ruin": 0.045, "meadow": 0.005},
	"moss": {"oldforest": 0.14, "fen": 0.1, "glade": 0.05, "crag": 0.04, "ruin": 0.04},
	"mushroom": {"oldforest": 0.035, "fen": 0.015, "glade": 0.012},
	"glowcap": {"oldforest": 0.004, "glade": 0.02, "fen": 0.005},
	"reeds": {"fen": 0.01},
	"cattail": {"fen": 0.004},
	"log": {"oldforest": 0.006, "fen": 0.003, "glade": 0.002},
	"stump": {"oldforest": 0.005, "fen": 0.004, "meadow": 0.001, "heath": 0.001, "ash": 0.001},
	"roots": {"oldforest": 0.008},
	# the new regions' own ground cover (no biome rate: LOOKS add them)
	"gorse": {}, "deadbush": {"salt": 0.006}, "ashdrift": {}, "cinders": {}, "lily": {}, "scaffold": {},
}

## Each new region's own look over its biome. Weighted by how far
## inside the region a spot is (_look_weight: full inside, gone 8 m out). Undergrowth rate =
## biome rate x mul + add; trees per 3.5 m candidate the same; `tint` colours the grassy kinds;
## `props` are RockKit pieces per m2 (_place_stones); `rows` plants orchard rows / a cypress avenue.
## Ideas: Enshrouded gives every region one strong ground read (ash shelves, heather uplands, reed
## water) by swapping the cover and its colour rather than adding more of it.
const LOOKS := {
	"quarry": {"tree_mul": {"oak": 0.0, "birch": 0.3, "pine": 0.35, "sapling": 0.35},
		"under_mul": {"grass": 0.62, "tallgrass": 0.7, "heather": 0.7, "flowers": 0.4, "fern": 0.45},
		"under_add": {"scaffold": 0.006, "moss": 0.02},
		"tint": Color(0.92, 0.9, 0.82), "props": {"rubble": 0.07, "block": 0.012}, "stone_mul": 1.6, "style": "granite"},
	"holds": {"tree_mul": {"oak": 0.12, "birch": 0.5, "pine": 0.2, "sapling": 0.15, "snag": 0.3},
		"under_mul": {"heather": 2.4, "grass": 2.3, "fern": 0.5, "litter": 0.4},
		"under_add": {"heather": 1.6, "flowers": 0.14, "gorse": 0.03, "mushroom": 0.01, "tallgrass": 0.08},
		"tint": Color(0.95, 0.92, 0.84)},
	"foundry": {"tree_mul": {"pine": 0.15, "sapling": 0.0, "birch": 0.0, "oak": 0.0}, "tree_add": {"snag": 0.04},
		"under_mul": {"grass": 0.6, "heather": 0.3},
		"under_add": {"grass": 0.45, "deadbush": 0.03, "cinders": 0.012, "ashdrift": 0.06, "tallgrass": 0.03},
		"tint": Color(0.5, 0.46, 0.42), "props": {"slag": 0.05}, "style": "ash"},
	"moor": {"tree_mul": {"oak": 0.0, "birch": 0.25, "pine": 0.25, "sapling": 0.3}, "tree_add": {"windtree": 0.2},
		"under_mul": {"grass": 0.92, "tallgrass": 0.9, "flowers": 0.45, "heather": 1.8, "shrub": 0.3},
		"under_add": {"gorse": 0.03, "moss": 0.02},
		"tint": Color(0.92, 0.88, 0.7), "props": {"cairn": 0.006}, "stone_mul": 1.6, "style": "granite"},
	"orchard": {"tree_mul": {"oak": 0.0, "birch": 0.1, "pine": 0.0, "sapling": 0.0, "snag": 0.6}, "rows": "fruit",
		"under_mul": {"heather": 0.3},
		"under_add": {"grass": 0.62, "tallgrass": 0.08, "ashdrift": 0.14, "cinders": 0.006, "stump": 0.004, "log": 0.0015, "litter": 0.03},
		"tint": Color(0.62, 0.6, 0.56)},
	"necropolis": {"tree_mul": {"oak": 0.15, "birch": 0.4, "pine": 0.2, "sapling": 0.2, "snag": 0.6}, "tree_add": {"yew": 0.3}, "rows": "cypress",
		"under_mul": {"grass": 2.15, "tallgrass": 2.6, "flowers": 0.5, "heather": 0.4, "moss": 1.8, "shrub": 0.4, "bramble": 1.4},   # grass 1.15 -> 1.42 (it sat on the floor of its band against heath)
		"under_add": {"glowcap": 0.003},
		"tint": Color(0.8, 0.86, 0.8), "props": {"headstone": 0.006}, "stone_mul": 1.3, "style": "granite"},
	"mere": {"tree_mul": {"oak": 0.2, "birch": 0.6, "pine": 0.0, "sapling": 0.5}, "dead_willow": 0.85,
		"under_mul": {"grass": 0.34, "tallgrass": 0.7, "flowers": 0.5, "reeds": 2.2, "cattail": 2.2, "moss": 1.6},
		"under_add": {"lily": 0.35},
		"tint": Color(0.86, 0.94, 0.88)},
}


## The world's edge on the west, east and south is a wall of cliff faces (RealmWayfinding.edges): a tree
## whose trunk or crown stands in that band grows through the rock.
static func on_edge_wall(at: Vector2, spread: float) -> bool:
	var bd := RealmLayout.BOUNDS
	var reach := 5.5 + spread * 0.3
	if at.y > bd.position.y + 32.0 and at.y < bd.end.y + 3.0:
		if absf(at.x - bd.position.x) < reach or absf(at.x - bd.end.x) < reach:
			return true
	return at.y > bd.end.y - reach and at.y < bd.end.y + 3.0
