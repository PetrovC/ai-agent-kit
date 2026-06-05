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

---

## Schema design

### Type system rules

- **PascalCase** for types, interfaces, unions, enums (`UserProfile`, `OrderStatus`).
- **camelCase** for fields and arguments (`firstName`, `createdAt`).
- **SCREAMING_SNAKE_CASE** for enum values (`PENDING`, `IN_PROGRESS`).
- **Non-null by default** on new schemas: `String!` unless null is a meaningful state.
  On existing schemas, treat non-null as a breaking change — add nullability conservatively.
- Scalar types: use custom scalars for domain types (`Date`, `UUID`, `Email`) — never raw `String` for them.

### Prefer specific types over generics

```graphql
# Bad — caller has to know the shape
type Mutation {
  updateUser(id: ID!, data: JSON!): JSON
}

# Good — typed, discoverable, validatable
input UpdateUserInput {
  displayName: String
  avatarUrl: String
}
type UpdateUserPayload {
  user: User!
}
type Mutation {
  updateUser(id: ID!, input: UpdateUserInput!): UpdateUserPayload!
}
```

### Nullability as error signal

Return `null` only when the field is genuinely optional (e.g., an optional relationship).
For errors, use union types (see Error handling).

---

## Operations

| Operation | Purpose | Convention |
|---|---|---|
| `query` | Read data | Named, idempotent |
| `mutation` | Write / side-effect | Returns affected object, not just a boolean |
| `subscription` | Real-time push | Returns event objects, not diffs |

Every mutation **must return** at least the mutated object (never just `Boolean!`).
This lets the client update its cache without a follow-up query.

```graphql
# Bad
type Mutation { deletePost(id: ID!): Boolean! }

# Good
type Mutation { deletePost(id: ID!): DeletePostPayload! }
type DeletePostPayload { deletedId: ID! }
```

---

## Resolvers

### Structure

Resolvers are thin dispatchers — they validate inputs, call a service, and return.
**Never put business logic in a resolver.**

```typescript
// resolver (thin)
async function createOrder(_, { input }, ctx) {
  ctx.auth.requireRole("user");
  return ctx.orderService.create(ctx.userId, input);
}

// service (business logic lives here)
class OrderService {
  async create(userId: string, input: CreateOrderInput) { ... }
}
```

### Context object

Inject per-request dependencies into context — never use module-level singletons in resolvers.

```typescript
type GraphQLContext = {
  userId: string | null;
  auth: AuthService;
  loaders: DataLoaders;   // per-request DataLoader instances
  db: DatabaseClient;
};
```

---

## DataLoader — N+1 prevention

Every has-many or belongs-to relationship **must** use a DataLoader if it can be accessed
from a list context. A missing DataLoader is a correctness bug, not a performance suggestion.

```typescript
import DataLoader from "dataloader";

// Batch function: takes [userId, ...], returns [User | null, ...]
// Array positions must match input positions.
const userLoader = new DataLoader<string, User | null>(async (ids) => {
  const users = await db.users.findMany({ where: { id: { in: [...ids] } } });
  const map = new Map(users.map((u) => [u.id, u]));
  return ids.map((id) => map.get(id) ?? null);
});

// Resolver uses loader, not direct DB call
async function post_author(post, _, ctx) {
  return ctx.loaders.user.load(post.authorId);
}
```

**Rules:**
- Instantiate loaders **per request**, not per application start (share between requests = stale data).
- Always handle missing keys (return `null` or throw, never leave gaps in the batch array).
- Use `loadMany` for batch fetching in a single resolver.

---

## Pagination

### Cursor-based (Relay spec) — preferred for large or live datasets

```graphql
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}
type UserEdge { node: User!, cursor: String! }
type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
type Query {
  users(first: Int, after: String, last: Int, before: String): UserConnection!
}
```

### Offset-based — acceptable for simple, non-live lists

```graphql
type Query {
  users(limit: Int! = 20, offset: Int! = 0): UsersPage!
}
type UsersPage { items: [User!]!, total: Int! }
```

Use cursor-based when data changes during pagination (infinite scroll, real-time feeds).
Use offset when users need to jump to a specific page number (admin tables, search results).

---

## Error handling

### Unexpected errors — let them bubble

Runtime errors (DB down, unexpected exception) surface as the standard GraphQL `errors` array.
Log them server-side; return a generic message to the client.

### Domain errors — use union types

```graphql
union CreateOrderResult = Order | OutOfStockError | PaymentDeclinedError

type OutOfStockError  { message: String!, productId: ID! }
type PaymentDeclinedError { message: String!, code: String! }

type Mutation { createOrder(input: CreateOrderInput!): CreateOrderResult! }
```

Clients can use `__typename` to branch safely, and IDEs give autocomplete on error fields.
Never encode error details in a generic `{ success: Boolean, error: String }` shape.

