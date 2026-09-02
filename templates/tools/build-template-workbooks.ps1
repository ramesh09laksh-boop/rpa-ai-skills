#Requires -Version 7.0
<#
.SYNOPSIS
    Regenerates the Config_TST.xlsx / Config_PRD.xlsx / Tests.xlsx shipped with the three
    REFramework templates under templates/.

.DESCRIPTION
    The workbooks are binary, so this script is their source of truth: edit the row data
    below, re-run, and the .xlsx files plus their diffable Markdown renderings are rewritten.
    Do not hand-edit the generated .xlsx in Excel and expect the change to survive — it will
    be overwritten the next time anyone runs this.

    Sheet names and column headers are not invented; they were read out of
    ../Avaloq/TKB-UC11.Kreditverletzung/Data/Config_TST.xlsx and
    ../Finnova/UC39_BPO_manuelle_Boersenauftraege/Tests/Tests.xlsx, which is what
    Framework/InitAllSettings.xaml and Tests/RunAllTests.xaml actually read.
    (Both sample projects live one level above this repo — see AGENTS.md.)

.EXAMPLE
    pwsh -File templates/tools/build-template-workbooks.ps1
#>
[CmdletBinding()]
param(
    [string] $TemplatesRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression | Out-Null

$TODO = '[UC-SPECIFIC — replace]'

# ---------------------------------------------------------------------------
# OOXML writer. Minimal SpreadsheetML with inline strings — no sharedStrings,
# no theme, no printer settings. Opens in Excel and reads cleanly through
# UiPath's Excel activities.
# ---------------------------------------------------------------------------

function ConvertTo-XmlText([string] $Value) {
    if ($null -eq $Value) { return '' }
    $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

function Get-ColumnName([int] $Index) {
    # 1 -> A, 26 -> Z, 27 -> AA
    $name = ''
    while ($Index -gt 0) {
        $rem = ($Index - 1) % 26
        $name = [char]([int][char]'A' + $rem) + $name
        $Index = [int](($Index - $rem - 1) / 26)
    }
    $name
}

function New-SheetXml([object[]] $Rows) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.AppendLine('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    [void]$sb.AppendLine('<sheetData>')
    for ($r = 0; $r -lt $Rows.Count; $r++) {
        $rowNum = $r + 1
        [void]$sb.Append("<row r=""$rowNum"">")
        $cells = @($Rows[$r])
        for ($c = 0; $c -lt $cells.Count; $c++) {
            $val = [string]$cells[$c]
            if ([string]::IsNullOrEmpty($val)) { continue }   # skip blanks entirely
            $ref = (Get-ColumnName ($c + 1)) + $rowNum
            $style = if ($rowNum -eq 1) { ' s="1"' } else { '' }
            [void]$sb.Append("<c r=""$ref""$style t=""inlineStr""><is><t xml:space=""preserve"">$(ConvertTo-XmlText $val)</t></is></c>")
        }
        [void]$sb.AppendLine('</row>')
    }
    [void]$sb.AppendLine('</sheetData>')
    [void]$sb.AppendLine('</worksheet>')
    $sb.ToString()
}

function New-Xlsx {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Sheets
    )

    $parts = [ordered]@{}
    $names = @($Sheets.Keys)

    $ctOverrides = ($names | ForEach-Object -Begin { $i = 0 } -Process {
            $i++
            "<Override PartName=""/xl/worksheets/sheet$i.xml"" ContentType=""application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml""/>"
        }) -join ''

    $parts['[Content_Types].xml'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
$ctOverrides
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>
"@

    $parts['_rels/.rels'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
"@

    $sheetTags = ($names | ForEach-Object -Begin { $i = 0 } -Process {
            $i++
            "<sheet name=""$(ConvertTo-XmlText $_)"" sheetId=""$i"" r:id=""rId$i""/>"
        }) -join ''

    $parts['xl/workbook.xml'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>$sheetTags</sheets>
</workbook>
"@

    $rels = ($names | ForEach-Object -Begin { $i = 0 } -Process {
            $i++
            "<Relationship Id=""rId$i"" Type=""http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"" Target=""worksheets/sheet$i.xml""/>"
        }) -join ''
    $styleRelId = 'rId' + ($names.Count + 1)

    $parts['xl/_rels/workbook.xml.rels'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
$rels
<Relationship Id="$styleRelId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@

    # Two cell formats: 0 = default, 1 = bold (header row).
    $parts['xl/styles.xml'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
"@

    $i = 0
    foreach ($name in $names) {
        $i++
        $parts["xl/worksheets/sheet$i.xml"] = New-SheetXml -Rows $Sheets[$name]
    }

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $Path) { Remove-Item -LiteralPath $Path -Force }

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    try {
        $zip = [System.IO.Compression.ZipArchive]::new($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($entryName in $parts.Keys) {
                $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
                $stream = $entry.Open()
                try {
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($parts[$entryName])
                    $stream.Write($bytes, 0, $bytes.Length)
                }
                finally { $stream.Dispose() }
            }
        }
        finally { $zip.Dispose() }
    }
    finally { $fs.Dispose() }

    Write-Host "  wrote $(Resolve-Path -Relative $Path)"
}

function Write-ContentsMarkdown {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Intro,
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Sheets
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# $Title")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('<!-- GENERATED by templates/tools/build-template-workbooks.ps1 — do not edit by hand. -->')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($Intro)
    [void]$sb.AppendLine()

    # Placeholders like <TOWER> and <Application> are swallowed as HTML tags if they reach a
    # Markdown renderer raw, so escape them. Pipes would break the table.
    function Format-Cell([string] $Value) {
        if ([string]::IsNullOrEmpty($Value)) { return '*(empty)*' }
        $Value.Replace('|', '\|').Replace('<', '&lt;').Replace('>', '&gt;')
    }

    foreach ($name in $Sheets.Keys) {
        $rows = @($Sheets[$name])
        [void]$sb.AppendLine('## `' + $name + '` sheet')
        [void]$sb.AppendLine()
        $header = @($rows[0])
        $width = $header.Count
        [void]$sb.AppendLine('| ' + (($header | ForEach-Object { Format-Cell $_ }) -join ' | ') + ' |')
        [void]$sb.AppendLine('|' + ('---|' * $width))
        $dataRows = @(if ($rows.Count -gt 1) { $rows[1..($rows.Count - 1)] })
        foreach ($row in $dataRows) {
            $cells = @($row)
            $padded = for ($c = 0; $c -lt $width; $c++) {
                Format-Cell $(if ($c -lt $cells.Count) { [string]$cells[$c] } else { '' })
            }
            [void]$sb.AppendLine('| ' + ($padded -join ' | ') + ' |')
        }
        [void]$sb.AppendLine()
        if ($dataRows.Count -eq 0) {
            [void]$sb.AppendLine('Header row only — the rows are written by the test run.')
            [void]$sb.AppendLine()
        }
    }

    [System.IO.File]::WriteAllText($Path, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host "  wrote $(Resolve-Path -Relative $Path)"
}

# ---------------------------------------------------------------------------
# Row data
# ---------------------------------------------------------------------------

$settingsHeader = @('Name', 'Value', 'Description')
$constantsHeader = @('Name', 'Value', 'Description')
$assetsHeader = @('Name', 'Asset', 'OrchestratorAssetFolder', 'Description (Assets will always overwrite other config)')

# Settings every template ships. OrchestratorQueueName is the Dispatcher/Performer pairing
# point — see templates/README.md.
$commonSettings = @(
    @('OrchestratorQueueName', $TODO,
        'Orchestrator queue name. The value must match the queue name defined on Orchestrator, AND must be byte-identical in the paired Dispatcher and Performer. A mismatch here fails silently: the Dispatcher enqueues, the Performer finds nothing and reports a clean run.'),
    @('OrchestratorQueueFolder', '',
        'Folder name. The value must match a folder defined in Orchestrator and the queue named in OrchestratorQueueName must be created in that folder. For classic folders leave the value empty.'),
    @('logF_BusinessProcessName', $TODO,
        'Logging field which allows grouping of log data of two or more subprocesses under the same business process name. Set the Dispatcher and Performer of a pair to the SAME value so both halves group together in Orchestrator logs.')
)

# Sane exception-handling defaults. The comments in the Description column are the reason a
# reviewer should push back if someone changes them.
$commonConstants = @(
    @('MaxRetryNumber', '0',
        'Must be 0 when working with Orchestrator queues — retries belong on the queue definition, not here. If > 0, the robot retries the same transaction after a system exception. Must be an integer.'),
    @('MaxConsecutiveSystemExceptions', '3',
        'The number of consecutive system exceptions allowed before the job stops. Setting this to 0 DISABLES the guard and lets a broken environment be hammered for the length of the queue — do not ship 0. Must be an integer.'),
    @('ShouldMarkJobAsFaulted', 'True',
        'Must be TRUE or FALSE. TRUE = an error in the Initialization state, or reaching MaxConsecutiveSystemExceptions, marks the Orchestrator job as Faulted. Keep TRUE; FALSE makes a job that processed nothing look green.'),
    @('RetryNumberGetTransactionItem', '2',
        'The number of times Get Transaction Item is retried after an exception. Must be an integer >= 1.'),
    @('RetryNumberSetTransactionStatus', '2',
        'The number of times Set Transaction Status is retried after an exception. Must be an integer >= 1.'),
    @('ExScreenshotsFolderPath', 'Exceptions_Screenshots',
        'Where to save exception screenshots — can be a full or a relative path.'),
    @('ExceptionMessage_ConsecutiveErrors', 'The maximum number of consecutive system exceptions was reached.',
        'Error message used when MaxConsecutiveSystemExceptions is reached.'),
    @('LogMessage_GetTransactionData', 'Processing Transaction Number: ',
        'Static part of logging message. Calling Get Transaction Data.'),
    @('LogMessage_GetTransactionDataError', 'Error getting transaction data for Transaction Number: ',
        'Static part of logging message. Error retrieving Transaction Data.'),
    @('LogMessage_Success', 'Transaction Successful.',
        'Static part of logging message. Processed Transaction successful.'),
    @('LogMessage_BusinessRuleException', 'Business rule exception.',
        'Static part of logging message. Processed Transaction failed with business exception.'),
    @('LogMessage_ApplicationException', 'System exception.',
        'Static part of logging message. Processed Transaction failed with application exception.')
)

# Every template ships the exception-mail asset row; a process with no route for its own
# failures is not shippable.
# Note the leading comma: without it PowerShell flattens a single-row array into four loose
# strings and the row lands one cell per spreadsheet row.
$mailAssetRows = @(, @('Mail_System_Exception_To', $TODO, '',
        'Text asset — recipients of the exception mail. Wire to a real Orchestrator Text asset; see .claude/skills/security/references/orchestrator-assets.md.')
)

$templates = [ordered]@{

    'REFramework-Dispatcher-Base' = @{
        ExtraSettings = @(, @('Dispatcher_Source_Path', $TODO,
                'Where the Dispatcher reads its upstream source from (mailbox folder, share path, report name, …). Replace with the concrete source for this UC.')
        )
        Assets        = @(, @('Source_System_Credential', $TODO, '',
                "Credential asset for the system the Dispatcher reads its source from. ONE ROW PER AUTHENTICATED APPLICATION — duplicate this row if the Dispatcher signs in to more than one, and rename the Name column to <Application>_System_Credential. If the Dispatcher reads an unauthenticated source (a share the robot already has rights to), DELETE this row rather than leaving it as $TODO.")
        ) + $mailAssetRows
        ConfigIntro   = @'
The Dispatcher reads an upstream source, applies the selection rule, and enqueues. It talks
to neither Finnova nor Avaloq, so it carries no library-specific keys — only the queue it
writes to and whatever credential its source needs.
'@
    }

    'REFramework-Performer-Finnova' = @{
        ExtraSettings = @(, @('Finnova_System_Win_Title_<TOWER>', $TODO,
                'Finnova window title for one tower. Add ONE ROW PER TOWER the process serves (ENT, ESP, ZGKB, PBS, NOVUS) — the workflow builds the key as "Finnova_System_Win_Title_" + in_TOWER, so a missing tower row is a runtime KeyNotFound, not a startup error.')
        )
        Assets        = @(
            @('Finnova_System_Launch_Cmd_<TOWER>', $TODO, '',
                'Text asset — the command that starts the Finnova Java client for one tower. One row per tower; the key is built by concatenation with in_TOWER.'),
            @('Finnova_System_PHI_Account_Name_<TOWER>', $TODO, '',
                'Text asset — the CyberArk object name for this tower (e.g. Bposecbot@FinnovaEntris). The object name is an identifier, not a secret. One row per tower.'),
            @('Finnova_System_Credential_<TOWER>', $TODO, '',
                'Credential asset for the Finnova login. Estate convention: name the Orchestrator credential after the CyberArk vault object it mirrors, so switching between Get Credential and Get PHI Vault stays a config change. One row per tower.')
        ) + $mailAssetRows
        ConfigIntro   = @'
Performer for the Finnova Java thin client. The `<TOWER>` rows are placeholders for a naming
pattern, not literal keys — the workflows build the key by concatenating the tower code onto
the prefix, so each tower the process serves needs its own row.
'@
    }

    'REFramework-Performer-Avaloq' = @{
        ExtraSettings = @()
        Assets        = @(
            @('Avaloq_System_Client_Path', 'Avaloq_SmartClient_Path', '',
                'Text asset — smartclient.exe launch path. Config key and asset name differ deliberately; the indirection lets one code base bind to differently-named assets per tenant.'),
            @('Avaloq_System_Client_Arguments', 'Avaloq_SmartClient_Arguments', '',
                'Text asset — integration server and DB coordinates passed to smartclient.exe.'),
            @('Avaloq_System_Credentials', $TODO, '',
                'Credential asset for the Smart Client login. NOTE: TKB-UC11 spells this key Avaloq_System_Credendials (sic) and its workflows match that typo. Do not copy the typo into a new project — but if you lift a workflow from TKB-UC11, fix the key and the workflow together or not at all.')
        ) + $mailAssetRows
        ConfigIntro   = @'
Performer for the Avaloq Smart Client. Client path and launch arguments come from Orchestrator
Text assets so a tenant or environment move is a config change, not a redeploy.
'@
    }
}

$testsHeader = @('WorkflowFile', 'ExpectedResult')
$testRows = @(
    @("$TODO — e.g. Framework\InitAllSettings.xaml", 'Success'),
    @("$TODO — e.g. Tests\Test-<Application>_Login.xaml", 'Success'),
    @("$TODO — e.g. Tests\Test-<Application>_Login_BadCredentials.xaml", 'SystemException')
)
$resultHeader = @('WorkflowFile', 'ExpectedResult', 'Status', 'Comments')

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

foreach ($templateName in $templates.Keys) {
    $spec = $templates[$templateName]
    $root = Join-Path $TemplatesRoot $templateName
    Write-Host "$templateName"

    $configSheets = [ordered]@{
        'Settings'  = @(, $settingsHeader) + $commonSettings + $spec.ExtraSettings
        'Constants' = @(, $constantsHeader) + $commonConstants
        'Assets'    = @(, $assetsHeader) + $spec.Assets
    }

    foreach ($env in @('TST', 'PRD')) {
        New-Xlsx -Path (Join-Path $root "Data\Config_$env.xlsx") -Sheets $configSheets
    }

    Write-ContentsMarkdown `
        -Path (Join-Path $root 'Data\config-contents.md') `
        -Title 'Config_TST.xlsx / Config_PRD.xlsx contents' `
        -Intro ($spec.ConfigIntro.Trim() + "`n`nBoth workbooks ship identical rows. That is deliberate: a key must exist in TST and PRD from`nthe first commit, or the PRD run fails on a key only TST has. Fill the values per environment;`nnever let the two sheets diverge in their key set.") `
        -Sheets $configSheets

    $testSheets = [ordered]@{
        'Tests'  = @(, $testsHeader) + $testRows
        'Result' = @(, $resultHeader)
    }
    New-Xlsx -Path (Join-Path $root 'Tests\Tests.xlsx') -Sheets $testSheets

    Write-ContentsMarkdown `
        -Path (Join-Path $root 'Tests\tests-contents.md') `
        -Title 'Tests.xlsx contents' `
        -Intro "Driven by Tests\RunAllTests.xaml. Every row below is a placeholder — the suite does not`npass as shipped and is not meant to. Replace all three rows with real workflows before UAT;`nan unreplaced ``$TODO`` row is a review finding." `
        -Sheets $testSheets
}

Write-Host ''
Write-Host 'Done.'
