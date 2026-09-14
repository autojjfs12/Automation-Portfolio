[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Group,
    [Parameter(Mandatory)] [string]$Member,
    [Parameter(Mandatory)] [ValidateSet('Add','Remove')] [string]$Action,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Module {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) { throw "Required module '$Name' is not installed." }
}

function Connect-GraphMembership {
    $scopes = @('Group.ReadWrite.All','User.Read.All')
    $ctx = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $ctx -or @($scopes | Where-Object { $_ -notin $ctx.Scopes }).Count -gt 0) {
        Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null
    }
}

Assert-Module 'Microsoft.Graph.Authentication'
Assert-Module 'Microsoft.Graph.Groups'
Assert-Module 'Microsoft.Graph.Users'
Connect-GraphMembership

$groupEsc = $Group.Replace("'","''")
$groups = @(Get-MgGroup -Filter "displayName eq '$groupEsc' or mail eq '$groupEsc'" -Property Id,DisplayName,Mail,MailEnabled,SecurityEnabled,GroupTypes)
if ($groups.Count -eq 0) { throw "Group '$Group' was not found." }
if ($groups.Count -gt 1) { throw "Multiple groups matched '$Group'. Use the group's email address where possible." }
$g = $groups[0]
if ('DynamicMembership' -in $g.GroupTypes) { throw 'Dynamic membership is managed by rules.' }
if ($g.MailEnabled -and 'Unified' -notin $g.GroupTypes) {
    throw 'Use Exchange Online tooling for distribution or mail-enabled security groups.'
}

$memberEsc = $Member.Replace("'","''")
$users = @(Get-MgUser -Filter "userPrincipalName eq '$memberEsc' or mail eq '$memberEsc'" -Property Id,DisplayName,UserPrincipalName)
if ($users.Count -ne 1) { throw "Member '$Member' could not be resolved uniquely." }
$u = $users[0]

$currentIds = @(Get-MgGroupMember -GroupId $g.Id -All | ForEach-Object { $_.Id })
$isMember = $u.Id -in $currentIds
$changeNeeded = ($Action -eq 'Add' -and -not $isMember) -or ($Action -eq 'Remove' -and $isMember)

if (-not $changeNeeded) {
    [pscustomobject]@{ Group=$g.DisplayName; Member=$u.UserPrincipalName; Action=$Action; Status='Skipped'; Message='Desired state already present.' }
    return
}

if ($DryRun) {
    [pscustomobject]@{ Group=$g.DisplayName; Member=$u.UserPrincipalName; Action=$Action; Status='DryRun'; Message='Change calculated but not applied.' }
    return
}

if ($Action -eq 'Add') {
    New-MgGroupMemberByRef -GroupId $g.Id -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.Id)" }
} else {
    Remove-MgGroupMemberByRef -GroupId $g.Id -DirectoryObjectId $u.Id
}

Start-Sleep -Seconds 2
$verifyIds = @(Get-MgGroupMember -GroupId $g.Id -All | ForEach-Object { $_.Id })
$verified = if ($Action -eq 'Add') { $u.Id -in $verifyIds } else { $u.Id -notin $verifyIds }

[pscustomobject]@{
    Group   = $g.DisplayName
    Member  = $u.UserPrincipalName
    Action  = $Action
    Status  = if ($verified) { 'Success' } else { 'FailedVerification' }
    Message = if ($verified) { 'Final state verified.' } else { 'Command completed but final state did not verify.' }
}
