# The end-to-end run — L4

**L4 is the only level that proves the automation works.** Everything below it proves the project
compiles, packages and opens. A real job, started in the Orchestrator folder, on a robot, as the
robot's Windows account, against the real application — then read back and checked against the
SDD.

A local `uip rpa run` or Studio Debug is **not** this. It uses *your* session, *your* Windows
account, and often a package version Orchestrator has never seen. That is L3 evidence.

**Platform:** this estate is **Automation Suite** (self-hosted), not Automation Cloud. The
Orchestrator host is the estate's own URL and `uip login` reaches it with `--authority <host>`.
See `decisions.md` §0, and the project's own `AGENTS.md` Environment block.

All commands below were taken from `--help` on this machine, 2026-10-26, against
**rpa-tool 1.204.2** and **orchestrator-tool 1.204.0**. Re-run `--help` before relying on a
flag, and check `uip tools list` — the tools version independently of the `uip` host.

## How the client secret is supplied — and how it is not

`uip login` supports a **non-interactive** sign-in, and the only acceptable way to give it the
secret is **by environment-variable reference**. From `--client-secret`'s own help text:

> *Client Secret or Application Secret. **Use `env.ENV_NAME` to read from an environment
> variable***

So:

```bash
# the secret is set in the shell/CI secret store, and only its NAME is typed
uip login --authority <automation-suite-host> --tenant <tenant> \
          --client-id env.UIPATH_CLIENT_ID \
          --client-secret env.UIPATH_CLIENT_SECRET
```

| | |
|---|---|
| **Do** | pass `env.UIPATH_CLIENT_SECRET` — the CLI reads the variable itself |
| **Do** | let a **person** sign in interactively (`uip login --authority <host>`), which is the normal case |
| **Never** | type the secret inline, as `--client-secret <the-actual-value>`. It lands in shell history, in the process list, and in an agent transcript |
| **Never** | put it in a file in the repo — not `.env`, not a config sheet, not a fixture `.json` |
| **Never** | paste it into a chat, a prompt, an issue or a commit message. An agent must not ask for it and must not accept it if offered |

`--client-assertion` (federated/workload identity) takes the same `env.ENV_NAME` form and avoids
a long-lived secret altogether — prefer it where the platform supports it.

If a sign-in is needed and no variable is set, that is a **human checkpoint**: ask the person to
run `uip login` themselves in their own terminal. Do not route it through an agent's shell.

---

## Part 1 — robot prerequisites

These are about the **robot machine**, not your laptop, and that is the whole difficulty: a
project that works in Studio and fails unattended almost always fails on one of these.

> **Most of this part cannot be verified from a developer machine, and is marked accordingly.**
> Where a check is not scriptable, it is a question for whoever owns the robot — not an
> assumption to carry into the run.

| # | Prerequisite | How to establish it |
|---|---|---|
| 1 | **Robot version supports the highest package versions in `project.json`** | Compare the robot's UiPath version against the dependency pins. A robot older than a package generally fails at load with a type or assembly error, not a clear version message. **Unverified here** — ask the robot owner, or read it in Orchestrator → Machines |
| 2 | **The robot's package source reaches both feeds** — the UiPath activity packages **and** the Swisscom libraries | The robot restores from *its own* configured sources, not yours. A library that restores on your machine can still be missing for the robot. **Unverified here** — this is the robot's NuGet configuration |
| 3 | **Unattended robot with an interactive Windows session** | UI automation needs a real desktop session. A robot configured without one fails on the first UI activity, often as a selector timeout rather than a session error. **Unverified here** |
| 4 | **Browser extension installed for the robot's user/profile** | The extension is per-user and per-browser-profile. Installed for *you* means nothing for the service account. **Unverified here** — a browser step will simply not find its element |
| 5 | **The application is reachable from the robot machine** | Network path, firewall, proxy, certificate, and the host actually resolving. **Unverified here** — reachable from your laptop is not the test |
| 6 | **The robot account has access to the folder, its assets and its queue** | **Scriptable** — see below |
| 7 | **The folder actually has an enabled robot with credentials** | **Scriptable** — `rpa remote targets` reports `enabled` and `hasCredentials` per robot |

### What is scriptable (requires `uip login` against the Automation Suite host)

```bash
uip or folders   list
uip or processes list --folder-path "Modern/RAP-Demo"
uip or assets    list --folder-path "Modern/RAP-Demo"
uip or queues    list --folder-path "Modern/RAP-Demo"
uip or machines  list                                    # robot host definitions
uip or sessions  list                                    # live host connections and their state

# the robot side, as far as it can be reached from here (rpa-tool 1.204.2)
uip rpa remote targets --folder-path "Modern/RAP-Demo"   # the folder's unattended robots:
                                                         #   enabled, hasCredentials
uip rpa remote status                                    # the configured remote connection
```

