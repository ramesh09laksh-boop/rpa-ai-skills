# `CardOne_System/` — CardOne credit-card administration

**Browser-based (Chrome).** CardOne is reached **from inside Avaloq** via a right-click
context menu, then driven as an ordinary web application. Used by
`../Avaloq/TKB-UC11.Kreditverletzung` to block credit cards for customers in credit-limit
violation.

No custom library — raw UiPath UI Automation with hand-written selectors. See
`.claude/skills/web/`.

## Launching CardOne

CardOne is **not** opened by URL. The Avaloq library opens it from the customer position:

```
Swisscom_UiPath_UIAutomation_Avaloq::Select Right Click Menu
    FieldCtrlname = "pos_id"
    Menu          = "Aufruf CardOne: Konto-Detail anzeigen"
```

This means **Avaloq must be logged in and showing the right position before CardOne can be
opened.** CardOne inherits the customer context from Avaloq; there is no way to navigate to
a specific account from within CardOne itself.

## Login — `CardOne_Login.xaml`

Argument: `in_Avaloq_System_Credentials` — CardOne reuses the **Avaloq** Orchestrator
credential asset (`AVQ_Credential_1004`). One credential, two systems.

Flowchart, with a retry counter:

```
FlowDecision "Retry?"  Cnt > 4
  TRUE  → Throw ApplicationException("CarOne Login: Failed.")     ' sic: "CarOne"
  FALSE → Launch CardOne
            CardOne_Close.xaml                    ' close any stale window first
            Select Right Click Menu (Avaloq)      ' opens CardOne
          CardOne / User Exists
            UiElementExists <html app='chrome.exe' title='CardOne*' />
                            <webctrl tag='INPUT' name='j_username' type='text' />
            TRUE  → BrowserScope (Chrome, <html app='chrome.exe' title='CardOne*' />)
                      → enter credentials, submit
            FALSE → UiElementExists "Service Unavailable"
                      → Throw BusinessRuleException("CardOne: Service Unavailable")
```

Three things to carry into any new CardOne work:

- **Close before launching.** `CardOne_Close.xaml` runs first every time.
- **`Service Unavailable` is a business exception, not a system one.** The workflow throws
  `BusinessRuleException("CardOne: Service Unavailable")` so the item is not retried against
  a down system.
- **Bounded retry (`Cnt > 4`)** then `ApplicationException(SysError)`.

## Selectors

| Element | Selector |
|---|---|
| Login window | `<html app='chrome.exe' title='CardOne*' />` |
| Main window | `<html app='chrome.exe' title='*CardOne Swisscom*' />` |
| Account detail | `<html app='chrome.exe' title='Bankkonto Details*' />` |
| Service unavailable | `<wnd app='chrome.exe' title='*Service Unavailable*' />` — a `wnd`, not `html` |
| Username | `<webctrl tag='INPUT' name='j_username' type='text' />` |
| Password | `<webctrl tag='INPUT' type='password' id='j_password' />` |
| Page messages | `<webctrl parentid='pageMessages' tag='SPAN' />` |
| Block-card button | `<webctrl id='header.menu.actions.creditcard.block.bank' tag='BUTTON' />` |
| Card number label | `<webctrl id='*creditCardNumber' tag='LABEL' />` |
| Logout | `<webctrl id='header.menu.user.logout' tag='LI' />` |
| Confirm buttons | `<webctrl tag='INPUT' type='submit' aaname='Auslösen' / 'Zurück' / 'OK' />` |
| Card list item | `String.Format("<webctrl parentid='linkContainer' tag='I' idx='{0}' />", IdxValue)` |

CardOne uses **stable, semantic `id` attributes** (`header.menu.actions.creditcard.block.bank`,
`pageMessages`, `linkContainer`). Prefer them over text or position — this is the most
selector-friendly of the three web systems in the estate.

Note the "Service Unavailable" page is matched as `<wnd …>`, not `<html …>` — the error page
does not load a document Chrome exposes as HTML.

## Reading page feedback — `CardOne_Page_Message_Check.xaml`

Outputs: `Exists` (Boolean), `PageMessage` (String).

CardOne reports success and failure in a `pageMessages` container rather than by changing
page. **Call this after every action** and branch on the message — an action that silently
did nothing otherwise looks like success.

## Workflow inventory

| Workflow | In | Out |
|---|---|---|
| `CardOne_Login` | `in_Avaloq_System_Credentials` | — |
| `CardOne_Logout` | *(no arguments)* | — |
| `CardOne_Close` | *(no arguments)* | — |
| `CardOne_Page_Message_Check` | *(no arguments)* | `Exists`, `PageMessage` |
| `CardOne_Goldene_Kreditkarte_Sperre` | `in_KK_entsperren_Queue`, `in_KV_Auftragsnummer`, `in_Entsperren_QueueItem_Postpone_InHours`, `in_KV_Konto` | `out_KK_Anzahl_aktiv`, `out_KK_Anzahl_gesperrt`, `out_KK_Anzahl_Fehler`, `out_CO_KKNrList` |

## Position in the transaction

Invoked from `Avaloq_System/Avaloq_Kreditkarte_sperren.xaml`, which is reached when
`KV_Verletzungsdauer > 30`. The card counts it returns (`out_KK_Anzahl_aktiv`,
`out_KK_Anzahl_gesperrt`, `out_KK_Anzahl_Fehler`) then select the ticket outcome code
K100 / K101 / K102 in `Process.xaml`.

Blocked cards are queued for later unblocking via
`Logic/KK_entsperren_Queue_Item_Add.xaml` into `UC15_KK_entsperren_Queue`, postponed by
`Entsperren_QueueItem_Postpone_InHours`.

## Shutdown

`CardOne_Logout.xaml` is invoked from **both** `Framework/CloseAllApplications.xaml` and
`Framework/KillAllProcesses.xaml`. Unlike Avaloq and Finnova, CardOne does get an explicit
logout — a browser session left open holds a server-side session.
