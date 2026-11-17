extends Control
## Unit frames (r33, after WoW's): the wanderer's own frame top left, the target's frame under the
## compass, a boss frame in its place during a boss fight, and the player's cast bar over the hotbar.
## All drawn in code on one Control (no textures, no WoW art): engraved ink plates, our ember /
## lantern palette, Cinzel for names and numbers.
##
##   Player frame   portrait medallion (the hooded wanderer, eyes lit; ember ring in a fight), name,
##                  level badge (when a level exists), Health (when it exists), Gloom, Breath, and a
##                  row of buffs / debuffs with timers and stacks. The Gloom you gain or shed flashes
##                  on the portrait as numbers, as WoW's portrait shows the hits you take.
##   Target frame   the locked-on foe, else the last one you hurt (held a few seconds). Name coloured
##                  by rank, an engraved wing frame round the rank emblem for elites (gold), rares
##                  (moon silver) and bosses (ember, crowned); health with percent; a cast bar for
##                  its wind-ups with the move's name, marked when a heavy blow can break it; and
##                  the afflictions you put on it (burn, rime stacks, frozen, slowed, marks).
##   Boss frame     the engaged boss: wider, phase notches and numeral, its cast bar and your
##                  afflictions. The arena's plain bar steps aside while it shows.
##
## Reads everything defensively, so data other systems add later lights up a widget and nothing
## breaks without it. What it reads (all optional, first found wins):
##   player   CombatState (p.combat(): statuses_of(p), get_target()), SkillBook.cast_info() {name, t,
##            total, color}, the Hearth's xp_info().level / .rested (group "hearth"), health /
##            max_health, buffs() -> [{name, glyph, color, left, dur, stacks, debuff}], plus what
##            the game already knows (firelight, a ward's store, riposte, kill chain, tide, winded,
##            hollowing blows)
##   enemy    display_name(), rank(), level() (-1: "??"), cast_info() {name, progress | t/total,
##            interruptible}, debuffs() [{id, name, left, stacks, harmful}], is_evading(), and
##            CombatState.statuses_of(enemy); older fallbacks: elite / guardian tables, enc_tier,
##            Afflict records, the wind-up states
##   events   target_changed, enemy_cast_ended (an "INTERRUPTED" flash), cast_stopped (yours)
## Typed where the target is always one script; the wanderer, foes and Breath stay dynamic (test stand-ins).
## Added by ui/hud.gd. Hidden while paused and under the loading screen.

const Afflict := preload("res://core/skills/afflict.gd")
const Tiers := preload("res://core/life/encounters/tiers.gd")
const Danger := preload("res://core/life/encounters/danger.gd")
const Elites := preload("res://core/life/encounters/elites.gd")
const Guardians := preload("res://core/life/encounters/guardians.gd")
const EncHud := preload("res://core/life/encounters/encounter_hud.gd")
const Hearth := preload("res://core/life/progression/hearth.gd")
const CombatState := preload("res://core/skills/combat_state.gd")
const StaffArts := preload("res://core/player/staff_arts.gd")
const UIType := preload("res://ui/type.gd")
const Med := preload("res://ui/medieval_style.gd")
const HudPrefs := preload("res://ui/hud_prefs.gd")
const Forge := preload("res://ui/hud_forge.gd")
const GloomMeter := preload("res://ui/gloom_meter.gd")

const LANTERN := Color("#FFB347")
const EMBER := Color("#FF6A2A")
const LILAC := Med.GILT
const INK := Color(0.93, 0.88, 0.8)
const QUIET := Color(0.78, 0.74, 0.7, 0.9)
const RIM := Color(0.5, 0.4, 0.28)
const GOLD := Color(0.95, 0.74, 0.36)
const MOON := Color(0.78, 0.86, 1.0)
const BLOOD := Color(0.78, 0.2, 0.14)
const HEALTH := Color(0.6, 0.09, 0.09)
const BREATH := Color(0.74, 0.7, 0.98)
const BUFF_RIM := Color(0.95, 0.76, 0.4)
const DEBUFF_RIM := Color(0.95, 0.3, 0.22)

const RANK_COL := {
	"normal": Color(0.96, 0.6, 0.46), "elite": Color(1.0, 0.8, 0.4), "rare": MOON,
	"rare_elite": Color(0.86, 0.9, 1.0), "boss": Color(1.0, 0.45, 0.26), "umbral": Color(0.74, 0.64, 1.0),
}
const RANK_NAME := {"normal": "", "elite": "Elite", "rare": "Rare", "rare_elite": "Rare Elite", "boss": "Boss"}

## Where things sit on the 1600 x 900 (and 1920 x 1080) canvas.
const PF_POS := Vector2(22, 16)
const PORTRAIT_R := 42.0
const BOSS_LEAVE_M := 60.0         ## a boss this far away is no longer the fight
const PF_W := 330.0                ## the plate right of the portrait
const PF_H := 130.0              ## and its height: name, Wounds, the Gloom meter, Breath
const TF_W := 380.0
const BF_W := 480.0
const TF_TOP := 92.0               ## under the compass
const ICON := 30.0
const SOFT_HOLD := 7.0             ## seconds the last foe you hurt stays your target
const SOFT_RANGE := 40.0

var _font: Font
var _body: Font
var _player: Node3D
var _alpha := 0.0
var _t := 0.0
var _scan := 0.0
var _now := 0.0

# player
var _buffs: Array = []             ## {name, glyph, color, left, dur, stacks, debuff}
var _buff_names_seen := {}
var _buff_note := ""
var _buff_note_t := 0.0
var _portrait_pops: Array = []     ## {text, col, t}
var _last_gloom := -1.0
var _fight := 0.0
var _p_trail := -1.0               ## the strip of health just lost, which drains away behind the bar
var _tide := false

# target
var _target: Node3D
var _soft: Node3D
var _soft_t := 0.0
var _hp_seen := {}                 ## enemy instance id -> hp at the last scan
var _t_trail := 1.0                ## the pale "just lost" strip behind the target's health
var _t_trail_id := 0
var _t_dead := 0.0
var _t_alpha := 0.0
var _titles := {}                  ## boss instance id -> title (from boss_engaged)
var _broke := {}                   ## enemy instance id -> [cast name, time] of a cast just interrupted
var _dur_seen := {}                ## "enemy id:status" -> the longest time_left seen (a sweep needs a whole)
var _my_stop := ["", 0.0, ""]      ## your last cast that stopped: [name, time, reason]
var _hearth: Hearth
var _deb_cache := {}               ## enemy instance id -> [time read, Array]

# boss
var _boss: Node3D
var _boss_title := ""
var _boss_arena: BossArena
var _b_trail := 1.0
var _b_alpha := 0.0


func _ready() -> void:
	name = "UnitFrames"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = UIType.title()
	_body = UIType.body()
	HudPrefs.ensure()
	for nm: String in LAYERS:
		var c := Control.new()
		c.name = nm.capitalize()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(_draw_layer.bind(c, nm))
		add_child(c)
		_layers[nm] = c
	Events.boss_engaged.connect(_on_boss_engaged)
	Events.boss_slain.connect(func(_id: String) -> void: _end_boss())
	Events.player_hurt.connect(_on_hurt)
	Events.gloom_tide.connect(func(on: bool) -> void: _tide = on)
	Events.enemy_cast_ended.connect(func(e: Node, cast: String, interrupted: bool) -> void:
		if interrupted and e != null:
			_broke[e.get_instance_id()] = [cast, _now])
	Events.cast_stopped.connect(func(id: StringName, reason: StringName) -> void:
		if reason == &"interrupted" or reason == &"moved":
			_my_stop = [String(id), _now, String(reason)])
	Events.hollowed.connect(func() -> void:
		_soft = null
		_end_boss())


func _process(delta: float) -> void:
	_t += delta
	_now = Time.get_ticks_msec() * 0.001
	var zone := get_tree().current_scene
	var hidden := get_tree().paused or not HudPrefs.unit_frames \
		or (zone != null and zone.get_node_or_null("LoadingScreen") != null)
	_alpha = move_toward(_alpha, 0.0 if hidden else 1.0, delta * 5.0)
	modulate.a = _alpha
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if _player == null:
		return
	_track_gloom()
	_tick_trail(delta)
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.25
		_rescan()
	for b: Dictionary in _buffs:
		if float(b.get("left", -1.0)) > 0.0:
			b.left = maxf(0.0, float(b.left) - delta)
	_buff_note_t = maxf(0.0, _buff_note_t - delta)
	for i in range(_portrait_pops.size() - 1, -1, -1):
		_portrait_pops[i].t = float(_portrait_pops[i].t) + delta
		if float(_portrait_pops[i].t) > 1.3:
			_portrait_pops.remove_at(i)
	_pick_target(delta)
	_tick_boss(delta)
	_tick_encounter_layout()
	if _alpha > 0.0 and _any_due():
		_redraw_layers()


