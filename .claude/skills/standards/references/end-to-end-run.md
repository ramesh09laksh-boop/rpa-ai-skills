# The end-to-end run — L4-local first, then L4

Everything below L4-local proves the project compiles, packages and opens. It says nothing about
whether the automation *does the work*. Two runs establish that, and they are not
interchangeable:

| | What it is | When |
|---|---|---|
| **L4-local (folder: `<folder>`)** | `pack`, then run **the packed package** with the **UiRobot installed on this machine**, pointed at an Orchestrator folder so the credential asset resolves | **The default.** Do this first, every time. No `uip login` |
| **L4** | A real job, started **in** the Orchestrator folder, on a **robot**, as the robot's own Windows account | The pre-production step. **Ask first** — it authenticates to and changes the tenant |

A local `uip rpa run` or Studio Debug is **neither**. Those execute the *project sources* in
your own session, often at a version no package ever held. That is L3 evidence.

**L4-local is a real rung, and a narrow one.** It runs the same artefact the robot would run, in
a folder context, so it catches what a sources-run cannot: a packaging defect, a missing assembly
reference, an asset that does not resolve, a config key the package does not carry. What it does
**not** prove is in *What L4-local does not prove* below — read that before quoting the level at
anyone.

**Platform:** this estate is **Automation Suite** (self-hosted), not Automation Cloud.

All commands below were taken from `--help` on this machine. `uip` commands: 2026-10-26, against
**rpa-tool 1.204.2** and **orchestrator-tool 1.204.0**. `UiRobot` commands: **2026-11-03**,
against **UiRobot 24.10.25** at `C:\Program Files\UiPath\Studio\UiRobot.exe`. Re-run `--help`
before relying on a flag, and check `uip tools list` — the tools version independently of the
`uip` host.

**Part 1 has since been run, and `--help` was not enough.** Seven `UiRobot execute` runs on
2026-11-04 corrected the `--input` quoting this file had transcribed from the help text, and
established that **the exit code and stdout carry no outcome at all** — Step 2a. Which rows are
read-from-help and which were observed is settled in *What in this file is unverified*; read that
before quoting any of it as fact.

---

## Part 0 — four facts to ask for once, and record

**Ask once, together, at the start — not one question per step.** Record the answers in the
project's own `AGENTS.md` **Environment** block, which is a committed file, so **non-secret facts
only**:

| Fact | Example | Why it is needed |
|---|---|---|
| **UiRobot install path** | `C:\Program Files\UiPath\Studio\UiRobot.exe` | It ships beside Studio, but the path moves with the install type (per-machine vs per-user) and the version. Do not guess it |
| **Orchestrator folder** | `Modern/RAP-Demo` | Passed to the robot so the credential asset resolves. Without it the asset lookup has no folder to look in |
| **Robot user** | the Windows account the robot service runs as | Decides whose desktop session, whose browser profile and whose extension the run uses — the usual cause of "works for me" |
| **Is the robot connected to the Automation Suite Orchestrator?** | yes / no | If **no**, an asset cannot resolve at all and `--folder` cannot mean anything. Say so up front rather than discovering it in an error |

**Never record a credential, an asset *value*, a token or a client secret** in that block, or
anywhere else. The asset **name** is fine — it is an identifier you have to name to wire anything
up.

> **This is not something to probe for.** `UiRobot` has no status verb — the verb list is
> `pack`, `trace`, `pip`, `connect`, `disconnect`, `flushlogs`, `version`, `execute`,
> `installprocess`, `help`. The only commands that would reveal or change the connection are
> `connect` / `disconnect`, and those **rebind the machine's robot service** — firmly on the
> ask-first list (`AGENTS.md`). `UiRobot version` is read-only and safe; it tells you the version
> and nothing about the binding. So: ask.

---

## Part 1 — L4-local: pack, then run the package with the local UiRobot

**No `uip login`, no publish, nothing in the tenant changes.**

### Step 1. Pack (L2b)

```bash
uip rpa pack <project-dir> --output-path <dir>
```

`pack` compiles, validates **and runs the analyzer** — the gate `validate` alone is not. Do not
pass `--ignored-rules` or `--skip-analyze` to get past a finding (`code-quality.md`). Pack from a
**clean checkout at the commit you intend to ship**, or "which version did I run?" has no answer
later.

