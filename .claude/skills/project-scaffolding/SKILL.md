---
name: project-scaffolding
description: Use when starting a new UC project — determines which Dispatcher/Performer template(s) to pull from rpa-ai-skills and fetches just that subfolder, without requiring a full clone of the templates repo. Trigger on "start a new UC project", "scaffold a new automation", "kick off UC<NN>", "which template do I use", "get the REFramework template", or when an SDD names its target application (Finnova, Avaloq, or both) and no project folder exists yet.
---

# Fetching a project template

`templates/` in `rpa-ai-skills` has no `SKILL.md` of its own, so `npx skills add` never brings
it along — that command carries skill folders only, which means **`templates/` is not in your
project** and no path starting with it will resolve there. This skill is the fetch step, wrapped
so it travels like any other skill: install it, and `scripts/fetch-template.*` comes with it.

Read every `templates/<name>/` below as *"the folder the fetch script copies into your project
as `<name>/`"* — the `templates/` prefix names a path in the skills repo and is **not in your
project**. Anything this skill tells you to open is either under this skill (`references/…`,
`scripts/…`) or inside a template you have already fetched.

## Before anything else: preflight

Environment problems cost a real build run more time than the automation logic did. Run this
first; it changes nothing and prints a one-line fix per failure:

```bash
scripts/preflight.sh [<project-dir>]
pwsh -NoProfile -File scripts/preflight.ps1 -ProjectPath <project-dir>
```

It checks Node 22.20+, git and GitHub auth (the skills repo is private), PowerShell 7,
**.NET SDK 8.0**, `uip` and its login, **the official `uipath-rpa` skill**, Studio **and whether
an instance has the project open**, the `UiPath.UIAutomation` 26.10.4 capture pin, that the
Swisscom libraries actually restore from your feed, and a capture smoke test. Pass `-NoProfile`
if you invoke the `.ps1` directly — a slow or prompting PowerShell profile makes it look like it
has hung.

**Two checks reach the tenant, and both are opt-in** — see `AGENTS.md`, *Ask before anything
that authenticates to, or changes, Orchestrator*:

| | |
|---|---|
| `-FolderPath "<folder>"` | runs `uip or folders/processes/assets/queues list`. **Passing the switch is the asking.** Omitted, they are skipped |
| the library-feed check | runs `uip rpa restore`. On Automation Suite the feed is Orchestrator-hosted, so that is an authenticated read — it changes nothing, but it signs in. `-SkipFeedCheck` / `--skip-feed-check` turns it off |

**On the official-skill check.** Every `uip rpa` invocation asks for the `uipath-rpa` skill, and
this estate now routes CLI mechanics there deliberately — the `web` skill carries no `uia`
command table. Where it lands depends on the agent *and* the install route, so the check looks
in every known location rather than one: the `uip skills install` store under
`~/.uipath/.skills/`, the Claude Code marketplace plugin under `~/.claude/plugins/`, each
agent's own global folder in your home directory (Claude Code, Codex, Copilot — both of its
locations — and OpenCode), and each agent's project-level folder when `-ProjectPath` is given.
The script holds the exact list; it is deliberately not duplicated here, because it moves when
an agent changes where it reads from.

It also compares each copy's `targetCli` against the installed host and **warns on a mismatch**.
That is not theoretical: on this machine the Claude Code plugin copy was `skills 1.201.0` /
`targetCli ^1.201.0` against a `1.204.0` host, while the `uip skills install` store was
`1.204.1`. Claude Code loads the plugin copy, so the agent reading those docs was a minor
version behind the tool it was documenting.

Preflight **does not install it** — it changes nothing, by design. Installing is an ask-first
action: ask once, then
`npx skills add https://github.com/uipath/skills --skill uipath-rpa --agent <id> -y` (confirm
`<id>` with `npx skills add --help`), or `uip skills install`.

**On the .NET SDK check.** It is a prerequisite of the **`uip rpa` tool**, not of capture
specifically: the official `uipath-rpa` skill states that `uip rpa` runs against a headless
Studio (`UiPath.Studio.Helm.<Platform>`) *auto-launched by a silent `dotnet restore`* the first
time a command needs one — so `validate`, `build`, `pack`, `analyze`, `restore`,
`activities find` and the `uia` group all sit on it. The `uip` host itself is Node and does not.
Reported as a **warning**, because `uip login` and `uip or …` work without it.

It checks `--list-sdks` **and** `--list-runtimes`, and reports a runtime-only install as its own
case: `dotnet --version` prints a version there while `--list-sdks` is empty, which reads as
"installed" and is not. Fix hint points at the official UiPath CLI installer, which provisions
.NET SDK 8.0 — see the repo README, *Prerequisites*.

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
move them into place as `<name>/`. Nothing else from the repo comes with them — **the rest of
`templates/` is not in your project**, which is why the instantiation checklist ships in this
skill rather than there. Neither script will overwrite an existing folder — that is deliberate,
so a re-run cannot silently discard work in progress. `-d` / `-Destination` sets where they land
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

