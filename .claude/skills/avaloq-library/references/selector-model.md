# Avaloq library — selector model

How `Swisscom.UiPath.UIAutomation.Avaloq` turns your addressing arguments into UiPath
selectors. Read this when an activity cannot find its target.

Source: `../Avaloq/Swisscom.UiPath.UIAutomation.Avaloq/Utility/Get_Win_Selector.xaml`,
`Get_Selector.xaml`, `Get_Web_Selector.xaml`, `Get_Web_Table_Selector.xaml`.

## What Avaloq looks like to UiPath

The Smart Client is a .NET/WinForms application. Controls carry a WinForms `ctrlname`, which
is what the library keys on — **not** screen text, and not position.

```
<wnd app='smartclient.exe' [isremoteapp='…'] ctrlname='<WindowCtrlName>' />
  <wnd ctrlname='<SectionCtrlname>' />
  <wnd aaname='<GroupAaname>' />
  <wnd ctrlname='<ContainerCtrlname>' />
  <wnd ctrlname='<FieldCtrlname>' />
```

## `Get_Win_Selector` — the window

```vb
' three mutually exclusive forms
WinSelector = "<wnd app='smartclient.exe'  " & CitrixApp & " ctrlname='AvaloqRibbonShell' />"
WinSelector = "<wnd app='smartclient.exe' "  & CitrixApp & " ctrlname='" & WinCrlName & "' />"
WinSelector = "<wnd app='smartclient.exe' "  & CitrixApp & " title='"    & WinTitle   & "' />"
```

- Pass `WinCrlName` *(sic — the library's spelling)* to target by control name, or
  `WinTitle` to target by title. `ctrlname` is the more stable of the two.
- With neither, the selector falls back to the ribbon shell `AvaloqRibbonShell`.
- `CitrixApp` comes from `Utility/Get_Remote_App.xaml` and inserts `isremoteapp='…'` when
  the Smart Client is a Citrix published application.

### Known window control names

| Window | `ctrlname` |
|---|---|
| Ribbon shell (main) | `AvaloqRibbonShell` |
| Login | `LoginView` |
| Task Desk | `*task_desk2` |
| Navigator Desk | `*nav_desk` |
| Status bar | `StatusBar`, `ultraStatusBar` |

Leading `*` wildcards are used because Avaloq prefixes desk control names at runtime.

## `Get_Selector` — the control inside the window

Built in order, each level only added if you supplied the argument:

```vb
Selector = "<wnd ctrlname='" & SectionCtrlname   & "' />"
Selector = Selector & "<wnd aaname='"   & GroupAaname       & "' />"
Selector = Selector & "<wnd ctrlname='" & ContainerCtrlname & "' />"
Selector = Selector & "<wnd ctrlname='" & FieldCtrlName     & "' />"
```

Note the middle level matches on **`aaname`** (accessible name) rather than `ctrlname` —
group boxes in Avaloq expose a caption, not a control name.

Omit the levels you do not need; the library only appends what you supply. Start with
`FieldCtrlname` alone and add outer levels only when the field name is ambiguous.

## `Get_Table_Selector` — grid cells

Takes `TableName`, `RowIndex`, `ColumnName`, `RowName`, `TableInRowName`, `TableIdx`,
`RowIdx` and appends the cell address to an existing `Selector` (in/out).

- `RowIndex` is an **`Int32`** — an actual row number.
- `RowIdx` and `TableIdx` are **Strings** — they are selector `idx=` disambiguators, *not*
  row numbers. Confusing these is the most common mistake with this library.
- `TableInRowName` addresses a table nested inside a row of another table.

## Web selectors — the embedded report browser

Avaloq renders reports in a browser **hosted inside `smartclient.exe`**:

```vb
' Get_Web_Selector
WebSelector = "<html app='smartclient.exe' title='" & WebTitle & "' />"
```

There is no `chrome.exe` here and no external browser process — use `WindowScope`, not
`BrowserScope`, and do not try to kill or close a browser.

```vb
' Get_Web_Table_Selector
"<webctrl tag='TABLE'  {0} />"      ' {0} = parentid / parentclass / idx
"<webctrl tag='{1}' {2} />"
"<webctrl {1} />"
```

built from `Parentid`, `Parentclass`, `Idx`, `RowIndex`, `ColumnIndex`, `Tag`, `Aaname`,
`Innertext`, `ColumnName`, `RowName`.

The report grid in the sample project anchors on `parentid='grid1'` +
`parentclass='objbox'`, which is stable across reports. See
`.claude/skills/standards/references/systems/web-nav-system.md`.

## Choosing addressing arguments

| Preference | Argument | Why |
|---|---|---|
| 1st | `FieldCtrlname` / `WindowCtrlName` | WinForms control names are stable across releases and languages. |
| 2nd | `GroupAaname` | Accessible caption — scopes well but is language-dependent. |
| 3rd | `WindowTitle` | Changes with the open record. |
| last | `Idx` | Positional; shifts with layout. |

Scope with `SectionCtrlname` / `ContainerCtrlname` before reaching for `Idx`.

For table cells prefer `RowName` / `ColumnName` over `RowIndex` for the same reason.

## Discovering control names

The library exposes four helpers that normalise a raw control name into the form the
selector builders expect:

| Activity | Use |
|---|---|
| `Utility/Get_Form_Field_CtrlName` | field |
| `Utility/Get_Form_Section_CtrlName` | section |
| `Utility/Get_Form_Container_CtrlName` | container |
| `Utility/Get_Form_Button_CtrlName` | button |

Each takes `in_CtrlName` and returns `out_CtrlName`. Use UiExplorer to read the raw
`ctrlname` off the target, then pass it through the matching helper rather than guessing the
normalised form.

## Debugging a failing activity

1. Is the Smart Client a Citrix published app on this runner? Check
   `Utility/Get_Remote_App` — `isremoteapp='…'` must be present or absent consistently.
2. Are you targeting the right window? Try `WinCrlName='AvaloqRibbonShell'` first, then the
   specific desk.
3. Invoke `Utility/Get_Selector` / `Utility/Get_Win_Selector` directly and inspect the
   returned string, then validate it in UiExplorer.
4. Probe with `Element Exists` / `Window Exists` before acting.
5. If the target is inside a report, it is **web**, not `wnd` — use `Get_Web_Selector` and
   the `Web Table *` activities.

## Not covered by the library

- No logout activity — `Stop` kills the process.
- No mail, file or Excel access.
- Nothing for external browsers. CardOne, launched from an Avaloq context menu, is a real
  Chrome application handled with raw UI Automation — see
  `.claude/skills/standards/references/systems/cardone-system.md` and `.claude/skills/web/`.
