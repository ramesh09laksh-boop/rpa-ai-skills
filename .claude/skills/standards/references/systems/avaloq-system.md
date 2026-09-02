# `Avaloq_System/` — Avaloq Smart Client

UI interaction with the Avaloq Smart Client. For the activity API of the underlying
library, use `.claude/skills/avaloq-library/`.

Present in `../Avaloq/TKB-UC11.Kreditverletzung` (13 workflows). Business domain: credit-limit
violations (Kreditverletzungen) at TKB.

## Session

### Login — `Avaloq_System/Avaloq_Login.xaml`

Arguments: `in_Avaloq_System_Credentials`, `in_Avaloq_System_Client_Path`,
`in_Avaloq_Systen_Arguments` *(sic — "Systen")*.

Invoked from `Framework/InitAllApplications.xaml`:

```vb
in_Avaloq_System_Credentials  = in_Config("Avaloq_System_Credendials").ToString  ' sic
in_Avaloq_System_Client_Path  = in_Config("Avaloq_System_Client_Path").ToString
in_Avaloq_Systen_Arguments    = in_Config("Avaloq_System_Client_Arguments").ToString
```

Body — **two nested retry scopes**, both using the shared `SysError` idiom
(see `../error-handling.md`):

```
RetryScope "Retry to get credential"  3 × 15 s
  TryCatch → Get Credential (AssetName = in_Avaloq_System_Credentials) → User, Password
  Condition: CheckTrue (SysError is Nothing)

RetryScope "Retry Avaloq Login"  18 × 10 min          ' ~3 hours of patience
  Send Hotkey  esc                                     ' clear any stray modal first
  Assign SysError = Nothing
  TryCatch → library Login (SmartClientPath, SmartClientArguments,
                            TimeOutInSeconds=60, RetryNumber=3, RetryIntervalInSeconds=60)
             Catch → Log Warn "Retry: Avaloq Login exception-" + exception.Message
  Condition: CheckTrue (SysError is Nothing)
```

Two details worth keeping:

- **`Send Hotkey esc` before login.** A leftover modal from a previous attempt otherwise
  blocks the login form.
- **18 retries at 10-minute intervals.** Avaloq is expected to be unavailable for long
  stretches (batch windows). Do not shorten this without checking the operating schedule.

Credentials come from an **Orchestrator Credential asset** (`AVQ_Credential_1004`), not
CyberArk — the opposite of the Swisscom Finnova projects. See `.claude/skills/security/`.

### Connection parameters

`Avaloq_System_Client_Arguments` (Orchestrator asset `Avaloq_SmartClient_Arguments`) holds
the integration-server coordinates:

```
-integrationServerHost sbttgavaint01.tgcorp.ch -integrationServerPort 10023 -avaloqSystemId TATG11
```

`Avaloq_System_Client_Path` (asset `Avaloq_SmartClient_Path`) holds the executable path.
Both are assets so the same code runs against test and production instances.

### Window control names

Avaloq addresses windows by `ctrlname`, not title:

| Window | `ctrlname` |
|---|---|
| Login | `LoginView` |
| Ribbon shell | `AvaloqRibbonShell` |
| Task Desk | `*task_desk2` |
| Navigator Desk | `*nav_desk` |

### Shutdown

`CloseAllApplications.xaml` and `KillAllProcesses.xaml` have the same body:
library `Stop` on Avaloq, then `CardOne_System\CardOne_Logout.xaml`. There is no Avaloq
logout activity.

## Workflow inventory