## Five canvas items, each redrawn only when what it shows changes or moves (one item redrawn every frame of a
## fight cost ~0.7 ms of script a frame): the wanderer's plate, IN COMBAT, the boss, the target, the cast bar.
const LAYERS := ["player", "bars", "auras", "combat", "boss", "target", "cast"]
var _layers := {}                ## name -> its Control
var _ci: CanvasItem = self       ## the canvas the drawing helpers draw on (the layer being drawn)
var _lsig := {}                  ## name -> what it last drew


func _redraw_layers() -> void:
	var gr := float(_p("gloom", 0.0)) / maxf(float(_p("gloom_max", 100.0)), 0.001)
	var psig: Array = [snappedf(_alpha, 0.001), _p("wounds", 0.0), _p("wounds_max", 0.0), _p("gloom", 0.0),
		_p("gloom_max", 100.0), _player_level(), _vs(), fposmod(_t, 5.3) > 0.12, HudPrefs.gloom_known(), _breath().snapped(Vector2(0.002, 1.0)),
		_buffs.map(func(b: Dictionary) -> Array: return [b.get("name", ""), b.get("glyph", ""), b.get("color", INK), b.get("stacks", 0), b.get("debuff", false)])]
	_mark("player", [snappedf(_alpha, 0.001), _player_level(), _vs(), fposmod(_t, 5.3) > 0.12, snappedf(smoothstep(0.55, 1.0, clampf(gr, 0.0, 1.0)), 0.02), _fight > 0.0], _alpha < 1.0)
	_mark("bars", psig, gr > 0.75 or not _portrait_pops.is_empty() or _alpha < 1.0 or (_p_trail > _health().x / maxf(_health().y, 0.001) + 0.0005))
	# only a timed buff moves (its sweep, its seconds); an untimed one is a still picture in the signature
	_mark("auras", [psig[psig.size() - 1], _vs()], _buff_note_t > 0.0 or _buffs.any(func(b: Dictionary) -> bool: return float(b.get("left", -1.0)) > 0.0))
	_mark("combat", [_fight > 0.0, _vs()], _fight > 0.0)
	_mark("boss", _unit_sig(_boss, _b_alpha, _b_trail, true), _casting(_boss, _b_alpha))
	_mark("target", _unit_sig(_target, _t_alpha, _t_trail, false) + [_boss != null], _casting(_target, _t_alpha))
	_mark("cast", [_cast_state().hash(), _vs()], not _cast_state().is_empty())


## A layer that moves (a sweep, a pulse, a bar easing, the Gloom's number climbing) redraws 30 to 40 times a second,
## not every frame: at 120 fps five of the seven redrew every frame of a fight, and the HUD was 2.15 ms of an 11 ms
## frame (fight_bench --hud-ab, --hud-draws). A change still shows within one such step: the signature is kept only
## when the layer is redrawn, so a skipped change is drawn on the next due frame. Which frame is due is FramePace's:
## a frame between physics ticks, the layers in two halves on alternate ones (they had all come due together).
const FramePace := preload("res://core/util/frame_pace.gd")
const SLOT := {"player": 1, "bars": 0, "auras": 1, "combat": 0, "boss": 1, "target": 0, "cast": 1}
var _ldraw := {}                 ## name -> msec of its last redraw


func _mark(nm: String, sig: Array, moving: bool) -> void:
	if not moving and sig == _lsig.get(nm):
		return
	if not FramePace.due(int(_ldraw.get(nm, -1000)), int(SLOT[nm])):
		return
	_ldraw[nm] = Time.get_ticks_msec()
	_lsig[nm] = sig
	(_layers[nm] as Control).queue_redraw()


## Is any layer's frame due? (When none is, what they would show is not even worked out.)
func _any_due() -> bool:
	for nm: String in LAYERS:
		if FramePace.due(int(_ldraw.get(nm, -1000)), int(SLOT[nm])):
			return true
	return false


func _casting(e: Variant, a: float) -> bool:      ## a shown foe mid-cast: its bar fills and BREAK pulses every frame
	return a > 0.0 and is_instance_valid(e) and _alive(e) and not _cast_of(e).is_empty()


func _breath() -> Vector2:                      ## the breath bar's (ratio, winded 1/0); x -1 when there is none
	var st := _stamina()
	if st and st.has_method("ratio"):
		return Vector2(float(st.call("ratio")), 1.0 if "winded" in st and bool(st.get("winded")) else 0.0)
	return Vector2(-1.0, 0.0)


## What a boss's or target's frame shows (a cast's progress and afflictions' seconds included: they move).
func _unit_sig(ev: Variant, a: float, trail: float, is_boss: bool) -> Array:
	if a <= 0.0 or not is_instance_valid(ev):           # (untyped: a freed foe may be passed)
		return [0]
	var e := ev as Node3D
	var dead := not _alive(e)
	var cast := _cast_of(e) if not dead else {}
	var deb := (_debuffs_of(e) if not dead else []).map(func(b: Dictionary) -> Array: return [b.get("name", ""), b.get("stacks", 0), snappedf(float(b.get("left", -1.0)), 0.1)])
	return [e.get_instance_id(), snappedf(a, 0.01), snappedf(_ratio(e), 0.001), snappedf(trail, 0.002), dead,
		e.get("hp") if "hp" in e else 0, int(e.get("phase")) if is_boss and "phase" in e else 0, _vs(),
		String(cast.get("name", "")), cast.get("interruptible", true), deb, _boss_title if is_boss else _name_of(e)]


# --- data ------------------------------------------------------------------------------------------

func _p(prop: String, def: Variant = null) -> Variant:
	if _player == null or not (prop in _player):
		return def
	var v: Variant = _player.get(prop)
	return def if v == null else v


## (value, max) of the player's health when the game has one, else Vector2(-1, -1).
func _health() -> Vector2:
	# r35: the wanderer's top bar is what the Wounds leave of him (full = unhurt, empty = hollowed)
	if "wounds" in _player and "wounds_max" in _player:
		var wm := maxf(float(_player.get("wounds_max")), 0.001)
		return Vector2(wm - float(_player.get("wounds")), wm)
	for pair: Array in [["health", "max_health"], ["hp", "max_hp"]]:
		if pair[0] in _player and pair[1] in _player:
			return Vector2(float(_player.get(pair[0])), maxf(float(_player.get(pair[1])), 0.001))
	return Vector2(-1, -1)


func _level_of(n: Node) -> int:
	if n == null:
		return -1
	if n.has_method("level"):
		var v: Variant = n.call("level")
		if v is int or v is float:
			return int(v)
		if v is Dictionary:
			return int((v as Dictionary).get("level", -1))
	if "level" in n and (n.get("level") is int or n.get("level") is float):
		return int(n.get("level"))
	return -1


## The wanderer's level and rested pool from the Hearth (core/life/progression/hearth.gd), else
## anything the player itself reports. Vector2i(level, rested) or (-1, 0).
func _player_level() -> Vector2i:
	if not is_instance_valid(_hearth):
		_hearth = get_tree().get_first_node_in_group(&"hearth") as Hearth
	if _hearth:
		var d := _hearth.xp_info()
		return Vector2i(int(d.get("level", -1)), int(d.get("rested", 0)))
	return Vector2i(_level_of(_player), 0)


func _combat() -> CombatState:
	return _player.call("combat") as CombatState if _player.has_method("combat") else null


## A Node: a stand-in's stamina is not a Stamina script, so its reads stay dynamic.
func _stamina() -> Node:
	return _player.call("stamina") if _player.has_method("stamina") else null


func _tick_trail(delta: float) -> void:
	var hp := _health()
	if hp.x < 0.0:
		return
	var r := hp.x / hp.y
	_p_trail = r if (_p_trail < 0.0 or r >= _p_trail) else move_toward(_p_trail, r, delta * 0.45)


