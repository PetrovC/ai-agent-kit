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

---

## Universal principles

- **No string in source code.** All user-facing text goes through a translation function.
- **No string concatenation.** `"Hello, " + name` breaks in languages with different word order. Use placeholders / ICU.
- **Plurals are not "add an s".** Use CLDR plural rules. `1 jour` / `2 jours` works in French, fails in Polish, Arabic, Russian.
- **Format dates / numbers via the platform.** Never hand-roll `"DD/MM/YYYY"` — `Intl.DateTimeFormat` exists.
- **Time zones are separate from locale.** A French user in Tokyo still wants Tokyo time.
- **RTL is a layout problem.** Test it; CSS logical properties save you (`margin-inline-start` not `margin-left`).

---

## Stack choices

| Stack | Library | Notes |
|---|---|---|
| Web (any framework) | `Intl.*` API (built-in) | Browsers ship CLDR. Use it for formatting. |
| React | `react-intl` (FormatJS) or `react-i18next` | FormatJS gives ICU MessageFormat out of the box. |
| Vue | `vue-i18n` | First-class plural / interpolation. |
| Angular | `@angular/localize` or `@ngx-translate/core` | `@angular/localize` is the official, compile-time approach. |
| .NET | `IStringLocalizer<T>` + `.resx` files | Built into ASP.NET Core. |
| Python | `gettext` (stdlib) or `babel` | Pair with `Flask-Babel` / `Django i18n`. |
| Go | `golang.org/x/text/message` | Or `nicksnyder/go-i18n` for ICU-style. |
| Rust | `fluent-rs` (Mozilla Fluent) | Excellent CLDR support. |
| React Native | `i18n-js` or `react-intl` | Detect device locale with `expo-localization`. |
| Flutter | Built-in `intl` package + `Localizations` | `flutter gen-l10n` from ARB files. |

---

## Translation function

Standard shape across libraries:

```ts
// Simple
t('greeting')                                 // "Hello"

// Interpolation
t('welcome', { name: 'Anna' })                // "Welcome, Anna"

// Plural (ICU)
t('items', { count: 1 })  // "1 item"
t('items', { count: 5 })  // "5 items"

// Select (gendered, status, etc.)
t('greeting_by_gender', { gender: 'female' }) // "Hello, ma'am"
```

ICU MessageFormat in the source string:

```
{count, plural,
  =0 {No items}
  one {1 item}
  other {# items}
}
```

This is one entry, **not** three keys (`items_zero`, `items_one`, `items_many`).

---

## Key naming

- **Hierarchical** by feature: `leaves.form.submit`, `leaves.balance.title`.
- **Stable**: don't rename keys lightly; translators will lose context.
- **English-locale-as-source-of-truth**: the EN file is canonical; other languages derive.
- **No keys that are the English string.** `t('Click here')` looks fine until "Click here" gets edited.

---

## Plurals (the part most people get wrong)

CLDR defines plural categories per language:

| Language | Categories | Example |
|---|---|---|
| English | one, other | `1 day` / `2 days` |
| French | one, many, other | `1 jour` / `2 jours` (note: French has different rules for numbers > 1M) |
| Polish | one, few, many, other | `1 dzień` / `2 dni` / `5 dni` / `1.5 dnia` |
| Arabic | zero, one, two, few, many, other | Six forms. Yes. |
| Japanese / Chinese | other | One form. |

**Always use the ICU `plural` selector.** Never write `if (count === 1) ... else ...`.

---

## Date, time, number, currency

Use `Intl` (web / Node) or the equivalent platform API. Never hand-roll formats.

```js
new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long' }).format(d)
// "14 mai 2026"

new Intl.NumberFormat('en-US', { style: 'currency', currency: 'EUR' }).format(1234.5)
// "€1,234.50"

new Intl.RelativeTimeFormat('ja', { numeric: 'auto' }).format(-1, 'day')
// "昨日"
```

For .NET: `string.Format(CultureInfo.GetCultureInfo("fr-FR"), "{0:C}", 1234.5m)`.

For Python: `babel.numbers.format_currency(1234.5, 'EUR', locale='fr_FR')`.

---

## Time zones

- **Store UTC in the database.** Always.
- **Display in the user's preferred timezone**, not the server's.
- The user's timezone is **separate from their locale**. A French speaker in Tokyo wants `fr` strings but `Asia/Tokyo` times.
- Use IANA names (`Europe/Paris`), not offsets (`UTC+1`) — DST changes break offsets.

---

## RTL (right-to-left)

Languages: Arabic (ar), Hebrew (he), Persian (fa), Urdu (ur).

- Set `dir="rtl"` on `<html>` when the user's language is RTL.
- Use **CSS logical properties**:
  - `margin-inline-start` (not `margin-left`)
  - `padding-inline-end` (not `padding-right`)
  - `border-inline-start` (not `border-left`)
  - `text-align: start` (not `left`)
- Icons that have direction (back arrows, send icons) need RTL variants OR transform.
- Test the entire UI with `dir="rtl"` before declaring RTL support.

---

## Locale detection

Priority order:
1. Explicit user choice (saved in profile or cookie).
2. URL segment (`/fr/...`) — best for SEO + sharing.
3. `Accept-Language` header (server) or `navigator.languages` (browser).
4. Fallback (English usually).

Don't auto-detect via IP geolocation — VPNs, travelers, expats all break.

---

## Translation flow

1. **Extract**: tool reads source code, produces a base file (en.json, en.po, en.xliff).
2. **Translate**: send to translators (or a TMS like Crowdin, Lokalise, Phrase). Don't edit source files by hand.
3. **Import**: pull translated files back into the repo (script in CI, or a webhook from the TMS).
4. **Validate**: missing keys, untranslated entries, broken interpolation should fail CI.
5. **Release**: ship.

Pseudo-locales (e.g., `en-XA` with accented characters) help catch hardcoded strings and layout issues without a real translator.

---

## What NOT to do

- No string concatenation: `"You have " + count + " messages"`.
- No `if (lang === 'fr') ...` branches in business code — fix the translation file.
- No hardcoded date / number / currency formats.
- No images with embedded text — make it a separate text layer.
- No assumption that translated text is the same length as English ("Save" → "Enregistrer" → "Сохранить" — all different widths).
- No translation of brand names, technical terms unless explicitly required.
- No machine translation in production without human review for high-visibility surfaces.
- No tying locale to country (Switzerland speaks 4 languages, Belgium 3, Canada 2).

---

## Verification commands

```bash
# Find hardcoded strings (rough heuristic — review results)
grep -rnE '"[A-Z][a-zA-Z ]{4,}"' src/ --include="*.tsx" | grep -v "t\\|i18n\\|console"

# Check for missing keys (i18next)
npx i18next-parser

# Pseudo-locale build
LANG=en-XA pnpm build

# Format checks (Babel for Python)
pybabel extract -o messages.pot src/
pybabel update -i messages.pot -d locales -l fr_FR
```

---

## Final response requirements

Always report:
- Translation keys added / changed / removed.
- Source-language file path (`en.json`, etc.) and whether other locales need an update.
- ICU constructs introduced (plural, select).
- Date / number / currency formatting changes.
- RTL impact if any.
- Time-zone handling for new temporal fields.
- Any new dependency (i18n library): name, version, **license (MIT only — see `dependencies` skill)**.
