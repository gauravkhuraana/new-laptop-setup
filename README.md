# Migrate-Laptop

**One script. Zero dependencies. Migrates your Windows laptop in minutes.**

Run it on your old laptop → it scans everything → generates ready-to-run scripts → you run them on the new laptop. Done.

---

## What It Does

1. **Scans** your old laptop — installed software, configs, data folders, settings
2. **Generates** scripts and reports you can review before running
3. **You run** the scripts on your new laptop to install apps and transfer data

Nothing is deleted or modified on your old laptop. Every script asks before doing anything.

---

## Quick Start (3 minutes)

### 1. Download

```powershell
# Option A: Clone
git clone https://github.com/gauravkhuraana/new-laptop-setup.git
cd new-laptop-setup

# Option B: Download just the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gauravkhuraana/new-laptop-setup/main/Migrate-Laptop.ps1" -OutFile "Migrate-Laptop.ps1"
```

### 2. Run on your OLD laptop

```powershell
.\Migrate-Laptop.ps1
```

A menu appears — pick **[3] Scan & Prepare**. It takes 1–2 minutes.

### 3. Copy `migration-output/` to your new laptop

Use USB drive, network share, or cloud sync.

### 4. Run the scripts on your NEW laptop

```powershell
# Install your apps (via winget)
.\Install-Software.ps1

# Transfer your data (Documents, Projects, etc.)
.\Transfer-Data.ps1

# Verify nothing was missed
.\Verify-Transfer.ps1
```

### 5. Follow the Restoration Guide

Open the HTML report (`scan-report-*.html`) → click the **Restoration Guide** tab. It has copy-paste commands for Git config, VS Code extensions, env variables, npm/pip packages, and more.

---

## What Gets Generated

After scanning, a `migration-output/` folder is created with:

| File | What it does | Run where? |
|------|-------------|------------|
| `Install-Software.ps1` | Installs apps via winget (edit to skip any) | New laptop |
| `Transfer-Data.ps1` | Copies data folders with smart exclusions | Old laptop |
| `Verify-Transfer.ps1` | Compares source vs destination after transfer | Old laptop |
| `scan-report-*.html` | Interactive report — software, configs, data, restoration guide | Open in browser |
| `scan-report-*.md` | Same report in Markdown | Any editor |
| `migration-for-ai-review.md` | Paste into ChatGPT/Copilot for personalized migration advice | AI assistant |
| `scan-*.json` | Raw scan data (re-generate scripts without re-scanning) | N/A |

> **No secrets are stored** in any generated file. Environment variable names are listed but values are not.

---

## What It Scans

| Category | What's detected |
|----------|----------------|
| **Software** | All installed apps, categorized as Developer / General / Other with winget IDs |
| **Git** | `.gitconfig` (user name, email), SSH key file names |
| **VS Code** | Extensions list, settings path, Insiders extensions |
| **Dev tools** | npm global packages, pip packages, PowerShell profile |
| **Windows settings** | WiFi profiles, theme, wallpaper, mouse, keyboard, display, power, sound |
| **Data folders** | User profile (Desktop, Documents, etc.) + custom folders on all drives |
| **Other** | Printers, mapped drives, WSL distros, startup programs, Chocolatey/Scoop packages, custom fonts, Outlook signatures, Docker images/volumes, Credential Manager count, hosts file, scheduled tasks, browser bookmarks |

---

## Resume Support

If any script is interrupted (network drop, laptop sleeps, you close the window), just re-run it. Completed steps are saved in a `*-progress.json` file and automatically skipped. To start fresh, delete the progress file.

---

## Transfer Methods

| Method | How |
|--------|-----|
| **USB drive** | Copy `migration-output/` to USB → plug into new laptop |
| **Network share** | On new laptop: create & share a folder. On old laptop: run `Transfer-Data.ps1` → enter `\\NEW-PC\ShareName` |
| **Cloud** | Copy into OneDrive/Google Drive/Dropbox → download on new laptop |

---

## Smart Exclusions

Transfer-Data.ps1 automatically skips files/folders you should never copy:

