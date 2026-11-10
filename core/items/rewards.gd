extends Node
## The night's reward rules, which used to live in Travel: what a boss kill pays (trophy, grave ash,
## the Thorn Heart's attunement), what an ordinary kill pays, and that a bell keeper's relic arrives
## attuned to its first variant. Travel keeps the inventory and the save; this node only decides what
## to hand it. One instance per night (world/main.gd); a test without a night adds its own.


func _ready() -> void:
	Events.boss_slain.connect(_on_boss_slain)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.item_gained.connect(_on_item_gained)


func _on_boss_slain(id: String) -> void:
	if ItemDB.BOSS_TROPHY.has(id):
		Travel.give(ItemDB.BOSS_TROPHY[id], 1, false)
	if id == "thornwarden" and not Travel.relics.has("thorn"):
		Travel.relics["thorn"] = &"splinter"          # the Thorn Heart arrives attuned to Splinter
	Travel.give("grave_ash", ItemDB.ASH_PER_BOSS, false)
	Travel.save_game()


func _on_enemy_killed(e: Node) -> void:
	if not e.has_meta(&"boss_id"):
		Travel.give("grave_ash", ItemDB.ASH_PER_KILL, false, false)
		Travel.save_lazy()


func _on_item_gained(id: String, amount: int, _total: int) -> void:
	if amount > 0:
		attune_relic(id)


## A bell keeper's relic arrives attuned to its first variant (the Thorn Heart's way).
static func attune_relic(id: String) -> void:
	var rk := String(ItemDB.def(id).get("relic", ""))
	if rk != "" and not rk in ["bone", "thorn"] and not Travel.relics.has(rk) and Reliquary.VARIANTS.has(rk):
		Travel.relics[rk] = (Reliquary.VARIANTS[rk] as Array)[0]
		Travel.save_soon()
