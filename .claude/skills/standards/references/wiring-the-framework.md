# Wiring the Framework from the SDD

`project-layout.md` says what each `Framework/` file *is*. This file says how to **connect** it
to the SDD's transactions. That step was missing, and its absence has a signature failure:

> On the Lanes run, every leaf workflow was authored and looked right, the Framework was left at
> stock, and `Framework/GetTransactionData.xaml`'s `Get Transaction Item` had been replaced with
> a `Log Message`. The job ran green and processed **0 transactions**.

A project with good leaf workflows and an unwired Framework is not 90 % done. It does nothing,
and it does nothing *quietly* — which is worse than failing.

This is a stage in its own right, between "project scaffolded" and "develop leaf workflows". It
is not finished below **L3** on the evidence ladder (`project-scaffolding` skill,
`references/evidence-ladder.md`).

## Wire in this order

Each step depends on the one before it, so do not skip ahead — a `Process.xaml` dispatch built
before `GetTransactionData` yields anything is built against a guess.

| # | File | What wiring it means |
|---|---|---|
| 1 | `Framework/InitAllSettings.xaml` | **Leave stock.** Confirm every SDD config key exists in `Settings`/`Constants`/`Assets`, in both `Config_TST.xlsx` and `Config_PRD.xlsx`. Only the JSON-config decision justifies touching this file. |
| 2 | `Framework/GetTransactionData.xaml` | Yield one transaction per call from the SDD's source — queue, or the non-queue shape below. |
| 3 | `Framework/InitAllApplications.xaml` | Log in to every application the SDD names, via `<App>_System/<App>-Login.xaml`. Credentials from the Orchestrator asset. |
| 4 | `Process.xaml` | Dispatch on transaction type to the right `<App>_System` workflow. Decisions stay in `Logic/`. |
| 5 | `Framework/SetTransactionStatus.xaml` | Map the classified exception to Success / Business / System. |
| 6 | `Framework/CloseAllApplications.xaml` | Close, in reverse order of opening. |
| 7 | `Framework/KillAllProcesses.xaml` | Force-kill the same set. Usually the same body as 6. |

## SDD element → Framework file

| In the SDD | Goes in | What it becomes |
|---|---|---|
| Work-item source (queue, mailbox, folder, workbook) | `GetTransactionData.xaml` | one transaction per call, `Nothing` when exhausted |
| Applications used, and their logins | `InitAllApplications.xaml` | one `<App>-Login.xaml` invoke each |
| Transaction types / process variants | `Process.xaml` | a `Switch` arm per type |
| Per-step UI interaction | `<App>_System/<App>_<Verb>.xaml` | invoked from the `Switch` arm |
| Business rules, validation, mapping | `Logic/Logic-<Name>.xaml` | invoked from the arm, **never** inline in `Process.xaml` |
| Named business exceptions | `Logic/Logic-Classify_Exception.xaml` | `BusinessRuleException` with the application's own text |
| Config keys | `Config_TST.xlsx` + `Config_PRD.xlsx` | `Settings` / `Constants` / `Assets` |
| Credentials | `Assets` sheet → `GetAppCredential` | never a literal, never a fixture file |
| Shutdown / cleanup | `CloseAllApplications.xaml`, `KillAllProcesses.xaml` | reverse of `InitAllApplications` |

## `Process.xaml` dispatch

A `Switch` on the transaction-type column, one arm per type the SDD defines, each arm invoking
the `<App>_System` workflow **with the arguments that workflow declares**. Nothing else:

- **No UI activity directly in `Process.xaml`.** It routes; `<App>_System/` touches the UI.
- **No business rule inline.** If the arm needs to decide something, it invokes a `Logic/`
  workflow. An inline title check in `Process.xaml` that duplicates `Logic-Validate_Title.xaml`
  is the specific smell — it happens when the `Logic/` workflow declares no arguments, so there
  is nothing to call it with. Fix the contract, not the call site.

### Transaction types come from the SDD, never from the test data

The transaction types, and which work-item columns each one reads, are **business definitions**.
Inferring them from whatever columns happen to be populated in a test workbook produces an
automation that matches the fixtures and not the process.

**If the SDD is silent: record an Assumption in the SDD *and* in
`Documentation/Progress.md`, and ask.** Do not pick the reading that makes the test data pass.

The Lanes run shows why. A `Create` needs a lane, and there were three candidate sources:

| Candidate | Why it is wrong |
|---|---|
| A hard-coded config key | Makes every Create go to one lane regardless of the work item |
| `TargetLane` | **Empty on every Create row** in the test workbook — Creates would land nowhere |
| `SourceLane`, falling back to the `Lane_Default` config key | Correct: the work item says where, config says where when the work item does not |

Reading `TargetLane` would have passed a naive inspection and failed every Create at runtime.

## Non-queue sources: read once, hand out one row per call

The full three-part change (`GetTransactionData`, `MaxRetryNumber`, `OrchestratorQueueName`) is
in the `project-scaffolding` skill, under *Non-queue REFramework*. Here, one rule:

> **If a configured source yields 0 transactions, log an `Error` and fail visibly.**

