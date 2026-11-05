extends RefCounted
## Encounters: enemy variants as data. A variant is a stat change (before the pawn enters the
## tree) plus a look (after its body is dressed): extra CreatureMesh parts on the rig's sockets --
## armour scraps, glowing marks, bone spurs -- and its own copy of the kind's flesh material with
## the variant's glow colour (eyes and marks). Parts are cached per (variant, kind) in memory and
## through GenCache, so a variant costs a few shared meshes, one material and ~3 draws per pawn.
##
##   scarred   tier 1+  ember claw-scars across the chest and arms, a brand on the brow; tougher
##   ironclad  tier 2+  scavenged iron: breastplate and rivets, pauldrons, a dented half-helm, a
##                       chain; heavy poise, a little slower
##   tideborn  the Gloom tide's hunters: violet spiral marks, wisps rising off the shoulders,
##                       violet tears; fast, and they track you
##   deeper    the Deeper Night (NG+): bone spurs, cold blue cracks, the open door branded on the
##                       chest; bigger and harder
## Quadrupeds (crawler, leaper) get the same ideas laid along the back and flanks.

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF_PATH := "res://core/life/encounters/variants.gd"
const CM_PATH := "res://core/enemy/creature_mesh.gd"
const Tiers := preload("res://core/life/encounters/tiers.gd")
const KinLook := preload("res://core/enemy/kin_look.gd")

const VARIANTS := {
	"scarred": {"label": "Scarred", "glow": Color(1.9, 0.55, 0.12), "hp": 1, "poise": 0.6, "scale": 1.06, "pace": 1.0},
	"ironclad": {"label": "Ironclad", "glow": Color(1.6, 0.85, 0.35), "hp": 2, "poise": 1.6, "scale": 1.08, "pace": 0.94},
	"tideborn": {"label": "Tide-born", "glow": Color(2.6, 0.3, 1.5), "hp": 0, "poise": 0.0, "scale": 1.0, "pace": 1.12},
	"deeper": {"label": "Deeper", "glow": Color(0.5, 1.25, 2.9), "hp": 2, "poise": 1.0, "scale": 1.14, "pace": 1.05},
}

const IRON := Color(0.3, 0.29, 0.32)
const RUST := Color(0.46, 0.27, 0.17)
const BONE := Color(0.95, 0.92, 0.84)
const SCAR := Color(0.55, 0.12, 0.1)

static var _parts := {}     # "variant/kind" -> {socket: ArrayMesh}
static var _mats := {}      # "variant/kind" -> ShaderMaterial


## The base kind of an enemy (its script or the nearest kind script it extends).
static func kind_of(e: Node) -> String:
	# r31: a kind built on another's body (a Gaunt on the Wretch's) dresses as that body
	var lk: Variant = e.get("look_kind")
	if lk is String and String(lk) != "":
		return String(lk)
	var s := e.get_script() as Script
	while s != null:
		for k: String in Tiers.KIND_PATHS:
			if s.resource_path == Tiers.KIND_PATHS[k]:
				return k
		s = s.get_base_script()
	return "wretch"


## Stats: call before add_child (Enemy._ready copies max_hp into hp).
static func pre(e: Node, variant: String) -> void:
	var v: Dictionary = VARIANTS.get(variant, {})
	if v.is_empty():
		return
	var hp := int(e.get("max_hp")) + int(v.hp)
	e.set("max_hp", hp)
	e.set("hp", float(hp))
	e.set("poise", float(e.get("poise")) + float(v.poise))
	e.set("walk_speed", float(e.get("walk_speed")) * float(v.pace))
	e.set_meta(&"enc_variant", variant)


