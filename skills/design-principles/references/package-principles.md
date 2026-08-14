# Package Principles (Component Cohesion & Coupling)

Robert C. Martin's six package-level principles — the half of the canon that pattern archives skip, governing what goes *into* a module boundary and how boundaries may *depend* on each other.

## Contents

- [How to read this file](#how-to-read-this-file)
- Cohesion — what goes IN a package
  - [Release-Reuse Equivalence Principle (REP)](#release-reuse-equivalence-principle-rep)
  - [Common Closure Principle (CCP)](#common-closure-principle-ccp)
  - [Common Reuse Principle (CRP)](#common-reuse-principle-crp)
- Coupling — how packages RELATE
  - [Acyclic Dependencies Principle (ADP)](#acyclic-dependencies-principle-adp)
  - [Stable Dependencies Principle (SDP)](#stable-dependencies-principle-sdp)
  - [Stable Abstractions Principle (SAP)](#stable-abstractions-principle-sap)
- [Sources](#sources)

## How to read this file

The six principles form two triads:

- **Cohesion (REP, CCP, CRP)** — what belongs inside one package.
- **Coupling (ADP, SDP, SAP)** — which dependency arrows between packages are allowed.

"Package" here means any deployable or importable module boundary: an npm package, a pnpm workspace package, a folder with an `index.ts` barrel, a microservice. If it has consumers that import it as a unit, these principles apply to it.

The cohesion triad is a **tension triangle** — you cannot maximize all three at once. REP and CRP pull toward small, single-purpose, independently released packages; CCP pulls toward lumping everything that changes together into one place. Early in a project, **CCP wins**: optimize for making a change touch one package. As the code grows external consumers and real reuse, the balance shifts toward **REP and CRP**: optimize for consumers not being disturbed by churn they don't care about. Repartitioning packages over a project's life is expected, not a failure.

The coupling triad is not negotiable in the same way: ADP is close to absolute, and SDP/SAP become binding as soon as packages have independent consumers or release cadences.

Running example throughout: a monorepo with workspace packages `orders`, `billing`, `notifications`, and a grab-bag `shared-utils`.

---

## Release-Reuse Equivalence Principle (REP)

**Canonical statement:** "The granule of reuse is the granule of release." — Robert C. Martin, Principles of OOD (2000)

**What it protects:** Consumers of reused code, by guaranteeing they depend on a tracked, versioned unit — not on someone else's file layout.

**Use when:**
- Code is consumed by more than one team, repo, or deploy unit.
- You are tempted to deep-import another package's internals "just this once".
- A shared folder is copy-pasted between projects and the copies are drifting.

**Skip when:**
- Code is app-internal with a single consumer and will never be reused outside the repo — versioning it separately is ceremony without a customer.
- The "reuse" is two call sites in the same package.

**Trade-off:** Releasing a real granule buys consumers stability (they upgrade on their schedule) at the cost of maintainer overhead — versioning, changelogs, deprecation. Pay it only where reuse is real; speculative packages are YAGNI at the package level.

**Smell that calls for it:** `import { x } from '../../billing/src/utils/format'` — reaching through another package's `src/`.
**Smell of overuse:** A repo with 40 published packages and one consumer each, where every change is a five-package release train.

### Don't

```typescript
// orders/src/receipt.ts — "reusing" billing's internals by path.
// No version, no contract; billing can break this by renaming a folder.
import { formatMoney } from '../../billing/src/utils/format';
```

### Do

```typescript
// The reused granule is its own released package with a public entry point.
// orders/package.json
// { "dependencies": { "@acme/money": "^2.1.0" } }
import { formatMoney } from '@acme/money';
```

Reuse arrives through a version you chose, not through a path you found.

---

## Common Closure Principle (CCP)

**Canonical statement:** "Classes that change together are packaged together." — Robert C. Martin, Principles of OOD (2000)

**What it protects:** The maintainer's cost of change — one requirement change should mean one package touched, one release cut.

**Use when:**
- Partitioning a new project: group by reason-to-change (business capability), not by technical layer.
- One routine kind of change (a tax rule, a pricing rule) forces edits and releases across several packages.
- You're unsure how to split — CCP is the default winner early in a project's life.

**Skip when:**
- The things that "change together" have different consumers — dragging them into one package makes every consumer depend on all of it (CRP objects).
- Change patterns are still unknown; guessing closure is speculation. Wait for two or three real changes and split along the seams they reveal.

**Trade-off:** CCP deliberately increases the size and internal coupling of a package to shrink the blast radius of a change. It is the Single Responsibility Principle lifted to packages: one reason to change per package.

**Smell that calls for it:** Every VAT tweak produces a three-package pull request and a coordinated release.
**Smell of overuse:** A `core` package that everything changes with — closure so broad it recreated the monolith.

### Don't

```text
A VAT rate change touches all three:

  orders/        -> applies tax in checkout total
  billing/       -> computes tax on invoices
  shared-utils/  -> taxRates.ts lookup table
```

### Do

```text
Tax logic is closed inside billing; a VAT change is one edit, one release:

  billing/src/tax/   rates.ts, applyTax.ts   (the only tax code in the repo)
  orders  ──depends on──▶  billing's public tax API
```

---

## Common Reuse Principle (CRP)

**Canonical statement:** "Classes that are used together are packaged together." — Robert C. Martin, Principles of OOD (2000)

**What it protects:** Consumers, from depending on — and being rebuilt, retested, and redeployed for — code they never call. This is the Interface Segregation Principle at package scale.

**Use when:**
- Consumers routinely import one corner of a package and ignore the rest.
- An unrelated change in a grab-bag package forces downstream version bumps ("why did the CSV fix bump my checkout?").
- A package's dependency tree drags heavy transitive deps into consumers that use none of them.

**Skip when:**
- There is one consumer and it uses everything — splitting buys nothing.
- The split would scatter code that CCP says changes together; early on, prefer the CCP lump and split when a second consumer appears.

**Trade-off:** CRP pushes toward many small packages (less unwanted coupling per consumer) and directly against CCP's fewer-bigger packages (less coordination per change). The triangle is real: pick your pain for the project's current age.

**Smell that calls for it:** Depending on `shared-utils` for `formatMoney` pulls a CSV parser and a retry library into a browser bundle.
**Smell of overuse:** Left-pad syndrome — one-function packages whose install and upgrade overhead dwarfs their content.

### Don't

```typescript
// shared-utils/index.ts — things used together? No: four unrelated audiences.
export * from './money';   // used by orders, billing
export * from './csv';     // used by reporting job only (drags in fast-csv)
export * from './retry';   // used by notifications only
export * from './dates';   // used everywhere
```

### Do

```text
Split along lines of common use; each consumer depends only on what it calls:

  @acme/money    ◀── orders, billing
  @acme/csv      ◀── reporting
  @acme/retry    ◀── notifications
  @acme/dates    ◀── (genuinely everyone)
```

---

## Acyclic Dependencies Principle (ADP)

**Canonical statement:** "The dependency graph of packages must have no cycles." — Robert C. Martin, Principles of OOD (2000)

**What it protects:** The ability to build, test, version, and reason about packages independently. A cycle fuses its members into one de-facto package with extra steps.

**Use when:**
- Always. Enforce it mechanically (dependency-cruiser, ESLint `import/no-cycle`, or your build graph) rather than by review.
- Two packages need each other: that is the signal to extract a third package or invert one arrow — never to add the second edge.

**Skip when:**
- There is no skip-case worth honoring in application code. Cycles inside a *single* package are tolerated by compilers but are the same smell at smaller scale — the only honest "skip" is not having drawn package boundaries yet.

**Trade-off:** Breaking a cycle costs you a new package or an interface (more pieces); keeping it costs you independent releasability of everything on the loop. The first cost is paid once, the second on every change forever.

**Smell that calls for it:** You cannot test or version `orders` without building `billing`, and vice versa; "morning-after syndrome" — someone else's change breaks you overnight.
**Smell of overuse:** None observed in practice; nobody has ever regretted an acyclic graph.

### Don't

```text
  orders ──▶ billing          billing needs OrderRef back from orders:
    ▲            │
    └────────────┘            orders ⇄ billing — one blob, two names
```

```typescript
// billing/src/invoice.ts
import { OrderRef } from 'orders';   // completes the cycle
```

### Do

```text
Extract the shared contract downward — both depend on it, neither on the other:

  orders ──▶ billing
     │          │
     └──▶ domain-types ◀──┘      (OrderRef lives here)
```

Alternatively invert with DIP: `billing` defines the `OrderLookup` interface it needs; `orders` implements it. Either way the graph is a DAG again.

---

## Stable Dependencies Principle (SDP)

**Canonical statement:** "Depend in the direction of stability." — Robert C. Martin, Principles of OOD (2000)

**What it protects:** Volatile packages' freedom to change. A package designed to change easily must not be depended on by one that is hard to change.

Martin's metric, in plain words: instability **I = fan-out / (fan-in + fan-out)** — the fraction of a package's couplings that point *outward*. I = 0 means everyone depends on you and you depend on no one (maximally stable, hard to change responsibly); I = 1 means the reverse (free to change). SDP says every dependency arrow should point from higher I to lower I.

**Use when:**
- Packages have independent consumers or release cadences — that's when a wrong-direction arrow starts hurting.
- Deciding where a new dependency arrow may point: check you're not making a widely-depended-on package depend on a churning one.
- A "stable" package keeps releasing because something under it keeps changing.

**Skip when:**
- A small app with one deploy unit and no external consumers — every package is effectively volatile, and the metric is noise.
- The dependency is on a concrete but *non-volatile* module (Martin's own DIP carve-out — stable standard-library-grade code injects no volatility).

**Trade-off:** Honoring SDP sometimes means adding an interface package just to turn an arrow around — more indirection, bought with immunity from a volatile package's churn.

**Smell that calls for it:** A type-only, everything-depends-on-it package imports from a feature package that changes weekly.
**Smell of overuse:** Inverting arrows onto abstractions for packages that never actually change.

### Don't

```typescript
// domain-types (fan-in: every package; I ≈ 0 — stable by position)
import { EmailTemplateId } from 'notifications';  // notifications ships weekly

// Every notifications release now ripples through the most
// depended-on package in the repo.
```

### Do

```text
Volatile depends on stable, never the reverse:

  notifications (I high) ──▶ domain-types (I ≈ 0)

domain-types owns the TemplateId type; notifications imports it.
```

---

## Stable Abstractions Principle (SAP)

**Canonical statement:** "Abstractness increases with stability." — Robert C. Martin, Principles of OOD (2000)

**What it protects:** Stable packages from rigidity. If everyone depends on you, you can't change — so you'd better be made of interfaces, which can be *extended* without being *modified* (OCP at package scale).

Abstractness, in plain words: **A = abstract types / total types** in the package. SAP pairs with SDP: packages that are stable (low I) should be abstract (high A); volatile packages (high I) should be concrete. A stable *and* concrete package sits in Martin's "zone of pain" — hard to change, impossible to extend.

**Use when:**
- A package's fan-in is growing: migrate its public surface toward interfaces and types as it stabilizes.
- Everyone depends directly on a concrete implementation (a specific vendor SDK wrapper, a specific ORM) — put an abstract package in front.
- You need to swap an implementation and discover every consumer names the concrete class.

**Skip when:**
- The package has no independent consumers yet — abstracting a volatile package is speculative generality (the opposite corner, Martin's "zone of uselessness": maximally abstract, nobody depends on it).
- The stable concrete thing is standard-library-grade and effectively frozen; depending on it is fine (same carve-out as SDP).

**Trade-off:** High abstractness buys extension-without-modification for the whole dependency tree, paid for in indirection — every abstract package needs at least one concrete package implementing it.

**Smell that calls for it:** Swapping Stripe for Adyen means editing `orders`, `billing`, and `notifications`.
**Smell of overuse:** Interface-only packages with a single implementor and no realistic second one, ever.

### Don't

```typescript
// payment-gateway: stable (everyone imports it) AND concrete. Zone of pain.
export class StripeGateway {
  charge(cents: number, source: string) { /* Stripe-specific */ }
}
// orders, billing, notifications all: import { StripeGateway } from 'payment-gateway';
```

### Do

```text
Stable package is abstract; concretions are volatile leaves:

  orders, billing ──▶ payments-api (interfaces: PaymentGateway) ◀── payments-stripe
                                                                ◀── payments-adyen
```

```typescript
// payments-api — stable, abstract
export interface PaymentGateway {
  charge(cents: number, source: PaymentSource): Promise<ChargeResult>;
}

// payments-stripe — volatile, concrete, swappable
export class StripeGateway implements PaymentGateway { /* ... */ }
```

---

## Sources

- Robert C. Martin, *The Principles of OOD*, butunclebob.com (`ArticleS.UncleBob.PrinciplesOfOod`) — canonical one-line statements of all six principles (quoted verbatim above).
- Robert C. Martin, *Design Principles and Design Patterns* (2000) — the paper introducing the principles as dependency-management tools; source of the I and A metrics.
- Robert C. Martin, *Clean Architecture* (2017), Part IV "Component Principles" — republication and expansion, including the tension triangle and the pain/uselessness zones.
- Coverage gap, verified 2026-07-15: neither java-design-patterns.com/principles/ (26 principles listed) nor refactoring.guru covers any of these six — which is why this file exists.
