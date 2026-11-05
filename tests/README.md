# `tests/` — proof that every `validate-project` rule still fires

```powershell
pwsh -NoProfile -File tests/run-fixtures.ps1
pwsh -NoProfile -File tests/run-fixtures.ps1 -Rule leaf-body-stub -KeepTemp
```

## Why this exists

CI used to check one thing about the checker: that `templates/` produces zero findings. That
proves a rule does not **false-positive**. It proves nothing about whether the rule still
**works**.

A rule whose regex stopped matching — a renamed activity, a reworded placeholder, a refactor
that moved the text it keys on — would go on reporting nothing, and CI would stay green.
`validate-project.ps1` would quietly become a 42 KB no-op, and the first symptom would be a
silent failure reaching production. Which is the exact class of defect every rule in it exists
to catch.

So each rule gets a pair, and **both directions are asserted**:

| | |
|---|---|
| `bad/` | the rule **must** appear among the findings |
| `good/` | the rule **must not** appear |

## What `good` means, precisely

**"This rule is silent", not "no findings at all".** Other rules may legitimately fire on a
fixture: a project built to trip exactly one rule and nothing else would have to be a complete
conformant project per rule, and nobody would maintain 31 of those. The assertion is per-rule,
and this is stated rather than left to be discovered.

## Layout — the fixture *is* the diff

```
tests/
  run-fixtures.ps1          the runner
  lib/New-ConfigWorkbook.ps1  TSV -> Config_<ENV>.xlsx, at test time
  fixtures/
    _base/                  a minimal conformant Windows project. Reports ZERO findings.
    <rule>/
      notes.md              what the rule catches, and what the cases differ by
      bad/                  overlay — the rule must fire
      good/                 overlay — the rule must be silent
      bad-<variant>/        optional: another trigger SHAPE
      good-<variant>/       optional: another thing it must stay silent on
```

### One case per trigger shape

A rule with more than one way to fire needs **one case per shape**. A single fixture carrying
both would stay green when one of them broke — the assertion is on the rule id, so either
trigger satisfies it.

`unresolved-mock` is the live example: it fires on the `[MOCK]` text marker **and** on a
declared mock (`Mock*/` folder, or a `Mock-*` / `Mock_*` file name), so it has `bad` and
`bad-declared-mock`. `leaf-body-stub` has `good-declared-mock` for the matching carve-out —
the declared mock it must *not* report.

`bad` and `good` (or at least one `bad-*` and one `good-*`) are required; a rule with only one
side fails the run.

Each case is **the base plus an overlay**. Copying a whole project per case would bury the one
difference that matters in ten identical files; this way the fixture directory *is* the diff,
and reviewing a fixture means reading three lines rather than a project.

`_base` reporting zero findings is what makes that work — it is the fixed point every overlay
is measured against. If a new rule fires on the base, the base is wrong, not the rule.

### Config is TSV, not `.xlsx`

`Sheet<TAB>Name<TAB>Value`, built into a workbook at test time by `lib/New-ConfigWorkbook.ps1`.
Committing 60-odd binary `.xlsx` files would make the fixtures unreadable and unreviewable,
which defeats the point of having them.

- `Data/Config.tsv` — used for **both** environments.
- `Data/Config_TST.tsv` / `Data/Config_PRD.tsv` — override one environment. This is what the two
  parity rules need.

All three sheets (`Settings`, `Constants`, `Assets`) are always created with a header row, even
when no rows target them: `assets-empty` distinguishes an **empty** Assets sheet from a
**missing** one.

### `fixture.json` — only when the default will not do

```json
{
  "projects": ["Dispatcher", "Performer"],
  "remove": [".gitignore"],
  "touch": ["Exceptions_Screenshots/stray.png"],
  "args": ["-TemplateMode"]
}
```

| Key | Default | For |
|---|---|---|
| `projects` | `["Proj"]` | `queue-name-match`, the only cross-project rule. With more than one, the overlay is nested per project name. |
| `remove` | `[]` | `not-a-project` (removes `project.json`), `missing-gitignore` (removes `.gitignore`) — a fixture that needs the base to be *less* complete. |
| `touch` | `[]` | a file the fixture needs but **cannot commit**, because this repo's `.gitignore` ignores it and should keep doing so. `run-output-clean` needs a stray file under `Exceptions_Screenshots/`, which is ignored as a data-protection backstop — those are screenshots of logged-in banking sessions. The runner creates it at test time rather than the `.gitignore` being weakened for a test. |
| `args` | `[]` | extra switches for `validate-project.ps1`. |

Every other fixture file is a committed, reviewable file. Check that it stays that way:

