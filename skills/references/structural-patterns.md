# Structural Patterns

How to compose objects and functions into larger structures without coupling callers to the mess inside.

## Contents

- [Adapter](#adapter)
- [Decorator](#decorator)
- [Facade](#facade)
- [Composite](#composite)
- [Proxy](#proxy)
- [Sources](#sources)

---

## Adapter

**Canonical intent:** Convert the interface someone else gave you into the interface your code wants, so callers never see the foreign shape.

**What it protects:** Your domain code from the naming, types, and quirks of third-party or legacy interfaces.

**Use when:**

- A third-party SDK, legacy module, or external API has a shape you don't control and don't want leaking inward.
- You need to swap vendors (or add a second one) behind a single domain-owned interface.
- Test doubles for an external system are painful because production code calls the vendor SDK directly.

**Skip when:**

- You own both sides — change one of them instead of adding a translation layer.
- The foreign interface is used in exactly one place and is unlikely to spread; an inline mapping is enough.
- The "domain interface" you'd adapt to is just a copy of the vendor's shape — that's a rename, not a boundary.

**Trade-off:** You pay one layer of indirection and a mapping that must be kept honest; you buy the freedom to change vendors, versions, and wire formats without touching domain code.

**Smell that calls for it:** Vendor types (`Stripe.Charge`, `AWS.S3.PutObjectRequest`) appearing in function signatures far from the boundary.

**Smell of overuse:** Adapters wrapping your own modules, or adapter-on-adapter stacks where nobody remembers which shape is canonical.

### Don't

```typescript
// Vendor shape leaks everywhere: every caller knows cents, snake_case, and SDK statuses
import { BraintopClient } from "braintop-sdk";

async function checkout(cart: Cart, client: BraintopClient) {
  const result = await client.charges.create({
    amount_in_cents: Math.round(cart.total * 100),
    currency_code: cart.currency.toUpperCase(),
    customer_ref: cart.customerId,
  });
  if (result.status_code === "SETTLED_OK") {
    // every call site repeats this mapping — a vendor swap touches all of them
    return { ok: true, receiptId: result.txn_ref };
  }
  return { ok: false, reason: result.failure_reason ?? "unknown" };
}
```

### Do

```typescript
// Domain owns the interface; the adapter is the only file that imports the SDK
interface PaymentProvider {
  charge(payment: { amount: Money; customerId: string }): Promise<ChargeResult>;
}

type ChargeResult =
  | { ok: true; receiptId: string }
  | { ok: false; reason: string };

// adapters/braintop.ts — the single place the vendor shape exists
import { BraintopClient } from "braintop-sdk";

function braintopProvider(client: BraintopClient): PaymentProvider {
  return {
    async charge({ amount, customerId }) {
      const result = await client.charges.create({
        amount_in_cents: amount.toMinorUnits(),
        currency_code: amount.currency,
        customer_ref: customerId,
      });
      return result.status_code === "SETTLED_OK"
        ? { ok: true, receiptId: result.txn_ref }
        : { ok: false, reason: result.failure_reason ?? "unknown" };
    },
  };
}

async function checkout(cart: Cart, payments: PaymentProvider) {
  return payments.charge({ amount: cart.total, customerId: cart.customerId });
}
```

**Idiomatic TS:** Structural typing removes the `implements` ceremony — an object literal or a single mapping function that returns the domain type *is* the adapter. Most adapters in TypeScript should be a function `(vendorThing) => DomainThing` or a small factory like the one above, not a class hierarchy.

---

## Decorator

**Canonical intent:** Wrap an object or function behind the same interface to add behavior before or after the call, so features stack by composition instead of inheritance.

**What it protects:** A stable core interface from accumulating every optional concern (retry, logging, caching, metrics) inside its implementation.

**Use when:**

- Cross-cutting behavior (retries, timing, caching, auth headers) applies to some call sites but not others.
- You'd otherwise need a subclass per combination (`RetryingLoggingClient`, `CachingRetryingClient`, …).
- Behaviors compose and order matters — callers should choose the stack.

**Skip when:**

- The behavior is universal — put it in the implementation once instead of wrapping everywhere.
- There is one concern and there will only ever be one; an option flag on the function is simpler.
- Callers need to reach through to wrapped internals; decorators only work against the interface.

**Trade-off:** Each layer adds indirection and can obscure stack traces and identity checks; in exchange, every combination of behaviors is available without a combinatorial class explosion.

**Smell that calls for it:** Class names concatenating adjectives, or the same retry/logging code pasted into many implementations.

**Smell of overuse:** A five-deep wrapper stack you must mentally unwind to answer "what actually happens on this call?"

### Don't

```typescript
// Subclass per combination — n behaviors means 2^n classes
class HttpClient {
  async get(url: string): Promise<Response> {
    return fetch(url);
  }
}

class LoggingHttpClient extends HttpClient {
  override async get(url: string) {
    console.log("GET", url);
    return super.get(url);
  }
}

class RetryingLoggingHttpClient extends LoggingHttpClient {
  override async get(url: string) {
    for (let attempt = 1; ; attempt++) {
      try {
        return await super.get(url);
      } catch (err) {
        if (attempt === 3) throw err;
      }
    }
  }
}
// Need retry WITHOUT logging? Another class. Add caching? Four more.
```

### Do

```typescript
// One function type, one wrapper per concern; callers compose the stack
type Fetcher = (url: string) => Promise<Response>;

const withLogging =
  (next: Fetcher): Fetcher =>
  async (url) => {
    const started = performance.now();
    const res = await next(url);
    console.log(`GET ${url} -> ${res.status} in ${performance.now() - started}ms`);
    return res;
  };

const withRetry =
  (attempts: number) =>
  (next: Fetcher): Fetcher =>
  async (url) => {
    let lastError: unknown;
    for (let i = 0; i < attempts; i++) {
      try {
        return await next(url);
      } catch (err) {
        lastError = err;
      }
    }
    throw lastError;
  };

// Order is explicit and visible at the call site
const fetchPage: Fetcher = withLogging(withRetry(3)((url) => fetch(url)));
```

**Idiomatic TS:** With first-class functions, this pattern collapses to higher-order functions over a function type — reserve wrapper *classes* for interfaces with several methods that must be decorated together. Do not confuse it with TypeScript's `@decorator` syntax: that is compiler-driven annotation machinery for classes and members, not the GoF composition pattern.

---

## Facade

**Canonical intent:** Put a small, purpose-built front door on a complicated subsystem so most callers never learn its internals.

**What it protects:** Callers from a subsystem's setup rituals, ordering rules, and vocabulary they don't need.

**Use when:**

- Using the subsystem correctly takes several coordinated calls (authenticate, then configure, then upload, then publish).
- Many callers repeat the same orchestration glue.
- You want a seam where the subsystem can be swapped or mocked as one unit.

**Skip when:**

- The subsystem is already one call — a facade over one function is a rename.
- Callers genuinely need the underlying knobs; a facade that re-exports everything hides nothing.
- There aren't yet two real call sites to shape it — you'd be guessing at the API.

**Trade-off:** You pay a second API to maintain and the risk it drifts from real caller needs; you buy call sites that state intent in one line and a subsystem you can rework behind a stable front.

**Smell that calls for it:** The same 15-line "how to talk to X" sequence copy-pasted across modules.

**Smell of overuse:** A god-facade that grows a mirror of every subsystem method one-to-one — complexity relocated, not reduced.

### Don't

```typescript
// Every caller re-learns the storage SDK's ritual
async function saveAvatar(userId: string, image: Buffer) {
  const session = await storageSdk.createSession({ scope: "write" });
  const bucket = storageSdk.bucket("user-media", { session });
  const upload = await bucket.beginMultipart(`avatars/${userId}.png`);
  await upload.putPart(1, image);
  const object = await upload.finish();
  await bucket.setAcl(object.key, { public: true });
  return storageSdk.cdnUrl(object.key); // six SDK concepts to save one file
}
```

### Do

```typescript
// One front door shaped by what callers actually do
interface MediaStorage {
  uploadPublic(key: string, data: Buffer): Promise<{ url: string }>;
  remove(key: string): Promise<void>;
}

function sdkMediaStorage(sdk: StorageSdk): MediaStorage {
  return {
    async uploadPublic(key, data) {
      const session = await sdk.createSession({ scope: "write" });
      const bucket = sdk.bucket("user-media", { session });
      const upload = await bucket.beginMultipart(key);
      await upload.putPart(1, data);
      const object = await upload.finish();
      await bucket.setAcl(object.key, { public: true });
      return { url: sdk.cdnUrl(object.key) };
    },
    async remove(key) {
      const session = await sdk.createSession({ scope: "write" });
      await sdk.bucket("user-media", { session }).delete(key);
    },
  };
}

const saveAvatar = (storage: MediaStorage, userId: string, image: Buffer) =>
  storage.uploadPublic(`avatars/${userId}.png`, image);
```

**Idiomatic TS:** A module that exports a handful of plain async functions — and keeps the SDK import private to the file — is a facade; no class needed. Add an `interface` only when you need substitution in tests. Otherwise the module boundary itself is the pattern.

---

## Composite

**Canonical intent:** Model part–whole trees so callers run one operation over a single item or a whole group without caring which they have.

**What it protects:** Tree-walking callers from knowing the difference between a leaf and a branch.

**Use when:**

- The data is genuinely recursive: menus in menus, org units containing org units, folders of folders, UI containers of components.
- The same operations (render, total, search) apply at every level of the tree.

**Skip when:**

- The structure is flat or exactly two levels deep — a list of lists needs `flatMap`, not a pattern.
- Leaf and branch behaviors keep diverging until the shared interface becomes a lie.
- Uniformity would hide constraints that matter (e.g., a section must never be empty).

**Trade-off:** You pay a more abstract type where "is this a single item?" needs an explicit check; you buy recursive operations written once and trees that nest to any depth for free.

**Smell that calls for it:** `if (Array.isArray(node))` or `instanceof Group` branches repeated in every function that touches the structure.

**Smell of overuse:** Forcing peer objects into a parent–child shape just to reuse a traversal.

### Don't

```typescript
// Every operation re-implements the leaf/branch split — and only handles 2 levels
type MenuEntry = { label: string; price: number };

function menuTotal(entries: (MenuEntry | MenuEntry[])[]): number {
  let total = 0;
  for (const entry of entries) {
    if (Array.isArray(entry)) {
      for (const child of entry) total += child.price; // a nested section
    } else {                                           // breaks this silently
      total += entry.price;
    }
  }
  return total;
}
```

### Do

```typescript
// Recursive discriminated union: one shape, any depth, exhaustive by construction
type MenuNode =
  | { kind: "item"; label: string; price: number }
  | { kind: "section"; label: string; children: MenuNode[] };

function menuTotal(node: MenuNode): number {
  switch (node.kind) {
    case "item":
      return node.price;
    case "section":
      return node.children.reduce((sum, child) => sum + menuTotal(child), 0);
  }
}

const brunch: MenuNode = {
  kind: "section",
  label: "Brunch",
  children: [
    { kind: "item", label: "Shakshuka", price: 14 },
    {
      kind: "section",
      label: "Sides",
      children: [{ kind: "item", label: "Halloumi", price: 6 }],
    },
  ],
};
```

**Idiomatic TS:** A recursive discriminated union plus functions that `switch` on `kind` usually beats the classic Component/Leaf/Composite class triad — the compiler enforces exhaustiveness and the data stays serializable. Reach for classes only when nodes carry behavior that must travel with them.

---

## Proxy

**Canonical intent:** Stand in front of an object with the same interface to control access to it — defer, cache, guard, or route the real work.

**What it protects:** Callers from knowing (and the real object from implementing) *when and whether* the expensive or sensitive work happens.

**Use when:**

- Construction or the underlying call is expensive and often unnecessary — lazy loading, memoization.
- Access needs a gate: auth checks, rate limits, quotas.
- The real object lives elsewhere (remote service, worker thread) and callers should not care.

**Skip when:**

- You'd change the interface or add new capabilities — that's Adapter or Decorator territory, not access control.
- The control logic belongs to the caller's business rules rather than to access itself.
- One local cache or `useMemo` at the single call site does the job.

**Trade-off:** You pay hidden behavior behind an innocent-looking interface (staleness, denials, latency surprises); you buy call sites that stay oblivious to caching, laziness, and permission plumbing.

**Smell that calls for it:** Cache lookups or permission checks copy-pasted in front of the same call all over the codebase.

**Smell of overuse:** Proxies with side effects nobody expects — reads that mutate, or innocuous-looking calls that fire network requests callers can't predict.

### Don't

```typescript
// Caching and gating tangled into the loader — and repeated in its callers
const cache = new Map<string, Bitmap>();

async function renderThumbnail(assetId: string, user: User) {
  if (!user.canView(assetId)) throw new Error("forbidden"); // repeated at
  let bitmap = cache.get(assetId);                          // every call site
  if (!bitmap) {
    bitmap = await decodeFromDisk(assetId); // loader now owns caching too
    cache.set(assetId, bitmap);
  }
  draw(bitmap);
}
```

### Do

```typescript
// Same interface, access policy layered in front; callers stay ignorant
interface ImageLoader {
  load(assetId: string): Promise<Bitmap>;
}

const diskLoader: ImageLoader = { load: (id) => decodeFromDisk(id) };

function cachingLoader(next: ImageLoader): ImageLoader {
  const cache = new Map<string, Promise<Bitmap>>();
  return {
    load(id) {
      const hit = cache.get(id);
      if (hit) return hit;
      const pending = next.load(id);
      cache.set(id, pending);
      return pending;
    },
  };
}

function guardedLoader(next: ImageLoader, user: User): ImageLoader {
  return {
    load: (id) =>
      user.canView(id) ? next.load(id) : Promise.reject(new Error("forbidden")),
  };
}

const loader = guardedLoader(cachingLoader(diskLoader), currentUser);
await loader.load("hero-banner"); // caching + auth, invisible to the call site
```

**Idiomatic TS:** Prefer an explicit wrapper (object or function) implementing the same interface — it is type-safe and greppable. JavaScript's native `Proxy` object fits only genuinely dynamic interception (unknown property names, instrumentation, mocking frameworks); as a default it defeats type checking and hides behavior. Note the overlap with Decorator: the wrapping shape is identical — the difference is intent, controlling *access* versus adding *behavior*.

---

## Sources

- Gamma, Helm, Johnson, Vlissides — *Design Patterns: Elements of Reusable Object-Oriented Software* (1994): canonical intents for Adapter, Decorator, Facade, Composite, Proxy.
- refactoring.guru design-patterns catalog — consulted for pattern selection and naming only; all examples here are original (its code is CC BY-NC-ND and not reused).
- MDN Web Docs, [`Proxy`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy) — the native dynamic-interception object discussed under Proxy.