| Workflow | In | Out |
|---|---|---|
| `Avaloq_Login` | `in_Avaloq_System_Credentials`, `in_Avaloq_System_Client_Path`, `in_Avaloq_Systen_Arguments` | — |
| `Avaloq_Navigate_To_Task_Template` | `in_Search_Keyword`, `in_Exception` | — |
| `Avaloq_Navigator_Desk_Extract` | `in_Report_Search_Keyword`, `in_MinimalerKapitalverletzungsbetrag`, `in_MaximalerKapitalverletzungsbetrag`, `in_KV_BP`, `in_Config` | `out_dt_TransactionData` |
| `Avaloq_Auftrag_Report_Öffnen` | `in_Report_Search_Keyword`, `in_KV_BP`, `in_KV_BP_Name`, `in_KV_Betrag` | `out_RowCount`, `out_RowNr` |
| `Avaloq_Check_Order_Already_Opened` | `in_Config`, `in_KV_Betrag`, `in_KV_BP` | `io_KV_Auftragsnummer` |
| `Avaloq_Ticket_bearbeiten` | `in_KV_Auftragsnummer`, `in_KV_Kommentar`, `in_KV_Lösungsmassnahmen`, `in_KV_Regelungsbetrag`, `in_KV_Fälligkeit`, `in_KV_Mahnung_1_neu`, `in_KV_Mahnung_2_neu`, `in_KV_Status`, `in_KV_BP`, `in_KV_Betrag`, `in_KV_Konto`, `in_Config`, `in_TransactionItem` | — |
| `Avaloq_Prüfte_BP-Saldo` *(sic)* | `in_KV_BP`, `in_Report_Search_BP_Saldo` | `out_BP_Saldo`, `out_BP_Eröffnungsdatum` |
| `Avaloq_Prüfe_Liquiditätskonti` | `in_KV_BP`, `in_KV_Regelungsbetrag`, `in_Report_Search_Liquiditätskonti` | `out_LiqDT` |
| `Avaloq_Prüfe_Fristenverletzung` | `in_KV_Konto`, `in_Report_Search_Fristenverletzung` | — |
| `Avaloq_Report_PrüfeInflow_letzten_3Monate` | `in_KV_BP`, `in_KV_Auftragsnummer`, `in_KV_Regelungsbetrag`, `in_KV_Konto`, `in_KV_Betrag`, `in_Report_Search_letzten3Monate`, `in_Config`, `in_TransactionItem` | `out_IF_Ratio` |
| `Avaloq_Interessewahrender_Übertrag` | `in_KV_Regelungsbetrag`, `in_LiqDT`, `in_KV_Konto` | `out_KU_Auftrag`, `out_Liq_Konto`, `out_LiqPopUpExists_Violation`, `out_LiqPopUpExists_Withdrawal` |
| `Avaloq_Mahngebühr_verrechnen` | `in_KV_BP`, `in_Mahngebühr_Queue` | — |
| `Avaloq_Kreditkarte_sperren` | `in_Avaloq_System_Credentials`, `in_KK_entsperren_Queue`, `in_Config`, `in_KV_Betrag`, `in_KV_BP`, `io_KV_Auftragsnummer`, `in_KV_Konto` | `out_KK_Anzahl_aktiv`, `out_KK_Anzahl_gesperrt`, `out_KK_Anzahl_Fehler`, `out_CO_KKNrList` |

## Library activity usage

Frequency in this folder — a good guide to what matters:

| Activity | Calls |
|---|---|
| `Set Text` | 28 |
| `Click` | 11 |
| `Close Tab` | 9 |
| `Table Extract` | 8 |
| `Get Text` | 6 |
| `Execute Drop Down Menu` | 6 |
| `Table Click Cell` | 5 |
| `Table Get Cell Text By Name` | 5 |
| `Table Get Column NameList` | 4 |
| `Select Menu` | 3 |

`Close Tab` at 9 calls reflects the invariant: **a workflow that opens an Avaloq tab closes
it before returning.**

## Reports are the main data source

Most `Avaloq_System/` workflows are "run a report, extract the grid":

```
Select Menu / Execute Drop Down Menu   → navigate to the report
Set Text                               → search keyword from an Orchestrator asset
Click                                  → execute
Sync
Table Extract / Table Extract by Scrollbar → DataTable
Table Get Column NameList              → verify the grid shape before trusting column names
Table Search By Index                  → locate the row
Close Tab
```

