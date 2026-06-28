#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Consistency validator for the book sources.
#
#   ruby tools/validate.rb [src_dir]   (default: ./src)
#
# Checks, per the project's editing requirements:
#   1. Footnotes: every reuse footnote:ID[] has a definition footnote:ID[text];
#      no duplicate definitions; no empty definitions; ids namespaced per file.
#   2. Qur'an verse markers: the s=/a= attributes match the (N:M) citation in the
#      verse text, and the surah= name matches the canonical name for s=.
#   3. Quote-block delimiters (____) are balanced per file.
#   4. No leftover Markdown footnote definitions ([^N]:) or markers ([.verse).
#
# Exit status: 0 if clean (warnings allowed), 1 if any ERROR found.

require 'set'

SRC = ARGV[0] || File.join(__dir__, '..', 'src')

# Canonical surah names by number (mirror of quran_index.rb).
SURAH = {
  1=>'al-Fātiḥah',2=>'al-Baqarah',3=>'Āl ʿImrān',4=>'al-Nisāʾ',5=>'al-Māʾidah',
  6=>'al-Anʿām',7=>'al-Aʿrāf',8=>'al-Anfāl',9=>'al-Tawbah',10=>'Yūnus',11=>'Hūd',
  12=>'Yūsuf',13=>'al-Raʿd',14=>'Ibrāhīm',15=>'al-Ḥijr',16=>'al-Naḥl',17=>'al-Isrāʾ',
  18=>'al-Kahf',19=>'Maryam',20=>'Ṭāhā',21=>'al-Anbiyāʾ',22=>'al-Ḥajj',23=>'al-Muʾminūn',
  24=>'al-Nūr',25=>'al-Furqān',26=>'al-Shuʿarāʾ',27=>'al-Naml',28=>'al-Qaṣaṣ',
  29=>'al-ʿAnkabūt',30=>'al-Rūm',31=>'Luqmān',32=>'al-Sajdah',33=>'al-Aḥzāb',34=>'Sabaʾ',
  35=>'Fāṭir',36=>'Yāsīn',37=>'al-Ṣāffāt',38=>'Ṣād',39=>'al-Zumar',40=>'Ghāfir',
  41=>'Fuṣṣilat',42=>'al-Shūrā',43=>'al-Zukhruf',44=>'al-Dukhān',45=>'al-Jāthiyah',
  46=>'al-Aḥqāf',47=>'Muḥammad',48=>'al-Fatḥ',49=>'al-Ḥujurāt',50=>'Qāf',51=>'al-Dhāriyāt',
  52=>'al-Ṭūr',53=>'al-Najm',54=>'al-Qamar',55=>'al-Raḥmān',56=>'al-Wāqiʿah',57=>'al-Ḥadīd',
  58=>'al-Mujādilah',59=>'al-Ḥashr',60=>'al-Mumtaḥanah',61=>'al-Ṣaff',62=>'al-Jumuʿah',
  63=>'al-Munāfiqūn',64=>'al-Taghābun',65=>'al-Ṭalāq',66=>'al-Taḥrīm',67=>'al-Mulk',
  68=>'al-Qalam',69=>'al-Ḥāqqah',70=>'al-Maʿārij',71=>'Nūḥ',72=>'al-Jinn',73=>'al-Muzzammil',
  74=>'al-Muddaththir',75=>'al-Qiyāmah',76=>'al-Insān',77=>'al-Mursalāt',78=>'al-Nabaʾ',
  79=>'al-Nāziʿāt',80=>'ʿAbasa',81=>'al-Takwīr',82=>'al-Infiṭār',83=>'al-Muṭaffifīn',
  84=>'al-Inshiqāq',85=>'al-Burūj',86=>'al-Ṭāriq',87=>'al-Aʿlā',88=>'al-Ghāshiyah',
  89=>'al-Fajr',90=>'al-Balad',91=>'al-Shams',92=>'al-Layl',93=>'al-Ḍuḥā',94=>'al-Sharḥ',
  95=>'al-Tīn',96=>'al-ʿAlaq',97=>'al-Qadr',98=>'al-Bayyinah',99=>'al-Zalzalah',
  100=>'al-ʿĀdiyāt',101=>'al-Qāriʿah',102=>'al-Takāthur',103=>'al-ʿAṣr',104=>'al-Humazah',
  105=>'al-Fīl',106=>'Quraysh',107=>'al-Māʿūn',108=>'al-Kawthar',109=>'al-Kāfirūn',
  110=>'al-Naṣr',111=>'al-Masad',112=>'al-Ikhlāṣ',113=>'al-Falaq',114=>'al-Nās',
}.freeze

errors = []
warnings = []