## A sudden mend (a kill, spent Resonance, a fire's first breath) rises off the portrait in gold;
## a blow is shown by _on_hurt with its own amount.
func _track_gloom() -> void:
	var w := float(_p("wounds", 0.0))
	if _last_gloom < 0.0:
		_last_gloom = w
		return
	var d := w - _last_gloom
	if d <= -2.0:
		_portrait_pop("+%d" % roundi(-d), Color(1.0, 0.82, 0.45))
	_last_gloom = w


func _on_hurt(amount: float, _from: Vector3) -> void:
	if amount >= 0.5:
		_portrait_pop("−%d" % roundi(amount), Color(1.0, 0.36, 0.26))
		_last_gloom = float(_p("wounds", 0.0)) + amount   # the blow lands on wounds after this signal
		_fight = 6.0


func _portrait_pop(text: String, col: Color) -> void:
	if _portrait_pops.size() >= 4:
		_portrait_pops.pop_front()
	_portrait_pops.append({"text": text, "col": col, "t": 0.0})


func _rescan() -> void:
	_fight = maxf(0.0, _fight - 0.25)
	var st := _stamina()
	if st and st.has_method("in_fight") and bool(st.call("in_fight")):
		_fight = maxf(_fight, 1.0)
	_buffs = _collect_buffs()
	for b: Dictionary in _buffs:
		var nm := String(b.get("name", ""))
		if nm != "" and not _buff_names_seen.has(nm):
			_buff_note = nm
			_buff_note_t = 3.0
		_buff_names_seen[nm] = _t
	for k: String in _buff_names_seen.keys():
		if _t - float(_buff_names_seen[k]) > 4.0:
			_buff_names_seen.erase(k)          # gone a while: its return is news again
	_scan_hurt()
	_sync_bars()


## Enemy health bars in the world are off unless the HUD setting is on; the locked-on target and the boss
## keep theirs (the bar is a render layer toggle: some enemies hide and show the bar themselves).
func _sync_bars() -> void:
	var on := HudPrefs.enemy_plates
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		var bar := e.get_node_or_null("HealthBar") as VisualInstance3D
		if bar == null:
			continue
		var want := on or e == _target or e == _boss
		var layers := 1 if want else 0
		if bar.layers != layers:
			bar.layers = layers


## What the wanderer carries: anything the player reports (buffs()), plus what the game already
## knows about: firelight, a Lantern Ward's store, the Ward's quickening, a riposte held ready, a
## kill chain, the Gloom tide and being winded.
func _collect_buffs() -> Array:
	var out: Array = []
	var cs := _combat()
	if cs:
		for st: Variant in cs.statuses_of(_player):
			if st is Dictionary:
				out.append(_from_status(st as Dictionary, "me"))
	if _player.has_method("buffs"):
		var ext: Variant = _player.call("buffs")
		if ext is Array:
			for b: Variant in ext:
				if b is Dictionary:
					out.append((b as Dictionary).duplicate())
	var lit := false
	if get_node_or_null("/root/LightGrid") != null:
		lit = float(LightGrid.drain_at(_player.global_position)) < 0.0
	if lit:
		out.append({"name": "Firelight", "glyph": "flame", "color": LANTERN, "left": -1.0, "stacks": 0})
	var ward := float(_p("ward_drain_left", 0.0))
	if ward > 0.0:
		out.append({"name": "Lantern Ward", "glyph": "ward", "color": Color(1.0, 0.85, 0.5), "left": -1.0, "stacks": roundi(ward)})
	var book := _player.call("skills") as SkillBook if _player.has_method("skills") else null
	if book:
		var left := book.boost_until - _now
		if left > 0.0:
			out.append({"name": "Quickened", "glyph": "quick", "color": Color(1.0, 0.9, 0.55), "left": left, "dur": 6.0, "stacks": 0})
	if bool(_p("_riposte_ready", false)):
		out.append({"name": "Riposte Ready", "glyph": "riposte", "color": Color(0.85, 0.55, 1.0), "left": -1.0, "stacks": 0})
	var chain := int(_p("_chain", 0))
	var chain_left := float(_p("_chain_until", 0.0)) - _now
	if chain >= 2 and chain_left > 0.0:
		out.append({"name": "Kill Chain", "glyph": "chain", "color": Color(0.8, 0.5, 1.0), "left": chain_left, "dur": 4.0, "stacks": chain})
	if _tide:
		out.append({"name": "Gloom Tide", "glyph": "tide", "color": Color(0.6, 0.5, 0.9), "left": -1.0, "stacks": 0, "debuff": true})
	if _breath().y > 0.5:
		out.append({"name": "Winded", "glyph": "winded", "color": Color(0.7, 0.78, 0.95), "left": -1.0, "stacks": 0, "debuff": true})
	var lv := _player_level()
	if lv.y > 0:
		out.append({"name": "Rested", "glyph": "rested", "color": Color(0.7, 0.66, 1.0), "left": -1.0, "stacks": 0})
	# buffs first, then debuffs (WoW keeps them in two rows; one row with a gap fits our corner)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(bool(a.get("debuff", false))) < int(bool(b.get("debuff", false))))
	return out


## A CombatState status or an enemy debuff, as an aura icon: {name, glyph, color, left, dur, stacks, debuff}.
func _from_status(st: Dictionary, owner_key: String) -> Dictionary:
	var id := String(st.get("id", st.get("name", "")))
	var left := float(st.get("time_left", st.get("left", -1.0)))
	var dur := float(st.get("duration", st.get("dur", -1.0)))
	var key := owner_key + ":" + id
	if dur <= 0.0 and left > 0.0:
		dur = maxf(float(_dur_seen.get(key, 0.0)), left)       # no whole given: the longest seen
		_dur_seen[key] = dur
	var harmful := bool(st.get("harmful", String(st.get("kind", "")) == "debuff"))
	var col: Color = st.get("color", _status_col(id, harmful))
	col = Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0), 1.0)   # statuses carry HDR glow colours
	var glyph := String(st.get("icon", st.get("glyph", "")))
	return {"name": String(st.get("name", id.capitalize())), "glyph": _glyph_for(glyph if glyph != "" else id), "color": col,
		"left": left, "dur": dur, "stacks": int(st.get("stacks", 0)), "debuff": harmful, "id": id}


func _glyph_for(id: String) -> String:
	match id:
		"umbral_mark", "mark":
			return "mark"
		"burning", "ember_scar":
			return "flame"
		"chilled", "rime":
			return "rime"
		"frozen":
			return "frozen"
		"slowed", "slow":
			return "slow"
		"warded", "ward":
			return "ward"
		"resonance":
			return "resonance"
		"surge":
			return "surge"
		"shaken", "broken", "silenced", "sundered", "shrouded", "enraged":
			return id
	return id


func _status_col(id: String, harmful: bool) -> Color:
	match id:
		"burning", "ember_scar":
			return Color(1.0, 0.5, 0.2)
		"chilled", "frozen":
			return Color(0.65, 0.86, 1.0)
		"umbral_mark", "mark", "sundered":
			return Color(0.85, 0.5, 1.0)
		"broken":
			return Color(1.0, 0.8, 0.5)
		"silenced":
			return Color(0.9, 0.9, 0.95)
		"shrouded", "warded":
			return Color(0.8, 0.7, 1.0)
		"enraged":
			return Color(1.0, 0.35, 0.25)
	return Color(1.0, 0.5, 0.4) if harmful else Color(1.0, 0.85, 0.5)


## Enemies near you that lost health since the last look: the newest becomes the soft target.
func _scan_hurt() -> void:
	var seen := {}
	var here := _player.global_position
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		var e3 := e as Node3D
		if e3 == null or not ("hp" in e3):
			continue
		if e3.global_position.distance_squared_to(here) > SOFT_RANGE * SOFT_RANGE:
			continue
		var id := e3.get_instance_id()
		var hp := float(e3.get("hp"))
		if _hp_seen.has(id) and hp < float(_hp_seen[id]) - 0.01:
			_soft = e3
			_soft_t = SOFT_HOLD
		seen[id] = hp
	_hp_seen = seen


func _alive(e: Node) -> bool:
	return e != null and is_instance_valid(e) and e.is_inside_tree() and (not e.has_method("is_alive") or bool(e.call("is_alive")))


