[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$InstallerPath,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw 'This script must be run on Windows.' }

$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
) | Where-Object { $_ -and (Test-Path $_) }

function Get-ChromeState {
    $exe = $chromePaths | Select-Object -First 1
    if (-not $exe) {
        $exe = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    }

    $version = if ($exe) { (Get-Item $exe).VersionInfo.ProductVersion } else { $null }
    [pscustomobject]@{ Installed=[bool]$exe; Executable=$exe; Version=$version }
}

$before = Get-ChromeState
if ($before.Installed -and -not $Apply) {
    [pscustomobject]@{ Status='Healthy'; Installed=$true; Version=$before.Version; Executable=$before.Executable; Message='Chrome is installed. Use -Apply only when remediation is actually required.' }
    return
}

if (-not $Apply) {
    [pscustomobject]@{ Status='DetectionOnly'; Installed=$before.Installed; Version=$before.Version; Executable=$before.Executable; Message='No changes made. Re-run with -Apply and provide -InstallerPath when reinstall is needed.' }
    return
}

if (-not $InstallerPath -or -not (Test-Path $InstallerPath)) {
    throw 'A valid -InstallerPath is required when -Apply is used.'
}

if ($WhatIfPreference) {
    [pscustomobject]@{ Status='WhatIf'; Installed=$before.Installed; Version=$before.Version; Executable=$before.Executable; Message='Would stop Chrome and reinstall using the supplied installer. No changes made.' }
    return
}
if ($PSCmdlet.ShouldProcess('Chrome processes', 'Stop processes before reinstall')) {
    Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

$uninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$chromeEntries = foreach ($root in $uninstallRoots) {
    Get-ItemProperty $root -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Google Chrome*' }
}

foreach ($entry in $chromeEntries) {
    if ($entry.UninstallString) {
        $cmd = $entry.UninstallString
        if ($cmd -match 'msiexec') {
            $productCode = [regex]::Match($cmd, '\{[0-9A-Fa-f-]+\}').Value
            if ($productCode -and $PSCmdlet.ShouldProcess('Google Chrome', "Uninstall MSI $productCode")) {
                Start-Process msiexec.exe -ArgumentList "/x $productCode /qn /norestart" -Wait
            }
        }
    }
}

if ($PSCmdlet.ShouldProcess($InstallerPath, 'Install Google Chrome')) {
    $ext = [IO.Path]::GetExtension($InstallerPath).ToLowerInvariant()
    if ($ext -eq '.msi') {
        Start-Process msiexec.exe -ArgumentList "/i `"$InstallerPath`" /qn /norestart" -Wait
    } else {
        Start-Process -FilePath $InstallerPath -ArgumentList '/silent /install' -Wait
    }
}

Start-Sleep -Seconds 2
$after = Get-ChromeState
[pscustomobject]@{
    Status     = if ($after.Installed) { 'Success' } else { 'FailedVerification' }
    Installed  = $after.Installed
    Version    = $after.Version
    Executable = $after.Executable
}
