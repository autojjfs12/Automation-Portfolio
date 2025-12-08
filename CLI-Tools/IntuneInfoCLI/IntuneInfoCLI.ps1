param(
    [string[]]$UserNames
)

# ---------- Connect to Microsoft Graph ----------
try {
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","User.Read.All"
} catch {
    Write-Warning "Graph login failed or not available. Using demo devices instead."
    $UserNames = $UserNames ?? @("j.doe","jj")
    foreach ($user in $UserNames) {
        Write-Host "Intune Devices for $user (Demo)"
        $devices = @(
            @{ DeviceName="DemoLaptop1"; OS="Windows 11"; Compliance="Compliant"; LastCheckIn= (Get-Date).AddHours(-5) },
            @{ DeviceName="DemoPhone1"; OS="iOS 17"; Compliance="Compliant"; LastCheckIn= (Get-Date).AddDays(-1) }
        )
        foreach ($device in $devices) {
            Write-Host "---------------------------"
            Write-Host "Device Name   : $($device.DeviceName)"
            Write-Host "OS            : $($device.OS)"
            Write-Host "Compliance    : $($device.Compliance)"
            Write-Host "Last Check-in : $($device.LastCheckIn)"
            Write-Host "---------------------------"
            Write-Host ""
        }
    }
    return
}

# ---------- Loop through each username ----------
foreach ($user in $UserNames) {
    try {
        $userObj = Get-MgUser -UserId $user -ErrorAction Stop
        $devices = Get-MgDeviceManagementManagedDevice -Filter "userId eq '$($userObj.Id)'" -ErrorAction Stop

        if (-not $devices) {
            Write-Host "No devices found for $user"
            continue
        }

        foreach ($device in $devices) {
            Write-Host "---------------------------"
            Write-Host "Device Name   : $($device.DeviceName)"
            Write-Host "OS            : $($device.OperatingSystem)"
            Write-Host "Compliance    : $($device.ComplianceState)"
            Write-Host "Last Check-in : $($device.LastCheckInDateTime)"
            Write-Host "---------------------------"
            Write-Host ""
        }
    } catch {
        Write-Warning "Failed to retrieve devices for $user. $_"
    }
}

Disconnect-MgGraph
