---
name: accessibility
description: >
  Use when building or reviewing user-facing UI (web, mobile, desktop) for
  accessibility: semantic HTML, ARIA, keyboard navigation, screen readers,
  contrast, focus management, motion sensitivity, WCAG conformance.
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Bash(pnpm:*)"
version: "1.0.0"
---

# Accessibility (a11y) Skill

## Goal

UI that everyone can use — including people who navigate with keyboard only,
screen readers, voice control, magnifiers, or who have reduced motion / color
sensitivity. Not a checkbox at the end; built in from the first prototype.

Target: **WCAG 2.2 Level AA** as the minimum bar for production UI.

---

## Universal principles

- **Semantic HTML first, ARIA second.** A `<button>` does the right thing by default; a `<div role="button">` won't.
- **Keyboard parity.** Anything a mouse user can do, a keyboard user can do — and you can see where focus is.
- **Don't kill the platform.** Screen reader, magnifier, browser zoom must keep working.
- **Color is a hint, not the only signal.** Errors must have text, not just red.
- **Movement is opt-in.** Respect `prefers-reduced-motion`.
- **Test with assistive tech, not just rules.** Lighthouse / axe catch ~30% of issues — humans catch the rest.

---

## Semantic HTML (web)

| Use | Not |
|---|---|
| `<button>` | `<div onclick>` |
| `<a href>` for navigation | `<button>` that does `location.href = ...` |
| `<label for>` + `<input>` | `<div>Email</div><input>` |
| `<nav>`, `<main>`, `<header>`, `<footer>` | `<div class="nav">` |
| `<ul><li>` for lists | `<div><div>` repeats |
| `<h1>` → `<h6>` once each, hierarchical | Random `<h3>` everywhere |
| `<button type="button">` inside forms | bare `<button>` (defaults to `submit`) |

One `<main>` per page. One visible `<h1>` per page.

---

## ARIA (when HTML is not enough)

**Rule 1: prefer native HTML.** If you reach for `role="..."` first, you're probably wrong.

**Use ARIA for** custom widgets that have no native equivalent: tabs, comboboxes, tree views, complex menus.

Pattern reference: [WAI-ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/).

Common attributes:

| Attribute | Purpose |
|---|---|
| `aria-label` | Accessible name when no visible text (icon button). |
| `aria-labelledby` | Accessible name from another element's text. |
| `aria-describedby` | Extra context (form field hint, error message). |
| `aria-live="polite"` | Announce dynamic content updates (toast, results count). |
| `aria-expanded` | Disclosure state (accordion, menu trigger). |
| `aria-current="page"` | Active item in nav. |
| `aria-hidden="true"` | Hide decorative content from AT (use sparingly). |
| `role="status"` | Wrapper for status messages, announced politely. |
| `role="alert"` | For urgent announcements (announced assertively). |

**Don't** combine `aria-hidden="true"` with focusable content — focus disappears for keyboard users.

---

## Keyboard navigation

- **Every interactive element must be reachable with `Tab`** (and `Shift+Tab` in reverse).
- **Focus is visible.** Don't `outline: none` unless you provide a custom focus ring.
- **Logical tab order** = DOM order. Avoid `tabindex` > 0 (overrides DOM, breaks expectations).
- **`tabindex="-1"`** = programmatically focusable but not in tab order. Use for modal containers receiving focus on open.
- **Skip link**: first focusable element should be "Skip to main content" hidden until focused.
- **Modals trap focus** while open; restore focus to the trigger on close.
- **Escape closes** dialogs, popovers, menus.

---

## Screen reader basics

Test on:
- **NVDA** (Windows, free) — the most common assistive tech globally.
- **VoiceOver** (macOS / iOS, built-in).
- **TalkBack** (Android, built-in).
- **JAWS** (Windows, paid) — common in enterprise.

The first 30 minutes of using a screen reader teach you more than any rule list.

Quick checks:
- The page has a clear, unique title.
- Headings read like a table of contents.
- Form fields are labeled.
- Errors announce themselves on submit.
- Buttons say what they do ("Save", not "OK" when ambiguous).

---

## Forms

- Every `<input>` has a `<label>` (use `for`/`id` or wrap).
- Required fields are marked in text, not only in color or `*` (the `*` should be paired with text).
- Inline validation errors are tied to the field via `aria-describedby`.
- On submit failure, focus moves to the first invalid field; an `aria-live` region summarizes errors.
- Use proper input types: `type="email"`, `type="tel"`, `type="number"`, `inputmode="numeric"` — for keyboard + autofill on mobile.
- Don't disable submit while the form is invalid — let the user submit and read the errors.

