# Finnova library — selector model

How `Swisscom.FinnovaLibrary` turns your addressing arguments into UiPath selectors. Read
this when an activity cannot find its target.

Source: `../Finnova/Swisscom FinnovaLibrary/Utility/GetWinSelector.xaml`,
`GetDialogSelector.xaml`, `GetSelector.xaml`, `GetWinDialogSelector.xaml`.

## What Finnova looks like to UiPath

Finnova is a Java Swing/AWT application:

```
<wnd app='java*.exe' cls='SunAwtFrame'  [isremoteapp='…'] title='<WindowTitle>' />   ' main windows
<wnd app='java*.exe' cls='SunAwtDialog' [isremoteapp='…'] title='<DialogTitle>' />   ' modal dialogs
  <java name='<PageTabName>' role='page tab' />
  <java name='<PanelName>' role='panel' [idx='<PanelIdx>'] />
  <java [idx='…'] [name='…'] [virtualname='…'] role='<Role>' />
```

## `GetWinSelector` — the window

```vb
' from Utility/GetWinSelector.xaml
CitrixApp = Environment variable "isRemoteApp"
If Not String.IsNullOrEmpty(CitrixApp) Then
    CitrixApp = "isremoteapp='" & CitrixApp & "'"
End If
WinSelector = "<wnd app='java*.exe' cls='SunAwtFrame' " & CitrixApp & " title='" & WindowTitle & "' />"
```

Two things follow:

1. **Citrix RemoteApp is driven by an environment variable, not by workflow config.**
   `isRemoteApp` is read from the robot machine's environment. If selectors resolve on one
   runner and fail on another, check that variable before touching the workflow.

2. **Title matching is exact (with wildcards), not fuzzy.** A fuzzy variant exists in the
   library —

   ```
   matching:title='fuzzy' fuzzylevel:title='0.4'
   ```

   — but it is **commented out**. That is why the window titles in config end in `*`:
   `BRZ Entris*`, `SLM -*`, `ZGKB -*`, `Habib Bank AG -*`, `BLK / BSS*`.

## `GetDialogSelector` — modal dialogs

```vb
DialogSelector = "<wnd app='java*.exe' cls='SunAwtDialog' " & CitrixApp & " title='" & DialogTitle & "' />"
```

Passing `DialogTitle` to an activity retargets it from the main frame to a dialog. Use it
whenever you are acting on something inside a Finnova popup.

## `GetSelector` — the control inside the window

Built in order, each part only added if you supplied the argument:

```vb
Selector = "<java name='" & PageTabName & "' role='page tab' />"                 ' if PageTabName
PanelSelector = "<java name='" & PanelName & "' role='panel' />"                 ' if PanelName
PanelSelector = "<java name='" & PanelName & "' role='panel' idx='" & PanelIdx & "' />"  ' if PanelIdx too
Selector = Selector & PanelSelector
Selector = Selector & "<java " & IdxSelector & NameSelector & VirtualnameSelector & " role='" & Role & "' />"
```

where `IdxSelector` = `idx='…' `, `NameSelector` = `name='…' `,
`VirtualnameSelector` = `virtualname='…' `.

### Table cells

`GetSelector` also emits the Java table attributes:

```vb
Selector = Selector & "<java " & ColumnIndex & RowIndex & ColumnName & RowName & " />"
' tableCol='…'  tableRow='…'  colName='…'  rowName='…'
```

and, when matching on a cell's rendered value:

```vb
Selector = String.Format("{0} <java role='label' name='{1}' />", Selector, CellValue)
```

This is why `Table/*` activities accept **both** index arguments (`ClickRow`/`ClickColumn`,
`GetRow`/`GetColumn` — Strings, not Ints) and name arguments (`RowName`/`ColumnName`).

## Choosing addressing arguments

| Preference | Argument | Why |
|---|---|---|
| 1st | `Virtualname` | Finnova's stable logical id. Survives layout changes. |
| 2nd | `Name` | Visible/accessible name. Breaks with language and label changes. |
| 3rd | `Idx` | Positional. Shifts whenever Finnova renders a different field set. |

Always scope with `PanelName` (and `PageTabName` if the window has tabs) before reaching
for `Idx` — a narrower scope usually makes `Idx` unnecessary.

`RowName` / `ColumnName` beat `GetRow` / `GetColumn` for the same reason.

## Debugging a failing activity

1. Is `WindowTitle` the right one **for this tower**? (`Finnova_System_Win_Title_<TOWER>`)
2. Is the target in a dialog rather than the main frame? → pass `DialogTitle`.
3. Is the environment variable `isRemoteApp` set/unset as expected for this runner?
4. Reproduce the selector by invoking `Utility/GetSelector` / `Utility/GetWinSelector`
   directly and inspecting the returned string, then validate it in UiExplorer.
5. Use `Utility/Element Exists` (addressing + `Role` → `Exists`) to probe without acting.

## Not covered by the library

- No activity opens a browser or attaches to one. Finnova's own UI is entirely Java.
- No activity reads mail, files or Excel — see `.claude/skills/standards/references/systems/mail-system.md`, `.claude/skills/standards/references/systems/file-system.md`.
- No activity performs a Finnova logout; projects terminate the process instead.
