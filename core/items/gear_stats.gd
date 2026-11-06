extends RefCounted
## The one hook through which gear touches play (docs/enshrouded/equipment.md). UpgradeDB.mods()
## calls `apply(m)` last, so worn gear lands in the same live modifier table the skills and the
## progression runtime already read (power, cd, gloom_add, dark_mult, lit_mult, kill_relief,
## step_range, step_cd, lash_power, mark_dmg, lance_charge, lance_blast, ward_life, well_life,
## lash_every and the behaviour flags). Nothing in player.gd or the skills reads gear directly.
## Load by path (no class_name): const GearStats := preload("res://core/items/gear_stats.gd")
##
## State: Travel.system_state("gear") = {bag: [piece], worn: {slot -> uid}, next_uid, pity, ...}

const GearDB := preload("res://core/items/gear_db.gd")
const SID := "gear"


static func state() -> Dictionary:
	var st := Travel.system_state(SID)
	if not (st.get("bag") is Array):
		st["bag"] = []
	if not (st.get("worn") is Dictionary):
		st["worn"] = {}
	return st


static func find(st: Dictionary, uid: int) -> Dictionary:
	for p: Variant in st.get("bag", []):
		if p is Dictionary and int((p as Dictionary).get("uid", -1)) == uid:
			return p
	return {}


## The gear screen's "new" marker: uids the wanderer has looked at. A save from before it had none, so
## the first call counts everything carried then as seen (call it before adding a piece to the bag).
static func seen_init(st: Dictionary) -> Array:
	if not (st.get("seen") is Array):
		var all: Array = []
		for p: Variant in st.get("bag", []):
			if p is Dictionary:
				all.append(int((p as Dictionary).get("uid", -1)))
		st["seen"] = all
	return st.seen


static func is_new(st: Dictionary, uid: int) -> bool:
	return not seen_init(st).has(uid)


static func mark_seen(st: Dictionary, uid: int) -> void:
	var seen := seen_init(st)
	if not seen.has(uid):
		seen.append(uid)


## The pieces worn now, by slot (only slots holding a piece that is still in the bag).
static func worn(st: Dictionary) -> Dictionary:
	var out := {}
	var w: Variant = st.get("worn", {})
	if not (w is Dictionary):
		return out
	for slot: String in GearDB.SLOTS:
		if (w as Dictionary).has(slot):
			var p := find(st, int((w as Dictionary)[slot]))
			if not p.is_empty() and String(p.get("slot", "")) == slot:
				out[slot] = p
	return out


static func any_worn() -> bool:
	return not worn(state()).is_empty()


## Set id -> number of its pieces worn.
static func set_counts(st: Dictionary) -> Dictionary:
	var out := {}
	for p: Dictionary in worn(st).values():
		var s := String(p.get("set", ""))
		if s != "":
			out[s] = int(out.get(s, 0)) + 1
	return out


## Everything worn, as [key, op, value] steps and flags: {"mods": [...], "flags": [...]}.
static func contributions(st: Dictionary) -> Dictionary:
	var mods: Array = []
	var flags: Array = []
	for p: Dictionary in worn(st).values():
		var bv := GearDB.base_value(p)
		mods.append([String(bv[0]), "add", float(bv[1])])
		if String(bv[0]) == "ward_life":
			mods.append(["well_life", "add", float(bv[1])])     # the lantern's glass holds both lights
		for a: Variant in p.get("aff", []):
			if a is Array and (a as Array).size() >= 2 and GearDB.AFFIX.has(String(a[0])):
				var d: Dictionary = GearDB.AFFIX[String(a[0])]
				mods.append([String(d.key), String(d.op), GearDB.affix_value(p, float(a[1]))])
		var lg := String(p.get("legend", ""))
		if GearDB.LEGENDS.has(lg):
			flags.append_array(GearDB.LEGENDS[lg].get("flags", []))
		var tr := String(p.get("trait", ""))          # r36: a piece's trait
		if GearDB.TRAITS.has(tr):
			flags.append_array(GearDB.TRAITS[tr].get("flags", []))
	var counts := set_counts(st)
	for s: String in counts:
		var sd: Dictionary = GearDB.SETS.get(s, {})
		for tier: Array in [["two", 2], ["four", 4]]:
			if int(counts[s]) >= int(tier[1]) and sd.has(tier[0]):
				var b: Dictionary = sd[tier[0]]
				mods.append_array(b.get("mods", []))
				flags.append_array(b.get("flags", []))
	return {"mods": mods, "flags": flags}


