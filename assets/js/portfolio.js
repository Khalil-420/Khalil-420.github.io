// Smooth scroll for in-page anchor links + scrollspy + mobile nav toggle.
(function () {
  var header = document.querySelector('.site-header');
  var nav = document.querySelector('.site-nav');
  var toggle = document.querySelector('.nav-toggle');

  // Mobile nav toggle
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    nav.addEventListener('click', function (e) {
      if (e.target.tagName === 'A') {
        nav.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  // Smooth scroll for same-page anchors, accounting for sticky header height
  document.querySelectorAll('a[href*="#"]').forEach(function (link) {
    link.addEventListener('click', function (e) {
      var href = link.getAttribute('href');
      var hashIndex = href.indexOf('#');
      if (hashIndex === -1) return;
      var id = href.slice(hashIndex + 1);
      if (!id) return;
      var target = document.getElementById(id);
      if (!target) return; // let the browser navigate to the other page
      e.preventDefault();
      var offset = (header ? header.offsetHeight : 0) + 12;
      var top = target.getBoundingClientRect().top + window.pageYOffset - offset;
      window.scrollTo({ top: top, behavior: 'smooth' });
      history.replaceState(null, '', '#' + id);
    });
  });

  // Scrollspy: highlight the nav link for the section in view
  var sections = Array.prototype.map.call(
    document.querySelectorAll('.site-nav a[href*="#"]'),
    function (a) {
      var id = a.getAttribute('href').split('#')[1];
      var el = id ? document.getElementById(id) : null;
      return el ? { link: a, el: el } : null;
    }
  ).filter(Boolean);

  if (sections.length && 'IntersectionObserver' in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        var match = sections.find(function (s) { return s.el === entry.target; });
        if (!match) return;
        if (entry.isIntersecting) {
          sections.forEach(function (s) { s.link.classList.remove('active'); });
          match.link.classList.add('active');
        }
      });
    }, { rootMargin: '-45% 0px -50% 0px', threshold: 0 });
    sections.forEach(function (s) { observer.observe(s.el); });
  }
})();
