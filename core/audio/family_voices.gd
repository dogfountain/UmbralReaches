extends RefCounted
## Per-family character under the creature voices. EnemyAudio (art/audio/enemy, 22 rendered voice sets) stays the voice; for the fifteen ordinary
## families this adds a procedural layer for each of idle, alert, attack, hurt and death, rendered in three takes by the cue bank on its worker thread
## (so seventy-five cues, 225 takes, none on the main thread) and played under the library take through the shared 3D voice pool (capped,
## distance-culled at 34 m, occluded). It is wired at the one choke point every creature voice already passes, EnemyAudio.say, so it inherits that
## function's per-enemy and per-set rate limits, its voice cap and its reach: no new timers, no new scans. The layer is quiet (it thickens a voice, it
## does not double it). Bosses keep their own phase cues (cue_bank.gd boss_*).
##   CueBank.family(voice_set, act, at, db)        called by EnemyAudio.say after it has played (cue_bank.gd)
##   FamilyVoices.recipes()                        the generated cue recipes, merged by the cue bank
## Families and their character (f = the fundamental, tone / noise = how tonal or breathy, metal = a bell in it, click = bone and chitin ticks):
##   hollow    a breathy moan             gaunt   a dry rasp              husk    a low grunt            bulwark   a deeper, heavier grunt
##   gurgle    a wet, bubbling throat     leaper  a high rising screech   chanter a held, chanted vowel  tollman   a tolled iron note
##   quiller   a quill rattle             ossuant bones knocking          crawler a skitter of ticks     burrower  a scraping drag
##   shade     a whispering swell         cinder  a crackle and a sigh    brood   a chittering swarm
## No class_name. Load by path: const FamilyVoices := preload("res://core/audio/family_voices.gd")

const FAMILIES := {
	"hollow": {"f": 150.0, "tone": 0.8, "noise": 0.5, "metal": false, "click": false},
	"gaunt": {"f": 110.0, "tone": 0.4, "noise": 0.9, "metal": false, "click": false},
	"husk": {"f": 72.0, "tone": 0.9, "noise": 0.4, "metal": false, "click": false},
	"bulwark": {"f": 56.0, "tone": 1.0, "noise": 0.5, "metal": false, "click": false},
	"gurgle": {"f": 120.0, "tone": 0.6, "noise": 0.8, "metal": false, "click": false},
	"leaper": {"f": 260.0, "tone": 0.9, "noise": 0.4, "metal": false, "click": false},
	"chanter": {"f": 196.0, "tone": 1.0, "noise": 0.2, "metal": false, "click": false},
	"tollman": {"f": 98.0, "tone": 0.7, "noise": 0.3, "metal": true, "click": false},
	"quiller": {"f": 330.0, "tone": 0.3, "noise": 0.6, "metal": false, "click": true},
	"ossuant": {"f": 180.0, "tone": 0.4, "noise": 0.3, "metal": false, "click": true},
	"crawler": {"f": 420.0, "tone": 0.3, "noise": 0.5, "metal": false, "click": true},
	"burrower": {"f": 90.0, "tone": 0.5, "noise": 0.9, "metal": false, "click": false},
	"shade": {"f": 300.0, "tone": 0.6, "noise": 0.9, "metal": false, "click": false},
	"cinder": {"f": 130.0, "tone": 0.5, "noise": 0.9, "metal": false, "click": false},
	"brood": {"f": 160.0, "tone": 0.3, "noise": 0.7, "metal": false, "click": true},
}
const ACTS := ["idle", "alert", "windup", "attack", "hurt", "stagger", "flee", "die"]
## the layer's own level under the library take, per act
const DB := {"idle": -26.0, "alert": -22.0, "windup": -23.0, "attack": -19.0, "hurt": -21.0, "stagger": -21.0, "flee": -23.0, "die": -19.0}
const LEN := {"idle": 1.0, "alert": 0.7, "windup": 0.9, "attack": 0.6, "hurt": 0.45, "stagger": 0.8, "flee": 1.0, "die": 1.5}

static var _recipes := {}


static func recipes() -> Dictionary:
	if _recipes.is_empty():
		for fam: String in FAMILIES:
			for act: String in ACTS:
				_recipes["fam_%s_%s" % [fam, act]] = {"len": float(LEN[act]), "db": float(DB[act]), "layers": _layers(FAMILIES[fam], act)}
	return _recipes


