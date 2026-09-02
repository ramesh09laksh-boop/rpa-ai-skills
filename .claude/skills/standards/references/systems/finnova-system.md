# `Finnova_System/` — Finnova core banking

UI interaction with the Finnova Java thin client. For the activity API of the underlying
library, use `.claude/skills/finnova-library/`.

Present in `UC39_BPO_manuelle_Börsenaufträge` (40 workflows) and
`PJFVA-966_UC81_BPO_VD03_TK _Valoren` (23 workflows).

## Session

### Login

UC39 — `Finnova_System/Finnova-Login.xaml` (`in_FinnovaLaunchCmd`, `in_ObjectName`, `in_TOWER`):

1. `Logic\Logic-Get_Credential.xaml` — `Get Credential` in a `RetryScope` (3 × 15 s),
   `CacheStrategy=None`. Asset name is the PHI account name from config.
2. Tower fix-up: for NOVUS the username becomes `String.Format("{0} 0", User)`. Undocumented
   in the code — preserve it.
3. Library `Login` with `Timeout=180`, `RetryLogin=2`, `RetryIntervalSeconds=45`,
   `CitrixUrl="https://smca.swisscom.com"`.

UC81 — `Finnova_System/Finnova_Login.xaml` (`in_Bank`, `in_VaultName`, `in_FinnovaLaunchCmd`)
takes the password from the **CyberArk PHI vault** (`Logic-PHI_Vault_Get.xaml` →
`Get PHI Vault`) instead of an Orchestrator credential. Both patterns are live — follow the
one the project already uses. See `.claude/skills/security/`.

### Where login is invoked

| Project | Where | Consequence |
|---|---|---|
| UC39 | `Framework/InitAllApplications.xaml` — once per job | Finnova is open when `Process` starts |
| UC81 | inside `Process.xaml`, per transaction, in a `TryCatch` | `InitAllApplications.xaml` is **empty** — do not assume the app is open |

### Window titles are per tower

```vb
WinTitel = in_Config("Finnova_System_Win_Title_" + in_TOWER).ToString
```

| Tower | Title |
|---|---|
| ENT | `BRZ Entris*` |
| ESP | `SLM -*` |
| ZGKB | `ZGKB -*` |
| PBS | `Habib Bank AG -*` |
| NOVUS | `BLK / BSS*` |

Never hardcode a title. Every UC39 `Finnova_System/` workflow takes `in_WinTitel` for this
reason — thread it through.

### Citrix RemoteApp

The library reads the **environment variable `isRemoteApp`** when building window selectors.
Nothing in the workflow sets it. If selectors resolve on one runner and fail on another,
check that variable first. Detail in `.claude/skills/finnova-library/references/selector-model.md`.

### Shutdown

No logout workflow exists in either project — `CloseAllApplications` / `KillAllProcesses`
terminate the process (`Stop`, `Stop BOAL`). If your SDD requires a clean logout you will
have to build it; there is no library activity for it.

## Workflow inventory — UC39 (order booking)

Every workflow takes `in_WinTitel` unless noted.