## Look: call once the pawn's body is dressed (after its _ready).
static func dress(e: Node, variant: String) -> void:
	if not VARIANTS.has(variant) or e.has_meta(&"enc_dressed"):
		return
	var rig: Node3D = e.get("_rig")
	if rig == null:
		return
	e.set_meta(&"enc_dressed", variant)
	var kind := kind_of(e)
	var quad := rig is QuadRig
	var parts := parts_for(variant, kind, rig)
	var mat := material(variant, kind)
	var flesh: Array[MeshInstance3D] = []
	var have: Variant = e.get("_flesh")
	if have is Array:
		for mi in have:
			if is_instance_valid(mi):
				(mi as MeshInstance3D).material_override = mat
				flesh.append(mi)
	for sock: String in parts:
		var at := rig.call("socket", sock) as Node3D
		if at == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Enc_" + variant + "_" + sock
		mi.mesh = parts[sock]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(mi)
		flesh.append(mi)
	if e.has_method("set_flesh"):
		e.call("set_flesh", flesh)
	var s: float = float(VARIANTS[variant].scale)
	if not is_equal_approx(s, 1.0):
		rig.scale *= s
		e.set("hp_bar_y", float(e.get("hp_bar_y")) * s)
	if quad and variant == "ironclad":
		e.set("leap_cooldown", float(e.get("leap_cooldown")) + 0.6)


## One material per (variant, kind): the kind's flesh with the variant's glow colour.
static func material(variant: String, kind: String, glow := Color(0, 0, 0, 0)) -> ShaderMaterial:
	var key := variant + "/" + kind
	if _mats.has(key):
		return _mats[key]
	var base := KinLook.material(kind) if KinLook.has(kind) else EnemyBody.material(StringName(kind))
	var m := base.duplicate() as ShaderMaterial
	var c: Color = glow if glow.a > 0.0 else VARIANTS.get(variant, {}).get("glow", Color(1, 0.4, 0.1))
	m.set_shader_parameter("eye_col", c)
	if variant == "deeper":
		m.set_shader_parameter("rim_col", Color(0.3, 0.55, 1.0))
	elif variant == "tideborn":
		m.set_shader_parameter("rim_col", Color(0.6, 0.3, 1.0))
	_mats[key] = m
	return m


## Cached parts: memory, then GenCache, then built.
static func parts_for(variant: String, kind: String, rig: Node3D) -> Dictionary:
	var key := variant + "/" + kind
	if _parts.has(key):
		return _parts[key]
	var quad := rig is QuadRig
	var shape := "h"
	if quad:
		var q := rig as QuadRig
		shape = "q%.2f_%.2f" % [q.body_len, q.body_height]
	var parts := cached("enc_var_%s_%s_%s" % [variant, kind, shape], func() -> Dictionary:
		return _quad(variant, kind, rig as QuadRig) if quad else _humanoid(variant, kind))
	_parts[key] = parts
	return parts


## GenCache wrapper shared with the elites: `key` -> {socket: ArrayMesh}.
static func cached(key: String, build: Callable, script_path := SELF_PATH) -> Dictionary:
	var full := "%s_%d" % [key, GenCache.salt(CM_PATH)]
	var joints: Variant = GenCache.load_var(full + "_joints", script_path)
	if joints is PackedStringArray:
		var got := {}
		for j: String in joints:
			var m := GenCache.load_mesh(full + "_" + j, script_path)
			if m == null:
				got.clear()
				break
			got[j] = m
		if not got.is_empty():
			return got
	var parts: Dictionary = build.call()
	var names := PackedStringArray()
	for j: String in parts:
		names.append(j)
		GenCache.save_mesh(full + "_" + j, script_path, parts[j])
	GenCache.save_var(full + "_joints", script_path, names)
	return parts


static func cm(seed_v: int) -> CreatureMesh:
	var c := CreatureMesh.new(seed_v)
	c.metric_uv = true
	return c


## Front of the chest in the chest socket's frame (-Z), per kind's build.
static func chest_front(kind: String) -> float:
	match kind:
		"husk", "ossuant", "bulwark":
			return 0.25
		"spitter":
			return 0.11
	return 0.13


