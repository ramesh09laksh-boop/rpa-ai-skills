---
name: web
description: Use for any browser-based step in a UiPath automation — any browser-based application, including single-page apps, plus this estate's three known surfaces (SIX iD portal, CardOne, and the Avaloq Smart Client's embedded report browser). Covers capturing targets live with the `uip rpa uia` CLI into the Object Repository, deriving and hardening selectors, choosing an input method, the idempotent login pattern, Application Card scoping, handling error/interstitial pages, and the version precheck capture needs. Trigger on SDD steps naming a URL, a web portal, Chrome, a login page, on "Object Repository", "capture selectors" or "TODO_SELECTOR", or when writing html/webctrl selectors.
---

# Browser automation

Three browser-based surfaces exist in this estate. **None of them has a custom library** —
all use raw UiPath UI Automation with hand-written selectors, which is why selector
discipline matters more here than anywhere else.

The capture loop below is **not specific to these three.** It has been run unchanged against a
single-page application outside the estate; what differed was the environment, not the method.
Use it for any browser-based target — see `references/capture-troubleshooting.md`.

| Surface | Root selector | Real browser? |
|---|---|---|
| SIX iD portal | `<html app='chrome.exe' title='SIX iD HTML' />` | Yes — Chrome |
| CardOne | `<html app='chrome.exe' title='*CardOne Swisscom*' />` | Yes — Chrome |
| Avaloq report | `<html app='smartclient.exe' title='Smart Client Report' />` | **No** — embedded in the Smart Client |

**The Avaloq report is not a browser.** There is no `chrome.exe` process to open, attach to,
refresh or kill. Use `WindowScope`, not `BrowserScope`; browser-level activities do not
apply. Details: the `standards` skill, `references/systems/web-nav-system.md`.

## Core rules

1. **Probe before you log in.** Every web login here is idempotent — check for a
   logged-in marker with a short `TimeoutMS` (100–500) and only authenticate if absent.
   Re-logging in when already authenticated is the most common failure.
2. **Prefer `id` over text.** CardOne exposes semantic ids
   (`header.menu.actions.creditcard.block.bank`) — use them. Fall back to `name`, `type`,
   then `aaname`.
3. **Preserve whitespace in `aaname`.** `aaname=' Login '`, `aaname=' Next '` and
   `rowName='ISIN '` all carry real leading/trailing spaces from the markup.
4. **Handle the error page explicitly.** SIX iD has a `SIX - Server Error` page; CardOne has
   `Service Unavailable`. Both are checked for by name in the sample project.
5. **Read the page's own feedback.** CardOne reports outcomes in a `pageMessages` container
   rather than by navigating — an action that silently did nothing otherwise looks like
   success.
6. **Never `KillProcess chrome`.** It takes down any other automation on the runner. The one
   occurrence in the estate is deliberately commented out.

## Capturing targets — use the UiPath CLI, not Playwright

**Playwright MCP is no longer used in this estate. Do not install it, do not drive a page with
it, and do not derive selectors from its snapshots.** Everything it was used for is done by
`uip rpa uia`, which has the decisive advantage: it explores the page through *the same UI
Automation engine the robot runs*, and it writes the result straight into the Object
Repository. A Playwright snapshot could only ever tell you what a *different* engine saw,
which you then re-typed by hand — and hand-typed selectors are the single largest source of
breakage in this folder.

### Prerequisite — capture under the role the robot runs as

**A selector captured as an administrator cannot resolve for the robot.** The production robot
signs in at the **least-privilege** role, and a higher role renders controls the robot will never
see: extra toolbar buttons, per-row option menus, an add-column affordance, admin-only panels.
Those extra controls sit in the ancestor chain, so a selector hardened against them is
unresolvable from the robot's session — and it fails at runtime, not at capture.

This is not hypothetical. On the Lanes capture the live session turned out to be an **Owner**:
the add-column control and the per-lane Options menus were both present, neither of which a
Member can see. Every selector from that session had to be treated as suspect.

