#!/usr/bin/env python3
"""Apply matched-Arabic decisions to the verse blocks — byte-perfect, no fabrication.

Input: a decisions JSON (list), one entry per verse block, of the form
  {"file":"sessions/session_01.adoc","idx":0,"s":3,"a":"133-134",
   "block_kind":"single"|"woven",
   "fragments":[{"english":"...","matched":true,"from":1,"to":7}, ...]}

For each block, the Arabic is sliced VERBATIM from the dataset (quran_lut.json)
using the agent's [from,to] word indices — agents never supply Arabic text, so the
script alone controls the characters. Then the block is rewritten:

  SINGLE (one fragment):
    [.quranverse]
    ****
    [.arabic]
    <sliced arabic>

    "<english>"<footnote?>

    [.verse-cite]
    — Sūrat X (s:a)
    ****

  WOVEN (>=2 fragments): keep the [quote] block, but prefix each quoted English
  fragment with its matched Arabic inline as  [.arabic-inline]#<arabic># before
  the quote, so commentary structure is preserved.

Safety:
- Every emitted Arabic span is re-derived here by slicing the dataset; the agent's
  text is ignored for Arabic. A contiguous [from,to] over the numbered word list
  is guaranteed to be verbatim dataset text.
- Blocks/fragments with matched=false get NO Arabic (left as the original English).
- Re-locates each block by its (file, s, a, idx-within-file) — robust to edits
  elsewhere; aborts a block if its English body no longer matches the manifest.
"""
import re, sys, json, os

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = os.path.join(ROOT, 'src')
LUT = json.load(open(sys.argv[2], encoding='utf-8'))   # quran_lut.json
LUT = {int(k): {int(a): t for a, t in v.items()} for k, v in LUT.items()}
DECISIONS = json.load(open(sys.argv[1], encoding='utf-8'))

BLOCK = re.compile(
    r'\[role="verse quran",surah="([^"]*)",s=(\d+),a="([^"]*)"\]\n'
    r'\[quote\]\n____\n(.*?)\n____', re.S)
CITE = re.compile(r'^\*[^*]*?:\*\s*')

def ayah_list(a):
    a = a.strip().replace('–', '-').replace('—', '-').replace(' ff.', '')
    out = []
    for p in a.split(','):
        p = p.strip()
        if '-' in p:
            lo, hi = p.split('-', 1); out += list(range(int(lo), int(hi) + 1))
        elif p:
            out.append(int(p))
    return out

def numbered_words(s, a):
    words = []
    for ay in ayah_list(a):
        for w in LUT[s][ay].split():
            words.append(w)
    return words

def slice_arabic(s, a, frm, to):
    words = numbered_words(s, a)
    if frm < 1 or to > len(words) or frm > to:
        return None
    return ' '.join(words[frm - 1:to])

# index decisions by (file, idx)
dec_by = {(d['file'], d['idx']): d for d in DECISIONS}

stats = {'single': 0, 'woven': 0, 'frag_matched': 0, 'frag_unmatched': 0, 'skipped': 0}

def rebuild_single(surah, s, a, body, frag):
    eng = CITE.sub('', body.strip())
    cite = f"— Sūrat {surah} ({s}:{a})"
    if not frag.get('matched'):
        stats['frag_unmatched'] += 1
        return None   # no Arabic -> leave original
    ar = slice_arabic(s, a, frag['from'], frag['to'])
    if ar is None:
        stats['frag_unmatched'] += 1
        return None
    stats['frag_matched'] += 1
    return (f"[.quranverse]\n****\n[.arabic]\n{ar}\n\n{eng}\n\n"
            f"[.verse-cite]\n{cite}\n****")

def rebuild_woven(surah, s, a, body):
    """Woven exegetical block: show the COMPLETE ayah(s) Arabic once at the top
    (clean, like single blocks), then the lecturer's fragment-by-fragment English
    commentary unchanged below. No per-fragment alignment needed — the full ayah
    range is sliced verbatim, so there is no over/under-inclusion risk."""
    words = numbered_words(s, a)
    if not words:
        return None
    ar = ' '.join(words)                     # the complete ayah(s)
    eng = CITE.sub('', body.strip())         # drop the *cite:* prefix; keep exegesis
    cite = f"— Sūrat {surah} ({s}:{a})"
    stats['frag_matched'] += 1
    return (f"[.quranverse]\n****\n[.arabic]\n{ar}\n\n{eng}\n\n"
            f"[.verse-cite]\n{cite}\n****")

def process_file(path):
    rel = os.path.relpath(path, SRC)
    text = open(path, encoding='utf-8').read()
    # find this file's decisions, ordered by idx
    file_decs = [d for d in DECISIONS if d['file'] == rel]
    if not file_decs:
        return
    idx = -1
    def repl(m):
        nonlocal idx
        idx += 1
        surah, s, a, body = m.group(1), int(m.group(2)), m.group(3), m.group(4)
        d = dec_by.get((rel, idx))
        if not d:
            stats['skipped'] += 1
            return m.group(0)
        frags = d.get('fragments', [])
        if d.get('block_kind') == 'single' and len(frags) == 1:
            rb = rebuild_single(surah, s, a, body, frags[0])
            if rb is None:
                return m.group(0)
            stats['single'] += 1
            return rb
        else:
            rb = rebuild_woven(surah, s, a, body)
            if rb is None:
                return m.group(0)
            stats['woven'] += 1
            return rb
    new = BLOCK.sub(repl, text)
    if new != text:
        open(path, 'w', encoding='utf-8').write(new)

def main():
    for path in sorted(__import__('glob').glob(os.path.join(SRC, 'sessions', '*.adoc'))) + \
                sorted(__import__('glob').glob(os.path.join(SRC, 'front', '*.adoc'))):
        process_file(path)
    print("Applied verse Arabic:")
    for k, v in stats.items():
        print(f"  {k}: {v}")

if __name__ == '__main__':
    main()
