---
name: graphql
description: >
  Use when implementing or reviewing GraphQL schemas, resolvers, mutations,
  subscriptions, dataloaders, code generation, federation, or GraphQL clients.
  Also use for GraphQL testing, performance (N+1), and schema-breaking-change analysis.
paths:
  - "**/*.graphql"
  - "**/*.gql"
  - "**/graphql.config.*"
  - "**/codegen.yml"
  - "**/codegen.yaml"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Bash(pnpm:*)"
version: "1.0.0"
---

# GraphQL Skill

## Goal
Implement correct, performant, and evolvable GraphQL APIs.
The schema is the contract — design it for consumers, not for the database.

## Quick reference

| Concept | Best practice |
|---|---|
| Schema | Design schema first, use descriptive names, avoid breaking changes |
| N+1 Problem | Always use DataLoaders for batching child entity resolution |
| Security | Disable introspection in production, enforce query depth & cost limits |
| Client | Use codegen for frontend types, use variables for dynamic inputs |
| Validation | Validate query syntax, variables, and custom scalar inputs |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)
