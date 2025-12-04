📂 Scripts Folder — Overview

This folder contains automation scripts written in PowerShell. Each script is designed to improve IT efficiency, support operations, and demonstrate automation engineering skills.
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
🔄 AutomaticBackupScript.ps1

A PowerShell script that securely backs up user profile data from a Windows machine.

✨ Features

1. Detects last logged-in user automatically
2. Backups Desktop, Documents, Pictures, and OneDrive (if available)
3. Creates timestamped backup directories
4. Logs every action to a text file
5. Supports DryRun mode
6. Generates HTML + PDF backup reports
7. Shows multi-level progress bars
8. Includes safe Ctrl + C interruption handling
9. Falls back to local storage if network path is unavailable

▶ How to Run
Run normally:
.\AutomaticBackupScript.ps1

Run in Dry Mode (no files copied):
.\AutomaticBackupScript.ps1 -DryRun

Customize the backup location:
.\AutomaticBackupScript.ps1 -NetworkPath "\\server\share\path"

📁 Output Example
Backup_JohnDoe_20250101_153022\
│
├── Desktop\
├── Documents\
├── Pictures\
├── OneDrive\
│
├── BackupLog_20250101_153022.txt
└── BackupReport_20250101_153022.pdf

🛡 Notes
- This script uses no sensitive company data.
- All examples and paths are generic for safe public demonstration.
- Ideal portfolio project for Automation Engineer / IAM Engineer / Endpoint Engineer roles.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
