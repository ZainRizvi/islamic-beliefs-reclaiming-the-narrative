#!/usr/bin/env bash
# Build driver for the book. Runs inside the Docker image (see compose.yaml),
# but also works on a host that has the Asciidoctor toolchain installed.
#
#   build.sh pdf | epub | html | validate | all
#
# Layout:
#   src/book.adoc            master document (includes the parts/chapters)
#   src/**/*.adoc            chapter + front/back matter sources (NEVER mutated)
#   tools/extensions/*.rb    custom Asciidoctor extensions (Qur'an index, etc.)
#   tools/build_indexes.rb   builds a processed render tree from the sources
#   tools/validate.rb        footnote / citation / index consistency checks
#   build/render/            processed copy of src (markers->anchors); rendered from here
#   build/                   rendered output (gitignored)
#
# The concepts index is produced non-destructively: build_indexes.rb copies src/
# to build/render/, turning @@CX(...)@@ markers into anchors there. The committed
# sources keep the full marker text, so nothing is ever lost.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT/src"
RENDER_DIR="$ROOT/build/render"
RENDER_SRC="$RENDER_DIR/book.adoc"
OUT="$ROOT/build"
EXT="$ROOT/tools/extensions"
mkdir -p "$OUT"

ext_flags=()
if [ -d "$EXT" ]; then
  while IFS= read -r -d '' f; do ext_flags+=( -r "$f" ); done \
    < <(find "$EXT" -name '*.rb' -print0 2>/dev/null)
fi

require_src() {
  if [ ! -f "$SRC_DIR/book.adoc" ]; then
    echo "ERROR: $SRC_DIR/book.adoc not found." >&2
    exit 2
  fi
}

# Build the processed render tree (src copy with concept markers -> anchors +
# the generated concepts index). Non-destructive: sources are untouched.
prepare_render() {
  echo ">> Building render tree (concepts index)"
  ruby "$ROOT/tools/build_indexes.rb" "$SRC_DIR" "$RENDER_DIR"
}

build_pdf() {
  require_src; prepare_render
  echo ">> Rendering PDF -> build/pdf-Islamic-Beliefs-Reclaiming-the-Narrative.pdf"
  asciidoctor-pdf "${ext_flags[@]}" \
    -a pdf-theme="$ROOT/tools/theme/book-theme.yml" \
    -D "$OUT" -o "pdf-Islamic-Beliefs-Reclaiming-the-Narrative.pdf" "$RENDER_SRC"
}

build_epub() {
  require_src; prepare_render
  echo ">> Rendering EPUB -> build/epub-Islamic-Beliefs-Reclaiming-the-Narrative.epub"
  asciidoctor-epub3 "${ext_flags[@]}" \
    -D "$OUT" -o "epub-Islamic-Beliefs-Reclaiming-the-Narrative.epub" "$RENDER_SRC"
}

build_html() {
  require_src; prepare_render
  echo ">> Rendering HTML -> build/html-Islamic-Beliefs-Reclaiming-the-Narrative.html"
  asciidoctor "${ext_flags[@]}" \
    -a toc=left -a sectnums \
    -D "$OUT" -o "html-Islamic-Beliefs-Reclaiming-the-Narrative.html" "$RENDER_SRC"
}

validate() {
  if [ -f "$ROOT/tools/validate.rb" ]; then
    echo ">> Running consistency validators"
    ruby "$ROOT/tools/validate.rb" "$SRC_DIR"
  else
    echo ">> No validator present yet (tools/validate.rb); skipping."
  fi
}

# Build the GitHub Pages site: a single-file index.html with the Amiri web font
# and verse styling injected via docinfo. Output goes to build/site/.
build_site() {
  require_src; prepare_render
  local site="$OUT/site"
  mkdir -p "$site"
  echo ">> Rendering site -> build/site/index.html"
  asciidoctor "${ext_flags[@]}" \
    -a toc=left -a sectnums -a sectanchors -a idprefix -a idseparator=- \
    -a docinfo=shared -a docinfodir="$ROOT/tools/web" \
    -a 'linkcss!' \
    -D "$site" -o "index.html" "$RENDER_SRC"
  # Also drop the standalone downloadable artifacts beside it, if present.
  for ext in pdf epub; do
    f="$OUT/${ext}-Islamic-Beliefs-Reclaiming-the-Narrative.${ext}"
    [ -f "$f" ] && cp "$f" "$site/" || true
  done
  # .nojekyll so GitHub Pages serves files as-is (no Jekyll processing).
  touch "$site/.nojekyll"
  echo ">> Site ready in build/site/ (index.html + downloads)"
}

case "${1:-all}" in
  pdf)      build_pdf ;;
  epub)     build_epub ;;
  html)     build_html ;;
  site)     build_site ;;
  validate) validate ;;
  all)      validate; build_html; build_pdf; build_epub ;;
  *) echo "Usage: build.sh {pdf|epub|html|site|validate|all}" >&2; exit 1 ;;
esac

echo ">> Done."
