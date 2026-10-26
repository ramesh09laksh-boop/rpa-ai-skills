#Requires -Version 7.0
<#
.SYNOPSIS
    Extracts library activity signatures from x:Members and checks them against what this repo
    documents. Maintainer script — run it on a library version bump.

.DESCRIPTION
    The library skills document exact argument names, and several are load-bearing (a
    misspelling that must be copied verbatim, an `Idx` vs `idx` casing split). Those are
    name/type/direction facts, and a human re-reading 155 workflows does not reliably catch a
    changed one. This does.

    Two modes:

      (default)   DRIFT CHECK. Regenerates the signature tables in memory and compares them
                  against the committed references/activities-signatures.md. Any difference is
                  drift: either the library changed, or the committed file was hand-edited.
                  Also reports real argument names that appear nowhere in activities.md.

      -Generate   Writes references/activities-signatures.md for each library.

    It does NOT touch activities.md. That file's value is its prose — which activity to prefer,
    what a gotcha costs, that SearchInColumn is 0-based — and only 3 of 155 workflows carry any
    annotation at all, so none of it is derivable from the XAML. Signatures are generated; prose
    stays hand-written.

.PARAMETER FinnovaRoot
.PARAMETER AvaloqRoot
    The library SOURCE projects. They live one level above this repo and are deliberately not
    published here (client and employer material), so both default to the sibling layout and
    the script SKIPS cleanly when they are absent — which is the normal case in CI.

.PARAMETER Generate
    Write the signature files instead of checking them.

.OUTPUTS
    Exit 0 when clean or skipped. Exit 1 on drift.

.EXAMPLE
    pwsh -File check-library-signatures.ps1
.EXAMPLE
    pwsh -File check-library-signatures.ps1 -Generate
#>
[CmdletBinding()]
param(
    [string] $FinnovaRoot,
    [string] $AvaloqRoot,
    [switch] $Generate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#   <script> = <repo>/.claude/skills/project-scaffolding/scripts/check-library-signatures.ps1
$skillsRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))  # <repo>/.claude/skills
$repoRoot = Split-Path -Parent (Split-Path -Parent $skillsRoot)                            # <repo>
# The libraries are SIBLINGS of the repo, not inside it - see AGENTS.md "What sits alongside it".
$siblingRoot = Split-Path -Parent $repoRoot

if (-not $FinnovaRoot) { $FinnovaRoot = Join-Path $siblingRoot 'Finnova/Swisscom FinnovaLibrary' }
if (-not $AvaloqRoot) { $AvaloqRoot = Join-Path $siblingRoot 'Avaloq/Swisscom.UiPath.UIAutomation.Avaloq' }

$libs = @(
    [pscustomobject]@{ Key = 'finnova'; Name = 'Swisscom.FinnovaLibrary'; Root = $FinnovaRoot
                       Skill = Join-Path $skillsRoot 'finnova-library' }
    [pscustomobject]@{ Key = 'avaloq'; Name = 'Swisscom.UiPath.UIAutomation.Avaloq'; Root = $AvaloqRoot
                       Skill = Join-Path $skillsRoot 'avaloq-library' }
)

# --- skip cleanly when the sources are not here -------------------------------
$missing = @($libs | Where-Object { -not (Test-Path -LiteralPath $_.Root) })
if ($missing.Count -gt 0) {
    Write-Host 'SKIPPED: library signature check - the library source projects are not present.' -ForegroundColor Yellow
    foreach ($m in $missing) {
        Write-Host ("         not found: {0}" -f $m.Root) -ForegroundColor DarkGray
    }
    Write-Host '         They live one level above this repo and are intentionally not published' -ForegroundColor DarkGray
    Write-Host '         here (client and employer material), so this is expected in CI and on a' -ForegroundColor DarkGray
    Write-Host '         standalone clone. Run it from a checkout that has the siblings.' -ForegroundColor DarkGray
    exit 0
}

