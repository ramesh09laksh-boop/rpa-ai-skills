---
description: Stage 10 — make a change to a project that already works, or fix a robot that is failing. Optional argument, the change request or the symptom.
argument-hint: "[change request file, or what is going wrong]"
---

The change request, or what is going wrong, if anything was given: `$ARGUMENTS`. If it is empty,
ask what should change — or, if this is a failing robot, what it does and what you expected.

**Load the `uc-delivery` skill and run its stage 10.** Its gate is **re-run stages 6–8 for
whatever the change touches**. Load `standards` and the application skill(s) **the project
already uses** — read the project to find out which, rather than choosing fresh ones.

If the starting point is a failure rather than a change request, begin at `standards`,
`references/troubleshooting.md`: the symptom is usually not the problem.

- **Match the project's existing conventions.** Do not introduce a second credential mechanism,
  a second config format, or a new folder pattern without asking — a project with two of
  anything is harder to maintain than a project with the older one of them.
- Identify **every** workflow, config key and test the change touches, and say so before
  editing.
- If config changes, update `Config_TST.xlsx` **and** `Config_PRD.xlsx` together, in the same
  change, along with `Tests/Tests.xlsx`.
- **Do not migrate an existing Legacy or classic-activity workflow as a side effect.** Flag it;
  do not touch it — unless the change explicitly asks for that migration.
- Re-run the conformance checker and the test suite before calling the change done, and re-run
  stages 6–8 for what the change touched.

Update `Documentation/Progress.md` with what changed and the evidence it still works.
