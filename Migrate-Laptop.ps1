<#
.SYNOPSIS
    Interactive wizard for migrating from one Windows laptop to another.
    Scans your old laptop, generates reviewable scripts, and guides you through setup.

.DESCRIPTION
    Single-file, zero-dependency PowerShell script. Works on Windows 10/11 with PowerShell 5.1+.

    What it does:
      1. SCAN  — Discovers drives, installed software, configs, and user data folders
      2. PLAN  — Generates reviewable scripts: Install-Software.ps1, Transfer-Data.ps1, Restore-Configs.ps1
      3. EXECUTE — Guides you through running the generated scripts on the new laptop

    You stay in full control — every script is reviewed before running.
    Nothing is deleted or modified on the old laptop.

    Supports transfer via: Network (robocopy), USB/External Drive, or Cloud (OneDrive).

.PARAMETER OutputDir
    Where scan results and generated scripts are saved. Default: ./migration-output

.PARAMETER ScanOnly
    Run Phase 1 (scan) only — no script generation or execution.

.PARAMETER FromCache
    Skip scanning and use a previous scan result (JSON file) to generate scripts.

.PARAMETER CacheFile
    Path to a specific scan cache JSON file. Used with -FromCache.

.EXAMPLE
    # Just run it — interactive wizard guides you:
    .\Migrate-Laptop.ps1

.EXAMPLE
    # Scan only (no script generation):
    .\Migrate-Laptop.ps1 -ScanOnly

.EXAMPLE
    # Generate scripts from a previous scan:
    .\Migrate-Laptop.ps1 -FromCache -CacheFile ".\migration-output\scan-2026-03-29.json"
#>

[CmdletBinding()]
param(
    [string]$OutputDir,
    [switch]$ScanOnly,
    [switch]$FromCache,
    [string]$CacheFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $OutputDir) { $OutputDir = Join-Path $scriptDir "migration-output" }

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 0: BANNER & INTERACTIVE MENU
# ═══════════════════════════════════════════════════════════════════════════

function Show-Banner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║           Migrate-Laptop — Laptop Migration Wizard          ║" -ForegroundColor Cyan
    Write-Host "  ║                                                              ║" -ForegroundColor Cyan
    Write-Host "  ║  Scans your old laptop, generates install & transfer scripts,║" -ForegroundColor Cyan
    Write-Host "  ║  and guides you through setting up your new machine.         ║" -ForegroundColor Cyan
    Write-Host "  ║                                                              ║" -ForegroundColor Cyan
    Write-Host "  ║  Safe by design — reads only, never deletes or modifies.     ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Created by gauravkhurana.com for the community" -ForegroundColor DarkCyan
    Write-Host "  #SharingIsCaring" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Like this tool? Star the repo & connect:" -ForegroundColor DarkGray
    Write-Host "    github.com/gauravkhuraana/new-laptop-setup" -ForegroundColor DarkCyan
    Write-Host "    gauravkhurana.com/connect" -ForegroundColor DarkCyan
    Write-Host ""
}

$script:ChosenMode = $null
$script:RunDate = Get-Date -Format "yyyy-MM-dd"
$script:RunTimestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$script:LogFilePath = $null

# Map CLI flags to mode
if ($ScanOnly)  { $script:ChosenMode = 'scan' }
if ($FromCache) { $script:ChosenMode = 'generate' }

# Show interactive menu if no mode set via params
if ($null -eq $script:ChosenMode) {
    Show-Banner
    Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │  Welcome! Pick where you'd like to start:                │" -ForegroundColor Cyan
    Write-Host "  ├──────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  │  UNDERSTAND FIRST                                        │" -ForegroundColor DarkGray
    Write-Host "  │  ─────────────────                                       │" -ForegroundColor DarkGray
    Write-Host "  │  [1] What is this tool? (start here if first time)       │" -ForegroundColor White
    Write-Host "  │      What it can do, what it can't, and how it works.    │" -ForegroundColor DarkGray
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  │  [2] I want to do it manually (no automation)            │" -ForegroundColor White
    Write-Host "  │      Printable tips, do's & don'ts, app-specific advice. │" -ForegroundColor DarkGray
    Write-Host "  │      For people who prefer doing things themselves.       │" -ForegroundColor DarkGray
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  │  USE THE TOOL                                            │" -ForegroundColor DarkGray
    Write-Host "  │  ────────────                                            │" -ForegroundColor DarkGray
    Write-Host "  │  [3] Scan & Prepare (run on OLD laptop)                  │" -ForegroundColor Green
    Write-Host "  │      Scans everything, generates reports & scripts.      │" -ForegroundColor DarkGray
    Write-Host "  │      SAFE: Read-only. Nothing installed, copied, deleted.│" -ForegroundColor DarkGray
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  │  [4] Scan Only (report only, no scripts)                 │" -ForegroundColor Yellow
    Write-Host "  │      Just the report. Generate scripts later if needed.  │" -ForegroundColor DarkGray
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  │  [5] Generate Scripts from Previous Scan                 │" -ForegroundColor Yellow
    Write-Host "  │      Uses saved scan data. No re-scanning needed.        │" -ForegroundColor DarkGray
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  │  AFTER MIGRATION                                         │" -ForegroundColor DarkGray
    Write-Host "  │  ───────────────                                         │" -ForegroundColor DarkGray
    Write-Host "  │  [6] Post-Migration Checklist (run on NEW laptop)        │" -ForegroundColor Magenta
    Write-Host "  │      Verify everything works on your new machine.        │" -ForegroundColor DarkGray
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  │  [7] Clean Up Old Laptop (DESTRUCTIVE — last step!)      │" -ForegroundColor Red
    Write-Host "  │      Wipe personal data. Double confirmation required.   │" -ForegroundColor DarkGray
    Write-Host "  │                                                          │" -ForegroundColor Cyan
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    $choice = Read-Host "  Enter choice [1-7]"
    switch ($choice) {
        '1' {
            $script:ChosenMode = 'about'
        }
        '2' {
            $script:ChosenMode = 'tips'
            Write-Host "  → Manual migration tips selected." -ForegroundColor White
        }
        '3' {
            $script:ChosenMode = 'full'
            Write-Host "  → Scan & Prepare selected. Will scan this laptop and generate scripts." -ForegroundColor Green
            Write-Host "    Nothing will be installed, copied, or deleted." -ForegroundColor DarkGray
        }
        '4' {
            $script:ChosenMode = 'scan'
            Write-Host "  → Scan-only selected. Will produce a report for review." -ForegroundColor Yellow
        }
        '5' {
            $script:ChosenMode = 'generate'
            Write-Host "  → Generate from cache selected." -ForegroundColor Yellow
        }
        '6' {
            $script:ChosenMode = 'checklist'
            Write-Host "  → Post-migration checklist selected." -ForegroundColor Magenta
        }
        '7' {
            $script:ChosenMode = 'cleanup'
            Write-Host ""
            Write-Host "  ████████████████████████████████████████████████████████████" -ForegroundColor Red
            Write-Host "  ██                                                      ██" -ForegroundColor Red
            Write-Host "  ██   WARNING: THIS WILL DELETE YOUR PERSONAL DATA       ██" -ForegroundColor Red
            Write-Host "  ██   THIS ACTION CANNOT BE UNDONE                       ██" -ForegroundColor Red
            Write-Host "  ██                                                      ██" -ForegroundColor Red
            Write-Host "  ████████████████████████████████████████████████████████████" -ForegroundColor Red
            Write-Host ""
            Write-Host "  → Old laptop cleanup selected." -ForegroundColor Red
        }
        default {
            Write-Host "  Invalid choice. Starting with option [1] — What is this tool?" -ForegroundColor Yellow
            $script:ChosenMode = 'about'
        }
    }
    Write-Host ""
}

# Create output directory
if (-not (Test-Path $OutputDir)) { New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null }

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 1: LOGGING
# ═══════════════════════════════════════════════════════════════════════════

$script:LogFilePath = Join-Path $OutputDir "migration-log-$($script:RunTimestamp).txt"

function Write-Log {
    param(
        [Parameter(Position = 0)] [string]$Message,
        [ValidateSet("Info","Warn","Error","Success")] [string]$Level = "Info"
    )
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $tag  = switch ($Level) { "Warn" { "WARN " } "Error" { "ERROR" } "Success" { " OK  " } default { "INFO " } }
    $line = "[$ts] [$tag] $Message"
    $color = switch ($Level) { "Warn" { "Yellow" } "Error" { "Red" } "Success" { "Green" } default { "Gray" } }
    Write-Host $line -ForegroundColor $color
    if ($script:LogFilePath) { Add-Content -Path $script:LogFilePath -Value $line -Encoding UTF8 }
}

function Write-Step {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ── $Title ──" -ForegroundColor Cyan
    Write-Host ""
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 2: KNOWN SOFTWARE DATABASE
# ═══════════════════════════════════════════════════════════════════════════

# Developer essentials — name patterns (regex) mapped to winget IDs
$script:DevEssentials = @(
    @{ Name = "Visual Studio Code";    Pattern = "Visual Studio Code|VS Code|VSCode"; WingetId = "Microsoft.VisualStudioCode";    Category = "Editor" }
    @{ Name = "Git";                   Pattern = "^Git$|Git for Windows";              WingetId = "Git.Git";                       Category = "Version Control" }
    @{ Name = "Node.js";              Pattern = "Node\.js|NodeJS";                    WingetId = "OpenJS.NodeJS.LTS";             Category = "Runtime" }
    @{ Name = "Python";               Pattern = "^Python\s*3|Python 3\.\d";          WingetId = "Python.Python.3.12";            Category = "Runtime" }
    @{ Name = "Java (JDK)";           Pattern = "Java.*Development Kit|OpenJDK|JDK|Temurin|Corretto"; WingetId = "EclipseAdoptium.Temurin.21.JDK"; Category = "Runtime" }
    @{ Name = "Docker Desktop";       Pattern = "Docker Desktop";                     WingetId = "Docker.DockerDesktop";           Category = "Containers" }
    @{ Name = "Postman";              Pattern = "Postman";                            WingetId = "Postman.Postman";                Category = "API Tools" }
    @{ Name = "Windows Terminal";     Pattern = "Windows Terminal";                   WingetId = "Microsoft.WindowsTerminal";      Category = "Terminal" }
    @{ Name = "PowerShell 7";        Pattern = "PowerShell [7-9]|PowerShell-7|pwsh"; WingetId = "Microsoft.PowerShell";           Category = "Terminal" }
    @{ Name = ".NET SDK";             Pattern = "\.NET SDK|dotnet-sdk";               WingetId = "Microsoft.DotNet.SDK.8";         Category = "Runtime" }
    @{ Name = "Visual Studio";        Pattern = "Visual Studio (Community|Professional|Enterprise) 20"; WingetId = "Microsoft.VisualStudio.2022.Community"; Category = "IDE" }
    @{ Name = "IntelliJ IDEA";        Pattern = "IntelliJ IDEA";                      WingetId = "JetBrains.IntelliJIDEA.Community"; Category = "IDE" }
    @{ Name = "Maven";                Pattern = "Apache Maven|maven";                 WingetId = "Apache.Maven";                   Category = "Build Tool" }
    @{ Name = "Gradle";               Pattern = "Gradle";                             WingetId = "Gradle.Gradle";                  Category = "Build Tool" }
    @{ Name = "kubectl";              Pattern = "kubectl|Kubernetes CLI";             WingetId = "Kubernetes.kubectl";              Category = "Containers" }
    @{ Name = "Terraform";            Pattern = "Terraform";                          WingetId = "Hashicorp.Terraform";             Category = "IaC" }
    @{ Name = "Azure CLI";            Pattern = "Azure CLI|Microsoft Azure CLI";      WingetId = "Microsoft.AzureCLI";              Category = "Cloud" }
    @{ Name = "AWS CLI";              Pattern = "AWS CLI|AWSCLI";                     WingetId = "Amazon.AWSCLI";                   Category = "Cloud" }
    @{ Name = "WSL";                  Pattern = "Windows Subsystem for Linux";        WingetId = "Microsoft.WSL";                   Category = "Runtime" }
    @{ Name = "GitHub CLI";           Pattern = "GitHub CLI|gh\.exe";                 WingetId = "GitHub.cli";                      Category = "Version Control" }
    @{ Name = "Notepad++";            Pattern = "Notepad\+\+";                        WingetId = "Notepad++.Notepad++";             Category = "Editor" }
    @{ Name = "Sublime Text";         Pattern = "Sublime Text";                       WingetId = "SublimeHQ.SublimeText.4";         Category = "Editor" }
    @{ Name = "DBeaver";              Pattern = "DBeaver";                            WingetId = "dbeaver.dbeaver";                 Category = "Database" }
    @{ Name = "HeidiSQL";             Pattern = "HeidiSQL";                           WingetId = "HeidiSQL.HeidiSQL";               Category = "Database" }
    @{ Name = "pgAdmin";              Pattern = "pgAdmin";                            WingetId = "PostgreSQL.pgAdmin";              Category = "Database" }
    @{ Name = "Redis Insight";        Pattern = "RedisInsight|Redis Insight";         WingetId = "Redis.RedisInsight";              Category = "Database" }
    @{ Name = "MongoDB Compass";      Pattern = "MongoDB Compass";                   WingetId = "MongoDB.Compass.Full";            Category = "Database" }
    @{ Name = "FileZilla";            Pattern = "FileZilla";                          WingetId = "TimKosse.FileZilla.Client";       Category = "FTP" }
    @{ Name = "WinSCP";               Pattern = "WinSCP";                            WingetId = "WinSCP.WinSCP";                   Category = "FTP" }
    @{ Name = "Fiddler";              Pattern = "Fiddler";                            WingetId = "Telerik.Fiddler.Classic";         Category = "Network" }
    @{ Name = "Wireshark";            Pattern = "Wireshark";                          WingetId = "WiresharkFoundation.Wireshark";   Category = "Network" }
)

# General essentials
$script:GeneralEssentials = @(
    @{ Name = "Google Chrome";        Pattern = "Google Chrome";                       WingetId = "Google.Chrome";                  Category = "Browser" }
    @{ Name = "Mozilla Firefox";      Pattern = "Mozilla Firefox";                     WingetId = "Mozilla.Firefox";                Category = "Browser" }
    @{ Name = "Microsoft Edge";       Pattern = "Microsoft Edge";                      WingetId = "Microsoft.Edge";                 Category = "Browser" }
    @{ Name = "Brave Browser";        Pattern = "Brave";                               WingetId = "Brave.Brave";                    Category = "Browser" }
    @{ Name = "7-Zip";                Pattern = "7-Zip|7zip";                          WingetId = "7zip.7zip";                      Category = "Utility" }
    @{ Name = "WinRAR";               Pattern = "WinRAR";                              WingetId = "RARLab.WinRAR";                  Category = "Utility" }
    @{ Name = "VLC Media Player";     Pattern = "VLC";                                 WingetId = "VideoLAN.VLC";                   Category = "Media" }
    @{ Name = "Spotify";              Pattern = "Spotify";                             WingetId = "Spotify.Spotify";                Category = "Media" }
    @{ Name = "Zoom";                 Pattern = "Zoom Workplace|Zoom Client";          WingetId = "Zoom.Zoom";                      Category = "Communication" }
    @{ Name = "Slack";                Pattern = "Slack";                                WingetId = "SlackTechnologies.Slack";         Category = "Communication" }
    @{ Name = "Microsoft Teams";      Pattern = "Microsoft Teams";                     WingetId = "Microsoft.Teams";                Category = "Communication" }
    @{ Name = "Discord";              Pattern = "Discord";                             WingetId = "Discord.Discord";                Category = "Communication" }
    @{ Name = "OBS Studio";           Pattern = "OBS Studio";                          WingetId = "OBSProject.OBSStudio";           Category = "Media" }
    @{ Name = "ShareX";               Pattern = "ShareX";                              WingetId = "ShareX.ShareX";                  Category = "Utility" }
    @{ Name = "Greenshot";            Pattern = "Greenshot";                           WingetId = "Greenshot.Greenshot";             Category = "Utility" }
    @{ Name = "Adobe Acrobat Reader"; Pattern = "Adobe Acrobat|Acrobat Reader";        WingetId = "Adobe.Acrobat.Reader.64-bit";    Category = "Productivity" }
    @{ Name = "LibreOffice";          Pattern = "LibreOffice";                         WingetId = "TheDocumentFoundation.LibreOffice"; Category = "Productivity" }
    @{ Name = "Notion";               Pattern = "Notion";                              WingetId = "Notion.Notion";                  Category = "Productivity" }
    @{ Name = "KeePass";              Pattern = "KeePass";                             WingetId = "DominikReichl.KeePass";          Category = "Security" }
    @{ Name = "Bitwarden";            Pattern = "Bitwarden";                           WingetId = "Bitwarden.Bitwarden";            Category = "Security" }
    @{ Name = "1Password";            Pattern = "1Password";                           WingetId = "AgileBits.1Password";            Category = "Security" }
    @{ Name = "TreeSize Free";        Pattern = "TreeSize";                            WingetId = "JAMSoftware.TreeSize.Free";      Category = "Utility" }
    @{ Name = "Everything Search";    Pattern = "Everything";                          WingetId = "voidtools.Everything";            Category = "Utility" }
    @{ Name = "PowerToys";            Pattern = "PowerToys";                           WingetId = "Microsoft.PowerToys";            Category = "Utility" }
    @{ Name = "Obsidian";             Pattern = "Obsidian";                            WingetId = "Obsidian.Obsidian";              Category = "Productivity" }
    @{ Name = "WinDirStat";           Pattern = "WinDirStat";                          WingetId = "WinDirStat.WinDirStat";          Category = "Utility" }
)

# Directories to exclude when transferring data
$script:ExcludeDirs = @(
    'node_modules', '.venv', 'venv', 'env', '__pycache__', '.pytest_cache',
    '.cache', '.tox', 'dist', 'build', 'target', 'bin', 'obj',
    'coverage', '.coverage', '.nyc_output', '.next', '.nuxt',
    '.gradle', '.m2', '.ivy2',
    '$RECYCLE.BIN', 'System Volume Information',
    '.tmp', '.temp', 'Thumbs.db'
)

$script:ExcludeFiles = @(
    '*.log', '*.tmp', '*.temp', '*.bak', '*.swp', '*.swo',
    'Thumbs.db', 'desktop.ini', '*.pyc', '*.pyo', '*.class',
    '*.o', '*.obj', '*.exe', '*.dll', '*.so', '*.dylib'
)

# System folders to never scan/copy
$script:SystemFolders = @(
    'Windows', 'Program Files', 'Program Files (x86)',
    'ProgramData', '$Recycle.Bin', 'Recovery',
    'System Volume Information', 'PerfLogs'
)

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3: SCAN FUNCTIONS (Phase 1)
# ═══════════════════════════════════════════════════════════════════════════

function Get-DriveInfo {
    Write-Step "Scanning Drives"
    $drives = @()
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -or $_.Free } | ForEach-Object {
        $d = @{
            Name      = $_.Name
            Root      = $_.Root
            UsedGB    = [math]::Round($_.Used / 1GB, 2)
            FreeGB    = [math]::Round($_.Free / 1GB, 2)
            TotalGB   = [math]::Round(($_.Used + $_.Free) / 1GB, 2)
            UsedPct   = if (($_.Used + $_.Free) -gt 0) { [math]::Round(($_.Used / ($_.Used + $_.Free)) * 100, 1) } else { 0 }
        }
        Write-Log "Drive $($d.Name): — $(Format-Size $_.Used) used / $(Format-Size $_.Free) free ($(Format-Size ($_.Used + $_.Free)) total)" -Level Info
        $drives += $d
    }
    return $drives
}

function Get-UserProfileFolders {
    Write-Step "Scanning User Profile Folders"
    $userProfile = $env:USERPROFILE
    $knownFolders = @(
        @{ Name = "Desktop";    Path = [Environment]::GetFolderPath('Desktop') }
        @{ Name = "Documents";  Path = [Environment]::GetFolderPath('MyDocuments') }
        @{ Name = "Downloads";  Path = (Join-Path $userProfile "Downloads") }
        @{ Name = "Pictures";   Path = [Environment]::GetFolderPath('MyPictures') }
        @{ Name = "Videos";     Path = [Environment]::GetFolderPath('MyVideos') }
        @{ Name = "Music";      Path = [Environment]::GetFolderPath('MyMusic') }
        @{ Name = "OneDrive";   Path = $env:OneDrive }
    )

    $results = @()
    foreach ($folder in $knownFolders) {
        if (-not $folder.Path -or -not (Test-Path $folder.Path)) {
            Write-Log "$($folder.Name): not found — skipping" -Level Warn
            continue
        }
        try {
            # Detect if folder is redirected to OneDrive (Known Folder Move / KFM)
            $isOneDrive = $folder.Path -imatch 'OneDrive'
            $items = Get-ChildItem -Path $folder.Path -Recurse -Force -ErrorAction SilentlyContinue
            $fileCount = @($items | Where-Object { -not $_.PSIsContainer }).Count
            $totalSize = ($items | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $totalSize) { $totalSize = 0 }
            $result = @{
                Name      = $folder.Name
                Path      = $folder.Path
                FileCount = $fileCount
                Size      = $totalSize
                SizeText  = Format-Size $totalSize
                IsOneDrive = $isOneDrive
            }
            if ($isOneDrive) {
                Write-Log "$($folder.Name): $fileCount files, $(Format-Size $totalSize) — $($folder.Path) [ONEDRIVE SYNCED]" -Level Info
            } else {
                Write-Log "$($folder.Name): $fileCount files, $(Format-Size $totalSize) — $($folder.Path)" -Level Info
            }
            $results += $result
        } catch {
            Write-Log "$($folder.Name): error scanning — $($_.Exception.Message)" -Level Warn
            $results += @{ Name = $folder.Name; Path = $folder.Path; FileCount = 0; Size = 0; SizeText = "Error"; Error = $_.Exception.Message }
        }
    }
    return $results
}

function Get-CustomDataFolders {
    Write-Step "Scanning for Custom Data Folders"
    $results = @()
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -or $_.Free }

    foreach ($drive in $drives) {
        $root = $drive.Root
        try {
            $topFolders = Get-ChildItem -Path $root -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object {
                    $name = $_.Name
                    # Skip system folders
                    $isSystem = $script:SystemFolders | Where-Object { $name -ieq $_ }
                    # Skip user profiles root on C:
                    if ($root -ieq "C:\") {
                        $isSystem = $isSystem -or ($name -ieq "Users")
                    }
                    -not $isSystem -and -not $name.StartsWith('$')
                }
            foreach ($folder in $topFolders) {
                try {
                    $items = Get-ChildItem -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue -Depth 0
                    $subCount = @($items | Where-Object { $_.PSIsContainer }).Count
                    $fileCount = @($items | Where-Object { -not $_.PSIsContainer }).Count
                    # Quick size estimate (top-level files only for speed)
                    $topFiles = Get-ChildItem -Path $folder.FullName -File -Force -ErrorAction SilentlyContinue
                    $topSize = ($topFiles | Measure-Object -Property Length -Sum).Sum
                    if ($null -eq $topSize) { $topSize = 0 }
                    $results += @{
                        Drive     = $drive.Name
                        Name      = $folder.Name
                        Path      = $folder.FullName
                        SubDirs   = $subCount
                        TopFiles  = $fileCount
                        TopSize   = $topSize
                        SizeText  = Format-Size $topSize
                        Note      = "(top-level size only — deep scan skipped for speed)"
                    }
                    Write-Log "  $($drive.Name):\$($folder.Name) — $subCount subdirs, $fileCount top files" -Level Info
                } catch {
                    Write-Log "  $($drive.Name):\$($folder.Name) — access denied or error" -Level Warn
                }
            }
        } catch {
            Write-Log "  Drive $($drive.Name): — error listing folders" -Level Warn
        }
    }
    return $results
}

