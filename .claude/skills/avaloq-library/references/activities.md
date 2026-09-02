# Avaloq library — activity reference

Source of truth: `../Avaloq/Swisscom.UiPath.UIAutomation.Avaloq/` (published as NuGet
`Swisscom.UiPath.UIAutomation.Avaloq`). Every activity listed here exists as a `.xaml` in
that project. Argument names are exactly as declared.

Namespaces as they appear in a consuming `.xaml`:

| Prefix target | Activities |
|---|---|
| `Swisscom_UiPath_UIAutomation_Avaloq` | all root-level activities |
| `Swisscom_UiPath_UIAutomation_Avaloq.Utility` | `Utility/*` |
| `Swisscom_UiPath_UIAutomation_Avaloq.CyberArk` | `CyberArk/*` |
| `Swisscom_UiPath_UIAutomation_Avaloq.SMCA` | `SMCALaunchApp` |

## The shared addressing arguments

| Argument | Meaning |
|---|---|
| `WindowCtrlName` | `ctrlname` of the Smart Client window (e.g. `LoginView`, `*task_desk2`, `*nav_desk`). |
| `WindowTitle` | Alternative to `WindowCtrlName` — matches on `title=` instead. |
| `SectionCtrlname` | Outermost form section. |
| `GroupAaname` | Group box, matched on `aaname` (accessible name). |
| `ContainerCtrlname` | Container inside the group. |
| `FieldCtrlname` | The control itself. |
| `Idx` | `idx=` disambiguator (String). |
| `Aaname` | `aaname=` of the target (used by `Click`, `Click Expand`). |

Omit the levels you do not need — the library only appends the parts you supply.

## The confirm/error out-arguments

`BreakIfConfirm` (in, Boolean), `ErrorMessage` (out, String), `ConfirmMessage` (out, String)
appear on `Click`, `Auftrag Öffnen`, `Auftrag Show`, `Execute Drop Down Menu` and `Sync`.
The library returns Avaloq's dialog text rather than throwing.

*(`Execute Drop Down Menu` spells its output `ConfitmMessage` — a typo in the library.
Copy it exactly.)*

---

## Session

### `Login`
Launches and logs into the Smart Client.

| Arg | Dir | Type | Notes |
|---|---|---|---|
| `User` | in | String | |
| `Password` | in | SecureString | |
| `StringPassword` | in | String | Plaintext alternative — **do not use.** |
| `SmartClientPath` | in | String | e.g. `C:\Program Files (x86)\AvaloqClient\TATG11\SmartClient.exe`. From an Orchestrator asset. |
| `SmartClientArguments` | in | String | `-integrationServerHost … -integrationServerPort … -avaloqSystemId …`. From an Orchestrator asset. |
| `SmartClientCitrixApp` | in | String | Citrix published-app name. |
| `TimeOutInSeconds` | in | Int32 | Sample uses `60`. |
| `RetryNumber` | in | Int32 | Sample uses `3`. |
| `RetryIntervalInSeconds` | in | Int32 | Sample uses `60`. |
| `AuthType` | in | String | |
| `BusinessUnit` | in | String | |

### `Stop`
`Process` (in, String). Terminates the Smart Client process.

### `Maximize Window`
`WindowCtrlName`, `WindowTitle`.

### `Window Exists`
`WindowCtrlName`, `WindowTitle` → `Exists` (out, Boolean).

### `Close Window`
`WindowCtrlName`, `WindowTitle`.

### `Close Tab`
`WindowCtrlName`, `WindowTitle`, `TabName`. Closes one tab within a window — the usual way
to clean up after a report or task template.

### `Sync`
| Arg | Dir | Notes |
|---|---|---|
| `TimeOutInSeconds` | in Int32 | |
| `WinSelector` | in String | Window to sync on (from `Utility/Get_Win_Selector`). |
| `BreakIfConfirm` | in Boolean | |
| `ErrorMessage`, `ConfirmMessage` | out | |

