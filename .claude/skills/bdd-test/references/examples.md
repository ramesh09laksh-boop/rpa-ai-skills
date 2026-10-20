# End-to-end examples

These are condensed. The pseudo-XAML shows structure and property intent, not literal markup.
Always produce real XAML from the project's own template (see `uipath-implementation.md` §3).

> **The workflow and file names here are illustrative placeholders, not estate files.**
> `CalculateCommission.xaml`, `TC_Commission_AboveMinimum.xaml`, `Portal/SearchClient.xaml`,
> client `TEST-0001` and reference `BK-TEST-1` are invented for these examples. No file of any
> of those names exists under `../Finnova/`, `../Avaloq/` or `../REFramework-*/`. Don't cite
> them as precedent, and don't go looking for them. The real registered test cases in the
> estate are `../REFramework-*/Tests/{Main,Process,GetTransactionData,InitAllSettings,InitAllApplications}TestCase.xaml`
> plus `WorkflowTestCaseTemplate.xaml`. The `@UC39` / `@UC252` tags below are shaped like the
> estate's UC numbering purely so the traceability pattern is visible.

## Contents
1. Workflow-level test from acceptance criteria (no UI)
2. Data-driven test from a Scenario Outline
3. Expected business exception
4. UI test on a web portal with synchronisation
5. Mocked external dependency (application unavailable)
6. Converting a manual test script

---

## 1. Workflow-level test from acceptance criteria

**Input**: "AC-03: For SIX equity orders, commission = 0.8% of order value, minimum CHF 30."

```gherkin
@UC39 @AC-03 @regression
Scenario: Commission above minimum
  Given an order for 100 shares at CHF 50.00 on SIX
  When the commission is calculated
  Then the commission is CHF 40.00

@UC39 @AC-03 @regression
Scenario: Minimum commission applies
  Given an order for 10 shares at CHF 20.00 on SIX
  When the commission is calculated
  Then the commission is CHF 30.00
```

Map:

| Scenario | Test case | When invokes | Then |
|---|---|---|---|
| Commission above minimum | `TC_Commission_AboveMinimum.xaml` | `Process/CalculateCommission.xaml` | Verify Expression With Operator `out_Commission = 40.00D` |
| Minimum commission applies | `TC_Commission_Minimum.xaml` | same | `out_Commission = 30.00D` |

```
... Given
  Assign  qty = 100 ; price = 50.00D ; market = "SIX"
... When
  Invoke Workflow File  Process/CalculateCommission.xaml
    in_Quantity=qty, in_Price=price, in_Market=market, out_Commission=actualCommission
... Then
  Verify Expression With Operator
    FirstExpression:  actualCommission
    Operator:         Equality
    SecondExpression: 40.00D
    OutputMessageFormat: "AC-03 commission: expected {RightExpression}, actual {LeftExpression}"
```

Two things to keep straight (both verified on `UiPath.Testing.Activities [23.10.1]`): the
properties are `FirstExpression` / `SecondExpression`, while the message tokens are
`{LeftExpression}` / `{RightExpression}`. First maps to Left, Second to Right.

Note: the expected value 40.00 is a literal taken from the AC (100 × 50 × 0.8%). It isn't calculated by the test.

## 2. Data-driven test from a Scenario Outline

```gherkin
@UC39 @AC-03
Scenario Outline: Commission by order value
  Given an order for <qty> shares at <price> on SIX
  When the commission is calculated
  Then the commission is <expected>

  Examples:
    | qty | price | expected |
    | 100 | 50.00 | 40.00    |
    | 10  | 20.00 | 30.00    |
    | 75  | 50.00 | 30.00    |   # boundary: 0.8% of 3750 = 30.00 exactly
```

