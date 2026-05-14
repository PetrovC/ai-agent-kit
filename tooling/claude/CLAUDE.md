# CLAUDE.md

## Role

You are a software engineering agent working on this repository.

Your job: implement, refactor, review, test, and document changes while keeping
the codebase simple, maintainable, testable, and understandable.

The goal is not clever code. The goal is code a new developer can understand
and a team can safely evolve for years.

---

## Personal overrides

Create a `CLAUDE.local.md` file in the project root (gitignored) for developer-specific
preferences — local paths, personal aliases, preferred verbosity, machine-specific tools.
It is merged with this file automatically by Claude Code. Do not commit it.

---

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file (and `CLAUDE.local.md` if present).
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill or rule (see routing below).
7. Source files directly related to the task.

Do not scan the entire repository unless the task explicitly requires it.

---

## Skill routing

Use the relevant skill when editing:

| Task touches | Use skill |
|---|---|
| C#, .NET, ASP.NET, EF Core, xUnit, backend | `dotnet` skill |
| Java, Kotlin, Spring Boot, Ktor, JPA, Gradle/Maven, Android | `java-kotlin` skill |
| Python, FastAPI, Django, pytest | `python` skill |
| Node.js backend (Express, NestJS, Fastify) | `node` skill |
| Go (modules, services, CLIs) | `go` skill |
| Rust (cargo, tokio, services, CLIs) | `rust` skill |
| Angular components, services, routing, signals | `angular` skill |
| Vue components, composables, Pinia | `vue` skill |
| Svelte components, SvelteKit routes, stores, form actions | `svelte` skill |
| React, Next.js, Remix, hooks, RSC | `react` skill |
| React Native (Expo or bare RN) | `mobile-rn` skill |
| Flutter (widgets, Riverpod / BLoC, Dart) | `mobile-flutter` skill |
| SQL / NoSQL schemas, migrations, queries (any engine) | `database` skill |
| Docker, Kubernetes, Terraform, CI/CD pipelines | `infrastructure` skill |
| REST / OpenAPI / GraphQL contracts, versioning, errors | `api-design` skill |
| Module boundaries, layers, DDD, CQRS, design | `architecture` skill |
| Adding/updating/reviewing tests | `testing` skill |
| PR review, quality check | `code-review` skill |
| Security-sensitive code | `security` skill |
| Adding, updating, or replacing any library/package | `dependencies` skill |
| GitHub issues, PRs, commits, CI | `github-workflow` skill |
| Logs / metrics / traces / SLO / alerting | `observability` skill |
| Kafka / RabbitMQ / SQS / event-driven / outbox / idempotency | `messaging` skill |
| Retries / timeouts / circuit breakers / exception design | `error-handling` skill |
| Nx / Turborepo / pnpm-cargo-go workspaces / build caching | `monorepo` skill |
| Accessibility (WCAG, ARIA, keyboard, screen readers) | `accessibility` skill |
| Internationalization (translation, ICU, RTL, formats) | `i18n` skill |
| LLM apps, RAG, tool use, agents, prompt caching, evals | `ai-dev` skill |
| Profiling, benchmarking, query plans, Core Web Vitals, caching strategy | `performance` skill |

---

## Subagent routing

Delegate noisy or specialized work to keep the main context clean:

| Situation | Use subagent |
|---|---|
| Affected area is unclear | `codebase-investigator` |
| Change touches more than 5 files | `code-reviewer` before final response |
| Test output is large | `test-runner` |
| Task affects architecture or boundaries | `architect` |
| Change touches security-sensitive code | `security-reviewer` |

Do not use subagents for simple one-file changes.

---

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Do not over-engineer. Add abstractions only when they remove real duplication or protect a real boundary.
- Respect layer boundaries and dependency direction.
- Avoid unrelated formatting changes.
- Do not add dependencies without justification. **MIT license only.** Avoid library bloat — if it can be done in ~20 lines of native code, do not pull a package. See `dependencies` skill.
- Do not modify files outside the task scope.

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
