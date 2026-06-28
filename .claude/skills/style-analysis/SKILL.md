---
name: style-analysis
description: Use when analyzing this book's prose to capture or refine its voice — e.g. extending docs/tone.md, deriving a style reference an editor or agent can apply across chapters, or comparing the translated voice against the source or another edition.
---

# Style Analysis

How to analyze this book's prose and turn what you find into a reusable voice
reference, so every chapter is edited toward the same target. The living output
of this method is `docs/tone.md`; use this skill when creating, extending, or
sanity-checking it.

## Derive from the text, don't impose a taxonomy

Don't arrive with a predetermined checklist. Read the actual prose and ask what
varies and what holds constant. The book is one speaker across 28 lectures, so
the voice is largely singular — but register shifts (fierce rebuke vs. patient
exposition vs. verse exegesis), and those shifts are part of the voice. The text
tells you where the boundaries are.

## What to analyze

Dimensions worth investigating — the text determines which matter:

- **Sentence patterns** — length distribution and rhythm; how they shift with
  intensity. (The bundled `prose-critique/resources/analyze.py` quantifies this:
  mean/median/stdev sentence length, opener variety, repetition.)
- **Diction and register** — recurring concrete imagery, the hot/indicting word
  choices to preserve, the academic circumlocutions to avoid.
- **Oral markers** — direct address, rhetorical questions, repetition-for-
  emphasis: the spoken-delivery fingerprints that should survive translation.
- **Logical connective style** — how arguments are signposted (or, in a raw
  transcript, where connectives are missing and must be supplied on the page).
- **Source-vs-output divergence** — when comparing editions, where one
  domesticates (e.g. converts a Persian calendar date) and the other preserves.

## Turn analysis into a reference, not a catalog

A style reference teaches a voice through **principles**, not exhaustive rules:

- **Principle** — the core insight in a few sentences: what the pattern is and
  why it works.
- **Representative example** — one or two, with a chapter/line citation, showing
  the principle in action. Prefer examples from our own text.
- **Pointer** — where to see more of the pattern in context.

An editor who internalizes a principle produces natural, consistent results. An
editor following a 40-item checklist produces something mechanical. This is why
`docs/tone.md` is written as states-and-principles, not a rulebook.

## Patterns vs. problems

Keep two things separate:

- **Intentional patterns** → the voice to reproduce. These belong in
  `docs/tone.md` ("Desired voice").
- **Unconscious tics / inconsistencies** → problems to fix. A word that recurs 29
  times, a register that's right in session 2 and flat in session 11 — these are
  issues for `prose-critique` to flag and revision to address, not voice to copy.

The test: would we want a future editor to *reproduce* this, or *fix* it?

## Quality tests for any voice reference

1. **Voice test** — could an editor, reading only this reference plus a chapter,
   produce prose that reads as the same book?
2. **Brevity test** — could they internalize it in one read? If they'd need to
   keep it open as a checklist while working, it's over-prescribed. Cut it down.
