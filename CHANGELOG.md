# Changelog

`npx skills update` pulls whatever is on `main`, so every merge to `main` reaches every UC
project on its next update. This file is how someone decides whether to run that command today.

Tag each release (`git tag -a v<x.y> -m ...`) so a project can pin or roll back.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Dates are ISO.

## [Unreleased] — v0.2.1 draft

Not tagged. Branch `chore/post-release-0.2.1`, PR #3.

### Added

- **Platform stated: Automation Suite, not Automation Cloud.** The skills never said which
  platform this estate runs on, so an agent had no way to know and would default to Cloud
  assumptions. `decisions.md` §0, plus an **Environment** block template in `uc-delivery` for
  each project's own `AGENTS.md` (platform, Orchestrator host, tenant, folder path, robot machine
  and Windows account, package feed, TST vs production) — **non-secret facts only**.
- **`standards/references/end-to-end-run.md`** — the L4 procedure: robot prerequisites, pack →
  publish → confirm the folder → start the job → read state, logs and queue results, and the
  **SDD acceptance table**. Five of the six robot prerequisites are marked **unverified from a
  developer machine** rather than presented as checks.
- **`standards/references/mocking.md`** — mark a stand-in `[MOCK]` in both the DisplayName and
  the annotation; what may and may not be mocked; a mocked run reaches **L3 at most**.
- **Wiring-review table** in `wiring-the-framework.md` — where to look and what wrong looks like,
  per Framework file, plus the two cross-file counts no single file reveals.
- **`config-key-undefined`** validate-project rule (error) — a workflow reading a config key no
  sheet defines gets `Nothing` and continues with an empty value.
- **`unresolved-mock`** validate-project rule (warning).
- **`preflight -FolderPath`** — the scriptable part of L4 readiness (folder, process, assets,
  queue), with the robot-side prerequisites reported as `SKIP`.
- **README lifecycle stage 7b — end-to-end run in the Orchestrator folder.**
- **How the client secret is supplied**, in `end-to-end-run.md` and `decisions.md`: by
  environment-variable reference only (`--client-secret env.UIPATH_CLIENT_SECRET`), never inline,
  never in a file, never pasted into a chat. An agent must not ask for it or accept it if offered.

### Changed

- **Reverted the leaf-contract rule tuning, and documented why.** The three sample projects
  (UC39, UC81, TKB-UC11) are **`targetFramework: Legacy`**, `modernBehavior: false`, Studio
  20.10–21.10 — verified from `project.json`. They are evidence, not conformance targets, so
  tuning rules to lower their finding counts was the wrong move and is undone.

  `validate-project` on a Legacy sample is now documented as **informational only**, and
  "never tune a rule to lower their counts" is written into `README.md`. Calibration is against
  modern projects: the three templates report **zero** leaf-contract findings; the Lanes project
  (Windows/modern) reports 6 + 6 + 2, which are the defects the original review identified.

  Two of the three reverted carve-outs would have suppressed genuine findings on Lanes.

- **Evidence ladder gains L2b (pack) and L4 is redefined.** `validate` and `build` are not the
  last compile-time gate — a missing assembly reference and `ST-SEC-008` pass both and fail at
  `pack`. L4 is now a **real job in the Orchestrator folder, on a robot**, with job state, logs
  and the SDD acceptance table; a local `uip rpa run` is **L3 evidence**, and a **mocked** run is
  L3 at most. Propagated to all five places that state the ladder and both Working-rules blocks.
- **`uc-delivery` explains the preflight result states**, because `SKIP` was being read as a
  pass. A `SKIP` is *not checked at all* and is an open item a person must verify; "0 blocking"
  does not mean the environment is good.

### Fixed

- **Re-ran every "0 findings" claim binary-safely.** Method: `grep -a` (or structured
  `--output json`) plus the exit code, on all seven real projects and the three templates.
  Plain `grep` suppresses matches when it decides a stream is binary, which non-ASCII project
  names trigger.

  | Claim | Re-measured | Verdict |
  |---|---|---|
  | UC39 reports **zero** leaf-contract findings | 47 before tuning, 23 after | **Was false** — already corrected |
  | **0** `secret-argument-string` anywhere | **1 on Lanes** — `Lanes-SignIn.xaml` declares `in_Password` as `String` | **Was overstated.** The sweep covered only the three Legacy samples and was generalised to "anywhere". The finding is a **true positive** — the exact defect the original review raised |
  | `config-key-undefined` 0 on all real projects | 0 on all seven | Holds |
  | `unresolved-mock` 0 on all real projects | 0 on all seven | Holds |
  | `object-repository-not-shared` silent on templates and reference projects | 0 on all six | Holds |
  | Templates 0 leaf-contract findings | 0/0/0 on all three | Holds |
  | Analyzer: 0 findings with `Default`, 1 with TAU | unchanged | Holds — was measured with `--output-filter`, not `grep` |

  The binary-safe counting rule is now in `AGENTS.md` → *Working agreement for long runs*.

