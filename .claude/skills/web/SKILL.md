---
name: web
description: Use for any browser-based step in a UiPath automation in this estate — SIX iD portal, CardOne, or the Avaloq Smart Client's embedded report browser — and for any new browser automation. Covers deriving stable web selectors, the idempotent login pattern, BrowserScope vs WindowScope, handling error/interstitial pages, and using Playwright MCP during development to explore a page's accessibility tree and confirm selectors before committing them to a workflow. Trigger on SDD steps naming a URL, a web portal, Chrome, a login page, or when writing html/webctrl selectors.
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

## Using Playwright MCP during development

Playwright MCP is a **build-time aid, not a runtime dependency**. The shipped robot uses
UiPath activities only; Playwright never runs in production.

Installed for this project with:

```bash
claude mcp add playwright npx @playwright/mcp@latest
```

(Node.js 20+ required; verified connected on Node 22.21.1. MCP tools become available in a
new session after installation.)

Use it to:

- open the live page and take an **accessibility snapshot** — not a screenshot — to read the
  real element tree, roles, names and ids
- confirm that an `id` / `name` you plan to put in a `<webctrl>` actually exists and is
  unique
- walk a flow end to end before encoding it, so you learn the interstitials (consent
  banners, "Login anyway", error pages) that break unattended runs
- re-check a selector after an application release

Then translate what you found into UiPath selectors — see `references/selector-strategy.md`
for the mapping, and record what you confirmed in `references/verified-flows.md`.

**Authorisation:** SIX iD, CardOne and Avaloq are authenticated production banking systems.
Only drive them with Playwright against an environment and account you are authorised to
use, and never paste a credential into a prompt or a snapshot. See `.claude/skills/security/`.

## References

- `references/selector-strategy.md` — how to derive stable selectors for these applications
- `references/verified-flows.md` — flow-by-flow record, with verification status
