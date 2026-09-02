---
name: finnova-library
description: Use when calling the Swisscom FinnovaLibrary UiPath activity package against the Finnova core-banking Java thin client (java*.exe / SunAwtFrame, optionally Citrix RemoteApp) — choosing the right library activity, filling its WindowTitle / PageTabName / PanelName / Idx / Virtualname addressing arguments, reading its ErrorMsg / Warning / Info message out-arguments, using Sync instead of Delay, and working with Finnova tables, combo boxes, checkboxes, trees and dialogs. Trigger whenever a workflow needs to click, type, read or extract anything in a Finnova window, or when a Swisscom.FinnovaLibrary dependency is present.
---

# Swisscom FinnovaLibrary — activity package

The reusable UiPath library that wraps the Finnova Java thin client. This skill covers the
**library API**. For how a project orchestrates it (login workflows, transaction flow,
error conventions) see `.claude/skills/standards/references/systems/finnova-system.md`.

- NuGet: `Swisscom.FinnovaLibrary` (samples pin `[4.0.3]` / `[4.0.7]`)
- Source: `../Finnova/Swisscom FinnovaLibrary/`
- Depends on `UiPath.System.Activities` 23.10.5, `UiPath.UIAutomation.Activities` 23.10.9

## The one rule

**Never write a raw selector or use generic `Click` / `Type Into` against Finnova.**
Every interaction goes through a library activity, which builds the `<java …>` selector
from addressing arguments you supply. The UC39 sample project contains **zero** raw Finnova
selectors outside `Tests/` — that is the standard to meet.

## How you address a control

Supply the narrowest unique combination:

`WindowTitle` → `PageTabName` (tab) → `PanelName` (+ `PanelIdx`) → `Virtualname` / `Name` / `Idx`

Prefer `Virtualname` (Finnova's stable logical id) over `Idx` (positional, shifts when
Finnova renders a different field set). `WindowTitle` is environment-specific — always read
it from config, never hardcode. Details in `references/selector-model.md`.

## Message handling contract

Most action activities (`Click Button`, `Click Toolbar Button`, `Select Tab`, `Set Text`,
`Workflow`, `Send Ctrl Key`, …) accept `MessageTitle` + `MessageBtnName` and return
`ErrorMsg` / `Warning` / `Info` / `Message`.

**The library does not throw when Finnova refuses an action — it returns the text.**
Pass the expected dialog in, then check the out-argument:

```vb
' Click Button (Name="Buchen", MessageTitle="Hinweis", MessageBtnName="OK", ErrorMsg=ErrMsg)
If Not String.IsNullOrEmpty(ErrMsg) Then
    Throw New BusinessRuleException(String.Format("Can't process: {0}", ErrMsg))
End If
```

Do not write a separate "handle popup" branch — that is what these arguments are for.

## Synchronization

Use `Sync` after any action that makes Finnova round-trip to the server. It waits for
Finnova's busy panel to reach `enabled,visible,showing`. **Do not use `Delay`** — no
`Finnova_System/` workflow in either sample project does.

Also available: `Wait For Dialog Vanish`, `Wait For Button Enabled`, `Window Exists`
(with `TimeoutMilliseconds`).

## Activity groups

| Group | Activities |
|---|---|
| Session | `Login`, `Stop`, `Stop BOAL`, `Switch Bank`, `Maximize Window`, `Window Exists`, `Close Window`, `Close All Window`, `Sync`, `Wait For …` |
| Navigation | `Select Menu`, `Select Tab`, `Click Menu Item`, `Menu Item Exists`, `Click Tree`, `Tree/ExtractTree`, `Click Element` |
| Buttons | `Click Button`, `Click Button By SimulateClick`, `Click Toolbar Button`, `Get Button Enabled`, `Button Exists`, `Click Message Button`, `Click Text`, `Double Click Text`, `Richt Click Text`, `Text Exists` |
| Fields | `Set Text`, `Get Text`, `Get Label`, `Get Selected Text`, `Get Text Editable`, `Select Item`, `Select List Item`, `Extract Combo Box`, `Combo Box Exists`, `Check Box`, `Get Check Box`, `Radio Button`, `Get Radio Button`, `Scrollbar Home/End`, `Send Ctrl/Shift Key`, `Workflow` |
| Tables | `Table/Extract`, `Table/Extract By Pages`, `Table/Get Cell`, `Table/Set Cell`, `Table/Click Cell`, `Table/Double Click Cell`, `Table/Search Item`, … |
| Utility/Logic | `Utility/GetSelector`, `Utility/HandleMessage`, `Logic/Format Number`, … |

## References

- `references/activities.md` — every activity, exact argument names, types and gotchas (exhaustive)
- `references/selector-model.md` — how selectors are built, Citrix RemoteApp, window titles
- `references/usage-example.md` — worked call sequences taken from the sample projects
