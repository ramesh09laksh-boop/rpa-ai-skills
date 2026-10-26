#Requires -Version 7.0
<#
.SYNOPSIS
    Conformance checker for a UiPath REFramework project instantiated from templates/.

.DESCRIPTION
    templates/README.md says an unreplaced [UC-SPECIFIC - replace] marker is a review finding,
    "the same way an unresolved TODO_SELECTOR is". This script is what actually finds them.

    Every rule here exists because the failure it catches is SILENT: the job runs, reports
    green, and does nothing or the wrong thing. A stock OrchestratorQueueName means the
    Performer polls a queue nobody fills. MaxConsecutiveSystemExceptions = 0 means a broken
    environment gets hammered for the length of the queue. ShouldMarkJobAsFaulted = False means
    a job that processed nothing looks successful in Orchestrator.

    No UiPath dependency: project.json and entry-points.json are JSON, the workbooks are OOXML
    read through System.IO.Compression, and the workflows are XML. Runs anywhere pwsh 7 does.

.PARAMETER ProjectPath
    One or more project folders (the folder holding project.json). Pass a Dispatcher and its
    Performer together to enable the cross-project queue-name check.

.PARAMETER WarningsAsErrors
    Treat warnings as errors for the exit code. Use in CI once a project is clean.

.OUTPUTS
    One line per finding. Exit code 0 when no errors, 1 otherwise.

.EXAMPLE
    pwsh -File validate-project.ps1 ./UC252_SRDII_Tresor_Dispatch

.EXAMPLE
    pwsh -File validate-project.ps1 ./UC81_Dispatcher ./UC81_Performer -WarningsAsErrors
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
    [string[]] $ProjectPath,

    [switch] $WarningsAsErrors,

    # Suppress a rule everywhere. Prefer a per-project validate-project.ignore file, which
    # forces a written reason and keeps the exception on screen.
    [string[]] $SkipRule = @(),

    # For checking templates/ itself, in CI. The templates SHIP their placeholders on purpose -
    # "<PROJECT-NAME-TBD-ask-team>", "[UC-SPECIFIC - replace]", the un-regenerated template
    # GUIDs - so template-default-left and name-no-whitespace fire on every one of them by
    # design. In this mode those two are reported as 'expected' and do not fail the run, while
    # every other rule still does. An EMPTY expected list is itself a failure: it means the
    # tripwires have gone missing from the templates.
    #
    # Never pass this for a real UC project. The whole point of those rules is that a
    # half-instantiated project cannot pass for a finished one.
    [switch] $TemplateMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$script:Findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param(
        [ValidateSet('error', 'warning')] [string] $Severity,
        [string] $Rule,
        [string] $Project,
        [string] $Message
    )
    $script:Findings.Add([pscustomobject]@{
            Severity = $Severity; Rule = $Rule; Project = $Project; Message = $Message
        })
}

# ---------------------------------------------------------------------------
# Minimal OOXML reader. Handles BOTH cell encodings that turn up in practice:
# inline strings (what templates/tools/build-template-workbooks.ps1 emits) and
# sharedStrings (what Excel and openpyxl emit). Getting only one of them right
# makes the checker pass on templates and silently skip real projects.
# ---------------------------------------------------------------------------
function Read-Workbook {
    param([string] $Path)

    # StrictMode off for this function only (it is dynamically scoped and reverts on exit).
    # XmlElement dot-access throws under StrictMode whenever the child element is absent, and
    # an optional child is the normal case in SpreadsheetML - <c> has no t on a numeric cell,
    # <si> has no t when it is a run of <r> fragments. Guarding every access would triple the
    # size of the reader for no safety gain; the rules below stay strict.
    Set-StrictMode -Off

    $sheets = @{}
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        function Get-EntryXml([string] $name) {
            $e = $zip.Entries | Where-Object FullName -eq $name
            if (-not $e) { return $null }
            $sr = [System.IO.StreamReader]::new($e.Open())
            try { [xml] $sr.ReadToEnd() } finally { $sr.Dispose() }
        }

        $shared = @()
        $ssXml = Get-EntryXml 'xl/sharedStrings.xml'
        if ($ssXml) {
            foreach ($si in $ssXml.sst.si) {
                # <si> is either <t>text</t> or a run of <r><t>..</t></r> fragments
                if ($si.t -is [string]) { $shared += $si.t }
                elseif ($si.t) { $shared += ($si.t | ForEach-Object { $_.'#text' }) -join '' }
                elseif ($si.r) { $shared += ($si.r.t | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.'#text' } }) -join '' }
                else { $shared += '' }
            }
        }

        $wbXml = Get-EntryXml 'xl/workbook.xml'
        if (-not $wbXml) { return $sheets }
        $relsXml = Get-EntryXml 'xl/_rels/workbook.xml.rels'

        $i = 0
        foreach ($sheet in $wbXml.workbook.sheets.sheet) {
            $i++
            $target = $null
            if ($relsXml) {
                $rid = $sheet.id
                if (-not $rid) { $rid = $sheet.Attributes['r:id'].Value }
                $rel = $relsXml.Relationships.Relationship | Where-Object Id -eq $rid
                if ($rel) { $target = $rel.Target -replace '^/xl/', '' -replace '^\.\./', '' }
            }
            if (-not $target) { $target = "worksheets/sheet$i.xml" }
            $sheetXml = Get-EntryXml "xl/$target"
            if (-not $sheetXml) { continue }

            $rows = [System.Collections.Generic.List[object]]::new()
            foreach ($row in $sheetXml.worksheet.sheetData.row) {
                $cells = @{}
                foreach ($c in $row.c) {
                    $ref = $c.r -replace '\d', ''
                    $type = $c.t
                    $val = $null
                    if ($type -eq 's') {
                        $idx = [int] $c.v
                        if ($idx -lt $shared.Count) { $val = $shared[$idx] }
                    }
                    elseif ($type -eq 'inlineStr') { $val = $c.is.t }
                    elseif ($type -eq 'b') { $val = if ($c.v -eq '1') { 'True' } else { 'False' } }
                    else { $val = $c.v }
                    if ($val -is [System.Xml.XmlElement]) { $val = $val.'#text' }
                    $cells[$ref] = $val
                }
                $rows.Add($cells)
            }
            $sheets[$sheet.name] = $rows
        }
    }
    finally { $zip.Dispose() }
    return $sheets
}

