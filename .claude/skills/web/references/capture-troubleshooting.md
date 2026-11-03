# Capture troubleshooting

What goes wrong during a `uip rpa uia` capture run, and what fixed it. Derived from a capture
run against a single-page web application outside this estate's three known surfaces — the loop
in `SKILL.md` worked unchanged, but these five things cost real time and none of them is
app-specific.

Application URLs, team identifiers, account names and element ids are deliberately absent. The
shapes are the transferable part.

## 0. The version precheck — do this before anything else

```bash
# read project.json FIRST
UiPath.UIAutomation.Activities   must be 26.10.4
UiPath.UIAutomation.CLI          must be 26.10.4   (the same version)
```

If either package is missing, differs from `26.10.4`, or the two differ **from each other**, fix
it and restore *before* any capture command. A mismatch makes `uip rpa uia` list **zero
subcommands**, which reads exactly like the CLI being unavailable or not installed — you will
spend the next twenty minutes debugging the wrong thing.

Verified case: a project on the estate's standard Studio 23.10 shipped
`UiPath.UIAutomation.Activities 23.10.13`, which is below the minimum `uip rpa uia` needs
(`UiPath.UIAutomation.CLI 26.4.1-preview` or newer). Both packages were raised to `26.10.4`
together and capture then worked. Note what that project then looked like:
`studioVersion 23.10.8.0` with UIA at `26.10.4` — the project diverges from the templates, and
whether that is the intended steady state is **an open question for the team**, not something to
settle silently per project.

## 1. A stale URL makes the registration gate reject every selector

**Symptom.** After the application navigates on its own — a post-sign-in redirect, a client-side
route change in a single-page app — the capture flow derives a **window** selector whose `url`
attribute is the **previous** page. Every element it then gates against that window fails,
because it is matching inside a window that is not the one on screen.

It looks like the selectors are wrong. They are fine; the window is wrong.

**Cause.** The browser extension's cached navigation state, not a tool bug. The tab reference you
captured before the redirect still resolves, so nothing errors — it just describes the old page.

**Fix, in this order — all four steps, or it comes back:**

1. **Navigate explicitly** with the interaction CLI, even though the page is already showing the
   right thing. The point is not to move the browser; it is to make the extension re-read where
   it is.
2. **Let it settle** — a couple of seconds.
3. **Take a fresh top-level snapshot.** This yields a **new** tab ref. Use the new one; the old
   ref still resolves and still describes the old page, which is the whole trap.
4. **Use a fresh work folder**, then re-run the capture flow for this screen.

Exact command names come from the UIA package's own `ui-automation-guide.md` (co-versioned with
the package), reached via the `web` skill, *The loop*.

Do not skip the explicit `navigate` because the page is already showing the right thing. The
point is not to move the browser; it is to make the extension re-read where it is.

## 2. One fresh work folder per screen

A leftover `window.xaml` from a previous screen in the work folder will be picked up and silently
reused, and you will harden selectors against the wrong window.

```bash
W="<project>/.local/.uia/<screen-name>"
rm -rf "$W" && mkdir -p "$W"
```

A folder per screen, created empty. Not one folder for the whole capture session.

## 3. Commit every 2–3 screens — then keep going

Capture is long, stateful and easy to lose. A run that captures eight screens and dies on the
ninth leaves nothing behind that the next run can resume from. So checkpoint often.

**The checkpoint is a commit, not a stop.** An earlier version of this section said "2–3 screens
per run, then stop and record", and agents read it the way it was written: they captured three
screens and ended the run with the ledger half empty. That was never the intent — the point of
the 2–3 boundary is that *losing* work costs at most three screens, not that a session is over
after three.

- **Every 2–3 screens: record, commit, and continue to the next batch.**
- Keep a progress file (`Documentation/Capture_Progress.md`) naming, per screen: the Object
  Repository app / screen / element reference ids, the role the capture was made under, which
  selectors passed the registration gate, and what is still `TODO_SELECTOR`. The reference ids
  are the part you cannot regenerate by guessing.
- Update the workflow's `.selectors-todo.md` as each marker is resolved, in the same run that
  resolved it.

**Stop only for one of these two reasons**, and say which:

| Stop when | What to report |
|---|---|
| The ledger is **complete** — every row in `Documentation/Leaf_Ledger.md` is yes | The ledger, and the highest evidence level reached with the command that proved it |
| A row needs **a person** | Exactly what you need: an account at the robot's role, a credential in an Orchestrator asset, a screen you cannot reach, an Owner-only control that must be removed |

Running out of screens in the current batch is **not** a reason to stop. Neither is a single
target that fails the registration gate — leave it `TODO_SELECTOR` with the reason and move to
the next one.

## 4. Parametrized descriptors take their values from config, never a literal

A descriptor parametrized as `{{laneName}}`, `{{teamName}}`, `{{accountName}}` resolves against a
**workflow variable of exactly that name** (see `SKILL.md` rule 5). Where that value comes from
matters as much as the binding:

- the value comes from `in_Config` or from the work item
- **never** a literal captured from whatever the test environment happened to show

A descriptor captured against one lane, team or account and then shipped with that literal baked
in is the hardest kind of wrong: it works in the environment it was captured in.

## 5. Scope a toast or banner read to the alert element

Reading an outcome message from the page container returns the container's children concatenated
with no separator — which looks like a value and cannot be split (`SKILL.md` rule 7). Scope the
read to the alert / toast element itself, and confirm with:

```bash
uip rpa uia interact get <eN> text
```

That prints what the activity will actually extract. Look at it before building logic on it.

## 6. Identify list items by business key, never by position

In a list, board or grid, resolve the item by its business key — a reference, a title, a label —
and not by index. A captured `idx` or an nth-child position is valid until the first sort, filter
or new item. This is the same rule the `pdd-sdd-scaffolding` skill applies to Finnova and Avaloq
grids; it is not weaker for the web.

## When to stop and leave a `TODO_SELECTOR`

`evaluate` is the gate. If it will not match **only** your target (or a deliberate, documented
set), leave `TODO_SELECTOR` with one line saying what you tried and what it matched instead. An
honest marker is worth more than a selector that passes because the matching was loosened until
it did.
