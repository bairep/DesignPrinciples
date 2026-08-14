# Pattern Selection Guide

How to go from a code smell to the right entry — and when the right answer is no pattern at all.

## Contents

- [Reach for the language first](#reach-for-the-language-first)
- [Symptom → candidate](#symptom--candidate)
- [The coupling ladder](#the-coupling-ladder)
- [When no pattern is the answer](#when-no-pattern-is-the-answer)
- [Sources](#sources)

## Reach for the language first

The classic criticism of design patterns (acknowledged even by refactoring.guru's own criticism page): many are kludges for missing language features. TypeScript has first-class functions, closures, structural typing, discriminated unions, and modules — these absorb whole patterns. Check this table before building any class hierarchy:

| Classical pattern | Idiomatic TS replacement | Keep the classical form when... |
|---|---|---|
| Strategy | A function type: `type Rule = (x: Input) => Output` | Strategies carry config/state or several related methods |
| Command | A closure (plus optional `undo` closure) | Commands must be serialized/persisted |
| Observer | `EventTarget`, Node `EventEmitter`, framework signals/stores | You need exhaustively-typed domain event unions |
| Template Method | A function taking step-functions as parameters | You're already inside a framework base class |
| Singleton | A module-scoped instance, injected explicitly | Never for global mutable state |
| Prototype | `structuredClone`, spread, factory functions | Polymorphic copy through an abstract interface |
| Factory (simple) | A plain function returning an interface type | You need families of consistent objects (Abstract Factory) |
| State | Discriminated union + exhaustive `switch` | States carry distinct heavy behavior — class-per-state |
| Decorator | Higher-order function wrapping a function type | The wrapped surface has multiple methods |
| Iterator | Built-in iterables / generators (`function*`) | Practically never hand-rolled in TS |

If the replacement column solves your problem, stop there. The pattern's *name* is still useful vocabulary ("this is a Strategy") even when the implementation is three lines.

## Symptom → candidate

Diagnose by the smell, not by pattern shopping:

| Smell in the code | Candidate | Entry |
|---|---|---|
| Same `switch`/`if` chain on a type tag grows with every variant | Strategy, or OCP via polymorphism | [behavioral-patterns.md](behavioral-patterns.md), [solid.md](solid.md) |
| Constructor with 5+ params, half optional | Builder — or an options object | [creational-patterns.md](creational-patterns.md) |
| `new ConcreteThing()` scattered where the concrete type varies by env/config/test | Factory Method | [creational-patterns.md](creational-patterns.md) |
| Third-party SDK types leaking through your codebase | Adapter (+ DIP port) | [structural-patterns.md](structural-patterns.md), [solid.md](solid.md) |
| Cross-cutting behavior (retry, cache, log) copy-pasted into business logic | Decorator | [structural-patterns.md](structural-patterns.md) |
| Callers must understand 6 subsystem classes to do one thing | Facade | [structural-patterns.md](structural-patterns.md) |
| Boolean flags multiplying (`isLoading && !hasError && isDirty`) | State (union-first) | [behavioral-patterns.md](behavioral-patterns.md) |
| Tree structure where groups and items get different code paths | Composite | [structural-patterns.md](structural-patterns.md) |
| Actions that need undo, audit log, queue, or retry | Command | [behavioral-patterns.md](behavioral-patterns.md) |
| Modules polling or reaching into each other for changes | Observer | [behavioral-patterns.md](behavioral-patterns.md) |
| Request must pass a variable set of handlers | Chain of Responsibility | [behavioral-patterns.md](behavioral-patterns.md) |
| Expensive resource built eagerly, or access needs guarding | Proxy | [structural-patterns.md](structural-patterns.md) |
| One change fans out across many packages | CCP / module boundaries | [package-principles.md](package-principles.md) |
| Import cycles between packages | ADP — fix unconditionally | [package-principles.md](package-principles.md) |

## The coupling ladder

Every pattern trades one coupling for another. Rank options by what the *caller* must know:

1. **Plain function call** — caller knows name + types. Cheapest. Default.
2. **Injected dependency (DIP port)** — caller knows an interface; wiring moved to composition root. Pay: indirection when navigating code. Buy: substitutability, testability.
3. **Event/observer** — caller knows nothing about reactors. Pay: hidden control flow, harder debugging. Buy: open-ended fan-out.
4. **Middleware/chain** — order-dependent implicit pipeline. Pay: hardest to trace. Buy: runtime-composable behavior.

Move DOWN the ladder (toward 1) unless the flexibility of a higher rung is exercised by a real, recurring change. A pattern whose flexibility is never exercised is pure carrying cost (Fowler's *cost of carry*).

## When no pattern is the answer

- **The variation isn't recurring.** One-off difference → an `if` statement. Second occurrence → still maybe an `if`. Extract at the third (rule of three).
- **You control both sides.** Adapter/Facade exist for boundaries you *don't* own. If it's all your code, change the inconvenient side.
- **The abstraction would have one implementation** and no test-double need. Interfaces with a single implementer are speculative generality (YAGNI).
- **You're reaching for a pattern to feel senior.** The GoF book is a vocabulary of solutions to *observed* problems. Pattern-first design inverts that — refactoring.guru's criticism page calls this the novice trap: "if all you have is a hammer, everything looks like a nail."

## Sources

- Gamma, Helm, Johnson, Vlissides — *Design Patterns* (1994): patterns as discovered vocabulary
- refactoring.guru/design-patterns/criticism — patterns-as-kludges, dogmatic application
- Fowler, *Yagni* (martinfowler.com/bliki/Yagni.html) — cost of carry
- Dan North, CUPID (cupid.dev) — graded properties over binary rules
