#!/usr/bin/env python3
"""Umbral Reaches code graph: what links to what, the way this project links things.

Generic code-graph tools see calls and imports. This game's scripts mostly link through:
  - preload/load("res://...") by path (most scripts have no class_name), and the const that holds it
  - class_name globals (OssKit, Player, Enemy, BossArena ...)
  - extends (a path or a class)
  - the Events autoload's signals (Events.x.emit / Events.x.connect)
  - groups (add_to_group / get_nodes_in_group / get_first_node_in_group / is_in_group, by string or Groups.CONST)
  - autoloads (project.godot)
  - scenes (.tscn ext_resource scripts and instanced scenes)
  - paths held as plain "res://..." strings (module tables, loaders) - path_ref
This indexes all of it into .code_graph/graph.json (rebuilt automatically when any .gd/.tscn/project.godot is newer)
and answers questions from the command line.

  tools/code_graph.py who <file|Class|Alias|func>  everything that links to it (preloads, extends, class uses, scenes, calls)
  tools/code_graph.py deps <file>                  what a file links to
  tools/code_graph.py impact <file> [depth]        files that could break if it changes (reverse links, transitive)
  tools/code_graph.py signal <name>                who declares, emits and connects a signal (Events or local)
  tools/code_graph.py group <name|Groups.CONST>    who adds to, looks up and tests a group
  tools/code_graph.py find <symbol>                where a func/const/var/signal/class_name is defined
  tools/code_graph.py file <file>                  a file's summary: class, extends, defines, links in and out
  tools/code_graph.py stats                        counts
  tools/code_graph.py build                        force a rebuild
A <file> may be a res:// path, a repo path, or a unique basename (villager.gd).
"""
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, ".code_graph")
OUT = os.path.join(OUT_DIR, "graph.json")
SKIP_DIRS = {".godot", ".claude", ".git", ".code_graph", "node_modules", "addons_disabled"}

RE_CLASS = re.compile(r"^class_name\s+(\w+)", re.M)
RE_EXTENDS = re.compile(r'^extends\s+(?:"([^"]+)"|(\w+))', re.M)
RE_RES = re.compile(r'(?:preload|load|ResourceLoader\.load)\(\s*"(res://[^"]+)"')
RE_PATH = re.compile(r'"(res://[^"]+\.(?:gd|tscn|gdshader|tres|glb))"')
RE_CONST_RES = re.compile(r'^(?:static\s+)?(?:const|var)\s+(\w+)\s*(?::=|:\s*\w+\s*=|=)\s*(?:preload|load)\(\s*"(res://[^"]+)"', re.M)
RE_FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\(", re.M)
RE_CONST = re.compile(r"^(?:static\s+)?const\s+(\w+)", re.M)
RE_VAR = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?var\s+(\w+)", re.M)
RE_SIGNAL = re.compile(r"^signal\s+(\w+)", re.M)
RE_EMIT = re.compile(r"\b(?:(\w+)\.)?(\w+)\.emit\(")
RE_EMIT_OLD = re.compile(r'emit_signal\(\s*&?"(\w+)"')
RE_CONNECT = re.compile(r"\b(?:(\w+)\.)?(\w+)\.connect\(")
RE_GROUP_ARG = r'\(\s*(?:&?"([\w/]+)"|Groups\.(\w+))'
RE_ADD_GROUP = re.compile(r"add_to_group" + RE_GROUP_ARG)
RE_GET_GROUP = re.compile(r"(?:get_nodes_in_group|get_first_node_in_group|call_group|call_group_flags\([^,]+,|get_node_count_in_group)" + RE_GROUP_ARG)
RE_IS_GROUP = re.compile(r"is_in_group" + RE_GROUP_ARG)
RE_GROUPS_CONST = re.compile(r'^const\s+(\w+)\s*:?=\s*&?"([\w/]+)"', re.M)
RE_CALL = re.compile(r"\b([A-Z]\w*)\.(\w+)\s*\(")
RE_TSCN_SCRIPT = re.compile(r'\[ext_resource[^\]]*path="(res://[^"]+)"')
RE_COMMENT = re.compile(r"(?m)#.*$")


def rel(path):
    return os.path.relpath(path, ROOT)


def res_to_rel(res):
    return res[len("res://"):] if res.startswith("res://") else res


def walk():
    for d, dirs, files in os.walk(ROOT):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS and not x.startswith(".")]
        for f in files:
            if f.endswith((".gd", ".tscn")):
                yield os.path.join(d, f)


