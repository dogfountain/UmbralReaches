extends RefCounted
## SECRETS (docs/LIFE_PLAN.md): exploration rewards and a world that remembers. Built by
## Realm.build after progression, village and life. Owns core/life/secrets/* only.
##   site_rim.gd      the Fallen Bells (bell puzzle), the Founder's Spill (ledge behind a lava
##                    curtain), the Rim Bridge (rope-bridge shortcut)          - the rift's west rim
##   site_fen.gd      the Upturned Barrow (opens after the bells; elite), Corvin's Drowned Crypt
##                    (lamp rite puzzle; elite), the Lay Brothers' Stair (postern gate shortcut)
##   site_wood.gd     the Hollow Oak (opens when the Thornwarden dies; elite), Ansel's Cist
##                    (kneeling-stone sequence), Pell's Den, Hobb's Cairn
##   site_glade.gd    (r28) the Singing Stones: sing back the small stone's phrase; wisps wake
##   site_breath.gd   (r28) the Ash-Hermit's Perch: jump into the rift's breath (breath_vent.gd)
##   site_company.gd  (r28) the Ninth Company's offering: shows once its three letters are read
##   site_r34.gd      (r34) the Cutters' Nook (climb-only), the Ninth Rank (lamp order), Corvin's
##                    Sluice (lever raises a sunk walk) in the new ground
##   (r28) the Lower Count under the Ossuary lives in world/areas/ossuary/oss_deep.gd and registers
##         its places here when it is built; beam.gd is its caught light
##   reactivity.gd    after each boss: brambles wither + moonlight (Thornwarden), the fen clears and
##                    its drowned graves get candles (Bone Abbot), the vortex sky calms in stages;
##                    marks where seals broke
##   director.gd      discovery, elite guardians, live reactions to boss kills and seal breaks
## State: Travel.system_state("secrets") (state.gd). Texts: pages.gd. Tests: zz/secrets_test.

