extends RefCounted
## The wanderer's gear baked into ONE skinned mesh on a runtime Skeleton3D (CharacterRig makes the
## skeleton: one bone per gear driver node, flat, posed every frame from the procedural joints).
## Every generated part (wanderer_gen.gd) is moved to the rig's rest space and skinned rigidly to
## its bone, and its surfaces are folded into three: cloth (all wool layers, one robe-wave shader;
## the per-part hem parameters ride in CUSTOM0/1), gear (leather, iron, wood, stitched straps, carved
## staff, lantern glass: one shader over a Texture2DArray) and orb (the swirl). Plus a low shadow
## proxy (outer cloth, staff, lantern) so the body itself casts no shadow. LODs on the body.
## Cached through GenCache; the key holds the part list, the bone rests and the generator's salt.
## Load by path (no class_name): const WBody := preload("res://core/player/wanderer_body.gd")

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const WGen := preload("res://core/player/wanderer_gen.gd")
const WTex := preload("res://core/player/wanderer_tex.gd")
const SELF := "res://core/player/wanderer_body.gd"
const GEN_SRC := "res://core/player/wanderer_gen.gd"
const CLOTH_SHADER := preload("res://core/player/robe_skin.gdshader")
const GEAR_SHADER := preload("res://core/player/wanderer_gear.gdshader")
const ORB_SHADER := preload("res://core/player/wanderer_orb.gdshader")
const ROBE_MAGIC := "res://art/textures/robe_magic.png"

## cloth surfaces: [tint, magic (rune veins), trim (embroidered band), uv scale, hem grime]
const CLOTH := {
	"cloth": [Color(1, 1, 1), 1.0, 0.0, Vector2(2.2, 2.2), 0.6],
	"tunic": [Color(0.86, 0.78, 0.66), 0.35, 0.0, Vector2(2.6, 2.6), 0.6],
	"lining": [Color(0.4, 0.33, 0.27), 0.0, 0.0, Vector2(3.0, 3.0), 0.0],
	"trim": [Color(1, 1, 1), 0.0, 1.0, Vector2(1.0 / 0.24, 1.0), 0.35],
	"tunic_trim": [Color(1, 1, 1), 0.0, 1.0, Vector2(1.0 / 0.24, 1.0), 0.35],
}
## gear surfaces: [layer (WandererTex.GEAR_LAYERS), tint, uv scale, metallic, emission, runes]
const GEAR := {
	"leather": [0, Color(1, 1, 1), Vector2(5, 5), 0.0, 0.0, 0.0],
	"grip": [0, Color(0.85, 0.8, 0.75), Vector2(6, 14), 0.0, 0.0, 0.0],
	"sole": [0, Color(0.45, 0.42, 0.42), Vector2(6, 6), 0.0, 0.0, 0.0],
	"cord": [0, Color(1.5, 1.3, 1.05), Vector2(2, 8), 0.0, 0.0, 0.0],
	"iron": [1, Color(1, 1, 1), Vector2(4, 4), 0.85, 0.0, 0.0],
	"wood": [2, Color(1.55, 1.45, 1.4), Vector2(1, 1), 0.0, 0.0, 0.0],
	"pants": [3, Color(0.75, 0.72, 0.72), Vector2(3, 3), 0.0, 0.0, 0.0],
	"wrap": [3, Color(1.5, 1.2, 0.8), Vector2(4, 4), 0.0, 0.0, 0.0],
	"strap": [4, Color(1, 1, 1), Vector2(1, 1), 0.0, 0.0, 0.0],
	"staff": [5, Color(1.35, 1.28, 1.22), Vector2(1, 1), 0.0, 0.0, 1.0],
	"glass": [2, Color(1.6, 1.25, 0.8), Vector2(1, 1), 0.0, 1.0, 0.0],
}
## shadow proxy: these parts' outer surfaces only (the lining, trims and small gear cast nothing)
const SHADOW_PARTS := ["coat", "mantle", "hood", "tail", "sleeve", "bell", "staff", "lantern"]
const SHADOW_SURFS := ["cloth", "staff", "wood", "grip", "glass"]

static var _mats := {}


