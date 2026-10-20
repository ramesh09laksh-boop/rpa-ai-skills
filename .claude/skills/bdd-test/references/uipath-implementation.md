# UiPath implementation practices for BDD test cases

## Contents
1. Inspecting the project
2. Scenario → implementation map
3. Test case structure
4. UI automation: selectors and synchronisation
5. Assertions
6. Test data, mocks, setup and teardown
7. Exceptions
8. Validation and execution
9. Unverified against estate

> Activity and property names below come from `UiPath.Testing.Activities` and the modern
> `UiPath.UIAutomation.Activities`. Confirm each one against the package versions in
> `project.json` before using it. Older pinned versions may lack newer properties.
>
> **Estate reference pins.** Every `../REFramework-*/` reference project and every
> `templates/` project pins `UiPath.Testing.Activities [23.10.1]` on Studio 23.10.8.0,
> `targetFramework: Windows`. `UiPath.UIAutomation.Activities` is `[23.10.13]`
> (Dispatcher-Base, Performer-Finnova) or `[24.10.10]` (Performer-Avaloq). Names in §5 and §6
> were verified against **23.10.1** — see §9 for what that version does *not* have.
>
> The three sample UC processes (`../Finnova/UC39…`, `../Finnova/PJFVA-966_UC81…`,
> `../Avaloq/TKB-UC11…`) are **`targetFramework: Legacy`, carry no
> `UiPath.Testing.Activities` dependency at all, and have an empty `fileInfoCollection`**.
> Their `Tests/` folders hold `_`-prefixed scratchpad workflows driven by `RunAllTests.xaml`
> + `Tests.xlsx` — that is the estate's *older* test idiom, not a Studio test case. Don't
> copy a Verify activity into one of those projects without first adding the package and
> agreeing the project is moving to real test cases.

## 1. Inspecting the project

Read these and record what you find before you edit anything:

| Look at | Why |
|---|---|
| `project.json` → `designOptions.outputType` and project type | A process with test cases or a Test Automation project changes where tests live and how they're published |
| `project.json` → `targetFramework` (Windows / Windows-Legacy / Portable) | Determines which activities and packages exist. A `Legacy` project has no modern activities |
| `project.json` → `dependencies` | Is `UiPath.Testing.Activities` there? Which UIAutomation version? |
| `project.json` → `designOptions.fileInfoCollection` | The existing test case entries. Mirror their shape and never invent fields |
| Existing test cases (`*.xaml` or coded `.cs` with test case attributes) | Folder, naming, template structure, how they invoke workflows |
| `.objects/` | The Object Repository is in use. Reuse its descriptors instead of adding inline selectors |
| Test data folders, mock folders (`Mocks/`) | Existing conventions for data and mocking |
| `Config.xlsx` / `Config_<ENV>.xlsx`, `AGENTS.md`, `.local/` excluded files | Settings and estate rules |
| Workflows under test: their arguments | What the `When` must pass and what the `Then` can read |

### `fileInfoCollection` entry shape

Verified against `../REFramework-Performer-Finnova/project.json` (six entries, all identical in
shape). A registered test case is exactly these five fields — there is no sixth:

```json
{
  "editingStatus": "InProgress",
  "testCaseId": "d375c1ea-e905-4acc-9bff-78d2fb57f4e2",
  "testCaseType": "TestCase",
  "executionTemplateType": "Local",
  "fileName": "Tests\\GetTransactionDataTestCase.xaml"
}
```

- `editingStatus` is the literal `InProgress` in the estate's six entries. `Publishable` is the
  other value; switching one is a project-setting change, so propose it (SKILL.md rule 4).
- `executionTemplateType` is `Local` throughout. Carry it forward — a new entry that omits it
  does not mirror the existing ones.
- `fileName` uses a **backslash** separator, escaped in JSON (`Tests\\…`).
- `testCaseId` is a fresh lowercase GUID per test case.

If the project has **coded** test cases, write coded ones too, in the same style. Don't mix
styles within one test suite unless the user asks. (No coded test case exists in the estate —
see §9.)

## 2. Scenario → implementation map

Produce this table before you write XAML:

| Scenario | Test case file | Data variation | When invokes | Then asserts with | Mocks | Needs live app |
|---|---|---|---|---|---|---|
| Standard commission | `Tests/Commission/TC_StandardCommission.xaml` | — | `Process/CalculateCommission.xaml` | Verify Expression With Operator ×2 | none | no |

Prefer testing **workflows through their arguments** over driving the UI end to end. Test the UI where the UI is itself the behaviour.

## 3. Test case structure

