---
name: standards
description: Use when creating, extending or navigating a UiPath REFramework automation project in this estate — deciding which folder a new workflow belongs in, naming a project, workflow or its in_/out_/io_ arguments, editing project.json / project.uiproj / entry-points.json, choosing targetFramework, wiring Framework/InitAllSettings, InitAllApplications, Process and SetTransactionStatus, or working inside an application folder such as Finnova_System, Avaloq_System, Mail_System, File_System, SIX_ID_System, CardOne_System, Web_Nav_System, Camunda_System, UBS KeyTrader or AI. Trigger when translating an SDD into workflows, scaffolding a new process from templates/, splitting work into a Dispatcher and a Performer, naming an Orchestrator queue, or asking "where does this step go?".
---

# UiPath project standards

Every project in this estate is UiPath **REFramework** with the same skeleton. An SDD step
maps onto exactly one folder; getting that mapping right is most of what makes these
projects maintainable.

Sample processes — the evidence behind everything here. They sit one level above the skills
repo:

| Project | Systems it talks to |
|---|---|
| `../Finnova/UC39_BPO_manuelle_Börsenaufträge` | Finnova, Mail, File, AI |
| `../Finnova/PJFVA-966_UC81_BPO_VD03_TK _Valoren` | Finnova, SIX iD, UBS KeyTrader, Camunda, Mail, File |
| `../Avaloq/TKB-UC11.Kreditverletzung` | Avaloq, CardOne, Web Nav, Mail, File |

Alongside them, `../REFramework-Dispatcher-Base/`, `../REFramework-Performer-Avaloq/` and
`../REFramework-Performer-Finnova/` are clean Studio 23.10 Windows REFramework skeletons. Use
them for what stock REFramework plumbing looks like and for project metadata; use the three
sample processes above for how this estate actually structures work.

## The skeleton

```
<Project>/
  Main.xaml                  REFramework state machine. Takes in_ENV (+ in_TOWER / in_System).
  Process.xaml               One transaction. (Or Framework/Process.xaml — both occur.)
  project.json               Dependencies, entry points, excludedLoggedData. targetFramework: Windows.
  project.uiproj             Project name / type / main file. Same name as project.json.
  entry-points.json          Declared process arguments, as JSON Schema.
  Framework/                 REFramework plumbing — Init, GetTransactionData, SetTransactionStatus…
  <Application>_System/      One folder per external system. UI interaction ONLY.
  Logic/                     Business rules and decisions. No UI interaction.
  Data/                      Config_TST.xlsx, Config_PRD.xlsx, Input/, Output/, Temp/
  Tests/                     Test workflows, Tests.xlsx, RunAllTests.xaml
  Documentation/
  Exceptions_Screenshots/
```

New projects are **Windows** (`"targetFramework": "Windows"`, `"modernBehavior": true`), not
Legacy. The older sample processes above are Legacy and stay that way — a migration is
deliberate work, not something to fold into an unrelated change.

## Starting a new project

Start from `templates/`, not from a sample project. Three templates, split by role:
`REFramework-Dispatcher-Base` (reads the source, filters, enqueues — no banking-library
dependency), `REFramework-Performer-Finnova`, `REFramework-Performer-Avaloq`. Instantiation
sequence and the deltas to apply to Studio's generated skeleton: `templates/README.md`.

Two things must be settled **before** the first publish, because both are painful afterwards:
the project name (`project.json → name` must contain **no whitespace anywhere** — it becomes
the package name and the Orchestrator process name) and the queue name.

### Ask before naming a Dispatcher/Performer pair

**Stop and ask the team the first time a UC needs both halves.** There is no working
Dispatcher + Performer pair in this estate yet, so there is no naming pattern to observe — a
`_Dispatcher` / `_Performer` suffix rule would be an assumption. Do not invent one, and do not
let a scaffold quietly establish one.

Ask all three parts together:

1. How should the two **project names** relate?
2. How are they **packaged and published** — two packages, or one with two entry points?
3. What **queue name** do they share?

Then record the answer in `references/naming-conventions.md` (*Dispatcher/Performer pairs*)
and apply it from then on. Answer (3) matters regardless of (1) and (2):
`OrchestratorQueueName` must be byte-identical in both projects' `Settings` sheets, and a
mismatch throws nothing — both jobs finish green with no transaction processed.

## The rule that matters most

**`<Application>_System/` touches the UI. `Logic/` decides. Never mix them.**

A `*_System` workflow takes the coordinates it needs (window title, config, business
inputs) and returns plain values — `out_Status`, `out_ISIN`, `out_ValidKonto`. It does not
decide what those values mean. A `Logic/` workflow takes values and returns a decision. It
never opens a window.

This is what makes a process retargetable across towers and testable without the
application open.

## One folder per application

Create a new `<Application>_System/` folder for each external system the process touches —
even if that system is reached by standard UiPath activities rather than a custom library
(`Mail_System`, `File_System`, `Camunda_System` all wrap stock activities).

Per-application detail, including the exact workflows each reference project provides and
their arguments:

| Folder | Application | Reference |
|---|---|---|
| `Finnova_System/` | Finnova Java thin client | `references/systems/finnova-system.md` |
| `Avaloq_System/` | Avaloq Smart Client | `references/systems/avaloq-system.md` |
| `SIX_ID_System/` | SIX iD portal (Chrome) | `references/systems/six-id-system.md` |
| `CardOne_System/` | CardOne (Chrome) | `references/systems/cardone-system.md` |
| `Web_Nav_System/` | Avaloq embedded report browser | `references/systems/web-nav-system.md` |
| `UBS KeyTrader/` | UBS KeyTrader Java client | `references/systems/ubs-keytrader.md` |
| `Camunda_System/` | Camunda DMN decision REST API | `references/systems/camunda-system.md` |
| `AI/` | LLM chat completion endpoint | `references/systems/ai-system.md` |
| `Mail_System/` | Exchange / SMTP | `references/systems/mail-system.md` |
| `File_System/` | Files, Excel, PDF, trace logs | `references/systems/file-system.md` |

For the activity APIs of the two custom libraries, use `.claude/skills/finnova-library/` and
`.claude/skills/avaloq-library/`.

## References

- `references/project-layout.md` — every folder and Framework file, what belongs in it
- `references/where-does-it-go.md` — decision rules for placing a new workflow
- `references/naming-conventions.md` — workflow and argument naming
- `references/error-handling.md` — exception types and the retry idiom used across all projects
- `references/systems/*.md` — one file per application folder (table above)

Cross-cutting: `.claude/skills/security/` (credentials and config), `.claude/skills/web/` (browser work).
