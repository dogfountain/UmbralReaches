extends RefCounted
## Keeps the painted albedo/normal maps. Strips the extra AO, detail-UV, and
## clearcoat pass that doubled samples on trunks and stone.


const ALL := [
	"res://art/materials/stone.tres",
	"res://art/materials/rock.tres",
	"res://art/materials/bark.tres",
	"res://art/materials/bark_giant.tres",
	"res://art/materials/iron.tres",
	"res://art/materials/coals.tres",
	"res://art/materials/crystal.tres",
]


static func apply() -> void:
	for path in ALL:
		var m := load(path) as StandardMaterial3D
		if m == null:
			continue
		# Keep painted albedo/normal/roughness. Strip AO + detail overlays that doubled samples.
		m.ao_enabled = false
		m.ao_texture = null
		m.detail_enabled = false
		m.clearcoat_enabled = false
		if m.uv1_triplanar:
			m.uv1_triplanar_sharpness = minf(m.uv1_triplanar_sharpness, 2.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
