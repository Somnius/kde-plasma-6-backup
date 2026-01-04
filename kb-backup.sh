#!/bin/bash

###############################################################################
# KDE Plasma 6 Backup Script
# 
# This script backs up all KDE Plasma 6 settings including:
# - Themes, decorations, colors, icons
# - Keyboard shortcuts, language, regional settings
# - Window manager settings, panel configurations
# - User-installed themes/icons/color schemes
#
# Usage: ./kb-backup.sh [OPTIONS]
#   --output-dir DIR    Specify backup directory (default: ./backup-YYYYMMDD-HHMMSS)
#   --no-compress       Don't compress the backup
#   --include-packages  Include package list for reinstallation
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect package manager (handles niche distros via /etc/os-release)
detect_package_manager() {
    # First check if package manager commands exist
    if command -v pacman >/dev/null 2>&1; then
        echo "pacman"
        return
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
        return
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
        return
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
        return
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
        return
    elif command -v emerge >/dev/null 2>&1; then
        echo "emerge"
        return
    fi
    
    # If no package manager found, check /etc/os-release for base distribution
    # This handles niche distros like PikaOS (Debian-based), CachyOS (Arch-based), etc.
    if [[ -f /etc/os-release ]]; then
        local id_like=$(grep "^ID_LIKE=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' | cut -d' ' -f1)
        local id=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        
        # Check ID_LIKE first (more reliable for derived distros)
        case "$id_like" in
            arch|archlinux)
                if command -v pacman >/dev/null 2>&1; then
                    echo "pacman"
                    return
                fi
                ;;
            debian|ubuntu)
                if command -v apt >/dev/null 2>&1; then
                    echo "apt"
                    return
                fi
                ;;
            fedora|rhel|centos)
                if command -v dnf >/dev/null 2>&1; then
                    echo "dnf"
                    return
                elif command -v yum >/dev/null 2>&1; then
                    echo "yum"
                    return
                fi
                ;;
            suse|opensuse)
                if command -v zypper >/dev/null 2>&1; then
                    echo "zypper"
                    return
                fi
                ;;
            gentoo)
                if command -v emerge >/dev/null 2>&1; then
                    echo "emerge"
                    return
                fi
                ;;
        esac
        
        # Fallback to ID if ID_LIKE didn't match
        case "$id" in
            arch|archlinux|manjaro|cachyos|endeavouros)
                if command -v pacman >/dev/null 2>&1; then
                    echo "pacman"
                    return
                fi
                ;;
            debian|ubuntu|pika|pikaos|mint|pop|elementary)
                if command -v apt >/dev/null 2>&1; then
                    echo "apt"
                    return
                fi
                ;;
            fedora|rhel|centos)
                if command -v dnf >/dev/null 2>&1; then
                    echo "dnf"
                    return
                elif command -v yum >/dev/null 2>&1; then
                    echo "yum"
                    return
                fi
                ;;
            opensuse*|suse)
                if command -v zypper >/dev/null 2>&1; then
                    echo "zypper"
                    return
                fi
                ;;
            gentoo)
                if command -v emerge >/dev/null 2>&1; then
                    echo "emerge"
                    return
                fi
                ;;
        esac
    fi
    
    echo "unknown"
}

# Get package list command for package manager
get_package_list_command() {
    local pkgmgr="$1"
    case "$pkgmgr" in
        pacman)
            echo "pacman -Q | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | awk '{print \$1}'"
            ;;
        apt)
            echo "dpkg -l | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | awk '{print \$2}'"
            ;;
        dnf|yum)
            echo "rpm -qa | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)'"
            ;;
        zypper)
            echo "zypper search --installed-only | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | awk '{print \$3}'"
            ;;
        emerge)
            echo "qlist -I | grep -E '(plasma|kde)' | grep -E '(theme|icon|color|desktop)' | sed 's/.*\\///'"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get install command hint for package manager
get_install_hint() {
    local pkgmgr="$1"
    case "$pkgmgr" in
        pacman)
            echo "sudo pacman -S"
            ;;
        apt)
            echo "sudo apt install"
            ;;
        dnf)
            echo "sudo dnf install"
            ;;
        yum)
            echo "sudo yum install"
            ;;
        zypper)
            echo "sudo zypper install"
            ;;
        emerge)
            echo "sudo emerge"
            ;;
        *)
            echo "your package manager"
            ;;
    esac
}

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE_DIR="${SCRIPT_DIR}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_BASE_DIR}/backup-${TIMESTAMP}"
COMPRESS=true
INCLUDE_PACKAGES=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --no-packages)
            INCLUDE_PACKAGES=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --output-dir DIR    Specify backup directory"
            echo "  --no-compress       Don't compress the backup"
            echo "  --no-packages       Don't include package list"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should not be run as root${NC}"
    exit 1
