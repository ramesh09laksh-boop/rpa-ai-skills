# `SIX_ID_System/` — SIX iD instrument reference data

**Browser-based (Chrome).** The SIX Group financial-instrument reference portal. Used by
`PJFVA-966_UC81_BPO_VD03_TK _Valoren` to look up instrument attributes that are then written
into Finnova.

**There is no custom library for SIX iD.** Every workflow uses raw UiPath UI Automation —
`OpenBrowser`, `BrowserScope`, `UiElementExists`, `Click`, `TypeInto`, `GetText`,
`ExtractData` — with hand-written selectors. See `.claude/skills/web/` for selector strategy and
`.claude/skills/web/references/verified-flows.md` before changing any of them.

## Configuration

| Config key | Value (PRD) |
|---|---|
| `SIX_ID_System_URL` | `https://portal.six-group.com` |
| `SIX_ID_System_CustomerID` | `CH29358` |
| `SIX_ID_System_Email` | `michael.sterchi@swisscom.com` |
| `SIX_ID_System_PHI_Vault_Name_FIN` | `SMG3@SIXID` |
| `SIX_ID_System_PHI_Vault_Name_AVQ` | `SMG2@SIXID` |

The password comes from the CyberArk PHI vault. Two Orchestrator assets also appear:

```vb
String.Format("{0}_UC81_SIX_System_AccountName", Environment.UserName)   ' per-robot account
"UC81_SIX_System_AccountName_Override"
```

i.e. the SIX account is chosen **per robot machine**, with a global override asset. If a job
fails to log in on a new runner, the per-user asset probably does not exist yet.

## Login — `SIX_ID_Login.xaml`

Arguments: `in_SIX_System_Url`, `in_CustomerID`, `in_ObjectName`, `in_Email`,
`in_ScreenshotFolder`.

The pattern is **idempotent login** — the same shape as CardOne and UBS KeyTrader:

```
UiElementExists  <html app='chrome.exe' title='SIX iD HTML' />
                 <webctrl tag='INPUT' type='submit' aaname='Suchen' />   TimeoutMS=100
  TRUE  → already logged in: BrowserScope → Activate → log "SIX ID login was successful"
  FALSE → Login:
            UiElementExists <html app='chrome.exe' title='*' />
              → if a browser is open, attach and close it
            OpenBrowser (Chrome, Url = in_SIX_System_Url)
              Activate → MaximizeWindow → RefreshBrowser
            Cnt = 0
            … credential entry, then retry loop …
            failure → Throw ApplicationException("SIX Login failed." / "SIX iD Login failed")
```

**Always probe for an existing session before logging in.** Re-logging in when already
authenticated is what breaks these flows.

A commented-out `KillProcess chrome` (`ContinueOnError=True`) sits in the init block. It is
disabled deliberately — killing Chrome takes down any other browser automation on the same
runner.

## Login page selectors

| Element | Selector |
|---|---|
| Email field | `<html app='chrome.exe' title='SIX Login' /><webctrl tag='INPUT' name='email' />` |
| Password field | `<webctrl tag='INPUT' id='isiwebpasswd' />` |
| Login button | `<webctrl tag='BUTTON' aaname=' Login ' />` — note the surrounding spaces |
| "Login anyway" | `<html … title='SIX Login' /><webctrl tag='BUTTON' aaname='*Login anyway*' name='submit' />` |
| "Back to login" | `<html … title='SIX Login' /><webctrl tag='BUTTON' aaname='*Back to login*' name='submit' />` |
| Logged-in user label | `String.Format("<webctrl aaname=' *{0}*' tag='LABEL' />", User)` |
| SIX iD HTML link | `<html … title='Home' /><webctrl aaname='SIX iD HTML*' tag='A' />` |
| Server error page | `<html app='chrome.exe' title='SIX - Server Error' />` |
| Back to home | `<html … title='SIX - Server Error' /><webctrl tag='A' aaname='Back to home' />` |

`aaname=' Login '` and `aaname=' Next '` carry **significant leading/trailing spaces**.
Preserve them exactly.

The portal has a dedicated **`SIX - Server Error`** page that the workflow checks for
explicitly (10 references) and recovers from via "Back to home". Any new SIX flow must
handle it.

## Working windows

| Window | Selector |
|---|---|
| Search page | `<html app='chrome.exe' title='SIX iD HTML' />` |
| Detail / VDB page | `<html app='chrome.exe' htmlwindowname='vdb' title='SIX iD HTML VDB' />` |

