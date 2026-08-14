# Design Katas

Deliberate practice for the entries in this skill. Each kata is small enough for one sitting (30–60 min) and targets one entry's judgment call — not just its mechanics.

## Contents

- [Practice protocol](#practice-protocol)
- [Kata 1 — Strategy: pricing rules](#kata-1--strategy-pricing-rules)
- [Kata 2 — Singleton detox](#kata-2--singleton-detox)
- [Kata 3 — State: form wizard](#kata-3--state-form-wizard)
- [Kata 4 — Builder: test-data factory](#kata-4--builder-test-data-factory)
- [Kata 5 — Decorator: resilient fetcher](#kata-5--decorator-resilient-fetcher)
- [Kata 6 — Adapter + DIP: swap the mailer](#kata-6--adapter--dip-swap-the-mailer)
- [Kata 7 — LSP: the read-only store](#kata-7--lsp-the-read-only-store)
- [Kata 8 — ISP: split the fat repository](#kata-8--isp-split-the-fat-repository)
- [Kata 9 — Observer: typed domain events](#kata-9--observer-typed-domain-events)
- [Kata 10 — ADP: break the cycle](#kata-10--adp-break-the-cycle)
- [Grading yourself](#grading-yourself)

## Practice protocol

1. **Pick a kata.** Read only its linked entry first — including **Skip when**.
2. **Write the Don't version first**, from the kata's setup. Feel why it hurts: try to add the "next change" and note what you had to touch.
3. **Refactor to the Do version** with tests green throughout (TDD where the kata gives behavior).
4. **Interrogate:** could a simpler form (see [pattern-selection.md](pattern-selection.md) — reach for the language first) have worked? If yes, do that version too and compare.
5. **Grade** with the CUPID lens below. Optionally save your solution under `katas/solutions/<kata>-<date>/` in this repo and compare against past attempts.

Run any kata with an agent: paste the setup, have it implement, then review its output against [code-review-checklist.md](code-review-checklist.md) yourself — that trains reviewer judgment, the skill you actually need.

## Kata 1 — Strategy: pricing rules

**Entry:** [behavioral-patterns.md — Strategy](behavioral-patterns.md)
**Setup:** An order total function applies discounts: none, percentage, fixed amount, buy-2-get-1. It's one growing `switch` on `discountType` with per-case params smuggled through optional fields.
**Task:** Extract each rule as a value of one function type; select via a record keyed by discount kind. Then add a "seasonal stacking" rule without touching existing rules.
**Done when:** Adding rule #5 touches one new function + one registry line. No class per strategy unless you can defend it.

## Kata 2 — Singleton detox

**Entry:** [creational-patterns.md — Singleton](creational-patterns.md)
**Setup:** A `Config.getInstance()` read from 8 modules, mutated in 2 (tests flake depending on order).
**Task:** Replace with a config object created once at the entry point and passed explicitly (constructor/param). Delete `getInstance`.
**Done when:** Every consumer declares its config dependency in its signature; two tests can run with different configs in the same process.

## Kata 3 — State: form wizard

**Entry:** [behavioral-patterns.md — State](behavioral-patterns.md)
**Setup:** A 3-step signup wizard tracked with `isStep1Done`, `isSubmitting`, `hasError`, `isComplete` booleans; several combinations are impossible but representable.
**Task:** Model as a discriminated union (`{ step: 'details' } | { step: 'review'; details: Details } | ...`) with an exhaustive transition function.
**Done when:** Illegal states don't compile; the `never` check in the `switch` catches a newly added state.

## Kata 4 — Builder: test-data factory

**Entry:** [creational-patterns.md — Builder](creational-patterns.md)
**Setup:** Tests construct `Invoice` objects with 9 fields; every test repeats all 9, obscuring which field matters.
**Task:** Write `anInvoice()` returning a valid default, with overrides — fluent builder or `(overrides?: Partial<Invoice>)` function. Do both; pick one and justify.
**Done when:** Each test states only the fields it cares about; invalid combinations are unrepresentable or rejected at build().

## Kata 5 — Decorator: resilient fetcher

**Entry:** [structural-patterns.md — Decorator](structural-patterns.md)
**Setup:** `fetchQuote(symbol): Promise<Quote>` needs retry, then caching, then timing logs — currently being braided into one 60-line function.
**Task:** Keep the core fetcher pure; add `withRetry`, `withCache`, `withTiming` as higher-order functions over the same function type. Compose in different orders and observe the behavioral difference (cache-then-retry vs retry-then-cache).
**Done when:** Each concern is one small wrapper; composition order is explicit at the call site.

## Kata 6 — Adapter + DIP: swap the mailer

**Entries:** [structural-patterns.md — Adapter](structural-patterns.md), [solid.md — DIP](solid.md)
**Setup:** Order confirmation calls a vendor SDK (`sendgrid.send({...vendor shape})`) from inside the order service.
**Task:** Define the port your domain needs (`sendReceipt(to, order)`), adapt the vendor to it at the edge, inject the port. Then "switch vendors" by writing a second adapter.
**Done when:** The order service compiles with zero vendor imports; swapping adapters touches only the composition root.

## Kata 7 — LSP: the read-only store

**Entry:** [solid.md — LSP](solid.md)
**Setup:** `CachedStore extends Store` but throws on `write()` ("cache is read-only"). Callers now try/catch or `instanceof`.
**Task:** Fix the hierarchy: separate `ReadableStore` / `WritableStore` interfaces so the read-only type never promises `write`.
**Done when:** No caller special-cases a subtype; the compiler prevents passing a read-only store where writes happen.

## Kata 8 — ISP: split the fat repository

**Entry:** [solid.md — ISP](solid.md)
**Setup:** `UserRepository` has 12 methods; the password-reset flow uses 2, but its tests stub all 12.
**Task:** Carve client-specific interfaces (`Pick`, or small explicit interfaces) per consumer; the concrete repo implements all of them (structural typing does the work).
**Done when:** Password-reset's test double has exactly 2 members.

## Kata 9 — Observer: typed domain events

**Entry:** [behavioral-patterns.md — Observer](behavioral-patterns.md)
**Setup:** Checkout must trigger receipt email, inventory decrement, and analytics — today via direct calls, coupling checkout to all three.
**Task:** Version A: platform primitive (`EventTarget`/`EventEmitter`). Version B: a 20-line typed emitter over a domain-event union (`OrderPlaced | OrderRefunded`) with exhaustive payload types. Compare.
**Done when:** You can articulate what B's type safety bought and what its extra code cost — and when you'd accept A.

## Kata 10 — ADP: break the cycle

**Entry:** [package-principles.md — ADP](package-principles.md)
**Setup:** `orders` imports `billing` for pricing; `billing` imports `orders` for the `Order` type. Cycle.
**Task:** Break it both canonical ways: (a) extract the shared type into a `domain` package both import; (b) invert one edge with an interface owned by the consumer. Say when each applies.
**Done when:** Dependency graph is acyclic (verify: `npx madge --circular` or by inspection) and you can defend the direction you chose.

## Grading yourself

Score each solution 1–5 on the CUPID properties ([general-principles.md — The CUPID lens](general-principles.md)):

- **Composable** — could another caller reuse the pieces without ceremony?
- **Unix** — does each unit do one thing well?
- **Predictable** — any surprises (hidden state, throws, ordering)?
- **Idiomatic** — would a TS developer read it as native, or as Java-in-TS?
- **Domain-based** — do names come from the problem domain, not the pattern (`PricingRule`, not `AbstractStrategyImpl`)?

A kata is *internalized* when you can state — without looking — the entry's **Skip when** and the simplest form that would also have worked.
