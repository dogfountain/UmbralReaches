extends RefCounted
## Item tooltips (r33 loot, after WoW's item tooltips): one look for a thing everywhere it is shown
## (the satchel, the gear panel, the shop, the loot window). Pure: builds BBCode for a RichTextLabel,
## and makes the panel that holds it. Load by path (no class_name):
##   const Tip := preload("res://ui/item_tooltip.gd")
##   rich.text = Tip.piece(p, worn_in_slot, GearStats.state())     # gear, compared with what is worn
##   rich.text = Tip.item("relic_fragment")                         # a satchel item
##   var box := Tip.panel(font)   # PanelContainer > RichTextLabel (named "Rich"), quality border
##
## A gear tooltip reads, top to bottom: the name in its quality colour; quality and item level;
## slot (and "Worn" when it is); the base line and affix lines; a legend line; the set with every
## piece (owned in the set's tint, missing grey) and both bonuses (grey until enough are worn);
## the raise level; flavour in gold italics; then "If you wear this instead" with green / red
## deltas against what the slot holds now.

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const LootDB := preload("res://core/items/loot_db.gd")

const Med := preload("res://ui/medieval_style.gd")
const INK := Med.BONE
const QUIET := Med.BONE_DIM
const GREY := Color(0.55, 0.5, 0.44)
const GOLD := Med.GILT
const GOOD := Color(0.5, 0.9, 0.45)
const BAD := Color(0.95, 0.42, 0.36)
const STAT := Color(0.86, 0.95, 0.82)


static func _c(col: Color, t: String) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), t]


static func _esc(t: String) -> String:
	return t.replace("[", "[lb]")


## A gear piece. `cur`: what the slot holds now ({} = nothing; the same piece = it is worn).
## `st`: the gear state (set pieces owned / worn); {} skips the set and swap lines.
static func piece(p: Dictionary, cur: Dictionary = {}, st: Dictionary = {}, opts: Dictionary = {}) -> String:
	if p.is_empty():
		return ""
	var q := int(p.get("rarity", 0))
	var lines := PackedStringArray()
	lines.append("[font_size=%d][b]%s[/b][/font_size]" % [int(opts.get("title_size", 24)), _c(LootDB.quality_color(q), _esc(String(p.get("name", "?"))))])
	lines.append(_c(QUIET, "%s  ·  Item Level %d" % [LootDB.quality_name(q), GearDB.item_level(p)]))
	# r36 slice: the trait is the line that changes how you play, so it comes first and reads biggest
	if GearDB.trait_line(p) != "":
		lines.append("[font_size=18][b]%s[/b][/font_size]" % _c(Med.GILT, GearDB.trait_line(p)))
	var worn := not cur.is_empty() and int(cur.get("uid", -1)) == int(p.get("uid", -2))
	var slot := String(p.get("slot", ""))
	lines.append(_c(INK, String(GearDB.SLOT_NAMES.get(slot, slot))) + ("    " + _c(GOLD, "Worn") if worn else ""))
	lines.append(_c(INK, GearDB.base_line(p)))
	# the sentence that changes a verb leads; the percents are the second look (small and quiet beneath it,
	# full size on the gear page where they are reforged: opts "full")
	var verb_led := GearDB.trait_line(p) != "" and not bool(opts.get("full", false))
	for a: Variant in p.get("aff", []):
		if a is Array:
			var al := "+ " + GearDB.affix_line(p, a)
			lines.append("[font_size=14]%s[/font_size]" % _c(QUIET, al) if verb_led else _c(STAT, al))
	var lg := String(p.get("legend", ""))
	if GearDB.LEGENDS.has(lg):
		lines.append(_c(LootDB.quality_color(4), String(GearDB.LEGENDS[lg].text)))
	var s := String(p.get("set", ""))
	if GearDB.SETS.has(s):
		lines.append_array(set_block(s, st))
	var lv := int(p.get("level", 0))
	if Slice.full() or lv > 0:
		lines.append(_c(QUIET, "Raised %d of %d" % [lv, GearDB.max_level(p)]))
	var fl := GearDB.flavour(p)
	if fl != "":
		lines.append("[i]%s[/i]" % _c(GOLD, "\"%s\"" % _esc(fl)))
	if not worn and not bool(opts.get("no_compare", false)):
		lines.append_array(compare_block(p, cur, st))
	return "\n".join(lines)


## The set's pieces (owned: tint; missing: grey) and its two bonuses (grey until active).
static func set_block(s: String, st: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var sd: Dictionary = GearDB.SETS[s]
	var owned := {}
	var worn_n := 0
	if not st.is_empty():
		for b: Variant in st.get("bag", []):
			if b is Dictionary and String((b as Dictionary).get("set", "")) == s:
				owned[String(b.slot)] = true
		worn_n = int(GearStats.set_counts(st).get(s, 0))
	out.append("")
	out.append(_c(sd.tint as Color, "%s (%d/4)" % [String(sd.name), owned.size()]))
	for slot: String in GearDB.SLOTS:
		out.append("  " + _c(sd.tint as Color if owned.has(slot) else GREY, String(sd.pieces[slot])))
	for tier: Array in [["two", 2], ["four", 4]]:
		var on := worn_n >= int(tier[1])
		out.append(_c(GOOD if on else GREY, "(%d) Set: %s" % [int(tier[1]), String(sd[tier[0]].text)]))
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
static func item(id: String, count := -1) -> String:
	var d := ItemDB.def(id)
	var q := LootDB.item_quality(id)
	var lines := PackedStringArray()
	lines.append("[font_size=24][b]%s[/b][/font_size]" % _c(LootDB.quality_color(q), _esc(String(d.get("name", id)))))
	var kind := String(d.get("kind", "material")).capitalize()
	if String(d.get("kind", "")) == "core":
		kind = "Staff Core"
	var sub := "%s  ·  %s" % [LootDB.quality_name(q), kind]
	if count > 1 or (count >= 0 and String(d.get("kind", "")) == "material"):
		sub += "  ·  %d carried" % count
	lines.append(_c(QUIET, sub))
	if String(d.get("text", "")) != "":
		lines.append(_c(INK, _esc(String(d.text))))
	var sp := LootDB.sell_price_item(id)
	if sp > 0:
		lines.append(_c(QUIET, "Sells for %d grave ash" % sp))
	if String(d.get("desc", "")) != "":
		lines.append("[i]%s[/i]" % _c(GOLD, "\"%s\"" % _esc(String(d.desc))))
	return "\n".join(lines)


## A PanelContainer with a RichTextLabel child named "Rich" (fit to content), dark plate, and a
## border that set_quality() tints.
static func panel(font: Font = null, width := 380.0) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Med.slip_dark(LootDB.quality_color(0)))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := RichTextLabel.new()
	r.name = "Rich"
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(width, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		r.add_theme_font_override("normal_font", font)
		r.add_theme_font_override("bold_font", font)
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 18)
	r.add_theme_font_size_override("italics_font_size", 15)
	r.add_theme_color_override("default_color", INK)
	pc.add_child(r)
	return pc


static func set_quality(pc: PanelContainer, q: int) -> void:
	var sb := pc.get_theme_stylebox("panel") as StyleBoxTexture
	if sb:
		sb.modulate_color = Med.slip_dark(LootDB.quality_color(q)).modulate_color


static func set_text(pc: PanelContainer, bb: String, q: int) -> void:
	var r := pc.get_node_or_null("Rich") as RichTextLabel
	if r:
		r.text = bb
	set_quality(pc, q)
