---
name: web
description: Use for any browser-based step in a UiPath automation in this estate — SIX iD portal, CardOne, or the Avaloq Smart Client's embedded report browser — and for any new browser automation. Covers capturing targets live with the `uip rpa uia` CLI into the Object Repository, deriving and hardening selectors, choosing an input method, the idempotent login pattern, Application Card scoping, and handling error/interstitial pages. Trigger on SDD steps naming a URL, a web portal, Chrome, a login page, or when writing html/webctrl selectors.
---

# Browser automation

Three browser-based surfaces exist in this estate. **None of them has a custom library** —
all use raw UiPath UI Automation with hand-written selectors, which is why selector
discipline matters more here than anywhere else.

| Surface | Root selector | Real browser? |
|---|---|---|
| SIX iD portal | `<html app='chrome.exe' title='SIX iD HTML' />` | Yes — Chrome |
| CardOne | `<html app='chrome.exe' title='*CardOne Swisscom*' />` | Yes — Chrome |
| Avaloq report | `<html app='smartclient.exe' title='Smart Client Report' />` | **No** — embedded in the Smart Client |

**The Avaloq report is not a browser.** There is no `chrome.exe` process to open, attach to,
refresh or kill. Use `WindowScope`, not `BrowserScope`; browser-level activities do not
apply. Details: `.claude/skills/standards/references/systems/web-nav-system.md`.

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

**Prerequisite.** `UiPath.UIAutomation.Activities` and `UiPath.UIAutomation.CLI` must be
present **at the same version** (26.10.4 works). A mismatch makes `uip rpa uia` list zero
subcommands, which reads like the CLI being unavailable.

### The rule

**Never hand-write or hand-edit a selector.** Every selector comes from
`target-anchorable resolve-defaults`, is hardened only with `selector-intelligence`, and is
confirmed by `selector-intelligence evaluate` before it is registered. Authoring a
`<webctrl …>` from a DOM inspection, a screenshot or a reference document is out of bounds —
the reference documents in this estate have been caught wrong, and so has the shipped UC81
XAML.

### The loop

Per screen, finish the whole loop before advancing the application — **complete-then-advance**.
Advancing can destroy the elements you have not captured yet.

| Step | Command |
|---|---|
| 1. Window baseline | `uip rpa uia snapshot capture --folder-path "$W"` → read `window-tree.yml` |
| 2. Open the page | `uip rpa uia interact browser open <url> --browser Chrome` |
| 3. Read the page tree | `uip rpa uia snapshot capture <bN> --folder-path "$W"` → read `tree.yml` |
| 4. Resolve the window | `uip rpa uia target-app resolve-defaults --refs '[…]' --name "<Screen>"` |
| 5. Resolve elements | `uip rpa uia target-anchorable resolve-defaults --refs '[…]'` |
| 6. Harden | `selector-intelligence get-ancestors` / `get-selector-attributes` |
| 7. **Confirm** | `selector-intelligence evaluate --selector … --refs …` |
| 8. Register | `object-repository create-elements` (new) / `replace-elements` (existing) |
| 9. Advance | `uip rpa uia interact click\|type\|select <eN> --input-method …` |
| 10. Attach to XAML | `object-repository link-elements` by `WorkflowViewState.IdRef` |

`evaluate` is the gate, not a formality: accept a selector only when **Matching candidates
lists your target and nothing else** (except a deliberate set — see below).

### What this estate learned the hard way

1. **Wildcard `rowName`.** Measured padding is *two* trailing spaces
   (`rowName="Versammlungsdatum  "`) where the reference docs say one. Write
   `rowName='Versammlungsdatum*'` and stop counting.
2. **Repair in place with `replace-elements`.** Never delete-and-re-add an element: the
   activity binding is identity-based, so every activity bound to it breaks even if you
   re-create the same name.
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
6. **Validate the literal before you parametrize.** `target-anchorable validate` prints a
   cropped screenshot of the match — look at it. A stored `string.Format` selector no longer
   validates against the live app.
7. **Read a value before you trust a Get Text.** `interact get <eN> text` shows what the
   activity will actually extract. A container cell can return its children concatenated with
   no separator, which looks like a value and is unsplittable.
8. **Interstitials arrive *after* the click, not before.** Probe-then-click can only clear an
   error page that was already showing. Wrap the landing in a bounded retry.

Record what you confirmed in `references/verified-flows.md`, and see
`references/selector-strategy.md` for the attribute-reliability rules.

**Authorisation:** SIX iD, CardOne and Avaloq are authenticated production banking systems.
Only drive them against an environment and account you are authorised to use, and never paste
a credential into a prompt, a snapshot or a definition file. See `.claude/skills/security/`.

## References

- `references/selector-strategy.md` — how to derive stable selectors for these applications
- `references/verified-flows.md` — flow-by-flow record, with verification status
