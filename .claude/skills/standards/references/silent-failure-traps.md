# Silent-failure traps

Every entry here is something that ran, reported success, and did the wrong thing. None of them
throws. None shows up in a code review by inspection. Each one was found the same way — by
disbelieving a green run — and each cost hours.

They are grouped by what you are doing at the time. `validate-project.ps1` enforces the ones that
can be detected statically; the rule name is given where it exists.

---

## Writing to Excel

### The classic write activities are broken on Windows / .NET 6

`rule: classic-excel-write`

`ui:AppendRange` and `ui:WriteRange` throw on a `targetFramework: Windows` project:

```
System.InvalidOperationException: Error in implicit conversion. Cannot convert null object.
   at UiPath.Excel.Activities.WorkbookActivity`1.EndExecute(...)
```

Reproduced on an empty sheet and a seeded one, with an absolute path, no Excel process running
and no lock file — while **`ui:ReadRange` on the very same workbook works**. The estate's older
REFramework samples use the classic form and are fine, because they are .NET Framework projects;
copying from them is what leads you here.

Use the modern activities in `UiPath.Excel.Activities.Business`:

```xml
<ueab:ExcelProcessScopeX ...>
  <ueab:ExcelProcessScopeX.Body>
    <ActivityAction x:TypeArguments="ui:IExcelProcess">
      <ActivityAction.Argument>
        <DelegateInArgument x:TypeArguments="ui:IExcelProcess" Name="ExcelProcessScopeTag" />
      </ActivityAction.Argument>
      <ueab:ExcelApplicationCard WorkbookPath="[path]" ...>
        <ueab:ExcelApplicationCard.Body>
          <ActivityAction x:TypeArguments="ue:IWorkbookQuickHandle">
            <ActivityAction.Argument>
              <DelegateInArgument x:TypeArguments="ue:IWorkbookQuickHandle" Name="Excel" />
            </ActivityAction.Argument>
            <ueab:WriteRangeX Append="True" ExcludeHeaders="True"
                              Destination="[Excel.Sheet(&quot;SheetName&quot;)]"
                              Source="[myDataTable]" />
          </ActivityAction>
        </ueab:ExcelApplicationCard.Body>
      </ueab:ExcelApplicationCard>
    </ActivityAction>
  </ueab:ExcelProcessScopeX.Body>
