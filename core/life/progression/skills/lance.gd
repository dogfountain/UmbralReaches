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
const SCATTER_DMG := 0.5        ## r36 Scatter: each of the three lances
const SCATTER_BLAST := 0.7
const SCATTER_FAN := 0.24       ## radians either side of the aim
const BRAND_DMG := 0.85
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
	# r36 Slag Heart: Scatter throws a fan of three at half strength; Brand Marks the burst twice
	var v := Reliquary.variant("slag")
	if v == &"scatter":
		cfg.dmg = float(cfg.dmg) * SCATTER_DMG
		cfg.blast = float(cfg.blast) * SCATTER_BLAST
	elif v == &"brand":
		cfg.dmg = float(cfg.dmg) * BRAND_DMG
	var b := p.fire_bolt(cfg)
	if b == null:
		return false
	if v == &"scatter":
		_scatter(p, b, cfg)
	elif v == &"brand":
		var br: float = cfg.blast
		b.burst_hooks.append(func(at: Vector3) -> void: _brand(p, at, br))
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


## r36 Scatter: two more lances either side of the first, same throw (cfg already halved).
func _scatter(p: Player, first: MagicBolt, cfg: Dictionary) -> void:
	var dir := first.direction
	for side: float in [-SCATTER_FAN, SCATTER_FAN]:
		var c2 := cfg.duplicate()
		c2["dir"] = dir.rotated(Vector3.UP, side)
		p.fire_bolt(c2)


## r36 Brand: every living foe in the burst takes two Marks.
func _brand(p: Player, at: Vector3, r: float) -> void:
	var n := 0
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Enemy
		if e and e.is_alive() and e.global_position.distance_to(at) <= r:
			e.add_mark(2)
			n += 1
	if n > 0:
		Vfx.ring(at + Vector3.UP * 0.06, r, Color(3.0, 1.2, 0.4), 0.35, 0.08, Vector3.UP, 1.2)