def strip_strings_keep(text):
    """Comments out (they mention names in prose); strings kept (paths and group names live in them)."""
    out = []
    for line in text.splitlines():
        i, q = 0, None
        cut = len(line)
        while i < len(line):
            c = line[i]
            if q:
                if c == "\\":
                    i += 2
                    continue
                if c == q:
                    q = None
            elif c in "\"'":
                q = c
            elif c == "#":
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return "\n".join(out)


def stale():
    if not os.path.exists(OUT):
        return True
    t = os.path.getmtime(OUT)
    if os.path.getmtime(os.path.join(ROOT, "project.godot")) > t or os.path.getmtime(__file__) > t:
        return True
    for p in walk():
        if os.path.getmtime(p) > t:
            return True
    return False


def build():
    files = {}
    classes = {}            # class_name -> file
    autoloads = {}          # name -> file
    groups_const = {}       # Groups.CONST -> group name
    sources = {}
    proj = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    for m in re.finditer(r'^(\w+)="\*?(res://[^"]+)"', proj.split("[autoload]", 1)[1].split("\n[", 1)[0] if "[autoload]" in proj else "", re.M):
        autoloads[m.group(1)] = res_to_rel(m.group(2))
    for p in walk():
        r = rel(p)
        try:
            text = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        sources[r] = text
        if r.endswith(".gd"):
            code = strip_strings_keep(text)
            m = RE_CLASS.search(code)
            if m:
                classes[m.group(1)] = r
            if r.endswith("core/util/groups.gd"):
                for g in RE_GROUPS_CONST.finditer(code):
                    groups_const[g.group(1)] = g.group(2)
    for name, f in autoloads.items():
        classes.setdefault(name, f)

    def grp(m):
        return m.group(1) if m.group(1) else groups_const.get(m.group(2), "Groups." + m.group(2))

    edges = []              # [from, to, kind, detail]
    signals = defaultdict(lambda: {"declared": [], "emit": [], "connect": []})
    groups = defaultdict(lambda: {"add": [], "lookup": [], "test": []})
    defs = defaultdict(list)  # symbol -> [file:line kind]
    for r, text in sources.items():
        if r.endswith(".tscn"):
            files[r] = {"kind": "scene"}
            for m in RE_TSCN_SCRIPT.finditer(text):
                target = res_to_rel(m.group(1))
                kind = "scene_script" if target.endswith(".gd") else ("scene_instance" if target.endswith(".tscn") else "scene_res")
                if kind != "scene_res":
                    edges.append([r, target, kind, ""])
            continue
        code = strip_strings_keep(text)
        info = {"kind": "script", "lines": text.count("\n") + 1}
        m = RE_CLASS.search(code)
        if m:
            info["class"] = m.group(1)
        m = RE_EXTENDS.search(code)
        if m:
            base = res_to_rel(m.group(1)) if m.group(1) else m.group(2)
            info["extends"] = base
            target = base if m.group(1) else classes.get(base)
            if target:
                edges.append([r, target, "extends", base])
        aliases = {}
        for m in RE_CONST_RES.finditer(code):
            aliases[m.group(1)] = res_to_rel(m.group(2))
        seen_res = set()
        for m in RE_RES.finditer(code):
            t = res_to_rel(m.group(1))
            if t not in seen_res:
                seen_res.add(t)
                alias = next((a for a, v in aliases.items() if v == t), "")
                edges.append([r, t, "preload", alias])
        line_of = lambda pos: code.count("\n", 0, pos) + 1
        for m in RE_PATH.finditer(code):
            t = res_to_rel(m.group(1))
            if t not in seen_res and t != r:
                seen_res.add(t)
                edges.append([r, t, "path_ref", "line %d" % line_of(m.start())])
        for m in RE_FUNC.finditer(code):
            defs[m.group(2)].append("%s:%d func" % (r, line_of(m.start())))
        for m in RE_CONST.finditer(code):
            defs[m.group(1)].append("%s:%d const" % (r, line_of(m.start())))
        for m in RE_VAR.finditer(code):
            defs[m.group(1)].append("%s:%d var" % (r, line_of(m.start())))
        for m in RE_SIGNAL.finditer(code):
            owner = "Events" if r == autoloads.get("Events") else r
            signals["%s.%s" % ("Events", m.group(1)) if owner == "Events" else m.group(1)]["declared"].append("%s:%d" % (r, line_of(m.start())))
            defs[m.group(1)].append("%s:%d signal" % (r, line_of(m.start())))
        if "class" in info:
            defs[info["class"]].append("%s:1 class_name" % r)
        for m in RE_EMIT.finditer(code):
            key = "Events.%s" % m.group(2) if m.group(1) == "Events" else m.group(2)
            signals[key]["emit"].append("%s:%d" % (r, line_of(m.start())))
        for m in RE_EMIT_OLD.finditer(code):
            signals[m.group(1)]["emit"].append("%s:%d" % (r, line_of(m.start())))
        for m in RE_CONNECT.finditer(code):
            if m.group(2) in ("timeout", "pressed", "finished", "body_entered", "body_exited", "area_entered", "area_exited", "tree_exiting", "tree_exited", "ready", "toggled", "value_changed", "text_changed", "item_selected", "animation_finished", "gui_input", "mouse_entered", "mouse_exited", "visibility_changed", "resized", "child_entered_tree", "child_exiting_tree", "text_submitted", "focus_entered", "focus_exited", "id_pressed", "screen_entered", "screen_exited") and m.group(1) != "Events":
                key = "(engine) " + m.group(2)
            else:
                key = "Events.%s" % m.group(2) if m.group(1) == "Events" else m.group(2)
            signals[key]["connect"].append("%s:%d" % (r, line_of(m.start())))
        for m in RE_ADD_GROUP.finditer(code):
            groups[grp(m)]["add"].append("%s:%d" % (r, line_of(m.start())))
        for m in RE_GET_GROUP.finditer(code):
            groups[grp(m)]["lookup"].append("%s:%d" % (r, line_of(m.start())))
        for m in RE_IS_GROUP.finditer(code):
            groups[grp(m)]["test"].append("%s:%d" % (r, line_of(m.start())))
        # class and alias uses: Class.func(...) / Alias.func(...), and bare class mentions (types, is, as, new())
        used = set()
        for m in RE_CALL.finditer(code):
            name, fn = m.group(1), m.group(2)
            target = aliases.get(name) or classes.get(name)
            if target and target != r:
                edges.append([r, target, "call", "%s.%s:%d" % (name, fn, line_of(m.start()))])
                used.add(name)
        for name, target in classes.items():
            if target == r or name in used:
                continue
            if re.search(r"\b%s\b" % re.escape(name), code):
                edges.append([r, target, "uses_class", name])
        files[r] = info
    # de-duplicate edges (keep the first detail per kind)
    seen = set()
    uniq = []
    for e in edges:
        k = (e[0], e[1], e[2], e[3] if e[2] == "call" else "")
        if k not in seen:
            seen.add(k)
            uniq.append(e)
    g = {"files": files, "classes": classes, "autoloads": autoloads, "groups_const": groups_const, "edges": uniq,
         "signals": signals, "groups": groups, "defs": defs}
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(g, f)
    return g


