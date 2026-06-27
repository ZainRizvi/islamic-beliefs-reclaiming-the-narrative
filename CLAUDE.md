# Islamic Beliefs: Reclaiming the Narrative

English translation of the Persian book **طرح کلی اندیشه اسلامی در قرآن** ("An Outline of Islamic Thought in the Qur'an") — 28 Ramadan lectures (1353/1974), in 4 parts: Faith, Tawhid, Prophethood, Wilayah. The work lives under `book_en/`.

## Commands

Run from `book_en/` (Docker; no local Ruby needed):

- `docker compose build` — build the toolchain image (once / on Gemfile change)
- `docker compose run --rm pdf` — render PDF
- `docker compose run --rm epub` / `html` — render those formats
- `docker compose run --rm validate` — footnote/citation/index consistency checks
- `docker compose run --rm all` — validate, then render all formats
- `docker compose run --rm shell` — interactive shell in the environment

## Key Directories

- `book_en/sessions/` — the 28 per-session Markdown translations (`session_NN.md`); current source of truth
- `book_en/front_note.md`, `front_author_intro.md` — front matter
- `book_en/reviews/` — per-chapter fidelity reviews
- `book_en/src/` — AsciiDoc sources (the authoring format we are migrating to)
- `book_en/tools/` — `build.sh`, custom Asciidoctor `extensions/`, `theme/`, `validate.rb`
- `book_en/build/` — rendered output (gitignored)
- `audio/` — 28 source MP3s (gitignored)
- `*.pdf` (root) — the Persian source PDF (862pp, AES-encrypted, copy allowed)

Only `book_en/` is tracked by git (see `.gitignore`).

## Authoring Workflow

Markdown is being migrated to **AsciiDoc** so indexes and cross-references regenerate on every build (Markdown can't encode index/verse markers as data).

- **Single source.** Edit prose in `src/`; never hand-edit rendered output or page numbers — page numbers exist only in the PDF and regenerate each build.
- **Indexes auto-generate.** Three apparatuses: Concepts & Key Ideas (curated), Qur'anic Verses (from verse markers), General Subject. Mark terms inline; don't maintain index lists by hand.
- **Verses.** Arabic glyphs in the source PDF extract scrambled — always reconstruct a verse from its footnote citation (surah + ayah), never from the raw glyphs. Render the meaning per the author's own in-text rendering.
- **Validate before render.** `validate` must pass (footnotes resolve, citations internally consistent) before building.

## Translation Principles

- **Faithful, full translation — never summarize.** Translate every sentence; preserve the lecturer's repetition, asides, and examples. A draft far shorter than its source means content was dropped.
- **One chapter per agent.** During translation/editing, an agent reads at most one session (hallucination guard). During review, watch specifically for accidental summarization.
- **Consistent terminology.** Tawhid, Prophethood, Wilayah, Ummah, the Bi'thah, etc. — keep the controlled vocabulary uniform so index entries don't fragment.

## Commit Discipline

- Separate **structural** changes (format conversion, tooling, reflow) from **content** changes (translation edits, index curation); don't mix in one commit. Structural first.
- Commit only when `validate` passes. Each commit is one logical unit; say whether it's structural or content.

## Gotchas

- System Ruby is 2.6 (too old); the toolchain needs Ruby ≥3.2 — use Docker, or Homebrew Ruby (`/opt/homebrew/opt/ruby/bin`).
- Debian Amiri font package is `fonts-hosny-amiri`, not `fonts-amiri`.
- Your handwritten index references the official 500-page **English** edition (not in repo). Treat it as a concept seed-list and locator, not as page data — match concepts by content to our text.
