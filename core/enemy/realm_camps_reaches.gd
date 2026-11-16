extends RefCounted
## The Far Reaches' camps (docs/far_reaches.md; EnemySpawner.REALM_CAMPS ends with these). Each stands where the
## land and the place give it a reason, at its region's tier (Tiers.REGION_BASE: the country round the two towns
## 2, the wild between them 3, the far corners 4) with its region's roster (Tiers.REGION_POOL / REGION_VARIANT):
##   guard   holding a landmark's approach or a gate          lair    a nest, a den, a ruin they live in
##   choke   a ford, a bridge's foot, a pass on a way          patrol  a round along a road or over open ground,
##                                                                     kept PATROL_MARGIN off the towns
## Positions come from the contract's anchors and slots (RealmReaches.SLOTS, KEEP_C, CRATER_C, NAVE_C, TOWN_E/F,
## ARCH_Z); every camp is 10 m+ inside the bounds, 13 m+ from every fire, 4 m+ off the ways and CAMP_MARGIN past
## the safe places (SpawnRules), and the spawner sets it on fair ground near its point when a place built over it
## (EnemySpawner._camp_move). "name" is for the audit and the map (zz/spawn_audit); the spawner ignores it.
## Same schema as EnemySpawner.REALM_CAMPS: at (y 60, probe 0: the ground is found under it), kinds ("kind@look"),
## r (ring radius), patrol (xz stops).

