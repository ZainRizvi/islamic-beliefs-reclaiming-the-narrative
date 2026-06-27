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
    1=>'al-Fātiḥah',2=>'al-Baqarah',3=>'Āl ʿImrān',4=>'al-Nisāʾ',5=>'al-Māʾidah',
    6=>'al-Anʿām',7=>'al-Aʿrāf',8=>'al-Anfāl',9=>'al-Tawbah',10=>'Yūnus',
    11=>'Hūd',12=>'Yūsuf',13=>'al-Raʿd',14=>'Ibrāhīm',15=>'al-Ḥijr',
    16=>'al-Naḥl',17=>'al-Isrāʾ',18=>'al-Kahf',19=>'Maryam',20=>'Ṭāhā',
    21=>'al-Anbiyāʾ',22=>'al-Ḥajj',23=>'al-Muʾminūn',24=>'al-Nūr',25=>'al-Furqān',
    26=>'al-Shuʿarāʾ',27=>'al-Naml',28=>'al-Qaṣaṣ',29=>'al-ʿAnkabūt',30=>'al-Rūm',
    31=>'Luqmān',32=>'al-Sajdah',33=>'al-Aḥzāb',34=>'Sabaʾ',35=>'Fāṭir',
    36=>'Yāsīn',37=>'al-Ṣāffāt',38=>'Ṣād',39=>'al-Zumar',40=>'Ghāfir',
    41=>'Fuṣṣilat',42=>'al-Shūrā',43=>'al-Zukhruf',44=>'al-Dukhān',45=>'al-Jāthiyah',
    46=>'al-Aḥqāf',47=>'Muḥammad',48=>'al-Fatḥ',49=>'al-Ḥujurāt',50=>'Qāf',
    51=>'al-Dhāriyāt',52=>'al-Ṭūr',53=>'al-Najm',54=>'al-Qamar',55=>'al-Raḥmān',
    56=>'al-Wāqiʿah',57=>'al-Ḥadīd',58=>'al-Mujādilah',59=>'al-Ḥashr',60=>'al-Mumtaḥanah',
    61=>'al-Ṣaff',62=>'al-Jumuʿah',63=>'al-Munāfiqūn',64=>'al-Taghābun',65=>'al-Ṭalāq',
    66=>'al-Taḥrīm',67=>'al-Mulk',68=>'al-Qalam',69=>'al-Ḥāqqah',70=>'al-Maʿārij',
    71=>'Nūḥ',72=>'al-Jinn',73=>'al-Muzzammil',74=>'al-Muddaththir',75=>'al-Qiyāmah',
    76=>'al-Insān',77=>'al-Mursalāt',78=>'al-Nabaʾ',79=>'al-Nāziʿāt',80=>'ʿAbasa',
    81=>'al-Takwīr',82=>'al-Infiṭār',83=>'al-Muṭaffifīn',84=>'al-Inshiqāq',85=>'al-Burūj',
    86=>'al-Ṭāriq',87=>'al-Aʿlā',88=>'al-Ghāshiyah',89=>'al-Fajr',90=>'al-Balad',
    91=>'al-Shams',92=>'al-Layl',93=>'al-Ḍuḥā',94=>'al-Sharḥ',95=>'al-Tīn',
    96=>'al-ʿAlaq',97=>'al-Qadr',98=>'al-Bayyinah',99=>'al-Zalzalah',100=>'al-ʿĀdiyāt',
    101=>'al-Qāriʿah',102=>'al-Takāthur',103=>'al-ʿAṣr',104=>'al-Humazah',105=>'al-Fīl',
    106=>'Quraysh',107=>'al-Māʿūn',108=>'al-Kawthar',109=>'al-Kāfirūn',110=>'al-Naṣr',
    111=>'al-Masad',112=>'al-Ikhlāṣ',113=>'al-Falaq',114=>'al-Nās',
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
        verses << { s: s, a: a, surah: (SURAH_NAMES[s] || b.attr('surah') || "Sūrah #{s}"), anchor: anchor }
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
