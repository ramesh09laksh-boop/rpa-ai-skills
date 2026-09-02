---
name: pdd-sdd-scaffolding
description: Use when translating a PDD/SDD into workflows and the document contains screenshots — whether annotated with explicit instruction text or only a visual marker (arrow, highlight) pointing at the control to act on. Also use when scaffolding against Finnova, Avaloq, SIX iD, CardOne or any target application that is not reachable right now (offline, no test tower, no credentials), so selector-level detail cannot be confirmed live. Produces a first-draft workflow scaffold plus a <WorkflowName>.selectors-todo.md checklist of every value that still needs confirming.
---

# PDD/SDD → activity scaffold

Turns a PDD/SDD — including its screenshots — into a REFramework workflow scaffold that a
developer reviews against the live application.

**Everything this skill produces is a first draft.** It calls real library activities in the
right order with the arguments the document actually supports, and it marks every value it
could not confirm. It never invents an activity name and never invents a selector.

Load `.claude/skills/standards/` first to decide which folder each step belongs in,
then the matching system reference and library skill.

## What you can produce without the application

| Derivable from the PDD/SDD alone | Needs the running app |
|---|---|
| Workflow structure and sequence — login → navigate → action → validate → close | Nothing about the *shape* of the flow |
| Which named library activity each step calls | — |
| `in_`/`out_` argument lists | — |
| Config keys and Orchestrator asset names | — |
| Business values named in the document (Valor, ISIN, FileId, BP, amounts) | — |
| `WindowTitle` / `WindowCtrlName` (from config, per tower) | — |
| Column *names* printed in a screenshot grid header | That the column is still there and still spelled that way |
| Column *order*, so a plausible column index | The real index at runtime after user sort/filter |
| Row position relative to a header or anchor row | The real `idx` / `RowIdx` |
| — | `Virtualname`, `FieldCtrlname`, `PanelName`, `SectionCtrlname` |

Scaffold everything in the left column fully. Do not stop at the first unknown selector and
hand back a stub — the sequence is the valuable part and it is fully derivable.

## Reading a screenshot

1. **Read the adjoining instruction text first.** Caption, numbered step, table cell, the
   sentence above or below the image. Only fall back to visual inference when there is none.
2. **Where only an arrow, highlight or circle is present**, identify the specific control it
   points at — a link label, a field, a checkbox, a grid cell, a toolbar button — and infer
   the action from what that control affords:

   | Control the marker points at | Action |
   |---|---|
   | Hyperlink, button, toolbar icon, menu entry | Click |
   | Empty input field | Set Text |
   | Checkbox | Check / Uncheck |
   | Radio button | select the option |
   | Combo box / dropdown | Select Item |
   | Grid row or cell | Click Cell / Double Click Cell (drill in) |
   | Populated read-only field or a whole grid | Get Text / Extract — a *read*, not a write |

   A marker on a populated read-only field almost always means "this is the value to read",
   not "type here". Check the surrounding text for a business term (`Valor`, `FileId`,
   `Auftragsnummer`) before deciding.
3. **Cross-reference the screen against the system reference** —
   `.claude/skills/standards/references/systems/finnova-system.md`,
   `.../avaloq-system.md`, `.../six-id-system.md`, `.../cardone-system.md`, etc. If a
   **project workflow** already wraps that screen (the inventory tables list every one), call
   it by name instead of scaffolding new UI code. If not, drop to the library skill
   (`.claude/skills/finnova-library/`, `.claude/skills/avaloq-library/`) and pick the library
   activity by name.
4. **Never a raw selector or a generic `Click` / `Type Into`** for Finnova or Avaloq. If no
   library activity fits, that is a finding to report, not a licence to write a selector.
   UC39 has zero raw Finnova selectors outside `Tests/`.
5. **Flag ambiguity instead of guessing.** Unclear arrow position, two candidate controls
   under one highlight, a screenshot with no legible labels — emit the step with a
   `TODO_SELECTOR` and a one-line question for the developer. Never silently pick one of two
   candidates.

## Approximate, don't blank — and never fabricate

For selector-level detail only the running app can confirm (`idx`, `RowIdx`, `TableIdx`, row
and column position, coordinates), give a **best-effort value derived from evidence in the
document**, marked as unverified:

- A grid header visible in a screenshot gives column names *and* their order, so a column
  index. Example: a header reading `Security | RecordDate | DeadLine | DateMeeting |
  Custodian | Status | NbOfHoldings | NbOfMsg | FileId` puts `FileId` at index 8 (0-based).
- A visible row's position relative to the header or a known anchor row gives a starting
  `RowIndex` / `idx`.
- Field labels and business keys in the surrounding text fill in argument *values* without a
  live session.

Mark every such value in the activity's **annotation** (greppable in the `.xaml` as
`sap2010:Annotation.AnnotationText`) and prefix the DisplayName so it is visible in the
Studio canvas:

