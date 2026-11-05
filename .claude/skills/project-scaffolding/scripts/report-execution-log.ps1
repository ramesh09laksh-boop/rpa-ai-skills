#Requires -Version 7.0
<#
.SYNOPSIS
    Reports the outcome of a local UiRobot run out of the execution log.

.DESCRIPTION
    `UiRobot execute` returns exit code 0 and prints `{}` on a run whose transaction FAILED. It
    returns exactly the same on a run that succeeded - observed over seven runs on 2026-11-04,
    two of them faulted. The exit status and stdout carry NO outcome information at all, so the
    execution log is the only source. See the `standards` skill, `references/end-to-end-run.md`,
    Step 2a.

    This is a REPORTER. It reads; it decides nothing. Its job is to put the per-transaction
    status table and every Warn/Error in front of a person, because the thing it replaces -
    `if ($LASTEXITCODE -eq 0) { "PASS" }` - is a silent false pass.

    The exit code is a CI convenience and nothing more. Do not build the habit this script exists
    to break: read the table.

.PARAMETER Mark
    Print the log's current byte length and exit. Capture it, run the robot, then pass it back as
    -Offset. The daily log is shared by every run on the machine; an offset is what makes "this
    run" mean anything.

.PARAMETER Offset
    Byte offset recorded by an earlier -Mark. Only what was appended after it is read.

.PARAMETER LogPath
    Defaults to %LOCALAPPDATA%\UiPath\Logs\<yyyy-MM-dd>_Execution.log. Pass it explicitly when
    the run crossed midnight, or to re-read an older day.

.OUTPUTS
    The run header, the per-transaction status table, and every Warn/Error line in the slice.
    Exit 0 when no transaction faulted, 1 when one did.

.EXAMPLE
    # the three steps, in one shell
    $mark = ./report-execution-log.ps1 -Mark
    & "C:\Program Files\UiPath\Studio\UiRobot.exe" execute --file $pkg --input '{"in_ENV":"TST"}'
    ./report-execution-log.ps1 -Offset $mark
#>
[CmdletBinding(DefaultParameterSetName = 'Report')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Mark')]
    [switch] $Mark,

    [Parameter(ParameterSetName = 'Report')]
    [long] $Offset = 0,

    [string] $LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $LogPath) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    $LogPath = Join-Path $localAppData ('UiPath\Logs\{0}_Execution.log' -f (Get-Date -Format 'yyyy-MM-dd'))
}

# ---------------------------------------------------------------------------
# -Mark: the log may not exist yet. A run on a machine whose first UiPath
# activity of the day is this one starts the file, so "missing" means 0 rather
# than being an error.
# ---------------------------------------------------------------------------
if ($Mark) {
    if (Test-Path -LiteralPath $LogPath) { (Get-Item -LiteralPath $LogPath).Length }
    else { 0L }
    return
}

if (-not (Test-Path -LiteralPath $LogPath)) {
    Write-Host "No execution log at $LogPath" -ForegroundColor Yellow
    Write-Host '  Nothing ran, the robot wrote somewhere else, or the run crossed midnight -'
    Write-Host '  pass -LogPath explicitly for the other day. This is NOT a pass.'
    exit 1
}

# ---------------------------------------------------------------------------
# Read only what was appended.
#
# Seek on a FileStream, not Get-Content -Tail: the offset is in BYTES because
# that is what -Mark can measure without parsing, and the file starts with a
# UTF-8 BOM that a line-based tail would have to account for anyway.
#
# A file SHORTER than the offset means it was replaced or truncated between the
# two calls (a new day, a cleared log). Saying so beats silently reporting the
# whole file as if it were one run.
# ---------------------------------------------------------------------------
$length = (Get-Item -LiteralPath $LogPath).Length
$truncated = $false
if ($Offset -gt $length) {
    $truncated = $true
    $Offset = 0
}

$fs = [System.IO.File]::Open($LogPath, 'Open', 'Read', 'ReadWrite')
try {
    [void] $fs.Seek($Offset, 'Begin')
    $sr = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8, $true)
    try { $slice = $sr.ReadToEnd() } finally { $sr.Dispose() }
}
finally { $fs.Dispose() }

$lines = @($slice -split '\r?\n' | Where-Object { $_.Trim() })

# Each line is "<time> <Level> {json}". The JSON is what carries the fields that
# matter; the prefix is a convenience for humans reading the raw file.
$events = foreach ($line in $lines) {
    $brace = $line.IndexOf('{')
    if ($brace -lt 0) { continue }
    try { $line.Substring($brace) | ConvertFrom-Json } catch { continue }
}
$events = @($events)

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
function Field { param($e, [string] $n) if ($e.PSObject.Properties[$n]) { $e.$n } else { $null } }

Write-Host ''
Write-Host "Execution log : $LogPath"
Write-Host "Slice         : bytes $Offset..$length  ($($lines.Count) line(s), $($events.Count) parsed)"
if ($truncated) {
    Write-Host '  WARNING: the log was shorter than the offset - replaced or truncated since -Mark.' -ForegroundColor Yellow
    Write-Host '           Read from 0 instead, so this slice may contain more than your run.' -ForegroundColor Yellow
}

if (-not $events) {
    Write-Host ''
    Write-Host 'Nothing was appended to the log in this slice.' -ForegroundColor Yellow
    Write-Host '  The robot never started, or it logged somewhere else. This is NOT a pass.'
    exit 1
}

