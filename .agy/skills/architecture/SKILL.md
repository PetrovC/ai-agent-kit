---
name: architecture
description: >
  Use when a task affects module boundaries, layer dependencies, Clean Architecture,
  DDD, CQRS, Event Sourcing, service decomposition, bounded contexts, cross-cutting
  concerns, or long-term maintainability decisions.
allowed-tools:
  - "Bash(git:*)"
  - "Bash(rg:*)"
version: "1.0.0"
---

# Architecture Skill

## Goal

Protect maintainability, scalability, testability, and readability over time.

Architecture exists to serve the business. Do not introduce patterns for their own sake.
A simple, explicit design that a new developer can understand in one hour is always
preferable to a "correct" design that requires three architecture diagrams to explain.

---

## Before proposing any architectural change

Ask yourself, in order:

1. What business capability is affected?
2. What is the simplest design that preserves clear dependencies?
3. Is the proposed abstraction removing real duplication or protecting a real boundary?
4. Will a developer unfamiliar with the project understand this in 30 minutes?
5. Is this change reversible, or does it lock us in?

If you cannot clearly answer 1, 2, and 3 — simplify.

---

## Layer boundaries

```
Domain        → no external dependencies. Pure business logic and invariants.
Application   → depends on Domain only. Ports/interfaces defined here. Orchestrates use cases.
Infrastructure→ implements Application ports. DB, HTTP clients, queues, file system.
Interfaces    → depends on Application only. HTTP controllers, CLI, gRPC. No business logic.
```

These rules are non-negotiable unless the project explicitly documents an exception
with a justification in `docs/ai/DECISIONS.md`.

**Common violations to reject:**
- ORM entities / `DbContext` directly in Domain handlers.
- HTTP status codes or request/response types in Application layer.
- `IConfiguration` injected into Domain services.
- Business logic in controllers or route handlers.

---

## When to use each pattern

| Situation | Use |
|---|---|
| Simple CRUD with light business rules | Layered architecture, thin domain model |
| Read/write models genuinely diverge | CQRS |
| Other parts of the system react to state changes | Domain events |
| The history of state changes is itself a product requirement | Event Sourcing |
| Independent business capability, separate deployability | Microservice / bounded context |
| Shared data, shared team, no strong reason to split | **Modular monolith** (default) |

Default: **modular monolith** until there is a concrete, demonstrated reason to split.
Do not introduce microservices, event sourcing, or message buses because they are "modern."

---

## DDD — Domain-Driven Design

Use DDD when the domain has **real complexity** (non-trivial rules, invariants that change).
Do not create Entities and Aggregates for simple CRUD tables.

### Entities vs Value Objects

```typescript
// Entity — has identity, owns its invariants
class Order {
  private readonly _id: OrderId;
  private _items: OrderItem[] = [];
  private _status: OrderStatus = OrderStatus.PENDING;
  private _events: DomainEvent[] = [];

  addItem(productId: ProductId, qty: number, price: Money): void {
    if (this._status !== OrderStatus.PENDING)
      throw new DomainError("Cannot modify a non-pending order");
    if (this._items.length >= 20)
      throw new DomainError("Order cannot exceed 20 items");
    this._items.push(new OrderItem(productId, qty, price));
    this._events.push(new ItemAdded(this._id, productId, qty));
  }

  get domainEvents(): DomainEvent[] { return [...this._events]; }
  clearEvents(): void { this._events = []; }
}

// Value Object — immutable, equality by value, no identity
class Money {
  constructor(readonly amount: number, readonly currency: string) {
    if (amount < 0) throw new DomainError("Amount cannot be negative");
    Object.freeze(this);
  }
  add(other: Money): Money {
    if (this.currency !== other.currency) throw new DomainError("Currency mismatch");
    return new Money(this.amount + other.amount, this.currency);
  }
  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }
}
```

### Aggregate rules

- One **repository per aggregate root**. Never query a child entity directly.
- Aggregate boundary = consistency boundary. Everything inside is always consistent.
- Cross-aggregate communication via **domain events** (async) or **application services** (sync, with care).
- Keep aggregates **small**. If an aggregate has >5 entities, it is probably too large.

### Domain events

```typescript
// Raise in the aggregate, dispatch in the application layer
class OrderPlaced implements DomainEvent {
  constructor(
    readonly orderId: OrderId,
    readonly customerId: CustomerId,
    readonly total: Money,
    readonly occurredAt: Date = new Date()
  ) {}
}

// Application layer dispatches after saving
class PlaceOrderHandler {
  async handle(cmd: PlaceOrderCommand): Promise<OrderId> {
    const order = Order.place(cmd.customerId, cmd.items);
    await this.orders.save(order);
    await this.bus.publishAll(order.domainEvents); // dispatch AFTER save
    order.clearEvents();
    return order.id;
  }
}
```

---

## CQRS — Command Query Responsibility Segregation

Apply CQRS when **read models and write models genuinely diverge** — e.g., a write model
enforces complex invariants but reads are aggregated views across many entities.