func _pick_target(delta: float) -> void:
	_soft_t = maxf(0.0, _soft_t - delta)
	var want: Node3D = null
	if _player.has_method("lock_target"):
		want = _player.call("lock_target") as Node3D
	var plates := HudPrefs.enemy_plates
	if want == null and plates and _player.has_method("current_target"):
		want = _player.call("current_target") as Node3D          # CombatState's remembered target
	if want == null and plates and _soft_t > 0.0 and is_instance_valid(_soft) and _soft.is_inside_tree():
		if _soft.global_position.distance_to(_player.global_position) < SOFT_RANGE + 10.0:
			want = _soft
	if want == _boss and _boss != null:
		want = null                                  # the boss frame already shows it
	if want != null and want != _target:
		_target = want
		_t_dead = 0.0
		_t_trail = _ratio(want)
		_t_trail_id = want.get_instance_id()
	if _target != null and (not is_instance_valid(_target) or not _target.is_inside_tree()):
		_target = null
	if _target != null and not _alive(_target):
		_t_dead += delta                             # "Dead" for a moment, then the frame goes
		if _t_dead > 1.2:
			_target = null
			_soft = null
	elif _target != null and want == null and (_target != _soft or not plates):
		_target = null
	if _target != null:
		var r := _ratio(_target)
		_t_trail = r if r > _t_trail else move_toward(_t_trail, r, delta * 0.9)
	_t_alpha = move_toward(_t_alpha, 1.0 if _target != null else 0.0, delta * 6.0)


func _ratio(e: Node) -> float:
	if e == null or not is_instance_valid(e) or not ("hp" in e) or not ("max_hp" in e):
		return 0.0
	return clampf(float(e.get("hp")) / maxf(float(e.get("max_hp")), 0.001), 0.0, 1.0)


func _rank(e: Node) -> String:
	if e.has_method("rank"):
		var rk := String(e.call("rank"))
		if rk == "rare" and (e.has_meta(&"elite_id") or e.has_meta(&"guardian_id")):
			return "rare_elite"
		if rk != "":
			return rk
	var rv: Variant = e.get("rank")                  # a field, on stand-ins (null when it is a method)
	if (rv is String or rv is StringName) and String(rv) != "":
		return String(rv)
	if "boss" in e and bool(e.get("boss")):
		return "boss"
	if e.has_meta(&"boss_id"):
		return "boss"
	var rare := e.has_meta(&"rare") or e.has_meta(&"enc_rare") or e.has_meta(&"rare_id")
	var elite := e.has_meta(&"elite_id") or e.has_meta(&"guardian_id")
	if rare:
		return "rare_elite" if elite else "rare"
	return "elite" if elite else "normal"


func _name_of(e: Node) -> String:
	var id := e.get_instance_id()
	if _titles.has(id):
		return String(_titles[id])
	if e.has_method("display_name"):
		var dn := String(e.call("display_name"))
		if dn != "":
			return dn
	for k: String in ["display_name", "title"]:
		if k in e and e.get(k) is String and String(e.get(k)) != "":
			return String(e.get(k))
		if e.has_meta(StringName(k)):
			return String(e.get_meta(StringName(k)))
	if e.has_meta(&"elite_id"):
		var d: Dictionary = Elites.ELITES.get(String(e.get_meta(&"elite_id")), {})
		if d.has("title"):
			return String(d.title)
	if e.has_meta(&"guardian_id"):
		var g: Dictionary = Guardians.GUARDIANS.get(String(e.get_meta(&"guardian_id")), {})
		if g.has("title"):
			return String(g.title)
	var s: Script = e.get_script()
	var base := String(s.resource_path).get_file().get_basename() if s else String(e.name)
	var nm := base.replace("_", " ").capitalize()
	if e.has_meta(&"enc_variant") and String(e.get_meta(&"enc_variant")) != "":
		nm = String(e.get_meta(&"enc_variant")).capitalize() + " " + nm
	return nm


## "Night · Elite", "Lv 4 · Rare": the tier of the ground it walks, or its level when it has one.
func _subline(e: Node, rank: String) -> String:
	var parts := PackedStringArray()
	var lv := _level_of(e)
	if lv < 1 and lv != -1 and e.has_meta(&"enc_tier"):
		lv = int(Tiers.LEVEL_BAND[clampi(int(e.get_meta(&"enc_tier")), 0, Tiers.LEVEL_BAND.size() - 1)]) + 1       # no level of its own: the first level of its tier's band, not a tier name
	if lv >= 1:
		parts.append("Lv %d  %s" % [lv, String(Danger.NAMES[Danger.rate(lv)]) if rank != "boss" else Danger.NAMES[Danger.rate(lv - Danger.BOSS_RANK)]])
	elif lv == -1 and e.has_method("level"):
		parts.append("Lv ??")                                    # a boss: beyond counting
	if e.has_meta(&"enc_umbral"):
		parts.append("Umbral")
	if e.has_method("is_evading") and bool(e.call("is_evading")):
		parts.append("Evading")
	var rn := String(RANK_NAME.get(rank, ""))
	if rn != "":
		parts.append(rn)
	return "  ·  ".join(parts)


const FEINT_S := 0.3    ## enemy.gd FEINT lasts this long

## {name, t, interruptible, col} while it winds up a move, else {}.
func _cast_of(e: Node) -> Dictionary:
	var b: Array = _broke.get(e.get_instance_id(), [])
	if not b.is_empty() and _now - float(b[1]) < 0.9:
		return {"name": "INTERRUPTED  ·  " + String(b[0]), "t": 1.0, "interruptible": true, "broken": true}
	if e.has_method("cast_info"):
		var ci: Variant = e.call("cast_info")
		if not (ci is Dictionary) or (ci as Dictionary).is_empty():
			return {}
		var d := (ci as Dictionary).duplicate()
		if not d.has("t"):
			d["t"] = float(d.get("progress", 0.0))
		elif float(d.get("total", 0.0)) > 0.0:
			d["t"] = float(d.t) / float(d.total)
		return d
	if not ("_state" in e) or not _alive(e):
		return {}
	var st := int(e.get("_state"))
	var st_t := float(e.get("_state_t")) if "_state_t" in e else 0.0
	match st:
		8:      # FEINT: a rear with no red. The bar says so over the 0.3 s the fake lasts; BREAK waits for the red
			return {"name": "Feint", "t": clampf(st_t / FEINT_S, 0.0, 1.0), "interruptible": false}
		2:      # WINDUP: the real blow (the red starts with this fill)
			var w := float(e.get("_cur_windup")) if "_cur_windup" in e else 0.42
			var chained := int(e.get("_combo_left")) > 0 if "_combo_left" in e else false
			return {"name": "Flurry" if chained else "Strike", "t": clampf(st_t / maxf(w, 0.05), 0.0, 1.0), "interruptible": true}
		6:      # LEAP_PREP
			var lp := float(e.get("leap_prep")) if "leap_prep" in e else 0.45
			return {"name": "Pounce", "t": clampf(st_t / maxf(lp, 0.05), 0.0, 1.0), "interruptible": true}
		10:     # CALL
			return {"name": "Call the Pack", "t": clampf(st_t / 0.9, 0.0, 1.0), "interruptible": false}
		9:      # SPECIAL
			var sn: Variant = e.get("special_name")
			var nm := String(sn) if (sn is String or sn is StringName) else "Dark Working"
			var br := bool(e.call("_special_breakable")) if e.has_method("_special_breakable") else false
			return {"name": nm, "t": fposmod(st_t, 1.5) / 1.5, "interruptible": br, "unknown": true}
	return {}


## The afflictions on `e` (yours: the game has no other source): burn, rime, frozen, slowed, marks.
func _debuffs_of(e: Node) -> Array:
	# read four times a second (the timers count down between reads)
	var id := e.get_instance_id()
	var c: Array = _deb_cache.get(id, [])
	if not c.is_empty() and _now - float(c[0]) < 0.25:
		var held: Array = c[1]
		var dt := _now - float(c[2])
		c[2] = _now
		for a: Dictionary in held:
			if float(a.get("left", -1.0)) > 0.0:
				a.left = maxf(0.0, float(a.left) - dt)
		return held
	var out := _read_debuffs(e)
	_deb_cache[id] = [_now, out, _now]
	if _deb_cache.size() > 16:
		for k: int in _deb_cache.keys():
			if k != id and _now - float(_deb_cache[k][0]) > 2.0:
				_deb_cache.erase(k)
	return out


