extends SkillBolt
## Rift Bolt with the Kindling's ranks (progression system). Same chain and Lash as SkillBolt;
## the numbers come from UpgradeDB.live.
##   I   Keen: faster, wider, and bolts bend toward a foe near the aim (MagicBolt.seek); a hotter
##       streak and a thin whistle over the shot.
##   II  Deep Marks: the Lash leaves 3 Marks, bursts wider, and its rune drags foes in to the burst.
##   III Through: ordinary bolts pass through bodies (the Lash still bursts).
## Oath of the Lash: the Lash comes every 2nd bolt. Rift Step II (Slip) and a riposte make the
## next bolt a Lash (combos SLIP LASH / RIPOSTE LASH). The staff core (Prism, Lodestar, Cinder,
## Rime) rides along on every bolt.

const DB := preload("res://core/life/progression/upgrade_db.gd")
const Combo := preload("res://core/skills/combo.gd")
const StaffSfx := preload("res://core/vfx/staff_sfx.gd")
const SEEK := 2.6              ## rad/s (Keen)
const PULL_PAD := 1.6          ## the Lash rune drags from this far past its burst


func _every() -> int:
	return int(DB.get_mod("lash_every", 3))


func pips(_book: SkillBook) -> Vector2i:
	var n := _every()
	var now := Time.get_ticks_msec() * 0.001
	if now - _last > CHAIN_WINDOW:
		return Vector2i(0, n)
	return Vector2i(_chain % n, n)


func primed(book: SkillBook) -> bool:
	if book.player and (book.player.get("_riposte_ready") == true or _slip(book.player)):
		return true
	var now := Time.get_ticks_msec() * 0.001
	return now - _last <= CHAIN_WINDOW and _chain % _every() == _every() - 1


func _slip(p: Node) -> bool:
	return float(p.get_meta(&"slip_lash_until", 0.0)) > Time.get_ticks_msec() * 0.001


func cast(book: SkillBook, _charge: float) -> bool:
	var p := book.player
	var r := int(DB.get_mod("bolt", 0))
	var power := float(DB.get_mod("power", 1.0))
	var now := Time.get_ticks_msec() * 0.001
	_chain = _chain + 1 if now - _last <= CHAIN_WINDOW else 1
	_last = now
	var riposte := p.consume_riposte()
	var slip := not riposte and _slip(p)
	if slip:
		p.remove_meta(&"slip_lash_until")
	var lash := riposte or slip or _chain % _every() == 0
	var cfg := {"dmg": 1.0, "blast": 1.8, "speed": 34.0, "marks": 1}
	if lash:
		cfg = {"dmg": 2.0, "blast": 3.2, "speed": 38.0, "marks": 2, "empower": true}
	if r >= 1:
		cfg.speed = float(cfg.speed) * 1.2
		cfg.blast = float(cfg.blast) + 0.5
		cfg.seek = SEEK
	if r >= 2 and lash:
		cfg.marks = 3
		cfg.blast = float(cfg.blast) + 0.8
	cfg.dmg = float(cfg.dmg) * power * (float(DB.get_mod("lash_power", 1.0)) if lash else 1.0)
	cfg.power = power
	cfg.core = String(DB.get_mod("core", ""))
	var thorn := String(Travel.relics.get("thorn", ""))
	if thorn != "":
		cfg["thorn"] = thorn
	var b := p.fire_bolt(cfg)
	if b == null:
		return false
	if r >= 3 and not lash:
		b.pierce = true          # set after arming: keeps the violet core (arm_with would whiten it)
	if r >= 1:
		StaffSfx.play("dart", b.global_position, -13.0, 1.5)     # Keen: a thin whistle over the shot
	if r >= 2 and lash:
		var blast := float(cfg.blast)
		b.burst_hooks.append(func(at: Vector3) -> void: _rune_pull(p, at, blast))
	if lash:
		p.kick(0.25)
		if riposte or slip:
			Combo.note("RIPOSTE LASH" if riposte else "SLIP LASH", p.global_position + Vector3.UP * 2.0, Color(0.8, 0.55, 1.0))
	return true


## Deep Marks: the Lash's rune drags foes inward to its burst for a moment.
static func _rune_pull(p: Node, at: Vector3, blast: float) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var reach := blast + PULL_PAD
	var n := 0
	for node in p.get_tree().get_nodes_in_group(Groups.ENEMY):
		var e := node as Node3D
		if e == null or (e.has_method("is_alive") and not e.call("is_alive")):
			continue
		var d := at - e.global_position
		if absf(d.y) > 3.0:
			continue
		d.y = 0.0
		var dist := d.length()
		if dist > reach or dist < 0.4:
			continue
		e.set("_knock", d / dist * minf(9.0, dist * 3.2) * (0.35 if bool(e.get("boss")) else 1.0))
		n += 1
	SpellFx.disc(at, reach, 0, SpellFx.VIOLET * 0.55, SpellFx.VIOLET_HOT * 0.7, 0.45)
	Vfx.burst(at + Vector3.UP * 0.6, SpellFx.VIOLET_HOT, {"count": 40, "life": 0.35, "speed": Vector2(0.0, 0.3), "size": 0.04, "radius": reach * 0.9, "radial": -reach * 5.0, "gravity": 0.0, "trail": 0.08})
	StaffSfx.play("rune_pull", at, -3.0 if n > 0 else -8.0)
