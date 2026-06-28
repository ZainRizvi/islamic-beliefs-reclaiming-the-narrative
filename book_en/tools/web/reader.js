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

  // Resolve all paths as ABSOLUTE (from-origin) URLs so fetches never compound
  // (the old relative scheme produced /p/p/... 404s on standalone chapter pages).
  // data-base is "p/" on the landing page (pages live one level down) or "" on a
  // standalone p/<slug>.html page (pages are siblings in the current dir).
  var BASE = content.getAttribute('data-base') || '';
  var curDir = location.pathname.replace(/[^/]*$/, '');     // dir of the current page
  // PDIR = absolute dir holding the p/* files. Landing page (data-base="p/") sits
  // one level above p/; a standalone p/<slug>.html page is already inside p/.
  // Derived from BASE (a build invariant), not string-stripping, so no fragile regex.
  var PDIR = (BASE === 'p/') ? curDir + 'p/' : curDir;
  var MANIFEST_URL = PDIR + 'manifest.json';
  function fragUrl(slug) { return PDIR + slug + '.frag.html'; }
  // canonical URL for a chapter, absolute from origin.
  function canonicalUrl(slug) { return PDIR + slug + '.html'; }

  var manifest = null;        // [{slug,title,url,part,index}]
  var bySlug = {};
  var anchorToSlug = {};      // sub-section / part-divider id -> owning chapter slug
  var loading = false;
  var loadedMax = -1;         // highest chapter index currently in the DOM
  var loadedMin = Infinity;

  function indexOfSlug(slug) { return bySlug[slug] ? bySlug[slug].index : -1; }

  // Register a chapter <article> already in the DOM (and its inner anchors).
  function noteLoaded(article) {
    var i = parseInt(article.getAttribute('data-index'), 10);
    if (!isNaN(i)) { loadedMax = Math.max(loadedMax, i); loadedMin = Math.min(loadedMin, i); }
    var slug = article.getAttribute('data-slug');
    (article.getAttribute('data-anchors') || '').split(/\s+/).forEach(function (a) {
      if (a) anchorToSlug[a] = slug;
    });
  }
  Array.prototype.forEach.call(content.querySelectorAll('article.chapter'), noteLoaded);

  // Fetch + append the chapter at index i (if not already present).
  function appendChapter(i) {
    if (!manifest || i < 0 || i >= manifest.length) return Promise.resolve(false);
    if (content.querySelector('article.chapter[data-index="' + i + '"]')) return Promise.resolve(false);
    if (loading) return Promise.resolve(false);
    loading = true;
    var slug = manifest[i].slug;
    return fetch(fragUrl(slug))
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

  // Lazy loading via a SMALL sentinel kept at the end of the content. Observing
  // the chapter article itself doesn't work: a chapter can be many viewports tall,
  // so it's already "intersecting" when observed and an IntersectionObserver only
  // fires on intersection-state CHANGES — it would never re-fire as you scroll
  // within one chapter. A tiny trailing sentinel re-enters the margin each time,
  // firing reliably. After each load we keep the sentinel last and re-check whether
  // it's still in range (covers fast scrolls / several short chapters).
  var TAIL_MARGIN = 1000;
  var sentinel = document.createElement('div');
  sentinel.id = 'reader-sentinel';
  sentinel.setAttribute('aria-hidden', 'true');
  sentinel.style.height = '1px';
  content.appendChild(sentinel);

  function sentinelInRange() {
    var vh = window.innerHeight || document.documentElement.clientHeight;
    return sentinel.getBoundingClientRect().top <= vh + TAIL_MARGIN;
  }
  function maybeLoadMore() {
    if (loading) return;                       // a fetch is in flight; its .then re-checks
    appendChapter(loadedMax + 1).then(function (added) {
      content.appendChild(sentinel);           // keep the sentinel last
      if (added && sentinelInRange()) maybeLoadMore();  // still need more
    });
  }
  var tailObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) { if (e.isIntersecting) maybeLoadMore(); });
  }, { rootMargin: TAIL_MARGIN + 'px 0px' });

  function refreshTailSentinel() {
    tailObserver.disconnect();
    tailObserver.observe(sentinel);
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

  // Make TOC links work within the reader. A TOC anchor may be a chapter slug,
  // a sub-section id, or a part-divider id. Resolve it to the OWNING chapter:
  //  - the target id itself if it's a chapter, else the chapter that contains it.
  // If that chapter is loaded, scroll to the exact element; otherwise navigate to
  // the chapter's page with the anchor (the browser jumps there, reader continues).
  function ownerChapter(anchorId) {
    if (bySlug[anchorId]) return anchorId;            // it's a chapter slug
    if (anchorToSlug[anchorId]) return anchorToSlug[anchorId];  // known sub-anchor
    return null;                                      // unknown until that chapter loads
  }
  function wireToc() {
    var toc = document.getElementById('toc');
    if (!toc) return;
    toc.addEventListener('click', function (ev) {
      var a = ev.target.closest('a');
      if (!a) return;
      var href = a.getAttribute('href') || '';
      var m = href.match(/#([A-Za-z0-9_-]+)$/);
      if (!m) return;                                 // external/other link: default
      var anchorId = m[1];
      var slug = ownerChapter(anchorId);
      if (!slug) {
        // Anchor lives in a chapter we haven't loaded and can't map yet. Find the
        // chapter by asking the manifest order isn't enough — fall back to opening
        // the anchor's own chapter page if the anchor IS a chapter, else let the
        // browser try (works once that chapter is loaded). Best effort: do nothing
        // special so the default in-page jump applies if present.
        return;
      }
      var existing = content.querySelector('article.chapter[data-slug="' + slug + '"]');
      var target = document.getElementById(anchorId) || existing;
      if (existing && target) {                       // loaded: smooth-scroll to exact spot
        ev.preventDefault();
        target.scrollIntoView({ behavior: 'smooth' });
        history.replaceState({ slug: slug }, '', canonicalUrl(slug) +
          (anchorId !== slug ? '#' + anchorId : ''));
      } else if (bySlug[slug]) {                       // not loaded: go to chapter page (+anchor)
        ev.preventDefault();
        location.href = canonicalUrl(slug) + (anchorId !== slug ? '#' + anchorId : '');
      }
    });
  }

  // ---- TOC drawer: hamburger toggle + slide-in panel + overlay --------------
  function initDrawer() {
    var toc = document.getElementById('toc');
    if (!toc) return;
    // toggle button
    var btn = document.createElement('button');
    btn.id = 'toc-toggle';
    btn.type = 'button';
    btn.setAttribute('aria-label', 'Open table of contents');
    btn.setAttribute('aria-expanded', 'false');
    btn.innerHTML = '&#9776;';                 // ☰
    document.body.appendChild(btn);
    // overlay
    var overlay = document.createElement('div');
    overlay.id = 'toc-overlay';
    document.body.appendChild(overlay);
    // close (×) inside the drawer
    var close = document.createElement('button');
    close.id = 'toc-close';
    close.type = 'button';
    close.setAttribute('aria-label', 'Close table of contents');
    close.innerHTML = '&times;';
    toc.insertBefore(close, toc.firstChild);

    // a11y wiring: name the drawer and link the toggle to it. Closed-state focus
    // is removed via CSS visibility:hidden (see docinfo) so off-screen links/buttons
    // aren't tab-reachable or announced.
    toc.setAttribute('role', 'navigation');
    toc.setAttribute('aria-label', 'Table of contents');
    btn.setAttribute('aria-controls', 'toc');

    function isOpen() { return document.body.classList.contains('toc-open'); }
    function open() {
      document.body.classList.add('toc-open');
      btn.setAttribute('aria-expanded', 'true');
      close.focus();                       // move focus into the drawer
    }
    function shut() {
      if (!isOpen()) return;               // guard: don't steal focus on stray Escape
      document.body.classList.remove('toc-open');
      btn.setAttribute('aria-expanded', 'false');
      btn.focus();                         // restore focus to the toggle
    }
    function toggle() { isOpen() ? shut() : open(); }
    btn.addEventListener('click', toggle);
    close.addEventListener('click', shut);
    overlay.addEventListener('click', shut);
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') shut(); });
    // close the drawer after picking a chapter (so you land on the content)
    toc.addEventListener('click', function (e) { if (e.target.closest('a')) shut(); });
  }
  initDrawer();

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
