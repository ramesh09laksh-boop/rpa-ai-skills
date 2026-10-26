# Troubleshooting — symptom → cause → fix

Start here when something is broken. Each row links to the skill that owns the detail; nothing
is copied, so there is one place to fix when an answer changes.

The symptoms are written as they actually present, which is usually **not** as the real problem.

## Build, restore and validate

| Symptom | Cause | Fix / where |
|---|---|---|
| Restore fails: unresolved dependency on `Swisscom.FinnovaLibrary` / `Swisscom.PHI` / `Swisscom.UiPath.UIAutomation.Avaloq` | The `.nupkg` is not published to your feed. Having the library *source* is not the same thing | Publish to the feed first. Do **not** relax the pin or `mustRestoreAllDependencies` — `README.md` |
| `validate-project` says PASS, `uip rpa build` says Success, Studio shows a compile error | Both are weaker checks than Studio. The observed case was `BC31424: System.Data.DataRow … forwarded to System.Data.Common` | Add `<AssemblyReference>System.Data.Common</AssemblyReference>` to `TextExpression.ReferencesForImplementation` in every XAML touching `DataTable`/`DataRow` — `silent-failure-traps.md`. And never claim done below **L3** — the `project-scaffolding` skill, `references/evidence-ladder.md` |
| UiRobot pack fails: *"Some references are not imported in current workflow"*, naming no file | A used `xmlns` prefix whose assembly is missing from `ReferencesForImplementation`. `uip rpa validate` passes this clean | `validate-project` rule `xmlns-assembly-unreferenced` finds it in a second — `silent-failure-traps.md` |
| Build fails on a `SecureString` | Analyzer `ST-SEC-008`: a credential fetched in one scope and used in another | Fetch it inside each scope that needs it — `silent-failure-traps.md` |
| `uip rpa <something>` → unknown command | The command surface changed. `run-file`, `get-analyzer-rules`, `search-templates`, `create-project`, `find-activities`, `get-default-activity-xaml` do **not** exist in 1.204.0 | The `project-scaffolding` skill, `references/cli-command-map.md` |
| `uip rpa validate` / `run` / `uia` / `analyzer-rules` fails oddly, or finds nothing | These are **Studio-IPC** commands and need a Studio instance with that project open. `instances list` can report a live Studio with `ProjectDirectory: "(none)"` | `uip rpa instances list`, then `uip rpa studio start` — the `project-scaffolding` skill, `references/cli-command-map.md` |
| `uip rpa run` → *"The workflow cannot be found"* | **Unsolved.** Leads ranked, test them in order | the `project-scaffolding` skill, `references/cli-command-map.md` → *Unsolved* |

## The analyzer

| Symptom | Cause | Fix / where |
|---|---|---|
| `analyze --governance-file-path` → `DirectoryNotFoundException` under the project folder | A relative path resolves against the **project**, not your shell | Pass an absolute path — `code-quality.md` |
| `analyze` → `ArgumentNullException` in `AnalyzerRulesProcessor.ProcessRules` | `--governance-file-type` defaults to `AutomationOps`; your file is Studio-shaped | Add `--governance-file-type Studio` — `code-quality.md` |
| Analyzer result clean, but suspiciously so | The rule set you think ran did not. Three ways: a `Default` file type discards your file; a signed-in tenant's policy outranks it; a rule id this Studio version does not recognise is silently inert (**no `SC-` rule loaded** in the observed case) | Read the log lines, and diff your enabled ids against `uip rpa analyzer-rules list` — `code-quality.md` |

## Selector capture

| Symptom | Cause | Fix / where |
|---|---|---|
| `uip rpa uia` lists **zero subcommands** | `UiPath.UIAutomation.Activities` and `.CLI` are not both at `26.10.4` — or no Studio session has the project open | Fix the pin and restore; run preflight — the `web` skill, `references/capture-troubleshooting.md` |
| `selector-intelligence evaluate` rejects every selector after a page navigation | The window selector's `url` is the **previous** page (cached extension navigation state). The selectors are fine; the window is wrong | Explicit `interact browser navigate` → wait → fresh snapshot (new tab ref) → **fresh work folder** → re-resolve — `capture-troubleshooting.md` |
| Selectors hardened against the wrong screen | A leftover `window.xaml` in a reused work folder | One fresh work folder per screen — `capture-troubleshooting.md` |
| A click "succeeds" and nothing happens; the run fails at the *next* activity | `Simulate` drives accessibility APIs and never dispatches a DOM click, so a JavaScript `onclick` control no-ops while reporting success | `HardwareEvents` or `DebuggerApi` for that activity (`NChildInteractionMode`) — the `web` skill |
| A captured target resolves to nothing in a fresh clone | `.objects/` was not committed | It is source, not local state — the `project-scaffolding` skill, `references/object-repository-and-git.md`; `validate-project` rule `object-repository-not-shared` |
| A `{{var}}` descriptor times out and nothing else is wrong | It binds to a workflow **variable of exactly that name**; something renamed it | The `web` skill rule 5, and the `pdd-sdd-scaffolding` skill on argument-vs-descriptor naming |

