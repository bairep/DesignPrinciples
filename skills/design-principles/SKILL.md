---
name: design-principles
description: Opinionated, language-agnostic archive of software design principles (SOLID, Martin's package principles, DRY, KISS, YAGNI, composition-over-inheritance, Law of Demeter, CUPID) and the most common GoF design patterns, each with when-to-use, when-NOT-to-use, coupling trade-offs, and do/don't TypeScript examples. Use when designing or restructuring modules, choosing or evaluating a design pattern, reviewing code for design quality, aligning agent-written code with design standards, practicing design katas, or when asked to check or update these design standards against the latest sources.
---

# Design Principles & Patterns

An opinionated archive of design principles and patterns: what each one protects, when to reach for it, when to skip it, and what it costs. Prose is language-agnostic; all examples are TypeScript.

## Philosophy — read this before applying anything

1. **Properties, not rules.** Following Dan North's CUPID argument, design qualities are graded, not binary. Every entry here has a **Use when** AND a **Skip when** — if you can't articulate the skip case, you don't understand the principle yet.
2. **It's all dependency management.** Martin's stated purpose for the principles: preventing the four symptoms of design rot — rigidity, fragility, immobility, viscosity — all caused by improper dependencies between modules. The organizing question is always: *which change becomes cheaper, and which coupling do I pay for it?*
3. **Patterns are vocabulary, not goals.** Applying a pattern where a language feature suffices (Strategy where a function type would do) adds indirection for nothing. Reach for the language first — see [references/pattern-selection.md](references/pattern-selection.md).
4. **YAGNI governs features, never code health.** Speculative capability is waste; refactoring, tests, and clarity are not (Fowler). Don't cite YAGNI to skip quality.
5. **Optimize for ease of change.** Not elegance, not purity, not maximal decoupling. A pattern earns its indirection only when the change it enables actually recurs.

## How to use this skill

| You are... | Read |
|---|---|
| Designing or refactoring a module | [pattern-selection.md](references/pattern-selection.md) first, then the matching entry |
| Reviewing code (human- or agent-written) | [code-review-checklist.md](references/code-review-checklist.md) |
| Deciding if a pattern is justified | The pattern's entry — check **Skip when** before **Use when** |
| Learning / deliberate practice | [katas.md](references/katas.md) |
| Updating this skill | Maintenance section below + [sources.md](references/sources.md) |

Read only the reference file you need; each is self-contained.

## Index

### Principles

| Entry | File | Reach for it when... |
|---|---|---|
| Single Responsibility (SRP) | [solid.md](references/solid.md) | One module changes for unrelated reasons/actors |
| Open-Closed (OCP) | [solid.md](references/solid.md) | The same switch/if-chain grows with every new variant |
| Liskov Substitution (LSP) | [solid.md](references/solid.md) | Subtypes surprise callers of the base contract |
| Interface Segregation (ISP) | [solid.md](references/solid.md) | Clients depend on methods they never call |
| Dependency Inversion (DIP) | [solid.md](references/solid.md) | High-level policy imports volatile low-level detail |
| Release-Reuse Equivalence (REP) | [package-principles.md](references/package-principles.md) | Consumers reuse code you don't version/release |
| Common Closure (CCP) | [package-principles.md](references/package-principles.md) | One change touches many packages |
| Common Reuse (CRP) | [package-principles.md](references/package-principles.md) | Importing one thing drags in a kitchen sink |
| Acyclic Dependencies (ADP) | [package-principles.md](references/package-principles.md) | Package/import cycles — always |
| Stable Dependencies (SDP) | [package-principles.md](references/package-principles.md) | Widely-used packages depend on churning ones |
| Stable Abstractions (SAP) | [package-principles.md](references/package-principles.md) | Stable packages are concrete, hard to extend |
| DRY | [general-principles.md](references/general-principles.md) | The same *policy* lives in two places |
| KISS | [general-principles.md](references/general-principles.md) | Always — complexity must earn its keep |
| YAGNI | [general-principles.md](references/general-principles.md) | Building for a presumed future need |
| Composition over Inheritance | [general-principles.md](references/general-principles.md) | Inheritance used for code sharing, not is-a |
| Law of Demeter | [general-principles.md](references/general-principles.md) | Code reaches through object graphs (`a.b.c.d()`) |
| CUPID (framing) | [general-principles.md](references/general-principles.md) | Grading overall design quality |

### Patterns

| Entry | File | Reach for it when... |
|---|---|---|
| Factory Method | [creational-patterns.md](references/creational-patterns.md) | Creation site must not know the concrete type |
| Abstract Factory | [creational-patterns.md](references/creational-patterns.md) | Families of objects must stay consistent |
| Builder | [creational-patterns.md](references/creational-patterns.md) | Telescoping args; stepwise valid construction; test data |
| Singleton | [creational-patterns.md](references/creational-patterns.md) | Almost never — see its Skip when |
| Prototype | [creational-patterns.md](references/creational-patterns.md) | Rarely in TS — `structuredClone` usually wins |
| Adapter | [structural-patterns.md](references/structural-patterns.md) | Foreign/legacy shape at your boundary |
| Decorator | [structural-patterns.md](references/structural-patterns.md) | Optional layered behavior (retry, cache, log) |
| Facade | [structural-patterns.md](references/structural-patterns.md) | Callers need 3 operations from a messy subsystem |
| Composite | [structural-patterns.md](references/structural-patterns.md) | Tree where items and groups share operations |
| Proxy | [structural-patterns.md](references/structural-patterns.md) | Same interface, controlled access (lazy, cached, guarded) |
| Strategy | [behavioral-patterns.md](references/behavioral-patterns.md) | Interchangeable policies — usually just a function type |
| Observer | [behavioral-patterns.md](references/behavioral-patterns.md) | Many reactors to events — prefer platform primitives |
| Command | [behavioral-patterns.md](references/behavioral-patterns.md) | Actions need queuing, logging, retry, or undo |
| State | [behavioral-patterns.md](references/behavioral-patterns.md) | Boolean-flag soup — unions first, classes second |
| Template Method | [behavioral-patterns.md](references/behavioral-patterns.md) | Fixed skeleton, varying steps — prefer function params |
| Chain of Responsibility | [behavioral-patterns.md](references/behavioral-patterns.md) | Variable handler pipelines / middleware |

## Reviewing code with this skill

When asked to review or align code with these standards:

1. Run through [code-review-checklist.md](references/code-review-checklist.md) top to bottom.
2. For each finding, cite the specific entry (file + heading) — never a vague "violates SOLID".
3. Check the entry's **Skip when** before flagging: a "violation" inside its skip case is correct design.
4. Report trade-offs honestly: name the coupling the fix introduces, not just the one it removes.

## Maintenance — keeping this skill current

This skill is self-maintaining. When asked to "update/check the design-principles skill":

1. Run `scripts/check-sources.sh` — verifies every registered source is reachable, checks GitHub repos for new pushes, and fails if the registry's last-verified date is over 180 days old.
2. For flagged sources, re-read them (WebFetch) and diff against the relevant reference file: new patterns, changed guidance, deprecations.
3. Search the web for new consensus (e.g., "design patterns considered harmful <current year>", new editions of registered books/sites).
4. Apply changes surgically to the affected reference file only; update **Last verified** dates in [sources.md](references/sources.md).
5. Run `scripts/validate-skill.sh` — structural self-check (links resolve, TOCs present, template headings intact, SKILL.md under 500 lines).
6. Record what changed and why in the changelog at the bottom of [sources.md](references/sources.md).

**Licensing rule:** refactoring.guru content is CC BY-NC-ND — its catalog informs *which* patterns matter, but every example here must stay original. Never copy or adapt its code.

## Backlog (deliberately not in v1 — YAGNI until needed)

- Modern additions: Repository, Dependency Injection (as a pattern entry), CQRS, Event Sourcing, Circuit Breaker
- Anti-pattern catalog (God object, anemic domain model, distributed monolith)
- Architecture-level patterns (hexagonal, functional core / imperative shell — partially covered by the separate `software-architecture` skill)