- Create the test case from the project's **BDD test case template**: Given / When / Then.
  In the estate that template is `Tests/WorkflowTestCaseTemplate.xaml`, present in all three
  `../REFramework-*/` reference projects. Its root Sequence is `Test Template`, and its three
  child Sequences are named **`... Given`**, **`... When`** and **`... Then`** — with the
  leading `... ` — so Studio's Test Explorer shows them in order. Keep those names.
  Its shipped shape is:
  - a `Config` variable, `Dictionary(String, Object)`;
  - a `Log Message` at the top;
  - `... Given` → Invoke Workflow File on `Framework\InitAllSettings.xaml`, returning `Config`;
  - `... When` → a Comment placeholder for the workflow to invoke;
  - `... Then` → a `Verify Control Attribute` inside a **Comment Out** block, to enable and adapt.

  Note `templates/` itself ships **no** test case XAML and an empty `fileInfoCollection` — only
  `Tests/Tests.xlsx`. A project scaffolded from `templates/` therefore has no template to copy;
  take it from a reference project, or from the first test case the project grows.
- If the project already has a test case, copy its exact XAML skeleton: namespaces, root
  activity, block names and annotations. The template's namespace prefix for the testing
  package is `xmlns:uta="clr-namespace:UiPath.Testing.Activities;assembly=UiPath.Testing.Activities"`.
- If neither is available, build a root Sequence with three child Sequences named `... Given`,
  `... When`, `... Then`. State in the report that the skeleton was hand-built and should be
  opened once in Studio to confirm it.
- Register the new test case in `fileInfoCollection` with a new GUID as `testCaseId`, copying the
  existing entries' fields (§1). Keep the `editingStatus` that new cases have by default, and
  tell the user if it must become `Publishable` to publish.
- Inside `... When`, use Invoke Workflow File on the workflow under test with explicitly bound arguments, and no other actions.
- Naming: follow the project's existing names. The reference projects use
  `<Workflow>TestCase.xaml` (`ProcessTestCase.xaml`, `InitAllSettingsTestCase.xaml`) — prefer
  that. Absent any convention, `TC_<Capability>_<Behaviour>.xaml` is fine. Put the Scenario
  name in the annotation either way.
- Keep test cases independent and runnable in any order or alone.

## 4. UI automation: selectors and synchronisation

Use this only when a step really has to drive the UI.

- Use the modern scope: **Use Application/Browser**, with Click, Type Into, Get Text, Get Attribute and Check App State inside it. Don't use classic activities in new code.
- **Finnova / Avaloq**: use the library activities from `finnova-library` / `avaloq-library`. Don't write raw selectors against those applications.
- **Targets**: prefer stable attributes (automation id, name, role) and anchors over index or position. Avoid `idx` and wildcards on dynamic text.
  Reuse Object Repository descriptors where they exist (`.objects/` is present in all three reference projects). Validate web selectors with the `web` skill — which uses the `uip rpa uia` CLI, **not** Playwright MCP.
- **Synchronisation**:
  - Before acting, wait for the element's ready state, or use Check App State on the expected screen.
  - After an action that changes state, use the activity's **Verify Execution** option, or a Check App State on the result.
    On `UiPath.UIAutomation.Activities [23.10.13]` this is the `VerifyOptions` property, present
    on Click and Type Into (via `IVerifyExecutionActivity`). It carries `Mode`, `Target`,
    `Timeout`, `Retry`, `DelayBefore` and `IsLoose`; Type Into adds `ExpectedText`.
  - Use Delay only with a comment explaining why. A Delay used for synchronisation is a defect.
  - Timeouts come from config, not literals scattered through the workflow.
- Read the values you will assert (Get Text / Get Attribute) **in `... Then`**, right before the Verify.

## 5. Assertions

Verified against `UiPath.Testing.Activities [23.10.1]`.

| Need | Activity | Available on 23.10.1 |
|---|---|---|
| Boolean condition | **Verify Expression** (`VerifyExpression`) | yes |
| Compare actual vs expected | **Verify Expression With Operator** (`VerifyExpressionWithOperator`), preferred because the log shows both values | yes |
| Numeric/date in a range | **Verify Range** (`VerifyRange`) | yes |
| A UI element property (text, enabled, visible) | **Verify Control Attribute** (`VerifyControlAttribute`) around the activity that reads it | yes |
| Attach evidence (screenshots, output files) | **Attach Document** (`AttachDocument`) | yes |
| Text or document content | **Compare Text** / **Compare PDF Documents**, with **Create Comparison Rule** to ignore dates or IDs | **no — see below** |

### The comparison activities are not on the estate's pin

`CompareText`, `ComparePdfDocuments` and `CreateComparisonRule` are **absent from
`UiPath.Testing.Activities [23.10.1]`**, which is what every estate project pins. Enumerated
from the package assemblies:

