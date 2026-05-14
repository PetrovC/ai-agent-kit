# Commands

> ⚠️ **STOP — Fill this file before letting any agent read it.**
> If commands are wrong or missing, the agent will guess and the first build/test run will fail.
> Once filled, remove this notice.

> The single source of truth for all build, test, lint, and run commands.
> AI agents read this file to know which commands to use for verification.

---

## Setup

```bash
# Install dependencies
dotnet restore
npm install
```

---

## Build

```bash
dotnet build
npm run build
```

---

## Run (local development)

```bash
dotnet run --project src/Web
npm run dev
```

---

## Tests

```bash
# All tests
dotnet test

# Filtered by project
dotnet test tests/Domain.Tests
dotnet test tests/Application.Tests

# Filtered by name
dotnet test --filter "FullyQualifiedName~LeaveCalculation"

# With output
dotnet test --logger "console;verbosity=detailed"

# Frontend tests
npm test
npm run test:watch
```

---

## Lint / format

```bash
dotnet format --verify-no-changes
npm run lint
npm run type-check
```

---

## Database

```bash
# List migrations
dotnet ef migrations list

# Add migration
dotnet ef migrations add <MigrationName> --project src/Infrastructure

# Generate SQL script (review before applying)
dotnet ef migrations script --idempotent

# Apply migrations
dotnet ef database update
```

---

## CI equivalent (what must pass before merge)

```bash
dotnet restore
dotnet build --no-restore
dotnet test --no-build
dotnet format --verify-no-changes
npm run build
npm test
npm run lint
```
