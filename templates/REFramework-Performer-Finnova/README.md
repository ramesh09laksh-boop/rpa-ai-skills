# REFramework-Performer-Finnova

The Performer half of a Dispatcher/Performer pair, pre-wired for the Finnova core-banking Java
thin client: consume the shared queue, do the work in Finnova, report the transaction status.

## What's in this folder

| File | |
|---|---|
| `project.json` | `Swisscom.FinnovaLibrary [2026.1.0]` + `Swisscom.PHI [24.10.0]`, runtime options, name placeholder. `targetFramework: Windows`, Studio 23.10.8.0 |
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

## Before you open it: the library feed

`Swisscom.FinnovaLibrary` and `Swisscom.PHI` must already be published to your package feed.
`project.json` sets `"mustRestoreAllDependencies": true`, so an unpublished package fails the
restore with an unresolved-dependency error rather than half-loading. Publish first —
[prerequisite](../README.md#before-you-start-the-library-feed).

## Deltas to apply to the generated skeleton

**Create `Finnova_System/`.** Every workflow that touches a Finnova window lives here and
nowhere else; `Logic/` decides, `Finnova_System/` acts. Workflow naming is
`Finnova-<Subject>_<Verb>.xaml` — verb last. See
[`systems/finnova-system.md`](../../.claude/skills/standards/references/systems/finnova-system.md).

**`Framework/InitAllApplications.xaml`** — launch the client and log in. Build the launch
command and window title by concatenating the tower code:

```vb
in_Config("Finnova_System_Launch_Cmd_" + in_TOWER).ToString
in_Config("Finnova_System_Win_Title_"  + in_TOWER).ToString
```

Credentials come from `Get Credential` against the asset in the `Assets` sheet, or from
`Get PHI Vault`. The two are interchangeable by asset name — the estate names the Orchestrator
credential after the CyberArk object it mirrors, which makes switching a config change.
Keep the password a `SecureString` end to end;
[`orchestrator-assets.md`](../../.claude/skills/security/references/orchestrator-assets.md).

**`Framework/GetTransactionData.xaml`** — stock. `Get Transaction Item` against
`in_Config("OrchestratorQueueName")` and `in_Config("OrchestratorQueueFolder")`. Do not change
the queue name here; change it in the `Settings` sheet so it stays diffable against the
Dispatcher's.

**`Process.xaml`** — read the fields the Dispatcher put in `ItemInformation`, call
`Finnova_System/` and `Logic/` workflows. Use library activities, never raw Finnova selectors:
the addressing arguments are `WindowTitle` / `PageTabName` / `PanelName` / `Idx` /
`Virtualname`, and every activity returns `ErrorMsg` / `Warning` / `Info` out-arguments that
you check rather than assume. Use the library's `Sync`, never a fixed `Delay`. Full API:
[`finnova-library`](../../.claude/skills/finnova-library/SKILL.md).

**Exceptions** — `BusinessRuleException` when Finnova refused the transaction (carry its own
`ErrorMsg` text into the message), `ApplicationException` for technical failure. The
distinction drives whether the queue item retries.

**`Framework/CloseAllApplications.xaml` / `KillAllProcesses.xaml`** — close the client
gracefully, then kill `java*.exe` as the fallback. A Performer that leaves a client session
open poisons the next transaction.

## Config

Filled-in rows and what each is for: [`Data/config-contents.md`](Data/config-contents.md).

The `Assets` sheet ships a row per authenticated application, all marked
`[UC-SPECIFIC — replace]`, and never ships empty. The `<TOWER>` rows are a **naming pattern,
not a literal key**: the workflows build the key by concatenating the tower code, so each
tower the process serves (`ENT`, `ESP`, `ZGKB`, `PBS`, `NOVUS`) needs its own row. A missing
tower row surfaces as a runtime `KeyNotFoundException` mid-transaction, not as a startup
failure.

`OrchestratorQueueName` must be byte-identical to the Dispatcher's. That mismatch fails
silently — [why, and what to check](../README.md#the-queue-name-is-a-contract-between-the-pair).

### Exception-handling defaults

`Constants` ships `MaxConsecutiveSystemExceptions = 3` and `ShouldMarkJobAsFaulted = True`.
Keep them: `0` disables the consecutive-exception guard and lets a dead Finnova session be
hammered for the length of the queue, and `False` makes a job that processed nothing look
green. `MaxRetryNumber = 0` is correct with Orchestrator queues — retry policy belongs on the
queue definition, not in `Config`.

## Tests

`Tests/Tests.xlsx` ships three rows, all marked `[UC-SPECIFIC — replace]`. The suite does not
pass as shipped and is not meant to. Replace all three and add `Tests/RunAllTests.xaml` before
UAT. Contents: [`Tests/tests-contents.md`](Tests/tests-contents.md).

Nothing in `Tests/` may be invoked from `Process.xaml`.

## Related skills

- [`finnova-library`](../../.claude/skills/finnova-library/SKILL.md) — activity API, addressing arguments, `Sync`
- [`standards`](../../.claude/skills/standards/SKILL.md) — where each workflow goes, naming, error handling
- [`security`](../../.claude/skills/security/SKILL.md) — credentials, assets, the never-do list
- [`pdd-sdd-scaffolding`](../../.claude/skills/pdd-sdd-scaffolding/SKILL.md) — scaffolding from an SDD when Finnova isn't reachable
