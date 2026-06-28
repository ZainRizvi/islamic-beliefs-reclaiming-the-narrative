#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Split the single rendered index.html into per-chapter pages for the web reader.
# (Ruby port — keeps the toolchain dependency-free; runs in the Asciidoctor image.)
#
# Input : build/site/index.html  (Asciidoctor book HTML, single file)
# Output: build/site/p/<slug>.html        standalone page per chapter (head+TOC+chapter)
#         build/site/p/<slug>.frag.html    content-only fragment (for JS append)
#         build/site/p/manifest.json       ordered [{slug,title,url,part,index}]
#         build/site/index.html            rewritten as the reader, starting at chapter 1
#
# Each chapter is a top-level <div class="sect1"> (its <h2 id> is the slug). Part
# dividers are <h1 id="part-..."> headings; each attaches to the chapter after it.
# Footnotes (one #footnotes block at the end) are filtered per page to those the
# chapter references.

require 'json'
require 'cgi'
require 'fileutils'

site = ARGV[0] || 'build/site'
src  = File.join(site, 'index.html')
pdir = File.join(site, 'p')
FileUtils.mkdir_p(pdir)

html = File.read(src)

head = html[0..(html.index('</head>') + '</head>'.length - 1)]
body_tag = html[/<body[^>]*>/]

toc_html = html[/<div id="toc".*?<\/div>\s*<\/div>\s*(?=<div id="content">)/m] || ''

content_start = html.index('<div id="content">') + '<div id="content">'.length
fn_md = html.match(/<div id="footnotes">.*?<\/div>\s*(?=<div id="footer">|<\/body>)/m)
content_end = fn_md ? fn_md.begin(0) : html.index('<div id="footer">')
content = html[content_start...content_end]
footnotes_block = fn_md ? fn_md[0] : ''

footer_md = html.match(/<div id="footer">.*?<\/div>\s*(?=<\/body>)/m)
footer_html = footer_md ? footer_md[0] : ''

# footnote id -> html
fn_items = {}
footnotes_block.scan(/<div class="footnote" id="(_footnotedef_\d+)">.*?<\/div>/m) do
  fn_items[$1] = $~[0]
end

def strip_tags(s) = CGI.unescapeHTML(s.gsub(/<[^>]+>/, '')).strip