</ueab:ExcelProcessScopeX>
```

```
xmlns:ue="clr-namespace:UiPath.Excel;assembly=UiPath.Excel.Activities"
xmlns:ueab="clr-namespace:UiPath.Excel.Activities.Business;assembly=UiPath.Excel.Activities"
```

`WriteRangeX` carries `Append`, which makes it a drop-in for `AppendRange`. Property sets, read
from the 2.22.4 assembly metadata:

| Activity | Properties |
|---|---|
| `WriteRangeX` | `Source`, `Destination`, `Append`, `ExcludeHeaders`, `IgnoreEmptySource` |
| `ReadRangeX` | `Range`, `ReadFormatting`, `HasHeaders`, `VisibleOnly`, `SaveTo` |
| `ExcelApplicationCard` | `WorkbookPath`, `Password`, `CreateNewFile`, `AutoSave`, `ReadOnly`, `KeepExcelFileOpen`, `TemplatePath`, `Body` |

`AddHeaders` is **not** a property of `AppendRange`. Adding it fails the UiRobot pack.

### Never write a data-sized table into a fixed-shape workbook

A monthly report grid was days 1–31 plus a `Total` column. The builder sized the day columns to
`DateTime.DaysInMonth(...)`, so in a 30-day month `Total` landed one column left — in the
template's *day 31* column. The template's own `SUM` in the real Total column then added the
Total to the counts and reported **double**. No error; just a plausible wrong number.

Match the template's grid exactly, whatever the data says.

### Excel coerces header strings

A column named `"Sep 26"` became the date **26 September**. Write ISO (`2026-09-01`) or a real
date if the cell is meant to hold one.

---

## Reading dates out of Excel

### Never `.ToString()` a cell and parse it with a fixed culture

`rule: hardcoded-culture`

`row(5).ToString()` renders in the *machine's* culture. A hardcoded `de-CH` parse rejected every
`MM/dd/yyyy` value a robot produced, and the workflow skipped the row. Convert from the DataRow
**object** (`CDate(row(5))`), or use `InvariantCulture` — not a guessed locale.

---

## VB expressions

### An expression cannot write through a ByRef `out` parameter

`rule: byref-out-arg`

```vb
' WRONG - the Boolean is right; recordDate is never assigned and keeps DateTime.MinValue
DateTime.TryParse(raw, culture, DateTimeStyles.None, recordDate)
```

A UiPath expression is evaluated as a read-only lambda, so the `out` write lands on a temporary.
Every row then compared as `01.01.0001`, nothing was ever due, and `0 notifications due` read as
correct business behaviour for a full day.

Guard and assign as two steps:

```vb
' Assign 1 (Boolean):  IsDate(row(5))
' Assign 2 (DateTime): CDate(row(5))
```

Same applies to `Dictionary.TryGetValue` and anything else with an `out` parameter.

---

## Paths and config

### A relative path resolves into the extracted package, not the project

`rule: relative-persisted-path`

At runtime the working directory is
`%USERPROFILE%\.nuget\packages\<package-id>\<version>\content\`, **not** the project folder. A
config value of `Data\Output\DispatchLog.xlsx` therefore writes inside the extracted package,
which is thrown away on the next version.

That file was the audit log providing idempotency. Losing it silently re-armed duplicate emails
to external parties — the worst outcome the process was designed to prevent.

Anything that must outlive a run gets an absolute path, or
`Path.Combine(in_Config("File_System_Root").ToString(), in_Config("...").ToString())`.

---

## Filtering a business workbook

### Filter positively

`rule: negative-active-filter`

`Where(Active <> "FALSE")` let two explanatory footnote rows at the bottom of a mapping workbook
through as if they were banks — the robot reported `4 active bank(s)` instead of 2, and the
generated report gained two rows of prose. Blank is not FALSE.

Use `= "TRUE"`, and add a shape guard on the key column (`Length <= 6` for a bank code) so future
prose in that column cannot pass either.

### Log every skip

A loop that silently dropped unparseable rows hid that **859 of 862** were being discarded. One
`Warn` in the `Else` branch surfaced it immediately. If a filter can drop a business item, the
drop must be visible — it is the same argument as an unresolved `TODO_SELECTOR`.

---

## Imports

### Every xmlns assembly must be referenced

`rule: xmlns-assembly-unreferenced`

A workflow that declares `xmlns:sd="clr-namespace:System.Data;assembly=System.Data.Common"`
without a matching `<AssemblyReference>System.Data.Common</AssemblyReference>` passes
`uip rpa validate` clean, then fails the UiRobot pack with:

```
Some references are not imported in current workflow. Do you want to import them automatically?
The project has validation errors and cannot be published.
```

The message names no file. Diagnosing it by bisection across a 30-workflow project takes hours;
the rule finds it in a second.

Do **not** over-correct: `System.Private.CoreLib` and friends appear in every Studio-authored
file and are entirely legitimate.

---

## Scheduling

### A once-per-period gate has no recovery

"Run daily, do nothing unless today is the first working day of the month" fires exactly once. If
the robot is down, in maintenance, or Orchestrator is wedged that morning, the month is never
reported and nothing complains. An Orchestrator `1W` cron has the same single-shot property, and
additionally knows nothing about the configured holiday calendar.

Gate on **"on or after the due point, and not already done"** instead. It self-heals on the next
run and is naturally idempotent — the same shape as a dispatch log preventing duplicate sends.

---

## Credentials

### A SecureString may not leave the scope that created it

Analyzer rule `ST-SEC-008`. Fetching a credential once at the top of a workflow and consuming it
inside an `If` branch fails the build. Fetch it inside each scope that needs it.

`uip rpa pack` runs the analyzer and catches this; `uip rpa validate` does not.
