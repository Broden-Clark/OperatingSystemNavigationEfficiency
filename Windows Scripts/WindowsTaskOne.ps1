# =====================================================================
# WindowsTaskOne.ps1 - Times participant in opening Settings from Notes
# =====================================================================

$ErrorActionPreference = 'Stop'

# --- Paths -------------------------------------------------------------
$scriptFolder  = $PSScriptRoot
$projectFolder = Split-Path -Parent $scriptFolder
$dataFolder    = Join-Path $projectFolder 'Data'
$csvPath       = Join-Path $dataFolder 'task_one_windows_results.csv'

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

function Wait-ForProcessEvent {
    param(
        [string]$ClassName,      # Win32_ProcessStartTrace or Win32_ProcessStopTrace
        [string]$ProcessName,    # e.g. 'notepad.exe', 'SystemSettings.exe'
        [int]$TimeoutSeconds = 0 # 0 = wait forever
    )
    $query = "SELECT * FROM $ClassName WHERE ProcessName = '$ProcessName'"
    $sid = "w_$ProcessName"
    Register-CimIndicationEvent -Query $query -SourceIdentifier $sid | Out-Null
    try {
        if ($TimeoutSeconds -gt 0) {
            $evt = Wait-Event -SourceIdentifier $sid -Timeout $TimeoutSeconds
            return [bool]$evt
        } else {
            Wait-Event -SourceIdentifier $sid | Out-Null
            return $true
        }
    } finally {
        Unregister-Event -SourceIdentifier $sid -ErrorAction SilentlyContinue
        Remove-Event      -SourceIdentifier $sid -ErrorAction SilentlyContinue
    }
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

Write-Host "Participant #$participantNumber  (CSV: $csvPath)"

# ============================================================
# TASK
# ============================================================

$stopwatch = [System.Diagnostics.Stopwatch]::new()

# Start timer when Notes closes
Write-Host "Waiting for Notes (notepad.exe) to close to start the timer..."
Wait-ForProcessEvent -ClassName 'Win32_ProcessStopTrace' -ProcessName 'notepad.exe' | Out-Null

$stopwatch.Start()
Write-Host ("Timer STARTED at {0:HH:mm:ss.fff}" -f (Get-Date))

# Stop timer when Settings opens
Write-Host "Waiting for Settings (SystemSettings.exe) to open to stop the timer..."
Wait-ForProcessEvent -ClassName 'Win32_ProcessStartTrace' -ProcessName 'SystemSettings.exe' | Out-Null

$stopwatch.Stop()
$elapsedTime = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

# Format with exactly 2 decimal places (culture-independent)
$elapsedTimeStr = $elapsedTime.ToString('F2', [System.Globalization.CultureInfo]::InvariantCulture)

Write-Host ("Timer STOPPED at {0:HH:mm:ss.fff}  - elapsed: {1} s" -f (Get-Date), $elapsedTime)

# Add result row to the CSV
# Format: "Participant (number), (time)"
#         "Participant 1, 12.34"
#         "Participant 2, 5.07"
$newRow = "Participant $participantNumber, $elapsedTimeStr`n"
Write-Text -Text $newRow -Path $csvPath -Append $true

Write-Host "Saved row to $csvPath"