def load():
    if stale():
        return build()
    with open(OUT, encoding="utf-8") as f:
        return json.load(f)


def resolve(g, q):
    q = q.strip()
    if q.startswith("res://"):
        q = res_to_rel(q)
    if q in g["files"]:
        return q
    if q in g["classes"]:
        return g["classes"][q]
    hits = [f for f in g["files"] if os.path.basename(f) == q or f.endswith("/" + q)]
    if len(hits) == 1:
        return hits[0]
    if len(hits) > 1:
        print("ambiguous: " + ", ".join(sorted(hits)))
        sys.exit(2)
    return None


def group_name(g, q):
    if q.startswith("Groups."):
        return g["groups_const"].get(q[7:], q)
    return g["groups_const"].get(q, q)


def by_kind(rows):
    out = defaultdict(list)
    for r in rows:
        out[r[0]].append(r[1])
    return out


def cmd_who(g, q):
    f = resolve(g, q)
    if f is None:
        # a function name: who calls X.q( or defines it
        calls = [e for e in g["edges"] if e[2] == "call" and e[3].split(":")[0].endswith("." + q)]
        print("defined: " + ("; ".join(g["defs"].get(q, [])) or "nowhere"))
        for e in sorted(calls):
            print("  call   %s  (%s)" % (e[0], e[3]))
        return
    rows = by_kind([(e[2], "%s%s" % (e[0], ("  (" + e[3] + ")") if e[3] else "")) for e in g["edges"] if e[1] == f])
    print("%s  <- %d links" % (f, sum(len(v) for v in rows.values())))
    for k in ("extends", "preload", "path_ref", "scene_script", "scene_instance", "uses_class", "call"):
        for x in sorted(rows.get(k, [])):
            print("  %-14s %s" % (k, x))