fi

echo -e "${BLUE}=== KDE Plasma 6 Backup Script ===${NC}"
echo -e "${BLUE}Backup directory: ${BACKUP_DIR}${NC}"
echo ""

# Create backup directory structure
mkdir -p "${BACKUP_DIR}"/{config,local-share,metadata}

# Function to backup a directory or file
backup_item() {
    local source="$1"
    local dest="$2"
    local description="$3"
    
    if [[ -e "$source" ]]; then
        echo -e "${GREEN}Backing up: ${description}${NC}"
        mkdir -p "$(dirname "$dest")"
        cp -r "$source" "$dest" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Could not backup ${source}${NC}"
            return 1
        }
        return 0
    else
        echo -e "${YELLOW}Skipping (not found): ${description}${NC}"
        return 1
    fi
}

# Function to backup a config file
backup_config() {
    local filename="$1"
    local description="${2:-$filename}"
    backup_item "${HOME}/.config/${filename}" "${BACKUP_DIR}/config/${filename}" "$description"
}

echo -e "${BLUE}--- Backing up configuration files ---${NC}"

# Core KDE Plasma configuration files
backup_config "kdeglobals" "Global KDE settings (themes, colors, fonts)"
backup_config "plasmarc" "Plasma theme and wallpaper settings"
backup_config "plasmashellrc" "Plasma shell configuration"
backup_config "plasma-org.kde.plasma.desktop-appletsrc" "Panel and desktop applets configuration"
backup_config "plasma-localerc" "Regional and language settings"
backup_config "user-dirs.locale" "User directories locale settings"
backup_config "plasma-workspace" "Workspace environment settings"
backup_config "plasmanotifyrc" "Notification settings"

# Window manager (KWin)
backup_config "kwinrc" "Window manager settings"
backup_config "kwinrulesrc" "Window rules"
backup_config "kwinoutputconfig.json" "Display/output configuration"

# Keyboard and input
backup_config "kglobalshortcutsrc" "Global keyboard shortcuts"
backup_config "kxkbrc" "Keyboard layout and switcher settings"
backup_config "kcminputrc" "Input device settings"

# KDE services
backup_config "kded6rc" "KDE daemon configuration (Plasma 6)"
backup_config "kded5rc" "KDE daemon configuration (legacy)"

# Activity manager
backup_config "kactivitymanagerdrc" "Activity manager settings"
backup_config "kactivitymanagerd-statsrc" "Activity manager statistics"

# Desktop portal
backup_config "xdg-desktop-portal-kderc" "Desktop portal settings (file dialog sizes, etc.)"

# KDE Connect
backup_item "${HOME}/.config/kdeconnect" "${BACKUP_DIR}/config/kdeconnect" "KDE Connect settings"

# KDE defaults (if they exist)
if [[ -d "${HOME}/.config/kdedefaults" ]]; then
    backup_item "${HOME}/.config/kdedefaults" "${BACKUP_DIR}/config/kdedefaults" "KDE default settings (includes ksplashrc)"
fi

# KDE.org application settings
if [[ -d "${HOME}/.config/kde.org" ]]; then
    backup_item "${HOME}/.config/kde.org" "${BACKUP_DIR}/config/kde.org" "KDE application settings"
fi

# Autostart entries
if [[ -d "${HOME}/.config/autostart" ]]; then
    backup_item "${HOME}/.config/autostart" "${BACKUP_DIR}/config/autostart" "Autostart applications"
fi

# Default applications (mimeapps.list)
backup_config "mimeapps.list" "Default applications for file types"

echo ""
echo -e "${BLUE}--- Backing up user-installed themes, icons, and resources ---${NC}"

# Plasma themes (desktop themes)
if [[ -d "${HOME}/.local/share/plasma/desktoptheme" ]]; then
    backup_item "${HOME}/.local/share/plasma/desktoptheme" \
                "${BACKUP_DIR}/local-share/plasma/desktoptheme" \
                "Plasma desktop themes"
fi

# Look and feel packages
if [[ -d "${HOME}/.local/share/plasma/look-and-feel" ]]; then
    backup_item "${HOME}/.local/share/plasma/look-and-feel" \
                "${BACKUP_DIR}/local-share/plasma/look-and-feel" \
                "Plasma look-and-feel packages"
fi

# Color schemes
if [[ -d "${HOME}/.local/share/color-schemes" ]]; then
    backup_item "${HOME}/.local/share/color-schemes" \
                "${BACKUP_DIR}/local-share/color-schemes" \
                "Color schemes"
fi

