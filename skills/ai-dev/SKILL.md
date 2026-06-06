---
name: ai-dev
description: >
  Use when building applications that call LLMs (Claude, OpenAI, Mistral,
  open-weights): prompt engineering, prompt caching, tool use / function
  calling, structured outputs, RAG, embeddings, vector stores, agentic
  workflows, evals, cost / latency optimization.
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Bash(python:*)"
  - "Bash(python3:*)"
  - "Bash(uv:*)"
  - "Bash(pip:*)"
version: "1.0.0"
---

# AI Development Skill

## Goal
LLM-powered apps that are correct, cost-aware, observable, and testable.
Treat the LLM like any other external dependency: typed inputs / outputs,
retries, timeouts, evals, prompt versioning.

## Quick reference

| Concept | Best practice |
|---|---|
| Caching | Order prompt stable -> volatile; cache tool definitions & system prompts |
| Outputs | Use tool calling / JSON mode with schemas for structured data |
| RAG | Chunk 500-1500 tokens, embed, store, retrieve top-k, and run reranking |
| Evals | Test with input -> expected behavior sets (50-500 cases), not snapshots |
| Latency | Cascade to smaller models (Haiku/3.5-mini), stream for chat UIs |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)
