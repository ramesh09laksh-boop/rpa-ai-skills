# `Documentation/Leaf_Ledger.md` — the per-workflow completion record

One row per leaf workflow. A row is complete when **every** column is `yes`; the stage gate is
the whole ledger, not the count of files that exist.

This file exists because "the workflows are written" is not a checkable claim. A leaf workflow
can exist, compile, validate, pack, and still be a stub bound to nothing — and every one of
those failures is silent. The ledger turns each of them into a column someone has to answer.

Copy the template below into `Documentation/Leaf_Ledger.md` when the first leaf workflow is
authored, and fill a row as each workflow finishes. **Do not pre-fill rows with `yes`.**

## The columns, and what each one is actually asking

| Column | `yes` means | The failure it catches |
|---|---|---|
| **body real** | The body performs the step. No workflow whose body is only a `LogMessage` or an annotation. | A Framework wired to stubs runs green and does nothing. `validate-project`'s `leaf-body-stub` rule finds these. |
| **contract met** | `in_Config` in, a business-key argument in, an `out_` outcome back, `SecureString` for any secret. | A no-op is indistinguishable from success to the caller. The four leaf-contract rules in `validate-project` cover this. |
| **captured as `<role>`** | The role the selectors were captured under, written out — not a tick. It must be the least-privilege role the robot runs as. | A selector captured as an administrator carries admin-only ancestors and cannot resolve from the robot's session. It fails at runtime, not at capture. |
| **matched only the target** | Each target passed the capture flow's registration gate: it matched the intended element **and nothing else** (or a deliberate, documented set). | A selector that passes because the matching was loosened until it did. |
| **parametrized by business key** | Any per-item target is pinned by its business key — a reference, a title, a label — through a workflow variable, never by index or a captured literal. | A descriptor captured against one row works in the environment it was captured in and nowhere else. |
| **run once** | This workflow has been executed once against the live application, and the run is named in the row. | Authored-but-never-run is the default state of a plausible-looking workflow. |
| **CONFIRMED** | All six above are `yes` and someone is prepared to say so. | A half-finished row passing for a finished one. |

Anything that is not `yes` gets a short reason in the row, not a blank. A blank is
indistinguishable from "nobody looked".

## Template

```markdown
# Leaf workflow ledger — <PROJECT-NAME>

Robot runs as: `<least-privilege role>`   ·   Application: `<app / URL>`   ·   Env: `TST`

A row is done only when every column is `yes`. `no` needs a reason in the same row.

| Workflow | body real | contract met | captured as `<role>` | matched only the target | parametrized by business key | run once | CONFIRMED |
|---|---|---|---|---|---|---|---|
| `<App>_System/<App>-Login.xaml`       | no | no | no | no | n/a | no | no |
| `<App>_System/<App>-<Verb>.xaml`      | no | no | no | no | no  | no | no |
| `Logic/Logic-<Name>.xaml`             | no | no | n/a | n/a | n/a | no | no |

## Reasons for every `no`

- `<App>-Login.xaml` — captured as Owner on 2026-11-03; re-capture needed at Member. See
  `<App>-Login.selectors-todo.md`.

## Runs

| Workflow | Command | Result | When |
|---|---|---|---|
| `<App>_System/<App>-<Verb>.xaml` | `<the command, verbatim>` | `<what it did>` | `<date>` |
```

Notes on filling it:

- **The `Workflow` column is the conformant path and name**, written as
  `<App>_System/<App>-<Subject>_<Verb>.xaml` with the prefix derived from the folder. Writing the
  row is the last comfortable moment to fix a name: by then the workflow is wired, and every
  rename from here costs an edit to each `Invoke Workflow File` that points at it. If the file on
  disk does not match what you are about to write in the row, rename the file — do not write the
  name the file happens to have. `naming-conventions.md`, and `leaf-name-prefix` in
  `validate-project`.
- **`n/a` is a legitimate value, a blank is not.** A `Logic/` workflow captures nothing, so its
  capture columns are `n/a`. A login screen has no per-item target, so its
  parametrized-by-business-key column is `n/a`. Write the `n/a`.
- **`captured as` holds a role name, not a tick.** `yes` in that column is a filling error.
- **The `Runs` table carries the command verbatim.** "Run once" without the command is not
  evidence — see the `project-scaffolding` skill, `references/evidence-ladder.md`, and never
  write PASS without the command that produced it.
- **The ledger does not replace the `.selectors-todo.md` files.** Those hold the per-target
  detail; the ledger holds one line per workflow and points at them.

## How the ledger is used as a gate

The capture-and-develop stage is done when:

1. Every row is `yes` in every column, **and**
2. Each workflow has been **run once** against the live application, with the command recorded.

If neither holds, the stage is not done — and the report says which rows are open and why. A row
that needs a person (an account at the right role, a credential in an Orchestrator asset, a
screen that cannot be reached) is named as a blocker with exactly what is needed, not carried as
a soft caveat.

Related: `references/project-layout.md` for the `_System` contract the *contract met* column
checks, `references/wiring-the-framework.md` for why a stub-wired Framework is a skeleton rather
than a process, and the `web` skill for the capture flow and the role precheck.
