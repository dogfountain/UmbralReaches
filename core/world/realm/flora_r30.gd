extends RefCounted
## The old undergrowth table, kept for A/B perf runs: the old-flora flag builds the wood as it was (this
## table, no edge crowding, no stones). Read by realm_flora.gd.

const UNDER := {
	"grass": {"meadow": 6.5, "heath": 2.8, "glade": 3.6, "oldforest": 0.7, "ruin": 3.0, "fen": 1.3, "crag": 0.9, "ash": 0.03},
	"tallgrass": {"meadow": 0.1, "heath": 0.22, "fen": 0.18, "ruin": 0.14, "glade": 0.06, "oldforest": 0.03},
	"flowers": {"meadow": 0.32, "heath": 0.14, "glade": 0.4, "ruin": 0.1},
	"heather": {"heath": 0.38, "crag": 0.16, "meadow": 0.012, "ruin": 0.03},
	"fern": {"oldforest": 0.3, "glade": 0.12, "fen": 0.03, "ruin": 0.05, "meadow": 0.004},
	"shrub": {"oldforest": 0.05, "meadow": 0.006, "heath": 0.01, "ruin": 0.025, "glade": 0.015, "fen": 0.01, "crag": 0.012},
	"bramble": {"oldforest": 0.018, "ruin": 0.025, "fen": 0.004},
	"litter": {"oldforest": 0.2, "glade": 0.02, "ruin": 0.04, "meadow": 0.005},
	"moss": {"oldforest": 0.1, "fen": 0.09, "glade": 0.04, "crag": 0.03, "ruin": 0.03},
}
