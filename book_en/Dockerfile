# Reproducible build environment for the book.
#
# Provides Ruby + the Asciidoctor single-source toolchain (PDF/EPUB/HTML) and the
# fonts needed to typeset Latin text, Arabic Qur'anic verses, and transliteration
# diacritics. Build once, render identically on any machine.

FROM ruby:3.3-slim

# System libraries:
#  - fontconfig + fonts: required for asciidoctor-pdf (Prawn) to embed glyphs.
#      fonts-noto-core / fonts-noto-extra : broad Latin + diacritics coverage
#      fonts-noto-cjk is intentionally omitted (large, unused).
#      fonts-hosny-amiri                  : high-quality Arabic (Amiri) for Qur'anic text
#  - libffi/zlib : native gem deps (nokogiri, ffi)
#  - make/gcc    : building native extensions
#  - git         : tooling may inspect repo state
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        libffi-dev \
        zlib1g-dev \
        fontconfig \
        fonts-noto-core \
        fonts-noto-extra \
        fonts-hosny-amiri \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -f

WORKDIR /book

# Install gems first (better layer caching: only re-runs when Gemfile* changes).
# Copy the lockfile too so the image pins the same versions as CI.
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

# The actual book sources are bind-mounted at run time (see compose.yaml),
# so edits on the host are picked up without rebuilding the image.

# Default: drop into a shell. compose.yaml defines the real build commands.
CMD ["bash"]
