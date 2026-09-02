# REFramework-Dispatcher-Base

The Dispatcher half of a Dispatcher/Performer pair: read the upstream source, apply the
selection rule, add one queue item per unit of work. Nothing else.

It talks to neither Finnova nor Avaloq — enqueueing is queue-and-source work — so this one
skeleton fits every project in the estate. **Copy it and adapt.** The source-read step and the
filter rule change every time; the state machine, the config loading and the queue-add pattern
don't. Only create a second Dispatcher template if a project needs something this one
genuinely cannot express.

## What's in this folder

| File | |
|---|---|
| `project.json` | Dependencies, runtime options, name placeholder. `targetFramework: Windows`, Studio 23.10.8.0 |
| `project.uiproj` | Project name / type / main file — keep in step with `project.json` |
| `entry-points.json` | Declares `in_ENV`, `in_OrchestratorQueueName`, `in_OrchestratorQueueFolder` |
| `Data/Config_TST.xlsx`, `Data/Config_PRD.xlsx` | `Settings` / `Constants` / `Assets`, pre-populated |
| `Data/config-contents.md` | Generated, diffable rendering of both workbooks |
| `Data/Input/`, `Data/Output/`, `Data/Temp/` | Empty, `.gitkeep` only |
| `Tests/Tests.xlsx` | `Tests` / `Result` sheets, placeholder rows |
| `Tests/tests-contents.md` | Generated, diffable rendering |
| `Documentation/`, `Exceptions_Screenshots/` | Empty, `.gitkeep` only |

`Main.xaml` and `Framework/` are **not** here — generate them from Studio's *Robotic
Enterprise Process* template and apply the deltas below. See
[`../README.md`](../README.md#instantiating-a-template) for the full instantiation sequence.

## Deltas to apply to the generated skeleton

A Dispatcher keeps the REFramework state machine but inverts what the transaction *is*: it
reads a batch up front and each transaction is one row of that batch, written to the queue.

**`Framework/InitAllSettings.xaml`** — leave stock. It already reads all three sheets and
resolves the `Assets` rows against Orchestrator.

**`Framework/InitAllApplications.xaml`** — open only what the source needs. If the source is a
share the robot already has rights to, this stays empty; do not open a banking client here.

**`Framework/GetTransactionData.xaml`** — read the source once on the first pass and hold the
result, then hand out one row per transaction:

```vb
' TransactionNumber is the REFramework counter, 1-based.
If in_TransactionNumber <= io_SourceDT.Rows.Count Then
    out_TransactionItem = io_SourceDT.Rows(in_TransactionNumber - 1)
Else
    out_TransactionItem = Nothing          ' ends the End Process transition
End If
```

The source read itself belongs in a `*_System/` workflow (`Mail_System/`, `File_System/`, …),
not inline in the Framework file — `<Application>_System/` touches the source, `Logic/`
decides. See
[`where-does-it-go.md`](../../.claude/skills/standards/references/where-does-it-go.md).

**`Logic/`** — the selection rule lives here, as a workflow taking a row and returning a
boolean plus a reason. Keeping it out of `Process.xaml` is what makes the rule testable
without the source system.

**`Process.xaml`** — filter, then enqueue. One `Add Queue Item` per accepted row:

```
Invoke  Logic\Logic-<Subject>_Select.xaml     in_Row → out_Accepted, out_Reason
If Not out_Accepted → Log Info (skip reason), exit the transaction cleanly
Add Queue Item
    QueueName  = in_Config("OrchestratorQueueName").ToString
    FolderPath = in_Config("OrchestratorQueueFolder").ToString
    Reference  = <a value that is unique per unit of work>
    ItemInformation = the fields the Performer needs
```

Two things to get right here:

- **`Reference` is the deduplication handle.** Set it to the natural business key (order
  number, contract number). With *Enforce unique references* on the queue, a re-run then
  re-enqueues nothing instead of doubling the work.
- **A filtered-out row is not an exception.** Log it and end the transaction as successful —
  a `BusinessRuleException` per skipped row buries the real failures.

**`Framework/CloseAllApplications.xaml` / `KillAllProcesses.xaml`** — close whatever
`InitAllApplications` opened, or leave stock-empty if it opened nothing.

## Config

Filled-in rows and what each is for: [`Data/config-contents.md`](Data/config-contents.md).

The `Assets` sheet ships one credential row per authenticated application, marked
`[UC-SPECIFIC — replace]`. Wire each to a real Orchestrator asset —
[`orchestrator-assets.md`](../../.claude/skills/security/references/orchestrator-assets.md).
If the Dispatcher's source needs no login, **delete** the `Source_System_Credential` row
rather than leaving a placeholder that resolves to nothing at runtime.

`OrchestratorQueueName` must be byte-identical to the Performer's. That mismatch fails
silently — [why, and what to check](../README.md#the-queue-name-is-a-contract-between-the-pair).

### Exception-handling defaults

`Constants` ships `MaxConsecutiveSystemExceptions = 3` and `ShouldMarkJobAsFaulted = True`.
Keep them. `0` disables the consecutive-exception guard, and `False` lets a job that enqueued
nothing finish green in Orchestrator. `MaxRetryNumber = 0` is correct here — the Dispatcher
writes to the queue, it doesn't consume it, so retry policy belongs on the queue definition.

## Tests

`Tests/Tests.xlsx` ships three rows, all marked `[UC-SPECIFIC — replace]`. The suite does not
pass as shipped and is not meant to. Replace all three and add `Tests/RunAllTests.xaml` before
UAT. Contents: [`Tests/tests-contents.md`](Tests/tests-contents.md).

Nothing in `Tests/` may be invoked from `Process.xaml`.

## Related skills

- [`standards`](../../.claude/skills/standards/SKILL.md) — where each workflow goes, naming, error handling
- [`security`](../../.claude/skills/security/SKILL.md) — credentials, assets, the never-do list
- [`pdd-sdd-scaffolding`](../../.claude/skills/pdd-sdd-scaffolding/SKILL.md) — turning the SDD's source/filter description into the first draft