```powershell
Get-ChildItem tests -Recurse -File -Force | ForEach-Object { git check-ignore $_.FullName }
# expect: no output. A fixture git ignores is a fixture CI never sees.
```

## Adding a rule

1. Write the rule in `validate-project.ps1`.
2. Create `tests/fixtures/<rule>/bad/` and `good/`, plus `notes.md`.
3. Run the suite (35 rules, 74 assertions as of the `card-instance-unbound` addition). **A new rule with no fixture
   directory fails the run** — the coverage check
   compares the rule ids it can find in the checker against the fixture directories, both ways.
   That is the half that makes the suite hard to cheat: without it, adding a rule and no fixture
   leaves the suite green and the new rule untested, which is the same hole one rule along.

If you cannot write a failing fixture for a rule, say so rather than deleting the rule or
faking the fixture.

## Coverage, and what is honestly not covered

35 rules, 35 fixture directories, 74 assertions. Three things inside existing rules are **not**
exercised, and are recorded here rather than implied:

- **`object-repository-not-shared`, the git-ignored branch.** The rule has two halves: `.objects/`
  holding no descriptors, and `.objects/` holding descriptors that `git check-ignore` reports as
  ignored. Fixtures are materialised in a temp directory outside any repository, so git cannot be
  asked. The first half is covered; the second is not.
- **`secret-argument-string`, both carve-outs.** The rule must stay silent on an argument named
  `*Credential*` (this estate names those after the Orchestrator *asset*, which is legitimately a
  String) and on anything passed to `AssetName=`. Neither carve-out is fixtured; both are
  load-bearing on real estate code, and breaking one would make the rule cry wolf rather than go
  quiet — a failure the `good` case would not catch.
- **`card-instance-unbound`, the property-element form.** The rule accepts `InUiElement` /
  `OutUiElement` either as an attribute or as the `<uix:NApplicationCard.InUiElement>` child
  element Studio emits for a non-trivial expression. All four fixtures use the attribute form,
  which is what Studio wrote in the project this rule came from; the child-element branch is
  **not** exercised. Breaking it would report a correctly-bound card — a false positive the `good`
  case would not catch.

Several rules also cover more trigger shapes than their fixture exercises —
`template-default-left` alone covers the `[UC-SPECIFIC — replace]` marker, the
`<PROJECT-NAME-TBD-ask-team>` name, the stock `ProcessABCQueue`, the stock
`logF_BusinessProcessName`, and two template GUIDs. Where the shapes share one code path, one
case is enough; where they are **separate branches**, add a `bad-<variant>` (see above). That
distinction is why `unresolved-mock` has two cases and `template-default-left` has one.

## Fixtures are not a substitute for a real project

The fixtures prove each rule still *fires*. They cannot tell you whether it fires on the right
things, because every fixture was written by the same person as the rule. Running the checker on
a real Windows project is a different test, and it has now found three defects the suite could
not:

- `leaf-body-stub` reported 6 declared mocks (`Mock_System/Mock-*.xaml`) alongside 1 true
  positive — noise that would have got the rule suppressed, hiding the true positive with it.
- `unresolved-mock` reported **nothing** on a project with a 22-workflow mock layer, because
  none of those files carried the `[MOCK]` string.
- `card-instance-unbound` reported **5 of 7** unbound Application Cards, silently missing the two
  that Studio had serialised as `InUiElement="{x:Null}"` — including the file that threw in both
  failed runs. All three fixtures were hand-written, so none of them carried Studio's explicit-null
  form, and the rule's presence-only match carved out exactly the cards most worth reporting.

All three are fixed, and all three now have fixtures (`bad-explicit-null` for the last).
**Re-run against a real project after changing a rule** — not instead of the suite, after it.

A packed `.nupkg` is a usable stand-in when the project folder is gone: `Expand-Archive` it and
point the checker at `content/`. That is how the calibration above was done, against the pre-fix
and post-fix packages of the same project — 7 findings and 0 respectively. Expect
`object-repository-not-shared` from an extracted package regardless; `.objects/` is not in it.

## Verifying the suite is not vacuous

A test suite that cannot fail is worth as much as a rule that cannot fire, so check it the same
way — break something and watch it go red:

```powershell
# 1. break a rule's pattern, e.g. <ui:(AppendRange|WriteRange)\b -> ...ZZZ
#    expect: FAIL classic-excel-write bad - DID NOT FIRE, exit 1
# 2. add an Add-Finding for a rule id with no fixture directory
#    expect: MISSING fixtures for: <id>, exit 1
```

Both were run against this suite and both failed as required; restore the file afterwards and
confirm the clean run is back to 74 passed.