func _read_debuffs(e: Node) -> Array:
	var out: Array = []
	var ids := {}
	var key := str(e.get_instance_id())
	if e.has_method("debuffs"):
		var ext: Variant = e.call("debuffs")
		if ext is Array:
			for d: Variant in ext:
				if d is Dictionary:
					var a := _from_status(d as Dictionary, key)
					ids[a.id] = true
					out.append(a)
	var cs := _combat()
	if cs:
		for d: Variant in cs.statuses_of(e):
			if d is Dictionary:
				var a := _from_status(d as Dictionary, key)
				if not ids.has(a.id) and not (a.id == "mark" and ids.has("umbral_mark")):
					ids[a.id] = true
					out.append(a)
	if e.has_method("debuffs"):
		out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(bool(x.debuff)) > int(bool(y.debuff)))
		return out                                   # the foe reports its own afflictions: done
	var mgr: Afflict = Afflict._inst as Afflict
	if mgr != null and is_instance_valid(mgr):
		var r: Dictionary = mgr._rec.get(e.get_instance_id(), {})
		if not r.is_empty():
			if float(r.get("burn", 0.0)) > 0.0:
				out.append({"name": "Burning", "glyph": "flame", "color": Color(1.0, 0.5, 0.2), "left": float(r.burn), "dur": 4.0, "stacks": 0})
			if float(r.get("frozen", 0.0)) > 0.0:
				out.append({"name": "Frozen", "glyph": "frozen", "color": Color(0.7, 0.9, 1.0), "left": float(r.frozen), "dur": Afflict.FREEZE_TIME, "stacks": 0})
			elif float(r.get("chill", 0.0)) > 0.0:
				out.append({"name": "Rime", "glyph": "rime", "color": Color(0.62, 0.84, 1.0), "left": float(r.chill), "dur": Afflict.CHILL_TIME, "stacks": int(r.get("stacks", 0))})
			if float(r.get("slow", 0.0)) > 0.0:
				out.append({"name": "Dragged", "glyph": "slow", "color": Color(0.7, 0.55, 1.0), "left": float(r.slow), "dur": 3.0, "stacks": 0})
	if "marks" in e and int(e.get("marks")) > 0 and not ids.has("mark"):
		out.append({"name": "Marked", "glyph": "mark", "color": Color(0.85, 0.5, 1.0), "left": -1.0, "stacks": int(e.get("marks"))})
	for a: Dictionary in out:
		if not a.has("debuff"):
			a["debuff"] = true                       # the old sources are all yours, all harmful
	return out


# --- boss ------------------------------------------------------------------------------------------

func _on_boss_engaged(boss: Node, title: String) -> void:
	if not (boss is Node3D):
		return
	_boss = boss as Node3D
	_boss_title = title
	_titles[boss.get_instance_id()] = title
	_b_trail = 1.0
	_boss_arena = null
	for a in get_tree().get_nodes_in_group(&"boss_arena"):
		var arena := a as BossArena
		if arena != null and arena._boss == boss:
			_boss_arena = arena
	if _target == boss:
		_target = null


func _end_boss() -> void:
	_boss = null
	_boss_arena = null


func _tick_boss(delta: float) -> void:
	if _boss != null and (not is_instance_valid(_boss) or not _boss.is_inside_tree() or not _alive(_boss)):
		_end_boss()
	# the frame ends when the wanderer leaves the fight by any means (a fall, a kindle, travel): 60 m away
	if _boss != null and is_instance_valid(_player) and _player.is_inside_tree() \
			and _boss.global_position.distance_to(_player.global_position) > BOSS_LEAVE_M:
		_end_boss()
	if _boss != null:
		var r := _ratio(_boss)
		_b_trail = r if r > _b_trail else move_toward(_b_trail, r, delta * 0.6)
		# the arena's own plain bar steps aside (core/world/boss_arena.gd builds it; r33 hud: reads
		# its `_bar_layer` defensively, no edit there)
		if HudPrefs.unit_frames and is_instance_valid(_boss_arena) and is_instance_valid(_boss_arena._bar_layer):
			_boss_arena._bar_layer.visible = false
	_b_alpha = move_toward(_b_alpha, 1.0 if _boss != null else 0.0, delta * 4.0)


var _enc_hud: EncHud
var _enc_t := 0.0


## Encounters' layer (core/life/encounters/encounter_hud.gd) placed its tide line and Deeper Night
## mark beside the old Gloom bar, and an elite bar under the compass: the frames own those places
## now. r33 hud: its controls are moved / faded from here, defensively (no edit to that file;
## elite_shown() keeps working, the box is only made transparent).
func _tick_encounter_layout() -> void:
	_enc_t -= get_process_delta_time()
	if _enc_t <= 0.0 and not is_instance_valid(_enc_hud):
		_enc_t = 1.0
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			var s: Script = c.get_script()
			if s and String(s.resource_path).ends_with("encounter_hud.gd"):
				_enc_hud = c as EncHud
				break
	if not is_instance_valid(_enc_hud):
		return
	# the tide line and the nightmare line move to our plate only while the frames are on
	if HudPrefs.unit_frames and _enc_hud._status != null:
		_enc_hud._status.position = Vector2(PF_POS.x + 6, _buff_row_y() + ICON + 26.0)
	if HudPrefs.unit_frames and _enc_hud._ng != null:
		_enc_hud._ng.position = Vector2(PF_POS.x + PORTRAIT_R * 2.0 + 16.0, PF_POS.y + PF_H)
	if _enc_hud._elite_box != null:
		var ours := HudPrefs.unit_frames and _target != null and _rank(_target) != "normal"
		_enc_hud._elite_box.modulate.a = 0.0 if ours else 1.0


## The canvas size (the Control's own size is not trusted: it is added before its parent is laid out).
func _vs() -> Vector2:
	return get_viewport_rect().size


func _buff_row_y() -> float:
	return PF_POS.y + PORTRAIT_R * 2.0 + 18.0 + (PF_H - 96.0)


# --- drawing ---------------------------------------------------------------------------------------

func _draw_layer(c: Control, nm: String) -> void:
	if _player == null or _font == null:
		return
	_ci = c
	match nm:
		"player":
			_draw_player()
		"bars":
			_draw_player_bars()
		"auras":
			_draw_player_auras()
		"combat":
			_draw_combat_tag()
		"boss":
			if _b_alpha > 0.0 and _boss != null:
				_draw_unit(_boss, Vector2(_vs().x * 0.5 - BF_W * 0.5, TF_TOP), BF_W, _b_alpha, true)
		"target":
			if _t_alpha > 0.0 and _target != null and is_instance_valid(_target):
				var top := TF_TOP + (118.0 if _boss != null else 0.0)
				_draw_unit(_target, Vector2(_vs().x * 0.5 - TF_W * 0.5, top), TF_W, _t_alpha, false)
		"cast":
			_draw_player_cast()
	_ci = self


## IN COMBAT on the wanderer's plate, pulsing: its own canvas item, so the pulse redraws only these letters.
func _draw_combat_tag() -> void:
	if _fight <= 0.0:
		return
	var plate := Rect2(PF_POS + Vector2(PORTRAIT_R * 1.55, -4.0), Vector2(PF_W, PF_H))
	var x := PF_POS.x + PORTRAIT_R * 2.0 + 12.0
	var w := plate.end.x - x - 12.0
	var fa := 0.8 + 0.2 * sin(_t * 6.0)
	Forge.label(_ci, _font, Vector2(x, plate.position.y + 28.0), "IN COMBAT", 14, Color(EMBER.lightened(0.25), fa), HORIZONTAL_ALIGNMENT_RIGHT, w)
	var ring := GOLD.lerp(EMBER, 0.6 + 0.4 * sin(_t * 5.0))      # the portrait's ring burns in a fight
	_ci.draw_arc(PF_POS + Vector2(PORTRAIT_R, PORTRAIT_R), PORTRAIT_R + 1.0, 0.0, TAU, 64, Color(ring, 0.95), 2.0, true)


