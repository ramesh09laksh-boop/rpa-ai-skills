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

## A Framework wired to stubs is a skeleton, not a process

Wiring is necessary and is not sufficient. The mirror image of the Lanes failure is just as
quiet: a Framework correctly wired — a real `Get Transaction Item`, a `Switch` with one arm per
transaction type, every arm invoking the right `_System` workflow — where the invoked workflows'
**bodies** are a `Log Message` each. Transactions are read, dispatched, marked Successful, and
nothing happens in the application.

That shape passes everything: it compiles, `uip rpa validate` and `build` are clean, the
analyzer is clean, it packs, and it runs. Studio's Error List is empty. Even a job in the
Orchestrator folder goes green with a non-zero transaction count — so it clears **L4** on the
transaction count alone. The only checks that catch it are reading the application state
independently of the robot's logs (`references/end-to-end-run.md`) and
`validate-project`'s **`leaf-body-stub`** rule, which reports a leaf workflow whose body
contains no activity that does the step. It is a warning mid-build and an **error** under
`--uat-readiness` / `-UatReadiness`: a stub is honest work in progress and is not shippable.

So: **wired** is a statement about `Framework/`. **Done** is a statement about `Framework/`
*and* the bodies behind it, which is what `Documentation/Leaf_Ledger.md`'s *body real* column
records (`references/leaf-ledger.md`).

### Stage 3 stays "wired, gate open" until the 0-transaction guard has been observed

Do not report stage 3 as done on the strength of the files looking right. The gate is the guard
**firing**, not the guard existing:

- Point the configured source at nothing — a queue with no items, a path that matches no file —
  and **watch it fail**. An `Error` log and a thrown exception, not a green finish.
- Then put the source back.

**This needs a run, and a run needs the Orchestrator asset** (`InitAllSettings` resolves every
`Assets` row at startup, so the credential has to exist before anything executes). That is a
human checkpoint, not something to work around: the `standards` skill,
`references/studio-checkpoints.md`, Checkpoint 4. Until it has been observed, report stage 3 as
**"wired, gate open — 0-transaction guard not yet observed, blocked on <the asset>"** and carry
on with the next stage. Do not write it up as done, and do not substitute "the guard is in the
XAML" for having seen it fire.

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
| 6 | `Framework/CloseAllApplications.xaml` | Close, in reverse order of opening — **only the instances this run opened**. |
| 7 | `Framework/KillAllProcesses.xaml` | Force-close the same set, by the same instance identity. Usually the same body as 6. |

Steps 3, 4, 6 and 7 all touch the same application instance, and **which instance** is a wiring
decision in its own right. It has its own section, immediately below, because getting it wrong
produces the worst defect this estate has recorded.

## Carrying the application instance between workflows

**REFramework splits work across workflows; the modern Application Card is a scope that cannot
span them.** So every leaf after the first re-attaches — and a selector screen identifies the
*application*, never the *instance*. A card attached by selector alone takes whichever matching
window it finds first, which may be the operator's.

> On the Google run, a Performer with a clean `validate-project`, a clean `uip rpa validate`,
> `build` and `pack`, an empty Studio Error List and a `Successful` L4-local run with 1
> transaction of 1 **opened its own browser window, drove the operator's, and then closed a
> window it had never opened.** Every gate stayed green. The only reason it was found is that a
> person was watching their own screen at the time.

The automation was not confused about *what* application to drive. It was never told *which copy*.

### The contract

`<App>-Open` publishes the instance; `Main.xaml` holds it; every downstream card binds it.

| Where | What it does |
|---|---|
| `<App>_System/<App>-Open.xaml` | The card that **opens** the application declares `OutUiElement`, published as `out_<App>Element` |
| `Framework/InitAllApplications.xaml` | Passes it up as `out_<App>Element` |
| `Main.xaml` | Holds it for the whole run, in one variable |
| `Framework/Process.xaml` → each `<App>_System` leaf | Threads it down as `in_<App>Element`; **every** card binds `InUiElement` |
| `Framework/CloseAllApplications.xaml`, `KillAllProcesses.xaml` | Take it as `in_<App>Element` and close **that** instance, guarded on `IsNot Nothing` |

The element is a `UiElement`, so the arguments are typed
`OutArgument(ui:UiElement)` / `InArgument(ui:UiElement)`, with `ui` bound to
`http://schemas.uipath.com/workflow/activities`.