| Version | What exists |
|---|---|
| `23.10.1` | none of the three. `AttachDocument` only |
| `24.10.4` | `CreateComparisonRule`, plus `VerifyTextEquivalence` and `VerifyDocumentsEquivalence` |
| `25.10.3` | `CreateComparisonRule`, plus `CompareText` and `ComparePdfDocuments` (renamed) |

So on an estate project today you **cannot** use them. Either assert on extracted text with
Verify Expression With Operator (`Contains` / `RegexMatch`), or propose a dependency bump to
25.10.x and wait for approval (SKILL.md rule 4). Don't write a Compare Text activity into a
23.10.1 project and don't silently bump the pin.

### Properties

| Property | On | Notes |
|---|---|---|
| `Expression` | Verify Expression, Verify Range, Verify Control Attribute | the value or condition under test |
| `FirstExpression`, `SecondExpression`, `Operator` | Verify Expression With Operator | **not** `LeftExpression`/`RightExpression` — those are message tokens only |
| `LowerLimit`, `UpperLimit`, `VerificationType` | Verify Range | `VerificationType` is `IsWithin` or `IsNotWithin` |
| `OutputMessageFormat` | all four Verify activities | the assertion message; token list below |
| `ContinueOnFailure` | all four, inherited from `AssertionActivity` | also `KeepScreenshots`, `ScreenshotsPath`, `Result`, `AlternativeVerificationTitle` |
| `TakeScreenshotInCaseOfFailingAssertion` | all four | paired with `TakeScreenshotInCaseOfSucceedingAssertion` |
| `FilePath`, `Tags` | Attach Document | it is not an assertion — it has `ContinueOnError`, not `ContinueOnFailure` |

`Operator` takes the `UiPath.Testing.Comparison` enum: `Equality`, `Inequality`, `GreaterThan`,
`GreaterThanOrEqual`, `LessThan`, `LessThanOrEqual`, `Contains`, `RegexMatch`.

`OutputMessageFormat` tokens, per activity:

| Activity | Tokens |
|---|---|
| Verify Expression | `{Expression}`, `{ExpressionText}`, `{Result}` |
| Verify Expression With Operator | `{LeftExpression}`, `{LeftExpressionText}`, `{RightExpression}`, `{RightExpressionText}`, `{Operator}`, `{Result}` |
| Verify Range | `{Expression}`, `{ExpressionText}`, `{LowerLimit}`, `{LowerLimitText}`, `{UpperLimit}`, `{UpperLimitText}`, `{Result}` |

The `…Text` variants render the authored expression source; the plain ones render the evaluated
value. Note the asymmetry: the *properties* are `FirstExpression`/`SecondExpression` but the
*message tokens* are `{LeftExpression}`/`{RightExpression}`. Both are correct in their place.

Rules:
- Use at least one Verify per `Then` line, and set `OutputMessageFormat` to say what was checked, the expected value and the actual value.
- Leave `ContinueOnFailure` false unless the scenario truly needs to report several independent checks. If you do set it, the test must still end as Failed.
- Keep `TakeScreenshotInCaseOfFailingAssertion` on for UI tests. The template ships it `True`.
- Normalise before comparing (trim, culture-invariant number and date parsing, CHF formatting). Don't loosen the operator instead.
- Never assert only that "no exception occurred". Assert on the result.
- Compare decimals as `Decimal` with an exact value, or with a tolerance the requirement states. Never invent a tolerance.

## 6. Test data, mocks, setup and teardown

**Data**
- Scenario Outline → data variation file (Excel/JSON as the project already uses). The columns become the test case's In arguments, including expected values.
- Shared or consumable data → **Test Data Queues**. On 23.10.1 the activities are:

  | Activity | Class | Key properties |
  |---|---|---|
  | Add Test Data Queue Item | `AddTestDataQueueItem` | `QueueName`, `Items`, `FolderPath`, `TimeoutMs` |
  | Bulk Add Test Data Queue Items | `BulkAddTestDataQueue` | bulk variant |
  | Get Test Data Queue Item | `GetTestDataQueueItem` | `QueueName`, `MarkConsumed`, `Output` |
  | Get Test Data Queue Items | `GetTestDataQueueItems` | plural, filtered |
  | Delete Test Data Queue Items | `DeleteTestDataQueueItems` | `TestDataQueueItems` |

  **There is no singular "Delete Test Data Queue Item"** — the delete activity is plural only and
  takes a collection. Marking an item consumed is **not** a separate activity either: set
  `MarkConsumed` on Get Test Data Queue Item. (`NewAddTestDataQueueItem` also exists as a
  newer-designer variant of Add.) Item-status filters use
  `TestDataQueueItemStatus`: `All`, `OnlyConsumed`, `OnlyNotConsumed`.
- Generated values → `RandomString`, `RandomNumber`, `RandomDate`, `RandomValue`, `GivenName`,
  `LastName` and `Address` (namespace `UiPath.Testing.Activities.TestData`), seeded or logged so
  a failure can be reproduced.
