# Config file format: `Config_<ENV>.xlsx` (stock) vs `Config_<ENV>.json`

A project-wide decision, made once, during PDD → SDD or at the latest when scaffolding the
project — not something to default silently, and painful to change afterwards because it's
baked into `Framework/InitAllSettings.xaml` at generation time.

## What stock REFramework actually does

Taken directly from `Framework/InitAllSettings.xaml` in the three reference projects — this
is not an extrapolation:

- `in_ConfigFile` (`Data\Config_<ENV>.xlsx`) and `in_ConfigSheets` (`{"Settings","Constants"}`)
  are process arguments.
- For each sheet in `in_ConfigSheets`: `ReadRange` into a DataTable, then for each row,
  `out_Config(Row("Name").ToString.Trim) = Row("Value")`.
- Separately: `ReadRange` the `Assets` sheet, then for each row, `TryCatch { Get Orchestrator
  asset AssetName=row("Asset") FolderPath=row("OrchestratorAssetFolder") }`, and on success
  `out_Config(row("Name").ToString) = AssetValue` — overwriting any Settings/Constants value
  of the same name.

Every other workflow in the project reads `in_Config("<key>")`. **That lookup never changes,
whichever file format is behind it** — the blast radius of this decision is contained entirely
inside `InitAllSettings.xaml`.

## Option 1 — `Config_TST.xlsx` / `Config_PRD.xlsx` (default)

What every template ships today. Zero Framework changes. Use this unless there's a specific
reason not to (a request to version config as text/JSON in git, an existing non-Excel config
convention in the receiving team, etc.) — it's the only option with zero migration risk.

## Option 2 — `Config_TST.json` / `Config_PRD.json`

Same `Settings` / `Constants` / `Assets` semantics, same TST/PRD parity rule (a key missing
from one environment's file fails that environment the same way a missing xlsx column does),
different file shape:

```json
{
  "Settings": {
    "OrchestratorQueueName": "...",
    "logF_BusinessProcessName": "..."
  },
  "Constants": {
    "MaxRetryNumber": 0,
    "MaxConsecutiveSystemExceptions": 3
  },
  "Assets": [
    { "Name": "Mail_System_Exception_To", "Asset": "Email_Recipients_Error", "OrchestratorAssetFolder": "" }
  ]
}
```

`Settings`/`Constants` are flat key→value, matching the two-column sheets. `Assets` stays an
**array of objects**, not a flat map — collapsing it would lose the `Asset` indirection
(config key name and Orchestrator asset name differ in real rows, e.g.
`Avaloq_System_Client_Path` → `Avaloq_SmartClient_Path`) and the folder-scoping column.

**Required Framework change — this is the actual cost of choosing JSON:**

`InitAllSettings.xaml` must be rebuilt (in Studio, not hand-edited XAML) to replace both
`ReadRange` activities with a JSON deserialization step that populates the same `out_Config`
dictionary the same way — Settings/Constants first, then the Assets loop **unchanged**
(`Get Orchestrator asset` per entry, overwrite on success, warn-and-continue on failure, per
`security/references/orchestrator-assets.md`). `in_ConfigSheets` has no JSON equivalent and
should be dropped from the rebuilt workflow rather than left wired to nothing.

Mark the result clearly as **not stock** — an annotation at the top of the workflow saying so
— since every other project in the estate has this file untouched, and a future developer
needs to know this one project deliberately diverges before they go looking for why a
`ReadRange` isn't there.

**This is one documented recipe, reused by all three templates.** `InitAllSettings.xaml` is
identical stock across `REFramework-Dispatcher-Base`, `REFramework-Performer-Finnova` and
`REFramework-Performer-Avaloq` today, so the same rebuild applies to whichever one(s) a
project fetches — there's no per-template variation to design separately.

## Known gap — not yet closed

`.claude/skills/project-scaffolding/scripts/validate-project.*` reads the config workbook
directly to check things like TST/PRD key parity and unresolved `[UC-SPECIFIC — replace]`
markers. **It does not yet parse JSON.** A project built with Option 2 needs that script
extended before it can get the same validation coverage — until then, check TST/PRD parity
and marker resolution by hand for a JSON-configured project. Do not claim validate-project
covers JSON config until this is actually built.

## Where this gets decided

- **Ask during PDD → SDD** (or at project scaffolding, at the latest) — don't infer a default.
  Record the answer in the SDD's configuration section.
- See `project-scaffolding/SKILL.md` → "Two decisions to settle before the first publish" —
  this is a third one, same shape as project name and queue name: no default this repo picks
  for you, and expensive to change after the first publish.
