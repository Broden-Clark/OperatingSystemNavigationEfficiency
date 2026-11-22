
# Application being closed
$TargetApp = "Notepad"

# Wait for Notepad to close
Write-Host "Waiting for $TargetApp to close..." -ForegroundColor Cyan

while (Get-Process -Name $TargetApp -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 100
}

# Start timer
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Notepad closed! Waiting for Settings to open..." -ForegroundColor Yellow

# Wait for Windows Settings to open
while (-not (Get-Process -Name "SystemSettings" -ErrorAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 100
}

# Stop timer
$Stopwatch.Stop()

# Calculate elapsed time
$Time = $Stopwatch.Elapsed.TotalSeconds

# Display results
Write-Host "Settings opened!" -ForegroundColor Green
Write-Host "Elapsed time: $([math]::Round($Time, 3)) seconds" -ForegroundColor Green

# Create blank CSV output file
$OutputFile = "$env:USERPROFILE\Desktop\Windows_Timing_Results.csv"

# Add column headings only (no participant records)
"Participant #,Time to Complete" | Set-Content -Path $OutputFile -Encoding UTF8

Write-Host "CSV template created successfully!" -ForegroundColor Cyan
Write-Host "File location: $OutputFile" -ForegroundColor Cyan
