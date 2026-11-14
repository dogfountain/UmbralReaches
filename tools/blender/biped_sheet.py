"""Join images side by side into one sheet (no PIL here): blender -b -P biped_sheet.py -- out.png in1.png in2.png ... [--h 1200]"""
import bpy
import sys
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
H = 1200
if "--h" in args:
    i = args.index("--h")
    H = int(args[i + 1])
    del args[i:i + 2]
out, ins = args[0], args[1:]
tiles = []
for p in ins:
    im = bpy.data.images.load(p)
    w, h = im.size
    if h != H:
        im.scale(int(w * H / h), H)
    a = np.empty(im.size[0] * im.size[1] * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    tiles.append(a.reshape(im.size[1], im.size[0], 4))
sheet = np.concatenate(tiles, axis=1)
o = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=False)
o.pixels.foreach_set(sheet.ravel())
o.filepath_raw = out
o.file_format = 'PNG'
o.save()
print("SHEET", out, sheet.shape)