---

## Orders (Aufträge)

### `Auftrag Öffnen`
Opens an order for editing.
`Auftrag_Nr` (in, String), `BreakIfConfirm` (in, Boolean) → `ErrorMessage`, `ConfirmMessage`.

### `Auftrag Show`
Same signature, read-only view.

Both return `ConfirmMessage` when Avaloq raises a dialog — most commonly "order is already
in use by another user". Branch on it.

---

## Navigation

### `Select Menu`
`Menu` (in, String). Ribbon menu path.

### `Execute Drop Down Menu`
`Menu` (in, String), `BreakIfConfirm` (in, Boolean) → `ErrorMessage`, `ConfitmMessage` *(sic)*.

### `Select Tab`
`WindowCtrlName`, `WindowTitle`, `TabName`.

### `Select Tab Orderbook` / `Select Tab Erfassung` / `Select Tab Aktuellste Aufträge`
No arguments. Fixed shortcuts for the three common Avaloq tabs.

### `Select Right Click Menu`
Opens a context menu on a control and picks an entry.
`WindowCtrlName`, `WindowTitle`, `FieldCtrlname`, `SectionCtrlname`, `GroupAaname`,
`ContainerCtrlname`, `Menu`.

This is how the sample project launches CardOne from Avaloq:
`Select Right Click Menu (FieldCtrlname="pos_id", Menu="Aufruf CardOne: Konto-Detail anzeigen")`.

### `Click Expand`
Expands a collapsible node.
`WindowCtrlName`, `WindowTitle`, `CtrlName`, `Idx`, `Aaname`.

---

## Fields and clicking

### `Click`
| Arg | Dir | Notes |
|---|---|---|
| `WindowCtrlName`, `WindowTitle`, `CtrlName`, `Idx`, `Aaname` | in | Note: `CtrlName`, not `FieldCtrlname`. |
| `BreakIfConfirm` | in Boolean | |
| `ErrorMessage`, `ConfirmMessage` | out | |

### `Click Text Button`
`WindowCtrlName`, `WindowTitle`, `FieldCtrlname`, `SectionCtrlname`, `GroupAaname`,
`ContainerCtrlname`. No message out-arguments.

### `Click Confirm OK` / `Click Confirm Abbrechen`
No arguments. Press OK / Cancel on the current Avaloq confirmation dialog.

### `Right Click Text`
Full addressing set, no arguments beyond it.

### `Get Text`
Full addressing set → `Value` (out, String).

### `Set Text`
Full addressing set, plus:
- `Text` (in, String)
- `CheckForFieldValid` (in, Boolean) — verifies the field accepted the value.

The single most-used activity in the sample project (28 call sites).

### `Type Into Text`
Full addressing set, plus `Text`, `EmptyField` (in, Boolean — clear first),
`CheckForFieldValid`. Use when the control needs real keystrokes rather than a value set.

### `Type Into by Append Text`
Appends after existing content. Same arguments as `Type Into Text`.

### `Type Into by Append Text Before`
Prepends before existing content. Same arguments.

### `Element Exists`
Full addressing set → `Exists` (out, Boolean). Probe before acting.

---

## Tables (Smart Client grids)

Addressing for all table activities: `WindowCtrlName`, `WindowTitle`, `SectionCtrlname`,
`GroupAaname`, `ContainerCtrlname`, `TableName`, plus the cell arguments below.

Cell arguments: `RowIndex` (Int32), `RowName` (String), `ColumnName` (String),
`TableIdx` (String), `RowIdx` (String), `TableInRowName` (String — a table nested in a row).

### `Table Extract`
→ `ExtractDataTable` (DataTable), `RowCount` (Int32).

### `Table Extract by Scrollbar`
For grids that virtualise rows. Adds `NumberOfScrollsDistance` (Int32),
`MaximumNumberOfScrolls` (Int32) → `ExtractDataTable`, `RowCount`.
Use this when `Table Extract` returns only the visible rows.

