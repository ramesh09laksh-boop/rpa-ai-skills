# Web flows — reference and verification status

## Verification status: NOT live-verified

**Every flow below was reconstructed from the sample projects' `.xaml` sources, not walked
against a live system.** Read them as an accurate record of *what the shipped robot does*,
not as confirmation that the applications still behave that way.

Why no live verification was performed:

| Reason | Detail |
|---|---|
| No credentials | SIX iD, CardOne and Avaloq are authenticated production banking systems. No test account was provided, and production logins were not attempted. |
| Authorisation | Driving a bank's production portal needs explicit authorisation for a named environment and account. That was not in scope of this task. |
| Tooling timing | Playwright MCP was installed and verified connected (`claude mcp add playwright npx @playwright/mcp@latest`, Node 22.21.1), but MCP tools load at session start, so it was not drivable in the session that produced these notes. |

**Treat every selector here as unverified until someone runs the procedure below.** Then
update the status column and date.

| Flow | Application | Status | Last checked |
|---|---|---|---|
| SIX iD login | SIX iD | ⚠ from code only | — |
| SIX iD instrument search & extract | SIX iD | ⚠ from code only | — |
| CardOne login | CardOne | ⚠ from code only | — |
| CardOne block credit card | CardOne | ⚠ from code only | — |
| Avaloq report table extract | Avaloq (embedded) | ⚠ from code only | — |

---

## Verification procedure

Run this per flow, in a **test** environment with an account you are authorised to use.

1. Start a session with Playwright MCP available (installed as above).
2. Navigate to the flow's entry URL.
3. Take an **accessibility snapshot** at each step — not a screenshot. Snapshots give roles,
   names and ids; screenshots give none of that.
4. For each element the flow touches, confirm the attribute the UiPath selector relies on
   still exists and is unique. Check raw DOM attributes for anything matched on `aaname` —
   snapshots normalise whitespace, and several selectors here depend on exact spaces.