- **Dependencies**: `node_modules`, `.venv`, `packages`, `.nuget`, `__pycache__`, `.gradle`, `.m2`
- **Build output**: `dist`, `build`, `target`, `bin`, `obj`
- **IDE caches**: `.vs`, `.idea`, `.angular`, `CachedData`
- **VCS**: `.git`, `.svn`, `.hg`
- **System junk**: `$RECYCLE.BIN`, `System Volume Information`, `Thumbs.db`, `desktop.ini`
- **OneDrive folders**: Skipped (they sync automatically)

After transferring projects, rebuild dependencies fresh: `npm install`, `pip install -r requirements.txt`, etc.

---

## Command Line Options

```powershell
.\Migrate-Laptop.ps1                    # Interactive wizard (recommended)
.\Migrate-Laptop.ps1 -ScanOnly          # Reports only, no scripts
.\Migrate-Laptop.ps1 -FromCache         # Generate scripts from previous scan
.\Migrate-Laptop.ps1 -OutputDir "D:\out" # Custom output folder
```

---

## Requirements

- **Windows 10 or 11**
- **PowerShell 5.1+** (built-in) or PowerShell 7
- **winget** (built into Windows 10/11 — used by Install-Software.ps1)
- No admin rights needed for scanning. Admin needed only for hosts file restore.

---

## FAQ

<details><summary><strong>Is it safe? Will it delete anything?</strong></summary>

The scan is **read-only** — it never deletes, modifies, or moves files on your old laptop. Generated scripts on the new laptop ask permission before every step. The only destructive option is **[7] Clean Up Old Laptop**, which requires typing two confirmation phrases.
</details>

<details><summary><strong>Does it work on Mac or Linux?</strong></summary>

No — it's Windows-only (PowerShell + winget + robocopy). For Mac, use the same approach manually: list your apps, use Homebrew to reinstall, and copy your data.
</details>

<details><summary><strong>What if winget doesn't recognize one of my apps?</strong></summary>

Apps without a winget ID show up in the "Other" section of the report (commented out in the install script). Install those manually. You can search winget: `winget search "app name"`.
</details>

<details><summary><strong>What if the script gets interrupted (network drop, laptop sleeps)?</strong></summary>

Just re-run it. Each script tracks progress in a `*-progress.json` file. Completed steps are automatically skipped. Delete the progress file to start over.
</details>

<details><summary><strong>Can I re-run the scan?</strong></summary>

Yes. Run `.\Migrate-Laptop.ps1` again and pick [3] or [4]. It overwrites the previous scan for the same date.
</details>

<details><summary><strong>Can I generate scripts without re-scanning?</strong></summary>

Yes — run `.\Migrate-Laptop.ps1 -FromCache`. It uses the saved JSON from your last scan.
</details>

<details><summary><strong>Does it work with multiple drives (D:, E:, etc)?</strong></summary>

Yes. It scans all drives and includes custom folders from each in the transfer script.
</details>

<details><summary><strong>What about WSL (Windows Subsystem for Linux)?</strong></summary>

WSL distros are detected and listed in the report but not migrated automatically. Export manually:
```powershell
wsl --export Ubuntu ubuntu-backup.tar          # On old laptop
wsl --import Ubuntu C:\WSL\ ubuntu-backup.tar  # On new laptop
```
</details>

<details><summary><strong>Do I need admin rights?</strong></summary>

No — scanning works without admin. `Install-Software.ps1` works best with admin rights (some winget installs need it). Hosts file restore requires admin.
</details>

<details><summary><strong>WiFi profiles were already restored when I signed in — do I need the scan?</strong></summary>

On corporate/domain-joined laptops, MDM-pushed WiFi profiles restore automatically. The scan is informational — it lists your saved networks so you can manually reconnect any personal ones (home, hotspot) that didn't auto-restore.
</details>

<details><summary><strong>How does it handle browser bookmarks and passwords?</strong></summary>

It detects browser profiles but does NOT export passwords. Sign into Chrome/Edge/Firefox on your new laptop — bookmarks, passwords, and extensions sync automatically via your browser account.
</details>

<details><summary><strong>What about VS Code settings and extensions?</strong></summary>

The report lists all your extensions with install commands. But the easiest way is **Settings Sync**: press `Ctrl+Shift+P` → "Settings Sync: Turn On" → sign in with GitHub or Microsoft. Extensions + settings restore automatically.
</details>

