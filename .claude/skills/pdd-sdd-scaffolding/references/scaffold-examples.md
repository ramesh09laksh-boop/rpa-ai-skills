# Worked examples — screenshot to scaffold

Three cases, in the order you hit them: instruction text present, arrow only, and no app
access. Notation matches `.claude/skills/finnova-library/references/usage-example.md` —
activity name on the left, arguments indented.

Markers used throughout:

| Marker | Meaning |
|---|---|
| `APPROX_SELECTOR (verify against live app)` | value inferred from something printed in the document |
| `TODO_SELECTOR` | no evidence exists; nothing guessed |

---

## 1. Screenshot with instruction text — the easy case

**SDD §3.1**, screenshot of the Finnova Valorenstamm search screen, caption beneath it:

> *"Im Feld Valor die Valorennummer aus der Mail eingeben und «Suchen» klicken."*

Text wins: no visual inference needed. The screen is in the UC81 inventory
(`.claude/skills/standards/references/systems/finnova-system.md`) as
`Finnova-Valoren_Search.xaml` — **so the scaffold is a call to the existing workflow, not new
UI code**:

```
Invoke Workflow File   Finnova_System\Finnova-Valoren_Search.xaml
                       in_WinTitel = WinTitel
                       in_Valor    = in_TransactionItem.SpecificContent("Valor").ToString
                       out_Status  = Status
                       out_Visum   = Visum
```

Nothing is approximated and no `.selectors-todo.md` row is produced. **Always check the
inventory before scaffolding activities** — most PDD screenshots describe a screen the estate
already wraps.

---

## 2. Arrow only, no instruction text

**SDD §4.1**, same screen further down. A red arrow points at a checkbox labelled
*Bestandeskorrektur*. No caption, no numbered step, no surrounding sentence.

Inference chain:

1. No adjoining text → fall back to the image.
2. The marker is on a **checkbox** → the action is Check/Uncheck. The arrow does not say
   which; the section heading is *"Zusatz erfassen"*, which implies setting it.
3. No project workflow wraps this control (`Finnova-Zusatz_Bestandeskorr_Verify` *verifies*,
   it does not set) → drop to the library: `Check Box`.
4. The checkbox's `Virtualname` is not visible in the screenshot and appears nowhere in the
   SDD text → **no evidence** → bare `TODO_SELECTOR`.

```
Check Box   WindowTitle = WinTitel
            PanelName   = TODO_SELECTOR
            Virtualname = TODO_SELECTOR
            Check       = True
            ErrorMsg    = ErrMsg

  Annotation:
  TODO_SELECTOR: label "Bestandeskorrektur" is legible in SDD §4.1 fig. 4 but no
    Virtualname/PanelName evidence exists — capture in UI Explorer against the live app.
    Check=True inferred from the section heading "Zusatz erfassen"; confirm the intended
    state.
```

A label read off a screenshot is **not** a `Virtualname`. Finnova's logical ids are not the
German display labels, and guessing one produces a selector that silently matches nothing.

### The ambiguous variant

If the same arrow had landed between the checkbox and the *Speichern* button, the scaffold
gets one step with a `TODO_SELECTOR` **and** a question in the checklist — not a coin flip:

```
- fig. 4 — the arrow sits between the *Bestandeskorrektur* checkbox and the *Speichern*
  button; scaffolded as Check Box on *Bestandeskorrektur*. Confirm which was meant.
```

---

## 3. No app access — full scaffold, approximated selectors

**SDD §4.2 fig. 7.** A report grid with this header row, and an arrow on the `FileId` cell
of the fourth visible row:

```
Security | RecordDate | DeadLine | DateMeeting | Custodian | Status | NbOfHoldings | NbOfMsg | FileId
```

Finnova and Avaloq are both unreachable — no test tower, no credentials. Scaffold anyway.

### What is fully derivable

The whole sequence, from the system reference's "Reports are the main data source" pattern:

```
Select Menu                    ' navigate to the report
Set Text                       ' search keyword, from an Orchestrator asset
Click                          ' execute
Sync
Table Extract by Scrollbar     ' grid → DataTable
Table Get Column NameList      ' verify grid shape before trusting column names
Table Search By Index          ' locate the row by business key
Table Get Cell Text By Name    ' read FileId
Close Tab
```

