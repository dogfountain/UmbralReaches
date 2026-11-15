extends RefCounted
## Where the Far Reaches' towns stand (data only; reach_towns.gd builds them). World xz, metres; a yaw turns a piece's
## front (+z in the model) to face (sin yaw, cos yaw): 0 = south (+z), PI = north, PI/2 = east, -PI/2 = west.
## The models are tools/blender/reach_town_*.py (art/models/reach_towns.glb); their collision and numbers are
## reach_towns_boxes.gd. Laid on the ground as surveyed with zz/town_map.gd (heights, pools, the ways).
##   Reedholm    the fishers' stilt town on the pools between the end of barrow_track and the Sorrow; the landing and
##               its fire where the track meets reed_ford; the ford's footbridge over the river
##   Fallowmere  the hamlet round the meeting of reed_ford, fallow_way and arches_way under the downs' scarp: the
##               tithe barn, the farmhouse, two cottages, the dovecote, the green and its fire; the fold, ricks, and
##               the drowned strips with the scarecrows to the south
##   Lastlight   the walled waystation across the road's end: curtain walls and four towers, the road gate (west),
##               the shut East Gate, a postern for the Bellfall track; the inn, the lamp tower, the stable, the
##               watch, a store, the pilgrims' shrine, the yard and its fire
## No class_name: preload by path.

const GLB := "res://art/models/reach_towns.glb"
const PROPS_GLB := "res://art/models/r37_south_hut.glb"

## town id -> region, the middle and the reach of its ground (flora and wildlife keep off; the discovery names it),
## the datum its decks hang from (Reedholm: the fen's water line).
const TOWNS := {
	"reedholm": {"name": "Reedholm", "region": "reedmere", "c": Vector2(-311.0, 281.0), "r": 30.0, "line": "the fishers keep their lamps lit"},
	"fallowmere": {"name": "Fallowmere", "region": "fallow", "c": Vector2(-160.0, 300.0), "r": 34.0, "line": "the Order's bread, and its graves"},
	"lastlight": {"name": "Lastlight", "region": "lastlight", "c": Vector2(324.5, 53.5), "r": 40.0, "line": "the last lamp before the mountain"},
}

## Piece kinds: the local footprint (for the ground under it and the site it reserves), its far silhouette and where
## that takes over (FarDetail), its own fade (0 = never: a building with a far mesh, or a landmark), whether it casts
## shadows. `stilt`: stands on piles from the water (its origin is the water line, not the ground).
const KIND := {
	"FM_TitheBarn": {"rect": Rect2(-14.6, -6.0, 29.2, 17.0), "far": "FM_BarnFar", "near": 230.0},
	"FM_Farmhouse": {"rect": Rect2(-8.4, -6.9, 17.6, 13.4), "far": "FM_HouseFar", "near": 170.0},
	"FM_Cottage": {"rect": Rect2(-5.1, -3.4, 12.6, 6.8), "vis": 230.0},
	"FM_Dovecote": {"rect": Rect2(-3.4, -3.4, 6.8, 6.8), "far": "FM_DoveFar", "near": 160.0},
	"FM_Rick": {"rect": Rect2(-2.9, -2.9, 5.8, 5.8), "vis": 200.0},
	"FM_Stook": {"rect": Rect2(-0.6, -0.6, 1.2, 1.2), "vis": 90.0, "shadow": false},
	"FM_Scarecrow": {"rect": Rect2(-0.5, -0.5, 1.0, 1.0), "vis": 120.0},
	"FM_Well": {"rect": Rect2(-1.3, -1.3, 2.6, 2.6), "vis": 120.0},
	"FM_Wain": {"rect": Rect2(-2.4, -1.3, 7.0, 2.6), "vis": 120.0},
	"FM_Hurdle": {"rect": Rect2(-1.3, -0.15, 2.6, 0.3), "vis": 90.0, "shadow": false},
	"FM_Gate": {"rect": Rect2(-1.9, -0.15, 3.8, 0.3), "vis": 100.0},
	"RH_Hall": {"rect": Rect2(-7.5, -5.5, 15.0, 12.2), "far": "RH_HallFar", "near": 190.0, "stilt": true},
	"RH_House": {"rect": Rect2(-4.2, -3.8, 8.4, 8.8), "far": "RH_HouseFar", "near": 150.0, "stilt": true},
	"RH_HouseB": {"rect": Rect2(-3.8, -3.5, 7.6, 8.2), "far": "RH_HouseFar", "near": 150.0, "stilt": true},
	"RH_HouseLong": {"rect": Rect2(-6.5, -3.4, 13.0, 8.0), "vis": 260.0, "stilt": true},
	"RH_Smokehouse": {"rect": Rect2(-2.5, -2.5, 6.0, 5.0), "vis": 220.0},
	"RH_Landing": {"rect": Rect2(-5.0, -3.4, 10.0, 6.8), "vis": 200.0, "stilt": true},
	"RH_HeronPole": {"rect": Rect2(-0.4, -0.4, 0.8, 0.8), "vis": 0.0},
	"RH_Rack": {"rect": Rect2(-2.3, -1.0, 4.6, 2.0), "vis": 120.0},
	"RH_NetFrame": {"rect": Rect2(-2.1, -0.3, 4.2, 0.6), "vis": 110.0},
	"RH_Punt": {"rect": Rect2(-2.7, -0.7, 6.4, 1.4), "vis": 110.0, "stilt": true},
	"RH_Trap": {"rect": Rect2(-0.4, -0.4, 1.4, 0.8), "vis": 60.0, "shadow": false},
	"RH_ReedStack": {"rect": Rect2(-0.8, -0.8, 1.6, 1.6), "vis": 100.0},
	"RH_Bridge": {"rect": Rect2(-9.6, -1.2, 19.2, 2.4), "vis": 240.0, "stilt": true},
	"LL_EastGate": {"rect": Rect2(-10.6, -4.8, 21.2, 9.6), "far": "LL_GateFar", "near": 240.0},
	"LL_RoadGate": {"rect": Rect2(-6.2, -4.4, 12.4, 8.8), "far": "LL_RoadGateFar", "near": 200.0},
	"LL_Wall": {"rect": Rect2(-5.0, -2.0, 10.0, 3.4), "far": "LL_WallFar", "near": 210.0},
	"LL_Postern": {"rect": Rect2(-5.0, -2.0, 10.0, 3.4), "far": "LL_WallFar", "near": 210.0},
	"LL_WallTower": {"rect": Rect2(-4.2, -4.2, 8.4, 8.4), "vis": 0.0},
	"LL_LampTower": {"rect": Rect2(-5.2, -5.2, 10.6, 10.4), "far": "LL_TowerFar", "near": 260.0},
	"LL_Inn": {"rect": Rect2(-10.4, -9.8, 20.8, 18.0), "far": "LL_InnFar", "near": 200.0},
	"LL_Stable": {"rect": Rect2(-9.3, -4.3, 18.6, 10.2), "vis": 240.0},
	"LL_Watch": {"rect": Rect2(-5.3, -3.8, 15.8, 7.6), "vis": 240.0},
	"LL_Store": {"rect": Rect2(-3.9, -3.0, 7.8, 6.0), "vis": 200.0},
	"LL_Shrine": {"rect": Rect2(-1.0, -0.6, 2.0, 2.2), "vis": 110.0},
}

