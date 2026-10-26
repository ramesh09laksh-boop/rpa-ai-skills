#Requires -Version 7.0
<#
.SYNOPSIS
    Checks the environment before a UC build starts, and prints a one-line fix per failure.

.DESCRIPTION
    On a real build run, environment problems cost more time than the automation logic did:
    an unauthenticated git, a UIAutomation version mismatch that makes `uip rpa uia` list zero
    subcommands, a Studio that was never started, a feed the libraries are not on. Each one
    surfaces later as a confusing error about something else.

    This fails early instead, in plain words. It changes nothing - every finding comes with the
    command that fixes it.

    Checks that need a project (the UIAutomation pin, the library feed) are skipped with a note
    when -ProjectPath is not given.

.PARAMETER ProjectPath
    A UC project folder (the one holding project.json). Enables the project-specific checks.

.PARAMETER SkipCapture
    Skip the capture smoke test, which needs a project with matching UIAutomation packages.

.OUTPUTS
    One line per check. Exit code 0 when nothing is blocking, 1 otherwise.

.EXAMPLE
    pwsh -File preflight.ps1
    pwsh -File preflight.ps1 -ProjectPath ./UC99_Something
#>
[CmdletBinding()]
param(
    [string] $ProjectPath,
    [switch] $SkipCapture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$script:Blocking = 0
$script:Warned = 0
$script:StudioHasProject = $false

function Report {
    param(
        [ValidateSet('ok', 'warn', 'fail', 'skip')] [string] $State,
        [string] $Check,
        [string] $Detail,
        [string] $Fix
    )
    $colour = switch ($State) { 'ok' { 'Green' } 'warn' { 'Yellow' } 'fail' { 'Red' } 'skip' { 'DarkGray' } }
    Write-Host ('{0,-6} {1,-26} {2}' -f $State.ToUpper(), $Check, $Detail) -ForegroundColor $colour
    if ($Fix) { Write-Host ('       {0,-26} fix: {1}' -f '', $Fix) -ForegroundColor DarkGray }
    if ($State -eq 'fail') { $script:Blocking++ }
    if ($State -eq 'warn') { $script:Warned++ }
}

function Test-Cmd([string] $name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

Write-Host ''
Write-Host 'Preflight - nothing here changes your machine.' -ForegroundColor Cyan
Write-Host ''

# --- 1. Node, for `npx skills` -------------------------------------------------
if (-not (Test-Cmd 'node')) {
    Report fail 'Node.js' 'not on PATH' 'install Node 22.20 or newer: https://nodejs.org'
}
else {
    $raw = (& node --version 2>$null) -replace '^v', ''
    try {
        $v = [version]$raw
        if ($v -lt [version]'22.20') {
            Report fail 'Node.js' "$raw is too old for the skills CLI" 'install Node 22.20 or newer'
        }
        else { Report ok 'Node.js' $raw }
    }
    catch { Report warn 'Node.js' "could not parse version '$raw'" 'check `node --version` by hand' }
}

# --- 2. git, and GitHub auth (the skills repo is private) ----------------------
if (-not (Test-Cmd 'git')) {
    Report fail 'git' 'not on PATH' 'install Git'
}
else {
    Report ok 'git' ((& git --version 2>$null) -replace '^git version ', '')

    if (Test-Cmd 'gh') {
        & gh auth status *> $null
        if ($LASTEXITCODE -eq 0) { Report ok 'GitHub auth' 'gh is signed in' }
        else {
            Report fail 'GitHub auth' 'gh is not signed in - a private-repo clone or `skills update` will fail' `
                'gh auth login'
        }
    }
    else {
        Report warn 'GitHub auth' 'gh not installed, so auth cannot be confirmed' `
            'install the GitHub CLI and run `gh auth login`, or confirm a VS Code GitHub sign-in / SSH key'
    }
}

# --- 3. PowerShell 7 (validate-project.sh needs it) ---------------------------
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Report ok 'PowerShell 7' $PSVersionTable.PSVersion.ToString()
}
else {
    Report fail 'PowerShell 7' "running $($PSVersionTable.PSVersion) - validate-project needs 7+" `
        'winget install --id Microsoft.PowerShell'
}

# --- 4. the uip CLI, and its login ------------------------------------------
$uipOk = Test-Cmd 'uip'
if (-not $uipOk) {
    Report fail 'uip CLI' 'not on PATH' 'install the UiPath CLI, then re-run this script'
}
else {
    Report ok 'uip CLI' (& uip --version 2>$null)

    $status = $null
    try {
        $json = & uip login status --output json 2>$null | ConvertFrom-Json
        $status = $json.Data.Status
    }
    catch { $status = $null }

    if ($status -eq 'Success' -or $status -eq 'Authenticated') {
        Report ok 'uip login' $status
    }
    elseif ($null -eq $status) {
        Report warn 'uip login' 'could not read login status' 'uip login status'
    }
    else {
        # Not blocking on its own: analyze/build work offline. But Orchestrator feeds are
        # skipped and a tenant governance policy cannot be resolved, which changes what the
        # analyzer actually enforces - so it must not pass silently.
        Report warn 'uip login' "$status - Orchestrator feeds and tenant governance will be skipped" 'uip login'
    }
}

# --- 5. Studio (needed by the Studio-IPC commands: validate, run, uia) --------
$studio = @(
    "$env:ProgramFiles\UiPath\Studio\UiPath.Studio.exe",
    "${env:ProgramFiles(x86)}\UiPath\Studio\UiPath.Studio.exe",
    "$env:LOCALAPPDATA\Programs\UiPath\Studio\UiPath.Studio.exe"
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

if ($studio) {
    Report ok 'UiPath Studio' $studio
    if ($uipOk) {
        try {
            $inst = & uip rpa instances list --output json 2>$null | ConvertFrom-Json
            $running = @($inst.Data)
            $script:StudioHasProject = $false
            if ($running.Count -eq 0) {
                Report warn 'Studio instance' 'none running - validate / run / uia need one' 'uip rpa studio start'
            }
            else {
                $withProject = @($running | Where-Object { $_.ProjectDirectory -and $_.ProjectDirectory -ne '(none)' })
                if ($withProject.Count -eq 0) {
                    Report warn 'Studio instance' `
                        "$($running.Count) running, none with a project open (ProjectDirectory '(none)')" `
                        'open the project in Studio - a run will otherwise fail with "The workflow cannot be found"'
                }
                else {
                    $script:StudioHasProject = $true
                    Report ok 'Studio instance' (($withProject | ForEach-Object { $_.ProjectDirectory }) -join '; ')
                }
            }
        }
        catch { Report warn 'Studio instance' 'could not query instances' 'uip rpa instances list' }
    }
}
else {
    Report warn 'UiPath Studio' 'not found in the usual locations' `
        'needed for L3/L4 and for the Studio-IPC commands; pass --studio-dir if it is installed elsewhere'
}

# --- 6. project-specific checks ----------------------------------------------
if (-not $ProjectPath) {
    Report skip 'project.json checks' 'no -ProjectPath given' 'pass -ProjectPath <project> for the capture-pin and feed checks'
}
elseif (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'project.json'))) {
    Report fail 'project.json' "no project.json in $ProjectPath" 'point -ProjectPath at the folder holding project.json'
}
else {
    $proj = Get-Content -LiteralPath (Join-Path $ProjectPath 'project.json') -Raw | ConvertFrom-Json
    $deps = $proj.dependencies

    # 6a. the capture pin: both UIAutomation packages, both at 26.10.4
    $wanted = '26.10.4'
    $act = $deps.'UiPath.UIAutomation.Activities'
    $cli = $deps.'UiPath.UIAutomation.CLI'
    $norm = { param($v) if ($v) { $v -replace '[\[\]()]', '' } else { $null } }
    $actV = & $norm $act
    $cliV = & $norm $cli

    if (-not $act -and -not $cli) {
        Report skip 'capture pin' 'no UIAutomation packages - this project does not capture selectors' ''
    }
    elseif ($actV -eq $wanted -and $cliV -eq $wanted) {
        Report ok 'capture pin' "Activities and CLI both $wanted"
    }
    else {
        Report fail 'capture pin' `
            ("Activities='$actV' CLI='$cliV' - both must be $wanted. A mismatch makes " +
             '`uip rpa uia` list ZERO subcommands, which reads as the CLI being unavailable') `
            "set both to [$wanted] in project.json and restore"
    }

    # 6b. the banking libraries have to be ON THE FEED, not just referenced
    $libs = @(@('Swisscom.FinnovaLibrary', 'Swisscom.PHI', 'Swisscom.UiPath.UIAutomation.Avaloq') |
        Where-Object { $deps.PSObject.Properties.Name -contains $_ })
    if ($libs.Count -eq 0) {
        Report skip 'library feed' 'no Swisscom library referenced' ''
    }
    elseif (-not $uipOk) {
        Report skip 'library feed' 'uip not available to test a restore' ''
    }
    else {
        Write-Host ('       {0,-26} testing restore of {1}...' -f '', ($libs -join ', ')) -ForegroundColor DarkGray
        & uip rpa restore $ProjectPath *> $null
        if ($LASTEXITCODE -eq 0) { Report ok 'library feed' "restore succeeded ($($libs -join ', '))" }
        else {
            Report fail 'library feed' `
                "restore failed - $($libs -join ', ') may not be published to your feed" `
                'publish the .nupkg(s) to the feed first; do NOT relax the dependency pin or mustRestoreAllDependencies'
        }
    }

    # 6c. capture smoke test
    if ($SkipCapture) {
        Report skip 'capture smoke test' '-SkipCapture given' ''
    }
    elseif (-not $uipOk) {
        Report skip 'capture smoke test' 'uip not available' ''
    }
    else {
        $uiaHelp = & uip rpa uia --project-dir $ProjectPath --help 2>$null | Out-String
        if ($uiaHelp -match '(?m)^\s*│\s*(snapshot|interact|target-app|object-repository)\b') {
            Report ok 'capture smoke test' '`uip rpa uia` lists subcommands'
        }
        elseif (-not $script:StudioHasProject) {
            # Do not call this blocking when the only missing piece is a Studio session - that
            # is the warning two lines up, and reporting it twice as a capture failure sends
            # people to re-check package versions that are already correct.
            Report warn 'capture smoke test' `
                '`uip rpa uia` lists no subcommands - no Studio instance has this project open' `
                'uip rpa studio start, open this project, then re-run'
        }
        else {
            Report fail 'capture smoke test' `
                '`uip rpa uia` lists no subcommands, with a Studio session present' `
                'check the capture pin above: both UIAutomation packages must be 26.10.4, then restore'
        }
    }
}

# --- summary ------------------------------------------------------------------
Write-Host ''
if ($script:Blocking -gt 0) {
    Write-Host "$($script:Blocking) blocking, $($script:Warned) warning(s). Fix the blocking items before starting." -ForegroundColor Red
    exit 1
}
if ($script:Warned -gt 0) {
    Write-Host "0 blocking, $($script:Warned) warning(s). You can start; read the warnings first." -ForegroundColor Yellow
    exit 0
}
Write-Host 'All clear.' -ForegroundColor Green
exit 0
