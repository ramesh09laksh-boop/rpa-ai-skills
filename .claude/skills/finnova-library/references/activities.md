# Finnova library — activity reference

Source of truth: `../Finnova/Swisscom FinnovaLibrary/` (project `Swisscom FinnovaLibrary`,
published as NuGet `Swisscom.FinnovaLibrary`). Every activity listed here exists as a
`.xaml` in that project. Argument names are exactly as declared.

Namespaces as they appear in a consuming `.xaml`:

| Prefix target | Activities |
|---|---|
| `Swisscom_FinnovaLibrary.Activities` | everything in `Activities/` |
| `Swisscom_FinnovaLibrary.Activities.Table` | everything in `Activities/Table/` |
| `Swisscom_FinnovaLibrary.Activities.Tree` | `ExtractTree` |
| `Swisscom_FinnovaLibrary` | `Close Window` (project root) |
| `Swisscom_FinnovaLibrary.Utility` / `.Logic` | helpers, see bottom |

## The shared addressing arguments

Nearly every activity accepts these. Provide the narrowest unique combination.

| Argument | Meaning |
|---|---|
| `WindowTitle` | Finnova main window title. Environment-specific — read from `Finnova_System_Win_Title_<TOWER>`. Defaults to `Finnova*` on `Select Menu`. |
| `PageTabName` / `TabName` | `<java role='page tab'>` name. Note the inconsistency: some activities call it `TabName`, table activities call it `PageTabName`. |
| `PanelName`, `PanelIdx` | `<java role='panel'>` name, plus index when the name repeats. |
| `Idx` | `idx=` attribute of the target element. |
| `Name` | `name=` attribute. |
| `Virtualname` | `virtualname=` attribute — Finnova's stable logical id. **Prefer this over `Idx`.** |
| `DialogTitle` | Targets a `SunAwtDialog` instead of the main frame. |
| `MessageTitle`, `MessageBtnName` | Dialog expected as a result of this action, and the button to press on it. |

Out-arguments `ErrorMsg` / `Warning` / `Info` / `Message` return text Finnova raised while
performing the action. See "Message handling" below.

---

## Session / application

### `Login`
Launches and logs into Finnova.

| Arg | Dir | Type | Notes |
|---|---|---|---|
| `LaunchCmd` | in | String | Path to the `start_finnova_jure.cmd` launcher. From config/asset. |
| `Username` | in | String | |
| `Password` | in | SecureString | |
| `StringPassword` | in | String | Plaintext alternative — **do not use.** |
| `Timeout` | in | Int32 | Seconds. Samples use `180`. |
| `RetryLogin` | in | Int32 | Samples use `2`. |
| `RetryIntervalSeconds` | in | Int32 | Samples use `45`. |
| `CitrixUrl` | in | String | e.g. `https://smca.swisscom.com`. |
| `isRemoteApp` | in | String | Citrix RemoteApp mode. |
| `FSSO` | in | Boolean | Federated single sign-on. |
| `SimulateClick` | in | Boolean | |
| `ReleaseInfo` | in | String | |
| `FinnovaMainWindow` | out | Window | Handle to the main frame. |
| `Message` | out | String | |

### `Stop`
Kills a process. `Process` (in, String).

### `Stop BOAL`
Stops the BOAL component. `LaunchCmd` (in, String).

### `Switch Bank`
Switches the active bank/mandant. `Bank` (in, String).

### `Maximize Window`
`WindowTitle` (in, String).

### `Window Exists`
`WindowTitle` (in), `TimeoutMilliseconds` (in, Int32) → `Exists` (out, Boolean).

### `Close Window` *(project root namespace, not `.Activities`)*
`WindowTitle` (in) → `Exists` (out, Boolean).

### `Close All Window`
No arguments. Closes all Finnova child windows. Use in `CloseAllApplications`.

### `Sync`
Waits until Finnova's busy panel (`<java idx='1' role='panel'/>` under the window or dialog)
reaches state `enabled,visible,showing`.

| Arg | Dir | Notes |
|---|---|---|
| `WindowTitle`, `DialogTitle` | in | Which window to sync on. |
| `SyncTimeout` | in Int32 | |
| `MessageTitle`, `MessageBtnName` | in | Dialog to dismiss while waiting. |
| `Info`, `Warning`, `ErrorMsg` | out | |

**Use `Sync` instead of `Delay` after any action that makes Finnova think.**

### `Wait For Dialog Vanish`
`DialogTitle`, `WindowTitle`, `TimeoutInSeconds`.

### `Wait For Button Enabled`
`WindowTitle`, `Idx`, `Name`, `PanelName`, `Virtualname`, `TabName`.