**Before the first capture command, prove you are not over-privileged:**

1. Ask which role the robot will run as, and get the answer written down (the SDD, or
   `Documentation/Progress.md`). "The least-privilege role that can do the work" is the target,
   not "whatever the test account has".
2. Name the controls that role must **not** see — the admin-only affordances for this
   application — and check each one is **absent** from the screen before you capture.
3. If any of them is present, **stop**: you are signed in above the robot's role. Record it and
   ask for an account at the right role.

**A capture made under a higher role is untrusted and is re-captured** — not reviewed, not
spot-checked, re-captured from a session at the robot's role. There is no way to tell from the
descriptor which ancestors were role-dependent, so auditing it costs more than redoing it.

Record the role next to each captured screen in `Documentation/Capture_Progress.md`, and in the
`captured as <role>` column of `Documentation/Leaf_Ledger.md` (the `standards` skill). A capture
with no role recorded is a capture nobody can trust later.

**Who provides the account.** The application account is created by a person — see the
`standards` skill, `references/studio-checkpoints.md`, Checkpoint 5. The agent never receives,
types or is shown its credential.

### Prerequisite — read `project.json` before the first capture command

The estate pins **both** packages at `26.10.4`:

```json
"UiPath.UIAutomation.Activities": "[26.10.4]",
"UiPath.UIAutomation.CLI":        "[26.10.4]"
```

