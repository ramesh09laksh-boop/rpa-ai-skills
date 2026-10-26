# `uip` command map

**`uip` is a host plus separately-versioned tools.** That is the single most important fact about
documenting it: the host (`uip`) and each tool (`rpa`, `or`, `rpa-legacy`, …) update
**independently**, a tool auto-installs on first use, and a verb that exists today may be spelled
differently next week. So every command below is keyed by **which tool owns it** and **which tool
version was checked**.

Re-run `--help` before relying on anything here. If `--help` disagrees with this file,
**`--help` wins** and this file is stale.

## Observed state of this machine

Captured **2026-10-26** on Windows, user `tzhlara2`, from `uip tools list` and
`$env:APPDATA\npm\node_modules\@uipath\*\package.json`:

| Tool | Version | Prefix | `tools list` status | Package last written |
|---|---|---|---|---|
| `cli` (the host) | **1.204.0** | — | — | 2026-10-21 15:39 |
| `rpa-tool` | **1.204.2** | `rpa` | ok | **2026-10-26 13:33** |
| `orchestrator-tool` | **1.204.0** | `or` | ok | 2026-10-26 17:39 |
| `rpa-legacy-tool` | **1.204.0** | `rpa-legacy` | ok | 2026-10-21 15:40 |
| `solution-tool` | 1.201.0 | `solution` | **needs update** | 2026-09-10 22:44 |
| `tasks-tool` | 1.201.0 | `tasks` | **needs update** | 2026-09-10 22:44 |
| `platform-tool` | 1.201.0 | `platform` | **needs update** | 2026-09-10 22:45 |
| `resource-tool` | 1.1.0 | — | not listed | 2026-05-29 13:13 |

Three tools are behind the host. **Do not run `uip tools update` mid-project** — see *Rules*.

## Tool ownership — which prefix owns which verb

### `rpa` — rpa-tool 1.204.2

`activities` · `analyze` · `analyzer-rules` · `build` · `cleanup` · `data-fabric-entities` ·
`debug` · `execution` · `files` · `get-library-object-repository` · `get-object-repository` ·
`init` · `instances` · `pack` · `packages` · `publish` · `remote` · `restore` · `run` ·
`settings` · `studio` · `templates` · `test-data` · `tm` · `uia` · `validate` ·
`workflow-examples`

Subcommands, where the verb is a group:

| Verb | Subcommands |
|---|---|
| `templates` | `search` |
| `activities` | `find`, `get-default-xaml` |
| `packages` | `inspect`, `install`, `versions` |
| `analyzer-rules` | `list` |
| `instances` | `list` |
| `studio` | `start` |
| `execution` | `cancel` |
| `settings` | `get`, `set` |
| `files` | `diff` |
| `workflow-examples` | `get`, `list` |
| `test-data` | `add-entity`, `add-queue`, `add-variation` |
| `tm` | `connect`, `status`, `set-default-project`, `clear-default-project` |
| `remote` | `targets`, `configure`, `status`, `start`, `stop`, `exec`, `upload-file`, `download-file` |
| `debug` | `start`, `start-from-here`, `restart-from-top`, `state`, `break`, `continue`, `continue-ignore`, `continue-retry`, `resume`, `step-into`, `step-over`, `step-out`, `set-breakpoints`, `toggle-breakpoint`, `test-activity`, `apply-file-changes` |
| `uia` | **lists none unless a project with matching UIAutomation packages is open** — see the `web` skill |

### `or` — orchestrator-tool 1.204.0

`assets` · `attachments` · `audit-logs` · `bucket-files` · `buckets` · `calendars` ·
`credential-stores` · `feeds` · `folders` · `jobs` · `libraries` · `licenses` · `machines` ·
`packages` · `process-roi` · `processes` · `queue-items` · `queue-roi` · `queues` · `roles` ·
`sessions` · `settings` · `triggers` · `users` · `webhooks`

> **There is no `or releases` subcommand** in orchestrator-tool 1.204.0. The concept exists —
> `or processes --help` calls a process a *"release binding"* — but the subcommand is
> **`processes`**: *"runnable bindings of packages to folders. Processes are what you execute
> with `jobs start`."*

