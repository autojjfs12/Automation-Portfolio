# PowerShell IT automation scripts

[Portfolio home](../README.md) · [Import notes and known limits](PORTFOLIO.md) · [CLI tools](../README.md#explore-the-repository)

Eight scripts cover Exchange Online access, Microsoft Graph group management and reporting, Active Directory employee changes, Windows endpoint tasks, and profile backup. The seven September additions complement the original backup script; the two existing CLI tools remain under `CLI-Tools/`.

## Script catalog

| Script | Purpose and output | Preview or read-only use |
|---|---|---|
| [add-mailbox-users](exchange/add-mailbox-users.ps1) | Batch distribution-group additions or mailbox FullAccess; per-user result objects and optional CSV | `-DryRun`; may authenticate, read Exchange data, and write an export |
| [Provision-SharedMailbox](exchange/Provision-SharedMailbox.ps1) | Create a shared mailbox and grant FullAccess/SendAs; mailbox summary | `-DryRun`; may authenticate and look up the mailbox |
| [Manage-GroupMembership](graph/Manage-GroupMembership.ps1) | Add/remove a user in a static cloud Microsoft 365 or security group; result object | `-DryRun`; may authenticate and read Graph data |
| [Get-BYODDeviceReport](intune/Get-BYODDeviceReport.ps1) | Intune-managed device inventory with personal-ownership flag; objects and optional CSV | Read-only against the tenant; `-OutputPath` writes locally |
| [Invoke-IntuneEntraSync](intune/Invoke-IntuneEntraSync.ps1) | Trigger local workplace-join/MDM tasks and optional computer policy refresh; per-target statuses | `-WhatIf` discovers targets without starting them |
| [Invoke-EmployeeMovementSync](active-directory/Invoke-EmployeeMovementSync.ps1) | Apply CSV-based AD department, title, office, and optional OU changes; per-row results | `-DryRun` reads AD users and validates target OUs |
| [Repair-ChromeInstall](endpoint-remediation/Repair-ChromeInstall.ps1) | Detect Chrome executable/version; optionally stop Chrome and reinstall from a local installer | Detection by default; `-Apply -InstallerPath ... -WhatIf` previews repair |
| [AutomaticBackupScript](AutomaticBackupScript.ps1) | Copy Desktop, Documents, Pictures, and a detected OneDrive folder; timestamped destination, log, HTML, and optional PDF | `-DryRun` skips source-file copies but still creates folders and reports |

## Requirements

Use PowerShell 7 for the examples below. Install the relevant modules before service use and confirm the signed-in account and target environment. The scripts do not supply credentials or grant the permissions needed to run them.

| Workflow | Modules / environment | Access requested or needed |
|---|---|---|
| Exchange scripts | `ExchangeOnlineManagement` | Authorized Exchange Online account with permissions for the requested group, mailbox, or access change |
| Graph membership | `Microsoft.Graph.Authentication`, `Microsoft.Graph.Groups`, `Microsoft.Graph.Users` | Script requests `Group.ReadWrite.All` and `User.Read.All`, including in preview |
| BYOD report | `Microsoft.Graph.Authentication`, `Microsoft.Graph.DeviceManagement` | Script requests `DeviceManagementManagedDevices.Read.All` |
| Employee movement | Windows environment with the `ActiveDirectory` module | Domain connectivity and delegated rights to read/update users and move objects to the intended OU |
| Local synchronization | Windows, PowerShell 7, available workplace-join/MDM scheduled tasks | Local rights to inspect/start the relevant tasks and run policy refresh |
| Chrome repair | Windows, PowerShell 7; trusted local MSI or EXE for repair | Administrator privileges for machine-level repair |
| Profile backup | Windows; readable user profile and writable destination | Access to the selected profile/share; `msedge.exe` discoverable by `Get-Command` for optional PDF output |

The Windows synchronization and repair scripts explicitly reject non-Windows hosts. A successful offline check on macOS does not establish Windows compatibility for an operational deployment.

## Usage examples

Run these commands from the `Scripts` directory in PowerShell. Addresses and OU names are generic placeholders. Replace them with lab values; the supplied CSVs are examples, not live input.

### Batch Exchange access

Choose one input source: `-CsvPath` or `-UserPrincipalName`. The [sample CSV](examples/mailbox-users.sample.csv) requires a `UserPrincipalName` column. Blank identities are ignored and repeated input identities are deduplicated.

```powershell
# Preview distribution-group additions from CSV.
./exchange/add-mailbox-users.ps1 -Mode DistributionGroup -Target 'team@example.com' -CsvPath ./examples/mailbox-users.sample.csv -DryRun

# Preview mailbox FullAccess for a single user with Outlook automapping.
./exchange/add-mailbox-users.ps1 -Mode MailboxAccess -Target 'support@example.com' -UserPrincipalName 'alex@example.com' -AutoMapping -DryRun
```

The script returns `Timestamp`, `User`, `Target`, `Mode`, `Action`, `Status`, and `Message`. Existing membership/access returns `Skipped`; failures are recorded per user so the remaining users can be processed. Add `-ExportPath` to save results outside the checkout. Mailbox access here grants FullAccess only; SendAs is handled by the provisioning script.

### Shared mailbox and cloud group membership

```powershell
# Preview a shared mailbox and requested access.
./exchange/Provision-SharedMailbox.ps1 -Name 'Support Demo' -PrimarySmtpAddress 'support@example.com' -FullAccessUsers 'alex@example.com' -SendAsUsers 'sam@example.com' -DryRun

# Preview one membership addition; use -Action Remove for removal.
./graph/Manage-GroupMembership.ps1 -Group 'Demo Team' -Member 'alex@example.com' -Action Add -DryRun
```

Provisioning rejects an existing non-shared mailbox. Graph membership resolves the group by display name or email and the user by UPN or email; ambiguous matches fail. Dynamic groups and Exchange-managed mail-enabled groups are rejected.

### Device reporting and local synchronization

```powershell
# Read Intune-managed devices for a user; omit the UPN for the full report.
./intune/Get-BYODDeviceReport.ps1 -UserPrincipalName 'alex@example.com'

# Preview local scheduled-task triggers and optional policy refresh on Windows.
./intune/Invoke-IntuneEntraSync.ps1 -IncludePolicyRefresh -WhatIf
```

The report returns corporate and unknown-ownership devices as well as personal devices; `IsLikelyBYOD` is true only when `ManagedDeviceOwnerType` is `personal`. It fetches all managed devices before applying the user filter. Add `-OutputPath` to export a CSV outside the checkout.

Synchronization reports task availability and triggering, not completed enrollment or cloud synchronization. Review the discovered task names on each device type.

### Employee movement

```powershell
./active-directory/Invoke-EmployeeMovementSync.ps1 -InputCsv ./examples/employee-movement.sample.csv -DryRun
```

The [sample CSV](examples/employee-movement.sample.csv) has five required headers: `UserPrincipalName`, `Department`, `Title`, `Office`, and `TargetOU`. Blank attribute/OU values leave the current state unchanged. Set lab OU values before previewing; each requested destination OU is checked before changes.

### Chrome detection and repair preview

```powershell
# Default detection does not stop processes or install software.
./endpoint-remediation/Repair-ChromeInstall.ps1

# Requires an existing trusted local installer even for this preview.
./endpoint-remediation/Repair-ChromeInstall.ps1 -Apply -InstallerPath 'C:\Lab\GoogleChromeStandaloneEnterprise64.msi' -WhatIf
```

The `Healthy` detection status means an executable was found; it does not establish application health. Actual repair may terminate Chrome sessions, uninstall detected MSI registrations, and install the supplied package. Installer authenticity and exit codes are not fully validated by the script. Test repair and recovery on a disposable Windows device.

### User-profile backup

```powershell
# Preview copies on Windows, using a writable lab destination.
./AutomaticBackupScript.ps1 -NetworkPath 'C:\Lab\Backups' -DryRun
```

Backup identifies the last logged-on user from registry/CIM data and resolves a local profile; verify the selected profile in the log. If the supplied destination is unavailable, it falls back to `%ProgramData%\UserBackup_Fallback`. It creates `<User>_<yyyyMMdd_HHmmss>` containing a text log and HTML report, with a PDF attempted if Edge is available. Actual runs copy the selected source folders, skip empty sources, and log copy errors.

**Backup preview still writes output:** `-DryRun` suppresses source-file copying, but destination creation, logging, HTML generation, and the Edge PDF attempt still run. Preview is not a restore test or a proof that every file can be copied. Review errors and independently validate recovery before relying on a backup.

## Usage and safety notes

- Use an authorized lab account/device, review the source and targets, and start with the applicable preview or detection mode. There is no universal `-DryRun` switch across the scripts. Removing a preview flag applies changes; Chrome repair additionally requires `-Apply`.
- Preview can authenticate and read real data. Graph membership requests write scopes even under `-DryRun`. Exports, backup contents, and reports may contain user identities, device identifiers, or private files; store them outside this public repository.
- Employee movement processes rows independently; attribute updates and OU moves are not transactional and can partially succeed. Unusual distinguished-name escaping and cross-domain moves require separate testing.
- Exchange/Graph post-change checks can be affected by eventual consistency. Shared-mailbox provisioning verifies mailbox type, not every resulting permission. Inspect result objects and confirm changes independently where needed.

For the two console tools, use the actual filenames [UserInfoCLI.ps1](../CLI-Tools/UserInfoCLI/UserInfoCLI.ps1) and [IntuneInfoCLI.ps1](../CLI-Tools/IntuneInfoCLI/IntuneInfoCLI.ps1). Both attempt Graph authentication and fall back to labeled demo output if connection fails; neither has an offline demo switch. `UserInfoCLI` may install `Microsoft.Graph` automatically and supports `-ShowGroups`. Console formatting and demo output do not establish live API correctness.

## Validation and coverage

From this directory:

```powershell
# Parse every repository PowerShell file, including the CLI tools.
./tests/Parse-AllScripts.ps1 -Root ..

# Run the existing fake-service smoke harness.
./tests/Smoke-Portfolio.ps1
```

Both checks passed on macOS with PowerShell during the October 2026 documentation review. Parsing checks syntax without executing the scripts. The offline smoke harness replaces service and OS commands with fakes and bypasses Windows guards only inside the harness. It covers:

- Mailbox batch single-row CSV/direct-user input and structured preview results.
- BYOD personal/company/unknown ownership classification.
- Rejection of a non-shared mailbox during provisioning.
- AD Department/Title/Office parameter mapping with a fake user.
- No-change synchronization and Chrome `-WhatIf` paths.

It does not validate all scripts or branches, real authorization, live Microsoft 365/AD behavior, Windows task execution, actual installers, backup/restore, or CLI query results. No live tenant or Windows operational test was performed during this documentation review. See [PORTFOLIO.md](PORTFOLIO.md) for import provenance, corrections, and additional limits.
