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

.PARAMETER FolderPath
    Orchestrator folder path (e.g. "Modern/RAP-Demo"). Checks the folder, process, assets and
    queue an end-to-end run needs. This estate is Automation Suite, so `uip login` must have
    been pointed at its host with --authority. Most robot-side prerequisites are NOT scriptable
    from a developer machine - see standards/references/end-to-end-run.md Part 1.

.OUTPUTS
    One line per check. Exit code 0 when nothing is blocking, 1 otherwise.

.EXAMPLE
    pwsh -File preflight.ps1
    pwsh -File preflight.ps1 -ProjectPath ./UC99_Something
#>
[CmdletBinding()]
param(
    [string] $ProjectPath,
    [switch] $SkipCapture,

    # An Orchestrator folder path, e.g. "Modern/RAP-Demo". Enables the L4 readiness checks:
    # does the folder exist, and does it hold a process, the Assets-sheet assets and the queue.
    # Needs `uip login` against the Automation Suite host first.
    [string] $FolderPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$script:Blocking = 0
$script:Warned = 0
$script:StudioHasProject = $false
$script:AssetKeys = @()      # Assets-sheet row names, if we can read them
$script:QueueName = $null    # configured OrchestratorQueueName, if we can read it

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
    Report ok 'uip CLI (host)' (& uip --version 2>$null)

    # `uip` is a host plus separately-versioned tools that update INDEPENDENTLY, and a tool
    # auto-installs on first use. That is not trivia: on this machine rpa-tool was rewritten
    # mid-day between two agent sessions, and the verb names differed either side of it
    # (search-templates/create-project vs templates search/init). So print the tool versions,
    # and compare rpa-tool against whatever the project recorded.
    $rpaToolVersion = $null
    try {
        $tools = & uip tools list --output json 2>$null | ConvertFrom-Json
        foreach ($t in @($tools.Data)) {
            $line = "$($t.Name) $($t.Version) [$($t.CommandPrefix)] $($t.Status)"
            if ($t.Name -eq 'rpa-tool') { $rpaToolVersion = $t.Version }
            if ($t.Status -eq 'ok') { Report ok "  tool: $($t.Name)" "$($t.Version) (prefix '$($t.CommandPrefix)')" }
            else {
                Report warn "  tool: $($t.Name)" "$($t.Version) - status '$($t.Status)'" `
                    'do NOT run `uip tools update` mid-project; update between projects and record the versions'
            }
        }
    }
    catch { Report warn 'uip tools list' 'could not read the tool versions' 'uip tools list' }

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

# --- 4b. rpa-tool version vs what the project recorded ------------------------
# A tool change mid-project silently alters verb names and flags. Progress.md is where the
# project records what it was built against; this is the comparison that makes a change visible
# rather than mysterious.
if ($ProjectPath -and $rpaToolVersion) {
    $progress = Join-Path $ProjectPath 'Documentation/Progress.md'
    if (-not (Test-Path -LiteralPath $progress)) {
        Report skip 'rpa-tool vs Progress.md' 'no Documentation/Progress.md to compare against' `
            "record `"rpa-tool: $rpaToolVersion`" in Documentation/Progress.md"
    }
    else {
        $txt = Get-Content -LiteralPath $progress -Raw
        $m = [regex]::Match($txt, '(?im)rpa-tool\s*[:=]?\s*v?([0-9]+\.[0-9]+\.[0-9]+)')
        if (-not $m.Success) {
            Report warn 'rpa-tool vs Progress.md' "Progress.md records no rpa-tool version (running $rpaToolVersion)" `
                "add `"rpa-tool: $rpaToolVersion`" to Documentation/Progress.md"
        }
        elseif ($m.Groups[1].Value -ne $rpaToolVersion) {
            Report fail 'rpa-tool vs Progress.md' `
                ("Progress.md records rpa-tool $($m.Groups[1].Value) but $rpaToolVersion is installed. " +
                 'Verb names and flags may have changed under this project') `
                'recheck the commands you rely on with --help, then update Progress.md'
        }
        else { Report ok 'rpa-tool vs Progress.md' "both $rpaToolVersion" }
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

    # Read the Assets rows and the queue name from Data/config-contents.md - the generated,
    # diffable rendering of the workbooks. Deliberately NOT a second OOXML reader: one
    # implementation of that lives in validate-project.ps1 and two would drift. When the
    # rendering is absent the folder checks degrade to a count rather than a comparison, which
    # is stated in their output rather than silently assumed.
    $contents = Join-Path $ProjectPath 'Data/config-contents.md'
    if (Test-Path -LiteralPath $contents) {
        $md = Get-Content -LiteralPath $contents -Raw
        $assetsSection = [regex]::Match($md, '(?s)##\s*`?Assets`?\s*sheet(.*?)(?=
##\s|\z)')
        if ($assetsSection.Success) {
            $script:AssetKeys = @([regex]::Matches($assetsSection.Groups[1].Value, '(?m)^\|\s*([A-Za-z0-9_][^|]*?)\s*\|') |
                ForEach-Object { $_.Groups[1].Value.Trim() } |
                Where-Object { $_ -and $_ -notin @('Name', 'Asset') -and $_ -notmatch '^-+$' })
        }
        $qm = [regex]::Match($md, '(?m)^\|\s*OrchestratorQueueName\s*\|\s*([^|]+?)\s*\|')
        if ($qm.Success) {
            $v = $qm.Groups[1].Value.Trim()
            if ($v -and $v -notmatch 'UC-SPECIFIC|not used|^\*?\(empty\)') { $script:QueueName = $v }
        }
    }

    # 6a. the capture pin: both UIAutomation packages, both at 26.10.4
    #
    # Read via PSObject.Properties, not dot-access: under Set-StrictMode, $deps.'Missing.Key'
    # THROWS rather than returning $null, and a project with no UIAutomation dependency at all
    # (the Dispatcher template is exactly that) is the normal case this check has to survive.
    $wanted = '26.10.4'
    $depNames = @($deps.PSObject.Properties.Name)
    $act = if ('UiPath.UIAutomation.Activities' -in $depNames) { $deps.'UiPath.UIAutomation.Activities' } else { $null }
    $cli = if ('UiPath.UIAutomation.CLI' -in $depNames) { $deps.'UiPath.UIAutomation.CLI' } else { $null }
    $norm = { param($v) if ($v) { $v -replace '[\[\]()]', '' } else { $null } }
    $actV = & $norm $act
    $cliV = & $norm $cli

    # No UiPath.UIAutomation.CLI means this project does not capture selectors - `uip rpa uia`
    # needs that package. Several templates legitimately carry UIAutomation.Activities (for UI
    # activities at runtime) without the CLI, so keying the skip on Activities alone reported a
    # blocking failure on the Dispatcher template, which never captures anything.
    if (-not $cli) {
        $detail = if ($act) {
            "no UiPath.UIAutomation.CLI - this project does not capture selectors (Activities is $actV)"
        } else { 'no UIAutomation packages - this project does not capture selectors' }
        Report skip 'capture pin' $detail 'to enable capture, add BOTH packages at 26.10.4'
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

# --- 7. Orchestrator folder readiness (L4) ------------------------------------
# Only what is genuinely checkable from here. The robot-side prerequisites - robot version vs
# package pins, the robot's own package sources, an interactive session, the browser extension
# for the service account, the application being reachable from the robot machine - cannot be
# established from a developer machine and are listed as manual in
# standards/references/end-to-end-run.md. Do not let a green preflight imply they hold.
if (-not $FolderPath) {
    Report skip 'Orchestrator folder' 'no -FolderPath given' 'pass -FolderPath "Modern/RAP-Demo" for the L4 readiness checks'
}
elseif (-not $uipOk) {
    Report skip 'Orchestrator folder' 'uip not available' ''
}
elseif ($status -ne 'Success' -and $status -ne 'Authenticated') {
    Report warn 'Orchestrator folder' "cannot query - uip login status is '$status'" `
        'uip login --authority <automation-suite-host> --tenant <tenant>'
}
else {
    $folderOk = $false
    try {
        $f = & uip or folders list --output json 2>$null | ConvertFrom-Json
        $names = @($f.Data | ForEach-Object { $_.FullyQualifiedName })
        if ($FolderPath -in $names) { Report ok 'Orchestrator folder' $FolderPath; $folderOk = $true }
        else {
            Report fail 'Orchestrator folder' "'$FolderPath' not found among $($names.Count) visible folder(s)" `
                'check the path, or that your identity has access to it'
        }
    }
    catch { Report warn 'Orchestrator folder' 'could not list folders' 'uip or folders list' }

    if ($folderOk) {
        # process
        try {
            $pr = & uip or processes list --folder-path $FolderPath --output json 2>$null | ConvertFrom-Json
            $n = @($pr.Data).Count
            if ($n -gt 0) { Report ok 'process in folder' "$n process(es)" }
            else { Report warn 'process in folder' 'none - nothing to start a job from' 'uip rpa pack, uip or packages upload, uip or processes create' }
        }
        catch { Report warn 'process in folder' 'could not list processes' "uip or processes list --folder-path `"$FolderPath`"" }

        # assets, compared against the project's Assets sheet when we have one
        try {
            $as = & uip or assets list --folder-path $FolderPath --output json 2>$null | ConvertFrom-Json
            $have = @($as.Data | ForEach-Object { $_.Name })
            if ($ProjectPath -and $script:AssetKeys -and $script:AssetKeys.Count -gt 0) {
                $missing = @($script:AssetKeys | Where-Object { $_ -notin $have })
                if ($missing.Count -eq 0) { Report ok 'assets in folder' "all $($script:AssetKeys.Count) Assets-sheet row(s) exist" }
                else {
                    Report fail 'assets in folder' ("missing: " + ($missing -join ', ')) `
                        'create them in Orchestrator - a person, not an agent; InitAllSettings resolves every Assets row at startup'
                }
            }
            else { Report ok 'assets in folder' "$($have.Count) asset(s) visible (no Assets sheet read to compare)" }
        }
        catch { Report warn 'assets in folder' 'could not list assets' "uip or assets list --folder-path `"$FolderPath`"" }

        # queue, compared against the configured OrchestratorQueueName when we have one
        try {
            $q = & uip or queues list --folder-path $FolderPath --output json 2>$null | ConvertFrom-Json
            $qnames = @($q.Data | ForEach-Object { $_.Name })
            if ($script:QueueName) {
                if ($script:QueueName -in $qnames) { Report ok 'queue in folder' $script:QueueName }
                else {
                    Report fail 'queue in folder' "'$($script:QueueName)' not found among $($qnames.Count) queue(s)" `
                        'create it, or fix OrchestratorQueueName - a mismatch throws nothing and leaves both jobs green'
                }
            }
            else { Report skip 'queue in folder' 'no OrchestratorQueueName read from config' '' }
        }
        catch { Report warn 'queue in folder' 'could not list queues' "uip or queues list --folder-path `"$FolderPath`"" }
    }

    Report skip 'robot-side prerequisites' 'not checkable from a developer machine' `
        'robot version vs package pins, the robot package sources, interactive session, browser extension for the service account, app reachability - see standards/references/end-to-end-run.md Part 1'
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
