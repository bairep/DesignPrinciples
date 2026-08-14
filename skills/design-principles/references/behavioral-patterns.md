# Behavioral Patterns

How objects and functions divide responsibility for an algorithm or interaction — and when each division is worth its indirection.

Behavioral patterns are where modern languages absorb the most. The classic critique (named on refactoring.guru's own criticism page) is that many patterns are kludges for missing language features — and Strategy in a language with first-class functions is the canonical case. In TypeScript, several of these patterns collapse into a function type, a union, or a platform primitive; the entries below lead with the idiomatic form and reserve the classical class shape for the cases that still earn it.

## Contents

- [Strategy](#strategy)
- [Observer](#observer)
- [Command](#command)
- [State](#state)
- [Template Method](#template-method)
- [Chain of Responsibility](#chain-of-responsibility)
- [Sources](#sources)

## Strategy

**Canonical intent:** Make a family of interchangeable algorithms swappable behind one contract, chosen at runtime without the caller knowing which one it got.

**What it protects:** Callers from `if/else` sprawl every time a new algorithm variant appears.

**Use when:**
- The same operation has several legitimate variants (pricing rules, retry policies, sort orders) selected by data or config.
- You keep adding branches to the same conditional as variants arrive.
- Variants must be testable in isolation from the code that picks them.

**Skip when:**
- There are exactly two variants and no evidence more are coming — a plain `if` is clearer.
- The "strategies" differ by a value, not behavior — use a parameter or lookup table of data instead.
- Selection logic and behavior are trivially small; the pattern's ceremony would outweigh both.

**Trade-off:** You pay one layer of indirection (the caller no longer sees which algorithm runs) to buy open-ended extension: new variants are new values, not edits to shared branching code.

**Smell that calls for it:** The same `switch (customer.tier)` duplicated in three modules, each growing a case per release.
**Smell of overuse:** A `Strategy` interface with one method, one implementation, and no second variant on any roadmap.

### Don't

```typescript
// Flaw: class-per-strategy ceremony for stateless one-liners —
// three files of boilerplate to express three expressions.
interface PricingStrategy {
  price(order: Order): number;
}

class RegularPricing implements PricingStrategy {
  price(order: Order): number {
    return order.subtotal;
  }
}

class GoldPricing implements PricingStrategy {
  price(order: Order): number {
    return order.subtotal * 0.9;
  }
}

class EmployeePricing implements PricingStrategy {
  price(order: Order): number {
    return order.subtotal * 0.7;
  }
}
```

### Do

```typescript
// The strategy IS a function type; the registry IS the extension point.
type PricingRule = (order: Order) => number;

const pricingRules = {
  regular: (order) => order.subtotal,
  gold: (order) => order.subtotal * 0.9,
  employee: (order) => order.subtotal * 0.7,
} satisfies Record<CustomerTier, PricingRule>;

function checkoutTotal(order: Order, tier: CustomerTier): number {
  return pricingRules[tier](order) + order.shipping;
}
```

**Idiomatic TS:** In TypeScript the pattern is a function type (`type PricingRule = (order: Order) => number`) or a record of functions keyed by a union — `satisfies` gives you exhaustiveness for free. The classical interface-plus-class-per-strategy form earns its keep only when a strategy carries its own state or configuration, or exposes several related methods that must vary together.

## Observer

**Canonical intent:** Let many listeners react to state changes in a subject without the subject knowing who they are.

**What it protects:** The publisher from compile-time dependencies on every party interested in its changes.

**Use when:**
- One event genuinely fans out to multiple independent reactions (order placed → email, analytics, inventory).
- Publisher and subscribers live in modules that must not import each other.
- Subscribers come and go at runtime (UI components mounting/unmounting).

**Skip when:**
- There is exactly one listener and it never changes — a direct call is honest and traceable.
- The "event" is really a request that needs a response — that's a function call, not a notification.
- Ordering between subscribers matters — observers promise independence; sequencing needs a pipeline.

**Trade-off:** You trade explicit call graphs for decoupling: publishers stay ignorant of consumers, but control flow becomes invisible in the source — "who reacts to this?" now requires runtime knowledge.

**Smell that calls for it:** The order module imports the email, analytics, and inventory modules just to tell each one what happened.
**Smell of overuse:** Debugging means grepping event names because nothing visibly calls anything — hidden control flow everywhere, plus listeners leaking because nobody unsubscribes.

### Don't

```typescript
// Flaw: stringly-typed events with `any` payloads — typos compile,
// payload shape is unchecked, and there is no way to unsubscribe.
class OrderEvents {
  private listeners: Record<string, ((data: any) => void)[]> = {};

  on(event: string, fn: (data: any) => void): void {
    (this.listeners[event] ??= []).push(fn); // no way to remove: leak
  }

  emit(event: string, data: any): void {
    this.listeners[event]?.forEach((fn) => fn(data));
  }
}

const events = new OrderEvents();
events.on("order-plcaed", (d) => sendReceipt(d.email)); // typo: never fires
```

### Do

```typescript
// Typed event map: payloads are checked, names can't be misspelled,
// and subscribing returns the unsubscribe.
type OrderEventMap = {
  placed: { orderId: string; email: string };
  shipped: { orderId: string; carrier: string };
};

class TypedEmitter<Events extends Record<string, unknown>> {
  private listeners = new Map<keyof Events, Set<(p: never) => void>>();

  on<K extends keyof Events>(event: K, fn: (payload: Events[K]) => void): () => void {
    const set = this.listeners.get(event) ?? new Set();
    set.add(fn as (p: never) => void);
    this.listeners.set(event, set);
    return () => set.delete(fn as (p: never) => void);
  }

  emit<K extends keyof Events>(event: K, payload: Events[K]): void {
    this.listeners.get(event)?.forEach((fn) => (fn as (p: Events[K]) => void)(payload));
  }
}

const orderEvents = new TypedEmitter<OrderEventMap>();
const unsubscribe = orderEvents.on("placed", ({ email }) => sendReceipt(email));
// later, on teardown:
unsubscribe();
```

**Idiomatic TS:** Prefer platform primitives — `EventTarget` in the browser, Node's `EventEmitter`, or your framework's signals/stores — over hand-rolled subject classes. Hand-roll only for typed domain events where you want an exhaustive, union-typed event map like the one above. Whatever you use, make every subscription return its unsubscribe and call it on teardown; forgotten unsubscribes are the pattern's classic leak.

## Command

**Canonical intent:** Reify an action as a value so it can be stored, passed, queued, and replayed instead of executed on the spot.

**What it protects:** The moment of deciding *what* to do from the moment (and place) of *doing* it.

**Use when:**
- Actions must be queued, logged, retried, or undone — you need the action after the call site is gone.
- You're building undo/redo: each action needs an inverse carried with it.
- Actions must cross a boundary (job queue, wire, disk) and be executed later.

**Skip when:**
- The action is executed immediately, exactly once, and never revisited — just call the function.
- You only need deferral, not storage or inspection — a plain callback already is one.
- No undo, no queue, no audit trail is on any roadmap.

**Trade-off:** Every action gains a wrapper (more objects, more indirection) in exchange for actions becoming data — inspectable, storable, reversible, schedulable.

**Smell that calls for it:** Undo is implemented by snapshotting the entire document because nobody recorded what changed.
**Smell of overuse:** `SaveCommand`, `LoadCommand`, `PrintCommand` classes each wrapping a single method call that is never queued, logged, or undone.

### Don't

```typescript
// Flaw: mutations applied directly at the call site — nothing is
// recorded, so undo is impossible without diffing snapshots.
class Editor {
  content = "";

  handleKeystroke(char: string): void {
    this.content += char;
  }

  handleDelete(count: number): void {
    this.content = this.content.slice(0, -count);
  }
  // "Add undo" from here means rebuilding every handler.
}
```

### Do

```typescript
// A command is a closure pair: do it, and know how to undo it.
type EditorCommand = {
  execute(): void;
  undo(): void;
};

function insertText(editor: { content: string }, text: string): EditorCommand {
  return {
    execute: () => (editor.content += text),
    undo: () => (editor.content = editor.content.slice(0, -text.length)),
  };
}

class History {
  private done: EditorCommand[] = [];

  run(cmd: EditorCommand): void {
    cmd.execute();
    this.done.push(cmd);
  }

  undo(): void {
    this.done.pop()?.undo();
  }
}
```

**Idiomatic TS:** A closure (plus an optional `undo` closure) covers most command needs — closures already capture their receiver and arguments, which is the bulk of what GoF command classes existed to hold. Reach for class-based commands when commands must be serialized (job queues, event logs, cross-process replay), because closures don't survive `JSON.stringify`.

## State

**Canonical intent:** Make an object's behavior change with its internal state by giving each state its own representation, instead of branching on flags.

**What it protects:** Every method from re-deriving "which mode are we in?" out of a pile of booleans.

**Use when:**
- An entity has a real lifecycle (draft → submitted → approved) and behavior differs per stage.
- Combinations of flags keep appearing that should be impossible (`isShipped && isCancelled`).
- Each transition has rules about which states it's legal from.

**Skip when:**
- There are two states and one boolean genuinely covers it.
- Behavior doesn't vary by state — you just need a status label for display.
- The "states" are independent toggles, not exclusive modes — that's configuration, not a state machine.

**Trade-off:** You pay upfront modeling (naming every state and transition) to buy unrepresentable bugs: the compiler rejects reading tracking numbers off unshipped orders instead of you finding it in production.

**Smell that calls for it:** Boolean-flag soup — three flags, eight combinations, five of them meaningless, and every method starts with flag algebra.
**Smell of overuse:** A class-per-state hierarchy with empty transitions for a three-value status enum whose behavior never differs.

### Don't

```typescript
// Flaw: three independent flags encode what is really one exclusive
// mode — illegal combinations compile and must be policed by hand.
class Order {
  isPaid = false;
  isShipped = false;
  isCancelled = false;
  trackingNumber?: string;

  ship(tracking: string): void {
    if (!this.isPaid || this.isCancelled || this.isShipped) {
      throw new Error("Cannot ship"); // runtime guard for a modeling failure
    }
    this.isShipped = true;
    this.trackingNumber = tracking;
  }
  // Nothing stops: isCancelled = true; isShipped = true;
}
```

### Do

```typescript
// One discriminated union: each state carries only the data that
// exists in that state, and transitions are total functions.
type OrderState =
  | { status: "pending" }
  | { status: "paid"; paidAt: Date }
  | { status: "shipped"; paidAt: Date; trackingNumber: string }
  | { status: "cancelled"; reason: string };

function ship(order: OrderState, trackingNumber: string): OrderState {
  switch (order.status) {
    case "paid":
      return { status: "shipped", paidAt: order.paidAt, trackingNumber };
    case "pending":
    case "shipped":
    case "cancelled":
      throw new Error(`Cannot ship a ${order.status} order`);
  }
}
// order.trackingNumber is a compile error unless status === "shipped".
```

**Idiomatic TS:** Reach for discriminated unions plus exhaustive `switch` first — they make illegal states unrepresentable, which is the pattern's whole point, at zero indirection cost. The classical class-per-state form is justified only when each state carries genuinely distinct, heavy behavior or dependencies (a game AI whose states each own timers and pathfinding), not for data lifecycles.

## Template Method

**Canonical intent:** Fix an algorithm's skeleton in one place and let variants override individual steps.

**What it protects:** The step *ordering* from being copy-pasted into every variant of the process.

**Use when:**
- Several processes share the same step sequence but differ in one or two steps (imports that parse differently but validate and persist identically).
- You're already inside an inheritance-based framework whose base classes expose hook methods.
- The skeleton must be genuinely closed — variants may fill holes but never reorder.

**Skip when:**
- Variants differ in the sequence itself, not just the steps — the "template" would dissolve into flags.
- You'd be introducing an inheritance hierarchy solely to reuse three lines of orchestration.
- Composition is available (it almost always is) — passing step functions does the same job without subclassing.

**Trade-off:** You get single-sourced orchestration, but the classical form pays for it with inheritance coupling: subclasses are bound to the base class's protected surface, and understanding one variant means reading two classes.

**Smell that calls for it:** Three import jobs, each duplicating the fetch-validate-persist choreography around one differing parse step.
**Smell of overuse:** An abstract base class with seven hooks, six of which every subclass leaves as the default.

### Don't

```typescript
// Flaw: an inheritance hierarchy created only to vary one step —
// every new format means a new subclass bound to protected hooks.
abstract class ImportJob {
  run(raw: string): void {
    const rows = this.parse(raw);
    const valid = rows.filter((r) => this.validate(r));
    this.persist(valid);
  }
  protected abstract parse(raw: string): Row[];
  protected validate(row: Row): boolean {
    return row.id !== "";
  }
  protected persist(rows: Row[]): void {
    saveRows(rows);
  }
}

class CsvImportJob extends ImportJob {
  protected parse(raw: string): Row[] {
    return raw.split("\n").map(parseCsvRow);
  }
}
```

### Do

```typescript
// The template is a function; the varying steps are parameters.
type ImportSteps = {
  parse: (raw: string) => Row[];
  validate?: (row: Row) => boolean;
};

function runImport(raw: string, steps: ImportSteps): void {
  const validate = steps.validate ?? ((row) => row.id !== "");
  const rows = steps.parse(raw);
  const valid = rows.filter(validate);
  saveRows(valid);
}

runImport(csvFile, { parse: (raw) => raw.split("\n").map(parseCsvRow) });
runImport(jsonFile, { parse: (raw) => JSON.parse(raw) as Row[] });
```

**Idiomatic TS:** A function that takes step-functions as parameters *is* the template method — same fixed skeleton, same pluggable holes, no inheritance, and defaults live in one visible place instead of a protected method. Keep the classical overriding form only where you already inherit from a framework base class that hands you hooks (component lifecycles, test harnesses).

## Chain of Responsibility

**Canonical intent:** Pass a request along a line of handlers, each deciding to act on it, pass it on, or stop the chain.

**What it protects:** Senders from knowing which of many possible handlers will serve a request — and handlers from knowing about each other.

**Use when:**
- Requests cross a variable, configurable set of handlers — HTTP middleware (Express/Koa/fetch middleware are this pattern), event bubbling, support-ticket escalation.
- Handlers must be added, removed, or reordered per deployment or per route.
- Each handler can genuinely short-circuit (auth rejects; nothing after it should run).

**Skip when:**
- The set of steps is fixed and all always run — a plain ordered list of function calls is simpler and traceable.
- Exactly one handler can ever match — that's a lookup, not a chain.
- You need to guarantee something handles the request — chains permit fall-through by design, so an unhandled request is a silent no-op.

**Trade-off:** You gain per-route composability and open-ended insertion, at the cost of diffuse control flow: no single place shows what runs, and a mis-ordered or `next`-forgetting handler fails silently.

**Smell that calls for it:** Every route handler re-opens with the same inline auth-then-rate-limit-then-log preamble, slightly different each time.
**Smell of overuse:** A "pipeline" of six handlers that all always run in fixed order and never short-circuit — that's a function calling six functions.

### Don't

```typescript
// Flaw: one monolithic handler hard-wires every concern — nothing
// can be reused, reordered, or skipped per route.
async function handleRequest(req: Request): Promise<Response> {
  const user = await verifyToken(req.headers.get("authorization"));
  if (!user) return new Response("unauthorized", { status: 401 });

  if (await isRateLimited(user.id)) {
    return new Response("too many requests", { status: 429 });
  }

  console.log(`${user.id} ${req.method} ${req.url}`);

  // ...actual route logic buried beneath the preamble,
  // and every other route re-implements the same stack.
  return routeOrders(req, user);
}
```

### Do

```typescript
// Each concern is a link that handles, passes on, or stops the chain.
type Ctx = { req: Request; user?: { id: string } };
type Middleware = (ctx: Ctx, next: () => Promise<Response>) => Promise<Response>;

const auth: Middleware = async (ctx, next) => {
  const user = await verifyToken(ctx.req.headers.get("authorization"));
  if (!user) return new Response("unauthorized", { status: 401 });
  ctx.user = user;
  return next();
};

const rateLimit: Middleware = async (ctx, next) =>
  ctx.user && (await isRateLimited(ctx.user.id))
    ? new Response("too many requests", { status: 429 })
    : next();

function compose(chain: Middleware[], terminal: (ctx: Ctx) => Promise<Response>) {
  return (ctx: Ctx): Promise<Response> =>
    chain.reduceRight<() => Promise<Response>>(
      (next, mw) => () => mw(ctx, next),
      () => terminal(ctx),
    )();
}

const handleOrders = compose([auth, rateLimit], (ctx) => routeOrders(ctx.req, ctx.user!));
```

**Idiomatic TS:** Middleware composition — an array of `(ctx, next)` functions folded into one handler — is the living form of this pattern; you rarely need GoF's linked handler objects. Keep the chain flat and declared in one array so the order is visible, and reserve it for stacks that genuinely vary or short-circuit; a fixed always-run sequence should stay a plain ordered function list.

## Sources

- Gamma, Helm, Johnson, Vlissides — *Design Patterns: Elements of Reusable Object-Oriented Software* (1994): canonical intents for all six patterns.
- refactoring.guru — design-patterns catalog and criticism page (reference only; examples above are original — the site's code is CC BY-NC-ND and was not adapted).
- patterns.dev — modern JavaScript/TypeScript treatments of observer and middleware-style composition.
