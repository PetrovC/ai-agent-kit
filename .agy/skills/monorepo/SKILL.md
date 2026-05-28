---
name: monorepo
description: >
  Use when working in a monorepo: Nx, Turborepo, pnpm / npm / yarn workspaces,
  Cargo workspaces, Go workspaces, Lerna, Bazel. Covers project structure,
  affected detection, build caching, dependency boundaries, CI matrix.
paths:
  - "**/nx.json"
  - "**/turbo.json"
  - "**/pnpm-workspace.yaml"
  - "**/lerna.json"
  - "**/.bazelrc"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(npx:*)"
---

# Monorepo Skill

## Goal

A single repo with many packages that stays fast, builds only what changed,
and enforces dependency boundaries. The goal is the speed and atomic-change
benefits of a monorepo without it turning into a tangled big-ball-of-mud.

---

## Universal principles

- **A monorepo is not a junk drawer.** Define clear package boundaries; enforce them in CI.
- **Build only what changed.** Use affected-detection (Nx, Turbo, Bazel) so PRs don't rebuild the world.
- **Cache builds and tests.** Local + remote cache. Skip work that already passed.
- **One lockfile, one toolchain version.** Drift between packages is the #1 monorepo headache.
- **Atomic changes preferred.** Cross-package refactor lands in one PR — that's the main reason you have a monorepo.

---

## Layout (typical)

```
my-monorepo/
├── packages/                    # or apps/ + libs/ in Nx
│   ├── api/
│   ├── web/
│   ├── mobile/
│   └── shared-types/
├── tools/                       # scripts, codegen, internal CLIs
├── .github/workflows/
├── package.json                 # workspace root
├── pnpm-workspace.yaml          # (or yarn / npm equivalent)
├── tsconfig.base.json           # shared TS config
└── turbo.json | nx.json | etc.
```

Rules:
- Apps are leaves (nothing depends on them).
- Libs are reusable (one or more apps depend on them).
- Shared types / contracts live in a dedicated package.
- Circular dependencies between packages are forbidden — enforce in CI.

---

## Choosing a tool

| Tool | Sweet spot | Notes |
|---|---|---|
| **pnpm workspaces** | TS / JS, small-to-medium monorepo | Fast, disk-efficient. Pair with Turborepo for build orchestration. |
| **Turborepo** | TS / JS, incremental builds | Easy onboarding, remote cache via Vercel. |
| **Nx** | TS / JS / .NET / Go (with plugins) | Heavyweight but feature-rich: affected, generators, graph viz. |
| **Cargo workspaces** | Rust | Built into Cargo. Use `[workspace]` + `members = ["crates/*"]`. |
| **Go workspaces** | Go ≥ 1.18 | `go.work` file for multi-module dev. |
| **Bazel / Pants / Buck** | Polyglot at large scale | Steep learning curve. Only adopt if you have FAANG-scale problems. |
| **Lerna** | Legacy, JS only | Nx absorbed it. New projects: pick something else. |

---

## pnpm workspaces (TS / JS)

```yaml
# pnpm-workspace.yaml
packages:
  - "packages/*"
  - "tools/*"
```

- Internal deps via `"my-shared": "workspace:*"` in `package.json`.
- `pnpm -r build` runs `build` across all packages (parallel by default).
- `pnpm --filter ./packages/api... test` runs tests in `api` and its dependencies.
- Hoisting: avoid `shamefully-hoist`. Per-package install is the safer default.

---

## Turborepo

```jsonc
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**"]
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"]
    },
    "lint": { "outputs": [] },
    "dev": { "cache": false, "persistent": true }
  }
}
```

- `dependsOn: ["^build"]` = upstream packages build first.
- `outputs` are what's cached. List them or caching can't help.
- `turbo run build --filter=api...` = build `api` + its upstream deps.
- `turbo run test --filter=...[origin/main]` = test packages affected by changes since `main`.

---

## Nx

