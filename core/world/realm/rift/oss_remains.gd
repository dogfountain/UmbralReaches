extends RefCounted
## What the Ossuary left on the rift's east wall (it was moved under the Waiting Field): five of the piers it
## hung on, snapped at different heights, standing in the lava along the wall, with a corbel or two still
## in the rock. Visual only (no collision: nobody walks there), built from the Ossuary's own kit.

const LAVA := -15.5
## [x, z, broken top y, width]
const PIERS := [[20.5, -31.0, 4.0, 2.2], [18.5, -49.0, 9.5, 2.0], [19.0, -63.0, 1.5, 2.0], [14.5, -79.0, 6.0, 2.2], [22.0, -93.0, -3.5, 2.0]]


static func build(host: Node3D) -> void:
	var k := OssKit.new()
	k.keep_lanes = false
	for p: Array in PIERS:
		var x: float = p[0]
		var z: float = p[1]
		var top: float = p[2]
		var w: float = p[3]
		var wl := w * 1.3
		var mid := lerpf(LAVA, top, 0.4)
		k.block("stone", Vector3(x - wl * 0.5, LAVA - 1.0, z - wl * 0.5), Vector3(x + wl * 0.5, mid, z + wl * 0.5), false)
		k.block("stone", Vector3(x - w * 0.5, mid, z - w * 0.5), Vector3(x + w * 0.5, top, z + w * 0.5), false)
		k.box("stone", Vector3(x, mid + 0.1, z), Vector3(wl + 0.1, 0.35, wl + 0.1), Basis.IDENTITY, false, 0.8)
		var y := mid + 4.0
		while y < top - 1.0:
			k.box("stone", Vector3(x, y, z), Vector3(w + 0.22, 0.22, w + 0.22), Basis.IDENTITY, false, 0.78)
			y += 4.0
		# the snapped end: a fallen block hanging off one corner
		k.box("stone", Vector3(x + w * 0.45, top - 0.35, z + w * 0.3), Vector3(w * 0.7, 0.7, w * 0.6), Basis(Vector3.FORWARD, 0.35), false, 0.82)
	k.commit(host, "OssRemainsBody")
