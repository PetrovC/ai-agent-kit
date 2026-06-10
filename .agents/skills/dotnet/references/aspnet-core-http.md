# .NET — ASP.NET Core HTTP Layer Reference

## Load when

Load this reference when:
- Task touches HTTP endpoints, routing, middleware, filters, or `Program.cs`
  wiring.
- Task text mentions minimal API, controller, middleware, ProblemDetails,
  authentication, authorization, JWT, OpenAPI, Swagger, appsettings, or
  options binding.
- Changed files match: `**/Program.cs`, `**/*Controller.cs`,
  `**/Endpoints/**`, `**/Middleware/**`, `**/appsettings*.json`.

---

## Minimal APIs vs controllers

| Use | When |
|---|---|
| **Minimal APIs** (default for new code) | Focused services, route groups per feature, handlers that delegate to the application layer. |
| **Controllers** | Existing controller codebase (consistency wins), heavy filter pipelines, model-binding edge cases you already rely on. |

Do not mix both styles for the same API surface. Structure minimal APIs as
route groups per feature, one mapping file per group:

```csharp
public static class OrderEndpoints
{
    public static IEndpointRouteBuilder MapOrders(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/orders").WithTags("Orders").RequireAuthorization();
        group.MapGet("/{id:guid}", GetOrder).WithName(nameof(GetOrder));
        group.MapPost("/", CreateOrder);
        return app;
    }

    private static async Task<Results<Ok<OrderDto>, NotFound>> GetOrder(
        Guid id, IOrderService orders, CancellationToken ct)
        => await orders.Find(id, ct) is { } order
            ? TypedResults.Ok(order.ToDto())
            : TypedResults.NotFound();
}
```

- Use `TypedResults` + `Results<T1, T2>` unions — they document the contract
  and feed OpenAPI without attributes.
- Handlers stay thin: validate, call the application layer, map the result.
  No business logic in endpoint files.

## Middleware pipeline ordering

Order in `Program.cs` is the contract. Canonical order:

```csharp
app.UseExceptionHandler();      // first: catches everything below
app.UseHsts();                  // non-dev only
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseCors();                  // after routing, before auth
app.UseRateLimiter();
app.UseAuthentication();        // who you are
app.UseAuthorization();         // what you may do — always after authentication
app.MapOrders();                // endpoints last
```

Custom middleware only for true cross-cutting concerns (correlation IDs,
tenant resolution). Prefer endpoint filters for per-route concerns:

```csharp
group.MapPost("/", CreateOrder).AddEndpointFilter<ValidationFilter<CreateOrderRequest>>();
```

## Exception handling and ProblemDetails

One global mapping — handlers and middleware must not `try/catch` per route.

```csharp
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<DomainExceptionHandler>(); // .NET 8+

public sealed class DomainExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext http, Exception ex, CancellationToken ct)
    {
        var (status, title) = ex switch
        {
            EntityNotFoundException => (StatusCodes.Status404NotFound, "Not found"),
            DomainRuleViolation     => (StatusCodes.Status422UnprocessableEntity, "Rule violated"),
            _ => (StatusCodes.Status500InternalServerError, "Unexpected error"),
        };
        http.Response.StatusCode = status;
        await http.Response.WriteAsJsonAsync(
            new ProblemDetails { Status = status, Title = title, Detail = ex.Message }, ct);
        return true;
    }
}
```

- Error contract is RFC 9457 ProblemDetails — everywhere, including
  validation (400) and auth (401/403) responses.
- Never leak stack traces or connection strings into `Detail` in production.

## Authentication and authorization

JWT bearer + policy-based authorization. Policies live in one place;
endpoints reference names, never inline rules.

```csharp
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.Authority = builder.Configuration["Auth:Authority"];
        o.TokenValidationParameters = new() { ValidateAudience = true, ValidAudience = "orders-api" };
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy("orders:write", p => p.RequireAuthenticatedUser().RequireRole("orders-admin"));

group.MapPost("/", CreateOrder).RequireAuthorization("orders:write");
```

- Secrets (authority, signing keys) come from configuration / user-secrets /
  environment — never from source.
- Default to `RequireAuthorization()` on the group and opt OUT with
  `[AllowAnonymous]`/`.AllowAnonymous()` per route, not the reverse.

## OpenAPI

- **.NET 9+**: built-in `builder.Services.AddOpenApi()` + `app.MapOpenApi()`
  (document at `/openapi/v1.json`). Swashbuckle is no longer shipped in
  templates — prefer the built-in generator for new services.
- Metadata comes from the code model: `TypedResults` unions, `.WithName()`,
  `.WithSummary()`, `.Produces<T>()` only when types cannot express it.
- Expose Swagger UI only in non-production environments.

## Configuration and options

Bind once, validate at startup, inject `IOptions<T>`:

```csharp
builder.Services.AddOptions<SmtpOptions>()
    .BindConfiguration("Smtp")
    .ValidateDataAnnotations()
    .ValidateOnStart();           // fail fast at boot, not on first use

public sealed class SmtpOptions
{
    [Required] public string Host { get; init; } = "";
    [Range(1, 65535)] public int Port { get; init; } = 587;
}
```

- `IOptions<T>` for static config, `IOptionsMonitor<T>` when hot-reload
  matters (background services). Don't inject `IConfiguration` into handlers.
- Layering: `appsettings.json` → `appsettings.{Environment}.json` →
  user-secrets (dev) → environment variables → command line. Last wins.

## Cancellation tokens

Accept a `CancellationToken` in every handler (bound automatically from
`HttpContext.RequestAborted`) and pass it all the way down — EF queries,
`HttpClient` calls, message publishes:

```csharp
private static async Task<Ok<List<OrderDto>>> ListOrders(
    IOrderService orders, CancellationToken ct)
    => TypedResults.Ok(await orders.List(ct));
```

A handler that ignores cancellation keeps burning DB/CPU for clients that
already disconnected.

## What NOT to do

- No business logic in endpoints, filters, or middleware — delegate to the
  application layer.
- No `[FromServices]` noise in minimal APIs — parameter injection is implicit.
- No per-route `try/catch` for error shaping — that is the exception
  handler's job.
- No `IConfiguration["key"]` reads scattered in handlers — bind options.
- No anonymous-by-default surfaces: groups opt IN to auth, routes opt out
  explicitly.
- No returning EF entities from endpoints — map to DTOs at the boundary.
