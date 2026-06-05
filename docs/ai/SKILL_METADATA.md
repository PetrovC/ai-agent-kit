# Skill Metadata Schema

Skills in the `ai-agent-kit` are documented in `SKILL.md` files located under `skills/<name>/`. Each skill file must contain a YAML frontmatter block defining its metadata schema to enable routing and execution.

## Frontmatter Fields

### Required/Standard Fields
- `name` (string): Unique identifier for the skill.
- `description` (string): Brief summary of what the skill does, used for tool routing.
- `paths` (list of strings): Glob patterns representing file types or locations relevant to this skill.
- `allowed-tools` (list of strings): Allowed MCP/system tool patterns for the skill runtime.
- `version` (string): SemVer version of the skill definition.

### Optional/New Metadata Fields
- `keywords` (list of strings): Lowercase keywords matched against task text to help select/activate this skill.
- `task_intents` (list of strings): List of intent labels indicating task types where this skill is relevant. Valid values:
  - `review`
  - `implement`
  - `fix`
  - `refactor`
  - `docs`
  - `ci`
  - `security`
  - `data-migration`
  - `small-change`
- `delegation_hints` (object): Options guiding subagent delegation:
  - `can_delegate` (boolean): `true` or `false` indicating if the skill's scope is delegatable to subagents.
  - `when` (string): Freetext explanation/condition for when delegation is recommended.

---

## The References Pattern

To avoid context-window bloat, large skills must be split into a short router (`SKILL.md`) and dedicated files in a `references/` subdirectory.

- **Purpose**: Lazy-load detailed, context-specific guidance only when task signals justify it.
- **Reference Structure**: Each file under `references/*.md` must begin with a `## Load when` section specifying the precise conditions under which it should be read.

---

## Annotated Example

Below is the frontmatter configuration for the `dotnet` skill:

```yaml
---
name: dotnet
description: >
  Use when modifying C#, .NET, ASP.NET Core, Entity Framework Core, xUnit,
  backend services, dependency injection, CQRS handlers, domain logic,
  application layer, or any backend project structure.
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/*.sln"
  - "**/global.json"
allowed-tools:
  - "Bash(dotnet:*)"
version: "1.0.0"
keywords:
  - dotnet
  - csharp
  - c#
  - asp.net
  - aspnet
  - entity framework
  - ef core
  - xunit
  - mediatr
  - ddd
  - cqrs
task_intents:
  - implement
  - review
  - fix
  - refactor
  - data-migration
delegation_hints:
  can_delegate: true
  when: >
    When the task also involves a frontend (Angular, Vue, React) — delegate
    backend to a focused subagent.
---
```
