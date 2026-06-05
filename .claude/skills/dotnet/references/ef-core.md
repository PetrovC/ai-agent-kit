# .NET — Entity Framework Core Reference

## Load when

Load this reference when:
- Task touches database queries, migrations, DbContext, repository implementations,
  or EF Core configuration.
- Changed files match: `**/Infrastructure/**`, `**/Migrations/**`,
  `**DbContext*.cs`, `**Repository*.cs`, `**EntityTypeConfiguration*.cs`.
- Task text mentions: EF Core, Entity Framework, migration, DbContext, repository,
  query, LINQ, AsNoTracking, Fluent API.

---

## Core rules

- Use repositories or query services defined in Application, implemented in Infrastructure.
- Do not leak `DbContext` into the domain or application layers.
- Migrations belong in Infrastructure.
- Use explicit configurations (`IEntityTypeConfiguration<T>`) over data annotations
  where possible.
- Avoid lazy loading unless explicitly justified and documented.
- Prefer `AsNoTracking()` for read-only queries.

## Dependency injection

- Register services with the correct lifetime: Singleton / Scoped / Transient.
- Do not capture Scoped services inside Singletons.
- Use `IOptions<T>` for configuration binding.
- Prefer constructor injection. Avoid service locator pattern.

## Migration commands

```bash
# Add a migration
dotnet ef migrations add <MigrationName> --project src/Infrastructure --startup-project src/Api

# Apply to dev database
dotnet ef database update --project src/Infrastructure --startup-project src/Api

# Generate SQL script (for review before production apply)
dotnet ef migrations script --project src/Infrastructure --startup-project src/Api
```

## Common pitfalls

- N+1 queries: use `.Include()` or explicit joins, not lazy loading.
- Missing `AsNoTracking()` on read queries causes unnecessary change tracking.
- Nullable reference types: configure correctly so EF correctly maps optional columns.
- Large migrations: always generate a SQL script and review before applying to production.