### The property names, and where they come from

`OutUiElement` is declared on `NApplicationCard` itself. **`InUiElement` is not** — it is
inherited from `RecoverableNativeActivity`, which is why it does not show up when you list the
card's own members and is easy to conclude does not exist. Both are settable as attributes on
`<uix:NApplicationCard>`:

| | Declared on | Verified |
|---|---|---|
| `OutUiElement` | `UiPath.UIAutomationNext.Activities.NApplicationCard` | **Verified** |
| `InUiElement` | `UiPath.UIAutomationNext.Activities.RecoverableNativeActivity` (base of `NApplicationCard`) | **Verified** |

Method, 2026-11-05: assembly metadata of
`UiPath.UIAutomation.Activities.Runtime 26.10.4`,
`lib/net6.0-windows7.0/UiPath.UIAutomationNext.Activities.dll` — type definitions, their declared
properties and the `NApplicationCard` base chain, read directly rather than inferred. The three
mode enums come from `UiPath.UIAutomationNext.dll` in the same package:

| Enum | Values |
|---|---|
| `NAppOpenMode` | `Never`, `IfNotOpen`, `Always` |
| `NAppCloseMode` | `Never`, `IfOpenedByAppBrowser`, `Always` |
| `NAppAttachMode` | `ByProcessName`, `ByInstance`, `SingleWindow` |

`uip rpa activities get-default-xaml --activity-class-name UiPath.UIAutomationNext.Activities.NApplicationCard`
is the other way to read this, and the one to prefer when a Studio instance has the project open —
it returns the card exactly as Studio would drop it in. It was **not** the source here: it is a
Studio-IPC command and needs a Studio instance holding *that* project, which this check did not
have. Both routes should agree; if they ever do not, the package the robot runs wins.

### The shape, per role

Three roles, three settings. This is the shape that ran green **and** left the operator's windows
alone:

| Role | `OpenMode` | `CloseMode` | Element binding |
|---|---|---|---|
| `<App>-Open` | `Always` | `Never` | `OutUiElement="[out_<App>Element]"` |
| Every working leaf | `Never` | `Never` | `InUiElement="[in_<App>Element]"` |
| `<App>-Close`, `<App>-Kill` | `Never` | `Always` | `InUiElement="[in_<App>Element]"` |

`AttachMode="ByInstance"` throughout — it is the mode that means "this instance", as against
`ByProcessName`, which means "anything running that executable".

`CloseMode="Never"` on the opening card is what lets the session outlive the workflow that
created it; the run would otherwise lose the application at the end of `<App>-Open`.

### Close only what this run opened

`CloseAllApplications` and `KillAllProcesses` are where an unbound card does its real damage: a
close is irreversible, and the window it closes may be someone's work.

Two mechanisms exist, and only one of them works here:

| | What it does | Use it? |
|---|---|---|
| `CloseMode="IfOpenedByAppBrowser"` | The card closes the application on scope exit **only if that card opened it** | **No** — not across workflows. The card that opened the application is in `<App>-Open`, and its scope ended there. The shutdown workflow's card did not open anything, so this closes nothing |
| `InUiElement` + `CloseMode="Always"`, guarded | The shutdown card attaches to **the instance handed to it** and closes that one | **Yes.** It is the only form that survives the workflow split |

So both shutdown workflows look like this:

```xml
<!-- Framework/CloseAllApplications.xaml, and KillAllProcesses.xaml -->
<If Condition="[in_BrowserElement IsNot Nothing]" DisplayName="Only if this run opened a session">
  <If.Then>
    <uix:NApplicationCard AttachMode="ByInstance" OpenMode="Never" CloseMode="Always"
                          InUiElement="[in_BrowserElement]" Version="V2"> … </uix:NApplicationCard>
```

**The `IsNot Nothing` guard is load-bearing, not defensive padding.** Stock `Main.xaml` invokes
`KillAllProcesses` **before** anything is opened, on the first pass. At that moment the element
is `Nothing`; an unguarded card falls back to attaching by selector and force-closes the first
matching window on the machine — which on the first pass can only ever be somebody else's. The
guard turns the first-pass invocation into a no-op, which is what it should always have been.

