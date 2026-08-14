# Design Principles (Uncle Bob / Clean Architecture arc) — plan

> Created 2026-08-14. Learner: experienced engineer, TS-fluent.
> Goal: full working command — own design work, code review, steering coding
> agents (swarm-forge). Pace: intensive (several sessions/week). No deadline.
> Prior: applies some SOLID, fuzzy on others.
> Source of truth: `design-principles` skill archive + live sources; verify
> mechanism claims before asserting (profile rule).

**Anki deck:** `DesignPrinciples`

## Stages (big-picture-first)

1. **Why principles exist — dependencies are the enemy.**
   Design rot (rigidity, fragility, immobility, viscosity); source-code
   dependency vs flow of control. ⚑ THRESHOLD: a dependency can point
   *against* the flow of control (the inversion move). Everything later
   is applications of this.
2. **SOLID at class level.** SRP, OCP, LSP, ISP, DIP — each as "which
   change does this protect me from". ⚑ THRESHOLD: LSP as substitutability
   contract (not inheritance syntax); DIP as ownership of the interface.
3. **Component cohesion.** REP, CCP, CRP — what belongs together in a
   package and why the three tension against each other.
4. **Component coupling.** ADP, SDP, SAP — dependency direction between
   packages; stability/abstractness metrics as review instruments.
5. **Boundaries & the Dependency Rule.** Policy vs detail, the rings,
   crossing boundaries, humble objects. Where SOLID scales into
   architecture.
6. **Applied practice.** Review agent-written code against stages 1–5;
   design katas via code-kata skill; violation-spotting drills.

## Gating

Advance only when current chunks are explainable unprompted and topic
cards aren't leeching. Expected fuzzy zones (from intake): identify which
SOLID letters are weak in session 1 and drill transfer, not coverage
(known failure signature: retrieval fails under changed question shape).