*(`UiRobot pack <project.json> -o <dir> [-v <version>]` also exists and is the robot's own
packer. Prefer `uip rpa pack`: it is the estate's L2b rung and it runs the analyzer.)*

### Step 2. Run the package, with the folder

Verified from `UiRobot help execute` on 2026-11-03:

```
  -p, --package-id      Package Id of the process to execute (available version will be used).
  -r, --process-name    Name of the process to execute.
  -f, --file            Nupkg or legacy project/workflow file to execute.
  -i, --input           Input parameters in JSON format.
      --folder          The Orchestrator folder path.
      --entry           The entry point path.

  usage: UiRobot execute [--package-id <id> | --process-name <name> | --file <path>]
                         [--input <params>] [--folder <path>] [--entry <entry_point>]
```

**`--folder` exists**, documented as *"The Orchestrator folder path."* — that is what makes the
credential asset resolve. So:

```powershell
# PowerShell. RUN, 7 times, 2026-11-04. This exact quoting.
$pkg = "$env:TEMP\uc01-l4local\DEMO-UC01.GoogleSearchHelloWorld.1.0.0.nupkg"
& "C:\Program Files\UiPath\Studio\UiRobot.exe" execute --file $pkg --input '{"in_ENV":"TST"}'
```

```bash
# Command Prompt / bash take the other quoting, from the tool's own examples. NOT run here.
UiRobot execute --file "<dir>\<Package>.1.0.0.nupkg" --input "{\"in_ENV\" : \"TST\"}"
```

Add `--entry "<EntryPoint>.xaml"` when the package declares more than one entry point.

> **The PowerShell quoting this file used to carry does not work, and that was found by running
> it.** `--input '{\"in_ENV\" : \"TST\"}'` — the tool's own example form, transcribed here from
> the help text — fails immediately:
>
> ```
> === exit code: -1   elapsed: 0.4s ===
> Invalid property identifier character: \. Path '', line 1, position 1.
> ```
>
> PowerShell passes the backslashes through literally and the robot's JSON parser rejects them. In
> PowerShell, single quotes are already literal, so the escapes must come **out**:
> `--input '{"in_ENV":"TST"}'`. That form ran 7 times without complaint. The `bash` form above
> keeps its escapes and is **still unverified** — nothing here ran it.

> **`--file` together with `--folder` is still UNVERIFIED, and seven real runs did not change
> that**, because none of them passed `--folder`. The project under test declares no Orchestrator
> asset (its `Assets` sheet is empty), so there was nothing for a folder to resolve and no honest
> way to exercise the pairing.
>
> 1. **`--file` together with `--folder`.** `--folder` is listed as a general option of
>    `execute`, independent of which selector you use — but every official *example* pairs it
>    with `--package-id` (`UiRobot execute --package-id UiPathDemo --folder "Product/Development/QA"`),
>    and the one `--file` example uses `--entry` instead. **UNVERIFIED.**
> 2. **That `--folder` is what resolves the asset for a `--file` run.** It is the only
>    folder-bearing option, so it is the only candidate — but that is inference from the help
>    text, not an observed asset lookup. **UNVERIFIED.**
>
> So a run without `--folder` is **not** an `L4-local` claim under this file's own definition —
> the folder is in the name for a reason. A project that needs no asset can still be run this way;
> report it as what it was, naming the absent folder, rather than borrowing the rung.
>
> If `--file` + `--folder` turns out not to resolve assets, the documented fallback is to make
> the package known to the robot first and run it by id:
> `UiRobot installprocess --process-name <name> --folder <folder>`, then
> `UiRobot execute --package-id <id> --folder <folder>` — which is the pairing the examples
> show. Record which one worked, with the date, and delete the one that did not.

### What actually ran — and it is one project

Everything in Step 2a and Step 2b below comes from **one project**, and that bound belongs with
the findings rather than under them:

| | |
|---|---|
| **Package** | `DEMO-UC01.GoogleSearchHelloWorld` `1.0.0`, packed with `uip rpa pack` |
| **Robot, 2026-11-04** | **UiRobot 24.10.25** at `C:\Program Files\UiPath\Studio\UiRobot.exe` — 7 runs |
| **Robot, 2026-11-05** | **UiRobot 26.0.204.0** at `C:\Program Files\UiPathPlatform\Robot\26.0.204-cloud.25540\UiRobot.exe` — 2 runs |
| **Project's own pins**, read from the `.nupkg`'s `project.json` | `UiPath.UIAutomation.Activities.Runtime [26.10.4]`, `UiPath.UIAutomation.CLI [26.10.4]`, `UiPath.System.Activities.Runtime [23.10.6]`, `UiPath.Excel.Activities [2.22.4]`, `UiPath.Mail.Activities [1.22.1]`, `UiPath.Testing.Activities [23.10.1]` |
| **`studioVersion`** | `23.10.8.0`, `targetFramework: Windows` |

**The UI Automation version is the one this estate pins for capture — 26.10.4 — confirmed from
the package rather than from the machine**, which matters because it is also the assembly the
`NApplicationCard` property names were read out of (`wiring-the-framework.md`). The thing that
ran and the thing that was inspected are the same version.

> **A robot older than the package it carries ran it anyway.** UiRobot **24.10.25** executed a
> package pinning **UIA 26.10.4** without a load error, across 7 runs. Part 2, prerequisite 1
> says a robot older than a package *"generally fails at load with a type or assembly error"* —
> that remains the expectation to design for, and this is **one** counter-observation on **one**
> project, not a licence to skip the check.

**What this project is not.** One transaction type, one application (a browser), **no Orchestrator
asset**, **no queue**, 1 transaction per run, and no `--folder`. So it exercises packaging, launch,
dispatch, a UI interaction, exception classification and shutdown — and says nothing about asset
resolution, queue retry, the circuit breaker, multiple transaction types, or a thick client. Do
not read a finding below as estate-wide until a second project reproduces it.

### Step 2a. The exit code is not the outcome — read the log

**`UiRobot execute` returned exit code `0` and printed `{}` on a run whose transaction failed.**
It returns exactly the same on a run that succeeded. The exit status carries **no outcome
information at all**, and neither does stdout.

Seven runs of the same package on 2026-11-04, from the same shell, every one of them exit `0`
with stdout `{}`:

| Started | Package | Transaction | `Error` lines | Exit code | stdout |
|---|---|---|---|---|---|
| 16:34:02 | `uc01-l4local` | **`ApplicationException`** | **3** | `0` | `{}` |
| 16:41:26 | `uc01-l4local-2` | **`ApplicationException`** | **3** | `0` | `{}` |
| 16:46:00 | `uc01-l4local-3` | `Success` | 0 | `0` | `{}` |
| 16:54:59 | `uc01-recheck` | `Success` | 0 | `0` | `{}` |
| 16:56:46 | `uc01-final` | `Success` | 0 | `0` | `{}` |
| 17:01:38 | `uc01-sessionfix` | `Success` | 0 | `0` | `{}` |
| 17:04:18 | `uc01-bound` | `Success` | 0 | `0` | `{}` |

Failed and passed are **indistinguishable** from outside the process. So:

> **L4-local reads the execution log. Never `$LASTEXITCODE`, never stdout.**

Anyone wiring CI or a wrapper script to the exit status gets a silent false pass — which is this
estate's signature failure shape, arriving through the one channel that looked mechanical enough
to trust.

**Where the log is:**

```
%LOCALAPPDATA%\UiPath\Logs\<yyyy-MM-dd>_Execution.log
```

One file per day, one JSON object per line after the timestamp and level. The two failed runs
above are in `C:\Users\<user>\AppData\Local\UiPath\Logs\2026-11-04_Execution.log`.

**What the failure looks like in it.** Three `Error` lines per failed run, from three different
files, all carrying the same cause — the activity that failed, the classifier's throw, and the
retry handler recording the transaction status:

```
16:35:12.4983 Error {"message":"Use Application/Browser (Google results): Could not find the UI
  element corresponding to this selector:\r\n<html app='chrome.exe' title='*Google Suche*'
  url='https://www.google.com/search*' />  …","level":"Error","fileName":"Google-Results_Verify",
  "jobId":"35e1a2ab-edcc-4f3f-96fa-368a2ec3d82b","processName":"DEMO-UC01.GoogleSearchHelloWorld"}

16:35:12.5043 Error {"message":"Throw ApplicationException: Could not find the UI element
  corresponding to this selector: …","level":"Error","fileName":"Process", …}

16:35:12.6857 Error {"message":"System exception.Could not find the UI element corresponding to
  this selector: … at Source: Throw ApplicationException","level":"Error","logType":"User",
  "fileName":"RetryCurrentTransaction","logF_TransactionNumber":"1",
  "logF_TransactionStatus":"ApplicationException", …}
```

Elided at `…`: the engine's *"closest matches found"* list, which quotes the titles and URLs of
every other window open at the time — the operator's own browsing. It is not a secret and it is
not needed here, but it does not belong in a committed file.

**The three fields that decide the outcome**, and the only ones worth scripting against:

| Field | Read it for |
|---|---|
| `"level":"Error"` | any error at all. Count them; a passing run has zero |
| `logF_TransactionStatus` | `Success` vs `ApplicationException` / `BusinessException`, per transaction |
| `logF_TransactionNumber` | which transaction, so a 10-of-12 run cannot aggregate away |

And note what the end of a **failed** run looks like, because it reads like a clean finish:

```
16:35:14.0559 Info {"message":"Process finished due to no more transaction data", …}
16:35:14.6188 Info {"message":"DEMO-UC01.GoogleSearchHelloWorld execution ended", …}
```

Both runs ended on those two lines, after the transaction had failed. *"Execution ended"* is not
*"execution succeeded"* — it is the only line stdout would have let you see, and it means nothing.

### Step 2b. `report-execution-log` — read the slice your run appended

The daily log is **shared by every UiPath process on the machine**, so "read the log" needs a
bound. Record its byte length before the run and read only what was appended:

```powershell
$s = '<skills>/project-scaffolding/scripts/report-execution-log.ps1'
$mark = & $s -Mark                                    # byte length now; 0 if the file does not exist yet
& $UiRobot execute --file $pkg --input '{"in_ENV":"TST"}'
& $s -Offset $mark                                    # only what the run appended
```

It prints the process and job id(s), the **per-transaction status table**, and **every Warn/Error
in full** — the selector-failure message is not truncated, because the *"closest matches found"*
list is the part that tells you which window it actually hit.

**It cannot prove which job wrote which line.** An offset bounds the slice in **time**, not by
author: if another robot, or a Studio debug, ran in the same window, its lines are in the slice
too. The script prints every job id it found and says this explicitly when there is more than
one. Check the id is yours before quoting any of it as evidence.

**The exit code is a CI convenience and is deliberately narrow:** non-zero **only** on a faulted
transaction. An `Error` line alone does not fail it — a retried transaction that eventually
succeeds logs errors on the way. The real limitation: **a run that died before reaching a
transaction** — `InitAllSettings`, an asset that did not resolve, a login that never completed —
has no faulted transaction and **exits 0**. The empty transaction table is the signal for that
case, which is why the table is printed first and why this is a reporter rather than a gate.

> **Do not let this become the habit Step 2a exists to break.** Replacing `$LASTEXITCODE` from
> `UiRobot` with `$LASTEXITCODE` from this script is the same mistake with an extra step. Read
> the table.

**Verified end to end on 2026-11-05**, against `UiRobot 26.0.204.0`:

| Case | Result |
|---|---|
| `-Mark` with no log for today yet | `0`, and the run then created the file |
| Run 1 from offset `0` | slice `0..17701`, 1 job id, `1 Success` — exit 0 |
| **Run 2 from offset `17701`** | slice `17701..35401`, **only run 2's job id**, `1 Success` — exit 0. The offset discriminates |
| The 2026-11-04 log from offset `18989` | **2 faulted transactions found** (`ApplicationException`), 6 `Error` lines, 9 job ids → the multi-job caveat printed — **exit 1** |
| Offset past end of file | warns that the log was replaced or truncated, reads from `0` |
| Offset at EOF (nothing appended) | *"Nothing was appended… This is NOT a pass"* — exit 1 |
| Missing log file | *"…This is NOT a pass"* — exit 1 |

> **The install path moved between those two dates, which is the Part 0 warning proving itself.**
> The 2026-11-04 runs used `C:\Program Files\UiPath\Studio\UiRobot.exe` (**UiRobot 24.10.25**).
> By 2026-11-05 that directory was **empty** and the robot was
> `C:\Program Files\UiPathPlatform\Robot\26.0.204-cloud.25540\UiRobot.exe` (**26.0.204.0**).
> Ask for the path; never hardcode it from this file.
>
> **The exit-code finding reproduced on the newer robot**: both 2026-11-05 runs also returned
> exit `0` with stdout `{}`. It is not a quirk of one build.

### Step 3. When it fails on an asset or on folder access — that is a checkpoint

Two failures here are **mine to fix, not yours to work around**:

| Symptom | What to report |
|---|---|
| The asset does not resolve | the **exact error text**, the **asset name** from the `Assets` sheet, and the **folder** you passed |
| The robot user has no access to the folder | the **exact error text**, the **folder**, and the **robot user** from Part 0 |

**Report it, name those things, and carry on with the next item.** Do not retry with a different
folder hoping one sticks, do not fall back to a local credential, and do not substitute a literal
for the asset — each of those turns a five-minute fix into a project that works on one machine.

**Never print an asset value.** Not in a report, a log, a commit, or a chat. The name is the
identifier; the value is the secret. See the `security` skill, and `references/studio-checkpoints.md`
Checkpoint 4 for what I need to do at my end.

### Step 4. Report it as L4-local

Name the level **with the folder in it** — `L4-local (folder: Modern/RAP-Demo)` — plus the
command verbatim, the package file and version, the transaction count processed vs input count,
and every `Warn` and `Error` line. Then complete the acceptance table in Part 4: a run without it
establishes that something executed, not that it was correct.

**Every number in that report comes from the execution log.** The exit code is `0` either way
(Step 2a), so "it exited cleanly" is not evidence of anything and must not appear in the report as
though it were. Quote the log path and the date you read, the way a command would be quoted.

### What L4-local does not prove

Being precise about this is the whole reason it has its own name:

- **Not the unattended service-account session.** It runs as **you**, in **your** interactive
  Windows session, with **your** browser profile and **your** extension. The single most common
  unattended failure — the extension or the session not existing for the service account — is
  invisible here.
- **Not the trigger.** Nothing proves the process starts when it is supposed to.
- **Not permissions beyond that one folder.** It proves your identity's access to the folder you
  named, not the robot account's, and not any other folder's.
- **Not the published artefact.** The package came from your disk, not from the feed the folder's
  robots restore from.
- **Not the Orchestrator job record** — no job key, no queue retry history, no retention trail.

So **L4-local is not L4, and must not be reported as it.** An Orchestrator job — Part 3, **ask
first** — remains the pre-production step.

---

## How the client secret is supplied — and how it is not

*(This section is about `uip login`, which belongs to the **L4** path in Part 3. L4-local needs
none of it.)*

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

## Part 2 — robot prerequisites

These are about the **robot machine**, not your laptop, and that is the whole difficulty: a
project that works in Studio and fails unattended almost always fails on one of these. **This is
the part L4-local cannot reach** — it ran on your machine, as you.

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

### What is scriptable (requires `uip login` against the Automation Suite host — **ask first**)

> **Every command in this block is a `uip or` or `uip rpa remote` command, and every one of them
> authenticates to Orchestrator** — including the pure reads. They are on the ask-first list:
> name the command, say it only reads, and wait. `AGENTS.md`, *Ask before anything that
> authenticates to, or changes, Orchestrator*. `preflight -FolderPath <path>` runs the `uip or`
> reads as a batch, and passing that switch is the asking.

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

## Part 3 — the Orchestrator job (L4) — **ask first**

> **Do not start here, and do not run any of it without asking.** Part 1 (L4-local) comes first
> and needs none of this. Everything below publishes to, or changes, the tenant: `uip login`,
> `uip rpa publish`, `uip or packages upload`, `uip or processes create`, `uip or jobs start`.
> Name the command, say what it changes, and wait — `AGENTS.md`.

### Step 1. Pack (L2b)

Already done in Part 1, Step 1 — **reuse that package**, do not re-pack. Re-packing produces a
different artefact from the one L4-local exercised, and the point of the sequence is that the
same package passes both.

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
| Every `uip` command name and flag above | **Verified** — read from `--help` on this machine, 2026-10-26, rpa-tool 1.204.2 / orchestrator-tool 1.204.0 |
| Every `UiRobot` verb and option in Part 1 | **Verified** — read from `UiRobot --help` and `UiRobot help execute`, 2026-11-03, UiRobot 24.10.25. `UiRobot version` was run (`24.10.25.0`) |
| **`execute --file … --input` — the command itself** | **RUN**, 7 times, 2026-11-04, UiRobot 24.10.25. Packed with `uip rpa pack`, then executed; the log records all seven jobs with `"initiatedBy":"CommandLine"` |
| **The PowerShell `--input` quoting** | **RUN, and corrected.** The form this file carried (`'{\"in_ENV\" : \"TST\"}'`, transcribed from the help) fails with exit `-1` and *"Invalid property identifier character: \\."*. `'{"in_ENV":"TST"}'` works. See Step 2 |
| The **`bash` / Command Prompt `--input` quoting** | **UNVERIFIED** — left as the tool's own example form; nothing here ran it |
| **Exit code `0` and stdout `{}` on a FAILED transaction** | **VERIFIED by observation.** Two runs threw `ApplicationException` on transaction 1 with 3 `Error` lines each and still exited `0` with `{}` — identical to the five passing runs. **Reproduced on UiRobot 26.0.204.0** on 2026-11-05, so it is not a quirk of one build. Step 2a |
| **`report-execution-log`'s `-Mark` / `-Offset` slice** | **VERIFIED on real runs**, 2026-11-05: a second run read from the first run's end offset returned **only the second run's job id**. All seven cases, including the faulted path against the 2026-11-04 log, are tabulated in Step 2b |
| **The `UiRobot` install path in this file** | **STALE BY DESIGN — ask, do not copy.** `C:\Program Files\UiPath\Studio\` was correct on 2026-11-04 and was an **empty directory** on 2026-11-05; the robot had moved to `C:\Program Files\UiPathPlatform\Robot\26.0.204-cloud.25540\`. Part 0, fact 1 |
| **That the execution log is the only outcome source for L4-local** | **VERIFIED** as the consequence of the row above: it is the only channel that distinguished the failed runs from the passing ones |
| The log path `%LOCALAPPDATA%\UiPath\Logs\<date>_Execution.log` | **Verified** — read on this machine; the two failed runs are in `2026-11-04_Execution.log` |
| That `UiRobot` has no connection-status verb | **Verified** — the verb list is `pack`, `trace`, `pip`, `connect`, `disconnect`, `flushlogs`, `version`, `execute`, `installprocess`, `help`. Hence Part 0 asks rather than probes |
| **`--file` together with `--folder`** | **UNVERIFIED — and the seven runs did not touch it.** None passed `--folder`: the project under test declares no asset, so there was nothing for a folder to resolve. `--folder` is a general option of `execute`, but every official example pairs it with `--package-id` |
| **That `--folder` is what resolves the credential asset for a `--file` run** | **UNVERIFIED** — inference from the help text ("The Orchestrator folder path"), not an observed asset lookup |
| That the **L4-local sequence** runs end to end | **PARTLY VERIFIED.** `pack` → `execute --file --input` → read the log ran end to end, 7 times. The **folder half is not verified**, so these were not L4-local claims by this file's own definition — no asset was resolved and none was needed |
| That the **L4 sequence** works end to end | **UNVERIFIED.** Nothing in Part 2 or Part 3 has been executed against a real tenant, folder, feed, robot or job — and under the ask-first rule it must not be, unprompted |
| `rpa remote targets` output shape | **UNVERIFIED** — the `enabled` / `hasCredentials` fields are from its help text, not from a response |
| Whether `--folder-path` on `rpa publish` is sufficient, or `--feed-id` is also needed | **UNVERIFIED** — depends on how the folder resolves its feed |

So: **run Part 1 once against a real folder and correct whatever is wrong**, then mark the
corrected steps verified with the date — starting with the two `--file`/`--folder` rows, which
are the ones the default path depends on and the only part of Part 1 still unwalked.

That is what happened to the rest of Part 1 on 2026-11-04, and it is the argument for doing it:
running the sequence corrected a quoting form that could not have worked, and turned up the exit
code finding, which no amount of reading `--help` would have produced. Part 2 and Part 3 remain
plans derived from the tools' own help rather than procedures someone has walked.

---

## Part 4 — the SDD acceptance table

**This is what makes a run mean anything — at either level.** The steps above prove something
executed; this proves it did the right thing. Fill it in for **L4-local** too: a run reported
without it establishes that the package started, not that the process was correct.

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

**For L4-local**, state all of this or it is not an L4-local claim:

- the level **with the folder in it** — `L4-local (folder: Modern/RAP-Demo)`
- the **command verbatim**, and the **package file and version** that ran
- **transaction count processed vs input count**
- every `Warn` and `Error` line
- the **completed acceptance table** (Part 4), with the application state read back independently
- the four Part 0 facts, as recorded
- that it ran **as your interactive account**, not the robot's — and therefore what it does not
  prove (see Part 1)
- anything still open, as a **named blocker** rather than a caveat

**For L4**, all of the above plus:

- the **job key**, its **state**, and its **duration**
- the **folder path** and the **published package version**
- every `Warn` and `Error` line from the **job log**

If any of those is missing, report the level you actually reached — L4-local, L3, or L2b — and
say what is needed to close the gap. That is a useful report. "It ran fine" is not, and neither
is calling an L4-local run L4.