---

## Navigation

### `Select Menu`
Opens a Finnova menu path and optionally waits for the resulting window.

| Arg | Dir | Notes |
|---|---|---|
| `Menu` | in | Menu path. |
| `NewWindowTitle` | in | Title to wait for. |
| `NewWindow` | out Window | Handle to the opened window. |
| `SkipDialogTitle` | in | Dialog to ignore. |
| `MessageTitle`, `MessageBtnName` | in | |
| `WindowTitle` | in | Optional, defaults to `Finnova*`. |

### `Select Tab`
| Arg | Dir | Notes |
|---|---|---|
| `Tab`, `WindowTitle`, `Idx`, `DialogTitle` | in | |
| `MessageTitle`, `MessageBtnName` | in | |
| `Selected` | out Boolean | |
| `Message`, `Warning`, `Info`, `ErrorMsg` | out | |

### `Click Menu Item`
`WindowTitle`, `Idx`, `Name`, `DialogTitle` → `Info`, `Warning`.

### `Menu Item Exists`
`WindowTitle`, `Idx`, `Name` → `Exists` (Boolean).

### `Click Tree`
`WindowTitle`, `Idx`, `Name`, `PanelName`, `PageTabName`.

### `Tree/ExtractTree`
`PanelName`, `WindowTitle`, `idx`, `PageTabName` → `Children` (IEnumerable&lt;UiElement&gt;), `Count` (Int32).
Pair with `Click Element` to act on one of the returned nodes.

### `Click Element`
Clicks one element out of a previously extracted collection.
`Children` (in, IEnumerable&lt;UiElement&gt;), `ItemIndex` (in, Int32), `ItemName` (in), `WindowTitle` (in).

---

## Buttons and clicking

### `Click Button`
The workhorse.

| Arg | Dir | Notes |
|---|---|---|
| `WindowTitle`, `Idx`, `Name`, `PanelName`, `TabName`, `DialogTitle`, `Virtualname` | in | |
| `SimulateClick` | in Boolean | Use when a hardware click is unreliable. |
| `MessageTitle`, `MessageBtnName` | in | |
| `Enabled` | out Boolean | False if the button was disabled. |
| `Warning`, `Info`, `ErrorMsg`, `Message` | out | |

### `Click Button By SimulateClick`
Same addressing, always simulated. No message out-arguments — prefer `Click Button` with
`SimulateClick=True` when you need to read messages back.

### `Click Toolbar Button`
Used for Speichern/Save and other toolbar actions.
`WindowTitle`, `Idx`, `Name`, `DialogTitle`, `Virtualname`, `MessageTitle`, `MessageBtnName`
→ `ErrorMsg`, `Warning`, `MsgInfo`.

### `Get Button Enabled`
`WindowTitle`, `Idx`, `PanelName`, `TabName`, `Virtualname`, `Name` → `Enabled` (Boolean).
Check this before clicking rather than catching a failure.

### `Button Exists`
Same addressing → `Exists` (Boolean).

### `Click Message Button`
Dismisses a Finnova dialog explicitly, when the inline `MessageTitle`/`MessageBtnName`
route is not enough.
`WindowTitle`, `Name`, `Idx`, `CheckForDialogTitle`, `ClickFoundBtnName`, `TimeoutInMilliseconds`.

