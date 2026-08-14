# Creational Patterns

How objects get made: the five GoF creational patterns, when each one earns its indirection, and how TypeScript's first-class functions and structural typing shrink or replace the classical forms.

## Contents

- [Factory Method](#factory-method)
- [Abstract Factory](#abstract-factory)
- [Builder](#builder)
- [Singleton](#singleton)
- [Prototype](#prototype)
- [Sources](#sources)

## Factory Method

**Canonical intent:** Define an interface for creating an object, but let the choice of concrete type be made in one dedicated place instead of at every call site.

**What it protects:** Call sites from knowing concrete classes — the "which implementation" decision becomes a single point of change.

**Use when:**
- The concrete type varies by configuration, platform, or environment (prod vs test, Stripe vs Braintree).
- Multiple call sites would otherwise repeat the same `new` + branching logic.
- You want tests to substitute a fake by swapping one creation point.

**Skip when:**
- There is exactly one concrete type and no realistic second one on the horizon — `new` is fine.
- The branching exists in only one place already; a factory adds a layer without removing a duplicate.
- You're about to build a `Creator` class hierarchy in TypeScript — a plain function almost always suffices (see Idiomatic TS).

**Trade-off:** You pay one hop of indirection (readers must follow the factory to see what's actually constructed) to buy a single point of change when implementations are added, swapped, or faked.

**Smell that calls for it:** The same `if (provider === ...) new X(...)` chain appears in more than one file.
**Smell of overuse:** A `FooFactory` that can only ever produce one `Foo`.

### Don't

```typescript
// Every call site knows every concrete gateway — adding a provider
// means hunting down and editing each copy of this chain
class CheckoutService {
  charge(amountCents: number, provider: string) {
    let gateway;
    if (provider === "stripe") {
      gateway = new StripeGateway(process.env.STRIPE_KEY!);
    } else if (provider === "braintree") {
      gateway = new BraintreeGateway(process.env.BT_MERCHANT_ID!);
    } else {
      throw new Error(`Unknown provider: ${provider}`);
    }
    return gateway.charge(amountCents);
  }
}

class RefundService {
  refund(transactionId: string, provider: string) {
    // ...the same if/else chain, duplicated and quietly drifting
  }
}
```

### Do

```typescript
interface PaymentGateway {
  charge(amountCents: number): Promise<Receipt>;
  refund(transactionId: string): Promise<void>;
}

type Provider = "stripe" | "braintree";

// The only place that knows the concretes. Exhaustive switch on a
// union: adding a Provider member won't compile until handled here.
function createGateway(provider: Provider): PaymentGateway {
  switch (provider) {
    case "stripe":
      return new StripeGateway(env.STRIPE_KEY);
    case "braintree":
      return new BraintreeGateway(env.BT_MERCHANT_ID);
  }
}

class CheckoutService {
  constructor(private readonly gateway: PaymentGateway) {}

  charge(amountCents: number) {
    return this.gateway.charge(amountCents);
  }
}

const checkout = new CheckoutService(createGateway(config.provider));
```

**Idiomatic TS:** A plain function returning an interface type *is* a factory method — the GoF form of subclassing a `Creator` class exists because C++/Java of 1994 lacked first-class functions. Only reach for the classical creator hierarchy when the creator owns a substantial shared algorithm around the creation point (which is really Template Method). Bonus: an exhaustive `switch` over a string-literal union gives you compile-checked completeness that the classical pattern never had.

## Abstract Factory

**Canonical intent:** Provide one interface that creates a whole family of related objects, so members of different families can't be mixed.

**What it protects:** Cross-object consistency — the guarantee that everything created together belongs to the same family (theme, platform, vendor).

**Use when:**
- You have *families* of related objects (dark button + dark input, Postgres connection + Postgres migrator) and mixing families is a bug.
- The family is chosen once (startup, request, tenant) and everything downstream must follow it.
- You already have two or more real families — not one family and a hunch.

**Skip when:**
- There's only one object per "family" — that's just Factory Method.
- Families exist but mixing them is harmless; a plain factory per type is simpler.
- The second family is speculative. Wait for it to actually exist.

**Trade-off:** You pay a wider interface (every product type appears on the factory, so adding a product type touches every family) to buy the impossibility of an inconsistent mix. It's the classic axis: easy to add families, expensive to add product types.

**Smell that calls for it:** A bug report that reads "the dark-mode dialog has a light-mode button."
**Smell of overuse:** An `AbstractWidgetFactory` with one concrete subclass, waiting since 2023 for a second.

### Don't

```typescript
// Consistency by convention only: nothing stops a mixed family,
// and the compiler is fine with it
function renderLoginForm(isDark: boolean) {
  const button = isDark ? new DarkButton() : new LightButton();
  const input = new LightInput(); // oops — mixed family, compiles fine

  // ...every render function repeats (and eventually flubs) the choice
  return layout(button, input);
}
```

### Do

```typescript
interface ThemeFactory {
  createButton(): Button;
  createInput(): Input;
}

// Families are plain objects — structural typing needs no classes
const darkTheme: ThemeFactory = {
  createButton: () => new DarkButton(),
  createInput: () => new DarkInput(),
};

const lightTheme: ThemeFactory = {
  createButton: () => new LightButton(),
  createInput: () => new LightInput(),
};

// The family travels as one value; a mixed pair can't happen by accident
function renderLoginForm(theme: ThemeFactory) {
  const button = theme.createButton();
  const input = theme.createInput();
  return layout(button, input);
}

renderLoginForm(user.prefersDark ? darkTheme : lightTheme);
```

**Idiomatic TS:** Each family is an object literal satisfying the factory interface — no `DarkThemeFactory` classes. A `Record<ThemeName, ThemeFactory>` map replaces the "factory of factories" ceremony, and structural typing lets tests pass a partial fake family without touching a class hierarchy.

## Builder

**Canonical intent:** Construct a complex object step by step, separating the assembly process from the finished, valid result.

**What it protects:** Call sites from telescoping constructors, and consumers from ever seeing a half-constructed object.

**Use when:**
- Construction takes many optional parts and the positional-argument form has become unreadable.
- A valid object requires cross-field validation that should run once, at `build()`, before anyone can hold the result.
- Test code needs "a valid X, with just this one field different" over and over — fluent builders shine brightest as test-data builders.

**Skip when:**
- A named options object with defaults expresses it in one signature (the common case in TS — see Idiomatic TS).
- The object has two or three fields. Just pass them.
- You'd be writing a builder for a type that's already a plain immutable record with no invariants.

**Trade-off:** You pay a second API surface to maintain (every new field means a new `withX` method) to buy readable call sites and a choke point where invariants are enforced before the object exists.

**Smell that calls for it:** A call site like `new Order("c42", items, undefined, true, false, undefined)`.
**Smell of overuse:** A builder whose `build()` does no validation and whose every method maps 1:1 to a field — that's an options object wearing a costume.

### Don't

```typescript
// Telescoping constructor: which boolean is which? Every new
// option reshuffles every call site.
class Order {
  constructor(
    customerId: string,
    items: LineItem[],
    coupon?: string,
    giftWrap?: boolean,
    expedited?: boolean,
    note?: string,
  ) {
    /* ... */
  }
}

const order = new Order("cust_42", items, undefined, true, false, undefined);
```

### Do

```typescript
// Test-data builder: every test states only what it cares about,
// and invalid drafts never escape build()
class OrderBuilder {
  private draft: OrderDraft = {
    customerId: "cust_test",
    items: [defaultLineItem()],
  };

  withCustomer(id: string): this {
    this.draft.customerId = id;
    return this;
  }

  withItems(...items: LineItem[]): this {
    this.draft.items = items;
    return this;
  }

  expedited(): this {
    this.draft.expedited = true;
    return this;
  }

  build(): Order {
    return validateOrder(this.draft); // throws on cross-field violations
  }
}

const order = new OrderBuilder().withCustomer("cust_42").expedited().build();
```

**Idiomatic TS:** For production code, a named options object with defaults — `createOrder({ customerId, items, expedited: true })` — kills telescoping constructors without any builder machinery, and `Partial<OrderOptions>` plus a validating `createOrder` function covers "step-wise assembly" for most cases. Reserve the fluent class form for test data and for genuinely staged construction where intermediate steps have their own logic.

## Singleton

**Canonical intent:** Guarantee a class has exactly one instance and give the whole program a single access point to it.

**What it protects:** Nothing you can't protect better another way — the "one instance" half is legitimate; the "global access point" half is the problem.

**Use when:**
- Almost never as the GoF `getInstance()` form. The legitimate need — exactly one connection pool, one config, one logger — is served by creating one instance at the composition root and passing it in.
- A third-party constraint genuinely forces a global access point (some frameworks, some FFI boundaries) — and then wrap it and quarantine it.

**Skip when:**
- You're reaching for it to avoid threading a dependency through two layers — that's the hidden-dependency trap, not a design win.
- The state inside it is mutable. A global mutable singleton is shared mutable state with extra steps.
- Tests would need a `reset()` hook to un-share state between cases. That hook is the pattern confessing.

**Trade-off:** You save the effort of passing a dependency explicitly, and pay with hidden coupling (no signature reveals the dependency), unswappable fakes, order-dependent tests, and one more piece of process-wide mutable state. The price outweighs the saving in nearly every codebase.

**Smell that calls for it:** (Rare) two live instances of something the outside world requires to be unique — and even then, prefer construction-site discipline.
**Smell of overuse:** `X.getInstance()` calls scattered through business logic; test files full of `beforeEach(() => X.reset())`.

### Don't

```typescript
// Global reachable from anywhere: the dependency is invisible in every
// signature, tests share state, and nothing can substitute a fake
class Database {
  private static instance: Database;

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database(process.env.DATABASE_URL!);
    }
    return Database.instance;
  }

  private constructor(private readonly url: string) {}

  query(sql: string, params?: unknown[]) {
    /* ... */
  }
}

// Deep inside business logic, invisible from the outside:
function findUser(id: string) {
  return Database.getInstance().query("select * from users where id = $1", [id]);
}
```

### Do

```typescript
// "Exactly one" is decided at the composition root, not enforced by
// the class. The dependency is visible in every signature that uses it.
export function createDatabase(url: string): Database {
  return new Database(url);
}

class UserRepository {
  constructor(private readonly db: Database) {}

  findUser(id: string) {
    return this.db.query("select * from users where id = $1", [id]);
  }
}

// main.ts — the only place that decides how many exist
const db = createDatabase(env.DATABASE_URL);
const users = new UserRepository(db);

// user-repository.test.ts — no reset hooks, no shared state
const repo = new UserRepository(fakeDb());
```

**Idiomatic TS:** ES modules are evaluated once, so a module-scoped `const db = createDatabase(...)` already gives you one instance per process without any `getInstance()` machinery — but still *pass it in* rather than importing it deep in business logic, or you've rebuilt the same hidden coupling with `import` syntax. Uniqueness is a wiring decision for the composition root, not a property a class should enforce on itself.

## Prototype

**Canonical intent:** Create new objects by copying an existing instance instead of constructing from scratch.

**What it protects:** Callers from knowing the concrete type (or expensive setup) of the thing they're copying.

**Use when:**
- You must copy objects *polymorphically* — through an abstract interface, where the caller can't know the concrete type — and the objects carry non-serializable state (methods, handles) that `structuredClone` can't carry.

**Skip when:**
- The data is plain. `structuredClone(order)` deep-copies it; `{ ...order, status: "paid" }` shallow-copies with changes. Both beat a hand-written `clone()`.
- "Copying is expensive setup avoidance" is the motive — a factory function capturing the setup usually reads better.

**Trade-off:** A `clone()` hierarchy costs a method on every class that must be kept deep/shallow-correct by hand, forever; it buys polymorphic copying, which TypeScript codebases need rarely.

**Smell that calls for it:** Code that needs a copy of "whatever this `Shape` really is" without a `switch` on its type.
**Smell of overuse:** `clone()` methods on plain data records.

### Don't

```typescript
// A clone() hierarchy for plain data — ceremony with no polymorphism payoff
abstract class DocumentNode {
  abstract clone(): DocumentNode;
}

class Paragraph extends DocumentNode {
  constructor(public text: string, public style: TextStyle) {
    super();
  }
  clone(): Paragraph {
    return new Paragraph(this.text, { ...this.style }); // hand-maintained depth
  }
}
```

### Do

```typescript
// Plain data: the platform already does this
const draftCopy = structuredClone(document);
const retitled = { ...document, title: "Q3 Report (final)" };
```

**Idiomatic TS:** `structuredClone`, spread, and factory functions cover nearly every real cloning need in JS/TS — the classical pattern predates all three. The classical `clone()` earns its keep only for polymorphic copying through an abstract interface; if you're not in that situation, you don't need Prototype.

## Sources

- Gamma, Helm, Johnson, Vlissides — *Design Patterns: Elements of Reusable Object-Oriented Software* (1994): canonical intents for all five patterns.
- refactoring.guru design-patterns catalog — reference for the modern 22-pattern canon and naming; all examples above are original (their code is CC BY-NC-ND and was not adapted).
- patterns.dev — modern JavaScript/TypeScript context on module-scope singletons and function-based factories.
