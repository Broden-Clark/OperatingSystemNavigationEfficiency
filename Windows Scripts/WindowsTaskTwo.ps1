# ==============================================================
# WinTaskTwo.ps1 - Times participant in opening internet browser
# ==============================================================

$ErrorActionPreference = 'Stop'

# --- Paths -------------------------------------------------------------
$scriptFolder  = $PSScriptRoot
$projectFolder = Split-Path -Parent $scriptFolder
$dataFolder    = Join-Path $projectFolder 'Data'
$csvPath       = Join-Path $dataFolder 'task_two_windows_results.csv'

# --- Helpers -----------------------------------------------------------
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Text {
    param([string]$Text, [string]$Path, [bool]$Append)
    if ($Append) {
        [System.IO.File]::AppendAllText($Path, $Text, $utf8NoBom)
    } else {
        [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
    }
}

function Get-LineCount {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    # Ignore blank lines so a trailing newline doesn't inflate the count
    return @(Get-Content -LiteralPath $Path | Where-Object { $_.Trim() -ne '' }).Count
}

# Data folder exists?
if (-not (Test-Path -LiteralPath $dataFolder)) {
    New-Item -ItemType Directory -Path $dataFolder -Force | Out-Null
}

# Create CSV with header
if (-not (Test-Path -LiteralPath $csvPath)) {
    Write-Text -Text ("Participant #, Time to Complete`n") -Path $csvPath -Append $false
}

# Header counts as line 1, so the first participant is #1
$participantNumber = Get-LineCount -Path $csvPath

# ============================================================
# TASK
# ============================================================

# Start timer
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Wait for Edge to open (a process with a visible window, so Edge's
# background/startup-boost processes don't trigger an early stop)
do {
    $edgeOpen = @(Get-Process -Name 'msedge' -ErrorAction SilentlyContinue |
                  Where-Object { $_.MainWindowHandle -ne 0 }).Count -gt 0
    if (-not $edgeOpen) { Start-Sleep -Milliseconds 50 }
} until ($edgeOpen)

# Stop the timer
$stopwatch.Stop()
$elapsedTime = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

# Format with exactly 2 decimal places (culture-independent)
$elapsedTimeStr = $elapsedTime.ToString('F2', [System.Globalization.CultureInfo]::InvariantCulture)

# Add result row to the CSV
# Format: "Participant (number), (time)"
#         "Participant 1, 12.34"
#         "Participant 2, 5.07"
$newRow = "Participant $participantNumber, $elapsedTimeStr`n"
Write-Text -Text $newRow -Path $csvPath -Append $true