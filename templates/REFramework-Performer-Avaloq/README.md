# REFramework-Performer-Avaloq

The Performer half of a Dispatcher/Performer pair, pre-wired for the Avaloq Smart Client:
consume the shared queue, do the work in Avaloq, report the transaction status.

## What's in this folder

| File | |
|---|---|
| `project.json` | `Swisscom.UiPath.UIAutomation.Avaloq [2025.9.1]` + `Swisscom.PHI [24.10.0]`, runtime options, name placeholder. `targetFramework: Windows`, Studio 23.10.8.0 |
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

`Swisscom.UiPath.UIAutomation.Avaloq` must already be published to your package feed.
`project.json` sets `"mustRestoreAllDependencies": true`, so an unpublished package fails the
restore with an unresolved-dependency error rather than half-loading. Publish first —
[prerequisite](../README.md#before-you-start-the-library-feed).

## Deltas to apply to the generated skeleton

**Create `Avaloq_System/`.** Every workflow that touches a Smart Client window lives here and
nowhere else; `Logic/` decides, `Avaloq_System/` acts. See
[`systems/avaloq-system.md`](../../.claude/skills/standards/references/systems/avaloq-system.md).

**`Framework/InitAllApplications.xaml`** — start `smartclient.exe` and log in. Path and
launch arguments come from Orchestrator Text assets, so an environment or tenant move is a
config change rather than a redeploy:

```vb
in_Config("Avaloq_System_Client_Path").ToString
in_Config("Avaloq_System_Client_Arguments").ToString
```

Credentials come from `Get Credential` against the asset in the `Assets` sheet. The library
also ships its own UI-driven CyberArk flow (`CyberArk/OpenPHI`, `GetCyberArkAccount`,
`ClosePHI`); if you use it, **always call `ClosePHI`**, or you leave a browser session holding
a retrieved secret. TKB-UC11 uses the Orchestrator credential instead.
[`orchestrator-assets.md`](../../.claude/skills/security/references/orchestrator-assets.md).

**`Framework/GetTransactionData.xaml`** — stock. `Get Transaction Item` against
`in_Config("OrchestratorQueueName")` and `in_Config("OrchestratorQueueFolder")`. Do not change
the queue name here; change it in the `Settings` sheet so it stays diffable against the
Dispatcher's.

**`Process.xaml`** — read the fields the Dispatcher put in `ItemInformation`, call
`Avaloq_System/` and `Logic/` workflows. Use library activities, never raw Smart Client
selectors: the addressing arguments are `WindowCtrlName` / `SectionCtrlname` /
`GroupAaname` / `ContainerCtrlname` / `FieldCtrlname`, and the
`BreakIfConfirm` / `ConfirmMessage` / `ErrorMessage` contract is how the client tells you it
refused — check it, don't assume success. Full API:
[`avaloq-library`](../../.claude/skills/avaloq-library/SKILL.md).

If the process reads the embedded Smart Client Report web tables, that browser work goes in
`Web_Nav_System/` — the one place raw web selectors are allowed outside `Tests/`. See
[`web`](../../.claude/skills/web/SKILL.md).

**Exceptions** — `BusinessRuleException` when Avaloq refused (carry its `ErrorMessage` /
`ConfirmMessage` text into the message), `ApplicationException` for technical failure. The
distinction drives whether the queue item retries.

**`Framework/CloseAllApplications.xaml` / `KillAllProcesses.xaml`** — close the Smart Client
gracefully, then kill `smartclient.exe` as the fallback. A Performer that leaves a session
open poisons the next transaction.

## Config

Filled-in rows and what each is for: [`Data/config-contents.md`](Data/config-contents.md).

The `Assets` sheet ships a row per authenticated application and never ships empty. Note that
`Avaloq_System_Client_Path` and `Avaloq_System_Client_Arguments` deliberately map to
differently-named Orchestrator assets (`Avaloq_SmartClient_Path`,
`Avaloq_SmartClient_Arguments`) — that indirection is what lets one code base bind to
per-tenant asset names.

One trap: TKB-UC11 spells the credential key `Avaloq_System_Credendials` (sic) and its
workflows match the typo. This template spells it `Avaloq_System_Credentials`. If you lift a
workflow out of TKB-UC11, fix the key and the workflow together or not at all.

`OrchestratorQueueName` must be byte-identical to the Dispatcher's. That mismatch fails
silently — [why, and what to check](../README.md#the-queue-name-is-a-contract-between-the-pair).

### Exception-handling defaults

`Constants` ships `MaxConsecutiveSystemExceptions = 3` and `ShouldMarkJobAsFaulted = True`.
Keep them: `0` disables the consecutive-exception guard and lets a dead Smart Client session
be hammered for the length of the queue, and `False` makes a job that processed nothing look
green. `MaxRetryNumber = 0` is correct with Orchestrator queues — retry policy belongs on the
queue definition, not in `Config`.

## Tests

`Tests/Tests.xlsx` ships three rows, all marked `[UC-SPECIFIC — replace]`. The suite does not
pass as shipped and is not meant to. Replace all three and add `Tests/RunAllTests.xaml` before
UAT. Contents: [`Tests/tests-contents.md`](Tests/tests-contents.md).

Nothing in `Tests/` may be invoked from `Process.xaml`.

## Related skills

- [`avaloq-library`](../../.claude/skills/avaloq-library/SKILL.md) — activity API, addressing arguments, the confirm/error contract
- [`standards`](../../.claude/skills/standards/SKILL.md) — where each workflow goes, naming, error handling
- [`security`](../../.claude/skills/security/SKILL.md) — credentials, assets, the never-do list
- [`web`](../../.claude/skills/web/SKILL.md) — the embedded report browser
- [`pdd-sdd-scaffolding`](../../.claude/skills/pdd-sdd-scaffolding/SKILL.md) — scaffolding from an SDD when Avaloq isn't reachable