Two defects shipped in v0.2.0, both in `preflight.ps1`, both found by testing rather than review:

- **`$deps.'UiPath.UIAutomation.CLI'` threw under `Set-StrictMode`** on any project without that
  dependency — which is most of them. Absent properties throw rather than returning `$null`; now
  read via `PSObject.Properties`.
- **The capture-pin check keyed on `Activities`**, so the Dispatcher template (Activities
  `23.10.13`, no CLI, never captures selectors) reported a **blocking** failure. `uip rpa uia`
  needs the CLI package, so the skip now keys on that.

And one in the CI added in v0.2.0:

- **The workbooks job compared with `git status --porcelain`**, which is line-ending-sensitive;
  the generator writes the platform newline, so on a Linux runner it reported three
  `config-contents.md` files as modified while `git diff` printed **nothing**. Both of the
  workflow's first two runs failed this way. Now `git diff --exit-code --ignore-cr-at-eol`.

### Still open — unchanged from v0.2.0, awaiting a decision

The analyzer rule file, the Avaloq dependency pins, capture-pin-vs-template-pin, and the worked
example are deliberately untouched. See *Known open* below.

### Upgrading from v0.1.x

1. Run `validate-project` — new rules mean new findings on a project that was clean before.
2. If `object-repository-not-shared` fires, remove `.objects/` from the **project's own**
   `.gitignore`; `npx skills update` cannot do it for you.
3. **Before committing `.objects/`, scan the `.content` files for credentials, email addresses,
   customer numbers and tokens, and check `.images/` for screenshots of a logged-in session.**
   Descriptors are captured from a live application and record what was on screen. Re-capture
   against throwaway data rather than hand-editing. Full text: `README.md` → *Upgrading from
   v0.1.x*.

## [v0.2.0] - 2026-10-26

### Added

- **`uc-delivery` skill** — a front door. Runs preflight, drives the ten delivery stages with a
  check gate on each, asks the open decisions one at a time, pauses properly at human
  checkpoints, and routes to the skill that owns each piece. Install this one first.
- **Evidence ladder (L1–L4)** — `validate-project` PASS is L1 of 4, and a report must name the
  level and the command that proved it. In `project-scaffolding`, `README.md` and `AGENTS.md`.
- **Wiring stage** — `standards/references/wiring-the-framework.md`. Connecting the SDD's
  transactions to the Framework was an undocumented gap between "project scaffolded" and
  "workflows written", and skipping it produces a job that runs green on zero transactions.
- **Workflow Analyzer gate** — `standards/references/code-quality.md`, with the four ways a
  governance rule file is silently not applied. Required at Code Review and UAT.
- **Preflight** — `project-scaffolding/scripts/preflight.{ps1,sh}`. Read-only; a one-line fix
  per failure.
- **Skill lint** — `project-scaffolding/scripts/lint-skills.ps1`, plus GitHub Actions running
  it, `validate-project -TemplateMode`, `bash -n` on every shipped script, and a check that the
  template workbooks still regenerate.
- **Layman-facing references** in `standards`: `decisions.md` (options, consequences, a default
  marked *recommended, not decided*, and who confirms), `studio-checkpoints.md` (what only a
  person can do, and what to paste back), `troubleshooting.md` (symptom → cause → fix),
  `test-data.md` (ingesting a business test-data workbook).
- **CLI route for the REFramework skeleton** — `uip rpa init`, with the deltas the generated
  26.10.1 skeleton needs to match this estate.
- **`web/references/capture-troubleshooting.md`** — the 26.10.4 version precheck, the stale-URL
  fix after a client-side redirect, and the per-screen work-folder protocol.
- **Official UiPath skills** — stated precedence when both sets are installed.
- **`.gitattributes`** — `*.sh text eol=lf`, so a shipped script survives a Windows checkout.
- **`evals/trigger-prompts.md`** — ~10 trigger prompts per skill plus cross-cutting checks, run
  by hand before each release.

