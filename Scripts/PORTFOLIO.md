# Enterprise IT automation scripts

Seven environment-neutral PowerShell scripts imported from the supplied `enterprise-it-automation-portfolio-v2.zip`. The existing backup script, CLI tools, and documentation are preserved.

| Script | Purpose | Preview mode | Requirements |
|---|---|---|---|
| [add-mailbox-users](exchange/add-mailbox-users.ps1) | Batch distribution-group membership or mailbox FullAccess | `-DryRun` | ExchangeOnlineManagement |
| [Provision-SharedMailbox](exchange/Provision-SharedMailbox.ps1) | Create a shared mailbox and grant access | `-DryRun` | ExchangeOnlineManagement |
| [Manage-GroupMembership](graph/Manage-GroupMembership.ps1) | Add/remove users from static cloud Microsoft 365 or security groups | `-DryRun` | Microsoft.Graph.Authentication, Groups, Users |
| [Get-BYODDeviceReport](intune/Get-BYODDeviceReport.ps1) | Report Intune-managed devices and flag personal ownership | Read-only | Microsoft.Graph.Authentication, DeviceManagement |
| [Invoke-IntuneEntraSync](intune/Invoke-IntuneEntraSync.ps1) | Trigger local workplace-join/MDM scheduled tasks | `-WhatIf` | Windows, PowerShell 7, appropriate local privileges |
| [Invoke-EmployeeMovementSync](active-directory/Invoke-EmployeeMovementSync.ps1) | Update AD department, title, office, and optional OU | `-DryRun` | Windows, ActiveDirectory module, directory permissions |
| [Repair-ChromeInstall](endpoint-remediation/Repair-ChromeInstall.ps1) | Detect Chrome and optionally reinstall | Default detection; `-Apply -WhatIf` previews | Windows, PowerShell 7, trusted local installer, administrator privileges for repair |

Run from this `Scripts` directory using PowerShell 7. Service scripts require an authorized account and the corresponding modules; preview modes may still authenticate and read service data.

```powershell
./exchange/add-mailbox-users.ps1 -Mode DistributionGroup -Target 'team@example.com' -CsvPath ./examples/mailbox-users.sample.csv -DryRun
./exchange/Provision-SharedMailbox.ps1 -Name 'Support Demo' -PrimarySmtpAddress 'support@example.com' -DryRun
./graph/Manage-GroupMembership.ps1 -Group 'Demo Team' -Member 'alex@example.com' -Action Add -DryRun
./intune/Get-BYODDeviceReport.ps1 -UserPrincipalName 'alex@example.com'
./active-directory/Invoke-EmployeeMovementSync.ps1 -InputCsv ./examples/employee-movement.sample.csv -DryRun
./intune/Invoke-IntuneEntraSync.ps1 -WhatIf
./endpoint-remediation/Repair-ChromeInstall.ps1
```

The CSV files use generic example identities. Substitute lab values before use. Scripts accept environment-specific identities and paths as parameters; no credentials or employer source files are included. Reports can contain real user/device information when run against a tenant; keep those outputs out of version control.

## Import corrections

The supplied package remains the source. Targeted fixes made during import:

- Mailbox batch input handles single-row CSVs and single users consistently and returns objects without mixing formatting records into the pipeline.
- BYOD reporting selects `managedDeviceOwnerType` and avoids an unsupported fallback field under strict mode. See [Microsoft's managed-device ownership definition](https://learn.microsoft.com/en-us/graph/api/resources/intune-devices-manageddeviceownertype?view=graph-rest-1.0).
- Employee movement rejects empty input, checks target OUs before changes, and passes Department/Title/Office as named parameters instead of LDAP attribute replacements. See [Set-ADUser](https://learn.microsoft.com/en-us/powershell/module/activedirectory/set-aduser).
- Shared-mailbox provisioning rejects an existing non-shared mailbox before granting permissions.
- Graph group membership rejects dynamic and Exchange-managed groups.
- Local synchronization reports skipped actions honestly under `-WhatIf` and checks the policy-refresh exit code.
- Chrome repair stops no processes under `-WhatIf`; process termination respects confirmation.

## Validation and limits

```powershell
./tests/Parse-AllScripts.ps1
./tests/Smoke-Portfolio.ps1
```

Syntax validation and offline checks passed during import. Offline checks replace service and OS commands with fakes; Windows-only guards are bypassed only inside the test harness. They cover single-user/CSV input, BYOD ownership, mailbox-type protection, AD attribute mapping, and no-change Windows preview paths. No live tenant, domain controller, scheduled task, or installer was exercised.

These are portfolio examples requiring lab validation before operational use:

- BYOD output covers Intune-managed devices, including corporate devices flagged as non-personal; it is not an inventory of every Entra-registered device.
- Directory/Exchange verification can be affected by eventual consistency. Mailbox provisioning verifies mailbox type, not every resulting permission.
- Employee-movement rows are independent, not transactional. Blank values leave attributes unchanged. Unusual distinguished-name escaping and cross-domain moves need separate testing.
- Synchronization discovers local scheduled tasks by name and reports triggering, not completed enrollment or cloud synchronization. Review the `-WhatIf` targets on each device type.
- Chrome detection checks executable presence/version, not application health. Repair may interrupt sessions, uninstalls detected MSI registrations, and does not fully validate installer exit codes or authenticity. Supply a trusted installer and test recovery in a disposable Windows environment.

The package's duplicate UserInfoCLI/IntuneInfoCLI files and top-level README were intentionally excluded. This document consolidates the package's relevant architecture, security, and testing notes without replacing existing documentation.
