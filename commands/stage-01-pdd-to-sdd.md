---
description: Stage 1 — turn the process document (PDD) into a solution design (SDD). Optional argument, the PDD file or the UC number.
argument-hint: "[PDD file or UC number]"
---

The PDD or UC number, if one was given: `$ARGUMENTS`. If it is empty, ask which document to
read before doing anything else.

**Load the `uc-delivery` skill and run its stage 1.** It owns the gate, the working rules, the
safety rails and the order of everything. Load `standards` for the project and application
conventions and the SDD's required sections (`references/sdd-outline.md`), and `security` for
the credential and config vocabulary.

Produce a complete SDD to the section list in the `standards` skill,
`references/sdd-outline.md`. Then:

- **Ask two decisions up front**, one message each, and record both answers in the SDD's
  Decisions table with who confirmed them: (1) the **config file format**, (2) the **credential
  mechanism**. Options, consequences and the recommended default for each: the `standards`
  skill, `references/decisions.md`. A recommended default is not an answer — until a person
  confirms it, it stays an Open Question.
- **Define every transaction type and the work-item columns each one uses.** Do not leave them
  to be discovered later from the test data; that is the gate on this stage.
- **Record the shape of the run**: whether there is an Orchestrator queue, and whether this is
  Dispatcher + Performer, Performer-only, or a single self-contained run.
- **Add an Open Questions / Assumptions section** for everything the PDD does not state.

Never invent a business rule, a credential name, a selector or a config value. If the PDD is
silent, it is an Open Question — not a guess, and not a plausible default written as fact.

Update `Documentation/Progress.md` when the stage closes, with the evidence for its gate.
