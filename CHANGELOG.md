# Changelog

`npx skills update` pulls whatever is on `main`, so every merge to `main` reaches every UC
project on its next update. This file is how someone decides whether to run that command today.

Tag each release (`git tag -a v<x.y> -m ...`) so a project can pin or roll back.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Dates are ISO.

## [Unreleased] — v0.2.2

**Merged to `main` on 2026-11-04 via PR #4, not tagged.** Branched from `main` (which was
content-identical to `chore/post-release-0.2.1` — the diff was empty). CI green on all six jobs
on the PR before merge.

> **Merged with three follow-up items still open**, at Ramesh's explicit decision after the
> release consequence was stated: the `designOptions.modernBehavior` comparison and proposal,
> `leaf-body-stub` calibration against the Lanes and Google projects, and two further *Known
> open* entries. Tracking continues against `main`.
>
> **No tag was cut.** A UC project that needs to stay still cannot pin this release by tag —
> `owner/repo#v0.2.2` does not exist. Cut one, or pin a branch, before telling anyone to pin it.

A correctness release. Most of it comes from two real runs — a Lanes capture and a Google
search demo — that each produced a project passing every check while doing nothing.

**Evidence level per item.** `verified` = a command was run and its output is in the commit.
`documented` = confirmed against the official co-versioned docs, not run. `unverified` = stated
as such, in the file itself.

| # | Change | Evidence |
|---|---|---|
| 1 | Capture under the role the robot runs as | verified (lint) · the Owner-session finding is from the Lanes run |
| 2 | The 2–3 screen boundary is a commit, not a stop | verified (lint; `grep` before/after) |
| 3 | Stages 4 and 5 merged into one per-workflow loop; leaf ledger | verified (lint) |
| 4 | `leaf-body-stub` rule; three StrictMode crashes fixed | verified (probe, both severities, plus a no-false-positive case) |
| 5 | `web` CLI claims re-verified; command table replaced | documented (official UIA package docs 26.10.4, quoted with file and line) |
| 6 | Stage 3 prompt names `KillAllProcesses` | verified (all seven matched against the prompt text) |
| 7 | `rpa-legacy` section trimmed to one line | verified (lint) |
| 8 | Skills made self-contained; install-simulation lint | verified (73 findings → 0, plus a negative control) |
| 9 | Data hygiene | verified (residual scan = 0 across 7 categories, plus a negative control) |
| 10 | A bad/good fixture per `validate-project` rule | verified (62/62, plus two negative controls) |
| — | .NET SDK 8.0 prerequisite; official installer documented | documented (official install page + `uipath-rpa` skill) · the installer itself was **not run** |
| — | Official `uipath-rpa` skill checked by preflight; ask-first before touching the tenant | verified (6 copies found, a real co-version drift surfaced; `npx skills add --help` and a read-only `--list`) |
| — | **L4-local** — pack, then run the package on the local UiRobot in a folder | documented (every `UiRobot` flag read from `--help`; `UiRobot version` run) · the **run itself was not executed** — no robot here is bound to a folder |

### Added

- **`leaf-body-stub`** validate-project rule — a leaf workflow whose body contains no activity
  that does the step. The four leaf-contract rules all check the *signature*, so a file can
  satisfy every one of them and still be a `Log Message` in a `Sequence`. A Framework correctly
  wired to workflows like that reads its transactions, dispatches them, marks them Successful
  and performs **no work** — while passing `validate`, `build`, `analyze`, `pack`, Studio's
  Error List, and a real Orchestrator job with a non-zero transaction count. Warning
  mid-build; **error** under the new `-UatReadiness` / `--uat-readiness` switch.
- **`tests/`** — a bad/good fixture per validate-project rule, with CI asserting **both**
  directions (`bad` must fire, `good` must be silent) and a coverage check that fails when a
  rule has no fixture. 31 rules, 62 assertions. CI previously checked only that `templates/`
  produces zero findings, which proves a rule does not false-positive and nothing about whether
  it still works.
- **`infra-identity-value`** skill-lint rule — real IPs, e-mail addresses and customer
  identifiers inside skills, as errors. Not secrets, which is why they were written down and why
  nothing flagged them.
- **`install-simulation`** skill-lint rule — each skill is copied **alone** to a temp directory,
  which is what `npx skills add --skill <name>` delivers, and every relative link and
  repo-level path mention is resolved there.
- **`standards/references/leaf-ledger.md`** — the `Documentation/Leaf_Ledger.md` template. Seven
  columns, each documented with the silent failure it catches. The capture-and-develop stage is
  gated on the whole ledger, not on the count of files that exist.
- **`project-scaffolding/references/instantiating-templates.md`** — the instantiation checklist,
  moved out of a file the fetch script never delivered.
- **The probe trap** in `web/SKILL.md` — a logged-in probe inside a card whose `TargetApp` is
  the sign-in screen, with `OpenMode = IfNotOpen`, can never fire.
- **.NET SDK 8.0** in the README prerequisites and as a `preflight` check, framed as a
  prerequisite of **`uip rpa`** rather than of capture, with the official installer, its skip
  switches, and a restricted-network section.
