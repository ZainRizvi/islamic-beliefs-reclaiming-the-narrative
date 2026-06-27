#!/usr/bin/env bash
# Build driver for the book. Runs inside the Docker image (see compose.yaml),
# but also works on a host that has the Asciidoctor toolchain installed.
#
#   build.sh pdf | epub | html | validate | all
#
# Layout:
#   src/book.adoc            master document (includes the parts/chapters)
#   src/**/*.adoc            chapter + front/back matter sources
#   tools/extensions/*.rb    custom Asciidoctor extensions (Qur'an index, etc.)
#   tools/validate.rb        footnote / citation / index consistency checks
#   build/                   rendered output (gitignored)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/src/book.adoc"
OUT="$ROOT/build"
EXT="$ROOT/tools/extensions"
mkdir -p "$OUT"

# Collect any custom extensions as -r flags (none yet is fine).
ext_flags=()
if [ -d "$EXT" ]; then
  while IFS= read -r -d '' f; do ext_flags+=( -r "$f" ); done \
    < <(find "$EXT" -name '*.rb' -print0 2>/dev/null)
fi

require_src() {
  if [ ! -f "$SRC" ]; then
    echo "ERROR: $SRC not found. The AsciiDoc sources haven't been created yet." >&2
    echo "       (Conversion from the Markdown originals is a separate step.)" >&2
    exit 2
  fi
}

build_pdf() {
  require_src
  echo ">> Rendering PDF -> build/Islamic-Beliefs-Reclaiming-the-Narrative.pdf"
  asciidoctor-pdf "${ext_flags[@]}" \
    -a pdf-theme="$ROOT/tools/theme/book-theme.yml" \
    -a pdf-fontsdir="$ROOT/tools/theme/fonts;GEM_FONTS_DIR" \
    -D "$OUT" -o "Islamic-Beliefs-Reclaiming-the-Narrative.pdf" "$SRC"
}

build_epub() {
  require_src
  echo ">> Rendering EPUB -> build/Islamic-Beliefs-Reclaiming-the-Narrative.epub"
  asciidoctor-epub3 "${ext_flags[@]}" \
    -D "$OUT" -o "Islamic-Beliefs-Reclaiming-the-Narrative.epub" "$SRC"
}

build_html() {
  require_src
  echo ">> Rendering HTML -> build/Islamic-Beliefs-Reclaiming-the-Narrative.html"
  asciidoctor "${ext_flags[@]}" \
    -a toc=left -a sectnums \
    -D "$OUT" -o "Islamic-Beliefs-Reclaiming-the-Narrative.html" "$SRC"
}

validate() {
  if [ -f "$ROOT/tools/validate.rb" ]; then
    echo ">> Running consistency validators"
    ruby "$ROOT/tools/validate.rb" "$ROOT/src"
  else
    echo ">> No validator present yet (tools/validate.rb); skipping."
  fi
}

case "${1:-all}" in
  pdf)      build_pdf ;;
  epub)     build_epub ;;
  html)     build_html ;;
  validate) validate ;;
  all)      validate; build_html; build_pdf; build_epub ;;
  *) echo "Usage: build.sh {pdf|epub|html|validate|all}" >&2; exit 1 ;;
esac

echo ">> Done."
