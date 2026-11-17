extends RefCounted
## Item tooltips (r33 loot, after WoW's item tooltips): one look for a thing everywhere it is shown
## (the satchel, the gear panel, the shop, the loot window). Pure: builds BBCode for a RichTextLabel,
## and makes the panel that holds it. Load by path (no class_name):
##   const Tip := preload("res://ui/item_tooltip.gd")
##   rich.text = Tip.piece(p, worn_in_slot, GearStats.state())     # gear, compared with what is worn
##   rich.text = Tip.item("relic_fragment")                         # a satchel item
##   var box := Tip.panel(font)   # PanelContainer > RichTextLabel (named "Rich"), quality border
##
## A gear tooltip reads, top to bottom: the name in its quality colour; quality and item level; slot (and
## "Worn" when it is); the implicit (the slot's base line); the rolled lines, each with its tier as pips;
## a legend line; the set with every piece (worn lit, carried dimmed, missing grey) and both bonuses (grey
## until enough are worn); the raise level; flavour in gold italics; then "If you wear this instead" with
## green / red deltas against what the slot holds now (the gear page shows that beside the worn piece).

const GearDB := preload("res://core/items/gear_db.gd")
const BbArt := preload("res://ui/bb_art.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const LootDB := preload("res://core/items/loot_db.gd")

const Med := preload("res://ui/medieval_style.gd")
const Card := preload("res://ui/item_card.gd")
const INK := Med.BONE
const QUIET := Med.BONE_DIM
const GREY := Color(0.55, 0.5, 0.44)
const GOLD := Med.GILT
const GOOD := Color(0.5, 0.9, 0.45)
const BAD := Color(0.95, 0.42, 0.36)
const STAT := Color(0.86, 0.95, 0.82)
const FLAVOUR := Color(0.8, 0.66, 0.38)


static func _c(col: Color, t: String) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), t]


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")


## Affix tier pips: filled for the tier reached, hollow for the rest (the best tier is gilt).
static func pips(tier: int) -> String:
	var n := GearDB.TIERS
	var col := GOLD if tier >= n else QUIET
	return BbArt.row("disc", tier, 15, col) + BbArt.row("ring", n - tier, 15, Color(GREY, 0.55))


## A divider between blocks: a marker the card splits on (ui/item_card.gd); `plain()` turns it into a BBCode rule.
static func _hr(strong := false) -> String:
	return Card.DIV_STRONG if strong else Card.DIV


static func plain(bb: String) -> String:
	var hr := "[hr color=#%s height=1]" % Color(Med.BRONZE, 0.6).to_html(true)
	return bb.replace(Card.DIV_STRONG, hr).replace(Card.DIV, hr)


## One affix line: its tier pips lead in a fixed column (every line has the same number of them), the text follows.
static func _stat(text: String, col: Color, tp: String, size := 0) -> String:
	var t := _c(col, text)
	if size > 0:
		t = "[font_size=%d]%s[/font_size]" % [size, t]
	return tp + "  " + t


