# Migrate-Laptop

**One script. Zero dependencies. Migrates your Windows laptop in minutes.**

Run it on your old laptop → it scans everything → generates ready-to-run scripts → you run them on the old/new laptop as guided. Done.

> **Fast transfer by default:** For repos and projects, the transfer script skips heavy re-creatable folders (like `node_modules`, `.git`, and build caches) so copy is much faster.
> **You control installs:** Your detected software is listed in `Install-Software.ps1`, and you can choose exactly what to install by keeping or commenting lines.

## Click the image to watch the video
[![Watch the video](https://img.youtube.com/vi/7ngPI9bEE8U/maxresdefault.jpg)](https://youtu.be/7ngPI9bEE8U)
---

## What It Does

1. **Scans** your old laptop — installed software, configs, data folders, settings
2. **Generates** scripts and reports you can review before running
3. **You run** the generated scripts on the correct laptop: install on NEW laptop, transfer/verify on OLD laptop

Nothing is deleted or modified on your old laptop. Every script asks before doing anything.

> **First time?** Check the [Pre-Migration Checklist](#before-you-start-on-old-laptop) before running — make sure cloud sync is finished, SSH keys are backed up, and 2FA is set up.

---

## Quick Start (3 minutes)

### 1. Download

You only need one file: **Migrate-Laptop.ps1**. Pick whichever method is easiest for you.

**Option A: Download directly from GitHub (easiest)**

1. Create a folder on your desktop or any drive, e.g. `C:\Migration`
2. Go to [**Migrate-Laptop.ps1**](https://github.com/gauravkhuraana/new-laptop-setup/blob/main/Migrate-Laptop.ps1)
3. Click the **Download raw file** button (↓ icon, top-right of the file)
4. Save it into your `C:\Migration` folder

**Option B: Download using PowerShell**

Open PowerShell and run:

```powershell
mkdir C:\Migration -ErrorAction SilentlyContinue
cd C:\Migration
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gauravkhuraana/new-laptop-setup/main/Migrate-Laptop.ps1" -OutFile "Migrate-Laptop.ps1"
```

**Option C: Clone the repo (if you have Git installed)**

```bash
git clone https://github.com/gauravkhuraana/new-laptop-setup.git
cd new-laptop-setup
```

> **Tip:** Keep everything in one folder. The script creates a `migration-output/` subfolder with all your reports and generated scripts.

### 2. Run on your OLD laptop

1. Open the folder where you saved `Migrate-Laptop.ps1`
2. **Right-click** an empty area in the folder → **Open in Terminal** (Windows 11) or **Open PowerShell window here** (Windows 10)
3. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1
```

> **Why `powershell -ExecutionPolicy Bypass`?** Windows blocks downloaded scripts on some systems by default. This allows the script to run for this one session only — it does not change any system settings. See [Troubleshooting](#troubleshooting) for alternatives.
>
> **Works with both** Windows PowerShell 5.1 (built-in) and PowerShell 7. If you prefer PowerShell 7, you can also run: `pwsh -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1`.

A menu appears — **pick [3] to get started**. It takes 1–2 minutes.

| Option | What it does |
|--------|-------------|
| **[1] What is this tool?** | Quick explainer — read this if it's your first time |
| **[2] Manual guide** | Step-by-step checklist if you prefer doing it yourself, no automation |
| **[3] Scan & Prepare** ⭐ | **Start here.** Scans your laptop and generates all reports + scripts |
| [4] Scan Only | Generates reports only, no install/transfer scripts |
| [5] Generate Scripts | Re-generate scripts from a previous scan (if you already scanned) |
| [6] Post-Migration Checklist | Run on your NEW laptop after migration to verify everything |
| [7] Clean Up Old Laptop | **Destructive** — deletes your data from the old laptop (last step, double-confirms) |

### 3. Copy `migration-output/` to your new laptop

Use USB drive, network share, or cloud sync.

### 4. Run the scripts

**On your OLD laptop** — transfer your data to the new laptop:

```powershell
# Copies your data folders (Documents, Projects, etc.) to the destination
.\Transfer-Data.ps1

# Verify nothing was missed
.\Verify-Transfer.ps1
```

**On your NEW laptop** — install your apps:

```powershell
# Install your apps (via winget)
.\Install-Software.ps1
```

### 5. Follow the Restoration Guide

Open the HTML report (`scan-report-*.html`) → click the **Restoration Guide** tab. It has copy-paste commands for Git config, VS Code extensions, env variables, npm/pip packages, and more.

### 6. Move folders to other drives (optional)

If your new laptop has multiple drives (D:\, E:\) and you want to move folders out of the migration landing zone:

**Option A: Windows built-in folder relocation (best for user folders)**

This makes Windows treat a folder on another drive as your official Documents/Downloads/etc everywhere — File Explorer, Save dialogs, all apps.

1. Open **File Explorer**
2. Right-click **Documents** (or Downloads, Pictures, Videos, Music, Desktop)
3. Click **Properties** → **Location** tab
4. Click **Move** → pick the new folder (e.g., `D:\Documents`)
5. Click **Apply** → **Yes** to move existing files

> Works for: Documents, Downloads, Desktop, Pictures, Videos, Music

**Option B: Robocopy move (best for project/data folders)**

Open PowerShell on the new laptop and move folders with robocopy. This copies files then deletes the source — fast and resume-safe:

```powershell
# Move a folder from migration landing zone to D:\
robocopy "C:\Migration\D\Projects" "D:\Projects" /E /MOVE /MT:16 /R:1 /W:1

# Move another folder to E:\
robocopy "C:\Migration\E\Code" "E:\Code" /E /MOVE /MT:16 /R:1 /W:1
```

> `/MOVE` = copies then deletes source. `/MT:16` = 16 threads for speed. Safe to re-run if interrupted.

**Option C: Drag and drop (simplest, one folder at a time)**

Open File Explorer → navigate to `C:\Migration\D\` → select a folder → **Cut** (Ctrl+X) → navigate to `D:\` → **Paste** (Ctrl+V).

### 7. Post-Migration Checklist

Do these on the **new laptop** after transferring data and installing software. Take your time — don't rush.

#### Sign in to sync (do these first)

- [ ] **OneDrive** — sign in → Desktop, Documents, Pictures sync back automatically
- [ ] **Browser (Chrome/Edge/Firefox)** — sign in → bookmarks, passwords, extensions all sync
- [ ] **VS Code** — `Ctrl+Shift+P` → "Settings Sync: Turn On" → sign in with GitHub or Microsoft
- [ ] **Microsoft 365 (Teams, Outlook, Word)** — sign in with your work/personal account
- [ ] **Password manager** — install and sign in (Bitwarden, 1Password, KeePass, etc.)

#### Set up manually (these don't sync)

- [ ] **Git config** — `git config --global user.name "Your Name"` and `git config --global user.email "you@email.com"`
- [ ] **SSH keys** — copy `.ssh/` folder via USB drive (never over network) → fix permissions:
  ```powershell
  icacls "$env:USERPROFILE\.ssh\id_*" /inheritance:r /grant:r "$($env:USERNAME):(R)"
  ```
  Test: `ssh -T git@github.com`
- [ ] **Environment variables** — Settings → System → About → Advanced → Environment Variables
- [ ] **PowerShell profile** — copy old `$PROFILE` content to new laptop (run `$PROFILE` to see path)
- [ ] **VPN** — configure connection settings (screenshot from old laptop helps)
- [ ] **Printers** — Settings → Bluetooth & Devices → Printers → Add printer

#### Rebuild project dependencies

After transferring project folders, open a terminal in each project and run:

| Project type | Command |
|-------------|---------|
| Node.js | `npm install` |
| Python | `pip install -r requirements.txt` |
| .NET / C# | `dotnet restore` |
| Java / Maven | `mvn clean install` |
| Java / Gradle | `gradle build` |
| Rust | `cargo build` |
| Go | `go mod download` |

#### Verify everything works

- [ ] Open each IDE/editor — VS Code, Visual Studio, IntelliJ
- [ ] Clone or open a Git repo — verify push/pull works
- [ ] Build at least one project per language you use
- [ ] Test SSH: `ssh -T git@github.com`
- [ ] Check browser extensions are present
- [ ] Verify Docker works: `docker run hello-world`
- [ ] Check mapped network drives (re-map if needed): `net use Z: \\server\share /persistent:yes`
- [ ] Test printers — print a test page

#### Important reminders

- [ ] **2FA / Authenticator** — set up on new device BEFORE wiping old laptop (Microsoft Authenticator, Google Authenticator, Authy)
- [ ] **License keys** — note down software license keys (check email receipts)
- [ ] **Outlook rules** — export: File → Manage Rules → Options → Export Rules
- [ ] **Outlook signatures** — copy `%APPDATA%\Microsoft\Signatures` folder

#### Wait before wiping

> **Wait at least 1–2 weeks** before deleting anything on the old laptop. You always discover something you missed after a few days. Keep the old laptop powered on and accessible as a backup.

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

## Security & Privacy

The script is **read-only** on your old laptop and never collects or transfers secrets.

| Item | What's captured | What's NOT captured |
|------|----------------|---------------------|
| **Environment variables** | Names only (with `<your-value>` placeholders) | Actual values — set manually from your password manager |
| **SSH keys** | File names listed; flagged for manual transfer | Key contents — never read or copied |
| **Windows Credential Manager** | Count of saved credentials | Actual credentials or passwords |
| **Browser passwords** | Not touched | Passwords, cookies, or session tokens |
| **Browser bookmarks** | Detected (sign-in syncs them) | Bookmark data is not exported |
| **WiFi networks** | Profile names only | Passwords or security keys |
| **Git config** | User name and email | Tokens, credentials, or credential helpers |
| **Docker** | Image names and volume names | Image layers or volume data |
| **Hosts file** | Custom entries listed in report | Not auto-restored (requires admin) |
| **WSL distros** | Distro names listed | File system contents — export manually |

> **TL;DR** — Names, counts, and metadata only. No passwords, tokens, keys, or secret values ever leave your machine through this script.

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
powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1                     # Interactive wizard (recommended)
powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1 -ScanOnly           # Reports only, no scripts
powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1 -FromCache          # Generate scripts from previous scan
powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1 -OutputDir "D:\out"  # Custom output folder
```

---

## Requirements

- **Windows 10 or 11**
- **PowerShell 5.1+** (built-in) or PowerShell 7
- **winget** (built into Windows 10/11 — used by Install-Software.ps1)
- No admin rights needed for scanning. Admin needed only for hosts file restore.

---

## Troubleshooting

<details><summary><strong>"File is not digitally signed" / UnauthorizedAccess error</strong></summary>

Windows blocks scripts downloaded from the internet on some machines. Fix it with **any one** of these:

**Option A: Bypass execution policy for this run only (recommended)**
```powershell
powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1
```

**Option B: Unblock the file, then run it**
```powershell
Unblock-File .\Migrate-Laptop.ps1
powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1
```

**Option C: Allow local scripts for your account (permanent)**
```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
Unblock-File .\Migrate-Laptop.ps1
.\Migrate-Laptop.ps1
```

**Why does this happen?** Windows marks downloaded files with a security flag (Zone Identifier). `Unblock-File` removes that flag, but if your execution policy is still `Restricted`, the script can still be blocked. `-ExecutionPolicy Bypass` works for that one run only.
</details>

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

Yes. Run `powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1` again and pick [3] or [4]. It overwrites the previous scan for the same date.
</details>

<details><summary><strong>Can I generate scripts without re-scanning?</strong></summary>

Yes — run `powershell -ExecutionPolicy Bypass -File .\Migrate-Laptop.ps1 -FromCache`. It uses the saved JSON from your last scan.
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

## Before You Start (on OLD laptop)

Do these **before** running the migration tool. Takes 10 minutes and saves hours later.

<details><summary><strong>Ensure sync is current</strong></summary>

- [ ] **OneDrive** — check system tray icon shows ✅ (fully synced, no pending uploads)
- [ ] **Browser sign-in** — verify you're signed into Chrome / Edge / Firefox
- [ ] **VS Code Settings Sync** — `Ctrl+Shift+P` → "Settings Sync: Turn On" → sign in
- [ ] **iCloud / Google Drive / Dropbox** — make sure everything is synced
</details>

<details><summary><strong>Back up what doesn't sync</strong></summary>

- [ ] **SSH keys** — copy `%USERPROFILE%\.ssh\` to USB drive (never email private keys)
- [ ] **License keys** — note from email receipts or use ProduKey
- [ ] **2FA / Authenticator** — ensure backup is on (Microsoft Authenticator, Authy). **You get locked out if you wipe without this**
- [ ] **Outlook rules** — File → Manage Rules → Options → Export Rules (`.rwz`)
- [ ] **VPN configs** — screenshot or export connection settings
- [ ] **KeePass database** — copy `.kdbx` file to USB
</details>

<details><summary><strong>Note down things you'll forget</strong></summary>

- [ ] **Printer names & IPs** — Settings → Printers (note network printer IPs)
- [ ] **Mapped network drives** — note `Z:\`, `X:\` paths from File Explorer
- [ ] **Custom hosts file entries** — check `C:\Windows\System32\drivers\etc\hosts`
- [ ] **Startup apps** — Task Manager → Startup tab
</details>

<details><summary><strong>Optional but helpful</strong></summary>

- [ ] **Docker volumes** — `docker volume ls` → export important ones
- [ ] **WSL distros** — `wsl --export Ubuntu ubuntu-backup.tar`
- [ ] **Local databases** — `pg_dump`, `mysqldump`, copy `.sqlite` files
</details>

> **TL;DR** — Make sure cloud sync is finished, copy SSH keys to USB, note license keys, back up 2FA. Then run the tool.

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

## Acknowledgements

Special thanks to **Monica Jain**, **Faiz Modi**, **Avishek Behera**, and **Amit Singh** for helping test this tool.

---

## Disclaimer

> **Use at your own risk.** While every precaution has been taken to make this tool safe and reliable, I am not responsible for any data loss, corruption, or unintended consequences. Always **back up your data independently** before running any migration. Verify everything works before wiping your old laptop.

---

## Wipe Old Laptop (Format C: Drive)

<details><summary><strong>How to securely wipe your old laptop after migration</strong></summary>

> **Do this only after** you've verified everything works on your new laptop. Wait at least 1–2 weeks.

### Step 1: Disable BitLocker

1. Open **Settings** → search for **BitLocker** → click **Manage BitLocker**
2. Click **Turn off BitLocker** → confirm
3. Wait for decryption to finish — check progress in an **admin** Command Prompt:
   ```powershell
   manage-bde -status C:
   ```
   Look for **"Percentage Encrypted"** — when it shows **0.0%** and status says **"Fully Decrypted"**, you're done.

   > **Estimated time:** ~30–60 min for NVMe SSD, ~1–2 hours for SATA SSD, ~3–6 hours for HDD.
   > Keep the laptop **plugged in** and don't let it sleep — decryption pauses during sleep.

### Step 2: Enable Windows Recovery Environment

Once BitLocker is fully off, open an **admin** Command Prompt and run:

```powershell
reagentc /enable
```

Verify it's enabled:

```powershell
reagentc /info
```

You should see **"Windows RE status: Enabled"**.

### Step 3: Reset the PC

1. Open **Settings** → **System** → **Recovery**
2. Click **Reset this PC**
3. Choose **Remove everything**
4. Select **Clean data** (overwrites the drive so files can't be recovered)
5. Confirm and let it run

The PC will restart and wipe everything. This can take 30–60 minutes.

### Alternative: Wipe via USB installer (if Reset doesn't work)

If the reset still fails, boot from a Windows USB installer:

1. Create a bootable USB using the [Windows Media Creation Tool](https://www.microsoft.com/software-download/windows11)
2. Boot from USB (press **F12** at startup for boot menu)
3. On the install screen, press **Shift+F10** to open Command Prompt
4. Run:
   ```
   diskpart
   select disk 0
   clean all
   exit
   ```
   > `clean all` writes zeros to every sector — secure but takes a few hours on large drives. Use `clean` (without `all`) for a quick wipe if BitLocker was previously enabled (encrypted data is unrecoverable without the key).

</details>

---

Created by [gauravkhurana.com](https://gauravkhurana.com) for the community.
Like this? [Star the repo](https://github.com/gauravkhuraana/new-laptop-setup) | [Connect](https://gauravkhurana.com/connect) | **#SharingIsCaring**
