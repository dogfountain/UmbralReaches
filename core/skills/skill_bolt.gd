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
	gcd = 0.0                   # r33: the bolt keeps its own cadence, off the global cooldown


const CHAIN_WINDOW := 0.9     ## seconds between shots that still count as one chain
var _chain := 0
var _last := -10.0


## Where the chain stands: two pips fill, the third is the Lash (the slot lights when it is next).
func pips(_book: SkillBook) -> Vector2i:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last > CHAIN_WINDOW:
		return Vector2i(0, 3)
	return Vector2i(_chain % 3, 3)


func primed(book: SkillBook) -> bool:
	if book.player and book.player.get("_riposte_ready") == true:
		return true
	var now := Time.get_ticks_msec() * 0.001
	return now - _last <= CHAIN_WINDOW and _chain % 3 == 2


func cast(book: SkillBook, _charge: float) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	_chain = _chain + 1 if now - _last <= CHAIN_WINDOW else 1
	_last = now
	var lash := book.player.consume_riposte() or _chain % 3 == 0
	var cfg := {"dmg": 1.0, "blast": 1.8, "speed": 34.0, "marks": 1}
	if lash:
		cfg = {"dmg": 2.0, "blast": 3.2, "speed": 38.0, "marks": 2, "empower": true}
	var thorn := String(Travel.relics.get("thorn", ""))
	if thorn != "":
		cfg["thorn"] = thorn
	var b := book.player.fire_bolt(cfg)
	if b != null and lash:
		book.player.kick(0.25)
	return b != null
