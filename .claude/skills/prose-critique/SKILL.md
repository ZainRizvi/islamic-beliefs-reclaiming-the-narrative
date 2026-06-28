---
name: prose-critique
description: Use when reviewing or evaluating the English prose of this book's chapters — assessing a draft translation's readability, voice fidelity, and faithfulness to the source. Adversarial close-reading that finds what does not work rather than confirming what does.
---

# Prose Critique

Find what doesn't work. A draft's author already believes it works — challenge
that. A critique that says "reads well" without digging is worse than none: it
creates false confidence. Earn any praise by reading critically first.

## The lenses that matter here

This is a faithful translation of transcribed nonfiction lectures, so the review
dimensions are not a novelist's. Assess against these, in priority order:

1. **Fidelity** — does the English say what the source says, in full? Watch
   specifically for **accidental summarization** (the cardinal sin per
   `CLAUDE.md` / `docs/tone.md`): dropped sentences, compressed asides, an
   example or repetition silently cut. A draft markedly shorter than its source
   dropped content. Also flag meaning drift and softened claims.
2. **Voice** — is the lecturer's force intact, or flattened to neutral
   paraphrase? Check against `docs/tone.md` "Desired voice": hot concrete diction,
   emotional charge, oral directness. A passage that no longer *moves* a listener
   has lost something real.
3. **Readability** — would a reader get through it without re-reading? Flag the
   print-adaptation failures from `docs/tone.md` "What to fix": **periodic /
   left-branching sentences** that strand the main clause at the end (the verb-last
   Persian order carried into English), run-on sentences (~40+ words / three-plus
   stacked qualifiers), stacked `of X and of Y that Z` prepositional chains and the
   ambiguous modifiers they create, missing logical connectives between thoughts,
   academic circumlocution where a plain word would serve.
4. **Consistency** — terminology and transliteration (Tawhid, Prophethood,
   Wilayah, the Bi'thah, etc.) uniform so index entries don't fragment; verse
   handling per the Qur'anic-accuracy rule.

## What makes a good finding

- **Specific.** Cite the chapter, paragraph, or line. "The pacing has issues" is
  not a finding.
- **Reasoned.** Say why it matters and what it costs — lost force, a reader
  stumbling, a claim weakened, a meaning changed.
- **Directable.** After reading it, the editor should know what to do. If the fix
  isn't obvious, say what decision or source-check is needed.
- **Non-obvious.** Spell-check caught the typos. You're here for things that need
  understanding of the source, the voice contract, and how the prose reads.

### What wastes time

- Vague "this could be stronger" with no how or why.
- Restating what the prose says without naming a problem.
- Praising what works (unless balanced feedback was requested).
- Re-litigating settled project decisions (the controlled vocabulary, the
  diacritic-folding convention) — critique execution, not premise.

## Communicating impact

Signal severity clearly. Lead with what damages the reading or betrays the
source: dropped content, meaning drift, lost force, a sentence a reader can't
parse. Let smaller observations follow. Tie every finding to a concrete cost.

## Your report

Open with the big picture: is this draft faithful, does it carry the voice, does
it read cleanly? Then findings grouped by severity. End with the single most
important thing to fix and the one change that would most improve the draft.

## Optional: mechanical analysis

A bundled, self-contained Python script measures mechanical prose properties —
sentence-length distribution (mean/median/stdev), sentence-opener variety,
repetition within a paragraph window, pronoun distribution. Useful as a
quantitative signal: e.g. a high mean sentence length flags run-on risk per
`docs/tone.md` rule #2. Read-only; reads one local file, prints to stdout, no
network or writes.

```bash
python3 resources/analyze.py <file.md> [window_size]
# or, if uv is available:  uv run resources/analyze.py <file.md> [window_size]
```

Use it to compare a draft against the book's own baseline, not against an
external target — the goal is a consistent voice across all 28 sessions.