Argument values that need no live session:

```
Set Text    Text = in_Config("Report_Search_Keyword").ToString
```

### What gets approximated, and on what basis

The header row is printed in the figure, so column names **and their order** are evidence.
`FileId` is the ninth column → index 8, 0-based. The arrow is on the fourth visible row, and
the header sits above it → `RowIndex = 3`, assuming no scroll offset, which the figure cannot
show.

```
Table Get Column NameList
            WindowCtrlName  = in_Config("Avaloq_System_Win_CtrlName").ToString
            SectionCtrlname = TODO_SELECTOR
            TableName       = TODO_SELECTOR
            ColumnNameList  = ColumnNames

If Not ColumnNames.Contains("FileId")
    → Throw New ApplicationException("Grid shape changed: FileId column not found")

Table Search By Index
            ExtractDataTable = dt
            SearchValues     = in_SecurityId          ' business key from the SDD
            ColumnIndexes    = "0"                    ' Security is the first column, fig. 7
            RowIndex         = RowIdx
            Found            = Found

If Not Found → Throw New BusinessRuleException(
                 String.Format("No grid row for Security={0}", in_SecurityId))

Table Get Cell Text By Name
            RowIndex   = RowIdx                       ' from the search, not hardcoded
            ColumnName = "FileId"
            Value      = out_FileId

  Annotation:
  APPROX_SELECTOR (verify against live app): ColumnName="FileId", column index 8,
    ColumnIndexes="0" for Security — inferred from the grid header order in SDD §4.2 fig. 7.
    Column spelling and order not confirmed against the running app.
```

Note what changed once the business key was available: the arrow pointed at row 4, so
`RowIndex = 3` was the honest approximation — but the SDD also names a `Security` value per
transaction, so `Table Search By Index` finds the row by that value and the index disappears
from the scaffold entirely. **Approximate an index only when no business key exists.** Keep
the approximation in the checklist anyway, as the fallback the developer may need if the
lookup turns out not to work.

### `Table Extract` vs `Table Extract by Scrollbar`

The figure shows nine columns and a partial row set, which means the grid virtualises. Use
`Table Extract by Scrollbar` and check `RowCount` — `Table Extract` returns only materialised
rows and would silently miss the target row. This is a shape decision from the screenshot,
not a selector, so it needs no marker.

---

## The resulting checklist

`Avaloq_System/Avaloq_CorpAction_FileId_Get.selectors-todo.md`:

```markdown
# Avaloq_CorpAction_FileId_Get.selectors-todo.md

Generated from SDD v1.3 §4.2 on 2026-09-01, with Avaloq unavailable. Every row must be
confirmed against the live application before UAT.

| # | Activity | Argument | Value | Basis | Status |
|---|---|---|---|---|---|
| 1 | `Table Get Column NameList` | `SectionCtrlname` | — | no evidence | TODO |
| 2 | `Table Get Column NameList` | `TableName` | — | no evidence | TODO |
| 3 | `Table Search By Index` | `ColumnIndexes` | `"0"` | Security is col 1 in fig. 7 header | APPROX |
| 4 | `Table Get Cell Text By Name` | `ColumnName` | `"FileId"` | fig. 7 header, col 9 (idx 8) | APPROX |
| 5 | `Table Get Cell Text By Name` | `RowIndex` | from `Table Search By Index` | — | resolved by lookup |
| 6 | `Table Extract by Scrollbar` | `MaximumNumberOfScrolls` | `10` | default; grid depth unknown | APPROX |

**Fallback if the value lookup fails**

Row 5 was originally approximated as `RowIndex=3` (arrow on row 4 of fig. 7, header at row 0,
no scroll offset assumed). Replaced by `Table Search By Index` on the Security key. Reinstate
only if the library lookup proves unusable, and flag it as a gap first.

**Ambiguous screenshots**

- none in this section.

**Library gaps found**

- none.
```

Rows 1 and 2 are the honest content of this file: the two `ctrlname` values genuinely cannot
be derived from a screenshot, and no amount of inference changes that. Everything else in the
workflow — nine activities, the exception handling, the config keys — was scaffolded without
touching the application.
