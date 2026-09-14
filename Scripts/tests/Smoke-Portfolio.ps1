# Offline checks: all service and operating-system commands are replaced by fakes.
[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference = 'Stop'
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Get-Module { param($Name, [switch]$ListAvailable) [pscustomobject]@{Name=$Name} }
function Import-Module { param($Name) }
function Start-Sleep { param($Seconds) }

& {
    function Get-ConnectionInformation { [pscustomobject]@{State='Connected'} }
    function Get-Recipient { param($Identity, $ErrorAction) [pscustomobject]@{PrimarySmtpAddress=$Identity;RecipientTypeDetails='MailUniversalDistributionGroup'} }
    function Get-DistributionGroupMember { param($Identity,$ResultSize,$ErrorAction) @() }
    function Add-DistributionGroupMember { throw 'DryRun attempted a mutation' }
    $csv = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()+'.csv')
    try {
        "UserPrincipalName`nalex@example.com" | Set-Content $csv
        $r = @(& "$Root/exchange/add-mailbox-users.ps1" -Mode DistributionGroup -Target team@example.com -CsvPath $csv -DryRun)
        Assert ($r.Count -eq 1 -and $r[0].Status -eq 'DryRun' -and $r[0].User -eq 'alex@example.com') 'Single-row CSV or structured output failed'
        $r = @(& "$Root/exchange/add-mailbox-users.ps1" -Mode DistributionGroup -Target team@example.com -UserPrincipalName alex@example.com -DryRun)
        Assert ($r.Count -eq 1 -and $r[0].Status -eq 'DryRun') 'Single direct user failed'
    } finally { Remove-Item $csv -Force }
}
& {
    function Get-MgContext { [pscustomobject]@{Scopes=@('DeviceManagementManagedDevices.Read.All')} }
    function Get-MgDeviceManagementManagedDevice {
        param($Property,[switch]$All)
        Assert ($Property -match 'managedDeviceOwnerType' -and $Property -notmatch ',ownerType,') 'Incorrect API property'
        foreach ($owner in 'personal','company','unknown') {
            [pscustomobject]@{DeviceName='demo';UserPrincipalName='alex@example.com';OperatingSystem='Windows';ComplianceState='unknown';ManagementAgent='mdm';DeviceEnrollmentType='userEnrollment';ManagedDeviceOwnerType=$owner;Manufacturer='Example';Model='Demo';SerialNumber='sample';EnrolledDateTime=$null;LastSyncDateTime=$null}
        }
    }
    $r = @(& "$Root/intune/Get-BYODDeviceReport.ps1")
    Assert ($r.Count -eq 3 -and $r[0].IsLikelyBYOD -and -not $r[1].IsLikelyBYOD -and -not $r[2].IsLikelyBYOD) 'Ownership classification failed'
}
& {
    function Get-ConnectionInformation { [pscustomobject]@{State='Connected'} }
    function Get-EXOMailbox { param($Identity,$ErrorAction) [pscustomobject]@{RecipientTypeDetails='UserMailbox'} }
    function Add-MailboxPermission { throw 'Unexpected permission mutation' }
    $rejected = $false
    try { & "$Root/exchange/Provision-SharedMailbox.ps1" -Name Demo -PrimarySmtpAddress demo@example.com } catch { $rejected = $_.Exception.Message -match 'not a shared mailbox' }
    Assert $rejected 'Existing user mailbox was not rejected'
}
& {
    $user = [pscustomobject]@{Department='Old';Title='Old';Office='Old';DistinguishedName='CN=Demo,OU=Users,DC=example,DC=com';SamAccountName='demo'}
    function Get-ADUser { param($Filter,$Properties,$ErrorAction,$Identity) $user }
    function Set-ADUser { param($Identity,$Department,$Title,$Office) $user.Department=$Department; $user.Title=$Title; $user.Office=$Office }
    $csv = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString()+'.csv')
    try {
        "UserPrincipalName,Department,Title,Office,TargetOU`ndemo@example.com,New,Analyst,Remote," | Set-Content $csv
        $r = & "$Root/active-directory/Invoke-EmployeeMovementSync.ps1" -InputCsv $csv
        Assert ($r.Status -eq 'Success' -and $user.Office -eq 'Remote') 'AD parameter mapping failed'
    } finally { Remove-Item $csv -Force }
}
& {
    # Permit offline Windows branches on any host; all affected commands are faked.
    function Get-ScheduledTask { param($TaskPath,$TaskName,$ErrorAction) [pscustomobject]@{TaskPath=$TaskPath;TaskName='Schedule demo'} }
    function Start-ScheduledTask { throw 'WhatIf attempted to start a task' }
    function gpupdate.exe { throw 'WhatIf attempted policy refresh' }
    $code = (Get-Content "$Root/intune/Invoke-IntuneEntraSync.ps1" -Raw).Replace('$IsWindows','$true')
    $r = @(& ([scriptblock]::Create($code)) -IncludePolicyRefresh -WhatIf)
    Assert ($r.Count -eq 3 -and @($r | Where-Object Status -ne 'Skipped').Count -eq 0) 'WhatIf status incorrectly reported mutation'
}
& {
    function Test-Path { param($Path) $Path -eq 'sample.msi' }
    function Get-Process { throw 'WhatIf inspected processes for termination' }
    function Stop-Process { throw 'WhatIf stopped a process' }
    function Start-Process { throw 'WhatIf launched an installer' }
    function Get-ItemProperty { throw 'WhatIf inspected uninstall entries' }
    $code = (Get-Content "$Root/endpoint-remediation/Repair-ChromeInstall.ps1" -Raw).Replace('$IsWindows','$true')
    $r = & ([scriptblock]::Create($code)) -Apply -InstallerPath sample.msi -WhatIf
    Assert ($r.Status -eq 'WhatIf') 'Chrome WhatIf failed'
}
'All offline portfolio smoke checks passed.'
