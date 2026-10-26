# rpa-ai-skills

Central agent-skills repo for the UiPath RPA estate (Finnova, Avaloq and the systems around
them). UC projects do **not** carry their own copy of these skills — they pull the ones they
need from here.

- Skills live in [`.claude/skills/`](.claude/skills/).
- Project templates live in [`templates/`](templates/).
- [`AGENTS.md`](AGENTS.md) is the entry point for an agent working *in this repo*.

## Prerequisite: publish the libraries to your feed

> The Finnova/Avaloq `.nupkg`s must already be published to `<your feed>` **before** opening
> or restoring any project that references them. Studio/CLI package restore will fail with an
> unresolved-dependency error otherwise — publish first, then scaffold or open the project.

This bites hardest on a brand-new project: the templates in [`templates/`](templates/) set
`"mustRestoreAllDependencies": true`, so a missing package fails loudly at restore rather than
leaving a project that half-loads and misbehaves later. That is the intended behaviour — fix
the feed, don't relax the flag.

The packages in question:

| Package | Template pin | Also pinned in |
|---|---|---|
| `Swisscom.FinnovaLibrary` | `[2026.1.0]` in `templates/REFramework-Performer-Finnova/` | both Finnova sample processes, at `[4.0.3]` / `[4.0.7]` |
| `Swisscom.PHI` | `[24.10.0]` in both Performer templates | both Finnova sample processes, at `[1.0.7]` |
| `Swisscom.UiPath.UIAutomation.Avaloq` | `[2025.9.1]` in `templates/REFramework-Performer-Avaloq/` | `../Avaloq/TKB-UC11.Kreditverletzung`, at `[2.6.5]` |

The library **sources** live one level above this repo (`../Finnova/Swisscom FinnovaLibrary/`,
`../Avaloq/Swisscom.UiPath.UIAutomation.Avaloq/`); having the source available is not the same as
having the package on the feed, and only the latter makes a restore succeed.

