extends RefCounted
## Progression (docs/LIFE_PLAN.md): grave ash fed to kindled fires buys lasting growth. Entry
## point for Realm.build: adds the runtime (kindling.gd: applies upgrades, fire spots, charms) and
## the Kindling menu (ui/growth.gd, [K] or [E] at a lit fire) and the combo readout
## (ui/combo_readout.gd), and the Hearthfire runtime (hearth.gd: the Paths' memory, the village's
## trades, meals and Rested, fire reach). Data: upgrade_db.gd, paths_db.gd, hearth_db.gd.

const Kindling := preload("res://core/life/progression/kindling.gd")
const Hearth := preload("res://core/life/progression/hearth.gd")
const Growth := preload("res://ui/growth.gd")
const ComboReadout := preload("res://ui/combo_readout.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")   # gear: drops, wear/raise/salvage
const GearPanel := preload("res://ui/gear_panel.gd")              # gear: the [O] menu
const LootWindow := preload("res://ui/loot_window.gd")            # r33 loot: bags, take one / all
const Gathering := preload("res://core/items/gather.gd")          # r33: ash-blooms, grave-iron


static func build(root: Node) -> void:
	if root.get_node_or_null("Progression") != null:
		return
	var k := Kindling.new()
	k.name = "Progression"
	root.add_child(k)
	var h := Hearth.new()          # the Hearthfire, the Paths' memory, meals and Rested (hearth.gd)
	h.name = "Hearth"
	root.add_child(h)
	var g := Growth.new()
	g.name = "Kindling"
	root.add_child(g)
	var cr := ComboReadout.new()
	cr.name = "ComboReadout"
	root.add_child(cr)
	var gr := GearRuntime.new()
	gr.name = "Gear"
	root.add_child(gr)
	var gp := GearPanel.new()
	gp.name = "GearPanel"
	root.add_child(gp)
	var lw := LootWindow.new()
	lw.name = "LootWindow"
	root.add_child(lw)
	var ga := Gathering.new()
	ga.name = "Gathering"
	root.add_child(ga)
