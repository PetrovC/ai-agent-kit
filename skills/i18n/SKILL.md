---
name: i18n
description: >
  Use when adding or reviewing internationalization / localization: translation
  files, date / number / currency formatting, plural rules, RTL layouts,
  language detection, locale switching, ICU MessageFormat, translation flow.
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(npx:*)"
version: "1.0.0"
---

# Internationalization (i18n) Skill

## Goal
Build the product so it works in any locale from day one. Translation can be
added later; the **structural** decisions (where strings live, how plurals work,
how dates format) cost 10× to retrofit if you guess wrong.

i18n is structural. l10n (localization) is content.

## Quick reference

| Concept | Best practice |
|---|---|
| Keys | Use descriptive, structured key names (e.g. `auth.login.title`) |
| Formatting | Use native Intl APIs or libraries for dates, times, numbers, and currencies |
| Layout | Support RTL (Right-to-Left) layouts using CSS logical properties |
| Code | Never hardcode user-facing strings; load translations dynamically or at build time |
| Key commands | `npm run i18n:check`, check for missing translation keys |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)