The skills' activity references have been **re-diffed at the argument level against the library
sources** (Finnova `projectVersion 2026.1.0`, Avaloq `2025.9.1` — the versions the template pins
correspond to), by extracting `x:Members` from all 155 workflow `.xaml` files and comparing
name-by-name. The corrections it produced, including one misspelling attributed to the wrong
library and an `Idx`/`idx` casing rule, are listed in
[`AGENTS.md`](AGENTS.md#deployment--review-rules).

One finding is not yet actioned: **the Avaloq library declares higher dependency floors than the
Avaloq Performer template pins**, so a restore resolves a version conflict it was not asked
about. Raise the template pins with the next library bump.

## Start a new project

Three REFramework templates, split by role — see [`templates/`](templates/):

| Template | Role |
|---|---|
| `REFramework-Dispatcher-Base` | Reads the upstream source, filters, enqueues. No banking-library dependency; one skeleton fits every project. |
| `REFramework-Performer-Finnova` | Consumes the shared queue, drives Finnova. |
| `REFramework-Performer-Avaloq` | Consumes the shared queue, drives Avaloq. |

A Dispatcher and its Performer **share one Orchestrator queue**, and a mismatched queue name
throws nothing — both jobs go green and no work is done. Settle the queue name when you
instantiate the pair: [the pairing contract](templates/README.md#the-queue-name-is-a-contract-between-the-pair).
**The project name is an open question, not a default.** Three formats are live in the estate
and none is minuted; the templates ship `"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails
the publishability check on purpose. Ask the team, then apply the answer —
[`naming-conventions.md`](.claude/skills/standards/references/naming-conventions.md).

## Install and update

Run from the root of the UC project. Needs **Node.js 22.20 or newer** (verified on v22.21.1).

The `--agent` value is the CLI's own agent id, not the product name you'd say out loud. The
ones this estate uses:

| Agent | `--agent` id |
|---|---|
| Claude Code | `claude-code` |
| GitHub Copilot | `github-copilot` |
| Codex | `codex` |
| OpenCode | `opencode` |
| every agent the CLI detects | `'*'` |

`--agent copilot` is **not** valid and fails with `Invalid agents: copilot`. The CLI prints its
full id list in that error, so `npx skills add <repo> --agent x -y` is the quickest way to
check an id you're unsure of.

```bash
# See what's in the repo without installing
npx skills add ramesh09laksh-boop/rpa-ai-skills --list

# Install everything, for the agents you actually use
npx skills add ramesh09laksh-boop/rpa-ai-skills \
  --agent claude-code --agent github-copilot --agent opencode

# Install only what the UC needs
npx skills add ramesh09laksh-boop/rpa-ai-skills \
  --skill uc-delivery --skill standards --skill project-scaffolding \
  --skill finnova-library --skill security --agent github-copilot
```

Keeping an installed set current:

```bash
npx skills list            # what is installed, and for which agents
npx skills check           # which installed skills have updates
npx skills update          # update all; name skills to limit it
                           #   -p project scope, -g global, -y skip the scope prompt
npx skills remove <skill> --agent <id>
```

> **The `owner/repo` prefix is required.** `npx skills add rpa-ai-skills` fails with
> `fatal: repository 'rpa-ai-skills' does not exist` — the CLI resolves a source as
> `owner/repo` or a full URL, never as a bare package name. The full URL form
> (`https://github.com/ramesh09laksh-boop/rpa-ai-skills`) works too.
>
> **The repo is private, so git must be authenticated for `add` *and* `update`.** A GitHub
> sign-in through VS Code, or `gh auth login`, is enough. A silent "nothing to update" on a
> machine that was never signed in is an auth failure, not an up-to-date install.
>
> **`update` pulls the current `main`.** Whatever is on `main` is what every UC project gets on
> its next update, so merge to `main` only once the change meets the Definition of Done below.
>
> **Let the CLI place the files.** Do not hand-copy a skill folder into `.claude/skills/` or
> `.github/skills/` in a UC project — a hand-placed copy is invisible to
> `skills list` / `check` / `update` and drifts silently.

### Where the files land

The CLI installs into the *agent's own* folder, and that folder differs per agent. Verified
with the current CLI (`skills@latest`, probe install into an empty repo):

| Install | Where the content actually lives |
|---|---|
| `--agent claude-code` alone | `.claude/skills/<skill>/` |
| `--agent github-copilot` / `codex` / `opencode` | `.agents/skills/<skill>/` (shared by all three) |
| **two or more agents together** | `.agents/skills/<skill>/`, with `.claude/skills/<skill>` as a **symlink** into it |

That last row is the common case and the one that surprises people: ask for Claude Code *and*
Copilot and the files are in `.agents/skills/`, with `.claude/skills/` pointing at them. Commit
both — a checkout that has the symlinks without their target has no skills at all.

Older CLI versions wrote Copilot skills to `.github/skills/` instead. **Check which one your
version actually wrote** — the install output prints the full target path, and
`npx skills list` prints it again per skill. A `skills-lock.json` is written at the project
root; commit it.

Because the install folder is agent-dependent, skill content must never hard-code
`.claude/skills/…`. Cross-skill references inside a skill name the skill
(*"the `standards` skill, `references/systems/finnova-system.md`"*) or use a path relative to
the skill's own folder (`scripts/…`, `assets/…`).

### Available skills

| `--skill` | Use for |
|---|---|
| `uc-delivery` | **Start here.** The front door: runs preflight, drives the ten stages with a gate on each, asks the decisions one at a time, and routes to the skill that owns each piece |
| `standards` | Project layout, where a workflow belongs, naming, error handling, and a reference per application folder (Finnova, Avaloq, SIX iD, CardOne, Web Nav, UBS KeyTrader, Camunda, AI, Mail, File) |
| `project-scaffolding` | Starting a new UC project — picks the right template(s) and fetches just those subfolders out of `templates/` |
| `finnova-library` | Calling `Swisscom.FinnovaLibrary` activities |
| `avaloq-library` | Calling `Swisscom.UiPath.UIAutomation.Avaloq` activities |
| `web` | Any browser-based step; live target capture with the `uip rpa uia` CLI |
| `security` | Credentials, Orchestrator assets, config, never-do list |
| `pdd-sdd-scaffolding` | PDD/SDD (incl. screenshots) → first-draft workflow scaffold; also covers scaffolding while the target application is unavailable |

`uc-delivery` is the one to install if you install only one — it routes to everything else.
`standards` routes to the application skills, so take it in every project too.

Typical picks:

| Project talks to | Skills |
|---|---|
| Finnova | `uc-delivery` `standards` `project-scaffolding` `finnova-library` `security` `pdd-sdd-scaffolding` |
| Avaloq | `uc-delivery` `standards` `project-scaffolding` `avaloq-library` `security` `pdd-sdd-scaffolding` |
| …plus any web portal (SIX iD, CardOne) | add `web` |

### `templates/` does not travel with `npx skills add`

That command carries `.claude/skills/` folders only, and `templates/` has no `SKILL.md` of its
own — so a UC project that installs the skills still has no template. That is what
`project-scaffolding` is for: it ships `scripts/fetch-template.sh` and a `.ps1` twin that
sparse-checkout just the matched `templates/<name>/` subfolder(s), so the fetch step travels
like any other skill.

The scripts need no setup — they default to `https://github.com/ramesh09laksh-boop/rpa-ai-skills`:

```bash
scripts/fetch-template.sh REFramework-Dispatcher-Base REFramework-Performer-Finnova
```

Working from a fork or an internal mirror? Override per invocation with `-r` / `-RepoUrl`, or
once per developer with `$RPA_SKILLS_REPO`. Precedence is flag > env var > default, and each
run prints which one it used.

### Put this in your project kickoff checklist

Pulling the right skills should not be something each developer remembers unprompted. Add
the `npx skills add` line to whatever scaffolding/kickoff checklist new UC projects already
follow, next to "create the repo" and "wire up Orchestrator".

## Not a UiPath specialist? Start here

One prompt. `uc-delivery` runs preflight, works the stages in order, asks you the decisions one
at a time in plain language, and tells you exactly what it needs at each point that needs a
person:

```
Load `uc-delivery`. Build the UiPath project for <PDD file>. Run preflight, ask me the
decisions one at a time in plain language, and tell me exactly what you need from me at each
Studio checkpoint.
```

To pick a half-finished project back up:

```
Load `uc-delivery`. Read Documentation/Progress.md and continue from "next".
```

It will not touch PRD, will not use real customer data, and will never ask you to paste a
credential into the chat.

## Official UiPath skills — how they coexist

Teams install UiPath's own skills alongside these (`npx skills add UiPath/skills --list` to see
what is available; `uipath-rpa` is the one the `uip rpa` CLI itself asks for on every
invocation). Both sets load, and they overlap.

**Precedence, decided here:**

| Owned by **this repo** | Owned by the **official** skills |
|---|---|
| Project creation and the estate's conventions | Generic activity authoring |
| Finnova / Avaloq UI automation | The `uip` CLI surface |
| REFramework structure and wiring | Orchestrator operations |
| This estate's testing and review rules | Platform features generally |

When the two disagree, **follow the estate and note the conflict in
`Documentation/Progress.md`** — so it gets settled once rather than re-decided per project.

## Development lifecycle

**Ten stages**, each a short prompt you can paste into Claude Code (or any agent with these
skills installed). Every prompt routes to skills that already exist in this repo — none of them
duplicate skill content, they just point the agent at the right ones for that stage.

```
PDD → SDD → Project → Wire → Capture → Develop → Test → Review → UAT → Deploy
                                                                          ↑________|
                                                                    Change / Enhancement
```

Two stages are new, and both were missing for the same reason — they are the work *between*
"the project exists" and "the workflows are written":

- **Wire** — connecting the SDD's transactions to the Framework. Skipping it produces a project
  with good leaf workflows that runs green and processes **zero** transactions.
- **Capture** — resolving every `TODO_SELECTOR` against the live application with `uip rpa uia`.

### Working rules — paste this at the top of any stage prompt

The old claim that the no-inventing rule was "repeated in each prompt below" was only true of
stages 1 and 3. Rather than repeat it unreliably, it lives here as one block to paste:

```
Working rules: never invent a selector, activity, argument, API, config value, credential or
business rule — if the source is silent it is an Open Question / TODO. Report the highest
check level reached, with the command used: L1 validate-project, L2 uip rpa validate+build,
L2b uip rpa pack, L3 Studio Error List clean, L4 a real job on TST in the Orchestrator folder
on a robot with the SDD acceptance table. A local run or a mocked run is L3 at most, never L4.
"Needs Studio" only with the exact command and its error. Commit locally after each item; keep
Documentation/Progress.md updated. Do not stop between items — log a blocker and continue with
the next.
```

### 1. PDD → SDD

```
Load `standards` for project/application conventions and `security` for the credential and
config vocabulary. Read <PDD file> and produce a complete SDD: business context, process
flow, Dispatcher/Performer split (if any), queue design, config keys (Settings/Constants/
Assets, for both TST and PRD), exception handling (Business vs Application), test strategy,
and the Orchestrator assets required. Ask two decisions up front and record the answers in
the SDD: (1) config file format — stock `Config_<ENV>.xlsx`, or JSON (`Config_<ENV>.json`,
which requires rebuilding `InitAllSettings.xaml` — see `standards/references/config-format.md`);
(2) credentials — Orchestrator Credential asset, CyberArk PHI vault, or both (see `security`).
Add an Open Questions / Assumptions section for anything else the PDD doesn't state. Do not
invent a business rule, a credential name, a selector, or a config value — if the PDD is
silent, it's an Open Question, not a guess.

Also record whether the process has an Orchestrator queue, and whether it is
Dispatcher+Performer, Performer-only, or a single self-contained run. Define every transaction
type and the work-item columns each one uses — do not leave them to the test data.
```

### 2. SDD → Project

```
Load `project-scaffolding`. Given <SDD file>, choose Dispatcher-only / Performer-only / both and
fetch the matching template(s). Carry forward the config-format and credential decisions from
the SDD — don't re-ask if they're already recorded there. Ask only for the project name and the
shared Orchestrator queue name if unsettled. Generate Main.xaml + Framework via the CLI route
(scratch folder, `--help` first, `--template-package-version` matching the config-format
decision), apply the template README deltas, work the instantiation checklist in
`templates/README.md`, then run `validate-project`, `uip rpa validate` per entry point, and
`uip rpa build`. This stage is done at L3 — Studio opens the project with an empty Error List.
```

### 3. Wire the Framework

```
Load `standards` (wiring-the-framework) and `security`. Wire the Framework from <SDD>, in
order: Config, GetTransactionData, InitAllApplications, Process dispatch, SetTransactionStatus,
CloseAllApplications. Author the XAML with the CLI (`uip rpa activities get-default-xaml`,
`uip rpa activities find`). If a configured source yields 0 transactions, fail loudly.
Credentials from the Orchestrator asset only. Transaction types come from the SDD; if it is
silent, record an Assumption and ask. Leaf workflows must follow the `_System` contract —
in_Config, an out_ outcome, SecureString secrets. Report which Framework files are wired and the
level reached.
```

### 4. Capture targets (browser apps)

```
Load `web`. First read project.json: UiPath.UIAutomation.Activities and UiPath.UIAutomation.CLI
must both be 26.10.4 — fix and restore before anything else. Capture targets for the workflows
listed in the *.selectors-todo.md files, 2–3 screens per run, following
`web/references/capture-troubleshooting.md`. After any page navigation: navigate explicitly,
fresh snapshot, fresh work folder. `evaluate` must match only the target — if not, leave
TODO_SELECTOR and record why. Identify list items by business key, never position. Commit
`.objects/` — it holds the captured selectors. Update each todo file and Progress.md.
```

### 5. Develop leaf workflows

```
Load `standards` for where each step belongs, plus the application skill(s) the SDD names —
`finnova-library`, `avaloq-library`, `web`. Use `pdd-sdd-scaffolding` for any screenshot-driven
step, or anything that can't be confirmed against a live application yet. Use modern
activities only — this is a Windows/modernBehavior project, so no classic Excel write
activities and no raw selector outside `Tests/` or Avaloq's `Web_Nav_System/`. Never invent an
activity, API, selector, or config value: mark it `TODO_SELECTOR` / `APPROX_SELECTOR` (per
`pdd-sdd-scaffolding`) or a config `TODO` instead.
```

### 6. Test data → tests

```
Load `standards` (test-data) and `security`. Read <TestData.xlsx> and <SDD>. Map the Config
sheet onto Settings/Constants/Assets in BOTH Config_TST.xlsx and Config_PRD.xlsx; any row whose
provenance is not "Observed" stays [UC-SPECIFIC — replace] and goes to Open Questions. Build
Tests/Tests.xlsx from TestCases + NegativeData per the template schema — NegativeData rows
become Business-exception tests asserting a correct refusal. Cover the happy path for each
transaction type in the SDD, every named Business exception, every Application exception
(file/Excel/Finnova/Avaloq/Orchestrator unavailable), and any edge case
`standards/references/silent-failure-traps.md` calls out. Replace fixed dates with today ± N.
Carry over "To verify"/BLOCKED statuses and do not mark a case passed without running it.
`Tests/RunAllTests.xaml` is never invoked from `Process.xaml`. If work items depend on each
other, describe the ordering risk and ask before choosing. Never copy a credential from a
fixture file.
```

### 7. Review

```
Load `standards`, `security`, and the application skill(s) in use. Validate against
`AGENTS.md` → "Deployment & review rules", `silent-failure-traps.md`,
`naming-conventions.md`, `prohibited-practices.md`, and the SDD's own requirement list — every
requirement should trace to a workflow and a test. Flag findings, don't fix them silently:
raw selectors outside `Tests/`/`Web_Nav_System/`, classic or Legacy-project activity usage,
a secret anywhere, an unresolved `[UC-SPECIFIC — replace]` or `*-selector-todo`, a
config-key or queue-name mismatch between TST and PRD. Do not migrate a Legacy workflow as a
side effect of review — report it as a finding and let the team decide.

Run the Workflow Analyzer and report its findings too:
`uip rpa analyze <project> --governance-file-path "<ABSOLUTE path to the rule file>"
--governance-file-type Studio --detailed-log-path <log>`, and
`uip rpa analyzer-rules list --project-dir <project>` to confirm the rule set loaded. The path
must be absolute and the file type must be `Studio`, or the file is ignored or crashes the run;
a tenant policy also silently outranks it. Cross-check the ids your file enables against the ids
that actually load — see `standards/references/code-quality.md`. Fix findings; do not relax a
rule to pass.
```

### 8. UAT Readiness

```
Confirm: every SDD requirement traces to a workflow and a test case; every
`APPROX_SELECTOR` / `TODO_SELECTOR` in every `*.selectors-todo.md` is resolved against the
live application; `Config_TST.xlsx` has no remaining `[UC-SPECIFIC — replace]`;
`validate-project` runs clean (or every suppressed rule has a written reason in
`validate-project.ignore`); `Tests/RunAllTests.xaml` passes. Additionally require **L4** on the
evidence ladder — a real run of `Main.xaml` on TST, with a log excerpt — and a clean
`uip rpa analyze` result, naming which rule set ran. List anything still open as a named
blocker, not a soft caveat.
```

### 9. Deployment Readiness

```
Load `standards` (deployment) and `security`. Pack, publish to TST, and confirm the process,
queue, assets and trigger exist in the right Orchestrator folder — use the official UiPath
platform skill for the Orchestrator mechanics. TST first; PRD only with named, explicit
approval for this release, and the first PRD run is watched with a known rollback.

Confirm: `Config_PRD.xlsx` carries the same key set as `Config_TST.xlsx`, with no remaining
`[UC-SPECIFIC — replace]`; every `Assets` row is wired to a real Orchestrator asset in the
right folder (`security` → `orchestrator-assets.md`); the Finnova/Avaloq `.nupkg`s are
published to the feed at the pinned versions; `project.json → name` has no placeholder and no
whitespace, and matches `project.uiproj`; the Dispatcher/Performer pair share one
byte-identical `OrchestratorQueueName`; logging excludes secrets
(`excludedLoggedData`). List anything unresolved as a blocker, not a note.
```

### 10. Change / Enhancement

```
Read the existing project and the change request together. Load `standards` and the
application skill(s) the project already uses — match its existing conventions; don't
introduce a second credential mechanism or a new folder pattern without asking. Identify
every workflow, config key, and test the change touches, and update `Tests/Tests.xlsx` and
both `Config_TST.xlsx`/`Config_PRD.xlsx` together if config changes. Don't migrate an
existing Legacy or classic-activity workflow as a side effect — flag it, don't touch it,
unless the change explicitly asks for that migration. Re-run `validate-project` and the test
suite before calling the change done.
```

## How much "validated" is worth — the evidence ladder

`validate-project` is a static checker. It reads text and workbook cells; it compiles nothing
and runs nothing. On the Lanes run it reported PASS, and `uip rpa build` reported Success, while
Studio showed a compile error in `Framework/InitAllSettings.xaml` and every workflow run failed
with *"The workflow cannot be found"*.

So "validated" on its own is not a claim. Name the level and the command:

| Level | What it establishes | Command |
|---|---|---|
| **L1** | Estate conformance (static) | `validate-project.sh` / `.ps1` |
| **L2** | Compiles and passes the analyzer | `uip rpa validate --min-severity error`, then `uip rpa build` |
| **L2b** | **Packs** — survives the UiRobot packaging step | `uip rpa pack <project> --output-path <dir>` |
| **L3** | Studio opens it with an **empty Error List** | Studio |
| **L4** | A **real job on TST** in the Orchestrator folder, on a robot, with the SDD's expected results checked | `uip or jobs start`, then `jobs get` / `jobs logs` |

A wiring or "project ready" stage is **not done below L3**. "Tested" means **L4** — a real job
started in the Orchestrator folder on a robot, with job state, logs and the SDD acceptance table.
**A local run of `Main.xaml` is L3 evidence, not L4**, and a **mocked** run reaches L3 at most.
L2b is a rung of its own because a missing assembly reference and `ST-SEC-008` both pass
`validate` and `build` and fail only at `pack`. Detail:
[`evidence-ladder.md`](.claude/skills/project-scaffolding/references/evidence-ladder.md);
procedure: [`end-to-end-run.md`](.claude/skills/standards/references/end-to-end-run.md).

## Definition of Done (UiPath project)

- [ ] Every SDD requirement traces to a workflow and a test case — no silent gaps
- [ ] **L3 reached at minimum** — Studio opens the project with an empty Error List — and the
      report names the level and the command that proved it
- [ ] No raw Finnova/Avaloq selector outside `Tests/` (and Avaloq's `Web_Nav_System/`)
- [ ] No classic/Legacy activity on a Windows (`modernBehavior: true`) project — see
      `standards/references/silent-failure-traps.md`
- [ ] No secret in a `.xaml`, config sheet, log, exception message, mail, screenshot, or commit
- [ ] `Config_TST.xlsx` and `Config_PRD.xlsx` carry the same key set, with no
      `[UC-SPECIFIC — replace]` remaining
- [ ] `project.json → name` has no placeholder, no whitespace, and matches `project.uiproj`
- [ ] A Dispatcher/Performer pair share one byte-identical `OrchestratorQueueName`
- [ ] Every `APPROX_SELECTOR` / `TODO_SELECTOR` resolved against the live application
- [ ] `validate-project` runs with zero errors, or every suppressed rule has a written reason
- [ ] `uip rpa analyze` runs clean, the report names **which rule set ran**, and no finding was
      cleared by disabling a rule — see
      [`code-quality.md`](.claude/skills/standards/references/code-quality.md)
- [ ] `Tests/RunAllTests.xaml` passes, and nothing under `Tests/` is invoked from `Process.xaml`
- [ ] Every Open Question/Assumption from the SDD is resolved or explicitly still open —
      never silently dropped
- [ ] The Framework is **wired** — `GetTransactionData` yields real transactions, `Process.xaml`
      dispatches on the SDD's transaction types, and a configured source yielding 0 transactions
      fails loudly rather than finishing green
- [ ] Every `_System` workflow meets the contract — `in_Config` in, an `out_` outcome back,
      secrets as `SecureString` — and no `logic-workflow-no-arguments` warning remains
- [ ] `.objects/` is **committed** if the project captured any selectors; a clone resolves every
      target

## Why the library and sample projects are still kept

They sit **one level above this repo**, as siblings of `rpa-ai-skills/`:

| Sibling | What it is |
|---|---|
| `../Finnova/`, `../Avaloq/` | Two UiPath library projects and three real UC processes |
| `../REFramework-Dispatcher-Base/`, `../REFramework-Performer-Avaloq/`, `../REFramework-Performer-Finnova/` | Three reference projects — real Studio 23.10 Windows REFramework skeletons |

`../Finnova/` and `../Avaloq/` are the **source-of-truth evidence the skills were derived
from** — the skills cite real activity signatures, real workflow sequences and real bugs from
these specific projects. When a library is upgraded, having the source to hand is what makes it
possible to regenerate or verify the affected skill content against ground truth.

The three `../REFramework-*/` projects are the **ground truth for the templates' project
metadata**. `templates/*/project.json`, `project.uiproj` and `entry-points.json` were taken from
them rather than hand-written, which is why the templates target Windows on Studio 23.10.8.0.

None of them is a template — [`templates/`](templates/) is. A new UC project starts from a
template, pulls `.claude/skills/`, and implements fresh against the library's own activities;
it does not clone the sample workflow files.

## Maintaining a skill

**Before merging to `main`, run the checks** — `main` is what every UC project pulls on its next
`npx skills update`:

```bash
pwsh -NoProfile -File .claude/skills/project-scaffolding/scripts/lint-skills.ps1
pwsh -NoProfile -File .claude/skills/project-scaffolding/scripts/validate-project.ps1   templates/REFramework-Dispatcher-Base templates/REFramework-Performer-Finnova   templates/REFramework-Performer-Avaloq -TemplateMode
```

Both run in CI ([`.github/workflows/checks.yml`](.github/workflows/checks.yml)) alongside
`bash -n` on every shipped script and a check that the template workbooks still regenerate.

Then work [`evals/trigger-prompts.md`](evals/trigger-prompts.md) — a skill that does not load is
a skill that does not exist, and trigger reliability is what a user actually experiences. Record
the result, update [`CHANGELOG.md`](CHANGELOG.md), and tag the release.

1. Edit under `.claude/skills/<name>/`. `SKILL.md` is the always-loaded summary; put detail
   in `references/*.md` so it loads only when needed.
2. Keep the frontmatter `description` trigger-shaped — it is the only thing an agent sees
   when deciding whether to load the skill.
3. Cite the estate. Every claim should be traceable to a file under `../Finnova/` or `../Avaloq/`.
   No invented activities, no invented selectors.
4. Opening `rpa-ai-skills` itself in Claude Code or Copilot picks the skills up
   automatically — `.claude/skills/` is auto-discovered, so you can test a change in place.

### If Copilot doesn't pick a skill up when you open *this* repo

This applies to working **inside `rpa-ai-skills` itself**, where the skills are discovered from
the committed `.claude/skills/` tree rather than installed. In a UC project, use
`npx skills add --agent github-copilot` and let the CLI place the files — a hand-made mirror
there is the wrong fix.

Claude Code auto-discovers `.claude/skills/`. If Copilot doesn't surface a skill for a test
prompt (try: *"implement a new Finnova commission workflow"* — it should reach for `standards`
and `finnova-library` before writing code), mirror the tree into whichever folder your Copilot
version reads, **in addition to** `.claude/skills/`, not instead of it. Which folder that is
depends on the version — `.github/skills/` on older ones, `.agents/skills/` on newer; run a
throwaway `npx skills add … --agent github-copilot` in a scratch directory and copy whatever
path it prints. Keep `.claude/skills/` as the source; a mirror that drifts is worse than no
mirror.
