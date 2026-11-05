extends SkillLance
## Ember Lance with the Kindling's ranks (progression system).
##   I   Quick Draw: charges faster (the runtime sets max_charge). Let go within PERFECT seconds of
##       the full-charge snap for a Perfect throw: +30% damage, a white ring and a bell.
##   II  Wide Ember: wider burst, harder tap, and the burst throws three cinders that burst again.
##   III Cinder Scar: a full charge leaves a Cinder Scar where it bursts.
## Oath of the Pyre: a full charge hits 50% harder (and charges faster, via max_charge).
## On a Marked foe the burst kindles the Marks (KINDLED RIFT, MagicBolt); over an Umbral Well it
## lights a MAELSTROM; on a frozen foe it SHATTERs.

const DB := preload("res://core/life/progression/upgrade_db.gd")
const CinderScar := preload("res://core/life/progression/fx/cinder_scar.gd")
const Cinders := preload("res://core/life/progression/fx/ember_cinders.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const Combo := preload("res://core/skills/combo.gd")
const PERFECT := 0.2           ## seconds after the full-charge snap that still count as Perfect
const PERFECT_MULT := 1.3

var perfects := 0              ## Perfect throws so far (tests)


func blast_at(c: float) -> float:
	return super.blast_at(c) + (1.0 if int(DB.get_mod("lance", 0)) >= 2 else 0.0) + float(DB.get_mod("lance_blast", 0.0))


func cast(book: SkillBook, charge: float) -> bool:
	var r := int(DB.get_mod("lance", 0))
	var c := clampf(charge, 0.0, 1.0)
	var full := c >= 0.98
	var perfect := r >= 1 and full and book.last_overcharge >= 0.0 and book.last_overcharge <= PERFECT
	var tap := 2.5 if r >= 2 else 2.0
	var power := float(DB.get_mod("power", 1.0))
	var cfg := {
		"heavy": true,
		"dmg": lerpf(tap, DMG_FULL, c) * power * (1.5 if full and bool(DB.get_mod("pyre", false)) else 1.0) * (PERFECT_MULT if perfect else 1.0),
		"blast": lerpf(BLAST_MIN, BLAST_MAX, c) + (1.0 if r >= 2 else 0.0) + float(DB.get_mod("lance_blast", 0.0)),
		"speed": lerpf(18.0, 30.0, c) * (1.15 if perfect else 1.0),
		"pierce": full,
		"power": power,
	}
	var p := book.player
	var b := p.fire_bolt(cfg)
	if b == null:
		return false
	p.kick(0.25 + c * 0.6 + (0.25 if perfect else 0.0))
	if perfect:
		perfects += 1
		_perfect_fx(p, b)
	if r >= 2:
		b.burst_hooks.append(func(at: Vector3) -> void: Cinders.throw(at, power, b.direction))
	if r >= 3 and full:
		CinderScar.follow(b)
	return true


func _perfect_fx(p: Player, b: Node3D) -> void:
	var at := b.global_position
	var dir := (b as MagicBolt).direction
	Vfx.ring(at, 0.9, Color(3.4, 3.0, 2.4), 0.22, 0.1, dir)
	Vfx.ring(at, 1.5, Color(3.0, 1.6, 0.7), 0.3, 0.06, dir)
	Vfx.burst(at, Color(3.6, 3.2, 2.6), {"count": 24, "life": 0.3, "speed": Vector2(3.0, 7.0), "size": 0.04, "gravity": 0.0, "trail": 0.07, "dir": dir, "spread": 30.0})
	StaffSfx.play("perfect", at, -1.0)
	HitText.pop(p.global_position + Vector3.UP * 2.3, "PERFECT", Color(1.0, 0.92, 0.7), true)