# A config sheet is Name | Value | Description. Returns an ordered name -> value map.
function Get-ConfigPairs {
    param($SheetRows)
    $map = [ordered]@{}
    if (-not $SheetRows) { return $map }
    $first = $true
    foreach ($row in $SheetRows) {
        $name = if ($row.Contains('A')) { $row['A'] } else { $null }
        if ($first) { $first = $false; if ($name -in @('Name', 'Asset')) { continue } }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $map[[string] $name] = if ($row.Contains('B')) { [string] $row['B'] } else { '' }
    }
    return $map
}

function Get-KeepFileName { '.gitkeep' }

# A project may carry validate-project.ignore:
#
#     # comments allowed
#     assets-empty: the Orchestrator assets do not exist yet - CR-1234
#
# A suppressed finding is still printed, with its reason, but does not fail the run. That is
# deliberate: a rule that can be switched off silently is a rule nobody can trust afterwards.
$script:Suppressions = @{}

function Read-Suppressions {
    param([string] $ProjectRoot, [string] $ProjectName)
    $path = Join-Path $ProjectRoot 'validate-project.ignore'
    $map = @{}
    if (Test-Path $path) {
        $lastRule = $null
        foreach ($line in (Get-Content -LiteralPath $path)) {
            if (-not $line.Trim() -or $line.Trim().StartsWith('#')) { continue }

            # An indented line continues the previous reason, so a reason can be written as a
            # readable paragraph instead of one enormous line.
            if ($line -match '^\s' -and $lastRule) {
                $map[$lastRule] = ($map[$lastRule] + ' ' + $line.Trim()).Trim()
                continue
            }

            $parts = $line.Trim() -split ':', 2
            $rule = $parts[0].Trim()
            $reason = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
            if (-not $reason) {
                Add-Finding warning 'suppression-without-reason' $ProjectName `
                    "validate-project.ignore suppresses '$rule' with no reason after the colon"
                $lastRule = $null
                continue
            }
            $map[$rule] = $reason
            $lastRule = $rule
        }
    }
    $script:Suppressions[$ProjectName] = $map
}

# ---------------------------------------------------------------------------
# Per-project rules
# ---------------------------------------------------------------------------
function Test-Project {
    param([string] $Path)

    $abs = (Resolve-Path -LiteralPath $Path).Path
    $name = Split-Path -Leaf $abs
    $projJsonPath = Join-Path $abs 'project.json'

    if (-not (Test-Path $projJsonPath)) {
        Add-Finding error 'not-a-project' $name "no project.json in $abs"
        return $null
    }
    $proj = Get-Content -LiteralPath $projJsonPath -Raw | ConvertFrom-Json
    Read-Suppressions -ProjectRoot $abs -ProjectName $name

    # --- name-no-whitespace -------------------------------------------------
    if ($proj.name -match '\s') {
        Add-Finding error 'name-no-whitespace' $name `
            "project.json name '$($proj.name)' contains whitespace - the package id derives from it"
    }
    if ($proj.name -ne $name) {
        Add-Finding warning 'name-no-whitespace' $name `
            "project.json name '$($proj.name)' does not match the folder name '$name'"
    }
    $uiprojPath = Join-Path $abs 'project.uiproj'
    if (Test-Path $uiprojPath) {
        $uiproj = Get-Content -LiteralPath $uiprojPath -Raw | ConvertFrom-Json
        if ($uiproj.Name -ne $proj.name) {
            Add-Finding error 'name-no-whitespace' $name `
                "project.uiproj Name '$($uiproj.Name)' disagrees with project.json name '$($proj.name)'"
        }
    }

    # --- target-framework ---------------------------------------------------
    if ($proj.targetFramework -ne 'Windows') {
        Add-Finding error 'target-framework' $name `
            "targetFramework is '$($proj.targetFramework)', expected 'Windows' (not 'Windows - Legacy')"
    }
    if (-not $proj.designOptions.modernBehavior) {
        Add-Finding error 'target-framework' $name 'designOptions.modernBehavior must be true'
    }

    # --- unattended-contradiction ------------------------------------------
    if ((-not $proj.runtimeOptions.isAttended) -and $proj.runtimeOptions.requiresUserInteraction) {
        Add-Finding error 'unattended-contradiction' $name `
            'isAttended false with requiresUserInteraction true - an unattended job will block on a dialog nobody sees'
    }

    # --- template-default-left (project.json) ------------------------------
    if ($proj.name -like '*PROJECT-NAME-TBD*') {
        Add-Finding error 'template-default-left' $name "project.json still ships the template name '$($proj.name)'"
    }
    foreach ($guid in @('626d7f84-ac42-45be-be60-f096f1cc0332',
                        '52654669-fea5-4a67-a77e-9ae69b3b8dcb')) {
        if ((Get-Content -LiteralPath $projJsonPath -Raw) -like "*$guid*") {
            Add-Finding error 'template-default-left' $name `
                "template GUID $guid was never regenerated - two projects sharing a projectId confuse Orchestrator"
        }
    }

    # --- missing-gitignore --------------------------------------------------
    if (-not (Test-Path (Join-Path $abs '.gitignore'))) {
        Add-Finding warning 'missing-gitignore' $name `
            'no .gitignore - Studio local state and Exceptions_Screenshots (logged-in banking sessions) will be committed'
    }

    # --- run-output-clean ---------------------------------------------------
    $keep = Get-KeepFileName
    foreach ($rel in @('Data/Output', 'Data/Temp', 'Exceptions_Screenshots')) {
        $dir = Join-Path $abs $rel
        if (-not (Test-Path $dir)) { continue }
        $stray = @(Get-ChildItem -LiteralPath $dir -Force | Where-Object Name -ne $keep)
        if ($stray) {
            $sev = if ($rel -eq 'Exceptions_Screenshots') { 'error' } else { 'warning' }
            Add-Finding $sev 'run-output-clean' $name `
                "$rel holds $($stray.Count) file(s) besides $keep - e.g. $($stray[0].Name)"
        }
    }

    # --- config workbooks ---------------------------------------------------
    $cfg = @{}
    foreach ($env in @('TST', 'PRD')) {
        $p = Join-Path $abs "Data/Config_$env.xlsx"
        if (Test-Path $p) { $cfg[$env] = Read-Workbook $p }
        else { Add-Finding error 'config-parity' $name "Data/Config_$env.xlsx is missing" }
    }

    $settings = @{}
    foreach ($env in $cfg.Keys) {
        $sheets = $cfg[$env]
        $all = [ordered]@{}
        foreach ($sheetName in @('Settings', 'Constants', 'Assets')) {
            if ($sheets.Contains($sheetName)) {
                foreach ($kv in (Get-ConfigPairs $sheets[$sheetName]).GetEnumerator()) {
                    $all["$sheetName|$($kv.Key)"] = $kv.Value
                }
            }
        }
        $settings[$env] = $all
    }

    # --- config-parity ------------------------------------------------------
    if ($settings.Count -eq 2) {
        $tst = $settings['TST'].Keys
        $prd = $settings['PRD'].Keys
        $only = @($tst | Where-Object { $_ -notin $prd }) + @($prd | Where-Object { $_ -notin $tst })

        # Split by sheet. Assets are the one place where a legitimate project can sit
        # asymmetric for a while - the Orchestrator asset simply does not exist in that
        # environment yet - and lumping it in with Settings would mean suppressing all three.
        $assetsOnly = @($only | Where-Object { $_ -like 'Assets|*' })
        $rest = @($only | Where-Object { $_ -notlike 'Assets|*' })

        if ($rest) {
            Add-Finding error 'config-parity' $name `
                "Config_TST and Config_PRD key sets differ: $($rest -join ', ')"
        }
        if ($assetsOnly) {
            Add-Finding error 'assets-parity' $name `
                ("Assets rows differ between Config_TST and Config_PRD: $($assetsOnly -join ', '). " +
                 'Every environment needs the same keys even when the asset values differ. If the ' +
                 'Orchestrator assets genuinely do not exist yet, record that in ' +
                 'validate-project.ignore rather than leaving the sheets out of step silently.')
        }
    }

    # --- value-driven rules -------------------------------------------------
    foreach ($env in $settings.Keys) {
        foreach ($kv in $settings[$env].GetEnumerator()) {
            $key = ($kv.Key -split '\|')[-1]
            $val = [string] $kv.Value

            if ($val -match '\[UC-SPECIFIC') {
                Add-Finding error 'template-default-left' $name "$env $key is still '[UC-SPECIFIC - replace]'"
            }
            switch ($key) {
                'OrchestratorQueueName' {
                    if ($val -eq 'ProcessABCQueue') {
                        Add-Finding error 'template-default-left' $name `
                            "$env OrchestratorQueueName is the stock 'ProcessABCQueue' - the Performer will poll a queue nobody fills"
                    }
                }
                'logF_BusinessProcessName' {
                    if ($val -eq 'Framework') {
                        Add-Finding error 'template-default-left' $name `
                            "$env logF_BusinessProcessName is the stock 'Framework' - logs will not group by business process"
                    }
                }
                'MaxConsecutiveSystemExceptions' {
                    if ($val -eq '0') {
                        Add-Finding error 'circuit-breaker-disabled' $name `
                            "$env MaxConsecutiveSystemExceptions = 0 disables the circuit breaker"
                    }
                }
                'ShouldMarkJobAsFaulted' {
                    if ($val -match '^(?i)false$') {
                        Add-Finding error 'silent-failure' $name `
                            "$env ShouldMarkJobAsFaulted = False - a job that processed nothing reports green"
                    }
                }
            }

            # --- relative-persisted-path (added: cost a whole audit trail in UC252) ---
            if ($val -match '^[A-Za-z0-9_.\- ]+\\[^\\].*\.(xlsx|xls|csv|json|txt)$') {
                Add-Finding warning 'relative-persisted-path' $name `
                    ("$env $key = '$val' is a RELATIVE path. At runtime the working directory is the " +
                     'extracted package (%USERPROFILE%\.nuget\packages\<id>\<ver>\content\), NOT the ' +
                     'project folder - so a file written there is discarded with the next version. ' +
                     'Confirm the workflow combines this with a root key; if it passes the value ' +
                     'straight to an Excel activity, anything it writes is lost.')
            }
        }
    }

    # --- assets-empty -------------------------------------------------------
    $bankingLib = $false
    if ($proj.dependencies) {
        foreach ($d in $proj.dependencies.PSObject.Properties.Name) {
            if ($d -match 'Finnova|Avaloq|Swisscom\.PHI') { $bankingLib = $true }
        }
    }
    if ($bankingLib -and $cfg.Contains('TST')) {
        $assets = Get-ConfigPairs $cfg['TST']['Assets']
        if ($assets.Count -eq 0) {
            Add-Finding error 'assets-empty' $name `
                ('project references a banking library but the Assets sheet is empty - the ' +
                 'credentials have to come from somewhere, and the alternatives are all worse. ' +
                 'Legitimate only while the Orchestrator assets are still being created; say so ' +
                 'in validate-project.ignore if that is the case.')
        }
    }

    # --- workflow-level rules ----------------------------------------------
    $xamls = @(Get-ChildItem -LiteralPath $abs -Filter *.xaml -Recurse -File |
        Where-Object FullName -notmatch '\\\.local\\')
    $selectorDocs = @(Get-ChildItem -LiteralPath $abs -Filter *.selectors-todo.md -Recurse -File -ErrorAction SilentlyContinue)

    $mainWired = $false
    $configRefs = @{}          # key name -> list of "file" strings that read it
    $configWrites = [System.Collections.Generic.HashSet[string]]::new()   # keys assigned at runtime
    foreach ($x in $xamls) {
        $text = Get-Content -LiteralPath $x.FullName -Raw
        $rel = $x.FullName.Substring($abs.Length).TrimStart('\', '/')

        # config-file-not-wired: the #1 guaranteed break for an instantiated template
        if ($x.Name -eq 'Main.xaml') {
            if ($text -match 'Data\\Config\.xlsx') {
                Add-Finding error 'config-file-not-wired' $name `
                    ('Main.xaml still passes the stock in_ConfigFile = "Data\Config.xlsx". No template ships ' +
                     'a Config.xlsx - Initialization will fail with file-not-found. Wire it to in_ENV; see ' +
                     'templates/README.md step 5.')
            }
            if ($text -match 'Config_' ) { $mainWired = $true }
        }

        # unresolved-todo
        if ($text -match 'TODO_SELECTOR|APPROX_SELECTOR') {
            $expected = [System.IO.Path]::ChangeExtension($x.FullName, $null).TrimEnd('.') + '.selectors-todo.md'
            if (-not ($selectorDocs | Where-Object FullName -eq $expected)) {
                Add-Finding warning 'unresolved-todo' $name `
                    "$rel has TODO_SELECTOR/APPROX_SELECTOR but no companion .selectors-todo.md"
            }
        }

        # unresolved-mock: a [MOCK] stand-in left in the project. Guidance alone is the weaker
        # form - the whole argument of this script is that a marker nobody greps for is
        # indistinguishable from finished work. Warning rather than error because a mock is
        # legitimate mid-build; it blocks review, not development.
        # See standards/references/mocking.md.
        if ($text -match '\[MOCK\]') {
            Add-Finding warning 'unresolved-mock' $name `
                ("$rel contains a [MOCK] stand-in. Legitimate mid-build, but a mocked run reaches " +
                 'L3 at most and an unreplaced [MOCK] blocks review - replace it and point the ' +
                 'config key at the real source.')
        }

        # classic-excel-write: broken on Windows/.NET 6, see standards/excel-activities.md
        if ($text -match '<ui:(AppendRange|WriteRange)\b') {
            Add-Finding error 'classic-excel-write' $name `
                ("$rel uses the classic ui:AppendRange/ui:WriteRange. On a Windows (.NET 6) project these " +
                 'throw "Error in implicit conversion. Cannot convert null object" at ' +
                 'WorkbookActivity.EndExecute while ReadRange on the same workbook works. Use the modern ' +
                 'ExcelProcessScopeX -> ExcelApplicationCard -> WriteRangeX (Append=True).')
        }

        # byref-out-arg: an expression cannot write back through an out parameter
        if ($text -match '(TryParse|TryGetValue)\([^"]*,\s*\w+\)\]') {
            Add-Finding error 'byref-out-arg' $name `
                ("$rel calls TryParse/TryGetValue inside an expression. The Boolean is correct but the " +
                 'out variable is never assigned - it keeps its default. Guard with IsDate(...) and assign separately.')
        }

        # xmlns declared but the assembly is never referenced -> UiRobot pack fails
        # with "Some references are not imported in current workflow", naming no file.
        # Only prefixes the body actually USES matter. A declared-but-unused xmlns is
        # generator boilerplate and harmless - projects full of them pack fine. The break is a
        # prefix that IS used while its assembly is missing from ReferencesForImplementation:
        # uip rpa validate passes clean and the UiRobot pack then fails with "Some references
        # are not imported in current workflow", naming no file.
        $headEnd = $text.IndexOf('>')
        if ($headEnd -lt 1) { $headEnd = [Math]::Min(4000, $text.Length) }
        $head = $text.Substring(0, $headEnd)
        $body = $text.Substring($headEnd)
        $referenced = @([regex]::Matches($text, '<AssemblyReference>([^<]+)</AssemblyReference>') |
            ForEach-Object { $_.Groups[1].Value })
        foreach ($m in [regex]::Matches($head, 'xmlns:(\w+)="clr-namespace:[^;"]*;assembly=([^"]+)"')) {
            $prefix = $m.Groups[1].Value
            $asm = $m.Groups[2].Value
            if ($asm -in $referenced) { continue }
            if ($body -notmatch "[<`"\s(]$prefix`:") { continue }   # declared but never used
            Add-Finding error 'xmlns-assembly-unreferenced' $name `
                "$rel uses the '$prefix`:' prefix (assembly '$asm') but never lists that assembly in ReferencesForImplementation"
        }

        # hardcoded-connection: belongs in config, per the security skill
        foreach ($m in [regex]::Matches($text, '(AssetName|Server|SharedMailbox)="([^"\[][^"]*)"')) {
            $prop = $m.Groups[1].Value; $lit = $m.Groups[2].Value
            if ($lit -match '^\{x:Null\}$' -or $lit.Length -lt 4) { continue }
            Add-Finding warning 'hardcoded-connection' $name `
                "$rel hardcodes $prop=`"$lit`" - read it from Config instead"
        }

        # negative-active-filter: let two footnote rows into UC252's bank list
        if ($text -match '&lt;&gt;\s*&quot;FALSE&quot;|<>\s*"FALSE"') {
            Add-Finding warning 'negative-active-filter' $name `
                ("$rel filters a business table with Active <> FALSE. Explanatory/footnote rows with a " +
                 'blank Active pass that test. Use = "TRUE".')
        }

        # config-key-undefined: collect every in_Config("Key") read in this file.
        # A key that is read but not defined returns Nothing from the Dictionary, the
        # expression evaluates to "" and the workflow carries on with an empty path, queue
        # name or timeout - no error, wrong behaviour. XAML stores the expression
        # HTML-encoded, so both quote forms have to match.
        $cfgKeyPattern = '(?:in_|io_|out_)?Config\(\s*(?:&quot;|")([^&"]+?)(?:&quot;|")\s*\)'
        foreach ($m in [regex]::Matches($text, $cfgKeyPattern)) {
            $k = $m.Groups[1].Value.Trim()
            if (-not $k) { continue }
            if (-not $configRefs.ContainsKey($k)) { $configRefs[$k] = [System.Collections.Generic.List[string]]::new() }
            if (-not $configRefs[$k].Contains($rel)) { $configRefs[$k].Add($rel) }
        }

        # A key can also be WRITTEN into the dictionary at runtime, which defines it just as
        # legitimately as a workbook row. Stock REFramework does exactly this for "ENV" in
        # Main.xaml:
        #     <Assign.To><OutArgument x:TypeArguments="x:Object">[Config("ENV")]</OutArgument>
        # Without this carve-out the rule reports ENV on every REFramework project in the
        # estate - verified against UC39, where it was the rule's only finding.
        foreach ($blk in [regex]::Matches($text, '(?s)<Assign\.To>(.*?)</Assign\.To>')) {
            foreach ($m in [regex]::Matches($blk.Groups[1].Value, $cfgKeyPattern)) {
                [void] $configWrites.Add($m.Groups[1].Value.Trim())
            }
        }
        # AddToCollection / InvokeMethod Add("Key", ...) against the Config dictionary
        foreach ($m in [regex]::Matches($text,
                '(?:in_|io_|out_)?Config\.Add\(\s*(?:&quot;|")([^&"]+?)(?:&quot;|")')) {
            [void] $configWrites.Add($m.Groups[1].Value.Trim())
        }

        # hardcoded-culture in a date parse
        if ($text -match 'New System\.Globalization\.CultureInfo\(&quot;[a-z]{2}-[A-Z]{2}&quot;\)') {
            Add-Finding warning 'hardcoded-culture' $name `
                ("$rel parses with a hardcoded CultureInfo. Excel cells stringify in the machine's culture; " +
                 'convert from the DataRow object or use InvariantCulture.')
        }

        # --- leaf-workflow contract (project-layout.md "Contract for a workflow in this
        # folder", and pdd-sdd-scaffolding "Scaffold shape") -------------------------------
        #
        # Scaffolded leaf workflows were breaking the estate's own _System contract while
        # looking entirely plausible: no in_Config, no out_ outcome, a password typed String.
        # None of that throws. The three rules below are deliberately WARNINGS - they are new,
        # and a new rule that fails a build on its first contact with a real project gets
        # switched off rather than fixed. Promote to error once a trial run across the estate
        # is clean.
        #
        # x:Members is the only declaration of a workflow's arguments:
        #   <x:Property Name="in_Config" Type="InArgument(scg:Dictionary(x:String, x:Object))" />
        $members = [regex]::Match($text, '<x:Members>(.*?)</x:Members>', 'Singleline')
        $props = @()
        if ($members.Success) {
            $props = @([regex]::Matches($members.Groups[1].Value,
                    '<x:Property\b[^>]*?Name="([^"]+)"[^>]*?Type="([^"]+)"') |
                ForEach-Object {
                    [pscustomobject]@{ ArgName = $_.Groups[1].Value; ArgType = $_.Groups[2].Value }
                })
            # Name= and Type= also occur in the other order
            $props += @([regex]::Matches($members.Groups[1].Value,
                    '<x:Property\b[^>]*?Type="([^"]+)"[^>]*?Name="([^"]+)"') |
                ForEach-Object {
                    [pscustomobject]@{ ArgName = $_.Groups[2].Value; ArgType = $_.Groups[1].Value }
                })
            $props = @($props | Sort-Object ArgName -Unique)
        }
        $argNames = @($props | ForEach-Object ArgName)

        # system-workflow-no-config: a _System workflow that cannot see Config has to get its
        # window titles, paths and timeouts from somewhere else - which means hardcoded.
        # '_'-prefixed files are developer scratchpads (project-layout.md), not deliverables -
        # the same carve-out the raw-selector rules give them.
        if ($rel -match '(^|[\\/])[A-Za-z0-9 _]+_System[\\/]' -and $props.Count -gt 0 -and
            $x.Name -notlike '_*') {
            if ('in_Config' -notin $argNames) {
                Add-Finding warning 'system-workflow-no-config' $name `
                    ("$rel is a _System workflow with no in_Config argument. project-layout.md's " +
                     'contract is in_Config + coordinates in, plain values out. Without it the window ' +
                     'title, timeouts and paths can only be hardcoded.')
            }
            if (-not ($argNames | Where-Object { $_ -like 'out_*' -or $_ -like 'io_*' })) {
                Add-Finding warning 'system-workflow-no-outcome' $name `
                    ("$rel is a _System workflow that returns nothing. A no-op is then " +
                     'indistinguishable from success to its caller. Return an out_ outcome ' +
                     '(out_Created, out_Moved, out_Status).')
            }
        }

        # secret-argument-string: a SecureString demoted to String. ST-SEC-009 calls the cast a
        # security breach, and the security skill forbids a plaintext secret crossing a
        # workflow boundary at all.
        #
        # The carve-out matters as much as the rule. An ASSET NAME is legitimately a String, and
        # this estate names those arguments after the credential: config-contents.md defines the
        # Assets key as <Application>_System_Credential, so 'Credential(s)' in an argument name
        # means the asset NAME here, not the secret. TKB-UC11's in_Avaloq_System_Credentials is
        # a String only because it feeds GetRobotCredential
        # AssetName="[in_Avaloq_System_Credentials]", while the secret stays in a local Password
        # variable. A rule that cries wolf on correct estate code is a rule nobody keeps on, so
        # 'credential' is excluded by name, and anything else used as an AssetName in this file
        # is excluded by use.
        foreach ($p in $props) {
            if ($p.ArgName -notmatch '(?i)(password|passwort|secret|pwd|apikey|api_key|token)') { continue }
            if ($p.ArgType -notmatch '\(\s*x:String\s*\)') { continue }
            if ($text -match ('AssetName="\[\s*' + [regex]::Escape($p.ArgName) + '\s*\]"')) { continue }
            Add-Finding warning 'secret-argument-string' $name `
                ("$rel declares $($p.ArgName) as String. A secret crosses a workflow boundary as " +
                 'SecureString or not at all - see the security skill, and analyzer rule ST-SEC-009. ' +
                 "(If it holds an Orchestrator asset NAME rather than the secret, pass it to " +
                 'GetRobotCredential/GetAsset AssetName so that is visible.)')
        }

        # logic-workflow-no-arguments: a Logic/ workflow with no arguments cannot be invoked
        # with anything, so the caller reimplements the rule inline and the two drift apart.
        if ($rel -match '(^|[\\/])Logic[\\/]' -and $x.Name -notlike '_*' -and $props.Count -eq 0) {
            Add-Finding warning 'logic-workflow-no-arguments' $name `
                ("$rel is a Logic/ workflow declaring no arguments. Nothing can be passed to it or " +
                 'returned from it, so callers duplicate the rule inline instead of invoking it.')
        }
    }

    if (@($xamls | Where-Object Name -eq 'Main.xaml').Count -gt 0) {
        if (-not $mainWired) {
            Add-Finding warning 'config-file-not-wired' $name `
                'Main.xaml never mentions a Config_<ENV> workbook - check that in_ConfigFile is wired to in_ENV'
        }
    }

    # --- config-key-undefined -----------------------------------------------
    # Compare what the workflows READ against what the workbooks DEFINE. Checked against TST
    # because config-parity already enforces that PRD carries the same key set, so a key
    # missing from both is reported once here rather than twice.
    if ($configRefs.Count -gt 0 -and $settings.Contains('TST')) {
        # $settings[env] keys are "SheetName|KeyName"; the sheet does not matter here because
        # InitAllSettings merges all three into one Dictionary.
        $defined = @($settings['TST'].Keys | ForEach-Object { ($_ -split '\|', 2)[1] })
        foreach ($k in ($configRefs.Keys | Sort-Object)) {
            if ($k -in $defined) { continue }
            if ($configWrites.Contains($k)) { continue }   # assigned at runtime, not a workbook row
            $where = $configRefs[$k] -join ', '
            Add-Finding error 'config-key-undefined' $name `
                ("$where reads in_Config(`"$k`") but no Settings/Constants/Assets row defines " +
                 "'$k'. A missing key returns Nothing, the expression becomes an empty string, " +
                 'and the run continues with an empty path/queue/timeout - no error, wrong behaviour.')
        }
    }

    # --- object-repository-not-shared ---------------------------------------
    # A workflow binding to an Object Repository target carries only a reference; the
    # descriptor itself lives in .objects/. If that folder is missing, empty or git-ignored,
    # the project's selectors do not travel - a clone gets the workflows and resolves every
    # target to nothing. Found in a real project: 134 files under .objects/, zero tracked,
    # ignored by a '.objects/' line inherited from this repo's own templates.
    $usesRepo = @($xamls | Where-Object {
            (Get-Content -LiteralPath $_.FullName -Raw) -match
            'ObjectRepository|TargetAnchorable\b.*ReferenceId|uix:'
        }).Count
    if ($usesRepo -gt 0) {
        $objDir = Join-Path $abs '.objects'
        $descriptors = 0
        if (Test-Path -LiteralPath $objDir) {
            # .metadata/.type alone is the empty root Studio creates in every project.
            $descriptors = @(Get-ChildItem -LiteralPath $objDir -Recurse -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notin '.metadata', '.type' }).Count
        }
        if ($descriptors -eq 0) {
            Add-Finding error 'object-repository-not-shared' $name `
                ("$usesRepo workflow(s) reference the Object Repository but .objects/ holds no " +
                 'descriptors. The selectors live in .objects/ - without it every target resolves ' +
                 'to nothing. Capture them, or recover the folder.')
        }
        else {
            # Present on disk is not the same as shared. Ask git.
            $ignored = $false
            try {
                $probe = Get-ChildItem -LiteralPath $objDir -Recurse -File -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notin '.metadata', '.type' } | Select-Object -First 1
                if ($probe) {
                    git -C $abs check-ignore -q -- $probe.FullName 2>$null
                    $ignored = ($LASTEXITCODE -eq 0)
                }
            }
            catch { $ignored = $false }   # no git, or not a repo - nothing to assert
            if ($ignored) {
                Add-Finding error 'object-repository-not-shared' $name `
                    (".objects/ holds $descriptors captured descriptor(s) but git IGNORES them. " +
                     'The workflows will be committed without their selectors and a fresh clone ' +
                     "resolves every target to nothing. Remove '.objects/' from this project's " +
                     '.gitignore - it is source, not Studio local state. THEN, BEFORE COMMITTING ' +
                     'IT: descriptors are captured from a live application and record what was ' +
                     'on screen, so scan the .content files for credentials, tokens, email ' +
                     'addresses and customer/account numbers, and check .images/ for screenshots ' +
                     'of a logged-in session. Re-capture against throwaway data rather than ' +
                     'hand-editing. See README.md "Upgrading from v0.1.x".')
            }
        }
    }

    return [pscustomobject]@{
        Name     = $name
        Proj     = $proj
        Settings = $settings
    }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
$results = @()
foreach ($p in $ProjectPath) {
    if (-not (Test-Path $p)) {
        Add-Finding error 'not-a-project' $p 'path does not exist'
        continue
    }
    $results += Test-Project $p
}
$results = @($results | Where-Object { $_ })

# --- queue-name-match: only meaningful across a Dispatcher/Performer pair ----
if ($results.Count -ge 2) {
    $names = @{}
    foreach ($r in $results) {
        foreach ($env in $r.Settings.Keys) {
            $k = $r.Settings[$env].Keys | Where-Object { $_ -like '*|OrchestratorQueueName' } | Select-Object -First 1
            if ($k) { $names["$($r.Name)/$env"] = [string] $r.Settings[$env][$k] }
        }
    }
    foreach ($env in @('TST', 'PRD')) {
        $vals = @($names.GetEnumerator() | Where-Object { $_.Key -like "*/$env" })
        $distinct = @($vals | ForEach-Object { $_.Value } | Where-Object { $_ } | Select-Object -Unique)
        if ($distinct.Count -gt 1) {
            Add-Finding error 'queue-name-match' '(pair)' `
                ("$env OrchestratorQueueName is not byte-identical across the projects: " +
                 (($vals | ForEach-Object { "$($_.Key)='$($_.Value)'" }) -join ', ') +
                 '. A mismatch fails silently - the Dispatcher enqueues and the Performer reports a clean empty run.')
        }
    }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
# Apply suppressions: a suppressed finding keeps its place in the output, with the reason,
# but stops counting towards the exit code.
foreach ($f in $script:Findings) {
    $reason = $null
    if ($SkipRule -contains $f.Rule) { $reason = "-SkipRule $($f.Rule)" }
    elseif ($script:Suppressions.ContainsKey($f.Project) -and
            $script:Suppressions[$f.Project].ContainsKey($f.Rule)) {
        $reason = $script:Suppressions[$f.Project][$f.Rule]
    }
    if ($reason) {
        $f | Add-Member -NotePropertyName Suppressed -NotePropertyValue $reason -Force
        $f.Severity = 'muted'
    }
}

$errors = @($script:Findings | Where-Object Severity -eq 'error')
$warnings = @($script:Findings | Where-Object Severity -eq 'warning')
$muted = @($script:Findings | Where-Object Severity -eq 'muted')

if ($script:Findings.Count -eq 0) {
    Write-Host "PASS - no findings across $($results.Count) project(s)."
}
else {
    foreach ($f in ($script:Findings | Sort-Object Severity, Rule)) {
        $colour = switch ($f.Severity) {
            'error' { 'Red' } 'warning' { 'Yellow' } default { 'DarkGray' }
        }
        Write-Host ("{0,-7} {1,-28} {2,-34} {3}" -f $f.Severity, $f.Rule, $f.Project, $f.Message) -ForegroundColor $colour
        if ($f.Severity -eq 'muted') {
            Write-Host ("{0,-7} {1,-28} {2,-34} reason: {3}" -f '', '', '', $f.Suppressed) -ForegroundColor DarkGray
        }
    }
    Write-Host ''
    $summary = "$($errors.Count) error(s), $($warnings.Count) warning(s)"
    if ($muted.Count -gt 0) { $summary += ", $($muted.Count) suppressed" }
    Write-Host "$summary across $($results.Count) project(s)."
}

if ($TemplateMode) {
    $expectedRules = @('template-default-left', 'name-no-whitespace')
    $expected = @($script:Findings | Where-Object { $_.Rule -in $expectedRules })
    $errors = @($errors | Where-Object { $_.Rule -notin $expectedRules })
    $warnings = @($warnings | Where-Object { $_.Rule -notin $expectedRules })

    Write-Host ''
    Write-Host "Template mode: $($expected.Count) finding(s) from $($expectedRules -join ', ') treated as expected." -ForegroundColor Cyan
    Write-Host "Remaining: $($errors.Count) error(s), $($warnings.Count) warning(s)."

    if ($expected.Count -eq 0) {
        Write-Host ''
        Write-Host 'FAIL - no placeholder findings at all. The templates ship their tripwires on purpose;' -ForegroundColor Red
        Write-Host '       if none fires, a placeholder has been "helpfully" filled in and a half-' -ForegroundColor Red
        Write-Host '       instantiated project could now pass for a finished one.' -ForegroundColor Red
        exit 1
    }
}

$failed = $errors.Count -gt 0 -or ($WarningsAsErrors -and $warnings.Count -gt 0)
exit ([int] $failed)
