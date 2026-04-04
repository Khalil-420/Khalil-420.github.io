#!/bin/bash
set -e
echo "🛡️  Setting up security blog files..."

# ─── _layouts/default.html ───────────────────────────────────────────────────
cat > _layouts/default.html << 'LAYOUT_DEFAULT'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{% if page.title %}{{ page.title }} — {{ site.title }}{% else %}{{ site.title }}{% endif %}</title>
  <meta name="description" content="{{ page.description | default: site.description }}">
  <link rel="stylesheet" href="{{ '/assets/css/main.css' | relative_url }}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
</head>
<body>
  {% include header.html %}
  <main class="container" style="padding: 2rem 1.5rem;">
    {{ content }}
  </main>
  {% include footer.html %}
</body>
</html>
LAYOUT_DEFAULT

# ─── _layouts/post.html ──────────────────────────────────────────────────────
cat > _layouts/post.html << 'LAYOUT_POST'
---
layout: default
---
<article>
  <header class="post-header">
    <h1>{{ page.title }}</h1>
    <div class="meta">
      {{ page.date | date: "%B %d, %Y" }}
      &nbsp;·&nbsp; {{ page.category }}
      {% if page.difficulty %}&nbsp;·&nbsp; difficulty: {{ page.difficulty }}{% endif %}
    </div>
  </header>
  <div class="post-content">
    {{ content }}
  </div>
</article>
LAYOUT_POST

# ─── _layouts/page.html ──────────────────────────────────────────────────────
cat > _layouts/page.html << 'LAYOUT_PAGE'
---
layout: default
---
<article>
  <header class="post-header">
    <h1>{{ page.title }}</h1>
  </header>
  <div class="post-content">
    {{ content }}
  </div>
</article>
LAYOUT_PAGE

# ─── _includes/header.html ───────────────────────────────────────────────────
cat > _includes/header.html << 'INCLUDE_HEADER'
<header class="site-header">
  <div class="container header-inner">
    <a href="{{ '/' | relative_url }}" class="site-title">
      <span>~/</span>{{ site.author | downcase | replace: ' ', '-' }}
    </a>
    <nav>
      <a href="{{ '/' | relative_url }}" {% if page.url == '/' %}class="active"{% endif %}>Home</a>
      <a href="{{ '/about' | relative_url }}" {% if page.url contains '/about' %}class="active"{% endif %}>About</a>
    </nav>
  </div>
</header>
INCLUDE_HEADER

# ─── _includes/footer.html ───────────────────────────────────────────────────
cat > _includes/footer.html << 'INCLUDE_FOOTER'
<footer class="site-footer">
  <div class="container footer-inner">
    <span>© {{ 'now' | date: "%Y" }} {{ site.author }} — built with Jekyll & ☕</span>
    <div class="footer-links">
      <a href="https://github.com/yourusername" target="_blank">GitHub</a>
    </div>
  </div>
</footer>
INCLUDE_FOOTER

# ─── index.html ──────────────────────────────────────────────────────────────
cat > index.html << 'INDEX'
---
layout: default
title: Home
---
<section class="hero">
  <h1>Hi, I'm <span class="accent">{{ site.author }}</span></h1>
  <p>{{ site.description }}</p>
  <div class="tag-row">
    <span class="tag ctf">#ctf</span>
    <span class="tag vuln">#vuln-research</span>
    <span class="tag tool">#tools</span>
    <span class="tag">#notes</span>
  </div>
</section>

<p class="section-title">// Recent Posts</p>
<ul class="post-list">
  {% for post in site.posts limit:10 %}
  <li class="post-item">
    <div>
      <a class="post-title-link" href="{{ post.url | relative_url }}">{{ post.title }}</a>
      <span class="category-badge {{ post.category }}">{{ post.category }}</span>
      <div class="post-meta">{{ post.description }}</div>
    </div>
    <span class="post-date">{{ post.date | date: "%Y-%m-%d" }}</span>
  </li>
  {% endfor %}
</ul>
INDEX

# ─── about.md ────────────────────────────────────────────────────────────────
cat > about.md << 'ABOUT'
---
layout: page
title: About
---

## whoami

Security researcher, CTF player, and lifelong learner.

This blog is where I document everything I learn — writeups, research, tools, and raw notes.

## What you'll find here

- **CTF Writeups** — step-by-step solutions with methodology explained
- **Vulnerability Research** — CVE analysis, PoCs, and deep dives
- **Tools & Scripts** — utilities I build along the way
- **Notes** — learning logs and references

## Contact

Find me on GitHub or reach out via the links in the footer.
ABOUT

# ─── _posts/2026-04-04-hello-world.md ────────────────────────────────────────
cat > _posts/2026-04-04-hello-world.md << 'POST'
---
layout: post
title: "Hello World — The Blog is Live"
date: 2026-04-04
category: notes
description: "First post. This is where it all begins."
---

## The blog is live

This is the first post on my security research blog.

Here I'll document everything I learn:

- CTF writeups with full methodology
- Vulnerability research and analysis
- Tools and scripts I build
- Raw notes and references

```bash
# The mindset
while true; do learn; break_things; document; done
```

Stay tuned.
POST