---

## Authentication and authorization

```
AuthN → HTTP middleware (JWT / session cookie) → inject { userId, roles } into context
AuthZ → resolver or schema directive level
```

- **Never** trust a `userId` from the request body — always use the authed identity from context.
- Check authorization at the **start** of each sensitive resolver (fail fast).
- For fine-grained access: schema directives (`@auth`, `@hasRole`) or a permission service called from resolvers.
- Field-level auth for partial visibility (return `null` on fields the user can't see, document this explicitly).

```typescript
async function sensitiveData(parent, args, ctx) {
  ctx.auth.requireRole("admin");   // throws if not admin
  return ctx.service.getSensitiveData(parent.id);
}
```

---

## Code generation (TypeScript)

Use [`@graphql-codegen/cli`](https://the-guild.dev/graphql/codegen) to generate typed resolvers and client hooks from the schema.

```yaml
# codegen.yml
schema: "./src/schema.graphql"
generates:
  ./src/generated/resolvers.ts:
    plugins: ["typescript", "typescript-resolvers"]
    config: { contextType: "../context#GraphQLContext" }
  ./src/generated/client.ts:
    documents: "./src/**/*.graphql"
    plugins: ["typescript", "typescript-operations", "typescript-react-apollo"]
```

Run codegen after every schema change — treat the output as checked-in source, not a build artifact.
Add to CI: `graphql-codegen --check` to fail if the generated files are stale.

---

## Server options by stack

| Stack | Library | Style |
|---|---|---|
| Node.js | Apollo Server, [GraphQL Yoga](https://the-guild.dev/graphql/yoga-server) | SDL-first or code-first |
| Node.js (code-first) | [Pothos](https://pothos-graphql.dev/) | Code-first, type-safe |
| Python | [Strawberry](https://strawberry.rocks/), [Ariadne](https://ariadnegraphql.org/) | Code-first / SDL-first |
| Go | [gqlgen](https://gqlgen.com/) | SDL-first, fully typed |
| .NET | [Hot Chocolate](https://chillicream.com/docs/hotchocolate) | Code-first or SDL |
| Java / Kotlin | Spring GraphQL, [Netflix DGS](https://netflix.github.io/dgs/) | Annotation-driven |

---

## Testing

### Unit — resolver in isolation

```typescript
it("returns null for unknown user", async () => {
  const ctx = { loaders: { user: { load: jest.fn().mockResolvedValue(null) } } };
  const result = await resolvers.Query.user(null, { id: "unknown" }, ctx, null);
  expect(result).toBeNull();
});
```

### Integration — full schema execution

```typescript
const { body } = await apolloServer.executeOperation({
  query: `{ user(id: "1") { name } }`,
});
expect(body.singleResult.errors).toBeUndefined();
expect(body.singleResult.data?.user?.name).toBe("Alice");
```

### Schema snapshot and breaking-change detection

```bash
# Detect breaking changes between two schema versions
npx graphql-inspector diff old-schema.graphql new-schema.graphql

# Validate schema against rules
npx graphql-inspector validate schema.graphql "src/**/*.ts"
```

Add breaking-change detection to CI — a removed field or changed type is a breaking change
for all consumers, including mobile clients that can't be force-updated.

---

## What NOT to do

- No `JSON` scalar for structured data — define a real type.
- No resolver that queries the DB directly without a DataLoader when called from a list.
- No mutation returning only `Boolean!` — always return the mutated resource.
- No business logic in resolvers — services / use-cases only.
- No exposing internal IDs or implementation details in the schema surface.
- No skipping authorization on fields because "the parent was already authorized."
- No shipping a schema change without running `graphql-codegen` and checking for breaking changes.
- No polling as a substitute for subscriptions in real-time use cases.

---

## Verification

```bash
# Generate types from schema
npx graphql-codegen

# Check generated files are up to date (CI)
npx graphql-codegen --check

# Lint schema
npx @graphql-eslint/eslint-plugin

# Detect breaking changes
npx graphql-inspector diff schema.graphql new-schema.graphql

# Run resolver tests
npx jest --testPathPattern=graphql

# Go (gqlgen)
go run github.com/99designs/gqlgen generate
go test ./graph/...

# Python (strawberry)
python -m pytest tests/graphql/

# .NET (Hot Chocolate)
dotnet test --filter "Category=GraphQL"
```

---

## Final response requirements

Always report:
- Schema types added, modified, or removed — flag any **breaking changes** explicitly.
- DataLoader added/used for every has-many resolver in a list context.
- Authorization checks present on all sensitive resolvers/fields.
- Code generation re-run (`graphql-codegen`) if schema changed — confirm output is current.
- Resolver delegation: which service / use-case was called (no business logic in the resolver).
- Pagination strategy and `totalCount` availability.
- Test coverage: new resolvers/mutations have unit and/or integration tests.
