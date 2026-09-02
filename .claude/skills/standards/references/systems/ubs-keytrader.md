# `UBS KeyTrader/` — UBS KeyTrader

**Java thick client** (`keytrader.exe`, `SunAwtFrame` — the same Swing technology as
Finnova, but a separate application with no custom library). Present in
`PJFVA-966_UC81_BPO_VD03_TK _Valoren`, used to look up a UBS fund category for an ISIN.

> The folder is named `UBS KeyTrader/` — with a space and no `_System` suffix. It deviates
> from the convention; new folders should be `<Application>_System/`. See
> `../naming-conventions.md`.

## Configuration

| Config key | Value (PRD) |
|---|---|
| `UBS_KeyTrader_Launch_Process` | `D:\Install\UBS KeyTrader\keytrader.exe` |
| `UBS_KeyTrader_PHI_Vault_Name` | `UBSKeyTrader@UC81` |

Credentials come from the CyberArk PHI vault. See `.claude/skills/security/`.

## Selectors

No library, so selectors are hand-written — but they follow the same Java shape the Finnova
library generates:

| Element | Selector |
|---|---|
| Main window (logged in) | `<wnd app='keytrader.exe' cls='SunAwtFrame' title='KeyTrader*Funds Primary*' />` |
| Login window | `<wnd app='keytrader.exe' cls='SunAwtFrame' title='KeyTrader Login*' />` |
| Welcome dialog | `<wnd app='keytrader.exe' cls='SunAwtDialog' title='Welcome to KeyTrader' />` |
| Result table | `<java name='table' role='table' />` |

`SunAwtFrame` for windows, `SunAwtDialog` for dialogs, `<java role='…'>` for controls —
identical to Finnova. If you need to extend this folder, the Finnova library's selector
model is the right mental model even though the library itself does not apply here:
`.claude/skills/finnova-library/references/selector-model.md`.

## Login — `UBS-KeyTrader-Login.xaml`

Arguments: `in_UBS_KeyTrader_PHI_Vault_Name`, `in_UBS_KeyTrader_Launch_Process`,
`in_Config`, `in_TransactionItem`.

Idempotent three-state flowchart — the same shape as SIX iD and CardOne:

```
UiElementExists  <wnd app='keytrader.exe' cls='SunAwtFrame' title='KeyTrader*Funds Primary*' />
                 TimeoutMS = 500
  TRUE  → already logged in → Log "Login was successful"
  FALSE → UiElementExists <wnd … title='KeyTrader Login*' />  TimeoutMS = 500
            TRUE  → Login:
                      WindowScope (<wnd … title='KeyTrader Login*' />)
                        → enter credentials from the PHI vault, submit
                        → dismiss <wnd … cls='SunAwtDialog' title='Welcome to KeyTrader' />
            FALSE → Launch UBS Key Trader:
                      StartProcess (FileName = in_UBS_KeyTrader_Launch_Process)
                      InterruptibleDoWhile  (Condition = Not Exists)   ' poll until the window appears
                      → then fall through to Login
```

Three states — *running and authenticated* / *running at the login screen* / *not running* —
each handled separately. Copy this shape for any desktop application that may already be
open; a workflow that assumes "not running" will fail on the second transaction.

`InterruptibleDoWhile` (rather than a fixed `Delay`) is how the project waits for the process
to start. Keep that.

## Workflow inventory

| Workflow | In | Out |
|---|---|---|
| `UBS-KeyTrader-Login` | `in_UBS_KeyTrader_PHI_Vault_Name`, `in_UBS_KeyTrader_Launch_Process`, `in_Config`, `in_TransactionItem` | — |
| `UBS-KeyTrader_Search_Info` | `in_ISIN` | `out_Category` |

Two workflows only — this is a narrow, read-only integration.

## Position in the transaction

Called from `Logic/Logic-Instrument_Fonds_Process.xaml` when a fund's category cannot be
determined from SIX iD. `out_Category` is passed into
`Finnova_System/Finnova-Fonds_Process.xaml` as `in_UBS_Fund_Category`.

Failure is reported as a business exception through the mail path, not thrown:

| Nr | `Exception_<n>_Msg` |
|---|---|
| 13 | `UBS Fund Category konnte im UBS Keytrader nicht ermittelt werden` |

## Gaps

- **No logout or close workflow.** Nothing shuts KeyTrader down — not
  `CloseAllApplications.xaml`, not `KillAllProcesses.xaml` (both are near-empty in UC81).
  The process is left running between jobs. If you need a clean shutdown you must add it.
- **No explicit error handling** in either workflow beyond the login flowchart. A failed
  search surfaces as a generic `System.Exception` and is classified as a system exception.