5. Walk the flow to completion, recording every interstitial (consent banner, "Login
   anyway", error page, session-expiry prompt).
6. Update the table above and note any drift in the flow's section below.

Never paste a credential into a prompt. Enter it in the browser directly, or use an
environment variable the tool reads.

---

## SIX iD — login

**Entry:** `https://portal.six-group.com` (config `SIX_ID_System_URL`)
**Source:** `PJFVA-966_UC81_BPO_VD03_TK _Valoren/SIX_ID_System/SIX_ID_Login.xaml`

```
1  Probe: <html app='chrome.exe' title='SIX iD HTML' />
          <webctrl tag='INPUT' type='submit' aaname='Suchen' />     TimeoutMS=100
     found → already logged in: BrowserScope → Activate → done
2  Not found:
     a  <html app='chrome.exe' title='*' /> exists → attach and close it
        (KillProcess chrome exists but is COMMENTED OUT — leave it that way)
     b  OpenBrowser (Chrome, in_SIX_System_Url) → Activate → MaximizeWindow → RefreshBrowser
     c  Cnt = 0
     d  <html … title='SIX Login' /><webctrl tag='INPUT' name='email' />   ← email
        <webctrl tag='INPUT' id='isiwebpasswd' />                          ← password
        <webctrl tag='BUTTON' aaname=' Login ' />                          ← submit  (spaces!)
     e  Interstitials:
        <webctrl tag='BUTTON' aaname='*Login anyway*' name='submit' />
        <webctrl tag='BUTTON' aaname='*Back to login*' name='submit' />
        <webctrl tag='BUTTON' aaname=' Next ' />                           (spaces!)
     f  Confirm: String.Format("<webctrl aaname=' *{0}*' tag='LABEL' />", User)
     g  <html … title='Home' /><webctrl aaname='SIX iD HTML*' tag='A' />   ← enter SIX iD
3  Error page at any point:
     <html app='chrome.exe' title='SIX - Server Error' />
     → <webctrl tag='A' aaname='Back to home' /> → retry
4  Cnt exceeded → Throw ApplicationException("SIX Login failed." / "SIX iD Login failed")
```

**Check on verification:** the ` Login ` / ` Next ` spaces; whether `isiwebpasswd` is still
the password id (it looks framework-generated and is the most likely to drift); whether the
`SIX - Server Error` page still exists.

---

## SIX iD — instrument search and extract

**Entry:** logged-in SIX iD, `<html app='chrome.exe' title='SIX iD HTML' />`
**Source:** `SIX_iD_Instrument_Search.xaml`, `SIX_iD_Instrument_Verify.xaml`, the four
`SIX_iD-*_Extract.xaml` workflows

```
1  Search page:  <webctrl id='search_extended' aaname='Show extended search ' />
                 <webctrl id='SearchCriterion' tag='SELECT' />
                 <webctrl tag='INPUT' type='submit' aaname='Suchen' />
2  Detail frame: <html app='chrome.exe' htmlwindowname='vdb' title='SIX iD HTML VDB' />
3  Field reads (note the trailing space in every rowName):
     <webctrl tag='TD' rowName='ISIN '     tableCol='2' />
     <webctrl tag='TD' rowName='Domizil '  tableCol='2' />
     <webctrl tag='TD' rowName='Emittent ' tableCol='2' />
     <webctrl rowName='Anlagefonds Beschreibung ' tableCol='1' />
4  Sections:
     <webctrl aaname='Fonds Zusammensetzung' parentid='vdb_page' parentname='Top' />
     <webctrl aaname='Rückzahlung per Endverfall' parentid='vdb_page' parentclass='vdb_header' />
5  Generic table read:
     <webctrl tag='TABLE' /><webctrl tableCol='3' tag='TD' tableRow='2' />
```

**Check on verification:** every `rowName` trailing space; that `htmlwindowname='vdb'` still
names the detail frame; that step 5's positional read still lands on the intended cell — it
is the least robust selector in the estate.

---

## CardOne — login

**Entry:** launched from Avaloq, not by URL:
`Select Right Click Menu (FieldCtrlname="pos_id", Menu="Aufruf CardOne: Konto-Detail anzeigen")`
**Source:** `TKB-UC11.Kreditverletzung/CardOne_System/CardOne_Login.xaml`

```
1  FlowDecision Cnt > 4 → Throw ApplicationException("CarOne Login: Failed.")
2  CardOne_Close.xaml                      ' always close a stale window first
3  Select Right Click Menu (Avaloq)        ' opens CardOne in Chrome
4  Probe: <html app='chrome.exe' title='CardOne*' />
          <webctrl tag='INPUT' name='j_username' type='text' />
     found → BrowserScope (Chrome, <html app='chrome.exe' title='CardOne*' />)
                <webctrl tag='INPUT' name='j_username' type='text' />   ← user
                <webctrl tag='INPUT' type='password' id='j_password' /> ← password
                <webctrl tag='INPUT' type='submit' aaname='OK' />       ← submit
     not found → <wnd app='chrome.exe' title='*Service Unavailable*' />   (wnd, not html)
                 → Throw BusinessRuleException("CardOne: Service Unavailable")
5  Landed: <html app='chrome.exe' title='*CardOne Swisscom*' />
```

**Requires Avaloq logged in and positioned on the customer.** CardOne has no way to navigate
to an account on its own.

**Check on verification:** that `j_username` / `j_password` (Java EE form names) are
unchanged; that the Service Unavailable page is still matched as `wnd` rather than `html`.

---

## CardOne — block a credit card

**Source:** `CardOne_Goldene_Kreditkarte_Sperre.xaml`, `CardOne_Page_Message_Check.xaml`

```
1  <html app='chrome.exe' title='Bankkonto Details*' />
2  Card list:  String.Format("<webctrl parentid='linkContainer' tag='I' idx='{0}' />", IdxValue)
3  Card number: <webctrl id='*creditCardNumber' tag='LABEL' />
4  Block:       <webctrl id='header.menu.actions.creditcard.block.bank' tag='BUTTON' />
5  Confirm:     <webctrl tag='INPUT' type='submit' aaname='Auslösen' />
   Cancel:      <webctrl tag='INPUT' type='submit' aaname='Zurück' />
6  ALWAYS: CardOne_Page_Message_Check.xaml
             <webctrl parentid='pageMessages' tag='SPAN' />  → Exists, PageMessage
7  Logout:      <webctrl id='header.menu.user.logout' tag='LI' />
```

Step 6 is not optional — CardOne reports success and failure in `pageMessages` without
navigating, so a no-op looks identical to success.

Outcome counts (`out_KK_Anzahl_aktiv`, `_gesperrt`, `_Fehler`) drive the ticket code
K100/K101/K102 in `Process.xaml`.

**Check on verification:** the semantic ids — they are the most stable selectors in the
estate and should be preferred anywhere CardOne is extended.

---

## Avaloq — report table extract (embedded browser)

**Not a real browser.** No `chrome.exe`; use `WindowScope`, not `BrowserScope`.
**Source:** `TKB-UC11.Kreditverletzung/Web_Nav_System/_Web_Nav_Table_Extract.xaml`

```
WinSelector = <html app='smartclient.exe' title='Smart Client Report' />
Selector    = <webctrl parentid='grid1' tag='TABLE' parentclass='objbox' />

WindowScope (WinSelector)
  Activate                                  ' required — does not render reliably unfocused
  ExtractData  ContinueOnError    = True
               MaxNumberOfResults = 1000
               SimulateClick      = True
               TimeoutMS          = 500
               ExtractMetadata    = <extract-table get_columns_name='1'
                                     get_empty_columns='1' columns_name_source='Longest' />
  RowCount = ExtractDataTable.Rows.Count    ' MUST be checked — ContinueOnError hides failure
```

Playwright MCP **cannot** verify this flow — the page is hosted inside `smartclient.exe` and
is not reachable by an external browser. Verify it with UiExplorer against a running Smart
Client instead.

**Known limits:** `MaxNumberOfResults=1000` silently truncates larger reports;
`ContinueOnError=True` turns a failed extract into an empty table. See
`.claude/skills/standards/references/systems/web-nav-system.md`.

---

## When you verify a flow

Update the status table at the top, then note below the flow:

```
### Verified <YYYY-MM-DD> — <environment> — <who>
- Selectors confirmed: …
- Drift found: …
- New interstitials: …
```
