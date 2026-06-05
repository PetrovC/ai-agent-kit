---
name: code-review
description: >
  Use when reviewing a branch, PR, diff, or implementation quality.
  Covers correctness, regression risk, security, maintainability, missing tests,
  architecture compliance, dependency changes, concurrency, data safety, and
  review comment quality.
allowed-tools:
  - "Bash(git:*)"
  - "Bash(gh:*)"
  - "Bash(rg:*)"
version: "1.0.0"
---

# Code Review Skill

## Goal
Find real problems before they reach production. Not cosmetic issues.

A good review catches: incorrect behavior, regressions, security holes, missing tests,
and architectural drift. It does not nitpick style unless style hides a real problem.

## Quick reference

| Focus | Check |
|---|---|
| Scope | Small, reviewable PRs (one concern per PR, < 200 lines preferred) |
| Security | Sanitized inputs, parameterized SQL, authorized endpoints, no committed secrets |
| Correctness | Handle async errors, prevent race conditions, check null/undefined boundary cases |
| Testing | Verify changed code is covered by automated unit/integration tests |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)
