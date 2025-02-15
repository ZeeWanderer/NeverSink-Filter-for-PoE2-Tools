#Requires -RunAsAdministrator

<# 
.SYNOPSIS
Schedules a persistent Windows Scheduled Task to update a Git repository via a "git pull".

.DESCRIPTION
This script creates a scheduled task that executes "git pull" within a Git repository.
Starting from the specified SourceRepoPath, the script searches upward until it finds a ".git" folder.
The task can be triggered at user logon (with a 1-minute delay) and/or at a specified interval.
Git must be installed and accessible via PATH.
If a task with the same name already exists, the -Force switch can be used to overwrite it without prompting.

.PARAMETER SourceRepoPath
**(Mandatory, Positional 0)** The file system path to the Git repository.
The script starts at this path and searches upward for a ".git" folder.
You must supply this value as the first positional argument.

.PARAMETER TaskName
The name of the scheduled task. Default is "Update Neversink Filters - Git Pull".

.PARAMETER AtLogon
If specified, a logon trigger is created so that the task runs at user logon with a 1-minute delay.

.PARAMETER Interval
A TimeSpan specifying how often the task should run. If provided, a repetition trigger is created that repeats at the given interval.

.PARAMETER Force
If specified, the script will automatically overwrite an existing scheduled task with the same name without prompting for confirmation.

.EXAMPLE
.\Schedule-Updates.ps1 "C:\MyRepo" -TaskName "My Git Update Task" -AtLogon

.EXAMPLE
.\Schedule-Updates.ps1 "C:\MyRepo" -Interval (New-TimeSpan -Minutes 30) -Force

.LINK
https://github.com/NeverSinkDev/NeverSink-Filter-for-PoE2

.LINK
https://github.com/ZeeWanderer/NeverSink-Filter-for-PoE2-Tools
#>

param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$SourceRepoPath,

    [Parameter(Mandatory = $false)]
    [string]$TaskName = "Update Neversink Filters - Git Pull",

    [switch]$AtLogon,
    [TimeSpan]$Interval,
    [switch]$Force
)

$SourceRepoPath = (Resolve-Path $SourceRepoPath).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is not installed or not in PATH"
}

$gitRoot = $SourceRepoPath
while (-not (Test-Path -Path (Join-Path $gitRoot ".git") -PathType Container)) {
    $gitRoot = Split-Path $gitRoot -Parent
    if (-not $gitRoot) {
        throw "Not a git repository (or any parent directories): .git not found"
    }
}

$action = New-ScheduledTaskAction -Execute "git.exe" `
    -Argument "pull" `
    -WorkingDirectory $gitRoot

$triggers = @()

if ($AtLogon) {
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn
    $logonTrigger.Delay = "PT1M"  # 1 minute delay after logon
    $triggers += $logonTrigger
}

if ($Interval) {
    $intervalTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval $Interval `
        -RepetitionDuration ([System.TimeSpan]::MaxValue)
    $triggers += $intervalTrigger
}

if (-not $triggers) {
    throw "You must specify at least one trigger type (-AtLogon or -Interval)"
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances Ignore `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -WakeToRun

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    if (-not $Force) {
        $choice = Read-Host "Task '$TaskName' already exists. Overwrite? (Y/N)"
        if ($choice.ToLower() -ne 'y') { exit }
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Principal $principal `
    -Description "Persistent task created $(Get-Date)"

Register-ScheduledTask -TaskName $TaskName -InputObject $task | Out-Null

Write-Host "`nCreated persistent scheduled task '$TaskName'" -ForegroundColor Green
Write-Host "Repository: $gitRoot"

Write-Host "`nTriggers:" -ForegroundColor Cyan
$triggers | ForEach-Object { 
    if ($_.Repetition.Interval) {
        Write-Host "- Repeats every $($_.Repetition.Interval)"
    }
    else {
        Write-Host "- Runs at user logon (with 1 minute delay)"
    }
}

Write-Host "`nVerification command:" -ForegroundColor Yellow
Write-Host "Get-ScheduledTask -TaskName '$TaskName' | Format-List"
