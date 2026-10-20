---
name: bdd-test
description: Turn business requirements, acceptance criteria, user stories or manual test steps into executable UiPath Studio test cases written as Gherkin (Given-When-Then) and implemented in the project's BDD test case template. Always invoke when asked to write, generate, automate, convert or fix a UiPath test case, test automation project, .feature file, Gherkin scenario, acceptance test, regression test, data-driven test, mock test, or "test for this workflow" — including Finnova, Avaloq and web-portal processes. Also invoke when asked to make an existing test data-driven, to parameterise or extend a test with examples, or to add a Scenario Outline, an Examples table or a data variation file. Covers authoring and validating tests in Studio; for Test Manager projects, test sets, executions and reporting, use uipath-test.
---

# bdd-test — BDD test cases in UiPath Studio

Turn requirements into **Gherkin scenarios → UiPath test cases** that actually check outcomes.
This skill authors and validates tests in the project. It does not administer Test Manager.
When the test case is ready, hand off to `uipath-test` (if installed) to link it and run it there.

## When to use

| Use this skill | Use something else |
|---|---|
| Acceptance criteria / user story / manual test script → automated test | Test Manager projects, sets, executions, reports → `uipath-test` |
| Adding test cases to a process or a test automation project | Building the process itself → `standards` + app skill |
| Data-driven tests (Scenario Outline → data variations) | Credentials/assets for the test → `security` (still required) |
| Mocking a workflow or an unavailable application | First scaffold from a PDD/SDD → `pdd-sdd-scaffolding` |
| Fixing a flaky or failing test case | |

Load alongside: `standards` (always), `security` (always), plus `finnova-library`, `avaloq-library` or `web` for whatever the test drives.
**Where they conflict, estate skills win over this one, and this one wins over generic UiPath guidance.**

## Workflow

Follow the steps in order, and don't write any XAML before step 3 is done.

1. **Inspect the project (read-only).** Read `project.json`, especially `targetFramework`, `dependencies` and `designOptions.fileInfoCollection`.
   Find the existing test cases, their folder, the template they use, and the test data files and mocks.
   Check whether `UiPath.Testing.Activities` is already a dependency and which version.
   Check whether the project uses the Object Repository (`.objects/`) and whether it has coded test cases (`.cs`).
   Note any `AGENTS.md`. Record what you found; it shapes everything that follows. → `references/uipath-implementation.md` §1
2. **Write the Gherkin first.** Create one `.feature` file per capability and one Scenario per acceptance criterion.
   Every `Then` must name an **observable** expected result.
   If a requirement has no checkable outcome, stop and ask; don't make one up.
   Show the scenarios to the user before implementing when the requirements were ambiguous. → `references/bdd-patterns.md`
3. **Map each scenario to an implementation.** Decide the test case file and the data variation file.
   Decide how the `When` step invokes the workflow under test, and which assertion activity each `Then` step uses.
   Decide what needs mocking (external apps, mail, queues) and what setup and teardown are needed.
   Show this map as a table. → `references/uipath-implementation.md` §2
4. **Implement.** Start from the project's own BDD template, or from an existing test case's structure. Never hand-invent a skeleton when one exists.
   Use modern activities, robust selectors and explicit synchronisation. Write one assertion per expected result.
   Assertion messages must show both the expected and the actual value. → `references/uipath-implementation.md` §3–§6
5. **Validate statically.** Check that every new XAML parses and every argument is bound.
   Check that new `fileInfoCollection` entries mirror the existing ones, that no existing file changed except where intended, and that dependencies are pinned.
   Run Workflow Analyzer / `uipcli package analyze` if it is available.
6. **Execute if you can, then report.** Run the tests through whatever the environment actually offers.
   Record each result exactly as the tool returned it. If you couldn't run them, mark them **Not executed** and give the command or steps to run them.
   Fill `assets/execution-report-template.md`.

## Critical rules

1. **Never fabricate results.** A test result is only "Passed" or "Failed" if a run in this session produced it, and you cite the output or log.
   Static validation is not execution.
   "Should pass", "expected to pass" and an empty results column are all forbidden. The honest status is `Not executed`.
2. **Never weaken an assertion to make a test pass.** Don't use `True = True`, an always-true expression, or a Verify activity with `ContinueOnFailure` hiding a real check.
   Don't widen tolerances, delete assertions, or catch-and-ignore an exception thrown in `When`/`Then`.
   If the product is wrong, the test must fail. Report it as a defect, not a test issue.
3. **Preserve existing work.** Don't modify, rename or reformat existing workflows or test cases unless the user asks.
   Add new files. If a change to an existing file is unavoidable (for example, adding an argument so a workflow can be invoked), propose it and wait.
4. **Don't change project-level settings silently.** That includes the project type, target framework, Studio or compatibility version, existing dependency versions, and the test case `editingStatus` (`InProgress` or `Publishable`).
   Propose such changes and wait.
5. **No invented activities, properties or selectors.** Use only activities whose package is in `project.json`, or one you explicitly propose adding.
   Take Finnova and Avaloq interactions from the library skills. Validate web selectors with the `web` skill.
6. **Test data is not production data.** Use synthetic values or Test Data Queues. Don't hard-code client numbers, IBANs or names from real cases.
   Credentials come from Orchestrator assets via `security`, never from the test file.
7. **Every test cleans up.** Anything it creates (queue items, files, records, open apps) must be removed or closed in teardown, including when the test fails.
8. **Synchronise on state, never on time.** Wait with Check App State or the activities' own wait and verify options. Use `Delay` only with a written reason.
9. **One behaviour per scenario.** A scenario that asserts unrelated things gets split.

## Definition of done

- [ ] A `.feature` file exists. Each Scenario traces to a requirement or AC ID, and every `Then` is observable.
- [ ] One UiPath test case per Scenario (or a data-driven test case per Scenario Outline), following the project's template, folder and naming.
- [ ] Every `Then` maps to at least one Verify activity whose message shows the expected and actual values.
- [ ] Given/When/Then hold only setup, action and assertion respectively, and teardown runs even when the test fails.
- [ ] Test data is synthetic or comes from a queue or file, and there are no secrets in files.
- [ ] Mocks are used only for external dependencies, never for the logic under test.
- [ ] Existing files are unchanged (or changed only with approval), and there is no unapproved project-setting or dependency change.
- [ ] Static validation passed, or its failures are listed.
- [ ] The execution report is filled in, every status is backed by evidence or marked `Not executed`, and defects are separated from test issues.

## References

| File | Read when |
|---|---|
| `references/bdd-patterns.md` | Writing or reviewing Gherkin; turning manual steps or ACs into scenarios |
| `references/uipath-implementation.md` | Inspecting the project, choosing activities, assertions, data, mocks, execution |
| `references/examples.md` | You want a worked end-to-end example (web, Finnova-style, data-driven, mocked) |
| `assets/execution-report-template.md` | Final step: the report you hand back |
