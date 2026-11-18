extends RefCounted
## The Hearthward races' sound and words (the hooks horse_race.gd calls): Fennick's herald, a start bell and beat ticks, a gate pass, the finish by place,
## a new best, the Cup; a murmur on the green while the ritual stands and a cheer or a groan at the end. Every cue is a cue-bank cue (three takes each),
## the lines are subtitles in Fennick's voice (spoken.gd). Called from horse_race.gd on its existing beats; nothing runs between them. No class_name.
##   begin(host)  beat(host, n)  go(host)  gate(host)  false_start(host)  finish(host, place, record, cup)

const CueBank := preload("res://core/audio/cue_bank.gd")
const Spoken := preload("res://core/story/spoken.gd")

const BEATS := ["Ready.", "Hold.", "Hold it.", "Now."]
const FIRST := ["Home first, and the whole green on its feet.", "First across. I have waited nine winters to say it.", "A clean win. Pour that wanderer something."]
const SECOND := ["Second, and by a nose. It is a very good second.", "Second. A length is a length, and you will have it next time."]
const THIRD := ["Third, and still on your feet. The green is kind to a good ride.", "Third home. The horse has more to say about it than you do."]
const LAST := ["Fourth, and the lantern is burning down. A fine run, and nobody is laughing.", "Home at last. The finish is the finish."]
const BEST := ["A new best, and I have written it on the post.", "That is your fastest, and the post has a new line for it."]
const CUP := "All four courses, and one horse. The Hearthward Cup is yours, and I have had it polished for a year."
const FALSE := ["Back to the line, if you please. The lantern has not dropped.", "Not yet. A man who goes before the word has only gone before the word."]


static func _fennick(host: Node, line: String) -> void:
	Spoken.say(host.get_tree(), "fennick", "Fennick", line)


## The ritual begins: the bell, and the green's murmur at the rail.
static func begin(host: Node) -> void:
	CueBank.play(host, "race_bell", 0.0)
	CueBank.play(host, "crowd_murmur", 0.0)


static func beat(host: Node, n: int) -> void:
	CueBank.play(host, "race_tick", 0.0, 1.0 + 0.06 * float(n))
	_fennick(host, String(BEATS[clampi(n, 0, BEATS.size() - 1)]))


static func go(host: Node) -> void:
	CueBank.play(host, "race_go", 0.0)
	CueBank.play(host, "crowd_cheer", -6.0)
	_fennick(host, String(BEATS[3]))


static func gate(host: Node) -> void:
	CueBank.play(host, "race_gate", 0.0, 0.94 + randf() * 0.14)


static func false_start(host: Node) -> void:
	CueBank.play(host, "race_false", 0.0)
	CueBank.play(host, "crowd_groan", 0.0)
	_fennick(host, String(FALSE[randi() % FALSE.size()]))


## The finish: by place a cheer, a murmur or a groan; Fennick's word; a new best; the Cup.
static func finish(host: Node, place: int, record: bool, cup: bool) -> void:
	CueBank.play(host, "race_first" if place == 0 else "race_finish", 0.0)
	CueBank.play(host, "crowd_cheer" if place < 2 else ("crowd_murmur" if place == 2 else "crowd_groan"), 0.0)
	var pool: Array = FIRST if place == 0 else (SECOND if place == 1 else (THIRD if place == 2 else LAST))
	_fennick(host, String(pool[randi() % pool.size()]))
	if record:
		host.get_tree().create_timer(3.0, false).timeout.connect(func() -> void:
			if is_instance_valid(host) and host.is_inside_tree():
				CueBank.play(host, "race_place", 0.0)
				_fennick(host, String(BEST[randi() % BEST.size()])))
	if cup:
		host.get_tree().create_timer(5.0, false).timeout.connect(func() -> void:
			if is_instance_valid(host) and host.is_inside_tree():
				CueBank.play(host, "race_cup", 0.0)
				_fennick(host, CUP))
