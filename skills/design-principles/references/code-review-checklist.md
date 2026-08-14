# Design Code-Review Checklist

For reviewing any code — human- or agent-written — against this skill's standards. Work top to bottom; cite findings as `file.md → entry heading`, and always check the entry's **Skip when** before flagging.

## Contents

- [How to review with this checklist](#how-to-review-with-this-checklist)
- [1. Dependency direction](#1-dependency-direction)
- [2. Change axes (cohesion)](#2-change-axes-cohesion)
- [3. Abstraction quality](#3-abstraction-quality)
- [4. Pattern usage sanity](#4-pattern-usage-sanity)
- [5. Simplicity and speculation](#5-simplicity-and-speculation)
- [6. TypeScript idiom](#6-typescript-idiom)
- [Writing the finding](#writing-the-finding)

## How to review with this checklist

- A checklist item failing is a *candidate* finding, not a verdict — confirm against the linked entry's Skip when.
- Rank findings by which future change they make expensive, not by rule-purity.
- Two or three high-impact findings beat ten nitpicks.

## 1. Dependency direction

- [ ] Does high-level policy import low-level volatile detail (DB clients, SDKs, HTTP libs) directly? → [solid.md — DIP](solid.md)
- [ ] Are stable-and-widely-imported modules depending on churning ones? → [package-principles.md — SDP](package-principles.md)
- [ ] Any import cycles between modules/packages? Flag unconditionally. → [package-principles.md — ADP](package-principles.md)
- [ ] Do third-party types leak past the boundary module that imports them? → [structural-patterns.md — Adapter](structural-patterns.md)
- [ ] Exception check: is the concrete dependency *non-volatile* (stdlib, platform API)? Then it's fine — Martin's own DIP carve-out.

## 2. Change axes (cohesion)

- [ ] Does one module serve unrelated actors/reasons to change (e.g., report formatting + persistence + validation)? → [solid.md — SRP](solid.md)
- [ ] Does adding a new variant of an existing concept require edits in N scattered places? → [solid.md — OCP](solid.md), [behavioral-patterns.md — Strategy](behavioral-patterns.md)
- [ ] Does one logical change require touching several packages at once? → [package-principles.md — CCP](package-principles.md)
- [ ] Is the same *business rule* (not similar-looking code) encoded twice? → [general-principles.md — DRY](general-principles.md)

## 3. Abstraction quality

- [ ] Can every subtype substitute for its base without callers special-casing (`instanceof`, try/catch around specific impls)? → [solid.md — LSP](solid.md)
- [ ] Do clients depend on interface members they never use? → [solid.md — ISP](solid.md)
- [ ] Is inheritance used for code reuse rather than a true, stable is-a? → [general-principles.md — Composition over Inheritance](general-principles.md)
- [ ] Does code reach through object graphs (`order.customer.account.plan.limits`)? Structure coupling. → [general-principles.md — Law of Demeter](general-principles.md)
- [ ] Does any interface have exactly one implementation and no test-double need? Speculative — inline it.

## 4. Pattern usage sanity

- [ ] Is there a class hierarchy where a function type would do (Strategy/Command/Template Method)? → [pattern-selection.md — Reach for the language first](pattern-selection.md)
- [ ] Singleton or module-level *mutable* state accessed from arbitrary depth? → [creational-patterns.md — Singleton](creational-patterns.md)
- [ ] Hand-rolled observer where `EventTarget`/`EventEmitter`/framework store suffices? → [behavioral-patterns.md — Observer](behavioral-patterns.md)
- [ ] Boolean-flag combinations encoding an implicit state machine? → [behavioral-patterns.md — State](behavioral-patterns.md)
- [ ] Facade that re-exports the whole subsystem (god-facade)? → [structural-patterns.md — Facade](structural-patterns.md)
- [ ] Pattern named in a class name (`FooStrategyFactoryImpl`) without the pattern's problem being present? Pattern-first design — flag it.

## 5. Simplicity and speculation

- [ ] Configurability, hooks, or params no current caller uses? → [general-principles.md — YAGNI](general-principles.md)
- [ ] Could this be a quarter of the size with the same behavior? → [general-principles.md — KISS](general-principles.md)
- [ ] Is an abstraction premature — fewer than ~3 real usage sites? (Duplication is cheaper than the wrong abstraction.)
- [ ] Counter-check: is someone *citing* YAGNI to skip tests/refactoring? That's the misuse — YAGNI never applies to code health.

## 6. TypeScript idiom

- [ ] `any` or unchecked casts where a union/generic would carry the type? 
- [ ] Illegal states representable (optional fields that are really variant-dependent) instead of discriminated unions?
- [ ] Mutable shared structures where `readonly`/immutability was cheap?
- [ ] Enums/string flags compared ad hoc instead of exhaustive `switch` with `never` check?

## Writing the finding

Format each finding as:

```
[<severity>] <file:line> — <one-sentence defect>
Entry: <reference file> → <entry name>
Cost: <which future change this makes expensive>
Fix: <smallest change that resolves it — and the coupling the fix introduces>
```

Severity by cost-of-change, not aesthetics: **high** = recurring change made expensive or correctness trap (LSP/ADP); **medium** = coupling that will hurt at the next feature; **low** = idiom/clarity.
