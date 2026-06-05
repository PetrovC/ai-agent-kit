# Adaptive Routing

## Purpose
Adaptive routing provides a dynamic mechanism to govern how the agent loads context and delegates tasks. Currently, the static keyword tables in main router files like [AGENTS.md](../../AGENTS.md), [CLAUDE.md](../../CLAUDE.md), and [AGY.md](../../AGY.md) load all listed skills indiscriminately, leading to wasted token usage on simple tasks and insufficient depth or coordination on complex, multi-layered tasks. By introducing intent-based classification and lazy-loading of subskills or references, the agent dynamically adjusts its workspace context budget. This design ensures that simple tasks remain lightweight and cost-effective, while complex multi-area tasks automatically trigger targeted subagent delegation and deep technical references.

## Routing pipeline

The adaptive routing workflow operates in five distinct sequential stages to process user requests, resolve context dependencies, and coordinate execution.

### Stage 1 — Classify task intent
- **Description**: Evaluates the task prompt and path metadata using deterministic, zero-LLM heuristics to assign intent categories.
- **Inputs**: Task description text (free text), optional list of changed/mentioned file paths.
- **Outputs**: One or more intent labels from this fixed vocabulary: `review`, `implement`, `fix`, `refactor`, `docs`, `ci`, `security`, `data-migration`, `small-change`.
- **Rule**: If no label matches with confidence, classify as `small-change` (fallback → do less).

### Stage 2 — Select skills
- **Description**: Filters the global skill catalog to select a minimal set of relevant skills based on intent and file path signals.
- **Inputs**: Intent labels from Stage 1, file paths (globs), task keywords.
- **Outputs**: A small candidate set of selected skills (default cap: 4 skills).
- **Rule**: A skill is selected only when at least one strong signal matches (file glob OR exact keyword OR explicit task_intent match). Weak or speculative matches do not load a skill.

### Stage 3 — Select references
- **Description**: Evaluates conditional rules on sub-skills and reference documents associated with selected skills to conditionally load in-depth files.
- **Inputs**: Selected skills from Stage 2, task description, file paths.
- **Outputs**: List of reference files to load (may be empty).
- **Rule**: If no `load_when` condition is met, do not load any reference beyond the base skill file (e.g., the dotnet [SKILL.md](../../skills/dotnet/SKILL.md)).

### Stage 4 — Decide delegation
- **Description**: Estimates task complexity and context constraints to decide whether to divide work among dedicated subagents.
- **Inputs**: Selected skills, intent labels, task scope estimate (number of independent technical areas).
- **Outputs**: A delegation plan (YAML shape) or a decision of "no delegation".
- **Decision criteria**:
  - **Delegate when ALL of**:
    - Task involves 2 or more independent technical areas (e.g. backend + frontend)
    - Total context estimate would exceed ~50% of the context window
    - The areas can be reviewed or worked independently
  - **Do NOT delegate when**:
    - Task is a single-file change
    - Task is docs-only, CI-only, or formatting-only
    - User has explicitly scoped the task to one area
    - Only 1 skill is selected
  - **Default cap**: 2–3 subagents maximum (governed under [SUBAGENT_GOVERNANCE.md](SUBAGENT_GOVERNANCE.md))

### Stage 5 — Synthesize results
- **Description**: Aggregates, cleans, and merges outputs from any active subagents into a unified, conflict-free final response.
- **Inputs**: Subagent outputs (concise structured summaries).
- **Outputs**: A single coherent answer with unified next actions presented to the user.
- **Rule**: Subagents return summaries, never full transcripts (conforming to [DELEGATION.md](DELEGATION.md)).

## Context protection rules
To safeguard the context window and prevent token bloat, the following rules must be strictly enforced:
- Load base `SKILL.md` files only (not deep versions, and not references/) unless signals justify depth.
- A strong signal constitutes a matching file glob OR an explicit keyword in the task text.
- Never load a skill speculatively ("this might be relevant").
- A skill not selected at Stage 2 is not loaded, even partially.
- The context budget for skill content must stay below 20% of the context window for a typical task.
- The main agent must be able to state which signal triggered each skill load.

## Fallback behavior
When intent classification returns low confidence (nothing matches clearly):
- Default to `small-change` intent.
- Load zero extra skills.
- Offer: "I can load additional context for [area] if you confirm that's needed".
- Never preload context just in case.

## Explainability
The main agent must produce a one-line reason for each selection:
- "Loaded dotnet skill: `src/Domain/Trip.cs` matched the dotnet `**/*.cs` path pattern" (referencing [SKILL.md](../../skills/dotnet/SKILL.md))
- "Loaded code-review skill: task text contains the keyword 'review'" (referencing [SKILL.md](../../skills/code-review/SKILL.md))
- "Loaded ddd-cqrs reference: `src/Domain/` path matched the `**/Domain/**` load condition" (referencing a hypothetical `skills/dotnet/references/ddd-cqrs.md` reference)
- "No delegation: task involves one technical area (dotnet backend only)"

