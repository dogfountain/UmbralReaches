"""Gear icon recipes: ("gear", id). ids: <slot>_<tier> for the plain bases (tier = rarity 0..4), set_<set>_<slot>,
legend_<id>, and the NAMED piece ids of core/items/gear_db.gd. Painters in gear_parts.py; each spec says which
object, in what material and palette; the backdrop tint follows the piece's rarity (a set piece: its set tint)."""
from registry import recipe
from paint import finish
import gear_parts as G

ORB = {
    "violet": ("#3a1aa8", "#a98bff", "#6a42f0"),
    "ember": ("#6a1204", "#ff9a3a", "#ff5a14"),
    "teal": ("#06504a", "#7ff0dc", "#2ac0b0"),
    "bone": ("#5a4c34", "#f2e6c4", "#c8b078"),
    "void": ("#020208", "#3a3a6a", "#4a4aa0"),
    "amber": ("#6a3a06", "#ffcf6a", "#e09020"),
    "green": ("#143a14", "#9ae07a", "#4aa040"),
    "rose": ("#5a0a2a", "#ff8ab0", "#e04a7a"),
    "glass": ("#16304a", "#a8d8ff", "#5aa0e0"),
    "ash": ("#101216", "#8890a0", "#4a5060"),
}
CLOTH = {
    "wool": ("#3a3026", "#a08c6c"), "grey": ("#2e2e34", "#8e8e9a"), "cream": ("#7a6a4a", "#efe2c0"),
    "violet": ("#2a1448", "#8a5ed0"), "black": ("#120e12", "#4a4048"), "soot": ("#1c1612", "#5a4a40"),
    "fen": ("#14301c", "#5a9a5a"), "teal": ("#0e3a3a", "#5ac0b0"), "salt": ("#4a4e52", "#d0d6da"),
    "rust": ("#4a1a0a", "#c0642a"), "red": ("#4a0e14", "#c04050"), "sack": ("#4a3a20", "#c8a870"),
    "bone": ("#5a5240", "#ece2c8"), "rift": ("#10102a", "#5a5ac0"), "moss": ("#2a3a14", "#8aa850"),
    "umber": ("#2e1c10", "#9a6a40"), "white": ("#8a8478", "#faf4e4"),
}

SPECS = {}   # id -> (slot, rarity, tint, params)


def spec(ident, slot, rar, **kw):
    tint = kw.pop("tint", None)
    SPECS[ident] = (slot, rar, tint, kw)


def cl(name, **kw):
    kw["cloth"] = CLOTH[name]
    return kw


def fo(orb, **kw):
    kw["orb"] = ORB[orb]
    return kw


