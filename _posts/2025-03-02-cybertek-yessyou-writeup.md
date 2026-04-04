---
layout: post
title: "CyberTEK CTF — YessYou Web Challenge Writeup"
date: 2025-03-02
category: ctf
difficulty: medium
platform: CyberTEK
tags: [web, blind-comparison, sorting, ctf, python]
description: "Leaking a flag character by character using a sorting oracle."
---

## Overview

I authored 4 web exploitation challenges for CyberTEK CTF: `reCURSED`, `B17`, `YessYou`, and `Random Quotes`. This writeup covers **YessYou**.

![YessYou challenge](/assets/images/yessyou_1.webp)

## Recon

After registering and logging in we're presented with a profile page where we can update our Username, Password, and Description, add Notes, and view a leaderboard of special users: **Vi**, **Yasuo**, and our own account.

![Profile page after login](/assets/images/yessyou_2.webp)

## Source Code Analysis

```python
def add_admins(FLAG):
    add_user("Yasuo", FLAG, "Virtue is no more than a luxury.", 1)
    add_user("Vi", generate_random_string(60), "If I want your opinion, I'll beat it out of you.", 1)

special_users = sorted(
    query_special(user_id),
    key=lambda x: (
        x[1],
        x[3] if x[1] == user_profile[1] and x[3] != user_profile[3] else x[2]
    )
)
```

Key observations:

- **Yasuo's password is the FLAG**
- The special users list is sorted by 3 criteria:
  1. Username
  2. If usernames match → sort by **description**
  3. If descriptions also match → sort by **password**

## The Oracle

Since the sort falls back to password comparison when username and description match, we can set our account to:

- **Username:** `Yasuo`
- **Description:** `Virtue is no more than a luxury.`

Now our password is compared directly against Yasuo's (the flag) in the sort order.

The logic is simple:
- If our password is **lexicographically less** than the flag → our account appears **below** Yasuo
- If our password is **greater** → our account appears **above** Yasuo

This gives us a character-by-character blind comparison oracle. 🙌

![Sorting oracle in action](/assets/images/yessyou_3.webp)

## Exploitation

By iterating through printable characters and observing our position in the leaderboard relative to Yasuo, we can leak the flag one character at a time:

1. Set password to `Securinets{` → account goes **above** Yasuo → current prefix is correct
2. Try each character at position `i`:
   - If position goes **up** → our char > flag[i], go lower
   - If position goes **down** → our char < flag[i], go higher
   - If position matches exactly → found flag[i] ✅
3. Append the found character and repeat

Following this logic character by character, the flag is revealed:

```
Securinets{H4S4G1}
```

![Flag found — HASAGI](/assets/images/yessyou_4.webp)

## Summary

| Step | Technique |
|---|---|
| Match username + description | Trigger password-based sort comparison |
| Observe leaderboard position | Blind character comparison oracle |
| Iterate character by character | Full flag extraction |

> **Lesson learned:** Never use sensitive data (like a flag or secret) as a sort key in a user-visible ranked list. Even indirect comparisons can leak secrets bit by bit.

HASAGI!! 😎