A source that is configured and returns nothing is a defect — a wrong path, an empty queue name,
a filter that matched nothing, a credential that silently failed. "Nothing to do today" and
"I could not find the work" look identical from the outside, and only one of them is fine. Make
the Performer say which:

```vb
' after the first-pass read, before handing out transaction 1
If dt_WorkItems Is Nothing OrElse dt_WorkItems.Rows.Count = 0 Then
    ' Log Message, Error: "Source '<path/queue>' yielded 0 transactions."  then Throw
```

An *empty queue* on a genuinely idle day is the one legitimate zero, and the SDD has to say so
explicitly for it to count.

## Exception mapping

One classifier, in `Logic/`, called from the `Catch` in `Process.xaml`:

| The application… | Throw | `SetTransactionStatus` records |
|---|---|---|
| refused, with a message ("duplicate", "not permitted", "already exists") | `BusinessRuleException`, carrying the application's own text | Business exception — **no retry** |
| was unreachable, timed out, crashed, returned nothing | `ApplicationException` | System exception — retried per `MaxRetryNumber` |
| session expired | `ApplicationException` | System exception, **one** re-initialise |

**One re-initialise on session expiry, not a loop.** Re-login, retry the transaction once; if it
expires again, that is a real failure and must surface. A re-initialise loop turns an
authentication problem into a process that runs all night.

Carry the application's own message text verbatim. A classifier that rewrites it into
"Business rule violated" destroys the only evidence of what the application actually said.

## Credentials

`GetAppCredential` against the Orchestrator asset named in the `Assets` sheet. Fetched **inside
the scope that uses it** — analyzer rule `ST-SEC-008` fails the build otherwise, and
`uip rpa validate` does not catch it (see `silent-failure-traps.md`).

Never from a test-data file, a fixture `.json`, an environment variable, or a literal. Full
rules: the `security` skill.

## Authoring the XAML

Author it with the CLI. Verified against `uip` **1.204.0**:

```bash
uip rpa activities find --query "switch" --project-dir <project>
uip rpa activities get-default-xaml --activity-class-name <FQCN> --project-dir <project>
uip rpa validate --project-dir <project> --min-severity error
```

`get-default-xaml` returns the activity exactly as Studio would drop it in, with real default
values — which is the whole point: it is the difference between the correct XAML and
plausible-looking XAML.

These are **Studio-IPC** commands and need a Studio instance with that project open
(`uip rpa instances list`, `uip rpa studio start`). That is a prerequisite, not a blocker.

**"Needs Studio" is only acceptable with the exact command you ran and the error it returned.**
Without those it is a guess about the tool, and the tool is usually not the problem.

## Reviewing a wired Framework

A checklist says what should be true. This table says **where to look and what a failure looks
like**, because every one of these passes inspection when it is wrong — that is why they are
here rather than in the checklist.

| File | Look for | Wrong looks like |
|---|---|---|
| `InitAllSettings.xaml` | Still stock (unless the SDD chose JSON config) | Edited to "just add one key" — the key belongs in the workbook, not the reader |
| `GetTransactionData.xaml` | A real source call, and the 0-transaction guard | A `Log Message` where `Get Transaction Item` was. Yields `Nothing` on call 1, `Main` goes straight to End, job green, 0 transactions |
| `InitAllApplications.xaml` | One `<App>-Login.xaml` invoke per application the SDD names | Empty, with the login moved into `Process.xaml` — then it re-authenticates per transaction. (UC81 does this deliberately; it is a decision, not a default) |
| `Process.xaml` | A `Switch` on the transaction type, one arm per SDD type | An inline `If` about business meaning, or a UI activity directly in the file |
| `SetTransactionStatus.xaml` | Business vs Application mapped from the classifier; retry and circuit-breaker counters intact | Queue calls removed **along with** the counters, when going queue-less. The circuit breaker goes with them, silently |
| `CloseAllApplications.xaml` | Closes everything `InitAllApplications` opened, in reverse | Closes one application and leaves the rest. The next run's idempotent-login probe then finds a half-open session |
| `KillAllProcesses.xaml` | Force-kills the same set | Empty, or `KillProcess chrome` — which takes down any other automation on the runner |

Two cross-file checks that no single file reveals:

- **Count the applications.** Every application opened in `InitAllApplications` appears in
  **both** `CloseAllApplications` and `KillAllProcesses`. A mismatch leaks a session.
- **Count the transaction types.** Arms in `Process.xaml` == transaction types in the SDD. Fewer
  arms means a type falls through; more means one was invented.

## Done means

- [ ] All seven files in the table wired, and the report names which
- [ ] `Process.xaml` has one `Switch` arm per SDD transaction type, each invoking a `_System`
      workflow — no UI activity and no business rule inline
- [ ] The 0-transaction guard is in place and was observed firing (point the source at nothing)
- [ ] Exceptions classified in `Logic/`, Business vs Application, application text carried
- [ ] Every credential comes from an Orchestrator asset, fetched in its consuming scope
- [ ] Every assumption about a transaction type is written in the SDD and `Progress.md`
- [ ] **L3** reached: Studio opens the project with an empty Error List