static func _layers(c: Dictionary, act: String) -> Array:
	var f: float = c.f
	var tone: float = c.tone
	var noise: float = c.noise
	var ly: Array = []
	match act:
		"idle":
			ly.append(["sine", 0.0, 0.85, f, f * 0.92, 0.35 * tone, 0.15, 0.4])
			ly.append(["noise", 0.0, 0.9, 0.25 * noise, f * 1.5, f * 6.0, 0.2, 0.5, 5.0])
			if c.click:
				for i in 3:
					ly.append(["thud", 0.2 + 0.25 * float(i), f * 3.0, f * 2.0, 0.04, 0.3])
			if c.metal:
				ly.append(["bell", 0.1, f * 4.0, 0.12, 0.6])
		"alert":
			ly.append(["sine", 0.0, 0.55, f * 0.9, f * 1.45, 0.45 * tone, 0.06, 0.3])
			ly.append(["noise", 0.0, 0.5, 0.35 * noise, f * 2.0, f * 9.0, 0.05, 0.25, 0.0])
			if c.click:
				ly.append(["thud", 0.05, f * 4.0, f * 2.5, 0.03, 0.4])
				ly.append(["thud", 0.14, f * 4.0, f * 2.5, 0.03, 0.35])
			if c.metal:
				ly.append(["bell", 0.0, f * 5.0, 0.18, 0.5])
		"windup":
			ly.append(["sine", 0.0, 0.8, f * 0.7, f * 1.3, 0.4 * tone, 0.3, 0.5])
			ly.append(["noise", 0.0, 0.8, 0.3 * noise, f, f * 6.0, 0.4, 0.4, 7.0])
			if c.click:
				for i in 4:
					ly.append(["thud", 0.1 + 0.16 * float(i), f * 3.0, f * 2.0, 0.03, 0.3 + 0.08 * float(i)])
			if c.metal:
				ly.append(["bell", 0.3, f * 3.0, 0.2, 0.8])
		"stagger":
			ly.append(["sine", 0.0, 0.6, f * 1.2, f * 0.5, 0.5 * tone, 0.01, 0.3])
			ly.append(["noise", 0.0, 0.5, 0.4 * noise, f, f * 5.0, 0.004, 0.2, 0.0])
			ly.append(["thud", 0.05, f * 1.4, f * 0.6, 0.2, 0.4])
		"flee":
			ly.append(["sine", 0.0, 0.9, f * 1.6, f * 2.2, 0.35 * tone, 0.05, 0.4])
			ly.append(["noise", 0.0, 0.9, 0.3 * noise, f * 2.0, f * 9.0, 0.05, 0.5, 11.0])
			if c.click:
				for i in 6:
					ly.append(["thud", 0.05 + 0.13 * float(i), f * 3.5, f * 2.0, 0.03, 0.3])
		"attack":
			ly.append(["noise", 0.0, 0.4, 0.4 * noise + 0.15, f, f * 8.0, 0.003, 0.12, 0.0])
			ly.append(["sine", 0.0, 0.4, f * 1.3, f * 0.7, 0.45 * tone, 0.01, 0.15])
			if f < 130.0:
				ly.append(["thud", 0.0, f * 1.6, f * 0.6, 0.25, 0.5])
			if c.click:
				ly.append(["thud", 0.0, f * 3.0, f * 1.5, 0.05, 0.5])
			if c.metal:
				ly.append(["bell", 0.0, f * 3.0, 0.3, 0.7])
		"hurt":
			ly.append(["sine", 0.0, 0.3, f * 1.5, f * 0.8, 0.5 * tone, 0.004, 0.1])
			ly.append(["noise", 0.0, 0.25, 0.3 * noise, f * 2.0, f * 7.0, 0.002, 0.08, 0.0])
			if c.click:
				ly.append(["thud", 0.02, f * 3.5, f * 1.8, 0.03, 0.4])
		"die":
			ly.append(["sine", 0.0, 1.3, f, f * 0.35, 0.5 * tone, 0.03, 0.6])
			ly.append(["noise", 0.0, 1.2, 0.3 * noise, f, f * 5.0, 0.02, 0.55, 3.0])
			if c.click:
				for i in 5:
					ly.append(["thud", 0.1 + 0.18 * float(i), f * 3.0, f * 1.6, 0.04, 0.35 - 0.05 * float(i)])
			if c.metal:
				ly.append(["bell", 0.0, f * 2.0, 0.35, 1.2])
			if f < 130.0:
				ly.append(["thud", 0.35, f * 1.2, f * 0.4, 0.4, 0.5])
	return ly
