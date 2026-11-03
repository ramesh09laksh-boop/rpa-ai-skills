#Requires -Version 7.0
<#
.SYNOPSIS
    Proves every validate-project rule still fires.

.DESCRIPTION
    CI used to check only that templates/ produces zero findings. That proves a rule does not
    FALSE-POSITIVE; it proves nothing about whether the rule still works. A rule whose regex
    stopped matching — a renamed activity, a reworded placeholder, a refactor that moved the
    text it keys on — would go on reporting nothing and CI would stay green. The checker would
    quietly become a 42-KB no-op, and the first symptom would be a silent failure reaching
    production, which is the exact class of defect every rule exists to catch.

    So: one bad/good pair per rule, and both directions asserted.

      bad  -> the rule MUST appear among the findings
      good -> the rule MUST NOT appear

    "good" means "this rule is silent", not "no findings at all". Other rules may legitimately
    fire on a fixture — a fixture built to trip exactly one rule and nothing else would be a
    full conformant project per rule, which nobody would maintain. The assertion is per-rule,
    and that is stated rather than implied.

.PARAMETER Rule
    Run only the named rule(s). Default: all.

.PARAMETER KeepTemp
    Leave the materialised fixture projects on disk and print the path. For debugging a
    fixture that does not behave.

.OUTPUTS
    One line per fixture. Exit 0 when every assertion holds, 1 otherwise.

.EXAMPLE
    pwsh -NoProfile -File tests/run-fixtures.ps1
    pwsh -NoProfile -File tests/run-fixtures.ps1 -Rule leaf-body-stub -KeepTemp
