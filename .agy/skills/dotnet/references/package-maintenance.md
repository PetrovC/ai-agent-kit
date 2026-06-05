# .NET — Package and Runtime Maintenance Reference

## Load when

Load this reference when:
- Task involves NuGet package updates, .NET runtime version upgrades, or
  vulnerability remediation.
- Task text mentions: package, NuGet, upgrade, outdated, CVE, vulnerability,
  dotnet list package, global.json, TargetFramework.

---

## Protocol

Never update packages silently. Always follow this protocol:

1. **Surface explicitly** — list what can be updated and why (security patch,
   bug fix, LTS upgrade, outdated minor).
2. **Wait for approval** — do not touch anything until the user confirms.
3. **Apply one package at a time** — run `dotnet restore && dotnet build &&
   dotnet test` after each update.
4. **Report** — which versions changed, whether tests pass, any breaking changes.

## Detection commands

```bash
# Packages with available updates
dotnet list package --outdated

# Packages with known vulnerabilities
dotnet list package --vulnerable --include-transitive

# Installed .NET SDKs
dotnet --list-sdks

# Installed .NET runtimes
dotnet --list-runtimes
```

## .NET runtime upgrade checklist

- Bump `<TargetFramework>` in every `.csproj` (e.g., `net8.0` → `net9.0`).
- Update `global.json` `sdk.version` if present.
- Run `dotnet build` and fix compiler warnings from the new TFM.
- Check [the official migration guide](https://learn.microsoft.com/en-us/dotnet/core/compatibility/).
- Only propose upgrades to **stable LTS releases** unless explicitly asked.
- Verify NuGet packages are compatible with the new TFM before proposing the upgrade.
