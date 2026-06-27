# Index Tagging Rules

You add index markers to ONE chapter (.adoc). Two kinds of index exist; you tag
for both. Do NOT change any prose, footnote, verse marker, or structure — only
INSERT the two kinds of markers described below. This is the user's own book.

## A. Concepts & Key Ideas index  — marker: @@CX(Primary | sub-aspect)@@
This is an ANALYTICAL index of ideas (propositions), not a keyword list. Model it
on entries like: "Faith — requires a sense of duty", "Tawhid's effects — destroys
class divisions", "Obeying other than God — strangles wisdom and growth".

- Place the marker IMMEDIATELY AFTER the sentence (after its period) that expresses
  the idea, inline. Example:
      ...most sins arise from fear.@@CX(Fear | most sins arise from it)@@
- Form: `@@CX(Primary | sub-aspect)@@` — primary is the headword (a noun/concept),
  sub-aspect is the specific idea. If an idea is best as a single headword with no
  sub-aspect, use `@@CX(Primary)@@`.
- Use the controlled vocabulary in tools/CONCEPT_SEED.md for primaries wherever it
  fits (Faith, Tawhid, Tawakkul, Anfāl, Wilayah, Tāghūt, etc.). Prefer reusing an
  existing primary over inventing a near-duplicate.
- Tag the SUBSTANTIVE ideas of the chapter — aim for roughly 8–16 markers per
  session (fewer for short front matter). Quality over quantity: tag genuine key
  ideas a reader would look up, not every sentence.
- The marker renders as nothing (concealed); it is stripped at build time.

## B. General subject index — marker: (((Term)))  or  (((Term, subentry)))
This is the conventional back-of-book index of names, places, terms, and topics.

- Use AsciiDoc concealed index terms: `(((Tāghūt)))`, `(((Abū Dharr)))`,
  `(((prayer, congregational)))`. Place INLINE right after the word/phrase.
- Tag: proper names (people, places, groups, books), technical terms
  (transliterated Arabic), and notable topics. ~10–20 per session.
- Two levels max: `(((primary, secondary)))`. Keep spelling consistent with the
  text (with diacritics).
- These feed the native "General Index" automatically.

## Critical constraints
- INSERT markers only. Never alter, reword, move, or delete existing text,
  footnotes (footnote:slug-N[...]), verse markers ([role="verse quran"...]),
  anchors ([#...]), or ____ quote blocks.
- Do not place a marker inside a [quote] ____ block's verse text, inside a
  footnote's [...], or inside the [role=...] attribute line. Place concept markers
  in the body prose only. (General (((...))) terms may go on the word in prose.)
- Keep the file building: balanced ____, intact markers. When unsure, tag less.

## Output
- Overwrite the same .adoc in place with markers inserted.
- Report: count of @@CX concept markers added, count of (((...))) general terms
  added, and the list of distinct concept PRIMARIES you used (so the orchestrator
  can normalize the vocabulary).
