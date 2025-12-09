param(
    [string[]]$UserNames,
    [switch]$ShowGroups
)

# ---------- Ensure Microsoft Graph module is installed ----------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    Write-Host "Installing Microsoft.Graph module..."
    Install-Module Microsoft.Graph -Scope CurrentUser -Force
}

# ---------- Connect to Graph automatically ----------
try {
    Connect-MgGraph -Scopes "User.Read.All","Group.Read.All"
    Write-Host "Successfully connected to Microsoft Graph."
} catch {
    Write-Warning "Unable to connect to Microsoft Graph. Using demo data instead."
    $UseMock = $true
}

# ---------- Fallback mock data ----------
if (-not $UserNames -or $UserNames.Count -eq 0) {
    $UserNames = @("j.doe","jj")
}
if ($UseMock) {
    foreach ($user in $UserNames) {
        Write-Host "User Info for $user (Demo)"
        Write-Host "----------------------"
        Write-Host "Display Name: $user Demo"
        Write-Host "Email: $user@example.com"
        Write-Host "Department: IT"
        Write-Host "Job Title: Demo Analyst"

        if ($ShowGroups) {
            Write-Host "Groups:"
            "Group A","Group B","Security Group 1" | ForEach-Object { Write-Host " - $_" }
        }
        Write-Host ""
    }
    return
}

# ---------- Live Graph query ----------
foreach ($user in $UserNames) {
    try {
        $graphUser = Get-MgUser -UserId $user
        Write-Host "User Info for $user"
        Write-Host "----------------------"
        Write-Host "Display Name: $($graphUser.DisplayName)"
        Write-Host "Email: $($graphUser.Mail)"
        Write-Host "Department: $($graphUser.Department)"
        Write-Host "Job Title: $($graphUser.JobTitle)"

        if ($ShowGroups) {
            $groups = Get-MgUserMemberOf -UserId $graphUser.Id | Select-Object -ExpandProperty DisplayName
            Write-Host "Groups:"
            foreach ($g in $groups) { Write-Host " - $g" }
        }

        Write-Host ""
    } catch {
        Write-Warning "Could not retrieve data for $user. $_"
    }
}

# ---------- Disconnect Graph ----------
Disconnect-MgGraph

