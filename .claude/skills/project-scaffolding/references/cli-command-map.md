# `uip` command map

**`uip` is a host plus separately-versioned tools.** That is the single most important fact about
documenting it: the host (`uip`) and each tool (`rpa`, `or`, `rpa-legacy`, …) update
**independently**, a tool auto-installs on first use, and a verb that exists today may be spelled
differently next week. So every command below is keyed by **which tool owns it** and **which tool
version was checked**.

Re-run `--help` before relying on anything here. If `--help` disagrees with this file,
**`--help` wins** and this file is stale.

## Observed state of this machine

Re-captured **2026-11-03** from `uip tools list --output table`. The previous snapshot
(2026-10-26) is kept below it, because the delta is the point of the section.

| Tool | Version | Prefix | `tools list` status |
|---|---|---|---|
| `cli` (the host) | **1.204.0** | — | — |
| `rpa-tool` | **1.204.2** | `rpa` | ok |
| `orchestrator-tool` | **1.204.0** | `or` | ok |
| `rpa-legacy-tool` | **1.204.0** | `rpa-legacy` | ok |
| `solution-tool` | **1.204.0** | `solution` | ok |
| `tasks-tool` | **1.204.0** | `tasks` | ok |
| `platform-tool` | **1.204.0** | `platform` | ok |

**Every tool now matches the host, and `resource-tool` no longer appears in `tools list` at
all.** On 2026-10-26 `solution-tool`, `tasks-tool` and `platform-tool` were all `1.201.0` with
status **needs update**, and `resource-tool 1.1.0` was present but unlisted. Three tool versions
moved and one tool vanished in eight days, without anyone here asking for it.

That is the whole argument of this file, and it is why **`--help` wins over anything written
here**. It is also why *Rules* says never to run `uip tools update` mid-project: if a tool can
move on its own, a deliberate update mid-build is strictly worse. Record the versions in
`Documentation/Progress.md` at the start of a project — `preflight` compares `rpa-tool` against
that record and flags a mismatch, which is what makes a change like this visible rather than
mysterious.

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

### `rpa-legacy`

**Not used — new projects are Windows/modern.**

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
| `rpa find-activities` | **`rpa activities find`** | **Confirmed** |

### State the tool and version, not just the name

An earlier version of this file said these names "are **not** commands in this version". For
modern work the statement that matters is narrower and checkable: **"absent from `rpa --help` on
rpa-tool 1.204.2"**. Never write that a command "does not exist" without naming the tool and the
version you checked.

(Some of these names do still exist on `rpa-legacy`, which is irrelevant to new projects — see
above.)

## Inspecting a library or its activities — the modern verbs

For re-verifying what a library actually exposes, without `rpa-legacy`:

| Need | Command | Status |
|---|---|---|
| Find activities available in the project's dependencies | `rpa activities find --query <q> [--tags] [--limit]` | **Verified** present |
| The exact XAML an activity produces, with real defaults | `rpa activities get-default-xaml --activity-class-name <FQCN>` | **Verified** — used to author Framework XAML |
| A package's **public API by reflection** | `rpa packages inspect --package-name <n> --package-version <v>` *or* `--nupkg-path <local .nupkg>` | **Verified working** — run against `UiPath.System.Activities 23.10.3`, returns a markdown API dump with per-class property tables (name / type / get / set). Both `packageName` **and** `packageVersion` are required, or it fails `INVALID_ARGUMENTS` |
| Which versions of a package exist | `rpa packages versions <package>` | **Verified** present |
| The Object Repository **inside** library `.nupkg`s | `rpa get-library-object-repository --library-paths <array>` | **Verified** present |
| Install/update a dependency | `rpa packages install` | **Verified** present |

### The gap, stated

**No `uip rpa` verb has been shown to recover a UiPath *library project's* `in_`/`out_` argument
names the way reading its `x:Members` does.** `packages inspect` reflects over the *compiled*
assemblies, which for a UiPath library means generated wrappers — whether the `in_`/`out_`
names survive that identically is **unverified**, because the Swisscom packages are not on a
feed reachable from this machine and no local `.nupkg` was available for `--nupkg-path`.

So for library signature re-verification the demonstrated method is still reading `x:Members`
from the library **source** project — 155 workflows across both libraries. That is **maintainer
provenance**: the feasibility write-up lives at `docs/feasibility-generated-activity-tables.md`
in the rpa-ai-skills repo, the library sources are siblings of it, and neither is in your
project. If someone gets a Swisscom `.nupkg` locally, `rpa packages inspect --nupkg-path` is the
first thing to try, and the answer belongs here.

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
2. ~~**`run` likely needs a Studio instance with the project open — UNVERIFIED.**~~
   **Eliminated, 2026-11-06, rpa-tool 1.204.2.** Tested on a machine with **no Studio and no
   `UiRobot.exe` installed** — only the Helm backend the CLI ships with
   (`%LOCALAPPDATA%\UiPath\Helm\<ver>-win32-x64`):
   `uip rpa run --project-dir <dir> --file-path "Tests\<file>.xaml"`, against a project **nothing
   had open**, printed *"Validating … Building for execution… Starting execution…"*, executed the
   workflow and returned its output arguments as JSON. `instances list` afterwards showed an
   instance bound to that directory — `run` **provisions its own**, which is why the help text's
   *"matching running Studio instances"* reads like a prerequisite and is not one.
   **A pre-opened Studio is not required, and "needs Studio" does not explain a failed `run`.**
   This does not reproduce or explain the original *"workflow cannot be found"*; it removes one
   candidate and leaves lead 1 as the leading one.
3. **The tool version.** That session predates the rpa-tool build on this machine. Lead 2 has now
   been re-tested on **1.204.2**; lead 1 has not.

Whoever settles this writes the answer here and deletes this section.

## Provenance

| Fact | Source |
|---|---|
| Tool versions and statuses | `uip tools list --output table`, **2026-11-03** |
| Every verb, subcommand and flag above | `--help` on this machine, 2026-10-26, at the tool versions in the *previous* snapshot. **Not re-run on 2026-11-03** — `rpa-tool` is unchanged at 1.204.2, so the `rpa` verbs should hold; `solution`, `tasks` and `platform` each moved a minor version and their verbs are **unverified at the new version**. None of them is used by these skills. |
| `.NET SDK 8.0` is what `uip rpa` restores its headless Studio with | the official `uipath-rpa` skill (`@uipath/skills` 1.204.1), which states `uip rpa` auto-launches headless Studio (`UiPath.Studio.Helm.<Platform>`) via a silent `dotnet restore` |
| `uip login status` reports `Status: "Logged in"` | run on 2026-11-03. `preflight` previously accepted only `Success`/`Authenticated` and warned on a correctly signed-in machine |
| The earlier names | An earlier agent session on this same machine; **tool version not recorded** |