# ─── assets/css/main.css ─────────────────────────────────────────────────────
cat > assets/css/main.css << 'CSS'
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg: #0f1117;
  --surface: #1a1d27;
  --border: #2a2d3a;
  --accent: #00d4aa;
  --accent2: #7c6af7;
  --text: #e2e8f0;
  --muted: #8892a4;
  --danger: #ff6b6b;
  --code-bg: #141820;
  --font: 'Inter', system-ui, sans-serif;
  --mono: 'JetBrains Mono', 'Fira Code', monospace;
}

body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--font);
  font-size: 16px;
  line-height: 1.7;
  min-height: 100vh;
}

a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }

.container { max-width: 780px; margin: 0 auto; padding: 0 1.5rem; }

.site-header {
  border-bottom: 1px solid var(--border);
  padding: 1.2rem 0;
  position: sticky; top: 0;
  background: rgba(15,17,23,0.95);
  backdrop-filter: blur(8px);
  z-index: 100;
}
.header-inner { display: flex; justify-content: space-between; align-items: center; }
.site-title { font-family: var(--mono); font-size: 1.1rem; font-weight: 700; color: var(--accent); }
.site-title span { color: var(--muted); }
nav a { color: var(--muted); font-size: 0.9rem; margin-left: 1.5rem; transition: color 0.2s; }
nav a:hover, nav a.active { color: var(--text); text-decoration: none; }

.hero { padding: 4rem 0 3rem; border-bottom: 1px solid var(--border); }
.hero h1 { font-size: 2rem; font-weight: 700; margin-bottom: 0.5rem; }
.hero h1 .accent { color: var(--accent); }
.hero p { color: var(--muted); font-size: 1.05rem; max-width: 520px; }
.tag-row { margin-top: 1rem; display: flex; flex-wrap: wrap; gap: 0.5rem; }
.tag { font-family: var(--mono); font-size: 0.75rem; padding: 0.2rem 0.7rem; border-radius: 4px; border: 1px solid var(--border); color: var(--muted); }
.tag.ctf { border-color: #7c6af755; color: var(--accent2); }
.tag.vuln { border-color: #ff6b6b55; color: var(--danger); }
.tag.tool { border-color: #00d4aa55; color: var(--accent); }

.section-title { font-family: var(--mono); font-size: 0.8rem; color: var(--muted); text-transform: uppercase; letter-spacing: 2px; margin: 2.5rem 0 1.2rem; }
.post-list { list-style: none; }
.post-item { padding: 1.2rem 0; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem; }
.post-item:last-child { border-bottom: none; }
.post-title-link { font-size: 1.05rem; font-weight: 600; color: var(--text); }
.post-title-link:hover { color: var(--accent); text-decoration: none; }
.post-meta { font-size: 0.8rem; color: var(--muted); margin-top: 0.25rem; }
.post-date { font-family: var(--mono); font-size: 0.8rem; color: var(--muted); white-space: nowrap; }
.category-badge { font-family: var(--mono); font-size: 0.7rem; padding: 0.15rem 0.5rem; border-radius: 3px; border: 1px solid; margin-left: 0.5rem; }
.category-badge.ctf { color: var(--accent2); border-color: var(--accent2); }
.category-badge.vuln { color: var(--danger); border-color: var(--danger); }
.category-badge.tools { color: var(--accent); border-color: var(--accent); }
.category-badge.notes { color: var(--muted); border-color: var(--border); }

.post-header { padding: 3rem 0 2rem; border-bottom: 1px solid var(--border); margin-bottom: 2rem; }
.post-header h1 { font-size: 1.8rem; line-height: 1.3; }
.post-header .meta { color: var(--muted); font-size: 0.9rem; margin-top: 0.75rem; font-family: var(--mono); }
.post-content h2 { font-size: 1.3rem; margin: 2rem 0 0.75rem; }
.post-content h3 { font-size: 1.1rem; margin: 1.5rem 0 0.5rem; color: var(--accent); }
.post-content p { margin-bottom: 1.2rem; }
.post-content ul, .post-content ol { margin: 0 0 1.2rem 1.5rem; }
.post-content li { margin-bottom: 0.4rem; }
.post-content blockquote { border-left: 3px solid var(--accent); padding: 0.5rem 1rem; margin: 1.5rem 0; background: var(--surface); border-radius: 0 6px 6px 0; color: var(--muted); }

code { font-family: var(--mono); font-size: 0.88em; background: var(--code-bg); padding: 0.15em 0.4em; border-radius: 4px; color: var(--accent); }
pre { background: var(--code-bg); border: 1px solid var(--border); border-radius: 8px; padding: 1.25rem; overflow-x: auto; margin: 1.5rem 0; }
pre code { background: none; padding: 0; color: var(--text); font-size: 0.85rem; }

.site-footer { border-top: 1px solid var(--border); padding: 2rem 0; margin-top: 4rem; color: var(--muted); font-size: 0.85rem; }
.footer-inner { display: flex; justify-content: space-between; align-items: center; }
.footer-links a { color: var(--muted); margin-left: 1rem; }
.footer-links a:hover { color: var(--accent); }

@media (max-width: 600px) {
  .hero h1 { font-size: 1.5rem; }
  nav a { margin-left: 1rem; }
  .post-item { flex-direction: column; gap: 0.25rem; }
  .footer-inner { flex-direction: column; gap: 1rem; text-align: center; }
}
CSS

echo ""
echo "✅ All files created successfully!"
echo ""
echo "Now run:  bundle exec jekyll serve"
echo "Then open: http://127.0.0.1:4000"
