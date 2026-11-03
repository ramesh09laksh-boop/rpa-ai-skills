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
      infra-identity-value    a real IP, e-mail address or customer id written into a skill.
                              Not secrets - which is why they got written down - but a skill
                              ships to EVERY install and into every agent's context, and the
                              value is stale on arrival because Config_<ENV>.xlsx is the
                              authority. Record the config key and the asset name instead.
                              Asset and vault OBJECT names are fine: they are identifiers you
                              must name to wire anything up
      install-simulation      a path the skill NAMES that does not exist in an installed
                              project. Each skill is copied ALONE to a temp directory - which
                              is what `npx skills add --skill <name>` actually delivers - and
                              every relative markdown link plus every repo-level path mention
                              is resolved there. `templates/README.md`, `AGENTS.md`,
                              `../Finnova/...` and friends exist in THIS repo and in no
                              installed project, so a skill that sends the reader to one is
                              sending them nowhere

.NOTES
    install-simulation and its two escape hatches
    -------------------------------------------------------------------------
    Two kinds of mention are legitimate, and both have to SAY SO in the passage itself:

      1. Provenance - the skill is recording WHERE its content came from. Useful to a
         maintainer, meaningless to a UC project.
      2. Mechanics - the passage is explaining that the path is NOT delivered, which is
         exactly the thing a reader needs to know.

    Either is declared by a phrase in the same paragraph (a run of lines between blank lines,
    or one table row):

      "maintainer provenance"      for case 1
      "not in your project"        for case 2

    Or, file-wide, by an HTML comment <!-- maintainer-provenance: <reason> --> anywhere in the
    file. That is for files whose whole subject is derived-from-the-estate evidence and whose
    provenance framing already sits at the top, such as references/systems/*.md and the two
    library skills' activity references.

    An escape hatch that is not one of those does not exist. "It is obviously provenance" is
    not checkable, which is the whole reason this rule exists - and the phrasing requirement
    means the reader is told, not just the linter.

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
            # before the citation, not merely somewhere earlier in the paragraph. Two forms
            # occur, and both are legitimate:
            #   prose       the `security` skill, `references/env-config.md`
            #   table cell  `standards` (`references/wiring-the-framework.md`)
            $named = [regex]::Match($preceding, '`([a-z][a-z0-9-]*)`(\s+skill,?|\s*\()\s*$')
            if ($named.Success) {
                $otherDir = Join-Path $SkillRoot $named.Groups[1].Value
                if (Test-Path -LiteralPath $otherDir) { $owner = $otherDir }
            }

            if (-not (Test-Path -LiteralPath (Join-Path $owner $cited))) {
                $where = if ($owner -eq $d.FullName) { '' } else { " (resolved against $(Split-Path -Leaf $owner))" }
                Add-Finding error 'broken-reference' $skill "$rel cites '$cited'$where which does not exist"
            }
        }

        # --- infra-identity-value ------------------------------------------------
        # A real host, mailbox, person or customer id written into a skill.
        #
        # These are not secrets, which is exactly why they got written down: a hostname is not
        # a password, so nobody flagged it. But a skill ships to EVERY install and into every
        # agent's context, so one real mail address here is published to all of them - and it
        # is stale on arrival, because the authority is the Config_<ENV>.xlsx workbook in front
        # of the reader. Record the KEY and the ASSET NAME; never the value.
        #
        # Asset and vault OBJECT names are deliberately fine - they are identifiers you have to
        # name in order to wire anything up, and the security skill already draws that line.
        foreach ($rule in @(
                @{ Name = 'ip'; Why = 'an IPv4 address'
                   Pattern = '\b(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\b' }
                @{ Name = 'email'; Why = 'an e-mail address'
                   Pattern = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' }
                @{ Name = 'customer-id'; Why = 'a customer/party identifier'
                   Pattern = '\b(?:CH|LI)\d{5,}\b' }
            )) {
            foreach ($m in [regex]::Matches($body, $rule.Pattern)) {
                $line = ($body.Substring(0, $m.Index) -split '\r?\n')[-1] +
                        (($body.Substring($m.Index) -split '\r?\n')[0])

                # A dotted quad is textually indistinguishable from a four-part version
                # string, and this repo is full of those: 23.10.8.0, 26.10.0.0, 5.5.13.3.
                # So an IPv4 is reported only when its line also reads like a host, and never
                # when the line reads like a version. KNOWN GAP, stated rather than hidden: a
                # PUBLIC infrastructure IP on a line with no host-ish word is not caught.
                if ($rule.Name -eq 'ip') {
                    if ($line -match '(?i)version|studio|nupkg|package|\[\d') { continue }
                    $octet1 = [int] (($m.Value -split '\.')[0])
                    $private = $octet1 -in 10, 127 -or $m.Value -match '^192\.168\.' -or
                               $m.Value -match '^172\.(1[6-9]|2\d|3[01])\.'
                    $hostish = $line -match '(?i)server|host|smtp|gateway|proxy|dns|relay|autodiscover|\bip\b'
                    if (-not ($private -or $hostish)) { continue }
                }

                # Placeholders are the point of the fix, so they must not trip it.
                if ($rule.Name -eq 'email' -and
                    $m.Value -match '(?i)@(example|test|invalid|localhost|domain)\.|<|>|\{|\$') { continue }

                Add-Finding error 'infra-identity-value' $skill `
                    ("$rel contains what looks like $($rule.Why). Skills ship to every install " +
                     'and into every agent context, and the value is stale on arrival - the ' +
                     'Config_<ENV>.xlsx workbook is the authority. Write the config KEY and the ' +
                     'Orchestrator ASSET NAME instead, or a <placeholder>.')
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

# ---------------------------------------------------------------------------
# install-simulation
#
# Every rule above reads the skill where it sits in THIS repo, next to its siblings and next to
# templates/, AGENTS.md and README.md. That is not the shape anyone consumes. `npx skills add
# --skill standards` delivers one folder, and a reference to `templates/README.md` or
# `../Finnova/...` resolves to nothing there - silently, because a markdown link to a missing
# file renders as a link.
#
# So: copy each skill ALONE into a temp directory and resolve its references there.
# ---------------------------------------------------------------------------

# Repo-level paths that exist here and in no installed project.
#
# Two filenames are deliberately NOT in this list, because inside a skill they overwhelmingly
# mean a file the project HAS rather than one this repo has:
#   README.md   almost always "the fetched template's own README.md", which is delivered
#   AGENTS.md   always the PROJECT's own AGENTS.md - the Environment block a UC project
#               writes for itself. Checked: all five mentions across the skills are that,
#               none points at this repo's AGENTS.md. Including it produced three findings
#               that were all wrong.
# Where either one really does mean this repo's copy, it is written as a markdown link, and
# the link check below resolves it inside the one-skill install.
#
# `templates/` carries a negative lookbehind for a dot: `.templates/` is a Studio-generated
# folder INSIDE a project, nothing to do with this repo's templates/. Without it, two correct
# mentions in object-repository-and-git.md were reported.
$repoLevelPattern = '\.\./Finnova[A-Za-z0-9/._-]*|\.\./Avaloq[A-Za-z0-9/._-]*|' +
                    '\.\./REFramework[A-Za-z0-9/._-]*|(?<!\.)templates/[A-Za-z0-9/._<>-]*|' +
                    '(?<![A-Za-z0-9/.-])docs/[A-Za-z0-9/._-]+|' +
                    '(?<![A-Za-z0-9/.-])evals/[A-Za-z0-9/._-]+'

$simRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("skill-install-sim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $simRoot -Force | Out-Null

try {
    foreach ($d in $skillDirs) {
        $skill = $d.Name

        # The install: this folder, alone, with nothing around it.
        $installed = Join-Path $simRoot $skill
        Copy-Item -LiteralPath $d.FullName -Destination $installed -Recurse -Force

        foreach ($f in Get-ChildItem -LiteralPath $installed -Recurse -File -Include *.md) {
            $rel = $f.FullName.Substring($installed.Length).TrimStart('\', '/')
            $body = Get-Content -LiteralPath $f.FullName -Raw
            if (-not $body) { continue }

            # File-scope escape hatch.
            if ($body -match '(?i)<!--\s*maintainer-provenance\b') { continue }

            # Paragraphs: runs of lines separated by blank lines. A paragraph carrying the
            # phrase is excused as a whole, which is the point - provenance is a statement
            # about a passage, not about one path.
            #
            # Split on a genuinely blank line, NOT on '(?m)^\s*$'. These files are CRLF in the
            # working copy, and \s matches \r, so '^\s*$' matches just before the \r\n of EVERY
            # line - which splits the file into single lines and makes a marker only ever
            # excuse the one line it sits on. That silently defeated most of the labels.
            $paragraphs = [regex]::Split($body, '\r?\n[ \t]*\r?\n')

            # A fenced code block is introduced by the prose above it, so the label on that
            # prose covers the block. Merge a paragraph that opens a fence into the previous
            # one; otherwise a labelled "here is the maintainer-side command:" paragraph fails
            # to cover the command it is labelling.
            $merged = [System.Collections.Generic.List[string]]::new()
            foreach ($p in $paragraphs) {
                if ($merged.Count -gt 0 -and $p -match '^\s*(```|~~~|\$ |    \S)') {
                    $merged[$merged.Count - 1] = $merged[$merged.Count - 1] + "`n" + $p
                }
                else { $merged.Add($p) }
            }
            $paragraphs = $merged.ToArray()

            # --- relative markdown links, code fences removed --------------------
            # `[x](y)` inside a fenced block is not a link; a C# method signature can look
            # exactly like one, and did.
            $prose = $body -replace '(?s)```.*?```', '' -replace '(?s)~~~.*?~~~', ''
            foreach ($m in [regex]::Matches($prose, '\[[^\]]*\]\(([^)\s]+)\)')) {
                $target = $m.Groups[1].Value
                if ($target -match '^(https?:|mailto:|#)') { continue }
                $target = ($target -split '#')[0]
                if (-not $target) { continue }

                $resolved = Join-Path (Split-Path -Parent $f.FullName) $target
                if (Test-Path -LiteralPath $resolved) { continue }

                $para = @($paragraphs | Where-Object { $_ -like "*$($m.Value)*" }) | Select-Object -First 1
                # Whitespace-tolerant: these files wrap at ~98 columns, so the phrase routinely
                # straddles a line break ("**not in your\nproject**"). Matching the literal
                # string silently failed on exactly the passages that had been labelled.
                if ($para -and $para -match '(?is)maintainer\s+provenance|not\s+in\s+your\s+project') { continue }

                Add-Finding error 'install-simulation' $skill `
                    ("$rel links to '$target', which does not exist in a one-skill install. " +
                     'Name the owning skill, use a path relative to this skill folder, or ' +
                     'label the passage "maintainer provenance - not in your project".')
            }

            # --- repo-level path mentions ---------------------------------------
            # Code fences are NOT stripped here: a command example telling someone to read
            # templates/README.md is precisely the defect.
            foreach ($m in [regex]::Matches($body, $repoLevelPattern)) {
                $cited = $m.Value
                $para = @($paragraphs | Where-Object { $_.Contains($cited) }) | Select-Object -First 1
                # Whitespace-tolerant: these files wrap at ~98 columns, so the phrase routinely
                # straddles a line break ("**not in your\nproject**"). Matching the literal
                # string silently failed on exactly the passages that had been labelled.
                if ($para -and $para -match '(?is)maintainer\s+provenance|not\s+in\s+your\s+project') { continue }

                Add-Finding error 'install-simulation' $skill `
                    ("$rel names '$cited', a path that exists in the rpa-ai-skills repo and in " +
                     'no installed project. Either say what the reader should do instead, or ' +
                     'label the passage "maintainer provenance - not in your project".')
            }
        }
    }
}
finally {
    Remove-Item -LiteralPath $simRoot -Recurse -Force -ErrorAction SilentlyContinue
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
