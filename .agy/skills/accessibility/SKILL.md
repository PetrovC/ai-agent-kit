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

## Quick reference

| Concept | Best practice |
|---|---|
| Structure | Use semantic HTML (`<main>`, `<nav>`, `<header>`), correct heading hierarchy |
| Keyboard | Logical tab order, visible focus states, no keyboard traps |
| Forms | Associate labels with inputs (`for`/`id`), provide clear error messages |
| Screen Readers| Provide descriptive alt text, use ARIA attributes correctly |
| Key commands | `npx playwright test --grep @a11y`, `lighthouse http://localhost:3000` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)