## parts: [[part, bone, wave Vector4], ...]; rests: rig-space rest Transform3D per bone.
## Returns [body ArrayMesh (surfaces named cloth / gear / orb), shadow ArrayMesh].
static func build(parts: Array, rests: Array) -> Array:
	var key := "wanderer_body|%d|%d" % [hash(var_to_str([parts, rests])), GenCache.salt(GEN_SRC)]
	var body := GenCache.load_mesh(key, SELF)
	var shadow := GenCache.load_mesh(key + "|shadow", SELF)
	if body != null and shadow != null:
		return [body, shadow]
	var t0 := Time.get_ticks_msec()
	var acc := {"cloth": _acc(), "gear": _acc(), "orb": _acc()}
	var sh := _acc()
	for e: Array in parts:
		var part: String = e[0]
		var bone: int = e[1]
		var wave: Vector4 = e[2]
		var xf: Transform3D = rests[bone]
		var m := WGen.mesh(part)
		for s in m.get_surface_count():
			var surf := m.surface_get_name(s)
			var arr := m.surface_get_arrays(s)
			if CLOTH.has(surf):
				_add(acc["cloth"], arr, xf, bone, _cloth_attr.bind(part, surf, wave))
			elif surf == "orb":
				_add(acc["orb"], arr, xf, bone, _orb_attr)
			else:
				_add(acc["gear"], arr, xf, bone, _gear_attr.bind(part, surf))
			if part in SHADOW_PARTS and surf in SHADOW_SURFS:
				_add(sh, arr, xf, bone, Callable())
	var im := ImporterMesh.new()
	for n: String in ["cloth", "gear", "orb"]:
		var a: Dictionary = acc[n]
		if (a["P"] as PackedVector3Array).is_empty():
			continue
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, _arrays(a, n != "orb"), [], {}, null, n, _flags())
	im.generate_lods(25.0, 60.0, [])
	body = im.get_mesh()
	shadow = _shadow_mesh(sh)
	GenCache.save_mesh(key, SELF, body)
	GenCache.save_mesh(key + "|shadow", SELF, shadow)
	print("WANDERER body baked: %d parts, %d ms" % [parts.size(), Time.get_ticks_msec() - t0])
	return [body, shadow]


static func _flags() -> int:
	return (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)


static func _acc() -> Dictionary:
	return {"P": PackedVector3Array(), "N": PackedVector3Array(), "T": PackedFloat32Array(), "UV": PackedVector2Array(),
		"C": PackedColorArray(), "C0": PackedFloat32Array(), "C1": PackedFloat32Array(), "B": PackedInt32Array(),
		"W": PackedFloat32Array(), "I": PackedInt32Array()}