**Precheck:** if either is missing, differs from `26.10.4`, or the two differ *from each other*,
fix it and restore before anything else. A too-old package makes `uip rpa uia` list **zero
subcommands**, which reads like the CLI being unavailable rather than a version problem. (Keep
the estate's bracket style, `[26.10.4]`.)

Verified in the estate: a project on the standard Studio 23.10 shipped
`UiPath.UIAutomation.Activities 23.10.13` and capture worked only once both packages were raised
to `26.10.4` together. That project then ran `studioVersion 23.10.8.0` with UIA at `26.10.4`,
which **diverges from `templates/`**; whether that divergence is the intended steady state is an
open question for the team, not a per-project decision. See
`references/capture-troubleshooting.md`.

**How this relates to the official minimum.** The official `uipath-rpa` skill states one
requirement — `UiPath.UIAutomation.Activities` at **26.10.2 or newer** — and adds *"Do not
hardcode the version from memory; this section is the only source of truth."* It does not mention
`UiPath.UIAutomation.CLI` at all. So:

| | |
|---|---|
| Official **minimum** | `UiPath.UIAutomation.Activities` ≥ `26.10.2` |
| This estate's **pin** | both packages exactly `26.10.4` |

The pin is a stricter local standard, not a contradiction — it is the combination this estate has
actually run a capture on. **Re-read the official section rather than trusting the number above**
when the minimum may have moved; if it has risen past `26.10.4`, the estate pin is what needs
changing. `UiPath.UIAutomation.CLI` is a real package (`26.10.4` and `26.10.6` exist on the
feed); why the official docs do not name it is **unverified**.

### The rule

**Never hand-write or hand-edit a selector**, and **never hand-call the selector-building CLIs
either.** Both halves matter, and the second one is the half this skill used to get wrong.

> **Never manually call internal selector-building `uip rpa uia` CLIs.** Direct calls bypass
> improvement and OR registration, leaving fragile unregistered selectors. Only SKILL.md flow is
> valid.
>
> — `UiPath.UIAutomation.Activities` 26.10.4, its own `uia-configure-target-guide`

Authoring a `<webctrl …>` from a DOM inspection, a screenshot or a reference document is equally
out of bounds — the reference documents in this estate have been caught wrong, and so has the
shipped UC81 XAML.

### The loop — follow the official capture flow, do not re-type it

**This skill no longer carries a command table, and that is the correction.** It used to list ten
`uip rpa uia` steps naming `target-app resolve-defaults`, `target-anchorable resolve-defaults`,
`selector-intelligence get-ancestors` / `get-selector-attributes` / `evaluate`, and
`object-repository create-elements` / `replace-elements` / `link-elements`. Those are exactly the
internal CLIs the rule above forbids calling by hand. A table of them here is an instruction to
do the forbidden thing, and it rots: the official docs state that
*"`uip rpa uia --help` deliberately exposes no standard subcommands — the UIA CLI surface is
owned and co-versioned by the `UiPath.UIAutomation.Activities` package."* Pinning those names in
this file guaranteed drift against the package the robot actually runs.

**Where the commands live now:**

1. Load the official **`uipath-rpa`** skill (`uip skills install`, or the CLI prints the reminder
   on every `uip rpa` invocation). Its UIA starter guide is the entry point.
2. From there, read the package's own guide **in full** —
   `{PROJECT_DIR}/.local/docs/packages/UiPath.UIAutomation.Activities/ui-automation-guide.md`.
   It ships with the package, so it is co-versioned with what the robot runs and **outranks
   anything written here** on command syntax.
3. Capture through the package's `uia-configure-target` flow. It owns the window baseline, the
   target-generation gate, selector improvement and Object Repository registration as one
   operation. If the file is absent, the installed package predates it — treat that as below the
   minimum version.

Three things the official flow needs that are easy to get wrong, verified against the
co-versioned docs and worth stating once:

| | |
|---|---|
| **Every ref is paired with its definition file** | The JSON array arguments take `{"ref": …, "definitionFilePath": …}` per entry — a bare ref is not the shape. Same for `--elements`, `--screens`, `--targets`, `--anchors`. |
| **Paths are absolute, native-host, forward-slash** | `C:/path/to/work`. **Not** a relative path, **not** git-bash/MSYS `/c/...`, **not** WSL `/mnt/c/...`, **not** bare `pwd`. In git-bash use `pwd -W` or `cygpath -m` and check the drive letter. An invalid path may silently write artifacts elsewhere, or fail with a misleading *path not found*. |
| **A doc file name is not a class name** | `CheckAppState.md` documents the class `UiPath.UIAutomationNext.Activities.NCheckState`. Look the class name up in the activity's doc; do not derive it from the filename. |

**The discipline rules still live here**, because they are estate decisions rather than CLI
mechanics:

- **Complete-then-advance.** Per screen, finish capture *before* advancing the application.
  Advancing can destroy the elements you have not captured yet.
- **The registration gate is a gate, not a formality.** Accept a target only when it matches
  **your target and nothing else** — except a deliberate, documented set. If it will not, leave
  `TODO_SELECTOR` with what you tried and what it matched instead.
- **One fresh work folder per screen**, created empty (`references/capture-troubleshooting.md`).
- **Repair in place.** Never delete-and-re-add an element; the activity binding is
  identity-based, so re-creating the same name still breaks every activity bound to it. The
  official docs make this MANDATORY too.
- **Business key, never position** — see the rule below.
- **Capture at the robot's role** — see the prerequisite above.

### The probe trap — a check inside the card that can never fire

The idempotent-login pattern (rule 1) puts a short-timeout probe for a logged-in marker ahead of
authenticating. Put that probe **inside an Application Card whose `TargetApp` is the sign-in
screen, with `OpenMode = IfNotOpen`, and it can never fire.**

Why, from the documented semantics of `NAppOpenMode.IfNotOpen` — *"Open a new application
instance or browser window, **if the selector does not match any existing instance**"*:

| State | What the card does | What the probe sees |
|---|---|---|
| Not signed in | sign-in selector matches → attaches | the sign-in screen. Probe correctly says "not logged in" |
| **Already signed in** | sign-in selector **no longer matches** → opens a **new** window at the URL | the sign-in screen **again** — because the card just produced one |

So the probe reports "not logged in" in both branches. The workflow re-authenticates every run,
which is precisely the failure rule 1 exists to prevent, and the card has also abandoned the live
session rather than attaching to it.

**Fix: scope the card to a screen that matches *any* page of the application** — a persistent
shell, header, nav frame or title pattern that is present signed-in and signed-out alike — and
probe for the logged-in marker *inside* that. The sign-in screen is a **state** to detect, never
the card's `TargetApp`.

Corollary: a probe can only observe a state the card did not just destroy. Any `IfNotOpen` card
targeting a transient screen has the same defect.

### What this estate learned the hard way

1. **Wildcard `rowName`.** Measured padding is *two* trailing spaces
   (`rowName="Versammlungsdatum  "`) where the reference docs say one. Write
   `rowName='Versammlungsdatum*'` and stop counting.
2. **Repair a broken descriptor in place.** Never delete-and-re-add an element: the activity
   binding is identity-based, so every activity bound to it breaks even if you re-create the
   same name. Re-running the capture flow from scratch on an existing element registers a
   *second* entry and orphans the link — the official docs route repair through their own
   recover-selector guide, which is the procedure to follow.
3. **Carry the proven input method into the workflow.** `Simulate` drives accessibility APIs
   and **never dispatches a DOM click**, so a control whose behaviour is a JavaScript
   `onclick` silently no-ops while the activity reports success — and the run then fails at
   the *next* activity, naming the wrong thing. Use `HardwareEvents` or `DebuggerApi` for
   those, per activity (`NChildInteractionMode`), leaving the card on `Simulate`.
4. **Sets use `NFindElements`, not `NForEachUiElement`.** The latter demands
   `ExtractDataSettings` / `ExtractMetadata`, a table schema only Studio's extraction wizard
   can produce — unavailable headless. `NFindElements` + `ForEach<UiElement>` + `InUiElement`
   on the readers needs no schema. **No `idx` in a filter**: it resolves across the whole
   scope and silently collapses the collection to one element.
5. **A `{{var}}`-parametrized descriptor needs a workflow variable of exactly that name.**
   The repository stores it as a `string.Format` over that variable; rename it and the
   descriptor stops resolving, with a timeout as the only symptom.
6. **Validate the literal before you parametrize.** The capture flow's validate step prints a
   cropped screenshot of the match — look at it. A stored `string.Format` selector no longer
   validates against the live app, so there is no second chance after parametrizing.
7. **Read a value before you trust a Get Text.** Read the element's text through the capture
   flow's interaction CLI first: it shows what the activity will actually extract. A container
   cell can return its children concatenated with no separator, which looks like a value and is
   unsplittable.
8. **Interstitials arrive *after* the click, not before.** Probe-then-click can only clear an
   error page that was already showing. Wrap the landing in a bounded retry.

Record what you confirmed in `references/verified-flows.md`, and see
`references/selector-strategy.md` for the attribute-reliability rules.

---

**Last verified against `rpa-tool 1.204.2`, official `uipath-rpa` skill `1.204.1`, and
`UiPath.UIAutomation.Activities` / `.CLI` `26.10.4`** (2026-11-03). The CLI surface is owned by
the UIA package and changes with it. When this file and the package's own
`ui-automation-guide.md` disagree, **the package wins** — it is co-versioned with what the robot
runs, and this file is not. Re-verify on any package bump and update this line.

**Authorisation:** SIX iD, CardOne and Avaloq are authenticated production banking systems.
Only drive them against an environment and account you are authorised to use, and never paste
a credential into a prompt, a snapshot or a definition file. See the `security` skill.

## References

- `references/selector-strategy.md` — how to derive stable selectors for these applications
- `references/verified-flows.md` — flow-by-flow record, with verification status
- `references/capture-troubleshooting.md` — the version precheck, the stale-URL fix after a
  client-side redirect, one work folder per screen, the commit-every-2–3-screens-then-continue
  protocol, and keeping parametrized descriptors out of literals
