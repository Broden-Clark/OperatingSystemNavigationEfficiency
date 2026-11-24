# =====================================================================
# WindowsTaskOne.ps1 - Times participant in opening Settings from Notes
# =====================================================================

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$dataFolder   = Join-Path (Split-Path -Parent $scriptFolder) 'Data'
$csvPath      = Join-Path $dataFolder 'task_one_windows_results.csv'
$participantNumber = 1
if (Test-Path $csvPath) {
    $existingContent = Get-Content -LiteralPath $csvPath -ErrorAction SilentlyContinue
    if ($null -ne $existingContent) {
        $lineCount = @($existingContent).Count
        $participantNumber = $lineCount   # header counted, same as original
    }
}

Write-Host "Participant #$participantNumber  (CSV: $csvPath)"

# Helpers
$stopwatch = [System.Diagnostics.Stopwatch]::new()

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

# Start timer when Notes closes
Write-Host "Waiting for Notes (notepad.exe) to close to start the timer..."
Wait-ForProcessEvent -ClassName 'Win32_ProcessStopTrace' -ProcessName 'notepad.exe' | Out-Null

$stopwatch.Start()
Write-Host ("Timer STARTED at {0:HH:mm:ss.fff}" -f (Get-Date))

# Stop timer when Settings opens
Write-Host "Waiting for Settings (SystemSettings.exe) to open to stop the timer..."
Wait-ForProcessEvent -ClassName 'Win32_ProcessStartTrace' -ProcessName 'SystemSettings.exe' | Out-Null

$stopwatch.Stop()
$elapsedTime = [math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
Write-Host ("Timer STOPPED at {0:HH:mm:ss.fff}  - elapsed: {1} s" -f (Get-Date), $elapsedTime)

# Append the result row
if (-not (Test-Path $csvPath)) {
    'Participant #, Time to Complete' | Out-File -LiteralPath $csvPath -Encoding UTF8
}

"$participantNumber,$elapsedTime" | Out-File -LiteralPath $csvPath -Encoding UTF8 -Append

Write-Host "Saved row to $csvPath"