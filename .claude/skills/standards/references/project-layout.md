# Project layout

Every folder in an REFramework project in this estate, and what belongs in it. Verified
against `UC39_BPO_manuelle_Börsenaufträge`, `PJFVA-966_UC81_BPO_VD03_TK _Valoren` and
`TKB-UC11.Kreditverletzung`.

## Root

| File | Purpose |
|---|---|
| `Main.xaml` | REFramework state machine. Entry-point arguments select the environment and target. |
| `Process.xaml` | The transaction body. **Location varies** — root in both Finnova projects, `Framework/Process.xaml` in the Avaloq project. Follow whichever the project already uses. |
| `project.json` | Dependencies (pinned, e.g. `"Swisscom.FinnovaLibrary": "[2026.1.0]"`), entry points, `runtimeOptions.excludedLoggedData`, `targetFramework`. |
| `project.uiproj` | `Name` / `ProjectType` / `Description` / `MainFile`. `Name` must match `project.json → name`. |
| `entry-points.json` | The process arguments Orchestrator offers, as JSON Schema. `uniqueId` pairs with `project.json → entryPoints[0]`. |
| `README.md`, `LICENSE` | Present in the Avaloq project only. |

### `targetFramework`

The three reference skeletons (`../REFramework-Dispatcher-Base/`,
`../REFramework-Performer-Avaloq/`, `../REFramework-Performer-Finnova/`) and everything in
`templates/` are `"targetFramework": "Windows"` with `"modernBehavior": true`, on
`"studioVersion": "23.10.8.0"`. The three sample processes predate that and are `"Legacy"`.

**Start new work on Windows; leave an existing Legacy project alone** unless migrating it is
the task. A published process carries its framework — flipping the value in `project.json`
without re-testing the workflows changes activity behaviour (notably modern vs classic UI
activities and `Delay`/`Timeout` defaults).

### `Main.xaml` entry-point arguments

| Argument | Projects | Values |
|---|---|---|
| `in_ENV` / `in_Env` | all three | `TST`, `PRD` — selects `Data\Config_<ENV>.xlsx` |
| `in_TOWER` | UC39 | `ENT`, `ESP`, `ZGKB`, `PBS`, `NOVUS` — which Finnova installation |
| `in_System` | UC81 | `FIN`, `AVQ` — which downstream system's settings to use |
| `in_OrchestratorQueueName` | UC81 | overrides the configured queue |

The config file is selected in `Main.xaml`:

```vb
' UC39
in_ConfigFile = "Data\Config_" + in_ENV + ".xlsx"
' TKB-UC11
in_ConfigFile = String.Format("Data\Config_{0}.xlsx", in_Env)
```

## `Framework/`

Standard REFramework files. Modify `InitAllApplications` / `CloseAllApplications` /
`KillAllProcesses`; leave the rest close to stock.

| File | What projects put here |
|---|---|
| `InitAllSettings.xaml` | Reads `Settings` + `Constants` sheets into `out_Config`, then overlays the `Assets` sheet from Orchestrator. **Do not modify** — see `.claude/skills/security/`. |
| `InitAllApplications.xaml` | Log in to every application the process needs. UC39 invokes `Finnova_System\Finnova-Login.xaml`; TKB-UC11 invokes `Avaloq_System\Avaloq_Login.xaml`. **Empty in UC81**, which logs in per transaction inside `Process.xaml` instead. |
| `GetTransactionData.xaml` | Pulls the next queue item / DataTable row. |
| `SetTransactionStatus.xaml` | Reports Success / Business / System back to Orchestrator. |
| `RetryCurrentTransaction.xaml` | Retry loop driven by `MaxRetryNumber`. |
| `CloseAllApplications.xaml` | Graceful shutdown. TKB-UC11: `Stop` Avaloq + `CardOne_Logout`. |
| `KillAllProcesses.xaml` | Forced shutdown. Often the same body as `CloseAllApplications`. |
| `TakeScreenshot.xaml` | Writes to `in_Config("ExScreenshotsFolderPath")`. |
| `Apps_All_Close.xaml` | UC81 only — extra close helper. |

## `<Application>_System/`

**UI interaction only.** One folder per external system. See
`references/systems/*.md` for each.

Contract for a workflow in this folder:

- **in**: `in_Config` (Dictionary&lt;String,Object&gt;), the window/session coordinates it needs
  (`in_WinTitel`, `in_Tower`), and business inputs
- **out**: plain values — `out_Status`, `out_ISIN`, `out_ValidKonto`, `out_ExtractDT`
- It opens what it needs and **closes what it opened** before returning
- It throws `BusinessRuleException` with the application's own message text when the
  application refuses

## `Logic/`

Business rules, parsing, mapping, comparison. **No UI interaction.**

Examples: `Logic-Risikodomizil_Identification.xaml`, `Logic-CP_UBS_Extract.xaml`,
`Logic-TEL_Process.xaml`, `Logic-KD_BackOffice_Msg_Adjust.xaml`,
`Logic-Get_Credential.xaml`.

UC39 has 22 `Logic/` workflows, 14 of them counterparty-specific PDF extractors
(`Logic-CP_<Bank>_Extract.xaml`) sharing one initialiser
(`Logic-CP_TradeConf_Extract_Init.xaml`, invoked 14 times). That per-variant-plus-shared-init
shape is the house pattern for "same job, many source formats".

## `Data/`

| Path | Contents |
|---|---|
| `Config_TST.xlsx`, `Config_PRD.xlsx` | Sheets `Settings`, `Constants`, `Assets`. See `.claude/skills/security/references/env-config.md`. |
| `Input/` | Static reference data checked into the repo — `Mappings.xlsx`, `BankLists.xlsx`, `CounterPartyList.xlsx`, mail templates (`Exception.txt`, `Info.txt`), Camunda request bodies (`Get*_JSON.txt`). |
| `Output/` | Runtime output. Ships with a `placeholder.txt` so the folder exists. |
| `Temp/` | Scratch. Same placeholder convention. |
| `Template/` | UC39 — mail body templates. |
| `AI/` | UC39 — prompt files (`SystemPrompt_Commission.txt`, `UserPrompt_Commission.txt`, `FewShot_Examples.txt`). |

> `Data/Output/` in the reference projects contains committed run artefacts
> (`output_28thOct.txt`, `Strukis.txt`, `TestLog.txt`). Do not copy that habit — outputs of
> a production run should not be committed.

## `Tests/`

`RunAllTests.xaml`, `RunAllTests_Logging.xaml`, `TestWorkflowTemplate.xaml`, `Tests.xlsx`,
plus ad-hoc `_Test*.xaml` scratch workflows.

The `_`-prefixed files are developer scratchpads, not a suite — they are where raw
selectors and hardcoded values legitimately live. **Nothing in `Tests/` should be invoked
from `Process.xaml`.** (UC39 invokes `Tests\RunAllTests_Logging.xaml` from production code
in three places — that is a defect, not a pattern to copy.)

## `Documentation/`

`REFramework Documentation-EN.pdf` in all three projects.

## `Exceptions_Screenshots/`

Target of `Framework/TakeScreenshot.xaml`. Ships with `placeholder.txt`.
`ExScreenshotsFolderPath` may redirect it to a network share (TKB-UC11 does). Screenshots
of a logged-in banking session contain customer data — see
`.claude/skills/security/references/prohibited-practices.md`.
