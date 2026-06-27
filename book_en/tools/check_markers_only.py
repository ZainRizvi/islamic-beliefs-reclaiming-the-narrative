#!/usr/bin/env python3
"""Verify (and optionally revert) that index tagging inserted ONLY markers.

For each tagged .adoc, strip the index markers (@@CX(...)@@ and (((...)))) and
compare to a pristine snapshot. If the stripped text differs from the snapshot,
the tagging changed prose — a violation. With --revert, restore that file from
the snapshot so no prose damage is ever kept.

    python3 tools/check_markers_only.py SNAPSHOT_DIR [--revert]

Exit 0 if all files are marker-only; 1 if any drift found (after optional revert,
exit reflects whether anything had to be reverted).
"""
import re, sys, os, glob, shutil, difflib

def strip_markers(t):
    t = re.sub(r'@@CX\(.+?\)@@', '', t)          # concept markers
    t = re.sub(r'\(\(\(.+?\)\)\)', '', t, flags=re.S)  # (((term))) general index
    return t

def main():
    if len(sys.argv) < 2:
        print("usage: check_markers_only.py SNAPSHOT_DIR [--revert]", file=sys.stderr)
        return 2
    snap = sys.argv[1]
    revert = '--revert' in sys.argv[2:]
    src = os.path.join(os.path.dirname(__file__), '..', 'src')
    files = sorted(glob.glob(os.path.join(src, 'sessions', '*.adoc'))) + \
            sorted(glob.glob(os.path.join(src, 'front', '*.adoc')))
    drift = []
    for after in files:
        rel = os.path.relpath(after, src)
        before = os.path.join(snap, rel)
        if not os.path.exists(before):
            continue
        b = open(before, encoding='utf-8').read()
        a = open(after, encoding='utf-8').read()
        if strip_markers(a) == b:
            continue
        drift.append(rel)
        # show a short diff sample
        bl, al = b.split('\n'), strip_markers(a).split('\n')
        sample = [l for l in difflib.unified_diff(bl, al, lineterm='', n=0)
                  if l[:1] in '+-' and not l.startswith(('+++', '---'))][:6]
        print(f"DRIFT {rel}:")
        for l in sample:
            print(f"    {l}")
        if revert:
            shutil.copy(before, after)
            print(f"    -> reverted to snapshot")
    if not drift:
        print(f"OK: all {len(files)} files are marker-only.")
        return 0
    print(f"\n{len(drift)} file(s) had prose drift" + (" (reverted)." if revert else "."))
    return 1

if __name__ == '__main__':
    sys.exit(main())
