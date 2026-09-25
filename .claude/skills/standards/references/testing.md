# Testing an automation in this estate

Scope: how to *run and prove* a workflow on a developer machine here. For UiPath's own test
framework — Test Manager, Given-When-Then test cases, `VerifyExpressionWithOperator`,
data-driven variations, execution templates, mocks — use
`.claude/skills/uipath-rpa/references/testing-guide.md`. That guide describes the product;
this file describes what actually works against these projects and these towers.

## Two different things, do not confuse them

| | **Probe** | **Test case** |
|---|---|---|
| Lives in | `Tests/Test-<Thing>.xaml` | `Tests/`, registered in `project.json` |
| Asserts | outside, by the person or script reading the output | inside, with test activities |
| Purpose | answer one question about production code, once | regression, re-run forever |
| Cost | minutes | hours |

Most estate work needs a **probe**: "does this actually create the folder?", "what does that
mail body look like?". A probe is a thin wrapper that invokes the **real production workflow**
and returns its outputs — it must not reimplement the logic it is checking, or it proves
nothing. UC252 `Tests/Test-Rollover_*.xaml` are the worked examples.

Promote a probe to a test case when the answer must stay true: year rollover, filing rules,
anything a future refactor could silently break.

## Running anything at all

`uip rpa run` is broken on these machines. The working recipe is UiRobot `pack` then
`execute`:

```powershell
$robot = 'C:\Program Files\UiPath\Studio\UiRobot.exe'
& $robot pack "<proj>\project.json" --output $out -v 31.0.0
& $robot execute --file "$out\<Id>.31.0.0.nupkg" `
    --entry 'Tests\Test-Thing.xaml' `
    --folder 'Modern/<OrchestratorFolder>' `
    --input '{"in_Year":2027}'
```

Four rules, each learned the hard way:

1. **`--entry` reaches any workflow**, not just declared entry points. This is what makes
   single-workflow probing possible — you do not need to run `Main.xaml`.
2. **`--folder` is mandatory.** Without it every `Get Asset` / `Get Credential` fails with
   *"organization unit is required"*, error 1101.
3. **Always pass a unique `-v`.** `execute` extracts to
   `%USERPROFILE%\.nuget\packages\<id>\<version>\` and **reuses that directory if it already
   exists** — same version number, silently old code, green run.
4. **If Studio has the project open**, `pack` fails with *"already opened in another Studio
   instance"*. Copy the project to `%TEMP%` and pack the copy. Confirm a `Version:` line
   appeared before trusting any run.

Output arguments come back as JSON on stdout. Per-transaction detail is in
`%LOCALAPPDATA%\UiPath\Logs\<date>_Execution.log`, one JSON object per line.

## Validation is two separate checks

| Command | Catches | Misses |
|---|---|---|
| `uip rpa validate` (run **from inside** the project dir — there is no `--project-path`) | VB compile errors: `BC30451`, `BC30002`, `BC30456` | estate conventions |
| `_build/validate.py` | orphaned workflows, unresolved invokes, TST/PRD config parity, XAML shape | anything the compiler would say |

Run **both**. Neither is sufficient, and a clean `uip rpa validate` does **not** mean the
project opens in Studio — missing assembly references surface later as `BC30456`.

`uip rpa validate` has also returned a stale result on consecutive runs with no file changes
in between. If it disagrees with itself, pack: a successful `pack` is the stronger signal.

## Never probe against production data

Copy the artefacts to a sandbox root and point config at the copy:

```
_rollover_test\
  Übersicht der GV PROXY_V1.0.xlsx    <- a COPY
  2026 MENGUENERHEBUNG\               <- deliberately empty
```

Build the config dictionary **inside the probe** rather than loading `Config_TST.xlsx`, so the
paths cannot accidentally resolve to the real share:

```vb
New Dictionary(Of String, Object) From {
    {"File_System_Root", CObj(in_Root)},
    {"Excel_System_Master_File", CObj(ChrW(220) & "bersicht der GV PROXY_V1.0.xlsx")}}
```

`ChrW(220)` is `Ü` — avoid non-ASCII literals in XAML and in `--input` JSON.

After the run, verify the real artefacts are untouched (file count, `LastWriteTime`, byte
size). Say so explicitly when reporting.

## Assert outside the workflow

A workflow's own boolean only means "the activity did not throw". `out_Written = True` came
back from a volume report that had no borders, no colour and a text date. Check the artefact:

```python
import openpyxl
wb = openpyxl.load_workbook(path)
ws = wb[wb.sheetnames[0]]
assert ws["A1"].number_format == "mmm-yy"
assert ws["A2"].fill.fgColor.rgb == "FF92D050"
```

Diffing a generated file cell-by-cell against a known-good reference is the strongest check
available and costs about ten lines. Prefer it to eyeballing.

## Probes with real-world effects

A probe that sends mail, writes to a bank folder or moves a message **must not be runnable by
accident**:

- Name it `Test-<Thing>_Live.xaml`.
- Never include it in a run-all.
- State the authorisation and date in the root annotation.
- Make the target visible in the output — `Test-Exception_Mail_Live.xaml` returns
  `out_Recipient` so the destination is never a guess.
- Mark the payload as a test where a human will see it (`TESTLAUF - kein echter Fall`).

**Design for a dry run first.** Expose the composed artefact so the logic can be proven
without the side effect: `Mail-Send_Exception.xaml` returns `out_Subject` / `out_Body`, so all
body variants were verified with `out_Sent = False` before a single mail was sent.

## Placement and naming

```
Tests/
  Tests.xlsx              stock REFramework test data
  Test-<Thing>.xaml       probe — safe to run
  Test-<Thing>_Live.xaml  probe with real-world effects — never in a run-all
```

`Test-` prefix, `PascalCase_With_Underscores` after it, matching the estate's workflow naming.
Arguments follow the usual `in_` / `out_` / `io_` rules.

## Known gaps in this estate

- **`UiPath.Testing.Activities` is a dependency in projects that never use it.** All three
  UC252 projects reference `[23.10.1]`; there are zero test activities, zero `testCases` in
  any `project.json`, and no `RunAllTests.xaml` anywhere. The package is carried, not used.
- **No regression suite exists.** Everything written so far is probes. Nothing re-runs on a
  change, so every refactor is verified by hand or not at all.
- **No CI.** `pack` + `execute` are run manually from PowerShell.

## PowerShell traps when scripting runs

- **Variables are case-insensitive.** `$r = & $R ...` overwrites the robot path with the
  command's output, and every later iteration silently reuses the first result. Use names that
  differ by more than case.
- Build `--input` with `ConvertTo-Json -Compress` on a hashtable; hand-written JSON gets the
  backslash escaping in Windows paths wrong.
- `2>&1` merges the robot's stderr, which is where exception text appears.
