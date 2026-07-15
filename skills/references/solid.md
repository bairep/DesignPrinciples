# SOLID Principles

The five class-level design principles from Robert C. Martin's "Principles of OOD" — each one a dependency-management tool, with explicit guidance on when to skip it.

Martin's stated purpose for these principles is managing dependencies between modules, not conceptual purity. They exist to fight the four symptoms of rotting design: **rigidity** (every change forces more changes), **fragility** (changes break unrelated things), **immobility** (nothing can be reused elsewhere), and **viscosity** (doing it right is harder than hacking). Treat each principle as a graded ideal you apply against *changes that actually recur* — not a binary rule.

## Contents

- [Single Responsibility (SRP)](#single-responsibility-srp)
- [Open-Closed (OCP)](#open-closed-ocp)
- [Liskov Substitution (LSP)](#liskov-substitution-lsp)
- [Interface Segregation (ISP)](#interface-segregation-isp)
- [Dependency Inversion (DIP)](#dependency-inversion-dip)
- [Sources](#sources)

---

## Single Responsibility (SRP)

**Canonical statement:** "A class should have one, and only one, reason to change" — Robert C. Martin, Principles of OOD (2000)

**What it protects:** The change axis per actor — a module answers to exactly one stakeholder, so one group's change request never breaks another group's code.

SRP is about *actors*, not verbs. A "reason to change" is a person or department that requests changes: accounting changes tax rules, ops changes the schema, sales changes the email template. "Does one thing" is the folklore misreading — a class can do several things and still have one reason to change, if all of them answer to the same actor.

**Use when:**
- Two different stakeholders keep requesting changes to the same module (tax rules and persistence schema both land in `Invoice`).
- A diff for one concern forces re-review and re-test of an unrelated concern.
- Merge conflicts cluster in one "god" class touched by every team.

**Skip when:**
- Only one actor exists. A small script or a CRUD endpoint with a single owner gains nothing from being split three ways.
- You are splitting by verb ("calculator", "validator", "formatter") without a second stakeholder — that is speculative structure, not SRP.
- The concerns always change together. Separating things that co-change violates cohesion and just adds file-hopping.

**Trade-off:** You pay in more classes and the plumbing to connect them; you buy the ability for each actor's changes to ship without retesting the others' code. If the actors never diverge, you paid for nothing.

**Smell that calls for it:** This week's tax-rule change touches the same class as last week's schema migration.
**Smell of overuse:** A cloud of one-method classes where no second stakeholder has ever appeared.

### Don't

```typescript
// One class serves three actors: accounting (tax), ops (schema), sales (email).
// Any of them changing forces re-testing all of it.
interface Database {
  execute(sql: string, params: readonly unknown[]): Promise<void>;
}

class Invoice {
  constructor(
    private readonly lines: ReadonlyArray<{ amount: number; taxable: boolean }>,
  ) {}

  total(): number {
    const net = this.lines.reduce((sum, l) => sum + l.amount, 0);
    const tax = this.lines
      .filter((l) => l.taxable)
      .reduce((sum, l) => sum + l.amount * 0.21, 0);
    return net + tax;
  }

  save(db: Database): Promise<void> {
    return db.execute('INSERT INTO invoices (payload) VALUES (?)', [
      JSON.stringify(this.lines),
    ]);
  }

  toCustomerEmailHtml(): string {
    const rows = this.lines.map((l) => `<tr><td>${l.amount}</td></tr>`);
    return `<table>${rows.join('')}</table>`;
  }
}
```

### Do

```typescript
type InvoiceLine = { readonly amount: number; readonly taxable: boolean };

// Changes with accounting.
function invoiceTotal(lines: readonly InvoiceLine[], taxRate: number): number {
  const net = lines.reduce((sum, l) => sum + l.amount, 0);
  const tax = lines
    .filter((l) => l.taxable)
    .reduce((sum, l) => sum + l.amount * taxRate, 0);
  return net + tax;
}

// Changes with ops.
class InvoiceRepository {
  constructor(private readonly db: Database) {}

  save(lines: readonly InvoiceLine[]): Promise<void> {
    return this.db.execute('INSERT INTO invoices (payload) VALUES (?)', [
      JSON.stringify(lines),
    ]);
  }
}

// Changes with sales.
function renderInvoiceEmail(lines: readonly InvoiceLine[]): string {
  const rows = lines.map((l) => `<tr><td>${l.amount}</td></tr>`);
  return `<table>${rows.join('')}</table>`;
}
```

---

## Open-Closed (OCP)

**Canonical statement:** "You should be able to extend a classes behavior, without modifying it" (sic) — Robert C. Martin, Principles of OOD (2000)

**What it protects:** Shipped, tested code — new variants arrive as new modules instead of edits to old ones, so existing behavior cannot regress.

Martin himself softened this one: full compliance is an *ideal*, and "even partial OCP compliance can make dramatic improvements." The working rule is: take the hit the first time a variation axis proves real (the second or third variant), then close the module against *that* axis. Closing against changes you merely imagine is speculative generality.

**Use when:**
- The same `switch`/`if` chain gets a new arm every sprint — the variation axis has proven itself.
- Third parties or other teams need to add variants without touching (or even seeing) your source.
- Modifying the shared module means an expensive re-certification or redeploy of everything that uses it.

**Skip when:**
- The case list is genuinely closed (order states, card suits, HTTP methods) — a union type with an exhaustive `switch` is *better*, because the compiler flags every unhandled case.
- You have one variant and a guess about a second. Wait for the guess to come true.
- The "extension point" would have exactly one implementation forever.

**Trade-off:** You pay an abstraction layer plus registration/dispatch indirection, and you lose compiler-checked exhaustiveness; you buy adding variants with zero edits to shipped code. Closed unions buy the opposite — pick per axis, deliberately.

**Smell that calls for it:** Every new business requirement reopens the same function and its test file.
**Smell of overuse:** Plugin registries, hooks, and abstract base classes with a single implementation and no second variant on the horizon.

### Don't

```typescript
type Row = { readonly id: string; readonly name: string };

// Every new format reopens this function — a modification magnet.
// Each edit risks the formats that already worked.
function exportReport(rows: readonly Row[], format: 'csv' | 'json' | 'xml'): string {
  switch (format) {
    case 'csv':
      return rows.map((r) => `${r.id},${r.name}`).join('\n');
    case 'json':
      return JSON.stringify(rows);
    case 'xml': {
      const items = rows.map((r) => `<row id="${r.id}">${r.name}</row>`);
      return `<rows>${items.join('')}</rows>`;
    }
  }
}
```

### Do

```typescript
type Row = { readonly id: string; readonly name: string };

interface ReportExporter {
  readonly format: string;
  export(rows: readonly Row[]): string;
}

const csvExporter: ReportExporter = {
  format: 'csv',
  export: (rows) => rows.map((r) => `${r.id},${r.name}`).join('\n'),
};

const jsonExporter: ReportExporter = {
  format: 'json',
  export: (rows) => JSON.stringify(rows),
};

// New formats are new modules that register themselves.
// This service never changes again.
class ReportService {
  private readonly exporters = new Map<string, ReportExporter>();

  register(exporter: ReportExporter): void { this.exporters.set(exporter.format, exporter); }

  export(rows: readonly Row[], format: string): string {
    const exporter = this.exporters.get(format);
    if (!exporter) throw new Error(`no exporter registered for "${format}"`);
    return exporter.export(rows);
  }
}
```

**Idiomatic TS:** When the variant list is stable, prefer a discriminated union and an exhaustive `switch` with a `never` check — the compiler then *forces* every arm to be handled. OCP and exhaustiveness-checking are opposing trades on the same axis; choose which failure mode you'd rather have.

---

## Liskov Substitution (LSP)

**Canonical statement:** "Derived classes must be substitutable for their base classes" — Robert C. Martin, Principles of OOD (2000)

**What it protects:** The behavioral contract of a type — callers written against the base type keep working no matter which subtype shows up at runtime.

Substitutability is about *behavior*, not method signatures. A subtype that compiles but strengthens preconditions, weakens postconditions, or throws where the base type promised success is a lie the compiler can't catch. The classic tell: a subtype that "supports" an operation by throwing.

**Use when:**
- Always — LSP is the one SOLID principle that is never optional once you have subtyping. Every subtype, `implements`, and mock must honor the full contract of what it substitutes for.
- Designing a hierarchy: state the contract (what callers may assume) before writing the second subtype.
- Writing test doubles — a fake that violates the real implementation's contract makes tests pass and production fail.

**Skip when:**
- You are tempted to *satisfy* it by contorting a hierarchy. Don't force is-a where it isn't: split the type instead (see the fix below) or use composition.
- There is no subtyping. Standalone functions and concrete types with no substitution have no LSP obligations.

**Trade-off:** You pay a real design constraint — subtypes cannot narrow what the base type promises, which sometimes means splitting a type in two; you buy the entire point of polymorphism: callers that never inspect which variant they got.

**Smell that calls for it:** Callers do `instanceof` checks before calling a method, or a subtype overrides a method to `throw new Error('not supported')`.
**Smell of overuse:** Deep inheritance towers built to preserve substitutability where separate types plus composition would be simpler.

### Don't

```typescript
class SettingsStore {
  private readonly values = new Map<string, string>();

  get(key: string): string | undefined {
    return this.values.get(key);
  }

  set(key: string, value: string): void {
    this.values.set(key, value);
  }
}

// Narrows the contract: the type says "writable", the behavior says "sometimes".
class ReadOnlySettingsStore extends SettingsStore {
  override set(_key: string, _value: string): never {
    throw new Error('store is read-only');
  }
}

// Compiles fine. Blows up at runtime when handed the read-only subtype.
function applyDefaults(store: SettingsStore): void {
  if (store.get('theme') === undefined) store.set('theme', 'dark');
}
```

### Do

```typescript
// Split the contract so no type promises more than every implementation delivers.
interface ReadableSettings {
  get(key: string): string | undefined;
}

interface WritableSettings extends ReadableSettings {
  set(key: string, value: string): void;
}

class InMemorySettings implements WritableSettings {
  private readonly values = new Map<string, string>();

  get(key: string): string | undefined {
    return this.values.get(key);
  }

  set(key: string, value: string): void {
    this.values.set(key, value);
  }
}

class EnvSettings implements ReadableSettings {
  get(key: string): string | undefined { return process.env[key]; }
}

// The signature states what it needs; read-only stores simply don't type-check here.
function applyDefaults(store: WritableSettings): void {
  if (store.get('theme') === undefined) store.set('theme', 'dark');
}
```

---

## Interface Segregation (ISP)

**Canonical statement:** "Make fine grained interfaces that are client specific" — Robert C. Martin, Principles of OOD (2000)

**What it protects:** Clients from dependencies they don't use — nobody is forced to depend on (implement, stub, or recompile against) methods they never call.

The unit of design is the *client's* need, not the provider's capability list. A fat interface couples every consumer to every capability: change the sampling API and the checkout flow's test doubles break, even though checkout never touched sampling.

**Use when:**
- Implementations (especially test doubles) stub methods with `throw` or no-ops just to satisfy the type.
- Distinct consumer groups use disjoint slices of one interface — recording events vs. administering the pipeline.
- A change to one capability forces recompiles/retests of consumers that never use it.

**Skip when:**
- The interface is already small and cohesive — splitting a 2-method interface is dust, not design.
- All clients genuinely use the whole surface.
- You're pre-splitting for imagined future clients. Segregate when the second kind of client *arrives*.

**Trade-off:** You pay more named interfaces to maintain and compose; you buy honest signatures (a function declares exactly what it uses) and change isolation per capability. Over-split and you get interface dust nobody can navigate.

**Smell that calls for it:** `implements` blocks full of `throw new Error('not supported')`, or importing a giant client type to call one method.
**Smell of overuse:** Dozens of one-method interfaces with one implementer and one caller each — segregation no client asked for.

### Don't

```typescript
// One fat contract: every consumer sees, and every implementation must
// supply, all five capabilities.
interface Telemetry {
  trackEvent(name: string, props: Record<string, string>): void;
  trackError(error: Error): void;
  flush(): Promise<void>;
  setSampling(rate: number): void;
  exportDashboard(dashboardId: string): Promise<Uint8Array>;
}

// A test double forced to stub methods the code under test never calls.
class NoopTelemetry implements Telemetry {
  trackEvent(): void {}
  trackError(): void {}
  flush(): Promise<void> { return Promise.resolve(); }
  setSampling(): void { throw new Error('not supported in tests'); }
  exportDashboard(): Promise<Uint8Array> { throw new Error('not supported in tests'); }
}
```

### Do

```typescript
// Sliced by client need, not provider capability.
interface EventSink {
  trackEvent(name: string, props: Record<string, string>): void;
  trackError(error: Error): void;
}

interface TelemetryAdmin {
  flush(): Promise<void>;
  setSampling(rate: number): void;
}

// Checkout records events; it cannot even name flush or sampling.
class CheckoutFlow {
  constructor(private readonly telemetry: EventSink) {}

  complete(orderId: string): void {
    this.telemetry.trackEvent('checkout_completed', { orderId });
  }
}

// One concrete provider may implement several slices;
// each client still depends only on its own.
class ProductionTelemetry implements EventSink, TelemetryAdmin {
  trackEvent(name: string, props: Record<string, string>): void { /* enqueue */ }
  trackError(error: Error): void { /* enqueue */ }
  flush(): Promise<void> { return Promise.resolve(); }
  setSampling(rate: number): void { /* adjust */ }
}
```

**Idiomatic TS:** Structural typing makes ISP nearly free. A client can declare the exact shape it consumes inline — `fn(t: Pick<Telemetry, 'trackEvent'>)` or `{ trackEvent(name: string, props: Record<string, string>): void }` — and any object with those members satisfies it, no `implements` declaration required. Segregate at the point of *use* first; only name shared interfaces once several clients need the same slice.

---

## Dependency Inversion (DIP)

**Canonical statement:** "Depend on abstractions, not on concretions" — Robert C. Martin, Principles of OOD (2000)

**What it protects:** High-level policy from volatile low-level detail — the direction of source dependencies is inverted so business rules never import vendors, databases, or transports.

The inversion is about *ownership*: the high-level module defines the interface it needs (a port, named in domain terms), and the low-level detail implements it. Martin's own carve-out matters just as much: applying DIP blanket-fashion is "draconian." Depending directly on concrete but **non-volatile** modules — the standard library, stable platform APIs — is legitimate, because they inject no volatility. Invert against things that *change or get swapped*: vendors, databases, message brokers, the clock, the network.

**Use when:**
- Business logic imports a vendor SDK, ORM, or HTTP client directly — the most volatile code in the system.
- Unit tests need live credentials, networks, or containers because the policy constructs its own dependencies.
- You foresee (or already face) swapping the detail: a second payment provider, a database migration.

**Skip when:**
- The dependency is stable and universal — don't wrap `JSON`, `Math`, `path`, or `crypto` in a port. That's Martin's own exception.
- The "abstraction" would mirror one concrete implementation method-for-method, forever. An interface with one permanent implementer is ceremony.
- Scripts and glue code at the edge of the system, whose whole job *is* to touch the concrete thing.

**Trade-off:** You pay one port + one adapter per volatile dependency, plus wiring at the composition root; you buy testable policy (fakes instead of live services) and swappable details. Spent on a stable dependency, the same indirection buys nothing.

**Smell that calls for it:** `import Stripe from 'stripe'` inside a file that also decides business rules; tests that hit real networks.
**Smell of overuse:** Ports wrapping the standard library, and interfaces whose only implementation is a pass-through.

### Don't

```typescript
import { StripeClient } from './vendor/stripe';

// High-level checkout policy welded to the most volatile code in the system.
// Testing this class means talking to Stripe.
class CheckoutService {
  private readonly stripe = new StripeClient(process.env.STRIPE_KEY ?? '');

  async payOrder(orderId: string, amountCents: number): Promise<void> {
    await this.stripe.charges.create({
      amount: amountCents,
      currency: 'usd',
      metadata: { orderId },
    });
  }
}
```

### Do

```typescript
// checkout.ts — the high-level module OWNS the port, named in domain terms.
interface PaymentGateway {
  charge(orderId: string, amountCents: number): Promise<void>;
}

class CheckoutService {
  constructor(private readonly payments: PaymentGateway) {}

  payOrder(orderId: string, amountCents: number): Promise<void> {
    return this.payments.charge(orderId, amountCents);
  }
}

// stripe-gateway.ts — the adapter, not the policy, depends on the vendor.
import { StripeClient } from './vendor/stripe';

class StripeGateway implements PaymentGateway {
  constructor(private readonly stripe: StripeClient) {}

  async charge(orderId: string, amountCents: number): Promise<void> {
    await this.stripe.charges.create({
      amount: amountCents,
      currency: 'usd',
      metadata: { orderId },
    });
  }
}

// main.ts — only the composition root knows both sides.
// new CheckoutService(new StripeGateway(new StripeClient(key)))
```

**Idiomatic TS:** A single-method port is just a function type — `type Charge = (orderId: string, amountCents: number) => Promise<void>` — injected as a plain parameter. No DI container needed; the composition root is ordinary code that calls constructors.

---

## Sources

- Robert C. Martin, ["The Principles of OOD"](http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod), butunclebob.com — canonical one-line statements for all five principles (and the six package principles beyond them).
- Robert C. Martin, ["Design Principles and Design Patterns"](https://staff.cs.utu.fi/staff/jouni.smed/doos_06/material/DesignPrinciplesAndPatterns.pdf) (2000) — the four rot symptoms; OCP as an ideal ("even partial OCP compliance can make dramatic improvements"); the DIP non-volatility exception.
- The SOLID acronym itself was coined by Michael Feathers, ordering Martin's five class-design principles.

All TypeScript examples are original to this document.