func _text(at: Vector2, t: String, pt: int, col: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var f := font if font else _font
	_ci.draw_string_outline(f, at, t, align, w, pt, 4, Color(0.0, 0.0, 0.0, 0.75 * col.a))
	_ci.draw_string(f, at, t, align, w, pt, col)


func _plate(r: Rect2, a: float, rim := RIM) -> void:
	Forge.plate(_ci, r, a, Color.WHITE if rim == RIM else Color.WHITE.lerp(rim.lightened(0.2), 0.5))


func _bar(r: Rect2, ratio: float, col: Color, a: float, trail := -1.0, notches: Array = []) -> void:
	Forge.bar(_ci, r, ratio, col, a, trail, notches, col.darkened(0.55).lerp(Color(0.3, 0.05, 0.05), 0.4))


func _diamond(p: Vector2, d: float, col: Color) -> void:
	_ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)]), col)


func _draw_player() -> void:
	var c := PF_POS + Vector2(PORTRAIT_R, PORTRAIT_R)
	var plate := Rect2(PF_POS + Vector2(PORTRAIT_R * 1.55, -4.0), Vector2(PF_W, PF_H))
	_plate(plate, 1.0)
	_portrait(c)
	var x := PF_POS.x + PORTRAIT_R * 2.0 + 12.0
	var w := plate.end.x - x - 12.0
	var y := plate.position.y + 28.0
	Forge.label(_ci, _font, Vector2(x, y), "THE WANDERER", 20, INK)
	_ci.draw_line(Vector2(x, y + 5.0), Vector2(x + w, y + 5.0), Color(Med.BRONZE, 0.55), 1.0)


## The wanderer's bars (health, Gloom, breath) and the Gloom rising off the portrait: their own layer, as they
## change with every blow and cast and the Gloom bar pulses when it runs high.
func _draw_player_bars() -> void:
	var plate := Rect2(PF_POS + Vector2(PORTRAIT_R * 1.55, -4.0), Vector2(PF_W, PF_H))
	var x := PF_POS.x + PORTRAIT_R * 2.0 + 12.0
	var w := plate.end.x - x - 12.0
	var y := plate.position.y + 39.0
	_portrait_pops_draw(PF_POS + Vector2(PORTRAIT_R, PORTRAIT_R))
	var hp := _health()
	var gr := clampf(float(_p("gloom", 0.0)) / maxf(float(_p("gloom_max", 100.0)), 0.001), 0.0, 1.0)
	# the Gloom bar is not drawn until Gloom first rises above 0 (a new game opens without it)
	HudPrefs.note_gloom(gr)
	var gloom_known := HudPrefs.gloom_known()
	if hp.x >= 0.0:
		var hr := Rect2(Vector2(x, y), Vector2(w, 24))
		_bar(hr, hp.x / hp.y, HEALTH, 1.0, _p_trail)
		Forge.label(_ci, _font, hr.position + Vector2(0, 18), "%s / %s" % [_num(hp.x), _num(hp.y)], 16, INK, HORIZONTAL_ALIGNMENT_CENTER, w)
		y += 32.0
		if gloom_known:
			GloomMeter.draw(_ci, Rect2(Vector2(x - 8.0, y), Vector2(w + 8.0, GloomMeter.ROW_H)), gr, _t)
			y += GloomMeter.ROW_H + 3.0
	elif gloom_known:
		GloomMeter.draw(_ci, Rect2(Vector2(x - 8.0, y), Vector2(w + 8.0, GloomMeter.ROW_H)), gr, _t)
		y += GloomMeter.ROW_H + 3.0
	var bt := _breath()
	if bt.x >= 0.0:
		_bar(Rect2(Vector2(x, y), Vector2(w, 7)), bt.x, Color(0.55, 0.62, 0.95) if bt.y > 0.5 else BREATH, 1.0)


## The wanderer's buff row and the name of a new one: their own layer, as a timer's sweep moves every frame.
func _draw_player_auras() -> void:
	_draw_auras(_buffs, Vector2(PF_POS.x + 4.0, _buff_row_y()), 1.0, 9)
	if _buff_note_t > 0.0 and _buff_note != "":
		var na := clampf(_buff_note_t, 0.0, 1.0)
		var n := mini(_buffs.size(), 9)
		Forge.label(_ci, _body, Vector2(PF_POS.x + 8.0 + n * (ICON + 6.0), _buff_row_y() + 20.0), _buff_note, 16, Color(INK, 0.9 * na))


## The hooded wanderer in a medallion: void face, two lit eyes, the lantern ring (ember in a fight).
func _portrait(c: Vector2) -> void:
	var r := PORTRAIT_R
	_ci.draw_circle(c, r + 4.0, Color(0.03, 0.022, 0.02, 0.95))
	for k in 6:
		var t := float(k) / 5.0
		_ci.draw_circle(c + Vector2(0, -r * 0.25 * t), r * (1.0 - t * 0.55), Color(0.09, 0.06, 0.13).lerp(Color(0.2, 0.12, 0.26), t))
	# hood and shoulders
	var hood := PackedVector2Array()
	for k in 25:
		var a := PI + PI * float(k) / 24.0
		hood.append(c + Vector2(cos(a) * r * 0.46, sin(a) * r * 0.58 - r * 0.02))
	hood.append(c + Vector2(r * 0.5, r * 0.3))
	hood.append(c + Vector2(r * 0.86, r * 0.62))
	hood.append(c + Vector2(r * 0.72, r * 0.95))
	hood.append(c + Vector2(-r * 0.72, r * 0.95))
	hood.append(c + Vector2(-r * 0.86, r * 0.62))
	hood.append(c + Vector2(-r * 0.5, r * 0.3))
	_ci.draw_colored_polygon(hood, Color(0.13, 0.1, 0.16))
	var face := PackedVector2Array()
	for k in 20:
		var a := TAU * float(k) / 20.0
		face.append(c + Vector2(cos(a) * r * 0.3, sin(a) * r * 0.36 + r * 0.04))
	_ci.draw_colored_polygon(face, Color(0.015, 0.01, 0.025))
	var g := clampf(float(_p("gloom", 0.0)) / maxf(float(_p("gloom_max", 100.0)), 0.001), 0.0, 1.0)
	var eye := Color(0.8, 0.66, 1.0).lerp(Color(1.0, 0.45, 0.25), smoothstep(0.55, 1.0, g))
	var blink := 1.0 if fposmod(_t, 5.3) > 0.12 else 0.2
	for sx: float in [-1.0, 1.0]:
		var e := c + Vector2(sx * r * 0.12, r * 0.0)
		_ci.draw_circle(e, 4.0, Color(eye, 0.25 * blink))
		_ci.draw_circle(e, 2.0 * blink + 0.4, Color(eye.lightened(0.3), blink))
	# the lantern hanging at the hip
	var lp := c + Vector2(r * 0.42, r * 0.66)
	_ci.draw_circle(lp, 5.5, Color(LANTERN, 0.25))
	_ci.draw_circle(lp, 2.6, LANTERN.lightened(0.2))
	# ring
	_ci.draw_arc(c, r + 1.0, 0.0, TAU, 64, Color(0.02, 0.015, 0.01), 5.0, true)
	if _fight <= 0.0:                               # in a fight the combat layer draws it, pulsing (_draw_combat_tag)
		_ci.draw_arc(c, r + 1.0, 0.0, TAU, 64, Color(GOLD, 0.95), 2.0, true)
	_ci.draw_arc(c, r + 6.5, 0.0, TAU, 64, Color(0.03, 0.02, 0.015, 0.95), 6.0, true)           # forged iron collar with eight rivets
	_ci.draw_arc(c, r + 6.5, 0.0, TAU, 64, Color(Forge.BEVEL_MID, 0.98), 4.0, true)
	_ci.draw_arc(c, r + 6.5, PI * 1.05, PI * 1.7, 24, Color(Forge.BEVEL_LIT, 0.85), 1.5, true)
	_ci.draw_arc(c, r + 6.5, PI * 0.1, PI * 0.6, 24, Color(Forge.BEVEL_DARK, 0.9), 1.5, true)
	for k in 8:
		var ka := TAU * float(k) / 8.0 + 0.4
		_ci.draw_circle(c + Vector2(cos(ka), sin(ka)) * (r + 6.5), 1.7, Color(Med.BRONZE.lightened(0.3), 0.95))
	# level badge: a bronze-rimmed boss on the ring's lower left, the number large enough to read at a glance
	var lv := _player_level().x
	if lv >= 0:
		var b := c + Vector2(-r * 0.74, r * 0.78)
		_ci.draw_circle(b + Vector2(0.5, 1.5), 17.5, Color(0, 0, 0, 0.5))
		_ci.draw_circle(b, 17.0, Color(0.03, 0.02, 0.014))
		_ci.draw_arc(b, 15.0, 0.0, TAU, 32, Forge.BEVEL_MID, 3.0, true)
		_ci.draw_arc(b, 15.0, PI * 0.95, PI * 1.75, 16, Forge.BEVEL_LIT, 1.5, true)
		_ci.draw_arc(b, 11.0, 0.0, TAU, 32, Color(GOLD, 0.5), 1.0, true)
		Forge.label(_ci, _font, b + Vector2(-17, 7), str(lv), 20, LANTERN.lightened(0.15), HORIZONTAL_ALIGNMENT_CENTER, 34.0, 2)



