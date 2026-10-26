# `uip rpa` command map

**Verified against `uip --version` → `1.204.0`** by running `--help` on each command. Re-run
`--help` before using any flag below; this file is a map, not a substitute for the tool.

The command surface was **restructured** at some point before 1.204.0. Several names that appear
in older UiPath documentation, in blog posts, and in the training data of most models do **not
exist** in this version. Using one produces an unknown-command error, which is at least loud —
but a plausible-looking wrong *flag* is worse, because some of them are silently ignored.

## Renamed — the old name is not a command

| Older name you may have seen | Command in 1.204.0 |
|---|---|
| `uip rpa run-file` | `uip rpa run --file-path <path>` |
| `uip rpa get-analyzer-rules` | `uip rpa analyzer-rules list` |
| `uip rpa search-templates` | `uip rpa templates search` |
| `uip rpa create-project` | `uip rpa init --name <name>` |
| `uip rpa find-activities` | `uip rpa activities find` |
| `uip rpa get-default-activity-xaml` | `uip rpa activities get-default-xaml` |

`uip rpa init --help` still says *"Use search-templates to discover available packages"* — the
help text is stale. The command is `uip rpa templates search`.

## Flags that do not exist on `analyze` in this version

Documented elsewhere, **absent** from `uip rpa analyze --help` here:

| Flag | Status | Use instead |
|---|---|---|
| `--result-path` | not present | `--detailed-log-path <path>`, or `--output json` and redirect |
| `--stop-on-rule-violation` | not present | read the exit code and the JSON result |

Present and verified on `analyze`: `--governance-file-path`, `--governance-file-type`,
`--default-severity`, `--detailed-log-path`, `--skip-analyze`, `--repository-path`,
`--policy-file` (alias of `--governance-file-path`), `--feed-folder`,
`--nuget-sources-config-path`, `--exclude-configured-sources`, `--format`.

`build` carries the same governance flags **plus** `--ignored-rules <rules>`.

### The governance file is conditional, and this is easy to miss

From `--governance-file-path`'s own help text:

> The tenant is asked first: where it publishes a policy of its own, that policy applies and
> this file is ignored **with a warning**; where it publishes none, or the answer cannot be
> established, this file is used.

So passing `--governance-file-path` is not the same as the rules in that file being applied. If
the signed-in tenant publishes an AutomationOps policy, your file is discarded and the run
analyzes against the tenant's rules. **Read the warning line in the output** before believing a
clean analyzer result came from your rule set.

## Two command families

This matters more than it looks, because it decides whether Studio has to be open.

**Studio-IPC commands** — carry `--project-dir <path>`, described as *"Project directory to
match against running Studio instances"*. They need a running Studio with **that project open**:

`validate` · `run` · `debug` · `execution` · `activities` · `analyzer-rules` · `files` ·
`get-object-repository` · `settings` · `uia` · `init` · `templates` · `instances` · `studio`

```bash
uip rpa instances list      # what is running, and its status
uip rpa studio start        # start one and wait until ready
```

**Compiler commands** — take a positional `project-dir` and run standalone:

`analyze` · `build` · `pack` · `publish` · `restore` · `cleanup`

## Full top-level command list (1.204.0)

`activities` · `analyze` · `analyzer-rules` · `build` · `cleanup` ·
`data-fabric-entities` · `debug` · `execution` · `files` ·
`get-library-object-repository` · `get-object-repository` · `init` · `instances` · `pack` ·
`packages` · `publish` · `remote` · `restore` · `run` · `settings` · `studio` · `templates` ·
`test-data` · `tm` · `uia` · `validate` · `workflow-examples`

## Unsolved: "The workflow cannot be found"

**Status: not solved. Recorded so the next person starts further along.**

On the Lanes run, **every** workflow failed to run — `Main.xaml` at the project root and
`Lanes_System/Lanes-SignIn.xaml` in a subfolder, with and without `--project-dir`, with and
without `--skip-build`:

```
The workflow cannot be found. Make sure that it is part of the project.
```

…while `uip rpa build` reported `"Success": true`. The run notes concluded it was a
"compiled-assembly resolution" problem in the tool.

### Two leads, in the order worth testing

**1. There was a compile error the CLI did not surface.** The same project had
`BC31424: System.Data.DataRow … forwarded to System.Data.Common` in
`Framework/InitAllSettings.xaml`, visible only in Studio. `validate-project` said PASS and
`build` said Success. A project that does not actually compile has no workflow to find, and
"cannot be found" is exactly the shape that failure would take. **Clear L3 first** (Studio,
empty Error List) and retry — see `evidence-ladder.md` and the `standards` skill's
`silent-failure-traps.md`.

**2. The command is Studio-IPC, and Studio may not have had the project open.** `run` is in the
Studio-IPC family above: `--project-dir` means *"Project directory to match against running
Studio instances"*, and the CLI resolves the file **relative to the project Studio has open**.
With no matching instance there is nothing to resolve the path against. Evidence that this is
how the family behaves: `analyzer-rules list` with no project open fails inside
`IInteropProjectService.OpenProject`, and its internal handler is still named
`[get-analyzer-rules]` — the CLI opens the project itself over IPC. A Studio instance can also
be running with **no project loaded** (`uip rpa instances list` →
`"ProjectDirectory": "(none)"`), which looks like a healthy environment and is not one.

```bash
uip rpa instances list        # is a Studio instance up, and is ProjectDirectory the right project?
uip rpa studio start          # start one and wait until ready, then retry
uip rpa run --project-dir <project> --file-path Main.xaml
```

**3. The command name.** The run used `uip rpa run-file`, which is not a command in 1.204.0 —
it is `run --file-path`. That alone does not explain the error (an unknown command fails
differently), but it does mean the run was on a different CLI version, so re-test on 1.204.0
before trusting the old conclusion.

**Whoever settles this writes the answer here**, and deletes this section.

## The CLI asks you to load the official UiPath skill

Every `uip rpa` invocation prints:

> Before using this tool, make sure you have loaded the **uipath-rpa** skill and read its
> documentation. `uipath-rpa/SKILL.md` is the canonical reference.

That is UiPath's own skill, not one of this repo's. Install it alongside these — it owns
generic activity authoring and the CLI surface; this repo owns the estate's conventions. See
`README.md` → "Official UiPath skills".
