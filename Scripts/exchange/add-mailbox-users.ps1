<#
.SYNOPSIS
    Batch-oriented Exchange Online helper for adding users to a distribution group
    or granting mailbox access.

.DESCRIPTION
    Portfolio-safe implementation based on the build recipe in the IT Automation
    Master Build Guide.

    The script:
      1. Accepts users from a CSV file or direct input.
      2. Connects to Exchange Online once.
      3. Validates each user and target.
      4. Detects current state before making a change.
      5. Supports -DryRun.
      6. Applies only missing membership/permissions.
      7. Verifies the final state.
      8. Continues safely when one item fails.
      9. Returns machine-readable PowerShell objects.

    No tenant-specific domains, credentials, mailbox names, or company values are
    hard-coded.

.PARAMETER Mode
    DistributionGroup:
        Adds each user to the target distribution group.

    MailboxAccess:
        Grants FullAccess to the target mailbox. Use -AutoMapping if desired.

.PARAMETER Target
    SMTP address or identity of the destination distribution group or mailbox.

.PARAMETER UserPrincipalName
    One or more user principal names supplied directly.

.PARAMETER CsvPath
    Path to a CSV containing a UserPrincipalName column.

.PARAMETER DryRun
    Shows the changes that would be made without modifying Exchange Online.

.PARAMETER AutoMapping
    Used only with MailboxAccess. Enables Outlook automapping when FullAccess is
    granted.

.PARAMETER ExportPath
    Optional CSV output path for the final structured results.

.EXAMPLE
    .\add-mailbox-users.ps1 `
        -Mode DistributionGroup `
        -Target "engineering@example.com" `
        -UserPrincipalName "alex@example.com","sam@example.com" `
        -DryRun

