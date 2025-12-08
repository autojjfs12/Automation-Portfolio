param(
    [string[]]$UserNames
)

# ---------- Connect to Microsoft Graph ----------
try {
    Connect-MgGraph -Scopes "User.Read.All"
} catch {
    Write-Warning "Graph login failed or not available. Using demo data instead."
    $UserNames = $UserNames ?? @("j.doe","jj")
    foreach ($user in $UserNames) {
        Write-Host "User Info for $user (Demo)"
        Write-Host "----------------------"
        Write-Host "Display Name: $user Fullname"
        Write-Host "Email: $user@example.com"
        Write-Host "Department: IT"
        Write-Host "Job Title: Demo Analyst"
        Write-Host ""
    }
    return
}

# ---------- Loop through usernames ----------
foreach ($user in $UserNames) {
    try {
        $graphUser = Get-MgUser -UserId $user -ErrorAction Stop
        Write-Host "User Info for $user"
        Write-Host "----------------------"
        Write-Host "Display Name: $($graphUser.DisplayName)"
        Write-Host "Email       : $($graphUser.Mail)"
        Write-Host "Department  : $($graphUser.Department)"
        Write-Host "Job Title   : $($graphUser.JobTitle)"
        Write-Host ""
    } catch {
        Write-Warning "User $user not found or insufficient permissions."
    }
}

Disconnect-MgGraph
