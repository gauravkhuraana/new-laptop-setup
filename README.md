# new-laptop-setup

### Migrate-Laptop — One script. Zero dependencies. Run it on your old laptop, copy the output folder to your new one, done.

Scans your old Windows laptop — software, configs, data folders — and generates ready-to-run scripts so you can set up your new machine in minutes instead of days.

## The Problem

Getting a new laptop should be exciting, not stressful. But in reality:
- You forget what software you had installed
- You lose configs (Git, SSH keys, VS Code extensions, environment variables...)
- You accidentally copy gigabytes of `node_modules`, `.venv`, and build junk
- You spend days reinstalling and reconfiguring everything
- You realize weeks later that you forgot something important

## What This Does

```
OLD LAPTOP (your current one)                    NEW LAPTOP (the new one)
════════════════════════════                     ════════════════════════

Step 1: SCAN                                     Step 0: PREPARE
┌─────────────────────────┐                      ┌─────────────────────────┐
│ Run: .\Migrate-Laptop.ps1                      │ 1. Create C:\Migration  │
│ Choose [1] Full Migration│                      │ 2. Right-click → Share  │
│                         │                      │ 3. Note laptop name/IP  │
│ Scans:                  │                      │    (e.g. NEW-PC or      │
│  • All drives (C,D,E)   │                      │     192.168.1.50)       │
│  • 172 software apps    │                      └─────────────────────────┘
│  • Browser extensions   │
│  • Office add-ins       │
│  • .gitconfig, SSH keys │
│  • VS Code extensions   │
│  • Env vars, WiFi...    │
│                         │
│ Generates:              │
│  📁 migration-output/   │
│   ├─ Install-Software.ps1
│   ├─ Transfer-Data.ps1  │
│   ├─ Restore-Configs.ps1│
│   ├─ reports (.html/.md)│
│   └─ scan cache (.json) │
└─────────┬───────────────┘
          │
          │ ⚠️ Review scripts
          │ (check for secrets in
          │  Restore-Configs.ps1)
          │
Step 2: TRANSFER DATA (over WiFi)
┌─────────────────────────┐      robocopy        ┌─────────────────────────┐
│ Run: .\Transfer-Data.ps1│─────────────────────► │ C:\Migration\           │
│                         │   \\NEW-PC\Migration  │   ├─ Desktop\           │
│ Choose [1] Network      │                       │   ├─ Documents\         │
│ Enter: NEW-PC           │   Per-folder confirm: │   ├─ Downloads\         │
│ Enter: Migration        │   Desktop (918 MB)? Y │   ├─ D_Automation\      │
│                         │   Documents (3.8GB)? Y│   ├─ E_projects\        │
│ Skips junk:             │   node_modules? SKIP  │   └─ ...                │
│  node_modules, .venv,   │   .cache? SKIP        │                         │
│  target, build, *.log   │                       │ If interrupted → re-run │
│                         │                       │ Resumes from last folder│
└─────────────────────────┘                       └─────────────────────────┘
          │
          │ Also copy migration-output/
          │ folder itself to new laptop
          │
          ▼
                                                  Step 3: INSTALL SOFTWARE
                                                  ┌─────────────────────────┐
                                                  │ Run: .\Install-Software │
                                                  │           .ps1          │
                                                  │                         │
                                                  │ Dev (16 apps)? Y        │
                                                  │  Installing [1/16] Git  │
                                                  │  Installing [2/16] Node │
                                                  │  ...via winget          │
                                                  │                         │
                                                  │ General (18 apps)? Y    │
                                                  │  Installing Chrome...   │
                                                  │  Installing Zoom...     │
                                                  │                         │
                                                  │ Other: commented out    │
                                                  │ (uncomment what u need) │
                                                  │                         │
                                                  │ If interrupted → resume │
                                                  └───────────┬─────────────┘
                                                              │
                                                  Step 4: RESTORE CONFIGS
                                                  ┌─────────────────────────┐
                                                  │ Run: .\Restore-Configs  │
                                                  │           .ps1          │
                                                  │                         │
                                                  │ .gitconfig? Y ✓         │
                                                  │ SSH keys? MANUAL (USB)  │
                                                  │ VS Code extensions? Y   │
                                                  │  code --install-ext ... │
                                                  │ PS profile? Y ✓         │
                                                  │ Env vars? Y ✓           │
                                                  │ npm packages? Y ✓       │
                                                  │ pip packages? Y ✓       │
                                                  │                         │
                                                  │ Browser ext → sign in   │
                                                  │ Office add-ins → sign in│
                                                  │ WiFi/theme → MS account │
                                                  └───────────┬─────────────┘
                                                              │
                                                  Step 5: VERIFY
                                                  ┌─────────────────────────┐
                                                  │ Run: .\Migrate-Laptop   │
                                                  │           .ps1          │
                                                  │ Choose [4] Checklist    │
                                                  │                         │
                                                  │ [1] Git works? ✓        │
                                                  │ [2] SSH keys? ✓         │
                                                  │ [3] VS Code? ✓          │
                                                  │ [4] Node.js? ✓          │
                                                  │ [5] Python? ✓           │
                                                  │ [6] Bookmarks? ✓        │
                                                  │ [7] Projects build? ✓   │
                                                  └───────────┬─────────────┘
                                                              │
          ┌───────────────────────────────────────────────────┘
          │ Once 100% satisfied...
          ▼
Step 6: CLEAN UP (optional)
┌─────────────────────────┐
│ On OLD laptop:          │
│ Run: .\Migrate-Laptop.ps1
│ Choose [5] Clean Up     │
│                         │
│ ██ WARNING ██           │
│ Type: I HAVE VERIFIED   │
│ Type: DELETE MY DATA    │
│                         │
│ Deletes personal data,  │
│ browser profiles, WiFi, │
│ credentials, SSH keys   │
│                         │
│ Keeps: Windows, apps,   │
│ domain login            │
└─────────────────────────┘
```

