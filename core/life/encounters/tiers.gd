extends RefCounted
## Encounters: regional danger tiers. A place has a base danger (the Hearthward road is gentle, the
## Rift and the summit are not); every boss you fell deepens the whole night one step; the Deeper
## Night (NG+) adds two more per cycle. A tier scales the camps' pawns (health, how much Gloom a
## blow fills, a little pace -- never the telegraph times), decides how often a pawn wears a
## variant (scarred, iron-scrapped) and whether a camp gets a mixed-in extra member.
## Pure/static: everything reads Travel and the encounters state; nothing here holds state.

## Base danger by RealmLayout region id.
const REGION_BASE := {
	"hearth": 0, "road": 0, "glade": 0, "chapel": 1, "thornwood": 1, "henge": 1, "fen": 1,
	"barrows": 2, "ossuary": 2, "rift": 2, "crags": 2, "summit": 3,
	# r34: the new ground, at the tiers RealmLayout.REGIONS suggests (the far quarry and the
	# Founder's Pits under the Crowns are the hard ones; the Rooted Holds stay gentle)
	"quarry": 2, "foundry": 2, "holds": 1, "moor": 1, "orchard": 1, "necropolis": 1, "mere": 1,
}

## Per tier: health x, Gloom per blow x, pace x, chance a pawn wears a variant, chance a camp gets
## one more (mixed) member, which variants it may draw.
const TIERS: Array[Dictionary] = [
	{"name": "Dusk", "hp": 1.0, "dmg": 1.0, "pace": 1.0, "variant": 0.0, "extra": 0.0, "pool": []},
	{"name": "Night", "hp": 1.25, "dmg": 1.1, "pace": 1.03, "variant": 0.25, "extra": 0.2, "pool": ["scarred"]},
	{"name": "Deep Night", "hp": 1.5, "dmg": 1.2, "pace": 1.05, "variant": 0.45, "extra": 0.35, "pool": ["scarred", "scarred", "ironclad"]},
	{"name": "Black Night", "hp": 1.8, "dmg": 1.3, "pace": 1.07, "variant": 0.6, "extra": 0.5, "pool": ["scarred", "ironclad"]},
	{"name": "Hollow Night", "hp": 2.1, "dmg": 1.4, "pace": 1.09, "variant": 0.7, "extra": 0.6, "pool": ["scarred", "ironclad", "ironclad"]},
	{"name": "Deeper Night", "hp": 2.5, "dmg": 1.5, "pace": 1.11, "variant": 0.85, "extra": 0.7, "pool": ["ironclad", "deeper"]},
	{"name": "Umbral Night", "hp": 3.0, "dmg": 1.6, "pace": 1.13, "variant": 1.0, "extra": 0.8, "pool": ["ironclad", "deeper", "deeper"]},
]

## Mixed packs: what joins a camp in each region (heavier kinds as the tier climbs).
const REGION_POOL := {
	"road": ["wretch", "crawler", "husk", "burrower", "gaunt"], "hearth": ["wretch", "crawler"], "chapel": ["wretch", "husk", "spitter", "chanter", "tollman"],
	"glade": ["crawler", "wretch"], "thornwood": ["crawler", "leaper", "wretch", "spitter", "chanter", "gaunt"], "henge": ["leaper", "crawler", "gaunt"],
	"fen": ["ossuant", "spitter", "wretch", "burrower", "quiller"], "barrows": ["ossuant", "husk", "spitter", "bulwark", "quiller"], "rift": ["husk", "spitter", "leaper", "bulwark", "chanter", "tollman"],
	"summit": ["husk", "spitter", "leaper", "bulwark", "chanter", "quiller"], "crags": ["leaper", "husk", "burrower", "gaunt"], "ossuary": ["ossuant", "husk", "bulwark", "quiller"],
	# r34: each new region's own roster (docs/r34/layout.md; the camps in EnemySpawner.REALM_CAMPS)
	"quarry": ["husk", "leaper", "leaper", "wretch", "bulwark"], "foundry": ["cinder", "bulwark", "wretch", "cinder", "gaunt"],
	"moor": ["gaunt", "gaunt", "wretch", "crawler", "husk"], "orchard": ["burrower", "mite", "crawler", "burrower", "wretch"],
	"necropolis": ["pilgrim", "pilgrim", "ossuant", "chanter", "quiller"], "mere": ["husk", "spitter", "wretch", "spitter", "ossuant"],
	"holds": ["crawler", "wretch"],
	# --- r37 east ---
	"stillwater": ["husk", "spitter", "wretch", "gaunt", "husk"], "anchorholds": ["bulwark", "chanter", "leaper", "husk", "quiller"],
	"saltmarket": ["wretch", "crawler"], "saltpans": ["husk", "burrower", "cinder", "gaunt", "crawler"],
}

## r34: a region's own look for some kinds (Variants.REGIONAL): what the quarry and the mere make of
## the hollowed that walk there. Camps, tides and ambushes in the region wear it.
const REGION_VARIANT := {
	"quarry": {"husk": "stonebound", "bulwark": "stonebound", "leaper": "stonebound"},
	"mere": {"husk": "drowned", "wretch": "drowned", "ossuant": "drowned"},
	# --- r37 east ---
	"stillwater": {"husk": "drowned", "wretch": "drowned"},
	"anchorholds": {"husk": "stonebound", "bulwark": "stonebound"},
}

