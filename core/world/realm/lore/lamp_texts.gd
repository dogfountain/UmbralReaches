extends RefCounted
## The lights others keep (core/world/realm/lamps/lamps_kept.gd): what is left beside a pilgrim's fire and
## under a window lit in a ruin. Entry shape: lore_db.gd; the shared table takes these in its `# --- lamps ---` block.

const TEXTS := {
	"lamp_pilgrim": {"region": "downs", "kind": "page", "title": "A page, folded small",
		"text": "Weirford, two nights south. I have walked it four times now and it is always two nights south. If you find me asleep, leave the fire. I banked it myself, I think. I have never been able to remember doing so."},
	"lamp_window": {"region": "orchard", "kind": "notice", "title": "Pinned to a stake under the window",
		"text": "PRESSING DONE. Loft swept, lamp trimmed, door left unbarred for whoever comes. NO ONE IS TO COME UP. The press-house burned the winter the orchard did. The lamp has been lit every night since, and I have not seen who lights it."},
}
