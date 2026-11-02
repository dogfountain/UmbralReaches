"""List art files with no res:// path or filename reference in text resources.
Usage: python3 tools/orphans.py
"""
import os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ART = os.path.join(ROOT, "art")
TEXT_EXT = {".gd", ".tscn", ".tres", ".import", ".cfg", ".md", ".shader", ".gdshader"}
SKIP_DIR = {".godot", "addons", "build", "docs/archive"}


def walk_text():
    blob = []
    for dirpath, dirnames, files in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in {".git", ".godot", "addons"}]
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext not in TEXT_EXT:
                continue
            path = os.path.join(dirpath, f)
            try:
                with open(path, "r", errors="ignore") as fh:
                    blob.append(fh.read())
            except OSError:
                pass
    return "\n".join(blob)


def main():
    text = walk_text()
    unused = []
    total = 0
    bytes_unused = 0
    for dirpath, _, files in os.walk(ART):
        if "/_unused" in dirpath.replace("\\", "/"):
            continue
        for f in files:
            if f.endswith(".import") or f.startswith("."):
                continue
            total += 1
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            res = "res://" + rel
            name = os.path.splitext(f)[0]
            if res in text or f in text or name in text:
                continue
            unused.append(rel)
            bytes_unused += os.path.getsize(full)
    for rel in unused:
        print(rel)
    print("ORPHANS %d / %d files, %.1f MB" % (len(unused), total, bytes_unused / 1e6), file=sys.stderr)


if __name__ == "__main__":
    main()
