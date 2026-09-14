[CmdletBinding()]
param(
    [string]$UserPrincipalName,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Module {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) { throw "Required module '$Name' is not installed." }
}

Assert-Module 'Microsoft.Graph.Authentication'
Assert-Module 'Microsoft.Graph.DeviceManagement'

$ctx = Get-MgContext -ErrorAction SilentlyContinue
if (-not $ctx -or 'DeviceManagementManagedDevices.Read.All' -notin $ctx.Scopes) {
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All' -NoWelcome | Out-Null
}

$properties = 'id,deviceName,userPrincipalName,operatingSystem,complianceState,managementAgent,deviceEnrollmentType,managedDeviceOwnerType,manufacturer,model,serialNumber,lastSyncDateTime,enrolledDateTime'
$devices = @(Get-MgDeviceManagementManagedDevice -Property $properties -All)

if ($UserPrincipalName) {
    $devices = @($devices | Where-Object { $_.UserPrincipalName -ieq $UserPrincipalName })
}

$report = $devices | ForEach-Object {
    $isPersonal = ($_.ManagedDeviceOwnerType -eq 'personal')
    [pscustomobject]@{
        DeviceName           = $_.DeviceName
        UserPrincipalName    = $_.UserPrincipalName
        OperatingSystem      = $_.OperatingSystem
        ComplianceState      = $_.ComplianceState
        ManagementAgent      = $_.ManagementAgent
        EnrollmentType       = $_.DeviceEnrollmentType
        OwnerType            = $_.ManagedDeviceOwnerType
        IsLikelyBYOD          = $isPersonal
        Manufacturer         = $_.Manufacturer
        Model                = $_.Model
        SerialNumber         = $_.SerialNumber
        EnrolledDateTime     = $_.EnrolledDateTime
        LastSyncDateTime     = $_.LastSyncDateTime
    }
}

if ($OutputPath) {
    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding utf8
}

$report
