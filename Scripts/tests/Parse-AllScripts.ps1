[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failed = @()
Get-ChildItem -Path $Root -Recurse -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failed += [pscustomobject]@{ File=$_.FullName; Errors=($errors.Message -join '; ') }
    }
}

if ($failed.Count -gt 0) {
    $failed | Format-Table -AutoSize
    throw "$($failed.Count) script(s) failed to parse."
}

'All PowerShell scripts parsed successfully.'
