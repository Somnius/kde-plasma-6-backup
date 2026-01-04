# KDE Plasma 6 Backup and Restore Guide

Complete guide for backing up and restoring all KDE Plasma 6 settings, themes, configurations, and user preferences.

![Version](https://img.shields.io/badge/version-1.2--beta-orange)
![License](https://img.shields.io/badge/license-MIT-blue)
![Shell](https://img.shields.io/badge/shell-Bash-green)
![Markdown](https://img.shields.io/badge/markdown-README-blue)

**Top Languages:**
![Bash](https://img.shields.io/badge/Bash-100%25-89e051?logo=gnu-bash&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell%20Script-100%25-89e051?logo=gnu-bash&logoColor=white)

**Status:** 🧪 **Beta Testing** - Currently being tested on latest PikaOS 4 (codename "nest") on desktop and virtual machines.

**License:** [MIT](LICENSE)

---

<a name="important-limitations"></a>
## ⚠️ Important Limitations <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

<div style="border: 2px solid #ff6b6b; background-color: #fff5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">

**⚠️ Cross-Distribution Compatibility Warning**

This project is **not recommended for cross-distribution use** (different base distributions). Some packages may not exist on other distributions (e.g., distribution-specific packages like `pika-kde-*` packages on PikaOS).

**Recommended Usage:**
- ✅ **Same distribution to same distribution** (e.g., CachyOS to CachyOS)
- ✅ **Same base distribution** (e.g., Arch to Arch, Debian/Ubuntu-based to Debian/Ubuntu-based)
- ❌ **Does NOT work on immutable distributions** (e.g., Fedora Silverblue, openSUSE MicroOS, NixOS) - **at all**

While the scripts include cross-distribution package manager detection, package name differences and distribution-specific packages will cause issues. Use with caution when restoring on different distributions.

</div>

---

<a name="important-use-the-wrapper-script"></a>
## ⚠️ Important: Use the Wrapper Script <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

**Always use the `kde-backup` wrapper script for all operations:**

```bash
./kde-backup backup    # Create backup
./kde-backup validate  # Validate backup
./kde-backup restore   # Restore backup
```

The individual scripts (`kb-backup.sh`, `kb-restore.sh`, `kb-validate.sh`) are internal implementation details and should be accessed through the wrapper only.

## Table of Contents

- [Important Limitations](#important-limitations)
- [Important: Use the Wrapper Script](#important-use-the-wrapper-script)
- [Quick Start](#quick-start)
- [Cross-Distribution Support](#cross-distribution-support)
- [Safety and Precautions](#safety-and-precautions)
- [Scripts Documentation](#scripts-documentation)
- [Testing Guide](#testing-guide)
- [What Gets Backed Up](#what-gets-backed-up)
- [What Cannot Be Recovered](#what-cannot-be-recovered)
- [Configuration Locations Reference](#configuration-locations-reference)
- [Quick Reference Commands](#quick-reference-commands)
- [Troubleshooting](#troubleshooting)
- [Manual Backup/Restore](#manual-backuprestore)
- [Backup Structure](#backup-structure)
- [Tips and Best Practices](#tips-and-best-practices)
- [References](#references)
- [License](#license)

---

<a name="quick-start"></a>
## Quick Start <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### Create a Backup

```bash
cd ~/kde-plasma-6-backup
./kde-backup backup
```

Creates a timestamped backup directory (e.g., `backup-20250104-120000`) and optionally compresses it.

### Validate a Backup (Recommended Before Restore)

```bash
./kde-backup validate backup-20250104-120000
```

Checks backup integrity and compatibility before restoring.

### Restore a Backup

```bash
# First validate (recommended)
./kde-backup validate backup-20250104-120000

# Then restore (with safety options for different hardware)
./kde-backup restore backup-20250104-120000 --skip-display-config

# Or restore with themes re-downloaded from repositories
./kde-backup restore backup-20250104-120000 --re-download-themes
```

**Note:** The `kde-backup` wrapper script is the recommended interface. Individual scripts (`kb-backup.sh`, `kb-restore.sh`, `kb-validate.sh`) are internal implementation details and should be accessed through the wrapper.

<a name="cross-distribution-support"></a>
## Cross-Distribution Support <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

The scripts automatically detect and support multiple Linux distributions and their package managers:

- **Arch-based:** Arch Linux, Manjaro, CachyOS, EndeavourOS (uses `pacman`)
- **Debian-based:** Debian, Ubuntu, PikaOS, Linux Mint, Pop!_OS, Elementary OS (uses `apt`)
- **Fedora-based:** Fedora, RHEL, CentOS (uses `dnf` or `yum`)
- **openSUSE:** openSUSE (uses `zypper`)
- **Gentoo:** Gentoo Linux (uses `emerge`)

Detection works by checking for package manager commands and `/etc/os-release` to identify base distributions, ensuring compatibility with niche distributions derived from major ones.

**Note:** Package names may differ between distributions. When using `--re-download-themes`, the script will attempt to install packages, but some may fail if names differ. This is expected and you may need to install packages manually.

---

<a name="safety-and-precautions"></a>
## Safety and Precautions <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### ⚠️ Is It Safe to Restore on Another System?

**Yes, with proper precautions.** KDE Plasma is designed to handle configuration changes gracefully, and the scripts include multiple safety measures.

### Safety Features Implemented

1. **Automatic Validation**
   - Restore script validates backups before restoring
   - Checks for essential files, permissions, and structure
   - Warns about potential compatibility issues

2. **Hardware-Specific Safety**
   - **Display Configuration (`kwinoutputconfig.json`):** Contains monitor-specific settings
     - **Risk:** Can cause display issues (black screen, wrong resolution) on different hardware
     - **Solution:** Use `--skip-display-config` when restoring on different systems
     - **Default behavior:** Script prompts before restoring display config

3. **Version Compatibility Checks**
   - Validates Plasma version compatibility
   - Warns about major version mismatches
   - Settings from Plasma 6.x should work on Plasma 6.x

4. **Backup of Existing Files**
   - Automatically backs up existing config files before overwriting
   - Files are renamed with timestamp: `filename.backup-YYYYMMDD-HHMMSS`
   - Easy rollback if needed

5. **Dry-Run Mode**
   - Preview what will be restored without making changes
   - Use `--dry-run` to see exactly what the restore will do

6. **Validation Script**
   - Standalone validation script (`kb-validate.sh`)
   - Check backup integrity before attempting restore
   - Identifies potential issues early

### Will KDE Session Start/Recover?

**Yes, KDE Plasma is designed to handle this:**

1. **Graceful Degradation:** If a setting causes issues, Plasma will:
   - Fall back to defaults for that specific setting
   - Continue running with other settings intact
   - Log warnings (check `journalctl --user -b | grep -i plasma`)

2. **Safe Configuration Storage:** All settings are in `~/.config/`:
   - User-writable (no root required)
   - Can be safely modified or removed
   - Plasma recreates defaults if files are missing

3. **Recovery Options:**
   - **TTY Access:** If display fails, use Ctrl+Alt+F2 to access terminal
   - **Remove problematic files:** Delete specific config files to reset
   - **Full reset:** Remove `~/.config/kde*` to start fresh (last resort)

### Recommended Restore Process

1. **Validate the backup:**
   ```bash
   ./kb-validate.sh backup-YYYYMMDD-HHMMSS
   ```

2. **Dry-run to preview:**
   ```bash
   ./kb-restore.sh backup-YYYYMMDD-HHMMSS --dry-run
   ```

3. **Restore with safety options:**
   ```bash
   # For different hardware (recommended):
   ./kb-restore.sh backup-YYYYMMDD-HHMMSS --skip-display-config
   
   # For same hardware:
   ./kb-restore.sh backup-YYYYMMDD-HHMMSS
   ```

4. **After restore:**
   - Log out and log back in (recommended)
   - Or restart Plasma: `killall plasmashell && kstart plasmashell`
   - Or reboot

---

<a name="scripts-documentation"></a>
## Scripts Documentation <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### `kde-backup` (Main Wrapper - **Use This**)

The main entry point for all backup/restore operations. This wrapper delegates to the appropriate internal scripts.

**Usage:**
```bash
./kde-backup backup [OPTIONS]
./kde-backup restore BACKUP_DIR [OPTIONS]
./kde-backup validate BACKUP_DIR
./kde-backup help
```

**Examples:**
```bash
# Create backup
./kde-backup backup

# Validate backup
./kde-backup validate backup-20250104-120000

# Restore backup (with safety options)
./kde-backup restore backup-20250104-120000 --skip-display-config

# Restore with re-downloading themes from repositories
./kde-backup restore backup-20250104-120000 --re-download-themes

# Get help
./kde-backup help
./kde-backup backup --help
./kde-backup restore --help
```

**Note:** The individual scripts (`kb-backup.sh`, `kb-restore.sh`, `kb-validate.sh`) are internal implementation details. Use the wrapper for all operations.

---

### Internal Scripts (Advanced Users Only)

The following scripts are called by the wrapper. They are documented here for reference, but you should use the `kde-backup` wrapper instead.

#### `kb-backup.sh`

Backs up all KDE Plasma 6 settings.

**Options:**
- `--output-dir DIR` - Specify custom backup directory
- `--no-compress` - Don't compress the backup (faster, larger)
- `--no-packages` - Don't include package list for reinstallation

**Examples:**
```bash
# Basic backup
./kb-backup.sh

# Backup to specific location without compression
./kb-backup.sh --output-dir ~/my-backup --no-compress

# Backup without package list
./kb-backup.sh --no-packages
```

#### `kb-restore.sh`

Restores KDE Plasma 6 settings from a backup.

**Note:** Use `./kde-backup restore` instead.

**Options:**
- `--re-download-themes` - Re-download themes/icons from repositories instead of restoring files
- `--skip-user-resources` - Only restore config files, skip themes/icons
- `--skip-display-config` - Skip display configuration (safe for different hardware)
- `--dry-run` - Show what would be restored without making changes
- `--validate-only` - Validate backup without restoring

**Safety Features:**
- Automatically validates backup before restore
- Warns about hardware-specific settings
- Creates backups of existing files before overwriting
- Prompts before restoring display configuration
- Checks Plasma version compatibility

**Examples:**
```bash
# Basic restore
./kb-restore.sh backup-20250104-120000

# Restore from compressed backup
./kb-restore.sh backup-20250104-120000.tar.gz

# Re-download themes from repositories (allows updates via Discover)
./kb-restore.sh backup-20250104-120000 --re-download-themes

# Only restore configuration, skip themes/icons
./kb-restore.sh backup-20250104-120000 --skip-user-resources

# Preview what would be restored
./kb-restore.sh backup-20250104-120000 --dry-run

# Validate only (no restore)
./kb-restore.sh backup-20250104-120000 --validate-only
```

#### `kb-validate.sh`

Validates backup integrity and compatibility.

**Note:** Use `./kde-backup validate` instead.

**Usage:**
```bash
./kb-validate.sh backup-20250104-120000
```

**What it checks:**
- Backup structure and essential files
- File permissions and readability
- Plasma version compatibility
- Hardware-specific settings (warnings)
- Autostart entries
- User resources

**Exit codes:**
- `0` - Validation passed (may have warnings)
- `1` - Validation failed (has errors)

---

<a name="testing-guide"></a>
## Testing Guide <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

Step-by-step guide to test the backup and restore scripts on your current system.

### Step 1: Create a Test Backup

```bash
cd ~/kde-plasma-6-backup

# Create a backup (this is safe, only reads your config)
./kde-backup backup
```

**Expected output:**
- Creates a directory like `backup-20250104-120000`
- Shows files being backed up
- Creates compressed archive `backup-20250104-120000.tar.gz`

**Note the backup directory name** - you'll need it for next steps.

### Step 2: Validate the Backup

```bash
# Replace with your actual backup directory name
./kde-backup validate backup-20250104-120000
```

**What to check:**
- ✓ All checks should pass (green checkmarks)
- ⚠️ Warnings are okay (like display config warning)
- ✗ Errors should not appear

**Expected:** Validation should pass with maybe some warnings about display config.

### Step 3: Dry-Run Restore (Preview Only)

This shows what would be restored **without making any changes**:

```bash
./kde-backup restore backup-20250104-120000 --dry-run
```

**What to check:**
- Lists all files that would be restored
- Shows source and destination paths
- No actual files are modified

**Expected:** Should show all your config files and resources that would be restored.

### Step 4: Validate-Only Mode

Another way to test validation:

```bash
./kde-backup restore backup-20250104-120000 --validate-only
```

**Expected:** Same validation as Step 2, but through the restore script.

### Step 5: Test Restore a Single File (Optional)

If you want to test restoring just one file to verify it works:

```bash
# Backup a single file first (safety)
cp ~/.config/kdeglobals ~/.config/kdeglobals.test-backup

# Manually restore from backup
cp backup-20250104-120000/config/kdeglobals ~/.config/kdeglobals

# Check if it's the same
diff ~/.config/kdeglobals.test-backup ~/.config/kdeglobals

# If everything looks good, restore your original
mv ~/.config/kdeglobals.test-backup ~/.config/kdeglobals
```

### Step 6: Full Test Restore (Advanced)

⚠️ **Warning:** This will restore all your settings. Make sure you have a backup first!

Since you're testing on the same system, this should restore your current settings (no change expected).

```bash
# The script automatically backs up existing files before overwriting
./kde-backup restore backup-20250104-120000
```

**What happens:**
- Script backs up existing files (with timestamp)
- Restores from your backup
- Your settings should remain the same (since backup = current state)

**After restore:**
- Log out and log back in (recommended)
- Or restart Plasma: `killall plasmashell && kstart plasmashell`

**To revert if needed:**
- Files are backed up as `filename.backup-YYYYMMDD-HHMMSS`
- You can manually restore them if needed

### Quick Test Sequence

For a quick test without full restore:

```bash
cd ~/kde-plasma-6-backup

# 1. Create backup
./kde-backup backup

# 2. Note the backup directory name (e.g., backup-20250104-120000)

# 3. Validate
./kde-backup validate backup-20250104-120000

# 4. Dry-run (preview)
./kde-backup restore backup-20250104-120000 --dry-run

# Done! No changes made to your system.
```

### What to Verify

After testing, verify:

1. **Backup created successfully:**
   - Directory exists: `backup-YYYYMMDD-HHMMSS/`
   - Contains `config/`, `local-share/`, `metadata/` subdirectories
   - Compressed archive exists: `backup-YYYYMMDD-HHMMSS.tar.gz`

2. **Validation passes:**
   - No errors (red ✗)
   - Warnings are acceptable (yellow ⚠️)
   - Essential files are present

3. **Dry-run shows expected files:**
   - Lists your config files
   - Lists your themes/icons
   - Shows correct paths

4. **Files are readable:**
   ```bash
   # Check a few files
   cat backup-YYYYMMDD-HHMMSS/config/kdeglobals | head -5
   ls -la backup-YYYYMMDD-HHMMSS/local-share/plasma/desktoptheme/
   ```

### Troubleshooting Tests

**If validation fails:**
- Check backup directory exists
- Verify file permissions
- Check backup wasn't corrupted

**If dry-run shows errors:**
- Check backup structure
- Verify all paths are correct
- Check file permissions

**If restore test fails:**
- Check logs: `journalctl --user -b | grep -i plasma`
- Restore script creates backups of existing files
- You can manually restore from `.backup-YYYYMMDD-HHMMSS` files

### Success Criteria

✅ **Test is successful if:**
1. Backup creates without errors
2. Validation passes (may have warnings)
3. Dry-run shows all expected files
4. Backup files are readable
5. Backup structure is correct

You're ready to use the backup for real restoration when needed!

---

<a name="what-gets-backed-up"></a>
## What Gets Backed Up <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### ✅ Fully Backed Up and Recoverable

**Configuration Files:**
- Themes, colors, icons, fonts (`kdeglobals`)
- Plasma theme and wallpaper (`plasmarc`)
- Panel layout and widgets (`plasma-org.kde.plasma.desktop-appletsrc`)
- Keyboard shortcuts (`kglobalshortcutsrc`)
- Keyboard layout and switcher (`kxkbrc`)
- Language/regional settings (`plasma-localerc`)
- Window manager settings (`kwinrc`, `kwinrulesrc`)
- Display configuration (`kwinoutputconfig.json`) - *use caution on different hardware*
- Input device settings (`kcminputrc`)
- Activity manager (`kactivitymanagerdrc`, `kactivitymanagerd-statsrc`)
- Desktop portal settings (`xdg-desktop-portal-kderc`)
- Notification settings (`plasmanotifyrc`)
- KDE services (`kded6rc`, `kded5rc`)
- KDE Connect settings
- Autostart applications
- KDE application settings (Discover, Dolphin, Kate, etc.)

**User Resources:**
- User-installed Plasma themes
- User-installed icon themes
- User-installed color schemes
- User-installed window decorations (Aurorae)
- Custom wallpapers
- Look-and-feel packages

**Metadata:**
- System information
- Current theme settings
- Package list for reinstallation
- Complete backup manifest

---

<a name="what-cannot-be-recovered"></a>
## What Cannot Be Recovered <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### ❌ Not Backed Up (System-Wide Settings)

These settings require manual reconfiguration or are system-specific:

1. **System-Wide Configuration (`/etc/`):**
   - Display manager settings (`/etc/sddm/`, `/etc/gdm/`, etc.)
   - System-wide KDE defaults (`/etc/xdg/`)
   - System-wide autostart (`/etc/xdg/autostart/`)

2. **Package-Managed Resources:**
   - System themes/icons in `/usr/share/` (but package list is saved for reinstallation)
   - System wallpapers in `/usr/share/wallpapers/`

3. **Hardware-Specific Settings:**
   - Display configuration (`kwinoutputconfig.json`) - **backed up but may not work on different hardware**
   - GPU-specific compositor settings
   - Monitor-specific arrangements

4. **Application Data (Not Settings):**
   - Application data in `~/.local/share/` (Dolphin bookmarks are in config, but some app data isn't)
   - Browser profiles, email data, etc. (not KDE-specific)

5. **Session State:**
   - Currently open windows/positions
   - Running applications
   - Temporary session data

6. **System Services:**
   - Systemd user services configuration
   - System-wide services

### ⚠️ Requires Manual Attention

1. **Missing Applications:**
   - Autostart entries for applications not installed on target system (harmless, just ignored)
   - Themes/icons not available in repositories (can restore files directly)

2. **Version-Specific Settings:**
   - Settings that changed format between Plasma versions
   - Deprecated settings (Plasma handles gracefully)

3. **Network/System-Specific:**
   - Network printer configurations
   - System-specific paths in some configs
   - Hardware-specific input device settings

### 📝 Precautions for Complete Restoration

To ensure complete restoration:

1. **Install Required Packages:**
   - Check `metadata/kde-packages.txt` from backup
   - Install themes/icons from repositories when possible
   - Use `--re-download-themes` option

2. **Verify System Compatibility:**
   - Same or compatible Plasma version
   - Required applications installed
   - Hardware compatibility (especially for display config)

3. **Manual Steps After Restore:**
   - Reconfigure display if using different hardware
   - Reinstall missing applications from autostart
   - Verify network printers if applicable
   - Check system services if needed

---

<a name="configuration-locations-reference"></a>
## Configuration Locations Reference <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### Configuration Files (`~/.config/`)

#### Core Plasma Settings

| File/Directory | Description | What It Contains |
|---------------|-------------|------------------|
| `kdeglobals` | Global KDE settings | Theme names, color scheme, icon theme, fonts, widget style |
| `plasmarc` | Plasma theme and wallpaper | Desktop theme name, wallpaper path |
| `plasmashellrc` | Plasma shell configuration | Shell behavior, startup settings |
| `plasma-org.kde.plasma.desktop-appletsrc` | Panel and applets | Panel layout, widgets, applet positions |
| `plasma-localerc` | Regional settings | Language, locale, date/time format |
| `plasma-workspace/` | Workspace environment | Environment variables, workspace-specific settings |
| `plasmanotifyrc` | Notification settings | Notification behavior, do not disturb settings |

#### Window Manager (KWin)

| File | Description | What It Contains |
|------|-------------|------------------|
| `kwinrc` | Window manager settings | Window decorations, effects, compositor settings, window behavior |
| `kwinrulesrc` | Window rules | Per-application window rules (size, position, behavior) |
| `kwinoutputconfig.json` | Display configuration | Multi-monitor setup, display arrangement ⚠️ Hardware-specific |

#### Keyboard and Input

| File | Description | What It Contains |
|------|-------------|------------------|
| `kglobalshortcutsrc` | Global keyboard shortcuts | All system-wide keyboard shortcuts |
| `kxkbrc` | Keyboard layout settings | Keyboard layout, layout switcher options, compose key |
| `kcminputrc` | Input device settings | Mouse, touchpad, tablet settings |

#### KDE Services and Activity Manager

| File | Description | What It Contains |
|------|-------------|------------------|
| `kded6rc` | KDE daemon configuration (Plasma 6) | Service settings, module configurations |
| `kded5rc` | KDE daemon configuration (legacy) | Legacy service settings |
| `kactivitymanagerdrc` | Activity manager settings | Activity configurations |
| `kactivitymanagerd-statsrc` | Activity statistics | Activity usage statistics |
| `xdg-desktop-portal-kderc` | Desktop portal settings | File dialog sizes, portal preferences |

#### Other Configuration

| Directory | Description | What It Contains |
|-----------|-------------|------------------|
| `kdeconnect/` | KDE Connect settings | Device pairings, notification settings |
| `kdedefaults/` | KDE default settings | System-wide default overrides (includes `ksplashrc`) |
| `kde.org/` | KDE application settings | Settings for Discover, Dolphin, Kate, etc. |
| `autostart/` | Autostart applications | `.desktop` files for applications that start with Plasma |

### User Resources (`~/.local/share/`)

#### Themes and Visual Resources

| Directory | Description | What It Contains |
|-----------|-------------|------------------|
| `plasma/desktoptheme/` | Plasma desktop themes | User-installed Plasma themes (Nordic, Dracula, etc.) |
| `plasma/look-and-feel/` | Look and feel packages | Complete desktop appearance packages |
| `color-schemes/` | Color schemes | User-installed color schemes (if any) |
| `icons/` | Icon themes | User-installed icon themes (Papirus, Nordic, etc.) |
| `aurorae/themes/` | Window decorations | User-installed Aurorae window decoration themes |
| `wallpapers/` | User wallpapers | Custom wallpapers (if stored here) |

#### KDE6 Specific Data

| Directory | Description | What It Contains |
|-----------|-------------|------------------|
| `kded6/` | KDE6 daemon data | Keyboard layouts, service data |
| `knewstuff3/` | KNewStuff registries | Metadata for content downloaded via Get Hot New Stuff (themes, icons, etc.) |

### System-Wide Resources (Package-Managed)

System-wide themes, icons, and resources are installed in `/usr/share/`:

- `/usr/share/plasma/desktoptheme/` - System Plasma themes
- `/usr/share/plasma/look-and-feel/` - System look-and-feel packages
- `/usr/share/color-schemes/` - System color schemes
- `/usr/share/icons/` - System icon themes
- `/usr/share/wallpapers/` - System wallpapers
- `/usr/share/aurorae/themes/` - System window decorations

**Note:** System-wide resources are managed by package managers and don't need to be backed up. They can be reinstalled via your distribution's package manager (apt, pacman, dnf, etc.) or Discover. The backup includes a package list for easy reinstallation, and the restore script automatically detects and uses the correct package manager.

---

<a name="quick-reference-commands"></a>
## Quick Reference Commands <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### View Current Settings

```bash
# Theme settings
grep -E "(Theme|ColorScheme|IconTheme)" ~/.config/kdeglobals
cat ~/.config/plasmarc

# Keyboard shortcuts
cat ~/.config/kglobalshortcutsrc

# Keyboard layout
cat ~/.config/kxkbrc
```

### List Installed Themes/Icons

```bash
# User-installed
ls ~/.local/share/plasma/desktoptheme/
ls ~/.local/share/icons/

# System-installed
ls /usr/share/plasma/desktoptheme/
ls /usr/share/icons/
```

### Backup/Restore Commands

```bash
# Create backup
cd ~/kde-plasma-6-backup
./kde-backup backup

# Validate backup
./kde-backup validate backup-YYYYMMDD-HHMMSS

# Restore backup (skip display config for different hardware)
./kde-backup restore backup-YYYYMMDD-HHMMSS --skip-display-config

# Restore with themes re-downloaded from repositories
./kde-backup restore backup-YYYYMMDD-HHMMSS --re-download-themes

# Dry-run (preview)
./kde-backup restore backup-YYYYMMDD-HHMMSS --dry-run

# Get help
./kde-backup help
```

### Apply Settings After Changes

```bash
# Restart Plasma Shell
killall plasmashell && kstart plasmashell

# Reload KWin (Window Manager)
qdbus org.kde.KWin /KWin reconfigure

# Full reload (logout/login recommended)
# Most reliable way to apply all settings
```

---

<a name="troubleshooting"></a>
## Troubleshooting <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

### Settings Not Applied After Restore

1. **Log out and log back in** - Many settings require a new session
2. **Restart Plasma:** `killall plasmashell && kstart plasmashell`
3. **Reboot** - Most reliable way to ensure all settings are applied

### Display Issues After Restore

If you experience display problems (black screen, wrong resolution, etc.):

1. **Switch to TTY:** Press `Ctrl+Alt+F2` (or F3-F6)
2. **Remove display config:**
   ```bash
   rm ~/.config/kwinoutputconfig.json
   ```
3. **Restart display manager:**
   ```bash
   sudo systemctl restart sddm  # or gdm, lightdm, etc.
   ```

**Prevention:** Always use `--skip-display-config` when restoring on different hardware.

### Themes Not Found After Restore

- If using `--re-download-themes`, check that themes are available in your repositories
- Some themes may need to be installed manually from Discover
- Check `metadata/kde-packages.txt` for package names
- User-installed themes are restored directly (won't get updates)

### Permission Issues

- Ensure backup files have correct ownership: `chown -R $USER:$USER ~/.config ~/.local/share`
- Some config files may have restrictive permissions (600) - this is normal

### KDE Session Won't Start

If KDE Plasma fails to start after restore:

1. **Boot to recovery/TTY** (Ctrl+Alt+F2)
2. **Check logs:**
   ```bash
   journalctl -b -u sddm  # or your display manager
   journalctl --user -b | grep -i plasma
   ```
3. **Reset to defaults (last resort):**
   ```bash
   # Backup current config
   mv ~/.config/kdeglobals ~/.config/kdeglobals.broken
   mv ~/.config/plasmarc ~/.config/plasmarc.broken
   # Log back in - Plasma will create defaults
   ```
4. **Gradually restore:** Restore files one at a time to identify the problematic setting

### Validation Fails

If validation reports errors:
- Check that backup is complete and not corrupted
- Verify file permissions on backup directory
- Ensure you have read access to all backup files
- Check that essential files exist in backup

### Missing Applications in Autostart

- Applications that don't exist on target system are simply ignored (harmless)
- Install missing applications or remove autostart entries manually

---

<a name="manual-backuprestore"></a>
## Manual Backup/Restore <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

If you prefer to manually backup specific settings:

### Backup Specific Settings

```bash
# Themes and colors
cp ~/.config/kdeglobals ~/backup/
cp ~/.config/plasmarc ~/backup/

# Keyboard shortcuts
cp ~/.config/kglobalshortcutsrc ~/backup/

# Window manager
cp ~/.config/kwinrc ~/backup/
cp ~/.config/kwinrulesrc ~/backup/

# User themes
cp -r ~/.local/share/plasma/desktoptheme ~/backup/
cp -r ~/.local/share/icons ~/backup/
```

### Restore Specific Settings

```bash
# Restore themes and colors
cp ~/backup/kdeglobals ~/.config/
cp ~/backup/plasmarc ~/.config/

# Restore keyboard shortcuts
cp ~/backup/kglobalshortcutsrc ~/.config/

# Restore window manager
cp ~/backup/kwinrc ~/.config/
cp ~/backup/kwinrulesrc ~/.config/

# Restore user themes
cp -r ~/backup/desktoptheme ~/.local/share/plasma/
cp -r ~/backup/icons ~/.local/share/
```

---

<a name="backup-structure"></a>
## Backup Structure <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

A backup directory contains:

```
backup-YYYYMMDD-HHMMSS/
├── config/              # All configuration files
│   ├── kdeglobals
│   ├── plasmarc
│   ├── kwinrc
│   ├── kactivitymanagerdrc
│   ├── xdg-desktop-portal-kderc
│   └── ...
├── local-share/         # User-installed resources
│   ├── plasma/
│   ├── icons/
│   └── ...
└── metadata/            # Backup information
    ├── system-info.txt      # System information
    ├── current-theme-settings.txt  # Current theme settings
    ├── kde-packages.txt     # List of installed packages
    └── manifest.txt         # Complete file list
```

---

<a name="tips-and-best-practices"></a>
## Tips and Best Practices <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

1. **Regular Backups:** Create backups after making significant changes to your setup
2. **Test Restores:** Test restoring on a test system or VM before you need it
3. **Package Lists:** The backup includes a package list (`metadata/kde-packages.txt`) for easy reinstallation
4. **Compressed Backups:** Compressed backups are smaller but take longer to create
5. **Version Compatibility:** Backups from Plasma 6 should work on Plasma 6, but may not be compatible with Plasma 5
6. **Hardware Differences:** Always use `--skip-display-config` when restoring on different hardware
7. **Validate First:** Always validate backups before restoring

---

<a name="references"></a>
## References <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

- [KDE UserBase - Configuration Files](https://userbase.kde.org/KDE_System_Administration/Configuration_Files)
- [Plasma Desktop Configuration](https://develop.kde.org/docs/plasma/configuration/)

---

<a name="license"></a>
## License <span style="float:right; font-size:0.7em;">[↑ Back to TOC](#table-of-contents)</span>

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
