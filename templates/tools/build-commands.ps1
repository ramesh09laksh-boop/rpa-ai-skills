#Requires -Version 7.0
<#
.SYNOPSIS
    Generates the slash commands for all three agents this repo supports, from the single
    source of truth in commands/.

.DESCRIPTION
    One command, three formats. The bodies are identical — Claude Code, GitHub Copilot and
    OpenCode all substitute $ARGUMENTS — so the only thing that actually differs is the
    frontmatter and the file path:

      commands/<name>.md  ->  .claude/commands/<name>.md          description, argument-hint
                          ->  .github/prompts/<name>.prompt.md    description, argument-hint
                          ->  .opencode/commands/<name>.md        description

    OpenCode's documented frontmatter is description / agent / model / subagent — there is no
    argument-hint field, so it is dropped rather than emitted as an unknown key. Folder names
    and fields were read off each product's current docs on 2026-11-23, not guessed:
    code.claude.com/docs/en/slash-commands, code.visualstudio.com/docs/copilot/customization/
    prompt-files, opencode.ai/docs/commands. OpenCode's folder is PLURAL (`commands/`); the
    legacy singular `command/` is still discovered but is not what new files should use.

    Same rule as build-template-workbooks.ps1: EDIT THE SOURCE, NOT THE OUTPUT. A hand-edit to
    a generated file is overwritten the next time anyone runs this, and CI fails any PR whose
    generated files do not match a re-run.

    Every generated file carries a GENERATED comment, and that marker is also what makes
    cleanup safe: a stale output whose source has been deleted is removed only if it carries
    the marker, so a hand-written command living in the same folder is never touched.

.PARAMETER RepoRoot
    Defaults to the repository root, two levels above this script.

.PARAMETER Check
    Generate into a temporary directory and compare, instead of writing. Exit 1 on any
    difference. Writes nothing.

.EXAMPLE
    pwsh -NoProfile -File templates/tools/build-commands.ps1

.EXAMPLE
    pwsh -NoProfile -File templates/tools/build-commands.ps1 -Check
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$sourceDir = Join-Path $RepoRoot 'commands'

if (-not (Test-Path -LiteralPath $sourceDir)) {
    Write-Error "No commands/ directory at $sourceDir"
    exit 2
}

# The only frontmatter keys a source file may carry. An unknown key is an error, not a silent
# drop: a typo'd `descriptoin:` would otherwise ship a command with no description, which is
# the one field that decides whether anyone ever finds it in the `/` menu.
$knownKeys = @('description', 'argument-hint')

$targets = @(
    [pscustomobject]@{
        Agent  = 'Claude Code'
        Dir    = Join-Path $RepoRoot '.claude/commands'
        Suffix = '.md'
        Fields = @('description', 'argument-hint')
    }
    [pscustomobject]@{
        Agent  = 'GitHub Copilot'
        Dir    = Join-Path $RepoRoot '.github/prompts'
        Suffix = '.prompt.md'
        Fields = @('description', 'argument-hint')
    }
    [pscustomobject]@{
        Agent  = 'OpenCode'
        Dir    = Join-Path $RepoRoot '.opencode/commands'
        Suffix = '.md'
        Fields = @('description')
    }
)

function Read-CommandSource {
    param([Parameter(Mandatory)] [System.IO.FileInfo] $File)

    $raw = [System.IO.File]::ReadAllText($File.FullName)
    $m = [regex]::Match($raw, '(?s)\A---\r?\n(.*?)\r?\n---\r?\n(.*)\z')
    if (-not $m.Success) {
        throw "$($File.Name): no --- frontmatter block. Every command needs at least a description."
    }

    $fm = [ordered]@{}
    foreach ($line in ($m.Groups[1].Value -split '\r?\n')) {
        if (-not $line.Trim()) { continue }
        $kv = [regex]::Match($line, '^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$')
        if (-not $kv.Success) {
            throw "$($File.Name): frontmatter line is not 'key: value' -> $line"
        }
        $key = $kv.Groups[1].Value
        if ($key -notin $knownKeys) {
            throw "$($File.Name): unknown frontmatter key '$key'. Allowed: $($knownKeys -join ', ')."
        }
        # Strip one layer of surrounding quotes; the generator re-quotes per target.
        $val = $kv.Groups[2].Value.Trim() -replace '^"(.*)"$', '$1' -replace "^'(.*)'$", '$1'
        $fm[$key] = $val
    }

    if (-not $fm.Contains('description') -or -not $fm['description'].Trim()) {
        throw "$($File.Name): description is required - it is the only thing shown in the / menu."
    }

    # Normalise to LF so the output is byte-identical on every platform. .gitattributes has
    # `* text=auto`, so git normalises the index anyway and CI diffs with --ignore-cr-at-eol.
    $body = ($m.Groups[2].Value -replace "`r`n", "`n").Trim() + "`n"

    [pscustomobject]@{
        Name        = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
        Frontmatter = $fm
        Body        = $body
    }
}