- **`L4-local` — a sixth rung on the evidence ladder.** `pack`, then run **the packed package**
  with the UiRobot on this machine, pointed at an Orchestrator folder so the credential asset
  resolves. **No `uip login`, nothing changed in the tenant**, so it is the default end-to-end
  run and the Orchestrator job becomes a second, ask-first step. Quoted with its folder —
  `L4-local (folder: Modern/RAP-Demo)`. `UiRobot execute` **does** have a `--folder` option;
  every flag was read from `UiRobot help execute` rather than guessed. `end-to-end-run.md` is
  restructured around it: Part 0 (ask four facts once) → Part 1 (L4-local) → Part 2 (robot
  prerequisites — the part L4-local cannot reach) → Part 3 (the Orchestrator job, ask-first) →
  Part 4 (the acceptance table, which now applies at both levels).
- **Preflight checks the official `uipath-rpa` skill**, agent-aware, in every known install
  location — and compares each copy's `targetCli` against the installed host. It does **not**
  install it: that is an ask-first action.
- **An ask-first rule for the tenant**, in `AGENTS.md`, `uc-delivery` and the README
  Working-rules block. The line is *not* read-versus-write: a read still signs in, under
  whoever's identity the local token holds, and lands in the audit log under their name — so
  `uip or folders list` is on the ask list. New `preflight -SkipFeedCheck` /
  `--skip-feed-check`, because the library-feed check runs `uip rpa restore`, which against an
  Orchestrator-hosted feed is an authenticated read.

### Changed

- **Stages 4 and 5 are one loop**, per workflow: capture → author → run once → pack → ledger
  row → commit → next. Separating them is what let a project *with a live session* ship
  `TODO_SELECTOR` placeholders and no capture at all.
- **`web/SKILL.md` no longer carries a `uip rpa uia` command table.** All four claims from the
  Lanes run were checked against the official docs; one of them is why the table is gone:
  *"Never manually call internal selector-building `uip rpa uia` CLIs. Direct calls bypass
  improvement and OR registration, leaving fragile unregistered selectors."* The old table
  listed exactly that set. The discipline rules stayed; the command names are now the package's
  to own.
- **Skills are self-contained.** The moved checklist above was a real bug — `fetch-template.*`
  sparse-checks-out `templates/<name>/` only, so the one artefact telling you how to finish
  instantiating a template was the one artefact it could not deliver. Provenance mentions are
  now labelled for the reader, and the templates' own delivered `README.md`/`.gitignore` files
  no longer hard-code `.claude/skills/…` paths that resolve to nothing in a project.
- **Data hygiene.** Infrastructure and identity values in the skills are replaced by their
  config **key** and Orchestrator **asset name**. Asset names and config keys stay — they are
  identifiers you must name to wire anything up.
- **`preflight` no longer warns at a signed-in machine.** `uip login status` reports
  `"Logged in"`; the check accepted only `Success`/`Authenticated`, so the L4 readiness checks
  were unreachable on exactly the machines that could run them.
- **Stage 3 is "wired, gate open"** until the 0-transaction guard has been *observed firing*.
  That needs a run, and a run needs the Orchestrator asset.

### Fixed

- **`leaf-body-stub` reported declared mocks; `unresolved-mock` reported none at all.** Both
  found by running the checker on a real Windows project (UC252) rather than on fixtures, and
  both are the same underlying mistake — treating the `[MOCK]` *string* as the only way a mock
  is declared.

  | | Before | After |
  |---|---|---|
  | `leaf-body-stub` | **7** findings — 6 under `Mock_System/`, 1 real | **1** |
  | `unresolved-mock` | **0** | **26** |

  A workflow under `Mock*/` or named `Mock-*` / `Mock_*` is a **declared** mock: doing nothing
  is its job. Reporting six of them as accidental stubs is how a rule gets blanket-suppressed —
  and that suppression would have hidden the one true positive beside them
  (`Bottomline_System/Bottomline_Logout.xaml`, a logout whose body is a `Comment` and a
  `Log Message`). So `leaf-body-stub` now carves declared mocks out, and `unresolved-mock` now
  recognises them — that project has 22 of them and **not one** carries the `[MOCK]` string, so
  the marker-only rule was blind to the whole layer and `mocking.md`'s *"a mocked run reaches L3
  at most"* cap applied to nothing. `mocking.md` now says a folder name is not a substitute for
  the marker.

  The fixture suite could not have caught either: every fixture was written by the same person
  as the rule. `tests/README.md` now says so, under *Fixtures are not a substitute for a real
  project*.
- **Three StrictMode crashes in `validate-project.ps1`**, each of which aborted the entire run
  and reported **no findings at all** rather than failing loudly: a `project.json` without
  `runtimeOptions`, without `dependencies`, and with an empty `"dependencies": {}`. Dot-access
  to an absent property throws under StrictMode *even inside* `if ($proj.dependencies)`, so the
  existing guard did not guard. Nothing in the estate omits those keys, which is why it went
  unnoticed until a minimal fixture existed.

