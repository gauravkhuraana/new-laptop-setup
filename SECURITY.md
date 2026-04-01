# Security Policy

## What This Script Does (and Doesn't Do)

Migrate-Laptop scans your local machine to help you migrate to a new laptop. Security matters because it touches sensitive data — SSH keys, configs, environment variables, browser bookmarks.

Here's exactly what happens with your data:

### What it reads

| Data | How it's used | Where it goes |
|------|--------------|---------------|
| Installed software list | Generates `Install-Software.ps1` | Local files in `migration-output/` only |
| `.gitconfig` | Content saved so it can be restored on new machine | Embedded in `Restore-Configs.ps1` |
| SSH key **file names** | Listed in report (so you know what to transfer) | Report files only |
| VS Code extensions list | Generates install commands | `Restore-Configs.ps1` |
| PowerShell profile | Content saved for restore | `Restore-Configs.ps1` |
| Environment variables | Names + values captured | `Restore-Configs.ps1` |
| Browser bookmark files | Detected (not read) | Path noted in report |
| Hosts file entries | Custom entries listed | `Restore-Configs.ps1` (commented) |
| npm/pip package names | Package lists captured | `Restore-Configs.ps1` |

### What it NEVER does (in scan/migrate modes 1-4)

- **Never connects to the internet** — no API calls, no telemetry, no analytics, no phoning home. Note: the generated `Install-Software.ps1` uses `winget` which downloads software from the internet, but that's a separate script you review and run on the new laptop
- **Never reads SSH private key contents** — only lists file names in `.ssh/`
- **Never reads browser passwords** — only detects if bookmark files exist
- **Never reads Credential Manager** — only flags it as a manual step
- **Never modifies or deletes** anything on the old laptop — strictly read-only
- **Never runs with elevated privileges** — no admin required for scanning

### Cleanup mode (option 5) — DESTRUCTIVE by design

Option [5] "Clean Up Old Laptop" is the **only destructive mode**. It deliberately deletes personal data to prepare the laptop for handover. Safety features:

- **Double confirmation required** — must type `I HAVE VERIFIED` then `DELETE MY DATA`
- **Every sub-step asks [y/N]** — defaults to No, so nothing deletes without explicit yes
- **Never touches Windows, Program Files, or domain accounts**
- **Logged** — all actions recorded in the migration log
- **Never sends data anywhere** — all output stays in a local folder you control

### How to verify this yourself

The script is a single file. You can audit it:

```powershell
# 1. Confirm NO internet calls (should find zero Invoke-RestMethod/WebRequest):
Select-String -Path .\Migrate-Laptop.ps1 -Pattern 'Invoke-RestMethod|Invoke-WebRequest|Net.WebClient|curl|wget' |
    Where-Object { $_.Line -notmatch '^\s*#|AppendLine' } |
    Select-Object LineNumber, Line

# 2. Confirm NO file deletions:
Select-String -Path .\Migrate-Laptop.ps1 -Pattern 'Remove-Item|Delete|del |rmdir|rm ' |
    Where-Object { $_.Line -notmatch '^\s*#|AppendLine' } |
    Select-Object LineNumber, Line

# 3. Confirm SSH key contents are never read:
Select-String -Path .\Migrate-Laptop.ps1 -Pattern 'Get-Content.*\.ssh|ssh.*private|id_rsa|id_ed25519' |
    Where-Object { $_.Line -notmatch '^\s*#|AppendLine' } |
    Select-Object LineNumber, Line

# 4. Confirm all file writes go to the output directory only:
Select-String -Path .\Migrate-Laptop.ps1 -Pattern 'Set-Content|Add-Content|Out-File' |
    Select-Object LineNumber, Line

# 5. Verify no encoded/obfuscated strings:
Select-String -Path .\Migrate-Laptop.ps1 -Pattern 'FromBase64|Convert.*String|EncodedCommand|iex ' |
    Where-Object { $_.Line -notmatch '^\s*#|AppendLine' } |
    Select-Object LineNumber, Line
```

## Sensitive Data Handling

### SSH Keys — Extra Protection

SSH keys are your most sensitive asset. This script:

- **Lists file names only** (e.g., `id_rsa`, `id_ed25519`, `config`) — never reads contents
- **Flags them for manual USB transfer** — never includes them in network robocopy
- **Generated scripts include permission-fix commands** (`icacls`) for the new machine
- **Does NOT auto-copy SSH keys** — the user must manually transfer them

### Environment Variables

User environment variables are captured (names + values) so they can be restored. Review the generated `Restore-Configs.ps1` before running — remove any you don't want on the new machine.

### Browser Data

- **Bookmarks**: File paths are detected, not contents. Recommends browser sign-in sync.
- **Passwords**: Never touched. The manual checklist reminds you to enable sync.
- **Cookies/sessions**: Never touched.

### Git Config

The full `.gitconfig` content is embedded in `Restore-Configs.ps1`. If it contains tokens or credentials (it shouldn't, but check), remove them before transferring.

## Generated Scripts Safety

The scripts generated in `migration-output/` are designed to be safe:

| Script | Safety features |
|--------|----------------|
| `Install-Software.ps1` | Asks confirmation per section. "Other" software commented out by default. Uses `winget` (Microsoft's package manager) — no random download URLs. |
| `Transfer-Data.ps1` | Asks confirmation per folder. Never overwrites without user approval. Validates destination exists before starting. |
| `Restore-Configs.ps1` | Asks confirmation per config item. SSH keys require manual action. Environment variables shown before being set. |

**All generated scripts can and should be reviewed before running.** They are plain PowerShell — no obfuscation.

## Automated Security Checks

The [Security Scan workflow](.github/workflows/security-scan.yml) runs on every push and PR:

| Check | What it verifies |
|-------|-----------------|
| **PowerShell syntax** | Script parses without any syntax errors |
| **PSScriptAnalyzer** | PowerShell best practices + security rules (injection, credential handling) |
| **No network calls** | Zero outbound HTTP/HTTPS calls in the script |
| **No file deletions** | Script never deletes files on the source machine |
| **No SSH key reading** | Private key contents are never accessed |
| **No obfuscation** | No Base64 encoding, `Invoke-Expression` on user data, or encoded commands |
| **Write scope check** | All file writes go to the output directory only |
| **No credential handling** | No Get-Credential, SecureString, or password reading APIs |

## What to Review Before Running on New Laptop

Before executing the generated scripts on your new machine, check:

1. **`Install-Software.ps1`** — Are all the winget IDs correct? Remove any you don't need.
2. **`Restore-Configs.ps1`** — Does `.gitconfig` contain any tokens? Remove them. Are all environment variable values safe to set?
3. **`Transfer-Data.ps1`** — Are the source paths correct? Is the destination accessible?

## Reporting a Vulnerability

If you find a security issue:

1. **Do NOT open a public issue**
2. Use [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
3. Or email the maintainer directly
4. Include steps to reproduce

We take security seriously and will respond promptly.
