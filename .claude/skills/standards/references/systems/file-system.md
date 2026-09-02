# `File_System/` — files, Excel, PDF and trace logs

Wraps **stock UiPath activities** (Excel, PDF, System) — no custom library. Present in all
three reference projects with different contents, because each process consumes different
inputs.

## Configuration

All paths come from config; no workflow builds an absolute path itself.

| Key | Example |
|---|---|
| `File_System_CP_List` | `Data\Input\CounterPartyList.xlsx` |
| `File_System_Bank_List` | `Data\Input\BankLists.xlsx` |
| `File_System_Folder_Download_<Counterparty>` | `D:\Data\RPA\BPO\UC39\Output\CP\UBS` |
| `File_System_Folder_TraceLogs` | `D:\Data\RPA\BPO\UC39\Output\Trace Logs` |
| `File_System_Tracelog_Folder_Path` | `P:\System_Daten\SCK\…\Prod\Output` |
| `File_System_Tracelog_File` | populated at runtime by `Tracelog_Init` |
| `File_System_Tracelog_RotateInDays` | Orchestrator asset `Tracelog_RotateInDays` |
| `Mappings_File`, `Kurztext_File` | `Data\Input\Mappings.xlsx`, `Kurztext.xlsx` |

Relative paths (`Data\Input\…`) resolve against the project folder; absolute paths point at
the robot's data drive or a network share. Both forms are in use — read the key, don't
assume.

## Workflow inventory

### UC39

| Workflow | In | Out |
|---|---|---|
| `File-Excel_Read` | `in_FilePath`, `in_SheetName`, `in_Range` | `out_ExcelDT` |
| `File-Read_Init` | `in_File` | `io_PDFText` |
| `File-PDF_To_Text_File_Conversion` | `in_FolderPath`, `in_Counterparty` | — |

`File-Read_Init.xaml` is invoked **14 times** — once per counterparty extractor. It is the
shared "load this PDF's text once" entry point. Use it rather than reading a PDF again.

### UC81

| Workflow | In | Out |
|---|---|---|
| `Excel_File_Read` | `in_File`, `in_Sheet`, `in_Range` | `out_DT` |

### TKB-UC11 — trace log

| Workflow | In | Out |
|---|---|---|
| `Tracelog_Init` | `in_File_Format`, `in_RotateFileInDays`, `io_Config` | — |
| `Tracelog_Append` | `in_Config`, `in_AppendValues` (String[]) | — |
| `Tracelog_Get` | `in_Config`, `in_Trace` | `out_IsExists`, `out_Values` (String[]) |

## The trace log — idempotency across runs

The trace log is not diagnostic logging. It is the project's **"have I already processed
this?"** store, and it is what makes the process safe to re-run after a crash.

```
Tracelog_Init   ' at job start: create/rotate the file, write its path into io_Config
                '               under File_System_Tracelog_File
Tracelog_Get    ' at transaction start: has this key been seen?
                '   → out_IsExists = True → Throw BusinessRuleException("Go to next order")
Tracelog_Append ' after each meaningful step: record what was done
```

`Process.xaml` in TKB-UC11 opens with exactly this check. UC39 does the same with
`TraceStatus` and a skip pattern:

```vb
Not Exists Or Not String.IsNullOrEmpty(TraceStatus) AndAlso Regex.IsMatch(TraceStatus, "TBC|Extracted")
```

Rotation is driven by the Orchestrator asset `Tracelog_RotateInDays`.

Activities used: `ReadTextFile`, `AppendLine`, `PathExists`, `CreateDirectory`, `MoveFile`.

> UC39 additionally depends on the `Swisscom.TraceLog.Library` NuGet package
> (`[2.1.1]`) alongside these workflows. The two mechanisms coexist; check which one a
> given workflow uses before extending it.

## PDF extraction (UC39)

Counterparty trade confirmations arrive as PDF attachments. `File_System/` turns them into
text; `Logic/Logic-CP_<Bank>_Extract.xaml` parses that text.

Activities: `ReadPDFText`, `ReadPDFWithOCR`, `GoogleOCR`, `WriteTextFile`, `InvokeCode`.
Dependencies: `UiPath.PDF.Activities [3.14.1]`, `iTextSharp [5.5.13.3]`.

**`ReadPDFText` first, OCR only as a fallback.** OCR is slow and lossy; the project reaches
for `ReadPDFWithOCR` / `GoogleOCR` only when the text layer is missing.

`GoogleOCR` sends page images to an external Google endpoint. Trade confirmations contain
customer and counterparty data — confirm that route is approved before extending its use.
See `.claude/skills/security/references/prohibited-practices.md`.

## Excel

`ExcelApplicationScope` + `ExcelReadRange` (UC39, UC81) or `ReadRange` (Framework). Reads
are wrapped in a small workflow (`File-Excel_Read`, `Excel_File_Read`) taking file, sheet and
range — call that rather than opening a scope inline.

## Cautions

- **`MessageBox` in `File-PDF_To_Text_File_Conversion.xaml`.** A modal dialog blocks an
  unattended robot indefinitely. Remove it if you touch this workflow; never add one.
- **Committed run output.** `Data/Output/` in the reference projects contains real artefacts
  (`output_28thOct.txt`, `Strukis.txt`). Keep `Data/Output/` and `Data/Temp/` to their
  `placeholder.txt` only.
- **Downloaded attachments contain customer data.** `File_System_Folder_Download_*` points at
  the robot's data drive; those files are not cleaned up by any workflow in the project.
  Retention is unmanaged — flag it if your process adds to it.