function Get-InstalledSoftware {
    Write-Step "Scanning Installed Software"

    $software = @{}  # Use hashtable to deduplicate by name

    # Method 1: Registry (64-bit + 32-bit uninstall keys) — catches software on ALL drives
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($path in $regPaths) {
        try {
            Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne '' } |
                ForEach-Object {
                    $name = $_.DisplayName.Trim()
                    if (-not $software.ContainsKey($name)) {
                        $installLoc = if ($_.InstallLocation) { $_.InstallLocation.TrimEnd('\') } else { "" }
                        $software[$name] = @{
                            Name           = $name
                            Version        = if ($_.DisplayVersion) { $_.DisplayVersion } else { "" }
                            Publisher       = if ($_.Publisher) { $_.Publisher } else { "" }
                            InstallDate    = if ($_.InstallDate) { $_.InstallDate } else { "" }
                            InstallLocation = $installLoc
                            Source         = "Registry"
                            WingetId       = ""
                            Category       = "Other"
                            IsDev          = $false
                            IsGeneral      = $false
                            IsPortable     = $false
                            IsNonStandard  = $false
                        }
                        # Flag if installed outside standard locations
                        if ($installLoc -and $installLoc -notmatch '^C:\\Program Files|^C:\\Windows|^C:\\ProgramData') {
                            $software[$name].IsNonStandard = $true
                        }
                    }
                }
        } catch { }
    }
    Write-Log "Registry scan: $($software.Count) applications found" -Level Info

    # Method 2: winget list (if available)
    $wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
    $wingetMap = @{}
    if ($wingetAvailable) {
        Write-Log "Running winget list (this may take a moment)..." -Level Info
        try {
            $wingetOutput = & winget list --accept-source-agreements 2>$null
            $headerFound = $false
            $nameEnd = 0; $idStart = 0; $idEnd = 0; $verStart = 0
            foreach ($line in $wingetOutput) {
                if ($line -match '^-{3,}') {
                    $headerFound = $true
                    # Parse column positions from the previous header line
                    $prevLine = $wingetOutput[([Array]::IndexOf($wingetOutput, $line)) - 1]
                    if ($prevLine -match 'Id') {
                        $idStart = $prevLine.IndexOf('Id')
                        $verStart = $prevLine.IndexOf('Version')
                        if ($verStart -lt 0) { $verStart = $prevLine.IndexOf('Ver') }
                        $nameEnd = $idStart
                        $idEnd = if ($verStart -gt 0) { $verStart } else { $prevLine.Length }
                    }
                    continue
                }
                if (-not $headerFound -or $line.Length -lt $idStart + 2) { continue }
                $wName = $line.Substring(0, [Math]::Min($nameEnd, $line.Length)).Trim()
                $wId = ""
                if ($line.Length -gt $idStart) {
                    $endPos = [Math]::Min($idEnd, $line.Length)
                    $wId = $line.Substring($idStart, $endPos - $idStart).Trim()
                }
                if ($wName -and $wId -and $wId -match '^\S+\.\S+') {
                    $wingetMap[$wName] = $wId
                    # Also add to software list if not already there
                    if (-not $software.ContainsKey($wName)) {
                        $software[$wName] = @{
                            Name        = $wName
                            Version     = ""
                            Publisher   = ""
                            InstallDate = ""
                            InstallLocation = ""
                            Source      = "Winget"
                            WingetId    = $wId
                            Category    = "Other"
                            IsDev       = $false
                            IsGeneral   = $false
                            IsPortable  = $false
                            IsNonStandard = $false
                        }
                    }
                }
            }
            Write-Log "Winget list: $($wingetMap.Count) packages with IDs found" -Level Info
        } catch {
            Write-Log "Winget list failed: $($_.Exception.Message)" -Level Warn
        }
    } else {
        Write-Log "winget not found — install it for better software detection" -Level Warn
    }

    # Method 3: Scan for portable apps (standalone .exe not in Program Files or registry)
    Write-Log "Scanning for portable/standalone software..." -Level Info
    $portableApps = @()
    $portableScanDirs = @()
    # Common portable app locations
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -or $_.Free }
    foreach ($drv in $drives) {
        $root = $drv.Root
        # Check for PortableApps folder
        $paDir = Join-Path $root "PortableApps"
        if (Test-Path $paDir) { $portableScanDirs += $paDir }
        # Check for common portable tool folders
        foreach ($dirName in @("tools", "portable", "apps", "software")) {
            $d = Join-Path $root $dirName
            if (Test-Path $d) { $portableScanDirs += $d }
        }
    }
    # Also check user profile common locations
    $userToolsDirs = @(
        (Join-Path $env:USERPROFILE "tools"),
        (Join-Path $env:USERPROFILE "portable"),
        (Join-Path $env:USERPROFILE "apps"),
        (Join-Path $env:LOCALAPPDATA "Programs")
    )
    foreach ($d in $userToolsDirs) {
        if (Test-Path $d) { $portableScanDirs += $d }
    }
    # Scan for .exe files in these directories (depth 1)
    foreach ($scanDir in $portableScanDirs) {
        try {
            $exeFiles = Get-ChildItem -Path $scanDir -Filter "*.exe" -Recurse -Depth 1 -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 100KB -and $_.Name -notmatch 'unins|setup|update|crash|helper' }
            foreach ($exe in $exeFiles) {
                $exeName = [System.IO.Path]::GetFileNameWithoutExtension($exe.Name)
                # Skip if already found via registry/winget
                $alreadyFound = $software.Values | Where-Object { $_.Name -imatch [regex]::Escape($exeName) }
                if (-not $alreadyFound) {
                    $portableApps += @{
                        Name     = $exeName
                        Path     = $exe.FullName
                        Size     = $exe.Length
                        SizeText = Format-Size $exe.Length
                        Folder   = $exe.DirectoryName
                    }
                }
            }
        } catch { }
    }

    # Also detect software installed in non-standard locations (other drives' Program Files)
    $nonStdSoftware = @($software.Values | Where-Object { $_.IsNonStandard -and $_.InstallLocation })
    if ($nonStdSoftware.Count -gt 0) {
        Write-Log "Non-standard install locations: $($nonStdSoftware.Count) apps installed outside C:\Program Files" -Level Info
    }
    if ($portableApps.Count -gt 0) {
        Write-Log "Portable apps found: $($portableApps.Count) standalone executables in tools/portable folders" -Level Success
    }

    # Categorize software
    foreach ($key in @($software.Keys)) {
        $app = $software[$key]
        $name = $app.Name

        # Try to match winget ID from winget output first
        if (-not $app.WingetId -and $wingetMap.Count -gt 0) {
            foreach ($wName in $wingetMap.Keys) {
                if ($name -ieq $wName -or $wName -imatch [regex]::Escape($name)) {
                    $app.WingetId = $wingetMap[$wName]
                    break
                }
            }
        }

        # Check against developer essentials
        foreach ($dev in $script:DevEssentials) {
            if ($name -imatch $dev.Pattern) {
                $app.IsDev = $true
                $app.Category = $dev.Category
                if (-not $app.WingetId) { $app.WingetId = $dev.WingetId }
                break
            }
        }

        # Check against general essentials
        if (-not $app.IsDev) {
            foreach ($gen in $script:GeneralEssentials) {
                if ($name -imatch $gen.Pattern) {
                    $app.IsGeneral = $true
                    $app.Category = $gen.Category
                    if (-not $app.WingetId) { $app.WingetId = $gen.WingetId }
                    break
                }
            }
        }
    }

    $devCount = @($software.Values | Where-Object { $_.IsDev }).Count
    $genCount = @($software.Values | Where-Object { $_.IsGeneral }).Count
    $otherCount = $software.Count - $devCount - $genCount
    Write-Log "Categorized: $devCount developer, $genCount general, $otherCount other" -Level Success

    # Return both installed software and portable apps
    $sortedSoftware = @($software.Values | Sort-Object @{Expression={$_.IsDev};Descending=$true}, @{Expression={$_.IsGeneral};Descending=$true}, Name)
    return @{
        Software     = $sortedSoftware
        PortableApps = $portableApps
    }
}

function Get-UserConfigs {
    Write-Step "Scanning Configurations"
    $configs = @{}
    $userProfile = $env:USERPROFILE

    # Git config
    $gitConfigPath = Join-Path $userProfile ".gitconfig"
    if (Test-Path $gitConfigPath) {
        $configs["GitConfig"] = @{
            Name = ".gitconfig"
            Path = $gitConfigPath
            Content = Get-Content $gitConfigPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            Found = $true
        }
        Write-Log ".gitconfig found at $gitConfigPath" -Level Success
    } else {
        $configs["GitConfig"] = @{ Name = ".gitconfig"; Path = $gitConfigPath; Found = $false }
        Write-Log ".gitconfig not found" -Level Warn
    }

    # SSH keys
    $sshDir = Join-Path $userProfile ".ssh"
    if (Test-Path $sshDir) {
        $sshFiles = Get-ChildItem $sshDir -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $configs["SSHKeys"] = @{
            Name   = "SSH Keys"
            Path   = $sshDir
            Files  = @($sshFiles)
            Found  = $true
            Note   = "SECURITY: Transfer these manually via USB — never over network unencrypted"
        }
        Write-Log "SSH directory found: $($sshFiles.Count) files (keys should be transferred manually/securely)" -Level Success
    } else {
        $configs["SSHKeys"] = @{ Name = "SSH Keys"; Path = $sshDir; Found = $false }
        Write-Log "No .ssh directory found" -Level Warn
    }

    # VS Code settings
    $vscodeSettingsDir = Join-Path $env:APPDATA "Code\User"
    $vscodeSettings = Join-Path $vscodeSettingsDir "settings.json"
    $vscodeKeybindings = Join-Path $vscodeSettingsDir "keybindings.json"
    $vscodeSnippetsDir = Join-Path $vscodeSettingsDir "snippets"
    $vscodeExtensions = @()
    if (Get-Command code -ErrorAction SilentlyContinue) {
        try {
            $vscodeExtensions = @(& code --list-extensions 2>$null)
            Write-Log "VS Code: $($vscodeExtensions.Count) extensions found" -Level Info
        } catch { }
    }
    $configs["VSCode"] = @{
        Name        = "VS Code"
        SettingsPath = $vscodeSettings
        SettingsExist = Test-Path $vscodeSettings
        KeybindingsPath = $vscodeKeybindings
        KeybindingsExist = Test-Path $vscodeKeybindings
        SnippetsDir  = $vscodeSnippetsDir
        SnippetsExist = Test-Path $vscodeSnippetsDir
        Extensions   = $vscodeExtensions
        Found        = (Test-Path $vscodeSettings) -or ($vscodeExtensions.Count -gt 0)
    }
    if ($configs["VSCode"].Found) {
        Write-Log "VS Code settings found. Extensions: $($vscodeExtensions.Count)" -Level Success
    }

    # PowerShell profile
    $psProfilePath = $PROFILE.CurrentUserAllHosts
    if (-not $psProfilePath) { $psProfilePath = $PROFILE }
    $configs["PSProfile"] = @{
        Name    = "PowerShell Profile"
        Path    = $psProfilePath
        Found   = Test-Path $psProfilePath
        Content = if (Test-Path $psProfilePath) { Get-Content $psProfilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { "" }
    }
    if ($configs["PSProfile"].Found) { Write-Log "PowerShell profile found: $psProfilePath" -Level Success }
    else { Write-Log "No PowerShell profile at $psProfilePath" -Level Warn }

    # Windows Terminal settings
    $wtPattern = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json"
    $wtFiles = @(Get-ChildItem $wtPattern -ErrorAction SilentlyContinue)
    if ($wtFiles.Count -gt 0) {
        $configs["WindowsTerminal"] = @{
            Name    = "Windows Terminal"
            Path    = $wtFiles[0].FullName
            Found   = $true
            Content = Get-Content $wtFiles[0].FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        Write-Log "Windows Terminal settings found" -Level Success
    } else {
        $configs["WindowsTerminal"] = @{ Name = "Windows Terminal"; Path = ""; Found = $false }
        Write-Log "Windows Terminal settings not found" -Level Warn
    }

    # User environment variables
    $userEnvVars = @()
    try {
        $envKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
        if ($envKey) {
            foreach ($name in $envKey.GetValueNames()) {
                $val = $envKey.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $userEnvVars += @{ Name = $name; Value = $val }
            }
            $envKey.Close()
        }
    } catch { }
    $configs["EnvVars"] = @{
        Name      = "User Environment Variables"
        Variables = $userEnvVars
        Found     = $userEnvVars.Count -gt 0
    }
    if ($userEnvVars.Count -gt 0) { Write-Log "User environment variables: $($userEnvVars.Count) found" -Level Success }

    # Browser bookmarks
    $bookmarks = @{}
    # Chrome
    $chromeBookmarks = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Bookmarks"
    $bookmarks["Chrome"] = @{ Name = "Chrome"; Path = $chromeBookmarks; Found = Test-Path $chromeBookmarks }
    # Edge
    $edgeBookmarks = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Bookmarks"
    $bookmarks["Edge"] = @{ Name = "Edge"; Path = $edgeBookmarks; Found = Test-Path $edgeBookmarks }
    # Firefox (profiles.ini based)
    $firefoxDir = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles"
    $ffFound = $false
    $ffPath = ""
    if (Test-Path $firefoxDir) {
        $ffProfiles = Get-ChildItem $firefoxDir -Directory -ErrorAction SilentlyContinue
        foreach ($p in $ffProfiles) {
            $bm = Join-Path $p.FullName "places.sqlite"
            if (Test-Path $bm) { $ffFound = $true; $ffPath = $p.FullName; break }
        }
    }
    $bookmarks["Firefox"] = @{ Name = "Firefox"; Path = $ffPath; Found = $ffFound; Note = if ($ffFound) { "Firefox uses places.sqlite — export bookmarks via browser menu" } else { "" } }
    $configs["Bookmarks"] = @{
        Name      = "Browser Bookmarks"
        Browsers  = $bookmarks
        Found     = ($bookmarks.Values | Where-Object { $_.Found }).Count -gt 0
    }
    foreach ($b in $bookmarks.Values) {
        if ($b.Found) { Write-Log "$($b.Name) bookmarks found" -Level Success }
    }

    # Browser extensions
    Write-Log "Scanning browser extensions..." -Level Info
    $browserExtensions = @{}

    # Chrome extensions
    $chromeExtDir = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Extensions"
    $chromeExts = @()
    if (Test-Path $chromeExtDir) {
        # Read extension names from manifest.json files
        $extDirs = Get-ChildItem $chromeExtDir -Directory -ErrorAction SilentlyContinue
        foreach ($extDir in $extDirs) {
            try {
                $verDirs = Get-ChildItem $extDir.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
                if ($verDirs) {
                    $manifest = Join-Path $verDirs.FullName "manifest.json"
                    if (Test-Path $manifest) {
                        $mj = Get-Content $manifest -Raw -Encoding UTF8 -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                        $extName = if ($mj.name -and $mj.name -notmatch '^__MSG_') { $mj.name } else { $extDir.Name }
                        $chromeExts += @{ Name = $extName; Id = $extDir.Name; Version = $mj.version }
                    }
                }
            } catch { }
        }
    }
    $browserExtensions["Chrome"] = @{ Name = "Chrome Extensions"; Extensions = $chromeExts; Found = $chromeExts.Count -gt 0 }
    if ($chromeExts.Count -gt 0) { Write-Log "Chrome extensions: $($chromeExts.Count) found" -Level Success }

    # Edge extensions
    $edgeExtDir = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\Default\Extensions"
    $edgeExts = @()
    if (Test-Path $edgeExtDir) {
        $extDirs = Get-ChildItem $edgeExtDir -Directory -ErrorAction SilentlyContinue
        foreach ($extDir in $extDirs) {
            try {
                $verDirs = Get-ChildItem $extDir.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
                if ($verDirs) {
                    $manifest = Join-Path $verDirs.FullName "manifest.json"
                    if (Test-Path $manifest) {
                        $mj = Get-Content $manifest -Raw -Encoding UTF8 -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                        $extName = if ($mj.name -and $mj.name -notmatch '^__MSG_') { $mj.name } else { $extDir.Name }
                        $edgeExts += @{ Name = $extName; Id = $extDir.Name; Version = $mj.version }
                    }
                }
            } catch { }
        }
    }
    $browserExtensions["Edge"] = @{ Name = "Edge Extensions"; Extensions = $edgeExts; Found = $edgeExts.Count -gt 0 }
    if ($edgeExts.Count -gt 0) { Write-Log "Edge extensions: $($edgeExts.Count) found" -Level Success }

    # Firefox add-ons
    $ffAddons = @()
    if ($ffFound -and $ffPath) {
        $ffExtJson = Join-Path $ffPath "extensions.json"
        if (Test-Path $ffExtJson) {
            try {
                $ffExtData = Get-Content $ffExtJson -Raw -Encoding UTF8 -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($ffExtData.addons) {
                    foreach ($addon in $ffExtData.addons) {
                        if ($addon.type -eq 'extension' -and $addon.location -eq 'app-profile') {
                            $ffAddons += @{ Name = $addon.defaultLocale.name; Id = $addon.id; Version = $addon.version }
                        }
                    }
                }
            } catch { }
        }
    }
    $browserExtensions["Firefox"] = @{ Name = "Firefox Add-ons"; Extensions = $ffAddons; Found = $ffAddons.Count -gt 0 }
    if ($ffAddons.Count -gt 0) { Write-Log "Firefox add-ons: $($ffAddons.Count) found" -Level Success }

    $configs["BrowserExtensions"] = @{
        Name       = "Browser Extensions"
        Browsers   = $browserExtensions
        Found      = ($browserExtensions.Values | Where-Object { $_.Found }).Count -gt 0
        SyncNote   = "Browser extensions sync automatically when you sign into your browser (Chrome/Edge/Firefox account)"
    }

    # Office / Outlook add-ins (COM add-ins from registry)
    $officeAddins = @()
    $addinRegPaths = @(
        "HKCU:\Software\Microsoft\Office\Outlook\Addins",
        "HKLM:\Software\Microsoft\Office\Outlook\Addins",
        "HKCU:\Software\Microsoft\Office\Excel\Addins",
        "HKCU:\Software\Microsoft\Office\Word\Addins",
        "HKLM:\Software\Microsoft\Office\Excel\Addins",
        "HKLM:\Software\Microsoft\Office\Word\Addins",
        "HKCU:\Software\Microsoft\Office\PowerPoint\Addins",
        "HKLM:\Software\Microsoft\Office\PowerPoint\Addins"
    )
    foreach ($regPath in $addinRegPaths) {
        try {
            if (Test-Path $regPath) {
                $appName = ($regPath -split '\\')[-2]  # Outlook, Excel, Word, etc.
                Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $addinName = $_.PSChildName
                    $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    $friendlyName = if ($props.FriendlyName) { $props.FriendlyName } else { $addinName }
                    $officeAddins += @{ Name = $friendlyName; App = $appName; Id = $addinName }
                }
            }
        } catch { }
    }
    $configs["OfficeAddins"] = @{
        Name    = "Office Add-ins"
        Addins  = $officeAddins
        Found   = $officeAddins.Count -gt 0
        SyncNote = "Office add-ins from Microsoft Store sync via your Microsoft 365 account. COM add-ins need manual reinstall"
    }
    if ($officeAddins.Count -gt 0) { Write-Log "Office add-ins: $($officeAddins.Count) found (Outlook, Excel, Word, PowerPoint)" -Level Success }

    # Outlook rules (guidance only — can't auto-export)
    $configs["OutlookRules"] = @{
        Name  = "Outlook Rules"
        Found = $false
        Note  = "Outlook rules must be exported manually: File -> Manage Rules -> Options -> Export Rules (.rwz)"
    }
    Write-Log "Outlook rules: manual export required (noted in report)" -Level Info

    # Scheduled Tasks (user-created only)
    $tasks = @()
    try {
        $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.Principal.UserId -and $_.Principal.UserId -notmatch 'SYSTEM|LOCAL SERVICE|NETWORK SERVICE' -and $_.TaskPath -notmatch '^\\Microsoft\\' } |
            Select-Object TaskName, TaskPath, @{N='State';E={$_.State.ToString()}}, Description)
    } catch { }
    $configs["ScheduledTasks"] = @{
        Name  = "Scheduled Tasks"
        Tasks = $tasks
        Found = $tasks.Count -gt 0
    }
    if ($tasks.Count -gt 0) { Write-Log "User scheduled tasks: $($tasks.Count) found" -Level Success }

    # npm global packages
    $npmGlobal = @()
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        try {
            $npmOutput = & npm list -g --depth=0 --json 2>$null | ConvertFrom-Json
            if ($npmOutput.dependencies) {
                $npmOutput.dependencies.PSObject.Properties | ForEach-Object {
                    $npmGlobal += @{ Name = $_.Name; Version = $_.Value.version }
                }
            }
        } catch { }
    }
    $configs["NpmGlobal"] = @{
        Name     = "npm Global Packages"
        Packages = $npmGlobal
        Found    = $npmGlobal.Count -gt 0
    }
    if ($npmGlobal.Count -gt 0) { Write-Log "npm global packages: $($npmGlobal.Count) found" -Level Success }

    # pip packages (user-installed)
    $pipPackages = @()
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        try {
            $pipOutput = & pip list --user --format=json 2>$null | ConvertFrom-Json
            foreach ($pkg in $pipOutput) {
                $pipPackages += @{ Name = $pkg.name; Version = $pkg.version }
            }
        } catch { }
    }
    $configs["PipPackages"] = @{
        Name     = "pip User Packages"
        Packages = $pipPackages
        Found    = $pipPackages.Count -gt 0
    }
    if ($pipPackages.Count -gt 0) { Write-Log "pip user packages: $($pipPackages.Count) found" -Level Success }

    # Hosts file (custom entries)
    $hostsPath = "C:\Windows\System32\drivers\etc\hosts"
    $customHosts = @()
    if (Test-Path $hostsPath) {
        try {
            $hostsContent = Get-Content $hostsPath -Encoding UTF8 -ErrorAction SilentlyContinue
            $customHosts = @($hostsContent | Where-Object { $_ -and $_.Trim() -and -not $_.Trim().StartsWith('#') })
        } catch { }
    }
    $configs["HostsFile"] = @{
        Name         = "Hosts File"
        Path         = $hostsPath
        CustomEntries = $customHosts
        Found        = $customHosts.Count -gt 0
    }
    if ($customHosts.Count -gt 0) { Write-Log "Custom hosts entries: $($customHosts.Count) found" -Level Success }

    # Windows Settings (WiFi, display, mouse, sound, theme, wallpaper, region)
    Write-Log "Scanning Windows settings..." -Level Info
    $winSettings = @{}

    # Saved WiFi profiles
    $wifiProfiles = @()
    try {
        $wifiOutput = & netsh wlan show profiles 2>$null
        if ($wifiOutput) {
            $wifiProfiles = @($wifiOutput | Select-String 'All User Profile\s*:\s*(.+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() })
        }
    } catch { }
    $winSettings["WiFi"] = @{
        Name     = "Saved WiFi Networks"
        Profiles = $wifiProfiles
        Found    = $wifiProfiles.Count -gt 0
        Sync     = "auto"
        SyncNote = "WiFi passwords sync via Microsoft account if signed in. Otherwise export manually: netsh wlan export profile folder=C:\wifi-backup"
    }
    if ($wifiProfiles.Count -gt 0) { Write-Log "WiFi profiles: $($wifiProfiles.Count) saved networks found" -Level Success }

    # Display/brightness settings
    $displayScale = $null
    try { $displayScale = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue).AppliedDPI } catch { }
    $winSettings["Display"] = @{
        Name      = "Display Settings"
        DPI       = $displayScale
        Found     = $null -ne $displayScale
        Sync      = "manual"
        SyncNote  = "Display scaling, brightness, and multi-monitor layout must be set manually on the new laptop (hardware-dependent)"
    }
    if ($displayScale) { Write-Log "Display DPI/scaling: $displayScale" -Level Info }

    # Mouse/cursor settings
    $mouseSpeed = $null; $cursorScheme = $null; $swapButtons = $null
    try {
        $mouseReg = Get-ItemProperty 'HKCU:\Control Panel\Mouse' -ErrorAction SilentlyContinue
        if ($mouseReg) {
            $mouseSpeed = $mouseReg.MouseSensitivity
            $swapButtons = $mouseReg.SwapMouseButtons
        }
        $cursorScheme = (Get-ItemProperty 'HKCU:\Control Panel\Cursors' -ErrorAction SilentlyContinue).'(default)'
    } catch { }
    $winSettings["Mouse"] = @{
        Name         = "Mouse & Cursor"
        Speed        = $mouseSpeed
        SwapButtons  = $swapButtons
        CursorScheme = $cursorScheme
        Found        = $null -ne $mouseSpeed
        Sync         = "partial"
        SyncNote     = "Mouse speed syncs via Microsoft account. Custom cursor schemes need manual setup"
    }
    if ($mouseSpeed) { Write-Log "Mouse speed: $mouseSpeed, Cursor scheme: $cursorScheme" -Level Info }

    # Keyboard settings
    $keyboardLayout = $null; $keyRepeatSpeed = $null
    try {
        $kbReg = Get-ItemProperty 'HKCU:\Control Panel\Keyboard' -ErrorAction SilentlyContinue
        if ($kbReg) { $keyRepeatSpeed = $kbReg.KeyboardSpeed }
        $keyboardLayout = (Get-WinUserLanguageList -ErrorAction SilentlyContinue | Select-Object -First 1).InputMethodTips
    } catch { }
    $winSettings["Keyboard"] = @{
        Name        = "Keyboard"
        Layout      = $keyboardLayout
        RepeatSpeed = $keyRepeatSpeed
        Found       = $null -ne $keyRepeatSpeed
        Sync        = "auto"
        SyncNote    = "Keyboard layout and language sync via Microsoft account"
    }

    # Sound settings
    $soundScheme = $null; $defaultPlayback = $null
    try {
        $soundScheme = (Get-ItemProperty 'HKCU:\AppEvents\Schemes' -ErrorAction SilentlyContinue).'(default)'
        $defaultPlayback = (Get-ItemProperty 'HKCU:\Software\Microsoft\Multimedia\Sound Mapper' -ErrorAction SilentlyContinue).Playback
    } catch { }
    $winSettings["Sound"] = @{
        Name           = "Sound"
        Scheme         = $soundScheme
        DefaultDevice  = $defaultPlayback
        Found          = $null -ne $soundScheme
        Sync           = "manual"
        SyncNote       = "Sound scheme and default devices are hardware-specific. Set via Settings > Sound on new laptop"
    }

    # Theme & wallpaper
    $wallpaperPath = $null; $themeFile = $null; $darkMode = $null
    try {
        $wallpaperPath = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).Wallpaper
        $darkMode = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue).AppsUseLightTheme
        $themeFile = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' -ErrorAction SilentlyContinue).CurrentTheme
    } catch { }
    $winSettings["Theme"] = @{
        Name         = "Theme & Wallpaper"
        Wallpaper    = $wallpaperPath
        DarkMode     = if ($darkMode -eq 0) { "Dark" } elseif ($darkMode -eq 1) { "Light" } else { "Unknown" }
        ThemeFile    = $themeFile
        Found        = $null -ne $wallpaperPath
        Sync         = "auto"
        SyncNote     = "Theme and wallpaper sync via Microsoft account. Custom wallpaper file should be copied manually"
    }
    if ($wallpaperPath) { Write-Log "Theme: $( if ($darkMode -eq 0) {'Dark'} else {'Light'} ) mode, Wallpaper: $wallpaperPath" -Level Info }

    # Region & locale
    $region = $null; $locale = $null
    try {
        $region = (Get-WinHomeLocation -ErrorAction SilentlyContinue).HomeLocation
        $locale = (Get-Culture).Name
    } catch { }
    $winSettings["Region"] = @{
        Name     = "Region & Locale"
        Region   = $region
        Locale   = $locale
        Found    = $null -ne $locale
        Sync     = "auto"
        SyncNote = "Region and language sync via Microsoft account"
    }
    if ($locale) { Write-Log "Locale: $locale, Region: $region" -Level Info }

    # Taskbar settings
    $taskbarPos = $null; $taskbarAutoHide = $null; $taskbarSmallIcons = $null
    try {
        $tbReg = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3' -ErrorAction SilentlyContinue
        $tbAdvanced = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ErrorAction SilentlyContinue
        if ($tbAdvanced) {
            $taskbarSmallIcons = $tbAdvanced.TaskbarSmallIcons
            $taskbarAutoHide = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3' -ErrorAction SilentlyContinue).Settings
        }
    } catch { }
    $winSettings["Taskbar"] = @{
        Name  = "Taskbar"
        Found = $null -ne $tbAdvanced
        Sync  = "auto"
        SyncNote = "Taskbar preferences sync via Microsoft account"
    }

    # File Explorer preferences
    $showExtensions = $null; $showHidden = $null; $launchTo = $null
    try {
        $expAdv = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ErrorAction SilentlyContinue
        if ($expAdv) {
            $showExtensions = if ($expAdv.HideFileExt -eq 0) { $true } else { $false }
            $showHidden = if ($expAdv.Hidden -eq 1) { $true } else { $false }
            $launchTo = if ($expAdv.LaunchTo -eq 1) { "This PC" } else { "Quick Access" }
        }
    } catch { }
    $winSettings["FileExplorer"] = @{
        Name           = "File Explorer"
        ShowExtensions = $showExtensions
        ShowHidden     = $showHidden
        LaunchTo       = $launchTo
        Found          = $null -ne $showExtensions
        Sync           = "export"
        SyncNote       = "These are captured and can be restored via Restore-Configs.ps1"
    }
    if ($showExtensions -ne $null) {
        Write-Log "File Explorer: ShowExtensions=$showExtensions, ShowHidden=$showHidden, LaunchTo=$launchTo" -Level Info
    }

    # Default apps
    $defaultBrowser = $null; $defaultPdf = $null
    try {
        $userChoice = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction SilentlyContinue
        if ($userChoice) { $defaultBrowser = $userChoice.ProgId }
        $pdfChoice = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.pdf\UserChoice' -ErrorAction SilentlyContinue
        if ($pdfChoice) { $defaultPdf = $pdfChoice.ProgId }
    } catch { }
    $winSettings["DefaultApps"] = @{
        Name           = "Default Apps"
        DefaultBrowser = $defaultBrowser
        DefaultPdf     = $defaultPdf
        Found          = $null -ne $defaultBrowser
        Sync           = "manual"
        SyncNote       = "Default apps must be set manually: Settings > Default Apps. Noted in report for reference"
    }
    if ($defaultBrowser) { Write-Log "Default browser: $defaultBrowser, PDF: $defaultPdf" -Level Info }

    # Power & sleep settings
    $sleepAC = $null; $sleepDC = $null; $screenOffAC = $null
    try {
        $sleepAC = (powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>$null | Select-String 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)' | ForEach-Object { [int]("0x" + $_.Matches[0].Groups[1].Value) / 60 })
        $screenOffAC = (powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 2>$null | Select-String 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)' | ForEach-Object { [int]("0x" + $_.Matches[0].Groups[1].Value) / 60 })
    } catch { }
    $winSettings["Power"] = @{
        Name        = "Power & Sleep"
        SleepAfter  = if ($sleepAC) { "$sleepAC min" } else { "Unknown" }
        ScreenOff   = if ($screenOffAC) { "$screenOffAC min" } else { "Unknown" }
        Found       = $null -ne $sleepAC
        Sync        = "manual"
        SyncNote    = "Power settings are hardware-dependent. Set via Settings > Power & Sleep"
    }

    $configs["WindowsSettings"] = @{
        Name     = "Windows Settings"
        Settings = $winSettings
        Found    = ($winSettings.Values | Where-Object { $_.Found }).Count -gt 0
    }

    return $configs
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 4: REPORT GENERATION
# ═══════════════════════════════════════════════════════════════════════════

