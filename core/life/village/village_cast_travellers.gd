extends RefCounted
## People on the road between the places (docs/far_reaches.md, life): walkers on the Pilgrims' Road, each on a
## walking network of their own (an island of the village's, merged by village.gd like Weirford's). They walk a
## stretch of the road, stop at its waystones and turns, and walk back; they camp where they stand ("outpost":
## nobody runs three hundred metres to the Keg). Voices stay babble. Data only, no class_name.
##   Ansel Tansy      a pilgrim walking the road between the orchard lane and the chapel, who keeps
##                   turning round to look at the mountain
##   Marra Quill     a salt carter on the east road between Saltmarket and the road to Lastlight

## xz of every walk node (world metres), on the road's line or its verge.
const NODES := {
	"tr_w0": Vector2(-112.0, 65.6), "tr_w1": Vector2(-100.0, 64.2), "tr_w2": Vector2(-88.0, 62.6),
	"tr_w3": Vector2(-76.0, 61.1), "tr_w4": Vector2(-63.0, 59.8),
	"tr_e0": Vector2(214.0, 77.4), "tr_e1": Vector2(232.0, 75.6), "tr_e2": Vector2(250.0, 73.4),
	"tr_e3": Vector2(270.0, 72.6), "tr_e4": Vector2(288.0, 72.4),
}

const EDGES := [["tr_w0", "tr_w1"], ["tr_w1", "tr_w2"], ["tr_w2", "tr_w3"], ["tr_w3", "tr_w4"],
	["tr_e0", "tr_e1"], ["tr_e1", "tr_e2"], ["tr_e2", "tr_e3"], ["tr_e3", "tr_e4"]]

const CAST := {
	"tansy": {"name": "Tansy", "title": "Ansel Tansy, walking home", "when": "", "camp": "outpost",
		"rig": {"seed": 7401, "sex": "m", "age": "old", "garment": "robe", "hood": true, "r": "staff", "hair": "short", "beard": "short", "girth": 0.96,
			"cloth": Color(0.42, 0.38, 0.32), "cloth2": Color(0.32, 0.29, 0.25), "hair_c": Color(0.72, 0.7, 0.66),
			"skin": Color(0.76, 0.56, 0.44), "leather": Color(0.36, 0.24, 0.13)},
		"home": "tr_w0", "speed": 0.72, "fearless": true,
		"schedule": {"dusk": "walk", "work": "walk", "midnight": "rest", "late": "walk"},
		"routines": {
			"walk": [
				{"act": "look_up", "at": "tr_w0", "face": Vector2(0.0, -104.0), "t": [5.0, 8.0]},
				{"act": "idle", "at": "tr_w2", "face": Vector2(-72.0, 52.0), "t": [4.0, 7.0]},
				{"act": "kneel", "at": "tr_w4", "face": Vector2(-72.0, 52.0), "t": [10.0, 16.0]},
				{"act": "look_up", "at": "tr_w3", "face": Vector2(0.0, -104.0), "t": [6.0, 9.0]},
				{"act": "idle", "at": "tr_w1", "face": Vector2(-160.0, 67.0), "t": [5.0, 8.0]},
			],
			"rest": [{"act": "sit", "at": "tr_w2", "face": Vector2(-96.0, 70.0), "t": [30.0, 45.0]},
				{"act": "look_up", "at": "tr_w2", "face": Vector2(0.0, -104.0), "t": [8.0, 12.0]}],
		}},
	"marra": {"name": "Marra", "title": "Marra Quill, salt carter", "when": "", "camp": "outpost",
		"rig": {"seed": 7502, "sex": "f", "age": "adult", "garment": "dress", "apron": "leather", "hat": "kerchief", "hair": "bun", "girth": 1.08,
			"cloth": Color(0.4, 0.36, 0.3), "cloth2": Color(0.5, 0.46, 0.4), "hair_c": Color(0.24, 0.15, 0.09),
			"skin": Color(0.8, 0.6, 0.46), "leather": Color(0.42, 0.28, 0.14)},
		"home": "tr_e0", "speed": 0.9, "fearless": true,
		"schedule": {"dusk": "haul", "work": "haul", "midnight": "haul", "late": "rest"},
		"routines": {
			"haul": [
				{"act": "tend", "at": "tr_e0", "face": Vector2(212.0, 92.0), "t": [8.0, 12.0]},
				{"act": "idle", "at": "tr_e2", "face": Vector2(266.0, 72.0), "t": [4.0, 6.0]},
				{"act": "look_up", "at": "tr_e4", "face": Vector2(322.0, 44.0), "t": [6.0, 9.0]},
				{"act": "idle", "at": "tr_e3", "face": Vector2(250.0, 73.0), "t": [4.0, 6.0]},
				{"act": "idle", "at": "tr_e1", "face": Vector2(212.0, 92.0), "t": [5.0, 8.0]},
			],
			"rest": [{"act": "sit", "at": "tr_e1", "face": Vector2(232.0, 82.0), "t": [30.0, 45.0]}],
		}},
}