# Icon themes
if [[ -d "${HOME}/.local/share/icons" ]]; then
    backup_item "${HOME}/.local/share/icons" \
                "${BACKUP_DIR}/local-share/icons" \
                "Icon themes"
fi

# Aurorae window decorations
if [[ -d "${HOME}/.local/share/aurorae/themes" ]]; then
    backup_item "${HOME}/.local/share/aurorae/themes" \
                "${BACKUP_DIR}/local-share/aurorae/themes" \
                "Aurorae window decorations"
fi

# Wallpapers
if [[ -d "${HOME}/.local/share/wallpapers" ]]; then
    backup_item "${HOME}/.local/share/wallpapers" \
                "${BACKUP_DIR}/local-share/wallpapers" \
                "User wallpapers"
fi

# KDE6 specific data
if [[ -d "${HOME}/.local/share/kded6" ]]; then
    backup_item "${HOME}/.local/share/kded6" \
                "${BACKUP_DIR}/local-share/kded6" \
                "KDE6 daemon data"
fi

# KNewStuff registries (downloaded content metadata)
if [[ -d "${HOME}/.local/share/knewstuff3" ]]; then
    backup_item "${HOME}/.local/share/knewstuff3" \
                "${BACKUP_DIR}/local-share/knewstuff3" \
                "KNewStuff download registries"
fi

echo ""
echo -e "${BLUE}--- Creating metadata ---${NC}"

# Save system information
{
    echo "Backup created: $(date)"
    echo "User: $(whoami)"
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')"
    echo "KDE Plasma version: $(plasmashell --version 2>/dev/null | head -1 || echo 'Unknown')"
    echo "KWin version: $(kwin --version 2>/dev/null | head -1 || echo 'Unknown')"
    echo ""
    echo "Hardware information:"
    echo "  CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs || echo 'Unknown')"
    echo "  GPU: $(lspci | grep -i vga | cut -d: -f3 | xargs || echo 'Unknown')"
    echo "  Displays: $(xrandr --listmonitors 2>/dev/null | grep -c 'Monitors:' || echo 'Unknown')"
} > "${BACKUP_DIR}/metadata/system-info.txt"

# Extract current theme/icon/color scheme settings
if [[ -f "${HOME}/.config/kdeglobals" ]]; then
    echo ""
    echo -e "${BLUE}Current settings:${NC}"
    grep -E "^(Theme|ColorScheme|IconTheme|Font)" "${HOME}/.config/kdeglobals" 2>/dev/null | \
        tee "${BACKUP_DIR}/metadata/current-theme-settings.txt" || true
fi

if [[ -f "${HOME}/.config/plasmarc" ]]; then
    grep -E "^(name|Theme)" "${HOME}/.config/plasmarc" 2>/dev/null | \
        tee -a "${BACKUP_DIR}/metadata/current-theme-settings.txt" || true
fi

# Create package list if requested
if [[ "$INCLUDE_PACKAGES" == true ]]; then
    echo ""
    echo -e "${BLUE}--- Creating package list ---${NC}"
    
    # Detect package manager
    PKG_MGR=$(detect_package_manager)
    INSTALL_HINT=$(get_install_hint "$PKG_MGR")
    LIST_CMD=$(get_package_list_command "$PKG_MGR")
    
    # List installed KDE/Plasma theme/icon packages
    {
        echo "# KDE Plasma theme and icon packages"
        echo "# Package manager: ${PKG_MGR}"
        echo "# Install with: ${INSTALL_HINT} \$(grep -v '^#' kde-packages.txt)"
        echo "# Note: Package names may differ between distributions"
        echo ""
        if [[ "$PKG_MGR" != "unknown" ]]; then
            eval "$LIST_CMD" | sort -u
        else
            echo "# Could not detect package manager - package list not generated"
        fi
    } > "${BACKUP_DIR}/metadata/kde-packages.txt" 2>/dev/null || true
    
    if [[ "$PKG_MGR" != "unknown" ]]; then
        echo -e "${GREEN}Package list saved to metadata/kde-packages.txt (${PKG_MGR})${NC}"
    else
        echo -e "${YELLOW}Warning: Could not detect package manager - package list not generated${NC}"
    fi
fi

# Create a manifest of all backed up items
echo ""
echo -e "${BLUE}--- Creating backup manifest ---${NC}"
{
    echo "KDE Plasma 6 Backup Manifest"
    echo "Created: $(date)"
    echo ""
    echo "=== Configuration Files ==="
    find "${BACKUP_DIR}/config" -type f 2>/dev/null | sed "s|${BACKUP_DIR}/||" | sort
    echo ""
    echo "=== User Resources ==="
    find "${BACKUP_DIR}/local-share" -type f 2>/dev/null | sed "s|${BACKUP_DIR}/||" | sort
} > "${BACKUP_DIR}/metadata/manifest.txt"

