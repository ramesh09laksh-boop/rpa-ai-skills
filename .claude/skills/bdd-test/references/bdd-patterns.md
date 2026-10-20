# BDD patterns for UiPath tests

## Contents
1. Scenario anatomy
2. Converting inputs (ACs, user stories, manual test scripts)
3. Scenario Outline and data
4. Tags
5. Anti-patterns
6. Language and file conventions

## 1. Scenario anatomy

```gherkin
@UC39 @AC-03 @regression
Feature: Commission calculation for manual stock orders
  As a back-office operator
  I want commissions calculated by the robot
  So that manual orders are booked with the correct fee

  Background:
    Given the order booking application is open on the start screen

  Scenario: Standard commission for a domestic equity order
    Given an order for 100 shares at CHF 50.00 on SIX
    When the robot processes the order
    Then the booked commission is CHF 40.00
    And the order status is "Booked"
```

| Keyword | Holds | UiPath block |
|---|---|---|
| `Given` | Preconditions: data, app state, logged-in user | **Given**: setup, test data, open app or mock |
| `When` | **One** business action (the behaviour under test) | **When**: invoke the workflow under test |
| `Then` / `And` | Observable outcomes | **Then**: Verify activities only (plus reading values to verify) |
| `Background` | Shared `Given` steps | Repeated in each test case's Given, or a shared setup workflow |

Rules:
- Write steps declaratively, describing the business intent. Write "Given a blocked client account", not "Given I click Search and type 123 and press Enter". The UI steps belong in the implementation.
- Use one `When` per scenario. If you have two, it's two scenarios, or the first one is really a `Given`.
- A `Then` must be checkable by the robot: a value, a status, a message, a file, a queue item, an element state. "The process works correctly" isn't checkable.

## 2. Converting inputs

**Acceptance criteria**: each criterion becomes one Scenario, tagged with the AC ID. Turn each condition clause into a `Given`, the trigger into the `When`, and each "shall" into a `Then`.

**User story without ACs**: don't invent ACs. Draft candidate scenarios, mark them `@draft`, and ask the user to confirm them before you implement.

**Manual test script** (Step / Action / Expected result):

| Manual column | Becomes |
|---|---|
| Preconditions | `Given` |
| Steps that set things up | `Given` (collapse them into intent) |
| The step being tested | `When` |
| Expected result | `Then` (one per distinct expectation) |
| Intermediate expected results | `Then`s of an earlier scenario, or a verify-on-state in the implementation (not extra scenarios) |

Keep the manual test case ID as a tag (`@TC-1234`) so it traces back to the original.

**Negative and edge paths**: for every happy-path scenario, ask whether the requirement defines what happens on invalid input, a missing record, or the application being unavailable.
If the requirement defines it, add a scenario. If it doesn't, list it as an open question instead of inventing behaviour.
Business exceptions (rules) and system exceptions (technical failures) are separate scenarios. They have different expected outcomes in REFramework.

## 3. Scenario Outline and data

```gherkin
  Scenario Outline: Commission by market
    Given an order for <qty> shares at <price> on <market>
    When the robot processes the order
    Then the booked commission is <commission>

    Examples:
      | qty | price  | market | commission |
      | 100 | 50.00  | SIX    | 40.00      |
      | 10  | 200.00 | XETRA  | 55.00      |
```

- An Outline becomes **one data-driven test case**. The Examples table becomes its data variation file, and each column becomes an argument.
- Expected values are columns too. Don't calculate the expected result inside the test with the same logic as the product.
- Keep the Examples small and meaningful: boundaries, one representative per equivalence class, plus known past defects.

## 4. Tags

| Tag | Meaning |
|---|---|
| `@UCnnn`, `@AC-n`, `@TC-n` | Traceability (required, at least one) |
| `@smoke`, `@regression` | Suite membership. Map to Test Manager test sets later via `uipath-test` |
| `@mocked` | Uses mock workflows; doesn't need the real app |
| `@requires-finnova`, `@requires-avaloq`, `@requires-web` | Needs a live environment |
| `@draft` | Not yet confirmed by the business; don't implement |
| `@manual` | Kept as a manual check on purpose; don't automate |

## 5. Anti-patterns

| Smell | Fix |
|---|---|
| UI-click steps in Gherkin | Rewrite as business intent |
| `Then` with no value ("Then it works") | Name the observable result, or ask |
| Several `When`s | Split the scenario |
| Scenarios that depend on each other's order | Make each one set up its own state in `Given` |
| Expected values calculated with product logic | Use literal expected values from the requirement |
| Huge Examples tables | Use boundaries and equivalence classes |
| Asserting on a log message instead of the outcome | Assert on the business result. Logs are supporting evidence only |

## 6. Language and file conventions

- Write in the language of the requirements. German requirements can use German Gherkin keywords (`# language: de`, then `Funktionalität` / `Szenario` / `Angenommen` / `Wenn` / `Dann`), if the team agrees. Don't mix languages in one file.
- Store feature files next to the tests, in the folder the project already uses. If there's none, use `Tests/Features/<Capability>.feature`.
- Studio doesn't execute `.feature` files. They are the specification, and the test cases implement them.
  Each test case's annotation (or its first Comment activity) quotes its Scenario name, so the two stay linked.
