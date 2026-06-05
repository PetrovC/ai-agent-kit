---
name: infrastructure
description: >
  Use when modifying Dockerfiles, docker-compose files, Kubernetes
  manifests, Terraform / OpenTofu, CI/CD pipelines (GitHub Actions,
  GitLab CI, Azure Pipelines), or any infrastructure-as-code.
paths:
  - "**/Dockerfile*"
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/docker-compose*.yml"
  - "**/docker-compose*.yaml"
  - "**/k8s/**"
  - "**/helm/**"
allowed-tools:
  - "Bash(docker:*)"
  - "Bash(kubectl:*)"
  - "Bash(terraform:*)"
version: "1.0.0"
---

# Infrastructure Skill

## Goal
Reproducible, reviewable, minimal infrastructure. No magic clicks in cloud
consoles, no "works because someone SSH'd in once." If it's not in the repo,
it doesn't exist.

## Quick reference

| Tool | Best practice |
|---|---|
| Docker | Multi-stage builds, pin base images, run as non-root user |
| Terraform | Use remote state locking, separate state files by env, pin provider versions |
| CI/CD | Use secrets for API keys, run validation/linters, pin action versions |
| Security | Never commit secrets, scan containers (Trivy), use minimal base images |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)