def cmd_deps(g, q):
    f = resolve(g, q)
    if f is None:
        print("no such file: " + q)
        sys.exit(1)
    rows = by_kind([(e[2], "%s%s" % (e[1], ("  (" + e[3] + ")") if e[3] else "")) for e in g["edges"] if e[0] == f])
    print("%s  -> %d links" % (f, sum(len(v) for v in rows.values())))
    for k in ("extends", "preload", "path_ref", "scene_script", "scene_instance", "uses_class", "call"):
        for x in sorted(rows.get(k, [])):
            print("  %-14s %s" % (k, x))
    for name, s in g["signals"].items():
        for kind in ("emit", "connect", "declared"):
            for loc in s[kind]:
                if loc.startswith(f + ":"):
                    print("  %-14s %s  (%s)" % ("signal " + kind, name, loc.split(":")[-1]))
    for name, s in g["groups"].items():
        for kind in ("add", "lookup", "test"):
            for loc in s[kind]:
                if loc.startswith(f + ":"):
                    print("  %-14s %s  (%s)" % ("group " + kind, name, loc.split(":")[-1]))


def cmd_impact(g, q, depth=3):
    f = resolve(g, q)
    if f is None:
        print("no such file: " + q)
        sys.exit(1)
    rev = defaultdict(set)
    for e in g["edges"]:
        rev[e[1]].add(e[0])
    # signal and group listeners of what f emits/adds are affected too
    for name, s in g["signals"].items():
        if any(l.startswith(f + ":") for l in s["emit"] + s["declared"]):
            for l in s["connect"]:
                rev[f].add(l.split(":")[0])
    seen = {f: 0}
    frontier = [f]
    for d in range(1, depth + 1):
        nxt = []
        for x in frontier:
            for y in rev.get(x, ()):
                if y not in seen:
                    seen[y] = d
                    nxt.append(y)
        frontier = nxt
    tests = sorted(x for x in seen if x.startswith("zz/") and x.endswith("_test.gd") or x.endswith("_test.tscn"))
    print("%s: %d files within %d steps" % (f, len(seen) - 1, depth))
    for d in range(1, depth + 1):
        layer = sorted(x for x, v in seen.items() if v == d and not x.startswith("zz/"))
        if layer:
            print("  step %d (%d): %s" % (d, len(layer), ", ".join(layer)))
    if tests:
        print("  tests that reach it (%d): %s" % (len(tests), ", ".join(os.path.basename(t).split(".")[0] for t in tests)))


def cmd_signal(g, q):
    keys = [k for k in g["signals"] if k == q or k == "Events." + q or k.endswith("." + q) or k == "(engine) " + q]
    if not keys:
        print("no signal " + q)
        return
    for k in keys:
        s = g["signals"][k]
        print(k)
        for kind in ("declared", "emit", "connect"):
            for loc in sorted(s[kind]):
                print("  %-8s %s" % (kind, loc))


def cmd_group(g, q):
    name = group_name(g, q)
    s = g["groups"].get(name)
    if not s:
        print("no group " + name)
        return
    print("group \"%s\"" % name)
    for kind in ("add", "lookup", "test"):
        for loc in sorted(s[kind]):
            print("  %-7s %s" % (kind, loc))


def cmd_find(g, q):
    for d in g["defs"].get(q, []):
        print(d)
    if q in g["classes"]:
        print("class_name/autoload -> " + g["classes"][q])


def cmd_file(g, q):
    f = resolve(g, q)
    if f is None:
        print("no such file: " + q)
        sys.exit(1)
    info = g["files"][f]
    print("%s  %s" % (f, json.dumps(info)))
    outs = sum(1 for e in g["edges"] if e[0] == f)
    ins = sum(1 for e in g["edges"] if e[1] == f)
    print("  links out %d, in %d (deps / who for the lists)" % (outs, ins))


def cmd_stats(g):
    kinds = defaultdict(int)
    for e in g["edges"]:
        kinds[e[2]] += 1
    print("files %d (scripts %d), classes %d, autoloads %d, edges %d %s, signals %d, groups %d, symbols %d" % (
        len(g["files"]), sum(1 for v in g["files"].values() if v["kind"] == "script"), len(g["classes"]), len(g["autoloads"]),
        len(g["edges"]), dict(kinds), len(g["signals"]), len(g["groups"]), len(g["defs"])))


def main():
    a = sys.argv[1:]
    if not a or a[0] in ("-h", "--help", "help"):
        print(__doc__)
        return
    if a[0] == "build":
        cmd_stats(build())
        return
    g = load()
    c = a[0]
    q = a[1] if len(a) > 1 else ""
    if c == "who":
        cmd_who(g, q)
    elif c == "deps":
        cmd_deps(g, q)
    elif c == "impact":
        cmd_impact(g, q, int(a[2]) if len(a) > 2 else 3)
    elif c == "signal":
        cmd_signal(g, q)
    elif c == "group":
        cmd_group(g, q)
    elif c == "find":
        cmd_find(g, q)
    elif c == "file":
        cmd_file(g, q)
    elif c == "stats":
        cmd_stats(g)
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