- Never put real client data or secrets in test files. Credentials come from Orchestrator assets (`security`).

**Mocks**
- Mock only things outside the behaviour under test: mail, external portals, Finnova or Avaloq when unavailable, Orchestrator queues.
- Use Studio's mock testing (a mock of the workflow under test, surrounding the dependency's activities); the runtime class is `UiPath.Testing.Activities.Mocks.MockActivity`, present on 23.10.1. Keep mocks in the folder Studio or the project uses.
- Mocked behaviour must follow the documented contract of the real dependency, and that includes realistic failures. Tag the scenario `@mocked`.
  For the estate's approach to unavailable applications, follow `pdd-sdd-scaffolding`.

**Setup and teardown**
- `... Given` creates exactly the state the scenario needs. Don't depend on leftovers from a previous test.
- Put teardown where it runs whatever happens: the Finally of a Try Catch that wraps When+Then, or the project's established cleanup workflow.
  Teardown closes applications, deletes created queue items and files, and resets records.
- Teardown failures are logged and reported, and they never hide the assertion's outcome.

## 7. Exceptions

- **Expected exception is the behaviour** (for example, a BusinessRuleException for an invalid order):
  catch it in `... When`, store it, and in `... Then` verify its type and message. If no exception was thrown, the test fails.
- **Unexpected exception**: let it fail the test. Don't swallow it, and don't convert it into a passed Verify.
- REFramework processes: test `Process.xaml` (or the transaction workflow) directly with a constructed transaction item and config dictionary, instead of running the whole state machine, unless the scenario is about the framework's retry and queue behaviour.
  The reference projects already ship a `ProcessTestCase.xaml` and a `GetTransactionDataTestCase.xaml` doing exactly this — read them before writing your own.
- Per `AGENTS.md`: `BusinessRuleException` means "the application refused"; `ApplicationException` means a technical failure. Carry the application's own message text into the assertion.

## 8. Validation and execution

**Static validation**
- Every new XAML must be well-formed. Check that namespaces and assembly references match the existing files and that every Invoke argument is bound with the right direction and type.
- Run Workflow Analyzer if available (Studio, or `uipcli package analyze <project.json>`). Report rule violations as they were returned.
- Diff against the starting state. Only the intended files should have changed.
- A project that pins the Finnova/Avaloq libraries will not restore unless those `.nupkg`s are on
  the feed — see `README.md` → "Prerequisite". A restore failure there is not a test defect.

**Execution**: use only what is actually available, and report which one you used:

| Route | Notes |
|---|---|
| Studio Test Explorer (user runs it) | Give the exact test cases to run, then ask for the results or the log |
| UiPath CLI against Orchestrator test sets | Needs a published package and a configured test set. Hand off to `uipath-test` for Test Manager flows |
| Not possible (no robot, no app, no auth) | Status `Not executed` with the reason and the exact steps to run |

Record each test's status from the output: `Passed`, `Failed`, `Error` (the test crashed before its assertion) or `Not executed`.
For failures, state whether you believe it's a **product defect** (the actual result contradicts the requirement) or a **test issue** (selector, data, environment), and give your evidence.

## 9. Unverified against estate

Everything in §5 and §6 above was enumerated directly from the
`UiPath.Testing.Activities` package assemblies in the local NuGet cache
(`23.10.1`, cross-checked against `24.10.4` and `25.10.3`), and §3 from
`../REFramework-*/Tests/WorkflowTestCaseTemplate.xaml` and `project.json`. The following could
**not** be verified, and the text above is retained on the stated assumption:

| Item | Assumed for | Why unverified |
|---|---|---|
| Studio's **display names** for 24.10's `VerifyTextEquivalence` / `VerifyDocumentsEquivalence` | `24.10.4` | Only the runtime class names are readable from assembly metadata. Whether the Studio activity panel labels them "Compare Text" / "Compare PDF Documents" on 24.10 (as 25.10 does) was not confirmed. On 25.10.3 the class names match the display names directly. |
| The `fileInfoCollection` field that points at a **data variation file** | `23.10.1` | No data-driven test case exists anywhere in the estate; all six registered entries are plain `TestCase` with the five fields in §1. No `dataVariation*` key occurs in any `project.json` in the layout. Create one data-driven test case in Studio and read the field name back before scripting it. |
| **Coded test case** (`.cs`) conventions | n/a | No `.cs` file exists in any estate project. The "match the existing style" instruction in §1 is sound but has no local example to match. |
| `Compare Text` / `Compare PDF Documents` / `Create Comparison Rule` in **actual estate use** | `25.10.x` | Confirmed to exist in the package at 25.10.3, but no estate project pins a version that has them, so none is in use and no argument signature has been exercised here. |
