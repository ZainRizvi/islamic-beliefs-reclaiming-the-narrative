# Markdown → AsciiDoc Conversion Rules

Convert one chapter/front-matter file from Markdown to AsciiDoc. This is a
**mechanical, lossless** conversion: preserve every word, every footnote, every
verse. Do NOT re-translate, summarize, reorder, or "improve" the prose.

## Header / title

Markdown:
```
## Session 1: Faith (1)

*ایمان (۱) — delivered Thursday, 28 Shahrīvar 1353 / 2 Ramaḍān al-Mubārak 1394*
```
AsciiDoc — a level-1 section (the master doc supplies the book title as level 0):
```
[#session-01]
== Session 1: Faith (1)

[.session-subtitle]
_ایمان (۱) — delivered Thursday, 28 Shahrīvar 1353 / 2 Ramaḍān al-Mubārak 1394_
```
Front matter files use the same `== Title` level with anchors `[#front-note]`
and `[#author-introduction]`. Title text: "Note" and "Author's Introduction".

## Emphasis / bold

- `**bold**` → `*bold*`
- `*italic*` → `_italic_`
- Inline `` `code` `` (rare) → `` `code` `` (unchanged).

## Verse and hadith blockquotes

Markdown blockquote lines begin with `> `. A verse looks like:
```
> **Qurʾān, Sūrat Āl ʿImrān (3:133–134):** "And hasten to a forgiveness..."
```
Convert to an AsciiDoc quote block, and ATTACH a structured verse marker so the
Qur'an index can find it. Use this exact form for Qur'an verses:
```
[.verse,quran,surah="Āl ʿImrān",s=3,a="133-134"]
[quote]
____
*Qurʾān, Sūrat Āl ʿImrān (3:133–134):* "And hasten to a forgiveness..."
____
```
Rules for the marker attributes:
- `surah=` the surah name exactly as written (keep diacritics).
- `s=` the surah NUMBER (integer). `a=` the ayah or ayah-range as written
  (e.g. `156` or `133-134`). Derive the number from the citation in the text —
  the `(3:133–134)` means s=3. If the line gives only a name and no number you
  can resolve, set `s=0` and keep `a=""`, and note it in your report.
- For a **hadith** blockquote (`> **Hadith:** ...` or a narration), use:
  ```
  [.hadith]
  [quote]
  ____
  *Hadith:* "..."
  ____
  ```
  (no quran/surah attributes).
- Consecutive `>` lines that form ONE quotation go inside ONE `____ ... ____`
  block (preserve line breaks with a trailing ` +` only if the original clearly
  intends a hard break; otherwise let them flow). If the Markdown has several
  SEPARATE `>` blocks (blank `>`-less line between them), make several blocks.

## Footnotes

Markdown uses `[^N]` inline refs and `[^N]: text` definitions collected at the
end. AsciiDoc footnotes are inline-defined with an id so they can be reused:

- FIRST occurrence of a given N → full definition at the ref site:
  `footnote:fnN[The footnote text.]`
- Any later reuse of the same N → `footnote:fnN[]`
- Use a per-file id namespace already implied by N; the master include keeps
  files separate so ids won't collide across chapters (Asciidoctor scopes by
  document, and we render one combined doc — so PREFIX the id with the file slug
  to be safe): use `footnote:s01-N[...]` for session_01, `footnote:note-N[...]`
  for front_note, `footnote:intro-N[...]` for author intro.
- Move each definition's text from the bottom of the file to its first ref site.
  After doing this, DELETE the trailing list of `[^N]:` definitions and any
  `## Footnotes` / `== Footnotes` heading — AsciiDoc collects them automatically.
- Preserve footnote text exactly, including `*emphasis*`/`_italic_` conversions
  and any nested verse citations.

## Paragraphs and structure

- Keep paragraph breaks as-is (blank line between paragraphs).
- Do not introduce new headings. A session is a single `==` section with flowing
  paragraphs and quote blocks. (If the source had a stray `## Footnotes`, drop it
  per the footnote rule above.)
- Preserve em dashes, curly quotes, ellipses, and all diacritics verbatim.

## Output

Write ONLY the converted AsciiDoc. No backtick fences around the whole file, no
commentary. The file must start with the `[#...]` anchor line.