```
APPROX_SELECTOR (verify against live app): ColumnName="FileId", column index 8, RowIndex=3
  — column index inferred from the grid header order in SDD §4.2 fig. 7; row position not
  confirmed — Table Get Cell Text By Name
```

If a control has **no supporting evidence at all** — no screenshot, no label, no prior
pattern in the reference projects — it gets a bare marker with no guess attached:

```
TODO_SELECTOR: no evidence in the SDD for the Fälligkeit field's Virtualname — capture it
  in UI Explorer against the live app — Set Text
```

The line between the two is evidence, not confidence. An informed estimate from something
actually printed in the document is an `APPROX_SELECTOR`. A plausible-looking name you
reasoned your way to is not evidence — that is a `TODO_SELECTOR`. Do not invent a screenshot
detail, a column, or a `Virtualname` that the document does not contain.

## Prefer a business key over a raw index

A hardcoded index breaks the first time a user sorts or filters the grid; a value lookup
survives it. Where the library offers a lookup by a business key that is visible in the
SDD or screenshot (Valor, ISIN, FileId, Auftragsnummer, BP), scaffold that instead:

| Instead of | Use | Library |
|---|---|---|
| `Table/Click Cell` with `ClickRow` | `Table/Click Cell By Value` (`CellValue`) | Finnova |
| `Table/Get Cell` with `GetRow`/`GetColumn` | `Table/Get Cell` with `RowName`/`ColumnName` | Finnova |
| row number in an extracted DataTable | `Table/Search Item` (`SearchItem`, `SearchInColumn` — **0-based**) → `FoundInRow` | Finnova |
| `Table Click Cell` with `RowIndex` | `Table Click Cell` with `RowName` + `ColumnName` | Avaloq |
| `Table Get Cell Text By Index` | `Table Get Cell Text By Name` (`RowName`, `ColumnName`) | Avaloq |
| a positional row in an extracted grid | `Table Search By Index` (`SearchValues`, `ColumnIndexes`) → `RowIndex`, `Found` | Avaloq |
| `Web Table Click Cell` with `RowIndex` | `Web Table Get Row By Col Innertext` → `RowIndex`, then click | Avaloq |

Verify the grid's shape before trusting a column name: `Table Get Column NameList` (Avaloq)
or a `Table/Extract` column check (Finnova). Both are cheap and both turn a silent wrong-column
read into a clear failure.

If the library only exposes index-based access for the operation you need, **record it as a
gap** — add a line to the relevant `references/activities.md` "Gotchas" section rather than
quietly working around it with a raw selector.

## Emit a `.selectors-todo.md` per workflow

Markers scattered through `.xaml` files are unreviewable. Alongside each generated workflow
write `<WorkflowName>.selectors-todo.md` next to it, listing every marker:

```markdown
# Finnova-Valoren_Search.selectors-todo.md

Generated from SDD v1.3 §4.2 on 2026-09-01. Every row must be confirmed against the live
application before UAT.

| # | Activity | Argument | Value | Basis | Status |
|---|---|---|---|---|---|
| 1 | `Table Get Cell Text By Name` | `ColumnName` | `"FileId"` | grid header, fig. 7 | APPROX |
| 2 | `Table Get Cell Text By Name` | `RowIndex` | `3` | row 4 in fig. 7, header at row 0 | APPROX |
| 3 | `Set Text` | `Virtualname` | — | no evidence | TODO |

**Ambiguous screenshots**

- fig. 11 — the arrow sits between the *Suchen* button and the *Valor* field; scaffolded as
  a Click on *Suchen*. Confirm which was meant.
```

One row per marker: activity, argument, the approximated value, what it was based on, and
`APPROX` or `TODO`. Ambiguous screenshots get their own list with the open question spelled
out. This is the file a developer or QA works through — keep it in sync when a marker is
resolved in the `.xaml`.

## Scaffold shape

Follow the estate's structure, not a flat script:

- `<Application>_System/` for anything that touches the UI; `Logic/` for the decisions. The
  scaffold must not put an `If` about business meaning inside a `_System` workflow.
- Thread `in_WinTitel` (Finnova) / the credential and path config keys (Avaloq) through —
  never hardcode a window title.
- A workflow that opens a window or tab closes it before returning (`Close Window`,
  `Close Tab`).
- Business refusals become `BusinessRuleException` carrying the application's own message
  text from `ErrorMsg` / `ConfirmMessage`; technical failures become `ApplicationException`.
  See `.claude/skills/standards/references/error-handling.md`.
- Credentials and asset names come from `.claude/skills/security/` — never from the SDD text
  itself, even if it prints one.

## References

- `references/scaffold-examples.md` — worked examples: annotated screenshot → scaffold step,
  for both an annotated-arrow case and an app-unavailable case, with the resulting
  `.selectors-todo.md`.