## Fold worn gear into a modifier table built by UpgradeDB.mods().
static func apply(m: Dictionary) -> void:
	fold(m, contributions(state()))


## Add / multiply / set every step of `c` (contributions()) into `m`, and switch on its flags.
static func fold(m: Dictionary, c: Dictionary) -> void:
	for step: Array in c.mods:
		var key := String(step[0])
		var v := float(step[2])
		match String(step[1]):
			"mul":
				m[key] = float(m.get(key, 1.0)) * maxf(0.2, 1.0 + v)
			"set":
				m[key] = mini(int(m.get(key, int(v))), int(v))
			_:
				m[key] = float(m.get(key, 0.0)) + v
	for f: Variant in c.flags:
		m[String(f)] = true


## What the behaviour flags are called in the panel.
const FLAG_NAMES := {"rosary": "burning foes gather Marks", "hook": "the Tether Marks its whole chain",
	"chalk": "hooks and darts lay 2 Marks", "tally": "Nova: 1.5 a Mark", "door": "Step: the Open Door",
	"bramble": "the Ward roots in brambles", "jar": "the Shade lingers and bursts", "ferrule": "Step lands with a Mark",
	"step_briar": "Step roots in brambles", "kill_spark": "a kill beside you hastens your spells", "ash_hunger": "a kill beside you gives more ash",
	"peal_echo": "the Peal rings twice"}


## Plain lines summing up what the gear worn gives (the panel's footer).
static func summary(st: Dictionary) -> PackedStringArray:
	var m := {"power": 1.0, "cd": 1.0, "gloom_add": 0.0, "dark_mult": 1.0, "lit_mult": 1.0, "kill_relief": 0.0,
		"step_range": 0.0, "step_cd": 1.0, "lash_power": 1.0, "mark_dmg": 0.0, "lance_charge": 1.0, "lance_blast": 0.0,
		"ward_life": 0.0, "well_life": 0.0, "lash_every": 3}
	var tmp := m
	var c := contributions(st)
	fold(tmp, c)
	var out := PackedStringArray()
	if float(tmp.power) > 1.0001:
		out.append("+%d%% spell power" % roundi((float(tmp.power) - 1.0) * 100.0))
	if float(tmp.cd) < 0.9999:
		out.append("spells recover %d%% sooner" % roundi((1.0 - float(tmp.cd)) * 100.0))
	if float(tmp.gloom_add) > 0.0:
		out.append("+%d Gloom held" % roundi(float(tmp.gloom_add)))
	if float(tmp.dark_mult) < 0.9999:
		out.append("Gloom gathers %d%% slower" % roundi((1.0 - float(tmp.dark_mult)) * 100.0))
	if float(tmp.lit_mult) > 1.0001:
		out.append("fire clears Gloom %d%% faster and mends the plate" % roundi((float(tmp.lit_mult) - 1.0) * 100.0))
	if float(tmp.kill_relief) > 0.0:
		out.append("%.1f Wounds mended a kill within 28 m" % float(tmp.kill_relief))
	if float(tmp.step_range) > 0.0:
		out.append("Step +%.1f m" % float(tmp.step_range))
	if float(tmp.step_cd) < 0.9999:
		out.append("Step recovers %d%% sooner" % roundi((1.0 - float(tmp.step_cd)) * 100.0))
	if float(tmp.lash_power) > 1.0001:
		out.append("Lash +%d%%" % roundi((float(tmp.lash_power) - 1.0) * 100.0))
	if int(tmp.lash_every) < 3:
		out.append("Lash every 2nd bolt")
	if float(tmp.mark_dmg) > 0.0:
		out.append("+%.2f a Mark detonated" % float(tmp.mark_dmg))
	if float(tmp.lance_charge) < 0.9999:
		out.append("Lance charges %d%% faster" % roundi((1.0 - float(tmp.lance_charge)) * 100.0))
	if float(tmp.lance_blast) > 0.0:
		out.append("Lance burst +%.1f m" % float(tmp.lance_blast))
	if float(tmp.ward_life) > 0.0:
		out.append("Ward +%.1f s" % float(tmp.ward_life))
	if float(tmp.well_life) > 0.0:
		out.append("Well +%.1f s" % float(tmp.well_life))
	for f: Variant in c.flags:
		var s := String(FLAG_NAMES.get(String(f), String(f)))
		if not out.has(s):
			out.append(s)
	return out


