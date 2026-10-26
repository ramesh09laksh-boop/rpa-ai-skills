# Human checkpoints — what only a person can do

Some steps need a human at a screen. On a real run, "needs Studio" repeatedly ended an agent's
work with nothing the person could act on — no command, no error, no instruction.

This file is the other half of that. For each checkpoint: the exact steps, what *good* looks
like, and **what to paste back**. An agent that reaches one of these should name the checkpoint
and stop asking for anything else.

**Rule for the agent:** "needs Studio" is only acceptable with **the exact command you ran and
the error it returned**. Many steps that feel like they need a human do not — `uip rpa validate`,
`run` and `uia` need a Studio *session*, which `uip rpa studio start` provides. That is a
prerequisite, not a checkpoint.

---

## Checkpoint 1 — open the project and read the Error List (L3)

**When:** after scaffolding, and after wiring the Framework. A wiring stage is **not done**
below this.

**Why a person:** this is the only check that catches a project which passes
`validate-project` **and** `uip rpa build` and still does not compile. That exact combination
happened: both reported success while Studio showed
`BC31424: System.Data.DataRow … forwarded to System.Data.Common`.

**Steps**

1. Open UiPath Studio.
2. **Open** → the project folder (the one containing `project.json`).
3. Wait for the dependency restore to finish — the status bar stops moving.
4. Open the **Error List** panel (`View` → `Error List`, or Ctrl+\, E).
5. Set the filter to show **Errors and Warnings**.

**Good looks like:** zero errors. Warnings are allowed, but read them.

**Paste back**

- the **full text of every error row**, including the file name and line
- if restore failed: the unresolved package name and version
- if nothing is wrong, just: *"Error List empty, N warnings"* and the warning text

---

## Checkpoint 2 — run `Main.xaml` on TST (L4)

**When:** before claiming anything is tested. "Tested" means this, with a log excerpt.

**Before you start:** confirm you are on **TST**. Never PRD without named approval.

**Steps**

1. In Studio, with the project open, check the run configuration passes `in_ENV = TST`.
2. **Debug** → **Start** (or Run, if you do not want to step).
3. Let it run to the end. Do not stop it early — the Framework's End state is part of the test.
4. Open the **Output** panel.

**Good looks like:** the process initialises, processes **at least one** transaction, and ends
without an unhandled exception.

> **A green run that processed zero transactions is not a pass.** It is the estate's signature
> silent failure. If the log says 0 transactions, that is a finding, not a success — see
> `silent-failure-traps.md`.

**Paste back**

- the Output panel from `Initialization` to the final state — or, if it is long, the first 20
  lines, the last 20, and **every** `Warn` and `Error` line
- the **transaction count** the log reports
- the full exception text and stack trace of anything that failed

---

## Checkpoint 3 — the Orchestrator job, queue and logs

**When:** after publishing to TST, and at UAT.

**Steps**

1. In Orchestrator, go to the **folder** the process is deployed to.
2. **Automations** → **Processes** — confirm the process exists and its package version.
3. **Queues** — find the queue by name. Check **New**, **In Progress**, **Successful**,
   **Application Exception** and **Business Exception** counts.
4. **Automations** → **Jobs** — find the run. Note its state and duration.
5. Open the job and read its **Logs**.

**Good looks like:** the job is `Successful`, the queue shows items moving to `Successful`, and
Business exceptions (if any) are ones the SDD predicts.

> **Check the queue name matches the one in both `Settings` sheets, character for character.**
> A mismatch is the failure that throws nothing: the Dispatcher fills one queue, the Performer
> polls another, and **both jobs go green**. If the Dispatcher succeeded and the Performer
> processed nothing, check this first.

**Paste back**

- job state, duration, and the package version it ran
- the five queue counts above, and the **exact queue name** as Orchestrator shows it
- for any failed item: its `Reason` and `Details`

---

## Checkpoint 4 — a credential or an asset

**When:** `InitAllSettings` fails on an `Assets` row, or a login fails.

**Why a person:** an agent must never be given a credential, and must never create one. This
checkpoint exists so it can ask correctly instead of working around the problem.

**Steps**

1. In Orchestrator, **Assets** in the right folder.
2. Confirm the asset **exists**, with the **exact name** from the `Assets` sheet.
3. Confirm its **type** (Credential vs Text) and that it is scoped to the robot/machine that runs.
4. If it does not exist, create it — **you**, not the agent — and set the value yourself.

**Paste back:** the asset name, its type, and the folder. **Never the value.**

---

## Checkpoint 5 — live selector capture

**When:** resolving `TODO_SELECTOR` markers.

**Why a person:** the application has to be open, reachable and signed in, on an environment and
account you are authorised to use.

**Steps**

1. Run preflight against the project: `scripts/preflight.sh <project>` (the
   `project-scaffolding` skill). Fix anything it flags — especially the 26.10.4 capture pin.
2. Open Studio with the project, so the Studio-IPC commands have a session.
3. Sign in to the target application yourself, in the browser the capture will drive.
4. Hand over: *"signed in, on screen X, go ahead"*.

**Paste back:** which screen is showing, and anything unusual — a consent banner, an MFA prompt,
a stale session warning.

**Never paste the credential**, and never paste a screenshot of a logged-in banking session —
those contain customer data (`prohibited-practices.md`).

---

## What an agent should say when it reaches a checkpoint

Not "this needs Studio". This:

> **Checkpoint 1 — Studio Error List.** I have reached L2: `uip rpa build` reports Success
> (command: `uip rpa build ./UC99_Thing`). L3 needs you.
> Please open `./UC99_Thing` in Studio, let the restore finish, open the Error List, and paste
> back every error row with its file name — or "empty" if there are none.
> Meanwhile I am continuing with <the next item that does not depend on this>.
