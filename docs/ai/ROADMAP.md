# Roadmap

This roadmap is agent-facing. GitHub Issues remain the detailed task tracker.
Every planned implementation below requires a dedicated issue before code or
script changes begin, and every implementation must be delivered through a PR.

The roadmap should guide future work without causing documentation PRs to grow
into feature implementation.

## Current State

The repository is healthy and still respects its core mission. It is already
usable for personal and private projects as a reusable multi-agent configurator.
The largest maturity gaps are public-release hygiene, diagnostics, isolated
script tests, validation depth, security posture documentation, and optional
adapter maturity.

## Now

Focus on stabilizing the kit for public consumption:

- keep `docs/ai/` official, complete, and tracked in this repository;
- add a root `LICENSE` matching the Claude plugin MIT metadata;
- add `SECURITY.md` because the kit ships security-relevant hooks;
- add `CONTRIBUTING.md` for external maintainability;
- add a root `VERSION` file as the future single source of truth for scripts,
  plugin metadata, extension metadata, and release notes;
- create GitHub Releases and release tags so users can pin versions;
- add a release checklist;
- clarify public onboarding and installation expectations.

## Next

Improve confidence in lifecycle behavior and target project health:

- strengthen `validate` checks without broad script rewrites;
- add `doctor.sh` and `doctor.ps1` to diagnose target project installation
  health;
- add BATS tests for Bash helpers;
- add Pester tests for PowerShell helpers;
- add Bash/PowerShell parity CI;
- add router parity CI across Claude, Codex, and Antigravity route files;
- clarify shared skills versus tool-specific metadata;
- continue improving Windows hook guidance, especially for Bash-installed or
  manually edited hook commands;
- add stronger checks that project-owned files are not overwritten.

## Later

These ideas are valuable, but should wait until the core is more stable:

- threat model for hooks, MCP examples, and install/update behavior;
- MCP supply-chain pinning or warnings;
- OpenSSF Scorecard;
- signed manifests or checksums;
- skill-level version metadata;
- skill evals, likely not required CI at first;
- init wizard or stack presets;
- optional Antigravity wrapper experiment;
- minimal and full install profiles;
- context sanitization scripts for logs and documents;
- shared context, subagent, MCP, and model-routing governance as installable
  assets.

## Explicitly Out Of Scope

- full orchestration platform;
- hosted SaaS;
- dependency update bot;
- model proxy;
- cost dashboard;
- IDE plugin;
- security sandbox;
- project architecture generator;
- replacing human PR review.

## Issue Requirement

For every planned improvement:

- create or link a dedicated GitHub issue before implementation;
- define problem, scope, acceptance criteria, and out-of-scope items;
- use one concern per issue;
- implement through a dedicated branch and PR;
- do not mix unrelated roadmap items in one PR.
