<#
    User Profile Backup Script (Sanitized / Portfolio-Friendly)

    - Auto-detect last logged-on user
    - Backup folder name: <User>_<yyyyMMdd_HHmmss>
    - Skips empty source folders (no files under them)
    - Optional DryRun mode (no file writes, just logs what *would* happen)
    - Dual progress bars (overall + per-folder)
    - Ctrl+C cancel handler (logs and exits cleanly)
    - Logs saved inside the created backup folder
    - Verifies network path; falls back to local if unavailable
    - Generates HTML + PDF report (via Microsoft Edge headless, if available)
#>

param(
    # Generic example network share path – replace with your own in real usage.
    [string]$NetworkPath = "\\fileserver\user-backups",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# ---------- Helpers ----------
function Write-Log {
    param([string]$Message)
    if (-not $script:LogFile) { return }
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[$stamp] $Message" | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
}

function Get-LastLoggedOnUser {
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI'
    $sam = $null; $upn = $null
    try { $sam = (Get-ItemProperty -Path $regPath -Name 'LastLoggedOnSAMUser' -ErrorAction SilentlyContinue).LastLoggedOnSAMUser } catch {}
    try { $upn = (Get-ItemProperty -Path $regPath -Name 'LastLoggedOnUser'    -ErrorAction SilentlyContinue).LastLoggedOnUser    } catch {}
    if ($sam) { $raw = $sam } else { $raw = $upn }
    if (-not $raw) { try { $raw = (Get-CimInstance Win32_ComputerSystem).UserName } catch {} }
    if (-not $raw) { throw "Unable to determine last logged-on user." }
    if ($raw -match '\\') { return ($raw -split '\\',2)[1] }
    if ($raw -match '@')  { return ($raw -split '@',2)[0] }
    return $raw
}

function Resolve-UserProfilePath([string]$SamUser) {
    $candidate = Join-Path 'C:\Users' $SamUser
    if (Test-Path $candidate) { return $candidate }

    $match = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -ieq $SamUser } | Select-Object -First 1
    if ($match) { return $match.FullName }

    $profiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
                Where-Object { $_.LocalPath -like 'C:\Users\*' -and
                               ($_.LocalPath -notmatch '\\(Default|Default User|Public|All Users)$') } |
                Sort-Object -Property LastUseTime -Descending
    if ($profiles -and $profiles[0].LocalPath) { return $profiles[0].LocalPath }

    throw "Could not resolve a profile path for user '$SamUser'."
}

function Get-OneDriveFolder([string]$UserProfile) {
    # Try to find any folder at profile root that starts with 'OneDrive'
    $candidates = Get-ChildItem -LiteralPath $UserProfile -Directory -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -like 'OneDrive*' }
    if ($candidates) {
        $biz = $candidates | Where-Object { $_.Name -like 'OneDrive -*' } | Select-Object -First 1
        if ($biz) { return $biz.Name }
        return ($candidates | Select-Object -First 1).Name
    }
    return $null
}

# ---------- Derive user + destination ----------
try { $TargetUser = Get-LastLoggedOnUser } catch { Write-Error $_; exit 1 }
try { $UserProfile = Resolve-UserProfilePath -SamUser $TargetUser } catch { Write-Error $_; exit 1 }

# Folder list (dynamic OneDrive detection)
$oneDriveName = Get-OneDriveFolder -UserProfile $UserProfile
$FoldersToBackup = @("Desktop","Documents","Pictures")
if ($oneDriveName) { $FoldersToBackup += $oneDriveName }

$Timestamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$FolderName  = "${TargetUser}_$Timestamp"

# Prefer network destination; else fall back to local
$DestRoot = $NetworkPath
if (-not (Test-Path $DestRoot)) {
    $DestRoot = Join-Path $env:ProgramData "UserBackup_Fallback"
    New-Item -Path $DestRoot -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Network path unavailable. Using local fallback: $DestRoot"
}

$BackupDestination = Join-Path -Path $DestRoot -ChildPath $FolderName

if (-not (Test-Path $BackupDestination)) {
    try {
        New-Item -Path $BackupDestination -ItemType Directory -Force | Out-Null
        Write-Host "Created backup folder: $BackupDestination"
    } catch {
        Write-Error "Failed to create backup folder: $_"
        exit 1
    }
}