| Workflow | In | Out |
|---|---|---|
| `Finnova-Login` | `in_FinnovaLaunchCmd`, `in_ObjectName`, `in_TOWER` | — |
| `Finnova-Handelsgruppe_Search` | `in_Handelsgruppe` | `out_Status` |
| `Finnova-System_Search` | — | `out_Status` |
| `Finnova-Nachbearbeiten_Search` | — | — |
| `Finnova-Nachbearbeiten_Rows_Extract` | `in_BankListDT` | `out_ExtractDT` |
| `Finnova-System_Valor_DoubleClick` | — | — |
| `Finnova-System_Save` | *(no arguments)* | — |
| `Finnova-System_DataRow_Extract` | `in_RowData`, `in_Mandat` | `out_DataDict` |
| `Finnova-Borsen_Abrechnungen_Extract` | `in_WinBorsenAbrech`, `in_FinCounterParty` | `out_BorsenAbrechDict`, `out_FeeDT` |
| `Finnova-Borsenabrechnugen_Status_Get` | — | `out_BorsenabrechnugenStatus` |
| `Finnova-BorsenPlatz_Verify` | — | `out_IsChangeInBorsenPlatz` |
| `Finnova-BorsenPlatz_Nr_Get` | `in_BorsenPlatz` | `out_BorsenPlatzNr` |
| `Finnova-HauptBörsenplatz_Get` | — | `out_HauptBorsenPlatz` |
| `Finnova-BorsenPlatze_Navigate` | *(no arguments)* | — |
| `Finnova-Borse_Derive` | — | `out_BorseList` |
| `Finnova-ISIN_Extract` | `in_Counterparty` | `out_ISIN` |
| `Finnova-CounterParty_Get` | — | `out_FinCounterParty` |
| `Finnova-CounterParty_With_BaseList_Check` | `in_CounterPartyDT`, `in_WinBorsenAbrech` | `out_CounterParty`, `out_CounterPartyExists` |
| `Finnova-Depotstelle_Konto_Check` | `in_Tower`, `in_Bank` | `out_ValidKonto`, `out_Konto` |
| `Finnova_Depotstelle_ZGKB_Verify` | `in_Tower`, `in_SkipDepotstelle` | — |
| `Finnova-KD_Komm_Get` | — | `Exists`, `KommValue` |
| `Finnova-KD_Komm_Update` | *(no arguments)* | — |
| `Finnova-Commsn_Update` | `in_Komm` | — |
| `Finnova-GP_KD_Zero_Komm_Update` | *(no arguments)* | — |
| `Finnova-Fee_Update` | `in_Fee`, `in_FeeText`, `in_Bank` | — |
| `Finnova_System_Fee_Add` | `in_Fee` | `out_RowNr` |
| `Finnova-TradeConfirm_Fee_Verify` | *(no arguments)* | — |
| `Finnova-Net_Amt_Verify` | `in_PDFNetAmt` | `out_AmountCheck` |
| `Finnova-Trade_ID_Table_Borse_Fill` | — | `out_IsSuccessful` |
| `Finnova-Trade_ID_Table_Details_Fill` | `in_PDFTradeBrkDT`, `in_TradeConfPdfDict` | — |
| `Finnova-Workflow_Tariff_Calculation` | *(no arguments)* | — |
| `Finnova-Message_Accept` | — | — |
| `Finnova-Backoffice_Msg_Send` | *(no arguments)* | — |
| `Finnova_System-GP_Backoffice_Msg_Check` | `in_GP_BackofficeText_BE_Pattern` | — |
| `Finnova_System-GP_Backoffice_Msg_Get` | — | `out_MeldungText` **(declared as `in` — bug)** |
| `Finnova_System_Weiterleiten` | `in_WinBorsenAbrech` | — |
| `Finnova_DLZ_Borse_BackOffice_Navigate` | — | — |
| `Finnova_System_Transaction_Data_Read` | `in_Config`, `in_TOWER`, `in_BankListDT` | `io_TransactionData` |

## Workflow inventory — UC81 (securities master data)

All take `in_Config` and `in_TransactionItem` (`QueueItem`) unless noted.

| Workflow | In | Out |
|---|---|---|
| `Finnova_Login` | `in_Bank`, `in_VaultName`, `in_FinnovaLaunchCmd` | — |
| `Finnova-Valoren_Search` | `in_Valor` | `out_Status`, `out_Visum` |
| `Finnova-Valoren_Status_Check` | `in_Valor` | — |
| `Finnova-Valorenstamm_Close` | *(no arguments)* | — |
| `Finnova_System_Speichern` | `WindowTitle` | `out_MsgInfo` |
| `Finnova-Fonds_Process` | `in_Risikodomizil_Finnova`, `in_Depostelle_Finnova`, `in_Risikotitelart_Finnova`, `in_TK_FondsTyp_Finnova`, `in_Instrument_Nr_Mail`, `in_UBS_Fund_Category` | — |
| `Finnova-Obligationen_Process` | `in_ValorNr`, `in_BilanzCodeNostroFinnova` | — |
| `Finnova-Strucki_Process` | `in_Risikodomizil_Finnova`, `in_Kurztext_Struki_DE/FR/EN`, `in_HändlerSymbol_Underlying_SIX`, `in_Instrument_Nr_Mail` | — |
| `Finnova-Strucki_Kurztext_Anpassung` | `in_KurzText_DT`, `in_Kurztext_Struki_DE/EN/FR` | — |
| `Finnova-Strucki_Nachpartikel_Indices_Get` | `io_Kurztext_Struki_DE/EN/FR` | `out_IsIndex`, `out_Nachpartikel` |
| `Finnova-Repliblockiert_Process` | `in_System`, `in_Instrument_Nr_Mail`, `in_Instrument_Typ_SIX`, `in_in_KurztextErmittelnDT` *(sic)* | — |
| `Finnova-Repliblockiert_Strukis_Process` | `in_Instrument_Nr_Mail`, `in_System`, `in_TextDT`, `in_KurztextErmittelnDT` | — |
| `Finnova-Repliblockiert_Text_Play` | `in_ValorNr`, `in_PlayIdx`, `in_ScrollIdx`, `in_TableIdx`, `in_System`, `in_TextDT` | — |
| `Finnova-Text_Play` | `Text_DT`, `in_ValorNr`, `in_PlayIdx`, `in_ScrollIdx`, `in_TableIdx`, `in_TextIdx`, `in_TrimPattern` | — |
| `Finnova-Text_Process_And_Speichern` | `in_Instrument_Nr_Mail` | — |
| `Finnova-Kurztext_Replace` | `in_Kurztext_Struki_Replace` | — |
| `Finnova-Replizierung_Ermitteln` | `in_Bank`, `in_Instrument_Nr_Mail` | — |
| `Finnova-TK_Fondstyp_Get` | *(no arguments)* | `out_TK_Fondstyp_Finnova` |
| `Finnova-Zusatz_Bestandeskorr_Verify` | — | — |
| `Finnova-CheckBox_Play` | `in_Idx` | — |
| `Finnova-Duplicate_Text_Remove` | `in_idx` | — |