### Changed

- **`.objects/` is no longer git-ignored.** It holds the Object Repository — captured selectors
  are source. See *Fixed*.
- **Lifecycle is ten stages**, adding **Wire** and **Capture**; `README.md` prompts rewritten
  with one shared "Working rules" block instead of a claim that the rule was repeated in each.
- **Library activity references re-diffed** against the library sources (Finnova
  `projectVersion 2026.1.0`, Avaloq `2025.9.1`) at the argument level. The "outstanding work"
  caveat is replaced by the specific findings.
- **`pdd-sdd-scaffolding` scaffold shape** now requires the `_System` contract explicitly.
- `project-scaffolding/SKILL.md` slimmed, detail moved into `references/`.
- `web` description widened to any browser-based application, including single-page apps.

### Fixed

- **`.objects/` was git-ignored, losing captured selectors.** A real project had 134 files there
  and **zero tracked** — a clone got the workflows and resolved every target to nothing.
  Removed from all four `.gitignore` files; new `validate-project` rule
  `object-repository-not-shared` (error).
- **`--agent copilot` is not a valid CLI id** — it is `github-copilot`. The documented command
  failed outright.
- **67 hard-coded `.claude/skills/` paths across 31 files inside the skills.** The CLI installs
  into the agent's own folder, so these resolved to nothing for Copilot, Codex and OpenCode and
  cross-skill loading silently failed. Now zero, enforced by the lint.
- **`ConfitmMessage` was documented as a Finnova misspelling.** It does not exist in the Finnova
  library — it is Avaloq's.
- **`Idx` vs `idx` casing** was documented as `Idx` throughout; it is lowercase in all 12
  `Table/*` + `Tree/ExtractTree` workflows and capital in the 36 top-level ones.
- **`Table/Get Cell Attribute`** was documented with an `ExtractDataTable` argument it does not
  have, and without its real `Attribute` / `Value` pair.
- **Documented `uip rpa` commands that do not exist** in 1.204.0 (`run-file`,
  `get-analyzer-rules`, `search-templates`, `create-project`, `find-activities`,
  `get-default-activity-xaml`), and `analyze` flags that do not exist (`--result-path`,
  `--stop-on-rule-violation`).
- **CRLF shebangs.** Both `.sh` files committed as LF but checked out as `#!/usr/bin/env bash\r`,
  which names no interpreter on Linux, macOS, WSL or Git Bash.
- **`BC31424` recipe** added to `silent-failure-traps.md` — a compile error that
  `validate-project` and `uip rpa build` both reported as clean.

### Known open

Carried deliberately rather than guessed. Each is written up where it belongs.

- **Which analyzer rule file is canonical** (`../RuleConfigs/{TAU,RPA,Legacy}.json`), and whether
  a client-specific rule set may be committed here. `TAU.json` has a malformed entry
  (`{"RuleId": "false"}`); no `SC-` rule appears in the loaded set, so the 16 it enables are
  likely inert. Nothing is shipped until this is settled.
- **`uip rpa run` → "The workflow cannot be found"** — unsolved; three leads recorded in test
  order.
- **The Avaloq library declares higher dependency floors than the Avaloq template pins**
  (`24.10.8`/`24.10.17` vs `[24.10.7]`/`[24.10.10]`), so a restore resolves a conflict nobody
  asked for.
- **Capture pins vs template pins** — a captured project ends on `studioVersion 23.10.8.0` with
  UIA at `26.10.4`, diverging from `templates/`. Is that the intended steady state?
- **`.entities/`, `.project/`, `.templates/`** have not been re-checked the way `.objects/` was.
- **A worked end-to-end example** is not shipped; the demo material needs clearance first.
- **Applications with no library and no reference** (desktop, Java, SAP, Citrix) are out of scope
  until someone decides otherwise. Whether `uip rpa uia` captures desktop apps is unverified.
- **Who owns test execution** — this repo or `test-ai-skills`.
- **Is Test Manager available on this Automation Suite**, or are tests run only via
  `Tests/RunAllTests.xaml`? `uip rpa tm` exists in the CLI (*"Configure Test Manager for the
  project — server connection and default project"*), so the tooling assumes it may be there;
  nothing in this estate records whether the Automation Suite deployment includes it. The answer
  changes stage 6: either tests are authored and reported through Test Manager, or
  `RunAllTests.xaml` plus `Tests.xlsx` stays the only mechanism and `uip rpa tm` should not be
  suggested at all.
