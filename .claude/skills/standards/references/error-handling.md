# Error handling conventions

Patterns present in all three reference projects. Nothing here is invented — where a
project deviates, that is noted.

## Exception type decides the outcome

All three projects are REFramework. The type you throw determines what happens:

| Throw | Meaning | REFramework result |
|---|---|---|
| `BusinessRuleException` | The application refused, or the data is not automatable | Transaction failed **Business** — no retry, next item |
| `ApplicationException` | Technical / system failure | Transaction failed **System** — retried per `MaxRetryNumber` |

Counts across the estate: ~35 `BusinessRuleException` throws vs ~10 `ApplicationException`.
These processes are dominated by "the application said no", which is a business outcome.

### Always carry the application's own message

```vb
Throw New BusinessRuleException(String.Format("Can't process: {0}", Message))
Throw New BusinessRuleException(String.Format("Please check the order in status:{0}", Status))
Throw New BusinessRuleException(String.Format(
    "The order cannot be processed due to the Depotstelle:{0}", Depotstelle))
Throw New BusinessRuleException("Position den Wert Abza beinhaltet")
```

A reviewer needs the application's text, not "step failed".

### `ApplicationException` for genuinely technical failures

```vb
Throw New ApplicationException(String.Format(
    "Failed to fill Risikodomizil: {0} in Finnova for the instrument: {1}",
    in_Risikodomizil_Finnova, in_Instrument_Nr_Mail))
Throw New ApplicationException("SIX Login failed.")
Throw New ApplicationException("CarOne Login: Failed.")
```

Login failures are system exceptions — the machine may recover. Data problems are not.

### The alternative: mail instead of throw

UC81 does **not** throw business exceptions from `Process.xaml`. It invokes
`Mail_System\Mail-_Process_Exception.xaml` with a numbered `in_ExceptionNr` that maps to
`Exception_<n>_Msg` in config, leaving the queue item successful while mailing a human.

Both conventions are legitimate. **Pick one per project and keep to it** — mixing them makes
queue statistics meaningless.

## The retry idiom

This exact shape appears in `Logic-Get_Credential.xaml`, `Avaloq_Login.xaml`,
`Mail-Archiv_Move.xaml`, `Mail_Send.xaml` and `AI-Commission_Get_By_Text.xaml`. Reuse it
rather than inventing a variant:

```
RetryScope  NumberOfRetries=3  RetryInterval=TimeSpan.FromSeconds(15)
  Body:
    Assign SysError = Nothing
    TryCatch
      Try:    <the fragile activity>
      Catch (System.Exception):
        SysError  = exception.Message
        exception = Nothing          ' swallow so RetryScope re-evaluates the condition
  Condition:
    CheckTrue (Expression = "SysError is Nothing", ErrorMessage = SysError)
```

Setting `exception = Nothing` inside the catch is deliberate: `RetryScope` then decides via
`CheckTrue` instead of propagating immediately, and `SysError` carries the last message into
the final failure.

Observed tuning:

| Operation | Retries | Interval |
|---|---|---|
| Get credential / asset | 3 | 15 s |
| Exchange mail read | 3 | 30 s |
| AI endpoint call | 3 | 15 s |
| Finnova `Login` (library-internal `RetryLogin`) | 2 | 45 s |
| Avaloq `Login` (library-internal `RetryNumber`) | 3 | 60 s |
| **Avaloq login, whole workflow** | **18** | **10 min** |

The Avaloq outer retry (~3 hours) reflects long batch windows during which the system is
unavailable. Do not shorten it without checking the operating schedule.

## Bounded retry with a counter

Where `RetryScope` does not fit — flowchart logins — the projects use an explicit counter:

```
FlowDecision "Retry?"  Cnt > 4
  TRUE → Throw ApplicationException("CarOne Login: Failed.")
  FALSE → … attempt … Cnt = Cnt + 1 → loop back
```

Used by `CardOne_Login.xaml` and `SIX_ID_Login.xaml`. Always terminate the loop with a throw.

## Catch granularity

`Catch System.Exception` throughout — 14 catches in UC39, 47 in UC81, 34 in TKB-UC11. There
is no custom exception hierarchy beyond `BusinessRuleException` / `ApplicationException`,
and only one typed `Catch BusinessRuleException` in the estate.

To distinguish, branch on the caught exception rather than adding typed catches:

```vb
' inside Catch(exception)
If TypeOf exception Is BusinessRuleException Then
    Throw New BusinessRuleException(exception.Message)
Else
    Throw New ApplicationException(exception.Message)
End If
```

`Framework/Process.xaml` (TKB-UC11) and `Logic-KD_BackOffice_Msg_Adjust.xaml` do exactly this.

## Probe before acting

Libraries raise a generic `System.Exception` for a missing element, which REFramework
classifies as a **system** exception and retries. If "element missing" is a business
outcome, test for it first:

| System | Probe |
|---|---|
| Finnova | `Text Exists`, `Button Exists`, `Combo Box Exists`, `Menu Item Exists`, `Window Exists`, `Utility/Element Exists` |
| Avaloq | `Element Exists`, `Window Exists` |
| Browser / Java clients | `UiElementExists` with a short `TimeoutMS` (100–500) |

The idempotent-login pattern is this rule applied to sessions — see
`systems/six-id-system.md`, `systems/cardone-system.md`, `systems/ubs-keytrader.md`.

## Screenshots

`Framework/TakeScreenshot.xaml` writes to `in_Config("ExScreenshotsFolderPath")` — relative
`Exceptions_Screenshots` in the Finnova projects, a network share in TKB-UC11.

Screenshots of a logged-in banking session contain customer data. See
`.claude/skills/security/references/prohibited-practices.md`.

## Framework tuning

| Constant | UC39 | UC81 | TKB-UC11 |
|---|---|---|---|
| `MaxRetryNumber` | 0 | 0 | 0 |
| `MaxConsecutiveSystemExceptions` | *not set* | *not set* | 0 |
| `RetryNumberGetTransactionItem` | *not set* | *not set* | 2 |
| `RetryNumberSetTransactionStatus` | *not set* | *not set* | 2 |
| `ShouldMarkJobAsFaulted` | *not set* | *not set* | False |

`MaxRetryNumber = 0` is correct when working from Orchestrator queues — the queue's own
retry count governs. Do not raise it to add retries; configure the queue instead.

## Known gaps

- **No timeout-specific handling.** Nothing catches `SelectorNotFoundException` or a timeout
  distinctly; a missing selector becomes a generic system exception.
- **No circuit breaker** in the two Finnova projects — `MaxConsecutiveSystemExceptions` is
  unset, so a systematically broken application produces a full queue of system exceptions.
- **`ContinueOnError=True` on `ExtractData`** (`Web_Nav_System/`) yields an empty DataTable
  instead of an exception. Always check `RowCount` after an extract.
- **`Camunda-Process_Logic.xaml` has no `TryCatch` and no `RetryScope`** — the one remote
  call in the estate that is not wrapped. See `systems/camunda-system.md`.
- **`MessageBox` activities** in `Camunda-Process_Logic.xaml` and
  `File-PDF_To_Text_File_Conversion.xaml` block an unattended robot indefinitely. Remove
  them; never add one.