### `rpa-legacy` — rpa-legacy-tool 1.204.0

`debug` (*"Execute a XAML workflow locally via UiRobot"*) · `find-activities` · `find-package` ·
`pack` · `type-definition` · `validate`

**`debug`, `pack` and `validate` exist on *both* `rpa` and `rpa-legacy`** and are different
implementations. Say which prefix you mean.

## The renames — old name → current, with confidence

The left column is what earlier documentation in this repo and an earlier agent session used.
**The tool version those names worked on is not recorded**, so "rename" is an inference about
*why* they differ; what is verified is only what each name does **now**.

| Earlier name | Now | Confidence |
|---|---|---|
| `rpa search-templates` | **`rpa templates search`** | **Confirmed** — `templates` is a group whose only subcommand is `search` |
| `rpa get-analyzer-rules` | **`rpa analyzer-rules list`** | **Confirmed**, with direct evidence: invoking it with no project open fails inside a handler the CLI still labels `[get-analyzer-rules]`, i.e. the old name survives internally |
| `rpa get-default-activity-xaml` | **`rpa activities get-default-xaml`** | **Confirmed** |
| `rpa run-file` | **`rpa run --file-path <path>`** | **Confirmed** — `run`'s usage is `--file-path <string>` |
| `rpa create-project` | **`rpa init --name <string>`** | **Unconfirmed as a rename.** `init` is *"Initialize a new UiPath project from a template"* and takes the same `--template-package-id` / `--template-package-version` / `--target-framework` / `--expression-language` / `--skip-solution-registration` flags the earlier session used, so it is the same operation. But no `create-project` verb is listed by `rpa --help` on **rpa-tool 1.204.2**, and nothing records which version had it |
| `rpa find-activities` | **`rpa activities find`** *…and also still `rpa-legacy find-activities`* | **Confirmed, with a correction** — see below |

### Correction to earlier docs: `find-activities` is not gone

An earlier version of this file said these names "are **not** commands in this version". That was
wrong for one of them. **`find-activities` exists on rpa-legacy-tool 1.204.0** as
`uip rpa-legacy find-activities`. It is absent from **rpa-tool 1.204.2**, where the equivalent is
`rpa activities find`.

The general rule this teaches: *"command X does not exist"* is meaningless without a tool and a
version. State both, as **"absent from `rpa --help` on rpa-tool 1.204.2"**.

`init --help` also still says *"Use search-templates to discover available packages"* — stale
help text inside the current tool. The command is `rpa templates search`.

## Flags, as `--help` prints them

```
rpa templates search   [--query <string>] [--limit <integer>] [--include-prerelease]
rpa init               --name <string> [--template-id] [--location] [--description]
                       [--expression-language {VisualBasic|CSharp}]
                       [--target-framework {Legacy|Windows|Portable}]
                       [--dotnet-version {net6.0|net8.0|net10.0}]
                       [--allow-prerelease-packages] [--template-package-id]
                       [--template-package-version] [--skip-solution-registration]
rpa validate           [--file-path <string>] [--skip-validation]
                       [--min-severity {error|warning|info|verbose}]
rpa build              [options] [project-dir]
rpa analyze            [options] [project-dir]
rpa pack               [options] [project-dir] [output-path]
rpa publish            [options] <package>        # a packed .nupkg, not a project folder
rpa restore            [options] [project-dir] [output-path]   # outputPath for air-gapped CI
rpa run                --file-path <string> [--input-arguments <key=value>]
                       [--input-arguments-file <path>] [--log-level ...] [--skip-build]
                       [--profiling] [--profiling-mode {endOfRun|stream}] [--remote]
```

### Global options (every `rpa` verb)

`--project-dir` · `--studio-dir` · `--robot-dir` · `--timeout` · `--verbose` · `--policy-file` ·
`--policy-file-type` · `--output {table|json|yaml|plain|markdown}` · `--output-filter` (JMESPath
over the response `Data`) · `--log-level` · `--log-file` · `--profile`

### `--policy-file` means two different things

A genuine trap:

