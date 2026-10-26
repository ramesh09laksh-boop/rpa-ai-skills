---
name: project-scaffolding
description: Use when starting a new UC project — determines which Dispatcher/Performer template(s) to pull from rpa-ai-skills and fetches just that subfolder, without requiring a full clone of the templates repo. Trigger on "start a new UC project", "scaffold a new automation", "kick off UC<NN>", "which template do I use", "get the REFramework template", or when an SDD names its target application (Finnova, Avaloq, or both) and no project folder exists yet.
---

# Fetching a project template

`templates/` in `rpa-ai-skills` has no `SKILL.md` of its own, so `npx skills add` never brings
it along — that command carries skill folders only. This skill is the fetch step, wrapped so it
travels like any other skill: install it, and `scripts/fetch-template.*` comes with it.

## Before anything else: preflight

Environment problems cost a real build run more time than the automation logic did. Run this
first; it changes nothing and prints a one-line fix per failure:

```bash
scripts/preflight.sh [<project-dir>]
pwsh -NoProfile -File scripts/preflight.ps1 -ProjectPath <project-dir>
```

It checks Node 22.20+, git and GitHub auth (the skills repo is private), PowerShell 7,
`uip` and its login, Studio **and whether an instance has the project open**, the
`UiPath.UIAutomation` 26.10.4 capture pin, that the Swisscom libraries actually restore from
your feed, and a capture smoke test. Pass `-NoProfile` if you invoke the `.ps1` directly — a
slow or prompting PowerShell profile makes it look like it has hung.

## What to fetch

Ask, or read it off the SDD: **which application does this UC drive?**

| The UC… | Fetch |
|---|---|
| always | `REFramework-Dispatcher-Base` |
| drives Finnova | `+ REFramework-Performer-Finnova` |
| drives Avaloq | `+ REFramework-Performer-Avaloq` |
| drives both | `+` both Performers |

The Dispatcher is always fetched. Its job — read the upstream source, apply the selection
rule, enqueue — touches neither banking library, so one skeleton fits every project. If the
SDD describes no queue at all and the process is a single self-contained run, say so and fetch
only the Performer; do not invent a Dispatcher the process does not need.

### Non-queue REFramework

A process with **no** Orchestrator queue needs three changes made together
(`GetTransactionData`, `MaxRetryNumber`, `OrchestratorQueueName`), and neither Performer
template flags them. Making one or two of the three is worse than making none, because the
result looks wired and processes nothing. Full recipe:
`references/non-queue-reframework.md`.

**If `rpa-ai-skills` is already checked out locally, skip the script and copy the folder.**
The script exists for the case where it isn't — it is not the only sanctioned route.

## Fetching

No setup needed — the canonical repo is the default:

```bash
scripts/fetch-template.sh REFramework-Dispatcher-Base REFramework-Performer-Finnova
```

```powershell
scripts\fetch-template.ps1 -Template REFramework-Dispatcher-Base,REFramework-Performer-Finnova
```

Both do a blobless, depth-1 sparse checkout of only the matched `templates/<name>/` paths, then
move them into place. Neither will overwrite an existing folder — that is deliberate, so a
re-run cannot silently discard work in progress. `-d` / `-Destination` sets where they land
(default: the current directory); `-b` / `-Ref` pins a branch or tag.

### Pointing at a fork or an internal mirror

The default is `https://github.com/ramesh09laksh-boop/rpa-ai-skills`. Override it per
invocation, or once per developer:

```bash
scripts/fetch-template.sh -r https://git.internal/rpa-ai-skills.git REFramework-Dispatcher-Base
export RPA_SKILLS_REPO=https://git.internal/rpa-ai-skills.git   # or set it once
```

Precedence is `-r` / `-RepoUrl` > `$RPA_SKILLS_REPO` > default. Each run prints which of the
three it used, so a stale mirror is visible in the output rather than something you discover
later.

If the clone fails against the default, the likely causes are that the repo is private and
git is not authenticated (`gh auth login`, an SSH key, or a PAT), or that your team works from
a mirror — GitHub returns "not found" for both. The scripts say so when they fail.

### Fetched files have CRLF line endings — this is expected

A naive `diff -r` reports **every** text file as changed. That is `core.autocrlf`, not content:
`diff -r --strip-trailing-cr` exits clean and the `.xlsx` files match by md5. Nothing to fix for
markdown/JSON; `*.sh` is the one exception, and the repo's `.gitattributes` already handles it.
Details: `references/fetched-files-crlf.md`.