You stay in full control — **every generated script asks for confirmation** before doing anything.
Nothing is deleted or modified on your old laptop. Ever (unless you choose option [5] Clean Up).

## Quick Start

### Download

**Option A: Clone the repo**
```bash
git clone https://github.com/gauravkhuraana/new-laptop-setup.git
cd new-laptop-setup
```

**Option B: Download just the script**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/gauravkhuraana/new-laptop-setup/main/Migrate-Laptop.ps1" -OutFile "Migrate-Laptop.ps1"
```

### Run it

```powershell
# Just run it — interactive wizard guides you through everything:
.\Migrate-Laptop.ps1
```

That's it. A menu appears:

```
  ┌──────────────────────────────────────────────────────────┐
  │  Welcome! Pick where you'd like to start:                │
  ├──────────────────────────────────────────────────────────┤
  │                                                          │
  │  UNDERSTAND FIRST                                        │
  │  [1] What is this tool? (start here if first time)       │
  │  [2] I want to do it manually (no automation)            │
  │                                                          │
  │  USE THE TOOL                                            │
  │  [3] Scan & Prepare (SAFE: read-only scan)               │
  │  [4] Scan Only (report only, no scripts)                 │
  │  [5] Generate Scripts from Previous Scan                 │
  │                                                          │
  │  AFTER MIGRATION                                         │
  │  [6] Post-Migration Checklist (run on NEW laptop)        │
  │  [7] Clean Up Old Laptop (DESTRUCTIVE — cannot undo!)    │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

**First time?** Pick **[1]** — it explains what the tool can do, what it can't, and how it works.
When ready, pick **[3]** on your old laptop to scan and generate scripts.

## Step-by-Step Migration Guide

### Step 1: Scan your old laptop

```powershell
# On your OLD laptop — full scan + script generation:
.\Migrate-Laptop.ps1
# Choose option [1] Full Migration
```