Report search keywords are **Orchestrator assets**, one per report, so they can be retuned
without a redeploy:

| Config key | Asset |
|---|---|
| `Report_Search_Keyword` | `Report_Hauptprozess_Keyword` |
| `Report_Search_letzten3Monate` | `Report_letzten3Monate_Keyword` |
| `Report_Search_Liquiditätskonti` | `Report_Liquiditätskonti_Keyword` |
| `Report_Search_BP-Saldo` | `Report_BP-Saldo_Keyword` |
| `Report_Search_Fristenverletzung` | `Report_Fristenverletzung_Keyword` |

Report output renders in the **embedded Smart Client browser** — see
`web-nav-system.md`.

## Transaction flow

`Framework/Process.xaml`. One transaction = one credit-limit violation. The steps are
numbered "Schritt N" in the workflow display names, matching the SDD.

```
Init
  Tracelog_Get → already processed? → BusinessRuleException("Go to next order")
Search for BP & Betrag
  → RowNr = -1 → BusinessRuleException("No task result row present")
TryCatch "Try to editing order"
  Web_Nav_System\_Web_Nav_Table_Click_Cell_Bearbeiten.xaml
  Catch → order in work → Tracelog_Append → BusinessRuleException(exception.Message)
        → report failure  → ApplicationException("Der Report …")
        → otherwise       → ApplicationException(exception.Message)
KV_Kommentar not empty and not starting "[RPA" → BusinessRuleException("The order can be processed manually.")
KV data extraction (Betrag, BP, Position/Konto, Mahnung 1, Mahnung 2)
  Position contains "Abza" → BusinessRuleException("Position den Wert Abza beinhaltet")
  Status 1. Mahnung missing → BusinessRuleException("Status 1. Mahnung kann nicht gefunden…")

Then a decision tree (flowchart) selecting one outcome code K30…K140:
  BP opening date < 90 days                → Avaloq_Ticket_bearbeiten (Schritt 5.3)
  Comfort/Premium position                 → Avaloq_Prüfe_Fristenverletzung (Schritt 6)
  KV_Betrag >= 100 and 2. Mahnung erfolgt  → Avaloq_Ticket_bearbeiten (K80)
  1. Mahnung erfolgt and Liq-Konto present → Avaloq_Interessewahrender_Übertrag (Schritt 21)
      Liq violation and KV_Betrag >= 100   → Avaloq_Mahngebühr_verrechnen (Schritt 19)
                                           → Avaloq_Ticket_bearbeiten (K110)
      Liq withdrawal                       → Avaloq_Ticket_bearbeiten (K140)
      otherwise                            → Avaloq_Ticket_bearbeiten (K130)
                                           → KK_entsperren_Queue_Item_Update
  Verletzungsdauer > 30                    → Avaloq_Kreditkarte_sperren (Schritt 16)
                                             → K100 / K101 / K102 by card counts
  IF_Ratio > 2                             → K90
  Keine Mahnung, dauer < 122 / < 180 / else→ K30 / K40 / K50
  BP_Saldo > Regelungsbetrag               → K70, else K60
```

Every leaf ends in `Avaloq_Ticket_bearbeiten` with a different outcome code — the process
always writes a ticket, and the tree only decides which. Preserve that shape when adding a
branch.

## Multi-queue side effects

This process feeds two other queues:

| Config | Queue | Written by |
|---|---|---|
| `OrchestratorQueueName_Mahngebühr` | `UC14_Mahngebühr_Queue` | `Avaloq_Mahngebühr_verrechnen` |
| `OrchestratorQueueName_KK_entsperren` | `UC15_KK_entsperren_Queue` | `Logic/KK_entsperren_Queue_Item_Add`, `…_Update` |

`Entsperren_QueueItem_Postpone_InHours` (Orchestrator asset) postpones the unblock item.
