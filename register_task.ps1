# Registers two Windows scheduled tasks:
#   "HSR News Digest" - runs hsr_news.py every day at the given times (summary report: web app + push, PDF mail as fallback)
#   "HSR Leak Alerts" - runs hsr_news.py --alert every N minutes (instant push notifications)
# Usage:  powershell -ExecutionPolicy Bypass -File register_task.ps1 [-Time "12:00,18:00"] [-AlertMinutes 10]
#         -AlertMinutes 0 removes the alerts task.
param([string]$Time = "12:00,18:00", [int]$AlertMinutes = 10)

$TaskName = "HSR News Digest"
$AlertTaskName = "HSR Leak Alerts"
$ScriptDir = $PSScriptRoot
$Script = Join-Path $ScriptDir "hsr_news.py"

# Resolve the real python.exe (not the WindowsApps stub) and prefer pythonw.exe (no console window).
$Python = (& python -c "import sys; print(sys.executable)").Trim()
$Pythonw = Join-Path (Split-Path $Python) "pythonw.exe"
if (Test-Path $Pythonw) { $Python = $Pythonw }

# -File passes "12:00,18:00" as one string, so split it here.
$Times = $Time -split "[,\s]+" | Where-Object { $_ }

# Also run on battery power (laptops), otherwise Windows skips the task.
# The digest also wakes the PC from sleep (needs "Allow wake timers" enabled in Power Options).
$Action = New-ScheduledTaskAction -Execute $Python -Argument "`"$Script`"" -WorkingDirectory $ScriptDir
$Triggers = $Times | ForEach-Object { New-ScheduledTaskTrigger -Daily -At $_ }
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -WakeToRun `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 45)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings `
    -Description "Honkai: Star Rail leak digest (web app + push, mail as fallback)" -Force | Out-Null
Write-Host "Registered '$TaskName' daily at $($Times -join ', ')"

if ($AlertMinutes -gt 0) {
    $AlertAction = New-ScheduledTaskAction -Execute $Python -Argument "`"$Script`" --alert" -WorkingDirectory $ScriptDir
    $AlertTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
        -RepetitionInterval (New-TimeSpan -Minutes $AlertMinutes)
    $AlertSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
    Register-ScheduledTask -TaskName $AlertTaskName -Action $AlertAction -Trigger $AlertTrigger -Settings $AlertSettings `
        -Description "Honkai: Star Rail instant leak alerts (web push)" -Force | Out-Null
    Write-Host "Registered '$AlertTaskName' every $AlertMinutes minutes"
} elseif (Get-ScheduledTask -TaskName $AlertTaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $AlertTaskName -Confirm:$false
    Write-Host "Removed '$AlertTaskName'"
}

Write-Host "  Python: $Python"
Write-Host "  Script: $Script"
Write-Host "Test now:  Start-ScheduledTask -TaskName '$TaskName'"
