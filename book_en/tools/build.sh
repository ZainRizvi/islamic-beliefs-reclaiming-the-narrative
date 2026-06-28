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

# Tool commands are overridable so CI (bundler) can prefix them with `bundle exec`
# without the script re-implementing anything. Locally they default to the bare
# binaries (present in the Docker image / on PATH). Arrays so multi-word values
# like "bundle exec asciidoctor" word-split correctly when invoked.
read -r -a RUBY <<< "${RUBY:-ruby}"
read -r -a AD <<< "${AD:-asciidoctor}"
read -r -a ADPDF <<< "${ADPDF:-asciidoctor-pdf}"
read -r -a ADEPUB <<< "${ADEPUB:-asciidoctor-epub3}"

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
  "${RUBY[@]}" "$ROOT/tools/build_indexes.rb" "$SRC_DIR" "$RENDER_DIR"
}

build_pdf() {
  require_src; prepare_render
  echo ">> Rendering PDF -> build/pdf-Islamic-Beliefs-Reclaiming-the-Narrative.pdf"
  "${ADPDF[@]}" "${ext_flags[@]+"${ext_flags[@]}"}" \
    -a pdf-theme="$ROOT/tools/theme/book-theme.yml" \
    -D "$OUT" -o "pdf-Islamic-Beliefs-Reclaiming-the-Narrative.pdf" "$RENDER_SRC"
}

build_epub() {
  require_src; prepare_render
  echo ">> Rendering EPUB -> build/epub-Islamic-Beliefs-Reclaiming-the-Narrative.epub"
  "${ADEPUB[@]}" "${ext_flags[@]+"${ext_flags[@]}"}" \
    -D "$OUT" -o "epub-Islamic-Beliefs-Reclaiming-the-Narrative.epub" "$RENDER_SRC"
}

build_html() {
  require_src; prepare_render
  echo ">> Rendering HTML -> build/html-Islamic-Beliefs-Reclaiming-the-Narrative.html"
  "${AD[@]}" "${ext_flags[@]+"${ext_flags[@]}"}" \
    -a toc=left -a sectnums \
    -D "$OUT" -o "html-Islamic-Beliefs-Reclaiming-the-Narrative.html" "$RENDER_SRC"
}

validate() {
  if [ -f "$ROOT/tools/validate.rb" ]; then
    echo ">> Running consistency validators"
    "${RUBY[@]}" "$ROOT/tools/validate.rb" "$SRC_DIR"
  else
    echo ">> No validator present yet (tools/validate.rb); skipping."
  fi
}

# Build the GitHub Pages site into build/site/: a single-file index.html with the
# Amiri web font + verse styling (via docinfo), plus the PDF/EPUB as downloads and
# a .nojekyll marker. Self-contained so CI and local produce the SAME output by
# calling this one function (no re-implementation, no divergence).
build_site() {
  require_src; prepare_render
  local site="$OUT/site"
  mkdir -p "$site"
  echo ">> Rendering site HTML -> build/site/index.html"
  "${AD[@]}" "${ext_flags[@]+"${ext_flags[@]}"}" \
    -a toc=left -a sectnums -a sectanchors -a idprefix -a idseparator=- \
    -a docinfo=shared -a docinfodir="$ROOT/tools/web" \
    -a 'linkcss!' \
    -D "$site" -o "index.html" "$RENDER_SRC"
  echo ">> Rendering downloads (PDF + EPUB) into build/site/"
  "${ADPDF[@]}" "${ext_flags[@]+"${ext_flags[@]}"}" \
    -a pdf-theme="$ROOT/tools/theme/book-theme.yml" \
    -D "$site" -o "Islamic-Beliefs-Reclaiming-the-Narrative.pdf" "$RENDER_SRC"
  "${ADEPUB[@]}" "${ext_flags[@]+"${ext_flags[@]}"}" \
    -D "$site" -o "Islamic-Beliefs-Reclaiming-the-Narrative.epub" "$RENDER_SRC"
  # .nojekyll so GitHub Pages serves files as-is (no Jekyll processing).
  touch "$site/.nojekyll"
  echo ">> Site ready in build/site/ (index.html + PDF + EPUB)"
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
