# `Web_Nav_System/` — Avaloq Navigator report tables

**Browser-based, but embedded.** Avaloq Smart Client renders its reports in an embedded
browser inside `smartclient.exe`. This folder drives those report tables.

Present in `../Avaloq/TKB-UC11.Kreditverletzung` (5 workflows). All files are `_`-prefixed —
they began as scratch workflows and were promoted into production without renaming.

## The window

```
<html app='smartclient.exe' title='Smart Client Report' />
```

Note `app='smartclient.exe'`, **not** `chrome.exe`. This is not an external browser; there
is no browser process to attach to, close or kill, and browser-level activities like
`OpenBrowser` / `RefreshBrowser` do not apply. Use `WindowScope`, not `BrowserScope`.

## Documented gap: the library is bypassed

`Swisscom.UiPath.UIAutomation.Avaloq` ships a `Web Table *` family built exactly for this
surface — `Web Table Extract`, `Web Table Extract By Scrollbar`, `Web Table Click Cell`,
`Web Table Click By Col Name`, `Web Table Click Button`, `Web Table Get Row By Col Innertext`.

**This folder does not use any of them.** It reimplements the same operations with raw
`WindowScope` + `Activate` + `ExtractData` / `Click` / `GetAttribute`. The only library
activities it calls are `Sync` (3×) and `Utility/Get_Win_Selector` (2×).

Before adding a workflow here, check whether a `Web Table *` activity already does the job —
see `.claude/skills/avaloq-library/references/activities.md`. The reason for the bypass is not
recorded anywhere in the project; treat it as unexplained rather than deliberate, and
verify against the live report before switching an existing workflow over.

## The implementation pattern

`_Web_Nav_Table_Extract.xaml`:

```
Sequence "Data Scraping"
  Variables:
    Selector    = <webctrl parentid='grid1' tag='TABLE' parentclass='objbox' />
    WinSelector = <html app='smartclient.exe' title='Smart Client Report' />

  WindowScope (Selector = WinSelector)
    Activate                       ' the report must have focus before extraction
    ExtractData
       ContinueOnError   = True
       MaxNumberOfResults= 1000
       SimulateClick     = True
       TimeoutMS         = 500
       ExtractMetadata   = <extract-table get_columns_name='1' get_empty_columns='1'
                                          columns_name_source='Longest' />
       → ExtractDataTable
    RowCount = ExtractDataTable.Rows.Count
```

Points that matter:

- **`Activate` before extracting.** The embedded report does not render reliably without
  focus.
- **`ContinueOnError=True` on `ExtractData`.** A failed extract yields an empty DataTable
  rather than an exception — so `RowCount` **must** be checked by the caller. `Process.xaml`
  does this and throws `BusinessRuleException("No task result row present")` when `RowNr = -1`.
- **`columns_name_source='Longest'`** — column names are taken from the longest header
  variant, because the report header wraps.
- **`MaxNumberOfResults=1000`** is a hard ceiling. A report with more rows is silently
  truncated. Nothing in the project detects this.
- The grid is anchored on `parentid='grid1'` + `parentclass='objbox'` — Avaloq's report grid
  container, stable across reports.

## Workflow inventory

| Workflow | In | Out |
|---|---|---|
| `_Web_Nav_Table_Extract` | *(no arguments)* | `ExtractDataTable`, `RowCount` |
| `_Web_Nav_Table_Extract by Scrollbar` | `NumberOfScrollsDistance`, `MaximumNumberOfScrolls` | `ExtractDataTable`, `RowCount` |
| `_Web_Nav_Table_Get_Row` | `Visibleinnertext`, `ColumnNr` | `RowNr` |
| `_Web_Nav_Table_Click_Cell_Bearbeiten` | `RowIndex` | — |
| `_Web_Nav_Table_Sort_By_Kreditverlet` | *(no arguments)* | — |

`_Web_Nav_Table_Get_Row` returns `-1` when the row is not found — the caller must test for
it. `_Web_Nav_Table_Click_Cell_Bearbeiten` is the entry point into editing an order and is
wrapped in a `TryCatch` in `Process.xaml`.

## Position in the transaction

```
Avaloq_Navigator_Desk_Extract        ' run the report
_Web_Nav_Table_Sort_By_Kreditverlet  ' sort by violation
_Web_Nav_Table_Extract               ' scrape the grid
_Web_Nav_Table_Get_Row               ' locate this transaction's row → RowNr
  RowNr = -1 → BusinessRuleException("No task result row present")
_Web_Nav_Table_Click_Cell_Bearbeiten ' open it for editing  (in a TryCatch)
  Catch → "order in work" → Tracelog_Append → BusinessRuleException
        → report failure  → ApplicationException("Der Report …")
```

## Leftovers to clean up, not copy

- `WriteLine "RowCount=…"` in `_Web_Nav_Table_Extract.xaml` — debug output left in
  production. Use `Log Message` at `Trace`.
- The `_` filename prefix on production workflows contradicts the convention that `_` means
  scratch (see `../naming-conventions.md`). Keep the names for now — renaming breaks the
  `InvokeWorkflowFile` paths in `Process.xaml` — but do not extend the pattern to new files.