# --- plain bases, by tier ---------------------------------------------------------------------
spec("focus_0", "focus", 0, **fo("ash", holder="cup", mat="wood", shaft="wood", band="iron", halo=0.2))
spec("focus_1", "focus", 1, **fo("amber", holder="cradle", mat="bronze", shaft="wood"))
spec("focus_2", "focus", 2, **fo("glass", holder="collar", mat="bronze", shaft="darkiron"))
spec("focus_3", "focus", 3, **fo("bone", holder="collar", mat="bone", shaft="bone", rx=0.44))
spec("focus_4", "focus", 4, **fo("void", holder="cage", mat="darkiron", shaft="darkiron", stars=True, halo=0.7))
spec("vestment_0", "vestment", 0, **cl("wool", form="stole", trim="#8a7a58", seed=2))
spec("vestment_1", "vestment", 1, **cl("sack", form="scapular", trim="#c89a4a", patches="#6a8a5a", seed=3))
spec("vestment_2", "vestment", 2, **cl("cream", form="stole", trim="#d8b25a", emblem="cross", emblem_col="#b8862a", seed=4))
spec("vestment_3", "vestment", 3, **cl("violet", form="cloak", trim="#d8b25a", emblem="star", emblem_col="#e0c070", seed=5))
spec("vestment_4", "vestment", 4, **cl("rift", form="stole", trim="#2a2a6a", glowhem="#ff6e9a", seed=6))
spec("lantern_0", "lantern", 0, form="horn", metal="iron", fire="warm", glass="#9a7a50", smoke=True, seed=2)
spec("lantern_1", "lantern", 1, form="cylinder", metal="iron", fire="warm", glass="#ffb454", leaded=True, seed=3)
spec("lantern_2", "lantern", 2, form="gothic", metal="silver", fire="pale", glass="#a8c8ff", seed=4)
spec("lantern_3", "lantern", 3, form="bulb", metal="bronze", fire="violet", glass="#a080ff", seed=5)
spec("lantern_4", "lantern", 4, form="bulb", metal="gilt", fire="pale", glass="#ffb0c8", seed=6)
spec("girdle_0", "girdle", 0, form="sash", base="#3a2c16", light="#b89a68", knots=2, seed=2)
spec("girdle_1", "girdle", 1, form="belt", buckle="iron", leather="leather", studs=False, seed=3)
spec("girdle_2", "girdle", 2, form="sash", base="#4a3a28", light="#e0d0b0", knots=5, kr=0.06, seed=4)
spec("girdle_3", "girdle", 3, form="belt", buckle="bronze", leather="darkleather", studs=True, wide=0.17, seed=5)
spec("girdle_4", "girdle", 4, form="cord", base="#1a1014", light="#7a5a6a", knots=9, kr=0.055, glowknots="#ff6e9a", knotc=("#1a0a10", "#6a3a4a"), seed=6)

# --- sets (backdrop in the set tint) ----------------------------------------------------------
spec("set_kindler_focus", "focus", 3, tint="#FF8A4A", **fo("ember", holder="cup", mat="darkiron", shaft="darkiron", band="rust", coals=True, halo=0.9))
spec("set_kindler_vestment", "vestment", 3, tint="#FF8A4A", **cl("soot", form="stole", trim="#e0782a", embers=True, emblem="flame", emblem_col="#ff9a3a", seed=11))
spec("set_kindler_lantern", "lantern", 3, tint="#FF8A4A", form="cylinder", metal="darkiron", fire="ember", glass="#ff8a3a", leaded=True, seed=12)
spec("set_kindler_girdle", "girdle", 3, tint="#FF8A4A", form="cord", base="#2a1a10", light="#a06a3a", knots=4, glowknots="#ff7a2a", knotc=("#2a1a10", "#8a4a22"), seed=13)
spec("set_ferryman_focus", "focus", 3, tint="#5FE3D0", **fo("teal", holder="ring", mat="iron", shaft="wood", hook=True))
spec("set_ferryman_vestment", "vestment", 3, tint="#5FE3D0", **cl("fen", form="cloak", trim="#3a7a6a", moss=True, clasp="bronze", seed=15))
spec("set_ferryman_lantern", "lantern", 3, tint="#5FE3D0", form="bulb", metal="bronze", fire="teal", glass="#50d8c0", chain=True, seed=16)
spec("set_ferryman_girdle", "girdle", 3, tint="#5FE3D0", form="cord", base="#2a3a2a", light="#8aa070", knots=2, thick=0.075, coil=True, strands=30, seed=17)
spec("set_tally_focus", "focus", 3, tint="#E8DCC0", **fo("bone", holder="beads", mat="bone", shaft="bone"))
spec("set_tally_vestment", "vestment", 3, tint="#E8DCC0", **cl("bone", form="scapular", trim="#b8a880", emblem="tally", emblem_col="#2a2218", emblem_s=0.16, seed=19))
spec("set_tally_lantern", "lantern", 3, tint="#E8DCC0", form="horn", metal="bone", fire="bone", glass="#e8d8a8", seed=20)
spec("set_tally_girdle", "girdle", 3, tint="#E8DCC0", form="sash", base="#4a4232", light="#e8dcc0", knots=7, kr=0.055, seed=21)
spec("set_bell_focus", "focus", 3, tint="#D79A52", **fo("amber", holder="ring", mat="bronze", shaft="wood"))
spec("set_bell_vestment", "vestment", 3, tint="#D79A52", **cl("umber", form="apron", trim="#b88a42", seed=23))
spec("set_bell_lantern", "lantern", 3, tint="#D79A52", form="cylinder", metal="bronze", fire="warm", glass="#ffb454", leaded=False, seed=24)
spec("set_bell_girdle", "girdle", 3, tint="#D79A52", form="sash", base="#4a3418", light="#d0a868", knots=3, bell=True, seed=25)