const CAMPS: Array[Dictionary] = [
	# --- the Greyfell (tier 4): the Order's western keep, its garrison never stood down. Stone-bound bulwarks hold
	# the gate where fell_track climbs to the crag, the bailey and the scree are lairs, a watch walks the fell.
	{"name": "the keep's gate", "at": Vector3(-326.0, 60.0, -70.0), "kinds": ["bulwark@stonebound", "bulwark@stonebound", "chanter", "husk@stonebound"], "probe": 0.0, "r": 2.8},      # on the keep's terrace (a site of the keep itself)
	{"name": "the keep's west bailey", "at": Vector3(-336.0, 60.0, -78.0), "kinds": ["husk@stonebound", "leaper@stonebound", "quiller", "husk"], "probe": 0.0},
	{"name": "the scree east of the crag", "at": Vector3(-276.0, 60.0, -96.0), "kinds": ["leaper@stonebound", "leaper@stonebound", "gaunt"], "probe": 0.0, "r": 3.0},
	{"name": "the fell watch", "at": Vector3(-298.0, 60.0, -86.0), "kinds": ["husk@stonebound", "bulwark@stonebound", "husk@stonebound"], "probe": 0.0,
		"patrol": [Vector2(-298, -86), Vector2(-282, -84), Vector2(-276, -70), Vector2(-294, -72)]},
	# --- the Lanternwood (tier 3): what grows in the dead. A mite nest in the deep wood, leapers at its north edge,
	# the pilgrims who turned back at the Last Milestone, and a pack that walks the road's last stretch.
	{"name": "the deep wood's nest", "at": Vector3(-346.0, 60.0, -34.0), "kinds": ["mite", "mite", "mite", "mite", "crawler"], "probe": 0.0, "r": 1.8},
	{"name": "the wood's north edge", "at": Vector3(-282.0, 60.0, -30.0), "kinds": ["leaper", "crawler", "spitter"], "probe": 0.0},
	{"name": "the Last Milestone", "at": Vector3(-344.0, 60.0, 28.0), "kinds": ["wretch", "husk", "gaunt"], "probe": 0.0},
	{"name": "the road's last stretch", "at": Vector3(-312.0, 60.0, 42.0), "kinds": ["gaunt", "gaunt", "crawler"], "probe": 0.0,
		"patrol": [Vector2(-312, 42), Vector2(-328, 40), Vector2(-344, 38), Vector2(-328, 42)]},
	# --- the Kings' Barrows (tier 3): barrow-wights between the mounds, the kings' war-band on the ridge's shoulder,
	# the dead who lie along the stone row (they rise as you walk it), a round along the ridge's back.
	{"name": "between the barrows", "at": Vector3(-344.0, 60.0, 120.0), "kinds": ["ossuant", "ossuant", "quiller"], "probe": 0.0},
	{"name": "the stone row", "at": Vector3(-294.0, 60.0, 134.0), "kinds": ["pilgrim", "pilgrim", "pilgrim", "pilgrim"], "probe": 0.0, "r": 3.4},
	{"name": "the ridge's south shoulder", "at": Vector3(-296.0, 60.0, 196.0), "kinds": ["husk", "bulwark", "chanter"], "probe": 0.0},
	{"name": "the ridge round", "at": Vector3(-338.0, 60.0, 178.0), "kinds": ["ossuant", "husk", "quiller"], "probe": 0.0,
		"patrol": [Vector2(-338, 178), Vector2(-340, 202), Vector2(-332, 216), Vector2(-334, 190)]},
	# --- the Reedmere (tier 3): the drowned in the meres, spitters in the reeds, a guard on the ford's far bank
	# (reed_ford crosses the Sorrow there); Reedholm itself is a safe place.
	{"name": "the north meres", "at": Vector3(-352.0, 60.0, 250.0), "kinds": ["husk@drowned", "spitter", "wretch@drowned"], "probe": 0.0},
	{"name": "the east reeds", "at": Vector3(-252.0, 60.0, 352.0), "kinds": ["spitter", "spitter", "husk@drowned"], "probe": 0.0},
	{"name": "the ford's far bank", "at": Vector3(-262.0, 60.0, 318.0), "kinds": ["husk@drowned", "wretch@drowned", "burrower"], "probe": 0.0},
	# --- Fallowmere (tier 2): what roots in the fallow fields, a round on the waste under the scarp, and one along
	# reed_ford half-way to Reedholm (the hamlet is a safe place; the Scarecrow holds the strips: guardians.gd).
	{"name": "the far fields", "at": Vector3(-196.0, 60.0, 366.0), "kinds": ["burrower", "burrower", "crawler"], "probe": 0.0},
	{"name": "the waste under the scarp", "at": Vector3(-186.0, 60.0, 250.0), "kinds": ["gaunt", "gaunt", "wretch"], "probe": 0.0,
		"patrol": [Vector2(-186, 250), Vector2(-198, 244), Vector2(-190, 230), Vector2(-174, 236)]},
	{"name": "the ford road", "at": Vector3(-212.0, 60.0, 314.0), "kinds": ["husk", "wretch", "crawler"], "probe": 0.0,
		"patrol": [Vector2(-212, 314), Vector2(-226, 312), Vector2(-224, 288), Vector2(-208, 290)]},
	# --- the Long Arches (tier 3): the Order's water-keepers under the aqueduct, leapers in the broken span's rubble,
	# husks among the piers, a pack along arches_way in the valley (the Water-Bailiff holds the castellum).
	{"name": "the valley under the arches", "at": Vector3(30.0, 60.0, 368.0), "kinds": ["husk", "quiller", "leaper"], "probe": 0.0},
	{"name": "the broken span's rubble", "at": Vector3(58.0, 60.0, 284.0), "kinds": ["leaper", "leaper", "gaunt"], "probe": 0.0, "r": 3.0},
	{"name": "the west piers", "at": Vector3(-30.0, 60.0, 354.0), "kinds": ["husk", "chanter", "quiller"], "probe": 0.0, "r": 2.6},
	{"name": "the valley road", "at": Vector3(14.0, 60.0, 332.0), "kinds": ["gaunt", "leaper", "crawler"], "probe": 0.0,
		"patrol": [Vector2(14, 332), Vector2(34, 330), Vector2(36, 310), Vector2(12, 312)]},
	# --- the Southwood (tier 3): the charcoal burners stayed (cinder casters in their clearing), gaunts hunt the
	# holly, leapers at the wood's north-east edge, a mite nest in the deep wood (the Hollow-Witch holds her hollow).
	{"name": "the burners' clearing", "at": Vector3(130.0, 60.0, 352.0), "kinds": ["cinder", "cinder", "husk", "wretch"], "probe": 0.0, "r": 2.8},
	{"name": "the holly brakes", "at": Vector3(212.0, 60.0, 320.0), "kinds": ["gaunt", "gaunt", "leaper"], "probe": 0.0,
		"patrol": [Vector2(212, 320), Vector2(228, 334), Vector2(206, 344), Vector2(194, 328)]},
	{"name": "the wood's north-east edge", "at": Vector3(243.0, 60.0, 260.0), "kinds": ["leaper", "crawler", "crawler"], "probe": 0.0},
	{"name": "the deep wood's nest", "at": Vector3(178.0, 60.0, 378.0), "kinds": ["mite", "mite", "mite", "mite", "mite"], "probe": 0.0, "r": 1.6},
	# --- the Bellfall (tier 4): the bell's heat on the crater's west shoulder (cinder casters, a bulwark), tollmen on
	# the east rim who ring when you come, a round south of bell_link (the Eighth Ringer holds the bell on the floor).
	{"name": "the crater's west shoulder", "at": Vector3(272.0, 60.0, -108.0), "kinds": ["cinder", "cinder", "bulwark"], "probe": 0.0, "r": 2.8},
	{"name": "the crater's east rim", "at": Vector3(346.0, 60.0, -88.0), "kinds": ["tollman", "husk", "gaunt"], "probe": 0.0},
	{"name": "the round below bell_link", "at": Vector3(270.0, 60.0, -66.0), "kinds": ["husk", "gaunt", "wretch"], "probe": 0.0,
		"patrol": [Vector2(270, -66), Vector2(280, -64), Vector2(284, -50), Vector2(264, -52)]},
	# --- Lastlight (tier 2): the walled waystation is a safe place, and the road from Saltmarket to its gate is the
	# salt carter's (village_cast_travellers.gd): a camp at bell_track's lower bend only.
	{"name": "bell_track's lower bend", "at": Vector3(290.0, 60.0, -14.0), "kinds": ["wretch", "husk", "crawler"], "probe": 0.0},
	# --- the road west of Weirford (tier 3, the Lanternwood and the Barrows' edge): a pack walks both verges between
	# the town and fell_track, clear of the town and west of the nav tiles' seam at x -262 (a path across it goes the
	# long way round)
	{"name": "the road west of Weirford", "at": Vector3(-268.0, 60.0, 74.0), "kinds": ["gaunt", "husk", "wretch"], "probe": 0.0,
		"patrol": [Vector2(-268, 74), Vector2(-286, 72), Vector2(-288, 48), Vector2(-268, 46)]},
	# --- the Drowned Nave (tier 3): the drowned come out of the nave's water onto its shores (the Precentor holds
	# the nave's door).
	{"name": "the nave's east shore", "at": Vector3(348.0, 60.0, 124.0), "kinds": ["husk@drowned", "spitter", "wretch@drowned"], "probe": 0.0},
	{"name": "the nave's south shore", "at": Vector3(298.0, 60.0, 212.0), "kinds": ["ossuant@drowned", "chanter", "ossuant"], "probe": 0.0},
	# --- the Thousand Cairns (tier 4): pilgrims who turned back lie under the north cairns (they rise as you pass),
	# gaunts walk the heath, and the windward cairns past the tower (the Cairn-Warden holds its foot).
	{"name": "the north cairns", "at": Vector3(346.0, 60.0, 270.0), "kinds": ["pilgrim", "pilgrim", "pilgrim", "chanter"], "probe": 0.0, "r": 3.2},
	{"name": "the south cairns", "at": Vector3(302.0, 60.0, 368.0), "kinds": ["gaunt", "gaunt", "husk"], "probe": 0.0,
		"patrol": [Vector2(302, 368), Vector2(322, 378), Vector2(340, 362), Vector2(318, 350)]},
	{"name": "the windward cairns", "at": Vector3(350.0, 60.0, 338.0), "kinds": ["quiller", "husk", "leaper"], "probe": 0.0},
]