# --- extract ------------------------------------------------------------------
function Get-Signatures {
    param([string] $Root)

    $out = [ordered]@{}
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.xaml |
        Where-Object { $_.FullName -notmatch '[\\/]\.' } | Sort-Object FullName)

    foreach ($f in $files) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
        $text = Get-Content -LiteralPath $f.FullName -Raw

        $members = [regex]::Match($text, '(?s)<x:Members>(.*?)</x:Members>')
        $args = [System.Collections.Generic.List[object]]::new()
        if ($members.Success) {
            foreach ($pm in [regex]::Matches($members.Groups[1].Value, '(?s)<x:Property\b(.*?)/>')) {
                $attrs = @{}
                foreach ($am in [regex]::Matches($pm.Groups[1].Value, '(\w+)="([^"]*)"')) {
                    $attrs[$am.Groups[1].Value] = $am.Groups[2].Value
                }
                if (-not $attrs.ContainsKey('Name')) { continue }
                $type = if ($attrs.ContainsKey('Type')) { $attrs['Type'] } else { '' }
                $dir = switch -Regex ($type) {
                    '^InOutArgument' { 'io' }
                    '^InArgument' { 'in' }
                    '^OutArgument' { 'out' }
                    default { '?' }
                }
                $inner = [regex]::Replace($type, '^(In|Out|InOut)Argument\((.*)\)$', '$2')
                $args.Add([pscustomobject]@{ Name = $attrs['Name']; Dir = $dir; Type = $inner })
            }
        }
        $out[$rel] = $args
    }
    return $out
}

function Build-Markdown {
    param([object] $Lib, [object] $Sigs)

    $sb = [System.Text.StringBuilder]::new()
    $n = @($Sigs.Keys).Count
    $argCount = 0
    foreach ($k in $Sigs.Keys) { $argCount += @($Sigs[$k]).Count }

    [void]$sb.AppendLine("# $($Lib.Name) — argument signatures")
    [void]$sb.AppendLine()
    # Not an agent-specific path: the CLI installs skills into the agent's own folder, so
    # '.claude/skills/...' resolves to nothing for Copilot/Codex/OpenCode. lint-skills.ps1
    # enforces this, and caught it here.
    [void]$sb.AppendLine('<!-- GENERATED by the project-scaffolding skill,')
    [void]$sb.AppendLine('     scripts/check-library-signatures.ps1')
    [void]$sb.AppendLine('     Do not edit by hand. Re-run with -Generate after a library version bump. -->')
    [void]$sb.AppendLine()
    # Backtick is PowerShell's escape character, so a literal markdown backtick needs doubling.
    $bt = [char]96
    [void]$sb.AppendLine("Extracted from the library source project's ${bt}x:Members${bt}. **Names, types and directions only** —")
    [void]$sb.AppendLine('what each argument is *for*, which activity to prefer, and the gotchas live in')
    [void]$sb.AppendLine('`activities.md`, which is hand-written because the XAML does not carry that information.')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("$n workflow file(s), $argCount argument(s).")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Direction is `in` / `out` / `io`. Type is as declared, with the')
    [void]$sb.AppendLine('`InArgument(...)` wrapper removed.')
    [void]$sb.AppendLine()

    foreach ($k in $Sigs.Keys) {
        [void]$sb.AppendLine("## ``$k``")
        [void]$sb.AppendLine()
        $args = @($Sigs[$k])
        if ($args.Count -eq 0) {
            [void]$sb.AppendLine('No arguments.')
            [void]$sb.AppendLine()
            continue
        }
        [void]$sb.AppendLine('| Argument | Dir | Type |')
        [void]$sb.AppendLine('|---|---|---|')
        foreach ($a in $args) {
            $nm = $a.Name -replace '\|', '\|'
            $ty = $a.Type -replace '\|', '\|'
            [void]$sb.AppendLine("| ``$nm`` | $($a.Dir) | ``$ty`` |")
        }
        [void]$sb.AppendLine()
    }
    return $sb.ToString()
}