This creates a `migration-output/` folder with everything you need.

### Step 2: Review the reports

Open the generated HTML report in your browser — it's interactive with tabs, search, and filtering:

```
migration-output/
├── scan-report-2026-03-29.html    ← Open this! Interactive dark-themed report
├── scan-report-2026-03-29.md      ← Markdown version
├── scan-2026-03-29.json           ← Raw data (can re-generate scripts later)
├── Install-Software.ps1           ← Ready to run on new laptop
├── Transfer-Data.ps1              ← Ready to run (old → new)
├── Restore-Configs.ps1            ← Ready to run on new laptop
└── migration-for-ai-review.md     ← Paste into ChatGPT/Copilot for advice
```

### Step 3: Copy the output folder to your new laptop

Use a USB drive, network share, or cloud sync — just get the `migration-output/` folder to your new machine.

### Step 4: Run the scripts on your new laptop (in order)

```powershell
# 1. Install all your software via winget
.\Install-Software.ps1

# 2. Transfer your data (choose: network, USB, or cloud)
.\Transfer-Data.ps1

# 3. Restore your configs (Git, VS Code extensions, env vars, etc.)
.\Restore-Configs.ps1
```

Each script asks for confirmation before every section. Nothing runs without your approval.

**Resume support:** If a script is interrupted (laptop sleeps, network drops, you close the window), just re-run it. Completed steps are tracked in a progress file and automatically skipped:

```
  Resuming from previous run — 12 steps already completed.
  To start fresh, delete: install-software-progress.json

  [SKIP] Git — already installed
  [SKIP] Node.js — already installed
  Installing [13/16]: Docker Desktop    ← picks up where you left off
```

To start fresh, delete the progress file (`*-progress.json`) next to the script.

### Step 5: Run the post-migration checklist

```powershell
# Back to the main script, choose option [4]:
.\Migrate-Laptop.ps1
# Choose option [4] Post-Migration Checklist
```

Walks you through verifying everything works: Git, SSH, VS Code, Node, Python, bookmarks, etc.

### Step 6: Clean up the old laptop (optional)

Once you're **100% satisfied** the new laptop is fully working:

```powershell
# On the OLD laptop — choose option [5]:
.\Migrate-Laptop.ps1
# Choose option [5] Clean Up Old Laptop
```

> **This is destructive and irreversible.** It requires typing `I HAVE VERIFIED` and then `DELETE MY DATA` to proceed. Each step also asks individual confirmation.

What it cleans (each step asks **[y/N]** individually):

| Step | What it does |
|------|-------------|
| 1 | Deletes contents of Desktop, Documents, Downloads, Pictures, Videos, Music |
| 2 | Deletes custom data folders on D:\, E:\, etc. |
| 3 | Removes Chrome, Edge, Firefox profile data (history, passwords, extensions, cookies) |
| 4 | Guides you through signing out of OneDrive, Teams, Google, iCloud |
| 5 | Deletes all saved WiFi passwords |
| 6 | Clears Windows Credential Manager (Git tokens, app passwords) |
| 7 | Deletes SSH keys and .gitconfig |
| 8 | Removes user environment variables (keeps PATH, TEMP) |
| 9 | Empties the Recycle Bin |

**What it does NOT touch:** Windows itself, installed programs, your domain/work login. The laptop stays bootable and usable — just clean of personal data.

## What It Scans

### Software (172 apps detected in testing)

Categorized automatically:

| Category | Examples | In Install script |
|----------|----------|-------------------|
| **Developer** (16 found) | VS Code, Git, Node.js, Python, Java, Docker, Azure CLI, PowerShell 7 | ✅ Active — runs by default |
| **General** (18 found) | Chrome, Edge, 7-Zip, Zoom, Slack, Teams, ShareX, PowerToys | ✅ Active — runs by default |
| **Other** (138 found) | Everything else on your machine | 💤 Commented out — uncomment what you need |