## A gear piece. `cur`: what the slot holds now ({} = nothing; the same piece = it is worn).
## `st`: the gear state (set pieces owned / worn); {} skips the set and swap lines.
## opts: title_size, full (every affix at full size), no_compare (the caller shows the compare),
## reforge_idx (>= 0: mark that affix line and say what it can become).
static func piece(p: Dictionary, cur: Dictionary = {}, st: Dictionary = {}, opts: Dictionary = {}) -> String:
	if p.is_empty():
		return ""
	var q := int(p.get("rarity", 0))
	var lines := PackedStringArray()
	var qc := LootDB.quality_color(q)
	if bool(opts.get("head", true)):          # the card draws the name on its band; plain callers keep it in the text
		lines.append("[center][font_size=%d][b]%s[/b][/font_size][/center]" % [int(opts.get("title_size", 26)), _c(qc, _esc(String(p.get("name", "?"))))])
	var worn := not cur.is_empty() and int(cur.get("uid", -1)) == int(p.get("uid", -2))
	var slot := String(p.get("slot", ""))
	# the gear page's type scale (opts "page"): the stat lines lead at 20, the type line and the trait above them,
	# the set, the raise level and the flavour under them at 15 and 16
	var pg := bool(opts.get("page", false))
	if pg:
		lines.append("[center]%s%s%s[/center]" % [_c(qc.lightened(0.15), LootDB.quality_name(q)), _c(QUIET, "  ·  Item Level %d  ·  " % GearDB.item_level(p)), _c(INK, String(GearDB.SLOT_NAMES.get(slot, slot)))])
		if worn:
			lines.append("[center]%s[/center]" % _c(GOLD, "Worn"))
	else:
		lines.append("[center]%s%s[/center]" % [_c(qc.lightened(0.15), LootDB.quality_name(q)), _c(QUIET, "  ·  Item Level %d" % GearDB.item_level(p))])
		lines.append("[center]%s%s[/center]" % [_c(INK, String(GearDB.SLOT_NAMES.get(slot, slot))), ("    " + _c(GOLD, "Worn")) if worn else ""])
	lines.append(_hr(true))
	# the implicit (the slot's own base stat) stands apart from the rolled lines
	lines.append("[center]%s[/center]" % (("[font_size=20]%s[/font_size]" if pg else "%s") % _c(INK, GearDB.base_line(p))))
	lines.append(_hr())
	# the trait is the line that changes how you play, so it comes first and reads biggest
	if GearDB.trait_line(p) != "":
		lines.append("[font_size=%d][b]%s[/b][/font_size]" % [21 if pg else 19, _c(Med.GILT, GearDB.trait_line(p))])
	# the sentence that changes a verb leads; the percents are the second look (smaller and quieter beneath it,
	# full size on the gear page where they are reforged: opts "full")
	var verb_led := GearDB.trait_line(p) != "" and not bool(opts.get("full", false))
	var ri := int(opts.get("reforge_idx", -1))
	var aff: Array = p.get("aff", [])
	for i in aff.size():
		var a: Variant = aff[i]
		if a is Array:
			var mark := "> " if i == ri and aff.size() > 1 else "+ "
			var al := mark + GearDB.affix_line(p, a)
			lines.append(_stat(al, QUIET if verb_led else (GOLD if i == ri and aff.size() > 1 else STAT), pips(GearDB.affix_tier(a)), 15 if verb_led else (20 if pg else 0)))
	if ri >= 0 and ri < aff.size():
		var pool := GearDB.reforge_pool(p, ri)
		if not pool.is_empty():
			lines.append("[font_size=15]%s[/font_size]" % _c(QUIET, "Line %d can become: %s" % [ri + 1, ", ".join(pool)]))
	var lg := String(p.get("legend", ""))
	if GearDB.LEGENDS.has(lg):
		lines.append(_hr())
		lines.append(_c(LootDB.quality_color(4), String(GearDB.LEGENDS[lg].text)))
	var s := String(p.get("set", ""))
	if GearDB.SETS.has(s):
		lines.append(_hr())
		if pg:                                  # the page's own Sets panel lists the pieces and the bonuses: the card names the set and no more
			lines.append("[center][font_size=16]%s[/font_size][/center]" % set_block(s, st)[0].trim_prefix("[center]").trim_suffix("[/center]"))
		else:
			lines.append_array(set_block(s, st))
	var lv := int(p.get("level", 0))
	if (Slice.full() or lv > 0) and not (pg and lv == 0):          # (the page's Raise button already says what is left to raise)
		lines.append(_hr())
		if pg:
			lines.append("[font_size=15]%s[/font_size]" % _c(QUIET, "Raised %d / %d" % [lv, GearDB.max_level(p)]))
		else:
			lines.append(_c(QUIET, "Raised %d of %d" % [lv, GearDB.max_level(p)]) + "  " + BbArt.row("disc", lv, 14, GOLD) + BbArt.row("ring", GearDB.max_level(p) - lv, 14, Color(GREY, 0.55)))
	var fl := GearDB.flavour(p)
	if fl != "":
		lines.append(_hr())
		lines.append(("[center][i][font_size=16]%s[/font_size][/i][/center]" if pg else "[center][i]%s[/i][/center]") % _c(Color(FLAVOUR, 0.85), "\"%s\"" % _esc(fl)))
	if not worn and not bool(opts.get("no_compare", false)):
		lines.append(_hr(true))
		lines.append_array(compare_block(p, cur, st))
	var out := "\n".join(lines)
	return out if bool(opts.get("blocks", false)) else plain(out)


