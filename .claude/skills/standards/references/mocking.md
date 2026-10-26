# Mocking — allowed, bounded, and never silent

Building against an application you cannot reach is normal in this estate: no test tower, no
credentials, a Performer whose upstream source does not exist yet. Standing still is not the
answer; neither is a mock nobody can find afterwards.

Two rules make the difference, and the second is the one that gets skipped:

1. **A mock must be visible.** Marked `[MOCK]` in the DisplayName *and* the annotation.
2. **A mocked run reaches L3 at most.** Never L4. A mock proves the *wiring*, not the process.

## Mark it `[MOCK]`, in both places

```
DisplayName:  [MOCK] Read work items from TestData.xlsx
Annotation:   [MOCK] Stands in for the real source, which is Open Question Q4 in the SDD.
              Replace with the real source before the end-to-end run. Owner: <name>.
```

The DisplayName makes it visible on the Studio canvas; the annotation
(`sap2010:Annotation.AnnotationText`) makes it greppable in the `.xaml`:

```bash
grep -rl "\[MOCK\]" --include="*.xaml" .
```

That one command is the whole point. A stand-in that is only obvious to the person who wrote it
is indistinguishable from finished work a week later — which is exactly how a `Log Message`
ended up where `Get Transaction Item` should have been, on a project that then ran green on
**zero** transactions.

Same discipline, same reasons, as `TODO_SELECTOR` / `APPROX_SELECTOR` in the
`pdd-sdd-scaffolding` skill. The marker is not an apology; it is the handover.

## What may be mocked, and what may not

| Mockable | Why it is safe |
|---|---|
| The **work-item source** — a `TestData.xlsx` standing in for a queue, mailbox or API | The shape is what the Framework needs; the origin is a config key |
| A **downstream notification** — writing the mail body to a file instead of sending it | Prevents a test run mailing external parties, which is the worse failure |
| A **read-only lookup** whose service is unavailable | Returns a fixed row; the caller's logic is unchanged |

| **Not** mockable | Why |
|---|---|
| **The application under automation** | Mocking it means you have tested nothing. This is what `TODO_SELECTOR` is for — leave the step unresolved and say so |
| **A credential** | Never. No literal, no fixture file, no "temporary" placeholder. The `security` skill |
| **`SetTransactionStatus` / the queue calls** | Stubbing these removes the retry and circuit-breaker counters with them, silently |
| **A test result** | A mocked run does not make a test case pass. See below |

## A mocked run is L3, never L4

On the evidence ladder (`project-scaffolding` skill, `references/evidence-ladder.md`):

- **L3** — Studio opens the project with an empty Error List. A mocked run can support this.
- **L4** — a real job on TST, started in the Orchestrator folder, on a robot, against the real
  application. **A mock cannot reach it**, by definition.

So: *"ran successfully with the source mocked"* is an L3 claim and must say so. Reporting it as
L4 is the failure this whole ladder exists to stop, because the next person reads L4 as "it
works against the real thing".

And the floor under both: a run that processed **0 transactions** is not a pass at any level.

## Removing a mock is a tracked item, not tidy-up

Every `[MOCK]` is an open item in `Documentation/Progress.md` with an owner, and every one is
gone before the end-to-end run:

- [ ] `grep -rl "\[MOCK\]" --include="*.xaml" .` returns **nothing**
- [ ] No `TODO_SELECTOR` / `APPROX_SELECTOR` left
- [ ] The config key that pointed at the stand-in (`WorkItem_Source` and friends) points at the
      real source, in **both** `Config_TST.xlsx` and `Config_PRD.xlsx`
- [ ] The Open Question the mock stood in for is answered in the SDD, not quietly closed by the
      fixture

An unreplaced `[MOCK]` **blocks review**, the same way an unreplaced
`[UC-SPECIFIC — replace]` or an unresolved `TODO_SELECTOR` does. See
`end-to-end-run.md` for where this is checked.
