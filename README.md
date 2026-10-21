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

The skills' activity references are verified against the older sample pins. The template pins
come from the reference projects and have not been re-checked against the library sources —
see [`AGENTS.md`](AGENTS.md#deployment--review-rules).

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

## Install into a UC project

Run from the root of the UC project.

**Everything:**

```bash
npx skills add ramesh09laksh-boop/rpa-ai-skills --agent claude-code
```

**Only what the project needs:**

```bash
npx skills add ramesh09laksh-boop/rpa-ai-skills --skill finnova-library --skill security --agent claude-code
```

Swap `--agent claude-code` for the agent you use — `--agent copilot`, `--agent codex`, or
`--agent '*'` for all of them.

> **The `owner/repo` prefix is required.** `npx skills add rpa-ai-skills` fails with
> `fatal: repository 'rpa-ai-skills' does not exist` — the CLI resolves a source as
> `owner/repo` or a full URL, never as a bare package name. The full URL form
> (`https://github.com/ramesh09laksh-boop/rpa-ai-skills`) works too.
>
> The repo is **private**, so git must be authenticated — a GitHub sign-in through VS Code, or
> `gh auth login`, is enough. Verified working: all seven skills install, including
> `project-scaffolding` with its fetch scripts intact.

### Available skills

| `--skill` | Use for |
|---|---|
| `standards` | Project layout, where a workflow belongs, naming, error handling, and a reference per application folder (Finnova, Avaloq, SIX iD, CardOne, Web Nav, UBS KeyTrader, Camunda, AI, Mail, File) |
| `project-scaffolding` | Starting a new UC project — picks the right template(s) and fetches just those subfolders out of `templates/` |
| `finnova-library` | Calling `Swisscom.FinnovaLibrary` activities |
| `avaloq-library` | Calling `Swisscom.UiPath.UIAutomation.Avaloq` activities |
| `web` | Any browser-based step; live target capture with the `uip rpa uia` CLI |
| `security` | Credentials, Orchestrator assets, config, never-do list |
| `pdd-sdd-scaffolding` | PDD/SDD (incl. screenshots) → first-draft workflow scaffold; also covers scaffolding while the target application is unavailable |

`standards` routes to the others — take it in every project.

Typical picks:

| Project talks to | Skills |
|---|---|
| Finnova | `standards` `project-scaffolding` `finnova-library` `security` `pdd-sdd-scaffolding` |
| Avaloq | `standards` `project-scaffolding` `avaloq-library` `security` `pdd-sdd-scaffolding` |
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

**The project name is an open question, not a default.** Three formats are live in the estate
and none is minuted; the templates ship `"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails
the publishability check on purpose. Ask the team, then apply the answer —
[`naming-conventions.md`](.claude/skills/standards/references/naming-conventions.md).

## Development lifecycle

Eight stages, each a short prompt you can paste into Claude Code (or any agent with these
skills installed). Every prompt routes to skills that already exist in this repo — none of
them duplicate skill content, they just point the agent at the right ones for that stage.

```
PDD → SDD → Project → Development → Testing → Code Review → UAT Readiness → Deployment Readiness
                                                                                    ↑__________________|
                                                                              Change / Enhancement
```

**One rule holds across every stage, repeated in each prompt below so it survives a lone
copy-paste:** never invent a selector, activity, API, configuration value, credential, or
business rule. Where the source material doesn't say, write it down as a `TODO` / Open
Question instead of a best guess.

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
```

### 2. SDD → Project

```
Load `project-scaffolding`. Given <SDD file>, determine Dispatcher-only, Performer-only, or
both, and fetch the matching template(s). Carry forward the config-format and credential
decisions from the SDD — don't re-ask if they're already recorded there. Ask for the project
name and the shared Orchestrator queue name if not already settled. Work the instantiation
checklist in `templates/README.md` end to end (including rebuilding `InitAllSettings.xaml` in
Studio if the SDD calls for JSON config) and run `validate-project` to zero errors before
calling this stage done.
```

### 3. SDD → Development

```
Load `standards` for where each step belongs, plus the application skill(s) the SDD names —
`finnova-library`, `avaloq-library`, `web`. Use `pdd-sdd-scaffolding` for any screenshot-driven
step, or anything that can't be confirmed against a live application yet. Use modern
activities only — this is a Windows/modernBehavior project, so no classic Excel write
activities and no raw selector outside `Tests/` or Avaloq's `Web_Nav_System/`. Never invent an
activity, API, selector, or config value: mark it `TODO_SELECTOR` / `APPROX_SELECTOR` (per
`pdd-sdd-scaffolding`) or a config `TODO` instead.
```

### 4. Development → Testing

```
Build or extend `Tests/Tests.xlsx` and `Tests/RunAllTests.xaml` — never invoked from
`Process.xaml`. Cover: the happy path for each transaction type in the SDD, every named
Business exception, every Application exception (file/Excel/Finnova/Avaloq/Orchestrator
unavailable), and any edge case the SDD or `standards/references/silent-failure-traps.md`
calls out. Run the suite and report pass/fail per the `Result` sheet — don't claim a test
passed without running it.
```

### 5. Code Review

```
Load `standards`, `security`, and the application skill(s) in use. Validate against
`AGENTS.md` → "Deployment & review rules", `silent-failure-traps.md`,
`naming-conventions.md`, `prohibited-practices.md`, and the SDD's own requirement list — every
requirement should trace to a workflow and a test. Flag findings, don't fix them silently:
raw selectors outside `Tests/`/`Web_Nav_System/`, classic or Legacy-project activity usage,
a secret anywhere, an unresolved `[UC-SPECIFIC — replace]` or `*-selector-todo`, a
config-key or queue-name mismatch between TST and PRD. Do not migrate a Legacy workflow as a
side effect of review — report it as a finding and let the team decide.
```

### 6. UAT Readiness

```
Confirm: every SDD requirement traces to a workflow and a test case; every
`APPROX_SELECTOR` / `TODO_SELECTOR` in every `*.selectors-todo.md` is resolved against the
live application; `Config_TST.xlsx` has no remaining `[UC-SPECIFIC — replace]`;
`validate-project` runs clean (or every suppressed rule has a written reason in
`validate-project.ignore`); `Tests/RunAllTests.xaml` passes. List anything still open as a
named blocker, not a soft caveat.
```

### 7. Deployment Readiness

```
Confirm: `Config_PRD.xlsx` carries the same key set as `Config_TST.xlsx`, with no remaining
`[UC-SPECIFIC — replace]`; every `Assets` row is wired to a real Orchestrator asset in the
right folder (`security` → `orchestrator-assets.md`); the Finnova/Avaloq `.nupkg`s are
published to the feed at the pinned versions; `project.json → name` has no placeholder and no
whitespace, and matches `project.uiproj`; the Dispatcher/Performer pair share one
byte-identical `OrchestratorQueueName`; logging excludes secrets
(`excludedLoggedData`). List anything unresolved as a blocker, not a note.
```

### 8. Change / Enhancement

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

## Definition of Done (UiPath project)

- [ ] Every SDD requirement traces to a workflow and a test case — no silent gaps
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
- [ ] `Tests/RunAllTests.xaml` passes, and nothing under `Tests/` is invoked from `Process.xaml`
- [ ] Every Open Question/Assumption from the SDD is resolved or explicitly still open —
      never silently dropped

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

1. Edit under `.claude/skills/<name>/`. `SKILL.md` is the always-loaded summary; put detail
   in `references/*.md` so it loads only when needed.
2. Keep the frontmatter `description` trigger-shaped — it is the only thing an agent sees
   when deciding whether to load the skill.
3. Cite the estate. Every claim should be traceable to a file under `../Finnova/` or `../Avaloq/`.
   No invented activities, no invented selectors.
4. Opening `rpa-ai-skills` itself in Claude Code or Copilot picks the skills up
   automatically — `.claude/skills/` is auto-discovered, so you can test a change in place.

### If Copilot doesn't pick a skill up

Claude Code and Copilot both auto-discover `.claude/skills/`. If Copilot doesn't surface a
skill for a test prompt (try: *"implement a new Finnova commission workflow"* — it should
reach for `standards` and `finnova-library` before writing code), mirror the tree to
`.github/skills/` **in addition to** `.claude/skills/`, not instead of it. Keep
`.claude/skills/` as the source; a mirror that drifts is worse than no mirror.
