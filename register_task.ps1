# Registers a Windows scheduled task that runs hsr_news.py every day at the given times.
# Usage:  powershell -ExecutionPolicy Bypass -File register_task.ps1 [-Time "12:00,18:00"]
param([string]$Time = "12:00,18:00")

$TaskName = "HSR News Digest"
$ScriptDir = $PSScriptRoot
$Script = Join-Path $ScriptDir "hsr_news.py"

# Resolve the real python.exe (not the WindowsApps stub) and prefer pythonw.exe (no console window).
$Python = (& python -c "import sys; print(sys.executable)").Trim()
$Pythonw = Join-Path (Split-Path $Python) "pythonw.exe"
if (Test-Path $Pythonw) { $Python = $Pythonw }

# -File passes "12:00,18:00" as one string, so split it here.
$Times = $Time -split "[,\s]+" | Where-Object { $_ }

$Action = New-ScheduledTaskAction -Execute $Python -Argument "`"$Script`"" -WorkingDirectory $ScriptDir
$Triggers = $Times | ForEach-Object { New-ScheduledTaskTrigger -Daily -At $_ }
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 45)

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Triggers -Settings $Settings `
    -Description "Honkai: Star Rail news digest to Gmail" -Force | Out-Null

Write-Host "Registered '$TaskName' daily at $($Times -join ', ')"
Write-Host "  Python: $Python"
Write-Host "  Script: $Script"
Write-Host "Test now:  Start-ScheduledTask -TaskName '$TaskName'"
