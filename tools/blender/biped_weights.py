"""Skin-weight functions for the remodelled bipeds (see biped_body.py). Each is fn(blender point) -> {bone: weight}."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import grunt_kit as GK
import grunt_body as GB
from boss_kit import G


def seg_weights(ctx):
    """The envelope weights the grunts use: the torso skin never follows the arm bones."""
    ARMB = ("shoulder_", "elbow_", "hand_")
    body_fn = GB.envelope_weights([sg for sg in ctx.segs if not sg[0].startswith(ARMB)])
    arm_fn = GB.envelope_weights([sg for sg in ctx.segs if sg[0].startswith(ARMB) or sg[0] == "chest"])
    all_fn = GB.envelope_weights(ctx.segs)
    stiff_fn = GB.envelope_weights(ctx.segs, band=0.012, power=3.0)        # armour: follows one bone almost wholly
    return body_fn, arm_fn, all_fn, stiff_fn


def base_weights(ctx, S, neck=0.1):
    """Weight functions for every socket tag the bipeds use: bodyskin / armskin (envelope), head, arm_l/r, leg_l/r
    (chains across the joints), r:<bone> (rigid on one bone)."""
    P0, C0 = S["pelvis"], S["chest"]
    WAIST = G(0, 1.02, 0)
    NECK = G(0, 1.63, -0.02 - neck)
    body_fn, arm_fn, all_fn, stiff_fn = seg_weights(ctx)
    ARMB = ("shoulder_", "elbow_", "hand_")
    body_stiff = GB.envelope_weights([sg for sg in ctx.segs if not sg[0].startswith(ARMB)], band=0.012, power=3.0)   # torso plates never follow the arm bones
    W = {"bodyskin": body_fn, "armskin": arm_fn, "all": all_fn, "stiff": stiff_fn, "bodystiff": body_stiff, "armstiff": stiff_fn,
         "head": lambda p: GK.chain_w(p, [("chest", C0), ("head", NECK + G(0, -0.01, 0))], 0.025),
         "torso": lambda p: GK.chain_w(p, [("pelvis", P0), ("chest", WAIST), ("head", NECK)], [0.075, 0.035])}
    for tag in ("l", "r"):
        W["arm_" + tag] = (lambda t: lambda p: GK.chain_w(p, [("chest", C0), ("shoulder_" + t, S["shoulder_" + t] + G(0, 0.035, 0)),
                                                              ("elbow_" + t, S["elbow_" + t]), ("hand_" + t, S["hand_" + t])], [0.03, 0.04, 0.028]))(tag)
        W["leg_" + tag] = (lambda t: lambda p: GK.chain_w(p, [("pelvis", P0), ("hip_" + t, S["hip_" + t] + G(0, 0.03, 0)),
                                                              ("knee_" + t, S["knee_" + t]), ("foot_" + t, S["foot_" + t])], [0.04, 0.045, 0.03]))(tag)
    for bn in S:
        W["r:" + bn] = (lambda b: lambda p: {b: 1.0})(bn)
    W["staff"] = W["r:hand_r"]
    return W


def skirt_weights(W, y_hip=0.86, y_knee=0.42, spread=0.8, knee_part=0.5, torso_from=0.95):
    """A robe / skirt from the neck to the ground: above the hips it follows the torso chain, below it the legs
    (each side by x), the hem half-way down following the knees; the front and back centre lines follow both."""
    sm = GK._smooth

    def fn(p):
        y = p.z
        wt = W["torso"](p)
        if y > torso_from:
            return wt
        a = sm(y_hip, y_knee * 0.4, y) * spread
        sl = sm(0.09, -0.09, p.x)
        sr = sm(-0.09, 0.09, p.x)
        kn = sm(y_knee + 0.1, y_knee - 0.2, y) * knee_part
        w = {"pelvis": 1.0 - a}
        for tag, s in (("l", sl), ("r", sr)):
            w["hip_" + tag] = a * s * (1.0 - kn)
            if kn > 0.0:
                w["knee_" + tag] = a * s * kn
        t = sm(torso_from, y_hip, y)
        out = {}
        for k, v in w.items():
            out[k] = out.get(k, 0.0) + v * t
        for k, v in wt.items():
            out[k] = out.get(k, 0.0) + v * (1.0 - t)
        tot = sum(out.values()) or 1.0
        return {k: v / tot for k, v in out.items() if v / tot > 0.002}
    return fn
