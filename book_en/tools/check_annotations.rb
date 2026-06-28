#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Annotation-preservation gate.
#
#   ruby tools/check_annotations.rb [src_dir]   (default: ./src)
#
# Tone iterations rewrite the PROSE of each chapter. The annotations, however, are
# positional — glued mid-sentence — so a careless rewrite can silently drop one.
# This gate makes that impossible to miss: for every working chapter it compares
# the annotation INVENTORY against the frozen baseline in src/transcription/ and
# FAILS if anything was lost or altered.
#
# What it inventories per file (order-independent multisets / exact text):
#   - @@CX(primary | sub)@@        concept-index markers   (payload text)
#   - (((term)))                   general-index terms      (payload text)
#   - footnote:ID[...]             footnotes                (ID + definition text)
#   - [.arabic] verse lines        Qur'anic Arabic          (verbatim, byte-exact)
#
# Failure conditions (any of these is an ERROR):
#   - a baseline annotation is MISSING from the working file
#   - a footnote ID present in both has DIFFERENT definition text
#   - a verse's Arabic text CHANGED (scripture must stay byte-identical)
# Added annotations are reported as INFO (intentional during curation), not errors.
#
# Exit 0 if every chapter preserves its baseline annotations; 1 otherwise.

require 'digest'

SRC  = ARGV[0] || File.join(__dir__, '..', 'src')
BASE = File.join(SRC, 'transcription')

unless Dir.exist?(BASE)
  warn "No baseline at #{BASE} — nothing to check against."
  exit 0
end

# --- extractors -------------------------------------------------------------

# @@CX(...)@@  -> array of inner payloads (whitespace-normalized)
def cx_markers(t)
  t.scan(/@@CX\((.+?)\)@@/).map { |m| m[0].strip.gsub(/\s+/, ' ') }
end

# (((term))) / (((term, sub)))  -> array of payloads. Avoid matching the literal
# example in a // comment line by skipping comment lines.
def index_terms(t)
  out = []
  t.each_line do |line|
    next if line.lstrip.start_with?('//')
    line.scan(/\(\(\((.+?)\)\)\)/) { |m| out << m[0].strip.gsub(/\s+/, ' ') }
  end
  out
end

# footnote:ID[definition]  -> { id => definition_text }. Balanced-bracket aware:
# footnote bodies can contain nested [...] (e.g. lexical glosses), so we scan for
# the macro then walk to the matching close bracket.
def footnotes(t)
  out = {}
  # Strip AsciiDoc line comments first (symmetry with cx_markers/index_terms), so a
  # footnote: shown literally in a // doc comment isn't inventoried as a real one.
  t = t.lines.reject { |line| line.lstrip.start_with?('//') }.join
  i = 0
  while (m = t.match(/footnote:([a-z0-9-]+)\[/, i))
    id = m[1]
    start = m.end(0)            # char after the opening [
    depth = 1
    j = start
    while j < t.length && depth > 0
      c = t[j]
      depth += 1 if c == '['
      depth -= 1 if c == ']'
      j += 1
    end
    body = t[start...(j - 1)]    # between [ and matching ]
    # an empty [] is a footnote REUSE, not a definition — ignore (no text to lose)
    out[id] = body unless body.empty?
    i = j
  end
  out
end

# Arabic verse lines: the line(s) right after a `[.arabic]` role line, up to the
# next blank line. Returns array of {context, text} where context is the nearby
# verse-cite (for a readable error), text is the verbatim Arabic.
def arabic_blocks(t)
  lines = t.lines.map(&:chomp)
  out = []
  lines.each_with_index do |ln, idx|
    next unless ln.strip == '[.arabic]'
    # Collect the following Arabic-script lines as the payload. Stop at a blank
    # line OR at the first line with no Arabic characters (the English gloss),
    # so the hash covers ONLY scripture even if a future edit drops the blank
    # separator between the Arabic and its English translation.
    buf = []
    k = idx + 1
    while k < lines.length && !lines[k].strip.empty? && lines[k] =~ /\p{Arabic}/
      buf << lines[k]
      k += 1
    end
    out << buf.join("\n")
  end
  out
end

# --- compare ----------------------------------------------------------------

# multiset diff: items in `base` not covered by `work` (accounts for duplicates)
def missing_multiset(base, work)
  remaining = work.dup
  base.reject { |x| (i = remaining.index(x)) && remaining.delete_at(i) }
end

errors = []
info   = []

base_files = Dir.glob(File.join(BASE, '**', '*.adoc')).sort
abort "Baseline has no .adoc files under #{BASE}" if base_files.empty?

base_files.each do |bpath|
  sub  = bpath.sub(BASE + File::SEPARATOR, '')      # e.g. sessions/session_01.adoc
  wpath = File.join(SRC, sub)
  unless File.exist?(wpath)
    errors << "#{sub}: working file is MISSING (baseline exists)"
    next
  end
  b = File.read(bpath)
  w = File.read(wpath)

  # 1. concept markers
  miss = missing_multiset(cx_markers(b), cx_markers(w))
  miss.each { |m| errors << "#{sub}: dropped @@CX marker -> #{m}" }
  added = missing_multiset(cx_markers(w), cx_markers(b))
  added.each { |m| info << "#{sub}: added @@CX marker -> #{m}" }

  # 2. general-index terms
  miss = missing_multiset(index_terms(b), index_terms(w))
  miss.each { |m| errors << "#{sub}: dropped (((index))) term -> #{m}" }
  added = missing_multiset(index_terms(w), index_terms(b))
  added.each { |m| info << "#{sub}: added (((index))) term -> #{m}" }

  # 3. footnotes (id presence + definition text)
  bf = footnotes(b); wf = footnotes(w)
  bf.each do |id, text|
    if !wf.key?(id)
      errors << "#{sub}: dropped footnote #{id}"
    elsif wf[id] != text
      errors << "#{sub}: footnote #{id} TEXT CHANGED"
    end
  end
  (wf.keys - bf.keys).each { |id| info << "#{sub}: added footnote #{id}" }

  # 4. Arabic verse text (must be byte-identical — scripture)
  ba = arabic_blocks(b); wa = arabic_blocks(w)
  bh = ba.map { |x| Digest::SHA256.hexdigest(x) }
  wh = wa.map { |x| Digest::SHA256.hexdigest(x) }
  missing_h = missing_multiset(bh, wh)
  unless missing_h.empty?
    errors << "#{sub}: Arabic verse text changed or dropped " \
              "(#{ba.length} verse block(s) in baseline, #{missing_h.length} no longer match)"
  end
end

unless info.empty?
  puts "INFO (added since baseline — fine during curation):"
  info.each { |i| puts "  + #{i}" }
  puts
end

if errors.empty?
  puts "✓ Annotations preserved: every baseline @@CX, (((term))), footnote, and Arabic verse is intact."
  exit 0
else
  puts "✗ ANNOTATION LOSS/DRIFT (#{errors.length}):"
  errors.each { |e| puts "  - #{e}" }
  puts
  puts "These annotations exist in src/transcription/ but were lost or altered in the working copy."
  puts "Re-add them to the edited chapter (or, if a baseline change is truly intended, update src/transcription/ deliberately)."
  exit 1
end
