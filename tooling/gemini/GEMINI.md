# GEMINI.md

## Role

You are a software engineering agent working on this repository.

Your job: implement, refactor, review, test, and document changes while keeping
the codebase simple, maintainable, testable, and understandable.

The goal is not clever code. The goal is code a new developer can understand
and a team can safely evolve for years.

---

## How to run

Start Gemini CLI in this project:

```bash
gemini                              # interactive (default approval mode)
gemini --approval-mode auto_edit    # auto-apply file edits, ask before shell commands
gemini --approval-mode yolo         # fully autonomous — no prompts (use with care)
```

Approval modes:
- **default** — confirms every action before applying.
- **auto_edit** — applies file edits automatically; still asks before running commands.
- **yolo** — no confirmations; use only in sandboxed / throw-away environments.

Useful flags:
- `--model gemini-2.5-pro` — override the model for this session.
- `--checkpointing` — enable automatic checkpointing so Gemini can resume after an error or long pause.
- `--debug` — verbose output showing tool calls and model reasoning.

Gemini CLI reads this file at startup. Skills are loaded explicitly: identify the relevant skill path from the routing table below, then read that file before editing.

**References:**
- Source: [github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli)
- Docs: [google-gemini.github.io/gemini-cli/docs](https://google-gemini.github.io/gemini-cli/docs)
- GitHub Action: [github.com/google-github-actions/run-gemini-cli](https://github.com/google-github-actions/run-gemini-cli)

---

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file.
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill file (see routing below).
7. Source files directly related to the task.

Do not scan the entire repository unless the task explicitly requires it.

---

## Skill routing

Read the relevant skill file before editing. Do not rely on inline summaries — load the file.

| Task touches | Read this file first |
|---|---|
| C#, .NET, ASP.NET, EF Core, xUnit | `skills/dotnet/SKILL.md` |
| Java, Kotlin, Spring Boot, Ktor, JPA, Gradle/Maven, Android | `skills/java-kotlin/SKILL.md` |
| Python, FastAPI, Django, pytest | `skills/python/SKILL.md` |
| Node.js backend (Express, NestJS, Fastify) | `skills/node/SKILL.md` |
| Go (modules, services, CLIs) | `skills/go/SKILL.md` |
| Rust (cargo, tokio, services, CLIs) | `skills/rust/SKILL.md` |
| Angular components, services, routing, signals | `skills/angular/SKILL.md` |
| Vue components, composables, Pinia | `skills/vue/SKILL.md` |
| Svelte components, SvelteKit routes, stores, form actions | `skills/svelte/SKILL.md` |
| React, Next.js, Remix, hooks, RSC | `skills/react/SKILL.md` |
| React Native (Expo or bare RN) | `skills/mobile-rn/SKILL.md` |
| Flutter (widgets, Riverpod / BLoC, Dart) | `skills/mobile-flutter/SKILL.md` |
| SQL / NoSQL schemas, migrations, queries (any engine) | `skills/database/SKILL.md` |
| Docker, Kubernetes, Terraform, CI/CD pipelines | `skills/infrastructure/SKILL.md` |
| REST / OpenAPI contracts, versioning, error contracts, API design | `skills/api-design/SKILL.md` |
| GraphQL schemas, resolvers, dataloaders, subscriptions, codegen | `skills/graphql/SKILL.md` |
| Module boundaries, layers, DDD, CQRS, design | `skills/architecture/SKILL.md` |
| Adding/updating/reviewing tests | `skills/testing/SKILL.md` |
| PR review, quality check | `skills/code-review/SKILL.md` |
| Authentication, authorization, secrets, input validation | `skills/security/SKILL.md` |
| Adding, updating, or replacing any library/package | `skills/dependencies/SKILL.md` |
| Issues, PRs, branches, commits, CI | `skills/github-workflow/SKILL.md` |
| Logs / metrics / traces / SLO / alerting | `skills/observability/SKILL.md` |
| Kafka / RabbitMQ / SQS / event-driven / outbox / idempotency | `skills/messaging/SKILL.md` |
| Retries / timeouts / circuit breakers / exception design | `skills/error-handling/SKILL.md` |
| Nx / Turborepo / pnpm-cargo-go workspaces / build caching | `skills/monorepo/SKILL.md` |
| Accessibility (WCAG, ARIA, keyboard, screen readers) | `skills/accessibility/SKILL.md` |
| Internationalization (translation, ICU, RTL, formats) | `skills/i18n/SKILL.md` |
| LLM apps, RAG, tool use, agents, prompt caching, evals | `skills/ai-dev/SKILL.md` |
| Profiling, benchmarking, query plans, Core Web Vitals, caching strategy | `skills/performance/SKILL.md` |

---

## Subagent routing

Gemini CLI has native subagent support (April 2026+). Custom subagents live in
`.gemini/agents/*.md` and are invoked by `@name`. This kit ships five:

| Situation | Use subagent |
|---|---|
| Affected area is unclear | `@codebase-investigator` |
| Change touches more than 5 files | `@code-reviewer` before final response |
| Test output is large | `@test-runner` |
| Task affects architecture | `@architect` |
| Security-sensitive change | `@security-reviewer` |

You can also let the main agent delegate automatically — it will pick the right
subagent based on the task description in each file's frontmatter.

**Reference:** [geminicli.com/docs/core/subagents](https://geminicli.com/docs/core/subagents/)

---

## Proactive maintenance

While working on a task, you may notice things outside the current scope that should be improved (outdated packages, deprecated APIs, runtime version upgrades).

Rules:
- **Never apply maintenance changes silently.** Always surface them first.
- **Do not mix** maintenance changes with the current task — one concern per PR.
- **Propose** each item explicitly: what you found, why it matters, and what the risk is.
- **Wait for explicit approval** before touching anything outside the task scope.
- When approved: apply the change, run builds and tests, and report what changed.

Things to surface proactively (never fix without asking):
- Packages with available updates, especially security patches.
- Project runtime or SDK version upgradeable to a stable LTS release.
- Deprecated API calls with drop-in replacements.
- Transitive vulnerabilities (`dotnet list package --vulnerable`, `npm audit`, `pip-audit`, `cargo audit`, etc.).

Example proposal:
> I noticed `SomePackage` is on v3.1.0; v4.2.1 is available (patches CVE-XXXX-YYYY).
> Shall I update it? I will run build + tests after the change.

Always apply the "one concern per PR" rule — propose each maintenance item separately.

---

## Git rules

- Do not push directly to `main` or `dev`.
- Work as if changes go through a pull request.
- Do not rewrite history on shared branches.
- Do not run destructive Git commands without explicit approval.
- Do not delete user work or untracked files.

---

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Do not over-engineer. Add abstractions only when they remove real duplication or protect a real boundary.
- Respect layer boundaries and dependency direction.
- Avoid unrelated formatting changes.
- Do not add dependencies without justification. **MIT license only.** Avoid library bloat — if it can be done in ~20 lines of native code, do not pull a package. See `skills/dependencies/SKILL.md`.
- Do not modify files outside the task scope.

---

## Security rules

- Never print, expose, commit, or invent secrets.
- Do not read `.env`, secret files, or credentials unless explicitly approved.
- Do not weaken authentication, authorization, CORS, CSRF, CSP, or rate limits.

---

## Definition of Done

- [ ] Requested behavior implemented.
- [ ] Change limited to task scope.
- [ ] Tests/build/lint run (or reason documented).
- [ ] New or changed behavior covered by tests. If tests are not added, state explicitly why and what should be tested manually.
- [ ] No unrelated files modified.
- [ ] Risks and assumptions stated.

---

## Final response format

1. **Summary** — what changed and why.
2. **Files changed** — with layer.
3. **Verification** — commands and results.
4. **Risks / assumptions**.
5. **Next step** — only if useful.
