# WindowsSettingTask.ps1
# Start timer when "Notes" closes; stop when "Settings" opens.

$StartTrigger = "Notes"
$StopTrigger  = "Settings"
$CsvPath      = Join-Path $PSScriptRoot "windows_settings_results.csv"
$Header       = "participant,elapsed_seconds"

function Get-VisibleTitles {
    Get-Process | Where-Object { $_.MainWindowTitle -ne "" } |
        Select-Object -ExpandProperty MainWindowTitle
}

function Test-TitlePresent([string]$needle) {
    (Get-VisibleTitles) -match [regex]::Escape($needle) | ForEach-Object { return $true }
    return $false
}

$notesWasVisible    = Test-TitlePresent $StartTrigger
$settingsWasVisible = Test-TitlePresent $StopTrigger
$startTime = $null
$timerRunning = $false

Write-Host "Watching for '$StartTrigger' to close and '$StopTrigger' to open."
Write-Host "CSV: $CsvPath"

while ($true) {
    $notesVisible    = Test-TitlePresent $StartTrigger
    $settingsVisible = Test-TitlePresent $StopTrigger

    if ($notesWasVisible -and -not $notesVisible -and -not $timerRunning) {
        $startTime = [System.Diagnostics.Stopwatch]::StartNew()
        $timerRunning = $true
        Write-Host "$(Get-Date -Format HH:mm:ss) Notes closed - timer STARTED"
    }

    if ($settingsVisible -and -not $settingsWasVisible -and $timerRunning) {
        $startTime.Stop()
        $elapsed = [math]::Round($startTime.Elapsed.TotalSeconds, 3)
        $timerRunning = $false

        # participant = line count (header included), like the AppleScript
        if (Test-Path $CsvPath) {
            $lines = @(Get-Content $CsvPath)
            $participant = $lines.Count
        } else {
            Set-Content -Path $CsvPath -Value $Header -Encoding UTF8
            $participant = 1
        }

        Add-Content -Path $CsvPath -Value "$participant,$elapsed" -Encoding UTF8
        Write-Host "$(Get-Date -Format HH:mm:ss) Participant $participant - Elapsed: $elapsed seconds"
    }

    $notesWasVisible    = $notesVisible
    $settingsWasVisible = $settingsVisible
    Start-Sleep -Milliseconds 250
}