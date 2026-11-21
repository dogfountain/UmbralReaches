extends RefCounted
## THE LAVA PIT (RealmLand reads `shift` while it lays the kept chasm's baked heights). The pit the Crossing spans was a 40 m trench with a
## glowing strip in it. Between the crust plain's end and the summit's feet the walls are drawn back by an irregular amount (a different lobe
## on each side, 5 to 13 m, so the banks bay and the cliffs stand off in headlands): the baked wall profile is sampled that many metres
## nearer the middle, so the lava lies in a bowl up to 26 m wider with a natural outline. The falls (realm_rift.gd FALLS), the bank mask and
## crust shelf (lava_works.gd), the basalt cliffs, the islands and the fissures (rift/features.gd) all read the ground itself and follow
## the new banks (the Cinder Way: the Ward Crag fills its west half; the molten east channel is the wide part). Nothing south of z -50 (the crust plain,
## the Cinder Way's Descent, the Lip, the rim road) and nothing north of
## z -90 (the summit's pillars and the ward) changes.

const PUSH_MIN := 5.0
const PUSH_MAX := 13.0
const Z_IN := Vector2(-51.0, -62.0)     ## the bowl opens over these z (its south end)
const Z_OUT := Vector2(-80.0, -91.0)    ## and closes over these (the summit's approach and pillars keep their ground)


## How far (m, signed to the wall's side) to sample the baked wall nearer the middle at world (x, z): 0 off the bowl and in its floor.
static func shift(x: float, z: float) -> float:
	var b := smoothstep(Z_IN.x, Z_IN.y, z) * (1.0 - smoothstep(Z_OUT.x, Z_OUT.y, z))
	if b <= 0.0:
		return 0.0
	var lx := x - Endgame.O.x
	var side := signf(lx)
	var lobe := 0.5 + 0.5 * (0.6 * sin(z * 0.115 + side * 1.9) + 0.4 * sin(z * 0.29 + side * 4.3 + 1.0))
	var d := lerpf(PUSH_MIN, PUSH_MAX, clampf(lobe, 0.0, 1.0)) * b * smoothstep(9.0, 19.0, absf(lx))
	return d * side


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