## Runtime

| Symptom | Cause | Fix / where |
|---|---|---|
| Job green in Orchestrator, no work done | Queue-name mismatch between Dispatcher and Performer (must be **byte-identical**), or `GetTransactionData` yields nothing on the first call | `templates/README.md` → the pairing contract; `wiring-the-framework.md` |
| Process ends instantly, 0 transactions, no error | The same family: a stubbed queue call left in during wiring, or a configured source that read nothing | Add the 0-transaction guard — `silent-failure-traps.md` → *"A Performer that ends instantly with 0 transactions"* |
| A file the process wrote has vanished since the last publish | A relative path resolves into the **extracted package**, which is discarded on the next version | Absolute path, or `Path.Combine(in_Config("File_System_Root")…)` — `silent-failure-traps.md`; rule `relative-persisted-path` |
| `ui:WriteRange` / `ui:AppendRange` throws *"Error in implicit conversion. Cannot convert null object"* | The classic Excel write activities are broken on a Windows/.NET project, while `ReadRange` on the same workbook works | Modern `ExcelProcessScopeX` → `ExcelApplicationCard` → `WriteRangeX` — `silent-failure-traps.md`; rule `classic-excel-write` |
| A date comparison silently matches nothing; everything looks "not due" | `TryParse` inside an expression cannot write through its `out` parameter | Guard and assign as two steps — `silent-failure-traps.md`; rule `byref-out-arg` |
| A row count is higher than it should be; prose rows treated as data | A negative filter (`Active <> "FALSE"`) lets blank-valued footnote rows through | Filter positively (`= "TRUE"`) plus a shape guard — `silent-failure-traps.md` |
| `InitAllSettings` fails at startup on an `Assets` row | The Orchestrator asset does not exist yet | Create the asset, or suppress `assets-parity` **with a written reason** — the `security` skill; the `project-scaffolding` skill, `references/suppressing-a-rule.md` |
| A monthly/periodic step never ran, and nothing complained | A once-per-period gate fires exactly once and has no recovery | Gate on "on or after the due point, and not already done" — `silent-failure-traps.md` |

## Tooling and the repo

| Symptom | Cause | Fix / where |
|---|---|---|
| A `.sh` script fails to execute on Linux/macOS/WSL/Git Bash | A CRLF shebang: `#!/usr/bin/env bash\r` names no interpreter | The repo's `.gitattributes` pins `*.sh text eol=lf`. Re-checkout the file — the `project-scaffolding` skill, `references/fetched-files-crlf.md` |
| A fetched template diffs against the source on every text file | `core.autocrlf` on Windows. Content is identical | `diff -r --strip-trailing-cr`; nothing to fix — the `project-scaffolding` skill, `references/fetched-files-crlf.md` |
| `npx skills add … --agent copilot` → `Invalid agents: copilot` | The id is `github-copilot` | `README.md` → Install and update |
| A skill does not load, or a cross-skill reference goes nowhere (Copilot/Codex/OpenCode) | A skills path hard-coded to one agent's folder (`.claude`-, `.github`- or `.agents`-prefixed). The CLI installs into the agent's own folder, which differs per agent | Name the skill, or use a path relative to the skill folder. The `project-scaffolding` skill, `scripts/lint-skills.ps1`, enforces it |
| `npx skills update` reports nothing to update on a machine that was never signed in | The repo is private; that is an auth failure, not an up-to-date install | `gh auth login` — `README.md` |
| A PowerShell script appears to hang with no output at all | A user profile that prompts or loads slowly | Invoke with `-NoProfile`; the `.sh` wrappers already do |

## When the symptom is not here

Two questions settle most of what is left:

1. **Which level did you actually reach?** L1 static, L2 compiles, L3 Studio clean, L4 real run.
   Most "mystery" failures are a claim made one or two levels above the evidence —
   the `project-scaffolding` skill, `references/evidence-ladder.md`.
2. **Did it really do nothing, or did it do nothing *quietly*?** If a green run is the symptom,
   read `silent-failure-traps.md` before debugging anything else.