## Appends one source surface (part-local) moved by xf to the rig's rest space. attr(p_local, uv)
## returns [uv, color, custom0 (Vector4), custom1 (Vector4)] per vertex (null for the shadow).
static func _add(a: Dictionary, arr: Array, xf: Transform3D, bone: int, attr: Callable) -> void:
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var tan: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT] if arr[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var P: PackedVector3Array = a["P"]
	var N: PackedVector3Array = a["N"]
	var T: PackedFloat32Array = a["T"]
	var UV: PackedVector2Array = a["UV"]
	var C: PackedColorArray = a["C"]
	var C0: PackedFloat32Array = a["C0"]
	var C1: PackedFloat32Array = a["C1"]
	var B: PackedInt32Array = a["B"]
	var W: PackedFloat32Array = a["W"]
	var I: PackedInt32Array = a["I"]
	var base := P.size()
	var bas := xf.basis
	var full := attr.is_valid()
	for i in pos.size():
		P.append(xf * pos[i])
		N.append((bas * nrm[i]).normalized())
		B.append_array([bone, 0, 0, 0])
		W.append_array([1.0, 0.0, 0.0, 0.0])
		if not full:
			continue
		if tan.size() >= (i + 1) * 4:
			var tv := (bas * Vector3(tan[i * 4], tan[i * 4 + 1], tan[i * 4 + 2])).normalized()
			T.append_array([tv.x, tv.y, tv.z, tan[i * 4 + 3]])
		else:
			T.append_array([1.0, 0.0, 0.0, 1.0])
		var r: Array = attr.call(pos[i], uv[i] if i < uv.size() else Vector2.ZERO)
		UV.append(r[0])
		C.append(r[1])
		var c0: Vector4 = r[2]
		var c1: Vector4 = r[3]
		C0.append_array([c0.x, c0.y, c0.z, c0.w])
		C1.append_array([c1.x, c1.y, c1.z, c1.w])
	for k in idx:
		I.append(base + k)
	a["P"] = P
	a["N"] = N
	a["T"] = T
	a["UV"] = UV
	a["C"] = C
	a["C0"] = C0
	a["C1"] = C1
	a["B"] = B
	a["W"] = W
	a["I"] = I


static func _arrays(a: Dictionary, tangents: bool) -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a["P"]
	arr[Mesh.ARRAY_NORMAL] = a["N"]
	if tangents:
		arr[Mesh.ARRAY_TANGENT] = a["T"]
	arr[Mesh.ARRAY_TEX_UV] = a["UV"]
	arr[Mesh.ARRAY_COLOR] = a["C"]
	arr[Mesh.ARRAY_CUSTOM0] = a["C0"]
	arr[Mesh.ARRAY_CUSTOM1] = a["C1"]
	arr[Mesh.ARRAY_BONES] = a["B"]
	arr[Mesh.ARRAY_WEIGHTS] = a["W"]
	arr[Mesh.ARRAY_INDEX] = a["I"]
	return arr


## A coarse copy of the outer cloth, staff and lantern: the coarsest LOD above ~2.5k triangles,
## compacted to the vertices it uses. Positions, normals and bones only.
static func _shadow_mesh(a: Dictionary) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a["P"]
	arr[Mesh.ARRAY_NORMAL] = a["N"]
	arr[Mesh.ARRAY_BONES] = a["B"]
	arr[Mesh.ARRAY_WEIGHTS] = a["W"]
	arr[Mesh.ARRAY_INDEX] = a["I"]
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "shadow")
	im.generate_lods(60.0, 60.0, [])
	var idx: PackedInt32Array = a["I"]
	for l in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, l)
		if li.size() < 7500:
			break
		idx = li
	var remap := {}
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	var B := PackedInt32Array()
	var W := PackedFloat32Array()
	var I := PackedInt32Array()
	var src_p: PackedVector3Array = a["P"]
	var src_n: PackedVector3Array = a["N"]
	var src_b: PackedInt32Array = a["B"]
	for k in idx:
		if not remap.has(k):
			remap[k] = P.size()
			P.append(src_p[k])
			N.append(src_n[k])
			B.append_array([src_b[k * 4], 0, 0, 0])
			W.append_array([1.0, 0.0, 0.0, 0.0])
		I.append(remap[k])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = P
	out[Mesh.ARRAY_NORMAL] = N
	out[Mesh.ARRAY_BONES] = B
	out[Mesh.ARRAY_WEIGHTS] = W
	out[Mesh.ARRAY_INDEX] = I
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	m.surface_set_name(0, "shadow")
	return m


# --- per-vertex attributes ----------------------------------------------------------------------

## Cloth: CUSTOM0 = part-local position + hem weight (the robe wave works in the part's own space),
## CUSTOM1 = leg push, wave scale, trim flag, hem grime; COLOR = tint x baked occlusion, a = veins.
static func _cloth_attr(p: Vector3, uv: Vector2, part: String, surf: String, wave: Vector4) -> Array:
	var c: Array = CLOTH[surf]
	var w := clampf((wave.x - p.y) / maxf(wave.y, 0.001), 0.0, 1.0)
	var ao := _ao(part, surf, p)
	var tint: Color = c[0]
	var col := Color(tint.r * ao, tint.g * ao, tint.b * ao, float(c[1]))
	var uvs: Vector2 = c[3]
	return [uv * uvs, col, Vector4(p.x, p.y, p.z, w), Vector4(wave.z, wave.w, float(c[2]), float(c[4]))]


