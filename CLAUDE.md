# Islamic Beliefs: Reclaiming the Narrative

English translation of the Persian book **طرح کلی اندیشه اسلامی در قرآن** ("An Outline
of Islamic Thought in the Qur'an") — 28 Ramadan lectures (1353 / 1974) by Ayatollah
Khamenei, in 4 parts: Faith, Tawhid, Prophethood, Wilayah. This repo holds the English
edition (AsciiDoc source) plus the toolchain that builds it into a PDF, EPUB, and a
published website. All work lives under `book_en/`.

**Live site:** https://zainrizvi.github.io/islamic-beliefs-reclaiming-the-narrative/
(auto-rebuilds + deploys on every push to `main` that touches `book_en/`.)

**Running todo list:** [`docs/todo.md`](docs/todo.md)

## Commands

Run from `book_en/` (Docker; no local Ruby needed):

- `docker compose build` — build the toolchain image (once / on Gemfile change)
- `docker compose run --rm all` — validate, then render HTML + PDF + EPUB
- `docker compose run --rm site` — build the full website into `build/site/`
- `docker compose run --rm pdf` / `epub` / `html` — render a single format
- `docker compose run --rm validate` — footnote/citation/index consistency checks
- `docker compose run --rm shell` — interactive shell in the environment

CI mirrors this exactly: `.github/workflows/pages.yml` runs `bash tools/build.sh site`
(with the tool commands pointed at `bundle exec`) and deploys `build/site/` to Pages.
`build.sh` is the single source of truth — CI never re-implements the build.

## Content layout (source of truth = AsciiDoc under `book_en/src/`)

- `src/book.adoc` — master document: title, 4 part dividers, `include::`s every
  chapter, then the three back-matter index sections.
- `src/sessions/session_NN.adoc` — the 28 lectures (one file each).
- `src/front/note.adoc`, `src/front/author-introduction.adoc` — front matter.
- `src/_generated/concepts-index.adoc` — committed placeholder; the real concepts
  index is generated into `build/render/` at build time (never hand-edit).
- `book_en/sessions/*.md`, `book_en/front_*.md`, `book_en/reviews/*` — the ORIGINAL
  Markdown translation + per-chapter fidelity reviews. Historical/reference only;
  the AsciiDoc in `src/` is what's built. Don't edit the `.md` expecting it to ship.

## Tooling (`book_en/tools/`)

- `build.sh` — build driver (`pdf|epub|html|site|validate|all`). Tool commands are
  overridable env vars (`AD`, `ADPDF`, `ADEPUB`, `RUBY`) so CI can prefix `bundle exec`.
- `validate.rb` — consistency checks (footnotes, verse markers vs citations, surah
  names, `____` balance, no leftover artifacts). Run before every render.
- `build_indexes.rb` — NON-DESTRUCTIVE: copies `src/` → `build/render/`, turns
  `@@CX(...)@@` concept markers into anchors THERE, generates the concepts index.
  The committed sources keep full marker text, so nothing is ever lost.
- `extensions/quran_index.rb` — Asciidoctor TreeProcessor: builds the mushaf-ordered
  "Index of Qur'anic Verses" from `[role="verse quran",s=,a=]` markers.
- `theme/book-theme.yml` — 6×9 PDF theme (Noto Serif body, Amiri for Arabic).
- `web/` — website assets: `docinfo.html` (head: fonts + all site CSS incl. dark
  mode + the TOC drawer), `reader.js` (infinite-scroll + drawer), `split_pages.rb`
  (splits the rendered HTML into per-chapter pages).
- `check_markers_only.py` — safety gate: confirms an edit inserted ONLY index
  markers (strips them, diffs against a pristine snapshot; `--revert` auto-restores).

## The three indexes

1. **Qur'anic Verses** — auto from `[role="verse quran"]` markers (extension).
2. **Concepts & Key Ideas** — from inline `@@CX(Primary | sub-aspect)@@` markers
   (seeded from the user's handwritten list in `tools/CONCEPT_SEED.md`).
3. **General Index** — native AsciiDoc `(((term)))` entries.

## Website (`tools/web/`, built by `build.sh site`)

`split_pages.rb` turns the single rendered `index.html` into: a per-chapter page at
`p/<slug>.html` (own URL, works standalone/no-JS), a content fragment
`p/<slug>.frag.html`, and `p/manifest.json`. `reader.js` provides:
- **Infinite scroll** — nearing the end of the loaded content fetches the next
  chapter's fragment, appends it, and updates the address bar + title.
- **TOC drawer** — hamburger toggle → slide-in panel, current chapter highlighted,
  click-to-jump. Accessible (focus management, `visibility:hidden` when closed).
- **Dark mode** — auto via `prefers-color-scheme` (CSS variables in `docinfo.html`).

## Qur'anic Arabic — accuracy rule

Verse blocks show Arabic script. The Arabic is sliced VERBATIM from the
`risan/quran-json` dataset by surah:ayah (public-domain Uthmani text) — agents pick
word-index ranges, NEVER type Arabic, so it's byte-perfect. Single-quote blocks show
only the fragment the author quoted; woven exegetical blocks show the full ayah on top.
When editing anywhere near verses, the `[.arabic]` lines must stay byte-identical
(verify with a hash); only Latin transliteration/prose may change.

## Authoring principles

- **Single source.** Edit prose in `src/`; never hand-edit rendered output or page
  numbers — they regenerate each build.
- **Faithful, full translation — never summarize.** Preserve the lecturer's
  repetition, asides, examples. A draft far shorter than its source dropped content.
- **One chapter per agent** during translation/editing (hallucination guard); during
  review, watch for accidental summarization.
- **Consistent terminology / transliteration.** Diacritics are folded to plain
  letters for readability (wilayat, Surat, Qur'an, 'Ali); keep it uniform so index
  entries don't fragment.

## Commit & deploy discipline

- Separate **structural** commits (tooling, format, site/CSS/JS) from **content**
  commits (translation edits, index curation, verse text). Structural first.
- Commit only when `validate` passes. Each commit is one logical unit; label it
  structural or content.
- Before pushing: run `/review-agent` over the diff and implement valid findings
  (pushing publishes the public site). Push to `main` triggers the Pages deploy.

## Gotchas

- System Ruby is 2.6 (too old); the toolchain needs Ruby ≥3.2 — use Docker (or
  Homebrew Ruby at `/opt/homebrew/opt/ruby/bin`).
- Debian Amiri font package is `fonts-hosny-amiri`, not `fonts-amiri`.
- Docker image has NO python3 — site tooling is Ruby (`split_pages.rb`), not Python.
- The infinite-scroll sentinel must be a SMALL element at the end of content, not the
  (very tall) chapter article itself — observing a full article never re-fires the
  IntersectionObserver. (See `reader.js`.)
- Only `book_en/` is git-tracked (see root `.gitignore`); `build/`, `audio/`, and the
  Persian source PDF are ignored.
