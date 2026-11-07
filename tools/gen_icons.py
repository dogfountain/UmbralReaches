"""Regenerates every painted icon into res://ui/icons/<category>/<id>.png (256x256, opaque, full bleed).

ICON KIT
  tools/icon_kit/paint.py     the painter: value-noise fbm, domain warp (hand-painted edges), SDF shapes
                              (circle, ellipse, box, stadium, segment, polyline), bevel() pseudo-3D rim lighting,
                              glow/sparks/stars, backdrop() painted ground, finish() = bloom + canvas texture +
                              tone map + vignette + grain, save_png().
  tools/icon_kit/registry.py  @recipe(category, id) registers a function that returns an (N, N, 3) float image.
  tools/icon_kit/<set>.py     the recipes. One small function per icon; add a file and import it below.
  ui/icons/icon_art.gd        IconArt.get_art(category, id) -> Texture2D (null when missing, callers fall back
                              to the old drawn glyph).

USAGE (numpy comes from Blender's bundled Python; no downloads, no PIL):
  blender -b --python tools/gen_icons.py                       # all icons
  blender -b --python tools/gen_icons.py -- spell/bolt aura    # only these ids / categories
  blender -b --python tools/gen_icons.py -- --sheet out.png    # also write a contact sheet of what was made
Then re-import in Godot (open the editor once, or copy the .import files from a normal import).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "icon_kit"))

import numpy as np  # noqa: E402

import paint  # noqa: E402
from registry import RECIPES  # noqa: E402
import spells  # noqa: E402,F401
import spells2  # noqa: E402,F401
import kindling  # noqa: E402,F401
import auras  # noqa: E402,F401
import gear  # noqa: E402,F401
import items_relics  # noqa: E402,F401
import items_charms  # noqa: E402,F401
import items_misc  # noqa: E402,F401
import hearth  # noqa: E402,F401
import village  # noqa: E402,F401

OUT = os.path.join(HERE, "..", "ui", "icons")


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        args = args[:i] + args[i + 2:]
    made = []
    for (cat, ident), fn in sorted(RECIPES.items()):
        key = "%s/%s" % (cat, ident)
        if args and not any(key == a or cat == a or ident == a for a in args):
            continue
        img = fn()
        d = os.path.join(OUT, cat)
        os.makedirs(d, exist_ok=True)
        paint.save_png(os.path.join(d, ident + ".png"), img)
        made.append((key, img))
        print("icon", key)
    if sheet and made:
        cols = min(len(made), 6)
        rows = (len(made) + cols - 1) // cols
        big = np.zeros((rows * paint.N, cols * paint.N, 3))
        for i, (_, img) in enumerate(made):
            r, c = divmod(i, cols)
            big[r * paint.N:(r + 1) * paint.N, c * paint.N:(c + 1) * paint.N] = img
        paint.save_png(sheet, big)


main()
