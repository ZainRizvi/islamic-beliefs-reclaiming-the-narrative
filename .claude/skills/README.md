# Project skills

Repo-local Claude skills for editing the English edition. They encode this
project's prose standards and tie back to `docs/tone.md` (the voice contract).

- **prose-craft** — line-level technique for writing/revising the translated prose.
- **prose-critique** — adversarial close-reading for evaluating a draft; bundles
  `prose-critique/resources/analyze.py`, a read-only prose-metrics script.
- **style-analysis** — method for deriving/refining the voice reference in `docs/tone.md`.

## Provenance

`prose-craft`, `prose-critique` (incl. `analyze.py`), and `style-analysis` were
adapted from the **creative-writing-skills** plugin by Jimmy Yao
(https://github.com/haowjy/creative-writing-skills), licensed Apache-2.0. The
upstream skills target fiction; they were rewritten here for this book's
faithful-translation-of-transcribed-lectures context. `analyze.py` is used
unmodified (byte-identical to upstream).
