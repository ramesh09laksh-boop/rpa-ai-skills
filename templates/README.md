# REFramework project templates

Three starting points, split by the role a project plays rather than by the bank system it
talks to. A Dispatcher's job — read the upstream source, apply the selection rule, enqueue —
never touches Finnova or Avaloq activities, so one shared skeleton fits every project. A
Performer does, so it gets a template per library.

| Template | Role | Library dependency |
|---|---|---|
| [`REFramework-Dispatcher-Base/`](REFramework-Dispatcher-Base/) | Reads the source, filters, enqueues | none |
| [`REFramework-Performer-Finnova/`](REFramework-Performer-Finnova/) | Consumes the queue, drives Finnova | `Swisscom.FinnovaLibrary [2026.1.0]`, `Swisscom.PHI [24.10.0]` |
| [`REFramework-Performer-Avaloq/`](REFramework-Performer-Avaloq/) | Consumes the queue, drives Avaloq | `Swisscom.UiPath.UIAutomation.Avaloq [2025.9.1]`, `Swisscom.PHI [24.10.0]` |

There is deliberately no combined template. One that carries both library dependencies is
bloat for a project that needs one; one that carries neither is not a template.

**Copy the base Dispatcher and adapt it.** The source-read step and the filter rule change
every time; the scaffold around them doesn't. Only create a new Dispatcher template if a
project's pattern needs something `REFramework-Dispatcher-Base/` genuinely cannot express.

## Before you start: the library feed