The template is project-level scaffolding only.

### First: rename the folder off the template's name

Each template lands in a folder named after the **template** — `REFramework-Dispatcher-Base` —
because the fetch script has no other name to use. On the CLI route below that folder *is* the
project (step 1 generates into a scratch folder and you copy `Main.xaml` + `Framework/` **into**
the fetched one), so unless it is renamed deliberately, the finished project ships under the
template's name.

```bash
git mv REFramework-Dispatcher-Base <Project-Name>
```

**This is the one instantiation step with no symptom.** A project whose folder still says
`REFramework-Dispatcher-Base` compiles, packs, publishes and runs exactly like one that was
renamed — nothing downstream forces it, so it survives to review unless someone does it on
purpose. What it costs: a reviewer cannot tell an instantiated project from an untouched
template, and a second UC fetched into the same parent directory collides with it (the fetch
script refuses to overwrite, by design, so the next fetch fails outright).

The name belongs in three places and they must agree: the **folder**, `project.json → name`,
`project.uiproj → Name`. `validate-project` reports the template name on the folder as
`project-folder-not-renamed` (**error**) and a folder/name disagreement as
`folder-name-mismatch`. If the name is not agreed yet, that is the ask in *Three decisions to
settle before the first publish* below — the folder keeps the template's name only for as long
as the question is open, and that is a reported finding, not a resting state.