## After fetching — this is not a finished project

The template is project-level scaffolding only. Three things still have to happen, in order:

1. **Generate `Main.xaml` and `Framework/*.xaml`.** The templates deliberately ship no `.xaml`
   — the REFramework skeleton comes from UiPath so it stays in step with your Studio version.
   Two routes, both verified:

   - **Route B — the CLI** (preferred; no Studio session needed):

     ```bash
     uip rpa templates search --query "REFramework" --output json
     uip rpa init --name "ScratchREF" \
       --template-package-id "UiPath.Template.REFramework" \
       --template-package-version "26.10.1" \
       --target-framework Windows --location "<scratch dir>" \
       --skip-solution-registration
     ```

     Generate into a **scratch folder**, then copy `Main.xaml` + `Framework/` into the project.
   - **Route A — Studio** (fallback): File → New → **Robotic Enterprise Process**,
     Compatibility: **Windows** (not *Windows – Legacy*).

   Either way, copy the fetched `project.json`, `project.uiproj`, `entry-points.json`, `Data/`
   and `Tests/` over what was produced.

   **The generated skeleton does not match this estate** — 26.10.1 ships a JSON
   `Data/Config.json`, a `Main.xaml` with **no `in_ENV` at all**, no
   `designOptions.modernBehavior`, and `studioVersion 26.10.0.0` against the templates'
   `23.10.8.0`. Pick `--template-package-version` to match the SDD's config-format decision
   (26.10.x = JSON `InitAllSettings`, 25.10.x = xlsx), and **never mix `Framework/` files across
   template versions** — that is what produced the `BC31424` compile error that `validate-project`
   and `uip rpa build` both missed. Full delta table and commands:
   `references/generating-the-skeleton.md`.
2. **Apply the "Deltas to apply to the generated skeleton" section** from the fetched
   template's own `README.md`. That section is what turns a stock REFramework skeleton into a
   Dispatcher or a Finnova/Avaloq Performer — it is the substance of the template, not an
   appendix.
3. **Work the instantiation checklist** in `templates/README.md` — project name, fresh GUIDs,
   every `[UC-SPECIFIC — replace]` in `Config_TST.xlsx` *and* `Config_PRD.xlsx`, and the shared
   queue name.
4. **Run the conformance checker and get it to zero errors.**

   ```bash
   `scripts/validate-project.sh`  <project-dir> [<project-dir>]
   pwsh -File `scripts/validate-project.ps1` <project-dir>
   ```

   Pass a Dispatcher and its Performer together and it also checks the queue name is
   byte-identical across the pair. Every rule it enforces catches a failure that is otherwise
   **silent** — a stock `ProcessABCQueue`, a disabled circuit breaker, `ShouldMarkJobAsFaulted`
   false, a `Main.xaml` still pointing at the non-existent `Data\Config.xlsx`. Non-zero exit on
   any error, so it drops straight into CI. An unreplaced marker is a review finding; this is
   what finds it.

   **`config-key-undefined` (error)** catches a workflow reading a config key no sheet defines.
   A missing key returns `Nothing` from the Dictionary, the expression becomes `""`, and the run
   continues with an empty path, queue name or timeout — no error, wrong behaviour. Keys the
   project *assigns* into Config at runtime (stock REFramework does this for `ENV` in
   `Main.xaml`) count as defined.

   **A `WARN` is not "pre-existing, therefore harmless".** `relative-persisted-path` in
   particular is a documented silent-failure trap — fix it before the first real run.

   Four rules land as warnings on the **leaf-workflow contract** —
   `system-workflow-no-config`, `system-workflow-no-outcome`, `secret-argument-string`,
   `logic-workflow-no-arguments`. They are warnings because the rules are new, not because the
   contract is optional: a scaffold that trips them does not meet the `_System` contract in
   `standards/references/project-layout.md`. Calibration — the estate's reference-quality
   project (UC39) reports **zero** of them.

   A rule that genuinely does not apply yet goes in a `validate-project.ignore` beside
   `project.json` **with a written reason**, and the finding is still printed. See
   `references/suppressing-a-rule.md`.

## `validate-project` PASS is level 1 of 4 — say which level you reached

`validate-project` is a **static** checker: text and workbook rules. It compiles nothing and
runs nothing. On the Lanes run it reported PASS and `uip rpa build` reported Success while
Studio showed a compile error in `Framework/InitAllSettings.xaml` and every run failed with
"The workflow cannot be found".

