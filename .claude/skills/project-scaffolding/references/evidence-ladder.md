# The evidence ladder — what "it works" is allowed to mean

`validate-project` printing **PASS** does not mean the project works. It is a *static
conformance checker*: it reads text and workbook cells and asserts this estate's own rules
(no stock queue name, circuit breaker enabled, `ShouldMarkJobAsFaulted` true, no unreplaced
`[UC-SPECIFIC — replace]`). It does not compile anything, does not open Studio, and does not
run a single activity.

That gap is not theoretical. On the Lanes run, all three of these were true at the same moment:

- `validate-project` reported **PASS**
- `uip rpa build` reported **Success**
- Studio showed a compile error in `Framework/InitAllSettings.xaml` —
  `BC31424: System.Data.DataRow … forwarded to System.Data.Common` — and **every** workflow run
  failed with *"The workflow cannot be found"*

So a report that says "validated" without saying *at which level* is not a report. Name the
level and the command.

## The four levels

| Level | What it establishes | Command |
|---|---|---|
| **L1** | Estate conformance — static text/workbook rules only | `validate-project.sh` / `validate-project.ps1` |
| **L2** | It compiles and passes the analyzer | `uip rpa validate --min-severity error`, then `uip rpa build` |
| **L3** | Studio opens the project with an **empty Error List** | Studio (human checkpoint) |
| **L4** | A real run of `Main.xaml` on TST, with a log excerpt | Studio, or `uip rpa run` |

Rules:

- **State the highest level reached, and the command that proved it.** "L2 — `uip rpa build`
  reported Success" is a report. "Validated" is not.
- **A wiring or "project ready" stage is not done below L3.** L1 and L2 both passed on a
  project Studio could not compile; only L3 caught it.
- **A stage that claims "tested" means L4.** No log excerpt, no L4.
- **Never write PASS without the level.** A bare PASS is the failure mode this ladder exists to
  stop.

## The commands, as they actually exist

Verified against `uip --version` **1.204.0** by running `--help` on each. The older
documented names (`run-file`, `get-analyzer-rules`, `search-templates`, `create-project`,
`find-activities`, `get-default-activity-xaml`) are **not** commands in this version — see
`cli-command-map.md`.

```bash
# L2a — diagnostics. --file-path is relative to the project; omit it for the whole project.
uip rpa validate --project-dir <project> --min-severity error
uip rpa validate --project-dir <project> --file-path Framework/InitAllSettings.xaml

# L2b — compile + analyzer in one step
uip rpa build <project>

# L4 — a real run
uip rpa run --project-dir <project> --file-path Main.xaml --input-arguments in_ENV=TST
```

### Two traps in those commands

**`validate`, `run`, `activities` and `analyzer-rules` drive Studio over IPC.** The tool
describes itself as *"creating and managing UiPath RPA projects via Studio IPC"*, and every one
of these carries `--project-dir <path>` — *"Project directory to match against running Studio
instances"*. They need a Studio instance with **that** project open:

```bash
uip rpa instances list          # which Studio instances are running, and their status
uip rpa studio start            # start one and wait until ready
```

`analyze`, `build`, `pack` and `restore` are the other family — they take a positional
`project-dir` and do not need Studio open.

**`uip rpa validate` is not a superset of the analyzer.** Two known cases where `validate`
passes clean and a later step fails: a declared `xmlns` assembly with no matching
`<AssemblyReference>` (fails the UiRobot pack), and `ST-SEC-008` SecureString scope (fails
`pack`). Both are in the `standards` skill, `references/silent-failure-traps.md`. L2 is
`validate` **and** `build`, never `validate` alone.

## Where this does not reach

L1–L4 are about *this project compiling and running*. They say nothing about whether it does
the right thing — that is the test suite and the SDD traceability check, and a green L4 on a
Performer that processed **zero** transactions is a known silent failure, not a pass. See the
`standards` skill, `references/silent-failure-traps.md`.
