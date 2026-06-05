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

---

## Language choice

- **New projects / new modules**: Kotlin. Concise, null-safe, coroutines are first-class.
- **Existing Java codebase**: keep Java unless there is a clear migration plan. Don't mix 50/50.
- **Kotlin ↔ Java interop**: Kotlin calls Java seamlessly; add `@JvmStatic`, `@JvmField`, `@JvmOverloads` on Kotlin code that Java calls.

---

## Project structure (Spring Boot / Ktor layered)

```
src/
  main/
    kotlin/ (or java/)
      com.example.myapp/
        domain/           # entities, value objects, domain services — no framework
        application/      # use cases, ports (interfaces), DTOs
        infrastructure/   # JPA repos, HTTP clients, adapters
        interfaces/       # REST controllers, workers, CLI
  test/
    kotlin/ (or java/)
      unit/
      integration/
build.gradle.kts
```

Rules:
- Domain has no Spring, no JPA annotations, no HTTP — pure business logic.
- Application defines interfaces (ports) implemented by Infrastructure.
- Controllers / interfaces call application use-cases — no business logic inline.
- Put Spring `@Service`, `@Repository`, `@Component` in Infrastructure/Interfaces, never in Domain.

---

## Build tools

### Gradle (Kotlin DSL — preferred for Kotlin projects)

```kotlin
// build.gradle.kts
plugins {
    kotlin("jvm") version "2.0.21"
    kotlin("plugin.spring") version "2.0.21"
    id("org.springframework.boot") version "3.3.5"
    id("io.spring.dependency-management") version "1.1.6"
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        freeCompilerArgs.addAll("-Xjsr305=strict")   // Spring null-safety annotations
    }
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.testcontainers:postgresql")
}
```

### Maven

- Use `kotlin-maven-plugin` with `allOpen` and `noArg` plugins for Spring.
- Pin parent `spring-boot-starter-parent` to an explicit version.

---

## Kotlin idioms (mandatory)

### Null safety

- Never use `!!` on values that can realistically be null — it's a runtime crash waiting to happen.
- Use `?.let { }`, `?: throw`, or `?: return` to handle nullable paths explicitly.
- Annotate Spring-injected fields with `lateinit var` only — not for domain state.

```kotlin
// Bad
val name: String? = user.name!!   // crashes if null

// Good
val name = user.name ?: throw IllegalStateException("User ${user.id} has no name")
```

### Data classes for DTOs and value objects

```kotlin
data class CreateLeaveRequest(
    val userId: UUID,
    val start: LocalDate,
    val end: LocalDate,
    val type: LeaveType,
)
```

- Use `copy()` for non-destructive modification.
- Prefer `value class` for single-field domain primitives: `@JvmInline value class UserId(val value: UUID)`.

### Sealed classes for error / state modeling

```kotlin
sealed class LeaveResult {
    data class Approved(val leave: Leave) : LeaveResult()
    data class Rejected(val reason: String) : LeaveResult()
    data class Error(val cause: Throwable) : LeaveResult()
}

val result: LeaveResult = service.request(cmd)
when (result) {
    is LeaveResult.Approved -> respond(result.leave)
    is LeaveResult.Rejected -> badRequest(result.reason)
    is LeaveResult.Error    -> internalError(result.cause)
}
```

### Extension functions

- Use to add behavior to external types without inheritance.
- Keep them near their usage, not in a global `Extensions.kt` dumping ground.

### Coroutines (Kotlin async)

- `suspend fun` for I/O-bound work. `withContext(Dispatchers.IO)` for blocking calls.
- Don't use `GlobalScope` — use `CoroutineScope` with a lifecycle.
- Spring Boot 3: mark `@Service` methods `suspend` with `kotlinx-coroutines-reactor` on classpath.
- Prefer `Flow<T>` over reactive types (`Flux`, `Observable`) in Kotlin code.

---

## Spring Boot 3.x

### Controller

```kotlin
@RestController
@RequestMapping("/api/leaves")
class LeaveController(private val handler: RequestLeaveHandler) {

    @PostMapping
    suspend fun requestLeave(@Valid @RequestBody cmd: CreateLeaveRequest): ResponseEntity<LeaveDto> {
        val result = handler.handle(cmd)
        return ResponseEntity.status(201).body(result)
    }
}
```

- One controller per bounded context.
- Validation via `@Valid` + Bean Validation (Jakarta) on the DTO.
- Controllers return `ResponseEntity<T>` for full control, or just `T` if 200 is always correct.
- Global exception handler: `@RestControllerAdvice` mapping domain exceptions → HTTP status codes.

### Service / use-case

```kotlin
@Service
class RequestLeaveHandler(
    private val leaveRepository: LeaveRepository,
    private val userRepository: UserRepository,
) {
    @Transactional
    suspend fun handle(cmd: CreateLeaveRequest): LeaveDto {
        val user = userRepository.findById(cmd.userId)
            ?: throw NotFoundException("User ${cmd.userId} not found")
        val leave = Leave.create(user, cmd.start, cmd.end, cmd.type)
        return leaveRepository.save(leave).toDto()
    }
}
```

### Configuration

```kotlin
@ConfigurationProperties(prefix = "app")
@ConstructorBinding   // Kotlin data class — no setters needed
data class AppProperties(
    val maxLeavePerYear: Int,
    val allowedCountryCodes: List<String>,
)
```

- Never read `System.getenv()` or `@Value("${...}")` deep in domain code — inject via `@ConfigurationProperties`.

---

## JPA / Hibernate