# --- r33 loot: one piece's own numbers, and a comparison against what is worn (tooltips) ---------

## Stat keys as the tooltips name them, and which way is better (true: lower is better).
## [label, lower is better, a percentage]. A lower-is-better line is shown sign-flipped under its
## label ("+5% faster spell recovery"), so plus always reads as more of the label.
const STAT_NAMES := {"power": ["spell power", false, true], "cd": ["faster spell recovery", true, true],
	"gloom_add": ["Gloom held", false, false], "dark_mult": ["slower Gloom gathering", true, true],
	"lit_mult": ["fire's relief", false, true], "kill_relief": ["Wounds mended a kill", false, false],
	"step_range": ["Rift Step reach (m)", false, false], "step_cd": ["faster Rift Step recovery", true, true],
	"lash_power": ["Lash damage", false, true], "mark_dmg": ["damage a Mark", false, false],
	"lance_charge": ["faster Lance charge", true, true], "lance_blast": ["Lance burst (m)", false, false],
	"ward_life": ["Lantern Ward (s)", false, false], "well_life": ["Umbral Well (s)", false, false],
	"shade_life": ["Bound Shade (s)", false, false], "tether_reach": ["Rift Tether reach (m)", false, false],
	"peal_reach": ["Founder's Peal reach (m)", false, false], "ash_find": ["grave ash a kill", false, true]}


## {mod key -> value} for one piece alone (base + affixes; "mul" affixes as their offset from 1).
static func piece_stats(p: Dictionary) -> Dictionary:
	var out := {}
	if p.is_empty():
		return out
	var bv := GearDB.base_value(p)
	out[String(bv[0])] = float(out.get(String(bv[0]), 0.0)) + float(bv[1])
	if String(bv[0]) == "ward_life":
		out["well_life"] = float(out.get("well_life", 0.0)) + float(bv[1])
	for a: Variant in p.get("aff", []):
		if a is Array and (a as Array).size() >= 2 and GearDB.AFFIX.has(String(a[0])):
			var d: Dictionary = GearDB.AFFIX[String(a[0])]
			out[String(d.key)] = float(out.get(String(d.key), 0.0)) + GearDB.affix_value(p, float(a[1]))
	return out


## What changes if `cand` is worn instead of `cur` ({} = the slot is empty): [[label, text, better]]
## (better: true green, false red). Also the item level and set-bonus changes.
static func compare(cand: Dictionary, cur: Dictionary, st: Dictionary = {}) -> Array:
	var out: Array = []
	var a := piece_stats(cand)
	var b := piece_stats(cur)
	var keys: Array = a.keys()
	for k: Variant in b.keys():
		if not keys.has(k):
			keys.append(k)
	keys.sort()
	for k: Variant in keys:
		var key := String(k)
		var d := float(a.get(key, 0.0)) - float(b.get(key, 0.0))
		if absf(d) < 0.0005:
			continue
		var info: Array = STAT_NAMES.get(key, [key, false, false])
		var lower_better := bool(info[1])
		var better := (d < 0.0) if lower_better else (d > 0.0)
		if lower_better:
			d = -d
		var txt := ""
		if bool(info[2]):
			txt = "%+d%% %s" % [roundi(d * 100.0), String(info[0])]
		elif absf(d) >= 1.0 and is_equal_approx(d, roundf(d)):
			txt = "%+d %s" % [roundi(d), String(info[0])]
		else:
			txt = "%+.2f %s" % [d, String(info[0])]
		out.append([key, txt, better])
	var dl := GearDB.item_level(cand) - (GearDB.item_level(cur) if not cur.is_empty() else 0)
	if dl != 0:
		out.push_front(["ilvl", "%+d item level" % dl, dl > 0])
	# set bonuses woken or lost by the swap
	if not st.is_empty():
		var before := set_counts(st)
		var after := before.duplicate()
		var cs := String(cur.get("set", ""))
		var ns := String(cand.get("set", ""))
		if cs != "":
			after[cs] = int(after.get(cs, 0)) - 1
		if ns != "":
			after[ns] = int(after.get(ns, 0)) + 1
		for s: String in GearDB.SET_ORDER:
			for tier: int in [2, 4]:
				var was := int(before.get(s, 0)) >= tier
				var now := int(after.get(s, 0)) >= tier
				if was != now:
					out.append(["set", "%s (%d) %s" % [String(GearDB.SETS[s].name), tier, "wakes" if now else "is lost"], now])
	return out
