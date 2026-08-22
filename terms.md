# Design Principles — terms dictionary

| Term | Definition | Synonyms heard | Avoid |
|---|---|---|---|
| control | Which code the CPU executes now: program counter + active stack frame. | the baton, execution | — |
| flow of control | Path the thread takes through code over time: call pushes a frame into the callee, return pops it back. Always flows domain → infra detail; never inverted. | runtime flow | "inverted control flow" (in DIP context) |
| source-code dependency | Compile-time import arrow. The one DIP inverts: adapter (infra) imports the port (domain). | import arrow | — |
| DIP | Dependency Inversion Principle: the source-code dependency points in the direction opposite to the flow of control (Uncle Bob wording — learner's anchor). | dependency inversion | conflating with IoC |
| IoC | Inversion of Control, Hollywood principle: a framework calls your code. Different idea from DIP; in DIP control is never inverted. | Hollywood principle | using "IoC" to mean DIP |
| port | Interface the domain owns, named after the domain need, lives in the domain layer. | port interface | vendor-named ports |
| adapter | Infra-layer implementation of a port. Imports the port; control lands here at runtime. | implementation, detail | — |
| composition root | Only place that knows both sides; constructs the adapter and injects it into the business rules. | — | — |
| actor | In SRP, a person or department who can request a change to a module. The unit SRP counts. | stakeholder, signer, party | "reason to change" read as a verb |
| reason to change | One actor. Not one verb, not one method, not a size threshold. | change axis | "does one thing" |
| invariant | A rule that defines what it means to be a valid instance; nobody signs off on it, breaking it is a bug. Lives on the type, enforced at construction. | validity rule | conflating with policy |
| policy | A rule a named stakeholder can change (overtime threshold, tax rate). Lives outside the data object, in that actor's module. | business rule, requirement | putting policy on the domain type |
| inert data object | Struct holding fields only, no behaviour; shared by two actors' modules so neither owns the other's code. | data object, record | adding formatting or rules to it |