.EXAMPLE
    .\add-mailbox-users.ps1 `
        -Mode MailboxAccess `
        -Target "shared-support@example.com" `
        -CsvPath ".\users.csv" `
        -AutoMapping `
        -ExportPath ".\results.csv"

.NOTES
    Requires the ExchangeOnlineManagement module and appropriate Exchange Online
    permissions. Test in a non-production environment before production use.
#>

[CmdletBinding(DefaultParameterSetName = 'Direct')]
param(
    [Parameter(Mandatory)]
    [ValidateSet('DistributionGroup', 'MailboxAccess')]
    [string]$Mode,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Target,

    [Parameter(Mandatory, ParameterSetName = 'Direct')]
    [ValidateNotNullOrEmpty()]
    [string[]]$UserPrincipalName,

    [Parameter(Mandatory, ParameterSetName = 'Csv')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$CsvPath,

    [switch]$DryRun,

    [switch]$AutoMapping,

    [string]$ExportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$inputParameterSet = $PSCmdlet.ParameterSetName

function New-Result {
    param(
        [string]$User,
        [string]$TargetIdentity,
        [string]$Action,
        [string]$Status,
        [string]$Message
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToString('s')
        User      = $User
        Target    = $TargetIdentity
        Mode      = $Mode
        Action    = $Action
        Status    = $Status
        Message   = $Message
    }
}

function Connect-ExchangeOnlineIfNeeded {
    $connection = Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Connected' } |
        Select-Object -First 1

    if (-not $connection) {
        Connect-ExchangeOnline -ShowBanner:$false
    }
}

function Get-InputUsers {
    if ($inputParameterSet -eq 'Csv') {
        $rows = @(Import-Csv -LiteralPath $CsvPath)

        if (-not $rows) {
            throw "CSV '$CsvPath' contains no data rows."
        }

        if (-not ($rows[0].PSObject.Properties.Name -contains 'UserPrincipalName')) {
            throw "CSV must contain a 'UserPrincipalName' column."
        }

        return @(
            $rows |
            ForEach-Object { $_.UserPrincipalName } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
    }

    return @(
        $UserPrincipalName |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    )
}

function Resolve-Recipient {
    param([Parameter(Mandatory)][string]$Identity)

    try {
        return Get-Recipient -Identity $Identity -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Test-DistributionGroupMembership {
    param(
        [Parameter(Mandatory)][string]$GroupIdentity,
        [Parameter(Mandatory)][string]$UserIdentity
    )

    $members = Get-DistributionGroupMember -Identity $GroupIdentity -ResultSize Unlimited -ErrorAction Stop
    return [bool]($members | Where-Object {
        $_.PrimarySmtpAddress -eq $UserIdentity -or
        $_.WindowsEmailAddress -eq $UserIdentity -or
        $_.ExternalEmailAddress -eq $UserIdentity
    })
}

function Add-DistributionGroupUserSafely {
    param(
        [Parameter(Mandatory)][string]$GroupIdentity,
        [Parameter(Mandatory)][string]$UserIdentity
    )

    if (Test-DistributionGroupMembership -GroupIdentity $GroupIdentity -UserIdentity $UserIdentity) {
        return New-Result -User $UserIdentity -TargetIdentity $GroupIdentity `
            -Action 'AddDistributionGroupMember' -Status 'Skipped' `
            -Message 'User is already a member.'
    }

    if ($DryRun) {
        return New-Result -User $UserIdentity -TargetIdentity $GroupIdentity `
            -Action 'AddDistributionGroupMember' -Status 'DryRun' `
            -Message 'Would add user to distribution group.'
    }

    Add-DistributionGroupMember -Identity $GroupIdentity -Member $UserIdentity -ErrorAction Stop

    if (Test-DistributionGroupMembership -GroupIdentity $GroupIdentity -UserIdentity $UserIdentity) {
        return New-Result -User $UserIdentity -TargetIdentity $GroupIdentity `
            -Action 'AddDistributionGroupMember' -Status 'Success' `
            -Message 'User added and membership verified.'
    }

    return New-Result -User $UserIdentity -TargetIdentity $GroupIdentity `
        -Action 'AddDistributionGroupMember' -Status 'Failed' `
        -Message 'Command completed but final membership verification failed.'
}

function Test-MailboxFullAccess {
    param(
        [Parameter(Mandatory)][string]$MailboxIdentity,
        [Parameter(Mandatory)][string]$UserIdentity
    )

    $permissions = Get-MailboxPermission -Identity $MailboxIdentity -User $UserIdentity -ErrorAction SilentlyContinue
    return [bool]($permissions | Where-Object {
        -not $_.Deny -and
        $_.IsInherited -eq $false -and
        $_.AccessRights -contains 'FullAccess'
    })
}

function Grant-MailboxAccessSafely {
    param(
        [Parameter(Mandatory)][string]$MailboxIdentity,
        [Parameter(Mandatory)][string]$UserIdentity
    )

    if (Test-MailboxFullAccess -MailboxIdentity $MailboxIdentity -UserIdentity $UserIdentity) {
        return New-Result -User $UserIdentity -TargetIdentity $MailboxIdentity `
            -Action 'GrantFullAccess' -Status 'Skipped' `
            -Message 'User already has explicit FullAccess.'
    }

    if ($DryRun) {
        return New-Result -User $UserIdentity -TargetIdentity $MailboxIdentity `
            -Action 'GrantFullAccess' -Status 'DryRun' `
            -Message "Would grant FullAccess. AutoMapping=$($AutoMapping.IsPresent)."
    }

    Add-MailboxPermission `
        -Identity $MailboxIdentity `
        -User $UserIdentity `
        -AccessRights FullAccess `
        -InheritanceType All `
        -AutoMapping:$AutoMapping.IsPresent `
        -ErrorAction Stop | Out-Null

    if (Test-MailboxFullAccess -MailboxIdentity $MailboxIdentity -UserIdentity $UserIdentity) {
        return New-Result -User $UserIdentity -TargetIdentity $MailboxIdentity `
            -Action 'GrantFullAccess' -Status 'Success' `
            -Message 'FullAccess granted and verified.'
    }

    return New-Result -User $UserIdentity -TargetIdentity $MailboxIdentity `
        -Action 'GrantFullAccess' -Status 'Failed' `
        -Message 'Command completed but final permission verification failed.'
}

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    throw "ExchangeOnlineManagement module is required. Install it with: Install-Module ExchangeOnlineManagement"
}

Connect-ExchangeOnlineIfNeeded

$targetObject = Resolve-Recipient -Identity $Target
if (-not $targetObject) {
    throw "Target '$Target' could not be resolved in Exchange Online."
}

if ($Mode -eq 'DistributionGroup' -and $targetObject.RecipientTypeDetails -notmatch 'DistributionGroup') {
    throw "Target '$Target' is not a distribution group."
}

if ($Mode -eq 'MailboxAccess' -and $targetObject.RecipientTypeDetails -notmatch 'Mailbox') {
    throw "Target '$Target' is not a mailbox."
}

$users = @(Get-InputUsers)
if (-not $users -or $users.Count -eq 0) {
    throw 'No valid users were provided.'
}

$results = foreach ($user in $users) {
    try {
        $recipient = Resolve-Recipient -Identity $user

        if (-not $recipient) {
            New-Result -User $user -TargetIdentity $Target `
                -Action 'ValidateRecipient' -Status 'NotFound' `
                -Message 'User could not be resolved in Exchange Online.'
            continue
        }

        $resolvedIdentity = $recipient.PrimarySmtpAddress.ToString()

        if ($Mode -eq 'DistributionGroup') {
            Add-DistributionGroupUserSafely `
                -GroupIdentity $Target `
                -UserIdentity $resolvedIdentity
        }
        else {
            Grant-MailboxAccessSafely `
                -MailboxIdentity $Target `
                -UserIdentity $resolvedIdentity
        }
    }
    catch {
        New-Result -User $user -TargetIdentity $Target `
            -Action $Mode -Status 'Failed' `
            -Message $_.Exception.Message
    }
}


if ($ExportPath) {
    $exportParent = Split-Path -Parent $ExportPath
    if ($exportParent -and -not (Test-Path -LiteralPath $exportParent)) {
        New-Item -ItemType Directory -Path $exportParent -Force | Out-Null
    }

    $results | Export-Csv -LiteralPath $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Host "Results exported to: $ExportPath"
}

$results
