#Requires -Version 7.0
<#
.SYNOPSIS
    Builds a Config_<ENV>.xlsx from a tab-separated fixture file.

.DESCRIPTION
    Fixtures must be reviewable in a diff, so they store config as TSV and this builds the
    workbook at test time. Committing 60-odd binary .xlsx files would make the fixtures
    unreadable and unreviewable, which defeats the point of having them.

    Input format, one row per config key, tab-separated:

        Settings<TAB>OrchestratorQueueName<TAB>UC99_Fixture_Queue
        Constants<TAB>MaxConsecutiveSystemExceptions<TAB>3
        Assets<TAB>Mail_System_Exception_To<TAB>Email_Recipients_Error

    Blank lines and lines starting with '#' are ignored. A value may be empty (two tabs).

    All three sheets - Settings, Constants, Assets - are always created, each with a header
    row, even when no rows target them. That matters: validate-project's assets-empty rule
    distinguishes an EMPTY Assets sheet from a MISSING one, and config-parity compares key
    sets across the two workbooks.

    The writer is a deliberate near-copy of the one in
    templates/tools/build-template-workbooks.ps1 (inline strings, no sharedStrings). The two
    are kept separate on purpose: the templates' generator produces SHIPPED artifacts and must
    not be able to break when a test needs a different shape.
#>

function New-ConfigWorkbook {
    param(
        [Parameter(Mandatory)] [string] $TsvPath,
        [Parameter(Mandatory)] [string] $XlsxPath
    )

    Add-Type -AssemblyName System.IO.Compression | Out-Null

    $sheets = [ordered]@{ Settings = @(); Constants = @(); Assets = @() }

    foreach ($line in (Get-Content -LiteralPath $TsvPath)) {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        $parts = $line -split "`t"
        $sheet = $parts[0].Trim()
        if (-not $sheets.Contains($sheet)) {
            throw "$TsvPath : unknown sheet '$sheet' (expected Settings, Constants or Assets)"
        }
        $name = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $val = if ($parts.Count -gt 2) { $parts[2] } else { '' }
        $sheets[$sheet] += , @($name, $val, 'fixture row')
    }

    # Header first. Get-ConfigPairs in validate-project skips row 1 when column A is
    # 'Name' or 'Asset', so the header must be one of those or the first key is swallowed.
    $withHeaders = [ordered]@{}
    foreach ($s in $sheets.Keys) {
        $withHeaders[$s] = @(, @('Name', 'Value', 'Description')) + $sheets[$s]
    }

    Write-Xlsx -Path $XlsxPath -Sheets $withHeaders
}

function ConvertTo-FixtureXmlText([string] $Value) {
    if ($null -eq $Value) { return '' }
    $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

function Get-FixtureColumnName([int] $Index) {
    $name = ''
    while ($Index -gt 0) {
        $rem = ($Index - 1) % 26
        $name = [char]([int][char]'A' + $rem) + $name
        $Index = [int](($Index - $rem - 1) / 26)
    }
    $name
}

function Write-Xlsx {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [System.Collections.Specialized.OrderedDictionary] $Sheets
    )

    $names = @($Sheets.Keys)
    $parts = [ordered]@{}

    $ctOverrides = (1..$names.Count | ForEach-Object {
            "<Override PartName=`"/xl/worksheets/sheet$_.xml`" ContentType=`"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml`"/>"
        }) -join ''

    $parts['[Content_Types].xml'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
$ctOverrides
</Types>
"@

    $parts['_rels/.rels'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
"@

    $sheetTags = (0..($names.Count - 1) | ForEach-Object {
            $i = $_ + 1
            "<sheet name=`"$(ConvertTo-FixtureXmlText $names[$_])`" sheetId=`"$i`" r:id=`"rId$i`"/>"
        }) -join ''

    $parts['xl/workbook.xml'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>$sheetTags</sheets>
</workbook>
"@

    $rels = (1..$names.Count | ForEach-Object {
            "<Relationship Id=`"rId$_`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet`" Target=`"worksheets/sheet$_.xml`"/>"
        }) -join ''

    $parts['xl/_rels/workbook.xml.rels'] = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
$rels
</Relationships>
"@

    $n = 0
    foreach ($sheetName in $names) {
        $n++
        $rows = @($Sheets[$sheetName])
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        [void]$sb.AppendLine('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
        [void]$sb.AppendLine('<sheetData>')
        for ($r = 0; $r -lt $rows.Count; $r++) {
            $rowNum = $r + 1
            [void]$sb.Append("<row r=`"$rowNum`">")
            $cells = @($rows[$r])
            for ($c = 0; $c -lt $cells.Count; $c++) {
                $val = [string]$cells[$c]
                if ([string]::IsNullOrEmpty($val)) { continue }
                $ref = (Get-FixtureColumnName ($c + 1)) + $rowNum
                [void]$sb.Append("<c r=`"$ref`" t=`"inlineStr`"><is><t xml:space=`"preserve`">$(ConvertTo-FixtureXmlText $val)</t></is></c>")
            }
            [void]$sb.AppendLine('</row>')
        }
        [void]$sb.AppendLine('</sheetData>')
        [void]$sb.AppendLine('</worksheet>')
        $parts["xl/worksheets/sheet$n.xml"] = $sb.ToString()
    }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }

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
}