# Per-page <head>: set a chapter-specific <title> and a rel=canonical so the 34
# standalone pages aren't indexed as duplicates. `canonical` is the page's path
# relative to the site (e.g. "p/session-01.html"); browsers/crawlers resolve it.
def head_for(head, title, canonical)
  h = head.sub(%r{<title>.*?</title>}m,
               %(<title>#{CGI.escapeHTML(title)} &middot; Islamic Beliefs</title>))
  h.sub('</head>', %(<link rel="canonical" href="#{canonical}">\n</head>))
end

footnotes_for = lambda do |chunk|
  ids = chunk.scan(/href="#(_footnotedef_\d+)"/).flatten.uniq
  ids.select! { |i| fn_items.key?(i) }
  return '' if ids.empty?
  ids.sort_by! { |i| i.split('_').last.to_i }
  body = ids.map { |i| fn_items[i] }.join("\n")
  %(<div id="footnotes"><hr>\n#{body}\n</div>)
end

# Balanced extraction of a <div ...> ... </div> starting at `start`.
def extract_div(s, start)
  i = start
  depth = 0
  re = /<(\/?)div\b[^>]*>/
  loop do
    m = s.match(re, i)
    return [s[start..], s.length] unless m
    if m[1].empty? then depth += 1 else depth -= 1 end
    if depth.zero?
      finish = m.end(0)
      return [s[start...finish], finish]
    end
    i = m.end(0)
  end
end

# Event stream: part headings + sect1 starts, in document order.
events = []
content.to_enum(:scan, /<h1 id="(part-[^"]*)"[^>]*>(.*?)<\/h1>/m).each do
  m = Regexp.last_match
  # carry BOTH the real Asciidoctor id and the label, so we never regenerate an
  # id from text (which could collide with a same-named section heading).
  events << [m.begin(0), :part, { id: m[1], label: strip_tags(m[2]) }]
end
# sect1 may carry extra classes (e.g. "sect1 quran-index-placeholder").
content.to_enum(:scan, /<div class="sect1(?:\s[^"]*)?">/).each do
  events << [Regexp.last_match.begin(0), :sect, Regexp.last_match.begin(0)]
end
events.sort_by! { |e| e[0] }

chapters = []
pending_part = nil
events.each do |_pos, kind, payload|
  if kind == :part
    pending_part = payload          # { id:, label: }
  else
    div_html, = extract_div(content, payload)
    slug = (div_html[/<h2 id="([^"]+)"/, 1]) || "chapter-#{chapters.length + 1}"
    titm = div_html[/<h2 id="[^"]+"[^>]*>(.*?)<\/h2>/m, 1]
    title = titm ? strip_tags(titm) : slug
    chapters << { slug: slug, title: title, html: div_html, part: pending_part }
    pending_part = nil
  end
end

manifest = []
chapters.each_with_index do |ch, idx|
  slug = ch[:slug]
  # Use the real Asciidoctor part id (carried from the rendered <h1 id>), never a
  # regenerated one — avoids duplicate/dead ids on title collisions.
  part_heading = ch[:part] ? %(<h1 class="part-divider" id="#{ch[:part][:id]}">#{ch[:part][:label]}</h1>\n) : ''
  body_html = "#{part_heading}#{ch[:html]}#{footnotes_for.call(ch[:html])}"
  # All element ids this chapter contains (its own sub-section anchors + any part
  # divider) so the reader can route a TOC link for a sub-section/part to the
  # chapter that owns it. Space-separated in data-anchors.
  anchors = body_html.scan(/\sid="([^"]+)"/).flatten.uniq.join(' ')
  chap_block = %(<article class="chapter" data-slug="#{slug}" data-index="#{idx}" data-anchors="#{anchors}" id="#{slug}">#{body_html}</article>)

  File.write(File.join(pdir, "#{slug}.frag.html"), chap_block)

  prev_link = idx > 0 ? %(<a rel="prev" href="#{chapters[idx - 1][:slug]}.html">&larr; Previous</a>) : '<span></span>'
  next_link = idx < chapters.length - 1 ? %(<a rel="next" href="#{chapters[idx + 1][:slug]}.html">Next &rarr;</a>) : '<span></span>'
  nav = %(<nav class="chapter-nav">#{prev_link}<a href="../index.html">Contents</a>#{next_link}</nav>)

  page = +''
  page << head_for(head, ch[:title], "p/#{slug}.html") << "\n" << body_tag << "\n" << '<div id="header"></div>' << "\n"
  page << toc_html << "\n"
  page << %(<div id="content" class="reader" data-start="#{slug}" data-base="">) << chap_block << '</div>' << "\n"
  page << nav << "\n" << footer_html << "\n"
  page << %(<script src="../reader.js" defer></script>) << "\n</body>\n</html>"
  File.write(File.join(pdir, "#{slug}.html"), page)

  manifest << { slug: slug, title: ch[:title], url: "p/#{slug}.html",
                part: ch[:part] && ch[:part][:label], index: idx }
end

File.write(File.join(pdir, 'manifest.json'), JSON.pretty_generate(manifest))

# Rewrite landing index.html as the reader, starting at the first chapter.
first = chapters.first[:slug]
first_frag = File.read(File.join(pdir, "#{first}.frag.html"))
landing = +''
# Landing keeps the book's full title; canonical points to the site root.
landing << head.sub('</head>', %(<link rel="canonical" href="./">\n</head>)) << "\n" << body_tag << "\n" << '<div id="header"></div>' << "\n"
landing << toc_html << "\n"
landing << %(<div id="content" class="reader" data-start="#{first}" data-base="p/">) << first_frag << '</div>' << "\n"
landing << footer_html << "\n"
landing << %(<script src="reader.js" defer></script>) << "\n</body>\n</html>"
File.write(src, landing)

puts "split into #{chapters.length} chapters -> #{pdir}/"
puts "  first: #{first} | last: #{chapters.last[:slug]}"