## [town, kind, x, z, yaw]
const PIECES := [
	# --- Reedholm ----------------------------------------------------------------------------------------------------
	["reedholm", "RH_Hall", -300.0, 274.0, -PI * 0.5],
	["reedholm", "RH_House", -302.0, 289.6, -PI * 0.5],
	["reedholm", "RH_HouseLong", -299.0, 257.0, -PI * 0.5],
	["reedholm", "RH_HouseB", -327.0, 291.5, PI * 0.5],
	["reedholm", "RH_Landing", -323.0, 303.6, PI * 0.5],
	["reedholm", "RH_Smokehouse", -325.5, 279.0, PI * 0.5],
	["reedholm", "RH_HeronPole", -318.6, 297.6, PI],
	["reedholm", "RH_Rack", -325.0, 268.0, PI * 0.5 + 0.2],
	["reedholm", "RH_Rack", -330.5, 273.0, PI * 0.5 - 0.1],
	["reedholm", "RH_NetFrame", -327.0, 261.5, 0.3],
	["reedholm", "RH_NetFrame", -309.5, 294.8, 0.1],
	["reedholm", "RH_ReedStack", -321.4, 284.6, 0.0],
	["reedholm", "RH_ReedStack", -320.6, 258.4, 1.0],
	["reedholm", "RH_ReedStack", -332.8, 281.0, 2.0],
	["reedholm", "RH_Punt", -327.9, 300.6, 0.05],
	["reedholm", "RH_Punt", -328.2, 306.4, -0.08],
	["reedholm", "RH_Punt", -292.6, 278.0, 1.62],
	["reedholm", "RH_Punt", -313.6, 266.0, 1.2],
	["reedholm", "RH_Trap", -321.6, 299.0, 0.4],
	["reedholm", "RH_Trap", -313.4, 280.6, 2.1],
	["reedholm", "RH_Trap", -320.4, 271.0, -0.6],
	["reedholm", "RH_Bridge", -284.8, 304.5, -0.077],
	# --- Fallowmere --------------------------------------------------------------------------------------------------
	["fallowmere", "FM_TitheBarn", -178.0, 283.0, 0.0],
	["fallowmere", "FM_Farmhouse", -172.0, 311.0, PI],
	["fallowmere", "FM_Cottage", -136.0, 288.0, 0.0],
	["fallowmere", "FM_Cottage", -128.0, 319.0, PI],
	["fallowmere", "FM_Dovecote", -158.6, 287.0, -0.4],
	["fallowmere", "FM_Well", -140.0, 294.6, 0.3],
	["fallowmere", "FM_Wain", -187.0, 292.6, 0.2],
	["fallowmere", "FM_Rick", -190.0, 306.5, 0.0],
	["fallowmere", "FM_Rick", -197.5, 311.0, 1.0],
	["fallowmere", "FM_Rick", -186.0, 322.0, 2.0],
	["fallowmere", "FM_Scarecrow", -122.0, 350.0, 0.6],
	["fallowmere", "FM_Scarecrow", -113.0, 362.0, -0.3],
	["fallowmere", "FM_Scarecrow", -131.0, 367.0, 0.2],
	["fallowmere", "FM_Scarecrow", -158.0, 334.0, 2.8],
	["fallowmere", "FM_Gate", -150.0, 322.0, 0.0],
	["fallowmere", "FM_Gate", -126.0, 342.0, 0.0],
	# --- Lastlight (its walls are laid by WALLS) ---------------------------------------------------------------------
	["lastlight", "LL_Inn", 330.0, 41.5, 0.0],
	["lastlight", "LL_LampTower", 347.0, 44.0, 0.0],
	["lastlight", "LL_Stable", 311.0, 75.2, PI],
	["lastlight", "LL_Watch", 340.0, 75.0, PI],
	["lastlight", "LL_Store", 299.8, 44.0, PI * 0.5],
	["lastlight", "LL_Shrine", 350.6, 55.6, -PI * 0.5],
	["lastlight", "FM_Well", 325.0, 58.2, 0.0],
	["lastlight", "FM_Wain", 323.0, 74.6, PI + 0.2],
]

