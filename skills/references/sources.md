# Source Registry

Every external source this skill is grounded in, what it's for, and what to check when updating. `scripts/check-sources.sh` reads the table below.

## Contents

- [Registry](#registry)
- [Update procedure](#update-procedure)
- [Licensing rules](#licensing-rules)
- [Changelog](#changelog)

## Registry

Last full verification: **2026-07-15** (deep-research run, 25/25 claims confirmed, 0 refuted).

<!-- check-sources:begin -->
| Source | URL | Role | On update, check |
|---|---|---|---|
| Martin, Principles of OOD | http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod | Canon: SOLID + 6 package principles (verbatim one-liners) | Page reachable (HTTP-only host); mirrors if down |
| Martin, Design Principles and Design Patterns (2000) | https://staff.cs.utu.fi/staff/jouni.smed/doos_06/material/DesignPrinciplesAndPatterns.pdf | Canon: rot symptoms, OCP/DIP softenings | Host has broken TLS; verify via mirrors |
| Fowler, Yagni | https://martinfowler.com/bliki/Yagni.html | YAGNI scoping + four costs | Content changes to the bliki entry |
| Dan North, CUPID | https://cupid.dev/properties | Contrarian framing: graded properties | New/renamed properties |
| refactoring.guru catalog | https://refactoring.guru/design-patterns/catalog | Pattern canon (22 patterns, no Interpreter) | Catalog additions/removals |
| refactoring.guru criticism | https://refactoring.guru/design-patterns/criticism | Misuse pitfalls | — |
| RefactoringGuru TS repo | https://github.com/RefactoringGuru/design-patterns-typescript | Example FORMAT reference only (license!) | Push date; pattern list drift vs our files |
| java-design-patterns | https://java-design-patterns.com/patterns/ | Broad pattern index (seed) | New patterns tagged as recommended |
| adnanhakim oop-principles | https://github.com/adnanhakim/copilot-instructions/blob/main/spring-boot/copilot-rules/oop-principles.md | Seed: agent-rules formatting inspiration | Push date |
| patterns.dev | https://www.patterns.dev/ | Modern JS/web patterns (backlog source) | New patterns worth adding |
| Learning JS Design Patterns, 2nd ed. | https://patterns.addy.ie/ | Modern JS pattern reference | New edition |
| awesome-design-patterns | https://github.com/DovAmir/awesome-design-patterns | Meta-index (cloud/microservices backlog) | Push date |
| awesome-software-architecture | https://github.com/mehdihadeli/awesome-software-architecture | Meta-index, architecture patterns | Releases |
| Anthropic skill best practices | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices | Skill structure rules (500-line router, one-level-deep refs) | Changed size/structure guidance |
| Agent Skills spec | https://agentskills.io/specification | Frontmatter/layout spec | Spec version bumps |
<!-- check-sources:end -->

Internal: `design-principles-skill-research.md` (repo root) — the verified deep-research report this v1 was built from.

## Update procedure

Triggered by "update/check the design-principles skill" (full steps in SKILL.md → Maintenance):

1. `scripts/check-sources.sh` — reachability + GitHub push dates + staleness gate (fails >180 days since Last full verification).
2. Re-read flagged sources; diff guidance against the relevant reference file.
3. Web-search for new consensus: pattern deprecations, new editions, "considered harmful" debates worth encoding as **Skip when** bullets.
4. Edit surgically; one reference file per concern. Examples stay original (see licensing).
5. `scripts/validate-skill.sh` must pass.
6. Bump the **Last full verification** date above and append to the changelog.

## Licensing rules

- **refactoring.guru / RefactoringGuru repo: CC BY-NC-ND 4.0.** Consult for *which* patterns matter and how they present examples — never copy or adapt their code or prose. All examples in this skill are original.
- awesome-software-architecture is CC0; Martin/Fowler/North pages are quoted minimally with attribution (short canonical statements).

## Changelog

- **2026-07-15** — v1. Built from deep-research report (5 SOLID + 6 package principles + 5 general principles + CUPID lens; 16 patterns across creational/structural/behavioral; pattern-selection guide; review checklist; 10 katas; self-check scripts).