## Gloom gained / shed, rising off the portrait.
func _portrait_pops_draw(c: Vector2) -> void:
	for pi in _portrait_pops.size():
		var p: Dictionary = _portrait_pops[pi]
		var t := float(p.t)
		var a := clampf((1.3 - t) / 0.5, 0.0, 1.0)
		var pop := 1.0 + 0.5 * clampf(1.0 - t * 6.0, 0.0, 1.0)
		var col: Color = p.col
		var at := Vector2(PF_POS.x + PORTRAIT_R * 1.55 + PF_W + 12.0 + pi * 52.0, c.y + 6.0 - t * 22.0)      # right of the plate: the portrait stays clear
		_text(at, String(p.text), int(22 * pop), Color(col, a), null, HORIZONTAL_ALIGNMENT_LEFT, 80.0)


## A row of aura icons with timers under them and stacks in the corner.
func _draw_auras(list: Array, at: Vector2, a: float, most: int, sz := ICON) -> void:
	var x := at.x
	var gap_done := false
	for i in mini(list.size(), most):
		var b: Dictionary = list[i]
		var deb := bool(b.get("debuff", false))
		if deb and not gap_done and i > 0:
			x += 8.0
		gap_done = gap_done or deb
		var r := Rect2(Vector2(x, at.y), Vector2(sz, sz))
		var col: Color = b.get("color", INK)
		_ci.draw_rect(r.grow(1.0), Color(0.03, 0.025, 0.03, 0.92 * a))
		_aura_glyph(String(b.get("glyph", "")), r.get_center(), sz * 0.34, Color(col, a), String(b.get("name", "?")))
		var left := float(b.get("left", -1.0))
		var dur := float(b.get("dur", 0.0))
		if left > 0.0 and dur > 0.0:
			var gone := clampf(1.0 - left / dur, 0.0, 1.0)
			_ci.draw_rect(Rect2(r.position, Vector2(sz, sz * gone)), Color(0.0, 0.0, 0.0, 0.45 * a))
		_ci.draw_rect(r.grow(-1.0), Color(DEBUFF_RIM if deb else BUFF_RIM, 0.8 * a), false, 1.0)
		Forge.bevel(_ci, r.grow(1.0), a, 2.0, Color(1.0, 0.7, 0.62) if deb else Color.WHITE)
		var stacks := int(b.get("stacks", 0))
		if stacks > 1 or (stacks == 1 and String(b.get("glyph", "")) in ["mark", "rime", "hollow"]):
			Forge.label(_ci, _font, r.position + Vector2(0, sz - 3.0), str(stacks), 14, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_RIGHT, sz - 2.0, 3)
		if left > 0.0:
			var tt := ("%.1f" % left) if left < 3.0 else (str(ceili(left)) if left < 60.0 else "%dm" % ceili(left / 60.0))
			Forge.label(_ci, _font, Vector2(r.position.x - 5.0, r.end.y + 15.0), tt, 14, Color(INK, 0.95 * a), HORIZONTAL_ALIGNMENT_CENTER, sz + 10.0, 3)
		x += sz + 6.0


func _aura_glyph(g: String, c: Vector2, u: float, col: Color, fallback: String) -> void:
	var art := IconArt.art("aura", g)
	if art != null:
		IconArt.draw_square(_ci, art, Rect2(c - Vector2(u, u) * 1.47, Vector2(u, u) * 2.94), Color(1, 1, 1, col.a))
		return
	match g:                                        # (every other aura has its painted icon in ui/icons/aura)
		"shrouded":
			_ci.draw_arc(c, u * 0.85, PI, TAU, 16, col, 2.0)
			_ci.draw_line(c + Vector2(-0.85, 0) * u, c + Vector2(-0.6, 0.9) * u, col, 2.0)
			_ci.draw_line(c + Vector2(0.85, 0) * u, c + Vector2(0.6, 0.9) * u, col, 2.0)
		"enraged":
			for k in 3:
				var x := (float(k) - 1.0) * u * 0.55
				_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x, -u), c + Vector2(x + u * 0.25, u * 0.6), c + Vector2(x - u * 0.25, u * 0.6)]), col)
		_:
			_text(c + Vector2(-u * 1.4, u * 0.5), fallback.substr(0, 1).to_upper(), int(u * 1.7), col, null, HORIZONTAL_ALIGNMENT_CENTER, u * 2.8)


## A target or boss frame at `at`, `w` wide.
func _draw_unit(e: Node3D, at: Vector2, w: float, a: float, is_boss: bool) -> void:
	var rank := "boss" if is_boss else _rank(e)
	var umbral := e.has_meta(&"enc_umbral")
	var ncol: Color = RANK_COL.get("umbral" if umbral and rank != "normal" else rank, RANK_COL.normal)
	var dead := not _alive(e)
	var h := 72.0 if not is_boss else 78.0
	var plate := Rect2(at, Vector2(w, h))
	var trim := GOLD if rank in ["elite", "boss"] else (MOON if rank.begins_with("rare") else RIM)
	_plate(plate, a, trim if rank != "normal" else RIM)
	# the rank emblem on the right, wings round it for anything above a pawn
	var ec := Vector2(plate.position.x - 2.0, plate.position.y + h * 0.5)
	if rank != "normal":
		_wings(ec, trim, a, rank == "boss")
	_ci.draw_circle(ec, 22.0, Color(0.04, 0.03, 0.03, 0.95 * a))
	_ci.draw_arc(ec, 22.0, 0.0, TAU, 40, Color(trim, a), 2.0, true)
	_emblem(ec, rank, ncol, a)
	var x := plate.position.x + 30.0
	var iw := w - 42.0
	var title := _boss_title if is_boss and _boss_title != "" else _name_of(e)
	_text(Vector2(x, plate.position.y + 20.0), title.to_upper() if is_boss else title, 17 if is_boss else 16, Color(ncol, a), null, HORIZONTAL_ALIGNMENT_LEFT, iw - 90.0)
	var sub := _subline(e, rank)
	if is_boss and "phase" in e:
		var ph := int(e.get("phase"))
		var ph_name := ""
		if is_instance_valid(_boss_arena):
			var pts := _boss_arena.phase_titles
			for k: int in pts:
				if ph >= k:
					ph_name = String(pts[k])
		sub = "Phase %s%s" % [["", "I", "II", "III", "IV", "V"][clampi(ph, 0, 5)], ("  ·  " + ph_name) if ph_name != "" else ""]
	Forge.label(_ci, _body, Vector2(x, plate.position.y + 21.0), sub, 14, Color(QUIET, a * 0.95), HORIZONTAL_ALIGNMENT_RIGHT, iw)
	# health
	var r := _ratio(e)
	var hb := Rect2(Vector2(x, plate.position.y + 28.0), Vector2(iw, 20.0 if is_boss else 18.0))
	var marks: Array = []
	if is_boss and e.has_method("phase_marks"):
		var pm: Variant = e.call("phase_marks")
		if pm is Array:
			marks = pm
	var trail := _b_trail if is_boss else (_t_trail if e.get_instance_id() == _t_trail_id else r)
	_bar(hb, r, BLOOD if rank != "boss" else Color(0.82, 0.22, 0.1), a, trail, marks)
	var pct := "DEAD" if dead else "%d%%" % ceili(r * 100.0)
	var hpn := ""
	if "hp" in e and "max_hp" in e and not dead and int(e.get("max_hp")) >= 10:
		hpn = "%s / %d" % [_num(float(e.get("hp"))), int(e.get("max_hp"))]
	Forge.label(_ci, _font, hb.position + Vector2(6, hb.size.y - 4.0), hpn, 14, Color(INK, a), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)
	Forge.label(_ci, _font, hb.position + Vector2(0, hb.size.y - 4.0), pct, 14, Color(INK, a), HORIZONTAL_ALIGNMENT_RIGHT, iw - 6.0, 2)
	# cast bar under the health
	var cast := _cast_of(e) if not dead else {}
	var cy := hb.end.y + 4.0
	if not cast.is_empty():
		var cb := Rect2(Vector2(x, cy), Vector2(iw, 17))
		var intr := bool(cast.get("interruptible", true))
		var cc := Color(1.0, 0.72, 0.3) if intr else Color(0.62, 0.6, 0.66)
		_ci.draw_rect(cb, Color(0.02, 0.015, 0.02, 0.9 * a))
		var t := clampf(float(cast.get("t", 0.0)), 0.0, 1.0)
		_ci.draw_rect(Rect2(cb.position + Vector2(1, 1), Vector2((cb.size.x - 2.0) * t, cb.size.y - 2.0)), Color(cc, 0.9 * a))
		_ci.draw_rect(cb, Color(LANTERN if intr else Color(0.5, 0.5, 0.55), a), false, 1.5 if intr else 1.0)
		if not intr:
			_shield(cb.position + Vector2(-8, 6), a)
		Forge.label(_ci, _body, cb.position + Vector2(0, 14), String(cast.get("name", "")), 14, Color(1, 0.97, 0.9, a), HORIZONTAL_ALIGNMENT_CENTER, iw, 2)
		if intr and t > 0.15:
			Forge.label(_ci, _font, cb.position + Vector2(0, 14), "BREAK", 14, Color(LANTERN, a * (0.6 + 0.4 * sin(_t * 12.0))), HORIZONTAL_ALIGNMENT_RIGHT, iw - 4.0, 2)
	# your afflictions on it, under the frame
	var deb := _debuffs_of(e) if not dead else []
	if not deb.is_empty():
		_draw_auras(deb, Vector2(x, plate.end.y + 4.0), a, 8, 24.0)