- **Never close by process name.** `KillProcess chrome` takes down every Chrome on the runner:
  other automations, and real people. This rule predates the section and is unchanged — the
  instance element is what makes it *keepable*, since it gives the shutdown workflow something
  precise to close instead.
- **A PID is not available here, and reaching for one is the wrong turn.** `NApplicationCard`
  publishes a `UiElement` and no process id, and `UiElement` exposes none. An `Int32` PID
  threaded through the Framework is a contract that cannot be honoured; `InUiElement` is the
  supported equivalent and carries strictly more information.
- **A session leaked by a previous crashed run is not force-closed**, because this run never
  attached to it. That is a deliberate limitation, not an oversight: finding it would mean
  matching by process name. If leaked sessions become a real problem, persist the instance
  identity across runs — do not widen the kill.

### Reviewing it

`validate-project`'s **`card-instance-unbound`** rule reports an Application Card in an
`<App>_System/` workflow with no `InUiElement` bound, carving out the one card per application
that legitimately opens it — the one that declares `OutUiElement`. It is a **warning**, for the
same reason the other leaf-contract rules are.

What the rule cannot see, and a reviewer must:

- **The thread is continuous.** `out_` on `InitAllApplications` → a variable in `Main.xaml` →
  `in_` on `Process.xaml`, `CloseAllApplications` and `KillAllProcesses`. A card that binds
  `InUiElement` to an argument nobody populates binds it to `Nothing`, which is the unbound case
  with extra steps.
- **One element per application.** Two applications means two arguments, not one reused.
- **The guard is on both shutdown workflows**, not just the graceful one.

**And watch your own screen during the first run.** This defect is invisible in the logs — the
robot reports every step as successful, because from its point of view every step *was*. Have the
application open in a window the automation has no business touching, and see that it is still
there afterwards. That is the only check that catches it directly.

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

Author it with the CLI. Verified against **rpa-tool 1.204.2**, 2026-10-26:

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
| `CloseAllApplications.xaml` | Closes everything `InitAllApplications` opened, in reverse, **bound to `in_<App>Element`** | Closes one application and leaves the rest. The next run's idempotent-login probe then finds a half-open session. Or: a card with no `InUiElement`, which closes whichever window matched first — possibly the operator's |
| `KillAllProcesses.xaml` | Force-closes the same set, by the same instance, guarded on `IsNot Nothing` | Empty, or `KillProcess chrome` — which takes down any other automation on the runner. Or unguarded, so the first-pass invocation force-closes a stranger's window |

Three cross-file checks that no single file reveals:

- **Count the applications.** Every application opened in `InitAllApplications` appears in
  **both** `CloseAllApplications` and `KillAllProcesses`. A mismatch leaks a session.
- **Follow the instance element end to end.** `<App>-Open`'s `OutUiElement` →
  `InitAllApplications`'s `out_` → a `Main.xaml` variable → `in_` on `Process.xaml` and both
  shutdown files → `InUiElement` on every card. A break anywhere leaves a card attaching by
  selector, and nothing fails. See *Carrying the application instance between workflows*.
- **Count the transaction types.** Arms in `Process.xaml` == transaction types in the SDD. Fewer
  arms means a type falls through; more means one was invented.

## Done means

- [ ] All seven files in the table wired, and the report names which
- [ ] `Process.xaml` has one `Switch` arm per SDD transaction type, each invoking a `_System`
      workflow — no UI activity and no business rule inline
- [ ] The 0-transaction guard is in place **and was observed firing** (point the source at
      nothing). Until then the stage is *"wired, gate open"*, not done — and the report says what
      it is blocked on
- [ ] No `leaf-body-stub` finding on a workflow the Framework dispatches to. A wired Framework
      over stub bodies is a skeleton, not a process
- [ ] **The application instance is threaded**: `<App>-Open` publishes `OutUiElement`, `Main.xaml`
      holds it, every downstream card binds `InUiElement`, and both shutdown workflows close
      **that** instance under an `IsNot Nothing` guard. No `card-instance-unbound` finding
- [ ] **A window the automation had no business touching was open during the first run, and was
      still open afterwards.** The logs cannot show this
- [ ] Exceptions classified in `Logic/`, Business vs Application, application text carried
- [ ] Every credential comes from an Orchestrator asset, fetched in its consuming scope
- [ ] Every assumption about a transaction type is written in the SDD and `Progress.md`
- [ ] **L3** reached: Studio opens the project with an empty Error List