Finnova/Avaloq `.nupkg`s must already be published to your package feed before you open or
restore a project that references them — see [the prerequisite note in the repo
README](../README.md#prerequisite-publish-the-libraries-to-your-feed). Both Performer
templates set `"mustRestoreAllDependencies": true`, so a missing package fails the restore
loudly instead of leaving you with a project that half-loads.

## What a template contains — and what it doesn't

Each template ships the project-level scaffolding that Studio's built-in REFramework template
leaves empty or gets wrong for this estate:

```
<Template>/
  README.md                    how to instantiate this one
  project.json                 dependencies, runtime options, name placeholder
  project.uiproj               project name / type / main file
  entry-points.json            declared process arguments (in_ENV, queue overrides)
  Data/
    Config_TST.xlsx            Settings / Constants / Assets, pre-populated
    Config_PRD.xlsx            identical key set to TST
    config-contents.md         generated, diffable rendering of both workbooks
    Input/  Output/  Temp/
  Tests/
    Tests.xlsx                 Tests / Result sheets, placeholder rows
    tests-contents.md          generated, diffable rendering
  Documentation/
  Exceptions_Screenshots/
```

**No `Main.xaml` and no `Framework/*.xaml`.** Those come from UiPath's own
*Robotic Enterprise Process* template, which is the authoritative source for them and stays
in step with your Studio version. Shipping a frozen copy here would rot, and nobody in this
repo can verify a hand-written REFramework `.xaml` still opens. Each template's README lists
the deltas to apply to the generated skeleton.

Generate it either with the CLI (`uip rpa init --template-package-id
UiPath.Template.REFramework …`) or from Studio. Both routes, and the full delta table, are in
the `project-scaffolding` skill, `references/generating-the-skeleton.md`.

### Version combinations: what has actually been verified

Studio version, template package version and config format have to agree, and the combination
drifts with every Studio release. **Add a row when you confirm one works** — that is what makes
the next project cheaper than this one.

| Template package | Version | Ships | `studioVersion` | `UiPath.UIAutomation.Activities` | Verified |
|---|---|---|---|---|---|
| `UiPath.Template.REFramework` | `26.10.1` | `Data/Config.json` (**JSON** `InitAllSettings`), queue-based `GetTransactionData`, **no `in_ENV`** in `Main.xaml`, no `designOptions.modernBehavior` | `26.10.0.0` | `[26.10.6]` | Generated and inspected via `uip rpa init` (rpa-tool 1.204.2) |
| `templates/` here, from `../REFramework-*/` | — | `Config_TST/PRD.xlsx` | `23.10.8.0` | — | The estate's current baseline |

Three consequences worth stating plainly:

- **26.10.x ships the JSON config variant.** If the SDD chose `Config_<ENV>.xlsx` — the estate
  default — request a 25.10.x template version instead, or you inherit an `InitAllSettings` that
  reads the wrong format. `uip rpa templates search` returns only the latest version per
  package, so an older one has to be named by exact version string.
- **`in_ENV` is an estate addition, not stock REFramework.** The generated `Main.xaml` has no
  `x:Members` at all, so the whole `Config_<ENV>` mechanism has to be added.
- **The capture pin and the template pin disagree.** 26.10.1 brings
  `UiPath.UIAutomation.Activities [26.10.6]`, while selector capture with `uip rpa uia` is
  verified at `26.10.4` (see the `web` skill). Reconcile deliberately; do not let `init` decide it.

**Never mix `Framework/` files across template versions.** The 25.10.1 xlsx-config
`InitAllSettings.xaml` dropped into a 26.10 skeleton produced a `BC31424` compile error that
both `validate-project` and `uip rpa build` reported as clean.

#### If Studio is not available

You do not have to hand-write the skeleton, and you should not. Either use the CLI route above,
or seed `Main.xaml` and `Framework/*.xaml` by **copying them from an unmodified REFramework
project** — the three
reference projects one level above this repo (`../REFramework-Dispatcher-Base/`,
`../REFramework-Performer-Avaloq/`, `../REFramework-Performer-Finnova/`) are real Studio 23.10
Windows projects and exist for exactly this. Any untouched REFramework in the estate works too.

Copy only from a project whose `project.json` agrees with your target on all four of:

| | must match |
|---|---|
| `studioVersion` | e.g. `23.10.8.0` |
| `targetFramework` | `Windows` — never a `Windows - Legacy` source |
| `designOptions.modernBehavior` | `true` |
| `expressionLanguage` | `VisualBasic` |

A mismatch on any of them produces a project that opens with errors, or silently behaves
differently at runtime.

**The source must be an unmodified skeleton, not another UC's implementation.** Copying a
working project drags its business logic, its selectors and its config assumptions into yours,
and they are extremely hard to spot afterwards — the `.xaml` looks plausible because it *is*
plausible, just for a different process.

Then: apply the deltas from the template's README (including the `in_ConfigFile` change in step
5 — the stock literal points at a `Config.xlsx` that does not exist), open the result in Studio
at the first opportunity so it reconciles `project.json`, and run
`.claude/skills/project-scaffolding/scripts/validate-project.ps1` before you trust it.

### The templates target Windows, not Legacy

All three `project.json` files set `"targetFramework": "Windows"` with
`"modernBehavior": true` and `"studioVersion": "23.10.8.0"`. Pins and runtime options were
taken from the three reference projects that sit one level above this repo —
`../REFramework-Dispatcher-Base/`, `../REFramework-Performer-Avaloq/`,
`../REFramework-Performer-Finnova/` — which are real Studio 23.10 Windows projects, not
hand-written JSON.

Two deliberate departures from those reference projects:

- **`"requiresUserInteraction": false`.** The reference projects carry Studio's default of
  `true`. Every project instantiated from these templates is unattended, so the templates
  keep `false`.
- **`"fileInfoCollection": []`.** The reference projects list six `Tests\*.xaml` test cases
  there. The templates ship no `.xaml`, and an entry pointing at a file that does not exist
  makes Studio complain on open — Studio repopulates this as you add test cases.

`entry-points.json` declares `in_ENV` plus `in_OrchestratorQueueName` /
`in_OrchestratorQueueFolder`. Its `uniqueId` is a placeholder, like `project.json`'s — regenerate
both when you instantiate.

## Getting a template into a UC project

`npx skills add` carries `.claude/skills/` folders only, and this directory has no `SKILL.md`,
so the templates do **not** come along with the skills. Two routes:

