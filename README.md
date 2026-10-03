# IT Automation Portfolio

PowerShell projects for identity and access management, Microsoft 365 administration, and Windows endpoint operations. This repository brings together eight automation scripts and two CLI tools, with sample CSV inputs and offline checks for selected workflows.

The code demonstrates practical approaches to repetitive IT work: validate inputs, inspect current state, preview changes, and return results that an operator can review. Each project has its own safeguards and limits; these are portfolio examples requiring lab validation before operational use.

## Featured work

| Project | IT workflow | What to look for in the code |
|---|---|---|
| [Batch Exchange access](Scripts/exchange/add-mailbox-users.ps1) | Add users to a distribution group or grant mailbox FullAccess | Direct or CSV input, recipient validation, existing-state checks, per-user results, and optional CSV export |
| [Shared mailbox provisioning](Scripts/exchange/Provision-SharedMailbox.ps1) | Create a shared mailbox and grant FullAccess or SendAs | Existing mailbox-type protection, permission checks, and a preview of requested access |
| [Cloud group membership](Scripts/graph/Manage-GroupMembership.ps1) | Add or remove a member through Microsoft Graph | Unique identity resolution, dynamic-group rejection, and final membership verification |
| [Employee movement](Scripts/active-directory/Invoke-EmployeeMovementSync.ps1) | Update AD department, title, office, and optional OU | CSV validation, target-OU lookup, row-level processing, and post-change checks |
| [BYOD device reporting](Scripts/intune/Get-BYODDeviceReport.ps1) | Report Intune-managed devices and flag personal ownership | Explicit Graph property selection, user filtering, structured output, and CSV export |

## Explore the repository

- **[Scripts and usage guide](Scripts/README.md):** all eight scripts, including local Intune/Entra task triggering, Chrome detection/repair, and user-profile backup.
- **[UserInfoCLI](CLI-Tools/UserInfoCLI/UserInfoCLI.ps1):** console queries for user details and optional group membership via `-ShowGroups`.
- **[IntuneInfoCLI](CLI-Tools/IntuneInfoCLI/IntuneInfoCLI.ps1):** console queries for a user's managed devices, OS, compliance, and check-in information.
- **[Import notes and validation limits](Scripts/PORTFOLIO.md):** provenance, targeted corrections, and known limits of the seven September additions.
- **[Backup documentation](Docs/Back-Up%20Script%20Documentation/Doc)** and **[CLI documentation](Docs/CLI%20Tools%20Documentation/Doc):** earlier design notes. Use the current script filenames and source when following examples; the older CLI notes refer to `IntuneCLI.ps1`, whose repository filename is `IntuneInfoCLI.ps1`.

`Apps/` is reserved for future work and currently contains only a placeholder.

## Getting started

Use PowerShell 7 for the examples. Exchange and Graph workflows require the corresponding modules and an authorized account. AD, backup, synchronization, and repair workflows need a suitable Windows environment; see the [script requirements](Scripts/README.md#requirements).

From the repository root, preview a batch operation with lab identities:

```powershell
Set-Location ./Scripts
./exchange/add-mailbox-users.ps1 -Mode DistributionGroup -Target 'team@example.com' -CsvPath ./examples/mailbox-users.sample.csv -DryRun
```

Replace the sample addresses with identities in your own test environment. `-DryRun` can still authenticate and read service data. The backup script also writes folders, logs, and reports during its preview. The CLI tools attempt Graph sign-in and show demo data only if connection fails; `UserInfoCLI` can install `Microsoft.Graph` if it is absent. There is no explicit offline demo switch.

## Validation

From the repository root:

```powershell
# Parse all PowerShell files, including both CLI tools; does not execute them.
./Scripts/tests/Parse-AllScripts.ps1 -Root .

# Exercise selected workflows with fake service and OS commands.
./Scripts/tests/Smoke-Portfolio.ps1
```

Both checks passed on macOS with PowerShell during the October 2026 documentation review. The smoke harness covers selected input handling, ownership classification, mailbox-type protection, AD attribute mapping, and Windows preview paths. It does not exercise every script or prove live service behavior.

Live Microsoft 365/AD operations, Windows task execution, installer behavior, backup/restore, and CLI query results have not been validated in that review. Keep tenant exports, user data, backup contents, and operational logs outside this public repository. See the [usage and safety notes](Scripts/README.md#usage-and-safety-notes) before running a workflow.
