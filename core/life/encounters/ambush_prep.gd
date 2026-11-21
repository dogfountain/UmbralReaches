extends RefCounted
## An ambush's risers built ahead (camps and villages perf pass, 21 Nov). An ambush built its two to four foes as it was
## sprung, one a frame, each a whole creature in the frame it rose (1.4-7 ms warm, beside its burst and the banner). Now the
## nearest open ambush site within PREP_R gets its risers built one at a time, on frames with room (Staging.claim), at the
## site and unseen (Staging.stage: asleep, hidden, no collision, out of the foes' group). When it is sprung, director.gd
## takes them in order (`next`): each is set on its rise spot and shown, as a fresh one was; any it lacks is built as before.
## Their kinds and looks are the site's region's (the sprung ambush picks by the wanderer's own: the same region).
## Load by path (no class_name).

const Staging := preload("res://core/life/encounters/staging.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const AmbushSites := preload("res://core/life/encounters/ambush_sites.gd")
const PREP_R := 110.0                  ## a site this near gets its risers built
const DROP_R := 170.0                  ## a site this far lets its unsprung risers go (one a claimed frame): the roads hold
                                       ## many sites, and a ride past them all should not leave each one's risers standing
const KEEP := &"prep"


## How many an ambush at `at` raises at most (trigger_ambush's want before the room cap).
static func most(at: Vector3) -> int:
	var tier := Tiers.tier_at(at)
	return 2 + (1 if tier >= 2 else 0) + (1 if tier >= 4 else 0)


## One more riser for the nearest open site in reach that lacks one, else one let go at a site left behind (either on a
## claimed frame). `make` is director.gd's _make: make.call(kind, at, tier, look, fx) -> Enemy.
static func step(sites: Array, pos: Vector3, owner: Node, made_ambushes: int, make: Callable) -> void:
	if Staging.OFF:
		return
	var best: Dictionary = {}
	var bd := PREP_R
	var drop: Dictionary = {}
	for s: Dictionary in sites:
		var at: Vector3 = s.at
		var d := pos.distance_to(at)
		if d > DROP_R:
			if drop.is_empty() and _ready_n(s) > 0:
				drop = s
			continue
		if float(s.cd) > 0.0:
			continue
		if d < bd and _ready_n(s) < most(at):
			best = s
			bd = d
	if (best.is_empty() and drop.is_empty()) or not Staging.claim(owner):
		return
	if best.is_empty():
		var gone: Variant = (drop[KEEP] as Array).pop_back()
		if is_instance_valid(gone):
			(gone as Node).queue_free()
		return
	var at2: Vector3 = best.at
	var have: Array = best.get(KEEP, [])
	var n := have.size()
	var pool: Array = AmbushSites.kinds(Tiers.REGION_POOL.get(Tiers.region_id(at2), ["wretch"]))
	var kind := String(pool[n % pool.size()])
	var rv := Tiers.region_variant(at2, kind)
	var look := rv if rv != "" else Tiers.pick_variant(at2, "amb%d" % n, made_ambushes)
	var e: Enemy = make.call(kind, at2, Tiers.tier_at(at2), look, false)      # (no rift effect: nobody sees it built)
	if e == null:
		return
	Staging.stage(e)
	have.append(e)
	best[KEEP] = have


static func _ready_n(s: Dictionary) -> int:
	var have: Array = s.get(KEEP, [])
	for i in range(have.size() - 1, -1, -1):
		if not is_instance_valid(have[i]):
			have.remove_at(i)
	return have.size()


## The next riser built ahead for this site, or null (it is then built as before).
static func next(s: Dictionary) -> Enemy:
	var have: Array = s.get(KEEP, [])
	while not have.is_empty():
		var e: Variant = have.pop_front()
		if is_instance_valid(e) and (e as Enemy).is_alive():
			return e as Enemy
	return null


## A riser built ahead, set on its spot and shown (what a fresh one was at its build).
static func place(e: Enemy, spot: Vector3) -> void:
	Staging.rise(e)
	e.global_position = spot + Vector3.UP * 0.05
	e.home = spot
	e.reset_physics_interpolation()