### Counts and claims that changed

Every one of these was asserted somewhere in the repo or the brief and is wrong:

| Claimed | Actual | How |
|---|---|---|
| `validate-project` has **42 rules** | **31** distinct rule ids (30 before `leaf-body-stub`) | 42 is the number of `Add-Finding` **call sites**, in a 42,321-byte script |
| (my own interim count) **29** rules | 31 | 29 missed `run-output-clean`, emitted as `Add-Finding $sev` rather than a literal severity |
| **56** repo-level path mentions inside skills | **69** | `grep -raoE` over `.claude/skills`, before any change |
| *"README stage 4 and `capture-troubleshooting.md` §3 say 2–3 screens per run, then stop"* | **one** place, not two | README said "2–3 screens per run" with no stop instruction |
| `solution-tool` / `tasks-tool` / `platform-tool` at **1.201.0, needs update** | all **1.204.0, ok**; `resource-tool` gone from `tools list` | `uip tools list`, 2026-11-03 — eight days after the recorded snapshot |
| `web/SKILL.md`: both UIA packages **"must"** be 26.10.4, no source | the official **minimum** is `UiPath.UIAutomation.Activities` **≥ 26.10.2**, and `UiPath.UIAutomation.CLI` is not named in the official docs at all | the estate's 26.10.4 pin is now presented as a stricter *local* standard, beside the official minimum |
| *"absolute native Windows paths"* for the UIA CLI | absolute and native-host, but **forward-slash** — `C:/…`, never `/c/…`, `/mnt/c/…` or relative | official `uia-configure-target/SKILL.md` line 16 |
| `studio-checkpoints.md`: *"run `Main.xaml` on TST **(L4)**"* | **L3 evidence.** A Studio Debug run executes the project *sources* in your own session, which the ladder has always called L3 | the heading contradicted the ladder in the same repo; retitled |
| The official skill is co-versioned with the CLI, so one copy is as good as another | **three copies, two versions.** `~/.uipath/.skills` at skills `1.204.1` / `targetCli ^1.204.0`; the Claude Code plugin marketplace **and** cache at `1.201.0` / `^1.201.0`; host `1.204.0` | Claude Code loads the **plugin** copy, so the agent reading those docs was a minor version behind the tool it documented. `preflight` now warns on it |

### Known open

- **The data-hygiene redaction is forward-only.** The removed values remain in git history and
  in any clone or `npx skills add` taken before this branch; `git log -S` on one of them returns
  a commit. Whether to rewrite history or rotate anything is a decision for Ramesh, not
  something to do silently.
- **The stage-5 prompt deviates from the brief by one phrase.** The supplied text said *"a
  target that fails the `evaluate` gate"*; it now reads *"the registration gate"*, because the
  official docs forbid calling that CLI by hand. The discipline is unchanged. Flagged for
  Ramesh to confirm.
- **Nothing above L1 was reached.** No `uip rpa validate`/`build`/`pack`, no Studio Error List,
  no robot, no Orchestrator job, **and no L4-local run**. See the per-item evidence table.
- **The two `UiRobot` facts the L4-local default rests on are unverified**, and
  `end-to-end-run.md` says so in its own table: that `--file` works **together with**
  `--folder` (every official example pairs `--folder` with `--package-id`), and that `--folder`
  is what resolves the credential asset for a `--file` run. No robot here is bound to a folder.
  **Run Part 1 once against a real folder and correct those two rows first** — a documented
  fallback via `installprocess` + `--package-id` is recorded in case they are wrong.
- **The Claude Code plugin copy of the official skill is a minor version behind the CLI**
  (`1.201.0` against host `1.204.0`). Updating it is the plugin route's business and is
  ask-first; `preflight` warns until someone does.
- **Two branches of existing rules have no fixture**, and `tests/README.md` says so:
  `object-repository-not-shared`'s git-ignored branch (fixtures live outside a repository, so
  `git check-ignore` cannot be asked) and both `secret-argument-string` carve-outs.
- **No internal-FQDN lint pattern.** An allowlist of public documentation hosts would need
  maintaining and would go stale; the one instance found was redacted by hand, and a future one
  is not caught.
- **A public infrastructure IP on a line with no host-ish word is not caught** by
  `infra-identity-value`. A dotted quad is textually indistinguishable from a four-part version
  string, and this repo has 16 of those.
- **The official UiPath CLI installer was not run**, so "needs administrator rights" is flagged
  as the likely case to confirm rather than as fact — the official install page does not state
  an elevation requirement.
- ~~**`leaf-body-stub` has no modern-project calibration.**~~ **Closed** — calibrated against
  UC252 (a real Windows project, 85 workflows, 63 leaf) on 2026-11-04, which found two defects
  and fixed both. See *Fixed* above. Still worth a second real project before promoting the rule
  to error outside stage 8.
- Everything under *Waiting on Ramesh* is untouched: the analyzer rule file, Dispatcher/Performer
  naming, Avaloq template pins, capture pin vs template pin, the worked example, whether Test
  Manager exists on the Suite, and the first real L4 run.

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
