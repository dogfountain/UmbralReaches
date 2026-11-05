extends RefCounted
## Encounters: what every named elite shares -- stats from Elites.ELITES (before _ready), and the
## tier/Umbral scaling the director applies before it enters the tree.

const Elites := preload("res://core/life/encounters/elites.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Synth := preload("res://core/vfx/synth.gd")


static func stats(e: Enemy, id: String) -> void:
	var d: Dictionary = Elites.ELITES.get(id, {})
	e.max_hp = int(d.get("hp", 12))
	e.hp = float(e.max_hp)
	e.chase_range = maxf(e.chase_range, 16.0)
	e.hunt_leash = maxf(e.hunt_leash, 22.0)
	e.sleep_range = 60.0
	e.poise += 1.5
	e.strike_gloom *= 1.25
	e.set_meta(&"elite_id", id)


## Tier and Umbral form (NG+): health climbs half as fast as a camp pawn's, damage the same.
static func scale(e: Enemy, tier: int, umbral: bool) -> void:
	var t := Tiers.info(tier)
	var hp := float(e.max_hp) * (0.5 + 0.5 * float(t.hp)) * (Elites.UMBRAL_HP if umbral else 1.0)
	e.max_hp = roundi(hp)
	e.hp = float(e.max_hp)
	e.strike_gloom *= float(t.dmg)
	if "spit_gloom" in e:
		e.set("spit_gloom", float(e.get("spit_gloom")) * float(t.dmg))
	if umbral:
		e.set_meta(&"enc_umbral", true)
		e.walk_speed *= 1.06
	e.set_meta(&"enc_tier", tier)


## An audible tell in time with a visible one.
static func knock(e: Node3D, n: int, gap: float, pitch := 0.7) -> void:
	var tw := e.create_tween()
	for i in n:
		tw.tween_callback(func() -> void:
			if is_instance_valid(e):
				Sfx.play_stream(Synth.get_stream("bone"), e.global_position + Vector3.UP * 1.4, 2.0, pitch))
		tw.tween_interval(gap)
