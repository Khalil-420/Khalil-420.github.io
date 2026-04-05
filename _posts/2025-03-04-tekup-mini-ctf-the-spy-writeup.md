---
layout: post
title: "TEKUP Mini CTF — The Spy Series Writeup (0→3)"
date: 2025-03-04
category: ctf
difficulty: easy
platform: TEKUP Mini CTF
tags: [forensics, base64, luks, docker, steganography, ctf]
description: "A 4-part forensics series: hidden base64 in PowerPoint, HTTP log analysis, LUKS disk decryption, and a suspicious Docker image."
---

## Overview

I made a series of forensics challenges for the TEKUP Mini CTF. This writeup covers all 4 parts: **THE SPY 0** through **THE SPY 3**.

---

## THE SPY 0

![The Spy 0 challenge](/assets/images/spy_1.webp)

After downloading the attachments, we find two files: a `.ppt` file and a password-protected zip.

Opening the PowerPoint, a hidden base64 string is visible in the slide:

![Hidden base64 in PowerPoint](/assets/images/spy_2.webp)

Throwing it into CyberChef and decoding reveals... a zip file! Inside it:
- `flag.png` → **THE SPY 0 flag** ✅
- `spylogs.txt` → useful for the next parts

![Decoded zip contents](/assets/images/spy_3.webp)

THE SPY 0 solved 😄 — now let's find this spy!

---

## THE SPY 1

![The Spy 1 challenge](/assets/images/spy_4.webp)

We now have `spylogs.txt` from the previous step. Taking a look at the log file:

![spylogs.txt contents](/assets/images/spy_5.webp)

HTTP requests with a `secret` query parameter containing base64-encoded values. Decoding them one by one:

| Base64 | Decoded |
|---|---|
| `RnJlZSBQYWxlc3RpbmU=` | Free Palestine 🇵🇸 |
| `S2VlcCBHb2luZw==` | Keep Going 🙂 |
| `WW91IGFsbW9zdCB0aGVyZQ==` | You almost there |
| `U2VjdXJpbmV0c3tIRV9BTFc0WVNfSk9LRV80Uk9VTkQhfQ==` | `Securinets{HE_ALW4YS_JOKE_4ROUND!}` |

Flag: `Securinets{HE_ALW4YS_JOKE_4ROUND!}` ✅

*He always jokes around* — narrowing down the suspect list! 🙂

---

## THE SPY 2

![The Spy 2 challenge](/assets/images/spy_6.webp)

We now have the zip password from the previous flag. Extracting it reveals `the_spy.img`:

![Zip contents](/assets/images/spy_7.webp)

The `.img` file is a **LUKS encrypted disk**:

> LUKS is the standard for Linux disk encryption. It stores all setup information in the partition header, allowing seamless data migration. `cryptsetup` is the tool used to manage LUKS volumes.

Trying to open it with `cryptsetup`:

```bash
sudo cryptsetup luksOpen the_spy.img trah
```

![cryptsetup asking for passphrase](/assets/images/spy_8.webp)

It asks for a passphrase. Time to bruteforce it:

```bash
sudo cryptsetup-john the_spy.img
# or use hashcat / john with a wordlist
```

![Bruteforce result](/assets/images/spy_9.webp)

Password: `abc123` — really!! 🤦

After unlocking, the device is mapped to `/dev/mapper/trah`. Mounting it:

```bash
sudo mount /dev/mapper/trah /mnt
ls /mnt
```

![Mounted device contents](/assets/images/spy_10.webp)

Inside we find a `Dockerfile`:

![Dockerfile contents](/assets/images/spy_11.webp)

Next hint found: **`HE LIVES IN BARDO!`** — I think I know who it is, but let's be sure 😉

---

## THE SPY 3

![The Spy 3 challenge](/assets/images/spy_12.webp)

Looking at the Dockerfile more carefully, one line stands out:

```dockerfile
FROM verysus:1.3
```

That looks **sus** 🤔. Pulling and running the image:

```bash
docker pull verysus:1.3
docker run verysus:1.3
```

![Docker image output](/assets/images/spy_13.webp)

The output contains a base64 string. Decoding it:

![Decoded output — spy revealed](/assets/images/spy_14.webp)

**The spy is found!** 👾

---

## Summary

| Challenge | Technique |
|---|---|
| THE SPY 0 | Hidden base64 in PowerPoint → zip → flag |
| THE SPY 1 | HTTP log analysis → base64 decode |
| THE SPY 2 | LUKS disk bruteforce → mount → Dockerfile |
| THE SPY 3 | Suspicious Docker image → base64 decode |

> **Lessons learned:** Steganography doesn't have to be complex — hidden text in plain sight is often overlooked. Always check open file descriptors, metadata, and image layers for hidden data.

Hope you enjoyed the challenges and learned something new! 🙏
