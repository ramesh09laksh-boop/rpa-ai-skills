#Requires -Version 7.0
<#
.SYNOPSIS
    Lints this repo's own skills. Run before merging to main.

.DESCRIPTION
    `npx skills update` pulls whatever is on main, so a broken skill on main is a broken skill
    in every UC project on its next update. These are the checks that catch the breakages which
    are invisible by inspection:

      name-matches-folder     an agent resolves a skill by its frontmatter `name`; a mismatch
                              makes the skill unloadable under the name everyone references
      description-length      the description is the ONLY thing an agent sees when deciding
                              whether to load a skill. Over 1024 chars it is rejected
      description-present     ditto - a missing one means the skill never triggers
      skill-md-length         SKILL.md is always loaded. Past ~500 lines it crowds out the work
      agent-specific-path     '.claude/skills/...' inside skill CONTENT. The CLI installs into
                              the agent's own folder (.claude/skills/, .agents/skills/, or
                              .github/skills/), so a hard-coded .claude path resolves to nothing
                              for Copilot, Codex and OpenCode, and cross-skill loading silently
                              fails. Name the skill, or use a path relative to the skill folder
      broken-reference        a `references/x.md` or `scripts/x` cited in text but not on disk
      credential-pattern      a password/secret/token assignment that looks like a real value

.PARAMETER SkillRoot
    Defaults to the .claude/skills directory two levels above this script.

.PARAMETER MaxSkillMdLines
    Default 500.

.OUTPUTS
    One line per finding. Exit code 0 when no errors, 1 otherwise.
#>
[CmdletBinding()]
param(
    [string] $SkillRoot,
    [int] $MaxSkillMdLines = 500,
    [switch] $WarningsAsErrors
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $SkillRoot) {
    $SkillRoot = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) ''
}
$SkillRoot = (Resolve-Path -LiteralPath $SkillRoot).Path

$findings = [System.Collections.Generic.List[object]]::new()
function Add-Finding {
    param([ValidateSet('error', 'warning')] [string] $Severity, [string] $Rule, [string] $Skill, [string] $Message)
    $findings.Add([pscustomobject]@{ Severity = $Severity; Rule = $Rule; Skill = $Skill; Message = $Message })
}