static func chest_half_w(kind: String) -> float:
	match kind:
		"husk", "ossuant", "bulwark":
			return 0.24
		"spitter":
			return 0.13
	return 0.16


## A line laid on the chest's front: (u, v) in [-1, 1] across and down the torso.
static func on_chest(kind: String, u: float, v: float, lift := 0.012) -> Vector3:
	var w := chest_half_w(kind)
	var f := chest_front(kind)
	var y := -0.02 - v * 0.15
	var x := u * w * 0.8
	var z := -(f * sqrt(maxf(0.0, 1.0 - u * u * 0.55)) + lift)
	return Vector3(x, y, z)


# --- humanoids --------------------------------------------------------------------------------

static func _humanoid(variant: String, kind: String) -> Dictionary:
	var parts := {}
	var sd := hash(variant + kind) % 997
	var arm_r := 0.06 if kind == "husk" or kind == "ossuant" or kind == "bulwark" else 0.045
	match variant:
		"scarred":
			var c := cm(sd)
			for k in 3:
				var pts := PackedVector3Array()
				var rad := PackedFloat32Array()
				for i in 6:
					var t := float(i) / 5.0
					pts.append(on_chest(kind, lerpf(-0.75, 0.55, t) + 0.12 * float(k), lerpf(-0.7, 0.35, t) + 0.28 * float(k)))
					rad.append(0.007 * sin(t * PI) + 0.002)
				c.tube(pts, rad, 5, SCAR, 0.0, 0.0, 0.55)
			for k in 5:
				var a := -0.5 + 0.25 * float(k)
				c.blob(on_chest(kind, a, -0.75, 0.004), Vector3(0.012, 0.01, 0.006), Basis.IDENTITY, SCAR, 0.0, 0.0, 0.7, 3, 6)
			parts["chest"] = c.commit()
			for side: String in ["l", "r"]:
				var a := cm(sd + (1 if side == "l" else 2))
				for y: float in [-0.1, -0.19]:
					_ring(a, Vector3(0, y, 0), arm_r + 0.006, 0.006, SCAR, 0.6)
				parts["shoulder_" + side] = a.commit()
			var h := cm(sd + 3)
			h.tube(PackedVector3Array([Vector3(-0.035, 0.07, -0.1), Vector3(0.0, 0.05, -0.112), Vector3(0.035, 0.07, -0.1)]),
				PackedFloat32Array([0.004, 0.007, 0.004]), 5, SCAR, 0.0, 0.0, 0.8)
			h.tube(PackedVector3Array([Vector3(0.0, 0.1, -0.09), Vector3(0.0, 0.05, -0.113), Vector3(0.0, 0.02, -0.112)]),
				PackedFloat32Array([0.003, 0.006, 0.003]), 5, SCAR, 0.0, 0.0, 0.8)
			parts["head"] = h.commit()
		"ironclad":
			var c := cm(sd)
			var f := chest_front(kind)
			var w := chest_half_w(kind)
			c.plate(Vector3(0, 0.0, -f - 0.012), Vector3(w * 0.85, 0.15, 0.03), Vector3(0, 0.12, -1.0), IRON, 1.0, 0.1)
			c.plate(Vector3(0.02, -0.15, -f * 0.95 - 0.01), Vector3(w * 0.7, 0.06, 0.025), Vector3(0, -0.2, -1.0), RUST, 1.0, 0.12)
			for k in 8:
				var u := -0.8 + 1.6 * float(k % 4) / 3.0
				var v := -0.75 if k < 4 else 0.55
				c.blob(on_chest(kind, u * 0.85, v, 0.03), Vector3(0.012, 0.012, 0.01), Basis.IDENTITY, Color(0.5, 0.48, 0.5), 1.0, 0.0, 0.0, 3, 6)
			# leather strap over the shoulder and a hanging chain
			c.tube(PackedVector3Array([Vector3(-w * 0.75, 0.2, 0.06), Vector3(-w * 0.6, 0.17, -f * 0.7), Vector3(0.0, -0.05, -f - 0.04), Vector3(w * 0.75, -0.22, -f * 0.6)]),
				PackedFloat32Array([0.018, 0.018, 0.018, 0.018]), 4, Color(0.28, 0.18, 0.12), 0.0, 0.05, 0.0, Vector2(0.35, 1.0), 0.6)
			for k in 9:
				var t := float(k) / 8.0
				var p := Vector3(lerpf(-w * 0.6, w * 0.7, t), -0.18 - sin(t * PI) * 0.07, -f - 0.03)
				c.blob(p, Vector3(0.014, 0.01, 0.006), Basis(Vector3.FORWARD, float(k % 2) * 1.57), IRON, 1.0, 0.0, 0.0, 3, 6)
			_ring(c, Vector3(0, 0.17, 0.0), 0.085, 0.022, IRON, 0.0, 1.0)      # gorget
			parts["chest"] = c.commit()
			for side: String in ["l", "r"]:
				var sx := -1.0 if side == "l" else 1.0
				var a := cm(sd + (1 if side == "l" else 2))
				a.plate(Vector3(sx * 0.02, 0.035, 0.0), Vector3(0.1, 0.03, 0.1), Vector3(sx * 0.7, 1.0, 0.0), IRON, 1.0, 0.1)
				a.plate(Vector3(sx * 0.045, -0.035, 0.0), Vector3(0.085, 0.025, 0.09), Vector3(sx * 0.95, 0.6, 0.0), RUST, 1.0, 0.12)
				a.claw(Vector3(sx * 0.04, 0.07, 0.0), Vector3(sx * 0.6, 1.0, 0.1).normalized(), 0.09, 0.016, Vector3(0, 0.03, 0), IRON)
				parts["shoulder_" + side] = a.commit()
			var h := cm(sd + 3)
			h.blob(Vector3(0, 0.045, 0.005), Vector3(0.13, 0.085, 0.138), Basis.IDENTITY, IRON, 1.0, 0.07, 0.0, 7, 12)
			_ring(h, Vector3(0, 0.0, 0.005), 0.132, 0.012, RUST, 0.0, 1.0)
			h.tube(PackedVector3Array([Vector3(0, 0.05, -0.135), Vector3(0, 0.0, -0.148), Vector3(0, -0.05, -0.142)]),
				PackedFloat32Array([0.012, 0.011, 0.006]), 5, IRON, 1.0, 0.0)
			parts["head"] = h.commit()
		"tideborn":
			var c := cm(sd)
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			for i in 22:
				var t := float(i) / 21.0
				var a := t * TAU * 1.6
				var r := 0.12 + 0.75 * t
				pts.append(on_chest(kind, cos(a) * r * 0.75, sin(a) * r * 0.6 - 0.1, 0.008))
				rad.append(0.005 + 0.003 * sin(t * PI))
			c.tube(pts, rad, 4, Color(0.3, 0.12, 0.4), 0.0, 0.0, 0.6)
			for side: float in [-1.0, 1.0]:
				for k in 2:
					var root := Vector3(side * (0.1 + 0.06 * float(k)), 0.19, 0.06)
					var wp := PackedVector3Array([root, root + Vector3(side * 0.03, 0.12, 0.05), root + Vector3(side * 0.0, 0.24, 0.12), root + Vector3(-side * 0.04, 0.34, 0.15)])
					c.tube(wp, PackedFloat32Array([0.016, 0.012, 0.007, 0.0]), 4, Color(0.25, 0.1, 0.35), 0.0, 0.1, 0.45, Vector2.ONE, 0.6)
			parts["chest"] = c.commit()
			var h := cm(sd + 3)
			for side: float in [-1.0, 1.0]:
				h.tube(PackedVector3Array([Vector3(side * 0.04, 0.0, -0.105), Vector3(side * 0.048, -0.04, -0.1), Vector3(side * 0.05, -0.085, -0.088)]),
					PackedFloat32Array([0.006, 0.005, 0.0]), 4, Color(0.3, 0.1, 0.4), 0.0, 0.0, 0.85)
			parts["head"] = h.commit()
		"deeper":
			var c := cm(sd)
			# the open door branded on the chest
			var door := PackedVector3Array([on_chest(kind, -0.3, 0.7), on_chest(kind, -0.3, -0.35), on_chest(kind, 0.0, -0.75),
				on_chest(kind, 0.3, -0.35), on_chest(kind, 0.3, 0.7)])
			c.tube(door, PackedFloat32Array([0.006, 0.007, 0.007, 0.007, 0.006]), 4, Color(0.2, 0.3, 0.45), 0.0, 0.0, 0.7)
			for k in 3:
				var z := PackedVector3Array()
				var rr := PackedFloat32Array()
				for i in 5:
					z.append(on_chest(kind, 0.45 + 0.1 * float(k) + (0.08 if i % 2 == 0 else -0.08), -0.6 + 0.35 * float(i) - 0.2 * float(k), 0.006))
					rr.append(0.004)
				c.tube(z, rr, 4, Color(0.2, 0.3, 0.45), 0.0, 0.0, 0.6)
			for k in 4:
				var y := 0.2 - 0.12 * float(k)
				c.claw(Vector3(0, y, 0.15), Vector3(0, 0.55, 1.0).normalized(), 0.13 - 0.015 * float(k), 0.022, Vector3(0, 0.05, 0), BONE)
			parts["chest"] = c.commit()
			for side: String in ["l", "r"]:
				var sx := -1.0 if side == "l" else 1.0
				var a := cm(sd + (1 if side == "l" else 2))
				a.claw(Vector3(sx * 0.03, 0.05, 0.02), Vector3(sx * 0.5, 1.0, 0.3).normalized(), 0.16, 0.024, Vector3(0, 0.04, 0.03), BONE)
				a.claw(Vector3(sx * 0.05, 0.02, -0.03), Vector3(sx * 0.9, 0.6, -0.1).normalized(), 0.1, 0.018, Vector3(0, 0.03, 0), BONE)
				parts["shoulder_" + side] = a.commit()
			var h := cm(sd + 3)
			for k in 5:
				var ang := -0.9 + 1.8 * float(k) / 4.0
				var base := Vector3(sin(ang) * 0.09, 0.08, cos(ang) * 0.05 + 0.02)
				h.claw(base, Vector3(sin(ang) * 0.4, 1.0, 0.35).normalized(), 0.09 + 0.04 * (1.0 - absf(ang)), 0.016, Vector3(0, 0, 0.04), BONE)
			parts["head"] = h.commit()
	return parts