const KIND_PATHS := {
	"wretch": "res://core/enemy/wretch.gd", "husk": "res://core/enemy/husk.gd", "crawler": "res://core/enemy/crawler.gd",
	"leaper": "res://core/enemy/leaper.gd", "spitter": "res://core/enemy/spitter.gd", "ossuant": "res://core/enemy/ossuant.gd",
	"bulwark": "res://core/enemy/bulwark.gd", "chanter": "res://core/enemy/chanter.gd",
	"burrower": "res://core/enemy/burrower.gd", "mite": "res://core/enemy/mite.gd",
	# r31 (docs/enshrouded/enemies.md)
	"gaunt": "res://core/enemy/gaunt.gd", "quiller": "res://core/enemy/quiller.gd", "tollman": "res://core/enemy/tollman.gd",
	# r34
	"pilgrim": "res://core/enemy/pilgrim.gd", "cinder": "res://core/enemy/cinder_caster.gd",
}


static func region_id(at: Vector3) -> String:
	var r := RealmLayout.region_at(at.x, at.z)
	return String(r.get("id", "hearth"))


## How many steps the whole night has deepened: bosses felled (this cycle) and two per Deeper Night
## cycle. r31 (r30 critique 12): the wanderer's own growth no longer deepens it -- spending ash must
## not make the world tougher. Depth now buys behaviour as well as numbers (`behave`).
static func night_depth() -> int:
	return Travel.bosses_slain.size() + 2 * ng_level()


static func ng_level() -> int:
	var st: Variant = Travel.systems.get("encounters", {})
	return int((st as Dictionary).get("ng", 0)) if st is Dictionary else 0


static func tier_at(at: Vector3) -> int:
	return clampi(region_base(region_id(at)) + night_depth(), 0, TIERS.size() - 1)


## Base danger of a region id: REGION_BASE, else the tier RealmLayout.REGIONS suggests, else 1.
static func region_base(id: String) -> int:
	if REGION_BASE.has(id):
		return int(REGION_BASE[id])
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == id:
			return int(r.get("tier", 1))
	return 1


## r34: the regional variant a pawn of `kind` wears at `at` ("" = none).
static func region_variant(at: Vector3, kind: String) -> String:
	var m: Dictionary = REGION_VARIANT.get(region_id(at), {})
	return String(m.get(kind, ""))


static func info(tier: int) -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]


## Deterministic per-slot dice (the same camp rolls the same way until the night deepens).
static func roll(key: String, salt: int) -> float:
	var h := hash(key + "#" + str(salt))
	return float(absi(h) % 10007) / 10007.0


## The variant a pawn at `at` wears ("" = plain). Seal guards and roamers alike.
static func pick_variant(at: Vector3, key: String, salt := 0) -> String:
	var t := info(tier_at(at))
	var pool: Array = t.pool
	if pool.is_empty() or roll(key, 11 + salt) >= float(t.variant):
		return ""
	return String(pool[int(roll(key, 23 + salt) * float(pool.size())) % pool.size()])


## Scale a fresh pawn (before it enters the tree: _ready sets hp from max_hp).
static func scale_stats(e: Node, tier: int) -> void:
	var t := info(tier)
	var base_hp := int(e.get("max_hp"))
	var hp := maxi(base_hp, roundi(float(base_hp) * float(t.hp)))
	if tier >= 2 and hp == base_hp:
		hp += 1
	e.set("max_hp", hp)
	e.set("hp", float(hp))
	e.set("strike_gloom", float(e.get("strike_gloom")) * float(t.dmg))
	if "spit_gloom" in e:
		e.set("spit_gloom", float(e.get("spit_gloom")) * float(t.dmg))
	e.set("walk_speed", float(e.get("walk_speed")) * float(t.pace))
	behave(e, tier)
	e.set_meta(&"enc_tier", tier)


## The `dmg` multiplier of the tier stored on a pawn (`enc_tier`), 1.0 when it was never scaled.
## For the literal blows (pools, slag, a tollman's clang) that scale_stats does not reach.
static func dmg_of(e: Node) -> float:
	if e == null or not e.has_meta(&"enc_tier"):
		return 1.0
	return float(info(int(e.get_meta(&"enc_tier"))).dmg)


## r31: the deeper the night, the cannier the pack -- more chains and feints, never shorter tells.
## Tier 0-1 as built; each tier past 1 adds a little (capped), so the late game has teeth that are
## not just a longer health bar.
static func behave(e: Node, tier: int) -> void:
	var k := clampi(tier - 1, 0, 5)
	if k == 0 or not (e is Enemy):
		return
	var en := e as Enemy
	if en.combo_max > 0 or en.role == &"flanker":
		en.combo_max = maxi(en.combo_max, 1)
		en.combo_chance = minf(en.combo_chance + 0.06 * float(k), 0.6)
	if en.strike_range > 0.0:
		en.feint_chance = minf(en.feint_chance + 0.04 * float(k), 0.35)


## A pawn already in the world (planted before encounters loaded): same scaling, bar refreshed.
static func scale_live(e: Node, tier: int) -> void:
	if e.has_meta(&"enc_tier"):
		return
	scale_stats(e, tier)
	var bar: Variant = e.get("_hp_bar")
	if bar is MeshInstance3D:
		(bar as MeshInstance3D).set_instance_shader_parameter(&"segments", Enemy.hp_segments(int(e.get("max_hp"))))
	if e is Enemy:
		(e as Enemy)._refresh_hp(false)


## The mixed-pack kind a camp in this region would gain at this tier.
static func extra_kind(at: Vector3, key: String) -> String:
	var pool: Array = REGION_POOL.get(region_id(at), ["wretch"])
	var tier := tier_at(at)
	# heavier picks from the pool's tail as the night deepens
	var i := int(roll(key, 41) * float(pool.size()) + float(tier) * 0.35) % pool.size()
	return String(pool[i])


static func script_for(kind: String) -> GDScript:
	return load(KIND_PATHS.get(kind, KIND_PATHS.wretch)) as GDScript