- One test case, `TC_Commission_ByOrderValue.xaml`, with In arguments `qty`, `price` and `expected`.
- A data variation file holds the Examples rows, registered the same way the project's other data-driven tests are.
  No data-driven test case exists in the estate yet, so create the first one through Studio and
  read the `fileInfoCollection` field name back rather than hand-writing it
  (`uipath-implementation.md` §9).
- `... Then` compares `actualCommission` against `expected`. The message includes the row values, so you can tell which row failed.

## 3. Expected business exception

```gherkin
@UC39 @AC-07
Scenario: Order on unsupported market is rejected
  Given an order on market "NYSE"
  When the commission is calculated
  Then a business rule exception is raised
  And the message names the unsupported market
```

```
... When
  Try
    Invoke Workflow File  CalculateCommission.xaml  (in_Market="NYSE")
  Catch BusinessRuleException ex
    Assign  caught = ex
... Then
  Verify Expression
    Expression: caught IsNot Nothing
    OutputMessageFormat: "Expected BusinessRuleException, none thrown (result {Result})"
  Verify Expression With Operator
    FirstExpression: caught.Message   Operator: Contains   SecondExpression: "NYSE"
```

Only `BusinessRuleException` is caught. A System.Exception must still fail the test.

## 4. UI test on a web portal

```gherkin
@requires-web @smoke
Scenario: Search shows the client status
  Given the operator is logged in to the portal
  When the operator searches for client "TEST-0001"
  Then the result shows status "Active"
```

```
... Given
  Get Credential (asset from Config via security skill)
  Use Browser  (portal URL from Config)
    Login workflow (existing, invoked, not copied)
    Check App State  target: dashboard header  → Appears, timeout from Config
... When
  Invoke Workflow File  Portal/SearchClient.xaml  in_ClientId="TEST-0001"
... Then
  Check App State  target: results table  → Appears
  Get Text  target: status cell (Object Repository descriptor)  → actualStatus
  Verify Expression With Operator
    FirstExpression: actualStatus.Trim   Operator: Equality   SecondExpression: "Active"
    TakeScreenshotInCaseOfFailingAssertion: True
Finally (teardown)
  Close the browser tab opened by the test
```

Synthetic client `TEST-0001` comes from the test data queue or file, not from a real case.
Selectors are validated with the `web` skill, which captures through the `uip rpa uia` CLI
straight into the Object Repository.

## 5. Mocked external dependency

**Context**: the Performer sends a confirmation mail and calls Finnova. The test environment has no Finnova.

```gherkin
@mocked @UC252
Scenario: Confirmation mail sent after successful booking
  Given Finnova confirms the booking with reference "BK-TEST-1"
  When the transaction is processed
  Then exactly one confirmation mail is prepared
  And the mail body contains "BK-TEST-1"
```

- Mock `Process.xaml`. In the mock, surround the Finnova library call so it returns the reference `"BK-TEST-1"`, matching the contract in `finnova-library`.
- Surround the send-mail activity so it captures the message into a variable or test output instead of sending.
- In `... Then`, verify the count of captured mails = 1 and that the body contains the reference
  (`Operator: Contains`).
- Add a sibling scenario where the Finnova mock throws the library's documented failure, and expect the system-exception path.
- Report the scenario as `@mocked`. It proves the process logic, not the Finnova integration.

## 6. Converting a manual test script

| # | Action | Expected |
|---|---|---|
| 1 | Open app, log in | Start screen |
| 2 | Enter client 123, press Search | Client opens |
| 3 | Open tab "Orders", enter order, Save | Message "Saved", status Pending |

```gherkin
@TC-1234
Scenario: Saving a new order sets it to pending
  Given a client is open in the application
  When the operator saves a new order for the client
  Then the confirmation "Saved" is shown
  And the order status is "Pending"
```

Steps 1 and 2 collapse into the `Given`, step 3's action becomes the `When`, and its two expectations become two `Then`s.
Client 123 is replaced by synthetic test data. The intermediate expectations ("start screen", "client opens") become synchronisation checks in `Given`, not separate scenarios.