#>
[CmdletBinding()]
param(
    [string[]] $Rule,
    [switch] $KeepTemp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
$repo = Split-Path -Parent $here
$validate = Join-Path $repo '.claude/skills/project-scaffolding/scripts/validate-project.ps1'
$fixtureRoot = Join-Path $here 'fixtures'
$baseDir = Join-Path $fixtureRoot '_base'

. (Join-Path $here 'lib/New-ConfigWorkbook.ps1')

if (-not (Test-Path -LiteralPath $validate)) { throw "validate-project.ps1 not found at $validate" }
if (-not (Test-Path -LiteralPath $baseDir)) { throw "fixture base not found at $baseDir" }

# ---------------------------------------------------------------------------
# Coverage: every rule the checker can emit needs a fixture directory.
#
# This is the half that makes the suite hard to cheat. Without it, adding a rule and no
# fixture leaves the suite green and the new rule untested - the same hole, one rule along.
# ---------------------------------------------------------------------------
$checkerText = Get-Content -LiteralPath $validate -Raw
$declaredRules = @([regex]::Matches($checkerText, "Add-Finding\s+(?:error|warning|\`$sev)\s+'([a-z0-9-]+)'") |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

$fixtureDirs = @(Get-ChildItem -LiteralPath $fixtureRoot -Directory |
    Where-Object Name -notlike '_*' | ForEach-Object Name | Sort-Object)

$missing = @($declaredRules | Where-Object { $_ -notin $fixtureDirs })
$orphan = @($fixtureDirs | Where-Object { $_ -notin $declaredRules })

# ---------------------------------------------------------------------------
# Materialise one fixture: base, then the overlay on top.
#
# The overlay is the fixture. Copying a whole project per case would bury the one difference
# that matters in 10 identical files; this way the fixture directory IS the diff.
# ---------------------------------------------------------------------------
function Copy-Tree {
    param([string] $From, [string] $To)
    if (-not (Test-Path -LiteralPath $To)) { New-Item -ItemType Directory -Path $To -Force | Out-Null }
    foreach ($item in Get-ChildItem -LiteralPath $From -Force) {
        $dest = Join-Path $To $item.Name
        if ($item.PSIsContainer) { Copy-Tree -From $item.FullName -To $dest }
        else { Copy-Item -LiteralPath $item.FullName -Destination $dest -Force }
    }
}

function Build-Fixture {
    param([string] $CaseDir, [string] $WorkDir)

    $cfgPath = Join-Path $CaseDir 'fixture.json'
    $cfg = if (Test-Path -LiteralPath $cfgPath) { Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json }
           else { $null }

    # [string[]] on each, not just @(...) inside the if: a single-element array RETURNED from
    # an if-expression is unrolled to a scalar on assignment, and `'Proj'.Count` then throws
    # under StrictMode. The cast is what keeps it an array.
    [string[]] $projects = if ($cfg -and $cfg.PSObject.Properties['projects']) { @($cfg.projects) } else { @('Proj') }
    [string[]] $extraArgs = if ($cfg -and $cfg.PSObject.Properties['args']) { @($cfg.args) } else { @() }
    [string[]] $remove = if ($cfg -and $cfg.PSObject.Properties['remove']) { @($cfg.remove) } else { @() }

    # Files the fixture needs but CANNOT commit, because this repo's own .gitignore ignores
    # them - and rightly so. `**/Exceptions_Screenshots/*` and `**/Data/Output/*` are a
    # data-protection backstop: screenshots of a logged-in banking session must not be
    # committable. Weakening that rule so a test fixture can live there would trade a real
    # protection for a test convenience. So the runner creates the file at test time instead.
    #
    # This was found by the suite's own check that every fixture file is trackable by git.
    [string[]] $touch = if ($cfg -and $cfg.PSObject.Properties['touch']) { @($cfg.touch) } else { @() }

    foreach ($p in $projects) {
        $target = Join-Path $WorkDir $p
        Copy-Tree -From $baseDir -To $target

        # Overlay. For a single-project fixture the overlay sits at the case root; for a
        # multi-project one it is nested per project name.
        $overlay = if ($projects.Count -eq 1) { $CaseDir } else { Join-Path $CaseDir $p }
        if (Test-Path -LiteralPath $overlay) {
            foreach ($item in Get-ChildItem -LiteralPath $overlay -Force) {
                if ($item.Name -in 'fixture.json', 'notes.md') { continue }
                if ($projects.Count -gt 1 -and $item.Name -in $projects) { continue }
                $dest = Join-Path $target $item.Name
                if ($item.PSIsContainer) { Copy-Tree -From $item.FullName -To $dest }
                else { Copy-Item -LiteralPath $item.FullName -Destination $dest -Force }
            }
        }

        foreach ($r in @($remove | Where-Object { $_ })) {
            $victim = Join-Path $target $r
            if (Test-Path -LiteralPath $victim) { Remove-Item -LiteralPath $victim -Recurse -Force }
        }

        foreach ($t in @($touch | Where-Object { $_ })) {
            $made = Join-Path $target $t
            $madeDir = Split-Path -Parent $made
            if ($madeDir -and -not (Test-Path -LiteralPath $madeDir)) {
                New-Item -ItemType Directory -Path $madeDir -Force | Out-Null
            }
            Set-Content -LiteralPath $made -Encoding utf8 -Value @'
Created by tests/run-fixtures.ps1, not committed: this repo's .gitignore correctly refuses to
track anything under Exceptions_Screenshots/ or Data/Output/. Stands in for run output that a
real project would have left behind.
'@
        }

        # Config TSV -> xlsx. Config.tsv covers both environments; Config_TST.tsv /
        # Config_PRD.tsv override one env, which is what the parity rules need.
        $dataDir = Join-Path $target 'Data'
        if (Test-Path -LiteralPath $dataDir) {
            $shared = Join-Path $dataDir 'Config.tsv'
            foreach ($env in @('TST', 'PRD')) {
                $perEnv = Join-Path $dataDir "Config_$env.tsv"
                $src = if (Test-Path -LiteralPath $perEnv) { $perEnv }
                       elseif (Test-Path -LiteralPath $shared) { $shared }
                       else { $null }
                if ($src) { New-ConfigWorkbook -TsvPath $src -XlsxPath (Join-Path $dataDir "Config_$env.xlsx") }
            }
            Get-ChildItem -LiteralPath $dataDir -Filter '*.tsv' -File | Remove-Item -Force
        }
    }

    return [pscustomobject]@{
        Paths = @($projects | ForEach-Object { Join-Path $WorkDir $_ })
        Args  = $extraArgs
    }
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
[string[]] $toRun = if ($Rule) { @($fixtureDirs | Where-Object { $_ -in $Rule }) } else { $fixtureDirs }
if ($Rule) {
    $unknown = @($Rule | Where-Object { $_ -notin $fixtureDirs })
    if ($unknown) { throw "no fixture for: $($unknown -join ', ')" }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vp-fixtures-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

$results = [System.Collections.Generic.List[object]]::new()

try {
    foreach ($ruleName in $toRun) {
        foreach ($expect in @('bad', 'good')) {
            $caseDir = Join-Path (Join-Path $fixtureRoot $ruleName) $expect
            if (-not (Test-Path -LiteralPath $caseDir)) {
                $results.Add([pscustomobject]@{
                        Rule = $ruleName; Case = $expect; Pass = $false
                        Detail = "no $expect/ directory"
                    })
                continue
            }

            $work = Join-Path $tempRoot "$ruleName-$expect"
            New-Item -ItemType Directory -Path $work -Force | Out-Null
            $built = Build-Fixture -CaseDir $caseDir -WorkDir $work

            # Filter out nulls before splatting. `[string[]] $x = if (...) { @() }` leaves $x
            # as $null, and @($null) is a ONE-element array holding $null - which splats as an
            # empty string and binds to -ProjectPath, failing with
            # "Cannot bind argument to parameter 'ProjectPath' because it is an empty string".
            $argList = @(@($built.Paths) + @($built.Args) | Where-Object { $_ })
            $output = & $validate @argList 6>&1 2>&1 | Out-String

            # The rule id is the second column of a finding line. Match it anchored so
            # 'config-parity' cannot be satisfied by a message that merely mentions it.
            $fired = [bool]([regex]::IsMatch($output,
                    "(?m)^(?:error|warning|muted)\s+" + [regex]::Escape($ruleName) + "\s"))

            $pass = if ($expect -eq 'bad') { $fired } else { -not $fired }
            $detail = if ($pass) {
                if ($expect -eq 'bad') { 'fired, as required' } else { 'silent, as required' }
            }
            else {
                if ($expect -eq 'bad') { 'DID NOT FIRE - the rule has stopped working, or the fixture no longer trips it' }
                else { 'FIRED on the good fixture - false positive' }
            }

            $results.Add([pscustomobject]@{
                    Rule = $ruleName; Case = $expect; Pass = $pass; Detail = $detail
                    Output = $output
                })
        }
    }
}
finally {
    if ($KeepTemp) { Write-Host "`nfixtures left at: $tempRoot" -ForegroundColor Cyan }
    else { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
Write-Host ''
foreach ($r in $results) {
    $tag = if ($r.Pass) { 'PASS' } else { 'FAIL' }
    $colour = if ($r.Pass) { 'Green' } else { 'Red' }
    Write-Host ("{0,-5} {1,-30} {2,-5} {3}" -f $tag, $r.Rule, $r.Case, $r.Detail) -ForegroundColor $colour
    if (-not $r.Pass -and $r.PSObject.Properties['Output'] -and $r.Output) {
        foreach ($line in (($r.Output -split '\r?\n') | Where-Object { $_ -match '^\s*(error|warning|muted)\s' })) {
            Write-Host "        | $line" -ForegroundColor DarkGray
        }
    }
}

$failed = @($results | Where-Object { -not $_.Pass })

Write-Host ''
Write-Host ("$($results.Count) assertion(s) over $($toRun.Count) rule(s): " +
            "$($results.Count - $failed.Count) passed, $($failed.Count) failed.")

if (-not $Rule) {
    Write-Host ''
    Write-Host "Coverage: $($declaredRules.Count) rule(s) in validate-project.ps1, $($fixtureDirs.Count) fixture directory(ies)."
    if ($missing) {
        Write-Host "MISSING fixtures for: $($missing -join ', ')" -ForegroundColor Red
        Write-Host '  A rule with no fixture is a rule nothing proves still works.' -ForegroundColor Red
    }
    if ($orphan) {
        Write-Host "Fixture(s) for no such rule: $($orphan -join ', ')" -ForegroundColor Yellow
        Write-Host '  Either the rule was renamed or removed, or the directory is a typo.' -ForegroundColor Yellow
    }
}

$bad = $failed.Count -gt 0 -or ($null -eq $Rule -and ($missing.Count -gt 0 -or $orphan.Count -gt 0))
exit ([int] $bad)