---

## Color and contrast

- **Text contrast**: ≥ 4.5:1 for normal text, ≥ 3:1 for large (≥ 18pt or 14pt bold). WCAG AA.
- **UI components & graphical objects**: ≥ 3:1 (borders of inputs, focus rings, icons).
- **Don't convey info by color alone.** Errors: red border + icon + text. Status: badge + label.
- Tools: `axe DevTools`, `Lighthouse`, browser DevTools color picker (shows contrast ratio).

---

## Motion and animation

- Respect `@media (prefers-reduced-motion: reduce)`:
  ```css
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
    }
  }
  ```
- No content flashes more than 3 times per second (seizure risk).
- Auto-playing video / carousels need a pause control.

---

## Images and media

- Every `<img>` has `alt`. Decorative images: `alt=""` (empty, not missing).
- Complex images (charts) need a longer text description nearby.
- Captions for video. Transcripts for audio.
- Don't put text in images — it's not selectable, translatable, or zoomable.

---

## Mobile (React Native / Flutter)

### React Native

- `accessibilityLabel`, `accessibilityRole`, `accessibilityHint` on every interactive element.
- `accessible={true}` to group children into one accessible element.
- `accessibilityState={{ expanded, selected, disabled }}` for stateful widgets.
- Honor `Appearance.getColorScheme()` and `AccessibilityInfo.isReduceMotionEnabled()`.

### Flutter

- `Semantics()` widget wraps custom-painted UI.
- Provide `label`, `hint`, `excludeSemantics: true` on decorative children.
- `MediaQuery.of(context).textScaleFactor` — don't hardcode font sizes that break at 200%.

See `mobile-rn` and `mobile-flutter` skills for stack-specific testing.

---

## Internationalization vs accessibility

- A screen-reader user in French expects French announcements. `lang` on `<html>` and on subtrees with different languages.
- Right-to-left languages (`dir="rtl"`) — test the layout.
- See the `i18n` skill for translation flow.

---

## Testing

### Automated

- **axe-core** (via `@axe-core/playwright`, `jest-axe`, `cypress-axe`) — catches ~30% of issues automatically.
- **Lighthouse a11y audit** — integrate in CI.
- **eslint-plugin-jsx-a11y** for React / JSX.

### Manual

- **Keyboard-only**: unplug your mouse, can you do everything?
- **Screen reader smoke test**: turn on NVDA / VoiceOver, navigate the changed page.
- **200% zoom**: layout still works?
- **Forced colors mode** (Windows high contrast): UI still readable?

### CI example (Playwright + axe)

```ts
import AxeBuilder from '@axe-core/playwright';

test('home page has no critical a11y violations', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(results.violations).toEqual([]);
});
```

---

## What NOT to do

- No `<div onclick>` for actions — use `<button>`.
- No `tabindex="0"` on every element to "make it focusable" — make it a real button or link.
- No `outline: none` without a replacement focus ring.
- No `alt="image"` or `alt="photo"` — describe the content or use `alt=""`.
- No placeholder-as-label — placeholder disappears when typing.
- No clickable thing < 44 × 44 px (touch target minimum).
- No color-only error / required indicators.
- No "we'll add a11y after the redesign" — retrofitting costs 10× more than building it in.

---

## Verification commands

```bash
# Web (Playwright + axe)
npx playwright test a11y.spec.ts

# Lighthouse
npx lighthouse https://example.com --only-categories=accessibility --view

# ESLint (React)
npx eslint . --rulesdir node_modules/eslint-plugin-jsx-a11y/lib/rules

# Manual smoke test prompts
echo "- Tab through the page. Can you reach every interactive element?"
echo "- Where is focus visible? Is the order logical?"
echo "- Turn on screen reader. Does navigation make sense?"
echo "- Zoom to 200%. Is anything cut off or overlapping?"
```

---

## Final response requirements

Always report:
- A11y impact: which elements were touched (semantic / ARIA / keyboard / focus).
- WCAG criteria addressed (e.g., "1.4.3 contrast", "2.1.1 keyboard").
- How it was tested: automated tool results, manual screen reader pass (if done), keyboard-only pass.
- Known gaps NOT fixed in this change and why.
- Any new dependency (axe, jsx-a11y, etc.): name, version, **license (MIT only — see `dependencies` skill)**.