echo -e "${GREEN}Manifest saved to metadata/manifest.txt${NC}"

# Create categories metadata for selective restore
echo ""
echo -e "${BLUE}--- Creating categories metadata ---${NC}"
{
    echo "# KDE Plasma 6 Backup Categories"
    echo "# Format: category|file_path|description"
    echo "# Used for selective restore functionality"
    echo ""
    echo "# Appearance & Themes"
    echo "appearance|config/kdeglobals|Global KDE settings (themes, colors, fonts)"
    echo "appearance|config/plasmarc|Plasma theme and wallpaper settings"
    echo "appearance|local-share/plasma/desktoptheme|Plasma desktop themes"
    echo "appearance|local-share/plasma/look-and-feel|Plasma look-and-feel packages"
    echo "appearance|local-share/color-schemes|Color schemes"
    echo "appearance|local-share/icons|Icon themes"
    echo "appearance|local-share/aurorae/themes|Window decorations (Aurorae)"
    echo "appearance|local-share/wallpapers|User wallpapers"
    echo ""
    echo "# Keyboard & Input"
    echo "keyboard|config/kglobalshortcutsrc|Global keyboard shortcuts"
    echo "keyboard|config/kxkbrc|Keyboard layout and switcher settings"
    echo "keyboard|config/kcminputrc|Input device settings (mouse, touchpad)"
    echo ""
    echo "# Language & Regional"
    echo "language|config/plasma-localerc|Regional and language settings"
    echo "language|config/user-dirs.locale|User directories locale settings"
    echo ""
    echo "# Window Manager"
    echo "window-manager|config/kwinrc|Window manager settings"
    echo "window-manager|config/kwinrulesrc|Window rules"
    echo "window-manager|config/kwinoutputconfig.json|Display/output configuration (hardware-specific)"
    echo ""
    echo "# Desktop & Panels"
    echo "desktop|config/plasma-org.kde.plasma.desktop-appletsrc|Panel and desktop applets configuration"
    echo "desktop|config/plasmashellrc|Plasma shell configuration"
    echo "desktop|config/plasma-workspace|Workspace environment settings"
    echo ""
    echo "# Notifications"
    echo "notifications|config/plasmanotifyrc|Notification settings"
    echo ""
    echo "# Applications"
    echo "applications|config/kde.org|KDE application settings (Discover, Dolphin, Kate, etc.)"
    echo "applications|config/autostart|Autostart applications"
    echo "applications|config/mimeapps.list|Default applications for file types"
    echo ""
    echo "# System Services"
    echo "services|config/kded6rc|KDE daemon configuration (Plasma 6)"
    echo "services|config/kded5rc|KDE daemon configuration (legacy)"
    echo "services|config/kactivitymanagerdrc|Activity manager settings"
    echo "services|config/kactivitymanagerd-statsrc|Activity manager statistics"
    echo "services|config/xdg-desktop-portal-kderc|Desktop portal settings"
    echo "services|config/kdedefaults|KDE default settings"
    echo ""
    echo "# Connectivity"
    echo "connectivity|config/kdeconnect|KDE Connect settings"
    echo ""
    echo "# KDE6 Data"
    echo "kde6-data|local-share/kded6|KDE6 daemon data"
    echo "kde6-data|local-share/knewstuff3|KNewStuff download registries"
} > "${BACKUP_DIR}/metadata/categories.txt" 2>/dev/null || true

echo -e "${GREEN}Categories metadata saved to metadata/categories.txt${NC}"

# Compress if requested
if [[ "$COMPRESS" == true ]]; then
    echo ""
    echo -e "${BLUE}--- Compressing backup ---${NC}"
    cd "${BACKUP_BASE_DIR}"
    tar -czf "backup-${TIMESTAMP}.tar.gz" "backup-${TIMESTAMP}"
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Backup compressed to: backup-${TIMESTAMP}.tar.gz${NC}"
        echo -e "${YELLOW}You can remove the uncompressed directory if desired${NC}"
    else
        echo -e "${RED}Warning: Compression failed, keeping uncompressed backup${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Backup completed successfully! ===${NC}"
echo -e "${BLUE}Backup location: ${BACKUP_DIR}${NC}"
if [[ "$COMPRESS" == true ]]; then
    echo -e "${BLUE}Compressed archive: ${BACKUP_BASE_DIR}/backup-${TIMESTAMP}.tar.gz${NC}"
fi
echo ""
echo -e "${YELLOW}To restore this backup, run:${NC}"
echo -e "${YELLOW}  ./kde-backup restore ${BACKUP_DIR}${NC}"

