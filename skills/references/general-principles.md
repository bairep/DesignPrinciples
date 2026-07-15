# General Design Principles

Cross-cutting principles beyond SOLID — the rules of thumb that govern duplication, simplicity, speculation, object composition, and structural coupling — plus the CUPID lens this skill uses to grade all of them.

## Contents

- [DRY — Don't Repeat Yourself](#dry--dont-repeat-yourself)
- [KISS — Keep It Simple](#kiss--keep-it-simple)
- [YAGNI — You Aren't Gonna Need It](#yagni--you-arent-gonna-need-it)
- [Composition over Inheritance](#composition-over-inheritance)
- [Law of Demeter](#law-of-demeter)
- [The CUPID lens](#the-cupid-lens)
- [Sources](#sources)

---

## DRY — Don't Repeat Yourself

**Canonical statement:** "Every piece of knowledge must have a single, unambiguous, authoritative representation within a system." — Hunt & Thomas, *The Pragmatic Programmer*

**What it protects:** One business rule, one place to change it — edits can't half-apply.

**Use when:**
- The same *policy* (a discount rate, a validation rule, a threshold) is encoded in more than one place.
- A bug fix or rule change would force you to remember every copy.
- Two code paths must always agree (checkout total vs. invoice total).

**Skip when:**
- Two snippets look alike but encode *different* policies that change independently (billing-address vs. shipping-address validation). Merging them couples unrelated decisions.
- You've seen only two occurrences and the shared abstraction isn't obvious yet — "duplication is far cheaper than the wrong abstraction" (Sandi Metz).
- The duplication is across module or service boundaries where sharing would create a dependency worse than the repeat.

**Trade-off:** Deduplicating couples every caller to one shared representation — great when it truly is one piece of knowledge, painful when the copies were only coincidentally similar and now need `options` flags to diverge.

**Smell that calls for it:** A rule change turned into a grep hunt, and one copy was missed.
**Smell of overuse:** A shared helper sprouting boolean parameters so each caller can get slightly different behavior.

### Don't

```typescript
type CartItem = { price: number; qty: number };
type InvoiceLine = { amount: number };

// The 10% member discount is knowledge, and it lives in two places.
// When marketing changes it to 15%, one of these WILL be missed.
function checkoutTotal(cart: CartItem[], isMember: boolean): number {
  const subtotal = cart.reduce((sum, i) => sum + i.price * i.qty, 0);
  return isMember ? subtotal * 0.9 : subtotal;
}

function invoiceTotal(lines: InvoiceLine[], isMember: boolean): number {
  const subtotal = lines.reduce((sum, l) => sum + l.amount, 0);
  return isMember ? subtotal * 0.9 : subtotal; // copy-pasted policy
}
```

### Do

```typescript
type CartItem = { price: number; qty: number };
type InvoiceLine = { amount: number };

// One authoritative representation of the discount policy.
const MEMBER_DISCOUNT_RATE = 0.1;

function applyMemberDiscount(subtotal: number, isMember: boolean): number {
  return isMember ? subtotal * (1 - MEMBER_DISCOUNT_RATE) : subtotal;
}

function checkoutTotal(cart: CartItem[], isMember: boolean): number {
  const subtotal = cart.reduce((sum, i) => sum + i.price * i.qty, 0);
  return applyMemberDiscount(subtotal, isMember);
}

function invoiceTotal(lines: InvoiceLine[], isMember: boolean): number {
  const subtotal = lines.reduce((sum, l) => sum + l.amount, 0);
  return applyMemberDiscount(subtotal, isMember);
}
```

---

## KISS — Keep It Simple

**Canonical statement:** "Keep it simple, stupid." — Kelly Johnson, Lockheed Skunk Works

**What it protects:** The next reader's ability to understand and safely change the code without a tour guide.

**Use when:**
- A design review needs a diagram to explain what a single function does.
- You're introducing a pattern, generic, or layer to solve a problem you can state in one sentence.
- The clever version and the boring version have the same behavior today.

**Skip when:**
- The "simple" version silently drops a real requirement (concurrency, i18n, precision) — simple is not the same as incomplete.
- The domain itself is irreducibly complex; hiding that complexity behind a naive API just moves the pain to callers.

**Trade-off:** Simplicity trades generality for changeability — boring code is easy to modify precisely because it commits to less. The moment a real second requirement arrives, upgrade the design *then*, with facts in hand.

**Smell that calls for it:** Indirection you must step through in a debugger to answer "what does this return?"
**Smell of overuse:** A 300-line God-function defended as "simple" because it has no abstractions.

### Don't

```typescript
// A strategy registry, generics, and three layers of indirection
// to answer a yes/no question about a hard-coded flag.
interface FlagRule<TCtx> {
  evaluate(ctx: TCtx): boolean;
}

class StaticRule implements FlagRule<unknown> {
  constructor(private readonly value: boolean) {}
  evaluate(): boolean {
    return this.value;
  }
}

class RuleEngine<TCtx> {
  private rules = new Map<string, FlagRule<TCtx>>();
  register(name: string, rule: FlagRule<TCtx>): this {
    this.rules.set(name, rule);
    return this;
  }
  isEnabled(name: string, ctx: TCtx): boolean {
    return this.rules.get(name)?.evaluate(ctx) ?? false;
  }
}

const engine = new RuleEngine().register("newCheckout", new StaticRule(true));
```

### Do

```typescript
// Same behavior, zero indirection, type-safe flag names for free.
const FLAGS = {
  newCheckout: true,
  betaSearch: false,
} as const;

type FlagName = keyof typeof FLAGS;

function isEnabled(flag: FlagName): boolean {
  return FLAGS[flag];
}
```

---

## YAGNI — You Aren't Gonna Need It

**Canonical statement:** "Yagni only applies to capabilities built into the software to support a presumptive feature, it does not apply to effort to make the software easier to modify." — Martin Fowler, *Yagni* (bliki)

**What it protects:** Today's velocity — every speculative feature carries four costs (Fowler): **cost of build**, **cost of delay** (the feature you didn't ship instead), **cost of carry** (complexity taxing all other work), and **cost of repair** (when the guess was wrong).

**Use when:**
- You're building a capability because someone *might* need it ("we'll probably want XML too").
- A design adds extension points, config options, or plugin seams with exactly one known consumer.
- "Future-proofing" is the only justification anyone can articulate.

**Skip when:**
- The work in question is refactoring, self-testing code, or code health — Fowler is explicit that these are *never* YAGNI violations. Citing YAGNI to skip quality is the misuse pitfall, not the principle.
- The decision is a genuine one-way door (wire format, public API, database schema) where retrofit cost is provably brutal.
- The codebase is not malleable. YAGNI presumes you can add the capability cheaply later; without refactoring, self-testing code, and continuous delivery it "turns from a beneficial practice into a curse" (Fowler).

**Trade-off:** You accept a possible future retrofit in exchange for a smaller, cheaper system now. That bet pays off because most presumptive features are never needed — and the ones that are arrive with better information than you have today.

**Smell that calls for it:** Interfaces with one implementation, `TODO: support other formats`, dead config options.
**Smell of overuse:** A team that quotes YAGNI to avoid writing tests or cleaning up — that's neglecting code health, which YAGNI explicitly does not cover.

### Don't

```typescript
type Row = Record<string, string | number>;

// The ticket asked for CSV export. This is a format plugin system
// with two stub implementations nobody requested — pure cost of carry.
interface ReportExporter {
  export(rows: Row[]): string;
}

class CsvExporter implements ReportExporter {
  export(rows: Row[]): string {
    /* the only real code in the file */ return "";
  }
}

class PdfExporter implements ReportExporter {
  export(): string {
    throw new Error("TODO: someday");
  }
}

class ExporterRegistry {
  private exporters = new Map<string, ReportExporter>();
  register(format: string, e: ReportExporter): void {
    this.exporters.set(format, e);
  }
  get(format: string): ReportExporter | undefined {
    return this.exporters.get(format);
  }
}
```

### Do

```typescript
type Row = Record<string, string | number>;

// Ship what was asked. When format #2 actually arrives, extract the
// seam then — with a real second case to design against.
function exportCsv(rows: Row[]): string {
  if (rows.length === 0) return "";
  const escape = (v: string | number) => `"${String(v).replace(/"/g, '""')}"`;
  const header = Object.keys(rows[0]).join(",");
  const lines = rows.map((r) => Object.values(r).map(escape).join(","));
  return [header, ...lines].join("\n");
}
```

---

## Composition over Inheritance

**Canonical statement:** "Favor object composition over class inheritance." — Gamma, Helm, Johnson, Vlissides, *Design Patterns* (1994)

**What it protects:** Independence from a parent class's implementation and change cadence — subclasses inherit every future change to the base, wanted or not.

**Use when:**
- You need behavior in *combinations* (email + SMS, logging + retry) — hierarchies force one subclass per combination.
- You're subclassing only to reuse a method or two — that's a has-a wearing an is-a costume.
- The base class keeps changing and every change ripples into subclasses.

**Skip when:**
- It's a true is-a with a stable, rarely-changing base and LSP genuinely holds — modeling `ReadonlyView extends View` as composition can be ceremony for nothing.
- A framework mandates the base class (test cases, ORM entities, UI components) — fighting the framework costs more than the coupling.

**Trade-off:** Composition swaps compile-time convenience (free inherited behavior) for runtime flexibility and looser coupling — you write a little more wiring, and in exchange behavior can be combined, swapped, and tested in isolation.

**Smell that calls for it:** Subclass names that concatenate features (`RetryingSmsAndEmailNotifier`), or `override` methods that gut the parent's behavior.
**Smell of overuse:** Passing nine collaborators through constructors to assemble what is honestly one fixed behavior.

### Don't

```typescript
type User = { id: string; email: string; phone: string };

// Each channel forks the hierarchy. Need SMS *and* Slack? New subclass.
// Need retry? Touch every class. The base's default quietly leaks into
// every subclass that forgets to override.
class Notifier {
  send(user: User, message: string): void {
    /* sends email by default */
  }
}

class SmsNotifier extends Notifier {
  override send(user: User, message: string): void {
    /* sends SMS — and silently drops the email behavior it inherited */
  }
}

class SlackNotifier extends Notifier {
  override send(user: User, message: string): void {
    /* sends Slack */
  }
}

class SmsAndSlackNotifier extends SmsNotifier {
  override send(user: User, message: string): void {
    super.send(user, message);
    /* ...and Slack, duplicated from SlackNotifier */
  }
}
```

### Do

```typescript
type User = { id: string; email: string; phone: string };

// Channels are values that share an interface. Combinations are data,
// not new classes; each channel is testable alone.
interface Channel {
  deliver(to: User, message: string): Promise<void>;
}

const email: Channel = {
  deliver: async (to, message) => {
    /* smtp */
  },
};

const sms: Channel = {
  deliver: async (to, message) => {
    /* twilio */
  },
};

class Notifier {
  constructor(private readonly channels: readonly Channel[]) {}
  async send(to: User, message: string): Promise<void> {
    await Promise.all(this.channels.map((c) => c.deliver(to, message)));
  }
}

const onboarding = new Notifier([email, sms]); // combine at runtime
```

---

## Law of Demeter

**Canonical statement:** "Only talk to your immediate friends." — Lieberherr & Holland, *Assuring Good Style for Object-Oriented Programs* (1989)

**What it protects:** Callers from being coupled to the *internal structure* of their collaborators — reach through an object graph and you break whenever any link in the chain changes shape.

**Use when:**
- Code navigates someone else's object graph: `order.getCustomer().getAddress().getZip()` couples you to `Order`, `Customer`, *and* `Address`.
- A structural refactor (moving a field one level) breaks callers that never cared about the structure.
- You're passing a whole object somewhere that only needs one value from it.

**Skip when:**
- The chain is a fluent builder, promise chain, or array pipeline (`orders.filter().map().slice()`) — each call returns the *same abstraction*, so no internal structure is exposed. Demeter is not a dot-counting rule.
- The object is a plain data structure (DTO, config, parsed JSON) with no behavior — reading nested data you own is fine.

**Trade-off:** Obeying Demeter means adding small delegating methods (`order.shippingZip()`), which is mild interface bloat — in exchange, structural changes stay local to the class that owns the structure instead of rippling through every caller.

**Smell that calls for it:** Train wrecks through *different* abstraction levels, and mocks-of-mocks-of-mocks in tests.
**Smell of overuse:** Wrapper methods that exist only to hide one dot, tripling the surface of a simple data holder.

### Don't

```typescript
// Checkout knows Order has a Customer, Customer has an Address, and
// Address has zip/city fields — three structures it can be broken by.
class Address {
  constructor(public readonly city: string, public readonly zip: string) {}
}
class Customer {
  constructor(public readonly address: Address) {}
}
class Order {
  constructor(public readonly customer: Customer) {}
}

function shippingLabel(order: Order): string {
  const zip = order.customer.address.zip;
  const city = order.customer.address.city;
  return `${city} ${zip}`;
}
```

### Do

```typescript
// Callers ask for what they need; Order owns (and can change) its structure.
class Address {
  constructor(public readonly city: string, public readonly zip: string) {}
}
class Customer {
  constructor(private readonly address: Address) {}
  shippingDestination(): { city: string; zip: string } {
    return { city: this.address.city, zip: this.address.zip };
  }
}
class Order {
  constructor(private readonly customer: Customer) {}
  shippingDestination(): { city: string; zip: string } {
    return this.customer.shippingDestination();
  }
}

function shippingLabel(order: Order): string {
  const { city, zip } = order.shippingDestination();
  return `${city} ${zip}`;
}
```

---

## The CUPID lens

Dan North's CUPID (cupid.dev) proposes five **properties** of joyful code:

- **Composable** — "plays well with others"
- **Unix philosophy** — "does one thing well"
- **Predictable** — "does what you expect"
- **Idiomatic** — "feels natural"
- **Domain-based** — "the solution domain models the problem domain"

North's key move is not the list — it's the *framing*. Principles are like rules: you're compliant or you're not, which invites checkbox thinking and dogma. Properties are graded: code has more or less of them, and you can always move toward them. That reframe turns design review from "does this violate SRP?" into "would this be more predictable, more composable?"

**Honest attribution:** North explicitly considers the SOLID principles no longer useful and offers CUPID as a replacement. This skill takes a middle path — it keeps SOLID and the principles above because their diagnostics are too valuable to discard, but it adopts North's grading stance wholesale. That is why every entry here has **Use when / Skip when** instead of commandments: every principle is a pressure to weigh, not a rule to obey.

When two principles collide (DRY says merge, KISS says don't abstract yet), CUPID is the tiebreaker: pick the option that leaves the code more predictable and more domain-shaped.

---

## Sources

- Martin Fowler, *Yagni* — https://martinfowler.com/bliki/Yagni.html (scoping, four costs, malleability precondition)
- Dan North, *CUPID — for joyful coding* — https://dannorth.net/cupid-for-joyful-coding/ and https://cupid.dev
- Andrew Hunt & David Thomas, *The Pragmatic Programmer* (DRY, canonical statement)
- Sandi Metz, *The Wrong Abstraction* — "duplication is far cheaper than the wrong abstraction"
- Gamma, Helm, Johnson, Vlissides, *Design Patterns* (1994) — composition over inheritance
- Lieberherr & Holland (1989) — Law of Demeter
