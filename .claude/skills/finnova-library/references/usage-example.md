# Finnova library — worked call sequences

Patterns lifted from `../Finnova/UC39_BPO_manuelle_Börsenaufträge/Finnova_System/` and
`../Finnova/PJFVA-966_UC81_BPO_VD03_TK _Valoren/Finnova_System/`. These are library call
sequences; for the surrounding project structure see `.claude/skills/standards/references/systems/finnova-system.md`.

Throughout, `WinTitel = in_Config("Finnova_System_Win_Title_" + in_TOWER).ToString`.

---

## 1. Open a Finnova function and search

```
Select Menu     Menu           = "<menu path>"
                NewWindowTitle = "<window to wait for>"
                NewWindow      = Win            ' out, UiPath.Core.Window
                MessageTitle   = "…"            ' if the menu can raise a dialog
                MessageBtnName = "OK"

Sync            WindowTitle    = WinTitel

Set Text        WindowTitle    = WinTitel
                PanelName      = "<panel>"
                Virtualname    = "<field>"
                Text           = in_SearchValue
                ErrorMsg       = ErrMsg

Click Button    WindowTitle    = WinTitel
                Name           = "Suchen"
                MessageTitle   = "Hinweis"
                MessageBtnName = "OK"
                Enabled        = Enabled
                ErrorMsg       = ErrMsg

If Not Enabled                     → Throw BusinessRuleException("Suchen not available")
If Not String.IsNullOrEmpty(ErrMsg)→ Throw BusinessRuleException(ErrMsg)

Sync            WindowTitle    = WinTitel
```

Used by `Finnova-Handelsgruppe_Search.xaml`, `Finnova-Nachbearbeiten_Search.xaml`,
`Finnova-Valoren_Search.xaml`.

---

## 2. Extract a grid, then work on the DataTable

Extract once, then query in memory — do not re-read cells from the UI in a loop.

```
Table/Extract        WindowTitle      = WinTitel
                     PanelName        = "<grid panel>"
                     idx              = "…"
                     PageTabName      = "<tab>"
                     ExtractDataTable = dt
                     TotalRows        = RowCount

If RowCount = 0      → Throw BusinessRuleException("No rows found for …")

Table/Search Item    ExtractDataTable = dt
                     SearchItem       = in_Valor
                     SearchInColumn   = "2"          ' 0-BASED, per the library's own note
                     Exists           = Found
                     FoundInRow       = RowNr        ' String

Table/Get Cell Value By Index
                     ExtractDataTable = dt
                     GetRow           = RowNr
                     GetColumn        = "5"
                     Value            = CellValue
```

`Table/Extract` is the single most-used activity in UC39 (28 call sites).

---

## 3. Drill into a record

```
Table/Double Click Cell   WindowTitle = WinTitel
                          PanelName   = "<grid panel>"
                          RowName     = "<row>"        ' prefer names over ClickRow/ClickColumn
                          ColumnName  = "<column>"
                          DialogTitle = "…"            ' if a dialog is expected
                          Message     = Msg
                          Warning     = Warn
                          ErrorMsg    = ErrMsg

Sync                      WindowTitle = WinTitel
```

`Finnova-System_Valor_DoubleClick.xaml` is exactly this.

---

## 4. Edit a cell and save

```
Table/Set Cell       Idx         = "…"
                     WindowTitle = WinTitel
                     PanelName   = "<panel>"
                     RowName     = "<row>"
                     ColumnName  = "<column>"
                     Text        = in_NewValue
                     DialogTitle = "…"

Sync                 WindowTitle = WinTitel

Click Toolbar Button WindowTitle    = WinTitel
                     Name           = "Speichern"
                     MessageTitle   = "…"
                     MessageBtnName = "OK"
                     ErrorMsg       = ErrMsg
                     Warning        = Warn
                     MsgInfo        = Info

If Not String.IsNullOrEmpty(ErrMsg) → Throw BusinessRuleException(ErrMsg)
```

UC39 factors the save half into one shared `Finnova-System_Save.xaml` and invokes it 12
times. Do the same rather than repeating `Click Toolbar Button` inline.

---

## 5. Read a value defensively

```
Text Exists   WindowTitle = WinTitel, PanelName = "<panel>", Idx = "…", Exists = Exists
If Exists
    Get Text  WindowTitle = WinTitel, PanelName = "<panel>", Idx = "…", Value = Value
Else
    → Throw BusinessRuleException("<field> not present")
```

The library raises a generic `System.Exception` for a missing element, which REFramework
classifies as a *system* exception and retries. If "missing" is a business outcome, probe
first with `Text Exists` / `Button Exists` / `Combo Box Exists` / `Menu Item Exists` /
`Window Exists` / `Utility/Element Exists`.

---

## 6. Combo boxes

```
Get Select Enabled   WindowTitle = WinTitel, PanelName = "<panel>", Idx = "…", Result = CanSelect
Extract Combo Box    WindowTitle = WinTitel, PanelName = "<panel>", Idx = "…", Items = Options
' validate in_Value against Options before selecting
Select Item          WindowTitle = WinTitel, PanelName = "<panel>", Idx = "…",
                     Item = in_Value, Enabled = Enabled
Get Selected Text    WindowTitle = WinTitel, PanelName = "<panel>", Idx = "…", Value = Selected
' confirm Selected = in_Value
```

Read back with `Get Selected Text` — `Select Item` returning `Enabled=True` only means the
control accepted input, not that the intended option was chosen.

---

## 7. Checkboxes and radio buttons

```
Get Check Box  WindowTitle = WinTitel, PanelName = "<panel>", VirtualName = "…",
               Checked = IsChecked, Enabled = IsEnabled
If IsEnabled AndAlso IsChecked <> in_Desired
    Check Box  WindowTitle = WinTitel, PanelName = "<panel>", VirtualName = "…", Action = "…"
```

`Action` drives check/uncheck. Always read state first — clicking a checkbox toggles it,
so an unconditional click is not idempotent on retry.

---

## 8. Multi-row selection

```
Table/Enable Mullti Row Click      ' library's spelling: two 'l's, no arguments
… Table/Click Cell for each row …
Table/Disable Mullti Row Click
```

---

## 9. Trees

```
Tree/ExtractTree  WindowTitle = WinTitel, PanelName = "<panel>", idx = "…",
                  Children = Nodes, Count = NodeCount
Click Element     Children = Nodes, ItemName = "<node>", WindowTitle = WinTitel
```

---

## Anti-patterns

| Don't | Do |
|---|---|
| `Delay` after a click | `Sync (WindowTitle = WinTitel)` |
| Hardcode `title='BRZ Entris*'` | `in_Config("Finnova_System_Win_Title_" + in_TOWER)` |
| `Idx = "7"` as the only anchor | scope with `PanelName` + `PageTabName`, prefer `Virtualname` |
| Separate "dismiss popup" branch | `MessageTitle` + `MessageBtnName` on the acting activity |
| Ignore `ErrorMsg` | branch on it and throw with Finnova's own text |
| Loop `Table/Get Cell` over a grid | `Table/Extract` once, then work on the DataTable |
| Pass `3` to `GetRow` | pass `"3"` — row/column arguments are Strings |
| Raw `Click` / `Type Into` on Finnova | a library activity |
