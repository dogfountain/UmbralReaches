extends RefCounted
## THE LAVA PIT's widening (RealmLand reads it while it lays the kept chasm's baked heights): the basin the Crossing spans was a 40 m trench
## with a glowing strip in it. Between the Spindle and the ward landing the walls are drawn back (the baked wall profile is sampled `shift`
## metres nearer the middle), so the lava lies in a bowl up to 16 m wider, its cliffs standing back round it and the stair crossing the
## open flow. The falls, the bank mask, the crust shelf, the basalt cliffs and the features all read the ground itself, so they follow
## the new banks. Nothing south of z -48 changes (the Threshold's starwater pool, the Watchers, the terraces), and nothing north of z -84
## (the summit's pillars and the ward).

const PUSH := 8.0                       ## how far the walls move out at the bowl's widest
const Z_IN := Vector2(-50.0, -60.0)     ## the bowl opens over these z (south end)
const Z_OUT := Vector2(-76.0, -86.0)    ## and closes over these (the summit's approach and pillars keep their ground)


## How far (m, signed to the wall's side) to sample the baked wall nearer the middle at world (x, z): 0 off the bowl and in its floor.
static func shift(x: float, z: float) -> float:
	var b := smoothstep(Z_IN.x, Z_IN.y, z) * (1.0 - smoothstep(Z_OUT.x, Z_OUT.y, z))
	if b <= 0.0:
		return 0.0
	var lx := x - Endgame.O.x
	var d := PUSH * b * smoothstep(9.0, 19.0, absf(lx))
	return d * signf(lx)