### `Click Text` / `Double Click Text` / `Richt Click Text`
*(`Richt` is the library's spelling — keep it.)*
`WindowTitle`, `Idx`, `Name`, `PanelName`, `TabName` (`Double Click Text` also takes
`DialogTitle`, `PageTabName`).

### `Text Exists`
`WindowTitle`, `Idx`, `PanelName`, `TabName` → `Exists` (Boolean).

---

## Reading and writing fields

### `Set Text`
| Arg | Dir | Notes |
|---|---|---|
| `WindowTitle`, `Idx`, `Text`, `PanelName`, `DialogTitle`, `TabName`, `PanelIdx` | in | |
| `MessageTitle`, `MessageBtnName`, `AnchorLabel`, `AnchorIdx` | in | `AnchorLabel` addresses a field by its adjacent label. |
| `Message`, `Warning`, `Info`, `ErrorMsg` | out | |

### `Get Text`
`WindowTitle`, `Idx`, `PanelName`, `TabName` → `Value` (String).

### `Get Label`
Same addressing → `Value` (String). For read-only label text.

### `Get Selected Text`
Same addressing → `Value` (String). For the current selection of a combo/list.

### `Get Text Editable`
Same addressing → `Result` (Boolean). Whether the field accepts input.

### `Select Item`
Selects an item in a combo box.
`Idx`, `WindowTitle`, `Item`, `PanelName`, `TabName`, `DialogTitle`, `PanelIdx` → `Enabled` (Boolean).

### `Select List Item`
Same, for a list control. `Idx`, `WindowTitle`, `Item`, `PanelName`, `TabName`, `DialogTitle` → `Enabled`.

### `Get Select Enabled`
`WindowTitle`, `Idx`, `PanelName`, `TabName` → `Result` (Boolean).

### `Extract Combo Box`
Reads all options. `Idx`, `WindowTitle`, `Item`, `PanelName`, `TabName` → `Items` (String[]).

### `Combo Box Exists`
`WindowTitle`, `Idx`, `PanelName`, `TabName` → `Exists` (Boolean).

### `Check Box` / `Get Check Box`
`Check Box`: `WindowTitle`, `Idx`, `Name`, `PanelName`, `PageTabName`, `Action`, `VirtualName`.
`Action` drives check/uncheck.
`Get Check Box`: same addressing → `Checked` (Boolean), `Enabled` (Boolean).

### `Radio Button` / `Get Radio Button`
`Radio Button`: `WindowTitle`, `Idx`, `Name`, `PanelName`, `PageTabName`, `Action`,
`VirtualName`, `PanelIdx`.
`Get Radio Button`: same → `Checked` (Boolean).

### `Scrollbar Home` / `Scrollbar End`
`WindowTitle`, `Idx`, `PanelName`, `TabName`.

### `Send Ctrl Key` / `Send Shift Key` / `Send Ctrl And Shift Key`
`WindowTitle`, `DialogTitle`, `Key`, `MessageTitle`, `MessageBtnName`
→ `ErrorMsg`, `Warning`, `MsgInfo`.

### `Workflow`
Triggers a Finnova workflow action (used in UC39 for tariff calculation).
`Idx`, `WindowTitle`, `Item`, `PanelName`, `PageTabName`, `Virtualname`, `DialogTitle`,
`MessageTitle`, `MessageBtnName` → `Warning`, `Info`, `ErrorMsg`, `Message`.

---

## Tables (`Activities/Table/`)

Table cells are addressed either by **index** (`ClickRow`/`ClickColumn`, `GetRow`/`GetColumn`,
`TextRow`/`TextColumn` — all String) or by **name** (`RowName`/`ColumnName`). Prefer names.
`ScrollBar*` arguments let an activity scroll the target cell into view first.

### `Table/Extract`
`PanelName`, `WindowTitle`, `idx`, `PageTabName` → DataTable + counts.
The most used activity in the samples (28 call sites in UC39).

### `Table/Extract By Pages`
Extracts a paged grid.
`PanelName`, `WindowTitle`, `idx`, `PageTabName`, `MaxNumberOfResults`
→ `ExtractDataTable`, `TotalRows`, `TotlaColumns` *(library's spelling)*.

### `Table/Get Cell`
`PanelName`, `WindowTitle`, `idx`, `GetRow`, `GetColumn`, `PageTabName`, `RowName`,
`ColumnName` → `Value` (String).

### `Table/Get Cell Value By Index`
Reads from an already-extracted DataTable — no UI access.
`ExtractDataTable`, `GetRow`, `GetColumn` → `Value` (String).

### `Table/Get Cell Attribute`
`ExtractDataTable`, `GetRow`, `GetColumn`, plus addressing → attribute value.
Used to read cell colour/state (e.g. Börsenabrechnungen status).

### `Table/Get Checkbox`
Addressing + `RowName`/`ColumnName` → `Checked` (Boolean).

### `Table/Set Cell`
`Idx`, `WindowTitle`, `PanelName`, `Text`, `TextRow`, `TextColumn`, `PageTabName`,
`DialogTitle`, `RowName`, `ColumnName`.

### `Table/Select Item`
Selects a combo value inside a cell.
`Idx`, `WindowTitle`, `Item`, `PanelName`, `SelectColumn`, `SelectRow`, `RowName`,
`ColumnName`, `PageTabName`.

### `Table/Extract Combo Box`
Options of an in-cell combo.
Addressing + `Column`, `Row`, `RowName`, `ColumnName` → `Items` (String[]).

### `Table/Click Cell`
Addressing + `ClickRow`, `ClickColumn`, `RowName`, `ColumnName`, `ScrollBar*`.

### `Table/Click Cell By Value`
Finds the cell by its text instead of coordinates.
Addressing + `CellValue`, `ScrollBar*`.

### `Table/Double Click Cell`
Addressing + `ClickRow`, `ClickColumn`, `DialogTitle`, `RowName`, `ColumnName`
→ `Message`, `Warning`, `ErrorMsg`. Standard way to drill into a record.

### `Table/Right Click Cell`
Addressing + `ClickRow`, `ClickColumn`, `RowName`, `ColumnName`, `ScrollBar*`.

### `Table/Click Column Header`
`PanelName`, `WindowTitle`, `PageTabName`, `ColumnName`. Sorts.

### `Table/Scrollbar Cell`
Scrolls a cell into view without clicking. Addressing + `ScrollBar*`.

### `Table/Search Item`
Searches an already-extracted DataTable.
`ExtractDataTable`, `SearchItem`, `SearchInColumn` (**0-based**, per the library's own note)
→ `Exists` (Boolean), `FoundInRow` (String).

### `Table/Item Count By Column Index`
`Item`, `ColumnIndex`, `ExtractedDataTable` → `Count` (Int32).

### `Table/Enable Mullti Row Click` / `Table/Disable Mullti Row Click`
*(library's spelling — two `l`s)* No arguments. Wrap multi-row selections: enable, select,
disable.

---

## Utility and Logic (`Utility/`, `Logic/`)

Mostly internal, but callable.

| Activity | Signature |
|---|---|
| `Utility/GetSelector` | Builds a `<java …>` selector from the addressing arguments → `Selector` |
| `Utility/GetWinSelector` | `WindowTitle` → `WinSelector` (`<wnd app='java*.exe' cls='SunAwtFrame' …>`) |
| `Utility/GetDialogSelector` | `DialogTitle` → `DialogSelector` (`cls='SunAwtDialog'`) |
| `Utility/GetWinDialogSelector` | `WindowTitle` → `Selector` |
| `Utility/Element Exists` | addressing + `Role` → `Exists` |
| `Utility/Dialog_Message_Get` | `in_DialogTitle` → `out_Msg` |
| `Utility/HandleError` | → `out_Msg` |
| `Utility/HandleMessage` | `MessageTitle`, `MessageBtnName`, `DialogTitle` → `out_Warning`, `out_Info` |
| `Utility/HandleScrollbar` | `Selector`, `PanelName`, `PageTabName`, `ScrollBar*`, `WinSelector` |
| `Utility/FSSO_Include_Disable` | `in_Finnova_Launchcmd` — disables FSSO in the launch cmd |
| `Logic/Format Number` | `Value` → `Result` |
| `Logic/Format String` | `Value` → `Result` |
| `Logic/Format Tel Number` | `Value`, `CountryCode` → `Result` |
| `Logic/IsEmail` | `Value` → `Result` (Boolean) |
| `Logic/Logic-Button_Click_By_Title` | `MessageTitle`, `MessageBtnName`, `Dialog` |

---

## Gotchas

- **Spelling is inconsistent and load-bearing.** `Richt Click Text`, `TotlaColumns`,
  `Mullti Row Click`, `ConfitmMessage`. Copy them exactly.
- **`TabName` vs `PageTabName`** differs between top-level and table activities.
- **`Table/Search Item.SearchInColumn` is 0-based**, per the library's own annotation. Row and
  column arguments elsewhere are Strings, not Ints — pass `"3"`, not `3`.
- **`Virtualname` beats `Idx`.** `Idx` shifts when Finnova renders a different field set.
- **`WindowTitle` is per-tower.** `BRZ Entris*`, `SLM -*`, `ZGKB -*`, `Habib Bank AG -*`,
  `BLK / BSS*` in the samples. Always `in_Config("Finnova_System_Win_Title_" + in_TOWER)`.
- **No library activity opens a browser or reads mail.** Those are separate systems — see
  `.claude/skills/standards/references/systems/six-id-system.md`, `.claude/skills/standards/references/systems/mail-system.md`.
- **No library activity exists for reading a Finnova report to file.** UC39 goes through
  Backoffice messages and table extraction instead.

## Message handling

When an action can raise a Finnova dialog, pass `MessageTitle` + `MessageBtnName` into the
activity and branch on the returned `ErrorMsg` / `Warning` / `Info`:

```vb
' Click Button (Name="Buchen", MessageTitle="Hinweis", MessageBtnName="OK",
'               ErrorMsg=ErrMsg, Warning=Warn)
If Not String.IsNullOrEmpty(ErrMsg) Then
    Throw New BusinessRuleException(String.Format("Can't process: {0}", ErrMsg))
End If
```

This is exactly what `Finnova-Message_Accept.xaml` and
`Finnova_System-GP_Backoffice_Msg_Check.xaml` do in UC39.