const State := preload("res://core/life/secrets/state.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const SiteRim := preload("res://core/life/secrets/site_rim.gd")
const SiteFen := preload("res://core/life/secrets/site_fen.gd")
const SiteWood := preload("res://core/life/secrets/site_wood.gd")
const SiteGlade := preload("res://core/life/secrets/site_glade.gd")
const SiteBreath := preload("res://core/life/secrets/site_breath.gd")
const SiteCompany := preload("res://core/life/secrets/site_company.gd")
const SiteR34 := preload("res://core/life/secrets/site_r34.gd")      # r34 places: the new ground's secrets
const Reactivity := preload("res://core/life/secrets/reactivity.gd")
const Director := preload("res://core/life/secrets/director.gd")
const SecretsPanel := preload("res://core/life/secrets/panel.gd")

static var build_ms := {}


static func build(root: Node) -> void:
	if root.get_node_or_null("Secrets") != null:
		return
	State.sites.clear()
	State.elites.clear()
	State.st()
	var host := Node3D.new()
	host.name = "Secrets"
	host.set_meta("site", "secrets")
	root.add_child(host)
	State.host = host
	await root.get_tree().physics_frame
	build_ms.clear()
	var t := Time.get_ticks_usec()
	SiteRim.build(root, host)
	build_ms["rim"] = (Time.get_ticks_usec() - t) / 1000
	t = Time.get_ticks_usec()
	SiteFen.build(root, host)
	build_ms["fen"] = (Time.get_ticks_usec() - t) / 1000
	t = Time.get_ticks_usec()
	SiteWood.build(root, host)
	build_ms["wood"] = (Time.get_ticks_usec() - t) / 1000
	t = Time.get_ticks_usec()
	if not "--no-r28-secrets" in OS.get_cmdline_user_args():     # A/B switch for perf measurements
		SiteGlade.build(root, host)
		SiteBreath.build(root, host)
		SiteCompany.build(root, host)
	build_ms["r28"] = (Time.get_ticks_usec() - t) / 1000
	t = Time.get_ticks_usec()
	if not "--no-r34-secrets" in OS.get_cmdline_user_args():
		SiteR34.build(root, host)
	build_ms["r34"] = (Time.get_ticks_usec() - t) / 1000
	# --- r37 east ---
	if not "--no-r37-east" in OS.get_cmdline_user_args():
		(load("res://core/life/secrets/site_r37_east.gd") as GDScript).call("build", root, host)
	t = Time.get_ticks_usec()
	Kit.prewarm()
	build_ms["snd"] = (Time.get_ticks_usec() - t) / 1000
	t = Time.get_ticks_usec()
	_clear_walks()
	var cleared := Kit.flush_flora(root)
	build_ms["flora"] = (Time.get_ticks_usec() - t) / 1000
	t = Time.get_ticks_usec()
	Reactivity.build(root, host)
	build_ms["react"] = (Time.get_ticks_usec() - t) / 1000
	State.refresh(false)
	var d: Node = Director.new()
	d.name = "SecretsDirector"
	host.add_child(d)
	if root.get_tree().get_first_node_in_group("secrets_panel") == null:
		var p: Node = SecretsPanel.new()
		p.name = "SecretsPanel"
		host.add_child(p)
	print("SECRETS %d places, %d elites, %d plants cleared, build %s ms" % [State.sites.size(), State.elites.size(), cleared, build_ms])


## Tests and renders: put the puzzles and gates in a solved/open state in `st` (in memory).
## list: "all", or ids: bells, cist, rite, bridge, postern.
static func debug_solve(st: Dictionary, list: Array) -> void:
	for g: String in State.GROUPS:
		if not (st.get(g) is Dictionary):
			st[g] = {}
	var all := "all" in list
	for p: String in ["bells", "cist", "rite"]:
		if all or p in list:
			(st.solved as Dictionary)[p] = true
	for o: String in ["bridge", "postern"]:
		if all or o in list:
			(st.open as Dictionary)[o] = true
	# the Lower Count (world/areas/ossuary/oss_deep.gd): "deep" opens all of it, "deep_slab" only
	# the way down
	if all or "deep" in list or "deep_slab" in list:
		(st.open as Dictionary)["deep_slab"] = true
	if all or "deep" in list:
		for o: String in ["deep_lift", "deep_hoard_door", "count_ended"]:
			(st.open as Dictionary)[o] = true
		for p: String in ["deep_dials", "deep_beam"]:
			(st.solved as Dictionary)[p] = true
		(st.elites as Dictionary)["sexton"] = true
		st["deep"] = {"drum": 3, "mirror_e": 4, "mirror_w": 2, "dials": [4, 2, 5]}
	for p: String in ["singing", "breath", "company"]:
		if all or p in list:
			(st.solved as Dictionary)[p] = true
	# r34 places: the Ninth Rank's lamps (puzzle), Corvin's Sluice (lever)
	if all or "ninth" in list:
		(st.solved as Dictionary)["ninth"] = true
	if all or "sluice" in list:
		(st.open as Dictionary)["sluice"] = true


## r34 layout: the secrets' walks (route, the kneeling stones, the postern's crest and stair) are ways
## a player takes, so no trunk or log stands on them. The doubled Realm's flora draws its trees afresh
## everywhere (one seeded sequence over twice the ground), and a trunk landed on the kneeling stones' line.
static func _clear_walks() -> void:
	var discs: Array = []
	for s: Dictionary in State.sites:
		var lines: Array = []
		if s.has("route"):
			var r: Dictionary = s.route
			var pl: Array = [r.from]
			pl.append_array(r.pts)
			lines.append(pl)
		for key: String in ["kneel", "crest", "stair"]:
			if s.has(key) and s[key] is Array:
				lines.append(s[key])
		if s.has("kneel") and (s.kneel as Array).size() >= 5:
			lines.append([s.kneel[0], s.kneel[2], s.kneel[4]])       # Ansel's mark: twelve, seven, three
		for pl: Array in lines:
			var prev: Variant = null
			for v: Variant in pl:
				var q := Vector2.INF
				if v is Vector3:
					q = Vector2((v as Vector3).x, (v as Vector3).z)
				elif v is Vector2:
					q = v
				elif v is Array and not (v as Array).is_empty() and (v as Array)[-1] is Vector2:
					q = (v as Array)[-1]
				if q == Vector2.INF:
					continue
				if prev != null:
					var a: Vector2 = prev
					var n := maxi(1, ceili(a.distance_to(q) / 1.5))
					for k in n + 1:
						var c := a.lerp(q, float(k) / n)
						discs.append(Vector3(c.x, c.y, 1.2))
				prev = q
	Kit.clear_flora(null, discs)