static func _ring(c: CreatureMesh, center: Vector3, r: float, thick: float, col: Color, glow: float, bone := 0.0) -> void:
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 13:
		var a := TAU * float(i) / 12.0
		pts.append(center + Vector3(cos(a) * r, sin(a * 3.0) * 0.004, sin(a) * r))
		rad.append(thick)
	c.tube(pts, rad, 4, col, bone, 0.0, glow)


# --- quadrupeds -------------------------------------------------------------------------------

static func _quad(variant: String, kind: String, rig: QuadRig) -> Dictionary:
	var parts := {}
	var sd := hash(variant + kind) % 997
	var L := rig.body_len
	var bulk := 1.25 if kind == "leaper" else 0.9
	var top := 0.16 * bulk
	var side_x := 0.16 * bulk
	match variant:
		"scarred":
			var c := cm(sd)
			for s: float in [-1.0, 1.0]:
				for k in 3:
					var pts := PackedVector3Array()
					var rad := PackedFloat32Array()
					for i in 5:
						var t := float(i) / 4.0
						pts.append(Vector3(s * (side_x + 0.012), 0.08 - t * 0.14, -L * 0.25 + L * 0.18 * float(k) + t * 0.1))
						rad.append(0.006 * sin(t * PI) + 0.002)
					c.tube(pts, rad, 4, SCAR, 0.0, 0.0, 0.6)
			parts["body"] = c.commit()
			var h := cm(sd + 1)
			h.blob(Vector3(0, 0.06, -0.06), Vector3(0.02, 0.008, 0.03), Basis.IDENTITY, SCAR, 0.0, 0.0, 0.8, 3, 6)
			parts["head"] = h.commit()
		"ironclad":
			var c := cm(sd)
			for k in 4:
				var z := lerpf(L * 0.3, -L * 0.3, float(k) / 3.0)
				c.plate(Vector3(0, top + 0.03, z), Vector3(0.15 * bulk, 0.025, 0.09), Vector3(0, 1.0, -0.3), IRON if k % 2 == 0 else RUST, 1.0, 0.1)
				for s: float in [-1.0, 1.0]:
					c.blob(Vector3(s * 0.1 * bulk, top + 0.035, z), Vector3(0.012, 0.01, 0.012), Basis.IDENTITY, Color(0.5, 0.48, 0.5), 1.0, 0.0, 0.0, 3, 6)
			# spiked iron collar where the neck leaves the body
			_ring(c, Vector3(0, 0.02, -L * 0.42), 0.13 * bulk, 0.02, IRON, 0.0, 1.0)
			for k in 6:
				var a := TAU * float(k) / 6.0 + 0.3
				var o := Vector3(cos(a), sin(a), 0.0)
				if o.y < -0.3:
					continue
				c.claw(Vector3(0, 0.02, -L * 0.42) + o * 0.13 * bulk, (o + Vector3(0, 0, -0.3)).normalized(), 0.07, 0.014, Vector3.ZERO, IRON)
			parts["body"] = c.commit()
			var h := cm(sd + 1)
			h.plate(Vector3(0, 0.07, -0.04), Vector3(0.07, 0.02, 0.09), Vector3(0, 1.0, -0.4), IRON, 1.0, 0.08)
			parts["head"] = h.commit()
		"tideborn":
			var c := cm(sd)
			for k in 8:
				var z := lerpf(L * 0.36, -L * 0.36, float(k) / 7.0)
				c.blob(Vector3(0, top + 0.01, z), Vector3(0.018, 0.012, 0.024), Basis.IDENTITY, Color(0.3, 0.1, 0.4), 0.0, 0.0, 0.7, 3, 6)
			for k in 3:
				var root := Vector3(0, top, lerpf(L * 0.2, -L * 0.25, float(k) / 2.0))
				c.tube(PackedVector3Array([root, root + Vector3(0.03, 0.12, 0.06), root + Vector3(-0.02, 0.24, 0.12), root + Vector3(0.0, 0.32, 0.2)]),
					PackedFloat32Array([0.014, 0.01, 0.006, 0.0]), 4, Color(0.25, 0.1, 0.35), 0.0, 0.1, 0.45, Vector2.ONE, 0.6)
			parts["body"] = c.commit()
		"deeper":
			var c := cm(sd)
			for k in 7:
				var z := lerpf(L * 0.36, -L * 0.36, float(k) / 6.0)
				c.claw(Vector3(0, top, z), Vector3(0, 1.0, 0.45).normalized(), 0.14 + 0.05 * sin(float(k) * 1.1), 0.024, Vector3(0, -0.1, 0.2), BONE)
			for s: float in [-1.0, 1.0]:
				var z := PackedVector3Array()
				var rr := PackedFloat32Array()
				for i in 6:
					z.append(Vector3(s * (side_x + 0.01), 0.06 - 0.03 * float(i % 2), -L * 0.3 + L * 0.12 * float(i)))
					rr.append(0.005)
				c.tube(z, rr, 4, Color(0.2, 0.3, 0.45), 0.0, 0.0, 0.7)
			parts["body"] = c.commit()
	return parts
