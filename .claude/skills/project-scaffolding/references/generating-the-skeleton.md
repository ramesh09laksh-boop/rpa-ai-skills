# Generating `Main.xaml` and `Framework/` — the two routes

The templates in `templates/` deliberately ship **no `.xaml`**. They carry `project.json`,
`project.uiproj`, `entry-points.json`, `Data/` and `Tests/`; the REFramework skeleton itself
comes from UiPath and has to be generated so it stays in step with your Studio version.

Two routes. Both end in the same place: copy `Main.xaml` + `Framework/` into the project, then
apply the fetched template's own *"Deltas to apply to the generated skeleton"* section.

## Route A — Studio (the fallback)

File → New → **Robotic Enterprise Process**, Compatibility: **Windows** (not *Windows – Legacy*).
Then copy the fetched `project.json`, `project.uiproj`, `entry-points.json`, `Data/` and `Tests/`
over what Studio produced.

Use this when the CLI route fails, or when you want Studio's own wizard defaults.

## Route B — the CLI

Verified working against `uip` **1.204.0**. Run `--help` before relying on any flag.

```bash
# 1. Find the template and its version. Returns the LATEST version per package.
uip rpa templates search --query "REFramework" --output json
#    -> UiPath.Template.REFramework | 26.10.1 | Official

# 2. Generate into a SCRATCH folder, never straight into the project
uip rpa init --name "ScratchREF" \
  --template-package-id "UiPath.Template.REFramework" \
  --template-package-version "26.10.1" \
  --target-framework Windows \
  --location "<scratch dir>" \
  --skip-solution-registration
```

`--skip-solution-registration` matters: without it a project created inside a solution
directory is auto-registered into the enclosing `.uipx`, and a scratch skeleton has no business
being in your solution.

**Generate into a scratch folder, then copy.** `uip rpa init` creates `<location>/<name>/` and
will not merge into an existing project — and you only want two of the things it produces.

### What 26.10.1 actually produces

Verified by running the command above and inspecting the output:

```
Main.xaml  Main.xaml.json  project.json  project.uiproj  entry-points.json
Data/Config.json  Data/{Input,Output,Temp}/
Framework/{InitAllSettings,InitAllApplications,GetTransactionData,Process,
           SetTransactionStatus,RetryCurrentTransaction,CloseAllApplications,
           KillAllProcesses,TakeScreenshot}.xaml
Framework/AGENTS.md  Framework/CLAUDE.md
Tests/*.xaml  Tests/Tests.xlsx  Exceptions_Screenshots/  LICENSE  README.md
```

## The deltas you must apply — and why you cannot skip them

The generated skeleton does **not** match this estate. Measured against `templates/`:

| What | 26.10.1 generates | This estate requires |
|---|---|---|
| Config | `Data/Config.json` — **JSON**, with a JSON-reading `InitAllSettings` | `Data/Config_TST.xlsx` + `Config_PRD.xlsx`, unless the SDD chose JSON |
| `Main.xaml` arguments | **none at all** — no `x:Members`, so no `in_ENV` | `in_ENV`, which selects `Config_<ENV>.xlsx` |
| `GetTransactionData` | queue-based (`GetQueueItem`) | queue-based, *or* the non-queue rewrite — see `non-queue-reframework.md` |
| `designOptions.modernBehavior` | **absent** | `true` — `validate-project` reports an error otherwise |
| `studioVersion` | `26.10.0.0` | `23.10.8.0` in `templates/`, from the reference projects |
| `UiPath.UIAutomation.Activities` | `[26.10.6]` | `[26.10.4]` if you intend to capture selectors — see the `web` skill |

The missing `in_ENV` is the one that bites first: the whole `Config_<ENV>` mechanism this estate
runs on is an estate addition, not stock REFramework. A skeleton copied in without it has no way
to tell TST from PRD.

## Pick the version to match the config-format decision

`UiPath.Template.REFramework` **26.10.x ships a JSON-config `InitAllSettings.xaml`.** Earlier
versions (25.10.x) ship the xlsx-config one. So the template version is not a free choice — it
follows the SDD's config-format decision:

| SDD chose | Prefer | Because |
|---|---|---|
| `Config_<ENV>.xlsx` (stock for this estate) | a 25.10.x template | its `InitAllSettings` already reads a workbook |
| `Config_<ENV>.json` | 26.10.x | its `InitAllSettings` already reads JSON |

`templates search` returns only the latest version per package, so an older version has to be
requested by exact version string.

### Do not mix `Framework/` files across template versions

This is a real, costly failure, not a precaution. The 25.10.1 xlsx-config `InitAllSettings.xaml`
copied into a 26.10-generated skeleton produced:

```
BC31424: Type 'System.Data.DataRow' in assembly 'System.Data' has been forwarded to
assembly 'System.Data.Common'.
```

…while `validate-project` reported **PASS** and `uip rpa build` reported **Success**. Only
opening it in Studio (**L3**) surfaced it. The recipe is in the `standards` skill,
`references/silent-failure-traps.md`.

If you must move a Framework file across versions, treat L3 as mandatory, not advisory.

## Record what worked

Studio version, template package version and the config format have to agree, and the
combination drifts with every Studio release. **When a pair is confirmed working, write it into
`templates/README.md`** so the next project starts from evidence instead of repeating this.
