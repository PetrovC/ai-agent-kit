---
name: java-kotlin
description: >
  Use when modifying Java or Kotlin code: Spring Boot, Quarkus, Ktor,
  Kotlin coroutines, JPA/Hibernate, JUnit 5, Gradle/Maven, Android (Kotlin),
  or any JVM backend / service structure.
paths:
  - "**/*.java"
  - "**/*.kt"
  - "**/*.kts"
  - "**/build.gradle"
  - "**/build.gradle.kts"
  - "**/pom.xml"
  - "**/settings.gradle*"
allowed-tools:
  - "Bash(./gradlew:*)"
  - "Bash(mvn:*)"
version: "1.0.0"
---

# Java / Kotlin Skill

## Goal
Clean, layered, type-safe JVM code. Kotlin is the modern default for new code;
Java is supported for existing codebases. No mutable shared state, no `null`
surprises, no anemic domain models. A junior should trace a request end-to-end.

## Quick reference

| Concept | Best practice |
|---|---|
| Language | Use records/pattern matching (Java) and data classes/coroutines (Kotlin) |
| Framework | Spring Boot (constructor injection, `@RestController`, `@Transactional`) |
| Concurrency | Use virtual threads (Java 21+) or Kotlin structured concurrency |
| Validation | Use Jakarta Validation (`@NotNull`, `@Size`) and standard exception handlers |
| Key commands | `./gradlew bootRun`, `./gradlew test`, `./gradlew lintKotlin` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)