Uses `winget` IDs so installation is one command per app. Knows 60+ common developer and general apps.

### Configurations

| Config | How it's handled |
|--------|-----------------|
| `.gitconfig` | Captured and restored automatically |
| SSH keys (`.ssh/`) | **Flagged for manual USB transfer** (security) |
| VS Code extensions | Full list captured, batch-installed via `code --install-extension` |
| VS Code settings | Path noted; recommends Settings Sync |
| PowerShell profile | Content captured and restored |
| Windows Terminal settings | Content captured; notes Microsoft account sync |
| Environment variables | All user-level vars captured and restored via `[Environment]::SetEnvironmentVariable` |
| Browser bookmarks | Chrome + Edge files detected; recommends browser sign-in sync |
| Outlook rules | **Manual export required** (noted in report) |
| Scheduled tasks | User-created tasks listed in report |
| npm global packages | Captured and batch-installed via `npm install -g` |
| pip user packages | Captured and batch-installed via `pip install --user` |
| Hosts file entries | Custom entries listed; admin restore noted |

### Data Folders

- **User profile**: Desktop, Documents, Downloads, Pictures, Videos, Music, OneDrive
- **Custom folders**: Scans all drives (C, D, E, etc.) for non-system folders
- **Smart exclusions**: Automatically skips junk (see below)

## Smart Exclusions

The transfer script automatically skips things you should never copy:

```
Folders:  node_modules, .venv, venv, __pycache__, .pytest_cache, .cache,
          dist, build, target, bin, obj, coverage, .next, .nuxt,
          .gradle, .m2, $RECYCLE.BIN, System Volume Information

Files:    *.log, *.tmp, *.temp, *.bak, *.pyc, *.class, *.o, *.obj,
          Thumbs.db, desktop.ini
```

After transferring your projects, rebuild dependencies fresh:
```bash
npm install              # Node.js projects
pip install -r requirements.txt  # Python projects
mvn clean install        # Java/Maven projects
dotnet restore           # .NET projects
```

## Transfer Methods

The transfer script supports three ways to move your data:

| Method | Best for | How it works |
|--------|----------|-------------|
| **Network** | Both laptops on same WiFi/LAN | Robocopy to `\\NEW-LAPTOP\SharedFolder` |
| **USB / External Drive** | Large amounts of data | Robocopy to `F:\Migration\` |
| **Cloud** | Already using OneDrive/Google Drive | Guidance on syncing folders |

### Setting up network transfer

On your **new laptop**:
1. Create a folder (e.g., `C:\Migration`)
2. Right-click → Properties → Sharing → Share
3. Note the computer name or IP

On your **old laptop**:
```powershell
.\Transfer-Data.ps1
# Choose [1] Network
# Enter: NEW-LAPTOP (or 192.168.1.50)
# Enter: Migration
```

## All Options

```powershell
# Interactive wizard (recommended):
.\Migrate-Laptop.ps1

# Scan only — no scripts generated, just reports:
.\Migrate-Laptop.ps1 -ScanOnly

# Generate scripts from a previous scan (no re-scanning):
.\Migrate-Laptop.ps1 -FromCache

# Generate from a specific scan file:
.\Migrate-Laptop.ps1 -FromCache -CacheFile ".\migration-output\scan-2026-03-29.json"

# Custom output directory:
.\Migrate-Laptop.ps1 -OutputDir "D:\my-migration"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `OutputDir` | `./migration-output` | Where reports and scripts are saved |
| `ScanOnly` | `false` | Scan and generate reports only (no scripts) |
| `FromCache` | `false` | Skip scanning, generate scripts from previous scan JSON |
| `CacheFile` | auto-detected | Path to specific scan cache JSON file |

## Output Files

After a full run, your `migration-output/` folder contains:

| File | Purpose | When to use |
|------|---------|-------------|
| `scan-report-*.html` | Interactive report (dark theme, tabs, filters) | Open in browser to review everything |
| `scan-report-*.md` | Markdown report | Share or read in any editor |
| `scan-*.json` | Raw scan data | Re-generate scripts later without re-scanning |
| `Install-Software.ps1` | Installs apps via winget | Run on **new** laptop (review first!) |
| `Transfer-Data.ps1` | Copies data with smart exclusions | Run on **old** laptop (pushes data to new) |
| `Restore-Configs.ps1` | Restores Git, VS Code, env vars, etc. | Run on **new** laptop |
| `migration-for-ai-review.md` | AI-friendly summary | Paste into ChatGPT/Copilot for personalized advice |
| `migration-log-*.txt` | Detailed log of the scan | Troubleshooting |

## Don't Forget (Manual Steps)

These can't be automated — the report flags them for you:

- [ ] **Outlook rules** — Export via File → Manage Rules & Alerts → Options → Export Rules
- [ ] **SSH keys** — Copy `.ssh/` folder via USB drive (never over unencrypted network)
- [ ] **License keys** — Note down software license keys before wiping old laptop
- [ ] **Browser passwords** — Sign into Chrome/Edge/Firefox to sync passwords
- [ ] **2FA / Authenticator apps** — Ensure backup codes are saved or app is synced
- [ ] **VPN configs** — Screenshot or export connection settings
- [ ] **Printer configs** — Note network printer IPs and names
- [ ] **Credential Manager** — Review Windows Credential Manager for saved credentials

## ⚠️ Secrets & Sensitive Data — Read This

The generated scripts may contain **sensitive information from your old machine**. This is by design (so configs can be restored), but you need to be aware:

### What gets embedded in generated scripts

| File | What's inside | Risk |
|------|--------------|------|
| `Restore-Configs.ps1` | Your `.gitconfig` content (full text) | May contain GitHub tokens if you use credential helpers |
| `Restore-Configs.ps1` | Your PowerShell profile (full text) | May contain API keys, custom functions with secrets |
| `Restore-Configs.ps1` | All user environment variable names + values | **High risk** — API keys, tokens, connection strings often stored here |
| `Restore-Configs.ps1` | Custom hosts file entries | Low risk, but reveals internal hostnames |
| `scan-*.json` | All of the above in JSON format | Same risks as above |
| `migration-for-ai-review.md` | Software list, drive info | Low risk, but reveals your setup |

### What to do

1. **Before sharing** the `migration-output/` folder with anyone:
   - Open `Restore-Configs.ps1` and check the `.gitconfig` section for tokens
   - Review the environment variables section — remove any API keys or secrets
   - Check the PowerShell profile section for sensitive values

2. **Never commit** `migration-output/` to a public Git repo — add it to `.gitignore`

3. **Delete the output folder** from the old laptop after you've confirmed the new one works

4. **If using network transfer** (robocopy), use a trusted private network — data is unencrypted

### The script itself is safe