# --- legends ----------------------------------------------------------------------------------
spec("legend_door_splinter", "focus", 4, **fo("amber", holder="splinter", mat="pale", shaft="wood", halo=0.8))
spec("legend_sunk_shroud", "vestment", 4, **cl("white", form="scapular", trim="#6a7a5a", wrap=True, roots=True, moss=True, seed=31))
spec("legend_unlit_lamp", "lantern", 4, form="bulb", metal="darkiron", fire="none", glass="#40365a", seed=32)
spec("legend_stair_rope", "girdle", 4, form="cord", base="#2a2218", light="#a09070", knots=3, thick=0.07, coil=True, strands=28, seed=33)

# --- named pieces -----------------------------------------------------------------------------
spec("heartwood_cup", "focus", 3, **fo("amber", holder="cup", mat="wood", shaft="wood", band="gilt", moss=True, halo=0.6, seed=41))
spec("henge_mantle", "vestment", 3, **cl("moss", form="cloak", trim="#5a7a3a", moss=True, clasp="stone", seed=42))
spec("briarwick_glass", "lantern", 3, form="cylinder", metal="wood", fire="warm", glass="#ffb454", briar=True, seed=43)
spec("counting_cord", "girdle", 3, form="sash", base="#4a4232", light="#e8dcc0", knots=11, kr=0.048, amp=0.14, seed=44)
spec("charnel_glass", "lantern", 3, form="bulb", metal="bone", fire="bone", glass="#e0d0a0", smoke=True, seed=45)
spec("bone_collar", "focus", 3, **fo("bone", holder="beads", mat="bone", shaft="bone", rx=0.46, seed=46))
spec("edict_stole", "vestment", 3, **cl("cream", form="stole", trim="#c8a040", emblem="dots", emblem_col="#8a6a30", seed=47))
spec("latch_cord", "girdle", 3, form="sash", base="#2a2a30", light="#8a8a98", knots=2, amp=0.3, seed=48)
spec("sky_cage", "focus", 3, **fo("void", holder="cage", mat="silver", shaft="darkiron", stars=True, seed=49))
spec("digger_glass", "lantern", 2, form="cylinder", metal="iron", fire="warm", glass="#a88a5a", smoke=True, seed=50)
spec("bone_cincture", "girdle", 2, form="beads", bead="bone", links=17, seed=51)
spec("mirewick_stole", "vestment", 2, **cl("fen", form="stole", trim="#7a8a3a", embers=True, seed=52))
spec("corpse_cradle", "focus", 2, **fo("teal", holder="cradle", mat="iron", shaft="wood", halo=0.9, seed=53))
spec("tollmans_ring", "focus", 3, **fo("ash", holder="cup", mat="iron", shaft="darkiron", band="gilt", seed=54))
spec("widow_veil", "vestment", 3, **cl("black", form="veil", trim="#5a4a58", band=True, seed=55))
spec("anchor_chain", "girdle", 3, form="chain", metal="iron", links=16, hang=True, seed=56)
spec("cell_lantern", "lantern", 3, form="coin", metal="darkiron", fire="warm", glass="#ffb454", leaded=True, seed=57)
spec("hermit_shawl", "vestment", 3, **cl("salt", form="cloak", trim="#8a9aa0", salt=True, clasp="iron", seed=58))
spec("horn_collar", "focus", 3, **fo("bone", holder="horn", mat="bone", shaft="wood", seed=59))
spec("cantor_hush", "vestment", 3, **cl("white", form="stole", trim="#8a8a98", emblem="bell", emblem_col="#6a6a80", seed=60))
spec("held_note", "lantern", 3, form="gothic", metal="gilt", fire="violet", glass="#a898ff", seed=61)
spec("reeve_tally", "focus", 2, **fo("ash", holder="cup", mat="wood", shaft="wood", band="iron", seed=62))
spec("mason_girdle", "girdle", 2, form="plumb", base="#2a3a1a", light="#8aa050", seed=63)
spec("breaker_cinch", "girdle", 2, form="harness", buckle="iron", leather="darkleather", wide=0.19, studs=True, stud="iron", seed=64)
spec("widow_salt", "lantern", 3, form="bulb", metal="silver", fire="pale", glass="#cfe0e8", brine=True, seed=65)
spec("lamplighter_wick", "lantern", 3, form="horn", metal="gilt", fire="pale", glass="#ffe8a8", chain=True, seed=66)
spec("shepherd_crook", "focus", 2, **fo("glass", holder="crook", mat="wood", shaft="wood", seed=67))
spec("ringer_gloves", "girdle", 2, form="wraps", base="#4a3a24", light="#d8c090", seed=68)
spec("slag_cowl", "vestment", 2, **cl("rust", form="scapular", trim="#2a1a12", glowhem="#ff7a2a", embers=True, seed=69))
spec("fog_lantern", "lantern", 2, form="horn", metal="iron", fire="pale", glass="#b8c8d0", smoke=True, seed=70)
spec("cinder_scapular", "vestment", 2, **cl("sack", form="scapular", trim="#6a5a4a", pockets=True, seed=71))
spec("pilgrim_orb", "focus", 3, **fo("ash", holder="cup", mat="wood", shaft="wood", band="bronze", halo=0.1, seed=72))
spec("kin_bell_ring", "focus", 3, **fo("amber", holder="rope", mat="bronze", shaft="wood", seed=73))
spec("hewer_apron", "vestment", 3, **cl("salt", form="apron", trim="#8a8a80", salt=True, seed=74))
spec("shepherd_strap", "girdle", 3, form="belt", buckle="bronze", leather="leather", emptyring=True, wide=0.14, seed=75)
spec("slag_glass", "lantern", 3, form="bulb", metal="darkiron", fire="red", glass="#ff7a3a", crack=True, seed=76)
spec("sower_cloak", "vestment", 3, **cl("moss", form="cloak", trim="#4a4a2a", pockets=True, clasp="wood", seed=77))
spec("ringer_clapper", "focus", 3, **fo("ash", holder="clapper", mat="iron", shaft="darkiron", seed=78))
spec("shutter_hasp", "girdle", 3, form="hasp", buckle="iron", leather="darkleather", studs=True, stud="iron", wide=0.17, seed=79)
spec("fare_lamp", "lantern", 3, form="coin", metal="bronze", fire="warm", glass="#ffcf70", seed=80)

PAINT = {"focus": G.focus, "vestment": G.vestment, "lantern": G.lantern, "girdle": G.girdle}


def make(ident):
    slot, rar, tint, p = SPECS[ident]
    img = G.ground(rar, p.get("seed", 1) + 100, tint)
    img = PAINT[slot](img, dict(p))
    img = finish(img, p.get("seed", 1), vignette=0.5, bloom=0.35, grade=(1.02, 0.99, 0.98), exposure=1.45)
    return G.rimline(img, rar, tint).clip(0, 1)


def _reg(ident):
    recipe("gear", ident)(lambda: make(ident))


for _id in SPECS:
    _reg(_id)
