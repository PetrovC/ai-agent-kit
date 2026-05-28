---
name: dependencies
description: >
  Use whenever a new package, library, NuGet, npm module, or any third-party
  code is about to be added or updated — regardless of language, scope, or size.
  Also use when reviewing a PR that introduces a dependency.
paths:
  - "**/package.json"
  - "**/package-lock.json"
  - "**/yarn.lock"
  - "**/pnpm-lock.yaml"
  - "**/*.csproj"
  - "**/Cargo.toml"
  - "**/go.mod"
  - "**/pyproject.toml"
  - "**/pom.xml"
  - "**/requirements*.txt"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(yarn:*)"
  - "Bash(pip:*)"
  - "Bash(uv:*)"
  - "Bash(cargo:*)"
  - "Bash(go:*)"
  - "Bash(mvn:*)"
  - "Bash(./gradlew:*)"
  - "Bash(dotnet:*)"
  - "Bash(pip-audit:*)"
---

# Dependencies Skill

## Goal

Every dependency is a permanent cost: bundle weight, supply-chain risk, license
obligation, security surface, and future maintenance. Most of the time, the right
answer is "do not add it."

The default is **no**. The burden of proof is on the addition.

---

## Hard rule — License

**Only MIT-licensed packages are allowed.**

This applies regardless of language, regardless of how popular the library is,
and regardless of how small the package is. Transitive dependencies must also
be MIT.

Not allowed by default (require explicit user approval): Apache-2.0, BSD-2/3,
ISC, MPL, LGPL, GPL, AGPL, unlicensed, proprietary, "custom" licenses.

If you cannot determine the license, do not add the package.

### Verifying license

```bash
# Node / npm / pnpm
npm view <package-name> license
npx license-checker --production --summary
npx license-checker --production --onlyAllow "MIT"

# .NET / NuGet
# Check the .nuspec or the NuGet.org page (Licenses column)
dotnet list package --include-transitive

# Generic: read the LICENSE file in the upstream repository
```

For transitive dependencies, run a full scan, not just the direct dep.

---

## Hard rule — Cost / benefit

Before adding any dependency, answer all of these in writing:

1. **Can this be done in under ~20 lines of native code?** If yes, do not add.
2. **What fraction of the library will actually be used?** If it is 1 function out of 200, do not add.
3. **What is the bundle / install impact?** Size, transitive count, deepest tree.
4. **Is it actively maintained?** Last commit date, open issues, recent security advisories.
5. **Is there a smaller, MIT-licensed alternative?** Look it up before deciding.
6. **What is the cost of removing it later?** Lock-in to its API shape.

If any of those answers is bad, do not add it.

---

## Common overkill patterns to refuse

- Adding **lodash** for `get`, `isEmpty`, `map`, `pick`, `omit` — native JS / TS handles this.
- Adding **moment.js** to format one date — use `Intl.DateTimeFormat` or, if needed, `date-fns` (tree-shakable, MIT).
- Adding **axios** when `fetch` works — modern Node and browsers have it.
- Adding **classnames** or **clsx** for one ternary — string concatenation works.
- Adding a **UI kit** (Material UI, PrimeVue full suite) for one button.
- Adding a **full ORM** for 3 simple queries.
- Adding **uuid** for a single ID — `crypto.randomUUID()` is built in.
- Adding **dotenv** in production .NET / modern Node — built-in config works.
- Adding a **state manager** (Redux, Pinia, NgRx) for one piece of local state.

If you find yourself reaching for a library to do something trivial — write the 5 lines instead.

---

## When adding *is* the right call

- The library replaces a significant amount of code (≈ 50+ lines), and that code
  would be non-trivial to write and test correctly.
- The library handles a complex domain where reimplementation is risky:
  cryptography, parsing (HTML, JSON5, YAML), time zones, internationalization,
  PDF generation, image processing.
- The library is the de-facto, battle-tested standard (e.g., `xunit`, `vitest`,
  `vue`, `efcore`).
- Reimplementing would create a security risk you cannot fully audit.

In those cases, still pick the lightest MIT option available.

---

## Pinning and updates

- Pin exact versions (`"package": "1.2.3"`, not `"^1.2.3"`) for direct deps in libraries.
- Apps can use ranges, but lockfiles must be committed (`package-lock.json`, `pnpm-lock.yaml`).
- When updating a dep, check the changelog and re-verify the license has not changed.
- Remove unused dependencies in the same PR as the code that stopped using them.

---

## Final response requirements

When adding or updating a dependency, always report:

- Package name, version, license — **state the license explicitly**.
- Why a native or already-installed solution was insufficient.
- Transitive dependency count and any non-MIT transitive deps found.
- Alternatives considered and why they were rejected.
- Bundle / install size impact if relevant (frontend, mobile).