| Level | What it establishes | Command |
|---|---|---|
| **L1** | Estate conformance (static) | `validate-project.sh` / `.ps1` |
| **L2** | Compiles and passes the analyzer | `uip rpa validate --min-severity error`, then `uip rpa build` |
| **L2b** | **Packs** — survives the UiRobot packaging step | `uip rpa pack <project> --output-path <dir>` |
| **L3** | Studio opens it with an **empty Error List** | Studio |
| **L4** | A **real job on TST** in the Orchestrator folder, on a robot, with the SDD's expected results checked | `uip or jobs start`, then `jobs get` / `jobs logs` |

Every report names the highest level reached **and the command that proved it**. A wiring or
"project ready" stage is not done below **L3** — L1 and L2 both passed on a project Studio
could not compile. **L2b is separate because `validate` and `build` are not the last
compile-time gate** — a missing assembly reference and `ST-SEC-008` both pass them and fail at
`pack`. **A local `uip rpa run` is L3 evidence, not L4**: L4 is a real job in the Orchestrator
folder on a robot. A mocked run reaches **L3 at most**. Never write PASS without the level.

Full detail, the two traps in those commands, and why `validate` is not a superset of the
analyzer: `references/evidence-ladder.md`. **Command names are per-tool and per-version** —
`uip` is a host plus separately-versioned tools. On **rpa-tool 1.204.2** the earlier
`run-file`, `get-analyzer-rules`, `search-templates` and `create-project` are absent, and
`find-activities` moved to `rpa-legacy`. Check `uip tools list` and see
`references/cli-command-map.md`.

## Three decisions to settle before the first publish

All three are painful to change afterwards and none has a default this repo will pick for you.

**The config file format.** Stock is `Config_TST.xlsx` / `Config_PRD.xlsx` — zero Framework
changes, the only zero-migration-risk option. A JSON alternative
(`Config_TST.json` / `Config_PRD.json`) is possible but requires rebuilding
`Framework/InitAllSettings.xaml` itself, since `ReadRange` can't read JSON — this is the one
Framework file allowed to diverge from stock if JSON is chosen, and the same divergence
applies identically to whichever template(s) are fetched. Ask during PDD → SDD, not here —
by scaffolding time the answer should already be in the SDD. See
the `standards` skill, `references/config-format.md`.

**The project name.** The templates ship `"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails
the publishability check on purpose. There are three naming formats live in the estate and no
minuted decision between them — ask the team, then apply the answer to `project.json → name`,
`project.uiproj → Name` and the folder name together. See
the `standards` skill, `references/naming-conventions.md`.

**How the Dispatcher and Performer relate.** There is no working pair in this estate yet, so
a `_Dispatcher`/`_Performer` suffix rule would be an assumption. When a UC first needs both
halves, ask all three parts in one go — how the project names relate, how they are packaged
and published, and what queue name they share — and record the answer.

The queue name is the one that bites silently: `OrchestratorQueueName` must be
**byte-identical** in both projects' `Settings` sheets. A mismatch throws nothing. The
Dispatcher enqueues, the Performer polls a queue that is empty or does not exist, and both
jobs finish green in Orchestrator with no work done.

## References

- `references/generating-the-skeleton.md` — Route A (Studio) and Route B (`uip rpa init`) for
  `Main.xaml` + `Framework/`, what 26.10.1 actually produces, and the deltas against this estate
- `references/evidence-ladder.md` — L1–L4, and why a PASS without a level is not a report
- `references/cli-command-map.md` — the real `uip rpa` command names in 1.204.0, and the
  Studio-IPC vs compiler split
- `references/non-queue-reframework.md` — the three changes a queue-less process needs
- `references/suppressing-a-rule.md` — `validate-project.ignore`, and what a suppression is not for
- `references/fetched-files-crlf.md` — why a fetched template diffs on every text file
- `references/object-repository-and-git.md` — why `.objects/` is **not** git-ignored. It is the
  Object Repository: captured selectors are source. A project was found with 134 files there and
  none tracked, so its clone had workflows and no selectors

## Related skills

- the `standards` skill — where each workflow goes, naming, project layout, error handling
- the `security` skill — wiring the `Assets` sheet rows to real Orchestrator assets
- the `pdd-sdd-scaffolding` skill — turning the SDD into first-draft workflows once the skeleton exists
- `finnova-library`, `avaloq-library` — the activity APIs the Performers call