$skillDirs = @(Get-ChildItem -LiteralPath $SkillRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') })

if ($skillDirs.Count -eq 0) {
    Write-Error "No skills found under $SkillRoot"
    exit 2
}

foreach ($d in $skillDirs) {
    $skill = $d.Name
    $skillMd = Join-Path $d.FullName 'SKILL.md'
    $text = Get-Content -LiteralPath $skillMd -Raw
    $lines = @(Get-Content -LiteralPath $skillMd)

    # --- frontmatter ---
    $fm = [regex]::Match($text, '(?s)\A---\r?\n(.*?)\r?\n---')
    if (-not $fm.Success) {
        Add-Finding error 'frontmatter-missing' $skill 'SKILL.md has no --- frontmatter block'
    }
    else {
        $block = $fm.Groups[1].Value
        $nameM = [regex]::Match($block, '(?m)^name:\s*(.+?)\s*$')
        if (-not $nameM.Success) {
            Add-Finding error 'name-matches-folder' $skill 'frontmatter has no name:'
        }
        elseif ($nameM.Groups[1].Value -ne $skill) {
            Add-Finding error 'name-matches-folder' $skill `
                "frontmatter name '$($nameM.Groups[1].Value)' does not match folder '$skill'"
        }

        # description may wrap onto continuation lines
        $descM = [regex]::Match($block, '(?ms)^description:\s*(.*?)(?=\r?\n[a-zA-Z_-]+:\s|\z)')
        if (-not $descM.Success -or -not $descM.Groups[1].Value.Trim()) {
            Add-Finding error 'description-present' $skill `
                'frontmatter has no description: - an agent has nothing to trigger on'
        }
        else {
            $desc = ($descM.Groups[1].Value -replace '\s+', ' ').Trim()
            if ($desc.Length -gt 1024) {
                Add-Finding error 'description-length' $skill "description is $($desc.Length) chars (limit 1024)"
            }
        }
    }

    if ($lines.Count -gt $MaxSkillMdLines) {
        Add-Finding error 'skill-md-length' $skill `
            "SKILL.md is $($lines.Count) lines (limit $MaxSkillMdLines) - move detail into references/"
    }

    # --- per-file content rules ---
    foreach ($f in Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Include *.md) {
        $rel = $f.FullName.Substring($d.FullName.Length).TrimStart('\', '/')
        $body = Get-Content -LiteralPath $f.FullName -Raw

        # agent-specific-path
        foreach ($m in [regex]::Matches($body, '\.(claude|github|agents)/skills/')) {
            Add-Finding error 'agent-specific-path' $skill `
                ("$rel hard-codes '$($m.Value)'. The CLI installs into the agent's own folder, so " +
                 'this resolves to nothing for other agents. Name the skill, or use a path ' +
                 'relative to the skill folder (references/..., scripts/..., assets/...).')
        }

        # broken-reference: `references/x.md` / `scripts/x` / `assets/x` cited but absent.
        #
        # A citation is relative to the skill that OWNS the file it points at, which is not
        # always the skill doing the citing. Cross-skill references are written
        # "the `security` skill, `references/env-config.md`" - so look back for a named skill
        # and resolve against that one. Without this the rule reports every cross-skill
        # reference in the repo as broken.
        foreach ($m in [regex]::Matches($body, '`((?:references|scripts|assets)/[A-Za-z0-9/._-]+)`')) {
            $cited = $m.Groups[1].Value
            if ($cited -match '\*') { continue }

            $owner = $d.FullName
            $lookStart = [Math]::Max(0, $m.Index - 80)
            $preceding = $body.Substring($lookStart, $m.Index - $lookStart)
            # Anchored at the END of the preceding text: the skill must be named immediately
            # before the citation ("the `security` skill, `references/env-config.md`"), not
            # merely somewhere earlier in the paragraph.
            $named = [regex]::Match($preceding, '`([a-z][a-z0-9-]*)`\s+skill,?\s*$')
            if ($named.Success) {
                $otherDir = Join-Path $SkillRoot $named.Groups[1].Value
                if (Test-Path -LiteralPath $otherDir) { $owner = $otherDir }
            }

            if (-not (Test-Path -LiteralPath (Join-Path $owner $cited))) {
                $where = if ($owner -eq $d.FullName) { '' } else { " (resolved against $(Split-Path -Leaf $owner))" }
                Add-Finding error 'broken-reference' $skill "$rel cites '$cited'$where which does not exist"
            }
        }

        # credential-pattern: an assignment that looks like a real secret, not a placeholder
        foreach ($m in [regex]::Matches($body,
                '(?i)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*["'']?([^\s"''`<\[\r\n]{8,})')) {
            $val = $m.Groups[2].Value
            if ($val -match '^(?i)(your|the|a|some|<|\{|\[|\.\.\.|xxx|todo|uc-specific|secure|null|none|string|\*+)') { continue }
            if ($val -match '^\$|^%|^\[UC-|GetRobotCredential|GetAppCredential|SecureString') { continue }
            # A plain alphabetic identifier, optionally in_/out_/io_-prefixed, is an ARGUMENT or
            # VARIABLE name, not a secret: `Password="[out_Password]"`, `Password = Password`.
            # Real secrets carry digits or symbols. Without this the rule fires on every correct
            # credential example in the security skill, and a lint that always shows the same
            # four warnings is a lint nobody reads.
            if ($val -match '^(in_|out_|io_)?[A-Za-z]+$') { continue }
            Add-Finding warning 'credential-pattern' $skill `
                "$rel has '$($m.Groups[1].Value)' assigned a literal-looking value - confirm it is not real"
        }
    }
}

# --- report ---
$errors = @($findings | Where-Object Severity -eq 'error')
$warnings = @($findings | Where-Object Severity -eq 'warning')

foreach ($f in ($findings | Sort-Object Severity, Rule, Skill)) {
    $colour = if ($f.Severity -eq 'error') { 'Red' } else { 'Yellow' }
    Write-Host ('{0,-7} {1,-22} {2,-22} {3}' -f $f.Severity, $f.Rule, $f.Skill, $f.Message) -ForegroundColor $colour
}

Write-Host ''
Write-Host ("$($errors.Count) error(s), $($warnings.Count) warning(s) across $($skillDirs.Count) skill(s).")

if ($errors.Count -gt 0 -or ($WarningsAsErrors -and $warnings.Count -gt 0)) { exit 1 }
exit 0