- `nx affected -t test` — runs tests only for projects affected by current changes.
- `nx graph` — visualize the dependency graph.
- `nx run-many -t lint` — fan out a target across projects.
- `tags` in `project.json` + ESLint `@nx/enforce-module-boundaries` enforce architectural rules (e.g., `scope:api` cannot depend on `scope:web`).
- Generators for new libs / apps — use them to keep new packages consistent.

---

## Cargo workspaces (Rust)

```toml
# Cargo.toml (workspace root)
[workspace]
members = ["crates/*"]
resolver = "2"

[workspace.dependencies]
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
```

- Reference workspace deps from member crates: `tokio = { workspace = true }`.
- `cargo build -p my-crate` builds one. `cargo test --workspace` tests all.
- Bundle similar crates by domain, not by layer.

---

## Go workspaces

```
// go.work (Go 1.18+)
go 1.22

use (
    ./services/api
    ./services/worker
    ./libs/shared
)
```

- Each module has its own `go.mod`.
- `go.work` is local-dev only — **don't commit `go.work.sum`** for security; commit `go.work`.
- `go build ./services/api/...` builds one.

---

## Affected detection in CI

Goal: a PR that only touches `packages/web/` does NOT run `api` integration tests.

```yaml
# GitHub Actions — Turborepo
- run: pnpm install --frozen-lockfile
- run: pnpm turbo run lint test --filter=...[origin/main]
```

```yaml
# Nx
- uses: nrwl/nx-set-shas@v4
- run: pnpm nx affected -t lint test build
```

- The base SHA is `origin/main` for PRs, `HEAD~1` for main.
- Cache misses still happen on first run; remote cache fixes that.

---

## Versioning and publishing

Three common models:

1. **Fixed / locked version** (all packages bump together) — Lerna default. Good for monorepos shipping a single product.
2. **Independent versioning** (each package bumps separately) — `changesets` (MIT) is the standard tool.
3. **No publishing** (internal-only) — packages reference each other via `workspace:*` and never leave the repo.

`changesets` workflow:
- Contributor adds a `.changeset/*.md` file describing the change + bump level.
- CI verifies presence.
- Release job bumps versions, generates CHANGELOG, publishes.

---

## CI matrix

A monorepo CI must:

1. **Install once** at the root (with frozen lockfile).
2. **Detect what changed.**
3. **Run only affected packages** for lint / test / build.
4. **Cache aggressively** (deps, builds, test results).
5. **Fail fast** on lint before test before build (cheapest first).

---

## What NOT to do

- No "everything depends on everything" — packages will rebuild constantly.
- No shipping a private internal-only utility to npm — keep it `workspace:*`.
- No multiple Node / TS / Rust versions across packages — pin in the root.
- No circular deps. CI must fail on them (use `madge` for JS, `cargo-deny` for Rust).
- No `npm install` next to `pnpm install` — pick one package manager and enforce via `engines` + `engine-strict`.
- No committing built artifacts (`dist/`, `target/`, `node_modules/`).
- No giant root `package.json` with every dependency — each package owns its deps.
- No "we'll split it later" — start with the boundaries you want.

---

## Verification commands

```bash
# pnpm
pnpm install --frozen-lockfile
pnpm -r build
pnpm --filter ./packages/api test

# Turborepo
turbo run build test lint --filter=...[origin/main]
turbo run build --dry-run        # show what would run

# Nx
nx affected -t lint test --base=origin/main
nx graph                          # opens dependency graph
nx run-many -t build

# Cargo
cargo build --workspace
cargo test -p my-crate
cargo deny check                  # license + advisory check

# Go
go build ./...
go test -race ./...
```

---

## Final response requirements

Always report:
- Packages added / changed and which packages depend on them.
- Tool config files changed (`turbo.json`, `nx.json`, `Cargo.toml`, `go.work`).
- New cross-package dependency edges introduced (no circles).
- CI impact: estimated build time change, cache hit expectations.
- Versioning impact if using changesets (which packages bump, what level).
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.