## The set's pieces (worn: lit in the set's tint; carried: dimmed; missing: grey) and its two bonuses
## (green once enough are worn, grey until).
static func set_block(s: String, st: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var sd: Dictionary = GearDB.SETS[s]
	var owned := {}
	var on := {}
	var worn_n := 0
	if not st.is_empty():
		for b: Variant in st.get("bag", []):
			if b is Dictionary and String((b as Dictionary).get("set", "")) == s:
				owned[String(b.slot)] = true
		for sl: Variant in GearStats.worn(st):
			if String((GearStats.worn(st)[sl] as Dictionary).get("set", "")) == s:
				on[String(sl)] = true
		worn_n = int(GearStats.set_counts(st).get(s, 0))
	var tint: Color = sd.tint
	out.append("[center]%s[/center]" % _c(tint, "%s (%d/4)" % [String(sd.name), owned.size()]))
	for slot: String in GearDB.SLOTS:
		var nm := String(sd.pieces[slot])
		if on.has(slot):
			out.append("  " + _c(tint.lightened(0.35), "[b]%s[/b]" % nm) + "  " + _c(QUIET, "worn"))
		elif owned.has(slot):
			out.append("  " + _c(tint.darkened(0.3), nm))
		else:
			out.append("  " + _c(GREY, nm))
	for tier: Array in [["two", 2], ["four", 4]]:
		var lit := worn_n >= int(tier[1])
		out.append(_c(GOOD if lit else GREY, "(%d) Set: %s" % [int(tier[1]), String(sd[tier[0]].text)]))
	return out


## "If you wear this instead": green / red deltas against what the slot holds now.
static func compare_block(p: Dictionary, cur: Dictionary, st: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var diffs := GearStats.compare(p, cur, st)
	out.append("")
	if cur.is_empty():
		out.append(_c(QUIET, "Nothing worn in this slot: wearing it is all gain."))
	else:
		out.append(_c(QUIET, "Instead of %s:" % _esc(String(cur.get("name", "?")))))
	if diffs.is_empty() and not cur.is_empty():
		out.append(_c(QUIET, "  no change"))
	for d: Array in diffs:
		out.append("  " + _c(GOOD if bool(d[2]) else BAD, String(d[1])))
	return out


## A satchel item: name in quality colour, quality and kind, what it does, gold italic lore.
static func item(id: String, count := -1, opts: Dictionary = {}) -> String:
	var d := ItemDB.def(id)
	var q := LootDB.item_quality(id)
	var lines := PackedStringArray()
	if bool(opts.get("head", true)):
		lines.append("[font_size=24][b]%s[/b][/font_size]" % _c(LootDB.quality_color(q), _esc(String(d.get("name", id)))))
	var kind := String(d.get("kind", "material")).capitalize()
	if String(d.get("kind", "")) == "core":
		kind = "Staff Core"
	var sub := "  ·  " + kind
	if count > 1 or (count >= 0 and String(d.get("kind", "")) == "material"):
		sub += "  ·  %d carried" % count
	lines.append("[center]%s%s[/center]" % [_c(LootDB.quality_color(q).lightened(0.15), LootDB.quality_name(q)), _c(QUIET, sub)])
	var sp := LootDB.sell_price_item(id)
	if String(d.get("text", "")) != "":
		lines.append(_hr(true))
		lines.append(_c(INK, _esc(String(d.text))))
	if sp > 0:
		lines.append(_hr())
		lines.append(_c(QUIET, "Sells for %d grave ash" % sp))
	if String(d.get("desc", "")) != "":
		lines.append(_hr())
		lines.append("[center][i]%s[/i][/center]" % _c(FLAVOUR, "\"%s\"" % _esc(String(d.desc))))
	var out := "\n".join(lines)
	return out if bool(opts.get("blocks", false)) else plain(out)


## The card: a PanelContainer (ui/item_card.gd) with a name band and a body of blocks. `font` is unused (the
## card carries the kit's fonts); kept so callers keep their shape.
static func panel(_font: Font = null, width := 380.0) -> PanelContainer:
	return Card.make(width)


static func set_quality(pc: PanelContainer, q: int) -> void:
	Card.set_quality(pc, q)


## Fill a card made by panel(): `bb` from piece() / item() with {"head": false, "blocks": true}, the name beside it.
static func set_text(pc: PanelContainer, bb: String, q: int, nm := "", size := Card.BODY_SIZE) -> void:
	Card.fill(pc, nm, q, bb, size)