### Then four more things, in order

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
3. **Work the instantiation checklist** — `references/instantiating-templates.md`. Project name,
   fresh GUIDs, `in_ENV` wired to `Config_<ENV>.xlsx`, every `[UC-SPECIFIC — replace]` in
   `Config_TST.xlsx` *and* `Config_PRD.xlsx`, and the shared queue name.

   It is **not** in the templates repo's `README.md`, which is what this step used to say.
   `scripts/fetch-template.*` sparse-checks-out `templates/<name>/` only, so that README is
   **not in your project** — the step pointed at a file you never received.
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

   **The three sample projects are `targetFramework: Legacy`** — maintainer provenance, not in
   your project: they live under `../Finnova/` and `../Avaloq/`, siblings of the skills repo on a
   maintainer's machine (`modernBehavior: false`, Studio 20.10–21.10). Running this checker on
   them is
   **informational only** — the rules encode the modern estate's contract, which those projects
   predate. Calibrate against the templates and modern UC projects instead, and **never tune a
   rule to lower a Legacy sample's count**. See `README.md`.

   ### The four leaf-workflow-contract rules, and the body rule

   | Rule | Fires when |
   |---|---|
   | `system-workflow-no-config` | an `<App>_System/` workflow declares no `in_Config` |
   | `system-workflow-no-outcome` | an `<App>_System/` workflow declares no `out_`/`io_` argument, so a no-op is indistinguishable from success |
   | `secret-argument-string` | a password/secret/token-named argument is typed `String` rather than `SecureString` |
   | `logic-workflow-no-arguments` | a `Logic/` workflow declares no arguments at all, so callers reimplement the rule inline |

   They are warnings because the rules are new, not because the contract is optional: a scaffold
   that trips them does not meet the `_System` contract in
   `standards/references/project-layout.md`.

   **All four check the *contract*. `leaf-body-stub` checks the *body*.**

   | Rule | Fires when |
   |---|---|
   | `leaf-body-stub` | an `<App>_System/` or `Logic/` workflow's body contains **no activity that does the step** — only logging, only containers, or nothing at all |

   This is the gap the four rules above leave: a file can satisfy every one of them and still be
   a `Log Message` in a `Sequence`. A Framework correctly wired to workflows like that reads its
   transactions, dispatches them, marks them Successful, and performs no work — and it passes
   `validate`, `build`, `analyze`, `pack`, Studio's Error List, and a real Orchestrator job with
   a non-zero transaction count. The official UiPath UIA docs name the same shape: *"That XAML
   compiles, validates, runs — and does nothing. It is the most expensive kind of stub."*

   Deliberately narrow — it fires only when there is **no** substantive activity at all, so a
   workflow with one real activity and ten logs is not reported. Partial work is not its
   business. **A declared mock is carved out**: a workflow under `Mock*/`, or named `Mock-*` /
   `Mock_*`, is *supposed* to do nothing, and the mock layer is `unresolved-mock`'s to report.

   **Calibration on a real modern project** (UC252, `targetFramework: Windows`, 85 workflows,
   63 of them leaf), measured 2026-11-04:

   | | Before the carve-out | After |
   |---|---|---|
   | `leaf-body-stub` | **7** — 6 under `Mock_System/`, 1 real | **1** |
   | `unresolved-mock` | **0** | **26** |

   The one real finding is `Bottomline_System/Bottomline_Logout.xaml`: a logout whose body is a
   `Comment` and a `Log Message`. The six mock findings were the kind of noise that gets a rule
   blanket-suppressed — and that suppression would have hidden the true positive next to them.

   The `unresolved-mock` jump is the other half: that project has **22** workflows under
   `Mock_System/` and **not one** carries the `[MOCK]` string, so the marker-only rule was blind
   to the whole layer and `mocking.md`'s *"a mocked run reaches L3 at most"* cap applied to
   nothing. It now also fires on a declared mock, asking for the marker to be added.

   | Mode | `leaf-body-stub` is |
   |---|---|
   | default (mid-build) | **warning** — a stub body is honest work in progress |
   | `--uat-readiness` / `-UatReadiness` (stage 8) | **error** — shipping a stub to UAT is not a backlog item |

   Keep a `TODO_SELECTOR` on an unresolved *target* and author the real activity around it.
   Replacing the activity with a log is the thing this rule exists to stop.

   ### And `leaf-name-prefix` checks the *name*

   | Rule | Fires when |
   |---|---|
   | `leaf-name-prefix` | a workflow under `<App>_System/` is not named `<App>-…` or `<App>_…` |

   The estate's convention derives the prefix from the folder — `Web_Nav_System/` → `Web_Nav-`,
   `Finnova_System/` → `Finnova-` — so a missing prefix is mechanical, not a judgement call. It
   is also invisible to every other gate: `Web_Nav_System/Login.xaml` compiles, validates,
   analyzes, packs and runs. The cost is that a file name is the only index into a 60-workflow
   project, so a leaf that does not say which application it drives is what sends the next
   developer to the wrong folder — or to writing a second copy of a workflow that already
   exists.

   **Fix it at authoring time.** After a workflow is wired, renaming it also means editing every
   `Invoke Workflow File` that points at it, which is why a wrong name stays wrong. Both
   separators pass and the comparison is case-insensitive; a declared mock is carved out, the
   same way `leaf-body-stub` carves one out. Convention: the `standards` skill,
   `references/naming-conventions.md`.

   **Calibration on modern projects** (`targetFramework: Windows`), measured 2026-10-26 with
   `grep -a`:

   | Project (maintainer provenance — measured here, not in your project) | `no-config` | `no-outcome` | `logic-no-arguments` | `secret-argument-string` |
   |---|---|---|---|---|
   | all three REFramework templates | 0 | 0 | 0 | 0 |
   | Lanes (a real modern UC project) | **6** | **6** | **2** | **1** |

   Zero on the templates, so the rules do not fire on conformant modern scaffolding. The Lanes
   findings, by file — every one a defect the project's own review had already identified:

   - `no-config` (6): `Lanes-Create_Card`, `Lanes-Edit_Card`, `Lanes-Open_Board`,
     `Lanes-Read_Board`, `Lanes-SignIn`, `Lanes-Verify_Session`
   - `no-outcome` (6): `Lanes-Create_Card`, `Lanes-Edit_Card`, `Lanes-Move_Card`,
     `Lanes-Open_Board`, `Lanes-Read_Board`, `Lanes-SignIn`
   - `logic-no-arguments` (2): `Logic-Classify_Exception`, `Logic-Validate_Title`
   - `secret-argument-string` (1): `Lanes-SignIn` — `in_Password` declared `String`

   Calibration — the estate's reference-quality
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
| **L4-local** | The **packed package** runs on the **local UiRobot**, in an Orchestrator folder so the credential asset resolves | `UiRobot execute --file <.nupkg> --folder "<folder>"` |
| **L4** | A **real job on TST** in the Orchestrator folder, on a **robot**, as the robot's own account, with the SDD's expected results checked | `uip or jobs start`, then `jobs get` / `jobs logs` — **ask first** |

Every report names the highest level reached **and the command that proved it**. A wiring or
"project ready" stage is not done below **L3** — L1 and L2 both passed on a project Studio
could not compile. **L2b is separate because `validate` and `build` are not the last
compile-time gate** — a missing assembly reference and `ST-SEC-008` both pass them and fail at
`pack`. **L4-local is the default end-to-end run**, quoted with its folder, and needs no
`uip login`; it is **not** L4, because it runs as your interactive account. **A local
`uip rpa run` is L3 evidence**, being a run of the *sources* in the developer's session. A mocked
run reaches **L3 at most**. Never write PASS without the level.

Full detail, the two traps in those commands, and why `validate` is not a superset of the
analyzer: `references/evidence-ladder.md`. **Command names are per-tool and per-version** —
`uip` is a host plus separately-versioned tools. On **rpa-tool 1.204.2** the earlier
`run-file`, `get-analyzer-rules`, `search-templates`, `create-project` and `find-activities`
are absent — the equivalents are `run --file-path`, `analyzer-rules list`, `templates search`,
`init` and `activities find`. Check `uip tools list` and see
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

- `references/instantiating-templates.md` — the eight-step instantiation checklist, which ships
  with this skill because the fetch script does not deliver the templates repo's own README
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