**`rpa remote targets` is the one that reaches the robot side at all.** Its own help says it
*"lists a folder's unattended robots (enabled, hasCredentials)"*, which settles two of the
prerequisites above that would otherwise be a conversation: whether a robot exists and is
enabled, and whether it has credentials attached. `uip or sessions list` adds whether a host is
actually connected.

`preflight.ps1 -FolderPath <path>` runs the `uip or` checks and reports what is missing. Note
what that proves and what it does not: it confirms the objects exist and that **your** identity
can see them. Whether the **robot's** account can is a folder-role question — `uip or roles list`
and the folder's user assignments.

---

## Part 2 — the run

### Step 1. Pack (L2b)

```bash
uip rpa pack <project-dir> --output-path <dir>
```

`pack` compiles, validates **and runs the analyzer** — the gate `validate` alone is not. Do not
pass `--ignored-rules` or `--skip-analyze` to get past a finding. See `code-quality.md`.

Pack from a **clean checkout at the commit you intend to ship**, or "which version is in TST?"
has no answer later.

### Step 2. Publish to the feed the folder uses

Two routes, both real; they belong to different tools:

```bash
# rpa-tool 1.204.2 - takes a PACKED .nupkg, not a project folder
uip rpa publish <path-to-.nupkg> --folder-path "Modern/RAP-Demo"
#   other flags it accepts: --feed-id, --folder-key, --personal-workspace,
#   --shared-libraries, --allow-any-feed

# orchestrator-tool 1.204.0 - upload straight to the folder's processes feed
uip or packages upload <path-to-.nupkg>
uip or packages versions <package-id>      # confirm the version landed
uip or feeds list                          # which feeds exist, for --feed-id
```

**The feed the folder uses**, not a tenant-wide cloud feed — this is Automation Suite. Prefer
`--folder-path` over `--personal-workspace`: a package in a personal workspace is not visible to
the folder's robots, and that failure looks like a missing process.

### Step 3. Confirm the folder is actually ready

Four things, and a missing one fails the job in a way that reads as a code problem:

| Must exist | Command | If missing |
|---|---|---|
| **Process**, bound to the version you just uploaded | `uip or processes list --folder-path <path>` | `uip or processes create`, or `uip or processes update-version` to move an existing one |
| **Credential asset**, exact name from the `Assets` sheet | `uip or assets list --folder-path <path>` | Create it — **a person, not an agent**, and never paste the value into a chat |
| **Queue** (if the process uses one), byte-identical name | `uip or queues list --folder-path <path>` | Create it. A name mismatch throws nothing and leaves both jobs green |
| **TST config** — `Config_TST.xlsx` has no `[UC-SPECIFIC — replace]` and every key the workflows read | `validate-project` (`config-key-undefined`, `template-default-left`) | Fix before starting; a missing key returns `Nothing` and the run continues with an empty value |

> **There is no `uip or releases` subcommand** in orchestrator-tool 1.204.0. The help prose
> calls a process a *"release binding"*, but the subcommand is **`processes`**: *"runnable
> bindings of packages to folders. Processes are what you execute with `jobs start`."* Other
> `processes` subcommands worth knowing: `get`, `resources` (what the package declares),
> `version-history`, `rollback`, `update-version`.

### Step 4. Start the job

```bash
uip or jobs start <process-key> --folder-path "Modern/RAP-Demo" \
  --input-arguments '{"in_ENV":"TST"}'
```

`--runtime-type Unattended`, `--machine-keys` and `--user-keys` pin *which* robot runs it, which
matters when the folder has more than one. `jobs start` returns the created job(s) with their
keys — keep the key; everything below needs it.

### Step 5. Read the state and the logs back

```bash
uip or jobs get     <job-key>                      # state, input/output arguments
uip or jobs history <job-key>                      # state transitions with timestamps
uip or jobs logs    <job-key> --level Warning      # every Warn and Error
uip or jobs logs    <job-key> --export -d run.csv  # the whole log, for the record
```

`Successful` is necessary and nowhere near sufficient — see Part 3.

### Step 6. Read the queue results (if there is a queue)

```bash
uip or queue-items list --folder-path <path> --queue-name <name> --status Successful
uip or queue-items list --folder-path <path> --queue-name <name> --status Failed
uip or queue-items get-history <item-key>          # retries, per item
```

