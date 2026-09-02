# Where does this step go?

Decision rules for placing a new workflow when translating an SDD step into code.

## The primary question

> Does this step **touch an application's UI or an external endpoint**?

| Answer | Folder |
|---|---|
| Yes — it clicks, types, reads a screen, calls an API, sends mail, reads a file | `<Application>_System/` |
| No — it decides, parses, maps, compares, formats | `Logic/` |
| It is REFramework plumbing (init, queue, retry, screenshot) | `Framework/` |
| It is a developer scratchpad or a test | `Tests/` |

A single SDD sentence often splits across two folders. "Check whether the Depotstelle is
valid for this tower" becomes `Finnova_System/Finnova-Depotstelle_Konto_Check.xaml` (reads
the field) and the tower rule lives in config, not in the system workflow.

## Decision tree

```
New step
│
├─ Does it read or write an application screen?
│    └─ YES → <Application>_System/
│             ├─ Application already has a folder? → add a workflow to it
│             └─ New application?                  → create <Application>_System/
│                                                     and document it in
│                                                     references/systems/
│
├─ Does it call an HTTP endpoint, mailbox, file or database?
│    └─ YES → still <Application>_System/
│             (Camunda_System, Mail_System, File_System, AI are all this case)
│
├─ Does it decide, parse, map, compare or format in-memory values?
│    └─ YES → Logic/
│
├─ Does it change how transactions are fetched, retried or reported?
│    └─ YES → Framework/
│
└─ Otherwise → it is probably orchestration → Process.xaml
```

## What belongs directly in `Process.xaml`

`Process.xaml` is **orchestration only**: sequence, branching, and invoking workflows.

Belongs there:
- reading fields off `in_TransactionItem`
- the flowchart / decision structure of the transaction
- throwing `BusinessRuleException` for a decision made at this level

Does **not** belong there:
- library activity calls (`Click Button`, `Set Text`, `Table/Extract`)
- selectors of any kind
- regex parsing of application text

If you are about to drop a `Set Text` into `Process.xaml`, you need a
`<Application>_System/` workflow instead.

## Splitting a step that repeats

When the same operation exists in several variants, use the UC39 counterparty pattern:

```
Logic/Logic-CP_TradeConf_Extract_Init.xaml     ' shared setup, invoked by each variant
Logic/Logic-CP_UBS_Extract.xaml
Logic/Logic-CP_Vontobel_Extract.xaml
Logic/Logic-CP_ZKB_Extract.xaml                ' 14 variants in total
```

One workflow per variant, one shared initialiser. Do not build a single workflow with a
14-branch switch.

## Reusing versus duplicating

Before adding a workflow, check whether the operation already exists:

- `Finnova-System_Save.xaml` (UC39) is invoked 12 times — there is exactly one save workflow.
- `File-Read_Init.xaml` and `Logic-CP_TradeConf_Extract_Init.xaml` are invoked 14 times each.

If a step is "save", "search", "close the window", "read the config", it almost certainly
already exists in the project. Grep the folder before writing.

## When to create a new `<Application>_System/` folder

Create one as soon as the process touches a system that does not have a folder — including
systems reached with stock UiPath activities. `Mail_System/`, `File_System/` and
`Camunda_System/` contain no custom-library activities at all, and they still get their own
folder.

Name it `<Application>_System/` (`Finnova_System`, `Camunda_System`). Two reference folders
deviate — `UBS KeyTrader/` and `AI/` — but new folders should follow the `_System` suffix.

When you create one, add a matching `references/systems/<application>-system.md` here so the
next developer's agent can find it.

## Placement checklist

Before committing a new workflow:

- [ ] Is it in the folder its content implies (UI → `_System`, decision → `Logic`)?
- [ ] Does a `_System` workflow avoid making business decisions?
- [ ] Does a `Logic` workflow avoid touching the UI?
- [ ] Does it take `in_Config` rather than reading `Config_*.xlsx` itself?
- [ ] Does it close every window it opened?
- [ ] Does it already exist under another name?
- [ ] Is it invoked from `Process.xaml` (not from `Tests/`, and not invoking `Tests/`)?