<details><summary><strong>What about Docker?</strong></summary>

Docker images and volumes are listed in the report. Images can be re-pulled (`docker pull`). Volumes with important data should be exported manually before wiping the old laptop: `docker run --rm -v myvolume:/data -v $(pwd):/backup busybox tar czf /backup/myvolume.tar.gz /data`.
</details>

<details><summary><strong>What about Git repos / source code?</strong></summary>

Your project folders are transferred via `Transfer-Data.ps1`. The `.git` folder is excluded by default (large, easily re-cloned). After transfer, just `git clone` your repos again or remove `.git` from the exclusion list in the script if you want to keep local history.
</details>

<details><summary><strong>How do I skip an app in Install-Software.ps1?</strong></summary>

Open the file in any editor. Each app is one line. Add `#` at the start to skip it:
```powershell
    # 'Docker Desktop'            = 'Docker.DockerDesktop'      # ← skipped
```
</details>

<details><summary><strong>What's the "Clean Up Old Laptop" option?</strong></summary>

Option [7] in the main menu. It deletes personal data (Desktop, Documents, browser profiles, WiFi passwords, SSH keys, etc.) from your old laptop. Requires typing `I HAVE VERIFIED` and `DELETE MY DATA`. Each step also asks individually. It does NOT touch Windows, installed programs, or your domain login.
</details>

<details><summary><strong>Can I use this in a corporate/enterprise environment?</strong></summary>

Yes. It's a single local PowerShell script with zero dependencies — no internet access, no telemetry, no external services. IT teams can review the source code (single file, ~4300 lines). See [SECURITY.md](SECURITY.md) for the security policy.
</details>

---

## Reporting a Bug

Found an issue? [Open a GitHub issue](https://github.com/gauravkhuraana/new-laptop-setup/issues/new) with the info below.

### What to include

**1. What happened**
- Which step/option you chose
- What you expected vs what actually happened

**2. Error screenshot**
- Screenshot of the PowerShell window showing the error (red text)

**3. PowerShell version** — run this and paste the output:
```powershell
$PSVersionTable | Format-List PSVersion, PSEdition, OS
```

**4. Windows version** — run this and paste the output:
```powershell
[System.Environment]::OSVersion.Version.ToString() + " " + (Get-CimInstance Win32_OperatingSystem).Caption
```

**5. Log files** — attach these from your `migration-output/` folder:

| File | When to attach |
|------|---------------|
| `migration-log-*.txt` | Always — this is the main scan log |
| `transfer-log.txt` | If transfer failed |
| `*-progress.json` | If a script stopped mid-way |
| `scan-*.json` | If the report looks wrong |

### Before sharing logs

Scan the log files for personal info. The logs may contain:
- Folder names and file paths
- Software names from your machine
- Environment variable names (not values)

Redact anything you're not comfortable sharing publicly. Or email them privately — see contact below.

### Quick debug command

Run this to collect all debug info into one file you can attach:

```powershell
$debugFile = "migration-debug-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt"
"=== PowerShell ===" | Out-File $debugFile
$PSVersionTable | Format-List | Out-File $debugFile -Append
"=== Windows ===" | Out-File $debugFile -Append
Get-CimInstance Win32_OperatingSystem | Format-List Caption, Version, BuildNumber | Out-File $debugFile -Append
"=== Winget ===" | Out-File $debugFile -Append
try { winget --version 2>&1 | Out-File $debugFile -Append } catch { "winget not found" | Out-File $debugFile -Append }
"=== Execution Policy ===" | Out-File $debugFile -Append
Get-ExecutionPolicy -List | Out-File $debugFile -Append
Write-Host "Debug info saved to: $debugFile" -ForegroundColor Green
```

Attach the generated file to your issue.

---

## Disclaimer

> **Use at your own risk.** While every precaution has been taken to make this tool safe and reliable, I am not responsible for any data loss, corruption, or unintended consequences. Always **back up your data independently** before running any migration. Verify everything works before wiping your old laptop.

---

Created by [gauravkhurana.com](https://gauravkhurana.com) for the community.
Like this? [Star the repo](https://github.com/gauravkhuraana/new-laptop-setup) | [Connect](https://gauravkhurana.com/connect) | **#SharingIsCaring**
