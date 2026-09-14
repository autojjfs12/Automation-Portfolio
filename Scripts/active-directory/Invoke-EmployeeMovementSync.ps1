[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$InputCsv,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    throw "Required module 'ActiveDirectory' is not installed."
}
if (-not (Test-Path $InputCsv)) { throw "Input file '$InputCsv' was not found." }

Import-Module ActiveDirectory
$rows = @(Import-Csv $InputCsv)
if ($rows.Count -eq 0) { throw "Input CSV contains no data rows." }
$requiredColumns = @('UserPrincipalName','Department','Title','Office','TargetOU')
foreach ($column in $requiredColumns) {
    if ($column -notin $rows[0].PSObject.Properties.Name) { throw "Input CSV is missing required column '$column'." }
}

$results = foreach ($row in $rows) {
    try {
        $user = Get-ADUser -Filter "UserPrincipalName -eq '$($row.UserPrincipalName.Replace("'","''"))'" -Properties Department,Title,Office,DistinguishedName -ErrorAction Stop
        if (-not $user) { throw 'User not found.' }

        $changes = @{}
        if ($row.Department -and $user.Department -ne $row.Department) { $changes.Department = $row.Department }
        if ($row.Title -and $user.Title -ne $row.Title) { $changes.Title = $row.Title }
        if ($row.Office -and $user.Office -ne $row.Office) { $changes.Office = $row.Office }

        $currentParent = ($user.DistinguishedName -split '(?<!\\),',2)[1]
        $moveNeeded = $row.TargetOU -and ($currentParent -ne $row.TargetOU)

        if ($moveNeeded) {
            Get-ADOrganizationalUnit -Identity $row.TargetOU -ErrorAction Stop | Out-Null
        }

        if ($DryRun) {
            [pscustomobject]@{
                UserPrincipalName = $row.UserPrincipalName
                AttributeChanges  = ($changes.Keys -join ', ')
                MoveNeeded        = $moveNeeded
                TargetOU          = $row.TargetOU
                Status            = 'DryRun'
            }
            continue
        }

        if ($changes.Count -gt 0) {
            Set-ADUser -Identity $user @changes
        }
        if ($moveNeeded) {
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $row.TargetOU
        }

        $verify = Get-ADUser -Identity $user.SamAccountName -Properties Department,Title,Office,DistinguishedName
        $verified = (!$row.Department -or $verify.Department -eq $row.Department) -and
                    (!$row.Title -or $verify.Title -eq $row.Title) -and
                    (!$row.Office -or $verify.Office -eq $row.Office) -and
                    (!$row.TargetOU -or (($verify.DistinguishedName -split '(?<!\\),',2)[1] -eq $row.TargetOU))

        [pscustomobject]@{
            UserPrincipalName = $row.UserPrincipalName
            AttributeChanges  = ($changes.Keys -join ', ')
            MoveNeeded        = $moveNeeded
            TargetOU          = $row.TargetOU
            Status            = if ($verified) { 'Success' } else { 'FailedVerification' }
        }
    } catch {
        [pscustomobject]@{
            UserPrincipalName = $row.UserPrincipalName
            AttributeChanges  = $null
            MoveNeeded        = $false
            TargetOU          = $row.TargetOU
            Status            = 'Failed'
            Error             = $_.Exception.Message
        }
    }
}

$results
