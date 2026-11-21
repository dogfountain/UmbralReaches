extends RefCounted
## THE LAVA PIT (RealmLand reads `shift` while it lays the kept chasm's baked heights). The pit the Crossing spans was a 40 m trench with a
## glowing strip in it. Between the crust plain's end and the summit's feet the walls are drawn back by an irregular amount (a different lobe
## on each side, 5 to 13 m, so the banks bay and the cliffs stand off in headlands): the baked wall profile is sampled that many metres
## nearer the middle, so the lava lies in a bowl up to 26 m wider with a natural outline. The east wall goes further, and further south:
## from the crust plain's north end (E_IN) it stands back 11 to 15 m, so the molten lake fills the rift wall to wall from the Foot to the
## crag and round it (21 Nov: from the air the lake had read as a strip between banks). The west wall stays where it is south of the bowl:
## the Descent's ledge, the Foot, the chapel branch and the Pilgrims' Chapel are built into it. The old Ossuary's site on the east wall is
## bare rock (RealmLayout.OSSUARY_OLD). The falls (realm_rift.gd FALLS), the bank mask and crust shelf (lava_works.gd), the basalt cliffs,
## the islands and the fissures (rift/features.gd) all read the ground itself and follow the new banks. Nothing within 9 m of the
## centreline moves (the Lip, the rim road, the causeway's line), and nothing north of z -91 (the summit's pillars and the ward).

const PUSH_MIN := 5.0
const PUSH_MAX := 13.0
const Z_IN := Vector2(-51.0, -62.0)     ## the bowl opens over these z (its south end)
const Z_OUT := Vector2(-80.0, -91.0)    ## and closes over these (the summit's approach and pillars keep their ground)
const E_IN := Vector2(-12.0, -22.0)     ## the east wall starts back over these z (the crust plain's north end), all the way to Z_OUT
const E_PUSH := Vector2(11.0, 15.0)     ## ... by this much (lobed): the kept core reaches x +30, so the lake's east shore stands near x 31


## How far (m, signed to the wall's side) to sample the baked wall nearer the middle at world (x, z): 0 off the bowl and in its floor.
static func shift(x: float, z: float) -> float:
	var lx := x - Endgame.O.x
	var side := signf(lx)
	var b := smoothstep(Z_IN.x, Z_IN.y, z) * (1.0 - smoothstep(Z_OUT.x, Z_OUT.y, z))
	var e := smoothstep(E_IN.x, E_IN.y, z) * (1.0 - smoothstep(Z_OUT.x, Z_OUT.y, z)) if side > 0.0 else 0.0
	if b <= 0.0 and e <= 0.0:
		return 0.0
	var lobe := clampf(0.5 + 0.5 * (0.6 * sin(z * 0.115 + side * 1.9) + 0.4 * sin(z * 0.29 + side * 4.3 + 1.0)), 0.0, 1.0)
	var d := maxf(lerpf(PUSH_MIN, PUSH_MAX, lobe) * b, lerpf(E_PUSH.x, E_PUSH.y, lobe) * e)
	return d * smoothstep(9.0, 19.0, absf(lx)) * side


## (the Cinder Way) Ground the way's first landing needs cut back: the rim's slope stood 1.5 m into the landing's south-west corner
## (rift/crossing.gd L1: x -21..-15.3, z -6.6..-12.4, walk -4.07). The ground there is laid no higher than CUT_Y, easing back over 2 m;
## the Descent's ledge stands over it.
const CUT := Rect2(-23.5, -12.5, 8.0, 7.2)
const CUT_Y := -4.9


static func carve(x: float, z: float, h: float) -> float:
	var lx := x - Endgame.O.x
	var d := maxf(maxf(CUT.position.x - lx, lx - CUT.end.x), maxf(CUT.position.y - z, z - CUT.end.y))
	if d >= 2.0:
		return h
	return lerpf(minf(h, CUT_Y), h, smoothstep(0.0, 2.0, d))