`htmlwindowname='vdb'` distinguishes the detail frame — the most-used selector in the folder
(12 references).

## Data extraction selectors

Table cells are addressed by **row name plus column index**, which survives layout changes
better than absolute coordinates:

```
<webctrl tag='TD' rowName='ISIN '    tableCol='2' />
<webctrl tag='TD' rowName='Domizil ' tableCol='2' />
<webctrl tag='TD' rowName='Emittent ' tableCol='2' />
<webctrl rowName='Anlagefonds Beschreibung ' tableCol='1' />
```

**The trailing space in every `rowName` is real** — it comes from the page markup. Dropping
it breaks the selector.

Section headers are addressed via their container:

```
<webctrl aaname='Fonds Zusammensetzung' parentid='vdb_page' parentname='Top' />
<webctrl aaname='Rückzahlung per Endverfall' parentid='vdb_page' parentclass='vdb_header' />
```

## Workflow inventory

| Workflow | In | Out |
|---|---|---|
| `SIX_ID_Login` | `in_SIX_System_Url`, `in_CustomerID`, `in_ObjectName`, `in_Email`, `in_ScreenshotFolder` | — |
| `SIX_iD_LogOut` | *(no arguments)* | — |
| `SIX_iD_Instrument_Search` | `in_Instrument_Nr_Mail`, `in_Instrument_NrTyp_Mail`, `in_Config`, `in_TransactionItem` | — |
| `SIX_iD_Instrument_Verify` | `in_Instrument_Nr_Mail`, `In_Instrument_Typ_Mail` *(capital I — sic)*, `in_Config`, `in_TransactionItem` | `out_Instrument_Typ_SIX` |
| `SIX_iD-Forderungspapier_Extract` | *(no arguments)* | `out_Branche_SIX`, `out_Domizil_SIX` |
| `SIX_iD-Anlagefonds-AnteilscheinTrustShare (3)_Extract` | *(no arguments)* | `out_ISIN_SIX`, `out_Emittent_SIX`, `out_AnlageBeschrei_SIX`, `out_AnlageFonds_Trust_Typ_SIX` |
| `SIX_ID-Anlagefonds_Beschreibung_Get` | *(no arguments)* | `out_Fonds_Beschreibung_SIX` |
| `SIX_iD-Fonds_Risikotitelart_Extract` | `in_Risikodomizil_Finnova`, `in_Instrument_Nr_Mail`, `in_KategorieDT`, `in_Config`, `in_TransactionItem` | `out_Risikotitelart_Finnova` |
| `SIX_iD-Strukturierte Instrumente (12)_Extract` | `in_Config`, `in_TransactionItem` | `out_HändlerSymbol_Underlying_SIX` (List), `out_Domizil_Underlying_SIX` (List) |
| `SIX_iD-Instrument_Strucki_Underlying` | `in_Wertpapier_ID`, `in_Config`, `in_TransactionItem` | `out_Domizil_Underlying_SIX`, `out_HändlerSymbol_Underlying_SIX` |
| `SIX_ID-Instrumentendetailinformationen_Close` | *(no arguments)* | — |

Two file names contain spaces and parentheses copied from UI labels
(`SIX_iD-Anlagefonds-AnteilscheinTrustShare (3)_Extract.xaml`,
`SIX_iD-Strukturierte Instrumente (12)_Extract.xaml`). Do not repeat that — see
`../naming-conventions.md`.

## Position in the transaction

SIX iD runs **first**, before Finnova:

```
SIX_ID_Login → SIX_iD_Instrument_Search → SIX_iD_Instrument_Verify → Instrument_Typ_SIX
  → (Finnova work)
  → SIX_ID-Instrumentendetailinformationen_Close
```

The instrument type returned by `SIX_iD_Instrument_Verify` drives the `Switch` in
`Process.xaml` that selects which `Logic-Instrument_*_Process` workflow runs.

## Error handling

`SIX_ID_Login` throws `ApplicationException` (system exception, retried) on login failure.
Business-level failures — instrument not found, unknown type — are **not** thrown; they
invoke `Mail_System\Mail-_Process_Exception.xaml` with a numbered exception:

| Nr | `Exception_<n>_Msg` |
|---|---|
| 1 | Instrument in SIX iD nicht gefunden |
| 3 | Instrumententyp in SIX iD unbekannt |
| 12 | Konnte Risikotitelart für Fonds nicht eindeutig ermitteln |