A Failed item's `Reason` / `Details` is where a Business exception's own message text ends up —
which is why the classifier must carry the application's wording verbatim.

### Driving the robot directly — `rpa remote`

An alternative to starting a job, for *diagnosing* the robot rather than running the process:

```bash
uip rpa remote configure --folder-path "Modern/RAP-Demo" --machine <machine> --robot <robot>
uip rpa remote status
uip rpa remote start                       # bring the session up
uip rpa run --file-path Main.xaml --remote # run/debug ON the configured remote agent
uip rpa remote exec <command>              # run a command on the remote agent
uip rpa remote upload-file / download-file # move a file to or from it
uip rpa remote stop
```

This is how you answer "is the application reachable *from the robot machine*" and "is the
extension installed for the *service account*" without logging into that box — `remote exec`
runs there, not here.

**It is not a substitute for L4.** `rpa run --remote` still runs under the CLI's own
orchestration rather than as an Orchestrator job with a job record, queue results and a
retention trail. Use it to diagnose; use `or jobs start` to establish L4.

## What in this file is unverified

Stated plainly, because the difference matters:

| | Status |
|---|---|
| Every command name and flag above | **Verified** — read from `--help` on this machine, 2026-10-26, rpa-tool 1.204.2 / orchestrator-tool 1.204.0 |
| That the **sequence** works end to end | **UNVERIFIED.** No live Orchestrator session exists on this machine: `uip login status` → `"Status": "Refresh Failed"`. Nothing in Part 1 or Part 2 has been executed against a real tenant, folder, feed, robot or job |
| `rpa remote targets` output shape | **UNVERIFIED** — the `enabled` / `hasCredentials` fields are from its help text, not from a response |
| Whether `--folder-path` on `rpa publish` is sufficient, or `--feed-id` is also needed | **UNVERIFIED** — depends on how the folder resolves its feed |

So: **run this once against TST and correct whatever is wrong**, then mark the corrected steps
verified with the date. Until then, treat the sequence as a plan derived from the tool's own
help rather than a procedure someone has walked.

---

## Part 3 — the SDD acceptance table

**This is what makes it L4.** Steps 1–6 prove a job ran; this proves it did the right thing.

Fill one row per SDD step. `Evidence` must be something a reader can check, not a restatement.

| SDD step | Expected (from the SDD) | Evidence | Pass/Fail |
|---|---|---|---|
| 4.1 Sign in | Session established as the service account | *application* shows the account signed in; job log line | |
| 4.2 Create card for each Create row | N cards exist, in the lane from `SourceLane` | **read back from the application**, N matches the test data | |
| 4.3 Move card | Card is in `TargetLane` | read back from the application | |
| 4.4 Duplicate title | **Business exception**, carrying the app's own message | queue item `Failed`, `Reason` holds the app's text | |

### Five rules, and they are the point

1. **Read the application state back independently of the robot's logs.** The robot logging
   *"card created"* is the robot's opinion. Open the application, or query it, and look. A robot
   that logs success having done nothing is the exact failure this estate keeps hitting.
2. **Compare per-transaction results with the test data.** Not a total — row by row. A run that
   processes 10 of 12 and reports `Successful` is a failure that aggregates away.
3. **Negative-data rows must produce the expected Business exceptions.** A negative row that
   *succeeds* is worse than one that fails: it means a refusal the process should have honoured
   was not. Expected-vs-actual, per row.
4. **No `[MOCK]` and no `TODO_SELECTOR` anywhere.**
   ```bash
   grep -rl "\[MOCK\]\|TODO_SELECTOR\|APPROX_SELECTOR" --include="*.xaml" .
   ```
   must return nothing. `validate-project` enforces both (`unresolved-mock`, `unresolved-todo`).
   A mocked run is **L3 at most** — `mocking.md`.
5. **Transaction count == input count.** State both numbers in the report.

> **A `Successful` job that processed 0 transactions is a failure.** It satisfies every
> mechanical check in Part 2 and is this estate's signature silent failure. Zero is only
> acceptable if the SDD explicitly says an empty source is a valid outcome, and it must be said
> there rather than assumed here. `silent-failure-traps.md`.

---

## Reporting it

State all of this, or it is not an L4 claim:

- the **job key**, its **state**, and its **duration**
- the **package version** that ran, and the **folder path**
- **transaction count processed vs input count**
- every `Warn` and `Error` line from the log
- the **completed acceptance table**, with the application state read back independently
- anything still open, as a **named blocker** rather than a caveat

If any of those is missing, report the level you actually reached — L3, or L2b — and say what is
needed to close the gap. That is a useful report. "It ran fine" is not.
