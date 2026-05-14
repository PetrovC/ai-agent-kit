# Commands

The single source of truth for build, test, lint, and run commands.

---

## Setup

```bash
# Backend
cd backend
dotnet restore

# Frontend
cd frontend
pnpm install --frozen-lockfile

# Local Postgres (for integration tests + dev)
docker compose up -d postgres
```

---

## Build

```bash
# Backend
cd backend
dotnet build --no-restore

# Frontend
cd frontend
pnpm build
```

---

## Run locally

```bash
# Backend (listens on http://localhost:5050)
cd backend/src/LeaveDesk.Api
dotnet run

# Frontend (Vite dev server on http://localhost:5173, proxies /api to 5050)
cd frontend
pnpm dev
```

---

## Test

```bash
# Backend - all
cd backend
dotnet test --no-build

# Backend - filter by module
dotnet test --filter "FullyQualifiedName~LeaveCalculation"

# Backend - integration only (slow, needs Postgres)
dotnet test backend/tests/LeaveDesk.Integration.Tests

# Frontend
cd frontend
pnpm test                       # vitest
pnpm test --coverage
pnpm test -- --reporter=verbose features/leaves
```

---

## Lint / format

```bash
# Backend
cd backend
dotnet format --verify-no-changes

# Frontend
cd frontend
pnpm lint                       # eslint
pnpm format -- --check          # prettier
pnpm tsc --noEmit               # type-check
```

---

## Database

```bash
# Create a migration
cd backend/src/LeaveDesk.Infrastructure
dotnet ef migrations add <Name> --startup-project ../LeaveDesk.Api

# Apply migrations to local dev DB
dotnet ef database update --startup-project ../LeaveDesk.Api

# Reset local DB (destructive)
docker compose down -v postgres && docker compose up -d postgres
```

---

## CI replication

To run what CI runs, locally:

```bash
# Backend
cd backend
dotnet restore
dotnet build --no-restore
dotnet test --no-build --logger trx
dotnet format --verify-no-changes

# Frontend
cd frontend
pnpm install --frozen-lockfile
pnpm tsc --noEmit
pnpm lint
pnpm test --coverage
pnpm build
```

---

## Deploy

Both services deploy on merge to `main`.

- Backend: GitHub Actions → `flyctl deploy --remote-only` (see `.github/workflows/deploy-backend.yml`).
- Frontend: Vercel autodeploys from `main`.

Manual deploy (emergency only):

```bash
# Backend
flyctl deploy --app leavedesk-api --remote-only

# Frontend
cd frontend && pnpm build && vercel deploy --prod
```
