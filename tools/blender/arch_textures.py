"""Run tools/gen_arch_textures.py under Blender's numpy (this machine has no system numpy/PIL).
    tools/blender/run.sh arch_textures.py -- brick plaster ashlar ruin floor wood beam
Installs a minimal PIL.Image shim that writes 8-bit PNGs through bpy."""
import os
import runpy
import sys
import types

import bpy
import numpy as np


class _Img:
	def __init__(self, a):
		self.a = a

	def save(self, path):
		a = self.a
		h, w = a.shape[:2]
		rgb = np.repeat(a[..., None], 3, 2) if a.ndim == 2 else a
		rgba = np.ones((h, w, 4), np.float32)
		rgba[..., :3] = rgb.astype(np.float32) / 255.0
		rgba = rgba[::-1]                                   # Blender rows run bottom-up
		img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False, float_buffer=False)
		img.colorspace_settings.name = "Non-Color"
		img.pixels.foreach_set(rgba.ravel())
		img.filepath_raw = path
		img.file_format = "PNG"
		img.save()
		bpy.data.images.remove(img)


pil = types.ModuleType("PIL")
im = types.ModuleType("PIL.Image")
im.fromarray = lambda a: _Img(a)
pil.Image = im
sys.modules["PIL"] = pil
sys.modules["PIL.Image"] = im

here = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
sys.argv = ["gen_arch_textures.py"] + argv
runpy.run_path(os.path.join(os.path.dirname(here), "gen_arch_textures.py"), run_name="__main__")
