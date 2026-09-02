---
name: avaloq-library
description: Use when calling the Swisscom.UiPath.UIAutomation.Avaloq activity package against the Avaloq Smart Client (smartclient.exe, .NET thick client, optionally Citrix) — choosing the right library activity, filling its WindowCtrlName / SectionCtrlname / GroupAaname / ContainerCtrlname / FieldCtrlname addressing arguments, handling the BreakIfConfirm / ConfirmMessage / ErrorMessage contract, opening Aufträge, driving Avaloq grids, ribbon and right-click menus, and extracting the embedded Smart Client Report web tables. Trigger whenever a workflow needs to click, type, read or extract anything in an Avaloq Smart Client window, or when a Swisscom.UiPath.UIAutomation.Avaloq dependency is present.
---

# Swisscom.UiPath.UIAutomation.Avaloq — activity package

The reusable UiPath library that wraps the Avaloq Smart Client. This skill covers the
**library API**. For how a project orchestrates it (login workflow, transaction flow,
error conventions) see `.claude/skills/standards/references/systems/avaloq-system.md`.

- NuGet: `Swisscom.UiPath.UIAutomation.Avaloq` (sample pins `[2.6.5]`), described in
  `project.json` as "Avaloq Smart Client Library"
- Source: `../Avaloq/Swisscom.UiPath.UIAutomation.Avaloq/`
- Depends on `UiPath.System.Activities` 24.10.8, `UiPath.UIAutomation.Activities` 24.10.17

## How you address a control

Avaloq Smart Client is a .NET/WinForms thick client. Controls are addressed by their
`ctrlname`, never by screen position:

`WindowCtrlName` / `WindowTitle` → `SectionCtrlname` → `GroupAaname` → `ContainerCtrlname` → `FieldCtrlname`

which the library assembles into:

```
<wnd app='smartclient.exe' [isremoteapp='…'] ctrlname='<WindowCtrlName>' />
  <wnd ctrlname='<SectionCtrlname>' />
  <wnd aaname='<GroupAaname>' />
  <wnd ctrlname='<ContainerCtrlname>' />
  <wnd ctrlname='<FieldCtrlname>' />
```

Tables add `TableName`, `RowIndex` (Int32) / `RowName`, `ColumnName`, `TableIdx`, `RowIdx`,
`TableInRowName`. Details in `references/selector-model.md`.

## The confirm/error contract

Activities that can trigger an Avaloq dialog — `Click`, `Auftrag Öffnen`, `Auftrag Show`,
`Execute Drop Down Menu`, `Sync` — take `BreakIfConfirm` (Boolean) and return
`ErrorMessage` + `ConfirmMessage`.

**Set `BreakIfConfirm=True` and branch on the returned messages** instead of writing a
separate popup handler. A populated `ConfirmMessage` normally means Avaloq wants a human
decision — throw a `BusinessRuleException` carrying that text. For unconditional dialogs
use `Click Confirm OK` / `Click Confirm Abbrechen` (both take no arguments).

## Synchronization

`Sync` (`TimeOutInSeconds`, `WinSelector`, `BreakIfConfirm` → `ErrorMessage`,
`ConfirmMessage`) after any action that makes Avaloq round-trip to the integration server.
`Window Exists` / `Element Exists` are cheap existence probes.

## Two UI technologies in one application

| Surface | Selector root | Library activities |
|---|---|---|
| Smart Client forms and grids | `<wnd app='smartclient.exe' …>` | `Click`, `Set Text`, `Table *` |
| Embedded report browser | `<html app='smartclient.exe' title='Smart Client Report' />` | `Web Table *` |

The `Web Table *` family targets the **embedded** browser, not an external one. See
`.claude/skills/standards/references/systems/web-nav-system.md` for how the sample project actually drives it (it bypasses these
activities — a documented gap) and `.claude/skills/standards/references/systems/cardone-system.md` for the genuinely external
Chrome application.

## Activity groups

| Group | Activities |
|---|---|
| Session | `Login`, `Stop`, `Maximize Window`, `Window Exists`, `Close Window`, `Close Tab`, `Sync` |
| Orders | `Auftrag Öffnen`, `Auftrag Show` |
| Navigation | `Select Menu`, `Execute Drop Down Menu`, `Select Tab`, `Select Tab Orderbook`, `Select Tab Erfassung`, `Select Tab Aktuellste Aufträge`, `Select Right Click Menu`, `Click Expand` |
| Fields | `Click`, `Click Text Button`, `Right Click Text`, `Get Text`, `Set Text`, `Type Into Text`, `Type Into by Append Text`, `Type Into by Append Text Before`, `Element Exists` |
| Tables | `Table Extract`, `Table Extract by Scrollbar`, `Table Click Cell`, `Table Set Text`, `Table Get Cell Text By Name`, `Table Search By Index`, `Table Scrollbar Click *`, … |
| Web tables | `Web Table Extract`, `Web Table Extract By Scrollbar`, `Web Table Click Cell`, `Web Table Click By Col Name`, `Web Table Click Button`, `Web Table Get Row By Col Innertext` |
| CyberArk/PHI | `CyberArk/GetCyberArkAccount`, `CyberArk/OpenPHI`, `CyberArk/ClosePHI` |
| SMCA | `SMCA/SMCALaunchApp` |
| Utility | `Utility/Get_Selector`, `Utility/Get_Win_Selector`, `Utility/Get_Process_Name`, … |

## References

- `references/activities.md` — every activity, exact argument names, types and gotchas (exhaustive)
- `references/selector-model.md` — how selectors are built, Citrix, ctrlname discovery
- `references/usage-example.md` — worked call sequences taken from the sample project
