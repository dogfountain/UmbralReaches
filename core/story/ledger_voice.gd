extends RefCounted
## The keep reads the Long Ledger aloud (the ledger-keeper the opening seat asked for): a line when it is posted, a line for each kind of bounty when one is paid,
## one when a rank is gained (the rank's own line, then his), and one about the Deeper Night's scaling. The keep says it as a subtitle in his own voice (spoken.gd);
## the sounds are the cue bank's (`ledger_post`, `ledger_pay`, `ledger_rank`, three takes each). Hooked from long_ledger.gd's post / _pay. No class_name.
##   LedgerVoice.posted(host, n, ng)   LedgerVoice.paid(host, counter, hard)   LedgerVoice.rank(host, r, line, ng)

const CueBank := preload("res://core/audio/cue_bank.gd")
const Spoken := preload("res://core/story/spoken.gd")

## by the bounty's counter ("kind:husk" is keyed "kind"): what the keep says when it is paid
const PAID := {
	"kills": ["That is a good many fewer of them in the dark. The ledger is obliged.", "Counted, and struck. The night is a little shorter."],
	"kind": ["Of that kind, and no more of them for it. I have crossed the line out.", "Done, and done properly. Of that sort the valley has fewer."],
	"great": ["One of the great ones, and the ledger remembers. It will want the name in the book.", "The ledger does not write that line often. Let it be written."],
	"clean": ["Not once down. I will tell nobody, because they will not believe me.", "A clean score, as asked. The Keg will pour for it."],
	"camps": ["You made camp, and the night turned. There is a seat for you by the fire and it is warm.", "A camp, taken properly. The ledger approves of sitting down."],
	"places": ["New ground, and inked. The map has more of you in it than it did.", "Found, and drawn. There is always room on the map."],
	"runs": ["The parcel is delivered. Hearthward gets its post by someone's boots.", "Carried, and signed for. It is a small thing and the whole of a village."],
	"races": ["You ran. Fennick takes it as a compliment, and so, in his way, do I.", "Entered, and finished. That is more than half of any race."],
	"wins": ["Won, and Fennick has chalked it on the post. The Cup waits.", "First home. The ledger does not pay for pride, but it makes an exception."],
}
const POSTED := ["The ledger is posted. %d bounties, and the pen is dry for a good reason.", "New work on the board: %d lines. Read them and choose a night's worth."]
const DEEPER := "The cracked bell has been rung, and the numbers are up. So is the purse. That is how it works."
const RANK := "The ledger writes your name a little larger."


## The keep's words are only said when the wanderer is within earshot of the Keg; the cue plays anywhere (it is the page turning in the wanderer's head).
static func _near_keg(host: Node) -> bool:
	var pl := host.get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return pl != null and RealmLayout.TAVERN.grow(45.0).has_point(Vector2(pl.global_position.x, pl.global_position.z))


static func posted(host: Node, n: int, ng: int) -> void:
	CueBank.play(host, "ledger_post", 0.0)
	if not _near_keg(host):
		return
	Spoken.say(host.get_tree(), "keep", "The keep", String(POSTED[randi() % POSTED.size()]) % n)
	if ng > 0:
		host.get_tree().create_timer(5.0, false).timeout.connect(func() -> void:
			if is_instance_valid(host) and host.is_inside_tree():
				Spoken.say(host.get_tree(), "keep", "The keep", DEEPER))


static func paid(host: Node, counter: String, hard: bool) -> void:
	CueBank.play(host, "ledger_pay", 0.0, 1.0 if not hard else 0.9)
	if not _near_keg(host):
		return
	var key := counter.split(":")[0]
	var pool: Array = PAID.get(key, PAID.kills)
	Spoken.say(host.get_tree(), "keep", "The keep", String(pool[randi() % pool.size()]))


static func rank(host: Node, r: int, rank_line: String, ng: int) -> void:
	CueBank.play(host, "ledger_rank", 0.0, 0.9 + 0.02 * float(r))
	host.get_tree().create_timer(2.5, false).timeout.connect(func() -> void:
		if is_instance_valid(host) and host.is_inside_tree() and _near_keg(host):
			Spoken.say(host.get_tree(), "keep", "The keep", rank_line if ng == 0 else rank_line + " " + RANK))