function Format-Command {
    param(
        [Parameter(Mandatory)] [object] $Command,
        [Parameter(Mandatory)] [object] $Target
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("---`n")
    foreach ($field in $Target.Fields) {
        if (-not $Command.Frontmatter.Contains($field)) { continue }
        $value = $Command.Frontmatter[$field]
        # A description is a line of prose that routinely contains a colon, a backtick or an
        # em-dash, so it is always quoted rather than emitted bare. SINGLE quotes: in YAML they
        # are literal, so the only character needing an escape is the apostrophe itself, which
        # doubles. That keeps every description valid whatever it says, with no backslashes.
        $quoted = "'" + ($value -replace "'", "''") + "'"
        [void]$sb.Append("${field}: $quoted`n")
    }
    [void]$sb.Append("---`n`n")
    [void]$sb.Append("<!-- GENERATED by templates/tools/build-commands.ps1 from commands/$($Command.Name).md - do not edit by hand. -->`n`n")
    [void]$sb.Append($Command.Body)
    $sb.ToString()
}

$marker = 'GENERATED by templates/tools/build-commands.ps1'

$sources = @(Get-ChildItem -LiteralPath $sourceDir -File -Filter '*.md' |
    Where-Object { $_.Name -ne 'README.md' } | Sort-Object Name)

if ($sources.Count -eq 0) {
    Write-Error "No command sources in $sourceDir"
    exit 2
}

$commands = @($sources | ForEach-Object { Read-CommandSource -File $_ })

$differences = [System.Collections.Generic.List[string]]::new()
$written = 0

foreach ($target in $targets) {
    Write-Host "$($target.Agent) -> $(($target.Dir).Substring($RepoRoot.Length).TrimStart('\','/'))"

    if (-not $Check -and -not (Test-Path -LiteralPath $target.Dir)) {
        New-Item -ItemType Directory -Path $target.Dir -Force | Out-Null
    }

    $expected = @{}
    foreach ($cmd in $commands) {
        $path = Join-Path $target.Dir ($cmd.Name + $target.Suffix)
        $expected[$path] = Format-Command -Command $cmd -Target $target
    }

    foreach ($path in ($expected.Keys | Sort-Object)) {
        $content = $expected[$path]
        $current = if (Test-Path -LiteralPath $path) {
            ([System.IO.File]::ReadAllText($path) -replace "`r`n", "`n")
        }
        else { $null }

        if ($current -ceq $content) {
            if (-not $Check) { Write-Host "  = $(Split-Path -Leaf $path)" }
            continue
        }

        if ($Check) {
            $differences.Add(($path.Substring($RepoRoot.Length).TrimStart('\', '/')))
            continue
        }

        [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  wrote $(Split-Path -Leaf $path)"
        $written++
    }

    # Stale outputs: a command that was renamed or deleted. Only files carrying the marker are
    # removed, so a hand-written command sharing the folder survives.
    if (Test-Path -LiteralPath $target.Dir) {
        foreach ($f in Get-ChildItem -LiteralPath $target.Dir -File -Filter ('*' + $target.Suffix)) {
            if ($expected.ContainsKey($f.FullName)) { continue }
            $body = [System.IO.File]::ReadAllText($f.FullName)
            if ($body -notmatch [regex]::Escape($marker)) { continue }
            if ($Check) {
                $differences.Add(($f.FullName.Substring($RepoRoot.Length).TrimStart('\', '/')) + ' (stale)')
            }
            else {
                Remove-Item -LiteralPath $f.FullName -Force
                Write-Host "  removed stale $($f.Name)"
            }
        }
    }
}

Write-Host ''

if ($Check) {
    if ($differences.Count -gt 0) {
        Write-Host 'The generated commands do not match commands/:' -ForegroundColor Red
        foreach ($d in $differences) { Write-Host "  $d" -ForegroundColor Red }
        Write-Host ''
        Write-Host 'Edit commands/<name>.md, then re-run templates/tools/build-commands.ps1.'
        exit 1
    }
    Write-Host "In sync: $($commands.Count) command(s) x $($targets.Count) agent(s)."
    exit 0
}

Write-Host "Done. $($commands.Count) command(s) x $($targets.Count) agent(s); $written file(s) written."
