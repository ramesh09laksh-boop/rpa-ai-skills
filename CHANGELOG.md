# Changelog

`npx skills update` pulls whatever is on `main`, so every merge to `main` reaches every UC
project on its next update. This file is how someone decides whether to run that command today.

Tag each release (`git tag -a v<x.y> -m ...`) so a project can pin or roll back.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Dates are ISO.

## [Unreleased]

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