## When not to activate extra context
No extra context or skills are loaded under the following conditions:
- Typo fixes, formatting, and doc wording changes.
- Single-file changes where the skill is obvious from the file type alone.
- When the user's description already fully constrains the scope.
- When the user explicitly says "quick fix" or "small change".
- When `small-change` intent is classified and no strong secondary signal exists.

## Examples

### Example A — Full-stack review
Task: "Review and fix my Planora project"
Files hint: `src/Api/Program.cs`, `src/Domain/Trip.cs`, `apps/web/src/app/app.component.ts`

| Stage | Result |
|---|---|
| Intent | `review` |
| Skills selected | `code-review` (keyword "review" matches [skills/code-review](../../skills/code-review/SKILL.md)), `dotnet` (`*.cs` files match [skills/dotnet](../../skills/dotnet/SKILL.md)), `angular` (`*.ts` + `apps/web` path matches [skills/angular](../../skills/angular/SKILL.md)) |
| References loaded | `code-review/references/architecture-review.md` (review + `.cs` Domain path), `dotnet/references/ddd-cqrs.md` (Domain path) |
| Delegation | Yes — backend (`*.cs`) and frontend (`*.ts`/Angular) are independent; 2 subagents |
| Delegation plan | `backend-reviewer` (scope: Api, Domain, Application; skills: code-review, dotnet) + `frontend-reviewer` (scope: apps/web; skills: code-review, angular) |
| Synthesis | Main agent merges findings, deduplicates, proposes unified next actions |

### Example B — .NET DDD backend only
Task: "Add the TripApproval aggregate to the Domain layer"
Files hint: `src/Domain/`, `src/Application/`

| Stage | Result |
|---|---|
| Intent | `implement` |
| Skills selected | `dotnet` (`*.cs` path match + keywords dotnet/domain matches [skills/dotnet](../../skills/dotnet/SKILL.md)) |
| References loaded | `dotnet/references/ddd-cqrs.md` (`**/Domain/**` path match) |
| Delegation | No — single technical area |

### Example C — Typo fix
Task: "Fix typo in README.md"
Files hint: `README.md` (referencing [README.md](../../README.md))

| Stage | Result |
|---|---|
| Intent | `small-change` (fallback — no strong match) |
| Skills selected | None |
| References loaded | None |
| Delegation | No |

### Example D — CI workflow change
Task: "Set up GitHub Actions workflow for the release pipeline"
Files hint: `.github/workflows/`

| Stage | Result |
|---|---|
| Intent | `ci` |
| Skills selected | `github-workflow` (intent `ci` matches, `.github/` path match matches [skills/github-workflow](../../skills/github-workflow/SKILL.md)) |
| References loaded | None (no `load_when` conditions met for single-area CI task) |
| Delegation | No — single technical area |

## Delegation plan shape
Below is the canonical shape of the delegation plan generated at Stage 4:

```yaml
should_delegate: true
reason: "backend (.cs, Domain) and frontend (.ts, Angular) can be reviewed independently"
subagents:
  - name: backend-reviewer
    scope: "src/Api, src/Domain, src/Application, src/Infrastructure"
    skills: [code-review, dotnet, architecture]
    intent: review
  - name: frontend-reviewer
    scope: "apps/web/src"
    skills: [code-review, angular]
    intent: review
merge_strategy: >
  Main agent synthesizes findings: deduplicates issues appearing in both reports,
  resolves conflicts, and proposes a single prioritized list of next actions.
```

## Design principles
- **Default: do less**: Load depth only when there is evidence. Do not load extra context unless signals justify it.
- **Prefer predictable rules**: Rely on deterministic, testable rules (e.g. glob matching and keyword checks) rather than speculative LLM-based intent heuristics.
- **Explainable selections**: Every selection decision must be explainable in a single, clear sentence.
- **Limit delegation**: Do not delegate small tasks, even if multiple skills match.
- **Keep skill set small**: Limit candidate skills to a maximum of 4 to save context and speed up responses.
- **Cap subagent count**: Cap concurrent subagents at 2–3 maximum to prevent excessive multi-agent overhead.
- **Summarized handbacks**: Subagents must only return summaries. The main agent remains responsible for synthesizing the final output.
- **Evolving design**: Adaptive routing rules are subject to evolution; refer to decisions logged in [DECISIONS.md](DECISIONS.md) for ADRs affecting routing behavior.
