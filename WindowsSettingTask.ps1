# WindowsSettingTask.ps1
# Start timer when "Notes" closes; stop when "Settings" opens.

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$csvPath      = Join-Path $scriptFolder 'task_one_windows_results.csv'
$participantNumber = 1
if (Test-Path $csvPath) {
    $existingContent = Get-Content -LiteralPath $csvPath -ErrorAction SilentlyContinue
    if ($null -ne $existingContent) {
        # Get-Content returns an array of lines; a single line returns a string
        $lineCount = @($existingContent).Count
        $participantNumber = $lineCount   # header counted, same as original
    }
}

Write-Host "Participant #$participantNumber  (CSV: $csvPath)"

# ---------- Helpers ----------
$stopwatch = [System.Diagnostics.Stopwatch]::new()
$started   = $false

function Wait-ForProcessEvent {
    param(
        [string]$ClassName,      # Win32_ProcessStartTrace or Win32_ProcessStopTrace
        [string]$ProcessName,    # e.g. 'notepad.exe', 'SystemSettings.exe'
        [int]$TimeoutSeconds = 0 # 0 = wait forever
    )
    $query = "SELECT * FROM $ClassName WHERE ProcessName = '$ProcessName'"
    if ($TimeoutSeconds -gt 0) {
        $watcher = Register-CimIndicationEvent -Query $query -SourceIdentifier "w_$ProcessName" -ErrorAction Stop
        try {
            $evt = Wait-Event -SourceIdentifier "w_$ProcessName" -Timeout $TimeoutSeconds
            if ($evt) { return $true } else { return $false }
        } finally {
            Unregister-Event -SourceIdentifier "w_$ProcessName" -ErrorAction SilentlyContinue
            Remove-Event      -SourceIdentifier "w_$ProcessName" -ErrorAction SilentlyContinue
        }
    } else {
        Register-CimIndicationEvent -Query $query -SourceIdentifier "w_$ProcessName" | Out-Null
        try {
            Wait-Event -SourceIdentifier "w_$ProcessName" | Out-Null
            return $true
        } finally {
            Unregister-Event -SourceIdentifier "w_$ProcessName" -ErrorAction SilentlyContinue
            Remove-Event      -SourceIdentifier "w_$ProcessName" -ErrorAction SilentlyContinue
        }
    }
}

# Start timer when Notes closes
Write-Host "Waiting for Notes (notepad.exe) to close to start the timer..."
Wait-ForProcessEvent -ClassName 'Win32_ProcessStopTrace' -ProcessName 'notepad.exe' | Out-Null

$stopwatch.Start()
$started = $true
Write-Host ("Timer STARTED at {0:HH:mm:ss.fff}" -f (Get-Date))

# Stop timer when Settings opens
Write-Host "Waiting for Settings (SystemSettings.exe) to open to stop the timer..."
Wait-ForProcessEvent -ClassName 'Win32_ProcessStartTrace' -ProcessName 'SystemSettings.exe' | Out-Null

$stopwatch.Stop()
$elapsedTime = [math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
Write-Host ("Timer STOPPED at {0:HH:mm:ss.fff}  — elapsed: {1} s" -f (Get-Date), $elapsedTime)

# Append the result row
if (-not (Test-Path $csvPath)) {
    'Participant #, Time to Complete' | Out-File -LiteralPath $csvPath -Encoding UTF8
}

# Original built "Participant N  –  Elapsed: X seconds (saved to <csv>)"
# and appended it as a new row. We mirror the row shape: participantNumber,elapsedTime
"$participantNumber,$elapsedTime" | Out-File -LiteralPath $csvPath -Encoding UTF8 -Append

Write-Host "Saved row -> $csvPath"