The main `Migrate-Laptop.ps1` script:
- Never connects to the internet (the generated `Install-Software.ps1` uses `winget` which downloads from the internet — but that's a separate script you review and run yourself)
- Never reads SSH private key contents (only file names)
- Never reads browser passwords
- Never deletes or modifies files on your old laptop
- All verified by [automated security scans](.github/workflows/security-scan.yml) on every commit

See [SECURITY.md](SECURITY.md) for the full security policy and self-audit commands.

## Prerequisites

- **Windows 10 or 11**
- **PowerShell 5.1+** (built-in) or PowerShell 7 (recommended)
- **winget** (built into Windows 10/11 — used by Install-Software.ps1)

No admin rights needed for scanning. Admin needed only for hosts file restore.

## Core Principles

This tool follows a simple philosophy:

| Do | Don't |
|----|-------|
| Copy **data** (source code, documents, photos) | Copy **system** (Windows, Program Files, drivers) |
| **Reinstall** software fresh via winget | Copy installed programs between machines |
| **Rebuild** dependencies (`npm install`, `pip install`) | Transfer `node_modules`, `.venv`, `target` |
| **Review** every script before running | Auto-execute anything without approval |
| **Read** from old laptop only | Delete or modify anything on old laptop |

## Bulk Install — How Commenting Works

The generated `Install-Software.ps1` has three sections:

```powershell
# DEVELOPER SOFTWARE (16 apps) — all ACTIVE
winget install --id "Git.Git" ...           # ← runs by default
winget install --id "Docker.DockerDesktop"   # ← runs by default
# winget install --id "Docker.DockerDesktop" # ← add # to SKIP it

# GENERAL SOFTWARE (18 apps) — all ACTIVE
winget install --id "Google.Chrome" ...      # ← runs by default

# OTHER SOFTWARE (138 apps) — all COMMENTED OUT
# winget install --id "Anthropic.Claude" ... # ← remove # to INSTALL it
# winget install --id "Bruno.Bruno" ...      # ← remove # to INSTALL it
```

**To skip** an app: add `#` at the start of its `winget` line
**To add** an app: remove `#` from its line in the OTHER section

Before running, each section shows the full list and asks for confirmation.

## Mac Users

This tool is **Windows-only** (PowerShell + winget + robocopy are Windows tools).

However, the concepts and approach work on Mac too. The generated `Install-Software.ps1` includes Mac equivalents at the bottom:

```bash
# Install Homebrew:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Then install your tools:
brew install git node python docker
brew install --cask visual-studio-code google-chrome firefox
```

## FAQ

**Q: Does it work on Mac?**
A: No — it's Windows-only (PowerShell, winget, robocopy). But the generated `Install-Software.ps1` includes Homebrew equivalents at the bottom. The same philosophy applies: scan, plan, execute.

**Q: Does it back up WiFi passwords, wallpaper, mouse settings, etc.?**
A: Yes — it scans WiFi profiles, theme/dark mode, wallpaper path, mouse speed, cursor scheme, keyboard layout, sound scheme, display scaling, and region. Most of these sync automatically via your Microsoft account. The report tells you which ones sync vs need manual setup.

**Q: How do I know what syncs automatically vs what I need to export?**
A: The report includes a "Sync vs Export" table. Things like browser data, VS Code settings, WiFi, and theme sync via your accounts. Things like Git config, env vars, and SSH keys are captured by this tool. Things like display scaling and sound are hardware-dependent and flagged as manual.

**Q: What if the script gets interrupted mid-way (network drop, laptop sleep)?**
A: Just re-run the same script. Each step is tracked in a `*-progress.json` file. Completed steps show `[SKIP]` and it picks up where you left off. This works for Install-Software, Transfer-Data, and Restore-Configs.

**Q: Can I re-run the scan if I forgot something?**
A: Yes! Just run `.\Migrate-Laptop.ps1` again. It overwrites the previous scan for the same date.

**Q: Can I generate scripts without re-scanning?**
A: Yes — run `.\Migrate-Laptop.ps1 -FromCache`. It uses the saved JSON from your last scan.

**Q: What if winget doesn't know one of my apps?**
A: The report lists all software. Unrecognized apps appear in the "Other" section (commented out). Install those manually.

**Q: Is it safe?**
A: The script **only reads** from your old laptop. It never deletes, modifies, or moves files. Generated scripts on the new laptop ask permission before every action.

**Q: Does it work with multiple drives?**
A: Yes — it scans all drives (C, D, E, etc.) and includes custom folders from each in the transfer script.

**Q: What about WSL (Windows Subsystem for Linux)?**
A: WSL distros aren't migrated automatically. Export them manually: `wsl --export Ubuntu ubuntu-backup.tar` then import on the new machine: `wsl --import Ubuntu C:\WSL\ ubuntu-backup.tar`.

---

Created by [gauravkhurana.com](https://gauravkhurana.com) for the community. **#SharingIsCaring**