func _num(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v         # a pool that is not whole shows its tenth


## The uninterruptible mark: a small grey shield.
func _shield(p: Vector2, a: float) -> void:
	var s := PackedVector2Array([p + Vector2(-5, -6), p + Vector2(5, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)])
	_ci.draw_colored_polygon(s, Color(0.55, 0.55, 0.6, a))
	s.append(s[0])
	_ci.draw_polyline(s, Color(0.1, 0.1, 0.12, a), 1.0)


## Engraved wings round the rank emblem (our own filigree: swept blades with thorn barbs).
func _wings(c: Vector2, col: Color, a: float, crown: bool) -> void:
	for sx: float in [-1.0]:           # one-sided: the frame's plate is on the right
		for k in 3:
			var ln := 34.0 - float(k) * 7.0
			var ang := deg_to_rad(-38.0 + float(k) * 34.0)
			var dir := Vector2(cos(ang) * sx, sin(ang))
			var base := c + dir * 18.0
			var tip := c + dir * (18.0 + ln)
			var side := Vector2(-dir.y, dir.x) * 4.5
			var blade := PackedVector2Array([base + side, tip, base - side])
			_ci.draw_colored_polygon(blade, Color(0.04, 0.03, 0.03, 0.95 * a))
			blade.append(blade[0])
			_ci.draw_polyline(blade, Color(col, 0.95 * a), 1.3, true)
			var mid := base.lerp(tip, 0.55)
			_ci.draw_line(mid, mid + (side.normalized() * 5.0 + dir * 3.0), Color(col, 0.8 * a), 1.0, true)
	if crown:
		var top := c + Vector2(0, -24.0)
		var pts := PackedVector2Array([top + Vector2(-11, 4), top + Vector2(-11, -6), top + Vector2(-5, -1), top + Vector2(0, -10), top + Vector2(5, -1), top + Vector2(11, -6), top + Vector2(11, 4)])
		_ci.draw_colored_polygon(pts, Color(col, a))
		pts.append(pts[0])
		_ci.draw_polyline(pts, Color(0.1, 0.05, 0.02, a), 1.0, true)


func _emblem(c: Vector2, rank: String, col: Color, a: float) -> void:
	match rank:
		"boss":
			_ci.draw_circle(c, 9.0, Color(col, 0.3 * a))
			_ci.draw_circle(c + Vector2(-4, -2), 2.5, Color(col, a))
			_ci.draw_circle(c + Vector2(4, -2), 2.5, Color(col, a))
			_ci.draw_line(c + Vector2(-5, 6), c + Vector2(5, 6), Color(col, a), 2.0)
		"elite", "rare_elite":
			_diamond(c, 10.0, Color(col, 0.85 * a))
			_diamond(c, 4.5, Color(0.04, 0.03, 0.03, a))
		"rare":
			for k in 8:
				var ang := TAU * float(k) / 8.0
				_ci.draw_line(c, c + Vector2(cos(ang), sin(ang)) * (11.0 if k % 2 == 0 else 6.0), Color(col, a), 1.5, true)
		_:
			_ci.draw_circle(c, 6.0, Color(col, 0.75 * a))


## The wanderer's own cast bar, over the hotbar: a charging Lance, a heavy staff draw, or anything
## the player reports through cast_info().
func _draw_player_cast() -> void:
	var cs := _cast_state()
	if cs.is_empty():
		return
	var name_t := String(cs.name)
	var t := float(cs.t)
	var col: Color = cs.col
	var full := bool(cs.full)
	var w := 300.0
	var r := Rect2(Vector2(_vs().x * 0.5 - w * 0.5, _vs().y - 210.0), Vector2(w, 20))
	var c := Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0)).lerp(Color(1, 0.95, 0.85), 0.5 if full else 0.0)
	Forge.plate(_ci, r.grow(5.0), 1.0, Color.WHITE if not full else Color(1.2, 1.1, 0.8), false)
	Forge.bar(_ci, r, clampf(t, 0.0, 1.0), c, 1.0)
	Forge.label(_ci, _font, r.position + Vector2(0, 16), name_t + ("  ·  READY" if full else ""), 14, INK, HORIZONTAL_ALIGNMENT_CENTER, w, 2)


## What the wanderer's own cast bar shows right now: {name, t, col, full}, or {} when there is no cast.
func _cast_state() -> Dictionary:
	var name_t := ""
	var t := -1.0
	var col := LILAC
	var full := false
	if _player.has_method("cast_info"):
		var ci: Variant = _player.call("cast_info")
		if ci is Dictionary and not (ci as Dictionary).is_empty():
			name_t = String(ci.get("name", ""))
			t = float(ci.get("t", 0.0))
			col = ci.get("color", LILAC)
	var book := _player.call("skills") as SkillBook if _player.has_method("skills") else null
	if t < 0.0 and book:
		var d := book.cast_info()
		if not d.is_empty():
			name_t = String(d.get("name", ""))
			var tot := float(d.get("total", 0.0))
			t = float(d.get("t", 0.0)) / tot if tot > 0.0 else float(d.get("t", 0.0))
			col = d.get("color", LILAC)
			full = String(d.get("kind", "")) == "charge" and t >= 1.0
			if String(d.get("kind", "")) == "cast" and tot > 0.0:
				name_t += "   %.1f" % maxf(tot - float(d.get("t", 0.0)), 0.0)
	if t < 0.0:
		if book and book.charging_slot() >= 0:
			var i := book.charging_slot()
			var slots := book.slots
			if i < slots.size() and slots[i] != null:
				name_t = String(slots[i].title)
				col = slots[i].color
			t = book.charge_ratio()
			full = t >= 1.0
	if t < 0.0:
		var arts := _player.call("arts") as StaffArts if _player.has_method("arts") else null
		if arts and arts.heavy_charge() > 0.0:
			name_t = "Heavy Strike"
			t = arts.heavy_charge()
			col = Color(1.0, 0.6, 0.3)
			full = t >= 0.99
	if t < 0.0 and _now - float(_my_stop[1]) < 0.8 and String(_my_stop[0]) != "":
		name_t = "INTERRUPTED" if String(_my_stop[2]) == "interrupted" else "MOVED"
		t = 1.0
		col = Color(0.85, 0.25, 0.2)
	if t < 0.0:
		return {}
	return {"name": name_t, "t": t, "col": col, "full": full}
