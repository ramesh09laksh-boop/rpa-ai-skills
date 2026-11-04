# Instantiating a template — the checklist

**This file travels with the skill.** It used to live in the templates repo's own
`templates/README.md` — which is **not in your project**, because `scripts/fetch-template.*`
sparse-checks-out `templates/<name>/` only, so the folder arrives and the checklist does not.
Step 3 of `SKILL.md` and both scripts' closing message pointed at a file that was never
delivered. It lives here now, next to the script that tells you to read it.

Work it in order. Steps 1 and 4 are painful to change after the first publish.

## 1. Decide the project name and the queue name first

Both are decisions, not defaults, and both are settled with the team — see `SKILL.md`,
*Three decisions to settle before the first publish*.

- **Project name.** The templates ship `"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails the
  publishability check on purpose: the angle brackets make an unreplaced placeholder impossible
  to publish and impossible to mistake for a finished name. Three naming formats are live in the
  estate and none is minuted. The `standards` skill, `references/naming-conventions.md`.
- **Queue name.** A Dispatcher and its Performer share one Orchestrator queue, and
  `OrchestratorQueueName` must be **byte-identical** in both `Settings` sheets. A mismatch throws
  nothing: the Dispatcher enqueues, the Performer polls an empty queue, and both jobs finish
  green with no work done. Write it down when you instantiate the pair — in both
  `Config_TST.xlsx` and `Config_PRD.xlsx`, and in the UC's own documentation, not just in
  whichever project you scaffolded first.
- **`logF_BusinessProcessName` to the same value in both**, so the two halves group under one
  business process in the Orchestrator logs and an empty Performer run is visible next to the
  Dispatcher run that fed it.
- `OrchestratorQueueFolder` scopes a queue-per-environment setup; leave it empty for classic
  folders.

## 2. Create the project with the right compatibility

Studio: **File → New → Robotic Enterprise Process**. Name it the agreed project name, in the
folder the UC repo will live in, and set **Compatibility: Windows** — not *Windows – Legacy*.
Getting this wrong at creation means regenerating the project: the template's `project.json` says
`Windows`, but the `.xaml` Studio generates for Legacy is not the same file.

The CLI route (`uip rpa init`) is preferred and needs no Studio session — `SKILL.md` step 1, and
`references/generating-the-skeleton.md` for the full delta table.

## 3. Copy the template's project files over the generated project

`project.json`, `project.uiproj`, `entry-points.json`, `Data/` and `Tests/`, replacing what
Studio produced.

## 4. Set the identity fields — three files, one set of values

In the copied `project.json`:

- **`"name"`** — the agreed project name. **No spaces, anywhere.** It propagates verbatim into
  the published package name and the Orchestrator process name.
- **`"projectId"`** and **`entryPoints[0].uniqueId`** — fresh GUIDs. The shipped values are
  placeholders; two projects sharing a `projectId` confuses Studio and Orchestrator.
- **`"description"`** — what the process does.

Then mirror `"name"` and `"description"` into `project.uiproj`, and `entryPoints[0].uniqueId`
into `entry-points.json`. A half-renamed project publishes under the wrong package name.

**Leave `project.json`'s own `entryPoints[0].input` as `[]`.** It looks inconsistent next to
`entry-points.json`, which declares three arguments — that is expected, not an oversight. Studio
rewrites `input`/`output` from `Main.xaml`'s actual arguments the first time it opens and saves
the project. Hand-editing it to "fix" the mismatch achieves nothing and is overwritten on the
next save.

## 5. Add `in_ENV` — and wire it to the config workbook

Open the project in Studio so it reconciles `Main.xaml` against `project.json`, and add the
`in_ENV` argument (plus `in_TOWER` / `in_System` if the process serves more than one
installation). `entry-points.json` already declares `in_ENV`, `in_OrchestratorQueueName` and
`in_OrchestratorQueueFolder`; add matching `Main.xaml` arguments or delete the ones the process
does not use. Being able to override the queue per Orchestrator process without a redeploy is
worth keeping for a Dispatcher/Performer pair.

**Then wire `in_ENV` to the config workbook — this step is not optional.** Selecting the workbook
is the entire reason `in_ENV` exists. Stock Studio `Main.xaml` invokes
`Framework/InitAllSettings.xaml` with the literal `in_ConfigFile = "Data\Config.xlsx"`, and **no
template ships a `Config.xlsx`** — they ship `Config_TST.xlsx` and `Config_PRD.xlsx`. Leave the
stock literal in place and the very first run dies in Initialization with file-not-found. Change
that argument to:

```vb
[If(String.IsNullOrWhiteSpace(in_ENV), "Data\Config_TST.xlsx",
    "Data\Config_" & in_ENV.Trim().ToUpperInvariant() & ".xlsx")]
```

The vocabulary is `TST` and `PRD`, matching the two shipped workbooks. The fallback is **TST**,
deliberately: an unset `in_ENV` must not silently pick up production settings. If you add a third
environment, add the workbook and keep the key set identical across all of them —
`validate-project` enforces that parity.

**This step assumes the stock xlsx config.** If the SDD calls for JSON config instead
(`Config_TST.json` / `Config_PRD.json`), the expression above changes its file extension
accordingly, **and** `Framework/InitAllSettings.xaml` itself has to be rebuilt in Studio to
deserialize JSON instead of `ReadRange` — it is no longer stock. Read the `standards` skill,
`references/config-format.md` before touching this step if that is the case.

`validate-project`'s `config-file-not-wired` rule is what catches a missed version of this step.

## 6. Fill in every `[UC-SPECIFIC — replace]`

In `Data/Config_TST.xlsx` **and** `Data/Config_PRD.xlsx` — both, with the same key set — and wire
each `Assets` row to a real Orchestrator asset: the `security` skill,
`references/orchestrator-assets.md`.

An unreplaced `[UC-SPECIFIC — replace]` marker is a review finding, the same way an unresolved
`TODO_SELECTOR` is. `validate-project`'s `template-default-left` rule finds them.

## 7. Replace the placeholder rows in `Tests/Tests.xlsx`, and add `Tests/RunAllTests.xaml`

No template ships the harness, because like `Main.xaml` it is Studio-generated. Its contract: it
reads the `Tests` sheet of `Tests.xlsx`, invokes each named workflow with the arguments in that
row, and writes pass/fail back to the `Result` sheet. Seed it from an estate project that already
has one.

**Do not invoke anything under `Tests/` from production code.** One estate project calls its test
harness from its live process; the harness then runs as part of the business process, which is
how a test fixture ends up writing to a production system. The `standards` skill,
`references/project-layout.md`.

## 8. Delete `.gitkeep` from any folder that now has real content

## Then: run the conformance checker and get it to zero errors

`SKILL.md` step 4. Pass a Dispatcher and its Performer together so the queue name is checked
across the pair.

---

**Maintainer provenance — not in your project.** The template workbooks are generated from a
script in the templates repo, and their sheet names and column headers were read out of real
estate projects rather than invented. None of that travels with a fetched template and none of it
is something a UC project needs. If you are editing the templates themselves rather than
instantiating one, that is the templates repo's own `README.md`, not this file.
