# Ingesting a business test-data workbook

A business analyst hands over a test-data workbook. Nothing in this repo said what to do with
it, so it got treated as a source of truth about the process — which it is not. It is a set of
observations about one environment at one moment.

A real one had these sheets:

```
README | Config | WorkItems | TestCases | NegativeData | Accounts | …
```

The mapping below is the safe reading of each. The traps are the point: every one of them turns
a workbook that looks helpful into an automation that matches the fixtures rather than the
process.

## `Config` → `Settings` / `Constants` / `Assets`

A flat sheet, typically `Key | Value | Type | Notes | Status`. Split it across the three config
sheets by what the value *is*, not by where it sat:

| Value is | Goes to | Example shape |
|---|---|---|
| environment-specific, changes between TST and PRD | `Settings` | a URL, a path, a mailbox, a queue name |
| the same in every environment | `Constants` | retry counts, a pipe-separated enum, a timeout |
| a secret, or anything resolved from Orchestrator at startup | `Assets` | `<Application>_System_Credential` |

**Add every key to both `Config_TST.xlsx` and `Config_PRD.xlsx` in the same change**, or the PRD
run fails on a key only TST has.

### The `Status` column is load-bearing — read it before the `Value`

Rows are marked with their provenance (`Observed`, `OPEN`, `To verify`, `BLOCKED`, or similar).
That column is the difference between a fact and a placeholder:

- **`Observed`** — someone saw this in the environment. Usable.
- **`OPEN` / blank / `To verify` / `BLOCKED`** — **nobody has confirmed it.** The value in the
  cell is a guess, and copying it into `Config_TST.xlsx` silently converts an open question into
  an answer.

An unconfirmed row goes into config as `[UC-SPECIFIC — replace]` **and** into the SDD's Open
Questions section. It is never filled in from the workbook. This is the same tripwire principle
as `"name": "<PROJECT-NAME-TBD-ask-team>"` — an unanswered question must not be able to ship as
an answer, and `validate-project` fails on the marker so it cannot.

### A pipe-separated set is a `Constants` row, not a hard-coded list

`Lane_Names = To Do|Doing|Done`, with the analyst's own note: *"Lane sets are board-specific and
must never be hard-coded."* Believe the note. The same applies to tower lists, status
vocabularies and tab names.

### Config URLs are not selector values

A `URL_*` key belongs in `Settings` and is read at runtime. It must **not** also end up baked
into a captured selector — see the `web` skill, `references/capture-troubleshooting.md`.

## `WorkItems` → Dispatcher input, or the Performer's source

Either the Dispatcher enqueues them, or — with no queue — the Performer reads them through a
`WorkItem_Source` config key pointing at the workbook. Both are legitimate; the SDD decides.

### Three traps, all observed in one workbook

**1. Items that depend on each other.** A row that edits or moves a card created by an earlier
row only works if the rows run in order, and a queue makes no such promise. Worse, if items are
matched by a business key the application does not enforce as unique — a card *title*, where the
app permits duplicates — the second run operates on whichever one it finds first.

> **Do not guess the ordering.** State the dependency and the risk, and ask. If the answer is
> "they must run in order", that is a design constraint on the whole process, not a test-data
> detail.

**2. Fixed dates make expected results expire.** A `DueDate` of a literal date passes until that
date is in the past, then fails for a reason that has nothing to do with the code. Use
**relative dates** — today ± N — computed at run time.

**3. A column that is empty for some transaction types.** The brief case: `TargetLane` is
populated for Move rows and **empty on every Create row**, while `SourceLane` and a
`Lane_Default` config key carry the Create case. Inferring "the lane comes from `TargetLane`"
from a glance at the sheet produces an automation that passes inspection and fails every Create.

Which column each transaction type reads comes from the **SDD**. If the SDD is silent, record an
Assumption in the SDD and `Documentation/Progress.md`, and ask — see
`wiring-the-framework.md`.

## `TestCases` + `NegativeData` → `Tests/Tests.xlsx`

The template schema is two sheets (`Tests/tests-contents.md`):

| Sheet | Columns |
|---|---|
| `Tests` | `WorkflowFile`, `ExpectedResult` |
| `Result` | `WorkflowFile`, `ExpectedResult`, `Status`, `Comments` — written by the run |

So a business test case does not map one-to-one onto a row: each becomes a **test workflow**
under `Tests/`, and the workbook row points at it with its expected result.

- `TestCases` happy paths → `ExpectedResult = Success`
- **`NegativeData` rows → Business-exception tests**, not failures to tolerate. Each one asserts
  that the process *refuses correctly*: `ExpectedResult = BusinessException`, carrying the
  application's own message text.
- Technical-failure cases (application unreachable, file locked, Orchestrator down) →
  `SystemException`.

### Carry the status over, and never upgrade it without a run

A case marked `To verify` or `BLOCKED` in the source workbook stays that way. **Do not mark a
test passed without running it** — that is the one rule in the testing stage, and a status
inherited from a document is not a run. Nothing in `Tests/` may be invoked from `Process.xaml`.

## `Accounts` and any credential fixture → nowhere

A test-data workbook with an `Accounts` sheet, or a sibling `test_data.json` holding sign-in
details, is **not** a credential source.

- Credentials come from the Orchestrator asset named in the `Assets` sheet, fetched with
  `GetAppCredential` inside the scope that uses it.
- Never copy a password into `Config_*.xlsx`, a `.xaml`, a definition file, a prompt or a commit.
- The account *identifier* (which test user a case runs as) may travel as data; the **secret**
  may not.

Full rules: the `security` skill. Fixture files holding credentials are git-ignored by this
repo's `.gitignore` (`test_data*.json`, `.env`, `.env.*`) — that is a backstop, not permission to
create one.

## Checklist

- [ ] Every `Config` row classified into `Settings` / `Constants` / `Assets`, in **both** workbooks
- [ ] Every non-`Observed` row left as `[UC-SPECIFIC — replace]` and listed as an Open Question
- [ ] Work-item source decided per the SDD, and any inter-item ordering dependency raised, not guessed
- [ ] Which column each transaction type reads taken from the SDD, not inferred from the sheet
- [ ] Fixed dates replaced with relative ones
- [ ] `NegativeData` rows became Business-exception tests
- [ ] `To verify` / `BLOCKED` statuses carried over, nothing marked passed without a run
- [ ] No credential left anywhere outside an Orchestrator asset
