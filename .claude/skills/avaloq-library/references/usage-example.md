# Avaloq library — worked call sequences

Patterns lifted from `../Avaloq/TKB-UC11.Kreditverletzung/Avaloq_System/`. These are library
call sequences; for the surrounding project structure see
`.claude/skills/standards/references/systems/avaloq-system.md`.

---

## 1. Login

```
RetryScope "Retry to get credential"  3 × 15 s
    TryCatch → Get Credential (AssetName = in_Avaloq_System_Credentials) → User, Password
    Condition: CheckTrue (SysError is Nothing)

RetryScope "Retry Avaloq Login"  18 × 10 min
    Send Hotkey  esc                       ' clear any stray modal from a previous attempt
    Assign SysError = Nothing
    TryCatch
      Try:  Login  User                   = User
                   Password               = Password        ' SecureString
                   SmartClientPath        = in_Avaloq_System_Client_Path
                   SmartClientArguments   = in_Avaloq_Systen_Arguments
                   TimeOutInSeconds       = 60
                   RetryNumber            = 3
                   RetryIntervalInSeconds = 60
      Catch: Log Warn "Retry: Avaloq Login exception-" + exception.Message
             SysError = exception.Message ; exception = Nothing
    Condition: CheckTrue (SysError is Nothing)
```

`SmartClientPath` and `SmartClientArguments` are Orchestrator assets — never literals.
`SmartClientArguments` carries the integration-server coordinates:
`-integrationServerHost … -integrationServerPort … -avaloqSystemId …`.

---

## 2. Run a report and extract the grid

The dominant pattern in this project — most `Avaloq_System/` workflows are a variant of it.

```
Select Menu             Menu = "<report path>"
' or
Execute Drop Down Menu  Menu           = "<menu path>"
                        BreakIfConfirm = True
                        ErrorMessage   = ErrMsg
                        ConfitmMessage = ConfirmMsg      ' sic

If Not String.IsNullOrEmpty(ConfirmMsg) → Throw BusinessRuleException(ConfirmMsg)

Set Text     WindowCtrlName  = "*task_desk2"
             FieldCtrlname   = "<search field>"
             Text            = in_Report_Search_Keyword   ' from an Orchestrator asset
             CheckForFieldValid = True

Click        WindowCtrlName = "*task_desk2"
             CtrlName       = "<execute button>"          ' note: CtrlName, not FieldCtrlname
             BreakIfConfirm = True
             ErrorMessage   = ErrMsg
             ConfirmMessage = ConfirmMsg

Sync         WinSelector      = WinSelector
             TimeOutInSeconds = 60
             BreakIfConfirm   = True

Table Get Column NameList  → ColumnNameList     ' verify the grid shape first
Table Extract              → ExtractDataTable, RowCount
If RowCount = 0 → Throw BusinessRuleException("Report returned no rows for …")

Close Tab    WindowCtrlName = "*task_desk2", TabName = "<report tab>"
```

**`Table Get Column NameList` before trusting column names.** Avaloq reports vary their
columns by parameterisation; checking is cheaper than a wrong extract.

---

## 3. Virtualised grids

`Table Extract` returns only materialised rows. When the grid scrolls:

```
Table Extract by Scrollbar
    WindowCtrlName         = "*nav_desk"
    SectionCtrlname        = "…"
    TableName              = "…"
    NumberOfScrollsDistance= 10
    MaximumNumberOfScrolls = 50
    ExtractDataTable       = dt
    RowCount               = RowCount
```

Compare `RowCount` against what the report claims. If it equals
`NumberOfScrollsDistance × MaximumNumberOfScrolls`, you have hit the ceiling and are
silently truncating.

---

## 4. Find a row, then act on it

Search the extracted DataTable in memory — do not re-read cells from the UI in a loop.

```
Table Search By Index    ExtractDataTable = dt
                         SearchValues     = String.Format("{0};{1}", KV_BP, KV_Betrag)
                         ColumnIndexes    = "2;5"          ' parallel delimited lists
                         RowIndex         = RowNr
                         Found            = Found

If Not Found → Throw BusinessRuleException("No task result row present")

Table Click Cell         WindowCtrlName = "*task_desk2"
                         TableName      = "…"
                         RowIndex       = RowNr            ' Int32
                         ColumnName     = "Bearbeiten"
```

`Table Search Count By Index` returns `SearchCount` + `RowIndexList` when several rows can
match.

---

## 5. Open an order

```
Auftrag Öffnen   Auftrag_Nr     = KV_Auftragsnummer
                 BreakIfConfirm = True
                 ErrorMessage   = ErrMsg
                 ConfirmMessage = ConfirmMsg

If Not String.IsNullOrEmpty(ConfirmMsg)
    ' most commonly "order is already in use by another user"
    → Throw BusinessRuleException(ConfirmMsg)
If Not String.IsNullOrEmpty(ErrMsg)
    → Throw ApplicationException(ErrMsg)
```

Use `Auftrag Show` for a read-only view — same signature, no lock taken.

---

## 6. Fill a form and confirm

```
Set Text      WindowCtrlName    = "…"
              SectionCtrlname   = "…"
              ContainerCtrlname = "…"
              FieldCtrlname     = "…"
              Text              = in_Value
              CheckForFieldValid= True        ' verifies the field accepted it

Type Into by Append Text        ' when adding to existing content rather than replacing
              FieldCtrlname = "kommentar"
              Text          = "[RPA] " & in_Comment
              EmptyField    = False

Click Text Button  FieldCtrlname = "…"        ' or Click with CtrlName
Sync               WinSelector   = WinSelector
Click Confirm OK                              ' unconditional dialog
```

`Type Into by Append Text` / `…Text Before` exist precisely so a comment field can be
extended without losing what a human wrote. `Avaloq_Ticket_bearbeiten.xaml` uses both, and
`Process.xaml` refuses to touch an order whose comment does not start with `[RPA`.

---

## 7. Launch another application from Avaloq

```
Select Right Click Menu   FieldCtrlname = "pos_id"
                          Menu          = "Aufruf CardOne: Konto-Detail anzeigen"
```

Avaloq passes the customer context to the target application. See
`.claude/skills/standards/references/systems/cardone-system.md`.

---

## 8. Clean up

```
Close Tab      WindowCtrlName = "…", TabName = "…"     ' preferred — 9 call sites
Close Window   WindowCtrlName = "…"
Window Exists  WindowCtrlName = "…" → Exists           ' verify before assuming
Stop           Process = "SmartClient"                  ' job end only
```

**A workflow that opens a tab closes it before returning.** Otherwise the next transaction
starts against the wrong tab.

---

## Anti-patterns

| Don't | Do |
|---|---|
| `Delay` after an action | `Sync (WinSelector = …, TimeOutInSeconds = 60)` |
| Ignore `ConfirmMessage` | `BreakIfConfirm=True` and branch on it |
| Hardcode the SmartClient path or arguments | Orchestrator assets `Avaloq_SmartClient_Path` / `_Arguments` |
| `FieldCtrlname` on `Click` | `Click` takes **`CtrlName`** |
| Pass a row number to `RowIdx` | `RowIndex` is the row (Int32); `RowIdx`/`TableIdx` are selector `idx=` strings |
| Loop `Table Get Cell Text By Name` over a grid | `Table Extract` once, then `Table Get Cell Text By Index` on the DataTable |
| Assume `Table Extract` got every row | use `Table Extract by Scrollbar` and check `RowCount` |
| Raw `ExtractData` on a report | `Web Table Extract` — but see the documented gap in `systems/web-nav-system.md` |
| Leave a tab open | `Close Tab` before returning |
