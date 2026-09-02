<#
.SYNOPSIS
    Fetch one or more REFramework templates out of rpa-ai-skills without cloning the whole repo.

.DESCRIPTION
    Blobless, depth-1, sparse checkout of templates/<name>/ only. The Windows twin of
    fetch-template.sh; behaviour and guardrails are identical.

    Works with no setup: the canonical repo is the default. Override with -RepoUrl, or by
    setting $env:RPA_SKILLS_REPO, when you work from a fork or an internal mirror.
    Precedence: -RepoUrl  >  $env:RPA_SKILLS_REPO  >  default.

.PARAMETER Template
    One or more of REFramework-Dispatcher-Base, REFramework-Performer-Finnova,
    REFramework-Performer-Avaloq. Always take the Dispatcher plus whichever Performer the
    SDD calls for.

.PARAMETER RepoUrl
    Git URL of rpa-ai-skills. Overrides $env:RPA_SKILLS_REPO.
    Defaults to https://github.com/ramesh09laksh-boop/rpa-ai-skills.

.PARAMETER Ref
    Branch or tag to fetch. Defaults to the remote's default branch.

.PARAMETER Destination
    Directory to place the templates in. Defaults to the current directory.

.EXAMPLE
    # Canonical repo, no setup needed:
    .\fetch-template.ps1 -Template REFramework-Dispatcher-Base,REFramework-Performer-Finnova

.EXAMPLE
    # Fork or internal mirror:
    .\fetch-template.ps1 -RepoUrl https://git.internal/rpa-ai-skills.git `
        -Template REFramework-Dispatcher-Base,REFramework-Performer-Finnova
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('REFramework-Dispatcher-Base',
                 'REFramework-Performer-Finnova',
                 'REFramework-Performer-Avaloq')]
    [string[]] $Template,

    # Precedence: this parameter > $env:RPA_SKILLS_REPO > the canonical default.
    [string] $RepoUrl = $(
        if ($env:RPA_SKILLS_REPO) { $env:RPA_SKILLS_REPO }
        else { 'https://github.com/ramesh09laksh-boop/rpa-ai-skills' }
    ),

    [string] $Ref,

    [string] $Destination = '.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is not on PATH.'
}

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    throw ('Repository URL is empty. Unset it to fall back to the default, ' +
           'or pass a real URL to -RepoUrl.')
}

$repoSource = if ($PSBoundParameters.ContainsKey('RepoUrl')) { '-RepoUrl' }
              elseif ($env:RPA_SKILLS_REPO)                  { '$env:RPA_SKILLS_REPO' }
              else                                           { 'default' }

# @() matters: Select-Object -Unique collapses a one-element result to a scalar string,
# and splatting a scalar with @ later does not pass it as a single argument.
$Template = @($Template | Select-Object -Unique)

if (-not (Test-Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
}
$destAbs = (Resolve-Path $Destination).Path

# Refuse to clobber. A re-run must not silently discard work in progress.
foreach ($t in $Template) {
    $target = Join-Path $destAbs $t
    if (Test-Path $target) {
        throw "$target already exists. Move or delete it first."
    }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $work | Out-Null

try {
    $refNote = if ($Ref) { " (ref: $Ref)" } else { '' }
    Write-Host "Fetching from $RepoUrl [$repoSource]$refNote"

    # --sparse checks out root-level files only; sparse-checkout set then adds the
    # directories we actually want. Cone mode (the default) is what populates a whole
    # directory from a path -- --no-cone takes gitignore-style patterns and silently
    # checks out nothing for a bare "/templates/<name>/".
    $repoDir   = Join-Path $work 'repo'
    $cloneArgs = @('clone', '--filter=blob:none', '--sparse', '--depth', '1')
    if ($Ref) { $cloneArgs += @('--branch', $Ref) }
    $cloneArgs += @($RepoUrl, $repoDir)

    $cloneOut = & git @cloneArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $hint = "`n$($cloneOut -join "`n")"
        if ($repoSource -eq 'default') {
            $hint += @"

GitHub reports "not found" both for a repo that does not exist and for a private
repo you are not authenticated to. If this one is private, set up credentials
(gh auth login, SSH key, or a PAT) and retry. If your team works from a fork or an
internal mirror, point at it instead:

  `$env:RPA_SKILLS_REPO = '<your-url>'    # once, per developer
  .\fetch-template.ps1 -RepoUrl '<your-url>' ...   # or per invocation
"@
        }
        throw "Could not clone $RepoUrl [$repoSource] (git exit $LASTEXITCODE).$hint"
    }

    # @() again: a single template must stay an array or the splat below misfires.
    $sparsePaths = @($Template | ForEach-Object { "templates/$_" })

    $sparseOut = & git -C $repoDir sparse-checkout set @sparsePaths 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git sparse-checkout set failed (exit $LASTEXITCODE):`n$($sparseOut -join "`n")"
    }

    foreach ($t in $Template) {
        $src = Join-Path $repoDir "templates\$t"
        if (-not (Test-Path $src)) {
            throw "templates/$t not found in $RepoUrl$refNote."
        }
        Move-Item -Path $src -Destination (Join-Path $destAbs $t)
        Write-Host "  -> $(Join-Path $destAbs $t)"
    }
}
finally {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "Fetched $($Template.Count) template(s). This is scaffolding, not a project yet:"
Write-Host ""
Write-Host "  1. Studio: File > New > Robotic Enterprise Process, Compatibility: Windows"
Write-Host "     (not 'Windows - Legacy'), then copy the fetched project.json, project.uiproj,"
Write-Host "     entry-points.json, Data/ and Tests/ over what Studio generated."
Write-Host "  2. Apply the 'Deltas to apply to the generated skeleton' section in each fetched"
Write-Host "     template's README.md."
Write-Host "  3. Work the instantiation checklist in templates/README.md - project name, fresh"
Write-Host "     GUIDs, every [UC-SPECIFIC - replace] in Config_TST.xlsx AND Config_PRD.xlsx,"
Write-Host "     and the shared queue name."
Write-Host ""
Write-Host 'project.json ships "name": "<PROJECT-NAME-TBD-ask-team>", which fails the'
Write-Host 'publishability check on purpose. Ask the team for the name before the first publish.'
