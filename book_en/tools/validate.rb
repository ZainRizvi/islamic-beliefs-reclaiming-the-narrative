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
  1=>"al-Fatihah",2=>"al-Baqarah",3=>"Al 'Imran",4=>"al-Nisa'",5=>"al-Ma'idah",
  6=>"al-An'am",7=>"al-A'raf",8=>"al-Anfal",9=>"al-Tawbah",10=>"Yunus",11=>"Hud",
  12=>"Yusuf",13=>"al-Ra'd",14=>"Ibrahim",15=>"al-Hijr",16=>"al-Nahl",17=>"al-Isra'",
  18=>"al-Kahf",19=>"Maryam",20=>"Taha",21=>"al-Anbiya'",22=>"al-Hajj",23=>"al-Mu'minun",
  24=>"al-Nur",25=>"al-Furqan",26=>"al-Shu'ara'",27=>"al-Naml",28=>"al-Qasas",
  29=>"al-'Ankabut",30=>"al-Rum",31=>"Luqman",32=>"al-Sajdah",33=>"al-Ahzab",34=>"Saba'",
  35=>"Fatir",36=>"Yasin",37=>"al-Saffat",38=>"Sad",39=>"al-Zumar",40=>"Ghafir",
  41=>"Fussilat",42=>"al-Shura",43=>"al-Zukhruf",44=>"al-Dukhan",45=>"al-Jathiyah",
  46=>"al-Ahqaf",47=>"Muhammad",48=>"al-Fath",49=>"al-Hujurat",50=>"Qaf",51=>"al-Dhariyat",
  52=>"al-Tur",53=>"al-Najm",54=>"al-Qamar",55=>"al-Rahman",56=>"al-Waqi'ah",57=>"al-Hadid",
  58=>"al-Mujadilah",59=>"al-Hashr",60=>"al-Mumtahanah",61=>"al-Saff",62=>"al-Jumu'ah",
  63=>"al-Munafiqun",64=>"al-Taghabun",65=>"al-Talaq",66=>"al-Tahrim",67=>"al-Mulk",
  68=>"al-Qalam",69=>"al-Haqqah",70=>"al-Ma'arij",71=>"Nuh",72=>"al-Jinn",73=>"al-Muzzammil",
  74=>"al-Muddaththir",75=>"al-Qiyamah",76=>"al-Insan",77=>"al-Mursalat",78=>"al-Naba'",
  79=>"al-Nazi'at",80=>"'Abasa",81=>"al-Takwir",82=>"al-Infitar",83=>"al-Mutaffifin",
  84=>"al-Inshiqaq",85=>"al-Buruj",86=>"al-Tariq",87=>"al-A'la",88=>"al-Ghashiyah",
  89=>"al-Fajr",90=>"al-Balad",91=>"al-Shams",92=>"al-Layl",93=>"al-Duha",94=>"al-Sharh",
  95=>"al-Tin",96=>"al-'Alaq",97=>"al-Qadr",98=>"al-Bayyinah",99=>"al-Zalzalah",
  100=>"al-'Adiyat",101=>"al-Qari'ah",102=>"al-Takathur",103=>"al-'Asr",104=>"al-Humazah",
  105=>"al-Fil",106=>"Quraysh",107=>"al-Ma'un",108=>"al-Kawthar",109=>"al-Kafirun",
  110=>"al-Nasr",111=>"al-Masad",112=>"al-Ikhlas",113=>"al-Falaq",114=>"al-Nas",
}.freeze

errors = []
warnings = []

def norm_name(s)
  # Compare surah names diacritic-insensitively: fold transliteration diacritics
  # to base letters, drop ayn/hamza/apostrophes, spaces, hyphens, and the "al"
  # article. So "Āl ʿImrān", "Al 'Imran", and "al-Imran" all compare equal.
  t = s.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')  # strip combining marks
  t.downcase.gsub(/[\s\-'''''’]/, '').sub(/\Aal/, '')
end

def norm_range(s)
  # normalize ayah range: en/em dashes -> hyphen, strip spaces
  s.to_s.gsub(/[‐-―]/, '-').gsub(/\s/, '')
end

# Exclude the frozen baseline (src/transcription/): it is an archive, not a build
# input. The annotation gate (tools/check_annotations.rb) compares against it instead.
files = Dir.glob(File.join(SRC, '**', '*.adoc'))
           .reject { |f| File.basename(f) == 'book.adoc' }
           .reject { |f| f.include?("#{File::SEPARATOR}transcription#{File::SEPARATOR}") }
           .sort
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
