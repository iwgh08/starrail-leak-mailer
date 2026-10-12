# Registers a daily Windows scheduled task that runs hsr_news.py.
# Usage:  powershell -ExecutionPolicy Bypass -File register_task.ps1 [-Time 08:00]
param([string]$Time = "08:00")

$TaskName = "HSR News Digest"
$ScriptDir = $PSScriptRoot
$Script = Join-Path $ScriptDir "hsr_news.py"

# Resolve the real python.exe (not the WindowsApps stub) and prefer pythonw.exe (no console window).
$Python = (& python -c "import sys; print(sys.executable)").Trim()
$Pythonw = Join-Path (Split-Path $Python) "pythonw.exe"
if (Test-Path $Pythonw) { $Python = $Pythonw }

$Action = New-ScheduledTaskAction -Execute $Python -Argument "`"$Script`"" -WorkingDirectory $ScriptDir
$Trigger = New-ScheduledTaskTrigger -Daily -At $Time
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 45)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings `
    -Description "Honkai: Star Rail news digest to Gmail" -Force | Out-Null

Write-Host "Registered '$TaskName' daily at $Time"
Write-Host "  Python: $Python"
Write-Host "  Script: $Script"
Write-Host "Test now:  Start-ScheduledTask -TaskName '$TaskName'"
