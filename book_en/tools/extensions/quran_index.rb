# Qur'an Verse Index extension for Asciidoctor.
#
# Collects every quote block tagged `[role="verse quran", surah="...", s=N, a="..."]`,
# assigns each a stable anchor, and generates a dedicated "Index of Qur'anic Verses"
# in mushaf order (by surah number, then ayah). Each entry cross-references the verse
# in the body so the PDF prints the page number.
#
# Activation: place a section titled exactly "Index of Qur'anic Verses" (any level)
# in the master document where you want the index; this extension fills it.
# Mark that section with the role `quran-index-placeholder` to be explicit:
#
#   [.quran-index-placeholder]
#   == Index of Qur'anic Verses
#
# Works for both HTML and PDF output (uses standard xref anchors).

require 'asciidoctor'
require 'asciidoctor/extensions'

module QuranIndex
  PLACEHOLDER_ROLE = 'quran-index-placeholder'.freeze

  # Canonical English surah names keyed by number — used so the index reads cleanly
  # and sorts in mushaf order even if the inline `surah=` spelling varies slightly.
  SURAH_NAMES = {
    1=>"al-Fatihah",2=>"al-Baqarah",3=>"Al 'Imran",4=>"al-Nisa'",5=>"al-Ma'idah",
    6=>"al-An'am",7=>"al-A'raf",8=>"al-Anfal",9=>"al-Tawbah",10=>"Yunus",
    11=>"Hud",12=>"Yusuf",13=>"al-Ra'd",14=>"Ibrahim",15=>"al-Hijr",
    16=>"al-Nahl",17=>"al-Isra'",18=>"al-Kahf",19=>"Maryam",20=>"Taha",
    21=>"al-Anbiya'",22=>"al-Hajj",23=>"al-Mu'minun",24=>"al-Nur",25=>"al-Furqan",
    26=>"al-Shu'ara'",27=>"al-Naml",28=>"al-Qasas",29=>"al-'Ankabut",30=>"al-Rum",
    31=>"Luqman",32=>"al-Sajdah",33=>"al-Ahzab",34=>"Saba'",35=>"Fatir",
    36=>"Yasin",37=>"al-Saffat",38=>"Sad",39=>"al-Zumar",40=>"Ghafir",
    41=>"Fussilat",42=>"al-Shura",43=>"al-Zukhruf",44=>"al-Dukhan",45=>"al-Jathiyah",
    46=>"al-Ahqaf",47=>"Muhammad",48=>"al-Fath",49=>"al-Hujurat",50=>"Qaf",
    51=>"al-Dhariyat",52=>"al-Tur",53=>"al-Najm",54=>"al-Qamar",55=>"al-Rahman",
    56=>"al-Waqi'ah",57=>"al-Hadid",58=>"al-Mujadilah",59=>"al-Hashr",60=>"al-Mumtahanah",
    61=>"al-Saff",62=>"al-Jumu'ah",63=>"al-Munafiqun",64=>"al-Taghabun",65=>"al-Talaq",
    66=>"al-Tahrim",67=>"al-Mulk",68=>"al-Qalam",69=>"al-Haqqah",70=>"al-Ma'arij",
    71=>"Nuh",72=>"al-Jinn",73=>"al-Muzzammil",74=>"al-Muddaththir",75=>"al-Qiyamah",
    76=>"al-Insan",77=>"al-Mursalat",78=>"al-Naba'",79=>"al-Nazi'at",80=>"'Abasa",
    81=>"al-Takwir",82=>"al-Infitar",83=>"al-Mutaffifin",84=>"al-Inshiqaq",85=>"al-Buruj",
    86=>"al-Tariq",87=>"al-A'la",88=>"al-Ghashiyah",89=>"al-Fajr",90=>"al-Balad",
    91=>"al-Shams",92=>"al-Layl",93=>"al-Duha",94=>"al-Sharh",95=>"al-Tin",
    96=>"al-'Alaq",97=>"al-Qadr",98=>"al-Bayyinah",99=>"al-Zalzalah",100=>"al-'Adiyat",
    101=>"al-Qari'ah",102=>"al-Takathur",103=>"al-'Asr",104=>"al-Humazah",105=>"al-Fil",
    106=>"Quraysh",107=>"al-Ma'un",108=>"al-Kawthar",109=>"al-Kafirun",110=>"al-Nasr",
    111=>"al-Masad",112=>"al-Ikhlas",113=>"al-Falaq",114=>"al-Nas",
  }.freeze

  # Sort key for an ayah string like "133-134" or "27" -> integer of first ayah.
  def self.ayah_key(a)
    return 0 if a.nil? || a.empty?
    (a[/\d+/] || '0').to_i
  end

  class Collector < Asciidoctor::Extensions::TreeProcessor
    def process(document)
      verses = []            # [{s:, a:, surah:, node:, anchor:}]
      counter = 0
      placeholder = nil

      document.find_by(context: :section).each do |sec|
        if (sec.role? && sec.roles.include?(PLACEHOLDER_ROLE)) ||
           (sec.title && sec.title =~ /Index of Qur.?.?an.* Verses/i)
          placeholder = sec
        end
      end

      document.find_by(context: :quote).each do |b|
        next unless b.role? && b.roles.include?('quran')
        s = b.attr('s').to_i
        a = (b.attr('a') || '').to_s.strip
        next if s <= 0     # unresolved fragment (s=0): not indexable, skip silently
        counter += 1
        anchor = "quranref-#{counter}"
        # Give the block an id so the index can xref to it (PDF prints the page).
        b.id ||= anchor
        anchor = b.id
        verses << { s: s, a: a, surah: (SURAH_NAMES[s] || b.attr('surah') || "Surah #{s}"), anchor: anchor }
      end

      return document unless placeholder

      # Group by surah, then list ayahs (deduped, sorted), each linking to its block.
      by_surah = verses.group_by { |v| v[:s] }
      lines = []
      by_surah.keys.sort.each do |s|
        name = SURAH_NAMES[s] || by_surah[s].first[:surah]
        lines << "*#{name}* (#{s})::"
        # one term line per distinct ayah, with links to every occurrence
        by_ayah = by_surah[s].group_by { |v| v[:a] }
        by_ayah.keys.sort_by { |a| QuranIndex.ayah_key(a) }.each do |a|
          refs = by_ayah[a].map { |v| "xref:#{v[:anchor]}[#{s}:#{a}]" }.join(', ')
          label = a.empty? ? "#{s}" : "#{s}:#{a}"
          lines << "  #{label}::: #{refs}"
        end
      end

      content = lines.join("\n")
      block = Asciidoctor::Block.new(placeholder, :open, source: content)
      parsed = Asciidoctor.load(content, safe: document.safe, doctype: 'article')
      # Reparse the description-list content into real blocks under the placeholder.
      dlist_blocks = parsed.blocks
      dlist_blocks.each { |blk| blk.parent = placeholder; placeholder.blocks << blk }

      document
    end
  end
end

Asciidoctor::Extensions.register do
  tree_processor QuranIndex::Collector
end
