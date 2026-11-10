extends RefCounted
## The rift's own stone: the Ossuary kit's ashlar and paving (OssKit materials "stone" and "floor"), paler and with a
## little starlight in them so the crossing, the Threshold's terraces, the stair and the quay read at night (the moon
## never reaches the floor of the rift). Registered once in OssKit's material table under their own keys.

const STONE := "rift_stone"
const FLOOR := "rift_floor"


static func ensure() -> void:
	_make(STONE, "stone", Color(1.3, 1.24, 1.4), 0.22)
	_make(FLOOR, "floor", Color(1.25, 1.2, 1.35), 0.18)


static func _make(key: String, from: String, tint: Color, glow: float) -> void:
	if OssKit._mats.has(key):
		return
	var m := (OssKit.mat(from) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = tint
	m.emission_enabled = true
	m.emission = Color(0.34, 0.26, 0.6)
	m.emission_energy_multiplier = glow
	m.emission_texture = m.albedo_texture
	OssKit._mats[key] = m
