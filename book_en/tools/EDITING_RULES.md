# Editing Pass Rules

You edit ONE chapter (one `.adoc` file) against ONE Persian source chunk. Three
concerns, in this order. This is the user's own book; the goal is a faithful,
publishable English edition — improve quality WITHOUT changing meaning or dropping
content.

## Cardinal rule: faithful and COMPLETE
- Never summarize, condense, or drop a sentence. The translation must remain a
  full rendering. If anything, restore detail; never remove it.
- Preserve the lecturer's voice: rhetorical repetition, direct address, asides,
  examples, anecdotes. Do not "tighten" these away.

## Pass 1 — Translation accuracy (vs. the Persian source)
- Read the Persian chunk and the English `.adoc` in parallel, paragraph by
  paragraph. Fix mistranslations, wrong word senses, dropped clauses, and
  reversed meanings.
- Watch for: bidi/extraction artifacts in the Persian that may have misled the
  first pass; idioms rendered too literally; technical religious terms.
- The Persian's Arabic Qur'an glyphs are scrambled (extraction artifact) — judge
  verse meaning from the citation + the author's surrounding Persian rendering,
  not the glyphs.

## Pass 2 — Footnote accuracy and consistency
- Every footnote's claim must be correct and match the source. Verse-citation
  footnotes (surah + ayah) must agree with the `[role="verse quran",s=,a=]`
  marker on the block AND with the (N:M) in the verse text. If they disagree,
  fix the footnote and/or the marker so all three agree.
- Lexical/root-letter glosses: keep accurate; fix obvious transliteration errors.
- Do not delete footnotes. Keep ids in the `slug-N` form already present.

## Pass 3 — Style and readability (faithful)
- Improve flow, fix awkward calques, regularize punctuation and em-dashes,
  ensure consistent terminology (Tawhid, Prophethood, Wilayah, Ummah, the
  Biʿthah, Tāghūt, etc.).
- Keep transliteration diacritics consistent.
- Do NOT paraphrase for brevity. Readability edits must preserve every idea.

## AsciiDoc integrity (do not break the build)
- Keep the `[#anchor]`, `== Title`, `[.session-subtitle]` lines intact.
- Keep every `[role="verse quran",surah=,s=,a=]` / `[role="hadith"]` marker and
  its `[quote] ____ ... ____` block; keep `____` delimiters balanced.
- Keep footnotes inline as `footnote:slug-N[...]` (defs) / `footnote:slug-N[]`
  (reuse). Don't reintroduce a trailing footnote list.
- Do not add index `(((...)))` entries in this pass — that is a separate step.

## Output
- Overwrite the same `.adoc` file in place with the edited version.
- Then report: a concise changelog (bullet list of the substantive corrections
  you made, grouped by pass), counts of {translation-fixes, footnote-fixes,
  style-edits}, and confirm the file still has the same number of verse markers
  and footnotes as before (or explain any deliberate change).
