/* Infinite-scroll book reader.
 *
 * Each chapter lives at its own URL (p/<slug>.html) and is independently
 * loadable. This script turns the reading column into a continuous scroll:
 * when the reader nears the end of the loaded content, it fetches the next
 * chapter's fragment (p/<slug>.frag.html), appends it, and as chapters scroll
 * into view it updates the address bar (history.replaceState) to that chapter's
 * canonical URL — without reloading the page.
 *
 * Progressive enhancement: with JS off, each p/<slug>.html is a normal page
 * with prev/next links. The landing index.html starts at the first chapter.
 */
(function () {
  'use strict';
  var content = document.getElementById('content');
  if (!content || !content.classList.contains('reader')) return;

  // base path to the per-chapter files (manifest + fragments). On the landing
  // page data-base="p/"; on a standalone p/<slug>.html page data-base="".
  var BASE = content.getAttribute('data-base') || '';
  var MANIFEST_URL = BASE + 'manifest.json';
  // Site root: the directory that contains index.html. On the landing page the
  // current path IS the root dir; on a standalone p/<slug>.html page the root is
  // one level up. Compute it once so canonical URLs are absolute and idempotent
  // (no compounding "/p/p/..." as the address bar updates during scrolling).
  var ROOT = (function () {
    var path = location.pathname;
    var dir = path.replace(/[^/]*$/, '');        // strip filename -> current dir
    return BASE === 'p/' ? dir : dir.replace(/p\/$/, '');
  })();
  // canonical URL for a chapter, absolute from origin: ROOT + p/<slug>.html
  function canonicalUrl(slug) { return ROOT + 'p/' + slug + '.html'; }

  var manifest = null;        // [{slug,title,url,part,index}]
  var bySlug = {};
  var loading = false;
  var loadedMax = -1;         // highest chapter index currently in the DOM
  var loadedMin = Infinity;

  function indexOfSlug(slug) { return bySlug[slug] ? bySlug[slug].index : -1; }

  // Register a chapter <article> already in the DOM.
  function noteLoaded(article) {
    var i = parseInt(article.getAttribute('data-index'), 10);
    if (!isNaN(i)) { loadedMax = Math.max(loadedMax, i); loadedMin = Math.min(loadedMin, i); }
  }
  Array.prototype.forEach.call(content.querySelectorAll('article.chapter'), noteLoaded);

  // Fetch + append the chapter at index i (if not already present).
  function appendChapter(i) {
    if (!manifest || i < 0 || i >= manifest.length) return Promise.resolve(false);
    if (content.querySelector('article.chapter[data-index="' + i + '"]')) return Promise.resolve(false);
    if (loading) return Promise.resolve(false);
    loading = true;
    var slug = manifest[i].slug;
    return fetch(BASE + slug + '.frag.html')
      .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
      .then(function (frag) {
        var tmp = document.createElement('div');
        tmp.innerHTML = frag;
        var art = tmp.querySelector('article.chapter') || tmp.firstElementChild;
        if (art) {
          content.appendChild(art);
          noteLoaded(art);
          observeChapter(art);
        }
        loading = false;
        return true;
      })
      .catch(function () { loading = false; return false; });
  }

  // Sentinel-based lazy loading: when the last loaded chapter's tail nears the
  // viewport, append the next one.
  var tailObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) appendChapter(loadedMax + 1).then(function (added) {
        if (added) refreshTailSentinel();
      });
    });
  }, { rootMargin: '800px 0px' });

  function refreshTailSentinel() {
    tailObserver.disconnect();
    var arts = content.querySelectorAll('article.chapter');
    if (arts.length) tailObserver.observe(arts[arts.length - 1]);
  }

  // Update the address bar as chapters scroll through the viewport.
  var titleObserver = new IntersectionObserver(function (entries) {
    // pick the top-most chapter currently intersecting
    var visible = entries.filter(function (e) { return e.isIntersecting; })
                         .map(function (e) { return e.target; });
    if (!visible.length) return;
    visible.sort(function (a, b) { return a.getBoundingClientRect().top - b.getBoundingClientRect().top; });
    var slug = visible[0].getAttribute('data-slug');
    if (!slug) return;
    var url = canonicalUrl(slug);
    if (location.pathname.split('/').pop() !== url.split('/').pop() ||
        BASE === 'p/') {                       // landing page: always reflect chapter
      try {
        history.replaceState({ slug: slug }, '', url);
        var m = bySlug[slug];
        if (m) document.title = m.title + ' · Islamic Beliefs';
        highlightToc(slug);
      } catch (e) { /* cross-origin / file:// — ignore */ }
    }
  }, { rootMargin: '-45% 0px -45% 0px' });      // fire when chapter crosses mid-viewport

  function observeChapter(art) { titleObserver.observe(art); }
  Array.prototype.forEach.call(content.querySelectorAll('article.chapter'), observeChapter);

  // Reflect current chapter in the left TOC.
  function highlightToc(slug) {
    var toc = document.getElementById('toc');
    if (!toc) return;
    Array.prototype.forEach.call(toc.querySelectorAll('a.current'),
      function (a) { a.classList.remove('current'); });
    var link = toc.querySelector('a[href$="#' + slug + '"], a[href$="/' + slug + '.html"], a[href="#' + slug + '"]');
    if (link) link.classList.add('current');
  }

  // Make TOC links work within the reader: clicking jumps to a loaded chapter or
  // navigates to its page (which the reader then continues from).
  function wireToc() {
    var toc = document.getElementById('toc');
    if (!toc) return;
    toc.addEventListener('click', function (ev) {
      var a = ev.target.closest('a');
      if (!a) return;
      var href = a.getAttribute('href') || '';
      var m = href.match(/#([a-z0-9-]+)$/i);
      if (!m) return;                          // external/other link: default
      var slug = m[1];
      var existing = content.querySelector('article.chapter[data-slug="' + slug + '"]');
      if (existing) {                          // already loaded: smooth-scroll
        ev.preventDefault();
        existing.scrollIntoView({ behavior: 'smooth' });
        history.replaceState({ slug: slug }, '', canonicalUrl(slug));
      } else if (bySlug[slug]) {               // jump to that chapter's page
        ev.preventDefault();
        location.href = canonicalUrl(slug);
      }
    });
  }

  fetch(MANIFEST_URL)
    .then(function (r) { return r.json(); })
    .then(function (m) {
      manifest = m;
      m.forEach(function (c) { bySlug[c.slug] = c; });
      refreshTailSentinel();
      wireToc();
      // set initial URL/title to the start chapter
      var start = content.getAttribute('data-start');
      if (start && bySlug[start]) { document.title = bySlug[start].title + ' · Islamic Beliefs'; highlightToc(start); }
    })
    .catch(function () { /* no manifest: pages still work standalone */ });
})();
