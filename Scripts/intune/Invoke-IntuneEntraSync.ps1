[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$IncludePolicyRefresh
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw 'This script must be run on Windows.' }

$tasks = @(
    @{ Path='\Microsoft\Windows\Workplace Join\'; Name='Automatic-Device-Join' }
)

$enterpriseMgmtTasks = Get-ScheduledTask -TaskPath '\Microsoft\Windows\EnterpriseMgmt\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -match 'PushLaunch|Schedule|OMADMClient' }

$results = New-Object System.Collections.Generic.List[object]

foreach ($task in $tasks) {
    try {
        $scheduled = Get-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction Stop
        if ($PSCmdlet.ShouldProcess("$($task.Path)$($task.Name)", 'Start scheduled task')) {
            Start-ScheduledTask -InputObject $scheduled
            $status = 'Triggered'
        } else { $status = 'Skipped' }
        $results.Add([pscustomobject]@{ Target="$($task.Path)$($task.Name)"; Action='StartTask'; Status=$status })
    } catch {
        $results.Add([pscustomobject]@{ Target="$($task.Path)$($task.Name)"; Action='StartTask'; Status='Unavailable'; Message=$_.Exception.Message })
    }
}

foreach ($scheduled in $enterpriseMgmtTasks) {
    try {
        if ($PSCmdlet.ShouldProcess("$($scheduled.TaskPath)$($scheduled.TaskName)", 'Start scheduled task')) {
            Start-ScheduledTask -InputObject $scheduled
            $status = 'Triggered'
        } else { $status = 'Skipped' }
        $results.Add([pscustomobject]@{ Target="$($scheduled.TaskPath)$($scheduled.TaskName)"; Action='StartTask'; Status=$status })
    } catch {
        $results.Add([pscustomobject]@{ Target="$($scheduled.TaskPath)$($scheduled.TaskName)"; Action='StartTask'; Status='Failed'; Message=$_.Exception.Message })
    }
}

if ($IncludePolicyRefresh) {
    try {
        if ($PSCmdlet.ShouldProcess('Computer policy', 'gpupdate /target:computer /force')) {
            & gpupdate.exe /target:computer /force | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "gpupdate exited with code $LASTEXITCODE" }
            $status = 'Triggered'
        } else { $status = 'Skipped' }
        $results.Add([pscustomobject]@{ Target='ComputerPolicy'; Action='gpupdate'; Status=$status })
    } catch {
        $results.Add([pscustomobject]@{ Target='ComputerPolicy'; Action='gpupdate'; Status='Failed'; Message=$_.Exception.Message })
    }
}

$results
