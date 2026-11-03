class_name SkillBolt
extends Skill
## Rift Bolt: the spammable primary. Each hit leaves an Umbral Mark that Nova detonates.


func _init() -> void:
	id = &"bolt"
	title = "Rift Bolt"
	blurb = "Fast bolt, marks what it hits. Every 3rd shot in a chain is a Rift Lash: big blast, 2 Marks."
	action = &"skill_bolt"
	cooldown = 0.28
	trigger = Trigger.HOLD_REPEAT
	color = Color("#A98BFF")
	glyph = &"bolt"


const CHAIN_WINDOW := 0.9     ## seconds between shots that still count as one chain
var _chain := 0
var _last := -10.0


func cast(book: SkillBook, _charge: float) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	_chain = _chain + 1 if now - _last <= CHAIN_WINDOW else 1
	_last = now
	var lash := book.player.consume_riposte() or _chain % 3 == 0
	var cfg := {"dmg": 1.0, "blast": 1.8, "speed": 34.0, "marks": 1}
	if lash:
		cfg = {"dmg": 2.0, "blast": 3.2, "speed": 38.0, "marks": 2, "empower": true}
	var b := book.player.fire_bolt(cfg)
	if b != null and lash:
		book.player.kick(0.25)
	return b != null
