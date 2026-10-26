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

## The CLI asks you to load the official UiPath skill

Every `uip rpa` invocation prints:

> Before using this tool, make sure you have loaded the **uipath-rpa** skill and read its
> documentation. `uipath-rpa/SKILL.md` is the canonical reference.

That is UiPath's own skill, not one of this repo's. Install it alongside these — it owns
generic activity authoring and the CLI surface; this repo owns the estate's conventions. See
`README.md` → "Official UiPath skills".