# Log file (inside created folder)
$script:LogFile = Join-Path $BackupDestination "BackupLog_$Timestamp.txt"
"Backup started $(Get-Date) on $env:COMPUTERNAME. User: $TargetUser. PS $($PSVersionTable.PSVersion). DryRun: $DryRun" | Out-File -FilePath $script:LogFile -Encoding UTF8
Write-Log "User profile: $UserProfile"
Write-Log "Folders to back up: $($FoldersToBackup -join ', ')"

# ---------- Ctrl+C cancellation (PS 5.1-safe) ----------
$script:Cancelled = $false
$global:__ckpHandler = [System.ConsoleCancelEventHandler]{
    param($sender, $e)
    $script:Cancelled = $true
    $e.Cancel = $true
    try { Write-Log "Backup cancelled by user (Ctrl+C)." } catch {}
}
[Console]::add_CancelKeyPress($global:__ckpHandler)

# ---------- Core ----------
function Backup-Files {
    $scriptStart = Get-Date
    $overallId   = 0
    $childId     = 1

    Write-Host "Indexing items for user '$TargetUser' ($UserProfile)..."
    Write-Log  "Indexing items under $UserProfile"

    $allItems = New-Object System.Collections.Generic.List[System.IO.FileSystemInfo]

    foreach ($folder in $FoldersToBackup) {
        $SourcePath = Join-Path $UserProfile $folder
        if (-not (Test-Path $SourcePath)) {
            Write-Warning "Source folder not found: $SourcePath"
            Write-Log    "Source folder not found: $SourcePath (skipped)"
            continue
        }

        # Empty = no files anywhere under it
        $hasFiles = Get-ChildItem -Path $SourcePath -Recurse -Force -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $hasFiles) {
            Write-Host "Skipping empty folder: $SourcePath"
            Write-Log  "Skipped empty source folder: $SourcePath (no files found)"
            continue
        }

        try {
            $items = Get-ChildItem -Path $SourcePath -Recurse -Force -ErrorAction SilentlyContinue
            if ($items) {
                foreach ($it in $items) {
                    try { $it | Add-Member -NotePropertyName RootFolder -NotePropertyValue $folder -Force } catch {}
                    [void]$allItems.Add($it)
                }
                Write-Log "Queued $($items.Count) items from: $SourcePath"
            }
        } catch {
            Write-Warning "Failed to enumerate: $SourcePath. $_"
            Write-Log    "Failed to enumerate: $SourcePath. $_"
        }
    }

    $total = $allItems.Count
    if ($total -eq 0) {
        Write-Warning "No items found to back up. Nothing to do."
        Write-Log    "No items found to back up. Exiting."
        return
    }

    # Per-folder totals
    $folderTotals = @{}
    $groups = $allItems | Group-Object RootFolder
    foreach ($g in $groups) { $folderTotals[$g.Name] = $g.Count }

    $processed = 0
    $fileCount = 0
    $dirCount  = 0

    $currentFolder = $null
    $curProc = 0
    $curTotal = 0

    try {
        foreach ($item in $allItems) {
            if ($script:Cancelled) { break }

            if ($currentFolder -ne $item.RootFolder) {
                $currentFolder = $item.RootFolder
                $curProc = 0
                $curTotal = if ($folderTotals.ContainsKey($currentFolder)) { $folderTotals[$currentFolder] } else { 0 }
                Write-Progress -Id $childId -ParentId $overallId -Activity "Processing: $currentFolder" -Status "0 / $curTotal" -PercentComplete 0
            }

            $relativePath = $item.FullName.Substring($UserProfile.Length + 1)
            $destination  = Join-Path $BackupDestination $relativePath

            if ($DryRun) {
                Write-Log "DRYRUN: Would copy: $($item.FullName) -> $destination"
            } else {
                if ($item.PSIsContainer) {
                    New-Item -Path $destination -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                    $dirCount++
                } else {
                    try {
                        Copy-Item -Path $item.FullName -Destination $destination -Force -ErrorAction Stop
                        $fileCount++
                    } catch {
                        if ($_.Exception.Message -match "because it is being used by another process") {
                            Write-Log "Skipped (in use): $($item.FullName)"
                        } else {
                            Write-Log "Error copying $($item.FullName): $_"
                        }
                    }
                }
            }

            $processed++
            $curProc++

            $overallPct = [int](($processed / $total) * 100)
            $childPct   = if ($curTotal -gt 0) { [int](($curProc / $curTotal) * 100) } else { 100 }

            Write-Progress -Id $overallId -Activity "Backing up $TargetUser → $BackupDestination" -Status "Processed: $processed / $total" -PercentComplete $overallPct
            Write-Progress -Id $childId   -ParentId $overallId -Activity "Processing: $currentFolder" -Status "$curProc / $curTotal" -PercentComplete $childPct
        }

        Write-Progress -Id $childId -Completed -Activity "Folder complete"
        Write-Progress -Id $overallId -Completed -Activity "Backup complete"

        $elapsed = (Get-Date) - $scriptStart
        if ($script:Cancelled) {
            Write-Warning "Backup cancelled by user."
            Write-Log    "Backup cancelled mid-run. Processed: $processed / $total"
        } elseif ($DryRun) {
            Write-Host "Dry run complete in $([int]$elapsed.TotalMinutes)m $([int]$elapsed.Seconds)s."
            Write-Log  "Dry run finished."
        } else {
            Write-Host "Backup completed in $([int]$elapsed.TotalMinutes)m $([int]$elapsed.Seconds)s."
            Write-Host "Files copied : $fileCount"
            Write-Host "Folders made : $dirCount"
            Write-Host "Log file     : $script:LogFile"
            Write-Log  "Backup completed. Files: $fileCount, Folders: $dirCount"
        }
    } catch {
        Write-Error "An error occurred during backup: $_"
        Write-Log  "Fatal error: $_"
        Write-Progress -Id $childId -Completed -Activity "Aborted"
        Write-Progress -Id $overallId -Completed -Activity "Aborted"
    }
}