## Transaction flow — UC39

```
Main (in_ENV, in_TOWER) → InitAllSettings → InitAllApplications → Finnova-Login
Process.xaml:
  WinTitel = in_Config("Finnova_System_Win_Title_" + in_TOWER)
  1  trace-log check → already processed? skip
  2  Get Mandat by Bank ; Close Window
  3  Finnova-Handelsgruppe_Search → Status
  4  IF Status ~ "Nachbearbeiten|Zu visieren"
       Finnova-Borsenabrechnugen_Status_Get
       Finnova-System_Valor_DoubleClick
       Finnova_Depotstelle_ZGKB_Verify
       Finnova_System-GP_Backoffice_Msg_Check   → BusinessRuleException("Can't process, …")
       Finnova-KD_Komm_Get
       Finnova-CounterParty_With_BaseList_Check → CP not supported? skip
       Finnova-Depotstelle_Konto_Check
  5  Dest ∈ {TEL, BLP_EMSX, BLP_TSOX}?
       YES  Finnova_System_DataRow_Extract → BorsenPlatz_Verify →
            Borsen_Abrechnungen_Extract → ISIN_Extract → Logic-TEL_Process
            ├ confirmation OK → KD_BackOffice_Msg_Adjust → Borsenabrechnugen_Status_Get
            │                 → Workflow_Tariff_Calculation → Message_Accept
            │                 → Weiterleiten → System_Search
            │                 → still Nachbearbeiten/Zu visieren?
            │                     Throw BusinessRuleException("Please check the order in status:…")
            └ no confirmation → Backoffice_Msg_Send
       NO   Fee_Update → TradeConfirm_Fee_Verify
            (fee > net amount → BusinessRuleException)
            Gegenwert? → Commsn_Update → System_Save → KD_Komm_Update
                       → BorsenPlatz_Verify → Workflow_Tariff_Calculation
                       → Fee_Update → System_Save
```

## Transaction flow — UC81

```
Process.xaml:
  1  SIX_ID_Login → SIX_iD_Instrument_Search → SIX_iD_Instrument_Verify → Instrument_Typ_SIX
  2  TryCatch: Finnova_Login → Finnova-Valoren_Search → out_Status, out_Visum
       Catch → Mail-_Process_Exception
  3  Switch Instrument_Typ_SIX
       "Forderungspapier (1)"                     → Logic-Instrument_Obligationen_Process
       "Hebelprodukt/Bezugsrecht (5)"             → Logic-Instrument_Warrants_Process
       "Anlagefonds-Anteilschein/Trust Share (3)" → Logic-Instrument_Fonds_Process
       "Strukturierte Instrumente (12)"           → Logic-Instrument_Strukis_Process
       "Optionen & Futures (ETD) (4)"             → Finnova-Text_Process_And_Speichern
       default                                    → Mail-_Process_Exception (Exception 3)
  4  Visum = "Repli blockiert" → Finnova-Repliblockiert_Process
  5  SIX_ID-Instrumentendetailinformationen_Close → Mail-Archiv_Move
```

**UC81 does not throw business exceptions from `Process.xaml`.** It invokes
`Mail-_Process_Exception.xaml` with a numbered `in_ExceptionNr` mapping to `Exception_<n>_Msg`
in config, leaving the queue item successful while mailing a human. UC39 throws
`BusinessRuleException`. Pick one convention per project; do not mix.

## Conventions to follow

- One shared save workflow (`Finnova-System_Save.xaml`, invoked 12 times) — never an inline
  `Click Toolbar Button`.
- `Finnova_System/` reads and writes the UI; `Logic/` decides. UC39 keeps this strictly.
- A workflow that opens a Finnova window closes it before returning.
- Business rejections carry Finnova's own message text.
- Zero raw selectors — UC39 has none outside `Tests/`. Match that.
