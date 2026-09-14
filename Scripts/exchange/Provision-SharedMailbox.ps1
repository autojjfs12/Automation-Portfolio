[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$PrimarySmtpAddress,
    [string[]]$FullAccessUsers = @(),
    [string[]]$SendAsUsers = @(),
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    throw "Required module 'ExchangeOnlineManagement' is not installed."
}

Import-Module ExchangeOnlineManagement
if (-not (Get-ConnectionInformation -ErrorAction SilentlyContinue)) {
    Connect-ExchangeOnline -ShowBanner:$false
}

$existing = Get-EXOMailbox -Identity $PrimarySmtpAddress -ErrorAction SilentlyContinue

if ($existing -and $existing.RecipientTypeDetails -ne 'SharedMailbox') {
    throw "The target exists and is not a shared mailbox. No permissions were changed."
}

if ($DryRun) {
    [pscustomobject]@{
        Mailbox    = $PrimarySmtpAddress
        Exists     = [bool]$existing
        WouldCreate = -not [bool]$existing
        FullAccess = $FullAccessUsers -join '; '
        SendAs     = $SendAsUsers -join '; '
        Status     = 'DryRun'
    }
    return
}

if (-not $existing) {
    New-Mailbox -Shared -Name $Name -PrimarySmtpAddress $PrimarySmtpAddress | Out-Null
}

foreach ($user in $FullAccessUsers) {
    $current = @(Get-MailboxPermission -Identity $PrimarySmtpAddress -User $user -ErrorAction SilentlyContinue | Where-Object { -not $_.IsInherited -and 'FullAccess' -in $_.AccessRights })
    if (-not $current) {
        Add-MailboxPermission -Identity $PrimarySmtpAddress -User $user -AccessRights FullAccess -InheritanceType All -AutoMapping:$true | Out-Null
    }
}

foreach ($user in $SendAsUsers) {
    $current = @(Get-RecipientPermission -Identity $PrimarySmtpAddress -Trustee $user -ErrorAction SilentlyContinue | Where-Object { 'SendAs' -in $_.AccessRights })
    if (-not $current) {
        Add-RecipientPermission -Identity $PrimarySmtpAddress -Trustee $user -AccessRights SendAs -Confirm:$false | Out-Null
    }
}

$verify = Get-EXOMailbox -Identity $PrimarySmtpAddress -ErrorAction Stop
[pscustomobject]@{
    Mailbox = $verify.PrimarySmtpAddress
    Name    = $verify.DisplayName
    Type    = $verify.RecipientTypeDetails
    Status  = if ($verify.RecipientTypeDetails -eq 'SharedMailbox') { 'Success' } else { 'FailedVerification' }
}
