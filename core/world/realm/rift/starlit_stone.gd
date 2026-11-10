extends RefCounted
## The rift's own stone: the Ossuary kit's ashlar and paving (OssKit materials "stone" and "floor"), paler and with a
## little starlight in them so the crossing, the Threshold's terraces, the stair and the quay read at night (the moon
## never reaches the floor of the rift). Registered once in OssKit's material table under their own keys.

const STONE := "rift_stone"
const FLOOR := "rift_floor"


static func ensure() -> void:
	_make(STONE, "stone", Color(1.28, 1.25, 1.3), 0.17)
	_make(FLOOR, "floor", Color(1.24, 1.21, 1.27), 0.14)


static func _make(key: String, from: String, tint: Color, glow: float) -> void:
	if OssKit._mats.has(key):
		return
	var m := (OssKit.mat(from) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = Color(0.3, 0.3, 0.44)       # cold starlight, not violet: the pool lights and the pillars' lanterns carry the violet
	m.emission_energy_multiplier = glow
	m.emission_texture = m.albedo_texture
	OssKit._mats[key] = m