# ---------- HTML → PDF report ----------
function Convert-LogToPdf {
    param(
        [string]$LogPath,
        [string]$DestFolder,
        [string]$User,
        [string]$Timestamp
    )

    if (-not (Test-Path $LogPath)) { return }

    $htmlPath = Join-Path $DestFolder "BackupReport_$Timestamp.html"
    $pdfPath  = Join-Path $DestFolder "BackupReport_$Timestamp.pdf"

    $logRaw = Get-Content -Path $LogPath -Raw
    # HTML-encode log
    $logHtml = $logRaw
    try {
        Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
        if ([type]::GetType("System.Web.HttpUtility")) {
            $logHtml = [System.Web.HttpUtility]::HtmlEncode($logRaw)
        } else {
            $logHtml = $logRaw -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
        }
    } catch {
        $logHtml = $logRaw -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
    }

    $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

@"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Backup Report - $User - $Timestamp</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; }
h1 { margin: 0 0 6px 0; }
h2 { margin-top: 28px; }
.summary { background:#f5f7fa; border:1px solid #dfe3e8; padding:12px 16px; border-radius:8px; }
pre { white-space: pre-wrap; word-wrap: break-word; background:#fff; border:1px solid #e5e7eb; padding:12px; border-radius:8px; }
.meta { color:#555; font-size:12px; margin-bottom: 16px; }
label { color:#333; font-weight:600; }
</style>
</head>
<body>
  <h1>Backup Report</h1>
  <div class="meta">Generated: $now</div>

  <div class="summary">
    <div><label>Computer:</label> $env:COMPUTERNAME</div>
    <div><label>User:</label> $User</div>
    <div><label>Destination:</label> $($DestFolder)</div>
    <div><label>Text log:</label> $([System.IO.Path]::GetFileName($LogPath))</div>
  </div>

  <h2>Log Output</h2>
  <pre>$logHtml</pre>
</body>
</html>
"@ | Out-File -FilePath $htmlPath -Encoding UTF8

    # Try Edge headless to create PDF
    $edgeCmd = Get-Command msedge.exe -ErrorAction SilentlyContinue
    if ($edgeCmd) {
        $args = @("--headless","--disable-gpu","--print-to-pdf=""$pdfPath""","--window-size=1024,1400",$htmlPath)
        Start-Process -FilePath $edgeCmd.Source -ArgumentList $args -Wait
        if (Test-Path $pdfPath) {
            Write-Host "PDF report created: $pdfPath"
            Write-Log  "PDF report created: $pdfPath"
            return
        }
    }

    Write-Warning "Microsoft Edge not found or PDF creation failed — HTML report saved: $htmlPath"
    Write-Log     "PDF generation unavailable. Saved HTML report: $htmlPath"
}

# ---------- Run with cleanup of Ctrl+C handler ----------
try {
    Backup-Files
} finally {
    if ($global:__ckpHandler) {
        [Console]::remove_CancelKeyPress($global:__ckpHandler)
        $global:__ckpHandler = $null
    }
    # Create PDF/HTML report after the handler is removed
    try { Convert-LogToPdf -LogPath $script:LogFile -DestFolder $BackupDestination -User $TargetUser -Timestamp $Timestamp } catch {}
}