| Where | Meaning |
|---|---|
| As a **global** option on any `rpa` verb | *"Governance policy to judge this invocation by where the signed-in tenant has none"* |
| On **`analyze`**, **`build`**, **`pack`** | **An alias for `--governance-file-path`** — *"Analyzer policy JSON file. Alias for --governance-file-path (Pipeline Analyze parity)"*. `--policy-file-type` likewise aliases `--governance-file-type` |

So on `analyze` the pairs are interchangeable; elsewhere `--policy-file` is about the invocation,
not the analyzer. Analyzer detail: the `standards` skill, `references/code-quality.md`.

### `publish` flags (rpa-tool 1.204.2)

`--personal-workspace` · `--feed-id` · `--folder-key` · `--folder-path` · `--shared-libraries` ·
`--allow-any-feed`, plus the globals.

## Two command families, and why it matters

**Studio-IPC** — carry `--project-dir`, described as *"Project directory to match against running
Studio instances"*. The `rpa` tool describes itself as managing projects *"via Studio IPC"*:

`validate` · `run` · `debug` · `execution` · `activities` · `analyzer-rules` · `files` ·
`get-object-repository` · `settings` · `uia` · `init` · `templates` · `instances` · `studio`

```bash
uip rpa instances list      # what is running, and its ProjectDirectory
uip rpa studio start        # start one and wait until ready
```

**Compiler/standalone** — take a positional `project-dir`:

`analyze` · `build` · `pack` · `publish` · `restore` · `cleanup`

## Rules

- **`rpa cleanup` only with `--dry-run`.** Its own description is *"Remove unused items from a
  UiPath project (**modifies the project sources in place**). Pass `--dry-run` to only detect
  unused items."* Run it without `--dry-run` only on a clean, committed tree, and never as a
  side effect of another task.
- **Never run `uip tools update` mid-project.** A tool version change alters verb names and
  flags underneath work in progress — which is exactly what produced the rename confusion
  documented above. Update between projects, deliberately, and record the new versions.
- **Record the tool versions in `Documentation/Progress.md`** at the start of a project.
  `preflight` prints `uip tools list` and warns when `rpa-tool` differs from the recorded
  version, so a mid-project change is visible rather than mysterious.
- **The CLI asks you to load the official `uipath-rpa` skill.** Every `uip rpa` invocation
  prints: *"Before using this tool, make sure you have loaded the uipath-rpa skill and read its
  documentation. uipath-rpa/SKILL.md is the canonical reference."* Load it for CLI mechanics;
  this estate's rules win on structure, naming and security. See the `uc-delivery` skill.

## Unsolved: `run` → "The workflow cannot be found"

An earlier session reported that **every** workflow failed to run — `Main.xaml` at the root and a
subfolder workflow, with and without `--project-dir`, with and without `--skip-build`:

```
The workflow cannot be found. Make sure that it is part of the project.
```

…while `rpa build` reported `"Success": true`. Leads, in the order worth testing:

1. **An unsurfaced compile error.** The same project had `BC31424: System.Data.DataRow … forwarded
   to System.Data.Common` visible only in Studio, while `validate-project` said PASS and `build`
   said Success. A project that does not compile has no workflow to find. Clear **L3** first.
2. **`run` likely needs a Studio instance with the project open — UNVERIFIED.** `run` is in the
   Studio-IPC family, `--project-dir` is documented as matching *running Studio instances*, and
   `instances list` can report a live Studio with `"ProjectDirectory": "(none)"`. That is
   suggestive, not established: it has **not** been tested by opening the project and re-running.
   Treat it as a hypothesis until someone does.
3. **The tool version.** That session predates the rpa-tool build on this machine, so re-test on
   **1.204.2** before trusting the old conclusion.

Whoever settles this writes the answer here and deletes this section.

## Provenance

| Fact | Source |
|---|---|
| Tool versions and statuses | `uip tools list`, 2026-10-26 |
| Package timestamps | `Get-ChildItem $env:APPDATA\npm\node_modules\@uipath`, 2026-10-26 |
| Every verb, subcommand and flag above | `--help` on this machine, 2026-10-26, tool versions in the table |
| The earlier names | An earlier agent session on this same machine; **tool version not recorded** |