const CONV := {
	"tansy": {"name": "Ansel Tansy", "start": [["!met:tansy", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Don't mind me. I stop. I walk ten steps and I stop and I look round at it. Forty years walking toward that mountain, and now I'm walking away I can't stop looking.", "next": "meet2"},
		"meet2": {"say": "Ansel. Ansel Tansy, of nowhere now. I got as far as the Stair's foot the winter of the Night. Everybody in front of me went up. I had a stone in my boot. That's the whole of my story.", "do": "met:tansy", "next": "hub"},
		"hub": {"say_if": [
			["boss:ascended_warden", "He's down, they say. The one at the top. I thought I'd feel lighter. I feel like a man who missed his cart and then heard it went into the river."],
			["", "The chapel's on the left, past the wall. I kneel there going and coming. The Kindlers never asked me what I believed. That's the nicest thing a church ever did for me."],
		], "choices": [
			{"text": "Where are you going?", "to": "where", "once": true},
			{"text": "What's on the road west?", "to": "west", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"where": {"say": "Home, I tell people. There's a village west of the Sorrow, beyond the Kings' ridge, and the reed folk there owe my sister a boat. If the boat's still there, that's home. If it isn't, I keep walking.", "next": "hub"},
		"west": {"say": "Past the Wall the road goes on to the end of the world and stops at a milestone in a wood that glows. Nothing burns in there. Nothing needs to. I slept a night under the caps and dreamt of nothing at all. Best sleep in forty years.", "next": "hub"},
	}},
	"marra": {"name": "Marra Quill", "start": [["!met:marra", "meet"], ["", "hub"]], "nodes": {
		"meet": {"say": "Mind the wheel. It's not the cart that'll have your foot, it's the salt in the rut. Gets in a cut and you'll know about it for a week.", "next": "meet2"},
		"meet2": {"say": "Marra. I carry salt from the pans to Lastlight and bread back, and I count the hollowed on the way. Fewer this month. That's either good news or a lot of them all together somewhere.", "do": "met:marra", "next": "hub"},
		"hub": {"say_if": [
			["", "Lastlight shuts its east gate at dusk and doesn't open it. Hasn't since the Night. Go in by the road gate, and say who you are before the lamp-keeper asks."],
		], "choices": [
			{"text": "What's at Lastlight?", "to": "lastlight", "once": true},
			{"text": "What's south of the road?", "to": "south", "once": true},
			{"text": "Goodbye.", "to": ""},
		]},
		"lastlight": {"say": "The last lamp before the mountain. Pilgrims turned there for the Stair. Now it's an inn, a watch and a lamp tower they keep lit, and a gate east that nobody opens. They say what's past it isn't the road any more.", "next": "hub"},
		"south": {"say": "A cathedral standing in a mere, all its roof gone, the moon coming through it like it's looking for something. And past that the cairns. One for every pilgrim who turned back. I've put a stone on it myself. Don't tell my mother.", "next": "hub"},
	}},
}