## Gear: CUSTOM0 = tint + metallic, CUSTOM1 = texture layer, emission, rune glow; COLOR = occlusion.
static func _gear_attr(p: Vector3, uv: Vector2, part: String, surf: String) -> Array:
	var g: Array = GEAR.get(surf, GEAR["leather"])
	var tint: Color = g[1]
	var emis := float(g[4])
	var rune := float(g[5])
	if surf == "glass":
		emis = 0.55 + 0.45 * sin(clampf((-0.126 - p.y) / 0.186, 0.0, 1.0) * PI)    # brightest mid-drum
	if surf == "staff":
		rune = smoothstep(0.22, 0.4, p.y) * smoothstep(1.06, 0.95, p.y)          # the upper shaft glows
	var ao := _ao(part, surf, p)
	var uvs: Vector2 = g[2]
	return [uv * uvs, Color(ao, ao, ao, 1.0), Vector4(tint.r, tint.g, tint.b, float(g[3])), Vector4(float(g[0]), emis, rune, 0.0)]


static func _orb_attr(p: Vector3, uv: Vector2) -> Array:
	return [uv, Color(1, 1, 1, 1), Vector4(p.x, p.y, p.z, 0.0), Vector4.ZERO]


## Baked occlusion (part-local heuristics): the hood darkens toward its depths so the void face sits
## in a real shadow; linings are dim; the coat darkens under the mantle and the belt and toward the
## hem's inside; sleeve undersides, boot welts and the cup under the orb a little.
static func _ao(part: String, surf: String, p: Vector3) -> float:
	match part:
		"hood":
			var front := smoothstep(-0.05, -0.2, p.z)                       # 1 at the face opening
			if surf == "lining":
				return lerpf(0.22, 0.75, front) * lerpf(0.75, 1.0, smoothstep(-0.12, 0.1, p.y))
			if surf == "tunic":
				return lerpf(0.35, 0.85, smoothstep(-0.08, -0.2, p.z))
			return lerpf(0.82, 1.0, smoothstep(-0.14, -0.02, p.y))
		"coat":
			if surf == "lining":
				return 0.55
			if surf == "tunic" or surf == "tunic_trim":
				return lerpf(0.55, 0.85, smoothstep(WGen.BELT_Y, WGen.BELT_Y - 0.3, p.y))
			var under_mantle := 1.0 - 0.3 * exp(-pow((p.y + 0.02) / 0.09, 2.0))
			var under_belt := 1.0 - 0.22 * exp(-pow((p.y - (WGen.BELT_Y - 0.04)) / 0.04, 2.0))
			var top := lerpf(0.86, 1.0, smoothstep(0.3, 0.2, p.y))           # in the mantle's shade
			return under_mantle * under_belt * top
		"mantle":
			return 0.6 if surf == "lining" else lerpf(0.9, 1.0, smoothstep(0.3, 0.2, p.y))
		"sleeve":
			return lerpf(0.72, 1.0, smoothstep(0.07, -0.05, p.y))              # under the mantle
		"bell":
			return 0.55 if surf == "lining" else lerpf(0.82, 1.0, smoothstep(-0.27, -0.12, p.y) * 0.5 + 0.5)
		"tail":
			return lerpf(0.85, 1.0, smoothstep(-0.2, 0.0, p.y))
		"boot":
			return lerpf(0.7, 1.0, smoothstep(0.0, 0.05, p.y))
		"staff":
			if p.y > 1.12:
				return lerpf(0.7, 1.0, smoothstep(1.15, 1.32, p.y))
	return 1.0


# --- materials ----------------------------------------------------------------------------------

static func material(surf: String) -> Material:
	if _mats.has(surf):
		return _mats[surf]
	var m := ShaderMaterial.new()
	match surf:
		"cloth":
			m.shader = CLOTH_SHADER
			m.set_shader_parameter("wool_tex", WTex.tex("wool"))
			m.set_shader_parameter("wool_n", WTex.tex("wool_n"))
			m.set_shader_parameter("trim_tex", WTex.tex("trim"))
			m.set_shader_parameter("trim_n", WTex.tex("trim_n"))
			var magic := load(ROBE_MAGIC) as Texture2D
			if magic:
				m.set_shader_parameter("magic_tex", magic)
		"gear":
			m.shader = GEAR_SHADER
			m.set_shader_parameter("albedo_arr", WTex.array(false))
			m.set_shader_parameter("normal_arr", WTex.array(true))
		_:
			m.shader = ORB_SHADER
	m.resource_name = "wanderer_" + surf
	_mats[surf] = m
	return m