### `Table Click Cell`
Addressing + `RowIndex` / `RowName`, `ColumnName`, `RowIdx`, `TableIdx`.

### `Table Double Click Cell`
Same arguments as `Table Click Cell`.

### `Table Click Cell Button`
Clicks a button rendered inside a cell. Same arguments.

### `Table Click Row`
Addressing + `RowIndex`, `RowName`.

### `Table Expand Row`
Addressing + `RowIndex`, `RowName`.

### `Table Set Text`
Addressing + `RowIndex`, `ColumnName`, `RowName`, `RowIdx`, `Text`.

### `Table Get Cell Text By Name`
Addressing + `RowIndex`, `ColumnName`, `RowName` → `Value` (String). Reads from the UI.

### `Table Get Cell Text By Index`
Reads from an **already-extracted DataTable** — no UI access.
`ExtractDataTable` (in), `RowIndex` (Int32), `ColumnIndex` (Int32) → `Value` (String).

### `Table Get Cell Index By Name`
Addressing + `ColumnName`, `TableIdx` → `ColumIndex` (out, Int32) *(library's spelling)*.

### `Table Get Cell Name`
Addressing + `ColumIndex` (in, Int32) → `ColumnName` (out, String).

### `Table Get Column NameList`
Addressing → `ColumnNameList` (out, List&lt;String&gt;). Use to verify a grid's shape before
relying on column names.

### `Table Search By Index`
Searches an extracted DataTable across several columns at once.
`ExtractDataTable` (in), `SearchValues` (in, String), `ColumnIndexes` (in, String)
→ `RowIndex` (out, Int32), `Found` (out, Boolean).
`SearchValues` and `ColumnIndexes` are parallel delimited lists.

### `Table Search Count By Index`
Same inputs → `SearchCount` (out, Int32), `RowIndexList` (out, List&lt;Int32&gt;).

### `Table Select Right Click Menu`
Addressing + `Menu`, `RowIndex`, `ColumnName`, `RowName`, `TableInRowName`.

### `Table Scrollbar Click Up` / `Down` / `Left` / `Right`
Addressing only (`WindowCtrlName`, `WindowTitle`, `SectionCtrlname`, `GroupAaname`,
`ContainerCtrlname`). Manual scrolling when the *by Scrollbar* extract is not appropriate.

---

## Web tables (embedded Smart Client Report browser)

These target `<html app='smartclient.exe' …>` — the browser embedded **inside** the Smart
Client, not an external one.

Common arguments: `TableParentid`, `TableParentclass`, `TableIdx`, `WebTitle`,
`WindowCtrlName`.

### `Web Table Extract`
→ `ExtractedDataTable` (DataTable), `RowCount` (Int32).

### `Web Table Extract By Scrollbar`
Adds `NumberOfScrollsDistance`, `MaximumNumberOfScrolls` → `ExtractedDataTable`, `RowCount`.

### `Web Table Click Cell`
+ `RowIndex` (Int32), `ColumnIndex` (Int32).

### `Web Table Click By Col Name`
+ `RowIndex` (Int32), `ColumnName` (String).

### `Web Table Click Button`
+ `RowIndex` (Int32), `ColumnAaname` (String).

### `Web Table Get Row By Col Innertext`
+ `ColumnIndex` (Int32), `Innertext` (String) → `RowIndex` (out, Int32).

> **Known gap:** the TKB-UC11 sample project does **not** use these activities. Its
> `Web_Nav_System/` folder reimplements the same operations with raw `ExtractData`,
> `Click` and `GetAttribute` inside a `WindowScope`. See `.claude/skills/standards/references/systems/web-nav-system.md`.

---

## CyberArk / PHI

### `CyberArk/GetCyberArkAccount`
Retrieves an account from the CyberArk PHI vault via the SMCA portal.

| Arg | Dir | Type | Notes |
|---|---|---|---|
| `Category` | in | String | "Provide the identifier text from Category column" (library annotation). |
| `TimeoutInSeconds` | in | Int32 | "Waiting time for the phi application to start from smca". |
| `PhiApp` | in | String | |
| `AccountDict` | out | Dictionary&lt;String,String&gt; | |
| `Username` | out | String | |
| `Password` | out | SecureString | |

### `CyberArk/OpenPHI`
`in_smcaApplicationName`, `in_TimeOut` (Int32), `in_Category` → `out_BrowserPHI` (Browser).

### `CyberArk/ClosePHI`
No arguments. **Always call this after retrieving a secret.**

### `CyberArk/GetChildAttributesOfBodyContainer`, `CyberArk/PHI-HandleActionButtion` *(sic)*
Internal helpers of the PHI flow. Not intended for direct use.

### `SMCA/SMCALaunchApp`
`LaunchApp` (in, String). Launches a published application through SMCA.

---

## Utility (`Utility/`)

| Activity | Signature |
|---|---|
| `Get_Selector` | `SectionCtrlname`, `GroupAaname`, `ContainerCtrlname`, `FieldCtrlname` → `Selector` |
| `Get_Win_Selector` | `WinCrlName` *(sic)*, `WinTitle` → `WinSelector` |
| `Get_Table_Selector` | `TableName`, `RowIndex`, `ColumnName`, `RowName`, `TableInRowName`, `TableIdx`, `RowIdx`, `Selector` (in/out) |
| `Get_Web_Selector` | `WebTitle` → `WebSelector` (`<html app='smartclient.exe' title='…' />`) |
| `Get_Web_Table_Selector` | `Parentid`, `Parentclass`, `Idx`, `RowIndex`, `ColumnIndex`, `Tag`, `Aaname`, `Innertext`, `ColumnName`, `RowName` → `Selector` |
| `Get_Form_Field_CtrlName` | `in_CtrlName` → `out_CtrlName` |
| `Get_Form_Section_CtrlName` | `in_CtrlName` → `out_CtrlName` |
| `Get_Form_Container_CtrlName` | `in_CtrlName` → `out_CtrlName` |
| `Get_Form_Button_CtrlName` | `in_CtrlName` → `out_CtrlName` |
| `Get_Process_Name` | `WindowTitle` → `ProcessName`, `TargetProcess` (Process) |
| `Get_Remote_App` | → `CitrixApp` |
| `Scrollbar_Click` | `Selector`, `WinSelector` |
| `Table_Scrollbar_Click` | `ScrollbarSelector`, `Selector`, `WinSelector` |

---

## Gotchas

- **Spelling is load-bearing.** `ConfitmMessage`, `ColumIndex`, `WinCrlName`,
  `PHI-HandleActionButtion`, and the German filenames `Auftrag Öffnen`,
  `Select Tab Aktuellste Aufträge`. Copy them exactly.
- **`Click` uses `CtrlName`; everything else uses `FieldCtrlname`.** Easy to mistype.
- **`RowIndex` is `Int32` here** (unlike the Finnova library, where row/column arguments are
  Strings). `RowIdx` and `TableIdx` are Strings — they are selector `idx=` values, not row
  numbers.
- **`Table Extract` returns only materialised rows.** For virtualised grids use
  `Table Extract by Scrollbar` and check `RowCount` against what you expect.
- **The library does not throw on an Avaloq dialog.** If you ignore `ConfirmMessage`, the
  workflow silently continues against a modal window and the next activity fails with an
  unrelated selector error.
- **No logout activity exists.** `Stop` kills the process; that is what the sample project
  does in both `CloseAllApplications` and `KillAllProcesses`.
- **No activity reads mail, files or Excel** — see `.claude/skills/standards/references/systems/mail-system.md`, `.claude/skills/standards/references/systems/file-system.md`.