- **Have `rpa-ai-skills` checked out?** Copy the template folder. Nothing else needed.
- **Don't?** Use the `project-scaffolding` skill, which does travel with `npx skills add` and
  ships `scripts/fetch-template.sh` (+ a `.ps1` twin) to sparse-checkout just the subfolder(s)
  you need:
  [`project-scaffolding`](../.claude/skills/project-scaffolding/SKILL.md).

## Instantiating a template

**The checklist lives in the `project-scaffolding` skill, not here:**
[`references/instantiating-templates.md`](../.claude/skills/project-scaffolding/references/instantiating-templates.md).

It moved because this file does not travel. `scripts/fetch-template.*` does a sparse checkout of
`templates/<name>/` only, so a UC project that fetches a template gets the folder and **not this
README** — and both the script's closing message and the skill's step 3 used to point here. The
checklist now ships with the script that tells you to work it.

Eight steps, in order: the project name and queue name decided first; Windows compatibility at
creation; copy the project files over; fresh GUIDs and the three identity files kept in step;
`in_ENV` added **and wired to `Config_<ENV>.xlsx`** (the stock literal points at a `Config.xlsx`
no template ships, so skipping this kills the first run in Initialization); every
`[UC-SPECIFIC — replace]` filled in both workbooks; `Tests.xlsx` rows and `RunAllTests.xaml`;
`.gitkeep` deleted where there is now real content. Then `validate-project` to zero errors.

Read it there. Keeping a second copy here is how the two drift apart.

## The queue name is a contract between the pair

A Dispatcher and its Performer share one Orchestrator queue. Both templates carry
`OrchestratorQueueName` in the `Settings` sheet, and it must be **byte-identical** in the two
projects.

This is the failure mode worth designing against: a mismatch throws nothing. The Dispatcher
enqueues successfully into `UC42_Something_Queue`, the Performer polls
`UC42_Somthing_Queue`, finds it empty, and ends its run reporting success. Both jobs go green
in Orchestrator and no transaction is ever processed.

So:

- **Write the queue name down when you instantiate the pair**, in both `Config_TST.xlsx` and
  `Config_PRD.xlsx`, and in the UC's own documentation — not just in whichever project you
  scaffolded first.
- **Set `logF_BusinessProcessName` to the same value in both**, so the two halves group under
  one business process in the Orchestrator logs and an empty Performer run is visible next to
  the Dispatcher run that fed it.
- **Check it as a pair, not per project.** Diffing the two `Settings` sheets is the whole
  check.
- If the process is queue-per-environment, `OrchestratorQueueFolder` scopes it — leave it
  empty for classic folders.

Queue naming that the estate actually evidences (TKB-UC11's config sheets):
`UC11_Hauptprozess_Queue`, `UC14_Mahngebühr_Queue`, `UC15_KK_entsperren_Queue` — i.e.
`UC<NN>_<Purpose>_Queue`. Follow it unless the team decides otherwise below.

## Open question: how a Dispatcher and Performer are named

There is **no working two-project pair in this estate yet**, so there is no observed naming
pattern to copy. A `_Dispatcher` / `_Performer` suffix rule would be an assumption, and this
repo does not ship assumptions as conventions.

The first UC to instantiate both templates settles it. Bring the question to the team, get an
answer for all three parts — project names, published package names, shared queue name — and
write it into
[`naming-conventions.md`](../.claude/skills/standards/references/naming-conventions.md#dispatcherperformer-pairs--undecided);
after that it is the rule. The `standards` skill raises this prompt on first
occurrence.

## Regenerating the workbooks

`Config_*.xlsx` and `Tests.xlsx` are generated, not hand-maintained. Edit the row data in
[`tools/build-template-workbooks.ps1`](tools/build-template-workbooks.ps1) and re-run it:

```powershell
pwsh -File templates/tools/build-template-workbooks.ps1
```

It rewrites all six config workbooks, all three test workbooks and their `*-contents.md`
renderings. Editing a shipped `.xlsx` in Excel works until the next person runs the script,
at which point the change is gone — change the script instead.
