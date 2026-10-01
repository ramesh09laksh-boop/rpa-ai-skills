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

**No `Main.xaml` and no `Framework/*.xaml`.** Those come from Studio's own
*Robotic Enterprise Process* template, which is the authoritative source for them and stays
in step with your Studio version. Shipping a frozen copy here would rot, and nobody in this
repo can verify a hand-written REFramework `.xaml` still opens. Each template's README lists
the deltas to apply to the generated skeleton.

#### If Studio is not available

You do not have to hand-write the skeleton, and you should not. Seed `Main.xaml` and
`Framework/*.xaml` by **copying them from an unmodified REFramework project** — the three
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

1. **Decide the project name and the queue name first** — see the two sections below. Both
   are painful to change after the first publish.
2. In Studio: **File → New → Robotic Enterprise Process**. Name it the agreed project name,
   in the folder the UC repo will live in, and set **Compatibility: Windows** — not
   *Windows – Legacy*. Getting this wrong at creation means regenerating the project; the
   template's `project.json` says `Windows`, but the `.xaml` Studio generates for Legacy is not
   the same file.
3. Copy the template's `project.json`, `project.uiproj`, `entry-points.json`, `Data/` and
   `Tests/` over the generated project, replacing what Studio produced.
4. In the copied `project.json`, set:
   - `"name"` — the agreed project name. **No spaces, anywhere.** It propagates verbatim into
     the published package name and the Orchestrator process name. The shipped value is
     `<PROJECT-NAME-TBD-ask-team>`, which fails the publishability check on purpose — the
     angle brackets make an unreplaced placeholder impossible to publish and impossible to
     mistake for a finished name. See
     [`naming-conventions.md`](../.claude/skills/standards/references/naming-conventions.md#no-whitespace-in-projectjson--name).
   - `"projectId"` and `entryPoints[0].uniqueId` — fresh GUIDs. The values shipped here are
     placeholders; two projects sharing a `projectId` confuses Studio and Orchestrator.
   - `"description"` — what the process does.

   Then mirror `"name"` and `"description"` into `project.uiproj`, and
   `entryPoints[0].uniqueId` into `entry-points.json`. Three files, one set of values — a
   half-renamed project publishes under the wrong package name.

   **Leave `project.json`'s own `entryPoints[0].input` as `[]`.** It looks inconsistent next to
   `entry-points.json`, which declares three arguments — that is expected, not an oversight.
   Studio rewrites `input`/`output` from `Main.xaml`'s actual arguments the first time it opens
   and saves the project. Hand-editing it to "fix" the mismatch achieves nothing and is
   overwritten on the next save.
5. Open the project in Studio so it reconciles `Main.xaml` against `project.json`, and add the
   `in_ENV` argument (plus `in_TOWER` / `in_System` if the process serves more than one
   installation). `entry-points.json` already declares `in_ENV`,
   `in_OrchestratorQueueName` and `in_OrchestratorQueueFolder`; add matching `Main.xaml`
   arguments or delete the ones the process does not use. Being able to override the queue per
   Orchestrator process without a redeploy is worth keeping for a Dispatcher/Performer pair —
   `PJFVA-966_UC81` does exactly this.

   **Then wire `in_ENV` to the config workbook — this step is not optional.** Selecting the
   workbook is the entire reason `in_ENV` exists. Stock Studio `Main.xaml` invokes
   `Framework/InitAllSettings.xaml` with the literal `in_ConfigFile = "Data\Config.xlsx"`, and
   **no template ships a `Config.xlsx`** — they ship `Config_TST.xlsx` and `Config_PRD.xlsx`.
   Leave the stock literal in place and the very first run dies in Initialization with
   file-not-found. Change that argument to:

   ```vb
   [If(String.IsNullOrWhiteSpace(in_ENV), "Data\Config_TST.xlsx",
       "Data\Config_" & in_ENV.Trim().ToUpperInvariant() & ".xlsx")]
   ```

   The vocabulary is `TST` and `PRD`, matching the two shipped workbooks. The fallback is
   **TST**, deliberately: an unset `in_ENV` must not silently pick up production settings. If
   you add a third environment, add the workbook and keep the key set identical across all of
   them — `validate-project` enforces that parity.

   **This step assumes the stock xlsx config.** If the SDD calls for JSON config instead
   (`Config_TST.json` / `Config_PRD.json`), the expression above changes its file extension
   accordingly, **and** `Framework/InitAllSettings.xaml` itself has to be rebuilt in Studio to
   deserialize JSON instead of `ReadRange` — it is no longer stock. See
   [`config-format.md`](../.claude/skills/standards/references/config-format.md) before
   touching this step if that's the case.
6. Fill in every `[UC-SPECIFIC — replace]` in `Data/Config_TST.xlsx` **and**
   `Data/Config_PRD.xlsx`, and wire each `Assets` row to a real Orchestrator asset —
   [`orchestrator-assets.md`](../.claude/skills/security/references/orchestrator-assets.md).
7. Replace the placeholder rows in `Tests/Tests.xlsx` and add `Tests/RunAllTests.xaml`.

   No template ships the harness, because like `Main.xaml` it is Studio-generated. Its contract:
   it reads the `Tests` sheet of `Tests.xlsx`, invokes each named workflow with the arguments in
   that row, and writes pass/fail back to the `Result` sheet. Seed it from an estate project that
   already has one — `UC39_BPO_manuelle_Boersenauftraege/Tests/` or
   `PJFVA-966_UC81_BPO_VD03_TK_Valoren/Tests/`.

   **Do not invoke anything under `Tests/` from production code.** UC39 calls
   `Tests\RunAllTests_Logging.xaml` from its live process; the test harness then runs as part of
   the business process, which is how a test fixture ends up writing to a production system. See
   [`project-layout.md`](../.claude/skills/standards/references/project-layout.md).
8. Delete `.gitkeep` from any folder that now has real content.

An unreplaced `[UC-SPECIFIC — replace]` marker is a review finding, the same way an
unresolved `TODO_SELECTOR` is.

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