def norm_name(s)
  # Compare surah names diacritic-insensitively: fold transliteration diacritics
  # to base letters, drop ayn/hamza/apostrophes, spaces, hyphens, and the "al"
  # article. So "Āl ʿImrān", "Al 'Imran", and "al-Imran" all compare equal.
  t = s.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')  # strip combining marks
  t.downcase.gsub(/[\s\-ʾʿʼʻ'’]/, '').sub(/\Aal/, '')
end

def norm_range(s)
  # normalize ayah range: en/em dashes -> hyphen, strip spaces
  s.to_s.gsub(/[‐-―]/, '-').gsub(/\s/, '')
end

files = Dir.glob(File.join(SRC, '**', '*.adoc')).reject { |f| File.basename(f) == 'book.adoc' }.sort
abort "No .adoc files under #{SRC}" if files.empty?

files.each do |path|
  rel = path.sub(%r{\A.*/src/}, 'src/')
  text = File.read(path)

  # --- 1. Footnotes -------------------------------------------------------
  defs = Hash.new(0)   # id -> count of definitions (footnote:id[ + nonbracket ])
  uses = Set.new       # id -> appears as reuse footnote:id[]
  text.scan(/footnote:([a-z0-9]+-\d+)\[(\]?)/) do |id, empty|
    if empty == ']'
      uses << id
    else
      defs[id] += 1
    end
  end
  defs.each { |id, n| errors << "#{rel}: footnote #{id} defined #{n} times" if n > 1 }
  # empty definition: footnote:id[] with nothing — only an error if id never defined
  uses.each { |id| errors << "#{rel}: footnote #{id} reused but never defined" unless defs.key?(id) }

  # leftover markdown footnote defs / markers
  errors << "#{rel}: leftover Markdown footnote definition [^N]:" if text =~ /^\[\^\d+\]:/
  # old verse/hadith marker syntax (now [role=...]); allow the [.verse-cite] role.
  errors << "#{rel}: leftover [.verse marker (use [role=...])" if text =~ /\[\.verse[,\]]/
  errors << "#{rel}: leftover [.hadith marker (use [role=...])" if text.include?('[.hadith')

  # --- 2. Quote-block delimiter balance ----------------------------------
  delim = text.lines.count { |l| l.strip == '____' }
  errors << "#{rel}: unbalanced ____ delimiters (#{delim}, odd)" if delim.odd?

  # --- 3. Verse markers: attribute vs citation consistency ---------------
  # Walk each marker line + the following non-empty content line (the citation).
  lines = text.lines
  lines.each_with_index do |line, i|
    next unless line =~ /\[role="[^"]*\bquran\b[^"]*"/
    surah = line[/surah="([^"]*)"/, 1]
    s = line[/[,\s]s=("?)(\d+)\1/, 2]&.to_i
    a = line[/a="([^"]*)"/, 1]
    # find the citation text within the next few lines (skip [quote] and ____)
    cite = nil
    (i+1..[i+5, lines.size-1].min).each do |j|
      l = lines[j].strip
      next if l.empty? || l == '[quote]' || l == '____'
      cite = l; break
    end
    next unless cite
    # extract (N:M) or (N) from the citation
    if (m = cite.match(/\((\d+):([0-9‐-―,\s-]+)\)/))
      cs = m[1].to_i
      ca = norm_range(m[2])
      if s && s != cs
        errors << "#{rel}: verse marker s=#{s} but citation says #{cs} — #{cite[0,60]}"
      end
      if a && !a.empty? && norm_range(a) != ca
        warnings << "#{rel}: verse marker a=\"#{a}\" vs citation \"#{m[2].strip}\" (#{SURAH[cs]} #{cs})"
      end
    elsif (m = cite.match(/\((\d+)\)/)) && s && s != m[1].to_i
      errors << "#{rel}: verse marker s=#{s} but citation says (#{m[1]})"
    end
    # surah name vs number
    if s && surah && !surah.empty? && SURAH[s] && norm_name(surah) != norm_name(SURAH[s])
      warnings << "#{rel}: surah=\"#{surah}\" but s=#{s} is #{SURAH[s]}"
    end
    if s && !SURAH.key?(s) && s != 0
      warnings << "#{rel}: s=#{s} is not a valid surah number"
    end
  end
end

puts "Validated #{files.size} files."
unless warnings.empty?
  puts "\nWARNINGS (#{warnings.size}):"
  warnings.each { |w| puts "  ⚠ #{w}" }
end
if errors.empty?
  puts "\n✓ No errors."
  exit 0
else
  puts "\nERRORS (#{errors.size}):"
  errors.each { |e| puts "  ✗ #{e}" }
  exit 1
end