**Do NOT** introduce CQRS just to "follow clean architecture." It adds two code paths.

```typescript
// ── Write side ───────────────────────────────────────────────────────────
// Command: intent to change state
class ShipOrderCommand {
  constructor(readonly orderId: string, readonly trackingNumber: string) {}
}

// Handler: loads aggregate, applies business rule, saves, dispatches events
class ShipOrderHandler {
  async handle(cmd: ShipOrderCommand): Promise<void> {
    const order = await this.orders.findById(cmd.orderId);
    order.ship(cmd.trackingNumber);   // enforces "can only ship confirmed orders"
    await this.orders.save(order);
    await this.bus.publishAll(order.domainEvents);
  }
}

// ── Read side ────────────────────────────────────────────────────────────
// Query: pure data retrieval, bypasses the domain model entirely
class GetOrderDashboardQuery {
  constructor(readonly customerId: string, readonly limit: number) {}
}

class GetOrderDashboardHandler {
  async handle(q: GetOrderDashboardQuery): Promise<OrderSummaryDto[]> {
    // Direct SQL / view query — no domain objects, no invariants
    return this.readDb.query(`
      SELECT o.id, o.status, o.created_at, COUNT(i.id) as item_count,
             SUM(i.price_amount) as total
      FROM orders o
      JOIN order_items i ON i.order_id = o.id
      WHERE o.customer_id = $1
      ORDER BY o.created_at DESC
      LIMIT $2
    `, [q.customerId, q.limit]);
  }
}
```

---

## Hexagonal Architecture — Ports & Adapters

The Application layer defines **ports** (interfaces); Infrastructure provides **adapters** (implementations).
This makes business logic testable without real DBs, queues, or HTTP clients.

```typescript
// Port — defined in Application layer
interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}

interface EmailService {
  sendShipmentNotification(to: string, trackingNumber: string): Promise<void>;
}

// Adapters — defined in Infrastructure layer
class PostgresOrderRepository implements OrderRepository {
  async findById(id: OrderId): Promise<Order | null> { /* EF Core / Drizzle / Prisma */ }
  async save(order: Order): Promise<void> { /* persist + publish outbox events */ }
}

class SendGridEmailService implements EmailService {
  async sendShipmentNotification(to: string, trackingNumber: string) { /* SendGrid SDK */ }
}

// Test — swap real adapters for fakes
class InMemoryOrderRepository implements OrderRepository {
  private store = new Map<string, Order>();
  async findById(id: OrderId) { return this.store.get(id.value) ?? null; }
  async save(order: Order) { this.store.set(order.id.value, order); }
}
```

The Application layer is **always tested with fake adapters**. Integration tests use real ones.

---

## Modular monolith

Prefer a modular monolith over microservices until you have:
- Genuinely independent deployment requirements.
- Separate team ownership of a module.
- Vastly different scaling requirements per module.

### Module rules

```
modules/
  orders/
    domain/         # Order, OrderItem, OrderId, Money
    application/    # PlaceOrderHandler, ShipOrderHandler, IOrderRepository
    infrastructure/ # PostgresOrderRepository, OrderController
  catalog/
    domain/
    ...
```

- Modules communicate **only via public interfaces or events** — never by importing each other's internal types.
- Cross-module queries go through a public read model, not a shared ORM entity.
- A module's database tables are **private** to that module. Other modules query via API or event.

---

## Bounded contexts

When the project uses multiple bounded contexts:
- Each context has its own model — do **not** share domain entities across contexts.
- Use explicit contracts (DTOs, integration events, anti-corruption layers) at the boundary.
- An anti-corruption layer translates the upstream model so it does not leak into your context.
- Document each context in `docs/ai/ARCHITECTURE.md`.

---

## Decision rule for abstractions

Add an abstraction only when one of these is true:
- It removes **real, stable** duplication (not speculative).
- It protects a **meaningful boundary** (infrastructure behind a port).
- It measurably improves **testability** of business logic.

Do not add base classes, generic helpers, or extension methods speculatively.
Three similar functions are better than a premature abstraction.

---

## Verification

After any architectural change:
- Read `docs/ai/ARCHITECTURE.md` — confirm it still describes the system; update if not.
- Read `docs/ai/DECISIONS.md` — add an ADR entry if this is a new architecture decision.
- Check that no new cross-layer dependency was introduced without a matching port/interface.
- Confirm the change is covered by at least one integration test (or document why not).

---

## Final response requirements

When proposing an architecture change, always structure your response as:

1. **Business capability affected** — what problem does this solve?
2. **Current state** — what is the existing design?
3. **Proposed change** — what changes and why?
4. **Layers affected** — which boundaries are touched?
5. **Dependencies introduced or removed** — what now depends on what?
6. **Why this is not over-engineered** — justify the complexity.
7. **Reversibility** — how hard is it to undo if wrong?
8. **Validation approach** — how do we know it works?
