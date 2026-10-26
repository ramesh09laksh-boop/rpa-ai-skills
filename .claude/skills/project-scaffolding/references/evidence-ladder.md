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

## The five rungs

| Level | What it establishes | Command |
|---|---|---|
| **L1** | Estate conformance — static text/workbook rules only | `validate-project.sh` / `validate-project.ps1` |
| **L2** | It compiles and passes the analyzer | `uip rpa validate --min-severity error`, then `uip rpa build` |
| **L2b** | It **packs** — survives the UiRobot packaging step | `uip rpa pack <project> --output-path <dir>` |
| **L3** | Studio opens the project with an **empty Error List** | Studio (human checkpoint) |
| **L4** | A **real job on TST**, started in the Orchestrator folder, on a robot, with the SDD's expected results checked | `uip or jobs start` / Orchestrator |

Rules:

- **State the highest level reached, and the command that proved it.** "L2 — `uip rpa build`
  reported Success" is a report. "Validated" is not.
- **A wiring or "project ready" stage is not done below L3.** L1 and L2 both passed on a
  project Studio could not compile; only L3 caught it.
- **A stage that claims "tested" means L4** — a real job, with job state, logs and the SDD
  acceptance table. A local run of `Main.xaml` is **not** L4; it is L3 evidence.
- **A mocked run reaches L3 at most.** By definition: a mock proves the wiring, not the process.
  See the `standards` skill, `references/mocking.md`.
- **Never write PASS without the level.** A bare PASS is the failure mode this ladder exists to
  stop.

## Why L2b exists separately

Because `validate` and `build` are not the last compile-time gate. Two failures in this repo's
own records pass both and surface only when the package is actually built:

| Fails at pack, passes `validate` | Detail |
|---|---|
| A used `xmlns` prefix whose assembly is missing from `ReferencesForImplementation` | *"Some references are not imported in current workflow… The project has validation errors and cannot be published."* The message **names no file** |
| `ST-SEC-008` — a `SecureString` used outside the scope that fetched it | `pack` runs the analyzer; `validate` does not |

Both are in the `standards` skill, `references/silent-failure-traps.md`. The first took hours to
bisect across a 30-workflow project; `validate-project`'s `xmlns-assembly-unreferenced` rule now
finds it in a second, which is L1 catching an L2b failure — a reason to run the whole ladder
rather than the top of it.

**Do not reach L2b by relaxing the analyzer.** `--ignored-rules`, `--skip-analyze` or a
governance file chosen to make the finding disappear produces a package that packs and a problem
that ships.

## What L4 actually requires

L4 is **not** "it ran on my machine". `uip rpa run` and Studio's Debug drive the *developer's*
session — a different account, a different Windows session, often a different package version
from the one Orchestrator holds. They are L3 evidence.

L4 is a real job, and all six:

1. The package is **published to the feed the Orchestrator folder uses**.
2. A **process** exists in that folder, bound to that package version.
3. The job is **started in that folder** (`uip or jobs start <process-key> --folder-path …`), on
   a **robot**, as the robot's Windows account.
4. **Job state** read back — `uip or jobs get <job-key>` — and it is `Successful`.
5. **Logs** read back — `uip or jobs logs <job-key>` — including every `Warn` and `Error`.
6. The **SDD acceptance table** completed: each SDD step against evidence, application state
   read back independently of the robot's own logs, per-transaction results compared with the
   test data, and **transaction count equal to input count**.

Procedure and the full acceptance table: the `standards` skill, `references/end-to-end-run.md`.

> **A green job that processed 0 transactions is a failure, not an L4 pass.** It is this
> estate's signature silent failure and it satisfies rules 1–5 perfectly.

## The commands, as they actually exist

Verified on this machine 2026-10-26 against **rpa-tool 1.204.2** (host `cli` 1.204.0)
by running `--help` on each. Tool versions move independently of the host — check
`uip tools list`. Earlier names (`run-file`, `get-analyzer-rules`,
`search-templates`, `create-project`, `get-default-activity-xaml`) are absent from
`rpa --help` on this tool version — but note `find-activities` is **not** gone: it lives on
**rpa-legacy-tool 1.204.0** as `uip rpa-legacy find-activities`. Full mapping, with per-rename
confidence: `cli-command-map.md`.

```bash
# L2 — diagnostics. --file-path is relative to the project; omit it for the whole project.
uip rpa validate --project-dir <project> --min-severity error
uip rpa validate --project-dir <project> --file-path Framework/InitAllSettings.xaml

# L2 — compile + analyzer in one step
uip rpa build <project>

# L2b — the packaging step itself
uip rpa pack <project> --output-path <dir>

# L3 evidence only - the developer's own session, not a robot's
uip rpa run --project-dir <project> --file-path Main.xaml --input-arguments in_ENV=TST

# L4 — a real job in the Orchestrator folder, on a robot
uip or packages upload <the .nupkg>
uip or jobs start <process-key> --folder-path "Modern/RAP-Demo"
uip or jobs get <job-key>
uip or jobs logs <job-key> --level Warning
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

L1–L2b are about *this project compiling and packaging*. They say nothing about whether it
does the right thing. L4 is where that is established, and only because it carries the SDD
acceptance table — a job that is `Successful` with **zero** transactions satisfies every
mechanical check and is still a failure. See the `standards` skill,
`references/end-to-end-run.md`, and the `standards` skill, `references/silent-failure-traps.md`.