$drift = 0
$gaps = 0

foreach ($lib in $libs) {
    $sigs = Get-Signatures -Root $lib.Root
    $md = Build-Markdown -Lib $lib -Sigs $sigs
    $target = Join-Path $lib.Skill 'references/activities-signatures.md'

    if ($Generate) {
        # LF explicitly: .gitattributes normalises on commit, and writing CRLF here makes the
        # drift check fail on a different platform for no reason. The template-workbook
        # generator taught this.
        [System.IO.File]::WriteAllText($target, ($md -replace "`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
        Write-Host ("  wrote {0}" -f (Resolve-Path -Relative $target)) -ForegroundColor Green
        continue
    }

    # --- drift: generated vs committed ---
    if (-not (Test-Path -LiteralPath $target)) {
        Write-Host ("DRIFT  {0}: {1} does not exist - run with -Generate" -f $lib.Key, 'references/activities-signatures.md') -ForegroundColor Red
        $drift++
    }
    else {
        $committed = (Get-Content -LiteralPath $target -Raw) -replace "`r`n", "`n"
        $fresh = $md -replace "`r`n", "`n"
        if ($committed.TrimEnd() -ne $fresh.TrimEnd()) {
            Write-Host ("DRIFT  {0}: activities-signatures.md does not match the library source." -f $lib.Key) -ForegroundColor Red
            Write-Host '       Either the library changed, or the file was hand-edited. Re-run with -Generate' -ForegroundColor DarkGray
            Write-Host '       and read the diff - a changed argument name is a breaking change for' -ForegroundColor DarkGray
            Write-Host '       every workflow that calls it.' -ForegroundColor DarkGray
            $drift++
        }
        else {
            Write-Host ("OK     {0}: signatures match the library source" -f $lib.Key) -ForegroundColor Green
        }
    }

    # --- gaps: real argument names that appear nowhere in the prose ---
    $prose = Join-Path $lib.Skill 'references/activities.md'
    if (Test-Path -LiteralPath $prose) {
        $proseText = Get-Content -LiteralPath $prose -Raw
        $real = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($k in $sigs.Keys) { foreach ($a in @($sigs[$k])) { [void]$real.Add($a.Name) } }

        # A documented name may be covered by a shorthand (ScrollBar* stands for five) or
        # deliberately omitted (the CyberArk/PHI internals are marked "not intended for direct
        # use"). Count it as mentioned if the literal name appears, or a prefix shorthand does.
        $unmentioned = @($real | Where-Object {
                if ($proseText -match [regex]::Escape($_)) { return $false }
                $pre = [regex]::Match($_, '^([A-Za-z]+?)(Idx|Max|Role|PageTabName|PanelName)$')
                if ($pre.Success -and $proseText -match ([regex]::Escape($pre.Groups[1].Value) + '\*')) { return $false }
                return $true
            } | Sort-Object)

        if ($unmentioned.Count -gt 0) {
            Write-Host ("INFO   {0}: {1} argument name(s) exist in the library but appear nowhere in activities.md" -f $lib.Key, $unmentioned.Count) -ForegroundColor Yellow
            foreach ($u in $unmentioned) { Write-Host "         $u" -ForegroundColor DarkGray }
            Write-Host '       Not a failure - some are deliberately undocumented internals. Review on a bump.' -ForegroundColor DarkGray
            $gaps += $unmentioned.Count
        }
    }
}

Write-Host ''
if ($Generate) {
    Write-Host 'Generated. Commit the result, and read the diff before you do.'
    exit 0
}
if ($drift -gt 0) {
    Write-Host "$drift library signature file(s) out of date. Re-run with -Generate." -ForegroundColor Red
    exit 1
}
Write-Host "Signatures match. $gaps documented-prose gap(s) noted above (informational)."
exit 0