# Which jobs are in the slice. This is also the honest caveat: an offset bounds
# the slice in TIME, not by author.
$jobs = @($events | ForEach-Object { Field $_ 'jobId' } | Where-Object { $_ } | Sort-Object -Unique)
$procs = @($events | ForEach-Object { Field $_ 'processName' } | Where-Object { $_ } | Sort-Object -Unique)
Write-Host "Process(es)   : $(($procs -join ', '))"
Write-Host "Job id(s)     : $(($jobs -join ', '))"

if ($jobs.Count -gt 1) {
    Write-Host ''
    Write-Host "  NOTE: $($jobs.Count) job ids in this slice." -ForegroundColor Yellow
    Write-Host '  The offset bounds the slice in TIME, not by author. This log is shared by every'
    Write-Host '  UiPath process on the machine, so if another robot or a Studio debug ran in the'
    Write-Host '  same window, its lines are here too. THIS SCRIPT CANNOT PROVE WHICH JOB WROTE'
    Write-Host '  WHICH LINE beyond the job id printed above - check that the id is yours before'
    Write-Host '  quoting any of this as evidence.'
}

# --- per-transaction status ---------------------------------------------------
# logF_TransactionNumber / logF_TransactionStatus are REFramework's own fields,
# written by SetTransactionStatus and RetryCurrentTransaction. A run that never
# reached a transaction has neither, which is itself worth seeing.
$txEvents = @($events | Where-Object { Field $_ 'logF_TransactionStatus' })
$transactions = @(
    $txEvents |
        Group-Object { '{0}|{1}' -f (Field $_ 'jobId'), (Field $_ 'logF_TransactionNumber') } |
        ForEach-Object {
            $last = $_.Group[-1]
            [pscustomobject]@{
                Job         = (Field $last 'jobId')
                Number      = (Field $last 'logF_TransactionNumber')
                Id          = (Field $last 'logF_TransactionID')
                Status      = (Field $last 'logF_TransactionStatus')
            }
        } | Sort-Object Job, { [int]::TryParse([string]$_.Number, [ref]$null) ? [int]$_.Number : 0 }
)

Write-Host ''
Write-Host '--- transactions ---'
if (-not $transactions) {
    Write-Host '  none - no logF_TransactionStatus in this slice.' -ForegroundColor Yellow
    Write-Host '  A run that processed ZERO transactions is a failure unless the SDD says an empty'
    Write-Host '  source is a valid outcome. See silent-failure-traps.md.'
}
else {
    $transactions | Format-Table -AutoSize @{L = 'Txn'; E = { $_.Number } },
        @{L = 'Status'; E = { $_.Status } },
        @{L = 'TransactionID'; E = { $_.Id } },
        @{L = 'Job'; E = { if ($_.Job) { $_.Job.Substring(0, 8) } else { '' } } } | Out-Host
}

# --- every Warn and Error ----------------------------------------------------
$problems = @($events | Where-Object {
        $lvl = Field $_ 'level'
        $lvl -in 'Warn', 'Warning', 'Error', 'Fatal', 'Critical'
    })

Write-Host "--- Warn / Error ($($problems.Count)) ---"
if (-not $problems) { Write-Host '  none' -ForegroundColor Green }
foreach ($p in $problems) {
    $lvl = Field $p 'level'
    $colour = if ($lvl -like 'Warn*') { 'Yellow' } else { 'Red' }
    # ConvertFrom-Json parses an ISO 8601 string into a [DateTime], so there is no 'T' left to
    # split on and a string-based reading prints the DATE. Handle the typed case first.
    $ts = Field $p 'timeStamp'
    $when =
        if ($ts -is [datetime]) { $ts.ToString('HH:mm:ss') }
        elseif ($ts -is [datetimeoffset]) { $ts.ToString('HH:mm:ss') }
        elseif ($ts) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse([string]$ts, [ref]$parsed)) { $parsed.ToString('HH:mm:ss') }
            else { ([string]$ts -split 'T')[-1] }
        }
        else { '--:--:--' }
    $file = Field $p 'fileName'
    Write-Host ("  [{0}] {1,-8} {2}" -f $when, $lvl, $file) -ForegroundColor $colour
    # Full message, indented. Never truncated: the closest-match list in a selector failure is
    # the part that tells you which window it actually found.
    foreach ($ml in ((Field $p 'message') -split '\r?\n')) {
        Write-Host ("            {0}" -f $ml) -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# Exit code - a CI convenience, and deliberately narrow.
#
# Non-zero ONLY on a faulted transaction. An Error line alone does not fail the
# run here: a classified-and-retried transaction that eventually succeeds logs
# Errors on the way, and failing on those would make the script cry wolf.
#
# WHAT THIS MEANS, and it is a real limitation rather than a quibble: a run that
# died BEFORE reaching a transaction - InitAllSettings, a missing asset, a login
# that never completed - has no faulted transaction and exits 0 here. The empty
# transaction table above is the signal for that case, which is why the table is
# printed first and why this is a reporter.
# ---------------------------------------------------------------------------
$faulted = @($transactions | Where-Object { $_.Status -and $_.Status -ne 'Success' })

Write-Host ''
if ($faulted) {
    Write-Host "FAULTED: $($faulted.Count) transaction(s) - $(($faulted | ForEach-Object { "#$($_.Number) $($_.Status)" }) -join ', ')" -ForegroundColor Red
    Write-Host 'Exit 1.'
    exit 1
}

Write-Host "No faulted transaction in this slice. $($transactions.Count) transaction(s), $($problems.Count) Warn/Error line(s)." -ForegroundColor Green
Write-Host 'Exit 0 - which means "nothing faulted", NOT "the run was correct". Correctness is the'
Write-Host 'SDD acceptance table, with the application state read back independently of these logs.'
exit 0