function Save-ScanCache {
    param([string]$CachePath, $ScanData)
    $ScanData | ConvertTo-Json -Depth 10 | Set-Content -Path $CachePath -Encoding UTF8
    Write-Log "Scan cache saved: $CachePath" -Level Success
}

function Load-ScanCache {
    param([string]$CachePath)
    if (-not (Test-Path $CachePath)) {
        Write-Log "Cache file not found: $CachePath" -Level Error
        return $null
    }
    $data = Get-Content -Path $CachePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Log "Loaded scan cache from $CachePath" -Level Success
    return $data
}

function Write-MarkdownReport {
    param([string]$ReportPath, $ScanData)
    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("# Laptop Migration Scan Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Field | Value |")
    [void]$sb.AppendLine("|-------|-------|")
    [void]$sb.AppendLine("| **Computer** | $($ScanData.ComputerName) |")
    [void]$sb.AppendLine("| **User** | $($ScanData.UserName) |")
    [void]$sb.AppendLine("| **OS** | $($ScanData.OSVersion) |")
    [void]$sb.AppendLine("| **Scan Date** | $($ScanData.ScanDate) |")
    [void]$sb.AppendLine("| **Total Software** | $($ScanData.Software.Count) |")
    [void]$sb.AppendLine("")

    # Drives
    [void]$sb.AppendLine("## Drives")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Drive | Total | Used | Free | Used % |")
    [void]$sb.AppendLine("|-------|-------|------|------|--------|")
    foreach ($d in $ScanData.Drives) {
        [void]$sb.AppendLine("| $($d.Name): | $($d.TotalGB) GB | $($d.UsedGB) GB | $($d.FreeGB) GB | $($d.UsedPct)% |")
    }
    [void]$sb.AppendLine("")

    # User profile folders
    [void]$sb.AppendLine("## User Profile Folders")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Folder | Files | Size | Path |")
    [void]$sb.AppendLine("|--------|-------|------|------|")
    foreach ($f in $ScanData.UserFolders) {
        [void]$sb.AppendLine("| $($f.Name) | $($f.FileCount) | $($f.SizeText) | ``$($f.Path)`` |")
    }
    [void]$sb.AppendLine("")

    # Custom data folders
    if ($ScanData.CustomFolders.Count -gt 0) {
        [void]$sb.AppendLine("## Custom Data Folders (Non-System)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Drive | Folder | Subdirs | Top Files |")
        [void]$sb.AppendLine("|-------|--------|---------|-----------|")
        foreach ($f in $ScanData.CustomFolders) {
            [void]$sb.AppendLine("| $($f.Drive): | $($f.Name) | $($f.SubDirs) | $($f.TopFiles) |")
        }
        [void]$sb.AppendLine("")
    }

    # Software — Developer
    $devSoftware = @($ScanData.Software | Where-Object { $_.IsDev })
    if ($devSoftware.Count -gt 0) {
        [void]$sb.AppendLine("## Developer Software ($($devSoftware.Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| # | Name | Version | Category | Winget ID |")
        [void]$sb.AppendLine("|---|------|---------|----------|-----------|")
        $i = 0
        foreach ($s in $devSoftware) {
            $i++
            [void]$sb.AppendLine("| $i | $($s.Name) | $($s.Version) | $($s.Category) | ``$($s.WingetId)`` |")
        }
        [void]$sb.AppendLine("")
    }

    # Software — General
    $genSoftware = @($ScanData.Software | Where-Object { $_.IsGeneral })
    if ($genSoftware.Count -gt 0) {
        [void]$sb.AppendLine("## General Software ($($genSoftware.Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| # | Name | Version | Category | Winget ID |")
        [void]$sb.AppendLine("|---|------|---------|----------|-----------|")
        $i = 0
        foreach ($s in $genSoftware) {
            $i++
            [void]$sb.AppendLine("| $i | $($s.Name) | $($s.Version) | $($s.Category) | ``$($s.WingetId)`` |")
        }
        [void]$sb.AppendLine("")
    }

    # Software — Other
    $otherSoftware = @($ScanData.Software | Where-Object { -not $_.IsDev -and -not $_.IsGeneral })
    if ($otherSoftware.Count -gt 0) {
        [void]$sb.AppendLine("## Other Installed Software ($($otherSoftware.Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("<details><summary>Click to expand</summary>")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| # | Name | Version | Publisher |")
        [void]$sb.AppendLine("|---|------|---------|-----------|")
        $i = 0
        foreach ($s in $otherSoftware) {
            $i++
            [void]$sb.AppendLine("| $i | $($s.Name) | $($s.Version) | $($s.Publisher) |")
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("</details>")
        [void]$sb.AppendLine("")
    }

    # Software installed in non-standard locations (other drives)
    $nonStdApps = @($ScanData.Software | Where-Object { $_.IsNonStandard -and $_.InstallLocation })
    if ($nonStdApps.Count -gt 0) {
        [void]$sb.AppendLine("## Software in Non-Standard Locations ($($nonStdApps.Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("> These apps are installed outside ``C:\Program Files``. They were still detected via registry/winget and will be reinstalled via ``winget`` on the new laptop. No need to copy them — just note the custom install paths if you want the same layout.")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Name | Install Location |")
        [void]$sb.AppendLine("|------|-----------------|")
        foreach ($s in $nonStdApps) {
            [void]$sb.AppendLine("| $($s.Name) | ``$($s.InstallLocation)`` |")
        }
        [void]$sb.AppendLine("")
    }

    # Portable apps (not in registry or winget)
    if ($ScanData.PortableApps -and $ScanData.PortableApps.Count -gt 0) {
        [void]$sb.AppendLine("## Portable / Standalone Software ($($ScanData.PortableApps.Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("> These are standalone ``.exe`` files found in tools/portable/apps folders. They are NOT installed via a package manager — **copy their entire folder** to the new laptop.")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Name | Path | Size |")
        [void]$sb.AppendLine("|------|------|------|")
        foreach ($p in $ScanData.PortableApps) {
            [void]$sb.AppendLine("| $($p.Name) | ``$($p.Path)`` | $($p.SizeText) |")
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("> **To migrate**: Copy the entire containing folder to the same path on the new machine (or any folder on your PATH).")
        [void]$sb.AppendLine("")
    }

    # Configurations
    [void]$sb.AppendLine("## Configurations Found")
    [void]$sb.AppendLine("")
    $configItems = @(
        @{ Label = "Git config (.gitconfig)";        Found = $ScanData.Configs.GitConfig.Found }
        @{ Label = "SSH keys";                        Found = $ScanData.Configs.SSHKeys.Found }
        @{ Label = "VS Code settings + extensions";   Found = $ScanData.Configs.VSCode.Found }
        @{ Label = "PowerShell profile";              Found = $ScanData.Configs.PSProfile.Found }
        @{ Label = "Windows Terminal settings";       Found = $ScanData.Configs.WindowsTerminal.Found }
        @{ Label = "User environment variables";      Found = $ScanData.Configs.EnvVars.Found }
        @{ Label = "Browser bookmarks";               Found = $ScanData.Configs.Bookmarks.Found }
        @{ Label = "Browser extensions (Chrome/Edge/Firefox)"; Found = $ScanData.Configs.BrowserExtensions.Found }
        @{ Label = "Office add-ins (Outlook/Excel/Word)"; Found = $ScanData.Configs.OfficeAddins.Found }
        @{ Label = "Scheduled tasks (user)";          Found = $ScanData.Configs.ScheduledTasks.Found }
        @{ Label = "npm global packages";             Found = $ScanData.Configs.NpmGlobal.Found }
        @{ Label = "pip user packages";               Found = $ScanData.Configs.PipPackages.Found }
        @{ Label = "Custom hosts file entries";       Found = $ScanData.Configs.HostsFile.Found }
        @{ Label = "Windows settings (WiFi, mouse, theme)"; Found = $ScanData.Configs.WindowsSettings.Found }
    )
    foreach ($item in $configItems) {
        $icon = if ($item.Found) { "✅" } else { "⬜" }
        [void]$sb.AppendLine("- $icon $($item.Label)")
    }
    [void]$sb.AppendLine("")

    # Sync vs Export recommendations
    [void]$sb.AppendLine("### Sync vs Export Recommendations")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Setting | Action | Details |")
    [void]$sb.AppendLine("|---------|--------|---------|")
    [void]$sb.AppendLine("| Browser bookmarks/passwords | \`\`Auto-sync\`\` | Sign into Chrome/Edge/Firefox — syncs automatically |")
    [void]$sb.AppendLine("| VS Code settings + extensions | \`\`Auto-sync\`\` | Enable Settings Sync (Ctrl+Shift+P > Settings Sync: Turn On) |")
    [void]$sb.AppendLine("| OneDrive files | \`\`Auto-sync\`\` | Sign into OneDrive — files sync automatically |")
    [void]$sb.AppendLine("| WiFi passwords | \`\`Auto-sync\`\` | Syncs via Microsoft account (if signed in) |")
    [void]$sb.AppendLine("| Theme, wallpaper, language | \`\`Auto-sync\`\` | Syncs via Microsoft account |")
    [void]$sb.AppendLine("| Windows Terminal settings | \`\`Auto-sync\`\` | Syncs via Microsoft account |")
    [void]$sb.AppendLine("| Mouse speed, keyboard layout | \`\`Partial sync\`\` | Basic settings sync; custom cursors need manual setup |")
    [void]$sb.AppendLine("| Git config (.gitconfig) | \`\`Export\`\` | Captured by this tool — restored via Restore-Configs.ps1 |")
    [void]$sb.AppendLine("| SSH keys | \`\`Manual USB\`\` | Copy via USB drive only — never over network |")
    [void]$sb.AppendLine("| Environment variables | \`\`Export\`\` | Captured by this tool — restored via Restore-Configs.ps1 |")
    [void]$sb.AppendLine("| PowerShell profile | \`\`Export\`\` | Captured by this tool — restored via Restore-Configs.ps1 |")
    [void]$sb.AppendLine("| Outlook rules | \`\`Manual export\`\` | File > Manage Rules > Options > Export Rules |")
    [void]$sb.AppendLine("| File Explorer preferences | \`\`Export\`\` | Show extensions, hidden files, launch folder — restored via Restore-Configs.ps1 |")
    [void]$sb.AppendLine("| Default apps (browser, PDF) | \`\`Manual\`\` | Set via Settings > Default Apps on new laptop |")
    [void]$sb.AppendLine("| Taskbar preferences | \`\`Auto-sync\`\` | Syncs via Microsoft account |")
    [void]$sb.AppendLine("| Display scaling, brightness | \`\`Manual\`\` | Hardware-dependent — set manually on new laptop |")
    [void]$sb.AppendLine("| Power & sleep timeouts | \`\`Manual\`\` | Hardware-dependent — set via Settings > Power |")
    [void]$sb.AppendLine("| Sound device defaults | \`\`Manual\`\` | Hardware-dependent — set via Settings > Sound |")
    [void]$sb.AppendLine("| Printer configs | \`\`Manual\`\` | Re-add printers via Settings > Printers |")
    [void]$sb.AppendLine("")

    # Windows Settings details
    if ($ScanData.Configs.WindowsSettings.Found) {
        [void]$sb.AppendLine("### Windows Settings Captured")
        [void]$sb.AppendLine("")
        $ws = $ScanData.Configs.WindowsSettings.Settings
        if ($ws.WiFi.Found) {
            [void]$sb.AppendLine("**WiFi Networks** ($($ws.WiFi.Profiles.Count) saved): $($ws.WiFi.Profiles -join ', ')")
            [void]$sb.AppendLine("")
        }
        if ($ws.Theme.Found) {
            [void]$sb.AppendLine("**Theme**: $($ws.Theme.DarkMode) mode | Wallpaper: ``$($ws.Theme.Wallpaper)``")
            [void]$sb.AppendLine("")
        }
        if ($ws.Mouse.Found) {
            [void]$sb.AppendLine("**Mouse**: Speed=$($ws.Mouse.Speed) | Cursor scheme: $($ws.Mouse.CursorScheme)")
            [void]$sb.AppendLine("")
        }
        if ($ws.Region.Found) {
            [void]$sb.AppendLine("**Region**: $($ws.Region.Locale)")
            [void]$sb.AppendLine("")
        }
        if ($ws.FileExplorer.Found) {
            [void]$sb.AppendLine("**File Explorer**: Show extensions=$($ws.FileExplorer.ShowExtensions) | Show hidden=$($ws.FileExplorer.ShowHidden) | Opens to: $($ws.FileExplorer.LaunchTo)")
            [void]$sb.AppendLine("")
        }
        if ($ws.DefaultApps.Found) {
            [void]$sb.AppendLine("**Default browser**: $($ws.DefaultApps.DefaultBrowser) | **Default PDF**: $($ws.DefaultApps.DefaultPdf)")
            [void]$sb.AppendLine("")
        }
        if ($ws.Power.Found) {
            [void]$sb.AppendLine("**Power**: Screen off after $($ws.Power.ScreenOff) | Sleep after $($ws.Power.SleepAfter)")
            [void]$sb.AppendLine("")
        }
    }

    # VS Code extensions list
    if ($ScanData.Configs.VSCode.Extensions.Count -gt 0) {
        [void]$sb.AppendLine("### VS Code Extensions ($($ScanData.Configs.VSCode.Extensions.Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("<details><summary>Click to expand</summary>")
        [void]$sb.AppendLine("")
        foreach ($ext in $ScanData.Configs.VSCode.Extensions) {
            [void]$sb.AppendLine("- ``$ext``")
        }
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("</details>")
        [void]$sb.AppendLine("")
    }

    # Browser extensions
    if ($ScanData.Configs.BrowserExtensions.Found) {
        [void]$sb.AppendLine("### Browser Extensions")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("> Browser extensions **sync automatically** when you sign into your browser account.")
        [void]$sb.AppendLine("")
        foreach ($bKey in @("Chrome", "Edge", "Firefox")) {
            try {
                $bData = $ScanData.Configs.BrowserExtensions.Browsers.$bKey
                if ($bData.Found) {
                    [void]$sb.AppendLine("<details><summary>$($bData.Name) ($($bData.Extensions.Count))</summary>")
                    [void]$sb.AppendLine("")
                    foreach ($ext in $bData.Extensions) {
                        [void]$sb.AppendLine("- $($ext.Name)")
                    }
                    [void]$sb.AppendLine("")
                    [void]$sb.AppendLine("</details>")
                    [void]$sb.AppendLine("")
                }
            } catch { }
        }
    }

    # Office add-ins
    if ($ScanData.Configs.OfficeAddins.Found) {
        [void]$sb.AppendLine("### Office Add-ins ($($ScanData.Configs.OfficeAddins.Addins.Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("> Microsoft Store add-ins sync via Microsoft 365 account. COM add-ins need manual reinstall.")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| App | Add-in |")
        [void]$sb.AppendLine("|-----|--------|")
        foreach ($addin in $ScanData.Configs.OfficeAddins.Addins) {
            [void]$sb.AppendLine("| $($addin.App) | $($addin.Name) |")
        }
        [void]$sb.AppendLine("")
    }

    # Manual steps reminder
    [void]$sb.AppendLine("## Manual Steps Required")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- [ ] **Outlook rules**: Export via File → Manage Rules → Options → Export Rules")
    [void]$sb.AppendLine("- [ ] **SSH keys**: Transfer via USB drive (never over unencrypted network)")
    [void]$sb.AppendLine("- [ ] **License keys**: Note down any software license keys before wiping old laptop")
    [void]$sb.AppendLine("- [ ] **Browser passwords**: Ensure sync is enabled or export passwords")
    [void]$sb.AppendLine("- [ ] **2FA/Authenticator**: Ensure backup codes are saved or app is synced")
    [void]$sb.AppendLine("- [ ] **VPN configs**: Export or screenshot VPN connection settings")
    [void]$sb.AppendLine("- [ ] **Printer configs**: Note network printer IPs/names")
    [void]$sb.AppendLine("- [ ] **Credential Manager**: Review Windows Credential Manager for saved creds")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("*Generated by Migrate-Laptop on $($ScanData.ScanDate)*")

    Set-Content -Path $ReportPath -Value $sb.ToString() -Encoding UTF8
    Write-Log "Markdown report saved: $ReportPath" -Level Success
}

function Write-HtmlReport {
    param([string]$ReportPath, $ScanData)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">')
    [void]$sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1.0">')
    [void]$sb.AppendLine("<title>Migration Scan Report - $($ScanData.ScanDate)</title>")
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('*{margin:0;padding:0;box-sizing:border-box}')
    [void]$sb.AppendLine('body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#0d1117;color:#c9d1d9;line-height:1.6}')
    [void]$sb.AppendLine('.container{max-width:1200px;margin:0 auto;padding:24px}')
    [void]$sb.AppendLine('h1{font-size:24px;font-weight:600;margin-bottom:4px;color:#f0f6fc}')
    [void]$sb.AppendLine('h2{font-size:18px;font-weight:600;margin:32px 0 12px;color:#f0f6fc;border-bottom:1px solid #30363d;padding-bottom:8px}')
    [void]$sb.AppendLine('.subtitle{color:#8b949e;margin-bottom:24px;font-size:14px}')
    [void]$sb.AppendLine('.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-bottom:28px}')
    [void]$sb.AppendLine('.card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:16px;text-align:center}')
    [void]$sb.AppendLine('.card .num{font-size:28px;font-weight:700}')
    [void]$sb.AppendLine('.card .label{font-size:11px;color:#8b949e;text-transform:uppercase;letter-spacing:.5px}')
    [void]$sb.AppendLine('.card.blue .num{color:#58a6ff} .card.green .num{color:#3fb950} .card.yellow .num{color:#d29922} .card.purple .num{color:#bc8cff}')
    [void]$sb.AppendLine('table{width:100%;border-collapse:collapse;margin-bottom:24px}')
    [void]$sb.AppendLine('th{background:#161b22;text-align:left;padding:8px 12px;font-size:12px;color:#8b949e;text-transform:uppercase;letter-spacing:.5px;border-bottom:1px solid #30363d;cursor:pointer;user-select:none}')
    [void]$sb.AppendLine('th:hover{color:#f0f6fc}')
    [void]$sb.AppendLine('td{padding:8px 12px;border-bottom:1px solid #21262d;font-size:13px}')
    [void]$sb.AppendLine('tr:hover{background:#161b22}')
    [void]$sb.AppendLine('.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:11px;font-weight:500}')
    [void]$sb.AppendLine('.badge-dev{background:#0c2d6b;color:#58a6ff} .badge-gen{background:#1b4332;color:#3fb950} .badge-other{background:#1c1c1c;color:#8b949e}')
    [void]$sb.AppendLine('.config-item{padding:6px 0;display:flex;align-items:center;gap:8px}')
    [void]$sb.AppendLine('.config-icon{font-size:16px}')
    [void]$sb.AppendLine('.section{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:16px;margin-bottom:16px}')
    [void]$sb.AppendLine('.filter-bar{margin-bottom:12px;display:flex;gap:8px;flex-wrap:wrap;align-items:center}')
    [void]$sb.AppendLine('.filter-bar input{background:#0d1117;color:#c9d1d9;border:1px solid #30363d;border-radius:6px;padding:6px 10px;font-size:13px;min-width:220px}')
    [void]$sb.AppendLine('.filter-bar select{background:#0d1117;color:#c9d1d9;border:1px solid #30363d;border-radius:6px;padding:6px 10px;font-size:13px}')
    [void]$sb.AppendLine('.footer{text-align:center;color:#484f58;font-size:12px;margin-top:32px;padding-top:16px;border-top:1px solid #21262d}')
    [void]$sb.AppendLine('.tab-bar{display:flex;gap:0;margin-bottom:16px;border-bottom:2px solid #30363d}')
    [void]$sb.AppendLine('.tab{padding:8px 20px;cursor:pointer;font-size:13px;color:#8b949e;border-bottom:2px solid transparent;margin-bottom:-2px}')
    [void]$sb.AppendLine('.tab:hover{color:#c9d1d9} .tab.active{color:#58a6ff;border-bottom-color:#58a6ff}')
    [void]$sb.AppendLine('.tab-content{display:none} .tab-content.active{display:block}')
    [void]$sb.AppendLine('code{background:#30363d;padding:1px 5px;border-radius:3px;font-size:12px}')
    [void]$sb.AppendLine('</style></head><body><div class="container">')

    # Header & summary cards
    $devCount = @($ScanData.Software | Where-Object { $_.IsDev }).Count
    $genCount = @($ScanData.Software | Where-Object { $_.IsGeneral }).Count
    $otherCount = $ScanData.Software.Count - $devCount - $genCount
    $configCount = @(
        $ScanData.Configs.PSObject.Properties | Where-Object {
            $_.Value -and $_.Value.Found
        }
    ).Count

    [void]$sb.AppendLine("<h1>&#128187; Laptop Migration Scan Report</h1>")
    [void]$sb.AppendLine("<p class=`"subtitle`">Computer: <strong>$($ScanData.ComputerName)</strong> &middot; User: <strong>$($ScanData.UserName)</strong> &middot; Scanned: <strong>$($ScanData.ScanDate)</strong></p>")
    [void]$sb.AppendLine('<div class="cards">')
    [void]$sb.AppendLine("  <div class=`"card blue`"><div class=`"num`">$($ScanData.Drives.Count)</div><div class=`"label`">Drives</div></div>")
    [void]$sb.AppendLine("  <div class=`"card green`"><div class=`"num`">$devCount</div><div class=`"label`">Dev Software</div></div>")
    [void]$sb.AppendLine("  <div class=`"card yellow`"><div class=`"num`">$genCount</div><div class=`"label`">General Software</div></div>")
    [void]$sb.AppendLine("  <div class=`"card purple`"><div class=`"num`">$otherCount</div><div class=`"label`">Other Software</div></div>")
    [void]$sb.AppendLine("  <div class=`"card blue`"><div class=`"num`">$configCount</div><div class=`"label`">Configs Found</div></div>")
    [void]$sb.AppendLine('</div>')

    # Tabs
    [void]$sb.AppendLine('<div class="tab-bar">')
    [void]$sb.AppendLine('  <div class="tab active" onclick="showTab(''drives'')">Drives</div>')
    [void]$sb.AppendLine('  <div class="tab" onclick="showTab(''software'')">Software</div>')
    [void]$sb.AppendLine('  <div class="tab" onclick="showTab(''configs'')">Configs</div>')
    [void]$sb.AppendLine('  <div class="tab" onclick="showTab(''folders'')">Data Folders</div>')
    [void]$sb.AppendLine('  <div class="tab" onclick="showTab(''checklist'')">Manual Steps</div>')
    [void]$sb.AppendLine('</div>')

    # Tab: Drives
    [void]$sb.AppendLine('<div id="tab-drives" class="tab-content active">')
    [void]$sb.AppendLine('<h2>Drives</h2>')
    [void]$sb.AppendLine('<table><thead><tr><th>Drive</th><th>Total</th><th>Used</th><th>Free</th><th>Used %</th></tr></thead><tbody>')
    foreach ($d in $ScanData.Drives) {
        [void]$sb.AppendLine("<tr><td><strong>$($d.Name):</strong></td><td>$($d.TotalGB) GB</td><td>$($d.UsedGB) GB</td><td>$($d.FreeGB) GB</td><td>$($d.UsedPct)%</td></tr>")
    }
    [void]$sb.AppendLine('</tbody></table></div>')

    # Tab: Software (with filter)
    [void]$sb.AppendLine('<div id="tab-software" class="tab-content">')
    [void]$sb.AppendLine('<h2>Installed Software</h2>')
    [void]$sb.AppendLine('<div class="filter-bar">')
    [void]$sb.AppendLine('  <input type="text" id="swSearch" placeholder="Search software..." oninput="filterSw()">')
    [void]$sb.AppendLine('  <select id="swCatFilter" onchange="filterSw()">')
    [void]$sb.AppendLine('    <option value="">All Categories</option>')
    [void]$sb.AppendLine('    <option value="dev">Developer</option>')
    [void]$sb.AppendLine('    <option value="gen">General</option>')
    [void]$sb.AppendLine('    <option value="other">Other</option>')
    [void]$sb.AppendLine('  </select>')
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<table id="swTable"><thead><tr><th>#</th><th>Name</th><th>Version</th><th>Type</th><th>Category</th><th>Winget ID</th></tr></thead><tbody>')
    $i = 0
    foreach ($s in $ScanData.Software) {
        $i++
        $typeClass = if ($s.IsDev) { "dev" } elseif ($s.IsGeneral) { "gen" } else { "other" }
        $typeLabel = if ($s.IsDev) { "Developer" } elseif ($s.IsGeneral) { "General" } else { "Other" }
        $typeBadge = "<span class=`"badge badge-$typeClass`">$typeLabel</span>"
        $nameEsc = ([System.Web.HttpUtility]::HtmlEncode($s.Name))
        $verEsc = ([System.Web.HttpUtility]::HtmlEncode($s.Version))
        $catEsc = ([System.Web.HttpUtility]::HtmlEncode($s.Category))
        $wIdEsc = if ($s.WingetId) { "<code>$([System.Web.HttpUtility]::HtmlEncode($s.WingetId))</code>" } else { "&mdash;" }
        [void]$sb.AppendLine("  <tr data-cat=`"$typeClass`"><td>$i</td><td>$nameEsc</td><td>$verEsc</td><td>$typeBadge</td><td>$catEsc</td><td>$wIdEsc</td></tr>")
    }
    [void]$sb.AppendLine('</tbody></table></div>')

    # Tab: Configs
    [void]$sb.AppendLine('<div id="tab-configs" class="tab-content">')
    [void]$sb.AppendLine('<h2>Configurations</h2>')
    [void]$sb.AppendLine('<div class="section">')
    $configChecks = @(
        @{ Label = "Git config (.gitconfig)"; Key = "GitConfig" }
        @{ Label = "SSH keys (.ssh/)"; Key = "SSHKeys" }
        @{ Label = "VS Code settings & extensions"; Key = "VSCode" }
        @{ Label = "PowerShell profile"; Key = "PSProfile" }
        @{ Label = "Windows Terminal settings"; Key = "WindowsTerminal" }
        @{ Label = "User environment variables"; Key = "EnvVars" }
        @{ Label = "Browser bookmarks"; Key = "Bookmarks" }
        @{ Label = "Browser extensions (Chrome/Edge/Firefox)"; Key = "BrowserExtensions" }
        @{ Label = "Office add-ins (Outlook/Excel/Word)"; Key = "OfficeAddins" }
        @{ Label = "Scheduled tasks (user-created)"; Key = "ScheduledTasks" }
        @{ Label = "npm global packages"; Key = "NpmGlobal" }
        @{ Label = "pip user packages"; Key = "PipPackages" }
        @{ Label = "Custom hosts file entries"; Key = "HostsFile" }
        @{ Label = "Windows settings (WiFi, mouse, theme)"; Key = "WindowsSettings" }
    )
    foreach ($c in $configChecks) {
        $found = $false
        try { $found = $ScanData.Configs.$($c.Key).Found } catch { }
        $icon = if ($found) { "&#9989;" } else { "&#11036;" }
        [void]$sb.AppendLine("<div class=`"config-item`"><span class=`"config-icon`">$icon</span> $($c.Label)</div>")
    }
    [void]$sb.AppendLine('</div>')

    # Sync vs Export recommendations
    [void]$sb.AppendLine('<h2>Sync vs Export</h2>')
    [void]$sb.AppendLine('<div class="section">')
    [void]$sb.AppendLine('<table style="width:100%"><thead><tr><th>Setting</th><th>Action</th><th>Details</th></tr></thead><tbody>')
    $syncItems = @(
        @("Browser bookmarks/passwords", "<span class=`"badge badge-dev`">Auto-sync</span>", "Sign into Chrome/Edge/Firefox")
        @("VS Code settings + extensions", "<span class=`"badge badge-dev`">Auto-sync</span>", "Enable Settings Sync in VS Code")
        @("OneDrive files", "<span class=`"badge badge-dev`">Auto-sync</span>", "Sign into OneDrive")
        @("WiFi passwords", "<span class=`"badge badge-dev`">Auto-sync</span>", "Syncs via Microsoft account")
        @("Theme, wallpaper, language", "<span class=`"badge badge-dev`">Auto-sync</span>", "Syncs via Microsoft account")
        @("Git config, env vars, PS profile", "<span class=`"badge badge-gen`">Export</span>", "Handled by Restore-Configs.ps1")
        @("SSH keys", "<span class=`"badge badge-other`">Manual USB</span>", "Copy via USB only &mdash; security")
        @("Outlook rules", "<span class=`"badge badge-other`">Manual</span>", "File &rarr; Manage Rules &rarr; Export")
        @("Display scaling, sound", "<span class=`"badge badge-other`">Manual</span>", "Hardware-dependent &mdash; set on new laptop")
    )
    foreach ($si in $syncItems) {
        [void]$sb.AppendLine("<tr><td>$($si[0])</td><td>$($si[1])</td><td>$($si[2])</td></tr>")
    }
    [void]$sb.AppendLine('</tbody></table>')
    [void]$sb.AppendLine('</div>')

    # VS Code extensions
    if ($ScanData.Configs.VSCode.Extensions.Count -gt 0) {
        [void]$sb.AppendLine("<h2>VS Code Extensions ($($ScanData.Configs.VSCode.Extensions.Count))</h2>")
        [void]$sb.AppendLine('<div class="section" style="max-height:300px;overflow-y:auto">')
        foreach ($ext in $ScanData.Configs.VSCode.Extensions) {
            [void]$sb.AppendLine("<div style=`"padding:2px 0`"><code>$([System.Web.HttpUtility]::HtmlEncode($ext))</code></div>")
        }
        [void]$sb.AppendLine('</div>')
    }
    [void]$sb.AppendLine('</div>')

    # Tab: Data Folders
    [void]$sb.AppendLine('<div id="tab-folders" class="tab-content">')
    [void]$sb.AppendLine('<h2>User Profile Folders</h2>')
    [void]$sb.AppendLine('<table><thead><tr><th>Folder</th><th>Files</th><th>Size</th><th>Path</th></tr></thead><tbody>')
    foreach ($f in $ScanData.UserFolders) {
        [void]$sb.AppendLine("<tr><td><strong>$($f.Name)</strong></td><td>$($f.FileCount)</td><td>$($f.SizeText)</td><td><code>$([System.Web.HttpUtility]::HtmlEncode($f.Path))</code></td></tr>")
    }
    [void]$sb.AppendLine('</tbody></table>')
    if ($ScanData.CustomFolders.Count -gt 0) {
        [void]$sb.AppendLine('<h2>Custom Data Folders</h2>')
        [void]$sb.AppendLine('<table><thead><tr><th>Drive</th><th>Folder</th><th>Subdirs</th><th>Top Files</th></tr></thead><tbody>')
        foreach ($f in $ScanData.CustomFolders) {
            [void]$sb.AppendLine("<tr><td>$($f.Drive):</td><td><strong>$($f.Name)</strong></td><td>$($f.SubDirs)</td><td>$($f.TopFiles)</td></tr>")
        }
        [void]$sb.AppendLine('</tbody></table>')
    }
    [void]$sb.AppendLine('</div>')

    # Tab: Manual Steps
    [void]$sb.AppendLine('<div id="tab-checklist" class="tab-content">')
    [void]$sb.AppendLine('<h2>Manual Steps Required</h2>')
    [void]$sb.AppendLine('<div class="section">')
    $manualSteps = @(
        "Outlook rules: Export via File &rarr; Manage Rules &rarr; Options &rarr; Export Rules"
        "SSH keys: Transfer via USB drive (never over unencrypted network)"
        "License keys: Note down any software license keys"
        "Browser passwords: Ensure sync is enabled or export passwords"
        "2FA/Authenticator: Ensure backup codes are saved"
        "VPN configs: Export or screenshot VPN connection settings"
        "Printer configs: Note network printer IPs/names"
        "Credential Manager: Review Windows Credential Manager for saved creds"
    )
    foreach ($step in $manualSteps) {
        [void]$sb.AppendLine("<div class=`"config-item`"><span class=`"config-icon`">&#9744;</span> $step</div>")
    }
    [void]$sb.AppendLine('</div></div>')

    # Footer + JS
    [void]$sb.AppendLine("<div class=`"footer`">Generated by <strong>Migrate-Laptop</strong> on $($ScanData.ScanDate) &middot; Created by gauravkhurana.com &middot; #SharingIsCaring</div>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('<script>')
    [void]$sb.AppendLine('function showTab(id){')
    [void]$sb.AppendLine('  document.querySelectorAll(".tab-content").forEach(t=>t.classList.remove("active"));')
    [void]$sb.AppendLine('  document.querySelectorAll(".tab").forEach(t=>t.classList.remove("active"));')
    [void]$sb.AppendLine('  document.getElementById("tab-"+id).classList.add("active");')
    [void]$sb.AppendLine('  event.target.classList.add("active");')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine('function filterSw(){')
    [void]$sb.AppendLine('  var s=document.getElementById("swSearch").value.toLowerCase();')
    [void]$sb.AppendLine('  var c=document.getElementById("swCatFilter").value;')
    [void]$sb.AppendLine('  document.querySelectorAll("#swTable tbody tr").forEach(function(r){')
    [void]$sb.AppendLine('    var t=r.textContent.toLowerCase(),rc=r.getAttribute("data-cat");')
    [void]$sb.AppendLine('    r.style.display=(!s||t.indexOf(s)>=0)&&(!c||rc===c)?"":"none";')
    [void]$sb.AppendLine('  });')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine('</script>')
    [void]$sb.AppendLine('</body></html>')

    Set-Content -Path $ReportPath -Value $sb.ToString() -Encoding UTF8
    Write-Log "HTML report saved: $ReportPath" -Level Success
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 5: SCRIPT GENERATION (Phase 2)
# ═══════════════════════════════════════════════════════════════════════════

# Progress tracker preamble — embedded into generated scripts for resume support
function Get-ProgressTrackerCode {
    param([string]$ScriptName)
    $trackerFile = "$ScriptName-progress.json"
    return @"
# ═══════════════════════════════════════════════════════════════
# PROGRESS TRACKER — Supports resume if interrupted
# ═══════════════════════════════════════════════════════════════
# A progress file ($trackerFile) tracks completed steps.
# If you re-run this script, already-completed steps are skipped.
# To start fresh, delete the progress file.

`$script:ProgressFile = Join-Path `$PSScriptRoot '$trackerFile'
`$script:Progress = @{}
if (Test-Path `$script:ProgressFile) {
    try {
        `$script:Progress = @{}
        `$loaded = Get-Content `$script:ProgressFile -Raw -Encoding UTF8 | ConvertFrom-Json
        `$loaded.PSObject.Properties | ForEach-Object { `$script:Progress[`$_.Name] = `$_.Value }
        `$done = @(`$script:Progress.Keys).Count
        Write-Host ""
        Write-Host "  Resuming from previous run — `$done steps already completed." -ForegroundColor Cyan
        Write-Host "  To start fresh, delete: $trackerFile" -ForegroundColor Gray
        Write-Host ""
    } catch {
        `$script:Progress = @{}
    }
}

function Save-Progress {
    param([string]`$StepId, [string]`$Status)
    `$script:Progress[`$StepId] = @{ Status = `$Status; CompletedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }
    `$script:Progress | ConvertTo-Json -Depth 3 | Set-Content -Path `$script:ProgressFile -Encoding UTF8
}

function Test-StepDone {
    param([string]`$StepId)
    return `$script:Progress.ContainsKey(`$StepId) -and `$script:Progress[`$StepId].Status -eq 'done'
}

"@
}

function Write-InstallScript {
    param([string]$ScriptPath, $ScanData)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<#')
    [void]$sb.AppendLine('.SYNOPSIS')
    [void]$sb.AppendLine('    Install software on the new laptop. Generated by Migrate-Laptop.')
    [void]$sb.AppendLine('.DESCRIPTION')
    [void]$sb.AppendLine("    Generated from scan of $($ScanData.ComputerName) on $($ScanData.ScanDate).")
    [void]$sb.AppendLine('    REVIEW EACH SECTION before running. Comment out anything you do not need.')
    [void]$sb.AppendLine('    Requires: winget (built into Windows 10/11)')
    [void]$sb.AppendLine('#>')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('# Ensure winget is available')
    [void]$sb.AppendLine('if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {')
    [void]$sb.AppendLine('    Write-Host "ERROR: winget is not available. Install App Installer from the Microsoft Store." -ForegroundColor Red')
    [void]$sb.AppendLine('    exit 1')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine('')

    # Add progress tracker
    [void]$sb.AppendLine((Get-ProgressTrackerCode -ScriptName "install-software"))

    # Bulk install header with instructions
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('# HOW TO USE THIS SCRIPT')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# This script installs software in 3 sections:')
    [void]$sb.AppendLine('#   1. DEVELOPER SOFTWARE  — Active by default (Git, VS Code, Node, Python...)')
    [void]$sb.AppendLine('#   2. GENERAL SOFTWARE    — Active by default (Chrome, Zoom, Slack...)')
    [void]$sb.AppendLine('#   3. OTHER SOFTWARE      — All COMMENTED OUT by default')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# To skip an app:  Add # at the start of its winget line')
    [void]$sb.AppendLine('# To add an app:   Remove # from its line in the OTHER section')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# Example — skip Docker but keep everything else:')
    [void]$sb.AppendLine('#   # winget install --id "Docker.DockerDesktop" ...   ← commented = skipped')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# Example — install Claude from OTHER section:')
    [void]$sb.AppendLine('#   winget install --id "Anthropic.Claude" ...          ← uncommented = will install')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# Each section asks for confirmation before running.')
    [void]$sb.AppendLine('# You can also run sections individually by copy-pasting.')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('')

    # Developer software
    $devSoftware = @($ScanData.Software | Where-Object { $_.IsDev -and $_.WingetId })
    if ($devSoftware.Count -gt 0) {
        [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
        [void]$sb.AppendLine("# DEVELOPER SOFTWARE ($($devSoftware.Count) apps)")
        [void]$sb.AppendLine('# These were detected on your old machine. Comment out any you')
        [void]$sb.AppendLine('# do NOT want by adding # at the start of the winget line.')
        [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('Write-Host "`n── Installing Developer Software ──`n" -ForegroundColor Cyan')
        [void]$sb.AppendLine("Write-Host `"  $($devSoftware.Count) apps to install. Review the list below.`" -ForegroundColor Gray")
        [void]$sb.AppendLine("Write-Host `"  To skip any: edit this file and add # before its winget line.`" -ForegroundColor Gray")
        [void]$sb.AppendLine('Write-Host ""')
        foreach ($s in $devSoftware) {
            [void]$sb.AppendLine("Write-Host `"    - $($s.Name)`" -ForegroundColor White")
        }
        [void]$sb.AppendLine('Write-Host ""')
        [void]$sb.AppendLine('$confirm = Read-Host "Install these developer apps? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        $idx = 0
        foreach ($s in $devSoftware) {
            $idx++
            $stepId = "dev-$idx"
            $safeId = $s.WingetId -replace '[^a-zA-Z0-9._]', ''
            [void]$sb.AppendLine("    if (Test-StepDone '$stepId') { Write-Host `"  [SKIP] $($s.Name) — already installed`" -ForegroundColor DarkGray }")
            [void]$sb.AppendLine("    else {")
            [void]$sb.AppendLine("        Write-Host `"Installing [$idx/$($devSoftware.Count)]: $($s.Name)`" -ForegroundColor Yellow")
            [void]$sb.AppendLine("        winget install --id `"$($s.WingetId)`" --accept-package-agreements --accept-source-agreements")
            [void]$sb.AppendLine("        Save-Progress '$stepId' 'done'")
            [void]$sb.AppendLine("    }")
            [void]$sb.AppendLine('')
        }
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('')
    }

    # General software
    $genSoftware = @($ScanData.Software | Where-Object { $_.IsGeneral -and $_.WingetId })
    if ($genSoftware.Count -gt 0) {
        [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
        [void]$sb.AppendLine("# GENERAL SOFTWARE ($($genSoftware.Count) apps)")
        [void]$sb.AppendLine('# Common applications detected on your old machine.')
        [void]$sb.AppendLine('# Comment out any you do NOT want.')
        [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('Write-Host "`n── Installing General Software ──`n" -ForegroundColor Cyan')
        [void]$sb.AppendLine("Write-Host `"  $($genSoftware.Count) apps to install. Review the list below.`" -ForegroundColor Gray")
        [void]$sb.AppendLine("Write-Host `"  To skip any: edit this file and add # before its winget line.`" -ForegroundColor Gray")
        [void]$sb.AppendLine('Write-Host ""')
        foreach ($s in $genSoftware) {
            [void]$sb.AppendLine("Write-Host `"    - $($s.Name)`" -ForegroundColor White")
        }
        [void]$sb.AppendLine('Write-Host ""')
        [void]$sb.AppendLine('$confirm = Read-Host "Install these general apps? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        $idx = 0
        foreach ($s in $genSoftware) {
            $idx++
            $stepId = "gen-$idx"
            [void]$sb.AppendLine("    if (Test-StepDone '$stepId') { Write-Host `"  [SKIP] $($s.Name) — already installed`" -ForegroundColor DarkGray }")
            [void]$sb.AppendLine("    else {")
            [void]$sb.AppendLine("        Write-Host `"Installing [$idx/$($genSoftware.Count)]: $($s.Name)`" -ForegroundColor Yellow")
            [void]$sb.AppendLine("        winget install --id `"$($s.WingetId)`" --accept-package-agreements --accept-source-agreements")
            [void]$sb.AppendLine("        Save-Progress '$stepId' 'done'")
            [void]$sb.AppendLine("    }")
            [void]$sb.AppendLine('')
        }
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('')
    }

    # Other software (all commented out)
    $otherWithWinget = @($ScanData.Software | Where-Object { -not $_.IsDev -and -not $_.IsGeneral -and $_.WingetId })
    if ($otherWithWinget.Count -gt 0) {
        [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
        [void]$sb.AppendLine("# OTHER SOFTWARE ($($otherWithWinget.Count) apps — ALL COMMENTED OUT)")
        [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
        [void]$sb.AppendLine('#')
        [void]$sb.AppendLine('# These were found on your old machine but are not in the known')
        [void]$sb.AppendLine('# essentials list. They are ALL commented out by default.')
        [void]$sb.AppendLine('#')
        [void]$sb.AppendLine('# To install any of them:')
        [void]$sb.AppendLine('#   1. Remove the # at the start of the winget line')
        [void]$sb.AppendLine('#   2. Save this file')
        [void]$sb.AppendLine('#   3. Run: powershell -File Install-Software.ps1')
        [void]$sb.AppendLine('#')
        [void]$sb.AppendLine('# Or copy individual lines and paste into a terminal.')
        [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
        [void]$sb.AppendLine('')
        foreach ($s in $otherWithWinget) {
            [void]$sb.AppendLine("# winget install --id `"$($s.WingetId)`" --accept-package-agreements --accept-source-agreements  # $($s.Name)")
        }
        [void]$sb.AppendLine('')
    }

    # Post-install config
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('# POST-INSTALL: Rebuild project dependencies')
    [void]$sb.AppendLine('# After transferring your project folders, run these in each project:')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('# Node.js projects:   npm install')
    [void]$sb.AppendLine('# Python projects:    pip install -r requirements.txt')
    [void]$sb.AppendLine('# Java/Maven:         mvn clean install')
    [void]$sb.AppendLine('# .NET:               dotnet restore')
    [void]$sb.AppendLine('# Gradle:             gradle build')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Write-Host "`nSoftware installation complete! Review any errors above.`n" -ForegroundColor Green')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('# MAC USERS: Use Homebrew instead of winget')
    [void]$sb.AppendLine('# Install Homebrew: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"')
    [void]$sb.AppendLine('# Then: brew install git node python docker')
    [void]$sb.AppendLine('# And:  brew install --cask visual-studio-code google-chrome firefox')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')

    Set-Content -Path $ScriptPath -Value $sb.ToString() -Encoding UTF8
    Write-Log "Install script saved: $ScriptPath" -Level Success
}

function Write-TransferScript {
    param([string]$ScriptPath, $ScanData)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<#')
    [void]$sb.AppendLine('.SYNOPSIS')
    [void]$sb.AppendLine('    Transfer data from old laptop to new laptop. Generated by Migrate-Laptop.')
    [void]$sb.AppendLine('.DESCRIPTION')
    [void]$sb.AppendLine("    Generated from scan of $($ScanData.ComputerName) on $($ScanData.ScanDate).")
    [void]$sb.AppendLine('    Supports 3 transfer methods: Network (robocopy), USB drive, or Cloud (OneDrive).')
    [void]$sb.AppendLine('    Run this script on the OLD laptop to push data to the new one.')
    [void]$sb.AppendLine('    REVIEW EACH SECTION — modify paths as needed for your setup.')
    [void]$sb.AppendLine('#>')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('[CmdletBinding()] param()')
    [void]$sb.AppendLine('')

    # Add progress tracker
    [void]$sb.AppendLine((Get-ProgressTrackerCode -ScriptName "transfer-data"))

    [void]$sb.AppendLine('# ── Choose transfer method ──')
    [void]$sb.AppendLine('Write-Host "`n  ── Transfer Method ──`n" -ForegroundColor Cyan')
    [void]$sb.AppendLine('Write-Host "  Compare your options:" -ForegroundColor Gray')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('Write-Host "   Method                  Speed          Time for 40 GB   You need" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "   ──────────────────────   ────────────   ──────────────   ─────────────────────────" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "   USB-C to USB-C cable    Up to 10 Gbps  ~30 seconds      USB-C port on both laptops" -ForegroundColor White')
    [void]$sb.AppendLine('Write-Host "   WiFi 6 / 6E (5-6 GHz)  80-150 MB/s    4-8 minutes      Both on same 5/6 GHz WiFi" -ForegroundColor White')
    [void]$sb.AppendLine('Write-Host "   WiFi 5 (5 GHz)         30-60 MB/s     11-22 minutes    Both on same 5 GHz WiFi" -ForegroundColor White')
    [void]$sb.AppendLine('Write-Host "   USB 3.0 external drive  80-100 MB/s    7-8 minutes      USB drive + USB 3.0 port" -ForegroundColor White')
    [void]$sb.AppendLine('Write-Host "   WiFi (2.4 GHz)         5-15 MB/s      45 min - 2 hrs   Avoid if possible" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "   Cloud (OneDrive etc.)   Depends on ISP Varies           Internet upload + download" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('Write-Host "  Pick your method:" -ForegroundColor Cyan')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('Write-Host "  [1] WiFi / Network (both laptops on same WiFi, share a folder)"')
    [void]$sb.AppendLine('Write-Host "  [2] USB / External Drive (copy to drive, plug into new laptop)"')
    [void]$sb.AppendLine('Write-Host "  [3] Cloud (OneDrive / Google Drive sync folder)"')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('Write-Host "  TIP: USB-C cable and WiFi both use option [1] — they appear as" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  a network share either way. Plug in the cable and share a folder." -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('$method = Read-Host "  Enter choice [1-3]"')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('switch ($method) {')
    [void]$sb.AppendLine('    ''1'' {')
    [void]$sb.AppendLine('        Write-Host ""')
    [void]$sb.AppendLine('        Write-Host "  ── Network Transfer Setup ──" -ForegroundColor Cyan')
    [void]$sb.AppendLine('        Write-Host ""')
    [void]$sb.AppendLine('        Write-Host "  SPEED TIP:" -ForegroundColor Yellow')
    [void]$sb.AppendLine('        Write-Host "    If your WiFi has multiple bands (2.4 GHz / 5 GHz / 6 GHz)," -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host "    connect BOTH laptops to the highest band (5 GHz or 6 GHz)." -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host "    5 GHz is ~3x faster than 2.4 GHz. 6 GHz (WiFi 6E) is even faster." -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host "    Ethernet cable is the fastest option if available." -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host ""')
    [void]$sb.AppendLine('        Write-Host "  Before continuing, set up the NEW laptop:" -ForegroundColor Yellow')
    [void]$sb.AppendLine('        Write-Host "    1. Both laptops must be on the SAME WiFi/network" -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host "    2. On the NEW laptop, create a folder (e.g., C:\Migration)" -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host "    3. Right-click the folder → Properties → Sharing → Share" -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host "    4. Add ''Everyone'' with Read/Write permission → Share" -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host "    5. Note the computer name: open CMD and type ''hostname''" -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host ""')
    [void]$sb.AppendLine('        $setupDone = Read-Host "  Is the shared folder ready on the new laptop? [Y/n]"')
    [void]$sb.AppendLine('        if ($setupDone -match ''^[nN]'') {')
    [void]$sb.AppendLine('            Write-Host "  Set up the shared folder first, then re-run this script." -ForegroundColor Yellow')
    [void]$sb.AppendLine('            exit 0')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('        $newLaptop = Read-Host "  Enter new laptop name or IP (e.g., NEW-LAPTOP or 192.168.1.50)"')
    [void]$sb.AppendLine('        $shareName = Read-Host "  Enter shared folder name on new laptop (e.g., Migration)"')
    [void]$sb.AppendLine('        $destBase = "\\$newLaptop\$shareName"')
    [void]$sb.AppendLine('        Write-Host ""')
    [void]$sb.AppendLine('        Write-Host "  Testing connection to $newLaptop..." -ForegroundColor Gray')
    [void]$sb.AppendLine('        if (-not (Test-Connection -ComputerName $newLaptop -Count 1 -Quiet -ErrorAction SilentlyContinue)) {')
    [void]$sb.AppendLine('            Write-Host "  Cannot reach $newLaptop on the network." -ForegroundColor Red')
    [void]$sb.AppendLine('            Write-Host "  Check:" -ForegroundColor Yellow')
    [void]$sb.AppendLine('            Write-Host "    - Both laptops are on the same WiFi/network" -ForegroundColor Gray')
    [void]$sb.AppendLine('            Write-Host "    - Firewall is not blocking file sharing" -ForegroundColor Gray')
    [void]$sb.AppendLine('            Write-Host "    - Computer name is correct (run ''hostname'' on new laptop)" -ForegroundColor Gray')
    [void]$sb.AppendLine('            Write-Host "    - Try using the IP address instead of the name" -ForegroundColor Gray')
    [void]$sb.AppendLine('            exit 1')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('        Write-Host "  Connected to $newLaptop" -ForegroundColor Green')
    [void]$sb.AppendLine('        Write-Host ""')
    [void]$sb.AppendLine('        Write-Host "  Quick test: Open Run (Win+R) on this laptop and type:" -ForegroundColor Yellow')
    [void]$sb.AppendLine('        Write-Host "    \\$newLaptop\$shareName" -ForegroundColor Cyan')
    [void]$sb.AppendLine('        Write-Host "  If a folder opens, the connection is working." -ForegroundColor Gray')
    [void]$sb.AppendLine('        Write-Host ""')
    [void]$sb.AppendLine('        $testOk = Read-Host "  Can you see the shared folder? [Y/n]"')
    [void]$sb.AppendLine('        if ($testOk -match ''^[nN]'') {')
    [void]$sb.AppendLine('            Write-Host "  Troubleshooting:" -ForegroundColor Yellow')
    [void]$sb.AppendLine('            Write-Host "    - Ensure Network Discovery is ON: Settings → Network → Advanced sharing" -ForegroundColor Gray')
    [void]$sb.AppendLine('            Write-Host "    - Turn off ''Password protected sharing'' (or use new laptop credentials)" -ForegroundColor Gray')
    [void]$sb.AppendLine('            Write-Host "    - Check Windows Firewall: allow ''File and Printer Sharing''" -ForegroundColor Gray')
    [void]$sb.AppendLine('            Write-Host "    - Try: \\\\<IP address>\\$shareName instead of hostname" -ForegroundColor Gray')
    [void]$sb.AppendLine('            exit 1')
    [void]$sb.AppendLine('        }')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('    ''2'' {')
    [void]$sb.AppendLine('        $destBase = Read-Host "  Enter external drive path (e.g., F:\Migration)"')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('    ''3'' {')
    [void]$sb.AppendLine('        $destBase = Read-Host "  Enter cloud sync folder path (e.g., C:\Users\you\OneDrive\Migration)"')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('    default {')
    [void]$sb.AppendLine('        Write-Host "  Invalid choice. Exiting." -ForegroundColor Red; exit 1')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('if (-not (Test-Path $destBase)) {')
    [void]$sb.AppendLine('    Write-Host "  Destination not reachable: $destBase" -ForegroundColor Red')
    [void]$sb.AppendLine('    Write-Host "  For network: ensure the folder is shared on the new laptop." -ForegroundColor Yellow')
    [void]$sb.AppendLine('    Write-Host "  Right-click folder → Properties → Sharing → Share..." -ForegroundColor Gray')
    [void]$sb.AppendLine('    exit 1')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('# Robocopy common flags:')
    [void]$sb.AppendLine('#   /E       = include subdirectories (even empty)')
    [void]$sb.AppendLine('#   /MT:16   = multi-threaded (16 threads for speed)')
    [void]$sb.AppendLine('#   /R:1     = retry once on failure')
    [void]$sb.AppendLine('#   /W:1     = wait 1 second between retries')
    [void]$sb.AppendLine('#   /XD      = exclude directories')
    [void]$sb.AppendLine('#   /XF      = exclude files')
    [void]$sb.AppendLine('#   /NP      = no progress percentage (cleaner output)')
    [void]$sb.AppendLine('#   /LOG+    = append to log file')
    [void]$sb.AppendLine('')

    # Build exclude args
    $xdArgs = ($script:ExcludeDirs | ForEach-Object { "`"$_`"" }) -join " "
    $xfArgs = ($script:ExcludeFiles | ForEach-Object { "`"$_`"" }) -join " "
    [void]$sb.AppendLine("`$commonXD = @($xdArgs)")
    [void]$sb.AppendLine("`$commonXF = @($xfArgs)")
    [void]$sb.AppendLine("`$roboFlags = @('/E', '/MT:16', '/R:1', '/W:1', '/NP')")
    [void]$sb.AppendLine("`$logFile = Join-Path `$destBase 'transfer-log.txt'")
    [void]$sb.AppendLine("`$script:TransferStart = Get-Date")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('function Show-Elapsed {')
    [void]$sb.AppendLine('    param([DateTime]$Start)')
    [void]$sb.AppendLine('    $elapsed = (Get-Date) - $Start')
    [void]$sb.AppendLine('    if ($elapsed.TotalHours -ge 1) { return "{0}h {1}m" -f [int]$elapsed.TotalHours, $elapsed.Minutes }')
    [void]$sb.AppendLine('    if ($elapsed.TotalMinutes -ge 1) { return "{0}m {1}s" -f [int]$elapsed.TotalMinutes, $elapsed.Seconds }')
    [void]$sb.AppendLine('    return "{0}s" -f [int]$elapsed.TotalSeconds')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │  SAFE TO STOP AT ANY TIME                               │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │                                                          │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │  Press Ctrl+C to stop. Nothing will be corrupted.        │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │  Completed folders are saved. When you re-run this       │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │  script, finished folders show [SKIP] automatically.     │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │                                                          │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │  Robocopy is resume-safe — even a partially copied       │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  │  folder will continue from where it left off.            │" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('# FOLDER STRUCTURE')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# Files are organized by source drive to avoid name clashes:')
    [void]$sb.AppendLine('#   migration/C/Desktop, migration/C/Documents, migration/C/Projects')
    [void]$sb.AppendLine('#   migration/D/Automation, migration/D/Projects')
    [void]$sb.AppendLine('#   migration/E/Code, migration/E/Backups')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('')

    # User profile folders (all on C:)
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('# USER PROFILE FOLDERS (C:\Users)')
    [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
    [void]$sb.AppendLine('')

    # Check for OneDrive-redirected folders and warn
    $oneDriveFolders = @($ScanData.UserFolders | Where-Object { $_.IsOneDrive })
    if ($oneDriveFolders.Count -gt 0) {
        [void]$sb.AppendLine('# ── ONEDRIVE NOTICE ──')
        [void]$sb.AppendLine('Write-Host ""')
        [void]$sb.AppendLine('Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  │  ONEDRIVE DETECTED                                      │" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  ├──────────────────────────────────────────────────────────┤" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  │  Some folders are synced to OneDrive (corporate or       │" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  │  personal). These will sync automatically when you sign   │" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  │  into OneDrive on the new laptop — no need to copy them. │" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  │                                                          │" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  │  OneDrive-synced folders detected:                       │" -ForegroundColor Blue')
        foreach ($odf in $oneDriveFolders) {
            [void]$sb.AppendLine("Write-Host `"  │    $($odf.Name) → $($odf.Path)`" -ForegroundColor DarkCyan")
        }
        [void]$sb.AppendLine('Write-Host "  │                                                          │" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  │  You can SKIP these — or copy them as a backup.          │" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Blue')
        [void]$sb.AppendLine('Write-Host ""')
        [void]$sb.AppendLine('')
    }

    $folderIdx = 0
    foreach ($f in $ScanData.UserFolders) {
        if ($f.FileCount -eq 0) { continue }
        $folderIdx++
        $safeName = $f.Name -replace '[^a-zA-Z0-9]', ''
        $stepId = "folder-$safeName"
        $oneDriveTag = if ($f.IsOneDrive) { " [ONEDRIVE — syncs automatically]" } else { "" }
        [void]$sb.AppendLine("# $($f.Name): $($f.FileCount) files, $($f.SizeText)$oneDriveTag")
        [void]$sb.AppendLine("if (Test-StepDone '$stepId') { Write-Host `"  [SKIP] $($f.Name) — already transferred`" -ForegroundColor DarkGray }")
        [void]$sb.AppendLine("else {")
        if ($f.IsOneDrive) {
            [void]$sb.AppendLine("Write-Host `"  ☁ $($f.Name) is synced to OneDrive — it will sync automatically on the new laptop.`" -ForegroundColor Blue")
            [void]$sb.AppendLine("`$confirm$safeName = Read-Host `"  Copy $($f.Name) anyway as backup ($($f.SizeText))? [y/N]`"")
            [void]$sb.AppendLine("if (`$confirm$safeName -match '^[yY]') {")
        } else {
            [void]$sb.AppendLine("`$confirm$safeName = Read-Host `"Transfer $($f.Name) ($($f.SizeText))? [Y/n]`"")
            [void]$sb.AppendLine("if (`$confirm$safeName -notmatch '^[nN]') {")
        }
        [void]$sb.AppendLine("    Write-Host `"  Transferring $($f.Name)...`" -ForegroundColor Yellow")
        [void]$sb.AppendLine("    `$stepStart = Get-Date")
        [void]$sb.AppendLine("    robocopy `"$($f.Path)`" `"`$destBase\C\$($f.Name)`" `$roboFlags /XD `$commonXD /XF `$commonXF /LOG+:`$logFile")
        [void]$sb.AppendLine("    Save-Progress '$stepId' 'done'")
        [void]$sb.AppendLine("    Write-Host `"  $($f.Name) done in `$(Show-Elapsed `$stepStart)`" -ForegroundColor Green")
        [void]$sb.AppendLine("}")
        [void]$sb.AppendLine("}")  # close else block
        [void]$sb.AppendLine('')
    }

    # Custom data folders — C: drive per-folder, other drives grouped
    if ($ScanData.CustomFolders.Count -gt 0) {
        # Group folders by drive
        $driveGroups = @{}
        foreach ($f in $ScanData.CustomFolders) {
            $drv = $f.Drive
            if (-not $driveGroups.ContainsKey($drv)) { $driveGroups[$drv] = @() }
            $driveGroups[$drv] += $f
        }

        # ── C: Drive — per-folder confirmation (system drive, needs careful selection) ──
        if ($driveGroups.ContainsKey('C')) {
            $cFolders = $driveGroups['C']
            [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
            [void]$sb.AppendLine("# C: DRIVE — CUSTOM FOLDERS ($($cFolders.Count) found)")
            [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
            [void]$sb.AppendLine('#')
            [void]$sb.AppendLine('# These are non-system folders found on C:\. Each one asks for')
            [void]$sb.AppendLine('# confirmation individually because C: contains system data.')
            [void]$sb.AppendLine('#')
            [void]$sb.AppendLine('# ALREADY EXCLUDED (never copied):')
            [void]$sb.AppendLine('#   Windows, Program Files, Program Files (x86), ProgramData,')
            [void]$sb.AppendLine('#   Users (profile folders are handled separately above),')
            [void]$sb.AppendLine('#   $Recycle.Bin, Recovery, System Volume Information, PerfLogs')
            [void]$sb.AppendLine('#')
            [void]$sb.AppendLine('# Only your custom folders on C:\ are listed below.')
            [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine('Write-Host "`n── C: Drive Custom Folders ──`n" -ForegroundColor Cyan')
            [void]$sb.AppendLine('Write-Host "  System folders (Windows, Program Files, Users) are excluded." -ForegroundColor DarkGray')
            [void]$sb.AppendLine('Write-Host "  Only your custom folders are shown below.`n" -ForegroundColor DarkGray')
            foreach ($f in $cFolders) {
                $safeName = "C_$($f.Name)" -replace '[^a-zA-Z0-9_]', ''
                $stepId = "folder-C-$safeName"
                [void]$sb.AppendLine("# C:\$($f.Name) ($($f.SubDirs) subdirs, $($f.TopFiles) top files)")
                [void]$sb.AppendLine("if (Test-StepDone '$stepId') { Write-Host `"  [SKIP] C:\$($f.Name) — already transferred`" -ForegroundColor DarkGray }")
                [void]$sb.AppendLine("else {")
                [void]$sb.AppendLine("`$confirm$safeName = Read-Host `"  Transfer C:\$($f.Name)? [Y/n]`"")
                [void]$sb.AppendLine("if (`$confirm$safeName -notmatch '^[nN]') {")
                [void]$sb.AppendLine("    Write-Host `"  Transferring C:\$($f.Name)...`" -ForegroundColor Yellow")
                [void]$sb.AppendLine("    `$stepStart = Get-Date")
                [void]$sb.AppendLine("    robocopy `"$($f.Path)`" `"`$destBase\C\$($f.Name)`" `$roboFlags /XD `$commonXD /XF `$commonXF /LOG+:`$logFile")
                [void]$sb.AppendLine("    Save-Progress '$stepId' 'done'")
                [void]$sb.AppendLine("    Write-Host `"  C:\$($f.Name) done in `$(Show-Elapsed `$stepStart)`" -ForegroundColor Green")
                [void]$sb.AppendLine("}")
                [void]$sb.AppendLine("}")  # close else
                [void]$sb.AppendLine('')
            }
        }

        # ── Other Drives (D:, E:, etc.) — grouped per drive, per-folder progress ──
        $otherDrives = $driveGroups.Keys | Where-Object { $_ -ne 'C' } | Sort-Object
        if ($otherDrives) {
            [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
            [void]$sb.AppendLine('# OTHER DRIVES — one confirmation per drive')
            [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
            [void]$sb.AppendLine('#')
            [void]$sb.AppendLine('# Non-C drives are transferred per drive. To skip a specific')
            [void]$sb.AppendLine('# folder, comment out its robocopy line below before running.')
            [void]$sb.AppendLine('#')
            [void]$sb.AppendLine('# Progress is tracked per folder — if interrupted, re-run and')
            [void]$sb.AppendLine('# completed folders will be skipped automatically.')
            [void]$sb.AppendLine('# ═══════════════════════════════════════════════════════════════')
            [void]$sb.AppendLine('')

            foreach ($drv in $otherDrives) {
                $folders = $driveGroups[$drv]
                [void]$sb.AppendLine("# ── Drive $($drv): — $($folders.Count) folders ──")
                [void]$sb.AppendLine("# Folders that will be copied (comment out any you DON'T want):")
                foreach ($f in $folders) {
                    [void]$sb.AppendLine("#   $($f.Name) ($($f.SubDirs) subdirs, $($f.TopFiles) top files)")
                }
                [void]$sb.AppendLine("")

                # Check if ALL folders on this drive are already done
                [void]$sb.AppendLine("Write-Host `"`n  Drive $($drv): — $($folders.Count) folders found:`" -ForegroundColor Cyan")
                foreach ($f in $folders) {
                    [void]$sb.AppendLine("Write-Host `"    $($f.Name)`" -ForegroundColor White")
                }
                [void]$sb.AppendLine("Write-Host `"  To skip specific folders: exit, edit this script, comment out their robocopy lines.`" -ForegroundColor DarkGray")
                [void]$sb.AppendLine("`$confirmDrive$drv = Read-Host `"  Transfer $($drv): drive ($($folders.Count) folders)? [Y/n]`"")
                [void]$sb.AppendLine("if (`$confirmDrive$drv -notmatch '^[nN]') {")

                foreach ($f in $folders) {
                    $safeName = "$($f.Drive)_$($f.Name)" -replace '[^a-zA-Z0-9_]', ''
                    $stepId = "folder-$safeName"
                    [void]$sb.AppendLine("    if (Test-StepDone '$stepId') { Write-Host `"    [SKIP] $($f.Name) — already transferred`" -ForegroundColor DarkGray }")
                    [void]$sb.AppendLine("    else {")
                    [void]$sb.AppendLine("        Write-Host `"  Transferring $($drv):\$($f.Name)...`" -ForegroundColor Yellow")
                    [void]$sb.AppendLine("        `$stepStart = Get-Date")
                    [void]$sb.AppendLine("        robocopy `"$($f.Path)`" `"`$destBase\$($f.Drive)\$($f.Name)`" `$roboFlags /XD `$commonXD /XF `$commonXF /LOG+:`$logFile")
                    [void]$sb.AppendLine("        Write-Host `"    done in `$(Show-Elapsed `$stepStart)`" -ForegroundColor DarkGray")
                    [void]$sb.AppendLine("        Save-Progress '$stepId' 'done'")
                    [void]$sb.AppendLine("    }")
                }

                [void]$sb.AppendLine("    Write-Host `"  Drive $($drv): transfer complete.`" -ForegroundColor Green")
                [void]$sb.AppendLine("}")
                [void]$sb.AppendLine('')
            }
        }
    }

    [void]$sb.AppendLine('Write-Host "`nData transfer complete in $(Show-Elapsed $script:TransferStart)! Check transfer-log.txt for details.`n" -ForegroundColor Green')

    Set-Content -Path $ScriptPath -Value $sb.ToString() -Encoding UTF8
    Write-Log "Transfer script saved: $ScriptPath" -Level Success
}

function Write-RestoreConfigsScript {
    param([string]$ScriptPath, $ScanData)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<#')
    [void]$sb.AppendLine('.SYNOPSIS')
    [void]$sb.AppendLine('    Restore configurations on the new laptop. Generated by Migrate-Laptop.')
    [void]$sb.AppendLine('.DESCRIPTION')
    [void]$sb.AppendLine("    Generated from scan of $($ScanData.ComputerName) on $($ScanData.ScanDate).")
    [void]$sb.AppendLine('    Run this on the NEW laptop after transferring data.')
    [void]$sb.AppendLine('    Each section asks for confirmation before proceeding.')
    [void]$sb.AppendLine('#>')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('$migrationDir = $PSScriptRoot  # Assumes this script is in the migration output folder')
    [void]$sb.AppendLine('$userProfile = $env:USERPROFILE')
    [void]$sb.AppendLine('')

    # Add progress tracker
    [void]$sb.AppendLine((Get-ProgressTrackerCode -ScriptName "restore-configs"))

    # Git config
    if ($ScanData.Configs.GitConfig.Found) {
        [void]$sb.AppendLine('# ── Git Config ──')
        [void]$sb.AppendLine('if (Test-StepDone ''gitconfig'') { Write-Host "  [SKIP] .gitconfig - already restored" -ForegroundColor DarkGray }')
        [void]$sb.AppendLine('else {')
        [void]$sb.AppendLine('$confirm = Read-Host "Restore .gitconfig? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        [void]$sb.AppendLine('    $gitconfigContent = @"')
        $gitContent = $ScanData.Configs.GitConfig.Content
        if ($gitContent) {
            foreach ($line in ($gitContent -split "`n")) {
                $safeLine = $line.TrimEnd()
                # Escape here-string terminator to prevent code injection in generated script
                if ($safeLine -eq '"@') { $safeLine = '`"@' }
                [void]$sb.AppendLine($safeLine)
            }
        }
        [void]$sb.AppendLine('"@')
        [void]$sb.AppendLine('    $gitconfigContent | Set-Content -Path (Join-Path $userProfile ".gitconfig") -Encoding UTF8')
        [void]$sb.AppendLine('    Write-Host "  .gitconfig restored." -ForegroundColor Green')
        [void]$sb.AppendLine("    Save-Progress 'gitconfig' 'done'")
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('}')  # close else
        [void]$sb.AppendLine('')
    }

    # SSH keys reminder
    if ($ScanData.Configs.SSHKeys.Found) {
        [void]$sb.AppendLine('# ── SSH Keys ──')
        [void]$sb.AppendLine('# SECURITY: SSH keys should be transferred manually via USB drive.')
        [void]$sb.AppendLine('# Copy the contents of your old .ssh folder to the new one:')
        [void]$sb.AppendLine("#   Source: $($ScanData.Configs.SSHKeys.Path)")
        [void]$sb.AppendLine('#   Destination: $env:USERPROFILE\.ssh')
        [void]$sb.AppendLine('#')
        [void]$sb.AppendLine('# After copying, fix permissions:')
        [void]$sb.AppendLine('# icacls "$env:USERPROFILE\.ssh\id_rsa" /inheritance:r /grant:r "$($env:USERNAME):(R)"')
        [void]$sb.AppendLine('# icacls "$env:USERPROFILE\.ssh\id_ed25519" /inheritance:r /grant:r "$($env:USERNAME):(R)"')
        [void]$sb.AppendLine('#')
        [void]$sb.AppendLine("# Files found: $($ScanData.Configs.SSHKeys.Files -join ', ')")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('Write-Host "  SSH Keys: Copy manually from USB drive to $env:USERPROFILE\.ssh" -ForegroundColor Yellow')
        [void]$sb.AppendLine('Write-Host "  Then run: icacls `"$env:USERPROFILE\.ssh\id_*`" /inheritance:r /grant:r `"$($env:USERNAME):(R)`"" -ForegroundColor Gray')
        [void]$sb.AppendLine('Read-Host "  Press Enter after copying SSH keys (or skip)"')
        [void]$sb.AppendLine('')
    }

    # VS Code extensions
    if ($ScanData.Configs.VSCode.Extensions.Count -gt 0) {
        [void]$sb.AppendLine('# ── VS Code Extensions ──')
        [void]$sb.AppendLine('if (Test-StepDone ''vscode-ext'') { Write-Host "  [SKIP] VS Code extensions - already installed" -ForegroundColor DarkGray }')
        [void]$sb.AppendLine('else {')
        [void]$sb.AppendLine('$confirm = Read-Host "Install VS Code extensions ($($ScanData.Configs.VSCode.Extensions.Count) extensions)? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        [void]$sb.AppendLine('    if (Get-Command code -ErrorAction SilentlyContinue) {')
        foreach ($ext in $ScanData.Configs.VSCode.Extensions) {
            [void]$sb.AppendLine("        code --install-extension `"$ext`"")
        }
        [void]$sb.AppendLine('        Write-Host "  VS Code extensions installed." -ForegroundColor Green')
        [void]$sb.AppendLine("        Save-Progress 'vscode-ext' 'done'")
        [void]$sb.AppendLine('    } else {')
        [void]$sb.AppendLine('        Write-Host "  VS Code not found — install it first, then re-run this section." -ForegroundColor Red')
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('}')  # close else
        [void]$sb.AppendLine('')
    }

    # VS Code settings
    if ($ScanData.Configs.VSCode.SettingsExist) {
        [void]$sb.AppendLine('# ── VS Code Settings ──')
        [void]$sb.AppendLine('# Your VS Code settings.json was found at:')
        [void]$sb.AppendLine("#   $($ScanData.Configs.VSCode.SettingsPath)")
        [void]$sb.AppendLine('# Copy it to: %APPDATA%\Code\User\settings.json on the new machine')
        [void]$sb.AppendLine('# Or better — enable Settings Sync in VS Code: Ctrl+Shift+P → "Settings Sync: Turn On"')
        [void]$sb.AppendLine('')
    }

    # PowerShell profile
    if ($ScanData.Configs.PSProfile.Found) {
        [void]$sb.AppendLine('# ── PowerShell Profile ──')
        [void]$sb.AppendLine('if (Test-StepDone ''ps-profile'') { Write-Host "  [SKIP] PowerShell profile - already restored" -ForegroundColor DarkGray }')
        [void]$sb.AppendLine('else {')
        [void]$sb.AppendLine('$confirm = Read-Host "Restore PowerShell profile? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        [void]$sb.AppendLine('    $profileDir = Split-Path $PROFILE -Parent')
        [void]$sb.AppendLine('    if (-not (Test-Path $profileDir)) { New-Item -Path $profileDir -ItemType Directory -Force | Out-Null }')
        [void]$sb.AppendLine('    $profileContent = @"')
        $psContent = $ScanData.Configs.PSProfile.Content
        if ($psContent) {
            foreach ($line in ($psContent -split "`n")) {
                $safeLine = $line.TrimEnd()
                # Escape here-string terminator to prevent code injection in generated script
                if ($safeLine -eq '"@') { $safeLine = '`"@' }
                [void]$sb.AppendLine($safeLine)
            }
        }
        [void]$sb.AppendLine('"@')
        [void]$sb.AppendLine('    $profileContent | Set-Content -Path $PROFILE -Encoding UTF8')
        [void]$sb.AppendLine('    Write-Host "  PowerShell profile restored at $PROFILE" -ForegroundColor Green')
        [void]$sb.AppendLine("    Save-Progress 'ps-profile' 'done'")
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('}')  # close else
        [void]$sb.AppendLine('')
    }

    # Windows Terminal settings
    if ($ScanData.Configs.WindowsTerminal.Found) {
        [void]$sb.AppendLine('# ── Windows Terminal Settings ──')
        [void]$sb.AppendLine('# Your Windows Terminal settings were found at:')
        [void]$sb.AppendLine("#   $($ScanData.Configs.WindowsTerminal.Path)")
        [void]$sb.AppendLine('# Windows Terminal syncs via your Microsoft account if signed in.')
        [void]$sb.AppendLine('# Otherwise, copy settings.json to the equivalent path on the new machine.')
        [void]$sb.AppendLine('')
    }

    # Environment variables
    if ($ScanData.Configs.EnvVars.Found) {
        [void]$sb.AppendLine('# ── User Environment Variables ──')
        [void]$sb.AppendLine('if (Test-StepDone ''env-vars'') { Write-Host "  [SKIP] Environment variables - already restored" -ForegroundColor DarkGray }')
        [void]$sb.AppendLine('else {')
        [void]$sb.AppendLine('$confirm = Read-Host "Restore user environment variables? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        foreach ($v in $ScanData.Configs.EnvVars.Variables) {
            $safeName = $v.Name -replace "'", "''"
            $safeValue = $v.Value -replace "'", "''"
            [void]$sb.AppendLine("    Write-Host `"  Setting: $($v.Name)`" -ForegroundColor Gray")
            [void]$sb.AppendLine("    [Environment]::SetEnvironmentVariable('$safeName', '$safeValue', 'User')")
        }
        [void]$sb.AppendLine('    Write-Host "  Environment variables restored." -ForegroundColor Green')
        [void]$sb.AppendLine("    Save-Progress 'env-vars' 'done'")
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('}')  # close else
        [void]$sb.AppendLine('')
    }

    # Browser bookmarks
    if ($ScanData.Configs.Bookmarks.Found) {
        [void]$sb.AppendLine('# ── Browser Bookmarks ──')
        [void]$sb.AppendLine('# Bookmarks are best synced via browser sign-in:')
        [void]$sb.AppendLine('#   Chrome: Sign in with Google account → bookmarks sync automatically')
        [void]$sb.AppendLine('#   Edge: Sign in with Microsoft account → bookmarks sync automatically')
        [void]$sb.AppendLine('#   Firefox: Sign in with Firefox account → bookmarks sync automatically')
        [void]$sb.AppendLine('# If not using sync, the bookmark files were backed up in the migration data.')
        [void]$sb.AppendLine('')
    }

    # npm global packages
    if ($ScanData.Configs.NpmGlobal.Found -and $ScanData.Configs.NpmGlobal.Packages.Count -gt 0) {
        [void]$sb.AppendLine('# ── npm Global Packages ──')
        [void]$sb.AppendLine('if (Test-StepDone ''npm-global'') { Write-Host "  [SKIP] npm global packages - already installed" -ForegroundColor DarkGray }')
        [void]$sb.AppendLine('else {')
        [void]$sb.AppendLine('$confirm = Read-Host "Install npm global packages? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        [void]$sb.AppendLine('    if (Get-Command npm -ErrorAction SilentlyContinue) {')
        $npmNames = ($ScanData.Configs.NpmGlobal.Packages | ForEach-Object { $_.Name }) -join " "
        [void]$sb.AppendLine("        npm install -g $npmNames")
        [void]$sb.AppendLine('        Write-Host "  npm global packages installed." -ForegroundColor Green')
        [void]$sb.AppendLine("        Save-Progress 'npm-global' 'done'")
        [void]$sb.AppendLine('    } else {')
        [void]$sb.AppendLine('        Write-Host "  npm not found — install Node.js first." -ForegroundColor Red')
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('}')  # close else
        [void]$sb.AppendLine('')
    }

    # pip packages
    if ($ScanData.Configs.PipPackages.Found -and $ScanData.Configs.PipPackages.Packages.Count -gt 0) {
        [void]$sb.AppendLine('# ── pip User Packages ──')
        [void]$sb.AppendLine('if (Test-StepDone ''pip-user'') { Write-Host "  [SKIP] pip packages - already installed" -ForegroundColor DarkGray }')
        [void]$sb.AppendLine('else {')
        [void]$sb.AppendLine('$confirm = Read-Host "Install pip user packages? [Y/n]"')
        [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
        [void]$sb.AppendLine('    if (Get-Command pip -ErrorAction SilentlyContinue) {')
        $pipNames = ($ScanData.Configs.PipPackages.Packages | ForEach-Object { $_.Name }) -join " "
        [void]$sb.AppendLine("        pip install --user $pipNames")
        [void]$sb.AppendLine('        Write-Host "  pip packages installed." -ForegroundColor Green')
        [void]$sb.AppendLine("        Save-Progress 'pip-user' 'done'")
        [void]$sb.AppendLine('    } else {')
        [void]$sb.AppendLine('        Write-Host "  pip not found — install Python first." -ForegroundColor Red')
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('}')  # close else
        [void]$sb.AppendLine('')
    }

    # Hosts file
    if ($ScanData.Configs.HostsFile.Found) {
        [void]$sb.AppendLine('# ── Hosts File ──')
        [void]$sb.AppendLine('# Custom entries found in your hosts file (requires admin to restore):')
        foreach ($entry in $ScanData.Configs.HostsFile.CustomEntries) {
            [void]$sb.AppendLine("#   $entry")
        }
        [void]$sb.AppendLine('# To restore: Run PowerShell as Admin and add these lines to C:\Windows\System32\drivers\etc\hosts')
        [void]$sb.AppendLine('')
    }

    # File Explorer preferences
    try {
        $feSettings = $ScanData.Configs.WindowsSettings.Settings.FileExplorer
        if ($feSettings -and $feSettings.Found) {
            [void]$sb.AppendLine('# ── File Explorer Preferences ──')
            [void]$sb.AppendLine('if (Test-StepDone ''file-explorer'') { Write-Host "  [SKIP] File Explorer settings - already restored" -ForegroundColor DarkGray }')
            [void]$sb.AppendLine('else {')
            [void]$sb.AppendLine('$confirm = Read-Host "Restore File Explorer preferences (show extensions, hidden files, etc.)? [Y/n]"')
            [void]$sb.AppendLine('if ($confirm -notmatch ''^[nN]'') {')
            [void]$sb.AppendLine('    $explorerKey = ''HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced''')
            if ($feSettings.ShowExtensions) {
                [void]$sb.AppendLine('    Set-ItemProperty -Path $explorerKey -Name HideFileExt -Value 0  # Show file extensions')
            }
            if ($feSettings.ShowHidden) {
                [void]$sb.AppendLine('    Set-ItemProperty -Path $explorerKey -Name Hidden -Value 1  # Show hidden files')
            }
            if ($feSettings.LaunchTo -eq 'This PC') {
                [void]$sb.AppendLine('    Set-ItemProperty -Path $explorerKey -Name LaunchTo -Value 1  # Open Explorer to This PC')
            }
            [void]$sb.AppendLine('    Write-Host "  File Explorer preferences restored." -ForegroundColor Green')
            [void]$sb.AppendLine("    Save-Progress 'file-explorer' 'done'")
            [void]$sb.AppendLine('}')
            [void]$sb.AppendLine('}')  # close else
            [void]$sb.AppendLine('')
        }
    } catch { }

    [void]$sb.AppendLine('Write-Host "`nConfiguration restore complete!`n" -ForegroundColor Green')
    [void]$sb.AppendLine('Write-Host "Next steps:" -ForegroundColor Cyan')
    [void]$sb.AppendLine('Write-Host "  1. Open your projects and run dependency installs (npm install, pip install, etc.)"')
    [void]$sb.AppendLine('Write-Host "  2. Test SSH: ssh -T git@github.com"')
    [void]$sb.AppendLine('Write-Host "  3. Sign into browsers to sync bookmarks/passwords"')
    [void]$sb.AppendLine('Write-Host "  4. Check VS Code extensions and settings"')
    [void]$sb.AppendLine('Write-Host ""')

    Set-Content -Path $ScriptPath -Value $sb.ToString() -Encoding UTF8
    Write-Log "Config restore script saved: $ScriptPath" -Level Success
}

function Write-AiReviewFile {
    param([string]$FilePath, $ScanData)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Migration Summary — For AI Review")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Paste this into ChatGPT, Copilot, or your preferred AI assistant for personalized migration advice.")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## My Setup")
    [void]$sb.AppendLine("- **Computer**: $($ScanData.ComputerName)")
    [void]$sb.AppendLine("- **OS**: $($ScanData.OSVersion)")
    [void]$sb.AppendLine("- **Drives**: $($ScanData.Drives.Count) ($( ($ScanData.Drives | ForEach-Object { "$($_.Name): ($($_.TotalGB) GB)" }) -join ', ' ))")
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Installed Software ($($ScanData.Software.Count) total)")
    $devSw = @($ScanData.Software | Where-Object { $_.IsDev })
    $genSw = @($ScanData.Software | Where-Object { $_.IsGeneral })
    [void]$sb.AppendLine("### Developer ($($devSw.Count))")
    foreach ($s in $devSw) { [void]$sb.AppendLine("- $($s.Name) ($($s.Version))") }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("### General ($($genSw.Count))")
    foreach ($s in $genSw) { [void]$sb.AppendLine("- $($s.Name) ($($s.Version))") }
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Data Folders")
    foreach ($f in $ScanData.UserFolders) {
        [void]$sb.AppendLine("- $($f.Name): $($f.FileCount) files, $($f.SizeText)")
    }
    [void]$sb.AppendLine("")

    [void]$sb.AppendLine("## Questions for AI")
    [void]$sb.AppendLine("1. Is there anything unusual in my software list that I should handle specially?")
    [void]$sb.AppendLine("2. Any recommendations for optimizing my new laptop setup?")
    [void]$sb.AppendLine("3. Are there any config files I might be missing?")
    [void]$sb.AppendLine("4. What's the best order to install and configure everything?")

    Set-Content -Path $FilePath -Value $sb.ToString() -Encoding UTF8
    Write-Log "AI review file saved: $FilePath" -Level Success
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 6: POST-MIGRATION CHECKLIST (Phase 3)
# ═══════════════════════════════════════════════════════════════════════════

function Show-PostMigrationChecklist {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║              Post-Migration Verification Checklist           ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    $checks = @(
        @{ Label = "VS Code opens and shows your extensions";            Cmd = "code --list-extensions | Measure-Object | Select -Expand Count" }
        @{ Label = "Git is installed and configured";                    Cmd = "git config --global user.name" }
        @{ Label = "SSH keys work (GitHub)";                             Cmd = "ssh -T git@github.com 2>&1" }
        @{ Label = "Node.js is installed";                               Cmd = "node --version 2>&1" }
        @{ Label = "Python is installed";                                Cmd = "python --version 2>&1" }
        @{ Label = "Java is installed";                                  Cmd = "java --version 2>&1" }
        @{ Label = "Docker is running";                                  Cmd = "docker --version 2>&1" }
        @{ Label = "Browser bookmarks are visible";                      Cmd = $null }
        @{ Label = "Environment variables are correct (check PATH)";     Cmd = $null }
        @{ Label = "Projects build successfully";                        Cmd = $null }
        @{ Label = "VPN connects properly";                              Cmd = $null }
        @{ Label = "Printers are configured";                            Cmd = $null }
    )

    $i = 0
    foreach ($check in $checks) {
        $i++
        if ($check.Cmd) {
            Write-Host "  [$i] $($check.Label)" -ForegroundColor White
            try {
                $result = Invoke-Expression $check.Cmd 2>&1
                Write-Host "      → $result" -ForegroundColor Gray
            } catch {
                Write-Host "      → Not available or not installed" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [$i] $($check.Label)" -ForegroundColor White
            Write-Host "      → Manual check required" -ForegroundColor DarkGray
        }

        $response = Read-Host "      Pass? [Y/n/skip]"
        if ($response -match '^[nN]') {
            Write-Host "      ✗ FAILED — address this before continuing" -ForegroundColor Red
        } elseif ($response -match '^[sS]') {
            Write-Host "      ○ Skipped" -ForegroundColor DarkGray
        } else {
            Write-Host "      ✓ Passed" -ForegroundColor Green
        }
        Write-Host ""
    }

    Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor Green
    Write-Host "  Migration verification complete!" -ForegroundColor Green
    Write-Host "  If all checks passed, your new laptop is ready." -ForegroundColor Green
    Write-Host "  Keep your old laptop data until you're confident." -ForegroundColor Yellow
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 6B: OLD LAPTOP CLEANUP (Destructive — double confirmation required)
# ═══════════════════════════════════════════════════════════════════════════

function Start-OldLaptopCleanup {
    # ── WARNING 1 of 2 ──
    Write-Host ""
    Write-Host "  ██████████████████████████████████████████████████████████████" -ForegroundColor Red
    Write-Host "  ██                                                          ██" -ForegroundColor Red
    Write-Host "  ██   ██     ██  █████  ██████  ███    ██ ██ ███    ██  ██████" -ForegroundColor Red
    Write-Host "  ██   ██     ██ ██   ██ ██   ██ ████   ██ ██ ████   ██ ██    " -ForegroundColor Red
    Write-Host "  ██   ██  █  ██ ███████ ██████  ██ ██  ██ ██ ██ ██  ██ ██  ██" -ForegroundColor Red
    Write-Host "  ██   ██ ███ ██ ██   ██ ██   ██ ██  ██ ██ ██ ██  ██ ██ ██  ██" -ForegroundColor Red
    Write-Host "  ██    ███ ███  ██   ██ ██   ██ ██   ████ ██ ██   ████  █████" -ForegroundColor Red
    Write-Host "  ██                                                          ██" -ForegroundColor Red
    Write-Host "  ██████████████████████████████████████████████████████████████" -ForegroundColor Red
    Write-Host ""
    Write-Host "  THIS WILL PERMANENTLY DELETE PERSONAL DATA FROM THIS LAPTOP" -ForegroundColor Red
    Write-Host "  THERE IS NO UNDO. FILES CANNOT BE RECOVERED." -ForegroundColor Red
    Write-Host ""
    Write-Host "  This cleanup will:" -ForegroundColor Yellow
    Write-Host "    1. Delete personal files (Desktop, Documents, Downloads, etc.)" -ForegroundColor Yellow
    Write-Host "    2. Delete custom data folders on all drives" -ForegroundColor Yellow
    Write-Host "    3. Remove browser profiles (Chrome, Edge, Firefox)" -ForegroundColor Yellow
    Write-Host "    4. Sign out of cloud accounts (OneDrive, Google, etc.)" -ForegroundColor Yellow
    Write-Host "    5. Remove saved WiFi passwords" -ForegroundColor Yellow
    Write-Host "    6. Clear Windows credentials" -ForegroundColor Yellow
    Write-Host "    7. Remove SSH keys and Git config" -ForegroundColor Yellow
    Write-Host "    8. Clear environment variables" -ForegroundColor Yellow
    Write-Host "    9. Empty Recycle Bin" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  It will NOT touch:" -ForegroundColor Green
    Write-Host "    - Windows installation (OS stays intact)" -ForegroundColor Green
    Write-Host "    - Installed programs (Program Files stays)" -ForegroundColor Green
    Write-Host "    - Your work login / domain account" -ForegroundColor Green
    Write-Host ""

    Write-Host "  CONFIRMATION 1 of 2:" -ForegroundColor Red
    Write-Host "  Have you verified the new laptop is fully working?" -ForegroundColor White
    $confirm1 = Read-Host "  Type 'I HAVE VERIFIED' to continue (anything else cancels)"
    if ($confirm1 -ne 'I HAVE VERIFIED') {
        Write-Host "  Cancelled. Good — verify your new laptop first." -ForegroundColor Green
        return
    }

    # ── WARNING 2 of 2 ──
    Write-Host ""
    Write-Host "  ██████████████████████████████████████████████████████████████" -ForegroundColor Red
    Write-Host "  ██                                                          ██" -ForegroundColor Red
    Write-Host "  ██       FINAL WARNING — POINT OF NO RETURN                 ██" -ForegroundColor Red
    Write-Host "  ██                                                          ██" -ForegroundColor Red
    Write-Host "  ██  Everything listed above will be PERMANENTLY DELETED     ██" -ForegroundColor Red
    Write-Host "  ██  from this laptop. This cannot be reversed.              ██" -ForegroundColor Red
    Write-Host "  ██                                                          ██" -ForegroundColor Red
    Write-Host "  ██████████████████████████████████████████████████████████████" -ForegroundColor Red
    Write-Host ""
    Write-Host "  CONFIRMATION 2 of 2:" -ForegroundColor Red
    $confirm2 = Read-Host "  Type 'DELETE MY DATA' to proceed (anything else cancels)"
    if ($confirm2 -ne 'DELETE MY DATA') {
        Write-Host "  Cancelled. Nothing was deleted." -ForegroundColor Green
        return
    }

    Write-Host ""
    Write-Log "Old laptop cleanup started — user confirmed twice" -Level Warn

    # ── Step 1: Clean user profile folders ──
    Write-Step "Step 1/9: Cleaning User Profile Folders"
    $profileFolders = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('MyDocuments'),
        (Join-Path $env:USERPROFILE "Downloads"),
        [Environment]::GetFolderPath('MyPictures'),
        [Environment]::GetFolderPath('MyVideos'),
        [Environment]::GetFolderPath('MyMusic')
    )
    foreach ($folder in $profileFolders) {
        if ($folder -and (Test-Path $folder)) {
            $folderName = Split-Path $folder -Leaf
            $confirm = Read-Host "  Delete contents of $folderName ($folder)? [y/N]"
            if ($confirm -match '^[yY]') {
                try {
                    Get-ChildItem -Path $folder -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleaned: $folder" -Level Success
                } catch {
                    Write-Log "Error cleaning $folder — $($_.Exception.Message)" -Level Error
                }
            } else {
                Write-Log "Skipped: $folder" -Level Info
            }
        }
    }

    # ── Step 2: Clean custom data folders on non-C drives ──
    Write-Step "Step 2/9: Cleaning Custom Data Folders (D:\, E:\, etc.)"
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { ($_.Used -or $_.Free) -and $_.Root -ne 'C:\' }
    foreach ($drive in $drives) {
        $root = $drive.Root
        # Skip temp drives
        if ($drive.Name -ieq 'Temp') { continue }
        $topFolders = Get-ChildItem -Path $root -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.Name.StartsWith('$') -and $_.Name -ne 'System Volume Information' -and $_.Name -ne '$RECYCLE.BIN' }
        if ($topFolders.Count -gt 0) {
            Write-Host "  Drive $($drive.Name): has $($topFolders.Count) folders" -ForegroundColor Yellow
            $confirmDrive = Read-Host "  Delete ALL personal data folders on $($drive.Name):? [y/N]"
            if ($confirmDrive -match '^[yY]') {
                foreach ($folder in $topFolders) {
                    try {
                        Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log "Deleted: $($folder.FullName)" -Level Success
                    } catch {
                        Write-Log "Error deleting $($folder.FullName) — $($_.Exception.Message)" -Level Warn
                    }
                }
            } else {
                Write-Log "Skipped drive $($drive.Name):" -Level Info
            }
        }
    }

    # ── Step 3: Remove browser profiles ──
    Write-Step "Step 3/9: Removing Browser Profiles"
    $browserPaths = @(
        @{ Name = "Chrome";  Path = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data" }
        @{ Name = "Edge";    Path = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data" }
        @{ Name = "Firefox"; Path = Join-Path $env:APPDATA "Mozilla\Firefox\Profiles" }
    )
    foreach ($browser in $browserPaths) {
        if (Test-Path $browser.Path) {
            $confirm = Read-Host "  Remove $($browser.Name) profile data ($($browser.Path))? [y/N]"
            if ($confirm -match '^[yY]') {
                try {
                    Remove-Item -Path $browser.Path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Removed $($browser.Name) profile data" -Level Success
                } catch {
                    Write-Log "Error removing $($browser.Name) — $($_.Exception.Message). Close the browser and retry." -Level Error
                }
            }
        }
    }

    # ── Step 4: Sign out of cloud accounts (guidance) ──
    Write-Step "Step 4/9: Cloud Account Sign-Out"
    Write-Host "  Cloud accounts need manual sign-out:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  OneDrive:" -ForegroundColor White
    Write-Host "    Right-click OneDrive icon in taskbar → Settings → Account → Unlink this PC" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Microsoft 365 / Teams:" -ForegroundColor White
    Write-Host "    Settings → Accounts → Sign out from all apps" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Google (if signed into Chrome — already removed in Step 3):" -ForegroundColor White
    Write-Host "    Go to myaccount.google.com/device-activity to remove this device" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  iCloud (if installed):" -ForegroundColor White
    Write-Host "    Open iCloud app → Sign Out" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Dropbox / other cloud storage:" -ForegroundColor White
    Write-Host "    Open the app → Preferences → Account → Unlink" -ForegroundColor Gray
    Write-Host ""
    # Try to stop/unlink OneDrive programmatically
    $odProcess = Get-Process OneDrive -ErrorAction SilentlyContinue
    if ($odProcess) {
        $confirm = Read-Host "  OneDrive is running. Stop it and clear local data? [y/N]"
        if ($confirm -match '^[yY]') {
            try {
                Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                $odCacheDir = Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive"
                if (Test-Path $odCacheDir) {
                    Remove-Item -Path $odCacheDir -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "OneDrive local cache cleared" -Level Success
                }
            } catch {
                Write-Log "Error clearing OneDrive — $($_.Exception.Message)" -Level Warn
            }
        }
    }
    Read-Host "  Press Enter after signing out of cloud accounts (or skip)"

    # ── Step 5: Remove saved WiFi passwords ──
    Write-Step "Step 5/9: Removing Saved WiFi Passwords"
    $confirm = Read-Host "  Delete all saved WiFi profiles? [y/N]"
    if ($confirm -match '^[yY]') {
        try {
            $wifiProfiles = & netsh wlan show profiles 2>$null |
                Select-String 'All User Profile\s*:\s*(.+)' |
                ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }
            foreach ($profile in $wifiProfiles) {
                & netsh wlan delete profile name="$profile" 2>$null | Out-Null
            }
            Write-Log "Deleted $($wifiProfiles.Count) WiFi profiles" -Level Success
        } catch {
            Write-Log "Error removing WiFi profiles — $($_.Exception.Message)" -Level Warn
        }
    }

    # ── Step 6: Clear Windows Credential Manager ──
    Write-Step "Step 6/9: Clearing Windows Credential Manager"
    $confirm = Read-Host "  Clear all saved credentials (Git tokens, app passwords, etc.)? [y/N]"
    if ($confirm -match '^[yY]') {
        try {
            # Clear generic credentials
            $creds = & cmdkey /list 2>$null | Select-String 'Target:\s*(.+)' | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }
            foreach ($cred in $creds) {
                & cmdkey /delete:"$cred" 2>$null | Out-Null
            }
            Write-Log "Cleared $($creds.Count) saved credentials" -Level Success
        } catch {
            Write-Log "Error clearing credentials — $($_.Exception.Message)" -Level Warn
        }
    }

    # ── Step 7: Remove SSH keys and Git config ──
    Write-Step "Step 7/9: Removing SSH Keys & Git Config"
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    if (Test-Path $sshDir) {
        $confirm = Read-Host "  Delete SSH keys ($sshDir)? [y/N]"
        if ($confirm -match '^[yY]') {
            try {
                Remove-Item -Path $sshDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "SSH keys deleted" -Level Success
            } catch {
                Write-Log "Error deleting SSH keys — $($_.Exception.Message)" -Level Warn
            }
        }
    }
    $gitConfig = Join-Path $env:USERPROFILE ".gitconfig"
    if (Test-Path $gitConfig) {
        $confirm = Read-Host "  Delete .gitconfig? [y/N]"
        if ($confirm -match '^[yY]') {
            Remove-Item -Path $gitConfig -Force -ErrorAction SilentlyContinue
            Write-Log ".gitconfig deleted" -Level Success
        }
    }

    # ── Step 8: Clear user environment variables ──
    Write-Step "Step 8/9: Clearing User Environment Variables"
    $confirm = Read-Host "  Remove all user environment variables (keeps system ones like PATH)? [y/N]"
    if ($confirm -match '^[yY]') {
        try {
            $envKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
            if ($envKey) {
                $names = @($envKey.GetValueNames())
                # Keep essential ones like PATH, TEMP, TMP
                $keepVars = @('PATH', 'TEMP', 'TMP', 'PATHEXT')
                foreach ($name in $names) {
                    if ($name -and $name -notin $keepVars) {
                        $envKey.DeleteValue($name, $false)
                        Write-Log "Removed env var: $name" -Level Info
                    }
                }
                $envKey.Close()
                Write-Log "User environment variables cleared (PATH, TEMP, TMP kept)" -Level Success
            }
        } catch {
            Write-Log "Error clearing env vars — $($_.Exception.Message)" -Level Warn
        }
    }

    # ── Step 9: Empty Recycle Bin ──
    Write-Step "Step 9/9: Emptying Recycle Bin"
    $confirm = Read-Host "  Empty the Recycle Bin (permanently delete trashed files)? [y/N]"
    if ($confirm -match '^[yY]') {
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Log "Recycle Bin emptied" -Level Success
        } catch {
            Write-Log "Error emptying Recycle Bin — $($_.Exception.Message)" -Level Warn
        }
    }

    # ── Done ──
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                   Cleanup Complete!                          ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Remaining manual steps:" -ForegroundColor Yellow
    Write-Host "    - Sign out of OneDrive, Teams, and other cloud apps" -ForegroundColor Yellow
    Write-Host "    - Deauthorize this device from online accounts:" -ForegroundColor Yellow
    Write-Host "        myaccount.google.com/device-activity" -ForegroundColor Gray
    Write-Host "        account.microsoft.com/devices" -ForegroundColor Gray
    Write-Host "        github.com/settings/sessions" -ForegroundColor Gray
    Write-Host "    - Remove this device from Find My Device (if enabled)" -ForegroundColor Yellow
    Write-Host "    - Consider Windows Reset if handing to someone else:" -ForegroundColor Yellow
    Write-Host "        Settings → System → Recovery → Reset this PC" -ForegroundColor Gray
    Write-Host ""
    Write-Log "Old laptop cleanup completed."
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 6C: ABOUT THIS TOOL
# ═══════════════════════════════════════════════════════════════════════════

function Show-AboutTool {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║         What is this tool? — Migrate-Laptop                 ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Created by gauravkhurana.com for the community" -ForegroundColor DarkCyan
    Write-Host "  Star the repo: github.com/gauravkhuraana/new-laptop-setup" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "  THE PROBLEM" -ForegroundColor Yellow
    Write-Host "  ───────────" -ForegroundColor Yellow
    Write-Host "  Getting a new laptop means:" -ForegroundColor White
    Write-Host "    - You forget what software you had installed" -ForegroundColor Gray
    Write-Host "    - You lose configs (Git, SSH, VS Code, env vars, terminal settings)" -ForegroundColor Gray
    Write-Host "    - You accidentally copy gigabytes of node_modules, .venv, build junk" -ForegroundColor Gray
    Write-Host "    - You spend days reinstalling everything from scratch" -ForegroundColor Gray
    Write-Host "    - Weeks later you realize you forgot something important" -ForegroundColor Gray
    Write-Host ""

    Write-Host "  THE SOLUTION" -ForegroundColor Green
    Write-Host "  ────────────" -ForegroundColor Green
    Write-Host "  This tool scans your OLD laptop and generates ready-to-run scripts" -ForegroundColor White
    Write-Host "  for your NEW one. You review everything, then run what you need." -ForegroundColor White
    Write-Host ""

    Write-Host "  WHAT IT CAN DO" -ForegroundColor Cyan
    Write-Host "  ──────────────" -ForegroundColor Cyan
    Write-Host "    [+] Detect all installed software (172+ apps on a typical dev machine)" -ForegroundColor White
    Write-Host "    [+] Generate winget install commands to reinstall everything" -ForegroundColor White
    Write-Host "    [+] Transfer data folders with smart exclusions (skip node_modules etc.)" -ForegroundColor White
    Write-Host "    [+] Capture .gitconfig, SSH key names, VS Code extensions" -ForegroundColor White
    Write-Host "    [+] Capture environment variables, PowerShell profile, Terminal settings" -ForegroundColor White
    Write-Host "    [+] Detect browser extensions (Chrome, Edge, Firefox)" -ForegroundColor White
    Write-Host "    [+] Detect Office add-ins (Outlook, Excel, Word, PowerPoint)" -ForegroundColor White
    Write-Host "    [+] Capture WiFi profiles, theme, wallpaper, mouse, keyboard settings" -ForegroundColor White
    Write-Host "    [+] Capture File Explorer preferences (show extensions, hidden files)" -ForegroundColor White
    Write-Host "    [+] Find portable/standalone software not in Program Files" -ForegroundColor White
    Write-Host "    [+] Generate an interactive HTML report with everything found" -ForegroundColor White
    Write-Host "    [+] Resume support — if interrupted, pick up where you left off" -ForegroundColor White
    Write-Host "    [+] Clean up old laptop when you're done (optional, with double confirm)" -ForegroundColor White
    Write-Host ""

    Write-Host "  WHAT IT CANNOT DO" -ForegroundColor Red
    Write-Host "  ─────────────────" -ForegroundColor Red
    Write-Host "    [-] Cannot migrate Windows itself (OS must be fresh on new laptop)" -ForegroundColor White
    Write-Host "    [-] Cannot transfer installed programs (they must be reinstalled)" -ForegroundColor White
    Write-Host "    [-] Cannot read SSH private key CONTENTS (only lists file names)" -ForegroundColor White
    Write-Host "    [-] Cannot export Outlook rules automatically (manual step required)" -ForegroundColor White
    Write-Host "    [-] Cannot transfer browser passwords (use browser sign-in sync)" -ForegroundColor White
    Write-Host "    [-] Cannot migrate license keys (note them down manually)" -ForegroundColor White
    Write-Host "    [-] Cannot transfer 2FA/Authenticator (set up on new device first)" -ForegroundColor White
    Write-Host "    [-] Cannot work on Mac (Windows PowerShell only — Mac tips included)" -ForegroundColor White
    Write-Host "    [-] Cannot migrate WSL distros automatically (export/import manually)" -ForegroundColor White
    Write-Host "    [-] Cannot transfer Docker volumes or database data (manual backup)" -ForegroundColor White
    Write-Host "    [-] Cannot migrate display/sound settings (hardware-dependent)" -ForegroundColor White
    Write-Host ""

    Read-Host "  Press Enter to see how it works..."

    Write-Host ""
    Write-Host "  HOW IT WORKS (step by step)" -ForegroundColor Cyan
    Write-Host "  ───────────────────────────" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Step 1: SCAN (on OLD laptop)" -ForegroundColor White
    Write-Host "    Run this tool, choose option [3] Scan & Prepare." -ForegroundColor Gray
    Write-Host "    It reads your laptop (never modifies anything) and generates:" -ForegroundColor Gray
    Write-Host "      - An HTML report (open in browser — interactive, searchable)" -ForegroundColor DarkGray
    Write-Host "      - Install-Software.ps1 (winget commands for all your apps)" -ForegroundColor DarkGray
    Write-Host "      - Transfer-Data.ps1 (robocopy commands for your data folders)" -ForegroundColor DarkGray
    Write-Host "      - Restore-Configs.ps1 (restores Git, VS Code, env vars, etc.)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Step 2: REVIEW" -ForegroundColor White
    Write-Host "    Open the HTML report. Check your software list." -ForegroundColor Gray
    Write-Host "    Open Install-Software.ps1 — comment out apps you don't need." -ForegroundColor Gray
    Write-Host "    Check Restore-Configs.ps1 for any secrets in env vars/.gitconfig." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Step 3: TRANSFER (pick what you need)" -ForegroundColor White
    Write-Host "    Copy the migration-output folder to the new laptop." -ForegroundColor Gray
    Write-Host "    Run scripts one at a time — each asks confirmation per item." -ForegroundColor Gray
    Write-Host "    You can run all three, or just one. They're independent." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Step 4: VERIFY" -ForegroundColor White
    Write-Host "    Run the post-migration checklist (option [6])." -ForegroundColor Gray
    Write-Host "    Tests Git, SSH, VS Code, Node, Python, bookmarks automatically." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Step 5: CLEAN UP (optional)" -ForegroundColor White
    Write-Host "    Once satisfied, clean the old laptop (option [7])." -ForegroundColor Gray
    Write-Host "    Requires typing 'I HAVE VERIFIED' and 'DELETE MY DATA'." -ForegroundColor Gray
    Write-Host ""

    Write-Host "  SAFETY GUARANTEES" -ForegroundColor Green
    Write-Host "  ─────────────────" -ForegroundColor Green
    Write-Host "    - This script never connects to the internet (zero network calls)" -ForegroundColor White
    Write-Host "      (Generated Install-Software.ps1 uses winget, which downloads from the internet)" -ForegroundColor DarkGray
    Write-Host "    - Never reads SSH private key contents" -ForegroundColor White
    Write-Host "    - Never reads browser passwords" -ForegroundColor White
    Write-Host "    - Never deletes or modifies files (except option [7] with double confirm)" -ForegroundColor White
    Write-Host "    - Automated security scans verify this on every code change" -ForegroundColor White
    Write-Host "    - Single .ps1 file — you can read the entire source code" -ForegroundColor White
    Write-Host ""

    Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  Created by gauravkhurana.com for the community" -ForegroundColor DarkCyan
    Write-Host "  Like this? Star the repo: github.com/gauravkhuraana/new-laptop-setup" -ForegroundColor DarkCyan
    Write-Host "  Connect: gauravkhurana.com/connect" -ForegroundColor DarkCyan
    Write-Host "  #SharingIsCaring" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "  Ready to start? Run this tool again and pick option [3] to scan." -ForegroundColor Yellow
    Write-Host "  Or pick option [2] if you prefer doing things manually." -ForegroundColor DarkGray
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 6D: MANUAL MIGRATION TIPS
# ═══════════════════════════════════════════════════════════════════════════

function Show-ManualTips {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║          Manual Laptop Migration — Tips & Checklist          ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Created by gauravkhurana.com for the community" -ForegroundColor DarkCyan
    Write-Host "  Star the repo: github.com/gauravkhuraana/new-laptop-setup" -ForegroundColor DarkCyan
    Write-Host "  Connect: gauravkhurana.com/connect" -ForegroundColor DarkCyan
    Write-Host ""

    # ── GENERAL TIPS (for everyone) ──
    Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "  │              GENERAL TIPS (for everyone)                  │" -ForegroundColor Green
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""
    Write-Host "  DO's:" -ForegroundColor Green
    Write-Host "    [+] Sign into Microsoft account on new laptop FIRST" -ForegroundColor White
    Write-Host "        WiFi passwords, theme, keyboard settings sync automatically" -ForegroundColor DarkGray
    Write-Host "    [+] Sign into browsers (Chrome/Edge/Firefox) to sync:" -ForegroundColor White
    Write-Host "        Bookmarks, passwords, extensions, history all come back" -ForegroundColor DarkGray
    Write-Host "    [+] Set up 2FA/Authenticator on NEW device BEFORE wiping old" -ForegroundColor White
    Write-Host "        Microsoft Authenticator, Google Authenticator, Authy" -ForegroundColor DarkGray
    Write-Host "        Transfer accounts or save backup codes first!" -ForegroundColor DarkGray
    Write-Host "    [+] Export Outlook rules BEFORE migration" -ForegroundColor White
    Write-Host "        File > Manage Rules & Alerts > Options > Export Rules" -ForegroundColor DarkGray
    Write-Host "    [+] Check your password manager is synced" -ForegroundColor White
    Write-Host "        Bitwarden, 1Password, KeePass, LastPass — sign in on new laptop" -ForegroundColor DarkGray
    Write-Host "        If using KeePass: copy your .kdbx database file manually" -ForegroundColor DarkGray
    Write-Host "    [+] Note down software license keys" -ForegroundColor White
    Write-Host "        Check email for purchase receipts or use tools like ProduKey" -ForegroundColor DarkGray
    Write-Host "    [+] Back up photos and videos to cloud or USB" -ForegroundColor White
    Write-Host "        OneDrive, Google Photos, or external drive" -ForegroundColor DarkGray
    Write-Host "    [+] Save VPN connection settings (screenshot or export)" -ForegroundColor White
    Write-Host "    [+] Note printer names and IPs for re-adding" -ForegroundColor White
    Write-Host ""
    Write-Host "  DON'Ts:" -ForegroundColor Red
    Write-Host "    [-] Don't copy the entire C: drive" -ForegroundColor White
    Write-Host "        Windows, drivers, and system files won't work on different hardware" -ForegroundColor DarkGray
    Write-Host "    [-] Don't copy Program Files — reinstall apps fresh" -ForegroundColor White
    Write-Host "        Use winget: winget install Git.Git Google.Chrome etc." -ForegroundColor DarkGray
    Write-Host "    [-] Don't copy node_modules, .venv, target, bin/obj folders" -ForegroundColor White
    Write-Host "        Rebuild with: npm install, pip install, mvn install, dotnet restore" -ForegroundColor DarkGray
    Write-Host "    [-] Don't format old laptop until new one is fully verified" -ForegroundColor White
    Write-Host "        Keep it for at least 2 weeks as backup" -ForegroundColor DarkGray
    Write-Host "    [-] Don't transfer SSH keys over WiFi or email" -ForegroundColor White
    Write-Host "        Use USB drive only — they are your most sensitive files" -ForegroundColor DarkGray
    Write-Host "    [-] Don't skip 2FA setup on new device" -ForegroundColor White
    Write-Host "        You'll get locked out of accounts if old device is wiped" -ForegroundColor DarkGray
    Write-Host ""

    Read-Host "  Press Enter for app-specific tips..."

    # ── APP-SPECIFIC TIPS ──
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
    Write-Host "  │            APP-SPECIFIC MIGRATION TIPS                    │" -ForegroundColor Yellow
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Outlook:" -ForegroundColor Cyan
    Write-Host "    - Rules: File > Manage Rules & Alerts > Options > Export Rules (.rwz)" -ForegroundColor Gray
    Write-Host "    - Signatures: Copy from %APPDATA%\Microsoft\Signatures" -ForegroundColor Gray
    Write-Host "    - Stationery: Sign into Outlook on new laptop — most settings sync" -ForegroundColor Gray
    Write-Host "    - If using Outlook desktop (not 365): export PST file via File > Export" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  VS Code:" -ForegroundColor Cyan
    Write-Host "    - BEST: Enable Settings Sync (Ctrl+Shift+P > Settings Sync: Turn On)" -ForegroundColor Gray
    Write-Host "      Syncs settings, keybindings, extensions, snippets, UI state" -ForegroundColor DarkGray
    Write-Host "    - Manual: Copy %APPDATA%\Code\User\settings.json to new machine" -ForegroundColor Gray
    Write-Host "    - Extensions: code --list-extensions > extensions.txt (then install loop)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Browser Extensions:" -ForegroundColor Cyan
    Write-Host "    - Chrome: Sign in with Google account — extensions sync automatically" -ForegroundColor Gray
    Write-Host "    - Edge: Sign in with Microsoft account — extensions sync automatically" -ForegroundColor Gray
    Write-Host "    - Firefox: Sign in with Firefox account — add-ons sync automatically" -ForegroundColor Gray
    Write-Host "    - Passwords: All 3 browsers sync passwords when signed in" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Password Managers:" -ForegroundColor Cyan
    Write-Host "    - Bitwarden/1Password/LastPass: Install app, sign in — vault syncs" -ForegroundColor Gray
    Write-Host "    - KeePass: Copy .kdbx file via USB, install KeePass, open the file" -ForegroundColor Gray
    Write-Host "    - Browser saved passwords: Sync via browser sign-in (see above)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2FA / Authenticator Apps:" -ForegroundColor Cyan
    Write-Host "    - Microsoft Authenticator: Back up in app (Settings > Backup)" -ForegroundColor Gray
    Write-Host "      Then restore on new device by signing into same Microsoft account" -ForegroundColor DarkGray
    Write-Host "    - Google Authenticator: Transfer accounts (hamburger menu > Transfer)" -ForegroundColor Gray
    Write-Host "      Scan QR code on new phone — do this BEFORE wiping old device!" -ForegroundColor DarkGray
    Write-Host "    - Authy: Multi-device — install on new device, accounts appear" -ForegroundColor Gray
    Write-Host "    - ALWAYS save backup codes when setting up 2FA on any service" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Video Editors (Filmora, Premiere, DaVinci, OBS):" -ForegroundColor Cyan
    Write-Host "    - Export presets/profiles before migration" -ForegroundColor Gray
    Write-Host "    - Copy project files, NOT the program (reinstall fresh)" -ForegroundColor Gray
    Write-Host "    - OBS: Copy %APPDATA%\obs-studio for scenes, profiles, settings" -ForegroundColor Gray
    Write-Host "    - DaVinci Resolve: Export project archive (File > Export Project Archive)" -ForegroundColor Gray
    Write-Host "    - Filmora: Copy project files (.wfp), reinstall the app" -ForegroundColor Gray
    Write-Host ""

    Read-Host "  Press Enter for developer-specific tips..."

    # ── DEVELOPER TIPS ──
    Write-Host ""
    Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Blue
    Write-Host "  │              DEVELOPER-SPECIFIC TIPS                      │" -ForegroundColor Blue
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  Git & SSH:" -ForegroundColor Cyan
    Write-Host "    - Copy .gitconfig to new laptop: %USERPROFILE%\.gitconfig" -ForegroundColor Gray
    Write-Host "    - SSH keys: Copy .ssh/ folder via USB drive (NEVER over network)" -ForegroundColor Gray
    Write-Host "    - Fix SSH key permissions on new machine:" -ForegroundColor Gray
    Write-Host "      icacls `"%USERPROFILE%\.ssh\id_*`" /inheritance:r /grant:r `"%USERNAME%:(R)`"" -ForegroundColor DarkGray
    Write-Host "    - Test: ssh -T git@github.com" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Node.js / npm:" -ForegroundColor Cyan
    Write-Host "    - Install Node via winget: winget install OpenJS.NodeJS.LTS" -ForegroundColor Gray
    Write-Host "    - Global packages: npm list -g --depth=0 (note them, reinstall)" -ForegroundColor Gray
    Write-Host "    - Per-project: just run npm install (node_modules rebuilds)" -ForegroundColor Gray
    Write-Host "    - npm cache dir: Can set via npm config set cache D:\npm-cache" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Python / pip:" -ForegroundColor Cyan
    Write-Host "    - Install Python via winget: winget install Python.Python.3.12" -ForegroundColor Gray
    Write-Host "    - User packages: pip list --user (note them, reinstall)" -ForegroundColor Gray
    Write-Host "    - Per-project: pip install -r requirements.txt" -ForegroundColor Gray
    Write-Host "    - Virtual environments: Never copy .venv — recreate fresh" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Java / Maven:" -ForegroundColor Cyan
    Write-Host "    - Install JDK: winget install EclipseAdoptium.Temurin.21.JDK" -ForegroundColor Gray
    Write-Host "    - Set JAVA_HOME environment variable" -ForegroundColor Gray
    Write-Host "    - Maven: winget install Apache.Maven" -ForegroundColor Gray
    Write-Host "    - Per-project: mvn clean install (downloads dependencies)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  .NET:" -ForegroundColor Cyan
    Write-Host "    - Install SDK: winget install Microsoft.DotNet.SDK.8" -ForegroundColor Gray
    Write-Host "    - Per-project: dotnet restore" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Docker:" -ForegroundColor Cyan
    Write-Host "    - Install: winget install Docker.DockerDesktop" -ForegroundColor Gray
    Write-Host "    - Images DON'T transfer — pull them again (docker pull)" -ForegroundColor Gray
    Write-Host "    - Volumes: Export important data first (docker cp or volume backup)" -ForegroundColor Gray
    Write-Host "    - docker-compose.yml files: These ARE your project files — just copy" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Environment Variables:" -ForegroundColor Cyan
    Write-Host "    - Check current: [Environment]::GetEnvironmentVariables('User')" -ForegroundColor Gray
    Write-Host "    - Common ones: JAVA_HOME, MAVEN_HOME, GOPATH, ANDROID_HOME" -ForegroundColor Gray
    Write-Host "    - Set: [Environment]::SetEnvironmentVariable('NAME','VALUE','User')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  WSL (Windows Subsystem for Linux):" -ForegroundColor Cyan
    Write-Host "    - Export: wsl --export Ubuntu ubuntu-backup.tar" -ForegroundColor Gray
    Write-Host "    - Import on new machine: wsl --import Ubuntu C:\WSL\ ubuntu-backup.tar" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Terminal / PowerShell:" -ForegroundColor Cyan
    Write-Host "    - PowerShell profile: Copy `$PROFILE to new machine" -ForegroundColor Gray
    Write-Host "    - Windows Terminal: Settings sync via Microsoft account" -ForegroundColor Gray
    Write-Host "    - Oh My Posh / Starship: Install theme engine, copy config" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Databases (if running locally):" -ForegroundColor Cyan
    Write-Host "    - PostgreSQL: pg_dump dbname > backup.sql" -ForegroundColor Gray
    Write-Host "    - MySQL: mysqldump dbname > backup.sql" -ForegroundColor Gray
    Write-Host "    - MongoDB: mongodump --out backup/" -ForegroundColor Gray
    Write-Host "    - SQLite: Copy .db file directly" -ForegroundColor Gray
    Write-Host "    - Redis: Copy dump.rdb" -ForegroundColor Gray
    Write-Host ""

    # ── BEFORE YOU FORMAT CHECKLIST ──
    Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Red
    Write-Host "  │          BEFORE YOU FORMAT — FINAL CHECKLIST              │" -ForegroundColor Red
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Verify ALL of these on the NEW laptop before touching the old one:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    [ ] 2FA / Authenticator set up on new device" -ForegroundColor White
    Write-Host "    [ ] Password manager accessible on new laptop" -ForegroundColor White
    Write-Host "    [ ] Browser bookmarks & passwords visible" -ForegroundColor White
    Write-Host "    [ ] Browser extensions installed (check after sign-in)" -ForegroundColor White
    Write-Host "    [ ] Email working (Outlook / Gmail)" -ForegroundColor White
    Write-Host "    [ ] OneDrive / cloud files syncing" -ForegroundColor White
    Write-Host "    [ ] VPN connection works" -ForegroundColor White
    Write-Host "    [ ] Printers configured" -ForegroundColor White
    Write-Host "    [ ] Chat apps working (Teams, Slack, Zoom)" -ForegroundColor White
    Write-Host "    [ ] Git works (git config, SSH keys, clone a repo)" -ForegroundColor White
    Write-Host "    [ ] Projects build successfully" -ForegroundColor White
    Write-Host "    [ ] IDE / editor settings look right" -ForegroundColor White
    Write-Host "    [ ] Documents & important files accessible" -ForegroundColor White
    Write-Host "    [ ] Outlook rules imported" -ForegroundColor White
    Write-Host "    [ ] Video editor projects openable" -ForegroundColor White
    Write-Host "    [ ] License keys activated on new machine" -ForegroundColor White
    Write-Host ""
    Write-Host "  Wait at least 1-2 weeks before formatting the old laptop." -ForegroundColor Yellow
    Write-Host "  You always discover something you forgot after a few days." -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  Created by gauravkhurana.com for the community" -ForegroundColor DarkCyan
    Write-Host "  Like this? Star the repo & share: github.com/gauravkhuraana/new-laptop-setup" -ForegroundColor DarkCyan
    Write-Host "  Connect: gauravkhurana.com/connect" -ForegroundColor DarkCyan
    Write-Host "  #SharingIsCaring" -ForegroundColor DarkCyan
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 7: MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

Write-Log "Migrate-Laptop started — Mode: $($script:ChosenMode)"
Write-Log "Output directory: $OutputDir"

# ── Mode: About ──
if ($script:ChosenMode -eq 'about') {
    Show-AboutTool
    exit 0
}

# ── Mode: Checklist ──
if ($script:ChosenMode -eq 'checklist') {
    Show-PostMigrationChecklist
    Write-Log "Post-migration checklist completed."
    exit 0
}

# ── Mode: Tips ──
if ($script:ChosenMode -eq 'tips') {
    Show-ManualTips
    exit 0
}

# ── Mode: Cleanup ──
if ($script:ChosenMode -eq 'cleanup') {
    Start-OldLaptopCleanup
    exit 0
}

# ── Mode: Generate from cache ──
if ($script:ChosenMode -eq 'generate') {
    if (-not $CacheFile) {
        # Find most recent cache
        $caches = @(Get-ChildItem -Path $OutputDir -Filter "scan-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($caches.Count -gt 0) {
            Write-Log "Found cached scan: $($caches[0].Name)"
            $confirm = Read-Host "  Use $($caches[0].Name)? [Y/n]"
            if ($confirm -match '^[nN]') {
                $CacheFile = Read-Host "  Enter path to scan JSON file"
            } else {
                $CacheFile = $caches[0].FullName
            }
        } else {
            $CacheFile = Read-Host "  No cached scans found. Enter path to scan JSON file"
        }
    }
    $scanData = Load-ScanCache -CachePath $CacheFile
    if (-not $scanData) { Write-Log "Failed to load cache. Exiting." -Level Error; exit 1 }

    Write-Step "Generating Scripts from Cached Scan"
    Write-InstallScript   -ScriptPath (Join-Path $OutputDir "Install-Software.ps1") -ScanData $scanData
    Write-TransferScript  -ScriptPath (Join-Path $OutputDir "Transfer-Data.ps1")    -ScanData $scanData
    Write-RestoreConfigsScript -ScriptPath (Join-Path $OutputDir "Restore-Configs.ps1") -ScanData $scanData
    Write-AiReviewFile    -FilePath   (Join-Path $OutputDir "migration-for-ai-review.md") -ScanData $scanData

    Write-Host ""
    Write-Host "  ✓ Scripts generated in: $OutputDir" -ForegroundColor Green
    Write-Host "  Review each script before running on the new laptop." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ── Mode: Scan (or Full) ──
Write-Step "Phase 1: Scanning This Laptop"

# Load System.Web for HTML encoding
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

$drives       = Get-DriveInfo
$userFolders  = Get-UserProfileFolders
$customFolders = Get-CustomDataFolders
$softwareResult = Get-InstalledSoftware
$software     = @($softwareResult.Software)
$portableApps = @($softwareResult.PortableApps)
$configs      = Get-UserConfigs

# Build scan data object
$scanData = @{
    ScanDate      = $script:RunDate
    ScanTimestamp  = $script:RunTimestamp
    ComputerName  = $env:COMPUTERNAME
    UserName      = $env:USERNAME
    OSVersion     = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
    Drives        = $drives
    UserFolders   = $userFolders
    CustomFolders = $customFolders
    Software      = $software
    PortableApps  = $portableApps
    Configs       = $configs
}

# Save cache and reload to normalize hashtables → PSCustomObject for report functions
$cachePath = Join-Path $OutputDir "scan-$($script:RunDate).json"
Save-ScanCache -CachePath $cachePath -ScanData $scanData
$scanData = Load-ScanCache -CachePath $cachePath

# Generate reports
Write-Step "Generating Reports"
$mdPath   = Join-Path $OutputDir "scan-report-$($script:RunDate).md"
$htmlPath = Join-Path $OutputDir "scan-report-$($script:RunDate).html"
Write-MarkdownReport -ReportPath $mdPath   -ScanData $scanData
Write-HtmlReport     -ReportPath $htmlPath -ScanData $scanData

Write-Host ""
Write-Host "  ✓ Scan complete!" -ForegroundColor Green
Write-Host "    JSON cache:  $cachePath" -ForegroundColor Gray
Write-Host "    MD report:   $mdPath" -ForegroundColor Gray
Write-Host "    HTML report: $htmlPath" -ForegroundColor Gray
Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
Write-Host "  │  ⚠  SENSITIVE DATA NOTICE                               │" -ForegroundColor Yellow
Write-Host "  ├──────────────────────────────────────────────────────────┤" -ForegroundColor Yellow
Write-Host "  │  The scan results may contain sensitive information:     │" -ForegroundColor Yellow
Write-Host "  │    • Environment variables (could have API keys/tokens)  │" -ForegroundColor Yellow
Write-Host "  │    • .gitconfig (could have credential helpers/tokens)   │" -ForegroundColor Yellow
Write-Host "  │    • PowerShell profile (could have secrets)             │" -ForegroundColor Yellow
Write-Host "  │    • WiFi network names                                 │" -ForegroundColor Yellow
Write-Host "  │                                                          │" -ForegroundColor Yellow
Write-Host "  │  Review generated scripts before sharing or uploading.   │" -ForegroundColor Yellow
Write-Host "  │  Never commit migration-output/ to a public Git repo.    │" -ForegroundColor Yellow
Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""

# ── Scan-only stops here ──
if ($script:ChosenMode -eq 'scan') {
    Write-Host "  Scan-only mode — review the reports, then re-run to generate scripts." -ForegroundColor Yellow
    Write-Host "  Use: .\Migrate-Laptop.ps1 -FromCache" -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Scan-only mode completed."
    exit 0
}

# ── Full mode: also generate scripts ──
Write-Step "Phase 2: Generating Migration Scripts"
Write-InstallScript        -ScriptPath (Join-Path $OutputDir "Install-Software.ps1")  -ScanData $scanData
Write-TransferScript       -ScriptPath (Join-Path $OutputDir "Transfer-Data.ps1")     -ScanData $scanData
Write-RestoreConfigsScript -ScriptPath (Join-Path $OutputDir "Restore-Configs.ps1")   -ScanData $scanData
Write-AiReviewFile         -FilePath   (Join-Path $OutputDir "migration-for-ai-review.md") -ScanData $scanData

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║               Scan Complete — Scripts Ready!                 ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Nothing was installed, copied, or deleted. You are in control." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Generated files in: $OutputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "  📋 STEP A: Review the reports" -ForegroundColor White
Write-Host "     Open scan-report-$($script:RunDate).html in your browser" -ForegroundColor Gray
Write-Host "     Check the software list, configs, and data folders" -ForegroundColor Gray
Write-Host ""
Write-Host "  📦 STEP B: Run scripts one at a time (you choose which ones)" -ForegroundColor White
Write-Host ""
Write-Host "     B1. Install-Software.ps1  — Install apps via winget" -ForegroundColor Gray
Write-Host "         Run on NEW laptop. Each app asks for confirmation." -ForegroundColor DarkGray
Write-Host "         You can skip this if you just want to transfer data." -ForegroundColor DarkGray
Write-Host ""
Write-Host "     B2. Transfer-Data.ps1     — Copy your data folders" -ForegroundColor Gray
Write-Host "         Run on OLD laptop. Each folder asks for confirmation." -ForegroundColor DarkGray
Write-Host "         You can skip this if you only want to install software." -ForegroundColor DarkGray
Write-Host ""
Write-Host "     B3. Restore-Configs.ps1   — Restore Git, VS Code, env vars" -ForegroundColor Gray
Write-Host "         Run on NEW laptop. Each config asks for confirmation." -ForegroundColor DarkGray
Write-Host "         You can skip this if you prefer manual setup." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  ✅ STEP C: Verify everything works" -ForegroundColor White
Write-Host "     Run: .\Migrate-Laptop.ps1 → choose [4] Post-Migration Checklist" -ForegroundColor Gray
Write-Host ""
Write-Host "  🤖 OPTIONAL: Paste migration-for-ai-review.md into ChatGPT/Copilot" -ForegroundColor White
Write-Host "     for personalized advice on your setup" -ForegroundColor Gray
Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
Write-Host "  │  ⚠  BEFORE YOU SHARE OR TRANSFER                        │" -ForegroundColor Yellow
Write-Host "  ├──────────────────────────────────────────────────────────┤" -ForegroundColor Yellow
Write-Host "  │  Restore-Configs.ps1 contains your actual configs:       │" -ForegroundColor Yellow
Write-Host "  │    • .gitconfig content (check for tokens)               │" -ForegroundColor Yellow
Write-Host "  │    • Environment variable values (check for API keys)    │" -ForegroundColor Yellow
Write-Host "  │    • PowerShell profile (check for secrets)              │" -ForegroundColor Yellow
Write-Host "  │                                                          │" -ForegroundColor Yellow
Write-Host "  │  Open Restore-Configs.ps1 and remove any secrets before  │" -ForegroundColor Yellow
Write-Host "  │  transferring to the new laptop.                         │" -ForegroundColor Yellow
Write-Host "  │  Never commit migration-output/ to a public Git repo.    │" -ForegroundColor Yellow
Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ──────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
Write-Host "  Created by gauravkhurana.com for the community" -ForegroundColor DarkCyan
Write-Host "  Like this tool? Star the repo: github.com/gauravkhuraana/new-laptop-setup" -ForegroundColor DarkCyan
Write-Host "  Connect: gauravkhurana.com/connect" -ForegroundColor DarkCyan
Write-Host "  #SharingIsCaring" -ForegroundColor DarkCyan
Write-Host ""

Write-Log "Full migration scan and script generation completed successfully."