- Map entities with `@Entity`, `@Id`, `@GeneratedValue`.
- Kotlin entities: add the `noArg` plugin (no-arg constructor required by JPA) and `allOpen` plugin.
- Use `open class` for entities in Kotlin when not using the plugin.
- `FetchType.LAZY` by default; use `@EntityGraph` or `JOIN FETCH` when eager loading is needed.
- Avoid bi-directional associations unless the relationship is actively navigated both ways.
- Migrations with Flyway or Liquibase — never `spring.jpa.hibernate.ddl-auto=create`.

```kotlin
@Entity
@Table(name = "leaves")
class Leave(
    @Id val id: UUID = UUID.randomUUID(),
    @ManyToOne(fetch = FetchType.LAZY) val user: User,
    val start: LocalDate,
    val end: LocalDate,
    @Enumerated(EnumType.STRING) val status: LeaveStatus = LeaveStatus.PENDING,
)
```

---

## Testing

### JUnit 5 + AssertJ + MockK (Kotlin) / Mockito (Java)

```kotlin
@ExtendWith(MockKExtension::class)
class RequestLeaveHandlerTest {

    @MockK lateinit var leaveRepository: LeaveRepository
    @MockK lateinit var userRepository: UserRepository
    @InjectMockKs lateinit var handler: RequestLeaveHandler

    @Test
    fun `rejects request when user has no remaining balance`() {
        // Arrange
        val user = User(id = userId, balance = 0)
        every { userRepository.findById(userId) } returns user
        val cmd = CreateLeaveRequest(userId, LocalDate.now(), LocalDate.now().plusDays(3), LeaveType.PAID)

        // Act & Assert
        assertThrows<InsufficientBalanceException> {
            runBlocking { handler.handle(cmd) }
        }
    }
}
```

- **Kotlin**: MockK (MIT) — native Kotlin mocking, supports coroutines, extension functions.
- **Java**: Mockito (`mockito-core`, MIT) — well-established, consistent.
- **Assertions**: AssertJ (Apache-2.0 — check license policy) or JUnit 5 native assertions.
- **Parametrized**: `@ParameterizedTest` + `@MethodSource` for table-driven cases.

### Integration tests (Spring Boot)

```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class LeaveApiIntegrationTest {

    @Container
    val postgres = PostgreSQLContainer("postgres:16-alpine")

    @Autowired lateinit var webTestClient: WebTestClient

    @Test
    fun `POST leave returns 201 and persists the request`() {
        webTestClient.post().uri("/api/leaves")
            .bodyValue(CreateLeaveRequest(...))
            .exchange()
            .expectStatus().isCreated
            .expectBody<LeaveDto>()
            .returnResult()
    }
}
```

- Real Postgres via Testcontainers — not H2. H2 hides real-world dialect and constraint differences.
- `WebTestClient` for reactive / async; `MockMvc` for synchronous Spring MVC.

---

## Code quality

### Kotlin

```kotlin
// detekt — static analysis
// ktlint — formatting
```

- Enforce with `detekt` (MIT) + `ktlint` (MIT). Both integrate with Gradle.
- Enable `detekt` rules: `complexity`, `naming`, `performance`, `style`.
- No `@Suppress("MaxLineLength")` just to avoid fixing code.

### Java

- `checkstyle` or `google-java-format` for formatting.
- SpotBugs for static analysis (replaces FindBugs).

---

## Package and runtime maintenance

When you notice (during any task) that Maven/Gradle dependencies or the JVM version can be updated, follow the proactive maintenance protocol — **do not apply silently**.

### Commands to detect what needs updating

```bash
# Gradle — check for dependency updates
./gradlew dependencyUpdates                # gradle-versions-plugin

# Gradle — vulnerability scan
./gradlew dependencyCheckAnalyze          # OWASP dependency-check-gradle

# Maven — check outdated
mvn versions:display-dependency-updates
mvn versions:display-plugin-updates

# Maven — vulnerability scan
mvn org.owasp:dependency-check-maven:check
```

### JVM LTS upgrade checklist

- Bump `jvmToolchain(X)` in `build.gradle.kts` (or `<java.version>` in Maven pom).
- Update CI `setup-java` action version.
- Check for removed/deprecated APIs: `jdeprscan` or `jdeps`.
- Only propose upgrades to **stable LTS releases** (LTS as of 2026: Java 21, Java 17).
- Re-run full test suite after upgrade.

---

## What NOT to do

- No `@Autowired` on fields — use constructor injection.
- No `lateinit var` for non-injected fields — initialize in the constructor or use `by lazy`.
- No `var` when `val` works — default to immutable.
- No `nullable!!` without a proof the value is never null at that point.
- No blocking I/O inside `suspend` functions without `withContext(Dispatchers.IO)`.
- No JPA `FetchType.EAGER` globally — use `@EntityGraph` for specific queries.
- No H2 for integration tests — use Testcontainers.
- No checked exceptions re-thrown as `RuntimeException` without context.
- No `System.out.println` — use SLF4J / Logback.

---

## Verification commands

```bash
# Gradle (Kotlin DSL)
./gradlew clean build
./gradlew test
./gradlew detekt
./gradlew ktlintCheck
./gradlew dependencyCheckAnalyze      # CVE scan (if plugin present)

# Maven
mvn clean verify
mvn test
mvn checkstyle:check
```

---

## Final response requirements

Always report:
- Layer of each changed file (Domain / Application / Infrastructure / Interfaces).
- Kotlin vs Java: which language was used and why.
- Tests added or updated (MockK / Mockito / Testcontainers).
- `detekt` / `ktlint` / `checkstyle` results.
- Gradle/Maven build and test results.
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.
  - Note: AssertJ is Apache-2.0 — check your project's license policy before adding.
- Any JVM or Kotlin version change.