## Reedholm's boardwalks: polylines of xz at "walk" height (a house's front steps come down to it) or "deck" height
## (a link between two decks). `end` / `start`: steps down to the bank at that end.
const WALKS := [
	{"pts": [Vector2(-306.9, 274.0), Vector2(-312.4, 274.0)], "h": "walk", "end": true},
	{"pts": [Vector2(-307.2, 288.6), Vector2(-311.6, 288.6)], "h": "walk", "end": true},
	{"pts": [Vector2(-303.6, 257.4), Vector2(-311.0, 257.4)], "h": "walk", "end": true},
	{"pts": [Vector2(-322.0, 292.5), Vector2(-319.2, 292.5)], "h": "walk", "end": true},
	{"pts": [Vector2(-300.0, 281.3), Vector2(-300.0, 285.6)], "h": "deck"},
	{"pts": [Vector2(-299.0, 263.3), Vector2(-299.0, 266.7)], "h": "deck"},
]

## Fallowmere's field edges and fold: runs of hurdles [from, to]; and the stooks' fields [centre, half size, yaw, count].
const HURDLES := [
	[Vector2(-196.0, 316.0), Vector2(-184.0, 316.0)], [Vector2(-184.0, 316.0), Vector2(-184.0, 326.0)],
	[Vector2(-184.0, 326.0), Vector2(-196.0, 326.0)], [Vector2(-196.0, 326.0), Vector2(-196.0, 316.0)],
	[Vector2(-176.0, 322.0), Vector2(-152.0, 322.0)], [Vector2(-148.0, 322.0), Vector2(-136.0, 322.0)],
	[Vector2(-140.0, 342.0), Vector2(-128.0, 342.0)], [Vector2(-124.0, 342.0), Vector2(-104.0, 342.0)],
	[Vector2(-140.0, 356.0), Vector2(-104.0, 356.0)], [Vector2(-140.0, 370.0), Vector2(-108.0, 370.0)],
]
const STOOK_FIELDS := [[Vector2(-163.0, 330.0), Vector2(9.0, 4.5), 0.0, 14], [Vector2(-118.0, 349.0), Vector2(12.0, 3.5), 0.0, 10],
	[Vector2(-124.0, 363.0), Vector2(13.0, 3.5), 0.0, 9]]

## Lastlight's curtain: corners (the towers stand on them) and, per side, what breaks it: a gate or postern by its
## middle along the side. `in` is the town side's yaw (the wall pieces' +z faces into the town).
const WALL_CORNERS := [Vector2(293.0, 26.0), Vector2(356.0, 26.0), Vector2(356.0, 81.0), Vector2(293.0, 81.0)]
const WALLS := [
	{"a": 0, "b": 1, "in": 0.0, "breaks": [["LL_Postern", 302.7]]},          # north: the postern on the Bellfall track
	{"a": 1, "b": 2, "in": -PI * 0.5, "breaks": [["LL_EastGate", 62.8]]},    # east: the shut gate at the road's end
	{"a": 2, "b": 3, "in": PI, "breaks": []},                                 # south
	{"a": 3, "b": 0, "in": PI * 0.5, "breaks": [["LL_RoadGate", 69.5]]},      # west: the road gate
]
const BREAK_W := {"LL_Postern": 10.0, "LL_EastGate": 21.2, "LL_RoadGate": 12.0}
const TOWER_KEEP := 3.4           ## the curtain stops this far from a corner (the tower covers the join)
